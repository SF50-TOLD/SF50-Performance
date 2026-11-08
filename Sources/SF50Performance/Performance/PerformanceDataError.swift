public import Foundation

/// The bundled AFM data could not be read.
///
/// Every model reads its tables and equations from the package's own resources, so this error
/// means the package was built or installed without them, or they were damaged.
public enum PerformanceDataError: Error, LocalizedError {
  /// A data file the models need is not in the bundle.
  case missingResource(path: String)

  /// A data file is in the bundle but could not be read.
  case unreadableResource(path: String, underlying: any Error)

  /// A regression equation names residuals the bundle does not carry.
  case missingResiduals(table: String)

  /// A data package has no configuration with a base manual and exactly a set of supplements.
  case missingConfiguration(package: String, base: String, supplements: [String])

  /// A data package is in a format, or holds equations in a version, this package doesn't read.
  case unsupportedPackageFormat(package: String, format: String)

  public var errorDescription: String? {
    String(
      localized: "Performance data couldn’t be loaded.",
      bundle: .module,
      comment: "Error description for missing or damaged bundled performance data."
    )
  }

  public var failureReason: String? {
    switch self {
      case .missingResource(let path):
        String(
          localized: "The data file “\(path)” is missing.",
          bundle: .module,
          comment: "Failure reason for bundled performance data. The argument is a file path."
        )
      case let .unreadableResource(path, underlying):
        String(
          localized: "The data file “\(path)” couldn’t be read: \(underlying.localizedDescription)",
          bundle: .module,
          comment:
            "Failure reason for bundled performance data. The arguments are a file path and the underlying error."
        )
      case .missingResiduals(let table):
        String(
          localized: "No residuals were found for the regression table “\(table)”.",
          bundle: .module,
          comment: "Failure reason for bundled performance data. The argument is a table name."
        )
      case let .missingConfiguration(package, base, supplements):
        String(
          localized:
            "The “\(package)” data has no configuration of “\(base)” and supplements [\(supplements.joined(separator: ", "))].",
          bundle: .module,
          comment:
            "Failure reason for bundled performance data. The arguments are a data package name, a base manual name and a list of supplement names."
        )
      case let .unsupportedPackageFormat(package, format):
        String(
          localized: "The “\(package)” data is in an unsupported format (\(format)).",
          bundle: .module,
          comment:
            "Failure reason for bundled performance data. The arguments are a data package name and its format."
        )
    }
  }
}
