import Foundation

/// The Cirrus SF50 Vision Jet, from its G1 and G2 AFMs and the updated thrust schedule supplement.
struct SF50Definition: AircraftDefinition {
  private static let g1AFM = "g1",
    g2AFM = "g2",
    updatedThrustScheduleSupplement = "g2+",
    flapsUpLandingDistanceFactor = 1.38,
    flapsUpIceLandingDistanceFactor = 1.52

  /// The G1 AFM's limitations (31452-001 Section 2).
  static let g1Limitations = limitations(maxEnrouteAltitudeFt: 28_000)

  /// The G2 AFM's limitations (31452-002 Section 2), which the G2+ and G3 share.
  static let g2Limitations = limitations(maxEnrouteAltitudeFt: 31_000)

  /// The aircraft generation and thrust schedule.
  let variant: SF50Variant

  let capabilities: Set<PerformanceCapability> = [
    .vref, .goAroundClimbGradient, .contamination, .iceProtection, .enrouteObstacleClimb
  ]

  let takeoffFlapSettings: [FlapSetting] = [.flaps50]

  let landingFlapSettings = FlapSetting.allCases

  var configurationSelection: ConfigurationSelection {
    switch variant {
      case .g1: .init(base: Self.g1AFM, supplements: [])
      case .g2, .g2Plus, .g3:
        .init(
          base: Self.g2AFM,
          supplements: variant.hasUpdatedThrustSchedule
            ? [Self.updatedThrustScheduleSupplement] : []
        )
    }
  }

  var limitations: AircraftLimitations {
    switch variant {
      case .g1: Self.g1Limitations
      case .g2, .g2Plus, .g3: Self.g2Limitations
    }
  }

  /// The limitations both AFMs share, with the ceiling that differs between them.
  private static func limitations(maxEnrouteAltitudeFt: Double) -> AircraftLimitations {
    let flaps50Crosswind = Measurement(value: 18, unit: UnitSpeed.knots)
    return .init(
      maxTakeoffWeight: .init(value: 6000, unit: .pounds),
      maxLandingWeight: .init(value: 5550, unit: .pounds),
      maxZeroFuelWeight: .init(value: 4900, unit: .pounds),
      maxEnrouteAltitude: .init(value: maxEnrouteAltitudeFt, unit: .feet),
      maxAirportElevation: .init(value: 10_000, unit: .feet),
      minAirportElevation: .init(value: -1000, unit: .feet),
      maxTailwind: .init(value: 10, unit: .knots),
      demonstratedCrosswind: [
        .flapsUp: flaps50Crosswind,
        .flapsUpIce: flaps50Crosswind,
        .flaps50: flaps50Crosswind,
        .flaps50Ice: flaps50Crosswind,
        .flaps100: .init(value: 16, unit: .knots)
      ],
      maxFuel: .init(value: 296, unit: .gallons),
      minTemperature: .init(value: -40, unit: .celsius),
      maxTemperature: .init(value: 50, unit: .celsius)
    )
  }

  func package() throws -> DataPackage { try DataPackage.sf50.get() }

  /// The AFM gives a Flaps UP landing only as a factor on the Flaps 50% total distance (or the
  /// Flaps 50% ice one), and publishes no Flaps UP ground run.
  func landingTables(for flapSetting: FlapSetting) -> LandingTables {
    switch flapSetting {
      case .flapsUp:
        .init(flapSetting: .flaps50, totalDistanceFactor: Self.flapsUpLandingDistanceFactor)
      case .flapsUpIce:
        .init(flapSetting: .flaps50Ice, totalDistanceFactor: Self.flapsUpIceLandingDistanceFactor)
      case .flaps50, .flaps50Ice, .flaps100:
        .init(flapSetting: flapSetting, totalDistanceFactor: nil)
    }
  }
}
