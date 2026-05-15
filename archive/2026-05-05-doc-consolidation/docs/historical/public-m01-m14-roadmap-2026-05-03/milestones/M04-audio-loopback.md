# M04 Audio Loopback

Date: 2026-05-03  
Status: source implementation complete; physical loopback evidence open  
Verdict: PARTIAL

## Objective

Implement and measure the local audio TX/RX loopback path with fixed playout
target and realtime-safe callback behavior.

## Scope

Cover audio callback ownership, preallocated rings, packet handoff shape,
analog loopback measurement, and underrun/overrun accounting.

## Affected Files

- [../architecture/latency-first-architecture.md](../architecture/latency-first-architecture.md)
- [../architecture/audio-rme-madi.md](../architecture/audio-rme-madi.md)
- `Sources/OpenLolaCore/RealtimeAudioEngine.swift`
- `Sources/OpenLolaCore/RealtimeAudioPacketHandoff.swift`
- `Sources/OpenLolaCore/AudioLoopbackRun.swift`
- `Sources/OpenLolaCore/AudioLoopbackHelpers.swift`
- `Sources/OpenLolaCore/UdpPcmPacket.swift`
- `Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift`
- `Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift`
- `Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift`
- `mac-port/reports/M04_AUDIO_LOOPBACK_2026-05-03.md`

Implemented source gate:

- `RealtimeAudioPacketHandoff` owns bounded capture and playout rings.
- `captureCallback` and `renderCallback` only update fixed block handoff state
  and counters; UDP packet allocation/encoding stays outside those callback
  methods.
- `sendNextPacket` preserves one UDP PCM packet per captured audio block.
- `receive` validates packet mode, applies the fixed zero/one-block target,
  drops late packets, and records late/drop counters without growing playout.
- Realtime report validation rejects PASS reports with late packets, underruns,
  callback overruns, hidden playout growth, or buffered targets larger than one
  block.
- `audio-loopback-run` reports the callback-safety checklist and blocks cleanly
  before starting Core Audio when the RME MADI device is not visible.

## Implementation Tasks

- Use preallocated capture and playout rings.
- Keep the callback free of blocking I/O, heap allocation, locks where
  avoidable, and logging.
- Preserve one UDP PCM block per audio block as the handoff model.
- Add counters for underruns, overruns, late packets, and callback deadline
  warnings.

## Test Plan

- Ring-buffer unit tests.
- Packetization tests.
- Callback-safety report validation.
- CLI loopback smoke using available device only as `PARTIAL` unless the RME
  rig is present.

## Benchmark Plan

Measure analog loopback with impulse or test tone. Record corrected one-way
latency, callback p50/p95/p99/max, underruns, overruns, and allocation warnings.

## Acceptance Criteria

- Fixed zero or one-block playout target.
- No hidden buffer growth.
- No callback allocation or blocking path.
- Physical loopback report exists for PASS.

## Risks

- Callback proof can be incomplete without instrumentation.
- Local loopback can pass while two-machine route fails.
- PLC can hide failures if counters are not strict.

## Blockers

M03 fastest stable device mode and physical analog loopback wiring. Source
validation is implemented, but PASS still requires a measured physical analog
loopback report on the selected RME or compatible low-latency device.

## Rollback Plan

Disable the realtime loopback path and return to source validators and packet
contract tests.

## Progress Checklist

- [x] Preallocated rings verified.
- [x] Callback safety validated.
- [ ] Analog loopback measured.
- [x] Fixed playout target validated.
- [x] M04 report stored.

## Resume Point

Resume at M05 after local audio loopback has a measured fastest mode.

VERDICT: PARTIAL
