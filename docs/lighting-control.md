# Lighting and control

In code today: the macOS runtime parses and sends OSC cues over UDP, reports
their timing and audio impact, and has a lighting safety gate that decides
whether Art-Net or sACN output would be allowed. It does not send Art-Net or sACN
packets, and no fixture, bridge, or external peer has been tested.

Lighting and show control may follow audio timing but never run blocking or
unbounded work on the audio callback.

## Evidence Labels

| Control area | Label |
|---|---|
| OSC, MIDI, Art-Net, sACN, and DMX terminology | `public standard` |
| Cue reports, arming state, allowlists, and failure policy | `original open-lola design` |
| Fixture timing and audio-impact thresholds | `experimentally derived requirement` |

## What the code does

- OSC message parsing, UDP loopback runs, and external OSC peer runs, with
  timing summaries and audio-impact checks;
- lighting safety and report models for Art-Net and sACN fixture workflows;
- a read-only ATEM reachability probe.

## Safety rules for live output

Before any live output you need:

- arming by the operator;
- an isolated or approved network;
- an allowlist of destinations and universes;
- a named owner for each fixture or bridge;
- defined blackout, hold, and drop behavior;
- a capture point;
- a comparison with audio running.

Keep broadcast and multicast traffic off the performance media network unless
that exact topology has been reviewed and measured.

Each result records where it came from: synthetic input, localhost OSC, an
external OSC peer, a packet capture, or watching a physical fixture. Without
external evidence the result is `PARTIAL`, never an assumed pass.

VERDICT: PARTIAL
