# N01 Review Boundary Decision

Date: 2026-05-04  
Status: next action companion  
Priority: P1  
Verdict: PARTIAL

## Objective

Decide whether `docs/review/` is internal-only, public-safe, or excluded from
release archives.

## Affected Paths

- `docs/review/`
- `docs/compliance/release-manifest.md`
- `docs/compliance/public-internal-boundary.md`
- `docs/compliance/public-doc-review-register.md`

## Current Finding

`docs/review/` lives under `docs/`, but it discusses internal evidence,
generated artifacts, Windows binaries, compliance blockers, and cleanup risks.
Its current status should be treated as `needs human review`.

## Decision Options

| Option | Meaning | Tradeoff |
|---|---|---|
| Internal-only | Keep review docs for maintainers and exclude from public release. | Safest default, but not public navigation. |
| Public-safe after review | Redact/internalize risky details and link from public docs. | More work and compliance review. |
| Release-excluded archive | Keep locally but exclude from release archives. | Useful for local planning, invisible externally. |

## Recommended Decision

Internal-only until compliance review says otherwise.

## Deliverables

- Human decision recorded.
- Release/public boundary updated if approved.
- No raw reverse-engineering or Windows corpus details promoted to public docs.

## Validation

```bash
bash scripts/verify-docs.sh
```

## Resume Here

After the decision, continue to
[N03_RELEASE_MANIFEST_POLICY.md](N03_RELEASE_MANIFEST_POLICY.md).

VERDICT: PARTIAL
