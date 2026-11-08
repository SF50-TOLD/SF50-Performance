import Foundation
import Testing

@testable import AircraftPerformance

struct DataPackageTests {
  @Test(
    "each SF50 type reads its AFM's configuration",
    arguments: [
      (SF50Variant.g1, "g1"),
      (.g2(updatedThrustSchedule: false), "g2"),
      (.g2(updatedThrustSchedule: true), "g2+"),
      (.g2Plus, "g2+"),
      (.g3, "g2+")
    ]
  )
  func configurationForType(type: SF50Variant, configuration: String) throws {
    #expect(try Aircraft.sf50(type).definition.data().directoryName == configuration)
  }

  @Test(
    "each SR22 option set reads its manuals' configuration",
    arguments: [
      (SR22Options(), "poh"),
      (.init(hartzellPropeller: true), "poh+hartzell"),
      (.init(turbonormalized: true), "poh+tornado-alley"),
      (.init(hartzellPropeller: true, turbonormalized: true), "poh+hartzell+tornado-alley")
    ]
  )
  func configurationForSR22(options: SR22Options, configuration: String) throws {
    #expect(try Aircraft.sr22(options).definition.data().directoryName == configuration)
  }

  @Test("a manifest in another package format is rejected")
  func rejectsOtherFormat() throws {
    let manifest = try JSONDecoder().decode(
      PackageManifest.self,
      from: Data(
        """
        {"format": 2, "equation_format": "1.0", "aircraft": {"name": "sf50", "title": "SF50"},
         "documents": {}, "configurations": {}, "equations": {}}
        """.utf8
      )
    )
    #expect(throws: PerformanceDataError.self) { try manifest.validateFormat() }
  }
}
