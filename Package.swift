// swift-tools-version: 6.4

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  .enableUpcomingFeature("InferIsolatedConformances"),
  .enableUpcomingFeature("ImmutableWeakCaptures"),
  .enableUpcomingFeature("MemberImportVisibility"),
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .strictMemorySafety()
]

let package = Package(
  name: "AircraftPerformance",
  defaultLocalization: "en",
  platforms: [.iOS("27.0"), .macOS("27.0")],
  products: [
    .library(name: "AircraftPerformance", targets: ["AircraftPerformance"])
  ],
  dependencies: [
    .package(url: "https://github.com/RISCfuture/MeasurementKit.git", from: "1.2.1"),
    .package(url: "https://github.com/apple/swift-numerics.git", from: "1.1.1")
  ],
  targets: [
    .target(
      name: "AircraftPerformance",
      dependencies: [.product(name: "MeasurementKit", package: "MeasurementKit")],
      resources: [.process("Resources"), .copy("Data")],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "AircraftPerformanceTests",
      dependencies: [
        "AircraftPerformance",
        .product(name: "MeasurementKit", package: "MeasurementKit"),
        .product(name: "RealModule", package: "swift-numerics")
      ],
      swiftSettings: swiftSettings
    )
  ],
  swiftLanguageModes: [.v6]
)
