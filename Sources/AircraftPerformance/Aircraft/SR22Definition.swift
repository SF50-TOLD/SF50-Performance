import Foundation

/// A pre-G3-wing Cirrus SR22, from POH 13772-001 Reissue A Revision A10 and the supplements for
/// the Hartzell composite propeller (13772-129) and Tornado Alley turbonormalizing (Report 215-6).
struct SR22Definition: AircraftDefinition {
  private static let baseManual = "poh",
    hartzellSupplement = "hartzell",
    tornadoAlleySupplement = "tornado-alley"

  /// The options installed on the aircraft.
  let options: SR22Options

  var configurationSelection: ConfigurationSelection {
    .init(
      base: Self.baseManual,
      supplements: Set(
        [
          options.hartzellPropeller ? Self.hartzellSupplement : nil,
          options.turbonormalized ? Self.tornadoAlleySupplement : nil
        ].compactMap(\.self)
      )
    )
  }

  /// POH Section 2, with Report 215-6's higher ceiling and cold-weather limit when
  /// turbonormalized.
  ///
  /// The POH sets one maximum weight, which applies to landing too, and no operating temperature
  /// range: below −23 °C it requires cowl inlet covers instead. Its tailwind corrections stop at
  /// 10 knots.
  var limitations: AircraftLimitations {
    let demonstratedCrosswind = Measurement(value: 20, unit: UnitSpeed.knots)
    return .init(
      maxTakeoffWeight: .init(value: 3400, unit: .pounds),
      maxLandingWeight: .init(value: 3400, unit: .pounds),
      maxZeroFuelWeight: nil,
      maxEnrouteAltitude: .init(value: options.turbonormalized ? 25_000 : 17_500, unit: .feet),
      maxAirportElevation: nil,
      minAirportElevation: nil,
      maxTakeoffElevation: .init(value: 10_000, unit: .feet),
      maxTailwind: .init(value: 10, unit: .knots),
      demonstratedCrosswind: [.flaps50: demonstratedCrosswind, .flaps100: demonstratedCrosswind],
      maxFuel: .init(value: 81, unit: .gallons),
      minTemperature: options.turbonormalized ? .init(value: -40, unit: .celsius) : nil,
      maxTemperature: nil
    )
  }

  var capabilities: Set<PerformanceCapability> {
    var capabilities: Set<PerformanceCapability> = [
      .balkedLandingClimb, .timeFuelDistanceToClimb, .airConditionerCorrection,
      .wetUnpavedCorrection
    ]
    if options.turbonormalized { capabilities.insert(.leanOfPeakClimb) }
    return capabilities
  }

  let takeoffFlapSettings: [FlapSetting] = [.flaps50]

  let landingFlapSettings: [FlapSetting] = [.flaps100]

  let correctionScheme = CorrectionScheme.groundRollReferenced

  let takeoffClimbSpeedKIAS: Double? = nil

  let obstacleClimbSpeedKIAS: Double? = nil

  func package() throws -> DataPackage { try DataPackage.sr22.get() }

  func enrouteClimbNames(iceContaminated: Bool) -> EnrouteClimbNames? {
    iceContaminated
      ? nil
      : .init(tableDirectory: "enroute climb", equationSuffix: "", obstacleTableDirectory: nil)
  }

  func landingTables(for flapSetting: FlapSetting) -> LandingTables {
    .init(flapSetting: flapSetting, totalDistanceFactor: nil)
  }
}
