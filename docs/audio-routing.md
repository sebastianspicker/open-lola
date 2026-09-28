# Audio routing

Status: source-level route and receive-mix contracts implemented
Verdict: PARTIAL

Audio routes preserve stream identity, channel order, and evidence about every
explicit transformation. The runtime must not silently truncate, reorder,
duplicate, or mix negotiated channels.

## Evidence Labels

| Rule | Label |
|---|---|
| Core Audio device and channel metadata | `public API` |
| Channel numbering and AoIP terminology | `public standard` |
| Route descriptors, metadata revisions, and receiver-mix behavior | `original open-lola design` |
| Hardware-specific mapping and gain acceptance | `experimentally derived requirement` |

## Route model

A route binds a session stream ID to an ordered source channel range, packet
fragments, an ordered destination channel range, and optional receiver mix
metadata. Channel descriptors carry stable IDs and labels, and metadata revisions
allow changes without changing packet order mid-deadline.

Two principal modes exist:

- identity or send-all preserves negotiated channel order from capture to output;
- explicit matrix metadata describes operator-selected routes and gains.

Matrix or mix behavior belongs outside the realtime transport framing. Missing or
invalid metadata must not cause an implicit remap, and gain and mute changes are
bounded, validated, and reportable.

## Invariants

- Negotiated total channel count and fragment ranges agree.
- Every channel offset and range is in bounds and non-overlapping for one audio
  deadline.
- Reassembly completes before a block is offered to playback.
- Receiver mix references known stream and channel identities.
- Fallback to fewer channels is explicit and visible.
- Route changes never block the audio callback.

The current source supports multichannel packet and reassembly and receiver
routing models. Physical full-duplex RME/MADI playback, gain behavior, and
high-channel stability remain unproved.

Wire fragmentation is documented in
[multichannel-transport.md](multichannel-transport.md) and receive policy in
[rx-buffering.md](rx-buffering.md).

VERDICT: PARTIAL
