# Verification Matrix

Date: 2026-05-05  
Status: executable C10 local/CI parity, C12 release hygiene, and GOAL.md codewise closure contracts implemented  
Milestone: C10, C12  
Verdict: PARTIAL

## Purpose

This document is the durable release-readiness verification matrix for C10. The
local and CI entrypoints intentionally share one command:

```bash
bash scripts/verify-release-readiness.sh
```

The future GitHub Actions workflow is:

```text
.github/workflows/release-readiness.yml
```

The workflow is read-only and runs the local script. It does not publish,
upload, notarize, package, or release artifacts.

## Local Matrix

| Gate | Command | Purpose | Expected result |
|---|---|---|---|
| Documentation contract | `bash scripts/verify-docs.sh` | Validates active Markdown links, required sections, public planning contracts, Windows evidence docs, and review docs. | pass |
| Shell scripts | `shellcheck scripts/*.sh` | Keeps verification scripts strict and portable enough for local and CI execution. | pass |
| C12 artifact hygiene | `bash scripts/verify-release-hygiene.sh` | Verifies generated-output exclusions, dependency-notice alignment, and internal/vendor artifact release boundaries. | pass |
| Release candidate export | `bash scripts/export-release-candidate.sh /path/to/output-parent` | Stages the allowlisted source candidate and runs the C12 candidate scan before inspection. | pass |
| Swift build | `swift build` | Proves SwiftPM package, library, CLI, and app targets compile. | pass |
| Swift tests | `swift test` | Runs source, report, CLI, fixture, release, and verification contract tests. | pass |
| Release boundary check | inside `verify-release-hygiene.sh` and `verify-release-readiness.sh` | Confirms generated output, package products, internal review docs, raw reverse-engineering evidence, and vendor binaries are excluded from release candidates. | pass |
| Manual release gates | inside `verify-release-readiness.sh` | Prints that Developer ID, notarization, Gatekeeper, clean-Mac, hardware, and benchmark evidence are manual gates. | manual |
| CLI ownership probe | `.build/debug/open-lola command-inventory` | Verifies C01 command ownership output still runs. | `VERDICT: PARTIAL` |
| Source ownership probe | `.build/debug/open-lola source-ownership-inventory` | Verifies C02 source ownership output still runs. | `VERDICT: PARTIAL` |
| Fixture smoke matrix probe | `.build/debug/open-lola fixture-smoke-matrix` | Verifies C08 fixture/CLI smoke ownership output still runs. | `VERDICT: PARTIAL` |
| Report schema probe | `.build/debug/open-lola report-schema-inventory` | Verifies C03 schema/evidence output still runs. | `VERDICT: PARTIAL` |
| GOAL.md codewise closure probe | `.build/debug/open-lola goal-codewise-closure` | Verifies source, docs, CLI, validation, and artifact coverage for `GOAL.md`. | `VERDICT: PASS` plus `real-world-verdict: partial` |
| GOAL.md codewise closure validator | `.build/debug/open-lola goal-codewise-closure-run --output /private/tmp/open-lola-goal-codewise-closure.json && .build/debug/open-lola validate-goal-codewise-closure-report /private/tmp/open-lola-goal-codewise-closure.json` | Verifies the generated closure artifact rejects false real-world PASS while accepting codewise PASS. | `VERDICT: PASS` plus `real-world-verdict: partial` |
| Realtime audio probe | `.build/debug/open-lola realtime-audio-path-inventory` | Verifies C06 audio path ownership output still runs. | `VERDICT: PARTIAL` |
| Network route probe | `.build/debug/open-lola network-route-command-matrix` | Verifies C05 route/evidence-boundary output still runs. | `VERDICT: PARTIAL` |
| Video/control probe | `.build/debug/open-lola video-control-degrade-matrix` | Verifies C07 video/control degradation output still runs. | `VERDICT: PARTIAL` |
| App shell surface probe | `.build/debug/open-lola native-app-shell-surface-probe` | Verifies C11 SwiftUI surface contract, read-only app shell ownership, and launch-probe blocker output still runs. | `VERDICT: PARTIAL` |

## Candidate Archive Matrix

Use the export script to stage a source candidate before inspection:

```bash
bash scripts/export-release-candidate.sh /path/to/output-parent
```

The export script runs:

```bash
OPEN_LOLA_RELEASE_CANDIDATE=/path/to/release-candidate bash scripts/verify-release-hygiene.sh
```

Expected result: `VERDICT: PASS` for the staging tool and hygiene scan. Product
readiness still remains `VERDICT: PARTIAL` until manual signing, notarization,
clean-Mac, hardware, and benchmark evidence exists.

## CI Parity

`.github/workflows/release-readiness.yml` mirrors local verification by running
only:

```bash
bash scripts/verify-release-readiness.sh
```

CI may install `shellcheck` when the hosted macOS runner does not provide it.
That is a tool bootstrap step, not a separate verification contract.

## Non-Publishing Rule

C10/C12 CI must not upload or publish:

- `.build/`,
- `win-compiled/`,
- raw `reverse-engineering/`,
- unreviewed `docs/review/`,
- app, package, disk image, debug symbol, coverage, or build-cache output.

The workflow therefore has no artifact upload, Pages upload, release creation,
signing, notarization, or package publication step.

## Manual Gates

The following release claims remain manual until real infrastructure exists:

- Developer ID identity,
- hardened runtime entitlements,
- notarization,
- Gatekeeper acceptance,
- clean-Mac install and launch,
- RME/MADI hardware evidence,
- Blackmagic/ATEM/lighting hardware evidence,
- measured route and benchmark evidence.

The expected product readiness verdict remains `VERDICT: PARTIAL` until those
manual gates are satisfied with real evidence.

## Resume Here

C10 local/CI parity tooling, C12 release artifact hygiene, GOAL.md codewise
closure, and source candidate staging are implemented. Do not add publishing,
signing, or artifact upload steps until the release manifest, license/notices,
candidate hygiene scan, and manual evidence gates are complete.

VERDICT: PARTIAL
