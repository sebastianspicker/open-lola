# Lighting and control

Status: OSC and safety/report contracts implemented; fixture output unproved
Verdict: PARTIAL

Lighting and show control are secondary synchronized paths. They may reference
audio timing but never execute blocking or unbounded work on the audio callback.

## Evidence Labels

| Control surface | Label |
|---|---|
| OSC, MIDI, Art-Net, sACN, and DMX terminology | `public standard` |
| Cue reports, arming state, allowlists, and failure policy | `original open-lola design` |
| Fixture timing and audio-impact thresholds | `experimentally derived requirement` |

## Current source

The macOS source implements OSC message parsing, UDP loopback and external report
shapes, timing summaries, audio-impact validation, and lighting safety and report
models for Art-Net and sACN-style fixture workflows. It also exposes a read-only
ATEM reachability probe. These paths can validate source and localhost behavior;
they do not establish a real bridge, fixture, universe, or external peer.

## Safety boundary

Live output requires explicit arming, an isolated or approved network, a
destination and universe allowlist, named fixture or bridge ownership, blackout
or hold and drop behavior, a capture point, and an audio-active comparison.
Broadcast or multicast traffic must not share a performance media network unless
the specific topology has been reviewed and measured.

The runtime must record whether the result came from synthetic input, localhost
OSC, an external OSC peer, packet capture, or physical fixture observation.
Missing external evidence produces `PARTIAL`, not an inferred pass.

VERDICT: PARTIAL
