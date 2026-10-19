# Multichannel transport

In code today: the macOS runtime implements UDP PCM v2 fragmentation and
reassembly and runs it over localhost. High channel counts over a physical
network have not been measured.

Large channel sets are sent as fragments, each carrying a contiguous channel
range for one audio deadline. All channels share one clock and one queue.

## Evidence Labels

| Transport property | Label |
|---|---|
| UDP, MTU, sequence, timestamp, DSCP, PTP, and AVB concepts | `public standard` |
| UDP PCM v2 fields, stream IDs, metadata revisions, and reassembly policy | `original open-lola design` |
| Accepted channel count, loss, and timing thresholds | `experimentally derived requirement` |

## Packet format

A UDP PCM v2 packet identifies:

- session stream and audio deadline;
- sequence and timestamp;
- sample format and rate;
- total channel count, channel offset, and channel count;
- fragment index and fragment count;
- metadata revision and payload length.

Each fragment holds a contiguous channel range for the same frame block and fits
in the configured MTU.

The receiver validates the envelope and nested audio metadata, groups fragments
by stream and deadline, and rejects overlaps or inconsistent metadata. It emits a
block only when the required range is complete. Stale and late blocks are dropped
according to the RX profile. UDP PCM v1 is a smaller format for diagnostics and
fallback; it is not meant for MADI-scale channel counts.

## Capability negotiation

Before media starts, peers agree on sample rate, sample format, total channels,
frames per block, MTU, stream IDs, route metadata, and the RX and latency
profiles. Unsupported values, or a fallback to fewer channels, must produce a
reject or a warning. The runtime never silently reshapes audio.

## Scheduling

- All fragments for one deadline share the same timing fields.
- Packetization and reassembly use bounded storage.
- Nothing is retransmitted on the Direct Audio First path.
- Loss, incomplete deadlines, late drops, jitter, and queue pressure are counted.
- Video and low-rate control traffic back off before audio timing suffers.

Hardware claims follow the [benchmark methodology](benchmark-methodology.md).

VERDICT: PARTIAL
