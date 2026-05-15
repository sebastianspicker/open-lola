# Evidence And Compliance Companion

Date: 2026-05-10
Status: active domain companion for documentation topology, deprecated archive, and release boundary
Verdict: PARTIAL

Canonical status lives in
[../IMPLEMENTATION_COMPANION.md](../IMPLEMENTATION_COMPANION.md). This file
collects the current documentation topology and evidence-boundary policy after
the 2026-05-05 consolidation.

## Active Documentation Topology

| Lane | Role |
|---|---|
| [../../docs/current-state.md](../../docs/current-state.md) | Current public-safe project state and blocker posture. |
| [../../README.md](../../README.md) | Repository entry point and current public-facing summary. |
| [../../docs/roadmap/README.md](../../docs/roadmap/README.md) | Public-safe roadmap router. |
| [../IMPLEMENTATION_COMPANION.md](../IMPLEMENTATION_COMPANION.md) | Single active implementation source of truth. |
| [README.md](README.md) plus four companion files | Domain detail subordinate to the canonical handoff. |
| [../../docs/](../../docs/README.md) | Publication-safe public documentation. |
| [../../research/](../../research/RESEARCH_COMPANION_2026.md) | Internal research companion set and evidence matrix. |
| [../../reverse-engineering/](../../reverse-engineering/README.md) | Internal static reverse-engineering evidence. |
| [../../archive/2026-05-05-doc-consolidation/](../../archive/2026-05-05-doc-consolidation/) | Superseded documentation and review snapshots. |
| [../../archive/2026-05-05-workflow-consolidation/](../../archive/2026-05-05-workflow-consolidation/) | Superseded workflow docs and internal generated RE evidence moved after this pass. |
| [../../archive/2026-05-10-superseded-plans-audits-goals/](../../archive/2026-05-10-superseded-plans-audits-goals/) | Superseded plan, audit, goal, and generated-output documents; do not use as active authority. |
| [../../archive/2026-05-11-doc-cleanup/](../../archive/2026-05-11-doc-cleanup/) | Superseded active-tree plan/remediation/milestone docs; do not use as active authority. |

## Release Boundary

- Public candidates come from the allowlist in
  [../../docs/compliance/release-manifest.md](../../docs/compliance/release-manifest.md).
- `archive/**`, `re_out/**`, `win-compiled/**`, `reverse-engineering/**`, raw
  root research, and unredacted report evidence are excluded by default.
- Source, tests, public docs, and verification scripts remain original
  open-lola work and must stay clean-room defensible.
- Compatibility, packet, benchmark, and release claims must cite public APIs,
  public standards, original tests, or measured reports, not proprietary or raw
  static evidence.

## Source Test Doc Crosswalk

| Surface | Active documentation |
|---|---|
| CLI command inventory | This companion plus generated CLI output and source tests. |
| Source ownership inventory | This companion and the domain companion matching the source area. |
| Report schemas and evidence classes | This companion plus release and benchmark docs. |
| External connector reports | [audio-network.md](audio-network.md), source tests, TX/RX session reports, fixture matrix, and schema inventory. |
| Realtime audio path inventory | [audio-network.md](audio-network.md). |
| Network route command matrix | [audio-network.md](audio-network.md). |
| Video/control degrade matrix | [video-control.md](video-control.md). |
| Release artifact hygiene | [../../docs/compliance/release-manifest.md](../../docs/compliance/release-manifest.md). |
| Verification matrix | [../../docs/testing/README.md](../../docs/testing/README.md). |

## Archive Rules

1. Move superseded documentation into the dated `archive/` lane that matches
   the cleanup pass without deleting it.
2. Keep active docs free of links into archived snapshots unless the link is
   explicitly labeled as archive context.
3. Do not chase current status inside archived snapshots.
4. Do not include `archive/**` in source release candidates.
5. Treat regenerated root `re_out/` output as local generated analysis and move
   or discard it before documentation/release verification.
5. Update `scripts/verify-docs.sh` and the Python verifier whenever the active
   topology changes.

## Resume here

Resume here: before public release, rerun docs, release hygiene, source export,
fixture provenance, public documentation review, implementation audit, license,
notices, and final review packet checks against the exact release candidate.

VERDICT: PARTIAL
