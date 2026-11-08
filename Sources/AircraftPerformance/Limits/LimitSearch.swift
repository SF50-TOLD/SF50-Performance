public import Foundation
import MeasurementKit

/// What stops a takeoff or landing limit from going any higher.
public enum BindingConstraint: String, Sendable, Hashable, CaseIterable, Codable {
  /// A distance exceeds what the runway declares available.
  case fieldLength = "field_length"

  /// The AFM data gives no figure: the conditions lie past the edge of its tables, or the tables
  /// carry no value there.
  case AFMData = "afm_data"

  /// The takeoff climb gradient falls short of what an obstacle off the departure end requires.
  case obstacleClearance = "obstacle_clearance"

  /// The aircraft cannot meet the AFM's go-around climb gradient.
  case goAroundClimbGradient = "go_around_climb_gradient"

  /// The structural maximum takeoff or landing weight.
  case structuralLimit = "structural_limit"

  /// The AFM's maximum operating temperature.
  case temperatureLimit = "temperature_limit"

  /// The tailwind component exceeds the AFM's limit.
  case windLimit = "wind_limit"

  /// The airport elevation lies outside the range the AFM approves.
  case elevationLimit = "elevation_limit"
}

/// The highest value of a quantity a takeoff or landing allows, and what stops it going higher.
public struct LimitSearchResult<UnitType: Dimension & Sendable>: Sendable {
  /// The highest value that satisfies every constraint, or `nil` where not even the lowest value
  /// searched does.
  public let limit: Measurement<UnitType>?

  /// The constraint the next value up violates, or the ceiling of the search where every value
  /// satisfies the rest.
  public let bindingConstraint: BindingConstraint

  /// Whether the limit rests on a figure the AFM tables do not cover: the calculation at the limit
  /// held an input at the edge of its data, so the limit is not fully supported by the AFM.
  public let reliesOnOffscaleData: Bool
}

// MARK: - Searches

extension PerformanceCalculator {
  /// The weight step the weight searches move in.
  public static let weightSearchIncrement = Measurement(value: 50, unit: UnitMass.pounds)

  /// The temperature step the temperature searches move in, in degrees Celsius.
  private static let temperatureSearchIncrementC = 1.0

  /// What stops a temperature search that reaches the top of its range: the manual's maximum
  /// operating temperature, or where it sets none, the edge of its tables.
  private var temperatureCeilingConstraint: BindingConstraint {
    settings.limitations.maxTemperature == nil ? .AFMData : .temperatureLimit
  }

  /**
   * The highest takeoff weight the runway, the AFM and an obstacle allow.
   *
   * Weights are searched in 50 lb steps from `minimumWeight` up to the structural maximum takeoff
   * weight.
   *
   * - Parameters:
   *   - conditions: The atmospheric conditions.
   *   - runway: The runway, with any NOTAM restricting it.
   *   - obstacle: An obstacle the takeoff climb must clear, or `nil` for the one the runway's
   *     NOTAM reports, if any.
   *   - minimumWeight: The lowest weight to search, such as the aircraft's empty weight.
   *   - safetyFactor: The multiplier for the distances, or `nil` for the settings' dry factor.
   * - Returns: The maximum weight and the constraint that sets it.
   * - Throws: ``PerformanceDataError`` if the bundled performance data could not be read.
   */
  public func maxTakeoffWeight(
    conditions: Conditions,
    runway: RunwayInput,
    obstacle: Obstacle? = nil,
    minimumWeight: Measurement<UnitMass>,
    safetyFactor: Double? = nil
  ) throws -> LimitSearchResult<UnitMass> {
    try searchWeight(
      from: minimumWeight,
      to: settings.limitations.maxTakeoffWeight,
      violating: operatingLimitViolation(
        for: .takeoff,
        conditions: conditions,
        runway: runway
      )
    ) { weight in
      takeoffVerdict(
        try takeoff(
          conditions: conditions,
          weight: weight,
          runway: runway,
          safetyFactor: safetyFactor
        ),
        runway: runway,
        obstacle: obstacle ?? runway.notam?.obstacle
      )
    }
  }

  /**
   * The highest landing weight the runway and the AFM allow.
   *
   * Weights are searched in 50 lb steps from `minimumWeight` up to the structural maximum landing
   * weight.
   *
   * - Parameters:
   *   - conditions: The atmospheric conditions.
   *   - runway: The runway, with any NOTAM restricting it.
   *   - flapSetting: The landing flap setting.
   *   - minimumWeight: The lowest weight to search, such as the aircraft's empty weight.
   *   - safetyFactor: The multiplier for the distances, or `nil` for the one the settings give
   *     the runway's condition.
   * - Returns: The maximum weight and the constraint that sets it.
   * - Throws: ``PerformanceDataError`` if the bundled performance data could not be read.
   */
  public func maxLandingWeight(
    conditions: Conditions,
    runway: RunwayInput,
    flapSetting: FlapSetting,
    minimumWeight: Measurement<UnitMass>,
    safetyFactor: Double? = nil
  ) throws -> LimitSearchResult<UnitMass> {
    try searchWeight(
      from: minimumWeight,
      to: settings.limitations.maxLandingWeight,
      violating: operatingLimitViolation(
        for: .landing,
        conditions: conditions,
        runway: runway
      )
    ) { weight in
      landingVerdict(
        try landing(
          conditions: conditions,
          configuration: .init(weight: weight, flapSetting: flapSetting),
          runway: runway,
          safetyFactor: safetyFactor
        ),
        runway: runway
      )
    }
  }

  /**
   * The highest outside air temperature at which a takeoff at a fixed weight is possible.
   *
   * Temperatures are searched in whole degrees Celsius across the AFM's operating range. Every
   * other condition — wind, altimeter setting — is held as given.
   *
   * - Parameters:
   *   - conditions: The atmospheric conditions, whose temperature is varied.
   *   - weight: The takeoff weight.
   *   - runway: The runway, with any NOTAM restricting it.
   *   - obstacle: An obstacle the takeoff climb must clear, or `nil` for the one the runway's
   *     NOTAM reports, if any.
   *   - safetyFactor: The multiplier for the distances, or `nil` for the settings' dry factor.
   * - Returns: The maximum temperature and the constraint that sets it.
   * - Throws: ``PerformanceDataError`` if the bundled performance data could not be read.
   */
  public func maxTakeoffTemperature(
    conditions: Conditions,
    weight: Measurement<UnitMass>,
    runway: RunwayInput,
    obstacle: Obstacle? = nil,
    safetyFactor: Double? = nil
  ) throws -> LimitSearchResult<UnitTemperature> {
    try searchTemperature(
      violating: operatingLimitViolation(
        for: .takeoff,
        conditions: conditions,
        runway: runway,
        checkingTemperature: false
      )
    ) { temperature in
      takeoffVerdict(
        try takeoff(
          conditions: conditions.replacingTemperature(with: temperature),
          weight: weight,
          runway: runway,
          safetyFactor: safetyFactor
        ),
        runway: runway,
        obstacle: obstacle ?? runway.notam?.obstacle
      )
    }
  }

  /**
   * The highest outside air temperature at which a landing in a fixed configuration is possible.
   *
   * Temperatures are searched in whole degrees Celsius across the AFM's operating range. Every
   * other condition — wind, altimeter setting — is held as given.
   *
   * - Parameters:
   *   - conditions: The atmospheric conditions, whose temperature is varied.
   *   - configuration: The landing weight and flap setting.
   *   - runway: The runway, with any NOTAM restricting it.
   *   - safetyFactor: The multiplier for the distances, or `nil` for the one the settings give
   *     the runway's condition.
   * - Returns: The maximum temperature and the constraint that sets it.
   * - Throws: ``PerformanceDataError`` if the bundled performance data could not be read.
   */
  public func maxLandingTemperature(
    conditions: Conditions,
    configuration: Configuration,
    runway: RunwayInput,
    safetyFactor: Double? = nil
  ) throws -> LimitSearchResult<UnitTemperature> {
    try searchTemperature(
      violating: operatingLimitViolation(
        for: .landing,
        conditions: conditions,
        runway: runway,
        checkingTemperature: false
      )
    ) { temperature in
      landingVerdict(
        try landing(
          conditions: conditions.replacingTemperature(with: temperature),
          configuration: configuration,
          runway: runway,
          safetyFactor: safetyFactor
        ),
        runway: runway
      )
    }
  }

  // MARK: - Verdicts

  /// The AFM operating limit the conditions and runway already breach, whatever the weight or
  /// temperature searched, or `nil` where they breach none.
  ///
  /// The AFM's crosswind figure is a demonstrated value, which the AFM does not consider limiting,
  /// so it stays a note. The temperature searches stay within the AFM's temperature range by
  /// construction, so they skip that check. The elevation limits bound only the tables, so the
  /// regression model, which may extrapolate past them, skips that check.
  private func operatingLimitViolation(
    for operation: Operation,
    conditions: Conditions,
    runway: RunwayInput,
    checkingTemperature: Bool = true
  ) -> BindingConstraint? {
    let limitations = settings.limitations
    let headwind = runway.headwind(conditions: conditions)
    if headwind < .zero && headwind.magnitude > limitations.maxTailwind {
      return .windLimit
    }
    if settings.modelKind == .tabular,
      !limitations.isApproved(elevation: runway.elevation, for: operation)
    {
      return .elevationLimit
    }
    if checkingTemperature, let temperature = conditions.temperature,
      !limitations.isApproved(temperature: temperature)
    {
      return .temperatureLimit
    }
    return nil
  }

  /// Whether a takeoff fits the runway, has AFM figures, and clears any obstacle.
  ///
  /// A clamped distance is the AFM's figure for the nearest conditions it covers, and the
  /// takeoff has to fit that figure: where the real distance may be shorter the AFM still cannot
  /// show the takeoff fits, so a clamped distance that does not fit is a violation. A refusal
  /// carrying no figure leaves the takeoff untestable.
  private func takeoffVerdict(
    _ report: TakeoffReport,
    runway: RunwayInput,
    obstacle: Obstacle?
  ) -> LimitVerdict {
    let results = report.results
    guard let takeoffRun = results.takeoffRun.nominalOrClamped,
      let takeoffDistance = results.takeoffDistance.nominalOrClamped
    else { return .violated(.AFMData) }
    guard
      takeoffRun <= runway.availableTakeoffRun
        && takeoffDistance <= runway.availableTakeoffDistance
    else { return .violated(.fieldLength) }

    let satisfied = LimitVerdict.satisfied(reliesOnOffscaleData: reliesOnOffscaleData(report))
    guard let obstacle else { return satisfied }
    let requirement = obstacle.climbRequirement(
      takeoffDistance: takeoffDistance,
      availableTakeoffRun: runway.availableTakeoffRun
    )
    switch requirement {
      case .none: return satisfied
      case .unclearable: return .violated(.obstacleClearance)
      case .gradient:
        guard let climbGradient = results.takeoffClimbGradient.nominalOrClamped else {
          return .violated(.AFMData)
        }
        return requirement.isMet(by: climbGradient) ? satisfied : .violated(.obstacleClearance)
    }
  }

  /// Whether a landing fits the runway, has AFM figures, and meets the go-around gradient.
  private func landingVerdict(_ report: LandingReport, runway: RunwayInput) -> LimitVerdict {
    let results = report.results
    guard let distance = results.landingDistance.nominalOrClamped else {
      return .violated(.AFMData)
    }
    guard distance <= runway.availableLandingDistance else { return .violated(.fieldLength) }
    guard let meetsGoAround = results.meetsGoAroundClimbGradient.nominalOrClamped else {
      return .violated(.AFMData)
    }
    return meetsGoAround
      ? .satisfied(reliesOnOffscaleData: reliesOnOffscaleData(report))
      : .violated(.goAroundClimbGradient)
  }

  private func reliesOnOffscaleData(_ report: TakeoffReport) -> Bool {
    report.isOffscaleLow || report.isOffscaleHigh
  }

  private func reliesOnOffscaleData(_ report: LandingReport) -> Bool {
    report.isOffscaleLow || report.isOffscaleHigh
  }

  // MARK: - Bisection

  private func searchWeight(
    from minimumWeight: Measurement<UnitMass>,
    to maximumWeight: Measurement<UnitMass>,
    violating operatingLimit: BindingConstraint?,
    verdict: (Measurement<UnitMass>) throws -> LimitVerdict
  ) throws -> LimitSearchResult<UnitMass> {
    if let operatingLimit {
      return .init(limit: nil, bindingConstraint: operatingLimit, reliesOnOffscaleData: false)
    }
    let search = try LimitBisection.highestSatisfying(
      from: minimumWeight.converted(to: .pounds).value,
      to: maximumWeight.converted(to: .pounds).value,
      increment: Self.weightSearchIncrement.converted(to: .pounds).value
    ) { try verdict(.init(value: $0, unit: .pounds)) }
    return .init(
      limit: search.highest.map { .init(value: $0, unit: .pounds) },
      bindingConstraint: search.violation ?? .structuralLimit,
      reliesOnOffscaleData: search.reliesOnOffscaleData
    )
  }

  /// The temperatures, in degrees Celsius, the temperature searches cover: the operating limits,
  /// and where the manual sets none, the range its takeoff tables cover.
  private func temperatureSearchRange() throws -> ClosedRange<Double> {
    let limitations = settings.limitations
    if let minimum = limitations.minTemperature, let maximum = limitations.maxTemperature {
      return minimum.converted(to: .celsius).value...maximum.converted(to: .celsius).value
    }
    let tabulated =
      try DataTableLoader(data: settings.aircraft.definition.data()).loadTakeoffRunData()
      .domain(of: .temperature) ?? 0...0
    let lowest = limitations.minTemperature?.converted(to: .celsius).value ?? tabulated.lowerBound,
      highest = limitations.maxTemperature?.converted(to: .celsius).value ?? tabulated.upperBound
    return lowest...highest
  }

  private func searchTemperature(
    violating operatingLimit: BindingConstraint?,
    verdict: (Measurement<UnitTemperature>) throws -> LimitVerdict
  ) throws -> LimitSearchResult<UnitTemperature> {
    if let operatingLimit {
      return .init(limit: nil, bindingConstraint: operatingLimit, reliesOnOffscaleData: false)
    }
    let range = try temperatureSearchRange(),
      search = try LimitBisection.highestSatisfying(
        from: range.lowerBound,
        to: range.upperBound,
        increment: Self.temperatureSearchIncrementC
      ) { try verdict(.init(value: $0, unit: .celsius)) }
    return .init(
      limit: search.highest.map { .init(value: $0, unit: .celsius) },
      bindingConstraint: search.violation ?? temperatureCeilingConstraint,
      reliesOnOffscaleData: search.reliesOnOffscaleData
    )
  }
}

/// Whether a candidate limit satisfies every constraint, or which one it violates.
enum LimitVerdict: Equatable {
  /// Every constraint holds; `reliesOnOffscaleData` is whether the figures behind that include any
  /// the AFM data does not cover.
  case satisfied(reliesOnOffscaleData: Bool)
  case violated(BindingConstraint)
}

/// A bisection over the multiples of an increment within a range.
///
/// Performance only worsens as weight or temperature rises, so the values that satisfy every
/// constraint are those up to some limit, and bisection finds it.
enum LimitBisection {
  /**
   * Finds the highest multiple of `increment` in a range that satisfies every constraint.
   *
   * - Parameters:
   *   - lowest: The bottom of the range, rounded up to a multiple of `increment`.
   *   - highest: The top of the range, rounded down to a multiple of `increment`.
   *   - increment: The step between candidates.
   *   - verdict: Tests one candidate.
   * - Returns: The highest satisfying candidate, or `nil` if none satisfies; whether that
   *   candidate relies on off-scale data; and the constraint the candidate one step above it
   *   violates, or `nil` if every candidate satisfies.
   */
  static func highestSatisfying(
    from lowest: Double,
    to highest: Double,
    increment: Double,
    verdict: (Double) throws -> LimitVerdict
  ) rethrows -> (highest: Double?, reliesOnOffscaleData: Bool, violation: BindingConstraint?) {
    var low = (lowest / increment).rounded(.up) * increment,
      high = (highest / increment).rounded(.down) * increment,
      best: Double?,
      bestReliesOnOffscaleData = false,
      violation: BindingConstraint?

    while low <= high {
      let candidate = ((low + high) / 2 / increment).rounded() * increment
      switch try verdict(candidate) {
        case .satisfied(let reliesOnOffscaleData):
          best = candidate
          bestReliesOnOffscaleData = reliesOnOffscaleData
          low = candidate + increment
        case .violated(let constraint):
          violation = constraint
          high = candidate - increment
      }
    }

    return (best, bestReliesOnOffscaleData, violation)
  }
}
