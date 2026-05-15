# C08 Test Fixture And CLI Smoke Matrix

Date: 2026-05-04  
Status: source-level matrix implemented  
Priority: P1  
Verdict: PARTIAL

## Code Evidence

- `Tests/OpenLolaCoreTests/` contains 64 Swift test/helper files.
- `Tests/OpenLolaCoreTests/Fixtures/` contains JSON and HEX fixtures for packet
  contracts, route reports, audio/video/control reports, release hardening,
  packaging, field runtime proof, and measurement reports.
- The executable fixture/CLI smoke matrix now lives in
  `FixtureSmokeMatrix.swift`, `FixtureSmokeMatrixData.swift`, and
  `FixtureSmokeMatrixTests.swift`.
- The CLI exposes the matrix through `open-lola fixture-smoke-matrix`.

## Objective

Create a test/fixture/CLI smoke matrix that supports future code refactors and
prevents false-green reporting.

## Affected Files

- `Tests/OpenLolaCoreTests/*.swift`
- `Tests/OpenLolaCoreTests/Fixtures/**`
- `Sources/OpenLolaCore/FixtureSmokeMatrix.swift`
- `Sources/OpenLolaCore/FixtureSmokeMatrixData.swift`
- `Sources/OpenLolaCore/Core/OpenLolaCLI.swift`
- `Sources/open-lola/*.swift`
- `Sources/OpenLolaCore/*SyntheticSmoke*.swift`
- `docs/compliance/fixture-provenance.md`
- `docs/review/fixture-cli-smoke-matrix.md`

## Improvement Plan

1. Map every fixture directory to source validator, test file, CLI validator,
   evidence class, and public/internal status. Done in source and docs.
2. Map every CLI smoke command to source owner, expected verdict, and whether it
   is synthetic-only. Done for all discovered `-synthetic-smoke` commands.
3. Add missing invalid fixtures for high-risk false-PASS cases. Done for the
   realtime audio engine synthetic PASS gap; C04/C09 false-PASS fixtures are
   also indexed.
4. Add command smoke expectations for C01 before command routing changes. Done
   through `FixtureSmokeMatrix.syntheticSmokes`.
5. Use the matrix as the prerequisite for source moves in C02. Recorded in
   `docs/review/fixture-cli-smoke-matrix.md`.

## Implemented Changes

- Added `FixtureSmokeMatrix` source types and data entries for 28 fixture
  groups and 29 synthetic CLI smoke commands.
- Added `OpenLolaCLI.fixtureSmokeMatrixJSONString()` and the
  `open-lola fixture-smoke-matrix` command.
- Added `FixtureSmokeMatrixTests.swift`, which verifies live fixture counts,
  related test/source ownership, synthetic-only CLI smoke labeling, high-risk
  false-PASS fixture presence, and JSON round-trip behavior.
- Added `realtime-audio-engine-synthetic-pass.json` and a regression test that
  rejects it with `passWithoutMeasuredRun`.
- Updated fixture provenance counts and added a human-readable review matrix.

## Acceptance Criteria

- Every fixture has provenance/status and a related test. Implemented at fixture
  group level and verified against the live fixture tree.
- Every synthetic smoke is labeled synthetic-only. Implemented and verified by
  discovering command strings from `Sources/open-lola/*.swift`.
- High-risk release/field/runtime reports have invalid false-PASS fixtures.
  Implemented for field runtime proof, integrated AV, packaging field,
  realtime audio engine, and release hardening.
- Future source move batches reference this matrix. Recorded in
  [../fixture-cli-smoke-matrix.md](../fixture-cli-smoke-matrix.md).

## Verification

```bash
swift test
.build/debug/open-lola fixture-smoke-matrix
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Resume Here

C08 is implemented. C01 is also implemented as executable command inventory and
validator routing cleanup. C03 is implemented as executable report schema and
evidence inventory. C06 is implemented as executable realtime audio path
inventory and RX PASS guard. C05 is implemented as executable route matrix and
NAT PASS guard. Continue with
[C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md](C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md).

VERDICT: PARTIAL
