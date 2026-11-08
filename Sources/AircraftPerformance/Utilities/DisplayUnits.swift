public import Foundation

/// The units a readout states measurements in.
///
/// Note and adjustment descriptions are written in these units. ``standard`` is the set the AFM
/// itself uses.
public struct DisplayUnits: Sendable, Hashable {
  /// Pounds, gallons, feet, knots and degrees Celsius, as the AFM writes them.
  public static let standard = Self(
    weight: .pounds,
    fuel: .gallons,
    length: .feet,
    height: .feet,
    speed: .knots,
    temperature: .celsius
  )

  /// The unit weights are stated in.
  public var weight: UnitMass

  /// The unit fuel quantities are stated in.
  public var fuel: UnitVolume

  /// The unit runway lengths and distances along the ground are stated in.
  public var length: UnitLength

  /// The unit elevations and heights are stated in.
  public var height: UnitLength

  /// The unit wind and airspeeds are stated in.
  public var speed: UnitSpeed

  /// The unit temperatures are stated in.
  public var temperature: UnitTemperature

  /**
   * Creates a set of display units.
   *
   * - Parameters:
   *   - weight: The unit weights are stated in.
   *   - fuel: The unit fuel quantities are stated in.
   *   - length: The unit runway lengths are stated in.
   *   - height: The unit elevations and heights are stated in.
   *   - speed: The unit wind and airspeeds are stated in.
   *   - temperature: The unit temperatures are stated in.
   */
  public init(
    weight: UnitMass,
    fuel: UnitVolume,
    length: UnitLength,
    height: UnitLength,
    speed: UnitSpeed,
    temperature: UnitTemperature
  ) {
    self.weight = weight
    self.fuel = fuel
    self.length = length
    self.height = height
    self.speed = speed
    self.temperature = temperature
  }
}

/// Writes measurements for note and adjustment descriptions.
///
/// Open-source Foundation has no measurement format style, so on Linux a measurement is written as
/// its formatted number followed by the unit's symbol.
enum MeasurementText {
  /**
   * Writes a measurement in a unit, rounded to an increment.
   *
   * - Parameters:
   *   - measurement: The measurement to write.
   *   - unit: The unit to write it in.
   *   - increment: The increment to round the number to.
   *   - width: How much of the unit name to write.
   *   - plusSign: Whether to sign positive numbers.
   * - Returns: The written measurement.
   */
  static func text<UnitType: Dimension>(
    _ measurement: Measurement<UnitType>,
    in unit: UnitType,
    increment: Double = 1,
    width: Width = .abbreviated,
    plusSign: Bool = false
  ) -> String {
    let converted = measurement.converted(to: unit),
      rounded = FloatingPointFormatStyle<Double>.number.rounded(increment: increment),
      numberStyle = plusSign ? rounded.sign(strategy: .always()) : rounded

    #if canImport(Darwin)
      let unitWidth: Measurement<UnitType>.FormatStyle.UnitWidth =
        switch width {
          case .abbreviated: .abbreviated
          case .narrow: .narrow
        }
      return converted.formatted(
        .measurement(width: unitWidth, usage: .asProvided, numberFormatStyle: numberStyle)
      )
    #else
      return "\(converted.value.formatted(numberStyle)) \(unit.symbol)"
    #endif
  }

  /// Writes a fraction as a percentage with up to two decimal places.
  static func percent(_ fraction: Float) -> String {
    fraction.formatted(.percent.precision(.fractionLength(0...2)))
  }

  /// How much of the unit name to write.
  enum Width {
    /// The unit's usual abbreviation, such as “ft”.
    case abbreviated

    /// The shortest form of the unit, such as “°” for a temperature.
    case narrow
  }
}
