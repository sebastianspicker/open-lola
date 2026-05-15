# M03 MADI TX

Date: 2026-05-04  
Status: source implementation complete; physical RME TX evidence pending  
Verdict: PARTIAL

## Objective

Implement full selected-channel and all-channel MADI transmit from Core Audio
input to original open-lola audio media packets with explicit timestamps,
channel metadata, sample format, and benchmark telemetry.

## Scope

In scope:

- capture all negotiated input channels from RME MADI or compatible interfaces;
- stable channel ordering;
- selectable channel maps;
- no heap allocation in the realtime callback;
- no blocking I/O or logging in the callback;
- preallocated packet blocks;
- packet timestamps from monotonic host time and sender frame index;
- v2 media packets for multichannel fragments;
- packetization benchmarks.

Out of scope:

- peer playout;
- receiver-side routing;
- drift correction;
- video transport.

## Affected Files

Expected new or changed files:

- `Sources/OpenLolaCore/AudioLoopbackRun.swift`
- `Sources/OpenLolaCore/RealtimeAudioPacketHandoff.swift`
- `Sources/OpenLolaCore/RealtimeAudioPayloadCaptureRing.swift`
- `Sources/OpenLolaCore/RealtimeAudioBuffers.swift`
- `Sources/OpenLolaCore/MadiTransmit.swift`
- `Sources/OpenLolaCore/UdpPcmV2Packet.swift`
- `Sources/OpenLolaCore/UdpPcmV2FragmentPlanner.swift`
- `Sources/OpenLolaCore/MultichannelTransport.swift`
- `Sources/OpenLolaCore/RmeFastestAudioPath.swift`
- `Sources/OpenLolaCore/OpenLolaCLI.swift`
- `Tests/OpenLolaCoreTests/MadiTransmitTests.swift`
- `Tests/OpenLolaCoreTests/UdpPcmV2PacketTests.swift`
- `Tests/OpenLolaCoreTests/RealtimeAudioPacketHandoffTests.swift`
- `docs/architecture/madi-full-rx-tx.md`

## Implementation Tasks

1. Added tests that fail when TX packetization falls back to stereo-only or
   silence-only handoff.
2. Replaced the hardcoded two-channel IOProc handoff with parsed channel count,
   sample format, and selected input/output maps.
3. Added preallocated realtime payload slabs sized by channel count, frames, and
   sample format.
4. Added interleaved and AudioBufferList capture paths for direct and remapped
   Core Audio layouts.
5. Packetized captured samples into v2 audio media packets outside the callback.
6. Carried stream ID, sequence number, sender frame index, host timestamp,
   channel offset, channels in fragment, sample rate, sample format, fragment
   IDs, and metadata revision.
7. Added counters for dropped input blocks, full capture rings, invalid input
   payloads, direct/remapped input blocks, packet fragment count, and allocation
   warnings.

## Test Plan

Tests first:

- 2, 8, 16, 32, and 64-channel TX packetization: implemented;
- selected channel map preserves ordering: implemented;
- channel metadata revision travels with packets: implemented;
- packet fragment count stays under MTU: implemented;
- sample format mismatch is rejected before media starts: implemented;
- callback handoff does not allocate after preflight: source counters
  implemented;
- sequence numbers and frame indexes are monotonic: implemented;
- stereo fallback is used only when explicitly negotiated: covered by existing
  transport negotiation tests.

## Benchmark Plan

- audio callback duration p50/p95/p99/max;
- packetization duration per block;
- fragments per audio block;
- TX ring occupancy and drops;
- memory allocations on TX hot path;
- max stable channel count at 48 kHz and 96 kHz;
- 8/16/32/64-frame stability where hardware accepts those buffers.

## Acceptance Criteria

- The TX path can packetize all negotiated MADI channels in tests.
- The realtime callback performs no blocking network I/O.
- Channel count, order, sample rate, and sample format are explicit.
- Synthetic benchmarks show bounded packetization time for 64 channels.
- Physical PASS requires measured RME MADI TX evidence.

## Implementation Evidence

- `RealtimeAudioPacketHandoff` now writes callback-facing capture data into
  preallocated payload slabs, preserving selected channel order.
- `sendNextPacket()` and `sendNextV2Packets(mode:)` emit captured payloads
  instead of synthetic silence when capture data is supplied.
- `AudioLoopbackRunConfiguration` accepts `--channels`, `--sample-format`,
  `--input-channels`, `--output-channels`, `--preallocated-blocks`, `--mtu`,
  `--max-fragments`, and `--metadata-revision`.
- `AudioLoopbackIOProcState` now uses the parsed channel count, sample format,
  and channel maps instead of hardcoded stereo int16 maps.
- `madi-tx-synthetic-smoke` emits a machine-readable partial report for
  2/8/16/32/64-channel packetization.

## Risks

- Core Audio may expose non-interleaved buffers or stream layouts requiring
  format-specific copy logic.
- Very small hardware buffers can make packet rate and scheduling overhead the
  limiting factor before CPU arithmetic becomes relevant.

## Blockers

- Physical RME MADI interface required for PASS.
- Exact channel format support must be read from the live device.

## Rollback Plan

Keep v1 UDP PCM and existing loopback probes available. If v2 live TX is
unstable, gate it behind explicit capability negotiation and retain stereo
loopback as a diagnostic-only path.

## Progress Checklist

- [x] Add failing multichannel TX tests.
- [x] Remove callback hardcoded stereo TX.
- [x] Add preallocated multichannel blocks.
- [x] Packetize captured samples into v2 packets.
- [x] Add TX hot-path counters.
- [x] Run synthetic packetization benchmarks.
- [ ] Run physical RME TX benchmark.

## Resume Point

Resume at the physical-evidence boundary: connect the RME MADI interface, run a
real `audio-loopback-run` with explicit channel maps, capture packet evidence,
and attach the physical TX benchmark before changing this milestone to `PASS`.

VERDICT: PARTIAL
