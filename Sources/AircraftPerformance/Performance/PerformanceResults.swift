public import Foundation
public import MeasurementKit

/// Results of a takeoff performance calculation.
public struct TakeoffResults: Sendable {
  /// Ground run distance from brake release to liftoff.
  public let takeoffRun: Value<Measurement<UnitLength>>

  /// Total distance from brake release to 50 feet AGL.
  public let takeoffDistance: Value<Measurement<UnitLength>>

  /// Climb gradient in feet per nautical mile at Vx.
  public let takeoffClimbGradient: Value<Measurement<UnitSlope>>

  /// Climb rate in feet per minute at Vx.
  public let takeoffClimbRate: Value<Measurement<UnitSpeed>>

  /// Whether any figure fell below the range the AFM tables cover.
  public var isOffscaleLow: Bool {
    takeoffRun.isOffscaleLow || takeoffDistance.isOffscaleLow
      || takeoffClimbGradient.isOffscaleLow || takeoffClimbRate.isOffscaleLow
  }

  /// Whether any figure rose above the range the AFM tables cover.
  public var isOffscaleHigh: Bool {
    takeoffRun.isOffscaleHigh || takeoffDistance.isOffscaleHigh
      || takeoffClimbGradient.isOffscaleHigh || takeoffClimbRate.isOffscaleHigh
  }
}

/// Results of a landing performance calculation.
public struct LandingResults: Sendable {
  /// Reference approach speed for the landing configuration.
  public let Vref: Value<Measurement<UnitSpeed>>

  /// Ground run distance from touchdown to stop.
  public let landingRun: Value<Measurement<UnitLength>>

  /// Total distance from 50 feet AGL to full stop.
  public let landingDistance: Value<Measurement<UnitLength>>

  /// Whether the aircraft can achieve the required go-around climb gradient.
  public let meetsGoAroundClimbGradient: Value<Bool>

  /// Whether any figure fell below the range the AFM tables cover.
  public var isOffscaleLow: Bool {
    Vref.isOffscaleLow || landingRun.isOffscaleLow || landingDistance.isOffscaleLow
  }

  /// Whether any figure rose above the range the AFM tables cover.
  public var isOffscaleHigh: Bool {
    Vref.isOffscaleHigh || landingRun.isOffscaleHigh || landingDistance.isOffscaleHigh
  }
}

/// A takeoff report including results and distance breakdowns.
public struct TakeoffReport: Sendable {
  public let results: TakeoffResults
  public let groundRunBreakdown: DistanceBreakdown
  public let distanceBreakdown: DistanceBreakdown

  /// The pressure altitude the tables were read at.
  public let pressureAltitude: Measurement<UnitLength>

  /// Whether the model's inputs fell below the range the AFM tables cover.
  public let inputsOffscaleLow: Bool

  /// Whether the model's inputs rose above the range the AFM tables cover.
  public let inputsOffscaleHigh: Bool

  /// Whether a figure or an input fell below the range the AFM tables cover.
  public var isOffscaleLow: Bool { results.isOffscaleLow || inputsOffscaleLow }

  /// Whether a figure or an input rose above the range the AFM tables cover.
  public var isOffscaleHigh: Bool { results.isOffscaleHigh || inputsOffscaleHigh }
}

/// A landing report including results and distance breakdowns.
public struct LandingReport: Sendable {
  public let results: LandingResults
  public let groundRunBreakdown: DistanceBreakdown
  public let distanceBreakdown: DistanceBreakdown

  /// The pressure altitude the tables were read at.
  public let pressureAltitude: Measurement<UnitLength>

  /// Whether the model's inputs fell below the range the AFM tables cover.
  public let inputsOffscaleLow: Bool

  /// Whether the model's inputs rose above the range the AFM tables cover.
  public let inputsOffscaleHigh: Bool

  /// Whether a figure or an input fell below the range the AFM tables cover.
  public var isOffscaleLow: Bool { results.isOffscaleLow || inputsOffscaleLow }

  /// Whether a figure or an input rose above the range the AFM tables cover.
  public var isOffscaleHigh: Bool { results.isOffscaleHigh || inputsOffscaleHigh }
}
