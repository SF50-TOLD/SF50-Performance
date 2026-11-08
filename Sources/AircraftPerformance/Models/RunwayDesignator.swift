public import Foundation

/// Ordering for runway designators.
///
/// Every list of runways should use this order, so that any view showing only the first few of
/// an airport's runways shows the same ones.
public enum RunwayDesignator {
  /// Where a designator's side letter falls. An unrecognized letter sorts after all of them.
  private static let sideOrder = ["": 0, "L": 1, "C": 2, "R": 3],
    unknownSideOrder = 4

  /// Orders two designators by runway number, then by side, with no letter before left, center, right.
  ///
  /// - Parameters:
  ///   - lhs: A designator, such as `"10L"`.
  ///   - rhs: The designator to compare it against.
  /// - Returns: How `lhs` orders against `rhs`.
  public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
    compare(number(of: lhs), number(of: rhs))
      ?? compare(side(of: lhs), side(of: rhs))
      ?? .orderedSame
  }

  private static func compare(_ lhs: Int, _ rhs: Int) -> ComparisonResult? {
    guard lhs != rhs else { return nil }
    return lhs < rhs ? .orderedAscending : .orderedDescending
  }

  private static func number(of name: String) -> Int {
    Int(name.filter(\.isNumber)) ?? 0
  }

  private static func side(of name: String) -> Int {
    sideOrder[name.filter(\.isLetter)] ?? unknownSideOrder
  }
}

extension ComparisonResult {
  var inverted: ComparisonResult {
    switch self {
      case .orderedAscending: .orderedDescending
      case .orderedDescending: .orderedAscending
      case .orderedSame: .orderedSame
    }
  }
}
