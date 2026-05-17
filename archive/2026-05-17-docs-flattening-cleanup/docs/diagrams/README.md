# Diagrams

Date: 2026-05-05  
Status: publication-safe diagram index  
Verdict: PARTIAL

This area is the public-safe index for architecture and validation diagrams.
It keeps diagram ownership explicit without exposing raw reverse-engineering
evidence.

## Active Diagram Sources

Current architecture diagrams and visual models are text-owned in these public
documents:

- [../architecture/latency-first-architecture.md](../architecture/latency-first-architecture.md)
- [../architecture/p2p-networking.md](../architecture/p2p-networking.md)
- [../architecture/audio-routing.md](../architecture/audio-routing.md)
- [../architecture/rx-buffering.md](../architecture/rx-buffering.md)
- [../architecture/video-blackmagic-atem.md](../architecture/video-blackmagic-atem.md)
- [../architecture/av-sync-and-timing.md](../architecture/av-sync-and-timing.md)

## Diagram Rules

- Public diagrams may show original open-lola architecture, public API
  boundaries, benchmark flow, and release gates.
- Public diagrams must not show proprietary packet grammar, private addresses,
  hashes, binary-derived strings, or generated static-analysis output.
- If a diagram depends on a measurement, cite the measured report or mark the
  diagram as a hypothesis.

Resume here: add rendered diagrams only after the text-owned architecture
source and evidence label are current.

VERDICT: PARTIAL
