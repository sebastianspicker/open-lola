# Documentation Restructure Proposal

Date: 2026-05-04  
Status: proposal only  
Scope: no documentation files moved  
Verdict: PARTIAL

## Objective

Keep the existing public/internal boundary while making navigation more
predictable. The proposed structure below is a future target, not an action
taken in this pass.

## Proposed Structure

```text
docs/
  architecture/
  reverse-engineering/
  compliance/
  research/
  benchmarks/
  milestones/
  testing/
  development/
  operations/
  diagrams/
  review/
  historical/
```

## Folder Proposals

| Proposed folder | Purpose | What belongs there | What does not belong there | Files that should be moved there later | Files that need to be created |
|---|---|---|---|---|---|
| `docs/architecture/` | Public-safe system architecture. | Public API/standard-based audio, network, video, timing, buffering, protocol, and control design docs. | Raw RE strings, internal addresses, generated Ghidra output, vendor binaries. | Already contains most public architecture docs. Consider only adding approved diagrams/indexes. | `source-module-crosswalk.md`, if public-safe. |
| `docs/compliance/reverse-engineering-boundary.md/` | Optional public-safe RE summaries only, if needed. | Sanitized compatibility summaries with no raw evidence. | Current internal `reverse-engineering/` evidence packages, hashes, strings, raw package details. | None until compliance approves. | `README.md` explaining why raw RE remains outside public docs. |
| `docs/compliance/` | Public/internal boundary, licenses, notices, release readiness, clean-room rules. | License decisions, release manifest, clean-room rules, fixture provenance, public-doc review registers. | Runtime implementation plans and raw RE evidence. | Already contains active compliance material. | `review-artifact-boundary.md` for `docs/review/` policy. |
| `docs/background/` | Publication-safe research synthesis. | Sanitized research summaries, claim labels, validation methodology, redaction notes. | Raw reverse-engineering evidence and generated data. | Already contains public-safe research docs. | `research-to-source-crosswalk.md`, if public-safe. |
| `docs/benchmarks/` | Public benchmark methodology and accepted measured result indexes. | Methodology, benchmark schema, accepted measured reports after review. | Synthetic-only outputs that could be mistaken for measured PASS. | Existing benchmark docs stay. | `measured-results-ledger.md` after real reports exist. |
| `docs/milestones/` | Public milestone docs that are active and release-safe. | Public release-hardening/milestone status approved for publication. | Internal `mac-port/` handoff reports and raw source-level evidence. | Existing `M14-release-hardening.md` stays. | Only add active public milestones after compliance review. |
| `docs/testing/` | Public-safe testing and verification guide. | Commands, local gates, fixture policy, test matrix, coverage expectations. | Internal generated evidence or private hardware logs. | Potentially summaries from `scripts/README.md` and `mac-port/VALIDATION_CHECKLIST.md` after sanitization. | `README.md`, `verification-matrix.md`, `fixture-index.md`. |
| `docs/development/` | Maintainer-facing but source-oriented development docs. | Source layout, module ownership, CLI command map, contribution workflow. | Public release claims and raw RE artifacts. | Future promotion of `docs/review/source-ownership-inventory.md` after publication-boundary review. | `source-layout.md`, `cli-command-index.md`, `module-owners.md`. |
| `docs/operations/` | Runtime operation and field validation procedures. | Hardware setup, route validation, packaging field-test procedure, clean-Mac checklist. | Legal decisions and raw RE. | Sanitized pieces from `mac-port/` only after review. | `field-validation.md`, `clean-mac-checklist.md`. |
| `docs/diagrams/` | Central public-safe diagram index. | Mermaid architecture diagrams that do not expose internal evidence. | Generated Ghidra diagrams unless sanitized. | Selected diagrams from `docs/architecture/` or this review after approval. | `README.md`, `architecture-overview.md`. |
| `docs/review/` | Internal repository audit and planning artifacts. | Functional maps, classification indexes, roadmaps, risk registers. | Release-ready public docs unless explicitly promoted. | Current review files remain here for now. | `review-artifact-boundary.md` or release-manifest entry. |
| `docs/historical/` | Superseded public-safe snapshots. | Frozen previous public roadmaps and plans. | Active roadmap or implementation handoff material. | Already contains public historical snapshots. | `archive-policy.md`. |

## Current External Documentation Lanes

The current repository also has important docs outside `docs/`:

| Current folder | Current role | Proposed long-term treatment |
|---|---|---|
| `mac-port/` | Internal implementation handoff, milestones, reports, templates, risks, open questions. | Keep outside public docs unless selected content is sanitized into `docs/development/`, `docs/testing/`, or `docs/operations/`. |
| `research/` | Current and deprecated research companion set. | Keep as internal/review research input; publish only sanitized summaries in `docs/background/`. |
| `reverse-engineering/` | Internal static evidence lane. | Keep outside public docs by default. |
| `win-compiled/` | Static Windows artifact corpus. | Never move into `docs/`; treat as evidence input only. |

## Proposed Navigation Changes

No navigation edits were made, but the next docs pass could:

1. Add a `docs/review` boundary note to `docs/compliance/release-manifest.md`.
2. Create `docs/testing/README.md` as a public-safe verification entry point.
3. Promote or mirror `docs/review/source-ownership-inventory.md` as
   `docs/development/source-module-crosswalk.md` after review publication
   policy is decided.
4. Add an archive policy to `docs/historical/README.md` and `mac-port/historical/README.md`.
5. Keep raw reverse-engineering and Windows corpus links out of public docs.

## Rationale

The current structure is not broken; it is dense. The main improvement is not
moving files for aesthetics. It is making audience boundaries explicit:

- `docs/`: public-safe or explicitly classified review material.
- `mac-port/`: internal implementation handoff.
- `research/`: research input.
- `reverse-engineering/`: internal static evidence.
- `win-compiled/`: external/vendor evidence corpus.

VERDICT: PARTIAL
