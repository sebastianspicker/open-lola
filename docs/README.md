# Public Documentation

Date: 2026-05-11
Status: publication-safe documentation entry point after cleanup
Verdict: PARTIAL

This directory is the publication-safe surface for open-lola. It excludes raw
reverse-engineering evidence, generated static-analysis packages, private
strings, addresses, hashes, proprietary message templates, packet grammar
details, archived review snapshots, and unredacted report notes.

## Document Map

| Document | Purpose |
|---|---|
| [current-state.md](current-state.md) | Publication-safe current project state and evidence gates. |
| [roadmap/README.md](roadmap/README.md) | Sanitized public Mac port roadmap. |
| [architecture/latency-first-architecture.md](architecture/latency-first-architecture.md) | Audio-first architecture entry point. |
| [architecture/](architecture/latency-first-architecture.md) | Public-safe audio, network, video, timing, buffering, protocol, and control design notes. |
| [benchmarks/README.md](benchmarks/README.md) | Public benchmark methodology index. |
| [source-contracts/README.md](source-contracts/README.md) | Condensed active public source-contract summary. |
| [background/README.md](background/README.md) | Publication-safe research summaries. |
| [reverse-engineering/README.md](reverse-engineering/README.md) | Public-safe reverse-engineering boundary, current implementation stage, and file disposition. |
| [compliance/README.md](compliance/README.md) | Condensed compliance, release, clean-room, and public/internal boundary summary. |
| [compliance/release-manifest.md](compliance/release-manifest.md) | Active release allowlist, exclusions, and blockers. |
| [testing/README.md](testing/README.md) | Source verification, CLI probe, and real-world evidence boundary. |
| [diagrams/README.md](diagrams/README.md) | Public-safe diagram index and publication rules. |

## Internal Boundary

Implementation status lives in
[mac-port/README.md](mac-port/README.md).
Research status lives under [background/README.md](background/README.md).
Detailed research ledgers are current planning evidence, but publication claims
were archived under
`../archive/2026-05-11-research-archive/`; publication claims should use
sanitized `docs/background/` material unless the release manifest explicitly
allows selected archived research files.
Internal reverse-engineering evidence lives under
`../private/reverse-engineering/`. Superseded reverse-engineering routers and
stale roadmap files are preserved under
`../archive/2026-05-11-reverse-engineering-consolidation/`. Superseded roadmap,
source-contract, testing, and compliance details are preserved under
`../archive/2026-05-11-doc-condense/`.
Superseded Mac-port handoff files are preserved under
`../archive/2026-05-11-mac-port-consolidation/`.

Public docs may summarize measured, reviewed evidence. They must not link to
raw internal evidence, Windows binaries, packet dumps, private route context, or
archived review notes as implementation authority.

## Resume here

Resume here: update this map only when a public-safe active documentation file
is added, removed, or reclassified. Keep release wording `VERDICT: PARTIAL`
until the release manifest, license, notices, fixture provenance, reviewer
signoff, hardware, benchmark, signing, notarization, Gatekeeper, and clean-Mac
gates close.

VERDICT: PARTIAL
