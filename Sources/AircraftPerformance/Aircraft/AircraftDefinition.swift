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
  var limitations: AircraftLimitations { get }

  /// The calculations the manual has figures for beyond the ones every aircraft has.
  var capabilities: Set<PerformanceCapability> { get }

  /// The flap settings the manual gives takeoff figures for.
  var takeoffFlapSettings: [FlapSetting] { get }

  /// The flap settings the manual gives landing figures for.
  var landingFlapSettings: [FlapSetting] { get }

  /// The bundled data package for the aircraft type.
  func package() throws -> DataPackage

  /// The landing tables a flap setting is read from.
  ///
  /// - Parameter flapSetting: The landing flap setting.
  func landingTables(for flapSetting: FlapSetting) -> LandingTables
}

extension AircraftDefinition {
  private static func document(_ document: PackageManifest.Document)
    -> AircraftConfigurationInfo.Document
  {
    .init(
      title: document.title,
      partNumber: document.partNumber,
      revision: document.revision,
      isSupplement: document.kind == .supplement,
      errata: document.errata.map {
        .init(
          table: $0.table,
          cell: $0.cell,
          printed: $0.printed,
          corrected: $0.corrected,
          reason: $0.reason
        )
      }
    )
  }

  /// The tables and equations of the configuration the aircraft flies.
  ///
  /// - Throws: ``PerformanceDataError`` if the configuration could not be read from the bundle.
  func data() throws -> AircraftData {
    try package().configuration(configurationSelection)
  }

  /// The manuals of the configuration the aircraft flies, from the package's manifest.
  ///
  /// - Throws: ``PerformanceDataError`` if the package could not be read or has no such
  ///   configuration.
  func configurationInfo() throws -> AircraftConfigurationInfo {
    let manifest = try package().manifest,
      selection = configurationSelection
    guard
      let name = manifest.configurationName(
        base: selection.base,
        supplements: selection.supplements
      ),
      let configuration = manifest.configurations[name]
    else {
      throw PerformanceDataError.missingConfiguration(
        package: manifest.aircraft.name,
        base: selection.base,
        supplements: selection.supplements.sorted()
      )
    }
    let documentNames = [configuration.base] + configuration.supplements
    return .init(
      aircraftTitle: manifest.aircraft.title,
      documents: documentNames.compactMap { name in manifest.documents[name].map(Self.document) },
      notes: configuration.notes.map {
        .init(subject: $0.subject, text: $0.text, sources: $0.sources)
      }
    )
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
