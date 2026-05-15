# Cleanup Candidates

Date: 2026-05-04  
Status: proposed cleanup candidates only  
Scope: no deletion, move, or rename performed  
Verdict: PARTIAL

## Cleanup Policy

Do not delete or move anything from this list without a separate implementation
request and a validation plan. Several candidates are intentionally preserved
as evidence or history.

## Candidate Summary

| Candidate | Current status | Why it is a candidate | Risk if kept | Risk if removed | Recommendation | Priority | Safe to automate |
|---|---|---|---|---|---|---|---|
| `.build/` | generated/needs cleanup | 3919 generated SwiftPM files are present in the filesystem snapshot. | False inventory size, stale binaries, accidental export. | Low if rebuilt; can lose local debug state. | Remove after explicit approval; never publish; C12 candidate scanning already rejects it. | P0 | Yes, with approval. |
| `.build/arm64-apple-macosx/debug/**/*.dSYM` | generated | Debug symbols for local builds. | Large private/debug artifacts in export. | Low if source can be rebuilt. | Delete with `.build/`. | P0 | Yes, with approval. |
| `.build/arm64-apple-macosx/debug/index/` | generated | Swift index store. | Massive noise. | Low. | Delete with `.build/`. | P2 | Yes, with approval. |
| `docs/review/` | new internal audit docs | Useful for planning, but under public docs root. | May be mistaken for publication-safe docs. | Losing current audit map if removed. | Keep internal or move later only after human decision; C12 excludes it from candidates by default. | P1 | No. |
| `research/deprecated-research/` | stale/archive | Superseded research surveys and dossier. | Readers may cite outdated claims. | Loss of research provenance. | Keep, add stronger archive manifest. | P3 | No. |
| `reverse-engineering/deprecated-reverse-engineering/` | stale/internal archive | Superseded detailed slice reports. | Stale evidence may be mistaken for current source of truth. | Loss of address-level traceability. | Keep as internal archive; freeze primary entry to current RE docs. | P3 | No. |
| `docs/historical/` | stale/public archive | Superseded public roadmap and implementation-plan snapshots. | Duplicate milestone narratives. | Loss of public traceability. | Keep, but exclude from active planning. | P3 | No. |
| `mac-port/historical/` | stale/internal archive | Superseded handoff reports/status companions. | Duplicate implementation state. | Loss of resume/history evidence. | Keep, add archive status and avoid active links except indexes. | P3 | No. |
| `reverse-engineering/evidence-packages/folder-analysis-20260503-1747/` | active/generated/internal | Generated static inventory, Ghidra summaries, data, and tools. | Public contamination and stale generated data. | Loss of reproducible evidence package. | Keep internal; add generated-package manifest/retention rule. | P2 | No. |
| `win-compiled/1-5/` | external/vendor/internal | Legacy Windows v1.5 artifacts for lineage comparison. | License/export risk and storage weight. | Loss of version-delta evidence. | Preserve unless a separate legal/storage decision says otherwise. | P1 | No. |
| `win-compiled/2-0/` | external/vendor/internal | Main Windows v2.0 evidence corpus. | High publication/license risk. | Loss of canonical static evidence input. | Preserve internal-only; never include in public release by default. | P0 | No. |
| `win-compiled/**/XimeaSetup/XIMEA_API_Installer.exe` | external/vendor installer | Large vendor installer. | License/export risk. | Loss of corpus completeness. | Preserve internal-only; record exclusion policy. | P0 | No. |
| `win-compiled/**/WinpcapSetup/WinPcap_4_1_3.exe` | external/vendor installer | Vendor installer. | License/export risk. | Loss of network evidence context. | Preserve internal-only; record exclusion policy. | P0 | No. |

## Duplicate Or Stale Material

| Area | Duplicate/stale pattern | Active source of truth | Recommendation |
|---|---|---|---|
| Public roadmap snapshots | `docs/historical/public-m01-m14-*` duplicates older milestone plans. | `docs/roadmap/`, `docs/current-state.md`, `README.md`. | Keep as archive; do not edit for active planning. |
| Mac-port status companions | `mac-port/historical/implementation-companions-2026-05-03/status/*` duplicates consolidated progress. | `mac-port/IMPLEMENTATION_COMPANION.md`, `mac-port/PROGRESS.md`, `mac-port/STATUS_INDEX.md`. | Keep as historical, active work resumes from consolidated companion. |
| Reverse-engineering slice reports | `reverse-engineering/deprecated-reverse-engineering/*` overlaps canonical 2026 RE docs. | `reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md`, evidence matrix. | Preserve for traceability; use current companion first. |
| Research surveys | `research/deprecated-research/*` overlaps current research companion set. | `research/RESEARCH_COMPANION_2026.md`, evidence matrix. | Preserve as deprecated; do not use as current roadmap without revalidation. |

## Files To Promote Or Index

| Candidate | Current location | Proposed action | Rationale | Priority |
|---|---|---|---|---|
| Source/test/doc crosswalk | missing | Create under `docs/review/` or `docs/development/` after boundary decision. | Needed before source refactor. | P1 |
| Fixture provenance matrix | partial in `docs/compliance/fixture-provenance.md` | Extend with every active fixture directory and public/internal status. | Fixtures are active validation inputs. | P1 |
| Generated evidence package manifest | missing or implicit in package docs | Add manifest inside evidence package or `reverse-engineering/README.md`. | Distinguishes generated evidence from hand-written findings. | P2 |
| CLI command index | partly in `README.md` usage text | Add a maintained command crosswalk. | CLI surface is large. | P2 |

## Files That Need Follow-Up Analysis

| Path | Reason | Needed decision |
|---|---|---|
| `LICENSE` | Pending placeholder. | Final source/documentation license. |
| `THIRD_PARTY_NOTICES.md` | Draft notices. | Final notice and attribution posture. |
| `docs/review/` | New internal audit under public docs root. | Public-safe, internal-only, or exclude from release. |
| `win-compiled/**` | External/vendor corpus. | Retention and distribution policy. |
| `reverse-engineering/evidence-packages/**/tools/*.py` | RE tooling lives inside generated evidence package. | Keep in package, promote to tools, or archive. |
| `.build/` | Generated output present locally. | Delete now, ignore only, or keep until current build proof is no longer needed. |

## Implemented Hygiene Gate

C12 adds the non-destructive release hygiene gate:

```bash
bash scripts/verify-release-hygiene.sh
```

The gate does not delete cleanup candidates. It fails if a staged release
candidate contains generated output, internal reverse-engineering evidence,
`win-compiled/`, `docs/review/`, package artifacts, debug symbols, local
secrets, captures, logs, or analysis/build metadata.

VERDICT: PARTIAL
