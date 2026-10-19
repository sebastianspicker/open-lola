# Open LoLa protocol

This is Open LoLa's own direct-peer control and media protocol, implemented in
the macOS runtime and tested on localhost. It is separate from the LoLa
compatibility behavior in the Rust station and the macOS LoLa connector.

## Evidence labels

| Protocol element | Label |
|---|---|
| UDP, monotonic time, sequence numbers, stream IDs, DSCP, and PTP concepts | `public standard` |
| Message names, JSON fields, media envelopes, packet headers, and profile rules | `original open-lola design` |
| Physical performance thresholds | `experimentally derived requirement` |

## Control plane

Control messages are compact, deterministic JSON, sent outside the audio
callback. Message types cover:

- peer identity and capabilities;
- session proposal, acceptance, and rejection;
- audio metadata;
- media start and pause;
- metrics, errors, and shutdown.

An accepted configuration names the session, peers, audio and video streams,
latency and RX profiles, endpoints, MTU, metrics interval, and reconnect
deadline.

A peer rejects incompatible profiles, duplicate or invalid stream IDs, malformed
endpoints, unsupported formats, and any media start before the session is
accepted. Audio metadata is advisory; safe playback never depends on it.

## Media plane

The UDP media envelope carries protocol version, payload type, stream, sequence,
monotonic timestamp, and a bounded payload length. Payload types are
multichannel PCM fragments, timing and metrics, raw or codec video fragments,
and keepalive.

UDP PCM v2 splits one audio deadline into contiguous channel ranges that share
sample, format, and timing fields. Video fragments carry frame identity,
dimensions, format, payload offsets, and a fingerprint. Before delivering
anything, the receiver checks nested metadata, source and stream identity,
bounds, completeness, duplicates or stale data, and the profile policy.

The fastest media paths never retransmit. Audio applies the negotiated loss
behavior, and video drops incomplete or expired frames. Media never travels on
the control socket.

UDP PCM v1 is a smaller format for diagnostics and fallback. Any channel
reduction or fallback to v1 must be visible. Migrations of saved reports follow
[source contracts](source-contracts.md).

## CLI probes

The macOS CLI can run source, synthetic, localhost, and manual-address probes for
capability negotiation, two-peer sessions, mesh topology and runtime, latency
profiles, RX buffering, and AV transport. Each probe writes a report ending in a
verdict line. A localhost report stays `PARTIAL` for any physical or
reference-peer claim.

## Security

The protocol does not authenticate peers, prevent replay, or protect media
confidentiality or integrity. Use it only on trusted, isolated networks as
described in [SECURITY.md](../SECURITY.md).
