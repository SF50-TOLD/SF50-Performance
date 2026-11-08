import Foundation

/// Regression-based performance model for any aircraft with a data package.
///
/// ``RegressionPerformanceModel`` calculates takeoff and landing performance using
/// polynomial regression equations derived from AFM table data. The `aircraft`
/// parameter drives which JSON data files get loaded (via the
/// ``RegressionEquationLoader``), selecting the appropriate coefficients and
/// adjustment factors for each configuration.
///
/// ## Bounds Checking
///
/// Regression models can extrapolate beyond the original AFM data range, but results
/// outside the bounds may be less reliable. Input ranges are validated against
/// the tabular model limits via ``BoundsChecker``.
final class RegressionPerformanceModel: BasePerformanceModel {

  // MARK: - Stored Properties

  private let boundsChecker: BoundsChecker
  private let landingTables: LandingTables

  // Takeoff
  private let takeoffRunEquation: RegressionEquation
  private let takeoffDistanceEquation: RegressionEquation
  private let takeoffClimbGradientEquation: RegressionEquation
  private let takeoffClimbRateEquation: RegressionEquation

  // En Route Climb, on the schedule the configuration flies
  private let enrouteClimbGradientEquation: RegressionEquation?
  private let enrouteClimbRateEquation: RegressionEquation?
  private let enrouteClimbSpeedEquation: RegressionEquation?

  // Landing, for the flap setting's tables
  private let landingRunEquation: RegressionEquation?
  private let landingDistanceEquation: RegressionEquation?

  // Balked Landing
  private let balkedLandingClimbGradientEquation: RegressionEquation?
  private let balkedLandingClimbRateEquation: RegressionEquation?

  // Go-Around
  private let hasGoAroundClassifier: Bool
  private let goAroundEquation: RegressionEquation?

  // VREF
  private let vrefEquation: RegressionEquation?

  /// Each correction's equation, by the distance it corrects.
  private let correctionFactorEquations: [DistanceTarget: [CorrectionFactor: RegressionEquation]]

  // MARK: - Bounds Checking

  override var takeoffInputsOffscaleLow: Bool {
    boundsChecker.takeoffBoundsStatus(
      weight: weight,
      altitude: altitude,
      temperature: temperature
    ) == .belowMinimum
  }

  override var takeoffInputsOffscaleHigh: Bool {
    boundsChecker.takeoffBoundsStatus(
      weight: weight,
      altitude: altitude,
      temperature: temperature
    ) == .aboveMaximum
  }

  override var landingInputsOffscaleLow: Bool {
    boundsChecker.landingBoundsStatus(
      weight: weight,
      altitude: altitude,
      temperature: temperature,
      flapSetting: configuration.flapSetting
    ) == .belowMinimum
  }

  override var landingInputsOffscaleHigh: Bool {
    boundsChecker.landingBoundsStatus(
      weight: weight,
      altitude: altitude,
      temperature: temperature,
      flapSetting: configuration.flapSetting
    ) == .aboveMaximum
  }

  // MARK: - VREF

  override var VrefKts: Value<Double> {
    vrefEquation.map(evaluate) ?? .notAvailable
  }

  // MARK: - Takeoff Climb

  override var takeoffClimbGradientFtNM: Value<Double> {
    evaluate(takeoffClimbGradientEquation)
  }

  override var takeoffClimbRateFtMin: Value<Double> {
    evaluate(takeoffClimbRateEquation)
  }

  // MARK: - En Route Climb

  override var enrouteClimbGradientFtNM: Value<Double> {
    evaluateEnrouteClimb(enrouteClimbGradientEquation, for: .gradient)
  }

  override var enrouteClimbRateFtMin: Value<Double> {
    evaluateEnrouteClimb(enrouteClimbRateEquation, for: .rate)
  }

  override var enrouteClimbSpeedKIAS: Value<Double> {
    evaluateEnrouteClimb(enrouteClimbSpeedEquation, for: .speed)
  }

  // MARK: - Balked Landing Climb

  override var balkedLandingClimbGradientFtNM: Value<Double> {
    balkedLandingClimbGradientEquation.map(evaluate) ?? .notAvailable
  }

  override var balkedLandingClimbRateFtMin: Value<Double> {
    balkedLandingClimbRateEquation.map(evaluate) ?? .notAvailable
  }

  // MARK: - Go-Around Climb Gradient

  /// Whether the go-around climb gradient is met, from the classifier fit to this configuration's
  /// landing table.
  ///
  /// The AFM's ice-contaminated landing table prints every cell, so in icing the gradient is met
  /// wherever that table reaches. Past its hot or high edge the AFM says nothing, and the model
  /// answers as the tabular one does, that the gradient is not met.
  override var meetsGoAroundClimbGradient: Value<Bool> {
    guard hasGoAroundClassifier else { return .notAvailable }
    guard let goAroundEquation else { return .value(!landingInputsOffscaleHigh) }
    return evaluateBool(goAroundEquation)
  }

  // MARK: - Landing Base Values

  private var landingRunBaseFt: Value<Double> {
    guard landingTables.hasGroundRun, let landingRunEquation else { return .notAvailable }
    return evaluate(landingRunEquation)
  }

  private var landingDistanceBaseFt: Value<Double> {
    guard let landingDistanceEquation else { return .notAvailable }
    return evaluate(landingDistanceEquation) * (landingTables.totalDistanceFactor ?? 1)
  }

  // MARK: - Initializer

  init(
    conditions: Conditions,
    configuration: Configuration,
    runway: RunwayInput,
    notam: NOTAMInput?,
    aircraft: Aircraft
  ) throws {
    let definition = aircraft.definition,
      capabilities = definition.capabilities,
      data = try definition.data()
    let landingTables = definition.landingTables(for: configuration.flapSetting)
    self.landingTables = landingTables
    let hasLandingFigures = definition.landingFlapSettings.contains(configuration.flapSetting)
    self.boundsChecker = try BoundsChecker(data: data, definition: definition)

    let loader = RegressionEquationLoader(data: data)

    takeoffRunEquation = try loader.loadTakeoffRunEquation()
    takeoffDistanceEquation = try loader.loadTakeoffDistanceEquation()
    takeoffClimbGradientEquation = try loader.loadTakeoffClimbGradientEquation()
    takeoffClimbRateEquation = try loader.loadTakeoffClimbRateEquation()

    let enrouteNames = definition.enrouteClimbNames(iceContaminated: configuration.iceProtection)
    enrouteClimbGradientEquation = try enrouteNames.map {
      try loader.loadEnrouteClimbGradientEquation(names: $0)
    }
    enrouteClimbRateEquation = try enrouteNames.map {
      try loader.loadEnrouteClimbRateEquation(names: $0)
    }
    enrouteClimbSpeedEquation = try enrouteNames.map {
      try loader.loadEnrouteClimbSpeedEquation(names: $0)
    }

    landingRunEquation =
      hasLandingFigures && landingTables.hasGroundRun
      ? try loader.loadLandingRunEquation(flapSetting: landingTables.flapSetting) : nil
    landingDistanceEquation =
      hasLandingFigures
      ? try loader.loadLandingDistanceEquation(flapSetting: landingTables.flapSetting) : nil

    let balkedLanding = capabilities.contains(.balkedLandingClimb)
    balkedLandingClimbGradientEquation =
      balkedLanding ? try loader.loadBalkedLandingClimbGradientEquation() : nil
    balkedLandingClimbRateEquation =
      balkedLanding ? try loader.loadBalkedLandingClimbRateEquation() : nil

    hasGoAroundClassifier = capabilities.contains(.goAroundClimbGradient)
    goAroundEquation =
      hasGoAroundClassifier && hasLandingFigures
      ? try loader.loadGoAroundClimbGradientEquation(flapSetting: configuration.flapSetting) : nil
    vrefEquation =
      capabilities.contains(.vref) && hasLandingFigures
      ? try loader.loadVrefEquation(flapSetting: configuration.flapSetting) : nil

    correctionFactorEquations = DistanceTarget.allCases.reduce(into: [:]) { equations, target in
      equations[target] = CorrectionFactor.allCases.reduce(into: [:]) { factors, factor in
        factors[factor] = loader.correctionFactorEquation(
          factor,
          for: target,
          landingFlapSetting: landingTables.flapSetting
        )
      }
    }

    super.init(conditions: conditions, configuration: configuration, runway: runway, notam: notam)
    correctionScheme = definition.correctionScheme
    correctsContamination = capabilities.contains(.contamination)
    if correctsContamination {
      contaminationCalculator = try ContaminationCalculator(data: data, usesTables: false)
    }
  }

  // MARK: - Base Values

  override func baseValue(for target: DistanceTarget) -> Value<Double> {
    switch target {
      case .takeoffRun: evaluate(takeoffRunEquation)
      case .takeoffDistance: evaluate(takeoffDistanceEquation)
      case .landingRun: landingRunBaseFt
      case .landingDistance: landingDistanceBaseFt
    }
  }

  // MARK: - Correction Factors

  override func correctionFactor(_ factor: CorrectionFactor, for target: DistanceTarget)
    -> Value<Double>?
  {
    correctionFactorEquations[target]?[factor].map(evaluate)
  }
}

// MARK: - Equation Evaluation

extension RegressionPerformanceModel {

  /// Evaluates a regression equation with the current input conditions.
  func evaluate(_ equation: RegressionEquation) -> Value<Double> {
    equation.evaluate(inputs: [
      "weight": weight,
      "altitude": altitude,
      "temperature": temperature
    ])
  }

  /**
   * Evaluates an en route climb equation, refusing outside the envelope its table covers.
   *
   * Extrapolation is the regression model's business, but these fits turn once past the conditions
   * they were made from: at temperatures a climb can be planned in, the ice-contaminated
   * gradient reports a descent. A figure like that is not an estimate the model can stand behind,
   * so it reports nothing instead — with a sign check behind the envelope check, since a
   * non-positive climb is nonsense wherever it comes from.
   */
  private func evaluateEnrouteClimb(
    _ equation: RegressionEquation?,
    for quantity: BoundsChecker.EnrouteClimbQuantity
  ) -> Value<Double> {
    guard let equation else { return .notAvailable }
    let status = boundsChecker.enrouteClimbBoundsStatus(
      for: quantity,
      weight: weight,
      altitude: altitude,
      temperature: temperature,
      iceContaminated: configuration.iceProtection
    )
    guard status == .withinBounds else { return .notAvailable }

    let result = evaluate(equation)
    guard let climb = result.nominal, climb > 0 else { return .notAvailable }
    return result
  }

  /// Evaluates a logistic equation with the current input conditions.
  func evaluateBool(_ equation: RegressionEquation) -> Value<Bool> {
    equation.evaluateBool(inputs: [
      "weight": weight,
      "altitude": altitude,
      "temperature": temperature
    ])
  }
}
