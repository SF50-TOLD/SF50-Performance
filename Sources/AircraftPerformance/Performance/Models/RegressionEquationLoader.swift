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
  /// - Parameter aircraft: The aircraft whose equations are wanted.
  /// - Throws: ``PerformanceDataError`` if the data set could not be read from the bundle.
  init(aircraft: Aircraft) throws {
    data = try aircraft.definition.data()
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

  // MARK: - Vref Equations

  func loadVrefEquation(flapSetting: FlapSetting) throws -> RegressionEquation {
    let filename = "vref-\(flapSetting.regressionFileSuffix).json"
    return try loadEquation(filename: filename)
  }

  // MARK: - En Route Climb Equations

  func loadEnrouteClimbGradientEquation(names: EnrouteClimbNames) throws -> RegressionEquation {
    try loadEquation(filename: "enroute-climb-gradient\(names.equationSuffix).json")
  }

  func loadEnrouteClimbRateEquation(names: EnrouteClimbNames) throws -> RegressionEquation {
    try loadEquation(filename: "enroute-climb-rate\(names.equationSuffix).json")
  }

  func loadEnrouteClimbSpeedEquation(names: EnrouteClimbNames) throws -> RegressionEquation {
    try loadEquation(filename: "enroute-climb-speed\(names.equationSuffix).json")
  }

  func loadEnrouteObstacleClimbGradientEquation(names: EnrouteClimbNames) throws
    -> RegressionEquation
  {
    try loadEquation(filename: "enroute-obstacle-climb-gradient\(names.equationSuffix).json")
  }

  // MARK: - Climb Equations

  func loadTakeoffClimbSpeedEquation() throws -> RegressionEquation {
    try loadEquation(filename: "takeoff-climb-speed.json")
  }

  func loadBalkedLandingClimbGradientEquation() throws -> RegressionEquation {
    try loadEquation(filename: "balked-landing-climb-gradient.json")
  }

  func loadBalkedLandingClimbRateEquation() throws -> RegressionEquation {
    try loadEquation(filename: "balked-landing-climb-rate.json")
  }

  // MARK: - Correction Factor Equations

  /// The equation for a correction's factor on a distance, or `nil` if the data has none.
  ///
  /// - Parameters:
  ///   - factor: The correction.
  ///   - target: The distance it corrects.
  ///   - landingFlapSetting: The flap setting whose landing equations are read.
  func correctionFactorEquation(
    _ factor: CorrectionFactor,
    for target: DistanceTarget,
    landingFlapSetting: FlapSetting
  ) -> RegressionEquation? {
    factor.equationFilenames(for: target, flapSuffix: landingFlapSetting.regressionFileSuffix)
      .lazy.compactMap { data.equationIfPresent($0) }.first
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
