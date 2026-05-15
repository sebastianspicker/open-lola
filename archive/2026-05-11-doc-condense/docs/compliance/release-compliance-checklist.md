# Release Compliance Checklist

Date: 2026-05-11
Status: practical contributor and release checklist with current blockers
Verdict: PARTIAL

## Current Blocking Snapshot

Latest local refresh: 2026-05-11.

| Gate | Current evidence | Status |
|---|---|---|
| Open-source release readiness | `/private/tmp/open-lola-open-source-release-readiness-current.json` reports `VERDICT: PARTIAL`, 9 requirements, and 6 blockers. | Blocked by final source license, documentation license, notices, fixture provenance, reviewer signoff, and public release approval. |
| Full goal completion | `/private/tmp/open-lola-goal-completion-audit-current.json` reports `VERDICT: PARTIAL`, 93 mapped items, 77 pass, 16 partial, and 26 blockers. | Blocked by release decisions plus runtime/hardware/signing evidence. |
| Runtime preflight | `/private/tmp/open-lola-goal-runtime-preflight-current.json` reports `VERDICT: PARTIAL`; all 10 runtime deliverables are partial. | Current host lacks visible Core Audio/RME/video/Blackmagic candidates, has denied camera permission, and has no Developer ID Application identity. |

<!-- TODO(human): [Release compliance closure] -> Provide final license choices, fixture provenance, reviewer signoff, public release approval, Developer ID signing/notarization evidence, and clean-Mac field evidence before marking this checklist complete -> [Source-only public release / binary package release / defer release] -->

## Contributor Checklist

- [ ] Do not copy decompiled code.
- [ ] Do not copy proprietary packet layouts.
- [ ] Do not use proprietary symbols in public API names.
- [ ] Do not publish raw binary excerpts.
- [ ] Do not publish license, authentication, activation, serial, or host
      identity behavior.
- [ ] Do not publish secrets, credentials, private endpoints, or venue data.
- [ ] Do not commit vendor SDK files unless redistribution is allowed and
      documented.
- [ ] Do not include unclear sample data.
- [ ] Document dependency licenses and SDK terms.
- [ ] Link every design decision to a clean engineering requirement.
- [ ] Link protocol, packet, session, compatibility, benchmark, and release
      tasks to a `CRQ-*` requirement ID.
- [ ] Keep internal research separate from public implementation.
- [ ] Label public claims by confidence level.
- [ ] Use original tests and fixtures.
- [ ] Record fixture provenance before release or compatibility claims.
- [ ] Keep compatibility mode optional and disabled by default.
- [ ] Complete the compatibility work gate before compatibility parser or
      packet implementation.
- [ ] Keep public release artifacts free of `win-compiled/` and raw generated
      evidence unless explicitly approved.

## Release Checklist

- [ ] Root `LICENSE` exists and is the final selected license, not the M05
      pending placeholder.
- [ ] Root `THIRD_PARTY_NOTICES.md` exists and is finalized against the release
      allowlist, not only the M07 draft.
- [ ] M07 notices and attribution register matches the exact release contents.
- [ ] Notice file does not imply redistribution rights for excluded evidence,
      SDKs, drivers, reports, captures, or binaries.
- [ ] Trademark/no-endorsement posture is reviewed for factual vendor and
      standards references.
- [ ] Public release manifest is defined.
- [ ] `win-compiled/` is excluded or rights are documented.
- [ ] `reverse-engineering/` is excluded or internal-only status is clear.
- [ ] Generated evidence packages are excluded.
- [ ] Public docs contain no raw RE details.
- [ ] Public docs contain no internal evidence links.
- [ ] M06 public-doc review register is current for every release candidate doc.
- [ ] `mac-port/reports/**` is excluded or represented only by selected redacted
      summaries.
- [ ] Public docs contain no private route addresses, hostnames, endpoints,
      operator paths, captures, or venue data.
- [ ] README states current license and evidence boundary.
- [ ] Apple SDK usage review is recorded.
- [ ] Blackmagic SDK status is recorded.
- [ ] RME driver dependency status is recorded.
- [ ] Art-Net/sACN standards and attribution status are recorded.
- [ ] Dante/AoIP proprietary integration status is recorded.
- [ ] Test fixture provenance is recorded.
- [ ] Clean-room requirement ledger is reviewed.
- [ ] M08 implementation audit register is current for the release candidate.
- [ ] Source/test token audit has no unclassified raw RE, binary-derived,
      proprietary, or internal-evidence matches.
- [ ] Native packet/session contracts cite open-lola `CRQ-*` requirements and
      original tests.
- [ ] Compatibility work gate is complete or no compatibility work is included.
- [ ] Optional SDK boundaries are source-only, non-default, and contain no
      vendored SDK headers, libraries, frameworks, or samples.
- [ ] Generated metadata such as `.DS_Store` is absent from the release archive.
- [ ] Benchmark and compatibility claims are PARTIAL unless measured evidence
      exists.
- [ ] Maintainer/legal review packet is complete.

## Verification Checklist

- [ ] `bash scripts/verify-docs.sh`
- [ ] `shellcheck -x scripts/*.sh scripts/lib/*.sh`
- [ ] `swift build`
- [ ] `swift test --no-parallel`
- [ ] release-hardening synthetic smoke
- [ ] CLI surface probe for the release mode
- [ ] manual check of release archive contents

## M09 Checklist Execution

The concrete M09 checklist run is recorded in
[release-readiness-checklist-run.md](../../archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/release-readiness-checklist-run.md).

| Area | M09 status | Release impact |
|---|---|---|
| Release manifest | PASS for dry run | Archive recipe exists; M10 must approve or revise it. |
| License | BLOCKED | Root `LICENSE` is still a pending placeholder. |
| Notices | BLOCKED | Root `THIRD_PARTY_NOTICES.md` is still an M07 draft. |
| Fixture provenance | BLOCKED | Fixtures are excluded from the M09 archive until CQ019 closes. |
| Implementation audit | PASS for dry run | M08 register exists; reviewer signoff remains required. |
| Public docs | PASS for dry run | Curated docs and compliance packet are included for review. |
| Release archive inspection | PASS for dry run | Archive was built under `/private/tmp` and forbidden paths were absent. |
| Hardware/signing/clean-Mac evidence | BLOCKED | M15 remains PARTIAL. |
| Reviewer signoff | BLOCKED | Maintainer/release reviewer signoff remains required. |

## M10 Review Packet

The final review packet is
[final-review-packet.md](final-review-packet.md).

| Area | M10 status | Release impact |
|---|---|---|
| Packet assembly | PASS | M01-M09 artifacts are attached by reference. |
| Final source/docs release decision | BLOCKED | Public release remains blocked until reviewer decisions are recorded. |
| Final binary/package decision | BLOCKED | M15 signing, notarization, Gatekeeper, and clean-Mac evidence remain open. |
| Archive review | PASS for dry run | M10 archive was rebuilt under `/private/tmp`; forbidden paths were absent. |
| Reviewer signoff | BLOCKED | Maintainer, legal/compliance, clean-room, release, and security/privacy signoff pending. |

## Resume here

Resume from the current blocking snapshot at the top of this checklist. The old
M09/M10 dry-run rows remain useful history, but they are not release approval.
Before any source, docs, binary, or package release, close the six
open-source-readiness blockers, the 26 full-goal blockers, and the runtime
preflight blockers recorded in the current `/private/tmp/open-lola-*.json`
reports.

VERDICT: PARTIAL
