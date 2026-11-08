import Foundation

/// Calculates statistical uncertainty for regression model predictions.
///
/// ``ResidualErrorCalculator`` provides RMSE (Root Mean Square Error) values for
/// regression model outputs. These values represent the statistical uncertainty
/// from the curve-fitting process and are used to generate confidence intervals.
///
/// ## Residual Data
///
/// RMSE values are loaded once from a bundled JSON file (`residuals.json`) that contains:
///
/// - Overall RMSE for each regression table
/// - Binned RMSE values for different input ranges (weight, altitude, temperature)
///
/// ``AircraftData`` checks that every table its equations name has residuals before it hands
/// out a single equation, so a lookup here always finds its table.
///
/// ## Binned Errors
///
/// When inputs are provided, the calculator looks up RMSE values for the specific
/// bins containing those inputs. Multiple bin matches are combined using
/// root-sum-square for proper statistical combination.
///
/// ## Usage
///
/// ```swift
/// let rmse = ResidualErrorCalculator.RMSE(
///     for: "g1/takeoff/ground run",
///     binParameters: [
///         "weight": 5500,
///         "altitude": 5000,
///         "temperature": 25
///     ]
/// )
/// ```
enum ResidualErrorCalculator {
  private static let residualFilename = "residuals.json"

  /// The tables whose residuals the regression contamination formulas look up.
  static let contaminationTables = ["water", "slush, wet snow", "dry snow", "compact snow"].map {
    contaminationTable(for: $0)
  }

  private static let residualData = Result { try loadResidualData() }

  /// Confirms that residuals exist for every table named.
  ///
  /// - Parameter tables: The residual tables that equations will look up.
  /// - Throws: ``PerformanceDataError`` if the residuals file cannot be read or lacks a table.
  static func validate(tables: some Sequence<String>) throws {
    let residuals = try residualData.get()
    for table in tables where residuals[table] == nil {
      throw PerformanceDataError.missingResiduals(table: table)
    }
  }

  static func RMSE(for table: String, binParameters: [String: Double] = [:]) -> Double {
    guard case .success(let residuals) = residualData, let residualData = residuals[table] else {
      preconditionFailure("No residual data for \(table); AircraftData validates every table")
    }

    // If no bin parameters provided, return overall RMSE
    if binParameters.isEmpty {
      return residualData.overallRMSE
    }

    // Collect all matching bin RMSEs
    var matchingRmses: [Double] = []

    for (binName, value) in binParameters {
      guard let bins = residualData.bins[binName] else { continue }

      for bin in bins {
        if bin.range.count >= 2 && value >= bin.range[0] && value < bin.range[1] {
          matchingRmses.append(bin.RMSE)
          break  // Only take first matching bin per parameter
        }
      }
    }

    // Combine RMSEs using root-sum-square for proper statistical combination
    if matchingRmses.isEmpty {
      return residualData.overallRMSE
    }
    if matchingRmses.count == 1 {
      return matchingRmses[0]
    }
    // Root-sum-square combination: sqrt(sum(rmse_i^2))
    let sumSquares = matchingRmses.reduce(0) { $0 + $1 * $1 }
    return sqrt(sumSquares)
  }

  // Convenience method to get RMSE for contamination adjustments
  static func contaminationRMSE(
    for contaminationType: String,
    distance: Double? = nil,
    depth: Double? = nil
  ) -> Double {
    var binParams: [String: Double] = [:]
    if let distance {
      binParams["distance"] = distance
    }
    if let depth {
      binParams["depth"] = depth
    }

    return RMSE(for: contaminationTable(for: contaminationType), binParameters: binParams)
  }

  private static func contaminationTable(for contaminationType: String) -> String {
    "\(SF50Definition.contaminationResidualDocument)/landing/contamination/\(contaminationType)"
  }

  private static func loadResidualData() throws -> [String: ResidualData] {
    let url = try DataPackage.sf50.get().directory.appending(component: residualFilename)
    do {
      let data = try Data(contentsOf: url)
      return try JSONDecoder().decode([String: ResidualData].self, from: data)
    } catch {
      throw PerformanceDataError.unreadableResource(path: residualFilename, underlying: error)
    }
  }

  struct ResidualData: Decodable, Sendable {
    let overallRMSE: Double
    let overallMaxError: Double
    let bins: [String: [Bin]]

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

    enum CodingKeys: String, CodingKey {
      case overallRMSE = "overall_rmse"
      case overallMaxError = "overall_max_error"
      case bins
    }
  }
}
