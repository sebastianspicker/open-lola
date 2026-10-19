# Audio routing

In code today: the macOS runtime has multichannel packetization and reassembly,
route descriptors, and receiver-mix and RME matrix metadata models. Full-duplex
RME/MADI playback, gain behavior, and stability at high channel counts have not
been tested on hardware.

A route keeps stream identity and channel order and records every change it
makes. Channels are never silently dropped, reordered, duplicated, or mixed.

## Evidence Labels

| Rule | Label |
|---|---|
| Core Audio device and channel metadata | `public API` |
| Channel numbering and AoIP terminology | `public standard` |
| Route descriptors, metadata revisions, and receiver-mix behavior | `original open-lola design` |
| Hardware-specific mapping and gain acceptance | `experimentally derived requirement` |

## Route model

A route maps a session stream ID to an ordered source channel range, its packet
fragments, an ordered destination channel range, and optional receiver mix
metadata. Channel descriptors have stable IDs and labels. Metadata carries a
revision number, so a route can change without reordering packets inside one
audio deadline.

There are two modes:

- identity (send-all): keeps the negotiated channel order from capture to output;
- matrix: metadata describes routes and gains the operator chose.

Matrix and mix processing happen outside the realtime transport framing. Missing
or invalid metadata never triggers a remap. Gain and mute changes are bounded,
validated, and reported.

## Invariants

- The negotiated total channel count matches the fragment ranges.
- Channel offsets and ranges are in bounds and do not overlap within one audio
  deadline.
- A block is complete before it goes to playback.
- Receiver mixes refer only to known stream and channel IDs.
- Falling back to fewer channels is visible.
- Route changes never block the audio callback.

See [multichannel-transport.md](multichannel-transport.md) for wire
fragmentation and [rx-buffering.md](rx-buffering.md) for receive policy.

VERDICT: PARTIAL
