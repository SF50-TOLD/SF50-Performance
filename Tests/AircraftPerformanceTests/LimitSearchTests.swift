import Foundation
import Testing

@testable import AircraftPerformance

@Suite
struct `Limit Searches` {
  private static let calculator = PerformanceCalculator(settings: .init(aircraft: .sf50(.g1)))

  private static let emptyWeight = Measurement(value: 3550, unit: UnitMass.pounds)

  private static let conditions = Conditions(
    windDirection: .init(value: 0, unit: .degrees),
    windSpeed: .init(value: 0, unit: .knots),
    temperature: .init(value: 20, unit: .celsius),
    seaLevelPressure: .init(value: 29.92, unit: .inchesOfMercury)
  )

  private static func runway(
    length: Double,
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

  private static func takeoffDistanceFt(weight: Double, temperature: Double = 20) throws -> Double {
    let report = try calculator.takeoff(
      conditions: conditions.replacingTemperature(with: .init(value: temperature, unit: .celsius)),
      weight: .init(value: weight, unit: .pounds),
      runway: runway(length: 10_000)
    )
    return try #require(report.results.takeoffDistance.nominal).converted(to: .feet).value
  }

  private static func landingDistanceFt(
    weight: Double,
    temperature: Double = 20,
    calculator: PerformanceCalculator = calculator,
    elevation: Double = 0
  ) throws -> Double {
    let report = try calculator.landing(
      conditions: conditions.replacingTemperature(with: .init(value: temperature, unit: .celsius)),
      configuration: .init(
        weight: .init(value: weight, unit: .pounds),
        flapSetting: .flaps100
      ),
      runway: runway(length: 10_000, elevation: elevation)
    )
    return try #require(report.results.landingDistance.nominal).converted(to: .feet).value
  }

  @Test
  func `bisection finds the same limit a linear scan would`() {
    let threshold = 5373.0
    let search = LimitBisection.highestSatisfying(from: 3550, to: 6000, increment: 50) {
      $0 <= threshold ? .satisfied(reliesOnOffscaleData: false) : .violated(.fieldLength)
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
    #expect(!result.reliesOnOffscaleData)
  }

  @Test
  func `finds no takeoff weight where even a clamped distance exceeds the runway`() throws {
    // The tables start at 5,000 lb, so every lighter weight reads the 5,000 lb distance, which is
    // more than 2,500 ft.
    let result = try Self.calculator.maxTakeoffWeight(
      conditions: Self.conditions,
      runway: Self.runway(length: 2500),
      obstacle: nil,
      minimumWeight: Self.emptyWeight
    )

    #expect(result.limit == nil)
    #expect(result.bindingConstraint == .fieldLength)
  }

  @Test
  func `flags a limit that rests on conditions colder than the tables cover`() throws {
    let cold = Self.conditions.replacingTemperature(with: .init(value: -30, unit: .celsius))
    let result = try Self.calculator.maxTakeoffWeight(
      conditions: cold,
      runway: Self.runway(length: 10_000),
      obstacle: nil,
      minimumWeight: Self.emptyWeight
    )

    #expect(result.limit == SF50Definition.g1Limitations.maxTakeoffWeight)
    #expect(result.reliesOnOffscaleData)
  }

  @Test
  func `finds no limit where the wind exceeds the AFM's tailwind limit`() throws {
    let tailwind = Conditions(
      windDirection: .init(value: 180, unit: .degrees),
      windSpeed: .init(value: 15, unit: .knots),
      temperature: .init(value: 20, unit: .celsius),
      seaLevelPressure: .init(value: 29.92, unit: .inchesOfMercury)
    )
    let result = try Self.calculator.maxTakeoffWeight(
      conditions: tailwind,
      runway: Self.runway(length: 10_000),
      obstacle: nil,
      minimumWeight: Self.emptyWeight
    )

    #expect(result.limit == nil)
    #expect(result.bindingConstraint == .windLimit)
  }

  @Test
  func `searches past the AFM's demonstrated crosswind, which is not limiting`() throws {
    let crosswind = Conditions(
      windDirection: .init(value: 90, unit: .degrees),
      windSpeed: .init(value: 25, unit: .knots),
      temperature: .init(value: 20, unit: .celsius),
      seaLevelPressure: .init(value: 29.92, unit: .inchesOfMercury)
    )
    let result = try Self.calculator.maxTakeoffWeight(
      conditions: crosswind,
      runway: Self.runway(length: 10_000),
      obstacle: nil,
      minimumWeight: Self.emptyWeight
    )

    #expect(result.limit != nil)
    #expect(result.bindingConstraint != .windLimit)
  }

  @Test
  func `reads the obstacle from the runway's NOTAM when none is given`() throws {
    let obstacle = Obstacle(
      height: .init(value: 700, unit: .feet),
      distanceFromDepartureEnd: .init(value: 1000, unit: .feet)
    )
    let notam = NOTAMInput(
      contaminationType: nil,
      contaminationDepth: .init(value: 0, unit: .meters),
      takeoffDistanceShortening: .init(value: 0, unit: .meters),
      landingDistanceShortening: .init(value: 0, unit: .meters),
      obstacleHeight: obstacle.height,
      obstacleDistance: obstacle.distanceFromDepartureEnd
    )
    let fromNOTAM = try Self.calculator.maxTakeoffWeight(
      conditions: Self.conditions,
      runway: Self.runway(length: 5000, notam: notam),
      minimumWeight: Self.emptyWeight
    )
    let explicit = try Self.calculator.maxTakeoffWeight(
      conditions: Self.conditions,
      runway: Self.runway(length: 5000),
      obstacle: obstacle,
      minimumWeight: Self.emptyWeight
    )

    #expect(fromNOTAM.bindingConstraint == .obstacleClearance)
    #expect(fromNOTAM.limit == explicit.limit)
  }

  @Test
  func `finds no takeoff weight past an obstacle inside the takeoff distance`() throws {
    let obstacle = Obstacle(
      height: .init(value: 700, unit: .feet),
      distanceFromDepartureEnd: .init(value: -1000, unit: .feet)
    )
    let result = try Self.calculator.maxTakeoffWeight(
      conditions: Self.conditions,
      runway: Self.runway(length: 5000),
      obstacle: obstacle,
      minimumWeight: .init(value: 5000, unit: .pounds)
    )

    #expect(result.limit == nil)
    #expect(result.bindingConstraint == .obstacleClearance)
  }

  @Test
  func `reaches the structural limit where nothing else binds`() throws {
    let result = try Self.calculator.maxTakeoffWeight(
      conditions: Self.conditions,
      runway: Self.runway(length: 10_000),
      obstacle: nil,
      minimumWeight: Self.emptyWeight
    )

    #expect(result.limit == SF50Definition.g1Limitations.maxTakeoffWeight)
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
    #expect(result.limit.map { $0 < SF50Definition.g1Limitations.maxTakeoffWeight } ?? false)
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
    #expect(long.limit == SF50Definition.g1Limitations.maxTemperature)
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

    let limit = try #require(result.limit).converted(to: .pounds).value
    #expect(result.bindingConstraint == .fieldLength)
    #expect(limit < SF50Definition.g1Limitations.maxLandingWeight.converted(to: .pounds).value)
    #expect(try Self.landingDistanceFt(weight: limit) <= 2400)
    #expect(try Self.landingDistanceFt(weight: limit + 50) > 2400)
  }

  @Test
  func `limits the landing temperature by field length`() throws {
    let configuration = Configuration(
      weight: .init(value: 5550, unit: .pounds),
      flapSetting: .flaps100
    )
    let result = try Self.calculator.maxLandingTemperature(
      conditions: Self.conditions,
      configuration: configuration,
      runway: Self.runway(length: 2600)
    )

    let limit = try #require(result.limit).converted(to: .celsius).value
    #expect(result.bindingConstraint == .fieldLength)
    #expect(try Self.landingDistanceFt(weight: 5550, temperature: limit) <= 2600)
    #expect(try Self.landingDistanceFt(weight: 5550, temperature: limit + 1) > 2600)
  }

  @Test
  func `limits the landing weight by the go-around climb gradient at a high, hot airport`() throws {
    let calculator = PerformanceCalculator(
      settings: .init(aircraft: .sf50(.g1), modelKind: .regression)
    )
    let hot = Self.conditions.replacingTemperature(with: .init(value: 30, unit: .celsius))
    let result = try calculator.maxLandingWeight(
      conditions: hot,
      runway: Self.runway(length: 12_000, elevation: 8000),
      flapSetting: .flaps100,
      minimumWeight: Self.emptyWeight
    )

    #expect(result.bindingConstraint == .goAroundClimbGradient)
    #expect(result.limit.map { $0 < SF50Definition.g1Limitations.maxLandingWeight } == true)
  }

  @Test
  func `bounds the airport elevation for the tables but not the regression model`() throws {
    let high = Self.runway(length: 12_000, elevation: 11_000)
    let tabular = try Self.calculator.maxTakeoffWeight(
      conditions: Self.conditions,
      runway: high,
      minimumWeight: Self.emptyWeight
    )
    #expect(tabular.limit == nil)
    #expect(tabular.bindingConstraint == .elevationLimit)

    let regression = try PerformanceCalculator(
      settings: .init(aircraft: .sf50(.g1), modelKind: .regression)
    ).maxTakeoffWeight(
      conditions: Self.conditions,
      runway: high,
      minimumWeight: Self.emptyWeight
    )
    #expect(regression.bindingConstraint != .elevationLimit)
  }

  @Test
  func `limits the landing weight where the tables give no figure`() throws {
    let hot = Self.conditions.replacingTemperature(with: .init(value: 30, unit: .celsius))
    let result = try Self.calculator.maxLandingWeight(
      conditions: hot,
      runway: Self.runway(length: 12_000, elevation: 8000),
      flapSetting: .flaps100,
      minimumWeight: Self.emptyWeight
    )

    #expect(result.bindingConstraint == .AFMData)
    #expect(result.limit.map { $0 < SF50Definition.g1Limitations.maxLandingWeight } == true)
  }
}
