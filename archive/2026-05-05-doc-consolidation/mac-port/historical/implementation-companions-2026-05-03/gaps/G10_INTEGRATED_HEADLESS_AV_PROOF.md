# G10 Integrated Headless AV Proof

## LoLa Comparison

LoLa is valuable because audio and video work together with latency low enough
for performance. The Mac project must prove the same kind of coexistence in a
headless runtime before treating UI, recording, or packaging as field-ready.

## Current Repo State

- Related milestone: [../milestones/M10_INTEGRATED_HEADLESS_AV.md](../milestones/M10_INTEGRATED_HEADLESS_AV.md)
- Related prototype: [../prototype/P04_INTEGRATED_AV_PROOF.md](../prototype/P04_INTEGRATED_AV_PROOF.md)
- Live status: [../status/M10_STATUS.md](../status/M10_STATUS.md), [../prototype/status/P04_STATUS.md](../prototype/status/P04_STATUS.md)
- Existing source validates integrated reports and synthetic headless smoke.
- 2026-05-03: `integrated-av-run` now writes a bounded PARTIAL integrated
  report from an operator-supplied audio baseline ID plus video/control
  participation switches.
- Missing piece: measured 30-minute integrated A/V/control stress.

## Implementation Plan

1. Record accepted audio-only baseline report ID from G04/G05.
2. Enable video capture from G07, video transport or preview from G09, OSC or
   ATEM polling if available, and explicit degradation policy.
3. Run a short integrated smoke and reject immediately if audio p99/max,
   playout target, underruns, or route verdict worsens.
4. Run at least 1,800 seconds headless with CPU, GPU, network, callback,
   packet, frame, drop, cue/control jitter, and degradation metrics.
5. Validate the integrated report and update P04 only if the audio-only
   baseline remains unchanged.

## Acceptance Tests

- `validate-integrated-av-report` accepts measured report.
- PASS requires measured mode, P04 proof evidence, RME visibility, video
  capture, video transport or preview, OSC/ATEM evidence where claimed, and no
  UI ownership of realtime paths.
- PASS rejects any audio metric regression or playout target change.

## Blockers / TODO(human)

- Depends on G03, G04, G07, and either G08 or G11 when control is included.
- TODO(human): [Integrated proof window] -> Reserve an uninterrupted 30-minute test window -> [lab run / venue run / defer P04 closure]

## Verification Commands

```bash
swift run open-lola integrated-av-run --audio-baseline <report-id> --video-capture on --video-transport on --osc-control on --atem-readonly <host|off> --duration-seconds 60 --output <integrated-report.json>
swift run open-lola validate-integrated-av-report <integrated-report.json>
swift test --filter IntegratedAv
swift test
```

## Resume here

Fill the real audio-only baseline report ID first, run `integrated-av-run` as a
short PARTIAL source-level proof, then replace the synthetic evidence with the
1,800 second measured proof before marking G10/M10 PASS.

VERDICT: PARTIAL
