import Foundation

@testable import AircraftPerformance

enum Helper {

  static func createTestConditions(
    temperature: Double? = nil,
    windDirection: Double = 0,
    windSpeed: Double = 0
  ) -> Conditions {
    let temp = temperature.map { Measurement(value: $0, unit: UnitTemperature.celsius) }
    let windDir = Measurement(value: windDirection, unit: UnitAngle.degrees)
    let windSpeedMeasurement = Measurement(value: windSpeed, unit: UnitSpeed.knots)

    return Conditions(
      windDirection: windDir,
      windSpeed: windSpeedMeasurement,
      temperature: temp
    )
  }

  static func createTestConfiguration(
    weight: Double = 6000,
    flapSetting: FlapSetting = .flaps50,
    iceProtection: Bool = false
  ) -> Configuration {
    Configuration(
      weight: Measurement(value: weight, unit: UnitMass.pounds),
      flapSetting: flapSetting,
      iceProtection: iceProtection
    )
  }

  static func createTestRunway(
    elevation: Double = 0,
    heading: Double = 360,
    slope: Double = 0,
    surfaceType: SurfaceType = .paved,
    notam: NOTAMInput? = nil
  ) -> RunwayInput {
    RunwayInput(
      id: "36",
      elevation: Measurement(value: elevation, unit: .feet),
      trueHeading: Measurement(value: heading, unit: .degrees),
      gradient: Float(slope / 100),
      length: Measurement(value: 5000, unit: .feet),
      takeoffRun: nil,
      takeoffDistance: nil,
      landingDistance: nil,
      surfaceType: surfaceType,
      notam: notam,
      airportVariation: Measurement(value: 0, unit: .degrees)
    )
  }

  /// Creates a constant-gradient climb profile for testing.
  /// Default: 300 ft/NM, 170 KIAS, ISA temps, zero wind, 29.92 inHg.
  /// All five profile variants use the same gradient/speed for backward-compatible behavior.
  static func createTestClimbProfile(
    gradientFtPerNM: Double = 300,
    windDirectionDeg: Double = 0,
    windSpeedKts: Double = 0
  ) -> ClimbProfile {
    // ISA standard temps: 15C at sea level, -56.5C at 36,089 ft (lapse rate 1.98C/1000ft)
    let altitudes: [Double] = [0, 5000, 10000, 15000, 20000, 25000, 30000]
    let dataPoints = altitudes.map { alt in
      let climbData = ClimbProfile.ClimbData(
        gradientFtPerNM: .value(gradientFtPerNM),
        indicatedAirspeedKts: .value(170)
      )
      return ClimbProfile.DataPoint(
        altitudeFt: alt,
        outsideAirTemperatureC: 15.0 - alt * 0.00198,
        windDirectionDeg: windDirectionDeg,
        windSpeedKts: windSpeedKts,
        takeoff: climbData,
        enrouteObstacle: climbData,
        enrouteObstacleAntiIce: climbData,
        enroute: climbData,
        enrouteAntiIce: climbData
      )
    }
    return ClimbProfile(dataPoints: dataPoints, seaLevelPressureInHg: 29.92)
  }
}
