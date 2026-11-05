public import Foundation

extension ClimbProfileGenerator {

  /// The altitude of the highest level a synthesized profile extends to.
  private static let maxWindsAltitudeFt: Double = 18000

  /// The spacing between the levels of a synthesized profile.
  private static let windsAltitudeStepFt: Double = 3000

  /// A calm column standing in for a winds aloft forecast that doesn't cover the flight.
  ///
  /// The winds are calm rather than the surface wind carried aloft: surface wind describes the
  /// first few hundred feet and nothing above, so extending it up through the climb would invent a
  /// wind field rather than admit there is none.
  ///
  /// The field's own level takes the reported temperature whatever its source: an observation
  /// describes the surface, and that is the surface.
  ///
  /// Above it, only a temperature the pilot *entered* is carried up, offset from the standard
  /// atmosphere by the deviation measured at the field — so a day that is fifteen degrees above
  /// standard stays fifteen above all the way up the climb. Entered weather is a statement about
  /// the atmosphere to fly through, made when nothing else is available; a downloaded surface
  /// report is an observation of the surface, and stays there, because a forecast covering the
  /// levels above it is what should be used instead.
  ///
  /// A constant deviation is the standard-atmosphere assumption pilots plan on. It describes a
  /// well-mixed air mass, and overstates the temperature aloft under a surface inversion.
  ///
  /// - Parameters:
  ///   - conditions: The measured, forecast, or entered conditions at the field.
  ///   - fieldElevation: The elevation of the departure or arrival airport.
  /// - Returns: Calm observations every 3,000 ft from the field to 18,000 ft.
  public static func standardObservations(
    conditions: Conditions,
    fieldElevation: Measurement<UnitLength>
  ) -> [WindsAloftObservation] {
    let fieldElevationFt = fieldElevation.converted(to: .feet).value
    // Read through `temperature(at:)` rather than the raw property, so a report that leaves the
    // temperature out — and a standard-atmosphere report at a field far above sea level — start
    // from the standard temperature *there* rather than from sea level's.
    let surfaceTemperatureC = conditions.temperature(at: fieldElevation)
      .converted(to: .celsius).value
    // Nothing to carry unless the pilot entered a temperature: a column with no reading of its own
    // deviates from standard by nothing.
    let deviationC =
      conditions.source == .entered && conditions.temperature != nil
      ? surfaceTemperatureC - isaTemperature(altitudeFt: fieldElevationFt) : 0

    return stride(
      from: fieldElevationFt,
      through: maxWindsAltitudeFt,
      by: windsAltitudeStepFt
    ).map { altitudeFt in
      .init(
        altitudeFt: altitudeFt,
        temperatureC: altitudeFt == fieldElevationFt
          ? surfaceTemperatureC : isaTemperature(altitudeFt: altitudeFt) + deviationC,
        windDirectionDeg: 0,
        windSpeedKts: 0
      )
    }
  }
}
