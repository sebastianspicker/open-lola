# M14 Release Hardening

Date: 2026-05-03  
Status: source-validation implemented; release evidence remains partial  
Verdict: PARTIAL

## Objective

Harden the public release surface without leaking proprietary evidence or
weakening latency guarantees.

## Scope

Cover public docs, verifier gates, source tests, release notes, packaging
readiness, clean-room audit, and final validation commands.

## Affected Files

- [../README.md](../README.md)
- [../architecture/clean-room-design-rules.md](../architecture/clean-room-design-rules.md)
- [../architecture/implementation-roadmap.md](../architecture/implementation-roadmap.md)
- `README.md`
- `MAC_PORT_PLAN.md`
- `mac-port/IMPLEMENTATION_COMPANION.md`
- `mac-port/PROGRESS.md`
- `mac-port/VALIDATION_CHECKLIST.md`
- `scripts/verify-docs.sh`
- `scripts/verify_docs/`
- `Sources/OpenLolaCore/ReleaseHardening.swift`
- `Sources/open-lola/MilestoneCommands.swift`
- `Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift`
- `Tests/OpenLolaCoreTests/Fixtures/ReleaseHardeningReports/valid/`
- `mac-port/reports/M14_RELEASE_HARDENING_2026-05-03.md`

## Implementation Tasks

- Add a release-hardening report schema with PASS guards for public docs,
  release claims, verification gates, benchmark comparison, packaging readiness,
  clean-Mac readiness, and remaining PARTIAL gates.
- Ensure release claims cite only public docs, open-lola tests, or measured
  reports; internal evidence paths are rejected by validation.
- Extend the docs verifier so public docs cannot link directly to internal
  evidence paths and the M14 report must include the CLI release-hardening
  surface.
- Run docs, shell, Swift build/test, and user-surface probes.
- Record remaining PARTIAL gates honestly.

## Test Plan

- `bash scripts/verify-docs.sh`
- `shellcheck scripts/verify-docs.sh`
- `swift build`
- `swift test`
- `swift test --filter ReleaseHardening`
- `.build/debug/open-lola release-hardening-run --output <path>`
- `.build/debug/open-lola validate-release-hardening-report <path>`
- `.build/debug/open-lola release-hardening-synthetic-smoke`
- CLI smoke probes relevant to the final feature set

## Benchmark Plan

Run regression benchmarks for the selected release profile and compare against
the accepted M12/M13 reports. The source contract now rejects PASS unless that
comparison is recorded and no regression is detected.

## Acceptance Criteria

- Public docs are clean-room safe.
- Release claims match measured evidence.
- Full verification matrix passes or failures are explicitly documented.
- No proprietary implementation detail is published.
- PASS cannot be claimed while remaining PARTIAL gates exist.

## Risks

- Release pressure can convert PARTIAL evidence into overstated claims.
- Packaging and clean-Mac behavior can differ from development runs.
- Generated artifacts can pollute the public surface.

## Blockers

Any failing verification gate, unreviewed public compatibility claim, missing
hardware evidence for a claimed feature, or unresolved clean-room concern.

## Rollback Plan

Remove or downgrade unsupported release claims, disable unstable optional
features, and return to the last verified profile.

## Progress Checklist

- [x] Public docs audited at source-validation level.
- [x] Full verification matrix represented in the M14 release ledger.
- [x] Regression benchmark comparison gate implemented; measured comparison
  remains PARTIAL.
- [x] Release claims matched to allowed evidence classes.
- [x] M14 report stored.

## Resume Point

Resume at release review with `VERDICT: PARTIAL` unless every claimed hardware,
route, audio, video, lighting, packaging, and clean-room gate has measured PASS
evidence.

VERDICT: PARTIAL
