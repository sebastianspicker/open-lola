# Milestone Index

Date: 2026-05-02  
Status: canonical milestone map

SOTA 2026 open questions and required probes are routed in
[SOTA_2026_OPEN_QUESTION_MATRIX.md](SOTA_2026_OPEN_QUESTION_MATRIX.md). Check
that file before treating any expected test as sufficient for milestone
closure.

| ID | Objective | Expected tests before | Expected tests after | Doc |
|---|---|---|---|---|
| M00 | Establish repo scaffold and evidence baseline before feature code. | No build/test surface. | `swift build`, `swift test`, docs links pass. | [milestones/M00_EVIDENCE_BASELINE_AND_REPO_SCAFFOLD.md](milestones/M00_EVIDENCE_BASELINE_AND_REPO_SCAFFOLD.md) |
| M01 | Define measurement rig, reference Macs, interfaces, network profiles, and report formats. | No repeatable measurement method. | Sample report fixtures validate required fields. | [milestones/M01_MEASUREMENT_HARDWARE_NETWORK_PROFILE.md](milestones/M01_MEASUREMENT_HARDWARE_NETWORK_PROFILE.md) |
| M02 | Enumerate Core Audio devices and prove callback-safe inventory/logging path. | No Core Audio CLI. | CLI reports devices, rates, buffers, latency, and clock domain. | [milestones/M02_CORE_AUDIO_DEVICE_INVENTORY.md](milestones/M02_CORE_AUDIO_DEVICE_INVENTORY.md) |
| M03 | Measure endpoint loopback and select fastest stable hardware mode. | No loopback report. | 16/32/64/128 frame matrix and 30-minute stability result. | [milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md](milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md) |
| M04 | Define and test native UDP PCM packet contract. | Packet parser tests fail or do not exist. | Header, sequence, timestamp, sample format, CRC/guard, and fixture tests pass. | [milestones/M04_UDP_PCM_PACKET_CONTRACT.md](milestones/M04_UDP_PCM_PACKET_CONTRACT.md) |
| M05 | Certify Mac-to-Mac UDP PCM routes. | No network route verdicts. | Route report validator, sender/receiver CLIs, and physical direct/switch/campus reports include p50/p95/p99/max/loss. | [milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md](milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md) |
| M06 | Add drift telemetry and same-deadline PLC policy. | Long run creeps or lacks telemetry. | Drift/PLC report validator, G05 certification wrapper, and 60-minute fixed-target run with drift correction outside callback. | [milestones/M06_DRIFT_AND_SAME_DEADLINE_PLC.md](milestones/M06_DRIFT_AND_SAME_DEADLINE_PLC.md) |
| M07 | Evaluate AVB/TSN/AES67/RAVENNA/Dante as gated interop modes. | No profile evidence. | AoIP report validator, G06 certification wrapper, and accepted/rejected verdicts against UDP PCM baseline. | [milestones/M07_AVB_PROFESSIONAL_AOIP_EVALUATION.md](milestones/M07_AVB_PROFESSIONAL_AOIP_EVALUATION.md) |
| M08 | Add Blackmagic/ATEM-first video capture probe with AVFoundation fallback. | No camera abstraction. | Test-pattern source, latest-frame queue, Blackmagic/ATEM inventory through macOS-exposed capture path, AVFoundation fallback source, video capture run/report validator, then audio-on/video-on proof without audio impact. | [milestones/M08_GENERIC_VIDEO_CAPTURE_PROBE.md](milestones/M08_GENERIC_VIDEO_CAPTURE_PROBE.md) |
| M09 | Add native best-effort video transport. | No frame transport tests. | Raw packetization, latest-frame receiver report validation, raw `video-transport-run`, degradation gates, then physical raw/intra-frame/VideoToolbox probes prove video degrades before audio. | [milestones/M09_NATIVE_VIDEO_TRANSPORT.md](milestones/M09_NATIVE_VIDEO_TRANSPORT.md) |
| M10 | Prove integrated headless A/V coexistence. | Audio/video run separately. | Integrated report validator, synthetic headless A/V smoke, bounded `integrated-av-run`, ownership/degradation gates, then 30-minute stress run preserves audio callback baseline. | [milestones/M10_INTEGRATED_HEADLESS_AV.md](milestones/M10_INTEGRATED_HEADLESS_AV.md) |
| M11 | Add OSC show-control probe. | No cue timing tests. | OSC cue packet tests, synthetic/live loopback jitter report, bounded `osc-cue-external-run`, G08 ATEM read-only reachability, then live control loop with unchanged audio metrics. | [milestones/M11_OSC_SHOW_CONTROL_PROBE.md](milestones/M11_OSC_SHOW_CONTROL_PROBE.md) |
| M12 | Gate sACN/Art-Net/fixture work behind standards and isolated network tests. | No universe safety model. | Lighting gate validator, OSC-first cue workflow guard, explicit arm/isolation policy, blackout/hold/drop PASS guards, bounded `lighting-gate-run` handoff, then one-universe QLC+/OLA probe with packet capture and no audio impact. | [milestones/M12_SACN_ARTNET_FIXTURE_GATE.md](milestones/M12_SACN_ARTNET_FIXTURE_GATE.md) |
| M13 | Build native app shell around proven headless core. | No UI. | Native app shell target, immutable config boundary, read-only metrics observation, realtime ownership PASS guards, bounded `native-app-runtime-smoke` handoff, then launched app-vs-CLI metrics probe. | [milestones/M13_NATIVE_APP_SHELL.md](milestones/M13_NATIVE_APP_SHELL.md) |
| M14 | Add recording/session artifacts outside live deadlines. | No recording. | Recording/session artifact validator, bounded side-lane pressure simulation, drop/gap PASS guards, bounded `recording-session-run` artifact handoff, then measured disk pressure drops recording data instead of delaying media. | [milestones/M14_RECORDING_SESSION_ARTIFACTS.md](milestones/M14_RECORDING_SESSION_ARTIFACTS.md) |
| M15 | Package, sign, and field-test on clean Macs. | No installable app. | Packaging field-test validator, signing/notarization/entitlement PASS guards, bounded `packaging-field-run`, P05 `field-runtime-proof-run`, composite F09 `field-readiness-run`, then signed/notarized clean-Mac field report with verdict. | [milestones/M15_PACKAGING_FIELD_TEST.md](milestones/M15_PACKAGING_FIELD_TEST.md) |

Resume here: use the first incomplete row in
[PROGRESS.md](PROGRESS.md) as the next implementation target, then load the
matching rows from [SOTA_2026_OPEN_QUESTION_MATRIX.md](SOTA_2026_OPEN_QUESTION_MATRIX.md).
