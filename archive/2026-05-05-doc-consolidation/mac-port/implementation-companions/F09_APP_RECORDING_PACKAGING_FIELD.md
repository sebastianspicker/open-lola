# F09 App Recording Packaging Field

Date: 2026-05-03
Status: required field-readiness path
Verdict: PARTIAL

## Finding

The current source layer has SwiftUI shell, native-app report validation,
recording/session artifact validation, packaging field-test validation, and
aggregate field-runtime proof scaffolds. The F09 source-level gap was the clean
runtime handoff across those surfaces: app config, recording side lane, ad-hoc
package layout, and aggregate field proof from one integrated baseline.
Developer ID signing, notarization, Gatekeeper, and clean-Mac field testing
remain Q010 runtime gates.

## Current Surface

- [../../Sources/open-lola-app/OpenLolaApp.swift](../../Sources/open-lola-app/OpenLolaApp.swift)
  provides the shell target.
- [../../Sources/OpenLolaCore/NativeAppShell.swift](../../Sources/OpenLolaCore/NativeAppShell.swift)
  validates app-shell reports.
- [../../Sources/OpenLolaCore/RecordingSessionArtifacts.swift](../../Sources/OpenLolaCore/RecordingSessionArtifacts.swift)
  validates recording side-lane reports.
- [../../Sources/OpenLolaCore/PackagingFieldTest.swift](../../Sources/OpenLolaCore/PackagingFieldTest.swift)
  validates package and clean-Mac field reports.
- [../../Sources/OpenLolaCore/FieldReadyRuntimeProof.swift](../../Sources/OpenLolaCore/FieldReadyRuntimeProof.swift)
  validates the aggregate runtime proof.
- [../../Sources/OpenLolaCore/FieldReadinessRun.swift](../../Sources/OpenLolaCore/FieldReadinessRun.swift)
  chains the M13, M14, M15, and P05 source-level handoffs from one integrated
  report.

## Required Runtime Shape

- App owns immutable setup/config handoff before audio start.
- App observes metrics read-only while audio runs.
- Recording uses a side lane and drops recording data under pressure before it
  can delay audio/video.
- Packaging records signing identity, entitlements, notarization, Gatekeeper,
  permissions, report-writing paths, and clean-Mac target identity.
- `open-lola field-readiness-run` writes the app runtime report, recording
  session report, ad-hoc packaging report, and P05 field-runtime proof together.

## Required Evidence

- app-vs-CLI metrics comparison for the same headless run;
- permission prompts observed on a clean Mac;
- recording-off baseline and recording-on disk-pressure stress;
- Developer ID signing identity or explicit ad-hoc-only blocker;
- project license decision and third-party notices;
- SDK redistribution and fixture provenance review for any bundled adapters or
  samples;
- notarization and Gatekeeper result;
- clean-Mac launch, RME visibility, ATEM status where included, and report
  writing proof.
- bounded field-readiness output directory containing the M13, M14, M15, and
  P05 reports from the same integrated baseline.

## PASS Criteria

- App launch cannot change audio timing relative to CLI.
- Recording cannot increase playout latency.
- Package is signed/notarized or explicitly marked PARTIAL with blocker.
- Package includes approved license/notices and excludes unapproved SDK,
  fixture, capture, generated, and binary artifacts.
- Clean-Mac field test writes machine-readable PASS or PARTIAL evidence.

## Resume here

Run `open-lola field-readiness-run --integrated-report <path>
--duration-seconds <n> --output-dir <dir>` against the measured F07 integrated
baseline. Answer Q010 in [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md) before
attempting signed/notarized clean-Mac PASS evidence.

VERDICT: PARTIAL
