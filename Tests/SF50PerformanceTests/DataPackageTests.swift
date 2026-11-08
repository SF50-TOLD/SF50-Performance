import Foundation
import Testing

@testable import SF50Performance

struct DataPackageTests {
  @Test(
    "each SF50 type reads its AFM's configuration",
    arguments: [
      (AircraftType.g1, "g1"),
      (.g2(updatedThrustSchedule: false), "g2"),
      (.g2(updatedThrustSchedule: true), "g2+"),
      (.g2Plus, "g2+"),
      (.g3, "g2+")
    ]
  )
  func configurationForType(type: AircraftType, configuration: String) throws {
    #expect(try AircraftData.forType(type).directoryName == configuration)
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
