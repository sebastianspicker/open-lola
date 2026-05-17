# 2026-05-17 Docs Flattening Cleanup Archive

Date: 2026-05-17
Status: archived superseded active-doc topology
Verdict: trace evidence only

This archive preserves documentation moved out of the active `docs/` tree while
flattening the live documentation surface to root-level `docs/*.md` files.

The active docs no longer use subfolders. These files are historical source
material only; do not treat them as current implementation authority unless a
future pass rechecks the live source tree and restores a replacement path.

## Contents

| Archived source | Replacement or disposition | Reason |
|---|---|---|
| `docs/architecture/apple-silicon-performance.md` | `docs/current-state.md` | Superseded planning-only performance note; current performance evidence remains in active status and benchmark docs. |
| `docs/architecture/blackmagic-video-rx-tx.md` | `docs/video-blackmagic-atem.md` | Unique source-status points were folded into the active video reference. |
| `docs/architecture/transport-error-handling.md` | `docs/p2p-networking.md` | Error-handling rules were folded into the active transport reference. |
| `docs/background/README.md` | `docs/validation-methodology.md` and `docs/compatibility-scope.md` | Background router duplicated the flat technical references. |
| `docs/background/lola-av-architecture.md` | archived only | Publication background, not active technical reference. |
| `docs/background/lola-av-tx-rx-model.md` | archived only | Publication background, not active technical reference. |
| `docs/background/lola-latency-analysis.md` | archived only | Publication background, not active technical reference. |
| `docs/background/lola-networking-model.md` | archived only | Publication background, not active technical reference. |
| `docs/background/open-lola-design-decisions.md` | archived only | Publication background, not active technical reference. |
| `docs/background/open-lola-deviations-and-improvements.md` | archived only | Publication background, not active technical reference. |
| `docs/background/publication-redactions.md` | `docs/release-manifest.md` and `docs/release-boundary.md` | Release boundary and public/internal policy remain in flat release docs. |
| `docs/benchmarks/README.md` | `docs/benchmark-methodology.md`, `docs/benchmark-audio-latency.md`, `docs/benchmark-e2e-av.md` | Router replaced by flat benchmark references. |
| `docs/diagrams/README.md` | archived only | Diagram index was not needed in the flat technical reference surface. |
| `docs/mac-port/sota-open-question-matrix.md` | `docs/open-questions.md` | Source refresh, probe coverage, and milestone routing were folded into the active open-questions ledger. |
| `docs/roadmap/README.md` | `docs/current-state.md` and `docs/implementation-handoff.md` | Roadmap summary duplicated current-state and active handoff docs. |

VERDICT: ARCHIVED
