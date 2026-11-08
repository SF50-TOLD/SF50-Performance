import Foundation
import MeasurementKit
import RealModule
import Testing

@testable import AircraftPerformance

@Suite
struct `Performance Notes` {
  private static let calculator = PerformanceCalculator(settings: .init(aircraft: .sf50(.g1)))

  private static let standardAltimeter = Measurement(
    value: 29.92,
    unit: UnitPressure.inchesOfMercury
  )

  private static func conditions(
    temperature: Double = 20,
    windDirection: Double = 0,
    windSpeed: Double = 0,
    altimeter: Measurement<UnitPressure>? = standardAltimeter
  ) -> Conditions {
    Conditions(
      windDirection: .init(value: windDirection, unit: .degrees),
      windSpeed: .init(value: windSpeed, unit: .knots),
      temperature: .init(value: temperature, unit: .celsius),
      seaLevelPressure: altimeter
    )
  }

  private static func runway(
    length: Double = 5000,
    elevation: Double = 0,
    notam: NOTAMInput? = nil
  ) -> RunwayInput {
    RunwayInput(
      id: "36",
      elevation: .init(value: elevation, unit: .feet),
      trueHeading: .init(value: 360, unit: .degrees),
      gradient: 0,
      length: .init(value: length, unit: .feet),
      takeoffRun: nil,
      takeoffDistance: nil,
      landingDistance: nil,
      notam: notam,
      airportVariation: .init(value: 0, unit: .degrees)
    )
  }

  private static func contaminated(_ contamination: Contamination) -> NOTAMInput {
    NOTAMInput(
      contaminationType: contamination.type,
      contaminationDepth: .init(value: contamination.depth ?? 0, unit: .meters),
      rwyCC: contamination.rwyCC,
      takeoffDistanceShortening: .init(value: 0, unit: .feet),
      landingDistanceShortening: .init(value: 0, unit: .feet),
      obstacleHeight: .init(value: 0, unit: .feet),
      obstacleDistance: .init(value: 0, unit: .feet)
    )
  }

  private static func takeoffNotes(
    weight: Double = 5000,
    conditions: Conditions = conditions(),
    runway: RunwayInput = runway(),
    obstacle: Obstacle? = nil,
    calculator: PerformanceCalculator = calculator
  ) throws -> [PerformanceNote] {
    let weight = Measurement(value: weight, unit: UnitMass.pounds),
      report = try calculator.takeoff(conditions: conditions, weight: weight, runway: runway)
    return PerformanceNotes.takeoffNotes(
      for: report,
      inputs: .init(
        settings: calculator.settings,
        configuration: .init(weight: weight, flapSetting: .flaps50),
        runway: runway,
        conditions: conditions,
        obstacle: obstacle
      )
    )
  }

  private static func landingNotes(
    runway: RunwayInput,
    calculator: PerformanceCalculator
  ) throws -> [PerformanceNote] {
    let
      configuration = Configuration(
        weight: .init(value: 5000, unit: .pounds),
        flapSetting: .flaps100
      ),
      report = try calculator.landing(
        conditions: conditions(),
        configuration: configuration,
        runway: runway
      )
    return PerformanceNotes.landingNotes(
      for: report,
      inputs: .init(
        settings: calculator.settings,
        configuration: configuration,
        runway: runway,
        conditions: conditions()
      )
    )
  }

  @Test
  func `warns when the takeoff distance exceeds what the runway declares`() throws {
    let notes = try Self.takeoffNotes(weight: 6000, runway: Self.runway(length: 3000))

    #expect(
      notes == [
        .takeoffDistanceExceedsAvailable(
          required: .init(value: 3519, unit: .feet),
          available: .init(value: 3000, unit: .feet)
        )
      ]
    )
  }

  @Test
  func `warns about wind, temperature and elevation outside the AFM limits`() throws {
    let crosswind = try Self.takeoffNotes(
      conditions: Self.conditions(windDirection: 90, windSpeed: 20)
    )
    #expect(crosswind.contains { if case .crosswindExceedance = $0 { true } else { false } })

    let tailwind = try Self.takeoffNotes(
      conditions: Self.conditions(windDirection: 180, windSpeed: 15)
    )
    #expect(tailwind.contains { if case .tailwindExceedance = $0 { true } else { false } })

    let hot = try Self.takeoffNotes(conditions: Self.conditions(temperature: 52))
    #expect(hot.contains { if case .temperatureOutsideLimits = $0 { true } else { false } })

    let high = try Self.takeoffNotes(runway: Self.runway(elevation: 10_500))
    #expect(high.contains { if case .airportElevationOutsideLimits = $0 { true } else { false } })
  }

  @Test
  func `leaves the elevation limit to the tables, which the regression may extrapolate past`()
    throws
  {
    let regression = PerformanceCalculator(
      settings: .init(aircraft: .sf50(.g1), modelKind: .regression)
    )
    let notes = try Self.takeoffNotes(
      runway: Self.runway(elevation: 10_500),
      calculator: regression
    )

    #expect(!notes.contains { if case .airportElevationOutsideLimits = $0 { true } else { false } })
  }

  @Test
  func `says when no altimeter setting corrected field elevation`() throws {
    let notes = try Self.takeoffNotes(conditions: Self.conditions(altimeter: nil))

    #expect(notes == [.pressureAltitudeFromFieldElevation])
  }

  @Test
  func `checks an obstacle against the climb from the end of the takeoff distance`() throws {
    let
      low = Obstacle(
        height: .init(value: 100, unit: .feet),
        distanceFromDepartureEnd: .init(value: 5000, unit: .feet)
      ),
      tall = Obstacle(
        height: .init(value: 1000, unit: .feet),
        distanceFromDepartureEnd: .init(value: 1000, unit: .feet)
      ),
      close = Obstacle(
        height: .init(value: 60, unit: .feet),
        distanceFromDepartureEnd: .init(value: 100, unit: .feet)
      )

    #expect(try Self.takeoffNotes(obstacle: low).isEmpty)

    let tallNotes = try Self.takeoffNotes(obstacle: tall)
    let required = try #require(
      tallNotes.compactMap { note -> Measurement<UnitSlope>? in
        if case .insufficientClimbGradient(let required, _) = note { required } else { nil }
      }.first
    )
    // 950 ft above the screen height, over 5,000 + 1,000 − 2,706 ft
    #expect(
      required.converted(to: .ratio).value.isApproximatelyEqual(
        to: 950.0 / 3294.0,
        relativeTolerance: 1e-9
      )
    )

    let closeNotes = try Self.takeoffNotes(runway: Self.runway(length: 2500), obstacle: close)
    #expect(closeNotes.contains(.obstacleWithinTakeoffDistance(obstacle: close)))
  }

  @Test
  func `qualifies a contaminated landing and the safety factor it does not take`() throws {
    let factored = PerformanceCalculator(
      settings: .init(aircraft: .sf50(.g1), safetyFactorDry: 1.2, safetyFactorContaminated: 1.4)
    )

    let rwyCC = try Self.landingNotes(
      runway: Self.runway(length: 10_000, notam: Self.contaminated(.rwyCC(3))),
      calculator: factored
    )
    #expect(rwyCC == [.rwyCCSafetyFactorNotApplied, .contaminationSupplemental])

    let wet = try Self.landingNotes(
      runway: Self.runway(length: 10_000, notam: Self.contaminated(.wetRunway)),
      calculator: factored
    )
    #expect(wet.isEmpty)
  }
}
