# Research Status

Date: 2026-05-11
Status: consolidated active research lane
Verdict: PARTIAL

This directory is the active research lane for open-lola. It replaces the
former top-level `research/` directory so research status, implementation
handoff, public background material, and release boundaries live under the same
documentation tree.

## Active Files

| File | Current role | Disposition |
|---|---|---|
| [RESEARCH_COMPANION_2026.md](RESEARCH_COMPANION_2026.md) | Canonical research entry point and decision summary. | Current. Keep as the detailed research router. |
| [RESEARCH_CURRENT_STATUS_MATRIX_2026.md](RESEARCH_CURRENT_STATUS_MATRIX_2026.md) | Current crosswalk from research, reverse-engineering boundary, Mac-port status, and real-world test tasks. | Current. Use as the execution bridge before field tests. |
| [RESEARCH_CURRENT_STATUS_IMPLEMENTATION_COMPANION_2026.md](RESEARCH_CURRENT_STATUS_IMPLEMENTATION_COMPANION_2026.md) | Code implementation companion for the current status matrix report, CLI, validator, and remaining RWT gates. | Current. Use for source-level matrix implementation progress. |
| [RESEARCH_EVIDENCE_MATRIX_2026.md](RESEARCH_EVIDENCE_MATRIX_2026.md) | Source matrix for matters 1-85 and required probes. | Current but dated to the 2026-05-02 source refresh; recheck sources before new implementation. |
| [RESEARCH_AUDIO_ENGINE_2026.md](RESEARCH_AUDIO_ENGINE_2026.md) | Core Audio, UDP PCM, callback safety, PLC, and drift research. | Current for design constraints; source-level implementation has advanced, physical evidence remains open. |
| [RESEARCH_NETWORK_TIMING_2026.md](RESEARCH_NETWORK_TIMING_2026.md) | DSCP/QoS, PTP, AVB/TSN, AES67/RAVENNA/Dante/ST 2110 research. | Current for gates; route measurements and professional-AoIP evidence remain missing. |
| [RESEARCH_VIDEO_PIPELINE_2026.md](RESEARCH_VIDEO_PIPELINE_2026.md) | AVFoundation, Blackmagic/ATEM, VideoToolbox, JPEG XS, UltraGrid, RIST/SRT research. | Current for constraints; source-level video lanes exist, hardware video proof remains missing. |
| [RESEARCH_LIGHTING_SHOW_CONTROL_2026.md](RESEARCH_LIGHTING_SHOW_CONTROL_2026.md) | OSC, sACN, Art-Net, DMX/RDM/RDMnet, OFL, OLA, QLC+, Chataigne, OpenFollow, PSN, and OTP research. | Current for gates; lighting/control probes remain missing. |
| [RESEARCH_BENCHMARK_ROADMAP_2026.md](RESEARCH_BENCHMARK_ROADMAP_2026.md) | Measurement gates for audio, network, video, lighting, and release evidence. | Current as the benchmark gate model; active execution status is summarized below. |

## Superseded Files

No file in this directory is deprecated or superseded as of 2026-05-11. The
deprecated research dossiers are already archived under
[../../archive/2026-05-05-doc-consolidation/research/deprecated-research/README.md](../../archive/2026-05-05-doc-consolidation/research/deprecated-research/README.md).

Do not restore the old top-level `research/` directory as an active lane. If a
new research note is needed, add it here and update this index plus
[../README.md](../README.md).

## Implementation Plan State

| Gate | State | What is finished | What is missing |
|---|---|---|---|
| Gate 0: Measurement rig | PARTIAL | Report schemas, CLI validators, preflight reports, and docs gates exist. | Reference Macs, RME MADI identity, route labels, packet-capture points, DSCP/PTP policy, and accepted PASS thresholds. |
| Gate 1: Core Audio fastest lane | PARTIAL | Core Audio inventory, device abstractions, callback-oriented contracts, synthetic/local reports, and source validators exist. | RME/MADI hardware loopback, accepted physical frame sizes, callback p99/max on target hardware, and analog latency evidence. |
| Gate 2: UDP PCM Mac-to-Mac | PARTIAL | UDP PCM packet contracts, direct P2P session reports, RX-buffer profiles, and local/socket-backed probes exist. | Physical two-Mac packet captures, packet age, jitter/loss, underrun/overrun, and fixed target proof on the same route. |
| Gate 3: PLC and drift | PARTIAL | Drift and same-deadline PLC design constraints are represented in source contracts and tests. | Hardware-route drift telemetry, bounded PLC CPU evidence at target frame sizes, and long-run fixed-target proof. |
| Gate 4: Network timing and interop | PARTIAL | DSCP/QoS, PTP, AVB/TSN, AES67/RAVENNA/Dante/ST 2110 gates are documented. | Measured route classification, PTP profile/domain/master evidence, switch stress cases, and endpoint interop latency. |
| Gate 5: Video | PARTIAL | AVFoundation/test-pattern/source-level video transport and reporting surfaces exist. | Blackmagic/ATEM or reviewed capture-path proof, video-under-audio-stress evidence, and degradation-before-audio proof. |
| Gate 6: Lighting and show control | PARTIAL | OSC and lighting protocol gates are documented. | OSC peer timing, OLA/QLC+ one-universe probes, multicast/broadcast isolation, fixture metadata validation, and tracking input proof. |
| Release and field closure | PARTIAL | Release-readiness reports, docs hygiene, and archive boundaries exist. | Final license/notices, fixture provenance, reviewer signoff, Developer ID signing, notarization, Gatekeeper, clean-Mac launch, and field run. |

## Resume Here

Do not create another implementation-plan summary. Use this file for the
research-to-implementation bridge, [../mac-port/README.md](../mac-port/README.md)
for execution status, [../current-state.md](../current-state.md) for public
state, and [../compliance/release-manifest.md](../compliance/release-manifest.md)
for release boundaries.

VERDICT: PARTIAL
