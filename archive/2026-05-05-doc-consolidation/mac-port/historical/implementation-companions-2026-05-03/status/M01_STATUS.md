# M01 Status

## Current status

- Status: Partial; schema, fixtures, G01 reference-rig validator, and tests
  implemented; Q001 remains open.
- Canonical milestone: [M01 Measurement Hardware Network Profile](../milestones/M01_MEASUREMENT_HARDWARE_NETWORK_PROFILE.md)

Canonical objective:

Define the measurement rig, reference Macs, audio interfaces, network profiles,
and report formats used by every later benchmark.

Canonical assumptions:

- At least two Macs can be made available before Mac-to-Mac route tests.
- Audio interface and network route names are stable enough for report labels.
- Fixtures can be validated before real hardware reports exist.

Canonical dependencies:

- M00 scaffold.
- Reference Macs and audio interfaces.
- Wired network routes for direct link, dedicated switch, and campus path.
- A report schema or typed fixture model.

Canonical affected modules/files:

- Future measurement fixture directory.
- Future report schema or model tests.
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)
- [../PROGRESS.md](../PROGRESS.md)

Canonical implementation sequence:

1. Define report fields for hardware, route, audio mode, timing metrics, and
   verdict.
2. Add sample fixture reports for endpoint, route, video, lighting, and field
   test shapes.
3. Add validation tests for required fields and verdict values.
4. Record reference hardware and route labels when known.
5. Update open questions that remain hardware-dependent.

Canonical acceptance criteria:

- Report fixtures cover endpoint, network, video, lighting, and field-test
  cases.
- Required fields include hardware identity, route identity, p50/p95/p99/max,
  loss/drop counts, and verdict.
- Measurement reports can be compared across milestones.

Rollback/recovery notes:

- Documentation-only changes: restore the preserved historical copy when one exists, or revert the specific changed file.
- Source changes: revert the smallest affected change set and rerun `swift test`.
- Hardware, network, audio, video, lighting, recording, or packaging reports: mark the report invalid rather than deleting it, then rerun measurement.

## Completed work

- Added a typed measurement report model with required hardware, route, audio
  mode, timing, loss/drop, and verdict fields.
- Added valid JSON fixtures for endpoint, network, video, lighting, and
  field-test report shapes.
- Added invalid JSON fixtures for missing hardware, missing route, missing
  timing, missing verdict, and invalid verdict.
- Added Swift tests that decode and validate all fixtures.
- Added a stricter G01 reference-rig report model, PARTIAL template fixture,
  CLI validator, and PASS guards for two reference Macs, RME MADI identity,
  direct/switch/campus route profiles, packet-capture fields, DSCP
  classification, and non-placeholder thresholds.
- Kept Q001 open because exact reference Macs, interfaces, OS versions, driver
  versions, and route labels require human/runtime input.

## Verified work

- `swift test` first failed before implementation because `MeasurementReport`
  and `MeasurementReportKind` did not exist.
- `swift test` passed after adding the model and fixtures.
- `swift test` first failed for the G01 pass-guard tests before
  `ReferenceRigReport` existed.
- `swift test` passed after adding the G01 model, fixture, and PASS guards.

## Partially completed work

- M01 source and fixture validation are implemented, including the G01
  reference-rig validator.
- Real hardware inventory and network route identity remain unresolved.

## Deferred work

- Measured hardware reports, actual route labels, and benchmark thresholds
  remain deferred until Q001 is answered.

## Open tasks

Canonical progress checklist:

- [x] Define report schema.
- [x] Add valid fixtures.
- [x] Add invalid fixture tests.
- [ ] Record known hardware.
- [ ] Record known network routes.
- [x] Update [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md).
- [x] Update [../PROGRESS.md](../PROGRESS.md).

SOTA 2026 routing:

- Rows: Q001, SOTA004, SOTA074, SOTA075 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: hardware identity, route labels, report fields, and pass/fail thresholds are recorded before measurements are treated as comparable.

Faster-than-LoLa companion implementation plan:

- [ ] Record the reference rig before any PASS claim: Mac model, macOS build,
  RME MADI model, RME driver package/version, firmware, driver mode, TotalMix
  version/state, clock source, channel labels, sample rates, and Core Audio UID
  values.
- [ ] Fill the exact Mac fields for each reference machine: stable report label,
  host name, Mac model identifier, Apple silicon or Intel generation, macOS
  product version and build, Thunderbolt/USB/Ethernet adapter identity, wired
  interface BSD name, and interface link speed.
- [ ] Fill the exact RME fields: model, optional serial only if acceptable,
  driver package name/version, firmware version, driver mode, TotalMix
  version, TotalMix routing snapshot reference, clock source, sample-rate
  source, MADI optical/coax state where relevant, channel count, selected input
  labels, selected output labels, Core Audio input UID, Core Audio output UID,
  current buffer frame size, accepted buffer-frame range, input/output latency
  frames, and safety-offset frames.
- [ ] Fill the exact sample-rate fields: 48 kHz, 96 kHz, and 192 kHz state as
  `accepted`, `rejected`, or `not tested`, with the requested/accepted buffer
  sizes for 16/32/64/128 frames where tested.
- [ ] Record the network labels used by every later report: `direct-wired`,
  `dedicated-switch`, and `campus`, each with interface name, link speed, MTU,
  route description, packet-capture point, and DSCP test policy.
- [ ] Fill the exact route fields: stable route label, sender Mac label,
  receiver Mac label, physical topology, cable/switch/VLAN notes, sender
  interface, receiver interface, link speed, MTU, IP addresses or subnets,
  packet-capture interface, packet-capture host, capture filter, DSCP requested
  value, DSCP observed value, and DSCP classification.
- [ ] Define faster-Mac thresholds in the report notes: RME 32-frame stable is
  the primary target, 16-frame stable is stretch, 64-frame is fallback, and
  built-in Apple/iPhone devices are smoke-only.
- [ ] Record PASS thresholds before closing Q001: M01 PASS requires two real
  reference Macs or an explicitly documented single-Mac PARTIAL rig, one RME
  MADI reference path, at least one physical route label, packet-capture point,
  DSCP policy, and non-placeholder thresholds for callback p99/max, underruns,
  packet age p99/max, packet loss, and allowed verdict values.
- [ ] Replace placeholder fixture identities only after real hardware reports
  exist; do not mark M01 PASS from synthetic or built-in-device evidence.
- [ ] Close Q001 only when real hardware and real route labels are recorded in
  this companion and in [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md). Placeholder
  fixture values, synthetic reports, built-in audio, or inferred route labels
  keep Q001 open.
- [ ] Keep LoLa as the benchmark baseline: Windows LoLa 64-frame int16 behavior
  is reference evidence, not a Mac packet or hardware compatibility contract.

## Known blockers

- Exact reference Macs, RME MADI details, driver/firmware versions, TotalMix
  state, Core Audio UID values, and physical network paths require real hardware
  input or measured inventory.
- Q001 cannot be closed from placeholders, synthetic fixtures, built-in Mac
  audio, or route names inferred from the plan.

TODO(human): [M01 hardware inventory] -> Identify real reference Macs, RME MADI path, and route labels for Q001 -> [Use current HfMT Mac pairs / borrow dedicated test Macs / defer hardware closure]

## Test coverage status

Canonical test plan:

Before: no repeatable measurement method exists.

After:

- fixture validation passes;
- invalid fixture tests fail for missing hardware, route, timing, or verdict
  fields;
- documentation link and topic gates pass.

Coverage state: fixture validation tests pass for five broad M01 report shapes,
five invalid required-field/verdict cases, one G01 partial reference-rig
fixture, and G01 PASS rejection guards for missing Macs, placeholder fields,
non-RME paths, missing route profiles, unclassified DSCP, and built-in-device
PASS allowance.

## Relevant files touched

Planned affected modules/files:

- Future measurement fixture directory.
- Future report schema or model tests.
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)
- [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md)
- [../PROGRESS.md](../PROGRESS.md)

Live files touched:

- [../../Package.swift](../../Package.swift)
- [../../Sources/OpenLolaCore/MeasurementReport.swift](../../Sources/OpenLolaCore/MeasurementReport.swift)
- [../../Sources/OpenLolaCore/ReferenceRigReport.swift](../../Sources/OpenLolaCore/ReferenceRigReport.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/MeasurementReportFixtureTests.swift](../../Tests/OpenLolaCoreTests/MeasurementReportFixtureTests.swift)
- [../../Tests/OpenLolaCoreTests/ReferenceRigReportTests.swift](../../Tests/OpenLolaCoreTests/ReferenceRigReportTests.swift)
- `../../Tests/OpenLolaCoreTests/Fixtures/MeasurementReports/`
- `../../Tests/OpenLolaCoreTests/Fixtures/ReferenceRigReports/`
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)
- [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md)
- [../PROGRESS.md](../PROGRESS.md)
- [M01_STATUS.md](M01_STATUS.md)
- [../milestones/M01_MEASUREMENT_HARDWARE_NETWORK_PROFILE.md](../milestones/M01_MEASUREMENT_HARDWARE_NETWORK_PROFILE.md)

## Latest verification

- 2026-05-02: red `swift test` failed before implementation because
  `MeasurementReport` and `MeasurementReportKind` did not exist.
- 2026-05-02: `swift test` passed with 7 Swift Testing tests.
- 2026-05-02: `swift build` passed.
- 2026-05-02: `swift run open-lola` passed.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- `swift build` and `swift run open-lola` required sandbox escalation after
  SwiftPM manifest sandboxing failed with `sandbox_apply: Operation not
  permitted`.
- 2026-05-02: faster-than-LoLa companion plan update passed
  `bash scripts/verify-docs.sh` and `shellcheck scripts/*.sh`.
- 2026-05-02: M01 measurement-baseline field template and Q001 real-hardware
  closure rule passed `bash scripts/verify-docs.sh` and
  `shellcheck scripts/*.sh`.
- 2026-05-02: red `swift test` failed before G01 implementation because
  `ReferenceRigReport` and related G01 types did not exist.
- 2026-05-02: G01 reference-rig validator passed `swift test` with 191 Swift
  Testing tests before documentation refresh.
- 2026-05-02: G01 CLI validator passed with `VERDICT: PARTIAL`.
- VERDICT: PARTIAL

## Next recommended steps

Provide exact RME/Mac hardware identity and physical route labels to close
Q001. Use RME MADI as the first professional audio reference path and leave
built-in devices as smoke fixtures only.

## Resume here

Resume at Q001 in [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md): fill the G01
reference-rig template with exact reference Macs, RME MADI interface details,
OS versions, driver/firmware versions, TotalMix state, and initial
direct/switch/campus route labels, then replace placeholder fixture identities
with measured hardware inventory.
