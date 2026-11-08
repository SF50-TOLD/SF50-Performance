import Foundation

/// A quantity a ``DataTable``'s input column holds, whatever name its header gives it.
enum TableInput: Sendable, Hashable, CaseIterable {
  /// Aircraft weight, in pounds.
  case weight

  /// Pressure altitude, in feet.
  case altitude

  /// Outside air temperature, in degrees Celsius.
  case temperature

  /// A dry landing distance a contamination table adjusts, in feet.
  case distance

  /// Contaminant depth, in inches.
  case depth

  /// A runway condition code.
  case rwyCC

  /// The header names a column holding this input may have.
  private var columnNames: Set<String> {
    switch self {
      case .weight: ["weight", "weight_lb"]
      case .altitude: ["altitude", "pressure_alt_ft"]
      case .temperature: ["temperature", "oat_c"]
      case .distance: ["distance"]
      case .depth: ["depth"]
      case .rwyCC: ["rwycc"]
    }
  }

  /// The input a header names, or `nil` for a name that isn't one.
  init?(columnName: String) {
    guard let input = Self.allCases.first(where: { $0.columnNames.contains(columnName) }) else {
      return nil
    }
    self = input
  }
}
