# Mac Port Roadmap Sanitization

Date: 2026-05-04
Milestone: [M03 Sanitize Mac Port Roadmap](../../archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M03-sanitize-mac-port-roadmap.md)
Status: implemented sanitization snapshot, pending reviewer signoff
Verdict: PARTIAL

## Purpose

This file records the M03 remediation of the Mac-port roadmap publication
posture. It is engineering compliance analysis, not legal advice.

## Roadmap Release Posture

| Path | Decision | Reason |
|---|---|---|
| `docs/roadmap/**` | Public-safe roadmap export after M06/M08 review. | Sanitized and does not link to raw evidence. |
| `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md` | Review-only canonical implementation overview. | Useful handoff, but includes internal evidence links and detailed implementation references. |
| `mac-port/**` | Review-only implementation handoff lane. | Contains internal research links, historical reports, operator notes, and source/status detail. |
| `docs/historical/**` | Review before including. | Superseded snapshots may contain stale claims. |

## Findings And Remediation

| File/path | Issue | Risk type | Severity | Remediation |
|---|---|---|---|---|
| `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md` | Mixed public/internal roadmap with direct internal research and reverse-engineering links. | Public documentation and clean-room boundary. | High | Marked review-only and linked to sanitized public roadmap. |
| `mac-port/README.md` | Canonical inputs include root research and reverse-engineering evidence. | Public release boundary. | High | Marked review-only and linked to sanitized public roadmap. |
| `mac-port/IMPLEMENTATION_COMPANION.md` | Active handoff references internal evidence and could be mistaken for public roadmap. | Public release boundary. | Medium | Added publication/compliance posture and M03 gates. |
| `docs/README.md`, `docs/current-state.md`, `README.md` | No active public roadmap existed after M02 removed direct mixed-roadmap links. | Public documentation usefulness. | Medium | Added `docs/roadmap/**` as the public roadmap lane. |
| `M15`, `F09`, release hardening | License/notice gates were not visible enough in packaging/field closure. | License and attribution. | Medium | Added explicit `LICENSE`, `THIRD_PARTY_NOTICES.md`, SDK redistribution, fixture provenance, and release-manifest gates. |
| Protocol, compatibility, video, lighting, benchmark docs | Clean-room and optional-compatibility gates existed unevenly across roadmap files. | Clean-room implementation discipline. | Medium | Added targeted clean-room/publication gates to active milestone and companion docs. |

## Audit Commands

```bash
rg -n "reverse-engineering|win-compiled|research/RESEARCH|deprecated-research|compatib|faster-than-LoLa|license|notices|Desktop Video|Dante|Art-Net|sACN|packet" archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md mac-port
rg -n "\]\((\.\./|\.\./\.\./)?(mac-port|reverse-engineering|win-compiled)|\]\(research/RESEARCH" README.md docs
```

## Public Export Rule

Public roadmap references must point to
[../roadmap/mac-port-public-roadmap.md](../roadmap/mac-port-public-roadmap.md).
Do not include `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md` or `mac-port/**` in public release artifacts
unless M06/M08/M10 reviewers explicitly approve a curated export.

## Remaining Items

- M06 must still review `docs/roadmap/**` wording before publication.
- M08 must verify that implementation and source comments do not cite raw
  internal evidence as implementation authority.
- M10 must decide whether `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md` and selected `mac-port/**` files
  remain internal forever or get separate curated exports.
- License, notices, SDK redistribution, and fixture provenance remain open
  release blockers.

VERDICT: PARTIAL
