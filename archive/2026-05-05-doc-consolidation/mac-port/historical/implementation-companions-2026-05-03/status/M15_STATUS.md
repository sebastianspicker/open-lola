# M15 Status

## Current status

- Status: Partial.
- Verdict: PARTIAL 2026-05-03.
- Canonical milestone: [M15 Packaging Field Test](../milestones/M15_PACKAGING_FIELD_TEST.md)
- Validation report: [M15 Packaging Field Test Validation Report](../reports/M15_PACKAGING_FIELD_TEST_2026-05-02.md)

Canonical objective:

Package, sign, and field-test the Mac app and tools on clean Macs with a
signed/notarization-ready build and a field report verdict.

Canonical assumptions:

- The app and CLIs have stable capabilities before packaging.
- Signing identity and clean-Mac target are available before final validation.
- Notarization readiness is required even if distribution remains self-hosted.

Canonical dependencies:

- M13 native app shell.
- M14 recording/session artifacts if field reports include recordings.
- Signing certificate and entitlement plan.
- Clean Mac test machine.

Canonical affected modules/files:

- Future packaging scripts or Xcode archive settings.
- Future entitlements.
- Future field-test report fixture.
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)

Canonical implementation sequence:

1. Define package contents: app, CLIs, docs, and report templates.
2. Add signing and entitlement configuration.
3. Build archive or distributable package.
4. Validate launch, permissions, audio device access, camera access, network
   access, and report writing on a clean Mac.
5. Run field test and record verdict.

Canonical acceptance criteria:

- Package is signed and notarization-ready.
- Clean-Mac install or launch path is documented.
- Required permissions are prompted and recorded.
- Field report ends with `VERDICT: PASS`, `VERDICT: FAIL`, or
  `VERDICT: PARTIAL`.

Rollback/recovery notes:

- Documentation-only changes: restore the preserved historical copy when one exists, or revert the specific changed file.
- Source changes: revert the smallest affected change set and rerun `swift test`.
- Hardware, network, audio, video, lighting, recording, or packaging reports: mark the report invalid rather than deleting it, then rerun measurement.

## Completed work

- Added `PackagingFieldTestReport` with package contents, signing readiness,
  notarization readiness, entitlement/purpose-string readiness, clean-Mac probe
  fields, field-report coverage, and PASS/PARTIAL verdict validation.
- Added `PackagingFieldTestSyntheticSmoke` for deterministic source validation.
- Added PASS guards that reject missing app bundles, missing `open-lola` CLI,
  missing docs/report templates, unsigned or invalid signatures, non-Developer
  ID signatures for Developer ID distribution, missing hardened runtime, missing
  secure timestamp, deprecated `altool`, missing notarization readiness,
  missing notarization acceptance, missing stapled ticket, failed Gatekeeper
  assessment, missing entitlement review, missing purpose strings, missing
  clean-Mac test, failed app launch, failed CLI smoke, missing permission prompt
  record, missing media/network access, failed report write, incomplete field
  evidence, and missing verdict line.
- Added CLI validation with `open-lola validate-packaging-field-report <path>`.
- Added CLI smoke output with `open-lola packaging-field-synthetic-smoke`.
- Added `PackagingFieldRunConfiguration` and `PackagingFieldRunner` for a
  bounded `open-lola packaging-field-run --integrated-report <path>
  --app-report <path> --recording-report <path> --output-dir <dir> --report
  <path>` handoff that writes an ad-hoc package layout, purpose-string files,
  entitlements, docs, report template, and a PARTIAL M15 report.
- Added `FieldReadyRuntimeProofRunConfiguration`,
  `FieldReadyRuntimeProofRunner`, and `open-lola field-runtime-proof-run` to
  aggregate M10, M13, M14, and M15 reports into a PARTIAL P05 proof.
- Added a synthetic PARTIAL packaging field-test fixture.
- Added [../reports/M15_PACKAGING_FIELD_TEST_2026-05-02.md](../reports/M15_PACKAGING_FIELD_TEST_2026-05-02.md).

## Verified work

- Red test run failed before implementation because M15 packaging/field-test
  types did not exist.
- `swift test --filter PackagingFieldTest` passed with 12 tests.
- 2026-05-03: `swift test --filter PackagingFieldTest` passed with 15 tests
  after adding the ad-hoc package handoff.
- 2026-05-03: `swift test --filter FieldReadyRuntime` passed with 16 tests
  after adding the aggregate P05 handoff.
- `.build/debug/open-lola validate-packaging-field-report Tests/OpenLolaCoreTests/Fixtures/PackagingFieldTests/valid/packaging-field-test-partial.json`
  passed with `VERDICT: PARTIAL`.
- `.build/debug/open-lola packaging-field-synthetic-smoke` passed with
  `VERDICT: PARTIAL`.
- `bash scripts/verify-docs.sh` passed.
- `shellcheck scripts/*.sh` passed.
- `swift test` passed with 128 tests.
- `swift build` passed after rerunning outside the sandbox to avoid the known
  SwiftPM `sandbox-exec: sandbox_apply: Operation not permitted` manifest
  failure.

## Partially completed work

- Source validation exists for package contents, Developer ID signing readiness,
  hardened runtime, secure timestamp, notarization readiness, entitlement and
  purpose-string readiness, clean-Mac probe fields, and field-report coverage.
- A bounded ad-hoc package layout can now be generated from M10/M13/M14 reports,
  and a P05 aggregate proof can be generated from M10/M13/M14/M15 reports.
- PASS-level runtime/distribution evidence is not complete because no real
  signed package, notarization ticket, Gatekeeper assessment, or clean-Mac field
  report has been recorded.

## Deferred work

- Real packaging script or Xcode archive/export settings beyond the ad-hoc
  local layout handoff.
- Real entitlements file and Info.plist purpose strings.
- Developer ID signing identity and secure timestamp.
- Notary submission, accepted ticket, and stapling.
- Clean-Mac install or launch validation.
- Final field report over measured M01-M14 runtime evidence.

## Open tasks

Canonical progress checklist:

- [x] Define package contents.
- [x] Add signing/entitlement config.
- [x] Build ad-hoc local package layout.
- [ ] Build Developer ID signed package.
- [ ] Validate signature.
- [ ] Test on clean Mac.
- [x] Record PARTIAL ad-hoc field report.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

SOTA 2026 routing:

- Rows: Q010, SOTA009, SOTA013, SOTA015, SOTA073 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: field-test closure records signing identity, clean-Mac target, fallback-route decisions, and deferred artistic/control integrations.

Faster-than-LoLa companion implementation plan:

- [ ] Keep M15 last. It proves the measured faster-Mac prototype can run on a
  clean Mac; it does not define the realtime architecture.
- [x] Package the smallest field surface first: `open-lola` CLI, optional
  `open-lola-app`, docs/report templates, and the validated report writer.
- [ ] Add Info.plist purpose strings and entitlement review for microphone,
  camera, and local network access before clean-Mac testing.
- [ ] Create a signed Developer ID package only after M13/M14 evidence exists,
  unless the user explicitly chooses an ad-hoc local package for earlier field
  smoke.
- [ ] Clean-Mac smoke must record launch, CLI summary, device inventory, RME
  visibility, camera permission/capture state, ATEM read-only connection where
  configured, local-network permission, report writing, and final verdict.
- [ ] Notarization readiness includes Developer ID signature, hardened runtime,
  secure timestamp, notarytool submission, accepted ticket, stapling, and
  Gatekeeper assessment. Do not use deprecated `altool`.

## Known blockers

- Signing certificate and distribution identity may require user input.
- Clean-Mac hardware may not be immediately available.
- PASS-level field testing depends on the measured M01-M14 evidence chain.

TODO(human): [M15 distribution] -> Provide signing identity and clean-Mac target for Q010 -> [ad-hoc local package / Developer ID signed package / defer packaging]

## Test coverage status

Canonical test plan:

Before: no installable app exists.

After:

- package builds;
- signature validation passes;
- clean-Mac launch succeeds;
- field report includes endpoint, network, audio, video, control, and packaging
  evidence as applicable;
- final verdict is recorded.

Coverage state: source-level M15 coverage exists for report fixture decoding,
synthetic smoke, JSON round trip, app-bundle PASS gate, Developer ID signature
PASS gate, hardened-runtime PASS gate, deprecated-`altool` PASS gate,
notarization-readiness PASS gate, purpose-string PASS gate, clean-Mac PASS gate,
launch PASS gate, and field verdict-line PASS gate. Real package build,
signature validation, notarization, Gatekeeper assessment, and clean-Mac launch
coverage remain missing.
Argument parsing, ad-hoc package artifact writing, and P05 aggregate proof
generation coverage also exists for the bounded handoff commands.

## Relevant files touched

Planned affected modules/files:

- Future packaging scripts or Xcode archive settings.
- Future entitlements and Info.plist purpose strings.
- Future measured field-test report fixture.
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)

Live files touched:

- [../../Sources/OpenLolaCore/PackagingFieldTest.swift](../../Sources/OpenLolaCore/PackagingFieldTest.swift)
- [../../Sources/OpenLolaCore/FieldReadyRuntimeProof.swift](../../Sources/OpenLolaCore/FieldReadyRuntimeProof.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift](../../Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift)
- [../../Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift](../../Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/PackagingFieldTests/valid/packaging-field-test-partial.json](../../Tests/OpenLolaCoreTests/Fixtures/PackagingFieldTests/valid/packaging-field-test-partial.json)
- [../reports/M15_PACKAGING_FIELD_TEST_2026-05-02.md](../reports/M15_PACKAGING_FIELD_TEST_2026-05-02.md)
- [../milestones/M15_PACKAGING_FIELD_TEST.md](../milestones/M15_PACKAGING_FIELD_TEST.md)
- [../PROGRESS.md](../PROGRESS.md)
- [../STATUS_INDEX.md](../STATUS_INDEX.md)
- [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md)
- [../MILESTONE_INDEX.md](../MILESTONE_INDEX.md)
- [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md)
- [../RISK_REGISTER.md](../RISK_REGISTER.md)
- [../../MAC_PORT_PLAN.md](../../MAC_PORT_PLAN.md)

## Latest verification

Commands:

```bash
swift test --filter PackagingFieldTest
swift test --filter FieldReadyRuntime
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
swift test
swift build
.build/debug/open-lola packaging-field-run --integrated-report /private/tmp/open-lola-g15-m10-integrated-av-smoke.json --app-report /private/tmp/open-lola-g15-m13-native-app-runtime-smoke.json --recording-report /private/tmp/open-lola-g15-m14-recording-session-run.json --output-dir /private/tmp/open-lola-g15-m15-package --report /private/tmp/open-lola-g15-m15-packaging-field-run.json
.build/debug/open-lola validate-packaging-field-report /private/tmp/open-lola-g15-m15-packaging-field-run.json
.build/debug/open-lola field-runtime-proof-run --integrated-report /private/tmp/open-lola-g15-m10-integrated-av-smoke.json --app-report /private/tmp/open-lola-g15-m13-native-app-runtime-smoke.json --recording-report /private/tmp/open-lola-g15-m14-recording-session-run.json --packaging-report /private/tmp/open-lola-g15-m15-packaging-field-run.json --output /private/tmp/open-lola-g15-p05-field-runtime-proof-run.json
.build/debug/open-lola validate-field-runtime-proof /private/tmp/open-lola-g15-p05-field-runtime-proof-run.json
.build/debug/open-lola validate-packaging-field-report Tests/OpenLolaCoreTests/Fixtures/PackagingFieldTests/valid/packaging-field-test-partial.json
.build/debug/open-lola packaging-field-synthetic-smoke
```

Result:

- Focused M15 and P05 tests pass.
- Full Swift/docs verification passes.
- The M15 ad-hoc package handoff, generated report validator, P05 aggregate
  proof handoff, generated proof validator, fixture validator, and synthetic
  smoke command pass with
  `VERDICT: PARTIAL`.
- `swift build` requires the existing sandbox escalation in this environment
  because SwiftPM manifest compilation fails under `sandbox-exec`.
- 2026-05-02: faster-than-LoLa companion plan update passed
  `bash scripts/verify-docs.sh` and `shellcheck scripts/*.sh`.
- VERDICT: PARTIAL

## Next recommended steps

After the current ad-hoc handoff is sufficient for local field rehearsal,
answer Q010 with signing identity, distribution method, entitlements, and
clean-Mac target, then create the smallest signed package and field report.

## Resume here

Start from `PackagingFieldTest.swift`, `FieldReadyRuntimeProof.swift`,
`packaging-field-run`, and `field-runtime-proof-run`. Answer Q010 in
[../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md), then replace the ad-hoc layout
with the smallest signed package that can launch, show RME/camera/network
permission state, connect to ATEM read-only where configured, and write a field
report on a clean Mac.
