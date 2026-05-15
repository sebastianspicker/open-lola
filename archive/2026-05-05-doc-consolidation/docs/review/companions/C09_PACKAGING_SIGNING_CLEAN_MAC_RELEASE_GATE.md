# C09 Packaging Signing Clean-Mac Release Gate

Date: 2026-05-04  
Status: source-level release gate implemented  
Priority: P0  
Verdict: PARTIAL

## Code Evidence

- Release and field readiness code exists in `PackagingFieldTest.swift`,
  `PackagingFieldTestValidation.swift`,
  `PackagingFieldTestRun.swift`, `ReleaseHardening.swift`,
  `FieldReadyRuntimeProof.swift`, `FieldReadinessRun.swift`,
  `RecordingSessionArtifacts.swift`, and related helpers.
- CLI commands include `packaging-field-run`, `field-runtime-proof-run`,
  `field-readiness-run`, `release-hardening-run`, and validators.
- The implemented C09 gate now requires signed release artifacts, non-placeholder
  signing identity evidence, notarization submission evidence, stapled ticket
  evidence, Gatekeeper assessment evidence, package hashes, clean-Mac install
  target evidence, installed artifact hash evidence, and explicit clean-Mac hash
  verification before a packaging field report may validate as `PASS`.
- Existing memory and docs state M15 remains `PARTIAL` until real Developer ID,
  notarization, Gatekeeper, entitlements, distribution mode, and clean-Mac
  evidence exists.

## Objective

Make packaging/signing/clean-Mac release readiness impossible to misreport from
source-level or synthetic evidence.

## Affected Files

- `Sources/OpenLolaCore/PackagingFieldTest.swift`
- `Sources/OpenLolaCore/PackagingFieldTestRun.swift`
- `Sources/OpenLolaCore/PackagingFieldTestHelpers.swift`
- `Sources/OpenLolaCore/ReleaseHardening.swift`
- `Sources/OpenLolaCore/FieldReadyRuntimeProof.swift`
- `Sources/OpenLolaCore/FieldReadyRuntimeProofValidation.swift`
- `Sources/OpenLolaCore/FieldReadinessRun.swift`
- `Sources/OpenLolaCore/RecordingSessionArtifacts.swift`
- `Sources/open-lola/MilestoneCommands.swift`
- `Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift`
- `Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift`
- `Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift`
- packaging/release fixtures under `Tests/OpenLolaCoreTests/Fixtures/`

## Improvement Plan

1. Inventory every packaging/release/field proof command and validator. Done.
2. Define required evidence fields for Developer ID, notarization, hardened
   runtime, entitlements, Gatekeeper, distribution mode, package hash, install
   target, and clean-Mac result. Done.
3. Add negative fixtures for missing signing identity, missing notarization,
   missing Gatekeeper, missing clean-Mac, and synthetic-only PASS attempts.
   Done for packaging field reports.
4. Ensure synthetic smokes can only produce `PARTIAL` for release-critical
   claims. Done for packaging field synthetic smoke.
5. Add CLI validation examples for packaging and release reports. Done in this
   companion and verified locally.

## Implemented Changes

- Added release-evidence fields to packaging artifacts, notarization readiness,
  and clean-Mac field probes.
- Split packaging field validation into `PackagingFieldTestValidation.swift` so
  the report model remains below the file-size guard while the release gate is
  explicit and testable.
- Added false-PASS guards for missing distribution artifacts, missing artifact
  hashes, placeholder signing identities, missing notarization submission IDs,
  missing stapled-ticket evidence, missing Gatekeeper assessment evidence,
  missing clean-Mac install targets, placeholder clean-Mac evidence, and missing
  clean-Mac package hash verification.
- Added invalid packaging field fixtures for missing signing, missing
  notarization, missing Gatekeeper acceptance, and missing clean-Mac evidence.
- Extended `PackagingFieldTestTests.swift` with direct validator tests and
  fixture-backed regression tests for the new C09 gate.

## Acceptance Criteria

- A report cannot validate as release PASS without all signing and clean-Mac
  evidence. Implemented for packaging field reports.
- Synthetic release/package reports remain `PARTIAL`. Verified for packaging
  field synthetic smoke.
- Tests cover missing evidence and false-PASS attempts. Implemented for C09
  packaging false-PASS cases.
- CLI output clearly distinguishes source validation from release readiness.
  Validator smokes now reject the C09 negative fixtures while accepting the
  partial fixture.

## Verification

```bash
swift test
.build/debug/open-lola release-hardening-synthetic-smoke
.build/debug/open-lola validate-release-hardening-report Tests/OpenLolaCoreTests/Fixtures/ReleaseHardeningReports/valid/release-hardening-partial.json
.build/debug/open-lola validate-packaging-field-report Tests/OpenLolaCoreTests/Fixtures/PackagingFieldTests/valid/packaging-field-test-partial.json
.build/debug/open-lola validate-packaging-field-report Tests/OpenLolaCoreTests/Fixtures/PackagingFieldTests/invalid/packaging-field-test-missing-signing.json
.build/debug/open-lola validate-packaging-field-report Tests/OpenLolaCoreTests/Fixtures/PackagingFieldTests/invalid/packaging-field-test-missing-notarization.json
.build/debug/open-lola validate-packaging-field-report Tests/OpenLolaCoreTests/Fixtures/PackagingFieldTests/invalid/packaging-field-test-missing-gatekeeper.json
.build/debug/open-lola validate-packaging-field-report Tests/OpenLolaCoreTests/Fixtures/PackagingFieldTests/invalid/packaging-field-test-missing-clean-mac.json
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Resume Here

C09 is implemented as a source-level packaging field release gate. C01 and C08
now index command ownership, the expanded fixture set, and CLI smoke coverage;
C03 indexes report schemas and evidence classes, C05 indexes route evidence
boundaries, and C06 indexes realtime audio path ownership before source
movement. Resume with
[C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md](C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md).

VERDICT: PARTIAL
