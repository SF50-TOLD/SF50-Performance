public import Foundation

/// Runway surface contamination type and depth.
///
/// ``Contamination`` represents various runway surface conditions that degrade
/// braking performance. Contamination data is used to apply performance penalties
/// according to the AFM contaminated runway tables.
public enum Contamination: Sendable, Hashable {
  /// Standing water or slush on the runway surface
  case waterOrSlush(depth: Measurement<UnitLength>)

  /// Slush or wet snow on the runway surface
  case slushOrWetSnow(depth: Measurement<UnitLength>)

  /// Dry snow covering the runway
  case drySnow

  /// Compacted snow or ice on the runway
  case compactSnow

  /// Wet runway surface
  case wetRunway

  /// Runway Condition Code (AC 91-79B) with landing distance factor
  case rwyCC(UInt8)

  /// The shallowest and deepest contaminant depths the AFM’s water and slush tables tabulate.
  ///
  /// The tabular model answers between these depths and nowhere else: outside them the AFM gives
  /// no distance, so the model reports the depth as offscale rather than reading it at the
  /// nearest depth the tables do hold. The regression model, fitted to these same tables,
  /// extrapolates past them.
  public static let shallowestTabulatedDepth = Measurement(value: 0.125, unit: UnitLength.inches),
    deepestTabulatedDepth = Measurement(value: 0.5, unit: UnitLength.inches)

  /// Raw type string for persistence.
  public var type: String {
    switch self {
      case .waterOrSlush: ContaminationType.waterOrSlush.rawValue
      case .slushOrWetSnow: ContaminationType.slushOrWetSnow.rawValue
      case .drySnow: ContaminationType.drySnow.rawValue
      case .compactSnow: ContaminationType.compactSnow.rawValue
      case .wetRunway: ContaminationType.wetRunway.rawValue
      case .rwyCC: ContaminationType.rwyCC.rawValue
    }
  }

  /// Contamination depth in meters for types that require it.
  public var depth: Double? {
    switch self {
      case .waterOrSlush(let depth): depth.converted(to: .meters).value
      case .slushOrWetSnow(let depth): depth.converted(to: .meters).value
      case .drySnow, .compactSnow, .wetRunway, .rwyCC: nil
    }
  }

  /// Runway Condition Code (1–6) if this is an `.rwyCC` contamination, nil otherwise.
  public var rwyCC: UInt8? {
    if case .rwyCC(let code) = self { code } else { nil }
  }

  /// Creates contamination from persistence storage values.
  ///
  /// A depth of zero or less describes a runway with nothing on it, so the reading is rejected the
  /// way a missing one is: every reader — a runway readout, a report, the performance models —
  /// then sees a clean runway and says the same thing about it.
  ///
  /// - Parameters:
  ///   - type: The raw type, as ``type`` gives it.
  ///   - depth: The contaminant depth in meters, for water and slush.
  ///   - rwyCC: The Runway Condition Code (1–6), for an RwyCC report.
  public init?(type: String?, depth: Double?, rwyCC: UInt8? = nil) {
    guard let type, let typeEnum = ContaminationType(rawValue: type) else { return nil }

    switch typeEnum {
      case .waterOrSlush:
        guard let depth, depth > 0 else { return nil }
        self = .waterOrSlush(depth: .init(value: depth, unit: .meters))
      case .slushOrWetSnow:
        guard let depth, depth > 0 else { return nil }
        self = .slushOrWetSnow(depth: .init(value: depth, unit: .meters))
      case .drySnow:
        self = .drySnow
      case .compactSnow:
        self = .compactSnow
      case .wetRunway:
        self = .wetRunway
      case .rwyCC:
        guard let rwyCC, (1...6).contains(rwyCC) else { return nil }
        self = .rwyCC(rwyCC)
    }
  }

  /// Raw string values for persistence.
  enum ContaminationType: String {
    /// Standing water or slush
    case waterOrSlush
    /// Slush or wet snow
    case slushOrWetSnow
    /// Dry snow coverage
    case drySnow
    /// Compacted snow or ice
    case compactSnow
    /// Wet runway surface
    case wetRunway
    /// Runway Condition Code
    case rwyCC
  }
}
