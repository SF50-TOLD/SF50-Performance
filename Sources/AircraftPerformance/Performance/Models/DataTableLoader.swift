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

  func loadEnrouteClimbGradientData(iceContaminated: Bool) throws -> DataTable {
    let subdir = iceContaminated ? "ice contaminated" : "normal"
    return try loadDataTable(path: "enroute climb/\(subdir)/gradient.csv")
  }

  func loadEnrouteClimbRateData(iceContaminated: Bool) throws -> DataTable {
    let subdir = iceContaminated ? "ice contaminated" : "normal"
    return try loadDataTable(path: "enroute climb/\(subdir)/rate.csv")
  }

  func loadEnrouteClimbSpeedData(iceContaminated: Bool) throws -> DataTable {
    let subdir = iceContaminated ? "ice contaminated" : "normal"
    return try loadDataTable(path: "enroute climb/\(subdir)/speed.csv")
  }

  // MARK: - Enroute Obstacle Climb Data Tables

  func loadEnrouteObstacleClimbGradientData(iceContaminated: Bool) throws -> DataTable {
    let subdir = iceContaminated ? "ice" : "normal"
    return try loadDataTable(path: "enroute obstacle climb/\(subdir)/gradient.csv")
  }

  // MARK: - Adjustment Factor Data Tables

  func loadTakeoffRunHeadwindData() throws -> DataTable {
    try loadDataTable(path: "takeoff/ground run - headwind factor.csv")
  }

  func loadTakeoffRunTailwindData() throws -> DataTable {
    try loadDataTable(path: "takeoff/ground run - tailwind factor.csv")
  }

  func loadTakeoffRunDownhillData() throws -> DataTable {
    try loadDataTable(path: "takeoff/ground run - downhill factor.csv")
  }

  func loadTakeoffRunUphillData() throws -> DataTable {
    try loadDataTable(path: "takeoff/ground run - uphill factor.csv")
  }

  func loadTakeoffDistanceHeadwindData() throws -> DataTable {
    try loadDataTable(path: "takeoff/total distance - headwind factor.csv")
  }

  func loadTakeoffDistanceTailwindData() throws -> DataTable {
    try loadDataTable(path: "takeoff/total distance - tailwind factor.csv")
  }

  func loadTakeoffDistanceUnpavedData() throws -> DataTable {
    try loadDataTable(path: "takeoff/total distance - unpaved factor.csv")
  }

  func loadLandingRunHeadwindData(landingPrefix: String) throws -> DataTable {
    try loadDataTable(path: "landing/\(landingPrefix)/ground run - headwind factor.csv")
  }

  func loadLandingRunTailwindData(landingPrefix: String) throws -> DataTable {
    try loadDataTable(path: "landing/\(landingPrefix)/ground run - tailwind factor.csv")
  }

  func loadLandingRunDownhillData(landingPrefix: String) throws -> DataTable {
    try loadDataTable(path: "landing/\(landingPrefix)/ground run - downhill factor.csv")
  }

  func loadLandingRunUphillData(landingPrefix: String) throws -> DataTable {
    try loadDataTable(path: "landing/\(landingPrefix)/ground run - uphill factor.csv")
  }

  func loadLandingDistanceHeadwindData(landingPrefix: String) throws -> DataTable {
    try loadDataTable(path: "landing/\(landingPrefix)/total distance - headwind factor.csv")
  }

  func loadLandingDistanceTailwindData(landingPrefix: String) throws -> DataTable {
    try loadDataTable(path: "landing/\(landingPrefix)/total distance - tailwind factor.csv")
  }

  func loadLandingDistanceUnpavedData(landingPrefix: String) throws -> DataTable {
    try loadDataTable(path: "landing/\(landingPrefix)/total distance - unpaved factor.csv")
  }

  // MARK: - Contamination Data Tables

  func loadCompactSnowLandingData() throws -> DataTable {
    try loadDataTable(path: "landing/contamination/compact snow.csv")
  }

  func loadDrySnowLandingData() throws -> DataTable {
    try loadDataTable(path: "landing/contamination/dry snow.csv")
  }

  func loadSlushLandingData() throws -> DataTable {
    try loadDataTable(path: "landing/contamination/slush, wet snow.csv")
  }

  func loadWaterLandingData() throws -> DataTable {
    try loadDataTable(path: "landing/contamination/water.csv")
  }

  // Alias methods for contamination data
  func loadContaminationCompactSnowData() throws -> DataTable {
    try loadCompactSnowLandingData()
  }

  func loadContaminationDrySnowData() throws -> DataTable {
    try loadDrySnowLandingData()
  }

  func loadContaminationSlushData() throws -> DataTable {
    try loadSlushLandingData()
  }

  func loadContaminationWaterData() throws -> DataTable {
    try loadWaterLandingData()
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
