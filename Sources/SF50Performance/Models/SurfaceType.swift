/// Runway surface type, distinguishing grooved and PFC surfaces for RwyCC factor lookup.
public enum SurfaceType: String, Codable, CaseIterable, Sendable {
  /// A paved surface without grooving or a porous friction course.
  case paved
  /// A grooved paved surface.
  case grooved
  /// A paved surface with a porous friction course.
  case pfc
  /// A grass or turf surface.
  case turf

  /// Whether this surface type is unpaved (grass/turf)
  public var isTurf: Bool { self == .turf }

  /// Whether this surface type has grooved or PFC treatment
  public var isGroovedOrPFC: Bool { self == .grooved || self == .pfc }
}
