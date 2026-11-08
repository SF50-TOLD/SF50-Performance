import Foundation

/// A quantity a ``DataTable``'s input column holds, under the name its header gives it.
enum TableInput: String, Sendable, Hashable, CaseIterable {
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
  case rwyCC = "rwycc"

  /// The input a header names, or `nil` for a name that isn't one.
  init?(columnName: String) {
    self.init(rawValue: columnName)
  }
}
