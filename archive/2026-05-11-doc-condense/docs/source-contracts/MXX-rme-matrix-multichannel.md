# MXX RME Matrix And Multichannel Routing

Date: 2026-05-04  
Status: source implementation complete; physical RME evidence pending  
Verdict: PARTIAL

## Objective

Execute the multichannel audio route from current stereo-compatible UDP PCM
toward professional RME/MADI use. The implemented source design prefers
send-all-channels plus receiver-local monitoring, with optional RME Matrix
metadata only where public or user-provided evidence permits it.

## Scope

This file covers M01 through M05:

- M01 Audit current audio/channel/buffer assumptions;
- M02 Define multichannel transport and channel metadata;
- M03 Implement send-all-channels mode;
- M04 Implement receiver-side local mixing;
- M05 Add optional RME Matrix metadata support.

Out of scope: changing defaults to unstable low-buffer profiles, WAN buffering,
video, lighting, or proprietary TotalMix internals.

## Affected Files

Planned source/test/docs surfaces:

- `Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventory.swift`
- `Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift`
- `Sources/OpenLolaCore/Audio/Routing/AudioRoutingAssumptionLedger.swift`
- `Sources/OpenLolaCore/Network/UDP/MultichannelTransport.swift`
- `Sources/OpenLolaCore/Audio/MADI/RmeMatrixMetadata.swift`
- `Sources/OpenLolaCore/Network/UDP/UdpPcmV2FragmentPlanner.swift`
- `Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift`
- `Sources/OpenLolaCore/Audio/Routing/ReceiverMixSnapshot.swift`
- `Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift`
- `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift`
- `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift`
- `Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift`
- `Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift`
- `Tests/OpenLolaCoreTests/MultichannelTransportTests.swift`
- `Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift`
- `Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift`
- `Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift`
- `docs/architecture/audio-routing.md`
- `docs/architecture/rme-madi-routing.md`
- `docs/architecture/multichannel-transport.md`

## Implementation Tasks

| Milestone | Tasks |
|---|---|
| M01 | Build an assumption ledger for every fixed `2`, `[0, 1]`, one-block target, stereo fixture, and default packet mode. Classify each as legacy compatibility, fixture, default profile, or bug. |
| M02 | Extend v2 packet schema, metadata schema, and negotiation contracts. Define channel metadata, metadata revisions, fragment IDs, and v1 fallback warnings. |
| M03 | Implement send-all-channels packetization and reassembly. Select channel ranges from Core Audio inventory and split each deadline into MTU-safe channel fragments. |
| M04 | Implement receiver-local mix snapshots with gain, mute, pan, and destination route. Keep mix preparation outside the callback and use precomputed state in render. |
| M05 | Add optional RME metadata providers: Core Audio only, documented TotalMix OSC/MIDI, user-provided snapshot, unavailable. Rate-limit updates on the control channel. |

## Implementation Evidence

Implemented source contracts:

- M01: `AudioRoutingAssumptionLedger` classifies the fixed stereo/default route
  assumptions as legacy compatibility, fixture, default profile, validation
  boundary, runtime multichannel path, or advisory metadata.
- M02: UDP PCM v2 header encode/decode validates stream ID, fragment IDs,
  channel ranges, sample format, packing mode, payload length, metadata
  revision, and guard bytes.
- M03: `RealtimeAudioPacketHandoff` captures selected input samples into
  preallocated payload slabs, and `UdpPcmV2Packetizer` splits a full interleaved
  audio deadline into MTU-safe channel-range fragments; `UdpPcmV2FragmentReassembler`
  reconstructs complete deadlines and reports missing/duplicate fragments
  without inventing audio.
- M04: `ReceiverMixSnapshot` prepares immutable gain/mute/pan route tables and
  rejects hidden destructive downmix unless explicitly allowed.
- M05: `RmeMatrixMetadataSnapshot` supports Core Audio, documented TotalMix
  OSC/MIDI, user-provided, and unavailable metadata providers; `PeerSessionRunner`
  publishes accepted metadata revisions on the control plane, receives peer
  metadata without changing media state, and rate-limits local updates.

Runtime source hook:

- `RealtimeAudioPacketHandoff.sendNextPacket()` and `sendNextV2Packets(mode:)`
  emit captured payloads for v1/v2 media. The callback-facing capture path uses
  preallocated slabs and counters; packet encoding remains outside the callback.

## Test Plan

Tests first for each milestone:

- M01: failing assumption-ledger test that requires every fixed stereo route to
  be classified;
- M02: metadata JSON round trip, v2 packet header round trip, malformed v2
  rejection, v1 fallback warning;
- M03: 2/8/16/32/64-channel packetization, selected channel ordering, fragment
  reassembly, metadata revision, lost fragment accounting, MTU rejection;
- M04: identity mix, gain/mute/pan, non-destructive route rejection, immutable
  snapshot replacement;
- M05: provider serialization, stale metadata fallback, unavailable metadata
  still plays media.

Current source tests:

- assumption-ledger classification;
- Core Audio channel-set extraction and non-contiguous selection;
- v2 packet header round trip and malformed packet rejection;
- 2/8/16/32/64-channel packetization, exact reassembly, lost-fragment
  accounting, metadata revision, selected channel ordering, and MTU rejection;
- realtime captured-payload v1/v2 handoff fragment emission;
- receiver mix precompute, hidden-downmix rejection, and immutable replacement;
- RME metadata serialization, rate limiting, and unavailable fallback.

Existing tests to extend:

- `MultichannelTransportTests`;
- `UdpPcmPacketTests`;
- `RealtimeAudioEngineTests`;
- `UdpPcmRouteReportTests`;
- `RmeFastestAudioPathTests`.

## Benchmark Plan

Benchmark method:

- local packetization CPU for 2/8/16/32/64 channels;
- MTU fragment count at 8/16/32/64 frame deadlines;
- receiver mix render cost with identity and non-identity routes;
- two-machine P2P packet age and loss for v2 fragments;
- physical RME MADI loopback with send-all-channels and metadata absent.

## Acceptance Criteria

M01 is accepted when every fixed channel/buffer assumption is classified.

M02 is accepted when metadata and v2 packet contracts round-trip without live
runtime wiring.

M03 is accepted when 64-channel send-all-channels packet accounting is exact
and no datagram relies on IP fragmentation.

M04 is accepted when receiver mix snapshots are deterministic, precomputed, and
do not allocate in the callback path.

M05 is accepted when metadata is optional, public/user-provided only, revisioned,
rate-limited, exchanged on the control channel, and never required for playback.

## Risks

- 64-channel float32 may exceed deadline pacing on small buffers.
- Matrix metadata may be incomplete, stale, or unavailable.
- Receiver-local mix can accidentally become callback-heavy.
- Changing stereo fixtures without classification can break v1 compatibility.

## Blockers

- Real RME MADI/Thunderbolt hardware is required for physical PASS.
- Public TotalMix metadata behavior must be operator-enabled and documented.
- A proper Git worktree is absent in this checkout, so progress remains
  filesystem/docs-based.

## Rollback Plan

Keep UDP PCM v1 unchanged. If v2 runtime wiring fails, disable v2 negotiation
and retain v1 stereo compatibility with explicit warnings. If metadata support
is unsafe or incomplete, disable the metadata provider and keep send-all-
channels mode.

## Progress Checklist

- [x] Source-level 64-channel negotiation test exists.
- [x] Source-level v1 stereo fallback test exists.
- [x] Source-level MTU fragment planner test exists.
- [x] Source-level receiver identity mix test exists.
- [x] M01 assumption ledger written.
- [x] M02 v2 packet encode/decode tests written.
- [x] M03 send-all-channels captured-payload runtime packetizer implemented.
- [x] M04 receiver mix runtime path implemented and exposed through
  `madi-full-duplex-run --receiver-mix swap-stereo` report evidence.
- [x] M05 public/user-provided metadata provider and control-channel exchange
  implemented.
- [ ] Physical RME MADI evidence attached.

## Resume Point

Resume at the physical-evidence boundary: attach real RME MADI/Core Audio
inventory, two-machine packet capture, and loopback evidence before promoting
this milestone from `PARTIAL` to `PASS`.

VERDICT: PARTIAL
