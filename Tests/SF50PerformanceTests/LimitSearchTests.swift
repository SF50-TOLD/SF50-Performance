import Foundation
import Testing

@testable import SF50Performance

@Suite
struct `Limit Searches` {
  private static let calculator = PerformanceCalculator(settings: .init(aircraftType: .g1))

  private static let emptyWeight = Measurement(value: 3550, unit: UnitMass.pounds)

  private static let conditions = Conditions(
    windDirection: .init(value: 0, unit: .degrees),
    windSpeed: .init(value: 0, unit: .knots),
    temperature: .init(value: 20, unit: .celsius),
    seaLevelPressure: .init(value: 29.92, unit: .inchesOfMercury)
  )

  private static func runway(length: Double) -> RunwayInput {
    RunwayInput(
      id: "36",
      elevation: .init(value: 0, unit: .feet),
      trueHeading: .init(value: 360, unit: .degrees),
      gradient: 0,
      length: .init(value: length, unit: .feet),
      takeoffRun: nil,
      takeoffDistance: nil,
      landingDistance: nil,
      notam: nil,
      airportVariation: .init(value: 0, unit: .degrees)
    )
  }

  private static func takeoffDistanceFt(weight: Double, temperature: Double = 20) throws -> Double {
    let report = try calculator.takeoff(
      conditions: conditions.replacingTemperature(with: .init(value: temperature, unit: .celsius)),
      weight: .init(value: weight, unit: .pounds),
      runway: runway(length: 10_000)
    )
    return try #require(report.results.takeoffDistance.nominal).converted(to: .feet).value
  }

  @Test
  func `bisection finds the same limit a linear scan would`() {
    let threshold = 5373.0
    let search = LimitBisection.highestSatisfying(from: 3550, to: 6000, increment: 50) {
      $0 <= threshold ? .satisfied : .violated(.fieldLength)
    }

    #expect(search.highest == 5350)
    #expect(search.violation == .fieldLength)

    let none = LimitBisection.highestSatisfying(from: 3550, to: 6000, increment: 50) { _ in
      .violated(.AFMData)
    }
    #expect(none.highest == nil)
    #expect(none.violation == .AFMData)
  }

  @Test
  func `limits the takeoff weight by field length on a short runway`() throws {
    let runway = Self.runway(length: 3200)
    let result = try Self.calculator.maxTakeoffWeight(
      conditions: Self.conditions,
      runway: runway,
      obstacle: nil,
      minimumWeight: Self.emptyWeight
    )

    let limit = try #require(result.limit).converted(to: .pounds).value
    #expect(result.bindingConstraint == .fieldLength)
    #expect(try Self.takeoffDistanceFt(weight: limit) <= 3200)
    #expect(try Self.takeoffDistanceFt(weight: limit + 50) > 3200)
  }

  @Test
  func `reaches the structural limit where nothing else binds`() throws {
    let result = try Self.calculator.maxTakeoffWeight(
      conditions: Self.conditions,
      runway: Self.runway(length: 10_000),
      obstacle: nil,
      minimumWeight: Self.emptyWeight
    )

    #expect(result.limit == LimitationsG1.maxTakeoffWeight)
    #expect(result.bindingConstraint == .structuralLimit)
  }

  @Test
  func `limits the takeoff weight by an obstacle the climb cannot clear`() throws {
    let obstacle = Obstacle(
      height: .init(value: 700, unit: .feet),
      distanceFromDepartureEnd: .init(value: 1000, unit: .feet)
    )
    let result = try Self.calculator.maxTakeoffWeight(
      conditions: Self.conditions,
      runway: Self.runway(length: 5000),
      obstacle: obstacle,
      minimumWeight: Self.emptyWeight
    )

    #expect(result.bindingConstraint == .obstacleClearance)
    #expect(result.limit.map { $0 < LimitationsG1.maxTakeoffWeight } ?? false)
  }

  @Test
  func `limits the takeoff temperature by field length, and otherwise by the AFM limit`() throws {
    let weight = Measurement(value: 6000, unit: UnitMass.pounds)

    let short = try Self.calculator.maxTakeoffTemperature(
      conditions: Self.conditions,
      weight: weight,
      runway: Self.runway(length: 4000),
      obstacle: nil
    )
    let limit = try #require(short.limit).converted(to: .celsius).value
    #expect(short.bindingConstraint == .fieldLength)
    #expect(try Self.takeoffDistanceFt(weight: 6000, temperature: limit) <= 4000)
    #expect(try Self.takeoffDistanceFt(weight: 6000, temperature: limit + 1) > 4000)

    let long = try Self.calculator.maxTakeoffTemperature(
      conditions: Self.conditions,
      weight: weight,
      runway: Self.runway(length: 10_000),
      obstacle: nil
    )
    #expect(long.limit == LimitationsG1.maxTemperature)
    #expect(long.bindingConstraint == .temperatureLimit)
  }

  @Test
  func `limits the landing weight by field length on a short runway`() throws {
    let result = try Self.calculator.maxLandingWeight(
      conditions: Self.conditions,
      runway: Self.runway(length: 2400),
      flapSetting: .flaps100,
      minimumWeight: Self.emptyWeight
    )

    #expect(result.bindingConstraint == .fieldLength)
    #expect(result.limit.map { $0 < LimitationsG1.maxLandingWeight } ?? true)
  }
}
