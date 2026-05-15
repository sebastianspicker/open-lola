# M13 Hardware Validation Report

Date: 2026-05-03
Public surface: [Current State](../../docs/current-state.md)
Status: PARTIAL

## Scope

This report validates the source-level M13 hardware-validation contract for
aggregating physical evidence across the reference rig, RME MADI audio path,
Blackmagic/ATEM video path, ATEM read-only control, lighting/control bridge,
direct route, dedicated-switch route, campus route, integrated profile, and
field-run evidence boundary.

It does not validate real RME hardware, real Blackmagic/ATEM hardware, a live
lighting bridge, packet captures, DSCP behavior, venue constraints, or a
30-minute physical field run.

## Implemented Contract

`Sources/OpenLolaCore/HardwareValidationReport.swift` records:

- final hardware identity, driver, firmware, Core Audio UID, cabling, and
  firmware snapshot fields;
- required evidence lanes for reference rig, RME fastest audio, video path,
  ATEM read-only control, lighting bridge, integrated profile, and field run;
- route identity rows for direct link, dedicated switch, and campus path;
- packet-capture point, capture interface, DSCP classification, venue
  constraints, measured flag, and verdict for each route;
- field-run duration, route labels, evidence separation, fastest-profile
  latency acceptance, synthetic-evidence boundary, and machine-readable
  verdict.

PASS validation rejects synthetic or incomplete evidence, missing route rows,
unclassified or harmful DSCP results, short field runs, placeholder hardware
identity, non-RME-MADI audio identity, and missing Blackmagic/ATEM production
identity.

`Sources/OpenLolaCore/HardwareValidationRun.swift` adds:

- `HardwareValidationSyntheticSmoke`;
- `HardwareValidationRunConfiguration`;
- `HardwareValidationRunner`, which aggregates existing validated reports into
  an M13 report without promoting missing physical evidence to PASS.

## Commands

```bash
swift test --filter HardwareValidationReportTests
swift test
swift build
.build/debug/open-lola validate-hardware-validation-report Tests/OpenLolaCoreTests/Fixtures/HardwareValidationReports/valid/hardware-validation-partial.json
.build/debug/open-lola hardware-validation-synthetic-smoke
.build/debug/open-lola atem-readonly-probe --host 127.0.0.1 --port 1 --timeout-milliseconds 1 --poll-interval-milliseconds 1000 --network-interface lo0 --same-network-as-audio false --output /private/tmp/open-lola-m13-atem-readonly.json
.build/debug/open-lola hardware-validation-run --reference-rig Tests/OpenLolaCoreTests/Fixtures/ReferenceRigReports/valid/reference-rig-partial.json --rme-fastest-audio Tests/OpenLolaCoreTests/Fixtures/RmeFastestAudioPathReports/valid/rme-fastest-audio-partial.json --video-capture Tests/OpenLolaCoreTests/Fixtures/VideoCaptureReports/valid/video-capture-partial.json --atem-control /private/tmp/open-lola-m13-atem-readonly.json --lighting-gate Tests/OpenLolaCoreTests/Fixtures/LightingFixtureGateReports/valid/lighting-gate-partial.json --integrated-profile Tests/OpenLolaCoreTests/Fixtures/IntegratedProfileReports/valid/integrated-profile-partial.json --field-run-report m13-field-run-required --duration-seconds 30 --output /private/tmp/open-lola-m13-hardware-validation-run.json
.build/debug/open-lola validate-hardware-validation-report /private/tmp/open-lola-m13-hardware-validation-run.json
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Results

- Red focused test run failed before implementation because the M13
  hardware-validation types did not exist.
- `swift test --filter HardwareValidationReportTests` passed with 12 M13 tests
  after implementation.
- `swift test` passed with 476 tests.
- `swift build` passed after rerunning outside the sandbox to avoid the known
  SwiftPM `sandbox-exec: sandbox_apply: Operation not permitted` manifest
  failure.
- `bash scripts/verify-docs.sh` passed.
- `shellcheck scripts/*.sh` passed.
- The fixture validates as a `PARTIAL` report and carries explicit
  `TODO(human)` physical evidence fields.
- The synthetic smoke emits a `PARTIAL` report.
- The bounded `hardware-validation-run` helper wrote and revalidated a
  `PARTIAL` aggregate report from existing partial fixtures plus an unavailable
  read-only ATEM probe.

## Deferred Runtime Evidence

M13 cannot be marked PASS until real reports exist for:

- accepted reference-rig identity with final hardware, driver, firmware, OS,
  cabling, Core Audio UID, and route facts;
- accepted RME MADI fastest-audio report;
- accepted Blackmagic/ATEM capture and read-only ATEM status reports;
- accepted lighting/control bridge report;
- direct, dedicated-switch, and campus-route reports with packet-capture points
  and DSCP classification;
- integrated profile matrix that stays within the accepted fastest audio
  latency profile;
- 30-minute or longer field run with synthetic/lab/field evidence separated.

## Verdict

M13 source validation is implemented. Physical hardware validation remains open.

VERDICT: PARTIAL

## Resume here

Run the physical matrix, write the aggregate with
`open-lola hardware-validation-run`, then validate it with
`open-lola validate-hardware-validation-report <path>`. Keep M13 `PARTIAL`
until every required route and hardware lane is measured on the real rig.
