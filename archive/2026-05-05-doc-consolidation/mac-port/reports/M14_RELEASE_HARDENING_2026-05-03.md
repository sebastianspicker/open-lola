# M14 Release Hardening Validation Report

Date: 2026-05-04  
Public surface: [Current State](../../docs/current-state.md)  
Status: PARTIAL

## Scope

This report validates the M14 source-level release-hardening contract for the
public release surface. It implements the release ledger schema, PASS guards,
fixture validation, synthetic smoke, bounded handoff writer, CLI validator, and
documentation verifier checks. It does not claim release PASS because measured
benchmark comparison, Developer ID signing, notarization, Gatekeeper, and
clean-Mac evidence remain open.

## Public Docs Audited

The public docs surface is `docs/`. The verifier now checks that public docs do
not include forbidden proprietary tokens and do not link directly into internal
evidence paths. Internal evidence may inform maintainer analysis, but public
release claims must cite one of:

- public documentation under `docs/`;
- open-lola tests or fixtures;
- selected measured reports under `mac-port/reports/` only after M06/M10
  redaction and release-manifest review.

`ReleaseHardeningReport` also rejects release claims that cite
`reverse-engineering/` or `win-compiled/` paths.

## Release Ledger Contract

The report records:

- public documentation audit state, clean-room review state, redaction review
  state, forbidden-token findings, internal-link findings, unsupported
  compatibility claims, generated-artifact findings, and evidence-label state;
- release claims, allowed evidence class, source path, source verdict, and
  notes;
- docs, shell, Swift build, Swift test, benchmark, packaging, and CLI smoke
  gates;
- selected release profile, M12 Apple Silicon performance reference, M13 E2E
  benchmark reference, current benchmark report ID, comparison state, and
  regression state;
- M15 packaging report ID, packaging verdict, signing verdict, clean-Mac
  verdict, and generated-artifact exclusion state;
- remaining PARTIAL gates.

PASS reports require a measured run, audited public docs, clean-room and
redaction review, evidence labels, no public-doc findings, every release claim
at PASS, every verification gate passed, benchmark comparison against accepted
M12/M13 evidence, no regression, PASS packaging/signing/clean-Mac evidence, no
generated release artifacts, and no remaining PARTIAL gates.

## Commands

```bash
swift test --filter ReleaseHardening
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
swift test
swift build
.build/debug/open-lola release-hardening-run --output /private/tmp/open-lola-m14-release-hardening.json
.build/debug/open-lola validate-release-hardening-report /private/tmp/open-lola-m14-release-hardening.json
.build/debug/open-lola validate-release-hardening-report Tests/OpenLolaCoreTests/Fixtures/ReleaseHardeningReports/valid/release-hardening-partial.json
.build/debug/open-lola release-hardening-synthetic-smoke
```

## Results

- 2026-05-03 red test run before implementation failed because the release-hardening
  report, PASS guards, synthetic smoke, run configuration, and runner did not
  exist.
- 2026-05-04 docs-contract red test failed while the live public M14 milestone
  still said implementation had not started and the README lacked release
  profile examples.
- `swift test --filter ReleaseHardening` passed with the focused M14 tests
  after the public milestone and README were updated.
- `swift test` passed with 644 tests.
- `shellcheck scripts/*.sh` passed.
- `swift build` failed under the command sandbox with SwiftPM
  `sandbox-exec: sandbox_apply: Operation not permitted`, then passed when
  rerun outside that sandbox.
- The release-hardening fixture validates with `VERDICT: PARTIAL`.
- The release-hardening synthetic smoke output validates with
  `VERDICT: PARTIAL`.
- The bounded release-hardening handoff writes a valid report with
  `VERDICT: PARTIAL`.
- PASS guards reject synthetic PASS, internal evidence citations, failing
  verification gates, benchmark regressions, partial packaging, missing
  clean-Mac evidence, missing signing evidence, generated-artifact leakage, and
  remaining PARTIAL gates.
- The docs verifier now requires this report and the release-hardening CLI
  surface.

## Deferred Runtime Evidence

M14 release hardening cannot be marked PASS until real reports exist for:

- full docs, shell, Swift build, Swift test, and user-surface verification on
  the release candidate;
- project `LICENSE`, `THIRD_PARTY_NOTICES.md`, SDK redistribution review, and
  fixture provenance review;
- measured regression benchmark comparison against accepted M12 Apple Silicon
  performance and M13 E2E integrated benchmark reports;
- final release claims backed only by public docs, open-lola tests, or measured
  reports;
- Developer ID signing, notarization, Gatekeeper, and clean-Mac field evidence
  through M15;
- maintainer review of compatibility wording and publication redactions.

## Verdict

M14 release-hardening source validation is implemented. The release remains
PARTIAL until measured verification, benchmark, packaging, signing, and
clean-Mac evidence exists.

VERDICT: PARTIAL

## Resume here

Use `open-lola release-hardening-run --output <path>` for bounded PARTIAL
handoffs. Use `open-lola validate-release-hardening-report <path>` for the
first measured release ledger after the full verification matrix and M15 clean-
Mac evidence are available. Keep release PASS blocked while any remaining
PARTIAL gate is listed.
