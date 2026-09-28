# Open LoLa protocol

Status: implemented source and localhost contracts
Verdict: PARTIAL

This document describes Open LoLa's own direct-peer control and media protocol.
It is separate from the LoLa compatibility behavior implemented by the Rust
station and Linux connector.

## Evidence Labels

| Protocol element | Label |
|---|---|
| UDP, monotonic time, sequence numbers, stream IDs, DSCP, and PTP concepts | `public standard` |
| Message names, JSON fields, media envelopes, packet headers, and profile rules | `original open-lola design` |
| Physical performance thresholds | `experimentally derived requirement` |

## Control plane

Control messages are deterministic compact JSON sent outside the audio callback.
They cover peer identity, capabilities, session proposal, acceptance, and
rejection, audio metadata, media start and pause, metrics, errors, and shutdown.
An accepted configuration identifies the session, peers, audio and video streams,
latency and RX profiles, endpoint sets, MTU, metrics interval, and reconnect
deadline.

Peers reject incompatible profiles, duplicate or invalid stream IDs, malformed
endpoints, unsupported formats, and media start before session acceptance. Audio
metadata is advisory and cannot be required for safe playback.

## Media plane

The UDP media envelope identifies protocol version, payload type, stream,
sequence, monotonic timestamp, and bounded payload length. Payload types cover
multichannel PCM fragments, timing and metrics, raw or codec video fragments, and
keepalive behavior.

UDP PCM v2 splits one audio deadline into contiguous channel ranges that share a
sample, format, and timing identity. Video fragments carry frame identity,
dimensions, format, payload offsets, and a fingerprint. Before delivery,
receivers validate nested metadata, source and stream identity, bounds,
completeness, duplicate or stale data, and profile policy.

There is no reliable retransmission on the fastest media paths. Audio applies the
negotiated loss behavior, and video drops incomplete or expired frames. Media
never travels on the control socket.

## Runtime and compatibility

The macOS CLI supports source, synthetic, localhost, and manual-address probes for
capability negotiation, direct two-peer sessions, mesh topology and runtime,
latency profiles, RX buffering, and AV transport. These commands produce reports
with final verdict lines. A localhost report remains `PARTIAL` for physical and
reference-peer claims.

UDP PCM v1 remains a smaller diagnostic and fallback format. Any channel
reduction or legacy fallback must be explicit. Persisted report migrations are
governed by [source contracts](source-contracts.md).

## Security

The current protocol does not authenticate peer identity, prevent replay, or
provide media confidentiality and integrity. Direct operation is restricted to
trusted, isolated networks as described in [SECURITY.md](../SECURITY.md).

VERDICT: PARTIAL
