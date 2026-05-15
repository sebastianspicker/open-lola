# Implementation Companion

Date: 2026-05-10
Status: canonical active source of truth after Linux LoLa seed consolidation, current blocker preflights, and generated-output archive cleanup
Verdict: PARTIAL

This is the single active implementation source of truth for open-lola roadmap
state, milestone status, evidence gates, risk posture, and resume instructions.
Root and public docs are routers or publication-safe summaries. Superseded
milestone files, old progress/index files, report notes, review docs, and the
previous F01-F12 companions are archived under
[../archive/2026-05-05-doc-consolidation/](../archive/2026-05-05-doc-consolidation/).
Superseded plan, audit, and goal documents are archived under
[../archive/2026-05-10-superseded-plans-audits-goals/](../archive/2026-05-10-superseded-plans-audits-goals/).
Superseded active-tree plan and remediation ledger snapshots are archived under
[../archive/2026-05-11-doc-cleanup/](../archive/2026-05-11-doc-cleanup/).
Generated reverse-engineering output formerly under root `re_out/` is archived
under
[../archive/2026-05-10-superseded-plans-audits-goals/generated/re_out/](../archive/2026-05-10-superseded-plans-audits-goals/generated/re_out/).

Publication posture: review-only internal handoff. Public wording lives under
[../docs/](../docs/README.md), especially
[../docs/current-state.md](../docs/current-state.md) and
[../docs/roadmap/](../docs/roadmap/README.md). Do not publish this file as
release text without M06/M08/M10 review.

## Current Progress

This checkout is not a Git repository, so current status is filesystem- and
command-verified. It contains the Swift Package Manager workspace,
`OpenLolaCore`, the `open-lola` CLI, the `open-lola-app` SwiftUI target, tests,
fixtures, public docs, internal research, internal reverse-engineering evidence,
Windows static evidence, and a tracked archive for superseded documentation.

Current source state:

| Area | Verdict | Current state | Missing evidence |
|---|---|---|---|
| M00 scaffold | PASS | Swift package, core library, CLI, app target, tests, and docs harness exist. | None. |
| M02 Core Audio inventory | PASS | Local Core Audio inventory source and CLI surface exist. | RME MADI target is not visible in current local evidence. |
| M04 UDP PCM packet contract | PASS | Parser, serializer, fixtures, validator, and localhost smoke exist. | Physical route evidence belongs to M05/F03. |
| M01, M03, M05-M15 | PARTIAL | Source validators, report schemas, fixtures, CLI probes, and synthetic or bounded handoff surfaces exist. | Real hardware, two-Mac routes, packet capture, video, control, lighting, app, recording, packaging, signing, notarization, Gatekeeper, and clean-Mac evidence. |
| MXX source contracts | PARTIAL | Multichannel routing, low-buffer profiles, and RX buffering contracts exist in source and public docs. | Physical RME/MADI, low-buffer, and impaired-route validation. |
| G16 LoLa parity deferral | PARTIAL | Parity ledger keeps LoLa compatibility out of the fastest path unless explicitly promoted. | No promoted parity feature has measured evidence. |
| External connectors | PARTIAL | Protocol-aware `tx`, `rx`, and simultaneous `tx-rx` session code, bidirectional connection-plan reports with parseable `tx-rx` endpoint commands, port/timing/video-profile overrides, PATH executable defaults for MVTP/UltraGrid and JackTrip, local executable identity preflight for UltraGrid `uv`/JackTrip PATH readiness, and LoLa raw-link interface/MAC tuples for both peers, media-mode validation, CLI runner, validator, schema inventory, and tests exist for LoLa numeric-SID status-check plus audio/video quick-connect ACK exchange, recovered template terminators, visible auxiliary control messages, outer Ethernet/IPv4/UDP wire framing, source-level media body serialization, Linux-seed normal audio/video fragments, Linux-seed video prelude packets, full-size synthetic raw-video byte carriers, JPEG byte-carrier handling without adding an encoder, source-level synthetic packet fixture generation with optional pcap output, passive capture labels for audio fragments, video preludes, video fragments, MJPEG candidates, malformed fragments, and unknown payloads, post-control UDP socket media TX/RX for IP-routed LoLa attempts, explicit LoLa `tx-rx` media evidence, and opt-in raw-link media TX/RX wiring with bounded BPF RX timeout from local RE evidence, explicit `tx-rx` UltraGrid `uv` audio/video endpoint commands with configurable capture/playback/display modules, JackTrip RtAudio mode, and JackTrip-plus-`tx-rx` auxiliary-UltraGrid AV mode with configurable video modules. `../linux_connector/` is the authoritative LoLa compatibility seed; use `../linux_connector/docs/protocol-reference.md` and `../linux_connector/docs/windows-validation.md` for byte-level evidence rather than duplicating offsets here. LoLa source-level grammar is implemented; real Windows LoLa interoperability remains unproven until a fresh measured Windows LoLa probe validates the Swift connector. | No selected external endpoints, command transcripts, route captures, latency comparisons, LoLa media packet captures, Windows-originated media captures, or interoperability evidence. |
| F10 faster-than-LoLa closure | PARTIAL | Closure ledger, validator, CLI writer, synthetic smoke, and PASS guards exist. | Measured F01-F04 evidence and same-hardware LoLa baseline. |
| Codewise closure | PASS | Codewise report, CLI writer, validator, schema inventory, docs areas, and report artifact exist. | Real-world completion remains PARTIAL. |
| Runtime completion | PARTIAL | Runtime audit, prompt-to-artifact checklist, required measurement commands, and report handoff live in this file. | Two Macs, RME/MADI, Blackmagic/ATEM, lighting/control target, Developer ID signing, notarization, Gatekeeper, and clean-Mac field evidence. |
| Release source export | PASS | Allowlisted source candidate staging and C12 hygiene scan exist. | Release remains blocked by license, notices, fixture provenance, reviewer signoff, hardware, benchmark, and package evidence. |

Do not mark any PARTIAL row PASS from synthetic fixtures, localhost-only smokes,
built-in Mac devices, placeholder hardware labels, or archived report notes.

## Lane Overview

Active detail is limited to four companion files. Old F01-F12 files are archive
snapshots, not live editing surfaces.

| Companion | Covers | Use for |
|---|---|---|
| [audio-network.md](implementation-companions/audio-network.md) | M01-M07, MXX audio/network, F01-F04, F11, F12, Q001-Q006, Q011-Q012 | RME/MADI, AudioDeviceIOProc/AUHAL, UDP PCM, DSCP, PTP, AVB/AoIP, drift, PLC, direct P2P, diagnostics, and NAT/ISP route work. |
| [video-control.md](implementation-companions/video-control.md) | M08-M12, F05-F08, Q007-Q009 | AVFoundation, Blackmagic/ATEM, VideoToolbox, integrated A/V, OSC, sACN, Art-Net, and lighting/control gates. |
| [app-release-field.md](implementation-companions/app-release-field.md) | M13-M15, F09-F10, G16, runtime closure | SwiftUI app shell, recording, packaging, clean-Mac field tests, faster-than-LoLa closure, and deferred parity. |
| [evidence-compliance.md](implementation-companions/evidence-compliance.md) | Docs topology, archive, release hygiene, clean-room, public/internal boundary | Documentation consolidation, release manifest, fixture provenance, source/test/doc crosswalk, and evidence classification. |

The public-safe roadmap lives in
[../docs/roadmap/README.md](../docs/roadmap/README.md). The active
publication-safe state is [../docs/current-state.md](../docs/current-state.md).
Open human or venue facts remain in [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md), and
research traceability remains in
[../research/RESEARCH_EVIDENCE_MATRIX_2026.md](../research/RESEARCH_EVIDENCE_MATRIX_2026.md).

## Open Evidence Gates

- TODO(human): [M01 hardware inventory] -> Identify real reference Macs, RME MADI path, route labels, packet-capture points, DSCP policy, and PASS thresholds for Q001 -> [Use current HfMT Mac pairs / borrow dedicated test Macs / defer hardware closure]
- TODO(human): [M03 analog loopback setup] -> Provide the physical loopback path and target input/output device UID for Q002-Q003 -> [Thunderbolt RME loopback / other interface loopback / defer M03 measurement]
- TODO(human): [M05 route access] -> Identify packet-capture points and permissions for Q004 and Q012; collect `tcpdump` capture, receiver-side DSCP read-back, and `sntp`/PTP clock artifact paths for `DirectPeerSessionReport` PASS -> [direct link only / dedicated switch / campus path with admin coordination]
- TODO(human): [M07 timing network] -> Identify PTP, AVB, AES67, RAVENNA, or Dante-capable switches/endpoints for Q005-Q006 -> [no interop hardware / AVB-only / professional AoIP endpoints]
- TODO(human): [F12 rendezvous and UDP forwarder host] -> Identify the self-hosted rendezvous/forwarder host, ports, operator, retention policy, and firewall rules for Q011 -> [existing VPS / Proxmox VM / defer NAT compatibility]
- TODO(human): [M12 lighting safety] -> Choose safe isolated universe, network, fixture target, blackout behavior, and packet-capture point for Q009 -> [OLA/QLC+ virtual output / isolated physical fixture / defer live fixture output]
- TODO(human): [M15 distribution] -> Provide signing identity, notarization account, entitlements, and clean-Mac target for Q010 -> [ad-hoc local package / Developer ID signed package / defer packaging]

Resolved policy gates:

- Q007: Blackmagic/ATEM production capture first; AVFoundation remains the
  generic harness and fallback for macOS-exposed devices; Desktop Video SDK is
  optional only after measured need.
- Q008: live OSC loopback first; Chataigne preferred external peer, Open Stage
  Control fallback.
- Windows LoLa packet compatibility is not a default design constraint. It stays
  deferred through G16 unless explicitly promoted with measured evidence.

### Runtime Completion Audit

Objective restated as concrete deliverables: open-lola is complete only when a
real, reproducible two-or-more-Mac session proves bidirectional multichannel RME
MADI audio, receiver-side routing/mixing, direct P2P UDP media, measured
latency/jitter/loss/underrun/overrun behavior, benchmarked RX buffer modes,
Blackmagic/ATEM/DeckLink/UltraStudio video TX/RX, staged or working multi-video,
real AV timing, non-blocking OSC/lighting, packaging/signing/notarization,
Gatekeeper acceptance, and a clean-Mac field test. Synthetic tests, localhost
tests, source contracts, generated fixtures, and assumed measurements do not
close any of these gates.

Local evidence from 2026-05-05:

- `.build/debug/open-lola device-inventory` failed with `open-lola: noDevices`.
- `.build/debug/open-lola video-capture-inventory` returned no devices,
  `permissionStatus: denied`, and `blackmagicSdkStatus:
  notLinkedOptionalBoundary`.
- `system_profiler SPUSBDataType SPThunderboltDataType SPAudioDataType
  SPCameraDataType` showed no connected Thunderbolt/USB devices and no audio
  devices in this session.
- `security find-identity -v -p codesigning` found one Apple Configurator
  identity, not a Developer ID Application identity.
- `networksetup -listallhardwareports` failed with `AuthorizationCreate()
  failed: -60008`; `ifconfig -l` listed local interfaces only and did not prove
  a test peer or route.
- Reciprocal localhost `madi-full-duplex-run` probes wrote `networkRuntime`
  reports for two peers and validated with `VERDICT: PARTIAL`; each side
  transmitted, completed, rendered four UDP PCM v2 blocks, and can record
  configured receiver-mix evidence with `--receiver-mix swap-stereo`. This
  proves the CLI/socket path, not physical RME/MADI readiness.
- Localhost `video-transport-run` probes wrote and validated socket-backed
  `m09-video-transport-run` and staged `m09-multi-video-transport-run` reports
  with test-pattern frames and UDP raw video fragments. This proves the
  CLI/socket path, not physical Blackmagic/ATEM readiness.
- `bash scripts/verify-release-readiness.sh` passed outside the sandbox, but it
  explicitly leaves hardware, signing, notarization, Gatekeeper, clean-Mac, and
  benchmark gates manual.

Live Windows LoLa evidence from 2026-05-06:

- The `tx-rx` UDP probe with native Windows LoLa proved that Windows control
  datagrams reached this Mac, including post-connect generated-signal,
  chat/monitor, and disconnect commands.
- The capture showed open-lola completed initiated status/quick-connect control
  and sent audio/video media toward Windows, but no Windows-originated media
  datagrams were captured on the configured audio/video ports.
- The failing behavior was open-lola closing the UDP control socket after the
  initiated `tx-rx` quick-connect exchange; macOS then answered later Windows
  control commands with UDP port-unreachable ICMP.
- The required source fix is to keep the LoLa UDP control responder alive for
  bidirectional receive-capable sessions and consume post-connect control
  datagrams while media is active. This remains PARTIAL until the Windows probe
  is repeated and Windows-originated media appears in capture.

Linux LoLa seed consolidation from 2026-05-08:

- `../linux_connector/` is copied as the authoritative compatibility seed from
  the validated Linux prototype and is intentionally not merged into SwiftPM
  packaging.
- Swift LoLa media now follows that seed for padded audio UDP payloads, audio
  fragment frame IDs, video prelude field offsets, and full-size generated raw
  video frames.
- Verdict remains PARTIAL until a fresh Windows LoLa probe validates this Swift
  behavior against a real peer.

Prompt-to-artifact checklist:

| Requirement | Existing artifact or command | Real PASS evidence required | Current verdict |
|---|---|---|---|
| Two-Mac multichannel RME MADI TX/RX both directions | `audio-loopback-run`, `madi-full-duplex-run`, `validate-madi-full-duplex-report` | Two reference Macs, visible RME MADI input/output UIDs, 32/64-frame runs, bidirectional TX/RX artifacts, callback and packet metrics. | PARTIAL; no local devices. `madi-full-duplex-run` is now socket-backed UDP runtime evidence, not physical Core Audio/RME evidence. |
| Receiver-side routing/mixing | `MadiReceiveEngine`, `ReceiverMixSnapshot`, `madi-full-duplex-run --receiver-mix swap-stereo`, `MadiFullDuplexReport.receiverMix` | Physical receive run proving receiver-local mix routes without destructive sender-side downmix. | PARTIAL; socket-backed MADI runtime now records configured receiver-mix evidence, but physical RME receive proof remains open. |
| Direct P2P session setup and UDP media path | `direct-p2p-two-peer-plan-run`, `direct-p2p-session-run`, `direct-p2p-localhost-smoke`, `direct-p2p-mesh-topology-synthetic-smoke`, `direct-p2p-mesh-runtime-localhost-smoke`, `udp-pcm-route-run`, `udp-pcm-loopback-run`, `network-diagnostics-run` | Two-Mac control/session transcript plus UDP route reports with packet capture, DSCP classification, ICMP/traceroute comparison, byte-exact loopback, explicit Core Audio input/output UIDs, and visible raw video receive evidence. | PARTIAL; socket-backed local and manual-address runs now exchange control JSON datagrams and UDP media, `direct-p2p-two-peer-plan-run` emits the paired responder/initiator AV command plan, and `direct-p2p-session-run --media audio-video` supports balanced AV and a distinct `--av-profile fastest` lane with explicit `--input-uid`/`--output-uid` selection, a v1 same-full-duplex-device UID constraint, direct audio-first/direct RX report metadata, fixed Core Audio buffer evidence, preview mode, routed audio/video packet counters, measured-evidence PASS fields, and fastest-PASS blocker text. Source-level mesh topology validates two-or-more-peer endpoint and directed-route shape, and localhost mesh runtime routes UDP PCM v2 audio across every directed peer pair. Physical direct-LAN AV proof remains open. |
| Measured audio latency, jitter, loss, underruns, overruns | `audio-loopback-run`, `udp-pcm-route-run`, `drift-plc-run`, benchmark validators | Analog loopback, route packet-age histograms, packet loss/late/drop counters, underrun/overrun counters, and 60-minute drift/PLC run. | PARTIAL; no hardware route. |
| Configurable RX buffer modes with benchmarks | `rx-buffer-benchmark-run`, `validate-rx-buffer-benchmark-report`, `latency-profile-benchmark-synthetic-smoke`, `latency-tuning-synthetic-smoke`, `docs/source-contracts/README.md` | Direct/small/adaptive/stable-WAN measurements on the same route with visible latency cost and fastest-path rejection where appropriate. | PARTIAL; local runtime benchmark now covers all RX profiles under deterministic impairment, but same-route physical RME benchmarks remain open. |
| Blackmagic/ATEM/DeckLink/UltraStudio video TX/RX | `video-capture-inventory`, `video-capture-run`, `video-transport-run`, `atem-readonly-probe` | Real Blackmagic/ATEM device identity, capture permission, transport report, read-only ATEM status, and audio-impact comparison. | PARTIAL; no visible device and permission denied. `video-transport-run` is now socket-backed UDP raw-fragment evidence with a test-pattern source, not physical Blackmagic/ATEM evidence. |
| Staged or working multi-video runtime | `session-capabilities`, `MultiVideoStreams`, `video-transport-run` | Multiple enabled streams or an explicit staged report showing bounded scheduling and audio-first degradation. | PARTIAL; capabilities advertise a staged four-stream test-pattern/raw-fragment limit, and `video-transport-run` can run bounded multi-stream localhost transport. Physical multi-camera Blackmagic/ATEM evidence remains open. |
| AV timing documentation from real runs | `integrated-av-run`, `integrated-profile-run`, `e2e-benchmark-run`, `docs/architecture/av-sync-and-timing.md` | 30-minute integrated run with audio-master timing, video frame-age, packet-age, AV offset/jitter metrics, and full M12 profile matrix. | PARTIAL; `integrated-av-run` can now aggregate a measured `video-transport-run` report, and `integrated-profile-run` can aggregate runtime reports, but no RME/audio, Blackmagic/ATEM, external control, lighting fixture, or 30-minute physical run exists here. |
| OSC/lighting without audio-thread impact | `osc-cue-external-run`, `atem-readonly-probe`, `lighting-gate-run` | External OSC peer, ATEM status, isolated lighting universe or virtual output, packet capture, and audio-baseline comparison. | PARTIAL; no external peer or safe lighting target configured. |
| Packaging, signing, notarization, Gatekeeper, clean-Mac | `native-app-runtime-smoke`, `recording-session-run`, `packaging-field-run`, `field-runtime-proof-run`, `field-readiness-run` | Developer ID Application identity, hardened runtime, notarization ticket, Gatekeeper acceptance, clean-Mac install/launch, permission prompts, and app-vs-CLI metric comparison. | PARTIAL; `packaging-field-run` now writes packaged microphone, camera, local-network, and network-client permission/entitlement artifacts, but no Developer ID identity or clean-Mac target exists. |

### Required Measurement Commands

Use a new run directory per physical attempt, for example
`/private/tmp/open-lola-real-runs/2026-05-05`. Replace every angle-bracket
placeholder with the measured hardware, peer, route, and operator values before
running. Do not set any command to `--verdict pass` until the matching validator
accepts a real physical report and the evidence packet is reviewed.

Hardware and local capability inventory:

```bash
.build/debug/open-lola device-inventory
.build/debug/open-lola video-capture-inventory --output <run-dir>/m08-video-inventory.json
security find-identity -v -p codesigning
system_profiler SPUSBDataType SPThunderboltDataType SPAudioDataType SPCameraDataType
```

RME loopback, multichannel audio, route, and drift:

```bash
.build/debug/open-lola audio-loopback-run --input-uid <rme-input-uid> --output-uid <rme-output-uid> --sample-rate 48000 --frames 32 --channels 64 --sample-format float32 --input-channels <comma-separated-0-based-input-map> --output-channels <comma-separated-0-based-output-map> --preallocated-blocks 8 --mtu 1200 --max-fragments 16 --metadata-revision <revision> --latency-profile directAudioFirst --rx-buffer-profile direct --duration-seconds 1800 --output <run-dir>/m03-rme-loopback-48k-32f.json
.build/debug/open-lola validate-loopback-report <run-dir>/m03-rme-loopback-48k-32f.json

.build/debug/open-lola madi-full-duplex-run --local-peer <mac-a-peer-id> --remote-peer <mac-b-peer-id> --local-host <mac-a-ip> --remote-host <mac-b-ip> --port <mac-a-udp-port> --remote-port <mac-b-udp-port> --sample-rate 48000 --frames 32 --channels 64 --duration-packets <packets> --input-uid <rme-input-uid> --output-uid <rme-output-uid> --sample-format float32 --local-stream-id 1 --remote-stream-id 2 --receiver-mix swap-stereo --output <run-dir>/m05-madi-full-duplex-mac-a.json
.build/debug/open-lola madi-full-duplex-run --local-peer <mac-b-peer-id> --remote-peer <mac-a-peer-id> --local-host <mac-b-ip> --remote-host <mac-a-ip> --port <mac-b-udp-port> --remote-port <mac-a-udp-port> --sample-rate 48000 --frames 32 --channels 64 --duration-packets <packets> --input-uid <rme-input-uid> --output-uid <rme-output-uid> --sample-format float32 --local-stream-id 2 --remote-stream-id 1 --output <run-dir>/m05-madi-full-duplex-mac-b.json
.build/debug/open-lola validate-madi-full-duplex-report <run-dir>/m05-madi-full-duplex-mac-a.json
.build/debug/open-lola validate-madi-full-duplex-report <run-dir>/m05-madi-full-duplex-mac-b.json

.build/debug/open-lola rx-buffer-benchmark-run --output <run-dir>/m07-rx-buffer-local-benchmark.json --packets 48
.build/debug/open-lola validate-rx-buffer-benchmark-report <run-dir>/m07-rx-buffer-local-benchmark.json

.build/debug/open-lola udp-pcm-route-run --role receiver --bind-host <receiver-ip> --peer <sender-ip> --port <udp-port> --sample-rate 48000 --frames 32 --channels 64 --duration-seconds 1800 --output <run-dir>/m05-route-receiver.json --dscp <0-63> --route-kind directLink --route-label <route-label> --route-topology <topology> --sender-label <mac-a-label> --sender-host <mac-a-hostname> --sender-interface <sender-iface> --sender-ip <sender-ip> --receiver-label <mac-b-label> --receiver-host <mac-b-hostname> --receiver-interface <receiver-iface> --receiver-ip <receiver-ip> --link-rate-mbps <mbps> --vlan <vlan-or-none> --multicast-policy unicast-only --dscp-observed <0-63> --dscp-classification honored --capture-point <capture-point> --capture-correlated true --capture-notes <capture-artifact> --verdict partial
.build/debug/open-lola udp-pcm-route-run --role sender --bind-host <sender-ip> --peer <receiver-ip> --port <udp-port> --sample-rate 48000 --frames 32 --channels 64 --duration-seconds 1800 --output <run-dir>/m05-route-sender.json --dscp <0-63> --route-kind directLink --route-label <route-label> --route-topology <topology> --sender-label <mac-a-label> --sender-host <mac-a-hostname> --sender-interface <sender-iface> --sender-ip <sender-ip> --receiver-label <mac-b-label> --receiver-host <mac-b-hostname> --receiver-interface <receiver-iface> --receiver-ip <receiver-ip> --link-rate-mbps <mbps> --vlan <vlan-or-none> --multicast-policy unicast-only --dscp-observed <0-63> --dscp-classification honored --capture-point <capture-point> --capture-correlated true --capture-notes <capture-artifact> --verdict partial
.build/debug/open-lola validate-route-report <run-dir>/m05-route-receiver.json

.build/debug/open-lola direct-p2p-two-peer-plan-run --output <run-dir>/m06-direct-p2p-av-plan.json --run-dir <run-dir> --mac-a-peer <mac-a-peer-id> --mac-a-host <mac-a-ip> --mac-a-port-base <mac-a-port-base> --mac-a-input-uid <mac-a-input-uid> --mac-a-output-uid <mac-a-output-uid> --mac-a-video-device-id <mac-a-camera-id-or-auto> --mac-b-peer <mac-b-peer-id> --mac-b-host <mac-b-ip> --mac-b-port-base <mac-b-port-base> --mac-b-input-uid <mac-b-input-uid> --mac-b-output-uid <mac-b-output-uid> --mac-b-video-device-id <mac-b-camera-id-or-auto> --duration-seconds <seconds> --channels 64 --frames 32 --preview on
.build/debug/open-lola direct-p2p-session-run --role responder --local-peer <mac-b-peer-id> --remote-peer <mac-a-peer-id> --local-host <mac-b-ip> --remote-host <mac-a-ip> --control-port <mac-b-control-port> --remote-control-port <mac-a-control-port> --audio-port <mac-b-audio-port> --video-port <mac-b-video-port> --metrics-port <mac-b-metrics-port> --channels 64 --packets <packets> --timeout-seconds 30 --output <run-dir>/m06-direct-p2p-mac-b.json
.build/debug/open-lola direct-p2p-session-run --role initiator --local-peer <mac-a-peer-id> --remote-peer <mac-b-peer-id> --local-host <mac-a-ip> --remote-host <mac-b-ip> --control-port <mac-a-control-port> --remote-control-port <mac-b-control-port> --audio-port <mac-a-audio-port> --video-port <mac-a-video-port> --metrics-port <mac-a-metrics-port> --channels 64 --packets <packets> --timeout-seconds 30 --output <run-dir>/m06-direct-p2p-mac-a.json
.build/debug/open-lola direct-p2p-session-run --media audio-video --role responder --local-peer <mac-b-peer-id> --remote-peer <mac-a-peer-id> --local-host <mac-b-ip> --remote-host <mac-a-ip> --control-port <mac-b-control-port> --remote-control-port <mac-a-control-port> --audio-port <mac-b-audio-port> --video-port <mac-b-video-port> --metrics-port <mac-b-metrics-port> --channels 64 --duration-seconds <seconds> --input-uid <mac-b-input-uid> --output-uid <mac-b-output-uid> --sample-rate 48000 --frames 32 --sample-format float32 --input-channels <csv> --output-channels <csv> --video-device-id <mac-b-camera-id-or-auto> --video-frame-rate 30 --video-stream-id 100 --timeout-seconds 30 --output <run-dir>/m06-direct-p2p-av-mac-b.json
.build/debug/open-lola direct-p2p-session-run --media audio-video --role initiator --local-peer <mac-a-peer-id> --remote-peer <mac-b-peer-id> --local-host <mac-a-ip> --remote-host <mac-b-ip> --control-port <mac-a-control-port> --remote-control-port <mac-b-control-port> --audio-port <mac-a-audio-port> --video-port <mac-a-video-port> --metrics-port <mac-a-metrics-port> --channels 64 --duration-seconds <seconds> --input-uid <mac-a-input-uid> --output-uid <mac-a-output-uid> --sample-rate 48000 --frames 32 --sample-format float32 --input-channels <csv> --output-channels <csv> --video-device-id <mac-a-camera-id-or-auto> --video-frame-rate 30 --video-stream-id 100 --timeout-seconds 30 --output <run-dir>/m06-direct-p2p-av-mac-a.json
.build/debug/open-lola validate-direct-p2p-session-report <run-dir>/m06-direct-p2p-mac-a.json
.build/debug/open-lola validate-direct-p2p-session-report <run-dir>/m06-direct-p2p-mac-b.json
.build/debug/open-lola validate-direct-p2p-session-report <run-dir>/m06-direct-p2p-av-mac-a.json
.build/debug/open-lola validate-direct-p2p-session-report <run-dir>/m06-direct-p2p-av-mac-b.json
.build/debug/open-lola direct-p2p-mesh-topology-synthetic-smoke --output <run-dir>/m06-direct-p2p-mesh-topology.json --peers 3
.build/debug/open-lola validate-direct-p2p-mesh-topology-report <run-dir>/m06-direct-p2p-mesh-topology.json
.build/debug/open-lola direct-p2p-mesh-runtime-localhost-smoke --output <run-dir>/m06-direct-p2p-mesh-runtime.json --peers 3 --packets 2
.build/debug/open-lola validate-direct-p2p-mesh-runtime-report <run-dir>/m06-direct-p2p-mesh-runtime.json

.build/debug/open-lola network-diagnostics-run --peer <peer-ip> --ping-count 100 --max-hops 8 --output <run-dir>/m05-network-diagnostics.json
.build/debug/open-lola drift-plc-run --route-report <run-dir>/m05-route-receiver.json --duration-seconds 3600 --policy sameDeadline --artifact-assessment-completed true --artifact-notes <artifact-notes> --output <run-dir>/m06-drift-plc-60min.json
```

For the current v1 AV runtime, each peer's `--input-uid` and `--output-uid`
must resolve to the same full-duplex Core Audio device. The accepted reports
must retain the UID evidence, selected buffer frames, preview mode, and routed
audio/video packet counters; they remain `PARTIAL` until `measuredEvidence`
records the physical two-Mac route, packet capture, DSCP observation, clock
sync, and raw video receive proof.

Video, OSC, ATEM, lighting, and integrated A/V:

```bash
.build/debug/open-lola video-capture-run --device-id <blackmagic-or-atem-device-id> --duration-seconds 1800 --output <run-dir>/m08-video-capture.json --stream-id 1 --queue-depth <n> --frame-rate <fps> --baseline-callback-p99-us <us> --video-callback-p99-us <us> --baseline-callback-max-us <us> --video-callback-max-us <us> --baseline-playout-target-frames 32 --video-playout-target-frames 32 --audio-underruns 0 --hidden-audio-impact false --production-hardware <atem|decklink|ultrastudio|blackmagic-capture> --production-model <model> --production-manufacturer Blackmagic --production-connection <usb-uvc|thunderbolt|pcie|unknown> --desktop-video-sdk-status <not-linked|linked|unavailable|required-after-measurement> --desktop-video-sdk-notes <notes> --verdict partial
.build/debug/open-lola video-transport-run --mode raw --peer <receiver-ip> --port <video-udp-port> --duration-seconds 1800 --output <run-dir>/m09-video-transport.json --stream-id 1 --stream-count <1-4> --visible-streams <n> --source-role <blackmagicInput|atemProgram|atemPreview|avFoundationDevice> --width <px> --height <px> --pixel-format <format> --frame-rate <fps> --queue-depth <n> --max-packet-bytes 1200 --route-kind directWired --packet-capture-point <capture-point>
.build/debug/open-lola osc-cue-external-run --audio-baseline <audio-baseline-report-id> --port <local-osc-port> --count <n> --first-external-peer <chataigne|openStageControl|other> --external-host <peer-host> --external-port <peer-port> --external-available true --output <run-dir>/m11-osc-external.json
.build/debug/open-lola atem-readonly-probe --host <atem-ip> --port 9910 --timeout-milliseconds 1000 --poll-interval-milliseconds 100 --network-interface <interface> --same-network-as-audio false --output <run-dir>/m11-atem-readonly.json
.build/debug/open-lola lighting-gate-run --audio-baseline <audio-baseline-report-id> --osc-cue-report <osc-report-id> --protocol <sacn|artNet> --interop-target <ola|qlcPlus> --universe <n> --network-mode isolatedUnicast --destination <target-ip> --port <port> --isolated-network true --explicitly-armed true --capture-tool <tool> --capture-point <capture-point> --duration-seconds <n> --output <run-dir>/m12-lighting-gate.json
.build/debug/open-lola integrated-av-run --audio-baseline <audio-baseline-report-id> --video-capture on --video-transport on --video-preview off --osc-control on --atem-readonly <atem-ip> --duration-seconds 1800 --video-transport-report <run-dir>/m09-video-transport.json --output <run-dir>/m10-integrated-av.json
.build/debug/open-lola integrated-profile-run --fastest-audio <fastest-audio-report-id> --integrated-av <integrated-av-report-id> --lighting-control <lighting-gate-report-id> --audio-only <audio-only-matrix-report-id> --audio-video <audio-video-matrix-report-id> --audio-control <audio-control-matrix-report-id> --audio-video-control <audio-video-control-matrix-report-id> --fastest-audio-report <run-dir>/m07-fastest-audio.json --integrated-av-report <run-dir>/m10-integrated-av.json --lighting-control-report <run-dir>/m12-lighting-gate.json --output <run-dir>/m12-integrated-profile.json
```

App, recording, packaging, field, and final closure:

```bash
.build/debug/open-lola native-app-runtime-smoke --headless-report <run-dir>/m10-integrated-av.json --duration-seconds <n> --output <run-dir>/m13-native-app-runtime.json
.build/debug/open-lola recording-session-run --integrated-baseline <run-dir>/m10-integrated-av.json --duration-seconds 1800 --output-dir <run-dir>/recording --report <run-dir>/m14-recording-session.json --record-audio on --audio-input-uid <core-audio-input-uid> --sample-rate 48000 --frames 32 --channels <n> --input-channels <csv> --sample-format int16-le --record-video on --video-device-id <blackmagic-or-atem-device-id|auto> --stream-id 1 --frame-rate <fps> --queue-depth <n>
.build/debug/open-lola packaging-field-run --integrated-report <run-dir>/m10-integrated-av.json --app-report <run-dir>/m13-native-app-runtime.json --recording-report <run-dir>/m14-recording-session.json --output-dir <run-dir>/package --report <run-dir>/m15-packaging-field.json
.build/debug/open-lola field-runtime-proof-run --integrated-report <run-dir>/m10-integrated-av.json --app-report <run-dir>/m13-native-app-runtime.json --recording-report <run-dir>/m14-recording-session.json --packaging-report <run-dir>/m15-packaging-field.json --output <run-dir>/p05-field-runtime-proof.json
.build/debug/open-lola field-readiness-run --integrated-report <run-dir>/m10-integrated-av.json --duration-seconds 1800 --output-dir <run-dir>/field-readiness
.build/debug/open-lola e2e-benchmark-run --audio-benchmark <run-dir>/audio-benchmark.json --integrated-av <run-dir>/m10-integrated-av.json --video-transport <run-dir>/m09-video-transport.json --performance-audit <run-dir>/performance-audit.json --duration-seconds 1800 --output <run-dir>/m13-e2e-benchmark.json
.build/debug/open-lola faster-than-lola-closure-run --claim-scope fieldReady --f01-report <run-dir>/f01-rme-hardware.json --f02-report <run-dir>/f02-realtime-engine.json --f03-report <run-dir>/f03-p2p-route.json --f04-report <run-dir>/f04-drift-plc-lola-baseline.json --f05-report <run-dir>/f05-blackmagic-atem.json --f06-report <run-dir>/f06-video-transport.json --f07-report <run-dir>/f07-integrated-runtime.json --f08-report <run-dir>/f08-lighting.json --f09-report <run-dir>/f09-field-readiness.json --output <run-dir>/f10-faster-than-lola-closure.json
.build/debug/open-lola release-hardening-run --output <run-dir>/m14-release-hardening.json
.build/debug/open-lola open-source-release-readiness-run --output <run-dir>/open-source-release-readiness.json
.build/debug/open-lola validate-open-source-release-readiness-report <run-dir>/open-source-release-readiness.json
```

Developer ID, notarization, Gatekeeper, and clean-Mac evidence for Q010 must be
captured outside the synthetic/ad-hoc packaging handoff. Use the exact signed
package paths from the release build, then copy command output into the M15
report fields `signing`, `notarization`, `cleanMac`, and `fieldReport` before
validation. The source-level `packaging-field-run` report stays PARTIAL until
these commands succeed on a real signed package and a clean target Mac:

```bash
security find-identity -v -p codesigning
codesign --display --verbose=4 <signed-app-bundle>
codesign --verify --deep --strict --verbose=2 <signed-app-bundle>
codesign -d --entitlements :- <signed-app-bundle>
shasum -a 256 <signed-app-bundle-or-dmg>
xcrun notarytool submit <signed-dmg-or-zip> --keychain-profile <notarytool-profile> --wait --output-format json > <run-dir>/m15-notary-submit.json
xcrun stapler staple <signed-dmg-or-app>
xcrun stapler validate <signed-dmg-or-app>
spctl --assess --type execute --verbose=4 <signed-app-bundle>
spctl --assess --type open --context context:primary-signature --verbose=4 <signed-dmg>

sw_vers
uname -m
system_profiler SPHardwareDataType SPAudioDataType SPCameraDataType
hdiutil attach <signed-dmg>
ditto <mounted-volume>/OpenLoLa.app /Applications/OpenLoLa.app
open -n /Applications/OpenLoLa.app
<installed-cli-path>/open-lola goal-codewise-closure
<installed-cli-path>/open-lola field-readiness-run --integrated-report <clean-mac-run-dir>/m10-integrated-av.json --duration-seconds 1800 --output-dir <clean-mac-run-dir>/field-readiness
.build/debug/open-lola validate-packaging-field-report <run-dir>/m15-packaging-field.json
.build/debug/open-lola validate-field-runtime-proof <run-dir>/p05-field-runtime-proof.json
```

The real report packet is not complete until every generated JSON report is
validated by its matching `validate-*` command, the raw run artifacts are
reviewed for private data and clean-room safety, and the final status remains
`PARTIAL` for any row that lacks physical evidence.

For a machine-readable handoff of this checklist, run:

```bash
.build/debug/open-lola goal-runtime-evidence-template
.build/debug/open-lola goal-runtime-evidence-template-run --output <run-dir>/goal-runtime-evidence-template.json
.build/debug/open-lola validate-goal-runtime-evidence-template-report <run-dir>/goal-runtime-evidence-template.json
.build/debug/open-lola goal-runtime-preflight
.build/debug/open-lola goal-runtime-preflight-run --output <run-dir>/goal-runtime-preflight.json
.build/debug/open-lola validate-goal-runtime-preflight-report <run-dir>/goal-runtime-preflight.json
```

## Verification

Current documentation consolidation must pass:

```bash
bash scripts/verify-docs.sh
shellcheck -x scripts/*.sh scripts/lib/*.sh
bash scripts/verify-release-hygiene.sh
swift test --no-parallel
bash scripts/verify-release-readiness.sh
```

SwiftPM may fail inside the sandbox with `sandbox-exec: sandbox_apply:
Operation not permitted`; rerun the same Swift command outside the sandbox when
that host limitation appears.

Latest broad runtime/documentation cleanup verification passed on 2026-05-05:
docs, shellcheck, release hygiene, non-parallel Swift tests,
reciprocal localhost `madi-full-duplex-run` socket probes, a manual-address
initiator/responder `direct-p2p-session-run` probe over local IPs, a localhost
`video-transport-run` socket probe, a measured-partial `integrated-av-run`
aggregate using that video transport report, a measured-partial
`integrated-profile-run` aggregate using latency, integrated A/V, and lighting
reports, GOAL codewise closure with `codeImplementedCount: 68` of
`requirementCount: 68`, the GOAL runtime evidence template with 10/10 runtime
deliverables still `PARTIAL`, the GOAL runtime preflight with 10/10 runtime
deliverables blocked on this host, and the release-readiness wrapper outside
the sandbox. The wrapper includes `swift build`, the full test suite, GOAL
codewise closure probes, GOAL runtime evidence template probes, GOAL runtime
preflight probes, GOAL completion audit probes with blocker `nextActions`, and
release-readiness CLI probes. Manual hardware, signing, notarization,
Gatekeeper, clean-Mac, and benchmark gates remained open.

Latest current-tree release-readiness rerun after the 2026-05-09
source-level audit closure and handoff documentation updates passed with final
`VERDICT: PASS`. The wrapper completed docs, shellcheck, release hygiene,
`swift build`, `swift test --no-parallel`, GOAL probes, and release-readiness
CLI probes, while still reporting runtime, open-source release, and manual
evidence gates as `PARTIAL`.

Current machine-preflight refresh from 2026-05-11:

| Command | Result |
|---|---|
| Source-level audit closure | Historical audit remediation, dedup/refactor resolution, stale finding re-scope, and historical-finding boundary are closed; this does not promote real-world gates to PASS. |
| `.build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-current.json` and validator | `VERDICT: PARTIAL`; 93 mapped items, 77 pass, 16 partial, 26 blockers, `real-world-verdict: partial`. |
| `.build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight-current.json` and validator | `VERDICT: PARTIAL`; 10 runtime deliverables are partial. |
| `.build/debug/open-lola open-source-release-readiness-run --output /private/tmp/open-lola-open-source-release-readiness-current.json` and validator | `VERDICT: PARTIAL`; 9 requirements, 6 release blockers. |
| `security find-identity -v -p codesigning` | 1 valid codesigning identity, 0 Developer ID Application identities. |
| `bash scripts/verify-release-readiness.sh` | PASS with product probes still `PARTIAL`; docs, shellcheck, hygiene, build, and non-parallel Swift tests passed. |

The 2026-05-11 runtime preflight saw 0 captured Core Audio devices, 0 RME MADI
candidates, 0 video devices, 0 Blackmagic/ATEM candidates, denied camera
permission, and no Developer ID Application identity. This confirms the active
source-level work is closed enough for handoff, but full product completion is
still blocked on real hardware, permissions, two-Mac route evidence,
signing/notarization/clean-Mac evidence, license decisions, fixture provenance,
reviewer signoff, and public release approval.

## Archived Detail

Archive root:
[../archive/2026-05-05-doc-consolidation/](../archive/2026-05-05-doc-consolidation/)

Major archived lanes:

- old public historical snapshots: `archive/2026-05-05-doc-consolidation/docs/historical/`
- internal review/audit docs: `archive/2026-05-05-doc-consolidation/docs/review/`
- deprecated research: `archive/2026-05-05-doc-consolidation/research/deprecated-research/`
- deprecated reverse-engineering notes: `archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/`
- old mac-port history, milestones, report notes, progress/index files, and F01-F12 companions: `archive/2026-05-05-doc-consolidation/mac-port/`
- superseded workflow docs and internal generated RE evidence:
  `archive/2026-05-05-workflow-consolidation/`
- latest active-tree plan/remediation cleanup:
  `archive/2026-05-11-doc-cleanup/`

Archived files are evidence snapshots. Do not update them for active status or
normal link hygiene. Update this file and the four active companions instead.

## Resume here

Resume here: close Q001 first. Record the real reference Macs, RME MADI
Thunderbolt path, UIDs, TotalMix/clock state, route labels, packet-capture
points, DSCP policy, and thresholds. Then run the RME loopback matrix for
M03/G02, measure the F02 realtime duplex path, certify the F03 direct two-Mac
UDP PCM route, run the F11 byte-exact loopback plus ICMP/traceroute comparison,
add F12 NAT/ISP evidence only after raw-route evidence exists, and run the F04
60-minute drift/PLC proof with the accepted F02 engine report and same-hardware
LoLa baseline. Only after that should video, control, lighting, recording, app,
packaging, clean-Mac, and faster-than-LoLa closure move toward PASS.

VERDICT: PARTIAL
