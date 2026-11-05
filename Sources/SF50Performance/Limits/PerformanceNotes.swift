public import Foundation
import MeasurementKit

/// The inputs a calculation's notes are checked against.
public struct PerformanceNoteInputs: Sendable {
  /// The engine settings the calculation used.
  public let settings: PerformanceSettings

  /// The aircraft's weight and flap setting.
  public let configuration: Configuration

  /// The runway, with any NOTAM restricting it.
  public let runway: RunwayInput

  /// The conditions the calculation used.
  public let conditions: Conditions

  /// The zero-fuel weight, or `nil` where it is not known.
  public let zeroFuelWeight: Measurement<UnitMass>?

  /// The fuel aboard, or `nil` where it is not known.
  public let fuel: Measurement<UnitVolume>?

  /// An obstacle off the departure end the takeoff climb must clear, or `nil` for none.
  public let obstacle: Obstacle?

  /**
   * Gathers the inputs a calculation's notes are checked against.
   *
   * - Parameters:
   *   - settings: The engine settings the calculation used.
   *   - configuration: The aircraft's weight and flap setting.
   *   - runway: The runway, with any NOTAM restricting it.
   *   - conditions: The conditions the calculation used.
   *   - zeroFuelWeight: The zero-fuel weight, if known.
   *   - fuel: The fuel aboard, if known.
   *   - obstacle: An obstacle the takeoff climb must clear, or `nil` for the one the runway's
   *     NOTAM reports, if any.
   */
  public init(
    settings: PerformanceSettings,
    configuration: Configuration,
    runway: RunwayInput,
    conditions: Conditions,
    zeroFuelWeight: Measurement<UnitMass>? = nil,
    fuel: Measurement<UnitVolume>? = nil,
    obstacle: Obstacle? = nil
  ) {
    self.settings = settings
    self.configuration = configuration
    self.runway = runway
    self.conditions = conditions
    self.zeroFuelWeight = zeroFuelWeight
    self.fuel = fuel
    self.obstacle = obstacle ?? runway.notam?.obstacle
  }
}

/// Checks a calculation's inputs and results against the AFM's limitations and the runway.
///
/// Every readout of a takeoff or landing — an app screen, a printed report, a server response —
/// calls these, so they all warn about the same things.
public enum PerformanceNotes {

  /**
   * The notes for a takeoff.
   *
   * - Parameters:
   *   - report: The calculated takeoff.
   *   - inputs: What the takeoff was calculated from.
   * - Returns: Offscale warnings, then limitation notes, then distance and climb gradient notes.
   */
  public static func takeoffNotes(
    for report: TakeoffReport,
    inputs: PerformanceNoteInputs
  ) -> [PerformanceNote] {
    offscaleNotes(low: report.isOffscaleLow, high: report.isOffscaleHigh)
      + inputNotes(for: .takeoff, inputs: inputs)
      + takeoffDistanceNotes(for: report.results, runway: inputs.runway)
      + climbGradientNotes(for: report.results, runway: inputs.runway, obstacle: inputs.obstacle)
  }

  /**
   * The notes for a landing.
   *
   * - Parameters:
   *   - report: The calculated landing.
   *   - inputs: What the landing was calculated from.
   * - Returns: Offscale warnings, then limitation notes, then distance and go-around notes.
   */
  public static func landingNotes(
    for report: LandingReport,
    inputs: PerformanceNoteInputs
  ) -> [PerformanceNote] {
    offscaleNotes(low: report.isOffscaleLow, high: report.isOffscaleHigh)
      + inputNotes(for: .landing, inputs: inputs)
      + landingDistanceNotes(for: report.results, runway: inputs.runway)
      + goAroundNotes(for: report.results)
  }

  /**
   * The notes that depend only on a calculation's inputs.
   *
   * These check wind, airport elevation, temperature, weight and fuel against the AFM's
   * limitations, and add the notes that qualify a contaminated landing, a VREF additive, or a
   * calculation made without an altimeter setting.
   *
   * - Parameters:
   *   - operation: The leg being calculated.
   *   - inputs: What it was calculated from.
   * - Returns: Wind, then elevation and temperature, then weight notes, then qualifying notes.
   */
  public static func inputNotes(
    for operation: Operation,
    inputs: PerformanceNoteInputs
  ) -> [PerformanceNote] {
    let limitations = inputs.settings.limitations
    return windNotes(inputs: inputs, limitations: limitations)
      + environmentNotes(inputs: inputs, limitations: limitations)
      + weightNotes(for: operation, inputs: inputs, limitations: limitations)
      + qualifyingNotes(for: operation, inputs: inputs)
  }

  // MARK: - Results

  private static func offscaleNotes(low: Bool, high: Bool) -> [PerformanceNote] {
    (high ? [.offscaleHigh] : []) + (low ? [.offscaleLow] : [])
  }

  private static func takeoffDistanceNotes(
    for results: TakeoffResults,
    runway: RunwayInput
  ) -> [PerformanceNote] {
    var notes: [PerformanceNote] = []
    if let run = results.takeoffRun.nominal, run > runway.availableTakeoffRun {
      notes.append(
        .takeoffRunExceedsAvailable(required: run, available: runway.availableTakeoffRun)
      )
    }
    if let distance = results.takeoffDistance.nominal, distance > runway.availableTakeoffDistance {
      notes.append(
        .takeoffDistanceExceedsAvailable(
          required: distance,
          available: runway.availableTakeoffDistance
        )
      )
    }
    return notes
  }

  /// Whether the takeoff climb clears an obstacle off the departure end.
  ///
  /// A takeoff distance the model has no figure for leaves the requirement unknown; the distance's
  /// own refusal is what the readout shows.
  private static func climbGradientNotes(
    for results: TakeoffResults,
    runway: RunwayInput,
    obstacle: Obstacle?
  ) -> [PerformanceNote] {
    guard let obstacle, let takeoffDistance = results.takeoffDistance.nominalOrClamped else {
      return []
    }
    let requirement = obstacle.climbRequirement(
      takeoffDistance: takeoffDistance,
      availableTakeoffRun: runway.availableTakeoffRun
    )
    switch requirement {
      case .none:
        return []
      case .unclearable:
        return [.obstacleWithinTakeoffDistance(obstacle: obstacle)]
      case .gradient(let required):
        guard !requirement.isMet(by: results.takeoffClimbGradient.nominalOrClamped) else {
          return []
        }
        return [
          .insufficientClimbGradient(
            required: required.converted(to: .feetPerNauticalMile),
            actual: results.takeoffClimbGradient
          )
        ]
    }
  }

  private static func landingDistanceNotes(
    for results: LandingResults,
    runway: RunwayInput
  ) -> [PerformanceNote] {
    guard let distance = results.landingDistance.nominal,
      distance > runway.availableLandingDistance
    else { return [] }
    return [
      .landingDistanceExceedsAvailable(
        required: distance,
        available: runway.availableLandingDistance
      )
    ]
  }

  private static func goAroundNotes(for results: LandingResults) -> [PerformanceNote] {
    guard let meets = results.meetsGoAroundClimbGradient.nominalOrClamped, !meets else {
      return []
    }
    return [.doesNotMeetGoAroundGradient]
  }

  // MARK: - Inputs

  /// Crosswind and tailwind against their limits. An unreported wind resolves to calm, which
  /// exceeds neither.
  private static func windNotes(
    inputs: PerformanceNoteInputs,
    limitations: any Limitations.Type
  ) -> [PerformanceNote] {
    var notes: [PerformanceNote] = []
    let
      crosswindLimit =
        inputs.configuration.flapSetting == .flaps100
        ? limitations.maxCrosswind_flaps100 : limitations.maxCrosswind_flaps50,
      crosswind = inputs.runway.crosswind(conditions: inputs.conditions).magnitude
    if crosswind > crosswindLimit {
      notes.append(.crosswindExceedance(crosswind: crosswind, limit: crosswindLimit))
    }

    let headwind = inputs.runway.headwind(conditions: inputs.conditions)
    if headwind < .zero, headwind.magnitude > limitations.maxTailwind {
      notes.append(
        .tailwindExceedance(tailwind: headwind.magnitude, limit: limitations.maxTailwind)
      )
    }
    return notes
  }

  /// Airport elevation and temperature against the AFM's limits.
  ///
  /// The elevation limits bound only the tables; the regression model may extrapolate past them.
  private static func environmentNotes(
    inputs: PerformanceNoteInputs,
    limitations: any Limitations.Type
  ) -> [PerformanceNote] {
    var notes: [PerformanceNote] = []
    let elevation = inputs.runway.elevation,
      approvedElevations = limitations.minAirportElevation...limitations.maxAirportElevation
    if inputs.settings.modelKind == .tabular, !approvedElevations.contains(elevation) {
      notes.append(.airportElevationOutsideLimits(elevation: elevation, limits: approvedElevations))
    }

    let approvedTemperatures = limitations.minTemperature...limitations.maxTemperature
    if let temperature = inputs.conditions.temperature,
      !approvedTemperatures.contains(temperature)
    {
      notes.append(
        .temperatureOutsideLimits(temperature: temperature, limits: approvedTemperatures)
      )
    }
    return notes
  }

  private static func weightNotes(
    for operation: Operation,
    inputs: PerformanceNoteInputs,
    limitations: any Limitations.Type
  ) -> [PerformanceNote] {
    var notes: [PerformanceNote] = []
    let weight = inputs.configuration.weight,
      maxWeight =
        operation == .takeoff ? limitations.maxTakeoffWeight : limitations.maxLandingWeight
    if weight > maxWeight {
      notes.append(.weightAboveMax(weight: weight, limit: maxWeight))
    }
    if let zeroFuelWeight = inputs.zeroFuelWeight, zeroFuelWeight > limitations.maxZeroFuelWeight {
      notes.append(
        .zeroFuelWeightExceeded(weight: zeroFuelWeight, limit: limitations.maxZeroFuelWeight)
      )
    }
    if let fuel = inputs.fuel, fuel > limitations.maxFuel {
      notes.append(.fuelExceedsCapacity(fuel: fuel, limit: limitations.maxFuel))
    }
    return notes
  }

  /// The notes that qualify how a figure was reached rather than warn about it.
  private static func qualifyingNotes(
    for operation: Operation,
    inputs: PerformanceNoteInputs
  ) -> [PerformanceNote] {
    var notes: [PerformanceNote] = []
    if operation == .landing, let contamination = inputs.runway.notam?.contamination {
      if case .rwyCC = contamination, inputs.settings.hasSafetyFactor {
        notes.append(.rwyCCSafetyFactorNotApplied)
      }
      if contamination != .wetRunway { notes.append(.contaminationSupplemental) }
    }
    if operation == .landing, inputs.settings.VREFAdditiveKts > 0 {
      notes.append(.VREFAdditiveApproximate)
    }
    if inputs.conditions.seaLevelPressure == nil {
      notes.append(.pressureAltitudeFromFieldElevation)
    }
    return notes
  }
}
