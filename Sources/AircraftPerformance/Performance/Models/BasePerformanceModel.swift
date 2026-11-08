public import Foundation

/// Base implementation of ``PerformanceModel`` with common functionality.
///
/// ``BasePerformanceModel`` provides shared infrastructure for performance calculations
/// including input data storage and common derived values (headwind, gradient, etc.).
///
/// ## Subclassing Notes
///
/// Distance properties (``takeoffRunFt``, ``takeoffDistanceFt``, ``landingRunFt``,
/// ``landingDistanceFt``) are computed via ``computeDistance(for:)`` and do not need
/// to be overridden. Instead, subclasses must override:
/// - ``baseValue(for:)`` - The unadjusted distance from equations or table lookup
/// - ``applyAdjustment(_:to:target:)`` - How to apply one adjustment using model-specific method
///
/// Non-distance properties must still be overridden:
/// - ``takeoffClimbGradientFtNM``
/// - ``takeoffClimbRateFtMin``
/// - ``VrefKts``
open class BasePerformanceModel: PerformanceModel {

  // MARK: - Properties

  public let conditions: Conditions
  public let configuration: Configuration
  public let runway: RunwayInput
  public let notam: NOTAMInput?

  // MARK: - Adjustment Generator

  /// How the aircraft's manual combines its corrections. Set by subclass initializers.
  var correctionScheme = CorrectionScheme.multiplicative

  /// Whether the aircraft's manual corrects for runway contamination. Set by subclass
  /// initializers.
  var correctsContamination = true

  var adjustmentGenerator: PerformanceAdjustmentGenerator {
    PerformanceAdjustmentGenerator(
      headwind: headwind,
      tailwind: tailwind,
      uphill: uphill,
      downhill: downhill,
      isTurf: runway.isTurf,
      contamination: notam?.contamination,
      scheme: correctionScheme,
      correctsContamination: correctsContamination,
      airConditionerOn: configuration.airConditionerOn
    )
  }

  // MARK: - Distance Properties (computed via computeDistance)

  open var takeoffRunFt: Value<Double> {
    computeDistance(for: .takeoffRun).value
  }

  open var takeoffDistanceFt: Value<Double> {
    computeDistance(for: .takeoffDistance).value
  }

  open var landingRunFt: Value<Double> {
    computeDistance(for: .landingRun).value
  }

  open var landingDistanceFt: Value<Double> {
    computeDistance(for: .landingDistance).value
  }

  // MARK: - Non-Distance Properties (to be overridden)

  open var takeoffClimbGradientFtNM: Value<Double> {
    fatalError("Subclasses must implement takeoffClimbGradientFtNM")
  }

  open var takeoffClimbRateFtMin: Value<Double> {
    fatalError("Subclasses must implement takeoffClimbRateFtMin")
  }

  open var VrefKts: Value<Double> {
    fatalError("Subclasses must implement VrefKts")
  }

  open var meetsGoAroundClimbGradient: Value<Bool> {
    .notAvailable
  }

  open var balkedLandingClimbGradientFtNM: Value<Double> { .notAvailable }
  open var balkedLandingClimbRateFtMin: Value<Double> { .notAvailable }

  open var enrouteClimbGradientFtNM: Value<Double> { .notAvailable }
  open var enrouteClimbRateFtMin: Value<Double> { .notAvailable }
  open var enrouteClimbSpeedKIAS: Value<Double> { .notAvailable }

  open var takeoffInputsOffscaleLow: Bool { false }
  open var takeoffInputsOffscaleHigh: Bool { false }
  open var landingInputsOffscaleLow: Bool { false }
  open var landingInputsOffscaleHigh: Bool { false }

  // MARK: - Contamination Calculator

  /// Calculator for runway contamination effects. Set by subclass initializers.
  var contaminationCalculator: ContaminationCalculator?

  // MARK: - Common Input Properties

  /// Aircraft weight in pounds.
  var weight: Double {
    configuration.weight.converted(to: .pounds).value
  }

  /// Temperature in Celsius, or ISA if not reported.
  var temperature: Double {
    conditions.temperature?.converted(to: .celsius).value ?? isaTemperature(altitudeFt: altitude)
  }

  /// The pressure altitude the tables and equations are read at, in feet.
  var altitude: Double {
    pressureAltitude.converted(to: .feet).value
  }

  /// The pressure altitude at the runway, from its elevation and the altimeter setting.
  ///
  /// Without an altimeter setting this is the runway elevation; ``Conditions/hasAltimeterSetting``
  /// says which.
  public var pressureAltitude: Measurement<UnitLength> {
    conditions.pressureAltitude(elevation: runway.elevation)
  }

  /// Headwind component in knots (positive = headwind, negative = tailwind).
  var headwindComponent: Double {
    runway.headwind(conditions: conditions).converted(to: .knots).value
  }

  /// Headwind in knots (zero if tailwind).
  var headwind: Double {
    headwindComponent > 0 ? headwindComponent : 0
  }

  /// Tailwind in knots (zero if headwind).
  var tailwind: Double {
    headwindComponent < 0 ? -headwindComponent : 0
  }

  /// Runway gradient as a fraction (positive = uphill).
  var gradient: Double {
    Double(runway.gradient)
  }

  /// Uphill gradient (zero if downhill).
  var uphill: Double {
    gradient > 0 ? gradient : 0
  }

  /// Downhill gradient as positive value (zero if uphill).
  var downhill: Double {
    gradient < 0 ? -gradient : 0
  }

  // MARK: - Initializer

  /**
   * Creates a base performance model with the given inputs.
   *
   * - Parameters:
   *   - conditions: Atmospheric conditions for the calculation.
   *   - configuration: Aircraft weight and flap configuration.
   *   - runway: Runway data snapshot.
   *   - notam: Active NOTAM restrictions, if any.
   */
  public init(
    conditions: Conditions,
    configuration: Configuration,
    runway: RunwayInput,
    notam: NOTAMInput?
  ) {
    self.conditions = conditions
    self.configuration = configuration
    self.runway = runway
    self.notam = notam
  }

  // MARK: - Distance Computation

  /// Computes the adjusted distance and breakdown for a given target.
  ///
  /// This method calls ``baseValue(for:)`` to get the unadjusted distance, then
  /// iterates through all applicable adjustments (determined by the adjustment generator),
  /// calling ``applyAdjustment(_:to:target:)`` for each one.
  open func computeDistance(for target: DistanceTarget)
    -> (value: Value<Double>, breakdown: DistanceBreakdown)
  {
    let generator = adjustmentGenerator,
      baseFt = baseValue(for: target)
    var value = baseFt,
      adjustments: [PerformanceAdjustment] = []

    func apply(_ kind: AdjustmentKind) {
      let (newValue, multiplier) = applyAdjustment(kind, to: value, target: target)
      value = newValue
      adjustments.append(.init(kind: kind, multiplier: multiplier, resultFt: value))
    }

    let kinds = generator.adjustmentKinds(for: target)
    kinds.filter { $0 != .airConditioner }.forEach(apply)
    if target.isTotalDistance, correctionScheme == .groundRollReferenced {
      for (kind, addition) in groundRunAdditions(for: target, generator: generator) {
        let previous = value
        value += addition
        adjustments.append(
          .init(
            kind: kind,
            multiplier: effectiveMultiplier(from: previous, to: value),
            resultFt: value
          )
        )
      }
    }
    kinds.filter { $0 == .airConditioner }.forEach(apply)

    return (value, .init(baseFt: baseFt, adjustments: adjustments))
  }

  /// The feet each ground run correction that carries to the total distance adds to the ground
  /// run, applying the ground run's corrections in turn.
  private func groundRunAdditions(
    for target: DistanceTarget,
    generator: PerformanceAdjustmentGenerator
  ) -> [(kind: AdjustmentKind, addition: Value<Double>)] {
    let groundRun = target.groundRun
    var run = baseValue(for: groundRun),
      additions: [(kind: AdjustmentKind, addition: Value<Double>)] = []
    for kind in generator.adjustmentKinds(for: groundRun) where kind != .airConditioner {
      let corrected = applyAdjustment(kind, to: run, target: groundRun).result
      if generator.isCarriedToTotalDistance(kind) { additions.append((kind, corrected - run)) }
      run = corrected
    }
    return additions
  }

  /// Returns the base (unadjusted) distance for the given target.
  ///
  /// Subclasses must override this to provide the value from regression equations or table lookup.
  open func baseValue(for target: DistanceTarget) -> Value<Double> {
    assertionFailure("\(Self.self) must override baseValue(for: \(target))")
    return .notAvailable
  }

  /// Applies a single adjustment to a distance value.
  ///
  /// The default implementation routes contamination to ``applyContamination(_:to:target:)``
  /// and all other adjustments through ``adjustmentMultiplier(for:target:)``.
  open func applyAdjustment(
    _ kind: AdjustmentKind,
    to value: Value<Double>,
    target: DistanceTarget
  ) -> (result: Value<Double>, effectiveMultiplier: Double) {
    switch kind {
      case .contamination(let contamination):
        return applyContamination(contamination, to: value, target: target)
      case .airConditioner:
        let result = value + (correctionFactor(.airConditioner, for: target) ?? .notAvailable)
        return (result, effectiveMultiplier(from: value, to: result))
      default:
        let multiplier = adjustmentMultiplier(for: kind, target: target)
        var result = value
        result *= multiplier
        return (result, multiplier.nominal ?? 1.0)
    }
  }

  /// Returns the multiplicative adjustment factor for a given adjustment kind and target.
  ///
  /// The factor comes from ``correctionFactor(_:for:)``: a regression model evaluates it from an
  /// equation, a tabular model interpolates it from a table. Slope corrections lengthen a takeoff
  /// run uphill and a landing run downhill.
  open func adjustmentMultiplier(
    for kind: AdjustmentKind,
    target: DistanceTarget
  ) -> Value<Double> {
    guard let correction = CorrectionFactor(kind),
      let factor = correctionFactor(correction, for: target)
    else {
      assertionFailure("\(Self.self) has no factor for \(kind) on \(target)")
      return .notAvailable
    }
    switch kind {
      case .headwind:
        return PerformanceAdjustments.windAdjustment(factor: factor, wind: -headwind)
      case .tailwind:
        return PerformanceAdjustments.windAdjustment(factor: factor, wind: tailwind)
      case .uphillGradient:
        return PerformanceAdjustments.gradientAdjustment(
          factor: factor,
          gradient: target.isLanding ? -uphill : uphill
        )
      case .downhillGradient:
        return PerformanceAdjustments.gradientAdjustment(
          factor: factor,
          gradient: target.isLanding ? downhill : -downhill
        )
      default:
        return PerformanceAdjustments.surfaceAdjustment(factor: factor)
    }
  }

  /// A correction's factor for a distance, or `nil` if the aircraft's data has none.
  ///
  /// Subclasses override this to read the factor from their own data.
  func correctionFactor(_: CorrectionFactor, for _: DistanceTarget) -> Value<Double>? { nil }

  /// Applies a contamination adjustment to a distance value.
  ///
  /// Uses the contamination calculator for additive contamination effects
  /// on landing distances.
  open func applyContamination(
    _ contamination: Contamination,
    to value: Value<Double>,
    target: DistanceTarget
  ) -> (result: Value<Double>, effectiveMultiplier: Double) {
    guard let contaminationCalculator else {
      return (value, 1.0)
    }
    let newValue: Value<Double>
    switch target {
      case .landingRun:
        newValue = contaminationCalculator.landingRunContaminationAddition(
          distance: value,
          contamination: contamination,
          isGroovedOrPFC: runway.isGroovedOrPFC
        )
      case .landingDistance:
        newValue = contaminationCalculator.landingDistanceContaminationAddition(
          landingDistance: value,
          landingRun: baseValue(for: .landingRun),
          contamination: contamination,
          isGroovedOrPFC: runway.isGroovedOrPFC
        )
      default:
        return (value, 1.0)
    }
    return (newValue, effectiveMultiplier(from: value, to: newValue))
  }

  /// Computes the effective multiplier between two values.
  func effectiveMultiplier(from oldValue: Value<Double>, to newValue: Value<Double>) -> Double {
    guard let old = oldValue.nominal, old > 0, let new = newValue.nominal else {
      return 1.0
    }
    return new / old
  }
}
