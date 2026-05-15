# M14 Release Hardening

Date: 2026-05-04
Status: source-validation implemented; release evidence remains partial
Verdict: PARTIAL

## Objective

Prepare the Mac-native source tree for release-candidate review with public
documentation, machine-readable release claims, verification gates, benchmark
comparison, packaging checks, and explicit remaining evidence blockers.

## Scope

In scope:

- publication-safe docs and README entry points;
- release claim references backed by public docs, source tests, or measured
  reports;
- release-hardening source validation, fixture validation, synthetic smoke, and
  bounded report handoff;
- opt-in raw recording-session artifacts for selected Core Audio input channels
  and AVFoundation video frames;
- packaging, signing, clean-Mac, generated-artifact, and benchmark comparison
  gates.

Out of scope:

- claiming hardware, route, SDK, or peer compatibility without measured
  evidence;
- publishing raw reverse-engineering evidence or internal artifacts;
- marking release validation `PASS` while any gate remains partial.

## Affected Files

- `README.md`
- `docs/current-state.md`
- `docs/architecture/**`
- `docs/benchmarks/**`
- `docs/source-contracts/**`
- `Sources/OpenLolaCore/Release/ReleaseHardening.swift`
- `Sources/OpenLolaCore/Release/RecordingSessionArtifacts.swift`
- `Sources/OpenLolaCore/Release/RecordingSessionRun.swift`
- `Sources/open-lola/Commands/MilestoneCommands.swift`
- `Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift`
- `Tests/OpenLolaCoreTests/Fixtures/ReleaseHardeningReports/valid/release-hardening-partial.json`
- `mac-port/reports/M14_RELEASE_HARDENING_2026-05-03.md`
- `scripts/verify-docs.sh`

## Implementation Tasks

1. Document the supported E2E modes in `README.md`: Direct Audio First,
   Balanced AV, Multi-Video Performance, and WAN Stable.
2. Keep every mode labeled `PARTIAL` until the required physical evidence exists.
3. Validate public documentation and release-claim references with the
   release-hardening report model.
4. Expose the release-hardening CLI surface:

```bash
open-lola release-hardening-synthetic-smoke
open-lola release-hardening-run --output <release-hardening.json>
open-lola validate-release-hardening-report <release-hardening.json>
```

5. Reject `PASS` when verification gates fail, internal evidence is cited,
   benchmark regression is present, packaging/signing/clean-Mac evidence is
   partial, generated artifacts are included, or remaining partial gates exist.
6. Keep `recording-session-run` media capture opt-in. When enabled, write raw
   audio to `audio/input.pcm`, raw video bytes to `video/frames.raw`, and frame
   metadata to `video/frames.index.jsonl`; when disabled or unavailable, do not
   emit fake media artifacts.

## Test Plan

Required source and documentation checks:

- `bash scripts/verify-docs.sh`
- `shellcheck -x scripts/*.sh scripts/lib/*.sh`
- `swift test --filter ReleaseHardening`
- `swift test --filter RecordingSessionArtifactTests`
- `swift test --no-parallel`
- `.build/debug/open-lola release-hardening-synthetic-smoke`
- `.build/debug/open-lola release-hardening-run --output <path>`
- `.build/debug/open-lola validate-release-hardening-report <path>`

## Benchmark Plan

Release benchmark comparison remains `PARTIAL` until accepted reports exist for:

- M12 Apple Silicon performance;
- M13 E2E integrated benchmark;
- current F10 faster-than-LoLa closure or successor benchmark;
- same-hardware, same-route regression comparison.

## Acceptance Criteria

- Documentation matches shipped source behavior.
- Public release claims cite public docs, original tests, or measured reports,
  not raw internal evidence.
- Release-hardening fixture, synthetic smoke, runner, and validator all pass.
- Recording-session reports prove audio and video artifacts separately when
  capture is enabled.
- `PASS` is blocked until physical, packaging, signing, notarization,
  Gatekeeper, clean-Mac, and benchmark evidence exists.
- Clean-room protocol docs remain original and public-API based.

## Risks

- Release pressure may convert `PARTIAL` evidence into unsupported claims.
- Public docs may drift from source validation rules.
- Hardware support language may overstate untested devices or SDK paths.
- Generated build artifacts may leak into a release candidate.

## Blockers

- Accepted M12 Apple Silicon performance evidence.
- Accepted M13 E2E integrated benchmark evidence.
- Accepted M15 packaging, signing, notarization, Gatekeeper, and clean-Mac
  field evidence.
- Final M04 clean-room reviewer signoff and fixture provenance confirmation.

## Rollback Plan

If release validation fails, keep the release status at `PARTIAL`, preserve the
failed report for review, and narrow public claims to the source-level behavior
or measured evidence that already passed.

## Progress Checklist

- [x] README release validation surface documented.
- [x] Release-hardening source contract implemented.
- [x] Release-hardening fixture and synthetic smoke documented.
- [x] Public docs audit gate represented.
- [x] Internal-evidence claim rejection represented.
- [ ] Measured release-candidate benchmark bundle attached.
- [ ] Packaging, signing, notarization, Gatekeeper, and clean-Mac evidence
      attached.
- [ ] Final maintainer, clean-room, and legal signoff recorded.

## Resume Point

Run `release-hardening-run` from a measured release candidate, validate it with
`validate-release-hardening-report`, then attach the benchmark, packaging,
signing, notarization, Gatekeeper, clean-Mac, and M04 clean-room signoff evidence.
Keep M14 `PARTIAL` until every listed blocker is closed.

VERDICT: PARTIAL
