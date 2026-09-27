# Multichannel transport

Status: source and localhost packet contracts implemented
Verdict: PARTIAL

Open LoLa transports large channel sets as bounded channel-range fragments for one
audio deadline. The design avoids treating every channel as an independent clock
or queue.

## Evidence Labels

| Transport property | Label |
|---|---|
| UDP, MTU, sequence, timestamp, DSCP, PTP, and AVB concepts | `public standard` |
| UDP PCM v2 fields, stream IDs, metadata revisions, and reassembly policy | `original open-lola design` |
| Accepted channel count, loss, and timing thresholds | `experimentally derived requirement` |

## Packet model

UDP PCM v2 identifies the session stream, audio deadline, sequence and timestamp,
sample format and rate, total channel count, channel offset and count, fragment
index and count, metadata revision, and payload length. Each fragment carries a
contiguous channel range for the same frame block and stays within the configured
MTU.

The receiver validates the envelope and nested audio metadata, groups fragments
by stream and deadline, rejects overlaps or inconsistent metadata, and emits a
block only when the required range is complete. Stale and late assemblies are
dropped according to the RX profile. UDP PCM v1 remains a smaller diagnostic or
fallback path, not the MADI-scale contract.

## Capability negotiation

Peers agree on sample rate, sample format, total channels, frames per block, MTU,
stream IDs, route metadata, and RX and latency profile before media starts.
Unsupported values or a channel-reducing fallback require an explicit reject or
warning; the runtime may not silently reshape audio.

## Scheduling

- All fragments for a deadline share timing identity.
- Packetization and reassembly use bounded storage.
- No retransmission delays the Direct Audio First path.
- Loss, incomplete deadlines, late drops, jitter, and queue pressure are counted.
- Video and low-rate control traffic yield before audio timing degrades.

Localhost delivery validates code paths but not physical high-channel throughput,
network QoS, switch behavior, or device playback. Hardware claims must follow
[benchmark methodology](benchmark-methodology.md).

VERDICT: PARTIAL
