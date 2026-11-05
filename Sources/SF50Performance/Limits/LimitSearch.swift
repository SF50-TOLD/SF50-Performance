public import Foundation

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
}

/// The highest value of a quantity a takeoff or landing allows, and what stops it going higher.
public struct LimitSearchResult<UnitType: Dimension & Sendable>: Sendable {
  /// The highest value that satisfies every constraint, or `nil` where not even the lowest value
  /// searched does.
  public let limit: Measurement<UnitType>?

  /// The constraint the next value up violates, or the ceiling of the search where every value
  /// satisfies the rest.
  public let bindingConstraint: BindingConstraint
}

// MARK: - Searches

extension PerformanceCalculator {
  /// The weight step the weight searches move in.
  public static let weightSearchIncrement = Measurement(value: 50, unit: UnitMass.pounds)

  /// The temperature step the temperature searches move in, in degrees Celsius.
  private static let temperatureSearchIncrementC = 1.0

  /**
   * The highest takeoff weight the runway, the AFM and an obstacle allow.
   *
   * Weights are searched in 50 lb steps from `minimumWeight` up to the structural maximum takeoff
   * weight.
   *
   * - Parameters:
   *   - conditions: The atmospheric conditions.
   *   - runway: The runway, with any NOTAM restricting it.
   *   - obstacle: An obstacle the takeoff climb must clear, or `nil` for none.
   *   - minimumWeight: The lowest weight to search, such as the aircraft's empty weight.
   *   - safetyFactor: The multiplier for the distances, or `nil` for the settings' dry factor.
   * - Returns: The maximum weight and the constraint that sets it.
   * - Throws: ``PerformanceDataError`` if the bundled performance data could not be read.
   */
  public func maxTakeoffWeight(
    conditions: Conditions,
    runway: RunwayInput,
    obstacle: Obstacle?,
    minimumWeight: Measurement<UnitMass>,
    safetyFactor: Double? = nil
  ) throws -> LimitSearchResult<UnitMass> {
    try searchWeight(
      from: minimumWeight,
      to: settings.limitations.maxTakeoffWeight
    ) { weight in
      takeoffVerdict(
        try takeoff(
          conditions: conditions,
          weight: weight,
          runway: runway,
          safetyFactor: safetyFactor
        ),
        runway: runway,
        obstacle: obstacle
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
      to: settings.limitations.maxLandingWeight
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
   *   - obstacle: An obstacle the takeoff climb must clear, or `nil` for none.
   *   - safetyFactor: The multiplier for the distances, or `nil` for the settings' dry factor.
   * - Returns: The maximum temperature and the constraint that sets it.
   * - Throws: ``PerformanceDataError`` if the bundled performance data could not be read.
   */
  public func maxTakeoffTemperature(
    conditions: Conditions,
    weight: Measurement<UnitMass>,
    runway: RunwayInput,
    obstacle: Obstacle?,
    safetyFactor: Double? = nil
  ) throws -> LimitSearchResult<UnitTemperature> {
    try searchTemperature { temperature in
      takeoffVerdict(
        try takeoff(
          conditions: conditions.replacingTemperature(with: temperature),
          weight: weight,
          runway: runway,
          safetyFactor: safetyFactor
        ),
        runway: runway,
        obstacle: obstacle
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
    try searchTemperature { temperature in
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

  /// Whether a takeoff fits the runway, has AFM figures, and clears any obstacle.
  ///
  /// A clamped distance still answers, since it is the AFM's own figure for milder conditions and
  /// errs long; a refusal carrying no figure leaves the takeoff untestable. A distance with no
  /// definite figure is no verdict on the runway, so only a definite one can exceed it.
  private func takeoffVerdict(
    _ report: TakeoffReport,
    runway: RunwayInput,
    obstacle: Obstacle?
  ) -> LimitVerdict {
    let results = report.results
    guard let takeoffDistance = results.takeoffDistance.nominalOrClamped else {
      return .violated(.AFMData)
    }
    guard
      fits(results.takeoffRun, within: runway.availableTakeoffRun)
        && fits(results.takeoffDistance, within: runway.availableTakeoffDistance)
    else { return .violated(.fieldLength) }

    guard let obstacle else { return .satisfied }
    let requirement = obstacle.climbRequirement(
      takeoffDistance: takeoffDistance,
      availableTakeoffRun: runway.availableTakeoffRun
    )
    switch requirement {
      case .none: return .satisfied
      case .unclearable: return .violated(.obstacleClearance)
      case .gradient:
        guard let climbGradient = results.takeoffClimbGradient.nominalOrClamped else {
          return .violated(.AFMData)
        }
        return requirement.isMet(by: climbGradient) ? .satisfied : .violated(.obstacleClearance)
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
    return meetsGoAround ? .satisfied : .violated(.goAroundClimbGradient)
  }

  private func fits(
    _ distance: Value<Measurement<UnitLength>>,
    within available: Measurement<UnitLength>
  ) -> Bool {
    guard let distance = distance.nominal else { return true }
    return distance <= available
  }

  // MARK: - Bisection

  private func searchWeight(
    from minimumWeight: Measurement<UnitMass>,
    to maximumWeight: Measurement<UnitMass>,
    verdict: (Measurement<UnitMass>) throws -> LimitVerdict
  ) throws -> LimitSearchResult<UnitMass> {
    let search = try LimitBisection.highestSatisfying(
      from: minimumWeight.converted(to: .pounds).value,
      to: maximumWeight.converted(to: .pounds).value,
      increment: Self.weightSearchIncrement.converted(to: .pounds).value
    ) { try verdict(.init(value: $0, unit: .pounds)) }
    return .init(
      limit: search.highest.map { .init(value: $0, unit: .pounds) },
      bindingConstraint: search.violation ?? .structuralLimit
    )
  }

  private func searchTemperature(
    verdict: (Measurement<UnitTemperature>) throws -> LimitVerdict
  ) throws -> LimitSearchResult<UnitTemperature> {
    let limitations = settings.limitations,
      search = try LimitBisection.highestSatisfying(
        from: limitations.minTemperature.converted(to: .celsius).value,
        to: limitations.maxTemperature.converted(to: .celsius).value,
        increment: Self.temperatureSearchIncrementC
      ) { try verdict(.init(value: $0, unit: .celsius)) }
    return .init(
      limit: search.highest.map { .init(value: $0, unit: .celsius) },
      bindingConstraint: search.violation ?? .temperatureLimit
    )
  }
}

/// Whether a candidate limit satisfies every constraint, or which one it violates.
enum LimitVerdict: Equatable {
  case satisfied
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
   * - Returns: The highest satisfying candidate, or `nil` if none satisfies; and the constraint
   *   the candidate one step above it violates, or `nil` if every candidate satisfies.
   */
  static func highestSatisfying(
    from lowest: Double,
    to highest: Double,
    increment: Double,
    verdict: (Double) throws -> LimitVerdict
  ) rethrows -> (highest: Double?, violation: BindingConstraint?) {
    var low = (lowest / increment).rounded(.up) * increment,
      high = (highest / increment).rounded(.down) * increment,
      best: Double?,
      violation: BindingConstraint?

    while low <= high {
      let candidate = ((low + high) / 2 / increment).rounded() * increment
      switch try verdict(candidate) {
        case .satisfied:
          best = candidate
          low = candidate + increment
        case .violated(let constraint):
          violation = constraint
          high = candidate - increment
      }
    }

    return (best, violation)
  }
}
