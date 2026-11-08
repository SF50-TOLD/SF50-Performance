import Foundation

/// A correction a manual prints beside a distance table, as a table and an equation of its own.
///
/// Data packages name them `<ground run|total distance> - <name> factor.csv` (or `addition`)
/// beside the distance table, and `<takeoff|landing>-<run|distance>-<name>-factor[-<flaps>].json`
/// among the equations.
enum CorrectionFactor: Sendable, CaseIterable {
  /// A fraction of the distance per 10 knots of headwind.
  case headwind

  /// A fraction of the distance per 10 knots of tailwind.
  case tailwind

  /// A fraction of the ground run per 1% of upslope.
  case uphill

  /// A fraction of the ground run per 1% of downslope.
  case downhill

  /// A fraction added on a dry unpaved runway.
  case unpaved

  /// A fraction added on a wet unpaved runway.
  case wetUnpaved

  /// Feet added with the air conditioner on.
  case airConditioner

  /// The table's name after the distance it corrects, such as `headwind factor`.
  var tableName: String {
    switch self {
      case .headwind: "headwind factor"
      case .tailwind: "tailwind factor"
      case .uphill: "uphill factor"
      case .downhill: "downhill factor"
      case .unpaved: "unpaved factor"
      case .wetUnpaved: "wet unpaved factor"
      case .airConditioner: "air conditioner addition"
    }
  }

  /// The equation's name after the distance it corrects, such as `headwind-factor`.
  var equationName: String {
    switch self {
      case .headwind: "headwind-factor"
      case .tailwind: "tailwind-factor"
      case .uphill: "uphill-factor"
      case .downhill: "downhill-factor"
      case .unpaved: "unpaved-factor"
      case .wetUnpaved: "wet-unpaved-factor"
      case .airConditioner: "air-conditioner-addition"
    }
  }

  /// The factor an adjustment applies, or `nil` for one that isn't a printed correction.
  init?(_ kind: AdjustmentKind) {
    switch kind {
      case .headwind: self = .headwind
      case .tailwind: self = .tailwind
      case .uphillGradient: self = .uphill
      case .downhillGradient: self = .downhill
      case .unpavedSurface: self = .unpaved
      case .wetUnpavedSurface: self = .wetUnpaved
      case .airConditioner: self = .airConditioner
      case .contamination, .safetyMargin, .VREFAdditive: return nil
    }
  }

  /// The table path of the factor for a distance, read from a flap setting's landing tables.
  func tablePath(for target: DistanceTarget, landingTablePrefix: String) -> String {
    "\(target.tableDirectory(landingTablePrefix: landingTablePrefix)) - \(tableName).csv"
  }

  /// The equation file names that may hold the factor for a distance, most specific first.
  ///
  /// A landing factor that varies by flap setting carries the setting's suffix; one that doesn't
  /// has none.
  func equationFilenames(for target: DistanceTarget, flapSuffix: String) -> [String] {
    let name = "\(target.equationPrefix)-\(equationName)"
    return target.isLanding ? ["\(name)-\(flapSuffix).json", "\(name).json"] : ["\(name).json"]
  }
}

/// How a manual's corrections combine into a corrected distance.
enum CorrectionScheme: Sendable {
  /// Each correction multiplies the distance it is printed beside, in turn. Slope corrects the
  /// ground run and surface the total distance.
  case multiplicative

  /// Wind multiplies each distance. Slope, surface and the air conditioner correct the ground run,
  /// and the feet they add to it are added to the total distance too, except where the manual
  /// prints a total distance correction of its own.
  case groundRollReferenced
}

extension DistanceTarget {
  /// The prefix of the distance's equation names, such as `takeoff-run`.
  var equationPrefix: String {
    switch self {
      case .takeoffRun: "takeoff-run"
      case .takeoffDistance: "takeoff-distance"
      case .landingRun: "landing-run"
      case .landingDistance: "landing-distance"
    }
  }

  /// The ground run of the same operation.
  var groundRun: Self { isLanding ? .landingRun : .takeoffRun }

  /// The distance table's path without its extension, such as `takeoff/ground run`.
  func tableDirectory(landingTablePrefix: String) -> String {
    switch self {
      case .takeoffRun: "takeoff/ground run"
      case .takeoffDistance: "takeoff/total distance"
      case .landingRun: "landing/\(landingTablePrefix)/ground run"
      case .landingDistance: "landing/\(landingTablePrefix)/total distance"
    }
  }
}
