# P05 Field-Ready Runtime

## Objective

Make the prototype usable in the field without prematurely productizing it.

## Background/Context

The first field-ready prototype stays CLI/headless until P04 has measured PASS
or defensible PARTIAL. Any app shell observes or configures proven paths; it
does not own realtime audio, video, or control loops.

## Canonical Roadmap Links

- [../milestones/M13_NATIVE_APP_SHELL.md](../milestones/M13_NATIVE_APP_SHELL.md)
- [../milestones/M14_RECORDING_SESSION_ARTIFACTS.md](../milestones/M14_RECORDING_SESSION_ARTIFACTS.md)
- [../milestones/M15_PACKAGING_FIELD_TEST.md](../milestones/M15_PACKAGING_FIELD_TEST.md)
- [P04_INTEGRATED_AV_PROOF.md](P04_INTEGRATED_AV_PROOF.md)

## Assumptions

- CLI/headless remains the primary runtime for the first prototype.
- App shell work starts only after P04 has measured evidence.
- Recording and session artifacts are side-lane work outside realtime paths.
- Signing and notarization follow a valid field report; they do not define the
  prototype architecture.

## Dependencies

- P04 integrated A/V proof or defensible PARTIAL.
- Permission purpose strings for microphone, camera, and local network when an
  app/runtime requires them.
- Report writer that never runs in realtime callbacks.
- Clean-Mac field-test target.

## Affected Modules/Files

- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Sources/open-lola-app/OpenLolaApp.swift](../../Sources/open-lola-app/OpenLolaApp.swift)
- [../../Sources/OpenLolaCore/NativeAppShell.swift](../../Sources/OpenLolaCore/NativeAppShell.swift)
- [../../Sources/OpenLolaCore/RecordingSessionArtifacts.swift](../../Sources/OpenLolaCore/RecordingSessionArtifacts.swift)
- [../../Sources/OpenLolaCore/PackagingFieldTest.swift](../../Sources/OpenLolaCore/PackagingFieldTest.swift)
- [../../Sources/OpenLolaCore/FieldReadyRuntimeProof.swift](../../Sources/OpenLolaCore/FieldReadyRuntimeProof.swift)
- [status/P05_STATUS.md](status/P05_STATUS.md)

## Implementation Plan

1. Keep the first prototype CLI/headless.
2. Add minimal app/runtime only after P04 has measured PASS or defensible
   PARTIAL.
3. Add permission purpose strings for microphone, camera, and local network.
4. Add recording/session artifact writer outside realtime paths.
5. Add signing/notarization only after the prototype can produce a valid field
   report.
6. Run clean-Mac smoke: launch, device inventory, RME visibility, ATEM
   connection, and report writing.
7. Build the aggregate proof from M10, M13, M14, and M15 reports with
   `open-lola field-runtime-proof-run`.
8. Validate the aggregate field proof with
   `open-lola validate-field-runtime-proof <path>`.

## Companion Status Fields

[status/P05_STATUS.md](status/P05_STATUS.md) records:

- runtime mode: CLI-only, app shell, or signed app;
- permission prompts observed;
- recording enabled or disabled;
- signing identity and notarization status;
- clean-Mac field-test target and verdict.
- aggregate P05 proof report ID and verdict.

## Test Plan

Before: prototype runtime may be CLI-only and not field-smoked on a clean Mac.

After:

- `swift build` passes;
- `swift test` passes;
- `bash scripts/verify-docs.sh` passes;
- `shellcheck scripts/*.sh` passes;
- CLI can run the prototype workflow and write reports;
- app shell, if present, does not own realtime paths;
- clean-Mac field test produces a machine-readable verdict.
- `swift run open-lola validate-field-runtime-proof <path>` passes for the
  aggregate P05 report.

## Validation Method

Accept field readiness only when the runtime can launch, enumerate devices,
see the RME device, connect to ATEM read-only when present, write reports, and
return `VERDICT: PASS`, `VERDICT: FAIL`, or `VERDICT: PARTIAL`.

The aggregate P05 report ties those facts back to the P04 integrated proof,
M13 runtime/app shell report, M14 recording report, and M15 clean-Mac field
report. P05 may stay PARTIAL with synthetic evidence, but it cannot PASS without
measured P04 evidence or an explicitly accepted defensible P04 PARTIAL.

## Acceptance Criteria

- CLI can run the prototype workflow and write reports.
- App shell does not own realtime audio/video/control paths.
- Recording evidence is enabled and proves writes stay outside realtime paths.
- Clean-Mac field test produces a machine-readable verdict.
- Signing/notarization status is recorded without blocking earlier CLI
  evidence.

## Risks and Mitigations

- App shell can start owning realtime paths. Mitigation: keep ownership in
  headless core and record app-vs-CLI metrics separately.
- Permission prompts can make field runs ambiguous. Mitigation: record observed
  prompt and permission state.
- Signing work can distract from measurement. Mitigation: defer signing until
  valid field reports exist.

## Known Blockers

- Requires P04 measured evidence before app/runtime expansion.
- Requires clean-Mac access for PASS.
- Requires signing identity only when signed app status is requested.

## Progress Checklist

- [ ] Confirm runtime mode.
- [ ] Keep CLI workflow functional.
- [ ] Record permission purpose strings and observed prompts.
- [ ] Add or validate recording/session artifact writer outside realtime paths.
- [ ] Defer signing/notarization until valid field report exists.
- [ ] Run clean-Mac launch, inventory, RME, ATEM, and report-writing smoke.
- [x] Add bounded aggregate P05 proof handoff.
- [ ] Validate aggregate P05 proof report from measured clean-Mac evidence.
- [ ] Update [status/P05_STATUS.md](status/P05_STATUS.md).

## Next Recommended Action

Do not expand app/runtime ownership before P04. Keep the field prototype
CLI-first and add only the minimum artifact and permission surfaces needed to
run the measured workflow outside the development Mac.

## Resume here

Start from [status/P05_STATUS.md](status/P05_STATUS.md),
`FieldReadyRuntimeProof.swift`, and `field-runtime-proof-run` after P04 has
measured PASS or a defensible PARTIAL.
