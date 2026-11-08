import Foundation

/// The digitized AFM tables and fitted regression equations for one data set.
///
/// Each data set is read from the bundle once, the first time a model asks for it, and shared by
/// every model built afterwards. Swift initializes the `static let`s that hold them lazily and
/// exactly once, so concurrent first requests need no lock.
///
/// The updated thrust schedule's data set (`g2+`) holds only the tables the schedule changes, and
/// takes the rest from the G2's.
struct AircraftData: Sendable {
  private static let dataDirectoryName = "Data",
    packageName = "sf50",
    regressionsDirectoryName = "regressions",
    tableExtension = "csv",
    equationExtension = "json"

  private static let g1 = Result { try Self(directory: "g1") }
  private static let g2 = Result { try Self(directory: "g2") }
  private static let g2Plus = Result { try Self(directory: "g2+", tableFallback: "g2") }

  /// The data set's directory name, which also prefixes its residual table names.
  let directoryName: String

  /// Tables keyed by path relative to the data set's directory, such as `takeoff/ground run.csv`.
  private let tables: [String: DataTable]

  /// Regression equations keyed by file name, such as `takeoff-ground-run.json`.
  private let equations: [String: RegressionEquation]

  /**
   * Reads a data set from the bundle.
   *
   * - Parameters:
   *   - directory: The data set's directory under `Data`.
   *   - tableFallback: A data set to take any table this one lacks from.
   * - Throws: ``PerformanceDataError`` if a file cannot be read, or if an equation names residuals
   *   the bundle does not carry.
   */
  private init(directory: String, tableFallback: String? = nil) throws {
    let root = try Self.dataDirectory()
    var tables = try Self.loadTables(in: root.appending(component: directory))
    if let tableFallback {
      let fallbackTables = try Self.loadTables(in: root.appending(component: tableFallback))
      tables.merge(fallbackTables) { own, _ in own }
    }
    let equations = try Self.loadEquations(
      in: root.appending(component: directory).appending(component: Self.regressionsDirectoryName)
    )

    try ResidualErrorCalculator.validate(
      tables: equations.values.compactMap(\.uncertaintyKey)
        + ResidualErrorCalculator.contaminationTables
    )

    directoryName = directory
    self.tables = tables
    self.equations = equations
  }

  // MARK: - Type Methods

  /// The data set for an aircraft type.
  ///
  /// - Parameter aircraftType: The aircraft whose data is wanted.
  /// - Returns: The G1, G2 or updated-thrust data set.
  /// - Throws: ``PerformanceDataError`` if the data set could not be read from the bundle.
  static func forType(_ aircraftType: AircraftType) throws -> Self {
    switch aircraftType {
      case .g1: try g1.get()
      case .g2, .g2Plus, .g3: try aircraftType.hasUpdatedThrustSchedule ? g2Plus.get() : g2.get()
    }
  }

  /// The bundled SF50 data package, holding every data set and the residuals.
  static func dataDirectory() throws -> URL {
    guard let resources = Bundle.module.resourceURL else {
      throw PerformanceDataError.missingResource(path: dataDirectoryName)
    }
    return resources.appending(component: dataDirectoryName, directoryHint: .isDirectory)
      .appending(component: packageName, directoryHint: .isDirectory)
  }

  private static func loadTables(in directory: URL) throws -> [String: DataTable] {
    try files(withExtension: tableExtension, in: directory, recursive: true).reduce(into: [:]) {
      tables,
      path in
      let url = directory.appending(path: path)
      do {
        tables[path] = try DataTable(fileURL: url)
      } catch {
        throw PerformanceDataError.unreadableResource(path: path, underlying: error)
      }
    }
  }

  private static func loadEquations(in directory: URL) throws -> [String: RegressionEquation] {
    try files(withExtension: equationExtension, in: directory, recursive: false).reduce(
      into: [:]
    ) { equations, path in
      do {
        equations[path] = try RegressionEquation(fileURL: directory.appending(path: path))
      } catch {
        throw PerformanceDataError.unreadableResource(path: path, underlying: error)
      }
    }
  }

  /// The paths, relative to `directory`, of the files there with an extension.
  private static func files(
    withExtension pathExtension: String,
    in directory: URL,
    recursive: Bool
  ) throws -> [String] {
    let directoryPath = directory.path(percentEncoded: false),
      fileManager = FileManager.default
    do {
      let paths =
        recursive
        ? try fileManager.subpathsOfDirectory(atPath: directoryPath)
        : try fileManager.contentsOfDirectory(atPath: directoryPath)
      return paths.filter { $0.hasSuffix(".\(pathExtension)") }
    } catch {
      throw PerformanceDataError.unreadableResource(
        path: directory.lastPathComponent,
        underlying: error
      )
    }
  }

  // MARK: - Lookups

  /// The table at a path relative to the data set's directory.
  ///
  /// - Parameter path: The table's path, such as `takeoff/ground run.csv`.
  /// - Throws: ``PerformanceDataError/missingResource(path:)`` if the data set has no such table.
  func table(_ path: String) throws -> DataTable {
    guard let table = tables[path] else {
      throw PerformanceDataError.missingResource(path: "\(directoryName)/\(path)")
    }
    return table
  }

  /// The regression equation in a file of the data set's `regressions` directory.
  ///
  /// - Parameter filename: The equation's file name, such as `takeoff-ground-run.json`.
  /// - Throws: ``PerformanceDataError/missingResource(path:)`` if the data set has no such
  ///   equation.
  func equation(_ filename: String) throws -> RegressionEquation {
    guard let equation = equations[filename] else {
      throw PerformanceDataError.missingResource(
        path: "\(directoryName)/\(Self.regressionsDirectoryName)/\(filename)"
      )
    }
    return equation
  }
}
