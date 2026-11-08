import Foundation

/// Looks up regression equations from the bundled JSON files.
///
/// ``RegressionEquationLoader`` names the regression equation definitions each performance
/// calculation needs. Each equation is stored as a JSON file in the package bundle, organized by
/// data set and category, and read once by ``AircraftData``.
///
/// ## Data Organization
///
/// Equation files are organized in the bundle as:
///
/// ```
/// Data/sf50/
/// ├── g1/
/// │   └── regressions/
/// │       ├── takeoff-ground-run.json
/// │       ├── takeoff-total-distance.json
/// │       ├── vref-flaps50.json
/// │       └── ...
/// ├── g2/
/// │   └── regressions/
/// │       └── ...
/// └── g2+/
///     └── regressions/
///         └── ...
/// ```
///
struct RegressionEquationLoader {

  private let data: AircraftData

  /// Creates a loader reading an aircraft type's data set.
  ///
  /// - Parameter aircraftType: The aircraft whose equations are wanted.
  /// - Throws: ``PerformanceDataError`` if the data set could not be read from the bundle.
  init(aircraftType: AircraftType) throws {
    data = try AircraftData.forType(aircraftType)
  }

  /// Creates a loader reading a data set already in hand.
  init(data: AircraftData) {
    self.data = data
  }

  // MARK: - Takeoff Equations

  func loadTakeoffRunEquation() throws -> RegressionEquation {
    try loadEquation(filename: "takeoff-ground-run.json")
  }

  func loadTakeoffDistanceEquation() throws -> RegressionEquation {
    try loadEquation(filename: "takeoff-total-distance.json")
  }

  func loadTakeoffClimbGradientEquation() throws -> RegressionEquation {
    try loadEquation(filename: "takeoff-climb-gradient.json")
  }

  func loadTakeoffClimbRateEquation() throws -> RegressionEquation {
    try loadEquation(filename: "takeoff-climb-rate.json")
  }

  // MARK: - Takeoff Adjustment Factor Equations

  func loadTakeoffRunHeadwindFactorEquation() throws -> RegressionEquation {
    try loadEquation(filename: "takeoff-run-headwind-factor.json")
  }

  func loadTakeoffRunTailwindFactorEquation() throws -> RegressionEquation {
    try loadEquation(filename: "takeoff-run-tailwind-factor.json")
  }

  func loadTakeoffRunUphillFactorEquation() throws -> RegressionEquation {
    try loadEquation(filename: "takeoff-run-uphill-factor.json")
  }

  func loadTakeoffRunDownhillFactorEquation() throws -> RegressionEquation {
    try loadEquation(filename: "takeoff-run-downhill-factor.json")
  }

  func loadTakeoffDistanceHeadwindFactorEquation() throws -> RegressionEquation {
    try loadEquation(filename: "takeoff-distance-headwind-factor.json")
  }

  func loadTakeoffDistanceTailwindFactorEquation() throws -> RegressionEquation {
    try loadEquation(filename: "takeoff-distance-tailwind-factor.json")
  }

  func loadTakeoffDistanceUnpavedFactorEquation() throws -> RegressionEquation {
    try loadEquation(filename: "takeoff-distance-unpaved-factor.json")
  }

  // MARK: - Landing Equations

  func loadLandingRunEquation(flapSetting: FlapSetting) throws -> RegressionEquation {
    let filename = "landing-run-\(flapSetting.regressionFileSuffix).json"
    return try loadEquation(filename: filename)
  }

  func loadLandingDistanceEquation(flapSetting: FlapSetting) throws -> RegressionEquation {
    let filename = "landing-distance-\(flapSetting.regressionFileSuffix).json"
    return try loadEquation(filename: filename)
  }

  /// Loads the go-around climb gradient classifier for a landing configuration.
  ///
  /// Each is fit to its own configuration's landing table, where a blank cell marks a condition
  /// that cannot meet the balked landing gradient. The ice-contaminated table has no blank cells,
  /// so it has no classifier, and this returns `nil` for it.
  func loadGoAroundClimbGradientEquation(flapSetting: FlapSetting) throws -> RegressionEquation? {
    switch flapSetting {
      case .flaps100: try loadEquation(filename: "go-around-climb-gradient-flaps100.json")
      case .flaps50, .flapsUp: try loadEquation(filename: "go-around-climb-gradient-flaps50.json")
      case .flaps50Ice, .flapsUpIce: nil
    }
  }

  // MARK: - Landing Adjustment Factor Equations

  func loadLandingRunHeadwindFactorEquation(flapSetting: FlapSetting) throws -> RegressionEquation {
    let filename = "landing-run-headwind-factor-\(flapSetting.regressionFileSuffix).json"
    return try loadEquation(filename: filename)
  }

  func loadLandingRunTailwindFactorEquation(flapSetting: FlapSetting) throws -> RegressionEquation {
    let filename = "landing-run-tailwind-factor-\(flapSetting.regressionFileSuffix).json"
    return try loadEquation(filename: filename)
  }

  func loadLandingRunUphillFactorEquation(flapSetting: FlapSetting) throws -> RegressionEquation {
    let filename = "landing-run-uphill-factor-\(flapSetting.regressionFileSuffix).json"
    return try loadEquation(filename: filename)
  }

  func loadLandingRunDownhillFactorEquation() throws -> RegressionEquation {
    try loadEquation(filename: "landing-run-downhill-factor.json")
  }

  func loadLandingDistanceHeadwindFactorEquation(
    flapSetting: FlapSetting
  ) throws -> RegressionEquation {
    let filename = "landing-distance-headwind-factor-\(flapSetting.regressionFileSuffix).json"
    return try loadEquation(filename: filename)
  }

  func loadLandingDistanceTailwindFactorEquation(
    flapSetting: FlapSetting
  ) throws -> RegressionEquation {
    let filename = "landing-distance-tailwind-factor-\(flapSetting.regressionFileSuffix).json"
    return try loadEquation(filename: filename)
  }

  func loadLandingDistanceUnpavedFactorEquation() throws -> RegressionEquation {
    try loadEquation(filename: "landing-distance-unpaved-factor.json")
  }

  // MARK: - Vref Equations

  func loadVrefEquation(flapSetting: FlapSetting) throws -> RegressionEquation {
    let filename = "vref-\(flapSetting.regressionFileSuffix).json"
    return try loadEquation(filename: filename)
  }

  // MARK: - En Route Climb Equations

  func loadEnrouteClimbGradientEquation(iceContaminated: Bool) throws -> RegressionEquation {
    let suffix = iceContaminated ? "ice" : "normal"
    return try loadEquation(filename: "enroute-climb-gradient-\(suffix).json")
  }

  func loadEnrouteClimbRateEquation(iceContaminated: Bool) throws -> RegressionEquation {
    let suffix = iceContaminated ? "ice" : "normal"
    return try loadEquation(filename: "enroute-climb-rate-\(suffix).json")
  }

  func loadEnrouteClimbSpeedEquation(iceContaminated: Bool) throws -> RegressionEquation {
    let suffix = iceContaminated ? "ice" : "normal"
    return try loadEquation(filename: "enroute-climb-speed-\(suffix).json")
  }

  // MARK: - En Route Obstacle Climb Equations

  func loadEnrouteObstacleClimbGradientEquation(iceContaminated: Bool) throws -> RegressionEquation
  {
    let suffix = iceContaminated ? "ice" : "normal"
    return try loadEquation(filename: "enroute-obstacle-climb-gradient-\(suffix).json")
  }

  // MARK: - Private Helpers

  private func loadEquation(filename: String) throws -> RegressionEquation {
    try data.equation(filename)
  }
}

// MARK: - FlapSetting Extension

extension FlapSetting {
  /// The file suffix used for regression equation JSON files.
  var regressionFileSuffix: String {
    switch self {
      case .flapsUp: "flapsup"
      case .flapsUpIce: "flapsupice"
      case .flaps50: "flaps50"
      case .flaps50Ice: "flaps50ice"
      case .flaps100: "flaps100"
    }
  }
}
