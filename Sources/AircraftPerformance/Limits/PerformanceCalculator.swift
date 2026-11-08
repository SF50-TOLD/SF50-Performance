public import Foundation

/// Calculates takeoff and landing performance with a fixed set of engine settings.
///
/// Every call is synchronous and the calculator holds no mutable state, so it can be used from a
/// main-actor view model or shared across a server's concurrent requests alike.
///
/// ```swift
/// let calculator = PerformanceCalculator(settings: .init(aircraft: .sf50(.g2Plus)))
/// let report = try calculator.takeoff(
///   conditions: conditions,
///   weight: .init(value: 5800, unit: .pounds),
///   runway: runway
/// )
/// ```
public struct PerformanceCalculator: Sendable {
  /// The flap setting the AFM publishes takeoff data for.
  public static let takeoffFlapSetting = FlapSetting.flaps50

  /// The engine settings every calculation reads.
  public let settings: PerformanceSettings

  private var service: DefaultPerformanceCalculationService { .shared }

  /**
   * Creates a calculator.
   *
   * - Parameter settings: The engine settings every calculation reads.
   */
  public init(settings: PerformanceSettings) {
    self.settings = settings
  }

  /**
   * Builds the performance model the settings select.
   *
   * - Parameters:
   *   - conditions: The atmospheric conditions.
   *   - configuration: The aircraft's weight and flap setting.
   *   - runway: The runway, with any NOTAM restricting it.
   * - Returns: The model, ready to be queried.
   * - Throws: ``PerformanceDataError`` if the bundled performance data could not be read.
   */
  public func model(
    conditions: Conditions,
    configuration: Configuration,
    runway: RunwayInput
  ) throws -> any PerformanceModel {
    try service.createPerformanceModel(
      conditions: conditions,
      configuration: configuration,
      runway: runway,
      notam: runway.notam,
      kind: settings.modelKind,
      aircraft: settings.aircraft
    )
  }

  /**
   * Calculates a takeoff at flaps 50%.
   *
   * - Parameters:
   *   - conditions: The atmospheric conditions.
   *   - weight: The takeoff weight.
   *   - runway: The runway, with any NOTAM restricting it.
   *   - safetyFactor: The multiplier for the distances, or `nil` for the settings' dry factor.
   * - Returns: The takeoff report.
   * - Throws: ``PerformanceDataError`` if the bundled performance data could not be read.
   */
  public func takeoff(
    conditions: Conditions,
    weight: Measurement<UnitMass>,
    runway: RunwayInput,
    safetyFactor: Double? = nil
  ) throws -> TakeoffReport {
    let model = try model(
      conditions: conditions,
      configuration: .init(weight: weight, flapSetting: Self.takeoffFlapSetting),
      runway: runway
    )
    return try service.calculateTakeoff(
      for: model,
      safetyFactor: safetyFactor ?? settings.safetyFactorDry
    )
  }

  /**
   * Calculates a landing.
   *
   * - Parameters:
   *   - conditions: The atmospheric conditions.
   *   - configuration: The landing weight and flap setting.
   *   - runway: The runway, with any NOTAM restricting it.
   *   - safetyFactor: The multiplier for the distances, or `nil` for the one the settings give
   *     the runway's condition.
   * - Returns: The landing report, with the settings' VREF additive applied.
   * - Throws: ``PerformanceDataError`` if the bundled performance data could not be read.
   */
  public func landing(
    conditions: Conditions,
    configuration: Configuration,
    runway: RunwayInput,
    safetyFactor: Double? = nil
  ) throws -> LandingReport {
    let model = try model(conditions: conditions, configuration: configuration, runway: runway)
    return try service.calculateLanding(
      for: model,
      safetyFactor: safetyFactor
        ?? settings.landingSafetyFactor(for: runway.notam?.contamination),
      VREFAdditiveKts: settings.VREFAdditiveKts
    )
  }
}
