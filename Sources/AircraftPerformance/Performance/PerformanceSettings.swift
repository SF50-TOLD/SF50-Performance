public import Foundation

/// Which performance model answers a calculation.
public enum PerformanceModelKind: String, Sendable, Hashable, CaseIterable, Codable {
  /// Interpolates the digitized AFM tables, and reports N/A wherever they give no figure.
  case tabular

  /// Evaluates regression equations fitted to the AFM tables, which extrapolate past them and
  /// carry an uncertainty.
  case regression
}

/// The engine settings a pilot chooses, which every calculation reads.
///
/// None of these are read from storage here: an app passes in whatever its pilot set, and a server
/// whatever its caller asked for.
public struct PerformanceSettings: Sendable, Hashable {
  /// The aircraft and its installed options.
  public var aircraft: Aircraft

  /// Which performance model answers.
  public var modelKind: PerformanceModelKind

  /// The multiplier applied to takeoff distances, and to landing distances on a dry or wet runway.
  public var safetyFactorDry: Double

  /// The multiplier applied to landing distances on a contaminated runway.
  public var safetyFactorContaminated: Double

  /// The speed added to VREF on approach.
  public var VREFAdditive: Measurement<UnitSpeed>

  /// The aircraft's operating limitations.
  public var limitations: AircraftLimitations { aircraft.limitations }

  /// ``VREFAdditive`` in knots.
  public var VREFAdditiveKts: Double { VREFAdditive.converted(to: .knots).value }

  /// Whether a safety factor other than 1 is configured for any runway condition.
  var hasSafetyFactor: Bool { safetyFactorDry != 1.0 || safetyFactorContaminated != 1.0 }

  /**
   * Creates engine settings.
   *
   * - Parameters:
   *   - aircraft: The aircraft and its installed options.
   *   - modelKind: Which performance model answers.
   *   - safetyFactorDry: The multiplier for takeoff distances and dry or wet landing distances.
   *   - safetyFactorContaminated: The multiplier for contaminated landing distances.
   *   - VREFAdditive: The speed added to VREF on approach.
   */
  public init(
    aircraft: Aircraft,
    modelKind: PerformanceModelKind = .tabular,
    safetyFactorDry: Double = 1,
    safetyFactorContaminated: Double = 1,
    VREFAdditive: Measurement<UnitSpeed> = .init(value: 0, unit: .knots)
  ) {
    self.aircraft = aircraft
    self.modelKind = modelKind
    self.safetyFactorDry = safetyFactorDry
    self.safetyFactorContaminated = safetyFactorContaminated
    self.VREFAdditive = VREFAdditive
  }

  /**
   * The safety factor for a landing on a runway in the given condition.
   *
   * RwyCC landing distances already carry the AC 91-79B factors, so no further factor applies.
   * A wet runway takes the dry factor, since the AFM's wet increase is already in the distance.
   *
   * - Parameter contamination: The runway's condition, or `nil` for a dry runway.
   * - Returns: The multiplier to apply to the landing distances.
   */
  public func landingSafetyFactor(for contamination: Contamination?) -> Double {
    switch contamination {
      case .rwyCC: 1.0
      case .wetRunway, nil: safetyFactorDry
      case .some: safetyFactorContaminated
    }
  }
}
