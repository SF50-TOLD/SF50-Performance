import Foundation

/// The fitting error of one regression table, from a data package's `residuals.json`.
///
/// Each entry holds the overall RMSE (root mean square error) of an equation against the table it
/// was fitted to, and the RMSE within bins of each input's range. The regression model reports a
/// figure's RMSE as its uncertainty.
///
/// ## Binned Errors
///
/// When inputs are provided, the RMSE is looked up in the bin containing each input. Multiple bin
/// matches are combined by root-sum-square.
struct ResidualData: Decodable, Sendable {
  private static let filename = "residuals.json"

  let overallRMSE: Double
  let overallMaxError: Double
  let bins: [String: [Bin]]

  enum CodingKeys: String, CodingKey {
    case overallRMSE = "overall_rmse"
    case overallMaxError = "overall_max_error"
    case bins
  }

  /// A range of one input and the RMSE within it.
  struct Bin: Decodable, Sendable {
    let range: [Double]
    let RMSE: Double
    let maxError: Double

    enum CodingKeys: String, CodingKey {
      case range
      case RMSE = "rmse"
      case maxError = "max_error"
    }
  }
}

extension ResidualData {
  /// Reads a package's residuals, keyed by `<document>/<table path without .csv>`.
  ///
  /// - Parameter directory: The package's directory.
  /// - Throws: ``PerformanceDataError`` if the file cannot be read.
  static func load(in directory: URL) throws -> [String: Self] {
    do {
      let data = try Data(contentsOf: directory.appending(component: filename))
      return try JSONDecoder().decode([String: Self].self, from: data)
    } catch {
      throw PerformanceDataError.unreadableResource(path: filename, underlying: error)
    }
  }

  /// The RMSE for the bins containing the inputs, or the overall RMSE where none does.
  ///
  /// The bins are combined in input-name order, so that the same inputs always give the same
  /// figure to the last bit.
  ///
  /// - Parameter binParameters: Input values keyed by input name, such as `weight`.
  func RMSE(binParameters: [String: Double] = [:]) -> Double {
    let matchingRMSEs = binParameters.sorted { $0.key < $1.key }.compactMap { binName, value in
      bins[binName]?.first { $0.contains(value) }?.RMSE
    }
    switch matchingRMSEs.count {
      case 0: return overallRMSE
      case 1: return matchingRMSEs[0]
      default: return sqrt(matchingRMSEs.reduce(0) { $0 + $1 * $1 })
    }
  }
}

extension ResidualData.Bin {
  /// Whether a value falls in the bin's half-open range.
  func contains(_ value: Double) -> Bool {
    range.count >= 2 && value >= range[0] && value < range[1]
  }
}
