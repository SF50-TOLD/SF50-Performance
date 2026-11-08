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
  private let vrefData: DataTable
  private let landingRunData: DataTable
  private let landingDistanceData: DataTable

  private let takeoffRun_headwindData: DataTable
  private let takeoffRun_tailwindData: DataTable
  private let takeoffRun_downhillData: DataTable
  private let takeoffRun_uphillData: DataTable
  private let takeoffDistance_headwindData: DataTable
  private let takeoffDistance_tailwindData: DataTable
  private let takeoffDistance_unpavedData: DataTable

  private let landingRun_headwindData: DataTable
  private let landingRun_tailwindData: DataTable
  private let landingRun_downhillData: DataTable
  private let landingRun_uphillData: DataTable
  private let landingDistance_headwindData: DataTable
  private let landingDistance_tailwindData: DataTable
  private let landingDistance_unpavedData: DataTable

  private let enrouteClimb_gradientNormalData: DataTable
  private let enrouteClimb_rateNormalData: DataTable
  private let enrouteClimb_speedNormalData: DataTable
  private let enrouteClimb_gradientIceContaminatedData: DataTable
  private let enrouteClimb_rateIceContaminatedData: DataTable
  private let enrouteClimb_speedIceContaminatedData: DataTable

  // MARK: - Non-Distance Outputs

  override var takeoffClimbGradientFtNM: Value<Double> {
    atApprovedAirport { takeoffClimbGradientData.value(for: chartInputs) }
  }

  override var takeoffClimbRateFtMin: Value<Double> {
    atApprovedAirport { takeoffClimbRateData.value(for: chartInputs) }
  }

  override var VrefKts: Value<Double> {
    vrefData.value(for: [.weight: weight])
  }

  /// Whether the AFM's go-around climb gradient is met.
  ///
  /// The tables publish a landing distance only where the gradient is met, so a distance the model
  /// can stand behind answers yes and one off the top of the tables answers no. Where the model has
  /// no distance at all it has no answer either, and says so rather than assuming the gradient
  /// holds.
  override var meetsGoAroundClimbGradient: Value<Bool> {
    switch landingDistanceFt {
      case .value, .valueWithUncertainty: .value(true)
      case .offscaleHigh: .value(false)
      case .offscaleLow(let clamped): clamped == nil ? .notAvailable : .value(true)
      case .invalid: .invalid
      case .notAvailable: .notAvailable
      case .notAuthorized: .notAuthorized
    }
  }

  // MARK: - En Route Climb

  override var enrouteClimbGradientFtNM: Value<Double> {
    let data =
      configuration.iceProtection
      ? enrouteClimb_gradientIceContaminatedData : enrouteClimb_gradientNormalData
    return data.value(for: enrouteInputs)
  }

  override var enrouteClimbRateFtMin: Value<Double> {
    let data =
      configuration.iceProtection
      ? enrouteClimb_rateIceContaminatedData : enrouteClimb_rateNormalData
    return data.value(for: enrouteInputs)
  }

  override var enrouteClimbSpeedKIAS: Value<Double> {
    let data =
      configuration.iceProtection
      ? enrouteClimb_speedIceContaminatedData : enrouteClimb_speedNormalData
    return data.value(for: enrouteInputs)
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
      loader = DataTableLoader(data: try definition.data())
    landingTables = definition.landingTables(for: configuration.flapSetting)
    let landingPrefix = loader.tablePrefix(for: landingTables.flapSetting)

    limitations = definition.limitations

    takeoffRunData = try loader.loadTakeoffRunData()
    takeoffDistanceData = try loader.loadTakeoffDistanceData()
    takeoffClimbGradientData = try loader.loadTakeoffClimbGradientData()
    takeoffClimbRateData = try loader.loadTakeoffClimbRateData()

    vrefData = try loader.loadVrefData(
      vrefPrefix: loader.tablePrefix(for: configuration.flapSetting)
    )

    landingRunData = try loader.loadLandingRunData(landingPrefix: landingPrefix)
    landingDistanceData = try loader.loadLandingDistanceData(landingPrefix: landingPrefix)

    takeoffRun_headwindData = try loader.loadTakeoffRunHeadwindData()
    takeoffRun_tailwindData = try loader.loadTakeoffRunTailwindData()
    takeoffRun_downhillData = try loader.loadTakeoffRunDownhillData()
    takeoffRun_uphillData = try loader.loadTakeoffRunUphillData()
    takeoffDistance_headwindData = try loader.loadTakeoffDistanceHeadwindData()
    takeoffDistance_tailwindData = try loader.loadTakeoffDistanceTailwindData()
    takeoffDistance_unpavedData = try loader.loadTakeoffDistanceUnpavedData()

    landingRun_headwindData = try loader.loadLandingRunHeadwindData(landingPrefix: landingPrefix)
    landingRun_tailwindData = try loader.loadLandingRunTailwindData(landingPrefix: landingPrefix)
    landingRun_downhillData = try loader.loadLandingRunDownhillData(landingPrefix: landingPrefix)
    landingRun_uphillData = try loader.loadLandingRunUphillData(landingPrefix: landingPrefix)
    landingDistance_headwindData = try loader.loadLandingDistanceHeadwindData(
      landingPrefix: landingPrefix
    )
    landingDistance_tailwindData = try loader.loadLandingDistanceTailwindData(
      landingPrefix: landingPrefix
    )
    landingDistance_unpavedData = try loader.loadLandingDistanceUnpavedData(
      landingPrefix: landingPrefix
    )

    enrouteClimb_gradientNormalData = try loader.loadEnrouteClimbGradientData(
      iceContaminated: false
    )
    enrouteClimb_rateNormalData = try loader.loadEnrouteClimbRateData(iceContaminated: false)
    enrouteClimb_speedNormalData = try loader.loadEnrouteClimbSpeedData(iceContaminated: false)
    enrouteClimb_gradientIceContaminatedData = try loader.loadEnrouteClimbGradientData(
      iceContaminated: true
    )
    enrouteClimb_rateIceContaminatedData = try loader.loadEnrouteClimbRateData(
      iceContaminated: true
    )
    enrouteClimb_speedIceContaminatedData = try loader.loadEnrouteClimbSpeedData(
      iceContaminated: true
    )

    super.init(conditions: conditions, configuration: configuration, runway: runway, notam: notam)
    contaminationCalculator = try ContaminationCalculator(loader: loader)
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
    atApprovedAirport {
      switch target {
        case .takeoffRun:
          takeoffRunData.value(
            for: chartInputs,
            clamping: .clampLow
          )
        case .takeoffDistance:
          takeoffDistanceData.value(
            for: chartInputs,
            clamping: .clampLow
          )
        case .landingRun:
          landingTables.hasGroundRun
            ? landingRunData.value(
              for: chartInputs,
              clamping: .clampLow
            )
            : .notAvailable
        case .landingDistance:
          landingDistanceData.value(
            for: chartInputs,
            clamping: .clampLow
          ) * (landingTables.totalDistanceFactor ?? 1)
      }
    }
  }

  // MARK: - Adjustment Multiplier

  override func adjustmentMultiplier(
    for kind: AdjustmentKind,
    target: DistanceTarget
  ) -> Value<Double> {
    switch (kind, target) {
      // Takeoff Run
      case (.headwind, .takeoffRun):
        PerformanceAdjustments.windAdjustment(
          factor: lookupFactor(takeoffRun_headwindData),
          wind: -headwind
        )
      case (.tailwind, .takeoffRun):
        PerformanceAdjustments.windAdjustment(
          factor: lookupFactor(takeoffRun_tailwindData),
          wind: tailwind
        )
      case (.uphillGradient, .takeoffRun):
        PerformanceAdjustments.gradientAdjustment(
          factor: lookupFactor(takeoffRun_uphillData),
          gradient: uphill
        )
      case (.downhillGradient, .takeoffRun):
        PerformanceAdjustments.gradientAdjustment(
          factor: lookupFactor(takeoffRun_downhillData),
          gradient: -downhill
        )

      // Takeoff Distance
      case (.headwind, .takeoffDistance):
        PerformanceAdjustments.windAdjustment(
          factor: lookupFactor(takeoffDistance_headwindData),
          wind: -headwind
        )
      case (.tailwind, .takeoffDistance):
        PerformanceAdjustments.windAdjustment(
          factor: lookupFactor(takeoffDistance_tailwindData),
          wind: tailwind
        )
      case (.unpavedSurface, .takeoffDistance):
        PerformanceAdjustments.surfaceAdjustment(
          factor: lookupFactor(takeoffDistance_unpavedData)
        )

      // Landing Run
      case (.headwind, .landingRun):
        PerformanceAdjustments.windAdjustment(
          factor: lookupFactor(landingRun_headwindData),
          wind: -headwind
        )
      case (.tailwind, .landingRun):
        PerformanceAdjustments.windAdjustment(
          factor: lookupFactor(landingRun_tailwindData),
          wind: tailwind
        )
      case (.uphillGradient, .landingRun):
        PerformanceAdjustments.gradientAdjustment(
          factor: lookupFactor(landingRun_uphillData),
          gradient: -uphill
        )
      case (.downhillGradient, .landingRun):
        PerformanceAdjustments.gradientAdjustment(
          factor: lookupFactor(landingRun_downhillData),
          gradient: downhill
        )

      // Landing Distance
      case (.headwind, .landingDistance):
        PerformanceAdjustments.windAdjustment(
          factor: lookupFactor(landingDistance_headwindData),
          wind: -headwind
        )
      case (.tailwind, .landingDistance):
        PerformanceAdjustments.windAdjustment(
          factor: lookupFactor(landingDistance_tailwindData),
          wind: tailwind
        )
      case (.unpavedSurface, .landingDistance):
        PerformanceAdjustments.surfaceAdjustment(
          factor: lookupFactor(landingDistance_unpavedData)
        )

      default:
        fatalError("Unexpected adjustment \(kind) for target \(target)")
    }
  }

  /// Looks up an adjustment factor, which varies with weight or pressure altitude, from a data
  /// table.
  ///
  /// These factors grow with their input, so holding a light aircraft at the lightest tabulated
  /// weight (or a low airport at the lowest altitude) overstates the penalty and the answer stays
  /// on the safe side. An input above the highest tabulated one would have its penalty
  /// understated, so it comes back offscale instead.
  private func lookupFactor(_ data: DataTable) -> Value<Double> {
    data.value(for: chartInputs, clamping: .clampLow)
  }
}

// MARK: - Airport Elevation

extension TabularPerformanceModel {
  /// Whether the airport lies within the elevations the AFM approves for takeoff and landing.
  ///
  /// The tables answer only there; the regression model is free to extrapolate past them.
  private var isAirportElevationApproved: Bool {
    (limitations.minAirportElevation...limitations.maxAirportElevation).contains(runway.elevation)
  }

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

  /// Reads a takeoff or landing figure, which the AFM does not authorize at an airport outside its
  /// approved elevations.
  private func atApprovedAirport(_ figure: () -> Value<Double>) -> Value<Double> {
    isAirportElevationApproved ? figure() : .notAuthorized
  }
}
