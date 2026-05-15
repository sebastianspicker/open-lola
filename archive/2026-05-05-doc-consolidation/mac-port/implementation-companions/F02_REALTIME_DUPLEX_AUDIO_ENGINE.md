# F02 Realtime Duplex Audio Engine

Date: 2026-05-03
Status: required production audio engine
Verdict: PARTIAL

## Finding

The current source layer validates realtime-audio reports and models bounded
handoff rings, but it does not yet run a measured full-duplex RME MADI engine.
The production path must use a direct Core Audio `AudioDeviceIOProc` or AUHAL
callback with preallocated handoff buffers, UDP send/receive outside setup
work, remote playout, and silence on miss.

## Current Surface

- [../../Sources/OpenLolaCore/RealtimeAudioEngine.swift](../../Sources/OpenLolaCore/RealtimeAudioEngine.swift)
  defines the report schema, callback safety checklist, bounded ring, playout
  behavior, and PASS guards.
- PASS requires measured mode, RME MADI hardware, accepted F01 fastest-audio
  evidence, accepted F03 route certification, non-synthetic callback ownership,
  callback-safe behavior, exact packet handoff, shutdown, and no hidden playout
  growth.

## Required Engine Shape

- Audio callback owner: direct `AudioDeviceIOProc` or AUHAL render callback.
- Allocation, locks, logging, file I/O, socket setup, report writing, and UI
  dispatch are absent from the callback.
- Rings are preallocated before start and have explicit capacity.
- Callback writes only counters and fixed-size block handoff state.
- UDP sockets are opened before audio start.
- Sender transmits exactly one UDP PCM audio block per deadline in the fastest
  mode.
- Receiver renders the due block or silence at the same deadline; it does not
  wait for late packets.
- Playout target is fixed by configuration and cannot grow adaptively.
- The configured preallocated block count matches the runtime ring capacity.
- The RME fastest-audio mode, F03 route packet mode, and realtime engine packet
  mode match on sample rate, frame count, channel count, and sample format where
  applicable.

## Required Evidence

The measured report must include:

- callback owner;
- callback p50/p95/p99/max and missed-deadline counters;
- input blocks, output blocks, network send blocks, network receive blocks;
- dropped input blocks, dropped network blocks, output underruns, and callback
  overruns;
- maximum buffered blocks and ring capacity;
- proof that UDP sockets were prepared before audio start;
- proof that the report was written only after stop.

## Implementation Gate

Do not add UI, codecs, recording, lighting, or session negotiation while this
finding is open. If new source is required, keep it in the core audio lane and
add focused tests before wiring a CLI run surface.

The source PASS gate is implemented. Do not mark F02 PASS unless the
`RealtimeAudioEngineReport` embeds accepted F01 and F03 source reports, references
a real run artifact, and validates all realtime handoff invariants.

## PASS Criteria

- F01 RME MADI path is accepted.
- F03 physical direct route is accepted.
- Full-duplex measured run emits `VERDICT: PASS`.
- F01 selected mode and F03 route packet mode match the realtime engine
  configuration.
- Input, output, network-send, and network-receive block counts match exactly.
- Playout target equals one hardware block; hidden or adaptive growth is absent.
- Callback max time remains inside the hardware block period.
- No packet loss policy increases playout latency.
- Shutdown completes and writes a machine-readable report.

## Resume here

Attach the RME hardware and direct route, then replace the remaining synthetic
runtime with the first measured `AudioDeviceIOProc` or AUHAL run path that emits
a `RealtimeAudioEngineReport` containing accepted F01/F03 source reports and a
real run artifact.

VERDICT: PARTIAL
