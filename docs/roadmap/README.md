# Public Roadmap

Date: 2026-05-11
Status: condensed public roadmap
Verdict: PARTIAL

This is the active public roadmap. Detailed M01-M15 roadmap exports were
superseded and archived under
`../../archive/2026-05-11-doc-condense/docs/roadmap/`.

## Roadmap

| Lane | Current posture | Evidence required before PASS |
|---|---|---|
| Core source and CLI | Source-level implemented. | Keep tests and docs green. |
| RME/Core Audio path | Source-level implemented; physical evidence open. | RME/MADI devices, AudioDeviceIOProc/AUHAL path evidence, loopback, and packet metrics. |
| UDP/P2P transport | Source-level implemented; route evidence open. | Two-Mac packet capture, DSCP/PTP facts, jitter/loss/underrun/overrun reports. |
| RX buffering and latency profiles | Source-level implemented; physical benchmark open. | Same-route direct/small/adaptive/stable-WAN measurements. |
| Video and control | Source-level partial. | Blackmagic/ATEM or reviewed capture path, OSC peer, sACN/Art-Net safety gate, and audio-impact proof. |
| App, recording, packaging | Source-level partial. | Launched app evidence, raw recording stress, Developer ID, notarization, Gatekeeper, and clean-Mac proof. |
| Release | Blocked. | License, notices, fixture provenance, reviewer signoff, and public release approval. |

## Rules

- Public docs must describe original open-lola design, public standards, public
  APIs, or measured evidence.
- Archived roadmap or review files are trace evidence only.
- `PARTIAL` remains the product verdict until real hardware, route, signing,
  release, and clean-Mac gates close.

## Resume Here

Use [../current-state.md](../current-state.md) for public status and
[../mac-port/README.md](../mac-port/README.md)
for internal execution commands.

VERDICT: PARTIAL
