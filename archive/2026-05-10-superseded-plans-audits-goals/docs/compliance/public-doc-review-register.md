# Public Documentation Review Register

Date: 2026-05-04
Milestone: [M06 Review Public Documentation](../../archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M06-public-doc-review.md)
Status: M06 audit snapshot, pending reviewer signoff
Verdict: PARTIAL

## Purpose

This register freezes the public-documentation review surface for M06. It is an
engineering compliance artifact, not legal advice. It records which documents
can be candidates for a curated public release, which documents need later
maintainer/legal review, and which trees must stay out of public archives unless
a redacted derivative is approved.

## Audit Commands

The M06 audit used repository-local text searches because this checkout is not a
Git worktree in this environment.

```bash
rg -n "\]\((\.\./|\.\./\.\./)?(mac-port/|reverse-engineering/|win-compiled/)|\]\(research/RESEARCH|\]\(\.\./\.\./background/|\]\(\.\./research/RESEARCH" README.md docs/README.md docs/current-state.md docs/roadmap docs/milestones docs/architecture docs/benchmarks docs/background docs/source-contracts docs/compliance
rg -n "drop-in compatible|fully decoded|fully compatible|Windows compatible|Faster than LoLa|packet dump|byte map|payload grammar|decompiled|Ghidra|PDB|license/authentication|activation|serial|secret|credential|private endpoint|/Users/[A-Za-z0-9._-]+|\b(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]{1,3}\.[0-9]{1,3})\b" README.md archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md docs mac-port
```

## Audit Result

| Check | Result | Action |
|---|---|---|
| Direct links from curated public docs to `reverse-engineering/**`, `win-compiled/**`, root `research/RESEARCH_*.md`, or `mac-port/**` | No matches in the curated public surface. | Keep the M02 link boundary. |
| Raw RE / packet / proprietary-detail wording in curated public docs | Matches are policy wording, clean-room prohibitions, or public source-contract terminology. | Keep reviewed wording; do not convert policy examples into implementation detail. |
| Private host, route, endpoint, or operator data | Private/demo addresses were present in `mac-port/reports/**`, not in the curated public docs. | Redacted report examples to TEST-NET documentation addresses, archived superseded report snapshots, and keep report trees review-only by default. |
| Unsupported compatibility or performance claims | Claims remain `PARTIAL` unless backed by measured evidence. | Keep release PASS blocked. |

## Public Release Candidate Docs

These files are public-release candidates only after final license/notices,
fixture provenance, M08 implementation audit, and M10 reviewer signoff.

| Path | M06 classification | Required release action |
|---|---|---|
| `README.md` | Publish after final blockers | Root license/notice placeholders still block release. |
| `docs/README.md` | Publish after final blockers | Keep it as the public docs map. |
| `docs/current-state.md` | Publish after final blockers | Keep claims `PARTIAL` until measured evidence exists. |
| `docs/roadmap/README.md` | Publish after final blockers | Use as sanitized public roadmap lane. |
| `docs/roadmap/mac-port-public-roadmap.md` | Publish after final blockers | Keep roadmap claims evidence-bound. |
| `docs/milestones/M14-release-hardening.md` | Publish after final blockers | Public release-hardening source-validation status only. |
| `docs/architecture/apple-silicon-performance.md` | Publish after final blockers | Keep benchmark claims measured/PARTIAL. |
| `docs/architecture/audio-rme-madi.md` | Publish after final blockers | Keep RME driver as user-installed prerequisite. |
| `docs/architecture/audio-routing.md` | Publish after final blockers | Keep routing design original and public-API based. |
| `docs/architecture/av-sync-and-timing.md` | Publish after final blockers | Keep audio-master timing claims source-level until measured. |
| `docs/architecture/benchmark-methodology.md` | Publish after final blockers | Use only sanitized fixture/report examples. |
| `docs/architecture/blackmagic-video-rx-tx.md` | Publish after final blockers | Keep SDK-backed paths optional and license-gated. |
| `docs/architecture/clean-room-design-rules.md` | Publish after final blockers | Keep as public clean-room rules. |
| `docs/architecture/e2e-p2p-session.md` | Publish after final blockers | Keep compatibility claims validation-bound. |
| `docs/architecture/latency-budget.md` | Publish after final blockers | Keep budget as current engineering target. |
| `docs/architecture/latency-first-architecture.md` | Publish after final blockers | Keep audio-first policy and evidence labels. |
| `docs/architecture/latency-profiles.md` | Publish after final blockers | Keep low-buffer PASS guards explicit. |
| `docs/architecture/lighting-control.md` | Publish after final blockers | Keep sACN/Art-Net review gates. |
| `docs/architecture/madi-full-rx-tx.md` | Publish after final blockers | Keep hardware evidence as missing until measured. |
| `docs/architecture/multichannel-audio-routing.md` | Publish after final blockers | Keep metadata public/user-provided. |
| `docs/architecture/multichannel-transport.md` | Publish after final blockers | Keep UDP PCM v2 as original open-lola source contract. |
| `docs/architecture/multiple-video-streams.md` | Publish after final blockers | Keep video degradation before audio-impact policy. |
| `docs/architecture/open-lola-protocol.md` | Publish after final blockers | Keep native protocol separate from legacy packet grammar. |
| `docs/architecture/p2p-networking.md` | Publish after final blockers | Avoid private route data. |
| `docs/architecture/rme-madi-routing.md` | Publish after final blockers | Keep routing metadata optional and user-provided. |
| `docs/architecture/rx-buffering.md` | Publish after final blockers | Keep visible latency-cost wording. |
| `docs/architecture/video-blackmagic-atem.md` | Publish after final blockers | Keep ATEM control read-only until reviewed. |
| `docs/benchmarks/README.md` | Publish after final blockers | Keep benchmark examples fixture-provenance bound. |
| `docs/benchmarks/audio-latency-methodology.md` | Publish after final blockers | Keep measured-run requirements explicit. |
| `docs/benchmarks/e2e-av-benchmark-methodology.md` | Publish after final blockers | Keep E2E claims `PARTIAL` until measured. |
| `docs/source-contracts/README.md` | Publish after final blockers | Keep active source-contract index only. |
| `docs/source-contracts/MXX-rme-matrix-multichannel.md` | Publish after final blockers | Keep original source contract and public metadata boundary. |
| `docs/source-contracts/MXX-rx-buffering.md` | Publish after final blockers | Keep original buffer profile contract. |
| `docs/source-contracts/MXX-ultra-low-buffer-profiles.md` | Publish after final blockers | Keep 16/8-frame gates explicit. |
| `docs/background/README.md` | Publish after final blockers | Keep as curated public research lane. |
| `docs/background/lola-av-architecture.md` | Publish after final blockers | Keep architecture-level summary only. |
| `docs/background/lola-av-tx-rx-model.md` | Publish after final blockers | Keep TX/RX model conceptual and sanitized. |
| `docs/background/lola-latency-analysis.md` | Publish after final blockers | Keep latency claims labeled. |
| `docs/background/lola-networking-model.md` | Publish after final blockers | Keep packet details withheld. |
| `docs/background/open-lola-compatibility-scope.md` | Publish after final blockers | Keep compatibility scope future/validated. |
| `docs/background/open-lola-design-decisions.md` | Publish after final blockers | Keep independent open-lola deltas explicit. |
| `docs/background/open-lola-deviations-and-improvements.md` | Publish after final blockers | Keep independent improvements and validation tasks. |
| `docs/background/publication-redactions.md` | Publish after final blockers | Keep public redaction guide aligned with compliance copy. |
| `docs/background/validation-and-test-methodology.md` | Publish after final blockers | Keep tests original and evidence-labeled. |

## Governance Docs

`docs/compliance/**` is useful review material but remains review-before-public
because it records internal boundaries, unresolved legal questions, and release
blockers. If governance docs are included in a public release, include this
register, [release-manifest.md](release-manifest.md), and
[public-documentation-safety.md](public-documentation-safety.md) together so the
limitations are visible.

## Review-Only Or Excluded Trees

| Path | M06 classification | Required action |
|---|---|---|
| `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md` | Review-only mixed roadmap | Use `docs/roadmap/**` for public release unless a separate export is approved. |
| `docs/historical/**` | Review-only historical snapshots | Exclude from first release unless traceability value justifies a separate review. |
| `mac-port/README.md`, `mac-port/MILESTONE_INDEX.md`, `mac-port/STATUS_INDEX.md`, `mac-port/PROGRESS.md`, `mac-port/VALIDATION_CHECKLIST.md` | Review-only operational handoff | Include only after public wording and claim review. |
| `mac-port/milestones/**` | Review-only implementation milestones | Do not publish as public claims without M08/M10 review. |
| `mac-port/implementation-companions/**` | Review-only implementation companions | Do not publish as public claims without M08/M10 review. |
| `mac-port/reports/**` | Exclude by default | Contains evidence-specific commands, route context, and operator report paths; publish only selected redacted summaries. |
| `mac-port/historical/reports-2026-05-03/**` | Exclude by default | Superseded report snapshots; keep only for traceability. |
| `mac-port/historical/**` | Exclude by default | Historical implementation snapshots may contain stale assumptions. |
| `research/RESEARCH_*.md` | Internal or sanitized-copy only | Copy safe material into `docs/background/**`; do not link root notes publicly. |
| `reverse-engineering/**` | Internal only | Never publish raw static-analysis or compatibility reconstruction detail. |
| `win-compiled/**` | Internal only | Never include Windows binaries or vendor artifacts in public source release. |

## M06 Remediation Record

| File/path | Issue | Risk type | Severity | Action |
|---|---|---|---|---|
| `mac-port/reports/F11_DIRECT_LINK_LOOPBACK_2026-05-03.md` | Planned direct-link examples used private static addresses. | Private route data in review-only report. | Medium | Replaced examples with TEST-NET documentation addresses and kept measured addresses as private-run inputs. |
| `mac-port/historical/reports-2026-05-03/F12_RENDEZVOUS_SERVICE_2026-05-03.md` | LAN-interface run named an active LAN address before remediation and was superseded by direct-traversal/F12 aggregate reports. | Private endpoint disclosure in review-only historical report. | Medium | Replaced with TEST-NET documentation address, documented that measured private LAN address is not retained publicly, and archived the superseded snapshot. |
| `mac-port/historical/reports-2026-05-03/M05_ROUTE_CERTIFICATION_2026-05-02.md` | Earlier M05 route-certification snapshot was superseded by the 2026-05-03 route-comparison workflow. | Stale evidence routing. | Low | Archived the superseded snapshot and kept `mac-port/reports/M05_ROUTE_CERTIFICATION_2026-05-03.md` active. |
| `mac-port/reports/**` | Reports can contain command lines, paths, route labels, and measured context. | Public documentation and privacy boundary. | Medium | Exclude by default from public release; publish selected redacted summaries only. |
| `docs/compliance/**` | Governance docs expose release blockers and internal boundary decisions. | Public process/legal-risk disclosure. | Low | Review before public export; include only as a complete governance packet. |

## Resume Here

Before M10, rerun the audit commands against the exact release manifest. If a
new public doc is added, classify it here before it can enter the public release
allowlist.

VERDICT: PARTIAL
