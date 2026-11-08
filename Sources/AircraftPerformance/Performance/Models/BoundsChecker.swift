import Foundation

/// Status of inputs relative to AFM table bounds.
///
/// Used by ``BoundsChecker`` to indicate whether performance calculation inputs
/// fall within, below, or above the valid data range.
enum BoundsStatus: Sendable {
  /// All inputs are within the valid AFM table range.
  case withinBounds
  /// One or more inputs are below the minimum table value.
  case belowMinimum
  /// One or more inputs are above the maximum table value.
  case aboveMaximum
}

/// Validates performance calculation inputs against AFM data table bounds.
///
/// ``BoundsChecker`` is used by regression models to validate that inputs (weight,
/// altitude, temperature) fall within the ranges covered by the original AFM tables.
/// While regression models can extrapolate beyond these bounds, results outside the
/// valid range may be less reliable.
///
/// ## Usage
///
/// ```swift
/// let aircraft = Aircraft.sf50(.g1)
/// let checker = try BoundsChecker(data: aircraft.definition.data(), definition: aircraft.definition)
///
/// let status = checker.takeoffBoundsStatus(
///     weight: 5800,
///     altitude: 5000,
///     temperature: 30
/// )
///
/// if status == .aboveMaximum {
///     // Warn user that inputs exceed AFM data range
/// }
/// ```
struct BoundsChecker: Sendable {

  private let takeoffRunData: DataTable
  private let takeoffClimbGradientData: DataTable

  /// The landing ground run table each landing flap setting is read from.
  private let landingRunData: [FlapSetting: DataTable]

  /// The en route climb tables of each schedule the manual has, keyed by whether it is the
  /// ice-contaminated one.
  private let enrouteClimbData: [Bool: [EnrouteClimbQuantity: DataTable]]

  /// The en route obstacle climb gradient tables, keyed as ``enrouteClimbData`` is.
  private let obstacleClimbGradientData: [Bool: DataTable]

  init(data: AircraftData, definition: any AircraftDefinition) throws {
    let loader = DataTableLoader(data: data)
    takeoffRunData = try loader.loadTakeoffRunData()
    takeoffClimbGradientData = try loader.loadTakeoffClimbGradientData()

    landingRunData = try definition.landingFlapSettings.reduce(into: [:]) { tables, flapSetting in
      let tableFlapSetting = definition.landingTables(for: flapSetting).flapSetting
      tables[flapSetting] = try loader.loadLandingRunData(
        landingPrefix: loader.tablePrefix(for: tableFlapSetting)
      )
    }

    // Each en route climb quantity is bounded by its own table: under the SF50's
    // ice-contaminated schedule the rate is tabulated 2,000 ft higher and 2 °C colder than the
    // gradient, and bounding one by the other would refuse a figure the AFM does give.
    let schedules = [false, true].compactMap { iceContaminated in
      definition.enrouteClimbNames(iceContaminated: iceContaminated).map { (iceContaminated, $0) }
    }
    enrouteClimbData = try schedules.reduce(into: [:]) { tables, schedule in
      tables[schedule.0] = [
        .gradient: try loader.loadEnrouteClimbGradientData(names: schedule.1),
        .rate: try loader.loadEnrouteClimbRateData(names: schedule.1),
        .speed: try loader.loadEnrouteClimbSpeedData(names: schedule.1)
      ]
    }
    obstacleClimbGradientData = try schedules.reduce(into: [:]) { tables, schedule in
      tables[schedule.0] = try loader.loadEnrouteObstacleClimbGradientData(names: schedule.1)
    }
  }

  /// Returns the bounds status for takeoff parameters.
  /// - Parameters:
  ///   - weight: Aircraft weight in lbs
  ///   - altitude: Pressure altitude in feet
  ///   - temperature: Temperature in Celsius
  /// - Returns: The bounds status (within, below, or above limits)
  func takeoffBoundsStatus(
    weight: Double,
    altitude: Double,
    temperature: Double
  ) -> BoundsStatus {
    checkBoundsStatus(
      weight: weight,
      altitude: altitude,
      temperature: temperature,
      dataTable: takeoffRunData
    )
  }

  /// Returns the bounds status for landing parameters.
  /// - Parameters:
  ///   - weight: Aircraft weight in lbs
  ///   - altitude: Pressure altitude in feet
  ///   - temperature: Temperature in Celsius
  ///   - flapSetting: The flap configuration to check bounds for
  /// - Returns: The bounds status (within, below, or above limits)
  func landingBoundsStatus(
    weight: Double,
    altitude: Double,
    temperature: Double,
    flapSetting: FlapSetting
  ) -> BoundsStatus {
    guard let dataTable = landingRunData[flapSetting] else { return .withinBounds }
    return checkBoundsStatus(
      weight: weight,
      altitude: altitude,
      temperature: temperature,
      dataTable: dataTable
    )
  }

  /// Returns the bounds status for en route climb parameters.
  ///
  /// The regression's en route climb equations are fitted to these tables and turn nonsensical
  /// outside them — at temperatures a climb can be planned in, the fitted gradient goes
  /// negative — so callers use this to refuse rather than to warn.
  ///
  /// - Parameters:
  ///   - quantity: Which en route climb figure is being asked for
  ///   - weight: Aircraft weight in lbs
  ///   - altitude: Pressure altitude in feet
  ///   - temperature: Temperature in Celsius
  ///   - iceContaminated: Whether the ice-contaminated schedule applies
  /// - Returns: The bounds status (within, below, or above limits)
  func enrouteClimbBoundsStatus(
    for quantity: EnrouteClimbQuantity,
    weight: Double,
    altitude: Double,
    temperature: Double,
    iceContaminated: Bool
  ) -> BoundsStatus {
    guard let dataTable = enrouteClimbData[iceContaminated]?[quantity] else {
      return .withinBounds
    }

    return checkBoundsStatus(
      weight: weight,
      altitude: altitude,
      temperature: temperature,
      dataTable: dataTable
    )
  }

  /// Returns the bounds status for takeoff climb parameters.
  ///
  /// The takeoff climb tables stop at 10,000 ft. A climb profile asks for the takeoff gradient
  /// wherever the takeoff segment reaches, and past the tables the fitted gradient grows without
  /// bound, so callers use this to refuse rather than to warn.
  func takeoffClimbBoundsStatus(
    weight: Double,
    altitude: Double,
    temperature: Double
  ) -> BoundsStatus {
    checkBoundsStatus(
      weight: weight,
      altitude: altitude,
      temperature: temperature,
      dataTable: takeoffClimbGradientData
    )
  }

  /// Returns the bounds status for en route obstacle climb parameters.
  ///
  /// Past the obstacle climb tables the fitted gradient turns and climbs again with altitude, so
  /// callers use this to refuse rather than to warn.
  func obstacleClimbBoundsStatus(
    weight: Double,
    altitude: Double,
    temperature: Double,
    iceContaminated: Bool
  ) -> BoundsStatus {
    guard let dataTable = obstacleClimbGradientData[iceContaminated] else { return .withinBounds }
    return checkBoundsStatus(
      weight: weight,
      altitude: altitude,
      temperature: temperature,
      dataTable: dataTable
    )
  }

  // MARK: - Private Helpers

  /// Whether inputs lie within a table's range, checking weight, then altitude, then temperature.
  private func checkBoundsStatus(
    weight: Double,
    altitude: Double,
    temperature: Double,
    dataTable: DataTable
  ) -> BoundsStatus {
    let inputs: [(TableInput, Double)] = [
      (.weight, weight), (.altitude, altitude), (.temperature, temperature)
    ]
    for (input, value) in inputs {
      guard let range = dataTable.domain(of: input) else { continue }
      if value < range.lowerBound { return .belowMinimum }
      if value > range.upperBound { return .aboveMaximum }
    }
    return .withinBounds
  }

  /// An en route climb figure, each tabulated over its own envelope.
  enum EnrouteClimbQuantity: Sendable {
    case gradient
    case rate
    case speed
  }
}
