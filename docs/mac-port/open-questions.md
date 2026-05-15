# Open Questions

Date: 2026-05-11
Status: active Mac-port question ledger after docs/mac-port consolidation
Verdict: PARTIAL

Questions are not considered "answered" by assumption. Runtime-dependent facts
remain open until a milestone records measurements or explicit user/venue input.
The detailed coverage matrix is
[sota-open-question-matrix.md](sota-open-question-matrix.md).

## Current Preflight Blockers

Latest local refresh: 2026-05-11.

| Report | Result | Human input still required |
|---|---|---|
| `/private/tmp/open-lola-goal-completion-audit-current.json` | `VERDICT: PARTIAL`; 93 mapped items, 77 pass, 16 partial, 26 blockers. | Runtime Q-gates below plus release/compliance blockers in `../compliance/README.md`. |
| `/private/tmp/open-lola-goal-runtime-preflight-current.json` | `VERDICT: PARTIAL`; 10 runtime deliverables are partial. | Reference Macs, RME MADI devices, route labels, capture points, camera/video permission, Blackmagic/ATEM hardware, lighting target, and field-test environment. |
| `/private/tmp/open-lola-open-source-release-readiness-current.json` | `VERDICT: PARTIAL`; 9 requirements, 6 blockers. | Final source license, documentation license, notices, fixture provenance, reviewer signoff, and public release approval. |

Current host evidence: no captured Core Audio devices, no RME MADI candidates,
no video devices, no Blackmagic/ATEM candidates, denied camera permission, one
valid codesigning identity, and no Developer ID Application identity.

## Disposition Ledger

| ID | Disposition | Owning milestone | Required evidence | Blocking scope |
|---|---|---|---|---|
| Q001 | User input required | M01/M13 | Schema, G01 reference-rig validator, M13 hardware-validation aggregate validator, and placeholder fixtures exist; exact reference Macs, macOS versions/builds, RME MADI model, driver/firmware, TotalMix state, Core Audio UID values, clock source, channel labels, sample rates, route labels, packet-capture points, DSCP policy, cabling, firmware snapshots, and PASS thresholds must still be recorded from real hardware/route evidence. | Blocks M01 and M13 full PASS, not source validation. |
| Q002 | Measurement gate | M02-M03 | M02 Core Audio inventory, M03 report validation, and G02 RME fastest-audio validation exist; physical analog loopback must still prove accepted sample rates without hidden conversion. | Blocks fastest-mode selection. |
| Q003 | Measurement gate | M03 | M03/G02 validation now requires 48/96/192 kHz disposition and rejects non-fastest PASS defaults; real loopback matrix must still prove whether higher rates improve corrected one-way latency. | Blocks high-rate default. |
| Q004 | Measurement gate | M05/M13 | M05 route-report source validation, G04 route-certification wrapper validation, M13 route aggregate gates, and localhost smoke exist; packet captures must still classify each physical route as DSCP honored, rewritten, ignored, harmful, or not tested with reason. | Blocks campus fastest-mode and M13 route PASS claims. |
| Q005 | User input required | M07 | M07 AoIP report source validation exists; real switch/endpoints must still document PTP version, profile, domain, master, lock state, and failure behavior. | Blocks PTP/AVB/AES67/RAVENNA/Dante acceptance. |
| Q006 | User input required | M07 | M07 baseline/stress report validation exists; AVB-capable hardware and network path must still be identified, then compared with direct UDP PCM under idle and stress. | Blocks AVB-as-better-than-UDP claim. |
| Q007 | Policy resolved | M08 | M08 now has test-pattern source validation and a Blackmagic/ATEM-first production capture policy. AVFoundation remains the generic harness and fallback for macOS-exposed Blackmagic/ATEM/UVC capture paths; Desktop Video SDK is optional only after measured need. | Does not block M08 source validation. |
| Q008 | Policy resolved | M11 | M11 now has OSC cue source validation and synthetic loopback timing; live OSC loopback remains first, Chataigne is preferred external peer, and Open Stage Control is fallback. | Does not block M11 source validation. |
| Q009 | User input required | M12 | M12 source validation now enforces OSC-first cue workflow, explicit arm/isolation, allowed universe, blackout/hold/drop policy, packet-capture evidence, setup-only fixture metadata, local fixture-owner guard, and no audio impact; allowed universe, isolated network, fixture target, blackout behavior, and packet-capture point must still be selected for a live run. | Blocks any real sACN/Art-Net output. |
| Q010 | User input required | M15 | M15/F09 source fields and composite handoff exist for signing identity, distribution identity, entitlements, and clean-Mac target; actual values still need to be recorded. | Blocks packaging/field-test closure. |
| Q011 | User input required | F12 | F12 source validation now records self-hosted rendezvous host, self-hosted UDP forwarder/relay host, session, direct traversal, relay fallback, raw-P2P preference, and a combined launcher warning that forwarding may degrade performance; the actual host, port, operator, retention policy, and firewall rules still need to be selected. | Blocks real NAT/ISP-friendly route evidence. |
| Q012 | Measurement gate | F11-F12 | F11 source validation now records UDP echo RTT, ICMP RTT, traceroute hops, and debug traces; F12 records raw-vs-NAT added latency when a raw-route RTT is supplied; real route permissions, DSCP observation, packet-capture points, and measured raw-vs-NAT latency for direct, campus, and ISP/NAT runs must still be documented. | Blocks route comparison and NAT tradeoff claims. |

## Human TODO Markers

- TODO(human): [M01 hardware inventory] -> Identify real reference Macs, RME MADI path, and route labels for Q001 -> [Use current HfMT Mac pairs / borrow dedicated test Macs / defer hardware closure]
- TODO(human): [M03 analog loopback setup] -> Provide the physical loopback path and target input/output device UID for Q002-Q003 -> [built-in acoustic probe only / USB or Thunderbolt interface analog loopback / defer M03 measurement]
- TODO(human): [M05 campus route access] -> Identify packet-capture points and permissions for Q004 -> [direct link only / dedicated switch / campus path with admin coordination]
- TODO(human): [F12 rendezvous and UDP forwarder host] -> Identify the self-hosted rendezvous/forwarder host, ports, operator, retention policy, and firewall rules for Q011 -> [existing VPS / Proxmox VM / defer NAT compatibility]
- TODO(human): [F11/F12 route permissions] -> Identify where ICMP, traceroute, UDP echo, DSCP, and packet capture are permitted for Q012 -> [direct lab only / campus with admin coordination / ISP/NAT field run]
- TODO(human): [M07 timing network] -> Identify PTP, AVB, AES67, RAVENNA, or Dante-capable switches/endpoints for Q005-Q006 -> [no interop hardware / AVB-only / professional AoIP endpoints]
- TODO(human): [M08 video capture hardware] -> Provide camera permission state, Blackmagic/ATEM/DeckLink/UltraStudio target identity, capture route, and packet-capture point for physical video TX/RX evidence -> [AVFoundation-visible Blackmagic/UVC path / Desktop Video SDK path after license review / defer physical video closure]
- TODO(human): [M12 lighting safety] -> Choose safe isolated universe, network, fixture target, and blackout behavior for Q009 -> [OLA/QLC+ virtual output / isolated physical fixture / defer live fixture output]
- TODO(human): [M15 distribution] -> Provide signing identity, notarization account/profile, entitlements, Gatekeeper acceptance target, and clean-Mac target for Q010 -> [ad-hoc local package / Developer ID signed package / defer packaging]

## Resume here

Before implementing a milestone, copy the relevant Q-ID into the target issue,
report, or status note, record the expected evidence before coding, and close
the question only with measured reports or explicit user-provided facts. Q001
specifically stays open until real hardware identity and real route labels are
recorded; placeholders, synthetic fixtures, built-in audio, and inferred route
labels do not close it.
