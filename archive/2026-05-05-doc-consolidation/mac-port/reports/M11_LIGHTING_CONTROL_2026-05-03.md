# M11 Lighting Control Implementation Report

Date: 2026-05-03  
Public surface: [Current State](../../docs/current-state.md)  
Status: source-level implementation complete; live evidence still required  
Verdict: PARTIAL

## Scope

This report closes the source-level implementation for the public M11
lighting/control milestone. It covers OSC cue timing, audio-impact guards, and
the isolated lighting fixture safety gate used before any sACN or Art-Net
output. It does not claim live Chataigne, Open Stage Control, QLC+, OLA, MIDI,
fixture, packet-capture, or audio-active PASS evidence.

## Implemented Source Surface

- `OscCueMessage` encodes and decodes the OSC 1.0 cue packet at
  `/open-lola/cue`.
- `OscCueUdpLoopbackRunner` records live local UDP cue timing and jitter.
- `OscCueExternalRunner` writes a bounded external-peer handoff report with an
  audio baseline ID and external peer availability.
- `LightingSafetyPolicy.decision(for:)` blocks output unless standards,
  isolation, explicit arming, allowed universe/destination, and the failure
  policy are all complete.
- `LightingFixtureGateReport.validate()` rejects PASS lighting evidence without
  packet capture, one-universe capture, OSC cue workflow, local fixture owner,
  complete blackout/hold/drop/disable policy, and unchanged audio metrics.

## Verification Commands

```bash
swift test --filter OscCueReportTests
swift test --filter LightingFixtureGate
swift test
swift build
.build/debug/open-lola osc-cue-run --peer 127.0.0.1 --port 0 --count 3 --output /private/tmp/open-lola-m11-osc-live-loopback.json
.build/debug/open-lola validate-osc-cue-report /private/tmp/open-lola-m11-osc-live-loopback.json
.build/debug/open-lola lighting-gate-run --audio-baseline m05-route-baseline-required --osc-cue-report m11-osc-cue-required --protocol sacn --interop-target qlcPlus --universe 1 --network-mode loopbackUnicast --destination 127.0.0.1 --port 5568 --isolated-network true --explicitly-armed false --capture-tool not-run --capture-point not-run --duration-seconds 0 --output /private/tmp/open-lola-m11-lighting-gate.json
.build/debug/open-lola validate-lighting-gate-report /private/tmp/open-lola-m11-lighting-gate.json
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Current Results

- OSC packet encode/decode, fixture validation, synthetic timing, live UDP
  loopback, external-peer handoff, and PASS guard tests exist.
- Lighting gate tests now cover unarmed output, incomplete failure policy,
  shared campus network mode, unapproved universe, packet capture, workflow,
  fixture owner, direct fixture streaming, and audio-impact PASS guards.
- The CLI can write and validate a bounded PARTIAL lighting gate handoff report
  without sending live fixture packets.

## Deferred Evidence

M11 stays PARTIAL until a real run records:

- accepted audio baseline active during the OSC cue loop;
- one live external OSC peer, preferably Chataigne first and Open Stage Control
  as fallback;
- selected Q009 lighting universe, isolated route, fixture or bridge owner, and
  blackout/hold/drop/disable behavior;
- packet capture for the lighting route;
- audio-off/audio-on comparison proving cue and lighting traffic do not change
  callback p99/max, playout target, or underrun count.

MIDI remains deferred as optional local control until a concrete target device
or venue workflow is selected.

## Verdict

The M11 source contract is implemented and guarded, but the milestone cannot be
marked PASS without live external-peer, lighting, packet-capture, and
audio-active evidence.

VERDICT: PARTIAL

## Resume here

Run `osc-cue-external-run` with the accepted audio baseline and selected OSC
peer, then run `lighting-gate-run` with the Q009 universe and isolated route.
Validate both reports before promoting any M11 or M12 evidence to PASS.
