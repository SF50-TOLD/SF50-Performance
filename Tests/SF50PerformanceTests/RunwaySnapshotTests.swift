import Foundation
import Testing

@testable import SF50Performance

/// A snapshot has to carry the same distances a calculation compares against — NOTAM shortening
/// included, and the run kept distinct from the distance.
@Suite
struct `Runway Snapshot Distances` {
  /// 5,000 ft of pavement with a 1,000 ft clearway: TORA 5,000, TODA 6,000.
  private static func runwayWithClearway(notam: NOTAMInput? = nil) -> RunwayInput {
    RunwayInput(
      id: "36",
      elevation: .init(value: 0, unit: .feet),
      trueHeading: .init(value: 360, unit: .degrees),
      gradient: 0,
      length: .init(value: 5000, unit: .feet),
      takeoffRun: .init(value: 5000, unit: .feet),
      takeoffDistance: .init(value: 6000, unit: .feet),
      landingDistance: .init(value: 4800, unit: .feet),
      notam: notam,
      airportVariation: .init(value: 0, unit: .degrees)
    )
  }

  /// Comparing `Measurement` values directly compares metres, where a foot-denominated subtraction
  /// leaves float dust.
  private static func feet(_ distance: Measurement<UnitLength>) -> Double {
    (distance.converted(to: .feet).value * 100).rounded() / 100
  }

  @Test
  func `measures the ground run against the run, not the distance over the clearway`() {
    let snapshot = RunwaySnapshot(Self.runwayWithClearway())

    #expect(Self.feet(snapshot.availableRun(for: .takeoff)) == 5000)
    #expect(Self.feet(snapshot.availableDistance(for: .takeoff)) == 6000)
  }

  @Test
  func `shortens what it reports as available by a NOTAM's shortening`() {
    let notam = NOTAMInput(
      contaminationType: nil,
      contaminationDepth: .init(value: 0, unit: .meters),
      takeoffDistanceShortening: .init(value: 1000, unit: .feet),
      landingDistanceShortening: .init(value: 800, unit: .feet),
      obstacleHeight: .init(value: 0, unit: .feet),
      obstacleDistance: .init(value: 0, unit: .feet)
    )
    let snapshot = RunwaySnapshot(Self.runwayWithClearway(notam: notam))

    #expect(Self.feet(snapshot.availableRun(for: .takeoff)) == 4000)
    #expect(Self.feet(snapshot.availableDistance(for: .takeoff)) == 5000)
    #expect(Self.feet(snapshot.availableDistance(for: .landing)) == 4000)
  }
}
