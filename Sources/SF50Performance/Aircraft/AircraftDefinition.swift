import Foundation

/// What one aircraft type contributes to the performance models beyond its data package.
///
/// A data package says which tables and equations each configuration has. A definition says
/// which configuration an aircraft flies, the limitations its manual sets, and the parts of the
/// manual that aren't tables, such as a flap setting given only as a factor on another's figures.
protocol AircraftDefinition: Sendable {
  /// The base manual and the supplements installed over it.
  var configurationSelection: ConfigurationSelection { get }

  /// The operating limitations the manual sets.
  var limitations: any Limitations.Type { get }

  /// The bundled data package for the aircraft type.
  func package() throws -> DataPackage

  /// The landing tables a flap setting is read from.
  ///
  /// - Parameter flapSetting: The landing flap setting.
  func landingTables(for flapSetting: FlapSetting) -> LandingTables
}

extension AircraftDefinition {
  /// The tables and equations of the configuration the aircraft flies.
  ///
  /// - Throws: ``PerformanceDataError`` if the configuration could not be read from the bundle.
  func data() throws -> AircraftData {
    try package().configuration(configurationSelection)
  }
}

/// A base manual and the supplements installed over it, by their names in a data package.
struct ConfigurationSelection: Sendable, Hashable {
  /// The base document's name.
  let base: String

  /// The installed supplements' names.
  let supplements: Set<String>
}

/// The landing tables a flap setting reads, and how its figures follow from them.
struct LandingTables: Sendable, Hashable {
  /// The flap setting whose landing tables and equations are read.
  let flapSetting: FlapSetting

  /// The factor applied to the tabulated total distance, or `nil` if it applies unchanged.
  let totalDistanceFactor: Double?

  /// Whether the manual gives a ground run for the setting.
  var hasGroundRun: Bool { totalDistanceFactor == nil }
}
