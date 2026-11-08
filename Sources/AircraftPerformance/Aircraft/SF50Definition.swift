import Foundation

/// The Cirrus SF50 Vision Jet, from its G1 and G2 AFMs and the updated thrust schedule supplement.
struct SF50Definition: AircraftDefinition {
  private static let g1AFM = "g1",
    g2AFM = "g2",
    updatedThrustScheduleSupplement = "g2+",
    flapsUpLandingDistanceFactor = 1.38,
    flapsUpIceLandingDistanceFactor = 1.52

  /// The configuration that holds the RwyCC landing distance factor tables.
  ///
  /// AC 91-79B's factors don't depend on the aircraft, so the package carries one copy, with the
  /// G1 AFM's tables.
  static let rwyCCConfiguration = ConfigurationSelection(base: g1AFM, supplements: [])

  /// The document whose contamination tables the regression contamination formulas' residuals
  /// are keyed by. The G1 and G2 AFMs print the same contamination tables.
  static let contaminationResidualDocument = g1AFM

  /// The aircraft generation and thrust schedule.
  let aircraftType: AircraftType

  var configurationSelection: ConfigurationSelection {
    switch aircraftType {
      case .g1: .init(base: Self.g1AFM, supplements: [])
      case .g2, .g2Plus, .g3:
        .init(
          base: Self.g2AFM,
          supplements: aircraftType.hasUpdatedThrustSchedule
            ? [Self.updatedThrustScheduleSupplement] : []
        )
    }
  }

  var limitations: any Limitations.Type {
    switch aircraftType {
      case .g1: LimitationsG1.self
      case .g2, .g2Plus, .g3: LimitationsG2.self
    }
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

extension AircraftType {
  /// The aircraft's definition.
  var definition: SF50Definition { .init(aircraftType: self) }
}
