public import Foundation

/// An aircraft whose performance the models calculate: its type and the options installed on it.
///
/// Each type is backed by its own data package of manual tables and fitted equations. What an
/// aircraft has figures for differs between types, and ``capabilities`` says which.
public enum Aircraft: Sendable, Hashable, Codable {
  /// A Cirrus SF50 Vision Jet.
  case sf50(SF50Variant)

  /// The aircraft's operating limitations.
  public var limitations: AircraftLimitations { definition.limitations }

  /// The calculations the aircraft's manual has figures for, beyond takeoff and landing
  /// distances and takeoff and en route climb.
  public var capabilities: Set<PerformanceCapability> { definition.capabilities }

  /// The flap settings the manual gives takeoff figures for.
  public var takeoffFlapSettings: [FlapSetting] { definition.takeoffFlapSettings }

  /// The flap settings the manual gives landing figures for.
  public var landingFlapSettings: [FlapSetting] { definition.landingFlapSettings }

  var definition: any AircraftDefinition {
    switch self {
      case .sf50(let variant): SF50Definition(variant: variant)
    }
  }

  /// The manuals the aircraft's figures come from, and the guidance that goes with them.
  ///
  /// - Throws: ``PerformanceDataError`` if the bundled data could not be read.
  public func configurationInfo() throws -> AircraftConfigurationInfo {
    try definition.configurationInfo()
  }
}

/// A calculation only some aircraft's manuals have figures for.
public enum PerformanceCapability: String, Sendable, Hashable, CaseIterable, Codable {
  /// VREF, by weight and flap setting.
  case vref

  /// Whether the go-around (balked landing) climb gradient is met.
  case goAroundClimbGradient = "go_around_climb_gradient"

  /// Balked landing climb gradient and rate.
  case balkedLandingClimb = "balked_landing_climb"

  /// Landing on a contaminated runway, including AC 91-79B runway condition codes.
  case contamination

  /// Figures with the ice protection system on.
  case iceProtection = "ice_protection"

  /// En route obstacle climb gradient.
  case enrouteObstacleClimb = "enroute_obstacle_climb"

  /// Time, fuel and distance to climb.
  case timeFuelDistanceToClimb = "time_fuel_distance_to_climb"

  /// Time, fuel and distance to climb leaning to the lean side of peak EGT.
  case leanOfPeakClimb = "lean_of_peak_climb"

  /// The takeoff correction for running the air conditioner.
  case airConditionerCorrection = "air_conditioner_correction"

  /// The correction for a wet unpaved runway.
  case wetUnpavedCorrection = "wet_unpaved_correction"
}

/// The manuals an aircraft's figures come from, and the guidance that goes with them.
public struct AircraftConfigurationInfo: Sendable, Hashable {
  /// The aircraft type's display name.
  public let aircraftTitle: String

  /// The base manual, then the installed supplements.
  public let documents: [Document]

  /// Guidance for this combination of manuals, such as a limitation a supplement adds.
  public let notes: [Note]

  /// A manual the figures come from.
  public struct Document: Sendable, Hashable {
    /// The manual's title.
    public let title: String

    /// The manual's part number.
    public let partNumber: String

    /// The manual's revision.
    public let revision: String

    /// Whether the manual supplements another.
    public let isSupplement: Bool

    /// The misprints in the manual that the figures correct.
    public let errata: [Erratum]
  }

  /// A misprinted table cell, and the value the figures use instead.
  public struct Erratum: Sendable, Hashable {
    /// The table, such as `enroute climb/gradient.csv`.
    public let table: String

    /// The cell's inputs, keyed by input name.
    public let cell: [String: Double]

    /// The value the manual prints.
    public let printed: Double

    /// The value the figures use.
    public let corrected: Double

    /// Why the printed value is wrong.
    public let reason: String
  }

  /// Guidance for a combination of manuals.
  public struct Note: Sendable, Hashable {
    /// What the note is about.
    public let subject: String

    /// The guidance.
    public let text: String

    /// Where the guidance comes from.
    public let sources: [String]
  }
}
