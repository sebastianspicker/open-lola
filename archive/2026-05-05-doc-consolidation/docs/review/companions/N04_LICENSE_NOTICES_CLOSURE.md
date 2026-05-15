# N04 License Notices Closure

Date: 2026-05-04  
Status: next action companion  
Priority: P0  
Verdict: PARTIAL

## Objective

Close the root license and third-party notice blockers before any public source
or binary release.

## Affected Paths

- `LICENSE`
- `THIRD_PARTY_NOTICES.md`
- `docs/compliance/license-decision-record.md`
- `docs/compliance/notices-attribution-register.md`
- `docs/compliance/dependency-license-review.md`
- `docs/compliance/final-review-packet.md`
- `win-compiled/`

## Current Finding

The root license is documented as pending, and the notice file is a draft. The
Windows corpus contains external/vendor binaries, DLLs, installers, and camera
configuration files that need explicit exclusion or legal approval.

## Deliverables

- final source/documentation license decision,
- final notice and attribution posture,
- Windows corpus release exclusion or approved distribution decision,
- updated compliance packet.

## Stop Conditions

Stop if the decision depends on legal interpretation, upstream license terms,
or redistribution of vendor binaries.

## Validation

```bash
bash scripts/verify-docs.sh
```

## Resume Here

After license and notices are closed, continue with
[N06_MEASURED_EVIDENCE_LEDGER.md](N06_MEASURED_EVIDENCE_LEDGER.md) for runtime
claim separation.

VERDICT: PARTIAL
