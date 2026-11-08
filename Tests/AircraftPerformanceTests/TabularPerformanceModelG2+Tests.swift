import Foundation
import RealModule
import Testing

@testable import AircraftPerformance

struct TabularPerformanceModelG2PlusTests {

  // MARK: - Takeoff Ground Run Tests

  @Test
  func `takeoff ground run exact match`() throws {
    // Test exact values from g2+/takeoff/ground run.csv (after removing ISA values)
    let testCases: [(weight: Double, altitude: Double, temperature: Double, expected: Double)] = [
      (6000, 0, -20, 1670),
      (6000, 0, -10, 1736),
      (6000, 0, 0, 1804),
      (6000, 0, 10, 1875),
      (6000, 0, 20, 1963),
      (6000, 0, 30, 2279),
      (6000, 0, 40, 2797),
      (6000, 0, 50, 3475),
      (6000, 1000, 20, 2058),
      (6000, 2000, 20, 2166),
      (6000, 3000, 20, 2322),
      (6000, 4000, 20, 2523),
      (6000, 5000, 20, 2726),
      (6000, 6000, 20, 2973),
      (6000, 7000, 20, 3283),
      (6000, 8000, 20, 3674),
      (5500, 0, 20, 1800),
      (5000, 0, 20, 1636)
    ]

    for testCase in testCases {
      let conditions = Helper.createTestConditions(temperature: testCase.temperature)
      let config = Helper.createTestConfiguration(weight: testCase.weight)
      let runway = Helper.createTestRunway(elevation: testCase.altitude)

      let model = try TabularPerformanceModel(
        conditions: conditions,
        configuration: config,
        runway: runway,
        notam: nil,
        aircraft: .sf50(.g2Plus)
      )

      let result = model.takeoffRunFt
      guard case .value(let value) = result else {
        PerformanceCase(for: model, aircraft: .sf50(.g2Plus))
          .fail(
            "Expected value for weight: \(testCase.weight), altitude: \(testCase.altitude), temp: \(testCase.temperature), got \(result)",
            computing: "takeoff run"
          )
        continue
      }

      #expect(value == testCase.expected)
    }
  }

  @Test
  func `takeoff ground run interpolation`() throws {
    // Test interpolation between known values
    let conditions = Helper.createTestConditions(temperature: 25)  // Between 20 and 30
    let config = Helper.createTestConfiguration(weight: 5750)  // Between 5500 and 6000
    let runway = Helper.createTestRunway(elevation: 500)  // Between 0 and 1000

    let model = try TabularPerformanceModel(
      conditions: conditions,
      configuration: config,
      runway: runway,
      notam: nil,
      aircraft: .sf50(.g2Plus)
    )

    let result = model.takeoffRunFt
    guard case .value(let value) = result else {
      PerformanceCase(for: model, aircraft: .sf50(.g2Plus))
        .fail("Expected interpolated value, got \(result)", computing: "takeoff run")
      return
    }

    // Value should be between the surrounding values
    #expect(value > 1602)  // 5500 lb at 0 ft, 20°C
    #expect(value < 2625)  // 6000 lb at 3000 ft, 20°C
  }

  // MARK: - Takeoff Distance Tests

  @Test
  func `takeoff distance exact match`() throws {
    // Test exact values from g2+/takeoff/total distance.csv (after removing ISA values)
    let testCases: [(weight: Double, altitude: Double, temperature: Double, expected: Double)] = [
      (6000, 0, -20, 2460),
      (6000, 0, -10, 2558),
      (6000, 0, 0, 2658),
      (6000, 0, 10, 2764),
      (6000, 0, 20, 2896),
      (6000, 0, 30, 3390),
      (6000, 0, 40, 4217),
      (6000, 0, 50, 5315),
      (6000, 1000, 20, 3037),
      (6000, 2000, 20, 3201),
      (6000, 3000, 20, 3439),
      (6000, 4000, 20, 3751),
      (6000, 5000, 20, 4065),
      (6000, 6000, 20, 4449),
      (6000, 7000, 20, 4937),
      (6000, 8000, 20, 5552)
    ]

    for testCase in testCases {
      let conditions = Helper.createTestConditions(temperature: testCase.temperature)
      let config = Helper.createTestConfiguration(weight: testCase.weight)
      let runway = Helper.createTestRunway(elevation: testCase.altitude)

      let model = try TabularPerformanceModel(
        conditions: conditions,
        configuration: config,
        runway: runway,
        notam: nil,
        aircraft: .sf50(.g2Plus)
      )

      let result = model.takeoffDistanceFt
      guard case .value(let value) = result else {
        PerformanceCase(for: model, aircraft: .sf50(.g2Plus))
          .fail(
            "Expected value for weight: \(testCase.weight), altitude: \(testCase.altitude), temp: \(testCase.temperature), got \(result)",
            computing: "takeoff distance"
          )
        continue
      }

      #expect(value == testCase.expected)
    }
  }

  // MARK: - Takeoff Climb Tests

  @Test
  func `takeoff climb gradient exact match`() throws {
    // Test exact values from g2+/takeoff climb/gradient.csv
    let testCases: [(weight: Double, altitude: Double, temperature: Double, expected: Double)] = [
      (6000, 0, -20, 1230),
      (6000, 0, -10, 1229),
      (6000, 0, 0, 1227),
      (6000, 0, 10, 1223),
      (6000, 0, 20, 1209),
      (6000, 0, 30, 1062),
      (6000, 0, 40, 876),
      (6000, 0, 50, 702),
      (5500, 0, 20, 1395),
      (5000, 0, 20, 1612)
    ]

    for testCase in testCases {
      let conditions = Helper.createTestConditions(temperature: testCase.temperature)
      let config = Helper.createTestConfiguration(weight: testCase.weight)
      let runway = Helper.createTestRunway(elevation: testCase.altitude)

      let model = try TabularPerformanceModel(
        conditions: conditions,
        configuration: config,
        runway: runway,
        notam: nil,
        aircraft: .sf50(.g2Plus)
      )

      let result = model.takeoffClimbGradientFtNM
      guard case .value(let value) = result else {
        PerformanceCase(for: model, aircraft: .sf50(.g2Plus))
          .fail(
            "Expected value for weight: \(testCase.weight), altitude: \(testCase.altitude), temp: \(testCase.temperature), got \(result)",
            computing: "takeoff climb gradient"
          )
        continue
      }

      #expect(value == testCase.expected)
    }
  }

  @Test
  func `takeoff climb rate exact match`() throws {
    // Test exact values from g2+/takeoff climb/rate.csv
    let testCases: [(weight: Double, altitude: Double, temperature: Double, expected: Double)] = [
      (6000, 0, -20, 2012),
      (6000, 0, -10, 1972),
      (6000, 0, 0, 1933),
      (6000, 0, 10, 1892),
      (6000, 0, 20, 1838),
      (6000, 0, 30, 1589),
      (6000, 0, 40, 1289),
      (6000, 0, 50, 1017),
      (5500, 0, 20, 2122),
      (5000, 0, 20, 2451)
    ]

    for testCase in testCases {
      let conditions = Helper.createTestConditions(temperature: testCase.temperature)
      let config = Helper.createTestConfiguration(weight: testCase.weight)
      let runway = Helper.createTestRunway(elevation: testCase.altitude)

      let model = try TabularPerformanceModel(
        conditions: conditions,
        configuration: config,
        runway: runway,
        notam: nil,
        aircraft: .sf50(.g2Plus)
      )

      let result = model.takeoffClimbRateFtMin
      guard case .value(let value) = result else {
        PerformanceCase(for: model, aircraft: .sf50(.g2Plus))
          .fail(
            "Expected value for weight: \(testCase.weight), altitude: \(testCase.altitude), temp: \(testCase.temperature), got \(result)",
            computing: "takeoff climb rate"
          )
        continue
      }

      #expect(value == testCase.expected)
    }
  }

  // MARK: - Vref Tests

  @Test(arguments: [
    (FlapSetting.flaps100, 85.0),
    (.flaps50, 96),
    (.flaps50Ice, 115),
    (.flapsUp, 104),
    (.flapsUpIce, 135)
  ])
  func `Vref follows the flap setting`(flapSetting: FlapSetting, expected: Double) throws {
    let runway = Helper.createTestRunway()
    let model = try TabularPerformanceModel(
      conditions: Helper.createTestConditions(),
      configuration: Helper.createTestConfiguration(weight: 5550, flapSetting: flapSetting),
      runway: runway,
      notam: nil,
      aircraft: .sf50(.g2Plus)
    )

    #expect(model.VrefKts == .value(expected))
  }

  @Test(arguments: [FlapSetting.flaps50, .flaps50Ice, .flaps100])
  func `a G3 performs exactly as a G2+`(flapSetting: FlapSetting) throws {
    func model(_ aircraftType: SF50Variant) throws -> TabularPerformanceModel {
      let runway = Helper.createTestRunway(elevation: 3000)
      return try TabularPerformanceModel(
        conditions: Helper.createTestConditions(temperature: 10),
        configuration: Helper.createTestConfiguration(weight: 5500, flapSetting: flapSetting),
        runway: runway,
        notam: nil,
        aircraft: .sf50(aircraftType)
      )
    }

    let g2Plus = try model(.g2Plus), g3 = try model(.g3)
    #expect(g3.takeoffDistanceFt == g2Plus.takeoffDistanceFt)
    #expect(g3.takeoffClimbGradientFtNM == g2Plus.takeoffClimbGradientFtNM)
    #expect(g3.landingDistanceFt == g2Plus.landingDistanceFt)
    #expect(g3.VrefKts == g2Plus.VrefKts)
    #expect(g3.takeoffDistanceFt.nominal != nil)
  }

  // MARK: - Wind Adjustment Tests

  @Test
  func `takeoff run headwind adjustment`() throws {
    // Test with 10 kt headwind
    let conditionsNoWind = Helper.createTestConditions(temperature: 20)
    let conditionsHeadwind = Helper.createTestConditions(
      temperature: 20,
      windDirection: 360,
      windSpeed: 10
    )
    let config = Helper.createTestConfiguration()
    let runway = Helper.createTestRunway(heading: 360)

    let modelNoWind = try TabularPerformanceModel(
      conditions: conditionsNoWind,
      configuration: config,
      runway: runway,
      notam: nil,
      aircraft: .sf50(.g2Plus)
    )

    let modelHeadwind = try TabularPerformanceModel(
      conditions: conditionsHeadwind,
      configuration: config,
      runway: runway,
      notam: nil,
      aircraft: .sf50(.g2Plus)
    )

    guard case .value(let noWindValue) = modelNoWind.takeoffRunFt else {
      PerformanceCase(for: modelNoWind, aircraft: .sf50(.g2Plus))
        .fail(
          "Expected a no-wind takeoff run, got \(modelNoWind.takeoffRunFt)",
          computing: "no-wind takeoff run"
        )
      return
    }
    guard case .value(let headwindValue) = modelHeadwind.takeoffRunFt else {
      PerformanceCase(for: modelHeadwind, aircraft: .sf50(.g2Plus))
        .fail(
          "Expected a headwind takeoff run, got \(modelHeadwind.takeoffRunFt)",
          computing: "headwind takeoff run"
        )
      return
    }

    // Headwind should reduce takeoff run
    #expect(headwindValue < noWindValue)
  }

  @Test
  func `landing run tailwind adjustment`() throws {
    // Test with 10 kt tailwind for landing
    let conditionsNoWind = Helper.createTestConditions(temperature: 20)
    let conditionsTailwind = Helper.createTestConditions(
      temperature: 20,
      windDirection: 180,
      windSpeed: 10
    )
    let config = Helper.createTestConfiguration(weight: 5550)
    let runway = Helper.createTestRunway(heading: 360)

    let modelNoWind = try TabularPerformanceModel(
      conditions: conditionsNoWind,
      configuration: config,
      runway: runway,
      notam: nil,
      aircraft: .sf50(.g2Plus)
    )

    let modelTailwind = try TabularPerformanceModel(
      conditions: conditionsTailwind,
      configuration: config,
      runway: runway,
      notam: nil,
      aircraft: .sf50(.g2Plus)
    )

    guard case .value(let noWindValue) = modelNoWind.landingRunFt,
      case .value(let tailwindValue) = modelTailwind.landingRunFt
    else {
      Issue
        .record(
          "Expected values for wind adjustment test, got modelNoWind = \(modelNoWind.landingRunFt), modelTailwind = \(modelTailwind.landingRunFt)"
        )
      return
    }

    // Tailwind landing run should have specific values
    #expect(noWindValue.isApproximatelyEqual(to: 2177.0, relativeTolerance: 0.01))
    #expect(tailwindValue.isApproximatelyEqual(to: 3091.34, relativeTolerance: 0.01))
  }

  // MARK: - Slope Adjustment Tests

  @Test
  func `landing run downhill adjustment`() throws {
    // Test with 2% downhill slope for landing
    let conditions = Helper.createTestConditions(temperature: 20)
    let config = Helper.createTestConfiguration(weight: 5550)
    let runwayFlat = Helper.createTestRunway(slope: 0)
    let runwayDownhill = Helper.createTestRunway(slope: -2)

    let modelFlat = try TabularPerformanceModel(
      conditions: conditions,
      configuration: config,
      runway: runwayFlat,
      notam: nil,
      aircraft: .sf50(.g2Plus)
    )

    let modelDownhill = try TabularPerformanceModel(
      conditions: conditions,
      configuration: config,
      runway: runwayDownhill,
      notam: nil,
      aircraft: .sf50(.g2Plus)
    )

    guard case .value(let flatValue) = modelFlat.landingRunFt else {
      PerformanceCase(for: modelFlat, aircraft: .sf50(.g2Plus))
        .fail(
          "Expected a flat landing run, got \(modelFlat.landingRunFt)",
          computing: "flat landing run"
        )
      return
    }
    guard case .value(let downhillValue) = modelDownhill.landingRunFt else {
      PerformanceCase(for: modelDownhill, aircraft: .sf50(.g2Plus))
        .fail(
          "Expected a downhill landing run, got \(modelDownhill.landingRunFt)",
          computing: "downhill landing run"
        )
      return
    }

    // Downhill landing run should have specific values
    #expect(flatValue.isApproximatelyEqual(to: 2177.0, relativeTolerance: 0.01))
    #expect(downhillValue.isApproximatelyEqual(to: 2438.24, relativeTolerance: 0.01))
  }

  // MARK: - Surface Adjustment Tests

  @Test
  func `landing distance unpaved adjustment`() throws {
    // Test unpaved runway adjustment for landing
    let conditions = Helper.createTestConditions(temperature: 20)
    let config = Helper.createTestConfiguration(weight: 5550)
    let runwayPaved = Helper.createTestRunway(surfaceType: .paved)
    let runwayUnpaved = Helper.createTestRunway(surfaceType: .turf)

    let modelPaved = try TabularPerformanceModel(
      conditions: conditions,
      configuration: config,
      runway: runwayPaved,
      notam: nil,
      aircraft: .sf50(.g2Plus)
    )

    let modelUnpaved = try TabularPerformanceModel(
      conditions: conditions,
      configuration: config,
      runway: runwayUnpaved,
      notam: nil,
      aircraft: .sf50(.g2Plus)
    )

    guard case .value(let pavedValue) = modelPaved.landingDistanceFt else {
      PerformanceCase(for: modelPaved, aircraft: .sf50(.g2Plus))
        .fail(
          "Expected a paved landing distance, got \(modelPaved.landingDistanceFt)",
          computing: "paved landing distance"
        )
      return
    }
    guard case .value(let unpavedValue) = modelUnpaved.landingDistanceFt else {
      PerformanceCase(for: modelUnpaved, aircraft: .sf50(.g2Plus))
        .fail(
          "Expected a unpaved landing distance, got \(modelUnpaved.landingDistanceFt)",
          computing: "unpaved landing distance"
        )
      return
    }

    // Unpaved landing distance should have specific values
    #expect(pavedValue.isApproximatelyEqual(to: 3247.0, relativeTolerance: 0.01))
    #expect(unpavedValue.isApproximatelyEqual(to: 3896.40, relativeTolerance: 0.01))
  }
}
