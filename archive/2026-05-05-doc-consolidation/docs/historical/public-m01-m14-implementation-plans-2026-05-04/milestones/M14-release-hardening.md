# M14 Release Hardening

Date: 2026-05-04  
Status: source-validation implemented; release evidence remains partial  
Verdict: PARTIAL

## Objective

Prepare the full E2E AV transport system for reproducible validation and user
handoff with documentation, configuration profiles, troubleshooting, known
limits, recovery behavior, and release evidence.

## Scope

In scope:

- docs and README entry points;
- profile configuration examples;
- hardware setup checklists;
- troubleshooting;
- benchmark report interpretation;
- known limits;
- clean shutdown and recovery documentation;
- release validation checklist;
- source-level release ledger and PASS guards.

Out of scope:

- claiming unsupported hardware compatibility;
- hiding missing physical evidence;
- introducing cloud or relay defaults;
- marking release `PASS` without measured M12/M13/M15 evidence.

## Affected Files

Implemented source and release-facing files:

- `README.md`
- `docs/current-state.md`
- `docs/architecture/e2e-p2p-session.md`
- `docs/architecture/open-lola-protocol.md`
- `docs/architecture/madi-full-rx-tx.md`
- `docs/architecture/blackmagic-video-rx-tx.md`
- `docs/architecture/latency-profiles.md`
- `docs/benchmarks/e2e-av-benchmark-methodology.md`
- `Sources/OpenLolaCore/ReleaseHardening.swift`
- `Sources/open-lola/MilestoneCommands.swift`
- `Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift`
- `Tests/OpenLolaCoreTests/Fixtures/ReleaseHardeningReports/valid/release-hardening-partial.json`
- `mac-port/reports/M14_RELEASE_HARDENING_2026-05-03.md`
- `scripts/verify-docs.sh`
- `scripts/verify_docs/`

## Implementation Tasks

1. Update README with the exact supported E2E modes and evidence status. Done.
2. Update current-state docs with M02-M13 results. Done; release hardening now
   records M14 source status while measured release evidence remains open.
3. Add configuration examples for Direct Audio First, Balanced AV,
   Multi-Video Performance, and WAN Stable. Done in `README.md`.
4. Add hardware setup checks for RME-compatible MADI and Blackmagic-compatible
   video. Done in `README.md` and the architecture docs.
5. Add troubleshooting for no device, wrong sample rate, channel mismatch,
   underruns, packet loss, late video, and reconnect. Done in `README.md`.
6. Add release validation checklist and known limits. Done in `README.md` and
   `ReleaseHardeningReport`.
7. Run full docs and source verification. Done for source validation; physical
   release evidence remains open.

## Source Contract

`ReleaseHardeningReport` records:

- public documentation audit state, clean-room review state, redaction review
  state, forbidden-token findings, internal-link findings, generated-artifact
  findings, unsupported compatibility claims, and evidence-label state;
- release claims with allowed evidence class, source path, source verdict, and
  notes;
- docs, shell, Swift build, Swift test, benchmark, packaging, and CLI smoke
  gates;
- selected profile, M12 Apple Silicon performance report ID, M13 E2E benchmark
  report ID, current benchmark report ID, comparison state, and regression
  state;
- packaging, signing, clean-Mac, and generated-artifact exclusion state;
- remaining `PARTIAL` gates.

PASS validation rejects synthetic runs, internal evidence citations, failing
verification gates, benchmark regressions, partial packaging, missing clean-Mac
evidence, missing signing evidence, generated artifacts, and any remaining
partial gates.

## CLI Surface

```bash
open-lola release-hardening-synthetic-smoke
open-lola release-hardening-run --output <release-hardening.json>
open-lola validate-release-hardening-report <release-hardening.json>
```

## Test Plan

Required verification:

- `bash scripts/verify-docs.sh`
- `shellcheck scripts/*.sh`
- `swift test --filter ReleaseHardening`
- `swift test --filter scopedCodeFilesStayWithinLineBudget`
- `swift test`
- `swift build`
- `.build/debug/open-lola release-hardening-run --output <path>`
- `.build/debug/open-lola validate-release-hardening-report <path>`
- `.build/debug/open-lola release-hardening-synthetic-smoke`
- E2E benchmark smoke and validator for the M13 dependency.

## Benchmark Plan

Release benchmark bundle:

- Direct Audio First audio-only;
- Balanced AV one video stream;
- Multi-Video Performance with configured stream count;
- WAN Stable impairment profile;
- reconnect and clean shutdown;
- maximum stable channel count and buffer size matrix.

The source contract rejects `PASS` unless this bundle is compared with accepted
M12 Apple Silicon performance evidence, accepted M13 E2E benchmark evidence,
and current F10 faster-than-LoLa closure evidence without regression.

## Acceptance Criteria

- Documentation matches shipped behavior.
- Every `PASS` claim has physical evidence.
- Missing hardware evidence is labeled `PARTIAL`.
- CI/source checks pass.
- User-facing commands have examples and failure modes.
- Clean-room protocol docs remain original and public-API based.
- Release ledger has no remaining partial gates before `PASS`.

## Known Limits

- Full live two-peer MADI plus Blackmagic AV runtime remains evidence-bound.
- Developer ID signing, notarization, Gatekeeper, and clean-Mac launch evidence
  are M15/P05 gates and cannot be inferred from source tests.
- Synthetic smokes validate report shape only.
- WAN Stable is a continuity profile, not a fastest-latency claim.

## Risks

- Release docs can become stale if they duplicate source constants. Prefer
  source-validated tables and machine-readable reports where practical.
- Hardware support language must remain conservative.
- Release pressure can convert `PARTIAL` evidence into overstated claims.

## Blockers

- Accepted M12 Apple Silicon performance evidence.
- Accepted M13 E2E integrated benchmark evidence.
- Accepted M15 packaging, signing, notarization, Gatekeeper, and clean-Mac
  field evidence.
- Physical hardware required for end-to-end `PASS`.

## Rollback Plan

If release validation fails, keep the feature in `PARTIAL` status, preserve the
benchmark evidence, and narrow README claims to source-level or
hardware-specific results already proven.

## Progress Checklist

- [x] Update README.
- [x] Update current-state evidence.
- [x] Add configuration examples.
- [x] Add troubleshooting.
- [x] Add release validation checklist.
- [x] Add source-level release ledger, validator, fixture, smoke, and runner.
- [x] Run source and docs verification for the source contract.
- [ ] Publish physical benchmark evidence.
- [ ] Attach Developer ID, notarization, Gatekeeper, and clean-Mac release
  evidence.

## Resume Point

Run the full release matrix, write a measured report with
`release-hardening-run` or a measured equivalent, then validate it with
`validate-release-hardening-report`. Keep M14 `PARTIAL` until every claimed
hardware, route, audio, video, packaging, and clean-room gate has measured
`PASS` evidence.

VERDICT: PARTIAL
