# Multichannel Transport Plan

Date: 2026-05-04  
Status: source implementation complete; physical route evidence pending  
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| UDP PCM v1 compatibility path | `compatibility requirement` |
| UDP PCM v2 channel-range fragments | `original open-lola design` |
| MTU-safe deadline fragmentation | `experimentally derived requirement` |
| Capability negotiation before media start | `implementation hypothesis` |

## Current Transport State

UDP PCM v1 is an original open-lola packet format with:

- magic and version;
- sample format;
- channel count;
- frames per packet;
- sample rate;
- sequence number;
- sender frame index;
- sender host time;
- payload byte count;
- guard;
- raw payload.

It has no channel metadata, no channel order contract beyond implicit payload
layout, no fragmentation, and no capability negotiation. It remains the legacy
stereo compatibility path.

The current source defines and tests a v2 source implementation:

- protocol version choices `udpPcmV1` and `udpPcmV2`;
- channel descriptors and channel sets;
- latency and RX buffer profile identifiers;
- capability negotiation;
- v2 MTU fragment planner;
- v2 packet encode/decode;
- 2/8/16/32/64-channel captured-payload packetization and reassembly;
- missing and duplicate fragment accounting;
- receiver mix snapshot preparation;
- optional matrix metadata snapshots and rate-limited metadata updates.

Direct socket certification remains future physical evidence. The source hook
`RealtimeAudioPacketHandoff.sendNextPacket()` and `sendNextV2Packets(mode:)`
emit captured payloads from preallocated handoff slabs without changing the
legacy v1 packet contract.

## Capability Negotiation

The control channel must negotiate:

- protocol version;
- sample rate;
- frames per packet;
- selected channel count and channel descriptors;
- sample format;
- wire packing mode;
- MTU and maximum fragments per deadline;
- latency profile;
- RX buffer profile;
- metadata support and metadata revision.

Negotiation is exact for v2. If exact v2 cannot be accepted, the peer either
rejects with a reason or falls back to explicit stereo v1 when both sides
support it.

## Packet Layout Direction

UDP PCM v2 media should carry one audio deadline split into channel fragments:

| Field | Purpose |
|---|---|
| stream ID | distinguish media streams |
| total channel count | reconstruct deadline shape |
| channel offset | first channel in this fragment |
| channels in fragment | channel count in this fragment |
| frames per packet | audio deadline size |
| sample rate | mode validation |
| sample format | payload interpretation |
| fragment index/count | loss accounting and reassembly |
| metadata revision | control-plane correlation |
| packing mode | interleaved channel range initially |
| sequence number | deadline identity |
| sender frame index | drift and playout mapping |
| sender host time | packet age and telemetry |
| payload length | validation |
| guard | malformed packet rejection |

The planner must keep every datagram below the configured MTU and must never
depend on IP fragmentation.

## Channel Order

Channel order is negotiated descriptor order sorted by stable source index.
Names are metadata. They do not define order.

Default labels:

- `input-1`, `input-2`, ... for sender channels;
- `output-1`, `output-2`, ... for receiver outputs.

Optional labels can come from user configuration or public documented RME
metadata.

## Pacing And Loss

Sequence numbers remain deadline-based. Fragment IDs distinguish partial
deadline loss from whole deadline loss.

Rules:

- send all fragments for a deadline inside that deadline's pacing window;
- reject modes whose fragment count cannot fit the deadline;
- do not wait for retransmission in fastest profiles;
- drop late fragments after deadline;
- count lost fragments and lost deadlines separately;
- report packet age, jitter, late, lost, duplicate, and reordered counts.

## Receiver Mix Control

Receiver mix control belongs on the control channel:

- identity mix by default;
- gain, mute, pan, and route maps as precomputed snapshots;
- no UI or matrix work in the audio callback;
- no sender-side forced downmix unless explicitly configured.

## Tests

Required tests:

- v2 packet header round trip: implemented;
- malformed v2 packets: implemented;
- 2/8/16/32/64-channel fragment round trip: implemented;
- selected channel map ordering: implemented;
- metadata revision propagation: implemented;
- fragment loss accounting: implemented;
- v1 fallback warning: implemented;
- rejected v2 when MTU or fragment budget is impossible: implemented;
- receiver mix precompute and snapshot replacement: implemented;
- optional RME metadata serialization and rate limiting: implemented.

## Resume here

Resume at two-machine route evidence. The source contracts are complete enough
to run a physical v2 packet-capture trial, but `PASS` still requires RME/MADI
hardware proof.

VERDICT: PARTIAL
