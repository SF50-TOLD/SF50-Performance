public import Foundation
public import MeasurementKit

/// Which distance is being computed.
public enum DistanceTarget: Sendable {
  case takeoffRun
  case takeoffDistance
  case landingRun
  case landingDistance

  public var isLanding: Bool { self == .landingRun || self == .landingDistance }
  public var isGroundRun: Bool { self == .takeoffRun || self == .landingRun }
  public var isTotalDistance: Bool { self == .takeoffDistance || self == .landingDistance }
}

/// Identifies a specific adjustment applied to a performance distance.
public enum AdjustmentKind: Sendable, Equatable {
  case headwind(Measurement<UnitSpeed>)
  case tailwind(Measurement<UnitSpeed>)
  case uphillGradient(Float)
  case downhillGradient(Float)
  case unpavedSurface
  case contamination(Contamination)
  case safetyMargin(Double)
  case VREFAdditive(Measurement<UnitSpeed>)

  /// Description of the adjustment in the AFM's units.
  public var localizedDescription: String { localizedDescription(units: .standard) }

  /**
   * Description of the adjustment for display to the user.
   *
   * - Parameter units: The units to state speeds in.
   * - Returns: The localized description.
   */
  public func localizedDescription(units: DisplayUnits) -> String {
    switch self {
      case .headwind(let speed):
        let speed = MeasurementText.text(speed, in: units.speed)
        return String(
          localized: "Headwind — \(speed)",
          bundle: .module,
          comment: "A distance adjustment. The argument is the headwind component."
        )
      case .tailwind(let speed):
        let speed = MeasurementText.text(speed, in: units.speed)
        return String(
          localized: "Tailwind — \(speed)",
          bundle: .module,
          comment: "A distance adjustment. The argument is the tailwind component."
        )
      case .uphillGradient(let gradient):
        let gradient = MeasurementText.percent(gradient)
        return String(
          localized: "Uphill — \(gradient)",
          bundle: .module,
          comment: "A distance adjustment. The argument is the runway slope, as a percentage."
        )
      case .downhillGradient(let gradient):
        let gradient = MeasurementText.percent(gradient)
        return String(
          localized: "Downhill — \(gradient)",
          bundle: .module,
          comment: "A distance adjustment. The argument is the runway slope, as a percentage."
        )
      case .unpavedSurface:
        return String(
          localized: "Unpaved Surface",
          bundle: .module,
          comment: "A distance adjustment for a turf runway."
        )
      case .contamination:
        return String(
          localized: "Contamination",
          bundle: .module,
          comment: "A distance adjustment for a contaminated runway."
        )
      case .safetyMargin(let factor):
        let factor = factor.formatted(.number.precision(.fractionLength(2)))
        return String(
          localized: "Safety Factor — \(factor)",
          bundle: .module,
          comment: "A distance adjustment. The argument is the safety factor multiplier."
        )
      case .VREFAdditive(let speed):
        let speed = MeasurementText.text(speed, in: units.speed, plusSign: true)
        return String(
          localized: "VREF — \(speed)",
          bundle: .module,
          comment: "A distance adjustment. The argument is the speed added to VREF."
        )
    }
  }
}

/// A single adjustment applied to a distance.
public struct PerformanceAdjustment: Sendable {
  public let kind: AdjustmentKind

  /// The effective multiplier for this adjustment (e.g., 0.944 for a 5.6% headwind reduction).
  public let multiplier: Double

  /// The running total distance in feet after this adjustment is applied.
  public let resultFt: Value<Double>

  public init(kind: AdjustmentKind, multiplier: Double, resultFt: Value<Double>) {
    self.kind = kind
    self.multiplier = multiplier
    self.resultFt = resultFt
  }
}

/// Base value plus ordered adjustments for a single distance.
public struct DistanceBreakdown: Sendable {

  /// The base distance in feet before any adjustments.
  public let baseFt: Value<Double>

  /// The ordered list of adjustments applied to the base distance.
  public let adjustments: [PerformanceAdjustment]

  public init(baseFt: Value<Double>, adjustments: [PerformanceAdjustment]) {
    self.baseFt = baseFt
    self.adjustments = adjustments
  }

  /// Returns a new breakdown with additional adjustments appended.
  func appending(_ additional: [PerformanceAdjustment]) -> Self {
    Self(baseFt: baseFt, adjustments: adjustments + additional)
  }
}

/// Severity level for a performance note.
public enum PerformanceNoteSeverity: Int, Sendable, Comparable {
  case warning = 0
  case info = 1

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

/// A warning or note about the performance calculation.
public enum PerformanceNote: Sendable, Equatable {
  // Offscale
  case offscaleHigh
  case offscaleLow

  // Informational
  case contaminationSupplemental
  case rwyCCSafetyFactorNotApplied
  case VREFAdditiveApproximate
  /// No altimeter setting was given, so the tables were read at field elevation.
  case pressureAltitudeFromFieldElevation

  // Exceedances (warnings)
  case crosswindExceedance(crosswind: Measurement<UnitSpeed>, limit: Measurement<UnitSpeed>)
  case tailwindExceedance(tailwind: Measurement<UnitSpeed>, limit: Measurement<UnitSpeed>)
  case weightAboveMax(weight: Measurement<UnitMass>, limit: Measurement<UnitMass>)
  case zeroFuelWeightExceeded(weight: Measurement<UnitMass>, limit: Measurement<UnitMass>)
  case fuelExceedsCapacity(fuel: Measurement<UnitVolume>, limit: Measurement<UnitVolume>)
  case airportElevationOutsideLimits(
    elevation: Measurement<UnitLength>,
    limits: ClosedRange<Measurement<UnitLength>>
  )
  case takeoffDistanceExceedsAvailable(
    required: Measurement<UnitLength>,
    available: Measurement<UnitLength>
  )
  case takeoffRunExceedsAvailable(
    required: Measurement<UnitLength>,
    available: Measurement<UnitLength>
  )
  case landingDistanceExceedsAvailable(
    required: Measurement<UnitLength>,
    available: Measurement<UnitLength>
  )
  case insufficientClimbGradient(
    required: Measurement<UnitSlope>,
    actual: Value<Measurement<UnitSlope>>
  )
  case doesNotMeetGoAroundGradient

  public var severity: PerformanceNoteSeverity {
    switch self {
      case .offscaleHigh:
        .warning
      case .offscaleLow,
        .contaminationSupplemental,
        .rwyCCSafetyFactorNotApplied,
        .VREFAdditiveApproximate,
        .pressureAltitudeFromFieldElevation:
        .info
      case .crosswindExceedance, .tailwindExceedance,
        .weightAboveMax, .zeroFuelWeightExceeded, .fuelExceedsCapacity,
        .airportElevationOutsideLimits,
        .takeoffDistanceExceedsAvailable,
        .takeoffRunExceedsAvailable,
        .landingDistanceExceedsAvailable,
        .insufficientClimbGradient,
        .doesNotMeetGoAroundGradient:
        .warning
    }
  }

  /// Description of the note in the AFM's units.
  public var localizedDescription: String { localizedDescription(units: .standard) }

  /**
   * Description of the note for display to the user.
   *
   * - Parameter units: The units to state measurements in.
   * - Returns: The localized description.
   */
  public func localizedDescription(units: DisplayUnits) -> String {
    switch self {
      case .offscaleHigh, .offscaleLow, .contaminationSupplemental, .rwyCCSafetyFactorNotApplied,
        .VREFAdditiveApproximate, .pressureAltitudeFromFieldElevation, .doesNotMeetGoAroundGradient:
        informationalDescription
      case .crosswindExceedance, .tailwindExceedance, .weightAboveMax, .zeroFuelWeightExceeded,
        .fuelExceedsCapacity, .airportElevationOutsideLimits:
        limitationDescription(units: units)
      case .takeoffDistanceExceedsAvailable, .takeoffRunExceedsAvailable,
        .landingDistanceExceedsAvailable, .insufficientClimbGradient:
        distanceDescription(units: units)
    }
  }
}

// MARK: - Descriptions

extension PerformanceNote {
  /// The descriptions of notes that carry no measurement.
  private var informationalDescription: String {
    switch self {
      case .offscaleHigh:
        String(
          localized:
            "The input values are above the maximums specified in the AFM table. Proceed with extreme caution.",
          bundle: .module,
          comment: "A performance note."
        )
      case .offscaleLow:
        String(
          localized: "The input values are below the minimums specified in the AFM table.",
          bundle: .module,
          comment: "A performance note."
        )
      case .contaminationSupplemental:
        String(
          localized:
            "Contaminated runway performance data is considered supplemental and is not FAA approved.",
          bundle: .module,
          comment: "A performance note."
        )
      case .rwyCCSafetyFactorNotApplied:
        String(
          localized:
            "AC 91-79B landing distance factors are applied. The configured safety factor is not applied to RwyCC landing distances.",
          bundle: .module,
          comment: "A performance note."
        )
      case .VREFAdditiveApproximate:
        String(
          localized:
            "Landing distances include an AC 91-79B §5.2.2 adjustment for the VREF additive. This is an approximation.",
          bundle: .module,
          comment: "A performance note."
        )
      case .pressureAltitudeFromFieldElevation:
        String(
          localized:
            "No altimeter setting was given, so the AFM tables were read at field elevation rather than pressure altitude.",
          bundle: .module,
          comment: "A performance note."
        )
      case .doesNotMeetGoAroundGradient:
        String(
          localized: "Go-around climb gradient requirement is not met.",
          bundle: .module,
          comment: "A performance note."
        )
      default:
        preconditionFailure("\(self) carries measurements")
    }
  }

  /// The descriptions of notes about an operating limitation.
  private func limitationDescription(units: DisplayUnits) -> String {
    switch self {
      case let .crosswindExceedance(crosswind, limit):
        let crosswind = MeasurementText.text(crosswind, in: units.speed),
          limit = MeasurementText.text(limit, in: units.speed)
        return String(
          localized: "Crosswind of \(crosswind) exceeds the \(limit) limit.",
          bundle: .module,
          comment: "A performance note. The arguments are the crosswind and its limit."
        )
      case let .tailwindExceedance(tailwind, limit):
        let tailwind = MeasurementText.text(tailwind, in: units.speed),
          limit = MeasurementText.text(limit, in: units.speed)
        return String(
          localized: "Tailwind of \(tailwind) exceeds the \(limit) limit.",
          bundle: .module,
          comment: "A performance note. The arguments are the tailwind and its limit."
        )
      case let .weightAboveMax(weight, limit):
        let weight = MeasurementText.text(weight, in: units.weight),
          limit = MeasurementText.text(limit, in: units.weight)
        return String(
          localized: "Weight of \(weight) exceeds the \(limit) maximum.",
          bundle: .module,
          comment: "A performance note. The arguments are the weight and its limit."
        )
      case let .zeroFuelWeightExceeded(weight, limit):
        let weight = MeasurementText.text(weight, in: units.weight),
          limit = MeasurementText.text(limit, in: units.weight)
        return String(
          localized: "Zero-fuel weight of \(weight) exceeds the \(limit) maximum.",
          bundle: .module,
          comment: "A performance note. The arguments are the zero-fuel weight and its limit."
        )
      case let .fuelExceedsCapacity(fuel, limit):
        let fuel = MeasurementText.text(fuel, in: units.fuel),
          limit = MeasurementText.text(limit, in: units.fuel)
        return String(
          localized: "Fuel quantity of \(fuel) exceeds the \(limit) usable capacity.",
          bundle: .module,
          comment: "A performance note. The arguments are the fuel quantity and the capacity."
        )
      case let .airportElevationOutsideLimits(elevation, limits):
        let elevation = MeasurementText.text(elevation, in: units.height),
          lower = MeasurementText.text(limits.lowerBound, in: units.height),
          upper = MeasurementText.text(limits.upperBound, in: units.height)
        return String(
          localized:
            "Airport elevation of \(elevation) is outside the AFM’s \(lower) to \(upper) limits.",
          bundle: .module,
          comment: "A performance note. The arguments are the elevation and the approved range."
        )
      default:
        preconditionFailure("\(self) is not a limitation note")
    }
  }

  /// The descriptions of notes comparing a distance or gradient against what is available.
  private func distanceDescription(units: DisplayUnits) -> String {
    switch self {
      case let .takeoffDistanceExceedsAvailable(required, available):
        let required = MeasurementText.text(required, in: units.length),
          available = MeasurementText.text(available, in: units.length)
        return String(
          localized: "Takeoff distance of \(required) exceeds the available \(available).",
          bundle: .module,
          comment: "A performance note. The arguments are the required and available distances."
        )
      case let .takeoffRunExceedsAvailable(required, available):
        let required = MeasurementText.text(required, in: units.length),
          available = MeasurementText.text(available, in: units.length)
        return String(
          localized: "Takeoff run of \(required) exceeds the available \(available).",
          bundle: .module,
          comment: "A performance note. The arguments are the required and available distances."
        )
      case let .landingDistanceExceedsAvailable(required, available):
        let required = MeasurementText.text(required, in: units.length),
          available = MeasurementText.text(available, in: units.length)
        return String(
          localized: "Landing distance of \(required) exceeds the available \(available).",
          bundle: .module,
          comment: "A performance note. The arguments are the required and available distances."
        )
      case .insufficientClimbGradient:
        return String(
          localized: "Required climb gradient may exceed actual climb performance.",
          bundle: .module,
          comment: "A performance note."
        )
      default:
        preconditionFailure("\(self) is not a distance note")
    }
  }
}
