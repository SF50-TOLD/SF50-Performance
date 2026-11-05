public import Foundation
import MeasurementKit

/// The runway restrictions a NOTAM imposes, as the performance models read them.
///
/// ``NOTAMInput`` is a `Sendable` value type, so it can cross into whatever context runs a
/// calculation.
public struct NOTAMInput: Sendable, Equatable {
  /// Raw contamination type string for serialization
  public let contaminationType: String?

  /// Depth of contamination on the runway surface
  public let contaminationDepth: Measurement<UnitLength>

  /// Runway Condition Code (1–6) for RwyCC contamination type
  public let rwyCC: UInt8?

  /// Reduction in takeoff distance available
  public let takeoffDistanceShortening: Measurement<UnitLength>

  /// Reduction in landing distance available
  public let landingDistanceShortening: Measurement<UnitLength>

  /// Height of obstacle above runway
  public let obstacleHeight: Measurement<UnitLength>

  /// Distance from the departure end of the runway to the obstacle
  public let obstacleDistance: Measurement<UnitLength>

  /// Parsed contamination enum from type string and depth
  public var contamination: Contamination? {
    guard let type = contaminationType else { return nil }
    return Contamination(
      type: type,
      depth: contaminationDepth.converted(to: .meters).value,
      rwyCC: rwyCC
    )
  }

  /// The obstacle this NOTAM reports off the departure end, or `nil` where it reports none.
  public var obstacle: Obstacle? {
    guard obstacleHeight > .zero else { return nil }
    return .init(height: obstacleHeight, distanceFromDepartureEnd: obstacleDistance)
  }

  /**
   * Creates a NOTAM snapshot.
   *
   * - Parameters:
   *   - contaminationType: The raw contamination type, as ``Contamination`` persists it.
   *   - contaminationDepth: Depth of the contaminant.
   *   - rwyCC: Runway Condition Code (1–6), for RwyCC contamination.
   *   - takeoffDistanceShortening: Reduction in takeoff distance available.
   *   - landingDistanceShortening: Reduction in landing distance available.
   *   - obstacleHeight: Height of an obstacle above the runway, or zero for none.
   *   - obstacleDistance: Distance of that obstacle beyond the departure end of the runway.
   */
  public init(
    contaminationType: String?,
    contaminationDepth: Measurement<UnitLength>,
    rwyCC: UInt8? = nil,
    takeoffDistanceShortening: Measurement<UnitLength>,
    landingDistanceShortening: Measurement<UnitLength>,
    obstacleHeight: Measurement<UnitLength>,
    obstacleDistance: Measurement<UnitLength>
  ) {
    self.contaminationType = contaminationType
    self.contaminationDepth = contaminationDepth
    self.rwyCC = rwyCC
    self.takeoffDistanceShortening = takeoffDistanceShortening
    self.landingDistanceShortening = landingDistanceShortening
    self.obstacleHeight = obstacleHeight
    self.obstacleDistance = obstacleDistance
  }
}

/// The runway facts a performance calculation needs.
///
/// ``RunwayInput`` is a `Sendable` value type, so it can cross into whatever context runs a
/// calculation. It includes all runway properties needed for performance calculations.
public struct RunwayInput: Identifiable, Hashable, Sendable, Comparable, RunwayOrientation {
  // MARK: - Properties

  /// Unique identifier (runway name)
  public let id: String

  /// Runway threshold elevation
  public let elevation: Measurement<UnitLength>

  /// True heading of the runway
  public let trueHeading: Measurement<UnitAngle>

  /// Runway gradient as a fraction (positive = upslope)
  public let gradient: Float

  /// Total runway length
  public let length: Measurement<UnitLength>

  /// Declared takeoff run available (TORA)
  public let takeoffRun: Measurement<UnitLength>?

  /// Declared takeoff distance available (TODA)
  public let takeoffDistance: Measurement<UnitLength>?

  /// Declared landing distance available (LDA)
  public let landingDistance: Measurement<UnitLength>?

  /// Takeoff run available, less any NOTAMed shortening.
  ///
  /// A ground run has to fit the run rather than the distance, which are different wherever a
  /// runway has a clearway.
  public var availableTakeoffRun: Measurement<UnitLength> {
    (takeoffRun ?? length) - takeoffShortening
  }

  /// Takeoff distance available, less any NOTAMed shortening.
  public var availableTakeoffDistance: Measurement<UnitLength> {
    (takeoffDistance ?? length) - takeoffShortening
  }

  /// Landing distance available, less any NOTAMed shortening.
  ///
  /// Shorter than the pavement wherever the threshold is displaced, so it — not the length — is
  /// what a landing distance leaves a margin against.
  public var availableLandingDistance: Measurement<UnitLength> {
    (landingDistance ?? length) - landingShortening
  }

  private var takeoffShortening: Measurement<UnitLength> {
    notam?.takeoffDistanceShortening ?? .zero
  }

  private var landingShortening: Measurement<UnitLength> {
    notam?.landingDistanceShortening ?? .zero
  }

  /// Surface type of the runway
  public let surfaceType: SurfaceType

  /// Surface type as the source data recorded it, or `nil` where it recorded none.
  ///
  /// ``surfaceType`` substitutes `.paved` for a surface nothing established, so a readout that
  /// named it would state a fact the data never gave.
  public let recordedSurfaceType: SurfaceType?

  /// Whether the gradient was surveyed, or estimable from a reciprocal threshold elevation.
  ///
  /// ``gradient`` answers zero for a runway that is neither, and announcing that as level asserts
  /// a slope nothing measured.
  public let hasKnownGradient: Bool

  /// Whether the runway has a turf surface
  public var isTurf: Bool { surfaceType.isTurf }

  /// Whether the runway has a grooved or PFC surface
  public var isGroovedOrPFC: Bool { surfaceType.isGroovedOrPFC }

  /// Active NOTAM snapshot if present
  public let notam: NOTAMInput?

  /// Magnetic variation at the airport
  public let airportVariation: Measurement<UnitAngle>

  /// Threshold crossing height for approach (nil if not available)
  public let thresholdCrossingHeight: Measurement<UnitLength>?

  /// Glidepath angle from ILS or PAPI/VASI (nil if not available)
  public let glidepathAngle: Measurement<UnitAngle>?

  /// Displaced threshold distance from runway end (nil if not displaced)
  public let displacedThresholdDistance: Measurement<UnitLength>?

  /// Runway designator (alias for id)
  public var name: String { id }

  // MARK: - Initialization

  /**
   * Creates a runway snapshot.
   *
   * - Parameters:
   *   - id: The runway designator.
   *   - elevation: Threshold elevation.
   *   - trueHeading: Runway heading in degrees true.
   *   - gradient: Runway gradient as a fraction, positive upslope.
   *   - length: Total runway length.
   *   - takeoffRun: Declared takeoff run available, or `nil` for the full length.
   *   - takeoffDistance: Declared takeoff distance available, or `nil` for the full length.
   *   - landingDistance: Declared landing distance available, or `nil` for the full length.
   *   - surfaceType: The surface the models treat the runway as.
   *   - recordedSurfaceType: The surface the source data recorded, or `nil` where it recorded none.
   *   - hasKnownGradient: Whether the gradient was surveyed or estimable.
   *   - notam: The NOTAM restricting the runway, or `nil` if none does.
   *   - airportVariation: Magnetic variation at the airport.
   *   - thresholdCrossingHeight: Threshold crossing height for the approach.
   *   - glidepathAngle: Glidepath angle from the ILS or visual glide slope indicator.
   *   - displacedThresholdDistance: Displaced threshold distance from the runway end.
   */
  public init(
    id: String,
    elevation: Measurement<UnitLength>,
    trueHeading: Measurement<UnitAngle>,
    gradient: Float,
    length: Measurement<UnitLength>,
    takeoffRun: Measurement<UnitLength>?,
    takeoffDistance: Measurement<UnitLength>?,
    landingDistance: Measurement<UnitLength>?,
    surfaceType: SurfaceType = .paved,
    recordedSurfaceType: SurfaceType? = nil,
    hasKnownGradient: Bool = true,
    notam: NOTAMInput?,
    airportVariation: Measurement<UnitAngle>,
    thresholdCrossingHeight: Measurement<UnitLength>? = nil,
    glidepathAngle: Measurement<UnitAngle>? = nil,
    displacedThresholdDistance: Measurement<UnitLength>? = nil
  ) {
    self.id = id
    self.elevation = elevation
    self.trueHeading = trueHeading
    self.gradient = gradient
    self.length = length
    self.takeoffRun = takeoffRun
    self.takeoffDistance = takeoffDistance
    self.landingDistance = landingDistance
    self.surfaceType = surfaceType
    self.recordedSurfaceType = recordedSurfaceType
    self.hasKnownGradient = hasKnownGradient
    self.notam = notam
    self.airportVariation = airportVariation
    self.thresholdCrossingHeight = thresholdCrossingHeight
    self.glidepathAngle = glidepathAngle
    self.displacedThresholdDistance = displacedThresholdDistance
  }

  // MARK: - Type Methods

  // Comparable implementation for sorting
  public static func < (lhs: Self, rhs: Self) -> Bool {
    let num1 = Int(lhs.name.filter(\.isNumber)) ?? 0,
      num2 = Int(rhs.name.filter(\.isNumber)) ?? 0

    if num1 != num2 {
      return num1 < num2
    }

    // If numbers are equal, compare the letters
    let letter1 = lhs.name.filter(\.isLetter),
      letter2 = rhs.name.filter(\.isLetter)

    // Order: no letter < L < C < R
    let letterOrder = ["": 0, "L": 1, "C": 2, "R": 3],
      val1 = letterOrder[letter1] ?? 4,
      val2 = letterOrder[letter2] ?? 4

    return val1 < val2
  }

  // MARK: - Instance Methods

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  /// Creates a copy of this runway with contamination override applied
  public func withContamination(_ contamination: Contamination?) -> Self {
    let newNotam: NOTAMInput? =
      if let notam {
        // Create a new NOTAM with the contamination override but keep other values
        NOTAMInput(
          contaminationType: contamination?.type,
          contaminationDepth: .init(value: contamination?.depth ?? 0, unit: .meters),
          rwyCC: contamination?.rwyCC,
          takeoffDistanceShortening: notam.takeoffDistanceShortening,
          landingDistanceShortening: notam.landingDistanceShortening,
          obstacleHeight: notam.obstacleHeight,
          obstacleDistance: notam.obstacleDistance
        )
      } else if let contamination {
        // Create a new NOTAM with just the contamination
        NOTAMInput(
          contaminationType: contamination.type,
          contaminationDepth: .init(value: contamination.depth ?? 0, unit: .meters),
          rwyCC: contamination.rwyCC,
          takeoffDistanceShortening: .init(value: 0, unit: .meters),
          landingDistanceShortening: .init(value: 0, unit: .meters),
          obstacleHeight: .init(value: 0, unit: .meters),
          obstacleDistance: .init(value: 0, unit: .meters)
        )
      } else {
        nil
      }

    return Self(
      id: id,
      elevation: elevation,
      trueHeading: trueHeading,
      gradient: gradient,
      length: length,
      takeoffRun: takeoffRun,
      takeoffDistance: takeoffDistance,
      landingDistance: landingDistance,
      surfaceType: surfaceType,
      recordedSurfaceType: recordedSurfaceType,
      hasKnownGradient: hasKnownGradient,
      notam: newNotam,
      airportVariation: airportVariation,
      thresholdCrossingHeight: thresholdCrossingHeight,
      glidepathAngle: glidepathAngle,
      displacedThresholdDistance: displacedThresholdDistance
    )
  }
}

/// The airport facts a performance calculation needs, with every runway.
///
/// ``AirportInput`` is a `Sendable` value type, so it can cross into whatever context runs a
/// calculation.
public struct AirportInput: Sendable {
  /// Unique record identifier
  public let recordID: String

  /// Airport location identifier (FAA LID or ICAO)
  public let locationID: String

  /// Airport name
  public let name: String

  /// Airport field elevation
  public let elevation: Measurement<UnitLength>

  /// Magnetic variation at the airport
  public let variation: Measurement<UnitAngle>

  /// Local timezone for the airport
  public let timeZone: TimeZone?

  /// Runways at this airport
  public let runways: [RunwayInput]

  /**
   * Creates an airport snapshot.
   *
   * - Parameters:
   *   - recordID: Unique record identifier.
   *   - locationID: Airport location identifier (FAA LID or ICAO).
   *   - name: Airport name.
   *   - elevation: Airport field elevation.
   *   - variation: Magnetic variation at the airport.
   *   - timeZone: Local time zone, or `nil` where unknown.
   *   - runways: The airport's runways.
   */
  public init(
    recordID: String,
    locationID: String,
    name: String,
    elevation: Measurement<UnitLength>,
    variation: Measurement<UnitAngle>,
    timeZone: TimeZone?,
    runways: [RunwayInput]
  ) {
    self.recordID = recordID
    self.locationID = locationID
    self.name = name
    self.elevation = elevation
    self.variation = variation
    self.timeZone = timeZone
    self.runways = runways
  }
}
