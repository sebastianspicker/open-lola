# Workflow Documentation Consolidation Plan

Date: 2026-05-05
Status: executed plan for documentation/workflow consolidation
Verdict: PASS

## Assumptions

- `README.md` remains the public entry point.
- `docs/README.md` remains the publication-safe documentation index.
- `mac-port/README.md` remains the internal Mac-port router.
- `mac-port/IMPLEMENTATION_COMPANION.md` remains the single active
  implementation handoff and workflow source.
- Runtime source, tests, `Package.swift`, and release scripts must not change
  for this docs-only consolidation unless a docs verifier requires a path
  update.
- Raw reverse-engineering evidence remains internal and must not be linked as a
  public implementation authority.
- This checkout is not a Git worktree; evidence is filesystem- and
  command-based.

## Classification Rules

| Classification | Rule |
|---|---|
| Active | Current entry point, public-safe reference, active compliance register, active internal research/RE companion, or verifier/source-dependent doc. |
| Superseded | Replaced by `README.md`, `docs/README.md`, `mac-port/README.md`, `mac-port/IMPLEMENTATION_COMPANION.md`, or current compliance docs. |
| Historical/reference | Archived snapshot retained for traceability, not active status. |
| Internal/private-boundary | Internal research, reverse-engineering evidence, or generated static-analysis evidence not suitable for public release. |
| Duplicate | Same workflow role as an active entry point. Move to superseded archive unless source or verifier dependencies require keeping it active. |
| Generated/residue | Generated local output or ignored junk. Delete only if already ignored and unrelated to durable docs. |

## Move Plan

| Source | Destination | Reason | Active replacement |
|---|---|---|---|
| `MAC_PORT_PLAN.md` | `archive/2026-05-05-workflow-consolidation/superseded/root/MAC_PORT_PLAN.md` | Root roadmap router duplicates `README.md`, `docs/roadmap/`, and the canonical implementation handoff. | `README.md`, `docs/roadmap/README.md`, `mac-port/IMPLEMENTATION_COMPANION.md` |
| `SOURCE_AUDIT.md` | `archive/2026-05-05-workflow-consolidation/superseded/root/SOURCE_AUDIT.md` | Source-folder restructuring audit is complete and no longer an active workflow entry point. | `mac-port/IMPLEMENTATION_COMPANION.md`, `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift` |
| `mac-port/WORKFLOW.md` | `archive/2026-05-05-workflow-consolidation/superseded/mac-port/WORKFLOW.md` | Workflow duplicate; active workflow now lives in the implementation companion and README routers. | `mac-port/IMPLEMENTATION_COMPANION.md`, `mac-port/README.md` |
| `docs/compliance/milestones/` | `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/` | Compliance milestone snapshots are replaced by current compliance registers and final review packet. | `docs/compliance/README.md`, `docs/compliance/final-review-packet.md`, `docs/compliance/public-internal-boundary.md` |
| `docs/compliance/release-readiness-checklist-run.md` | `archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/release-readiness-checklist-run.md` | Dry-run checklist snapshot is replaced by active release readiness and hygiene gates. | `docs/testing/verification-matrix.md`, `docs/compliance/release-manifest.md`, `docs/compliance/release-artifact-hygiene.md` |
| `reverse-engineering/evidence-packages/` | `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/` | Generated static-analysis evidence is internal and should not sit in the active workflow tree. | `reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md`, `docs/compliance/reverse-engineering-boundary.md` |

## Required Link Updates

- Remove `MAC_PORT_PLAN.md` from public reading order and route users to
  `docs/roadmap/README.md` and `mac-port/IMPLEMENTATION_COMPANION.md`.
- Remove `mac-port/WORKFLOW.md` from `mac-port/README.md`.
- Replace active links to compliance milestone snapshots with links to this
  archive lane or current compliance registers.
- Replace active links to `reverse-engineering/evidence-packages/` with links
  to the internal archive copy.
- Preserve release hygiene exclusion text for `reverse-engineering/**` and
  `reverse-engineering/evidence-packages/**`; those are release boundary
  patterns, not active file assertions.

## Verification Plan

```bash
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
bash scripts/verify-release-hygiene.sh
```

Surface probes:

```bash
test -f README.md
test -f docs/README.md
test -f mac-port/README.md
test -f mac-port/IMPLEMENTATION_COMPANION.md
test -f docs/testing/verification-matrix.md
test -f docs/compliance/public-internal-boundary.md
test -f archive/2026-05-05-workflow-consolidation/MANIFEST.md
```

## Wording And Folder-Structure Addendum

The stricter follow-up pass also reviews every non-archived Markdown file for
current wording, duplicate information, public/internal path clarity, and
reader-facing metadata. Public-safe research summaries now live under
`docs/background/`, and the former public reverse-engineering boundary moved to
`docs/compliance/reverse-engineering-boundary.md` so the repository no longer
has duplicate public/internal `research` or `reverse-engineering` folder names.

The detailed evidence is recorded in
[WORDING_AND_STRUCTURE_AUDIT.md](WORDING_AND_STRUCTURE_AUDIT.md).

VERDICT: PASS
