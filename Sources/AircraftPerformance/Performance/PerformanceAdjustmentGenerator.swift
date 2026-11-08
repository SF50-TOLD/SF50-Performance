import Foundation

/// Determines which adjustments apply for each distance target.
///
/// ``PerformanceAdjustmentGenerator`` holds the "which adjustments" logic every model class
/// shares. The generator inspects the current conditions (wind, gradient, surface, contamination,
/// air conditioner) and produces an ordered list of adjustment kinds for each ``DistanceTarget``,
/// placed where the aircraft's ``CorrectionScheme`` applies them.
struct PerformanceAdjustmentGenerator: Sendable {
  let headwind: Double
  let tailwind: Double
  let uphill: Double
  let downhill: Double
  let isTurf: Bool
  let contamination: Contamination?

  /// How the aircraft's manual combines its corrections.
  var scheme: CorrectionScheme = .multiplicative

  /// Whether the manual corrects for contamination, rather than only for a wet unpaved runway.
  var correctsContamination = true

  /// Whether the air conditioner runs during takeoff.
  var airConditionerOn = false

  /// Whether the runway is unpaved and wet.
  private var isWetTurf: Bool { isTurf && contamination == .wetRunway }

  private var windKinds: [AdjustmentKind] {
    var kinds: [AdjustmentKind] = []
    if headwind > 0 { kinds.append(.headwind(.init(value: headwind, unit: .knots))) }
    if tailwind > 0 { kinds.append(.tailwind(.init(value: tailwind, unit: .knots))) }
    return kinds
  }

  private var gradientKinds: [AdjustmentKind] {
    var kinds: [AdjustmentKind] = []
    if uphill > 0 { kinds.append(.uphillGradient(Float(uphill))) }
    if downhill > 0 { kinds.append(.downhillGradient(Float(downhill))) }
    return kinds
  }

  /// Returns the ordered list of adjustment kinds for a target.
  ///
  /// Under ``CorrectionScheme/groundRollReferenced`` a total distance gets only its own
  /// corrections here; ``isCarriedToTotalDistance(_:)`` says which it takes from the
  /// ground run.
  func adjustmentKinds(for target: DistanceTarget) -> [AdjustmentKind] {
    switch scheme {
      case .multiplicative: multiplicativeKinds(for: target)
      case .groundRollReferenced: groundRollReferencedKinds(for: target)
    }
  }

  /// Whether a ground run correction's feet are added to the total distance too.
  func isCarriedToTotalDistance(_ kind: AdjustmentKind) -> Bool {
    guard scheme == .groundRollReferenced else { return false }
    switch kind {
      case .uphillGradient, .downhillGradient, .unpavedSurface, .wetUnpavedSurface: return true
      default: return false
    }
  }

  private func multiplicativeKinds(for target: DistanceTarget) -> [AdjustmentKind] {
    var kinds: [AdjustmentKind] = []

    // Contamination (landing only, applied first before wind/gradient)
    if let contamination, correctsContamination, target.isLanding {
      kinds.append(.contamination(contamination))
    }

    kinds += windKinds

    // Gradient (ground run only, not total distance)
    if target.isGroundRun { kinds += gradientKinds }

    // Unpaved surface (total distance only)
    if isTurf, target.isTotalDistance {
      kinds.append(.unpavedSurface)
    }

    return kinds
  }

  private func groundRollReferencedKinds(for target: DistanceTarget) -> [AdjustmentKind] {
    var kinds = windKinds
    if target.isGroundRun {
      kinds += gradientKinds
      if isTurf { kinds.append(isWetTurf ? .wetUnpavedSurface : .unpavedSurface) }
    }
    if airConditionerOn, !target.isLanding { kinds.append(.airConditioner) }
    return kinds
  }
}
