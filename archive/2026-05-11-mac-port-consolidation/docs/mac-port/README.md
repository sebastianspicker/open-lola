# Mac Port Documentation

Date: 2026-05-05
Status: review-only implementation handoff router after consolidation
Verdict: PARTIAL

The single active implementation source of truth is
[IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md). This directory is
review-only; public roadmap wording belongs under
[../docs/roadmap/](../docs/roadmap/README.md).

## Active Files

| File | Purpose |
|---|---|
| [IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md) | Canonical progress, evidence gates, risk posture, verification, archive map, and resume state. |
| [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) | Human and venue facts required for hardware, route, standards, lighting, NAT, and distribution gates. |
| [RISK_REGISTER.md](RISK_REGISTER.md) | Active Mac port risk register. |
| [SOTA_2026_OPEN_QUESTION_MATRIX.md](SOTA_2026_OPEN_QUESTION_MATRIX.md) | Research-probe routing for open questions and milestone gates. |
| [implementation-companions/](implementation-companions/README.md) | Four active domain companions subordinate to the canonical handoff. |
| [templates/](templates/SESSION_HANDOFF_TEMPLATE.md) | Session handoff and status templates. |

## Archived Files

Old milestone plans, reports, progress/index files, historical snapshots, and
F01-F12 companions are under
[../archive/2026-05-05-doc-consolidation/mac-port/](../archive/2026-05-05-doc-consolidation/mac-port/).
The superseded workflow duplicate is under
[../archive/2026-05-05-workflow-consolidation/superseded/mac-port/WORKFLOW.md](../archive/2026-05-05-workflow-consolidation/superseded/mac-port/WORKFLOW.md).
Do not edit archived snapshots as active status.

## Verification

```bash
bash scripts/verify-docs.sh
shellcheck -x scripts/*.sh scripts/lib/*.sh
bash scripts/verify-release-hygiene.sh
swift test --no-parallel
```

## Resume here

Resume here: open [IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md),
then the one domain companion matching the current task.

VERDICT: PARTIAL
