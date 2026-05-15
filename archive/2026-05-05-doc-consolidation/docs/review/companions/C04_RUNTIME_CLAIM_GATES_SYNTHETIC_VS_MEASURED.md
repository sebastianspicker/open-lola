# C04 Runtime Claim Gates Synthetic Vs Measured

Date: 2026-05-04  
Status: source implementation complete; real release evidence remains open  
Priority: P0  
Verdict: PARTIAL

## Code Evidence

- The repository contains many synthetic smokes and source-level validators.
- Release and field readiness code includes `ReleaseHardening.swift`,
  `PackagingFieldTest.swift`, `FieldReadyRuntimeProof.swift`,
  `FieldReadinessRun.swift`, `FasterThanLoLaClosure.swift`, and
  `LoLaParityDeferredFeatures.swift`.
- Project documentation already states that M15, integrated proof, field-ready
  runtime, clean-Mac, and release claims remain `PARTIAL` until real evidence
  exists.

## Objective

Make it difficult for code or CLI flows to turn synthetic/source-level evidence
into a real runtime PASS by accident.

## Affected Files

- `Sources/OpenLolaCore/ReleaseHardening.swift`
- `Sources/OpenLolaCore/PackagingFieldTest.swift`
- `Sources/OpenLolaCore/FieldReadyRuntimeProof.swift`
- `Sources/OpenLolaCore/FieldReadinessRun.swift`
- `Sources/OpenLolaCore/IntegratedAvReport*.swift`
- `Sources/OpenLolaCore/E2EBenchmark*.swift`
- release and field proof tests/fixtures

## Improvement Plan

1. Completed: inventoried release/field/integrated PASS-producing validators
   and CLI surfaces.
2. Completed: kept synthetic/source-level reports explicitly separated from
   measured release evidence through existing `runMode`, `verdict`, and report
   evidence fields.
3. Completed: tightened validation guards so release PASS requires measured
   report claims, required verification gate kinds, non-placeholder benchmark
   and packaging identifiers, release distribution, signed-app runtime mode,
   Gatekeeper-accepted distribution, clean-Mac evidence, and measured run modes.
4. Completed: added negative fixtures where synthetic reports attempt to claim
   real PASS.
5. Completed: kept synthetic/source-only smokes useful while preserving
   `VERDICT: PARTIAL` for source-only evidence.

## Implementation Summary

Changed source:

- `Sources/OpenLolaCore/ReleaseHardening.swift`
- `Sources/OpenLolaCore/ReleaseHardeningSyntheticSmoke.swift`
- `Sources/OpenLolaCore/PackagingFieldTest.swift`
- `Sources/OpenLolaCore/FieldReadyRuntimeProof.swift`
- `Sources/OpenLolaCore/FieldReadyRuntimeProofValidation.swift`
- `Sources/OpenLolaCore/IntegratedAvReportValidation.swift`

Changed tests and fixtures:

- `Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift`
- `Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift`
- `Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift`
- `Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift`
- `Tests/OpenLolaCoreTests/Fixtures/ReleaseHardeningReports/invalid/release-hardening-synthetic-pass.json`
- `Tests/OpenLolaCoreTests/Fixtures/PackagingFieldTests/invalid/packaging-field-test-synthetic-pass.json`
- `Tests/OpenLolaCoreTests/Fixtures/FieldReadyRuntimeProofs/invalid/field-runtime-proof-synthetic-pass.json`
- `Tests/OpenLolaCoreTests/Fixtures/IntegratedAvReports/invalid/integrated-av-synthetic-pass.json`

Implemented guards:

- `ReleaseHardeningReport` PASS now requires a measured run, a measured report
  claim, required release verification gate kinds, accepted benchmark
  comparison, non-placeholder benchmark/package identifiers, packaging PASS,
  clean-Mac PASS, signing PASS, generated artifact exclusion, and no remaining
  partial gates.
- `PackagingFieldTestReport` PASS now rejects ad-hoc/deferred distribution
  methods in addition to synthetic runs and incomplete signing/notarization/
  clean-Mac evidence.
- `FieldReadyRuntimeProofReport` PASS now requires P04 PASS, signed app runtime
  mode, Gatekeeper-accepted distribution, clean-Mac PASS, RME visibility, ATEM
  status, and machine-readable report-writing evidence.
- `IntegratedAvReport` checks synthetic PASS claims before duration/proof
  details, so synthetic reports fail as synthetic rather than as incidental
  short-run reports.

## Acceptance Criteria

- Synthetic smokes cannot satisfy real release/field PASS requirements.
- M15 packaging, field runtime proof, integrated AV proof, and release hardening
  remain `PARTIAL` without real evidence.
- Tests cover rejected false-PASS reports.

Status: completed for source-level validation. The product remains
release-readiness `PARTIAL` until real hardware, benchmark, signing,
notarization, Gatekeeper, and clean-Mac evidence exists.

## Verification

```bash
swift test
swift build
.build/debug/open-lola release-hardening-synthetic-smoke
.build/debug/open-lola validate-release-hardening-report Tests/OpenLolaCoreTests/Fixtures/ReleaseHardeningReports/valid/release-hardening-partial.json
.build/debug/open-lola validate-release-hardening-report Tests/OpenLolaCoreTests/Fixtures/ReleaseHardeningReports/invalid/release-hardening-synthetic-pass.json
.build/debug/open-lola validate-field-runtime-proof Tests/OpenLolaCoreTests/Fixtures/FieldReadyRuntimeProofs/invalid/field-runtime-proof-synthetic-pass.json
.build/debug/open-lola validate-packaging-field-report Tests/OpenLolaCoreTests/Fixtures/PackagingFieldTests/invalid/packaging-field-test-synthetic-pass.json
.build/debug/open-lola validate-integrated-av-report Tests/OpenLolaCoreTests/Fixtures/IntegratedAvReports/invalid/integrated-av-synthetic-pass.json
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Resume Here

Resume with
[C12_ARTIFACT_DEPENDENCY_GENERATED_OUTPUT_HYGIENE.md](C12_ARTIFACT_DEPENDENCY_GENERATED_OUTPUT_HYGIENE.md);
C07 is now implemented.
C01, C03, C04, C05, C06, C08, and C09 are implemented; source movement still
waits until C02 explicitly approves source ownership boundaries.

VERDICT: PARTIAL
