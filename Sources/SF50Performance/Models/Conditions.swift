public import Foundation

/// Atmospheric conditions used for performance calculations.
///
/// ``Conditions`` represents weather observations or forecasts including wind,
/// temperature, dewpoint, and pressure. Conditions can be downloaded from weather services,
/// taken from the International Standard Atmosphere, or entered by hand.
public struct Conditions: Sendable, Equatable {
  /// The altimeter setting of the standard atmosphere, in inches of mercury.
  private static let standardAltimeterInHg = 29.92

  /// How far pressure altitude rises for each inch of mercury the altimeter setting falls.
  private static let pressureAltitudeFtPerInHg = 1000.0

  /// Time interval during which these conditions are valid.
  public let validTime: DateInterval

  /// Data source for these conditions.
  public let source: Source

  /// Wind direction in degrees true, or `nil` for variable winds.
  public let windDirection: Measurement<UnitAngle>?

  /// Wind speed, or `nil` if not reported.
  public let windSpeed: Measurement<UnitSpeed>?

  /// Temperature, or `nil` if not reported.
  public let temperature: Measurement<UnitTemperature>?

  /// Dewpoint temperature, or `nil` if not reported.
  public let dewpoint: Measurement<UnitTemperature>?

  /// Sea level pressure (the altimeter setting), or `nil` if not reported.
  public let seaLevelPressure: Measurement<UnitPressure>?

  /// Whether winds are calm (less than 1 knot or not reported).
  public var windsCalm: Bool {
    windSpeed.map { $0 < Measurement(value: 1, unit: UnitSpeed.knots) } ?? true
  }

  /// Whether these conditions carry an altimeter setting that corrects field elevation to
  /// pressure altitude.
  ///
  /// ISA conditions carry the standard setting, which corrects nothing.
  public var hasAltimeterSetting: Bool { seaLevelPressure != nil && source != .ISA }

  /// Whether the wind was reported as variable rather than not reported at all.
  ///
  /// A station reporting variable winds publishes a speed and no direction. The absent direction is
  /// part of what it said — the wind has no prevailing direction to give — so it is not a gap for
  /// another service to fill.
  public var windIsVariable: Bool { windSpeed != nil && windDirection == nil }

  /// Whether every value is reported, leaving nothing for another service to fill in.
  ///
  /// A wind reported as variable counts as reported, so having no direction doesn't by itself send
  /// the lookup on to another service.
  public var isComplete: Bool {
    windSpeed != nil && temperature != nil && dewpoint != nil && seaLevelPressure != nil
  }

  /**
   * Creates conditions from every value.
   *
   * - Parameters:
   *   - validTime: The period these conditions apply to.
   *   - source: Where the values came from.
   *   - windDirection: Wind direction in degrees true, or `nil` for variable winds.
   *   - windSpeed: Wind speed.
   *   - temperature: Temperature.
   *   - dewpoint: Dewpoint temperature.
   *   - seaLevelPressure: Sea level pressure (altimeter setting).
   */
  public init(
    validTime: DateInterval,
    source: Source,
    windDirection: Measurement<UnitAngle>?,
    windSpeed: Measurement<UnitSpeed>?,
    temperature: Measurement<UnitTemperature>?,
    dewpoint: Measurement<UnitTemperature>?,
    seaLevelPressure: Measurement<UnitPressure>?
  ) {
    self.validTime = validTime
    self.source = source
    self.windDirection = windDirection
    self.windSpeed = windSpeed
    self.temperature = temperature
    self.dewpoint = dewpoint
    self.seaLevelPressure = seaLevelPressure
  }

  /**
   * Creates conditions with manually entered values.
   *
   * - Parameters:
   *   - windDirection: Wind direction in degrees true.
   *   - windSpeed: Wind speed.
   *   - temperature: Temperature.
   *   - seaLevelPressure: Sea level pressure (altimeter setting).
   */
  public init(
    windDirection: Measurement<UnitAngle>? = nil,
    windSpeed: Measurement<UnitSpeed>? = nil,
    temperature: Measurement<UnitTemperature>? = nil,
    seaLevelPressure: Measurement<UnitPressure>? = nil
  ) {
    validTime = .init(start: .now, duration: 3600)
    self.windDirection = windDirection
    self.windSpeed = windSpeed
    self.temperature = temperature
    dewpoint = nil
    self.seaLevelPressure = seaLevelPressure
    source = .entered
  }

  /// Creates conditions with the given values, attributed to the services that supplied them.
  ///
  /// - Parameters:
  ///   - validTime: The period these conditions apply to.
  ///   - providers: The services the values came from.
  ///   - windDirection: Wind direction in degrees true, or `nil` for variable winds.
  ///   - windSpeed: Wind speed.
  ///   - temperature: Temperature.
  ///   - dewpoint: Dewpoint temperature.
  ///   - seaLevelPressure: Sea level pressure (altimeter setting).
  public init(
    validTime: DateInterval,
    providers: WeatherProviders,
    windDirection: Measurement<UnitAngle>?,
    windSpeed: Measurement<UnitSpeed>?,
    temperature: Measurement<UnitTemperature>?,
    dewpoint: Measurement<UnitTemperature>?,
    seaLevelPressure: Measurement<UnitPressure>?
  ) {
    self.init(
      validTime: validTime,
      source: .downloaded(providers),
      windDirection: windDirection,
      windSpeed: windSpeed,
      temperature: temperature,
      dewpoint: dewpoint,
      seaLevelPressure: seaLevelPressure
    )
  }

  /// Creates ISA standard conditions (sea level, 15°C, 1013.25 hPa, calm winds).
  public init() {
    validTime = .init(start: .now, duration: 3600)
    windDirection = .init(value: 0, unit: .degrees)
    windSpeed = .init(value: 0, unit: .knots)
    temperature = standardTemperature
    dewpoint = nil
    seaLevelPressure = standardSeaLevelPressure
    source = .ISA
  }

  /// Returns these conditions with each unreported value taken from `other`.
  ///
  /// The period stays this report's own: `other` is filling gaps in it, not describing a period of
  /// its own. Both services are credited, since the result carries values from each.
  ///
  /// - Parameter other: The conditions to fill the gaps from.
  /// - Returns: The combined conditions.
  public func filling(from other: Self) -> Self {
    .init(
      validTime: validTime,
      source: source.adding(other.source),
      windDirection: windDirection(filledFrom: other),
      windSpeed: windSpeed ?? other.windSpeed,
      temperature: temperature ?? other.temperature,
      dewpoint: dewpoint ?? other.dewpoint,
      seaLevelPressure: seaLevelPressure ?? other.seaLevelPressure
    )
  }

  /// The wind direction to carry into a merge with `other`.
  ///
  /// A wind reported as variable keeps its absent direction. `other` will usually offer a definite
  /// one, but taking it would claim a prevailing wind the reporting station said isn't there, and
  /// the runway would be credited with a headwind nobody observed.
  private func windDirection(filledFrom other: Self) -> Measurement<UnitAngle>? {
    guard !windIsVariable else { return nil }
    return windDirection ?? other.windDirection
  }

  /// Returns conditions modified by user-entered values, changing the source to `.entered`.
  public func userModified(with conditions: Self) -> Self {
    .init(
      validTime: validTime,
      source: .entered,
      windDirection: conditions.windDirection ?? windDirection,
      windSpeed: conditions.windSpeed ?? windSpeed,
      temperature: conditions.temperature ?? temperature,
      dewpoint: conditions.dewpoint ?? dewpoint,
      seaLevelPressure: conditions.seaLevelPressure ?? seaLevelPressure
    )
  }

  /// Returns the temperature at the given elevation, using ISA lapse rate if not reported.
  public func temperature(at elevation: Measurement<UnitLength>) -> Measurement<UnitTemperature> {
    if source == .ISA {
      return ISATemperature(at: elevation)
    }
    return temperature ?? ISATemperature(at: elevation)
  }

  /// Calculates density altitude at the given elevation using NWS dry-air formula.
  public func densityAltitude(elevation: Measurement<UnitLength>) -> Measurement<UnitLength> {
    let stationPressureInHg = absolutePressure(elevation: elevation)
      .converted(to: .inchesOfMercury).value
    let tempDegF = temperature(at: elevation).converted(to: .fahrenheit).value

    let DA = SF50Performance.densityAltitude(
      stationPressureInHg: stationPressureInHg,
      temperatureF: tempDegF
    )
    return .init(value: DA, unit: .feet)
  }

  /**
   * The pressure altitude at a field, from its elevation and the altimeter setting.
   *
   * Each inch of mercury the altimeter setting falls below standard puts the field 1,000 ft
   * higher in the standard atmosphere. Without an altimeter setting — and for ISA conditions,
   * whose setting is standard by definition — the field elevation is used unchanged; check
   * ``hasAltimeterSetting`` to say which.
   *
   * - Parameter elevation: The field elevation.
   * - Returns: The pressure altitude the takeoff and landing tables are read at.
   */
  public func pressureAltitude(elevation: Measurement<UnitLength>) -> Measurement<UnitLength> {
    guard hasAltimeterSetting, let seaLevelPressure else { return elevation }
    let altimeterInHg = seaLevelPressure.converted(to: .inchesOfMercury).value,
      correctionFt = (Self.standardAltimeterInHg - altimeterInHg) * Self.pressureAltitudeFtPerInHg
    return elevation + .init(value: correctionFt, unit: .feet)
  }

  private func absolutePressure(elevation: Measurement<UnitLength>) -> Measurement<UnitPressure> {
    let SLP = seaLevelPressure ?? .init(value: standardSeaLevelPressureHPa, unit: .hectopascals)
    return pressure(altimeter: SLP, altitude: elevation)
  }

  private func pressure(altimeter: Measurement<UnitPressure>, altitude: Measurement<UnitLength>)
    -> Measurement<UnitPressure>
  {
    let slpPa = altimeter.converted(to: .hectopascals).value * 100
    let altM = altitude.converted(to: .meters).value

    let pressurePa = pressureAtAltitude(seaLevelPressurePa: slpPa, altitudeM: altM)
    return .init(value: pressurePa / 100, unit: .hectopascals)
  }

  /// Where weather conditions came from.
  public enum Source: Sendable, Equatable {
    /// Downloaded from the given services.
    ///
    /// More than one contributes when an aviation report leaves values unreported and a forecast
    /// model fills them in.
    case downloaded(WeatherProviders)

    /// International Standard Atmosphere defaults.
    case ISA

    /// Manually entered by user.
    case entered

    /// The services that contributed, or nothing for conditions that weren't downloaded.
    public var providers: WeatherProviders {
      guard case .downloaded(let providers) = self else { return [] }
      return providers
    }

    /// Returns this source credited with `other`'s services as well.
    ///
    /// Only downloaded sources combine: filling gaps in an entered or ISA report would change what
    /// it is, and neither is ever the base of a merge.
    public func adding(_ other: Self) -> Self {
      guard case .downloaded(let providers) = self,
        case .downloaded(let otherProviders) = other
      else { return self }
      return .downloaded(providers.union(otherProviders))
    }
  }
}
