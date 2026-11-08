/// The type of performance operation being calculated.
///
/// ``Operation`` distinguishes between takeoff and landing performance
/// calculations, which use different AFM data tables and calculation methods.
public enum Operation: String, CaseIterable, Codable, Sendable {
  /// Takeoff performance calculation
  case takeoff
  /// Landing performance calculation
  case landing
}
