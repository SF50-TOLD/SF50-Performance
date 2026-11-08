import Foundation

/// Tabular performance model for any aircraft with a data package.
///
/// ``TabularPerformanceModel`` calculates takeoff and landing performance using
/// direct interpolation from digitized AFM table data. The `aircraft` parameter
/// drives which data files are loaded.
final class TabularPerformanceModel: BasePerformanceModel {

  // MARK: - Properties

  private static let seaLevelFt = 0.0

  private let limitations: AircraftLimitations
  private let landingTables: LandingTables
  private let takeoffRunData: DataTable
  private let takeoffDistanceData: DataTable
  private let takeoffClimbGradientData: DataTable
  private let takeoffClimbRateData: DataTable
  private let vrefData: DataTable?
  private let landingRunData: DataTable?
  private let landingDistanceData: DataTable?
  private let balkedLandingClimbGradientData: DataTable?
  private let balkedLandingClimbRateData: DataTable?

  /// Each correction's table, by the distance it corrects.
  private let correctionFactorData: [DistanceTarget: [CorrectionFactor: DataTable]]

  private let enrouteClimbGradientData: DataTable?
  private let enrouteClimbRateData: DataTable?
  private let enrouteClimbSpeedData: DataTable?

  // MARK: - Non-Distance Outputs

  override var takeoffClimbGradientFtNM: Value<Double> {
    atApprovedAirport(for: .takeoff) { takeoffClimbGradientData.value(for: chartInputs) }
  }

  override var takeoffClimbRateFtMin: Value<Double> {
    atApprovedAirport(for: .takeoff) { takeoffClimbRateData.value(for: chartInputs) }
  }

  override var VrefKts: Value<Double> {
    vrefData?.value(for: [.weight: weight]) ?? .notAvailable
  }

  /// Whether the AFM's go-around climb gradient is met.
  ///
  /// The tables publish a landing distance only where the gradient is met, so a distance the model
  /// can stand behind answers yes and one off the top of the tables answers no. Where the model has
  /// no distance at all it has no answer either, and says so rather than assuming the gradient
  /// holds.
  override var meetsGoAroundClimbGradient: Value<Bool> {
    guard hasGoAroundClassifier else { return .notAvailable }
    switch landingDistanceFt {
      case .value, .valueWithUncertainty: return .value(true)
      case .offscaleHigh: return .value(false)
      case .offscaleLow(let clamped): return clamped == nil ? .notAvailable : .value(true)
      case .invalid: return .invalid
      case .notAvailable: return .notAvailable
      case .notAuthorized: return .notAuthorized
    }
  }

  override var balkedLandingClimbGradientFtNM: Value<Double> {
    balkedLandingClimbGradientData?.value(for: chartInputs) ?? .notAvailable
  }

  override var balkedLandingClimbRateFtMin: Value<Double> {
    balkedLandingClimbRateData?.value(for: chartInputs) ?? .notAvailable
  }

  private let hasGoAroundClassifier: Bool

  // MARK: - En Route Climb

  override var enrouteClimbGradientFtNM: Value<Double> {
    enrouteClimbGradientData?.value(for: enrouteInputs) ?? .notAvailable
  }

  override var enrouteClimbRateFtMin: Value<Double> {
    enrouteClimbRateData?.value(for: enrouteInputs) ?? .notAvailable
  }

  override var enrouteClimbSpeedKIAS: Value<Double> {
    enrouteClimbSpeedData?.value(for: enrouteInputs) ?? .notAvailable
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
      data = try definition.data(),
      loader = DataTableLoader(data: data)
    let landingTables = definition.landingTables(for: configuration.flapSetting)
    self.landingTables = landingTables
    let landingPrefix = loader.tablePrefix(for: landingTables.flapSetting),
      hasLandingFigures = definition.landingFlapSettings.contains(configuration.flapSetting)

    limitations = definition.limitations

    takeoffRunData = try loader.loadTakeoffRunData()
    takeoffDistanceData = try loader.loadTakeoffDistanceData()
    takeoffClimbGradientData = try loader.loadTakeoffClimbGradientData()
    takeoffClimbRateData = try loader.loadTakeoffClimbRateData()

    vrefData =
      capabilities.contains(.vref) && hasLandingFigures
      ? try loader.loadVrefData(vrefPrefix: loader.tablePrefix(for: configuration.flapSetting))
      : nil
    hasGoAroundClassifier = capabilities.contains(.goAroundClimbGradient)

    landingRunData =
      hasLandingFigures ? try loader.loadLandingRunData(landingPrefix: landingPrefix) : nil
    landingDistanceData =
      hasLandingFigures ? try loader.loadLandingDistanceData(landingPrefix: landingPrefix) : nil

    let balkedLanding = capabilities.contains(.balkedLandingClimb)
    balkedLandingClimbGradientData =
      balkedLanding ? try loader.loadBalkedLandingClimbGradientData() : nil
    balkedLandingClimbRateData = balkedLanding ? try loader.loadBalkedLandingClimbRateData() : nil

    correctionFactorData = DistanceTarget.allCases.reduce(into: [:]) { tables, target in
      tables[target] = CorrectionFactor.allCases.reduce(into: [:]) { factors, factor in
        factors[factor] = loader.correctionFactorTable(
          factor,
          for: target,
          landingFlapSetting: landingTables.flapSetting
        )
      }
    }

    let enrouteNames = definition.enrouteClimbNames(iceContaminated: configuration.iceProtection)
    enrouteClimbGradientData = try enrouteNames.map {
      try loader.loadEnrouteClimbGradientData(names: $0)
    }
    enrouteClimbRateData = try enrouteNames.map { try loader.loadEnrouteClimbRateData(names: $0) }
    enrouteClimbSpeedData = try enrouteNames.map { try loader.loadEnrouteClimbSpeedData(names: $0) }

    super.init(conditions: conditions, configuration: configuration, runway: runway, notam: notam)
    correctionScheme = definition.correctionScheme
    correctsContamination = capabilities.contains(.contamination)
    if correctsContamination {
      contaminationCalculator = try ContaminationCalculator(data: data, usesTables: true)
    }
  }

  // MARK: - Base Values

  /// The AFM's distance for the current conditions, before any adjustment.
  ///
  /// Distance grows with weight, altitude and temperature alike, so an input below the tabulated
  /// range is held at the bottom of it: the figure that comes back is longer than the truth, which
  /// is the side to err on. It comes back as a clamped offscale figure rather than a definite one,
  /// so that the readout can say the AFM never covered the conditions asked for. Above the range,
  /// where holding the input would understate the distance, no figure is offered at all.
  override func baseValue(for target: DistanceTarget) -> Value<Double> {
    atApprovedAirport(for: target.isLanding ? .landing : .takeoff) {
      switch target {
        case .takeoffRun:
          takeoffRunData.value(for: chartInputs, clamping: .clampLow)
        case .takeoffDistance:
          takeoffDistanceData.value(for: chartInputs, clamping: .clampLow)
        case .landingRun:
          landingTables.hasGroundRun
            ? landingRunData?.value(for: chartInputs, clamping: .clampLow) ?? .notAvailable
            : .notAvailable
        case .landingDistance:
          (landingDistanceData?.value(for: chartInputs, clamping: .clampLow) ?? .notAvailable)
            * (landingTables.totalDistanceFactor ?? 1)
      }
    }
  }

  // MARK: - Correction Factors

  /// Looks up an adjustment factor, which varies with weight or pressure altitude, from a data
  /// table.
  ///
  /// These factors grow with their input, so holding a light aircraft at the lightest tabulated
  /// weight (or a low airport at the lowest altitude) overstates the penalty and the answer stays
  /// on the safe side. An input above the highest tabulated one would have its penalty
  /// understated, so it comes back offscale instead.
  override func correctionFactor(_ factor: CorrectionFactor, for target: DistanceTarget)
    -> Value<Double>?
  {
    correctionFactorData[target]?[factor]?.value(for: chartInputs, clamping: .clampLow)
  }
}

// MARK: - Airport Elevation

extension TabularPerformanceModel {
  /// The inputs the takeoff and landing tables, and their factors, are read at.
  private var chartInputs: [TableInput: Double] {
    [.weight: weight, .altitude: chartElevation, .temperature: temperature]
  }

  /// The inputs the en route climb tables are read at.
  private var enrouteInputs: [TableInput: Double] {
    [.weight: weight, .altitude: altitude, .temperature: temperature]
  }

  /// The elevation the takeoff and landing tables are read at.
  ///
  /// Below sea level the AFM has its sea-level figures used, so those are what the tables give,
  /// as an answer the AFM stands behind rather than an offscale one.
  private var chartElevation: Double {
    Swift.max(altitude, Self.seaLevelFt)
  }

  /// Reads a takeoff or landing figure, which the manual does not authorize at an airport outside
  /// the elevations it approves for the operation.
  ///
  /// The tables answer only there; the regression model is free to extrapolate past them.
  private func atApprovedAirport(for operation: Operation, _ figure: () -> Value<Double>)
    -> Value<Double>
  {
    limitations.isApproved(elevation: runway.elevation, for: operation) ? figure() : .notAuthorized
  }
}
