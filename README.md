# SF50Performance

[![CI](https://github.com/SF50-TOLD/SF50-Performance/actions/workflows/ci.yml/badge.svg)](https://github.com/SF50-TOLD/SF50-Performance/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Takeoff, landing and climb performance models for the Cirrus SF50 Vision Jet, G1 through G3,
built from the Airplane Flight Manual. This is the engine behind the
[SF50 TOLD](https://github.com/SF50-TOLD/iOS) app.

## Disclaimer

This package has not been approved by the FAA or by Cirrus Aircraft as an official source of
performance information. Always verify performance information with official sources. Use it
for pre-flight planning only, never in the cockpit.

## Features

- **Takeoff**: ground run, distance over a 50 ft obstacle, and Vx climb gradient and rate, with
  the wind, slope and surface corrections broken out
- **Landing**: VREF, ground run, distance from 50 ft, and the go-around climb gradient, on dry,
  wet and contaminated runways (including AC 91-79B runway condition codes)
- **Climb profiles**: gradient and rate by altitude for the takeoff, en route obstacle and en
  route climb schedules, with and without ice protection, through a column of winds aloft
- **Limits**: the maximum takeoff or landing weight, or the maximum temperature, a runway allows,
  and the constraint that sets it
- **Notes**: one function that checks a calculation against the AFM's limitations and the runway
- **Models**: the tabular model interpolates the AFM tables and reports N/A outside them; the
  regression model extrapolates and reports an uncertainty
- Tables are read at pressure altitude, from field elevation and the altimeter setting

## Requirements

- Swift 6.4
- iOS 27, macOS 27, or Linux

## Installation

```swift
dependencies: [
  .package(url: "https://github.com/SF50-TOLD/SF50-Performance.git", from: "1.0.0")
]
```

Then add `SF50Performance` to your target's dependencies.

## Usage

```swift
import SF50Performance

let calculator = PerformanceCalculator(settings: .init(aircraftType: .g2Plus))
let conditions = Conditions(
  windDirection: .init(value: 280, unit: .degrees),
  windSpeed: .init(value: 12, unit: .knots),
  temperature: .init(value: 18, unit: .celsius),
  seaLevelPressure: .init(value: 30.02, unit: .inchesOfMercury)
)
let report = try calculator.takeoff(
  conditions: conditions,
  weight: .init(value: 5800, unit: .pounds),
  runway: runway  // a RunwayInput
)
let notes = PerformanceNotes.takeoffNotes(
  for: report,
  inputs: .init(
    settings: calculator.settings,
    configuration: .init(weight: .init(value: 5800, unit: .pounds), flapSetting: .flaps50),
    runway: runway,
    conditions: conditions
  )
)
```

Every figure is a `Value`: a definite value, a value with uncertainty, or the reason there is
none (offscale, not available, not authorized). Pass the reason on rather than substituting a
figure.

## AFM data

The tables in `Sources/SF50Performance/Data` are digitized from the Cirrus SF50 Airplane Flight
Manual and its supplements, which are copyright Cirrus Design Corporation. The regression
equations and residuals are fitted to those tables. They are included so that the models can be
checked against the manual; they are not a substitute for it.

Each aircraft's data is a data package published by
[Data-Extraction](https://github.com/SF50-TOLD/Data-Extraction) (format described in its
`docs/data-package.md`) and mirrored unchanged into `Data/<aircraft>/`. Its `manifest.json`
records the generator version and each source document, and each document directory's
`source.json` records the PDF it was extracted from.

To refresh the data, check out Data-Extraction beside this repository (or set
`DATA_EXTRACTION_DIR`), then run:

```sh
script/update-data          # mirror every package, deleting files a package no longer has
script/update-data --check  # change nothing; exit non-zero if any package is out of date
```

Review the diff and commit it. Run `script/update-data --check` before tagging a release.

## License

MIT; see [LICENSE](LICENSE). The license covers this package's code, not the AFM content
described above.
