public import Foundation

/// An aircraft's certified operating limitations, as its flight manual states them.
public struct AircraftLimitations: Sendable, Hashable {
  /// Maximum certified takeoff weight.
  public let maxTakeoffWeight: Measurement<UnitMass>

  /// Maximum certified landing weight.
  public let maxLandingWeight: Measurement<UnitMass>

  /// Maximum zero fuel weight, or `nil` if the manual sets none.
  public let maxZeroFuelWeight: Measurement<UnitMass>?

  /// Maximum pressure altitude for enroute flight.
  public let maxEnrouteAltitude: Measurement<UnitLength>

  /// Highest airport elevation approved for takeoff and landing, or `nil` if the manual sets none.
  public let maxAirportElevation: Measurement<UnitLength>?

  /// Lowest airport elevation approved for takeoff and landing, or `nil` if the manual sets none.
  ///
  /// Performance below sea level is read from the sea-level figures.
  public let minAirportElevation: Measurement<UnitLength>?

  /// Highest airport elevation approved for takeoff, where it is lower than
  /// ``maxAirportElevation`` or the manual sets it for takeoff alone, or `nil` if neither.
  public let maxTakeoffElevation: Measurement<UnitLength>?

  /// Maximum tailwind component for takeoff and landing.
  public let maxTailwind: Measurement<UnitSpeed>

  /// The demonstrated crosswind component for each flap setting the manual gives one for, which
  /// it does not consider limiting.
  public let demonstratedCrosswind: [FlapSetting: Measurement<UnitSpeed>]

  /// Maximum usable fuel capacity.
  public let maxFuel: Measurement<UnitVolume>

  /// Minimum operating temperature, or `nil` if the manual sets none.
  public let minTemperature: Measurement<UnitTemperature>?

  /// Maximum operating temperature, or `nil` if the manual sets none.
  public let maxTemperature: Measurement<UnitTemperature>?

  /// Creates a set of limitations.
  ///
  /// - Parameters:
  ///   - maxTakeoffWeight: Maximum certified takeoff weight.
  ///   - maxLandingWeight: Maximum certified landing weight.
  ///   - maxZeroFuelWeight: Maximum zero fuel weight, or `nil` if the manual sets none.
  ///   - maxEnrouteAltitude: Maximum pressure altitude for enroute flight.
  ///   - maxAirportElevation: Highest airport elevation approved for takeoff and landing, if any.
  ///   - minAirportElevation: Lowest airport elevation approved for takeoff and landing, if any.
  ///   - maxTakeoffElevation: A highest elevation for takeoff alone, if the manual sets one.
  ///   - maxTailwind: Maximum tailwind component for takeoff and landing.
  ///   - demonstratedCrosswind: The demonstrated crosswind component by flap setting.
  ///   - maxFuel: Maximum usable fuel capacity.
  ///   - minTemperature: Minimum operating temperature, if any.
  ///   - maxTemperature: Maximum operating temperature, if any.
  public init(
    maxTakeoffWeight: Measurement<UnitMass>,
    maxLandingWeight: Measurement<UnitMass>,
    maxZeroFuelWeight: Measurement<UnitMass>?,
    maxEnrouteAltitude: Measurement<UnitLength>,
    maxAirportElevation: Measurement<UnitLength>?,
    minAirportElevation: Measurement<UnitLength>?,
    maxTakeoffElevation: Measurement<UnitLength>? = nil,
    maxTailwind: Measurement<UnitSpeed>,
    demonstratedCrosswind: [FlapSetting: Measurement<UnitSpeed>],
    maxFuel: Measurement<UnitVolume>,
    minTemperature: Measurement<UnitTemperature>?,
    maxTemperature: Measurement<UnitTemperature>?
  ) {
    self.maxTakeoffWeight = maxTakeoffWeight
    self.maxLandingWeight = maxLandingWeight
    self.maxZeroFuelWeight = maxZeroFuelWeight
    self.maxEnrouteAltitude = maxEnrouteAltitude
    self.maxAirportElevation = maxAirportElevation
    self.minAirportElevation = minAirportElevation
    self.maxTakeoffElevation = maxTakeoffElevation
    self.maxTailwind = maxTailwind
    self.demonstratedCrosswind = demonstratedCrosswind
    self.maxFuel = maxFuel
    self.minTemperature = minTemperature
    self.maxTemperature = maxTemperature
  }

  /// The demonstrated crosswind component for a flap setting, or `nil` if the manual gives none.
  public func maxCrosswind(for flapSetting: FlapSetting) -> Measurement<UnitSpeed>? {
    demonstratedCrosswind[flapSetting]
  }

  /// The highest airport elevation approved for takeoff or landing, or `nil` if there is none.
  public func maxElevation(for operation: Operation) -> Measurement<UnitLength>? {
    guard operation == .takeoff, let maxTakeoffElevation else { return maxAirportElevation }
    return maxAirportElevation.map { Swift.min($0, maxTakeoffElevation) } ?? maxTakeoffElevation
  }

  /// Whether an airport's elevation is approved for takeoff or landing.
  func isApproved(elevation: Measurement<UnitLength>, for operation: Operation) -> Bool {
    elevation >= (minAirportElevation ?? elevation)
      && elevation <= (maxElevation(for: operation) ?? elevation)
  }

  /// Whether a temperature is within the operating limits.
  func isApproved(temperature: Measurement<UnitTemperature>) -> Bool {
    temperature >= (minTemperature ?? temperature) && temperature <= (maxTemperature ?? temperature)
  }
}
