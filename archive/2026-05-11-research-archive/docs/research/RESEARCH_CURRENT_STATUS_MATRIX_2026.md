# Open Lola Current Evidence Status Matrix 2026

Date: 2026-05-11
Status: current docs-safe evidence crosswalk
Verdict: PARTIAL

This matrix compares the current project state with the active research
evidence matrix, benchmark roadmap, reverse-engineering boundary, and Mac-port
handoff. It is an execution bridge: use it to see what is already done, what is
still only source-level, and which real-world test tasks must close before any
runtime or release `PASS` claim.

## Evidence Sources Used

| Source | Role |
|---|---|
| [../current-state.md](../current-state.md) | Current product status and public evidence policy. |
| [README.md](README.md) | Active research lane and research-to-implementation gate summary. |
| [RESEARCH_EVIDENCE_MATRIX_2026.md](RESEARCH_EVIDENCE_MATRIX_2026.md) | Research matters 1-85, cross-item decisions, and required probes. |
| [RESEARCH_BENCHMARK_ROADMAP_2026.md](RESEARCH_BENCHMARK_ROADMAP_2026.md) | Measurement gates 0-6 and pass/fail criteria. |
| [../mac-port/README.md](../mac-port/README.md) | Current Mac-port implementation state, completed work, missing evidence. |
| [../mac-port/open-questions.md](../mac-port/open-questions.md) | Q001-Q012 runtime, hardware, route, and release blockers. |
| [../reverse-engineering/README.md](../reverse-engineering/README.md) | Public-safe reverse-engineering status and publication boundary. |
| [../../private/reverse-engineering/README.md](../../private/reverse-engineering/README.md) | Private evidence lane; use only for internal validation, not public release wording. |
| [../testing/README.md](../testing/README.md) | Active source verification, CLI probes, and manual evidence gates. |

## Status Legend

| Status | Meaning |
|---|---|
| DONE | Complete for source/docs/local validation and not blocked by current scope. |
| SOURCE-DONE | Implemented at source/test/report level, but real-world evidence is missing. |
| PARTIAL | Some source or evidence exists, but the lane cannot claim runtime PASS. |
| MISSING | Required real-world evidence or operator input is absent. |
| DEFERRED | Deliberately not a default implementation path yet. |
| BLOCKED | Cannot proceed to PASS until user, hardware, legal, or release input exists. |

## Current Crosswalk Matrix

| Lane | Research / RE finding | Current implementation status | Done now | Missing before PASS | Real-world task |
|---|---|---|---|---|---|
| Measurement rig | Gate 0 requires stable device identity, repeatable loopback, comparable reports, and packet timing. | PARTIAL | Report schemas, validators, preflight reports, docs gates, and placeholder fixtures exist. | Reference Macs, RME/MADI identity, route labels, capture points, DSCP/PTP policy, and thresholds. | RWT-001 |
| Core Audio / RME | Research adopts Core Audio HAL/AUHAL/IOProc, accepted buffer probing, measured latency, and callback safety. | SOURCE-DONE | Core Audio inventory, device abstractions, callback-oriented contracts, source validators, and local/synthetic reports exist. | RME/MADI loopback, accepted physical frame sizes, callback p99/max on target hardware, analog latency. | RWT-002 |
| UDP/P2P transport | Research adopts direct UDP PCM on wired measured paths and one packet per audio block. | SOURCE-DONE | UDP PCM packet contracts, direct P2P reports, control/media report surfaces, local/socket-backed probes, and RX-buffer profiles exist. | Two-Mac packet captures, packet age, jitter/loss, underrun/overrun, fixed target proof on the same route. | RWT-003 |
| RX buffering / latency profiles | Research rejects hidden buffer growth and requires explicit latency cost. | SOURCE-DONE | Direct, small, adaptive, and stable-WAN profiles exist with visible latency policy. | Same-route direct/small/adaptive/stable-WAN measurements and proof of justified profile choice. | RWT-004 |
| PLC and drift | Research allows silence or same-deadline PLC only inside the already-due audio block. | PARTIAL | Drift and same-deadline PLC constraints exist in source contracts and tests. | Hardware-route drift telemetry, bounded PLC CPU timing, and long-run fixed-target proof. | RWT-005 |
| DSCP/PTP/AoIP | Research requires route classification and explicit PTP/AVB/TSN/AES67/RAVENNA/Dante evidence. | PARTIAL | DSCP/QoS, PTP, AVB/TSN, AES67/RAVENNA/Dante gates and report shapes are documented. | Measured DSCP classification, PTP profile/domain/master, switch stress cases, endpoint interop latency. | RWT-006 |
| Video | Research keeps video subordinate to audio and requires degradation before audio timing changes. | PARTIAL | AVFoundation/test-pattern source paths, source-level video transport, and reporting surfaces exist. | Blackmagic/ATEM or reviewed capture proof, video under audio stress, degradation-before-audio evidence. | RWT-007 |
| Lighting / show control | Research adopts OSC first and gates sACN/Art-Net/DMX-family work behind isolation and standards review. | PARTIAL | OSC and lighting protocol gates are documented; OSC-first policy exists. | OSC peer timing, isolated OLA/QLC+ one-universe probes, packet capture, blackout behavior, fixture metadata validation. | RWT-008 |
| Windows LoLa compatibility | Reverse engineering is useful evidence, not a compatibility claim; static/Mac-confirmable checks are done, Windows runtime gates remain open. | SOURCE-DONE / PARTIAL | Static corpus classification, parser/builder behavior, synthetic fixture plan, Linux-seed layout handling, and passive decode surfaces exist. | Windows-originated control/media captures, ASIO/WinPcap/camera timing, 44.1/48 kHz interop, loss/reconnect behavior. | RWT-009 |
| App / recording / operator surface | Current app shell and reports are source-level; field behavior still needs runtime evidence. | PARTIAL | SwiftUI app shell, operator surfaces, release-readiness reports, and recording/report fields exist. | Launched app evidence with real devices, raw recording stress, packet/report artifacts from a physical session. | RWT-010 |
| Release / field closure | Release requires allowlisted artifacts, license/notices, provenance, signing, notarization, clean-Mac evidence, and review. | BLOCKED | Release-readiness reports, release hygiene scripts, docs boundaries, and archive boundaries exist. | Final license/notices, fixture provenance, reviewer approval, Developer ID, notarization, Gatekeeper, clean-Mac launch. | RWT-010 |

## Real-World Test Matrix

| Task | Blocks | Required evidence | Acceptance condition |
|---|---|---|---|
| RWT-001 Hardware Baseline | Q001 | Reference Macs, macOS builds, RME/MADI model, driver/firmware, TotalMix state, Core Audio UIDs, route labels, packet-capture points, DSCP/PTP policy, cabling, PASS thresholds. | Hardware and route identity is stable enough that later reports are comparable. |
| RWT-002 Core Audio Loopback | Q002-Q003 | Accepted 16/32/64/128 frame sizes, sample-rate matrix, callback p50/p95/p99/max, missed deadlines, reported latency, analog round-trip and corrected one-way latency. | Selected fastest profile is physically proven without hidden conversion or callback overruns. |
| RWT-003 Two-Mac UDP/P2P | Q004 | Direct wired route, control/media transcript, packet capture, packet age at playout, jitter/loss/reordering, underrun/overrun, fixed receive target. | Direct UDP/P2P stays inside selected playout target on the measured route. |
| RWT-004 RX Buffer Profiles | Q004, Q012 | Same physical route measured with direct, small, adaptive, and stable-WAN profiles; latency cost and recovery behavior recorded. | Each profile has a measured use case and no hidden default growth. |
| RWT-005 PLC And Drift | Q002-Q004 | Silence/repeat/PLC timing, sender/receiver frame drift, bounded CPU timing, long-run fixed-target report. | Concealment or drift handling never increases default audio playout latency. |
| RWT-006 Network Timing And AoIP | Q005-Q006, Q012 | DSCP honored/rewritten/ignored/harmful classification, PTP profile/domain/master, switch and endpoint identities, AVB/TSN stress, AES67/RAVENNA/Dante comparison where available. | Interop or deterministic-network mode is correctly labeled and does not replace direct UDP without measured superiority. |
| RWT-007 Video | Q007 | Camera permission, Blackmagic/ATEM or AVFoundation target identity, capture route, frame age/drop counts, audio p99/max under video load, packet capture. | Video improves presence/cueing while dropping or degrading before audio timing changes. |
| RWT-008 Lighting And Show Control | Q008-Q009 | OSC peer timing, isolated universe, OLA/QLC+ Art-Net or sACN probe, packet capture, blackout/hold/drop behavior, fixture metadata validation. | Lighting/control has measured cue behavior and no audio packet/callback impact. |
| RWT-009 Windows LoLa Compatibility | WV01-WV10 | Windows-originated control and media captures, ASIO buffer timing, XIMEA/PtGrey observations where applicable, WinPcap scheduling, 44.1/48 kHz sessions, loss/reconnect/bounce/generated-signal observations. | Compatibility wording remains PARTIAL unless WV01-WV08 at minimum are attached with packet captures and runtime traces. |
| RWT-010 Release And Field Package | Q010 | Final license/notices, fixture provenance, reviewer signoff, Developer ID identity, notarization ticket, Gatekeeper acceptance, clean-Mac launch, field session artifact bundle. | Release candidate is allowlisted, reviewed, signed/notarized as intended, and proven on a clean Mac. |
| RWT-011 NAT / ISP Route | Q011-Q012 | Self-hosted rendezvous/forwarder host, ports, operator, retention policy, firewall rules, ICMP/traceroute/UDP echo, raw-vs-NAT added latency. | NAT/ISP route is documented as fallback and never presented as faster than raw direct P2P without evidence. |

## Resume Here

Start with RWT-001. Do not run later physical PASS claims against placeholder
hardware, built-in-device-only probes, localhost runs, or synthetic fixtures.
After RWT-001 is recorded, run RWT-002 and RWT-003 on the same reference Macs
and route before judging video, lighting, Windows compatibility, NAT fallback,
or release readiness.

VERDICT: PARTIAL
