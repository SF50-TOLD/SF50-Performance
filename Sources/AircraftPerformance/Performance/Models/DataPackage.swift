import Foundation
import Synchronization

/// One aircraft's bundled data package, as Data-Extraction's `afm export` writes it.
///
/// A package holds a directory per source document, a directory of equations per configuration,
/// `residuals.json`, and the `manifest.json` that says which document each configuration reads
/// each table from. A configuration's data is read the first time it is asked for and shared by
/// every request afterwards.
final class DataPackage: Sendable {
  private static let dataDirectoryName = "Data",
    manifestFilename = "manifest.json"

  /// The SF50 Vision Jet's package.
  static let sf50 = Result { try DataPackage(name: "sf50") }

  /// The package's directory in the bundle.
  let directory: URL

  /// The package's manifest.
  let manifest: PackageManifest

  /// Every equation's and lookup table's error bounds, keyed by
  /// `<document>/<table path without .csv>`.
  let residuals: [String: ResidualData]

  private let loadedConfigurations = Mutex<[String: Result<AircraftData, any Error>]>([:])

  /**
   * Reads a package's manifest from the bundle.
   *
   * - Parameter name: The package's directory under `Data`.
   * - Throws: ``PerformanceDataError`` if the manifest cannot be read, or describes a package or
   *   equation format this loader doesn't read.
   */
  private init(name: String) throws {
    directory = try Self.directory(named: name)
    manifest = try Self.loadManifest(in: directory)
    try manifest.validateFormat()
    residuals = try ResidualData.load(in: directory)
  }

  // MARK: - Loading

  private static func directory(named name: String) throws -> URL {
    guard let resources = Bundle.module.resourceURL else {
      throw PerformanceDataError.missingResource(path: dataDirectoryName)
    }
    return resources.appending(component: dataDirectoryName, directoryHint: .isDirectory)
      .appending(component: name, directoryHint: .isDirectory)
  }

  private static func loadManifest(in directory: URL) throws -> PackageManifest {
    let path = "\(directory.lastPathComponent)/\(manifestFilename)"
    let data: Data
    do {
      data = try Data(contentsOf: directory.appending(component: manifestFilename))
    } catch {
      throw PerformanceDataError.missingResource(path: path)
    }
    do {
      return try JSONDecoder().decode(PackageManifest.self, from: data)
    } catch {
      throw PerformanceDataError.unreadableResource(path: path, underlying: error)
    }
  }

  // MARK: - Configurations

  /// The data of the configuration with a base manual and exactly a set of supplements.
  ///
  /// - Parameter selection: The base manual and the supplements installed over it.
  /// - Throws: ``PerformanceDataError`` if the package has no such configuration, or its data
  ///   could not be read.
  func configuration(_ selection: ConfigurationSelection) throws -> AircraftData {
    guard
      let name = manifest.configurationName(
        base: selection.base,
        supplements: selection.supplements
      )
    else {
      throw PerformanceDataError.missingConfiguration(
        package: manifest.aircraft.name,
        base: selection.base,
        supplements: selection.supplements.sorted()
      )
    }
    return try configuration(named: name)
  }

  /// The data of a configuration named in the manifest.
  ///
  /// - Parameter name: The configuration's name, such as `g2+`.
  /// - Throws: ``PerformanceDataError`` if the configuration's data could not be read.
  func configuration(named name: String) throws -> AircraftData {
    let data = loadedConfigurations.withLock { loaded in
      if let data = loaded[name] { return data }
      let data = Result { try AircraftData(configuration: name, in: self) }
      loaded[name] = data
      return data
    }
    return try data.get()
  }
}
