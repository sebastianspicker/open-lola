# N03 Release Manifest Policy

Date: 2026-05-04  
Status: companion updated after release-manifest C12 policy implementation  
Priority: P0  
Verdict: PARTIAL

## Objective

Record how review docs, generated output, Windows artifacts, and internal
reverse-engineering evidence are treated during release/export work.

## Affected Paths

- `docs/compliance/release-manifest.md`
- `docs/compliance/public-internal-boundary.md`
- `docs/review/release-artifact-hygiene.md`
- `scripts/verify-release-hygiene.sh`
- `docs/review/`
- `.build/`
- `win-compiled/`
- `reverse-engineering/`

## Required Policy Decisions

| Surface | Default policy | Reason |
|---|---|---|
| `docs/review/` | internal-only until reviewed | Audit notes include internal risks and cleanup candidates. |
| `.build/` | exclude | Generated local build output. |
| `win-compiled/` | exclude | External/vendor Windows binary corpus. |
| `reverse-engineering/` | internal-only | Static evidence and generated analysis details. |
| `research/` | review before publication | Research inputs require sanitized public summaries. |

## Implemented C12 Policy

`docs/compliance/release-manifest.md` now records the C12 artifact hygiene rule.
The executable gate is:

```bash
bash scripts/verify-release-hygiene.sh
```

When a staged release candidate exists, scan it with:

```bash
OPEN_LOLA_RELEASE_CANDIDATE=/path/to/release-candidate bash scripts/verify-release-hygiene.sh
```

## Deliverables

- Release manifest records inclusion/exclusion rules.
- Public/internal boundary docs point to the chosen review policy.
- No public docs link to raw Windows binaries or generated RE evidence.

## Acceptance Criteria

- `bash scripts/verify-docs.sh` passes.
- `bash scripts/verify-release-hygiene.sh` passes.
- The release boundary is readable without interpreting chat history.
- `docs/review/` status is unambiguous.

## Resume Here

After policy is recorded, continue with
[N04_LICENSE_NOTICES_CLOSURE.md](N04_LICENSE_NOTICES_CLOSURE.md) or an export
script that calls the C12 candidate scan.

VERDICT: PARTIAL
