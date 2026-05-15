# P05 Status

## Current status

- Status: Partial.
- Canonical prototype milestone: [P05 Field-Ready Runtime](../P05_FIELD_READY_RUNTIME.md)
- Objective: make the prototype field-runnable while keeping the first runtime
  CLI/headless and measurement-first.
- Assumptions: app/runtime expansion waits for P04 measured PASS or defensible
  PARTIAL; app shell does not own realtime paths; recording artifacts stay
  outside callbacks.
- Dependencies: P04 evidence, permission purpose strings when needed, report
  writer outside realtime paths, and clean-Mac target.
- Affected modules/files: CLI, app shell, native app shell report, recording
  artifacts, packaging field report, and this status companion.
- Implementation sequence: confirm runtime mode, keep CLI workflow, add
  permission/report/artifact surfaces, defer signing until field report exists,
  run clean-Mac smoke.
- Acceptance criteria: CLI workflow writes reports, app shell does not own
  realtime paths, recording writes stay outside realtime paths, clean-Mac field
  test produces machine-readable verdict.
- Rollback/recovery notes: if app/runtime changes disturb headless metrics,
  disable the app/runtime path and keep CLI as authoritative prototype runner.

## Completed work

- Added the P05 prototype milestone contract.
- Added this live P05 companion.
- Added `FieldReadyRuntimeProofReport` as the aggregate P05 proof contract.
- Added PASS guards for measured P04 evidence or accepted defensible P04
  PARTIAL, CLI/headless authority, CLI report writing, app shell not owning
  realtime paths, purpose strings, observed permission prompts, recording
  evidence outside realtime paths, recorded signing/notarization status,
  clean-Mac target, RME visibility, ATEM read-only status, report writing, and a
  machine-readable clean-Mac verdict.
- Added CLI validation with `open-lola validate-field-runtime-proof <path>`.
- Added CLI smoke output with `open-lola field-runtime-synthetic-smoke`.
- Added a synthetic PARTIAL P05 proof fixture.
- Added `FieldReadyRuntimeProofRunConfiguration` and
  `FieldReadyRuntimeProofRunner` for a bounded `open-lola
  field-runtime-proof-run --integrated-report <path> --app-report <path>
  --recording-report <path> --packaging-report <path> --output <path>` handoff
  that aggregates M10, M13, M14, and M15 reports into a PARTIAL P05 proof.

## Verified work

- Baseline documentation verifier and shellcheck passed before adding the
  prototype layer.
- Post-change `swift build` passed.
- Post-change `swift test` passed with 128 Swift Testing tests.
- Post-change `bash scripts/verify-docs.sh` passed with prototype docs included.
- Post-change `shellcheck scripts/*.sh` passed.
- Existing valid native app shell, recording session, and packaging field
  fixtures passed their CLI validators.
- 2026-05-02: P05 aggregate proof red test failed before implementation because
  `FieldReadyRuntimeProofReport`, `FieldReadyRuntimeSyntheticSmoke`, and the
  validation errors did not exist.
- 2026-05-02: `swift test --filter FieldReadyRuntime` passed with 13 tests
  after adding the aggregate proof contract.
- 2026-05-03: `swift test --filter FieldReadyRuntime` passed with 16 tests
  after adding the aggregate proof handoff.

## Partially completed work

- Existing M13, M14, and M15 report contracts can represent app shell,
  recording, and field-test evidence.
- P05 now has a single aggregate proof report that references those source
  reports and makes the field runtime closure gate executable.
- `field-runtime-proof-run` can now populate that aggregate proof from current
  M10, M13, M14, and M15 report files.
- PASS-level field evidence is not complete because no measured clean-Mac
  RME/ATEM/report-writing run has been recorded.

## Deferred work

- Runtime mode decision is deferred until P04 has measured evidence.
- Permission prompt observation, signing, notarization, and clean-Mac field test
  are deferred.

## Open tasks

- [x] Record runtime mode: CLI-only, app shell, or signed app.
- [ ] Record permission prompts observed.
- [x] Record recording enabled/disabled state.
- [x] Record signing identity and notarization status.
- [ ] Record clean-Mac field-test target and verdict.
- [x] Prove CLI prototype workflow can write reports at the report-contract
  level.
- [x] Confirm app shell does not own realtime audio/video/control paths at the
  report-contract level.
- [x] Add aggregate P05 proof validator and synthetic smoke.
- [x] Add aggregate P05 proof handoff writer.

## Known blockers

- P04 integrated proof is not complete.
- Clean-Mac target is not recorded.
- Real signing identity is not supplied and notarization remains deferred.

## Test coverage status

- Required general gates: `swift build`, `swift test`,
  `bash scripts/verify-docs.sh`, `shellcheck scripts/*.sh`.
- Required field gates: native app shell, recording session, and packaging
  field report validators when those artifacts exist.
- Coverage state: aggregate P05 proof coverage exists for fixture decoding,
  synthetic smoke, JSON round trip, measured-run PASS gate, P04 defensible
  evidence gate, CLI report-writing gate, app realtime ownership gate,
  permission prompt gate, recording evidence gate, clean-Mac target gate, RME
  visibility gate, ATEM status gate, and machine-readable field verdict gate.
  Clean-Mac runtime evidence is not recorded yet.
  Argument parsing and aggregate proof generation from M10/M13/M14/M15 reports
  are covered by focused tests.

## Relevant files touched

- [../P05_FIELD_READY_RUNTIME.md](../P05_FIELD_READY_RUNTIME.md)
- [P05_STATUS.md](P05_STATUS.md)
- [../../../Sources/OpenLolaCore/FieldReadyRuntimeProof.swift](../../../Sources/OpenLolaCore/FieldReadyRuntimeProof.swift)
- [../../../Sources/open-lola/main.swift](../../../Sources/open-lola/main.swift)
- [../../../Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift](../../../Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift)
- [../../../Tests/OpenLolaCoreTests/Fixtures/FieldReadyRuntimeProofs/valid/field-runtime-proof-partial.json](../../../Tests/OpenLolaCoreTests/Fixtures/FieldReadyRuntimeProofs/valid/field-runtime-proof-partial.json)

## Latest verification

- 2026-05-02: `swift build` passed.
- 2026-05-02: `swift test` passed with 128 Swift Testing tests.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- 2026-05-02: `swift run open-lola validate-native-app-shell-report
  Tests/OpenLolaCoreTests/Fixtures/NativeAppShellReports/valid/native-app-shell-partial.json`
  passed with `VERDICT: PARTIAL`.
- 2026-05-02: `swift run open-lola validate-recording-session-report
  Tests/OpenLolaCoreTests/Fixtures/RecordingSessionArtifacts/valid/recording-session-partial.json`
  passed with `VERDICT: PARTIAL`.
- 2026-05-02: `swift run open-lola validate-packaging-field-report
  Tests/OpenLolaCoreTests/Fixtures/PackagingFieldTests/valid/packaging-field-test-partial.json`
  passed with `VERDICT: PARTIAL`.
- 2026-05-02: `swift test --filter FieldReadyRuntime` passed with 13 tests.
- 2026-05-02: `swift test` passed with 183 tests after adding the aggregate
  P05 proof contract.
- 2026-05-02: `swift build` passed after rerunning outside the known SwiftPM
  sandbox failure.
- 2026-05-02: `.build/debug/open-lola validate-field-runtime-proof
  Tests/OpenLolaCoreTests/Fixtures/FieldReadyRuntimeProofs/valid/field-runtime-proof-partial.json`
  passed with `VERDICT: PARTIAL`.
- 2026-05-02: `.build/debug/open-lola field-runtime-synthetic-smoke` passed
  with `VERDICT: PARTIAL`.
- 2026-05-03: `.build/debug/open-lola field-runtime-proof-run
  --integrated-report /private/tmp/open-lola-g15-m10-integrated-av-smoke.json
  --app-report /private/tmp/open-lola-g15-m13-native-app-runtime-smoke.json
  --recording-report /private/tmp/open-lola-g15-m14-recording-session-run.json
  --packaging-report /private/tmp/open-lola-g15-m15-packaging-field-run.json
  --output /private/tmp/open-lola-g15-p05-field-runtime-proof-run.json` wrote a
  PARTIAL aggregate proof.
- 2026-05-03: `.build/debug/open-lola validate-field-runtime-proof
  /private/tmp/open-lola-g15-p05-field-runtime-proof-run.json` passed with
  `VERDICT: PARTIAL`.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- VERDICT: PARTIAL

## Next recommended steps

Keep the runtime CLI-only until P04 records measured PASS or defensible PARTIAL.
Then fill the P05 aggregate proof with clean-Mac target, RME visibility,
ATEM read-only status, observed permission prompts, and report-writing evidence.

## Resume here

Resume after P04 records integrated evidence. Start from
`FieldReadyRuntimeProof.swift`, populate the aggregate report with
`field-runtime-proof-run` from real M13, M14, and M15 evidence, then validate it with
`open-lola validate-field-runtime-proof <path>`.
