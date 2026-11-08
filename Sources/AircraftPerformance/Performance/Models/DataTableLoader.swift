import Foundation

/// Looks up performance data tables from the bundled CSV files.
///
/// ``DataTableLoader`` names the digitized AFM chart data each performance calculation needs.
/// Each data table is stored as a CSV file in the package bundle, organized by data set (G1, G2,
/// or the updated thrust schedule's G2+) and performance category, and read once by
/// ``AircraftData``.
///
/// ## Data Organization
///
/// Performance data is organized in the bundle as:
///
/// ```
/// Data/sf50/
/// ├── g1/
/// │   ├── takeoff/
/// │   │   ├── ground run.csv
/// │   │   ├── total distance.csv
/// │   │   └── ... adjustment factors
/// │   ├── landing/
/// │   │   ├── 100/ (flaps 100)
/// │   │   ├── 50/ (flaps 50)
/// │   │   └── contamination/
/// │   └── enroute climb/
/// └── g2+/
///     └── ... (similar structure)
/// ```
///
struct DataTableLoader {

  private let data: AircraftData

  /// Creates a loader reading an aircraft type's data set.
  ///
  /// - Parameter aircraft: The aircraft whose tables are wanted.
  /// - Throws: ``PerformanceDataError`` if the data set could not be read from the bundle.
  init(aircraft: Aircraft) throws {
    data = try aircraft.definition.data()
  }

  /// Creates a loader reading a data set already in hand.
  init(data: AircraftData) {
    self.data = data
  }

  // MARK: - Main Performance Data Tables

  func loadTakeoffRunData() throws -> DataTable {
    try loadDataTable(path: "takeoff/ground run.csv")
  }

  func loadTakeoffDistanceData() throws -> DataTable {
    try loadDataTable(path: "takeoff/total distance.csv")
  }

  func loadLandingRunData(landingPrefix: String) throws -> DataTable {
    try loadDataTable(path: "landing/\(landingPrefix)/ground run.csv")
  }

  func loadLandingDistanceData(landingPrefix: String) throws -> DataTable {
    try loadDataTable(path: "landing/\(landingPrefix)/total distance.csv")
  }

  func loadVrefData(vrefPrefix: String) throws -> DataTable {
    try loadDataTable(path: "vref/\(vrefPrefix).csv")
  }

  func loadTakeoffClimbGradientData() throws -> DataTable {
    try loadDataTable(path: "takeoff climb/gradient.csv")
  }

  func loadTakeoffClimbRateData() throws -> DataTable {
    try loadDataTable(path: "takeoff climb/rate.csv")
  }

  // MARK: - Enroute Climb Data Tables

  func loadEnrouteClimbGradientData(names: EnrouteClimbNames) throws -> DataTable {
    try loadDataTable(path: "\(names.tableDirectory)/gradient.csv")
  }

  func loadEnrouteClimbRateData(names: EnrouteClimbNames) throws -> DataTable {
    try loadDataTable(path: "\(names.tableDirectory)/rate.csv")
  }

  func loadEnrouteClimbSpeedData(names: EnrouteClimbNames) throws -> DataTable {
    try loadDataTable(path: "\(names.tableDirectory)/speed.csv")
  }

  /// The en route obstacle climb gradient table, or `nil` for a schedule without one.
  func loadEnrouteObstacleClimbGradientData(names: EnrouteClimbNames) throws -> DataTable? {
    try names.obstacleTableDirectory.map { try loadDataTable(path: "\($0)/gradient.csv") }
  }

  // MARK: - Climb Data Tables

  func loadTakeoffClimbSpeedData() throws -> DataTable {
    try loadDataTable(path: "takeoff climb/speed.csv")
  }

  func loadBalkedLandingClimbGradientData() throws -> DataTable {
    try loadDataTable(path: "balked landing/gradient.csv")
  }

  func loadBalkedLandingClimbRateData() throws -> DataTable {
    try loadDataTable(path: "balked landing/rate.csv")
  }

  // MARK: - Correction Factor Data Tables

  /// The table of a correction's factor on a distance, or `nil` if the data has none.
  ///
  /// - Parameters:
  ///   - factor: The correction.
  ///   - target: The distance it corrects.
  ///   - landingFlapSetting: The flap setting whose landing tables are read.
  func correctionFactorTable(
    _ factor: CorrectionFactor,
    for target: DistanceTarget,
    landingFlapSetting: FlapSetting
  ) -> DataTable? {
    data.tableIfPresent(
      factor.tablePath(for: target, landingTablePrefix: tablePrefix(for: landingFlapSetting))
    )
  }

  // MARK: - Prefix Helpers

  /// The name the tables give a flap setting, as a VREF table's file name or a landing table
  /// directory.
  func tablePrefix(for flapSetting: FlapSetting) -> String {
    switch flapSetting {
      case .flapsUp: "up"
      case .flapsUpIce: "up ice"
      case .flaps50: "50"
      case .flaps50Ice: "50 ice"
      case .flaps100: "100"
    }
  }

  // MARK: - Helper Functions

  private func loadDataTable(path: String) throws -> DataTable {
    try data.table(path)
  }
}
