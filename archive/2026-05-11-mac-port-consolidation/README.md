# Mac Port Consolidation Archive

Date: 2026-05-11
Status: archived superseded Mac-port handoff files
Verdict: PARTIAL

This lane preserves the former top-level `mac-port/` documentation tree after
the active implementation handoff moved to `docs/mac-port/`.

## Why Archived

The former tree mixed routers, status, implementation plan fragments, field
commands, SOTA routing, risk, templates, and four domain companions. Several
files duplicated the active public docs under `docs/roadmap/`,
`docs/source-contracts/`, `docs/testing/`, and `docs/compliance/`, or still
pointed to the old top-level `mac-port` location.

## Contents

| Path | Disposition |
|---|---|
| `docs/mac-port/README.md` | Superseded router. Replaced by `docs/mac-port/README.md` in the active tree. |
| `docs/mac-port/IMPLEMENTATION_COMPANION.md` | Superseded oversized mixed handoff. Current progress and missing evidence are consolidated in active `docs/mac-port/README.md`. |
| `docs/mac-port/implementation-companions/` | Superseded domain companion fan-out. Active status is consolidated in `docs/mac-port/README.md`, with public details under `docs/architecture/` and `docs/source-contracts/`. |
| `docs/mac-port/templates/` | Superseded templates with old path assumptions. |

Do not edit this archive as current status. Use it only to trace the
2026-05-11 consolidation.

VERDICT: PARTIAL
