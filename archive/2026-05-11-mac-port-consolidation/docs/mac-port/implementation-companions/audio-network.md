# Audio And Network Companion

Date: 2026-05-05
Status: active domain companion for audio and route evidence
Verdict: PARTIAL

Canonical status lives in
[../IMPLEMENTATION_COMPANION.md](../IMPLEMENTATION_COMPANION.md). This file
collects the audio and network details previously spread across M01-M07,
F01-F04, F11, F12, report notes, and old milestone files.

## Scope

Covered lanes:

- M01 hardware/reference rig and Q001.
- M02 Core Audio inventory.
- M03 fastest endpoint loopback and Q002-Q003.
- M04 UDP PCM packet contract.
- M05 direct peer-to-peer route, F03, F11, Q004, and Q012.
- M06 drift and same-deadline PLC, F04.
- M07 PTP, AVB, AES67, RAVENNA, Dante, WCRT, and Q005-Q006.
- F12 self-hosted rendezvous, direct traversal, UDP forwarder/relay fallback,
  and Q011.
- Public MXX multichannel routing, low-buffer profiles, and RX buffering.

## Current Source Surfaces

| Area | Source-level state | PASS blocker |
|---|---|---|
| Hardware baseline | Reference-rig schema, fixtures, validators, and hardware-validation aggregate gates exist. | Real reference Macs, RME MADI model, driver, firmware, TotalMix state, UIDs, clock, channel labels, route labels, DSCP policy, and thresholds. |
| Core Audio inventory | Device inventory model and CLI output exist. | RME or equivalent target must be visible outside sandbox. |
| Realtime audio | Report schemas, callback-safety guards, AudioDeviceIOProc/AUHAL planning, and local RX-buffer benchmark rows for Direct/Small/Adaptive/Stable-WAN exist. | Measured RME callback ownership, no allocation/lock/log/file I/O in callback, packet handoff on accepted route, and same-route RX-buffer benchmark evidence. |
| UDP PCM | Packet v1/v2 contracts, fragments, receiver-local mix snapshots, localhost smokes, and socket-backed full-duplex receiver-mix report evidence exist. | Physical two-Mac sender/receiver and byte-exact loopback reports with packet capture. |
| Route diagnostics | UDP echo, ICMP, traceroute, DSCP/capture fields, and session validators exist. | Direct, switch, campus, and ISP/NAT measurements where permitted. |
| Drift/PLC | Same-deadline PLC and fixed-target certification contracts exist. | 60-minute run on accepted engine and route with artifact notes plus same-hardware LoLa baseline. |
| AoIP/PTP | Report gates for PTP/AVB/AES67/RAVENNA/Dante profile evaluation exist. | Real PTP lock state, switch/endpoints, profile clauses, and stress comparison against direct UDP PCM. |
| NAT/ISP | Self-hosted rendezvous, direct traversal, relay fallback, forwarder launcher warning, and raw-P2P preference guards exist. | Real two-client NAT/ISP evidence; relay/forwarder remains compatibility evidence only. |
| External connectors | LoLa control UDP/TCP TX/RX from local RE facts and public manual version differences with numeric SID handling, recovered template terminators, status-check ACK, explicit audio/video quick-connect fields, quick-connect ACK exchange, visible reject/disconnect/chat/bounce-back/generated-signal control message builders, configured-source-port UDP control TX for remote peers with wildcard bind fallback for NAT-advertised source IPs, advertised-host preflight notes for likely NAT/public-IPv4 mismatches, outer Ethernet/IPv4/UDP wire framing, source-level media body serialization, normal audio/video fragments, video prelude packets, source-level media TX/RX reports attached to LoLa session artifacts, explicit simultaneous LoLa `tx-rx` media evidence, post-control UDP socket media TX/RX for IP-routed LoLa attempts, opt-in raw-link media TX/RX wiring inside LoLa connector sessions, macOS BPF raw-link TX/RX runners with memory-backed dry-run coverage and bounded RX timeouts, source-level synthetic packet fixture generation with optional pcap output round-tripped through the passive decoder, real LoLa control-attempt failure reports with structured runtime errors plus partial sent/received control-message traces, and a passive pcap/pcapng capture decoder that labels audio fragments, video preludes, video fragments, MJPEG candidates, malformed fragments, and unknown payloads without overclaiming compatibility, MVTP/UltraGrid `uv` simultaneous `tx-rx` audio/video launch plans with configurable capture/playback/display modules, JackTrip RtAudio `tx-rx` launch plans with explicit queue/redundancy, bind port, peer audio port, sample-rate, and buffer-size settings, JackTrip P2P server/client connection plans, JackTrip Docker wrapper mapping sample-rate and buffer-size into the container JACK environment, JackTrip-plus-auxiliary-UltraGrid video plans for AV mode with configurable video modules and grouped audio/video process start, bidirectional connection-plan reports that emit parseable endpoint commands for local and remote A/V attempts with port/timing/video-profile overrides, PATH executable defaults, and LoLa raw-link interface/MAC tuples for both peers, external-process launch/non-zero-exit FAIL artifacts, media-mode validation, CLI runner, validator, report schema, and tests exist. LoLa source-level grammar is implemented; real Windows LoLa interoperability remains PARTIAL until measured Windows-originated media captures validate it. | Selected external endpoints, command transcripts, measured route captures, latency comparison, LoLa media packet captures, Windows-originated media captures, and packet-capture review before any interoperability PASS. |

## Next Action

1. Close Q001 with real hardware and route labels.
2. Run Core Audio inventory outside the sandbox and record the RME MADI UIDs.
3. Run the M03/G02 loopback matrix across accepted sample rates and buffer
   sizes.
4. Certify a direct two-Mac UDP PCM route with packet capture, packet age, loss,
   jitter, DSCP classification, and no hidden playout growth.
5. Include `direct-p2p-session-run` control/media evidence in the physical
   direct-LAN proof.
6. Include `madi-full-duplex-run --receiver-mix swap-stereo` in the physical
   RME receive proof.
7. Repeat `rx-buffer-benchmark-run` on the same physical RME/direct route for
   Direct, Small, Adaptive, and Stable/WAN profile rows.
8. Run F11 byte-exact loopback and compare UDP echo RTT with ICMP/traceroute.
9. Run M06 drift/PLC only after F02 and F03 are measured PASS.
10. Treat F12 NAT/relay/forwarder evidence as compatibility-only unless raw P2P
   evidence exists and remains faster.

## Archive Pointers

The older audio, route, drift, buffering, and benchmark files are preserved under
[../../archive/2026-05-05-doc-consolidation/mac-port/](../../archive/2026-05-05-doc-consolidation/mac-port/).
Use them only to trace superseded audio/network decisions.

## Resume here

Resume here: start with Q001, then M03/G02, F02, F03/M05, F11, F12, F04/M06,
and M07 in that order.

VERDICT: PARTIAL
