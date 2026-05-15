# Public Documentation Safety

Date: 2026-05-04
Status: M06 public release surface review snapshot
Verdict: PARTIAL

## Review Position

The current curated public docs are written as publication-safe material, but
the repository as a whole is not a publication-safe source bundle. Public
release must be an explicit export boundary, not a raw checkout. The active M06
classification rule is recorded here and in
[release-manifest.md](release-manifest.md); superseded register notes are
archived under
[../../archive/2026-05-10-superseded-plans-audits-goals/](../../archive/2026-05-10-superseded-plans-audits-goals/).

## Public Doc Classification

| Path | Classification | Required action |
|---|---|---|
| `README.md` | Publish after final blockers | License state is explicit, but release remains blocked until the placeholder license is replaced and notices are final. |
| `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md` | Review-only mixed roadmap | Use the sanitized `docs/roadmap/**` export for public release unless a separate curated export is approved. |
| `docs/README.md` | Publish after final blockers | Current boundary language is good; keep it as the public documentation map. |
| `docs/current-state.md` | Publish after final blockers | Avoids raw RE detail and keeps claims PARTIAL. |
| `docs/roadmap/**` | Publish after final blockers | Sanitized public roadmap lane after M03/M06. |
| `docs/architecture/*.md` | Publish after final blockers | M06 text audit found no direct internal evidence links; keep evidence labels present. |
| `docs/benchmarks/*.md` | Publish after final blockers | Keep benchmark fixture provenance and no private host data. |
| `docs/source-contracts/*.md` | Publish after final blockers | Contracts remain original open-lola designs, not legacy packet grammar. |
| `docs/background/*.md` | Publish after final blockers | Curated public summaries; M06 text audit found no raw internal evidence links. |
| `docs/historical/**` | Review-only | Historical public snapshots may contain stale claims; exclude from first release unless traceability value justifies review cost. |
| `docs/compliance/**` | Review before public export | Governance docs may expose internal process, unresolved legal questions, and release blockers. |
| `background/**` | Internal only by default | Research references and source studies need provenance and license review before public export. |
| `reverse-engineering/**` | Internal only | Contains raw or generated static-analysis evidence and compatibility reconstruction. |
| `win-compiled/**` | Internal only | Contains binaries and vendor artifacts with unclear redistribution rights. |
| `mac-port/**` | Review-only or exclude by default | Contains useful roadmap and reports, but report files can contain route, command, hardware, and operator context. |
| `mac-port/reports/**` | Exclude by default | Publish only selected redacted summaries after M06/M10 review. |

## Public-Safe Wording Patterns

Use:

- "internal static analysis notes";
- "legacy low-latency systems suggest";
- "open-lola implements an original native transport";
- "compatibility remains unproven";
- "requires authorized peer captures and measured tests";
- "hardware evidence is missing; verdict remains PARTIAL".

Avoid:

- exact recovered message names;
- exact proprietary ports, offsets, or byte layouts;
- generated function labels;
- binary strings, file hashes, build paths, or private paths;
- activation, serial, license, or host-identity details;
- "drop-in compatible" or "fully decoded".

## Claim Labels

Public claims must use these labels:

- `confirmed`: open-lola test, public standard, public API, or measured report.
- `observed`: internal evidence exists but raw details are withheld.
- `inferred`: reasonable conclusion, not yet measured.
- `hypothesis`: possible design direction.
- `requires validation`: blocked on hardware, peer, standard, license, or
  maintainer review.
- `internal-only`: not suitable for publication.

## Release Export Rule

A public source release should default to:

- include: `Sources/`, `Tests/`, `scripts/`, `Package.swift`, sanitized `docs/`,
  selected `mac-port/` status docs, final `LICENSE`, final
  `THIRD_PARTY_NOTICES.md`;
- exclude: `win-compiled/`, `reverse-engineering/`, generated evidence
  packages, raw packet captures, private host data, and unclear sample data.

## Resume here

Before publication, rerun the documentation and release-manifest checks against
the exact release candidate and attach reviewer signoff.

VERDICT: PARTIAL
