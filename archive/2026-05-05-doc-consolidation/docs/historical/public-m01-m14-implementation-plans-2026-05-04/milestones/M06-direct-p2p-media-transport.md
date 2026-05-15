# M06 Direct P2P Media Transport

Date: 2026-05-04  
Status: source implementation complete; direct LAN and physical audio evidence open  
Verdict: PARTIAL

## Objective

Implement direct peer-to-peer session setup with a control channel and UDP-first
media channels for audio and video, using manual peer addresses as the first
gold-standard mode.

## Scope

In scope:

- direct IP/manual peer mode;
- peer identity and capability exchange from M02;
- separate control and media channels;
- UDP media sender and receiver;
- explicit sequence numbers, timestamps, stream IDs, and payload type IDs;
- reconnect/recovery policy;
- metrics exchange;
- clean shutdown.

Out of scope:

- WAN/NAT optimization beyond existing route probes;
- relay as a low-latency path;
- retransmission for realtime audio.

## Affected Files

Expected new or changed files:

- `Sources/OpenLolaCore/PeerSessionRunner.swift`
- `Sources/OpenLolaCore/SessionProtocol.swift`
- `Sources/OpenLolaCore/SessionControlMessage.swift`
- `Sources/OpenLolaCore/UdpMediaTransport.swift`
- `Sources/OpenLolaCore/UdpPcmSocketOperations.swift`
- `Sources/OpenLolaCore/UdpPcmContinuousRouteRunner.swift`
- `Sources/OpenLolaCore/NatFriendlyRoute.swift`
- `Sources/OpenLolaCore/OpenLolaCLI.swift`
- `Sources/open-lola/NetworkCommands.swift`
- `Sources/open-lola/main.swift`
- `Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift`
- `Tests/OpenLolaCoreTests/UdpMediaTransportTests.swift`
- `Tests/OpenLolaCoreTests/ReconnectionTests.swift`
- `docs/architecture/e2e-p2p-session.md`
- `docs/architecture/open-lola-protocol.md`

## Implementation Tasks

Source status:

- `PeerSessionRunner` implements the M06 lifecycle states: idle,
  handshaking, configured, media starting, running, recovering, shutting down,
  closed, and failed.
- `UdpMediaTransport` implements the UDP-first media socket path and a binary
  media envelope carrying payload type, stream ID, sequence number, timestamp,
  and nested audio/video payloads.
- Audio media payloads use UDP PCM v2 and are routed by stream ID into the
  existing MADI receive pipeline source contract.
- Video payload type IDs are reserved and the media envelope can carry raw
  video fragments as synthetic-first video payloads.
- Metrics now carry packet loss, jitter, late packets, callback p99, queue
  depth, CPU, memory, underrun/overrun, and dropped video fields.
- Reconnect uses explicit media pause/stop and restart boundaries while keeping
  the accepted session configuration intact.

1. Add loopback tests for control handshake and media port assignment.
2. Implement control channel session lifecycle: idle, handshaking, configured,
   media starting, running, recovering, shutting down, closed, failed.
3. Implement UDP media socket binding and peer address validation.
4. Route audio payloads by stream ID to the MADI RX/TX pipeline.
5. Reserve video payload IDs and route synthetic video first.
6. Add metrics packet exchange for loss, jitter, late packets, callback
   duration, queue depth, CPU, and memory.
7. Implement reconnect with explicit media stop/start boundaries.

## Test Plan

Tests first:

- direct P2P session setup;
- media channel cannot start before accepted session configuration;
- sequence and timestamp validation;
- packet loss and jitter stats;
- reconnect after media socket failure;
- clean shutdown is idempotent;
- audio media is never sent over the control channel.

## Benchmark Plan

- control handshake duration;
- media packet send/receive overhead;
- UDP packet jitter distribution on loopback and direct LAN;
- packet loss behavior under impairment simulation;
- reconnect time;
- metrics packet overhead.

## Acceptance Criteria

- Two peers can negotiate and start direct UDP media channels.
- Audio packets include sequence, timestamp, stream ID, payload type, and sample
  metadata.
- Reconnect and shutdown do not leave media callbacks blocked.
- Direct LAN/manual address is the only PASS-eligible P2P mode at this stage.

## Risks

- Combining NAT traversal and lowest-latency direct mode too early can obscure
  direct-route timing measurements.
- Reconnect code can accidentally touch audio-critical paths if boundaries are
  not explicit.

## Blockers

- M02 session model required.
- M03-M05 required for physical audio PASS.

## Rollback Plan

Keep existing route certification commands intact. If the new session runner is
unstable, disable media start from negotiated sessions and keep route probes as
diagnostics.

## Progress Checklist

- [x] Add direct peer session tests.
- [x] Implement control lifecycle.
- [x] Implement UDP media transport.
- [x] Add metrics exchange.
- [x] Add reconnect/shutdown behavior.
- [ ] Run direct LAN packet benchmarks.
- [ ] Run two-peer manual address smoke test.

## Resume Point

Source loopback is now implemented through `open-lola direct-p2p-localhost-smoke`
or `open-lola direct-p2p-localhost-smoke --output <path>`, followed by
`open-lola validate-direct-p2p-session-report <path>`. Next resume point: run
two real peers on a direct LAN/manual address path, capture packet timing, then
attach the route report before considering M06 for PASS. Keep the milestone
PARTIAL until physical MADI and direct LAN evidence exist.

VERDICT: PARTIAL
