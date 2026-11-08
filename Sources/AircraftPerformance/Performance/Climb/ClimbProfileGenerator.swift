import Foundation

/// Generates a ``ClimbProfile`` from weather observations, aircraft weight,
/// and performance equations/tables.
public enum ClimbProfileGenerator {

  /// The spacing of the levels the charts are read at between winds-aloft levels.
  private static let chartReadingStepFt: Double = 500

  /// Generates a climb profile by evaluating performance equations at each altitude in the
  /// provided winds-aloft observations, and every 500 ft between them.
  ///
  /// The profile interpolates figures between its levels, and a level the charts have no figure
  /// for leaves the whole span beside it without one. Reading the charts at the forecast levels
  /// alone would let a level thousands of feet above a chart's edge erase the band the chart does
  /// cover; reading them closely puts the edge of the profile within a step of the chart's own.
  ///
  /// - Parameters:
  ///   - windsAloft: Atmospheric observations at various altitudes.
  ///   - weightLb: Aircraft weight in pounds.
  ///   - aircraft: The aircraft, whose data package and configuration the figures come from.
  ///   - seaLevelPressureInHg: Sea-level pressure for TAS computation.
  ///   - useRegressionModel: If true, use regression equations; otherwise use tabular data.
  /// - Returns: A ``ClimbProfile`` with data points at each winds-aloft altitude.
  /// - Throws: ``PerformanceDataError`` if the bundled performance data could not be read.
  public static func generate(
    windsAloft: [WindsAloftObservation],
    weightLb: Double,
    aircraft: Aircraft,
    seaLevelPressureInHg: Double,
    useRegressionModel: Bool
  ) throws -> ClimbProfile {
    let definition = aircraft.definition,
      data = try definition.data(),
      source: any EquationSource =
        useRegressionModel
        ? try RegressionSource(data: data, definition: definition)
        : try TabularSource(data: data, definition: definition)

    let dataPoints = chartReadingLevels(windsAloft).map { obs in
      makeDataPoint(obs: obs, weightLb: weightLb, source: source, definition: definition)
    }

    return ClimbProfile(dataPoints: dataPoints, seaLevelPressureInHg: seaLevelPressureInHg)
  }

  // MARK: - Private

  /// The winds-aloft levels, with levels between them on every multiple of 500 ft, ascending.
  private static func chartReadingLevels(
    _ observations: [WindsAloftObservation]
  ) -> [WindsAloftObservation] {
    let ascending = observations.sorted { $0.altitudeFt < $1.altitudeFt }
    guard let lowest = ascending.first else { return [] }
    return [lowest]
      + zip(ascending, ascending.dropFirst()).flatMap { low, high in
        levels(between: low, and: high) + [high]
      }
  }

  /// The atmosphere on each multiple of 500 ft strictly between two observations.
  private static func levels(
    between low: WindsAloftObservation,
    and high: WindsAloftObservation
  ) -> [WindsAloftObservation] {
    let firstLevelFt =
      ((low.altitudeFt / chartReadingStepFt).rounded(.down) + 1) * chartReadingStepFt
    return stride(from: firstLevelFt, to: high.altitudeFt, by: chartReadingStepFt).map {
      level(at: $0, between: low, and: high)
    }
  }

  /// The atmosphere at an altitude between two observations, read linearly between them as the
  /// profile reads it.
  private static func level(
    at altitudeFt: Double,
    between low: WindsAloftObservation,
    and high: WindsAloftObservation
  ) -> WindsAloftObservation {
    let fraction = (altitudeFt - low.altitudeFt) / (high.altitudeFt - low.altitudeFt)
    func read(_ quantity: KeyPath<WindsAloftObservation, Double>) -> Double {
      low[keyPath: quantity] + fraction * (high[keyPath: quantity] - low[keyPath: quantity])
    }
    return .init(
      altitudeFt: altitudeFt,
      temperatureC: read(\.temperatureC),
      windDirectionDeg: read(\.windDirectionDeg),
      windSpeedKts: read(\.windSpeedKts)
    )
  }

  private static func makeDataPoint(
    obs: WindsAloftObservation,
    weightLb: Double,
    source: any EquationSource,
    definition: any AircraftDefinition
  ) -> ClimbProfile.DataPoint {
    let altitude = obs.altitudeFt,
      temperature = obs.temperatureC

    // Takeoff climb gradient (no anti-ice variant)
    let takeoffGradient = source.takeoffClimbGradient(
      weight: weightLb,
      altitude: altitude,
      temperature: temperature
    )

    // Enroute obstacle climb gradients
    let obstacleGradient = source.enrouteObstacleClimbGradient(
      weight: weightLb,
      altitude: altitude,
      temperature: temperature,
      iceContaminated: false
    )
    let obstacleGradientIce = source.enrouteObstacleClimbGradient(
      weight: weightLb,
      altitude: altitude,
      temperature: temperature,
      iceContaminated: true
    )

    // Enroute climb gradients
    let enrouteGradient = source.enrouteClimbGradient(
      weight: weightLb,
      altitude: altitude,
      temperature: temperature,
      iceContaminated: false
    )
    let enrouteGradientIce = source.enrouteClimbGradient(
      weight: weightLb,
      altitude: altitude,
      temperature: temperature,
      iceContaminated: true
    )

    // Enroute climb speeds
    let enrouteSpeed = source.enrouteClimbSpeed(
      weight: weightLb,
      altitude: altitude,
      temperature: temperature,
      iceContaminated: false
    )
    let enrouteSpeedIce = source.enrouteClimbSpeed(
      weight: weightLb,
      altitude: altitude,
      temperature: temperature,
      iceContaminated: true
    )

    let obstacleSpeed: Value<Double> =
      definition.obstacleClimbSpeedKIAS.map { .value($0) } ?? .notAvailable

    return ClimbProfile.DataPoint(
      altitudeFt: altitude,
      outsideAirTemperatureC: temperature,
      windDirectionDeg: obs.windDirectionDeg,
      windSpeedKts: obs.windSpeedKts,
      takeoff: .init(
        gradientFtPerNM: takeoffGradient,
        indicatedAirspeedKts: definition.takeoffClimbSpeedKIAS.map { .value($0) }
          ?? source.takeoffClimbSpeed(weight: weightLb, altitude: altitude)
      ),
      enrouteObstacle: .init(
        gradientFtPerNM: obstacleGradient,
        indicatedAirspeedKts: obstacleSpeed
      ),
      enrouteObstacleAntiIce: .init(
        gradientFtPerNM: obstacleGradientIce,
        indicatedAirspeedKts: obstacleSpeed
      ),
      enroute: .init(
        gradientFtPerNM: enrouteGradient,
        indicatedAirspeedKts: enrouteSpeed
      ),
      enrouteAntiIce: .init(
        gradientFtPerNM: enrouteGradientIce,
        indicatedAirspeedKts: enrouteSpeedIce
      )
    )
  }

  /// Evaluates a regression equation at a weight, altitude and temperature.
  ///
  /// `RegressionEquation` already answers in `Value`; this only spells the inputs, which both
  /// sources name identically.
  private static func evaluate(
    _ equation: RegressionEquation,
    weight: Double,
    altitude: Double,
    temperature: Double
  ) -> Value<Double> {
    equation.evaluate(inputs: [
      "weight": weight,
      "altitude": altitude,
      "temperature": temperature
    ])
  }

  /// Evaluates a delta polynomial as `base - max(0, delta)`, or the equation itself where it is
  /// not a delta type.
  ///
  /// Where either half has no answer, neither has the difference — so the refusal is passed out
  /// rather than being allowed to read as a penalty of zero.
  private static func evaluateDelta(
    base: RegressionEquation,
    delta: RegressionEquation,
    weight: Double,
    altitude: Double,
    temperature: Double
  ) -> Value<Double> {
    guard delta.type == .deltaPolynomial else {
      return evaluate(delta, weight: weight, altitude: altitude, temperature: temperature)
    }

    let deltaValue = evaluate(delta, weight: weight, altitude: altitude, temperature: temperature)
    guard let penalty = deltaValue.nominal else { return deltaValue }
    return evaluate(base, weight: weight, altitude: altitude, temperature: temperature)
      - Swift.max(0, penalty)
  }

  /// A winds-aloft observation at a single altitude.
  public struct WindsAloftObservation: Sendable {
    public let altitudeFt: Double
    public let temperatureC: Double
    public let windDirectionDeg: Double  // true, FROM
    public let windSpeedKts: Double

    public init(
      altitudeFt: Double,
      temperatureC: Double,
      windDirectionDeg: Double,
      windSpeedKts: Double
    ) {
      self.altitudeFt = altitudeFt
      self.temperatureC = temperatureC
      self.windDirectionDeg = windDirectionDeg
      self.windSpeedKts = windSpeedKts
    }
  }

  // MARK: - Equation Sources

  /// Abstracts whether we use regression equations or data tables.
  ///
  /// Every figure is a `Value` because either source is entitled to have no answer, and which
  /// kind of no-answer it was matters downstream: conditions outside the charts read differently
  /// to a hole in them, and both read differently to an equation that could not be evaluated.
  private protocol EquationSource {
    func takeoffClimbGradient(weight: Double, altitude: Double, temperature: Double)
      -> Value<Double>
    func takeoffClimbSpeed(weight: Double, altitude: Double) -> Value<Double>
    func enrouteObstacleClimbGradient(
      weight: Double,
      altitude: Double,
      temperature: Double,
      iceContaminated: Bool
    ) -> Value<Double>
    func enrouteClimbGradient(
      weight: Double,
      altitude: Double,
      temperature: Double,
      iceContaminated: Bool
    ) -> Value<Double>
    func enrouteClimbSpeed(
      weight: Double,
      altitude: Double,
      temperature: Double,
      iceContaminated: Bool
    ) -> Value<Double>
  }

  // MARK: - Regression Source

  /// The fitted equations stand behind a figure only inside the charts they were fitted to, and
  /// only where it is a climb: past either edge they extrapolate into gradients the AFM shows
  /// going negative, or invent a climb where the AFM shows a descent. Both read as no answer.
  private struct RegressionSource: EquationSource {
    private let boundsChecker: BoundsChecker
    private let takeoffGradientEq: RegressionEquation
    private let takeoffSpeedEq: RegressionEquation?

    /// Each schedule's equations, keyed by whether it is the ice-contaminated one.
    private let obstacleGradientEqs: [Bool: RegressionEquation]
    private let enrouteGradientEqs: [Bool: RegressionEquation]
    private let enrouteSpeedEqs: [Bool: RegressionEquation]

    init(data: AircraftData, definition: any AircraftDefinition) throws {
      boundsChecker = try BoundsChecker(data: data, definition: definition)
      let loader = RegressionEquationLoader(data: data),
        schedules = schedules(of: definition)
      takeoffGradientEq = try loader.loadTakeoffClimbGradientEquation()
      takeoffSpeedEq =
        definition.takeoffClimbSpeedKIAS == nil ? try loader.loadTakeoffClimbSpeedEquation() : nil
      obstacleGradientEqs = try schedules.reduce(into: [:]) { equations, schedule in
        guard schedule.names.obstacleTableDirectory != nil else { return }
        equations[schedule.iceContaminated] =
          try loader.loadEnrouteObstacleClimbGradientEquation(names: schedule.names)
      }
      enrouteGradientEqs = try schedules.reduce(into: [:]) { equations, schedule in
        equations[schedule.iceContaminated] =
          try loader.loadEnrouteClimbGradientEquation(names: schedule.names)
      }
      enrouteSpeedEqs = try schedules.reduce(into: [:]) { equations, schedule in
        equations[schedule.iceContaminated] =
          try loader.loadEnrouteClimbSpeedEquation(names: schedule.names)
      }
    }

    /// Passes on a gradient only where it is a climb.
    private static func climbOnly(_ gradient: Value<Double>) -> Value<Double> {
      guard let nominal = gradient.nominal else { return gradient }
      return nominal > 0 ? gradient : .notAvailable
    }

    func takeoffClimbGradient(weight: Double, altitude: Double, temperature: Double)
      -> Value<Double>
    {
      guard
        boundsChecker.takeoffClimbBoundsStatus(
          weight: weight,
          altitude: altitude,
          temperature: temperature
        ) == .withinBounds
      else { return .notAvailable }
      return Self.climbOnly(
        evaluate(takeoffGradientEq, weight: weight, altitude: altitude, temperature: temperature)
      )
    }

    func takeoffClimbSpeed(weight: Double, altitude: Double) -> Value<Double> {
      guard let takeoffSpeedEq else { return .notAvailable }
      return takeoffSpeedEq.evaluate(inputs: ["weight": weight, "altitude": altitude])
    }

    func enrouteObstacleClimbGradient(
      weight: Double,
      altitude: Double,
      temperature: Double,
      iceContaminated: Bool
    ) -> Value<Double> {
      guard let obstacleGradientNormalEq = obstacleGradientEqs[false],
        let obstacleGradientEq = obstacleGradientEqs[iceContaminated]
      else { return .notAvailable }
      guard
        boundsChecker.obstacleClimbBoundsStatus(
          weight: weight,
          altitude: altitude,
          temperature: temperature,
          iceContaminated: iceContaminated
        ) == .withinBounds
      else { return .notAvailable }
      let gradient =
        iceContaminated
        ? evaluateDelta(
          base: obstacleGradientNormalEq,
          delta: obstacleGradientEq,
          weight: weight,
          altitude: altitude,
          temperature: temperature
        )
        : evaluate(
          obstacleGradientNormalEq,
          weight: weight,
          altitude: altitude,
          temperature: temperature
        )
      return Self.climbOnly(gradient)
    }

    func enrouteClimbGradient(
      weight: Double,
      altitude: Double,
      temperature: Double,
      iceContaminated: Bool
    ) -> Value<Double> {
      guard
        isWithinEnrouteCharts(
          .gradient,
          weight: weight,
          altitude: altitude,
          temperature: temperature,
          iceContaminated: iceContaminated
        )
      else { return .notAvailable }
      guard let equation = enrouteGradientEqs[iceContaminated] else { return .notAvailable }
      return Self.climbOnly(
        evaluate(equation, weight: weight, altitude: altitude, temperature: temperature)
      )
    }

    func enrouteClimbSpeed(
      weight: Double,
      altitude: Double,
      temperature: Double,
      iceContaminated: Bool
    ) -> Value<Double> {
      guard
        isWithinEnrouteCharts(
          .speed,
          weight: weight,
          altitude: altitude,
          temperature: temperature,
          iceContaminated: iceContaminated
        )
      else { return .notAvailable }
      guard let equation = enrouteSpeedEqs[iceContaminated] else { return .notAvailable }
      return evaluate(equation, weight: weight, altitude: altitude, temperature: temperature)
    }

    private func isWithinEnrouteCharts(
      _ quantity: BoundsChecker.EnrouteClimbQuantity,
      weight: Double,
      altitude: Double,
      temperature: Double,
      iceContaminated: Bool
    ) -> Bool {
      boundsChecker.enrouteClimbBoundsStatus(
        for: quantity,
        weight: weight,
        altitude: altitude,
        temperature: temperature,
        iceContaminated: iceContaminated
      ) == .withinBounds
    }
  }

  // MARK: - Tabular Source

  private struct TabularSource: EquationSource {
    private let takeoffGradientTable: DataTable
    private let takeoffSpeedTable: DataTable?

    /// Each schedule's tables, keyed by whether it is the ice-contaminated one.
    private let obstacleGradientTables: [Bool: DataTable]
    private let enrouteGradientTables: [Bool: DataTable]
    private let enrouteSpeedTables: [Bool: DataTable]

    init(data: AircraftData, definition: any AircraftDefinition) throws {
      let tableLoader = DataTableLoader(data: data),
        schedules = schedules(of: definition)

      takeoffGradientTable = try tableLoader.loadTakeoffClimbGradientData()
      takeoffSpeedTable =
        definition.takeoffClimbSpeedKIAS == nil
        ? try tableLoader.loadTakeoffClimbSpeedData() : nil
      obstacleGradientTables = try schedules.reduce(into: [:]) { tables, schedule in
        tables[schedule.iceContaminated] =
          try tableLoader.loadEnrouteObstacleClimbGradientData(names: schedule.names)
      }
      enrouteGradientTables = try schedules.reduce(into: [:]) { tables, schedule in
        tables[schedule.iceContaminated] =
          try tableLoader.loadEnrouteClimbGradientData(names: schedule.names)
      }
      enrouteSpeedTables = try schedules.reduce(into: [:]) { tables, schedule in
        tables[schedule.iceContaminated] =
          try tableLoader.loadEnrouteClimbSpeedData(names: schedule.names)
      }
    }

    /// Reads a table, and asks for no clamping.
    ///
    /// `DataTable` can hold an input at its low edge and hand back that edge's figure as the
    /// `clamped` payload of an offscale result, which is conservative and honest. Nothing here
    /// can carry it: the profile is read through `gradient(at:profile:)`, which answers in a bare
    /// `Double`, so a substituted figure would arrive at the climb integration indistinguishable
    /// from one the chart covered. Until a readout can say a figure came from the edge of a
    /// chart, the table is asked only for what it actually holds.
    private func tableValue(_ table: DataTable, inputs: [TableInput: Double]) -> Value<Double> {
      table.value(for: inputs)
    }

    func takeoffClimbGradient(weight: Double, altitude: Double, temperature: Double)
      -> Value<Double>
    {
      tableValue(
        takeoffGradientTable,
        inputs: [.weight: weight, .altitude: altitude, .temperature: temperature]
      )
    }

    func takeoffClimbSpeed(weight: Double, altitude: Double) -> Value<Double> {
      guard let takeoffSpeedTable else { return .notAvailable }
      return tableValue(takeoffSpeedTable, inputs: [.weight: weight, .altitude: altitude])
    }

    func enrouteObstacleClimbGradient(
      weight: Double,
      altitude: Double,
      temperature: Double,
      iceContaminated: Bool
    ) -> Value<Double> {
      guard let table = obstacleGradientTables[iceContaminated] else { return .notAvailable }
      return tableValue(
        table,
        inputs: [.weight: weight, .altitude: altitude, .temperature: temperature]
      )
    }

    func enrouteClimbGradient(
      weight: Double,
      altitude: Double,
      temperature: Double,
      iceContaminated: Bool
    ) -> Value<Double> {
      guard let table = enrouteGradientTables[iceContaminated] else { return .notAvailable }
      return tableValue(
        table,
        inputs: [.weight: weight, .altitude: altitude, .temperature: temperature]
      )
    }

    func enrouteClimbSpeed(
      weight: Double,
      altitude: Double,
      temperature: Double,
      iceContaminated: Bool
    ) -> Value<Double> {
      guard let table = enrouteSpeedTables[iceContaminated] else { return .notAvailable }
      return tableValue(
        table,
        inputs: [.weight: weight, .altitude: altitude, .temperature: temperature]
      )
    }
  }
}

extension ClimbProfileGenerator {
  /// The en route climb schedules an aircraft's manual has, normal first.
  fileprivate static func schedules(of definition: any AircraftDefinition)
    -> [(iceContaminated: Bool, names: EnrouteClimbNames)]
  {
    [false, true].compactMap { iceContaminated in
      definition.enrouteClimbNames(iceContaminated: iceContaminated).map { (iceContaminated, $0) }
    }
  }
}
