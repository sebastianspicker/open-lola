# M04 Audio Loopback Source Implementation Report

Date: 2026-05-03  
Public surface: [Current State](../../docs/current-state.md)  
Status: PARTIAL

## Scope

This report validates the source-level M04 audio loopback implementation. It
does not claim physical PASS because the RME MADI device, selected fastest mode,
and analog loopback wiring were not available on this Mac.

## Implemented Gate

- Bounded capture and playout rings are implemented by
  `Sources/OpenLolaCore/RealtimeAudioPacketHandoff.swift`.
- The callback-facing capture/render methods update fixed block state and
  counters only.
- Packetization remains outside those callback-facing methods and emits one UDP
  PCM packet per captured audio block.
- Playout accepts fixed zero-block or one-block targets; larger buffered targets
  remain invalid for PASS.
- Late packets are dropped and counted.
- PASS validation rejects late packets, underruns, overruns, hidden playout
  growth, packet-count mismatch, callback-safety violations, and missing
  hardware/route source evidence.
- `audio-loopback-run` now reports the callback-safety checklist and blocks
  before starting Core Audio when the target RME UID is absent.

## Commands

```bash
swift test
swift build
swift run open-lola realtime-audio-synthetic-smoke
swift run open-lola audio-loopback-run --input-uid missing-rme-uid --output-uid missing-rme-uid --sample-rate 48000 --frames 32 --duration-seconds 1 --output /private/tmp/open-lola-m04-audio-loopback-preflight.json
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

`swift build` and the two `swift run` probes required an unsandboxed rerun after
SwiftPM hit `sandbox-exec: sandbox_apply: Operation not permitted`.

## Results

- `swift test` passed with 410 Swift Testing cases.
- `swift build` passed after the unsandboxed rerun.
- `realtime-audio-synthetic-smoke` emitted `VERDICT: PARTIAL` with one captured
  block, one sent packet, one received packet, one one-block-target underrun,
  zero late packets, bounded ring capacity 4, and completed shutdown.
- `audio-loopback-run` wrote a blocked-preflight report to
  `/private/tmp/open-lola-m04-audio-loopback-preflight.json` with
  `VERDICT: PARTIAL`; blockers were missing input UID, missing output UID, no
  input/output channels, and no visible RME MADI device.
- `bash scripts/verify-docs.sh` passed.
- `shellcheck scripts/*.sh` passed.

## Remaining Hardware Gate

TODO(human): [M04 physical loopback closure] -> Connect the selected RME or compatible low-latency audio path, provide the same-device input/output UID, and run the analog loopback report -> [RME MADI / compatible Core Audio device / defer physical closure]

## Verdict

M04 source-level audio loopback is implemented. Physical analog loopback
measurement is still required before this milestone can become PASS.

VERDICT: PARTIAL
