# M09 Release-Readiness Checklist Run

Date: 2026-05-04
Milestone: [M09 Prepare Release-Readiness Compliance Checklist](milestones/M09-release-checklist.md)
Status: dry-run release checklist executed, final release blocked
Review type: engineering release-readiness review, not legal advice
Verdict: PARTIAL

## Purpose

This file is the M09 execution record for the release-readiness checklist. It
turns the reusable checklist into a concrete dry-run release review that can be
repeated during M10 against the exact release candidate.

This is not a public release approval. The archive built from this process is a
review artifact only.

## Release Candidate Profile

| Field | Value |
|---|---|
| Profile ID | `m09-public-source-review-candidate` |
| Archive path | `/private/tmp/open-lola-m09-release-candidate.tar.gz` |
| Archive size | 528K |
| Archive entries | 321 |
| Archive intent | Dry-run source/docs review artifact. |
| Source state | Filesystem checkout; not a Git worktree in this environment. |
| Include posture | Public docs plus compliance review packet. |
| Exclude posture | Internal evidence, binaries, raw reports, generated outputs, and unclear fixtures excluded. |
| Final release posture | Blocked until M10 reviewer signoff and open legal/license/provenance questions are closed. |

## Archive Command

Run from the repository root:

```bash
tar -czf /private/tmp/open-lola-m09-release-candidate.tar.gz \
  --exclude ".DS_Store" \
  --exclude "*/.DS_Store" \
  --exclude "Tests/OpenLolaCoreTests/Fixtures" \
  .gitignore \
  Package.swift \
  LICENSE \
  THIRD_PARTY_NOTICES.md \
  README.md \
  Sources \
  Tests \
  scripts \
  docs/README.md \
  docs/current-state.md \
  docs/roadmap \
  docs/architecture \
  docs/benchmarks \
  docs/source-contracts \
  docs/background \
  docs/milestones/M14-release-hardening.md \
  docs/compliance
```

M09 includes `docs/compliance/**` as a review packet because the root README
links to compliance governance files and because the release is still blocked.
If M10 decides compliance docs are internal-only, rewrite public README links and
exclude `docs/compliance/**` from the final public archive.

## Archive Content Rules

The archive must not contain:

- `win-compiled/**`;
- `reverse-engineering/**`;
- root `research/RESEARCH_*.md`;
- `research/deprecated-research/**`;
- `mac-port/**`;
- `Tests/OpenLolaCoreTests/Fixtures/**` until CQ019 is closed;
- `.build/**`, `.swiftpm/**`, `DerivedData/**`, or package/app artifacts;
- `.DS_Store` or other generated metadata;
- packet captures, media captures, screenshots, private endpoint data, or raw
  generated evidence.

## Checklist Execution

| Area | M09 result | Notes |
|---|---|---|
| Release manifest defined | PASS | `release-manifest.md` defines include, review, exclude, and M09 archive recipe. |
| Public release is allowlist-based | PASS | Archive command lists explicit roots and excludes unclear fixtures. |
| Root `LICENSE` present | BLOCKED | Present but still an M05 pending placeholder, not a final license grant. |
| Root `THIRD_PARTY_NOTICES.md` present | BLOCKED | Present but still an M07 draft, not final release notices. |
| Public docs review current | PASS | M06 register remains the public-doc classification source. |
| Implementation audit current | PASS | M08 register exists and must be rerun for M10. |
| Fixture provenance | BLOCKED | CQ019 is open; fixtures are excluded from the M09 dry-run archive. |
| Optional SDK redistribution | PASS for dry run | No SDK files are included; future SDK adapters remain gated. |
| Compatibility claims | PASS for dry run | Compatibility remains deferred/default-off; no compatibility parser or packet code is promoted. |
| Hardware/signing/clean-Mac evidence | BLOCKED | M15 signing, notarization, Gatekeeper, and clean-Mac evidence are still unavailable. |
| Maintainer/legal signoff | BLOCKED | Required before any public release or package publication. |

## Archive Inspection Result

| Check | Result | Notes |
|---|---|---|
| Archive built | PASS | `/private/tmp/open-lola-m09-release-candidate.tar.gz` was created from the M09 allowlist command. |
| Entry count | PASS | `tar -tzf /private/tmp/open-lola-m09-release-candidate.tar.gz \| wc -l` returned 321 entries. |
| Forbidden path scan | PASS | No archive entries matched internal evidence, `mac-port`, fixture resources, build outputs, captures, packages, or generated metadata. |
| Included source/docs check | PASS | Archive contains `Sources/**`, `Tests/**/*.swift`, curated public docs, and `docs/compliance/**` as a review packet. |
| Fixture exclusion | PASS for dry run | `Tests/OpenLolaCoreTests/Fixtures/**` is absent because CQ019 remains open. |
| Final publication approval | BLOCKED | Dry-run archive still includes placeholder license and draft notices. |

## Verification Record

| Command | Result | Notes |
|---|---|---|
| `bash scripts/verify-docs.sh` | PASS | Documentation contract passed. |
| `shellcheck scripts/verify-docs.sh` | PASS | Shell verifier remains clean. |
| `find . -name .DS_Store -type f \| sort` | PASS | No generated macOS metadata remains in the checkout. |
| M08 internal-path scan | PASS with classified match | Only the intentional `ReleaseHardeningTests.swift` negative test references an internal evidence path. |
| Optional SDK file scan | PASS | No SDK headers, libraries, frameworks, or Desktop Video SDK files found. |
| M09 archive build | PASS | Built in `/private/tmp`, not inside the repo. |
| M09 archive forbidden-content scan | PASS | No forbidden paths matched. |
| `swift build` | PASS | Ran unsandboxed because SwiftPM manifest compilation fails under sandbox-exec on this host. |
| `swift test` | PASS | 644 tests passed. |
| `.build/debug/open-lola release-hardening-synthetic-smoke` | PASS | CLI smoke emitted `VERDICT: PARTIAL`. |
| `.build/debug/open-lola release-hardening-run --output /private/tmp/open-lola-m09-release-hardening.json` | PASS | Report generated with three claims and four remaining partial gates. |
| `.build/debug/open-lola validate-release-hardening-report /private/tmp/open-lola-m09-release-hardening.json` | PASS | Generated report validated and emitted `VERDICT: PARTIAL`. |

## Blockers Before PASS

| Blocker | Source | Required closure |
|---|---|---|
| Final source license not selected | CQ001, `LICENSE` | Replace placeholder with final license text. |
| Documentation license not selected | CQ002 | Record final docs license in release packet. |
| Third-party notices not final | CQ005, M07 | Finalize notices against exact release contents. |
| Apple SDK/distribution agreement state open | CQ006 | Record distribution account/agreement posture. |
| Fixture provenance open | CQ014, CQ019 | Sign off fixture provenance or keep fixtures excluded. |
| Compliance-doc public status open | CQ017 | Decide whether `docs/compliance/**` is public governance or internal review packet. |
| Final export command needs M10 signoff | CQ018 | Approve or revise the M09 archive recipe. |
| Clean-room reviewer unnamed | CQ024 | Record reviewer and signoff. |
| Packaging evidence incomplete | M15 | Provide signing identity, notarization readiness, Gatekeeper, and clean-Mac run evidence. |

## Resume Here

For M10, rebuild the archive from this recipe or a reviewed successor, inspect the
archive contents, attach the command output to the review packet, and do not
promote beyond `VERDICT: PARTIAL` until every blocker above is closed.

VERDICT: PARTIAL
