import Foundation

/// The digitized AFM tables and fitted regression equations of one configuration in a
/// ``DataPackage``.
///
/// Each table is read from the document the package's manifest names for it, so a configuration
/// that layers a supplement over its base reads the supplement's tables where it prints them and
/// the base's everywhere else. Equations are read from the configuration's own `regressions`
/// directory, which holds its complete set.
struct AircraftData: Sendable {
  private static let regressionsDirectoryName = "regressions",
    equationExtension = "json"

  /// The configuration's name, such as `g2+`.
  let directoryName: String

  /// Tables keyed by path relative to a document's directory, such as `takeoff/ground run.csv`.
  private let tables: [String: DataTable]

  /// Regression equations keyed by file name, such as `takeoff-ground-run.json`.
  private let equations: [String: RegressionEquation]

  /**
   * Reads a configuration's tables and equations from its package.
   *
   * - Parameters:
   *   - configuration: The configuration's name in the package's manifest.
   *   - package: The package holding it.
   * - Throws: ``PerformanceDataError`` if a file cannot be read, or if an equation names residuals
   *   the package does not carry.
   */
  init(configuration: String, in package: DataPackage) throws {
    guard let tablePaths = package.manifest.configurations[configuration]?.tables else {
      throw PerformanceDataError.missingResource(path: configuration)
    }
    tables = try Self.loadTables(tablePaths, in: package.directory)
    equations = try Self.loadEquations(
      in: package.directory.appending(component: configuration)
        .appending(component: Self.regressionsDirectoryName)
    )

    try ResidualErrorCalculator.validate(
      tables: equations.values.compactMap(\.uncertaintyKey)
        + ResidualErrorCalculator.contaminationTables
    )

    directoryName = configuration
  }

  // MARK: - Type Methods

  /// The data set for an aircraft type.
  ///
  /// - Parameter aircraftType: The aircraft whose data is wanted.
  /// - Returns: The G1, G2 or updated-thrust data set.
  /// - Throws: ``PerformanceDataError`` if the data set could not be read from the bundle.
  static func forType(_ aircraft: Aircraft) throws -> Self {
    try aircraft.definition.data()
  }

  /// Reads each table from the document the manifest names for it.
  private static func loadTables(
    _ documents: [String: String],
    in packageDirectory: URL
  ) throws -> [String: DataTable] {
    try documents.reduce(into: [:]) { tables, entry in
      let (path, document) = entry
      do {
        tables[path] = try DataTable(
          fileURL: packageDirectory.appending(component: document).appending(path: path)
        )
      } catch {
        throw PerformanceDataError.unreadableResource(
          path: "\(document)/\(path)",
          underlying: error
        )
      }
    }
  }

  private static func loadEquations(in directory: URL) throws -> [String: RegressionEquation] {
    try files(withExtension: equationExtension, in: directory).reduce(into: [:]) {
      equations,
      path in
      do {
        equations[path] = try RegressionEquation(fileURL: directory.appending(path: path))
      } catch {
        throw PerformanceDataError.unreadableResource(path: path, underlying: error)
      }
    }
  }

  /// The names of the files in a directory with an extension.
  private static func files(withExtension pathExtension: String, in directory: URL) throws
    -> [String]
  {
    do {
      let names = try FileManager.default.contentsOfDirectory(
        atPath: directory.path(percentEncoded: false)
      )
      return names.filter { $0.hasSuffix(".\(pathExtension)") }
    } catch {
      throw PerformanceDataError.unreadableResource(
        path: directory.lastPathComponent,
        underlying: error
      )
    }
  }

  // MARK: - Lookups

  /// The table at a path relative to a document's directory.
  ///
  /// - Parameter path: The table's path, such as `takeoff/ground run.csv`.
  /// - Throws: ``PerformanceDataError/missingResource(path:)`` if the configuration has no such table.
  func table(_ path: String) throws -> DataTable {
    guard let table = tables[path] else {
      throw PerformanceDataError.missingResource(path: "\(directoryName)/\(path)")
    }
    return table
  }

  /// The regression equation in a file of the configuration's `regressions` directory.
  ///
  /// - Parameter filename: The equation's file name, such as `takeoff-ground-run.json`.
  /// - Throws: ``PerformanceDataError/missingResource(path:)`` if the configuration has no
  ///   such equation.
  func equation(_ filename: String) throws -> RegressionEquation {
    guard let equation = equations[filename] else {
      throw PerformanceDataError.missingResource(
        path: "\(directoryName)/\(Self.regressionsDirectoryName)/\(filename)"
      )
    }
    return equation
  }
}
