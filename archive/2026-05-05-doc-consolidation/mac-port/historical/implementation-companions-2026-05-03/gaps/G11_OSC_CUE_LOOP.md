# G11 OSC Cue Loop

## LoLa Comparison

LoLa includes control/session features around the media path. For the Mac
roadmap, OSC is the first show-control probe because it can stay outside the
audio callback and can be measured independently.

## Current Repo State

- Related milestone: [../milestones/M11_OSC_SHOW_CONTROL_PROBE.md](../milestones/M11_OSC_SHOW_CONTROL_PROBE.md)
- Live status: [../status/M11_STATUS.md](../status/M11_STATUS.md)
- Existing source has OSC packet tests, synthetic loopback timing, live UDP
  loopback, fixture validation, and synthetic smoke.
- 2026-05-03: `osc-cue-external-run` now records a bounded PARTIAL report with
  a live local UDP loopback, an operator-supplied audio baseline ID, and first
  external peer availability fields.
- Missing piece: live external peer and audio-active cue-loop evidence.

## Implementation Plan

1. Run localhost cue loop to confirm the local command surface and report shape.
2. Select the first external peer. Chataigne is preferred; Open Stage Control is
   fallback.
3. Record peer version, host, route, count, p50/p95/p99/max jitter, dropped
   cues, and timestamp correlation.
4. Repeat with audio active using the accepted audio baseline.
5. Reject PASS if audio p99/max, playout target, underruns, or route verdict
   changes.

## Acceptance Tests

- `validate-osc-cue-report` accepts live report.
- PASS requires live UDP loopback evidence, first external peer evidence, cue
  count consistency, and unchanged audio metrics.
- PASS rejects unavailable peer state unless verdict remains PARTIAL.

## Blockers / TODO(human)

- TODO(human): [M11 OSC peer] -> Choose the first live OSC peer for cue-loop measurement -> [Chataigne / Open Stage Control / defer external OSC]
- Requires peer software on reachable host.

## Verification Commands

```bash
swift run open-lola osc-cue-run --peer 127.0.0.1 --port <port> --count <n> --output mac-port/reports/<osc>.json
swift run open-lola osc-cue-external-run --audio-baseline <report-id> --port 0 --count <n> --first-external-peer chataigne --external-host <host> --external-port <port> --external-available false --external-unavailable-reason <reason> --output mac-port/reports/<osc>.json
swift run open-lola validate-osc-cue-report mac-port/reports/<osc>.json
swift test --filter OscCue
```

## Resume here

Use `osc-cue-external-run` to record the chosen first external peer and audio
baseline ID. Keep G11/M11 PARTIAL until that peer is live and the cue loop runs
with measured audio active.

VERDICT: PARTIAL
