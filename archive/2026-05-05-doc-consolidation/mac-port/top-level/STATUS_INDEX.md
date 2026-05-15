# Status Index

Date: 2026-05-03
Status: compact map routed to the consolidated implementation companion

Live progress, missing evidence, latest verification, and resume state now live
in [IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md). The old
per-milestone status files are archived under
[historical/implementation-companions-2026-05-03/status/](historical/implementation-companions-2026-05-03/status/).

| ID | Canonical plan | Current state |
|---|---|---|
| M00 | [M00_EVIDENCE_BASELINE_AND_REPO_SCAFFOLD.md](milestones/M00_EVIDENCE_BASELINE_AND_REPO_SCAFFOLD.md) | Complete; Swift package scaffold, CLI, tests, and docs harness exist. |
| M01 | [M01_MEASUREMENT_HARDWARE_NETWORK_PROFILE.md](milestones/M01_MEASUREMENT_HARDWARE_NETWORK_PROFILE.md) | Partial; source validation exists, Q001 hardware and route labels open. |
| M02 | [M02_CORE_AUDIO_DEVICE_INVENTORY.md](milestones/M02_CORE_AUDIO_DEVICE_INVENTORY.md) | Complete; Core Audio inventory CLI passes outside the sandbox. |
| M03 | [M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md](milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md) | Partial; audio device abstraction and fastest-path validation exist, physical RME loopback matrix open. |
| M04 | [M04_UDP_PCM_PACKET_CONTRACT.md](milestones/M04_UDP_PCM_PACKET_CONTRACT.md) | Complete; UDP PCM packet contract, fixtures, validator, and localhost smoke pass. |
| M05 | [M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md](milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md) | Partial; localhost and source surfaces pass, physical two-Mac packet-captured routes open. |
| M06 | [M06_DRIFT_AND_SAME_DEADLINE_PLC.md](milestones/M06_DRIFT_AND_SAME_DEADLINE_PLC.md) | Partial; drift/PLC validators and synthetic smoke pass, accepted physical route and 60-minute run open. |
| M07 | [M07_AVB_PROFESSIONAL_AOIP_EVALUATION.md](milestones/M07_AVB_PROFESSIONAL_AOIP_EVALUATION.md) | Partial; AoIP validators exist, real AVB/PTP/AES67/RAVENNA/Dante hardware and WCRT evidence open. |
| M08 | [M08_GENERIC_VIDEO_CAPTURE_PROBE.md](milestones/M08_GENERIC_VIDEO_CAPTURE_PROBE.md) | Partial; Blackmagic/ATEM-first source policy, AVFoundation fallback inventory, and video-only surfaces exist, target Blackmagic/ATEM identity and audio-on/video-on proof open. |
| M09 | [M09_NATIVE_VIDEO_TRANSPORT.md](milestones/M09_NATIVE_VIDEO_TRANSPORT.md) | Partial; raw transport and degradation gates exist, physical video route and VideoToolbox runtime evidence open. |
| M10 | [M10_INTEGRATED_HEADLESS_AV.md](milestones/M10_INTEGRATED_HEADLESS_AV.md) | Partial; integrated synthetic and bounded run surfaces plus overlap/report cross-reference gates exist, 30-minute measured stress open. |
| M11 | [M11_OSC_SHOW_CONTROL_PROBE.md](milestones/M11_OSC_SHOW_CONTROL_PROBE.md) | Partial; OSC and ATEM read-only source surfaces exist, live external peer and real ATEM evidence open. |
| M12 | [M12_SACN_ARTNET_FIXTURE_GATE.md](milestones/M12_SACN_ARTNET_FIXTURE_GATE.md) | Partial; OSC-first cue workflow and sACN/Art-Net safety gates exist, Q009 live lighting selection and evidence open. |
| M13 | [M13_NATIVE_APP_SHELL.md](milestones/M13_NATIVE_APP_SHELL.md) | Partial; SwiftUI target and runtime smoke handoff exist, launched app-vs-CLI metrics open. |
| M14 | [M14_RECORDING_SESSION_ARTIFACTS.md](milestones/M14_RECORDING_SESSION_ARTIFACTS.md) | Partial; artifact schema and bounded writer exist, real media writer and disk-pressure evidence open. |
| M15 | [M15_PACKAGING_FIELD_TEST.md](milestones/M15_PACKAGING_FIELD_TEST.md) | Partial; packaging, field-runtime proof, and composite F09 readiness handoffs exist, Q010 signing and clean-Mac evidence open. |
| G16 | [reports/G16_LOLA_PARITY_DEFERRED_FEATURES_2026-05-03.md](reports/G16_LOLA_PARITY_DEFERRED_FEATURES_2026-05-03.md) | Partial; parity features remain deferred until explicit promotion and measured proof. |
| F10 | [reports/F10_FASTER_THAN_LOLA_CLOSURE_2026-05-03.md](reports/F10_FASTER_THAN_LOLA_CLOSURE_2026-05-03.md) | Partial; closure validator, synthetic smoke, and bounded handoff exist, measured benchmark evidence open. |
| Public M14 | [reports/M14_RELEASE_HARDENING_2026-05-03.md](reports/M14_RELEASE_HARDENING_2026-05-03.md) | Partial; release-hardening validator, docs guard, synthetic smoke, and bounded handoff exist, measured release-candidate evidence open. |
| F12 | [reports/F12_RENDEZVOUS_FORWARDER_LAUNCHER_2026-05-03.md](reports/F12_RENDEZVOUS_FORWARDER_LAUNCHER_2026-05-03.md) | Partial; self-hosted UDP forwarder launcher exists for compatibility, warns that it may degrade performance, and still cannot replace raw-route PASS evidence. |

Resume here: use [IMPLEMENTATION_COMPANION.md](IMPLEMENTATION_COMPANION.md) as
the active status companion and start with Q001 hardware inventory.

VERDICT: PARTIAL
