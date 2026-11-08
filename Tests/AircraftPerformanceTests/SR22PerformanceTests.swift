import Foundation
import RealModule
import Testing

@testable import AircraftPerformance

struct SR22PerformanceTests {
  private static let base = SR22Options(),
    hartzell = SR22Options(hartzellPropeller: true),
    turbonormalized = SR22Options(turbonormalized: true)

  private static var wetNOTAM: NOTAMInput {
    .init(
      contaminationType: "wetRunway",
      contaminationDepth: .init(value: 0, unit: .meters),
      takeoffDistanceShortening: .init(value: 0, unit: .feet),
      landingDistanceShortening: .init(value: 0, unit: .feet),
      obstacleHeight: .init(value: 0, unit: .feet),
      obstacleDistance: .init(value: 0, unit: .feet)
    )
  }

  private static func calculator(
    _ options: SR22Options = base,
    kind: PerformanceModelKind = .tabular
  ) -> PerformanceCalculator {
    .init(settings: .init(aircraft: .sr22(options), modelKind: kind))
  }

  private static func landingConfiguration(weight: Double = 3400) -> Configuration {
    Helper.createTestConfiguration(weight: weight, flapSetting: .flaps100)
  }

  // MARK: - Tables

  @Test
  func `the tabular model reads the POH's takeoff and landing cells`() throws {
    let calculator = Self.calculator(),
      conditions = Helper.createTestConditions(temperature: 20),
      runway = Helper.createTestRunway()

    let takeoff = try calculator.takeoff(
      conditions: conditions,
      weight: .init(value: 3400, unit: .pounds),
      runway: runway
    )
    #expect(takeoff.results.takeoffRun == .value(.init(value: 1067, unit: .feet)))
    #expect(takeoff.results.takeoffDistance == .value(.init(value: 1650, unit: .feet)))

    let landing = try calculator.landing(
      conditions: conditions,
      configuration: Self.landingConfiguration(weight: 2900),
      runway: runway
    )
    #expect(landing.results.landingRun == .value(.init(value: 1161, unit: .feet)))
    #expect(landing.results.landingDistance == .value(.init(value: 2372, unit: .feet)))
    #expect(landing.results.Vref == .notAvailable)
  }

  @Test(arguments: [(base, 867.0), (hartzell, 731.0)])
  func `the Hartzell supplement replaces the en route climb gradient`(
    options: SR22Options,
    expected: Double
  ) throws {
    let model = try Self.calculator(options).model(
      conditions: Helper.createTestConditions(temperature: 0),
      configuration: Self.landingConfiguration(),
      runway: Helper.createTestRunway()
    )
    #expect(model.enrouteClimbGradientFtNM == .value(expected))
  }

  @Test
  func `the misprinted en route climb gradient reads its corrected value`() throws {
    let model = try Self.calculator().model(
      conditions: Helper.createTestConditions(temperature: -20),
      configuration: Self.landingConfiguration(weight: 2900),
      runway: Helper.createTestRunway(elevation: 12_000)
    )
    #expect(model.enrouteClimbGradientFtNM == .value(510))
  }

  // MARK: - Corrections

  /// POH 5-12: wind is 10% per 12 kt headwind; slope is 22% of the ground roll per 1% upslope at
  /// sea level; dry grass adds 20% of the ground roll; the slope and grass feet are added to the
  /// total distance; the air conditioner adds 100 ft to the ground roll and 150 ft to the total.
  @Test
  func `takeoff corrections add their ground roll feet to the total distance`() throws {
    let takeoff = try Self.calculator().takeoff(
      conditions: Helper.createTestConditions(temperature: 20, windDirection: 360, windSpeed: 12),
      weight: .init(value: 3400, unit: .pounds),
      runway: Helper.createTestRunway(slope: 1, surfaceType: .turf),
      airConditionerOn: true
    )

    let windRun = 1067 * 0.9,
      slopedRun = windRun * 1.22,
      grassRun = slopedRun * 1.2,
      expectedRun = grassRun + 100,
      expectedDistance = 1650 * 0.9 + (grassRun - windRun) + 150
    #expect(
      try #require(takeoff.results.takeoffRun.nominal).value.isApproximatelyEqual(
        to: expectedRun,
        relativeTolerance: 1e-6
      )
    )
    #expect(
      try #require(takeoff.results.takeoffDistance.nominal).value.isApproximatelyEqual(
        to: expectedDistance,
        relativeTolerance: 1e-6
      )
    )
  }

  /// POH 5-27: downslope adds 27% of the ground roll per 1%, and wet grass 60% of it.
  @Test
  func `landing on a wet grass downslope adds its ground roll feet to the total`() throws {
    let landing = try Self.calculator().landing(
      conditions: Helper.createTestConditions(temperature: 20),
      configuration: Self.landingConfiguration(),
      runway: Helper.createTestRunway(slope: -1, surfaceType: .turf, notam: Self.wetNOTAM)
    )

    let slopedRun = 1161 * 1.27,
      expectedRun = slopedRun * 1.6
    #expect(
      try #require(landing.results.landingRun.nominal).value.isApproximatelyEqual(
        to: expectedRun,
        relativeTolerance: 1e-6
      )
    )
    #expect(
      try #require(landing.results.landingDistance.nominal).value.isApproximatelyEqual(
        to: 2372 + (expectedRun - 1161),
        relativeTolerance: 1e-6
      )
    )
  }

  // MARK: - Limits

  @Test
  func `takeoff is not authorized above the maximum takeoff altitude, landing is`() throws {
    let calculator = Self.calculator(Self.turbonormalized),
      conditions = Helper.createTestConditions(temperature: 0),
      runway = Helper.createTestRunway(elevation: 11_000)

    let takeoff = try calculator.takeoff(
      conditions: conditions,
      weight: .init(value: 3400, unit: .pounds),
      runway: runway
    )
    #expect(takeoff.results.takeoffRun == .notAuthorized)

    let landing = try calculator.landing(
      conditions: conditions,
      configuration: Self.landingConfiguration(),
      runway: runway
    )
    #expect(landing.results.landingRun != .notAuthorized)

    let notes = PerformanceNotes.inputNotes(
      for: .takeoff,
      inputs: .init(
        settings: calculator.settings,
        configuration: Self.landingConfiguration(),
        runway: runway,
        conditions: conditions
      )
    )
    #expect(
      notes.contains(
        .airportElevationAboveLimit(
          elevation: .init(value: 11_000, unit: .feet),
          limit: .init(value: 10_000, unit: .feet)
        )
      )
    )
  }

  @Test
  func `the tabulated weights come from the ground run tables`() throws {
    let aircraft = Aircraft.sr22(Self.base)
    #expect(
      try aircraft.tabulatedWeights(for: .takeoff)
        == Measurement(value: 2900, unit: .pounds)...Measurement(value: 3400, unit: .pounds)
    )
    #expect(try aircraft.tabulatedWeights(for: .landing, flapSetting: .flaps50) == nil)
  }

  // MARK: - Climb

  @Test
  func `time, fuel and distance to climb are the table's difference between altitudes`() throws {
    let climb = try Self.calculator().timeFuelDistanceToClimb(
      from: .init(value: 0, unit: .feet),
      to: .init(value: 10_000, unit: .feet)
    )
    #expect(climb.time == .value(.init(value: 9.5, unit: .minutes)))
    #expect(climb.fuel == .value(.init(value: 3.5, unit: .gallons)))
    #expect(climb.distance == .value(.init(value: 16.5, unit: .nauticalMiles)))

    let leanOfPeak = try Self.calculator().timeFuelDistanceToClimb(
      from: .init(value: 0, unit: .feet),
      to: .init(value: 10_000, unit: .feet),
      leanOfPeak: true
    )
    #expect(leanOfPeak.time == .notAvailable)
  }

  @Test
  func `the climb profile reads the tabulated climb speeds and has no obstacle climb`() throws {
    let profile = try ClimbProfileGenerator.generate(
      windsAloft: [
        .init(altitudeFt: 0, temperatureC: 15, windDirectionDeg: 0, windSpeedKts: 0),
        .init(altitudeFt: 6000, temperatureC: 3, windDirectionDeg: 0, windSpeedKts: 0)
      ],
      weightLb: 3400,
      aircraft: .sr22(Self.hartzell),
      seaLevelPressureInHg: 29.92,
      useRegressionModel: false
    )
    let seaLevel = try #require(profile.dataPoints.first)
    #expect(seaLevel.climbData(for: .takeoff).indicatedAirspeedKts == .value(91))
    #expect(seaLevel.climbData(for: .enroute(antiIce: false)).indicatedAirspeedKts == .value(112))
    #expect(
      seaLevel.climbData(for: .enrouteObstacle(antiIce: false)).gradientFtPerNM == .notAvailable
    )
  }

  // MARK: - Regression

  @Test
  func `the regression takeoff ground run fits the POH table`() throws {
    let aircraft = Aircraft.sr22(Self.base)
    try validateRegressionPredictions(
      try aircraft.definition.data().table("takeoff/ground run.csv"),
      configBuilder: { Helper.createTestConfiguration(weight: $0) },
      modelBuilder: { conditions, configuration, runway in
        try RegressionPerformanceModel(
          conditions: conditions,
          configuration: configuration,
          runway: runway,
          notam: nil,
          aircraft: aircraft
        )
      },
      valueExtractor: { $0.takeoffRunFt },
      aircraft: aircraft,
      testName: "sr22TakeoffGroundRun"
    )
  }
}
