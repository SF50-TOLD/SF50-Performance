# Change Log

## [Unreleased]

## [2.0.1] - 2026-11-08

### Fixed

- A temperature search for an aircraft whose manual sets no maximum temperature, such as the
  SR22, reports the edge of the tables (`afmData`) as what stops it, not a temperature limit

## [2.0.0] - 2026-11-08

### Added

- The Cirrus SR22 without the G3 wing, from POH 13772-001 Rev A10, as `Aircraft.sr22(_:)` with
  `SR22Options` for the Hartzell composite propeller (13772-129) and Tornado Alley
  turbonormalizing (Report 215-6) supplements, in any combination. Its corrections are stated
  against the ground roll, and the feet they add carry into the total distance
- Balked landing climb gradient and rate (`PerformanceModel.balkedLandingClimbGradientFtNM` and
  `balkedLandingClimbRateFtMin`), and `PerformanceCalculator.timeFuelDistanceToClimb(from:to:leanOfPeak:)`
- Wet unpaved runway and air conditioner corrections (`AdjustmentKind.wetUnpavedSurface`,
  `.airConditioner`, `Configuration.airConditionerOn`, and `airConditionerOn:` on `takeoff`)
- `Aircraft.tabulatedWeights(for:flapSetting:)`, the weights a manual's takeoff or landing
  ground run table covers, for starting a weight search
- One-sided limit notes (`airportElevationAboveLimit`, `temperatureBelowLimit` and so on) for
  manuals that set only one bound

### Changed

- The package, product and module are renamed `AircraftPerformance`, since the package is no
  longer SF50-only. The repository keeps its name for now
- Each aircraft's data is a Data-Extraction data package, mirrored unchanged into
  `Data/<aircraft>/` by `script/update-data`; tables resolve through the package's manifest
- The aircraft is an `Aircraft`, such as `.sf50(.g2Plus)`, wherever an `AircraftType` was taken.
  `Aircraft` and its options are `Codable`, and say which calculations they have figures for
  (`capabilities`), which flap settings they have takeoff and landing figures for, and which
  manuals the figures come from (`configurationInfo()`)
- Limitations are an `AircraftLimitations` value instead of a type conforming to `Limitations`.
  The demonstrated crosswind is looked up by flap setting. The zero fuel weight, the airport
  elevation and temperature bounds are optional, and `maxTakeoffElevation` holds a takeoff-only
  ceiling
- `PerformanceAdjustmentGenerator` and `ClimbProfileGenerator`'s SF50 climb speed constants are
  no longer public
- A regression figure's uncertainty no longer varies in its last digit from run to run

| 1.x | 2.0 |
|---|---|
| `import SF50Performance` | `import AircraftPerformance` |
| `AircraftType` | `SF50Variant`, wrapped as `Aircraft.sf50(_:)` |
| `AircraftTypeSetting` | `SF50Generation` (same raw values) |
| `AircraftType(setting:updatedThrustSchedule:)` | `SF50Variant(generation:updatedThrustSchedule:)` |
| `aircraftType:` arguments and `PerformanceSettings.aircraftType` | `aircraft:` and `.aircraft` |
| `any Limitations.Type`, `LimitationsG1`, `LimitationsG2` | `AircraftLimitations`, from `Aircraft.limitations` |
| `maxCrosswind_flaps50`, `maxCrosswind_flaps100` | `maxCrosswind(for:)`, optional |
| `maxZeroFuelWeight`, `min`/`maxAirportElevation`, `min`/`maxTemperature` | optional |

## [1.0.0] - 2026-11-04

### Added

- Takeoff, landing and climb profile performance models for the SF50 G1, G2, G2+ and G3, extracted
  from SF50 TOLD: the tabular AFM model and the regression model, with wind, slope, surface and
  contamination corrections and their breakdowns
- `PerformanceCalculator`, which takes the engine settings (aircraft type, model, safety factors
  and VREF additive) as explicit inputs
- `PerformanceNotes`, one check of a takeoff or landing against the AFM's limitations and the
  runway: weight, wind, airport elevation, temperature, available distance and obstacle clearance
- Maximum takeoff and landing weight and maximum temperature searches, each reporting the
  constraint that binds. They stop at the AFM's tailwind and temperature limits, and at its airport
  elevation limits for the tabular model. They check the runway's NOTAM obstacle when no obstacle is
  given, and `reliesOnOffscaleData` marks a limit that rests on offscale figures. The maximum
  demonstrated crosswind, which the AFM does not consider limiting, appears only as a note
- Builds and runs on Linux

### Changed

Compared with the engine in SF50 TOLD 4.0.1:

- The takeoff and landing tables are read at pressure altitude, computed from field elevation and
  the altimeter setting, rather than at field elevation. Without an altimeter setting the field
  elevation is used, and the notes say so
- The takeoff distance is over a 50 ft obstacle, as the G1 AFM states, and an obstacle's required
  climb gradient is measured from the end of the takeoff distance at 50 ft
- Each data set is read from the bundle once and shared, so building a model no longer re-reads its
  tables, and missing data throws `PerformanceDataError` rather than stopping the process
