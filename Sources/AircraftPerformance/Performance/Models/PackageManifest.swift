import Foundation

/// A data package's `manifest.json`: what the package holds and how its documents combine into
/// configurations.
///
/// The format is Data-Extraction's `docs/data-package.md`, package format 1.
struct PackageManifest: Decodable, Sendable {
  /// The package format this loader reads.
  static let supportedFormat = 1

  /// The equation file version this loader evaluates.
  static let supportedEquationFormat = "1.0"

  /// The package format.
  let format: Int

  /// The equation file version every equation in the package has.
  let equationFormat: String

  /// The aircraft the package describes.
  let aircraft: Aircraft

  /// The manuals the tables are extracted from, keyed by document name.
  let documents: [String: Document]

  /// The combinations of a base manual and supplements, keyed by configuration name.
  let configurations: [String: Configuration]

  /// The fitted equations, keyed by equation name.
  let equations: [String: Equation]

  enum CodingKeys: String, CodingKey {
    case format, aircraft, documents, configurations, equations
    case equationFormat = "equation_format"
  }

  /// The aircraft a package describes.
  struct Aircraft: Decodable, Sendable {
    /// The package's short name, such as `sf50`.
    let name: String

    /// The aircraft's display name.
    let title: String
  }

  /// A base manual or a supplement to one.
  struct Document: Decodable, Sendable {
    /// The manual's title.
    let title: String

    /// Whether the manual is complete or amends a base.
    let kind: Kind

    /// The manual's part number.
    let partNumber: String

    /// The manual's revision.
    let revision: String

    /// The bases a supplement amends; empty when it amends any.
    let appliesTo: [String]

    /// The supplements this one can't be installed with.
    let excludes: [String]

    /// The misprints the package's tables correct.
    let errata: [Erratum]

    enum CodingKeys: String, CodingKey {
      case title, kind, revision, excludes, errata
      case partNumber = "part_number"
      case appliesTo = "applies_to"
    }

    /// Whether a document is a complete manual or a supplement.
    enum Kind: String, Decodable, Sendable {
      case base
      case supplement
    }
  }

  /// A cell a document misprints, and the value its table holds instead.
  struct Erratum: Decodable, Sendable {
    /// The table's path, such as `enroute climb/gradient.csv`.
    let table: String

    /// The cell's inputs, keyed by column name.
    let cell: [String: Double]

    /// The value the document prints.
    let printed: Double

    /// The value the table holds.
    let corrected: Double

    /// Why the printed value is wrong.
    let reason: String

    /// Where the correction comes from.
    let sources: [String]
  }

  /// A base manual plus a set of supplements installed together.
  struct Configuration: Decodable, Sendable {
    /// The base document's name.
    let base: String

    /// The installed supplements' names.
    let supplements: [String]

    /// The document each table path is read from.
    let tables: [String: String]

    /// Guidance that applies to the configuration.
    let notes: [Note]

    /// Operating limits the configuration's manuals set, keyed by name, such as
    /// `maximum-takeoff-altitude`.
    let limits: [String: Limit]?
  }

  /// An operating limit a manual sets.
  struct Limit: Decodable, Sendable {
    /// The limit's value, in ``unit``.
    let value: Double

    /// The value's unit, such as `ft` or `degC`.
    let unit: String

    /// Where the limit comes from.
    let sources: [String]
  }

  /// Guidance for a configuration, such as a limitation a supplement adds.
  struct Note: Decodable, Sendable {
    /// What the note is about.
    let subject: String

    /// The guidance.
    let text: String

    /// Where the guidance comes from.
    let sources: [String]
  }

  /// A fitted equation's source table and inputs.
  struct Equation: Decodable, Sendable {
    /// The path of the table the equation is fitted to.
    let table: String

    /// The equation's inputs, in term order.
    let variables: [Variable]

    /// An equation input and its unit.
    struct Variable: Decodable, Sendable {
      /// The input's name, such as `weight`.
      let name: String

      /// The input's unit, such as `lb`.
      let unit: String
    }
  }
}

extension PackageManifest {
  /// Confirms that this loader reads the package's format and its equations' version.
  ///
  /// - Throws: ``PerformanceDataError/unsupportedPackageFormat(package:format:)`` otherwise.
  func validateFormat() throws {
    guard format == Self.supportedFormat else {
      throw PerformanceDataError.unsupportedPackageFormat(
        package: aircraft.name,
        format: String(format)
      )
    }
    guard equationFormat == Self.supportedEquationFormat else {
      throw PerformanceDataError.unsupportedPackageFormat(
        package: aircraft.name,
        format: "equations \(equationFormat)"
      )
    }
  }

  /// The name of the configuration with a base manual and exactly a set of supplements.
  ///
  /// - Parameters:
  ///   - base: The base document's name.
  ///   - supplements: The names of the supplements installed over it.
  /// - Returns: The configuration's name, or `nil` if the package has no such combination.
  func configurationName(base: String, supplements: Set<String>) -> String? {
    configurations.first { _, configuration in
      configuration.base == base && Set(configuration.supplements) == supplements
    }?.key
  }
}
