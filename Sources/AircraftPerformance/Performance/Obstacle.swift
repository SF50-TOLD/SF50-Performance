public import Foundation
public import MeasurementKit

/// An obstacle off the departure end of a runway.
///
/// The climb gradient needed to clear it is measured from the point where the takeoff ends: the
/// end of the takeoff distance, where the aircraft crosses the AFM's screen height. From there the
/// aircraft has to gain the obstacle's height above the screen over the ground that remains.
public struct Obstacle: Sendable, Hashable {
  /// The height above the runway at which the AFM takeoff distance ends: the G1 AFM (P/N
  /// 31452-001, Section 5, Takeoff Distance) measures the total distance over a 50-foot obstacle.
  public static let screenHeight = Measurement(value: 50, unit: UnitLength.feet)

  /// The obstacle's height above the runway.
  public let height: Measurement<UnitLength>

  /// The obstacle's distance beyond the departure end of the runway.
  public let distanceFromDepartureEnd: Measurement<UnitLength>

  /**
   * Creates an obstacle.
   *
   * - Parameters:
   *   - height: The obstacle's height above the runway.
   *   - distanceFromDepartureEnd: Its distance beyond the departure end of the runway.
   */
  public init(height: Measurement<UnitLength>, distanceFromDepartureEnd: Measurement<UnitLength>) {
    self.height = height
    self.distanceFromDepartureEnd = distanceFromDepartureEnd
  }

  /**
   * The climb gradient needed to clear this obstacle after a takeoff.
   *
   * The aircraft crosses the screen height at the end of `takeoffDistance`, measured from brake
   * release. The obstacle stands `availableTakeoffRun` plus ``distanceFromDepartureEnd`` from
   * brake release, so the climb has the difference between the two to gain the obstacle's height
   * above the screen.
   *
   * - Parameters:
   *   - takeoffDistance: The takeoff distance over the screen height, from brake release.
   *   - availableTakeoffRun: The takeoff run available, which ends at the departure end.
   * - Returns: What clearing the obstacle requires.
   */
  public func climbRequirement(
    takeoffDistance: Measurement<UnitLength>,
    availableTakeoffRun: Measurement<UnitLength>
  ) -> ClimbRequirement {
    let heightAboveScreenFt = (height - Self.screenHeight).converted(to: .feet).value
    guard heightAboveScreenFt > 0 else { return .none }

    let distanceFromScreenFt =
      (availableTakeoffRun + distanceFromDepartureEnd - takeoffDistance).converted(to: .feet).value
    guard distanceFromScreenFt > 0 else { return .unclearable }

    return .gradient(.init(value: heightAboveScreenFt / distanceFromScreenFt, unit: .ratio))
  }
}

/// What clearing an obstacle requires of the takeoff climb.
public enum ClimbRequirement: Sendable, Hashable {
  /// The obstacle is no taller than the screen height, so the takeoff itself clears it.
  case none

  /// The takeoff climb must achieve this gradient from the end of the takeoff distance.
  case gradient(Measurement<UnitSlope>)

  /// The obstacle is taller than the screen height and stands within the takeoff distance, so no
  /// climb gradient clears it.
  case unclearable

  /**
   * Whether a takeoff climb gradient meets this requirement.
   *
   * - Parameter climbGradient: The gradient the aircraft achieves, or `nil` where the model has
   *   none.
   * - Returns: Whether the obstacle is cleared. A missing gradient clears only an obstacle that
   *   needs none.
   */
  public func isMet(by climbGradient: Measurement<UnitSlope>?) -> Bool {
    switch self {
      case .none: true
      case .unclearable: false
      case .gradient(let required):
        // Compared as ratios: values made by different unit instances need not compare equal.
        climbGradient.map {
          $0.converted(to: .ratio).value >= required.converted(to: .ratio).value
        } ?? false
    }
  }
}
