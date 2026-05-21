# Open-Lola Protocol Plan

Date: 2026-05-21
Status: M06 source-level protocol and direct UDP media contract implemented  
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| UDP media, monotonic timestamps, sequence numbers, stream IDs, DSCP, and PTP vocabulary | `public standard` |
| Core Audio, AVFoundation, VideoToolbox, and Blackmagic Desktop Video SDK integration fields | `public API` |
| Message names, field names, packet headers, payload types, and negotiation structs below | `original open-lola design` |
| PASS/FAIL thresholds and latency profile promotion rules | `experimentally derived requirement` |
| IP/NAT preflight before trusted media readiness and manual direct IP as an explicit lab route | `implementation hypothesis` |

## Clean-Room Boundary

The protocol is not a compatibility protocol. It must not copy proprietary LoLa
packet formats, symbols, message strings, binary-derived field order, or
decompiled logic. Prior research is reduced to independent requirements:

- exchange low-latency multichannel audio;
- exchange low-latency video;
- prioritize stable audio latency over video continuity;
- expose every buffer in the latency budget;
- keep the default media path direct and UDP-first.

M04 clean-room requirement IDs for this protocol surface:

- `CRQ-001`: cite sanitized requirements, not raw internal evidence;
- `CRQ-002`: use open-lola-owned public naming;
- `CRQ-100`: keep packet contracts original and versioned;
- `CRQ-101`: keep media and control/session lanes separate;
- `CRQ-500`: keep legacy compatibility optional and disabled by default.

Any compatibility parser or packet extension must follow the active compliance
and release boundary in [release-boundary.md](release-boundary.md) and
[release-manifest.md](release-manifest.md) before
source implementation.

## Current Source Protocols

Current source contracts:

- UDP PCM v1 in `UdpPcmPacket.swift`: single audio packet shape with explicit
  sample rate, frames, channel count, sample format, sequence number, sender
  frame index, host-time timestamp, and payload size. It is still used by route
  and loopback probes.
- UDP PCM v2 in `UdpPcmV2Packet.swift`: channel-range fragments for one audio
  deadline, stream ID, metadata revision, fragment index/count, total channel
  count, channel offset, and MTU-safe payloads.
- Video fragment v1 in `VideoTransportPacket.swift`: frame sequence, timestamp,
  payload size, fragment index/count, payload offset, fingerprint, and payload.
  M06 wraps it in the UDP media envelope for payload type and stream ID; live
  Blackmagic socket TX/RX remains open.
- Direct media envelope v1 in `UdpMediaTransport.swift`: binary UDP envelope
  with payload type ID, stream ID, sequence number, timestamp, payload byte
  count, and header guard. It validates nested UDP PCM v2 audio metadata.
- NAT/rendezvous reports in `NatFriendlyRoute*.swift`: endpoint registration and
  UDP traversal evidence, but not session capability negotiation.
- M02 session contract in `Core/PeerIdentity.swift`, `SessionProtocol.swift`,
  `SessionControlMessage.swift`, `AudioStreamDescription.swift`,
  `VideoStreamDescription.swift`, and `SessionNegotiation.swift`: clean-room
  peer identity, capability documents, audio/video stream descriptions,
  session proposals, accepted configurations, profile validation, deterministic
  JSON control messages, and a small session state machine. Accepted
  configurations validate a two-or-more-peer media topology by requiring one
  control/audio/video/metrics endpoint set per configured peer and rejecting
  duplicate per-channel endpoints.
- M07 session profile contract in `SessionLatencyProfilePolicy` and
  `SessionLatencyProfileBenchmarkMetrics`: Direct Audio First, Balanced AV,
  Multi-Video Performance, and WAN Stable have explicit RX compatibility,
  video-pressure, continuity, and fastest-PASS policy fields.
- M06 session runner in `PeerSessionRunner.swift`: direct manual-address
  handshake, advisory audio metadata exchange, media start/stop barriers,
  UDP `audioTiming` media probes, reconnect state, shutdown, UDP socket start,
  and stream-ID audio routing into the MADI receive source contract.
- `open-lola session-capabilities`: prints the local source-level capability
  document without starting media.
- `open-lola direct-p2p-localhost-smoke`: runs two source-level peers in one
  process, negotiates a direct session, exchanges UDP audio media packets, and
  emits a PARTIAL report.
- `open-lola direct-p2p-session-run --output <path>`: runs two local peers with
  socket-backed UDP control JSON and UDP media packets, then emits a PARTIAL
  report.
- `open-lola direct-p2p-session-run --role initiator|responder ...`: runs the
  same control and media path over configured manual-address endpoints so two
  hosts can collect matching PARTIAL session reports before packet-capture
  review.
- `open-lola direct-p2p-mesh-topology-synthetic-smoke --output <path>`:
  writes a source-level three-or-more-peer topology report with one endpoint set
  per peer and directed audio/video route records. It does not start a
  multi-peer media runtime.
- `open-lola direct-p2p-mesh-runtime-localhost-smoke --output <path>`:
  runs a localhost all-pairs mesh probe that sends UDP PCM v2 audio fragments
  across every directed peer pair and validates complete reassembly metrics. It
  remains PARTIAL until physical multi-peer evidence exists.
- `open-lola latency-profile-benchmark-synthetic-smoke`: emits a source-level
  M07 latency-profile benchmark report with callback p99, route age, packet
  age, jitter, underruns, overruns, and added RX buffer cost.
- `open-lola rx-buffer-benchmark-run --output <path>`: emits a local runtime
  RX-buffer benchmark matrix for Direct, Small, Adaptive, and Stable/WAN
  profiles. It remains PARTIAL until repeated on a physical two-Mac route.

## Control Message Structures

Control messages should be encoded as compact JSON first for debuggability. A
binary control codec can be added only after the JSON contract is stable and
benchmarked. Control is outside the audio callback.

Shipped M02 message types:

| Type | Purpose |
|---|---|
| `hello` | peer identity, implementation version, supported control protocol versions |
| `capabilities` | audio, video, transport, timing, and profile capabilities |
| `sessionPropose` | proposed profile, stream set, direct addresses, and MTU |
| `sessionAccept` | accepted stream IDs, formats, rates, channels, and ports |
| `sessionReject` | explicit machine-readable reason |
| `audioMetadata` | advisory public/user-provided channel and route metadata, rate-limited and never required for playback |
| `mediaStart` | start barrier with monotonic start time |
| `mediaPause` | pause media without tearing down the accepted configuration |
| `metrics` | loss, jitter, underruns, overruns, drift, frame drops, CPU, memory |
| `error` | recoverable and fatal runtime errors |
| `shutdown` | graceful stop and final metrics request |

Deferred control concepts remain reconnect negotiation and richer clock-model
exchange. M06 now sends bounded UDP `audioTiming` probes after media sockets are
connected; these probes are report evidence only and do not promote physical
direct-LAN readiness.

## Media Payload Types

Use explicit payload type IDs:

| ID | Name | Direction | Notes |
|---|---|---|---|
| 1 | audio_pcm_v2 | bidirectional | MADI-scale channel fragments |
| 2 | audio_timing | bidirectional | timing and drift telemetry |
| 16 | video_raw_frame_fragment | unidirectional or bidirectional | initial raw/intra baseline |
| 17 | video_videotoolbox_fragment | unidirectional or bidirectional | optional after benchmark |
| 32 | metrics | bidirectional | low-rate metrics if not on control |
| 48 | keepalive | bidirectional | media path liveness |

## Audio Media Packet

Audio media should evolve from UDP PCM v2 without breaking its clean-room shape.

Required fields:

- protocol magic and version;
- payload type ID;
- stream ID;
- sequence number per audio deadline;
- sender frame index;
- sender monotonic host time;
- sample rate;
- frames per packet;
- total channel count;
- channel offset;
- channels in fragment;
- fragment index and fragment count;
- sample format;
- channel metadata revision;
- RX/latency profile ID;
- payload byte count;
- header guard.

No retransmission in Direct Audio First. Loss produces same-deadline PLC,
silence, or repeat-last-good according to negotiated policy.

## Video Media Packet

M06 carries video fragments inside the direct media envelope. The active source
fragment includes stream ID, frame sequence number, timestamp and timestamp
basis, source role, dimensions, pixel format, frame rate, full-frame payload
byte count, fragment index/count, payload offset, frame fingerprint, and payload.
`VideoStreamDescription` separately negotiates role, resolution, frame rate,
pixel format, transport format, payload type, priority, capture state, queue
depth, and bandwidth budget.

Remaining protocol and field-evidence work:

- keep stream-description negotiation and per-fragment validation aligned
  before changing the video wire shape;
- bind negotiated drop/degradation policy to physical receiver behavior;
- add measured VideoToolbox/JPEG XS codec fields only after benchmark evidence;
- prove physical Blackmagic/ATEM TX/RX and packet-captured route behavior before
  promoting video transport to `PASS`.

Video packets are never allowed to wait on audio. Receivers drop incomplete or
late frames and keep the latest usable frame.

## Session Configuration

The accepted session must contain:

- peer IDs and session ID;
- control endpoint and media endpoints;
- negotiated audio stream descriptors;
- negotiated video stream descriptors;
- timing mode;
- latency profile;
- RX buffer profile;
- MTU and max fragment count;
- metric exchange interval;
- reconnect policy;
- shutdown deadline.

The shipped `SessionConfiguration` contains session ID, peers, audio/video
stream descriptors, latency profile, RX buffer profile, control/audio/video/
metrics endpoints, MTU, metric interval, and reconnect deadline. M06 adds
optional per-peer media endpoint assignments so two direct manual peers can bind
and connect separate audio, video, and metrics UDP sockets, then exchange
low-rate UDP `audioTiming` probes before routed audio packets.

M07 profile compatibility is explicit before media starts:

- Direct Audio First: direct RX only, no enabled video, fastest eligible.
- Balanced AV: small RX only, benchmark evidence required, not fastest eligible.
- Multi-Video Performance: small/adaptive RX, enabled video required, drop
  video before audio latency grows.
- WAN Stable: Stable/WAN RX only, continuity first, never a fastest PASS claim.

## Compatibility Policy

UDP PCM v1 remains a measurement and stereo fallback path only. MADI-scale audio
requires the v2 multichannel path or later. Legacy fallback must be explicit in
control negotiation and must emit a warning when requested channel count is
reduced.

## Security And Safety

Initial direct IP mode can use unauthenticated local control for lab use. Before
WAN or public-network use, add:

- peer identity verification;
- replay-resistant session IDs;
- rate limits for control messages;
- optional pre-shared-key authentication;
- no credential extraction, licensing bypass, DRM bypass, or binary patching.

## Tests

Implemented tests cover:

- control message JSON round trip;
- capability negotiation success and rejection;
- audio stream description validation;
- video stream description validation;
- duplicate stream ID rejection;
- media packet payload type validation;
- shutdown and error message validation.
- direct P2P session setup and media port assignment;
- media start rejection before accepted session configuration;
- media envelope sequence, timestamp, stream ID, payload type, and nested audio
  validation;
- packet loss and jitter metric accounting;
- reconnect after media socket failure;
- idempotent shutdown;
- audio media not being sent over the control channel;
- session profile/RX compatibility for Direct Audio First, Balanced AV,
  Multi-Video Performance, and WAN Stable;
- M07 benchmark telemetry and fastest-PASS rejection for buffered session
  profiles.

## Resume here

Continue M06 with a physical two-peer direct LAN/manual-address run and
physical MADI evidence. Source-level localhost, socket-backed, and manual
endpoint commands are implemented, but they are not direct LAN `PASS` evidence
without packet-captured two-Mac field reports.

VERDICT: PARTIAL
