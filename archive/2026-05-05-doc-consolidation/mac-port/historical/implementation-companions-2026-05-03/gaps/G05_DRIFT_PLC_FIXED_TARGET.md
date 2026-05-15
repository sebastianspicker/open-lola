# G05 Drift PLC Fixed Target

## LoLa Comparison

LoLa hides network irregularity with very small buffering, but the speed rule is
that the audio deadline cannot move just to conceal errors. The Mac path must
show drift and PLC behavior with the same playout target before and after every
correction or missing-packet event.

## Current Repo State

- Related milestone: [../milestones/M06_DRIFT_AND_SAME_DEADLINE_PLC.md](../milestones/M06_DRIFT_AND_SAME_DEADLINE_PLC.md)
- Live status: [../status/M06_STATUS.md](../status/M06_STATUS.md)
- Existing source validates drift/PLC reports and can generate a fixed-target
  report from a route report.
- G05 now has a fixed-target certification wrapper that composes an accepted
  G04 route certification with an M06 drift/PLC report.
- Missing piece: an accepted physical G04 route, a real 60-minute route run,
  run artifact path, and artifact assessment.

## Implementation Plan

1. Use the accepted G04 route as the only input for the first real drift run.
2. Record sender frame index, receiver playout frame index, sequence number,
   packet age, drift frames, correction events, PLC events, and callback p99/max.
3. Keep correction outside the callback unless a future bounded branch is proven
   and documented.
4. For packet loss, output silence, repeat last good block, or bounded
   substitute inside the already-due block. Never wait for retransmission.
5. Run for at least 3,600 seconds with fixed playout target.
6. Add artifact notes from listening review or explicit operator assessment.

## Acceptance Tests

- `validate-drift-plc-report` accepts the measured report.
- `validate-drift-plc-certification-report` accepts the wrapper that ties the
  measured report to the accepted G04 route certification.
- PASS run duration is at least 3,600 seconds.
- PASS has no underruns, hidden growth, retransmission waits, unbounded
  callback corrections, or playout target changes.
- Artifact assessment is completed and dated.
- G05 certification PASS rejects synthetic mode, missing route certification,
  missing drift/PLC report, route mismatch, packet-mode mismatch, fixture
  evidence, and missing run artifact path.

## Blockers / TODO(human)

- Depends on G04 accepted physical route.
- TODO(human): [M06 artifact assessment] -> Choose who reviews PLC artifacts after the fixed-target run -> [operator listening review / musician review / defer PASS]

## Verification Commands

```bash
swift run open-lola drift-plc-run --route-report <route-report.json> --duration-seconds 3600 --policy silence --artifact-assessment-completed true --artifact-notes "<notes>" --output mac-port/reports/<drift>.json
swift run open-lola validate-drift-plc-report mac-port/reports/<drift>.json
swift run open-lola validate-drift-plc-certification-report mac-port/reports/<g05-certification>.json
swift run open-lola drift-plc-certification-synthetic-smoke
swift test
```

## Resume here

Use the first physical route PASS from G04 and run the 60-minute fixed-target
measurement without changing the playout target, then validate the G05
certification wrapper.

VERDICT: PARTIAL
