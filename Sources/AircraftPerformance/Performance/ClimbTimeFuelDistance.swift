public import Foundation

/// The time, fuel and distance to climb between two pressure altitudes.
///
/// The figures are the manual's table read at the top of the climb, less the table read at the
/// bottom, since the tables run from sea level. The manual's own adjustments to them, such as
/// fuel for start, taxi and takeoff, or an increase for a temperature above standard, are not
/// applied; ``Aircraft/configurationInfo()`` carries the notes that say which apply.
public struct ClimbTimeFuelDistance: Sendable {
  /// A climb the aircraft's manual has no figures for.
  static let notAvailable = Self(time: .notAvailable, fuel: .notAvailable, distance: .notAvailable)

  /// The time to climb.
  public let time: Value<Measurement<UnitDuration>>

  /// The fuel burned in the climb.
  public let fuel: Value<Measurement<UnitVolume>>

  /// The still-air distance covered in the climb.
  public let distance: Value<Measurement<UnitLength>>
}

extension PerformanceCalculator {
  private static let timeToClimbName = "time",
    fuelToClimbName = "fuel",
    distanceToClimbName = "distance"

  /**
   * The time, fuel and distance to climb from one pressure altitude to another.
   *
   * - Parameters:
   *   - bottom: The pressure altitude the climb starts at.
   *   - top: The pressure altitude the climb ends at.
   *   - leanOfPeak: Whether the climb is flown lean of peak, for an aircraft with
   *     ``PerformanceCapability/leanOfPeakClimb``.
   * - Returns: The figures, each `.notAvailable` where the manual has none.
   * - Throws: ``PerformanceDataError`` if the bundled performance data could not be read.
   */
  public func timeFuelDistanceToClimb(
    from bottom: Measurement<UnitLength>,
    to top: Measurement<UnitLength>,
    leanOfPeak: Bool = false
  ) throws -> ClimbTimeFuelDistance {
    let definition = settings.aircraft.definition,
      capability: PerformanceCapability = leanOfPeak ? .leanOfPeakClimb : .timeFuelDistanceToClimb
    guard definition.capabilities.contains(capability) else { return .notAvailable }

    let data = try definition.data(),
      bottomFt = bottom.converted(to: .feet).value,
      topFt = top.converted(to: .feet).value
    func climb(_ quantity: String) throws -> Value<Double> {
      let reading = try timeFuelDistanceReader(quantity, leanOfPeak: leanOfPeak, data: data)
      return reading(topFt) - reading(bottomFt)
    }
    return .init(
      time: try climb(Self.timeToClimbName).toMeasurement(UnitDuration.minutes),
      fuel: try climb(Self.fuelToClimbName).toMeasurement(UnitVolume.gallons),
      distance: try climb(Self.distanceToClimbName).toMeasurement(UnitLength.nauticalMiles)
    )
  }

  /// Reads one quantity of the time, fuel and distance to climb from sea level, by the model the
  /// settings choose.
  private func timeFuelDistanceReader(
    _ quantity: String,
    leanOfPeak: Bool,
    data: AircraftData
  ) throws -> (Double) -> Value<Double> {
    let suffix = leanOfPeak ? " - lean of peak" : ""
    switch settings.modelKind {
      case .tabular:
        let table = try data.table("climb/time fuel distance\(suffix)/\(quantity).csv")
        return { table.value(for: [.altitude: $0]) }
      case .regression:
        let equation = try data.equation(
          "climb-\(quantity)\(leanOfPeak ? "-lean-of-peak" : "").json"
        )
        return { equation.evaluate(inputs: ["altitude": $0]) }
    }
  }
}
