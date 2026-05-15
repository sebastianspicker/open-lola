# Validation And Test Methodology

Date: 2026-05-03  
Status: publication-safe validation contract  
Scope: claim labels, evidence labels, and publication-safe wording

## Claim Labels

| Label | Definition | Required proof |
|---|---|---|
| `validated` | Confirmed for the stated scope. | Passing test, fixture, timing report, controlled observation, or maintainer-approved interoperability evidence. |
| `strongly supported` | Supported by multiple evidence categories but not fully runtime-confirmed. | Independent evidence categories that agree, plus explicit remaining gap. |
| `inferred` | A reasoned conclusion from architecture or static evidence. | Plausible evidence chain and a named validation path. |
| `hypothesis` | A candidate explanation or design path. | None beyond plausibility; must not drive compatibility claims. |
| `open-lola design decision` | A deliberate project choice. | Decision rationale and validation method for open-lola behavior. |
| `future work` | Not yet complete. | Clear acceptance criteria before the label can change. |

## Safe Evidence Labels

| Evidence label | Publication-safe use |
|---|---|
| runtime observation | Behavior observed during allowed runtime tests. |
| sanitized packet analysis | Packet-level evidence with proprietary payloads, fields, and templates removed. |
| timing measurement | Measured latency, jitter, drift, or buffer behavior. |
| black-box behavior test | Inputs and outputs observed without publishing internal implementation details. |
| public API behavior | Behavior documented or observable through public APIs. |
| controlled interoperability test | Maintainer-approved peer test with publication-safe notes. |
| open-lola implementation test | Test of open-lola-owned code or contracts. |
| fixture-based validation | Test fixture created or sanitized for publication. |
| internal reverse-engineering notes withheld for publication safety | Internal-only evidence summarized without raw detail. |

## Internal-Only Evidence Sentence

If a public claim depends on internal-only evidence, use this exact sentence:

Internal notes are referenced here only as evidence categories; publication
must continue to use the safe labels in this table.

## Validation Rules

- A claim can be `validated` only for the exact tested scope.
- `strongly supported` is not a substitute for peer interoperability.
- `inferred` claims must name what evidence would upgrade them.
- `hypothesis` claims must not appear in compatibility support lists.
- open-lola-owned formats can be fully documented; proprietary legacy grammar
  cannot.
- Synthetic or fixture-derived examples must be clearly identified as such.
- Legacy Compatibility Mode remains `PARTIAL` until runtime, packet, and peer
  evidence cover the claimed behavior.

## Publication Checks

Before release, public docs under `docs/background/` should pass:

- Markdown link check.
- ASCII check.
- Search for private symbols, raw addresses, proprietary message templates,
  binary excerpts, captured packet payloads, hashes, debug-symbol paths, and
  build paths.
- Maintainer review for any compatibility language.

VERDICT: PARTIAL
