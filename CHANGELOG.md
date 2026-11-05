# Change Log

## [Unreleased]

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
