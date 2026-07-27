# Open Questions

Date: 2026-07-24
Status: active question register after source-alpha evidence refresh
Verdict: PARTIAL

Questions are not considered "answered" by assumption. Runtime-dependent facts
remain open until a milestone records measurements or explicit user or venue
input. This file owns the source-review and probe matrix.

## Current Preflight Blockers

Latest local source refresh: 2026-07-24.

| Gate | Current public result | Human input still required |
|---|---|---|
| Source and policy gates | The available host built the Swift workspace; all 1,094 Swift tests passed, including socket-backed cases; 147 Python tests passed under an existing Python 3.11 environment; documentation, source-documentation, tracked-boundary, release-hygiene, and ShellCheck gates passed. The locked Python environment and Ruff gate did not pass locally. | Exact Swift 6.3.3/Xcode 26.6 and locked Python matrix execution for the approved candidate. |
| Runtime preflight | `PARTIAL`; source, synthetic, and localhost contracts do not close physical evidence gates. | Reference Macs, RME MADI devices, route labels, capture points, Blackmagic/ATEM hardware, lighting target, and field-test environment. |
| Public source alpha | `PARTIAL`; `v0.1.0-alpha.1` is proposed but not tagged or published. | Final licenses, notices, JPEG XS disposition, fixture provenance, reviewer signoff, exact-candidate CI, and explicit release approval. |

No current public hardware inventory was collected. Older local device and
signing counts are not evidence for the proposed candidate.

## Question Dispositions

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

## SOTA Source Refresh And Probe Matrix

This matrix keeps open questions, source checks, and probe routing in one
maintained document.

## Source Refresh

| Area | Current checked source | Implementation consequence |
|---|---|---|
| macOS audio | Apple [Core Audio](https://developer.apple.com/documentation/coreaudio) and [Audio Workgroups](https://developer.apple.com/documentation/audiotoolbox/understanding-audio-workgroups) docs checked 2026-05-02. | Use HAL/AUHAL or `AudioDeviceIOProc`; adopt Audio Workgroups only after measurement. |
| macOS UDP/raw Ethernet | Apple Network [`NWProtocolUDP`](https://developer.apple.com/documentation/network/nwprotocoludp) and [`NWEthernetChannel`](https://developer.apple.com/documentation/network/nwethernetchannel) docs checked 2026-05-02. | Use UDP first; custom Ethernet requires entitlement and is not default. |
| macOS video | Apple AVFoundation, [`AVCaptureVideoDataOutput`](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput), frame-duration, Core Media I/O, and [VideoToolbox](https://developer.apple.com/documentation/videotoolbox) docs checked 2026-05-02. | Use Blackmagic/ATEM inventory first; AVFoundation/test-pattern remains the fallback and generic harness for macOS-exposed capture devices; VideoToolbox is a later bandwidth probe. |
| AVB | Apple [Audio MIDI Setup AVB support](https://support.apple.com/guide/audio-midi-setup/set-up-audio-devices-ams59f301fda/mac) checked 2026-05-02. | AVB remains optional local-network benchmark up to 192 kHz, not default. |
| Opus | IETF [RFC 6716](https://datatracker.ietf.org/doc/rfc6716/) checked 2026-05-02. | Opus remains bandwidth fallback, not fastest musical default. |
| AES67 | AES official [standards store](https://aes.org/publications/standards-store/) checked 2026-05-02 for the AES67-2023 listing. | AES67 is gated interop; measure against direct UDP PCM. |
| Lighting standards | ESTA [published-docs page](https://tsp.esta.org/tsp/documents/published_docs.php) checked 2026-05-02. | Treat ANSI E1.11-2024 and ANSI E1.31-2025 as current checked DMX512-A/sACN references. |
| Art-Net | Official [Art-Net site](https://art-net.org.uk/) checked 2026-05-02. | Art-Net output requires spec review, credit, and OEM-code/licensing review. |
| OSC | [OSC 1.0 specification](https://opensoundcontrol.stanford.edu/spec-1_0.html) checked 2026-05-02. | Use OSC 1.0 semantics for first cue-loop probe. |

## Evidence Matrix Probe Coverage

| ID | Evidence source | Owning milestone | Disposition | Required probe from evidence matrix | Gate to close or defer |
|---|---|---|---|---|---|
| SOTA001 | Burg PLC for NMP, 2024 | M06 | Measurement gate | measure callback CPU p99/max for 16/32/64 frame blocks and compare silence, repeat, Burg, and no-PLC under synthetic loss. | Compare same-deadline PLC candidates against silence/repeat with callback p99/max and no playout growth. |
| SOTA002 | Tilt Loss for Music PLC, 2026 | M06 | Deferred | identify any model small enough for same-block CPU-only inference and test worst-case execution under real callback pressure. | Reject ML PLC for fastest default until a candidate proves bounded same-block CPU execution outside callback risk. |
| SOTA003 | Perceptual Metric Gap for NMP PLC, 2025 | M06 | Measurement gate | define a music PLC corpus with transient, sustained, and polyphonic material plus a no-added-latency acceptance gate. | Define a music PLC corpus and no-added-latency acceptance gate before any non-silence PLC closes. |
| SOTA004 | OVBOX low-delay network audio, 2024 | M01-M03 | Measurement gate | build an analog loopback and acoustic loopback report format that separates interface, OS, network, and playout contributions. | Add report fields separating interface, OS, network, playout, analog, and acoustic latency contributions. |
| SOTA005 | Corelink Audio, AES 2024 | M05 | Measurement gate | compare direct UDP peer-to-peer against a relay route with identical audio devices and fixed buffer targets. | Compare direct UDP peer-to-peer before any relay route can be accepted. |
| SOTA006 | NetMusic3D, 2025 | M06 | Measurement gate | measure channel-count scaling and drift correction separately from the core transport. | Measure channel-count scaling separately from drift correction and core transport. |
| SOTA007 | Zero-delay spatial rendering for immersive NMP, 2025 | M10 | Deferred | benchmark renderer CPU p99 and cache behavior at target frame sizes before any audio-lane adoption. | Do not adopt spatial rendering until audio-lane CPU p99/cache behavior is measured under target frame sizes. |
| SOTA008 | Immersive NMP and XR quality of experience, 2024 | M10 | Measurement gate | define a multimodal QoE test where video stutter is allowed but audio playout target is fixed. | Define multimodal QoE with fixed audio playout and permitted video stutter. |
| SOTA009 | Exploiting latency in NMP design, NIME 2025 | M15 | Deferred | none for fastest path; revisit only after the measured low-latency core exists. | Revisit latency-as-design only after measured low-latency core and field-test criteria exist. |
| SOTA010 | Waveform autoencoding at perceivable latency, NIME 2025 | M06 | Rejected as default | measure full encode/decode plus scheduling latency before any live-mode consideration. | Do not use waveform autoencoding in fastest mode before full encode/decode scheduling latency is measured. |
| SOTA011 | 5G-enabled IoMusT latency/reliability, 2024 | M05 | Deferred | compare 5G, Wi-Fi, and wired campus routes with identical loopback instrumentation. | Measure 5G/Wi-Fi only as fallback routes after wired campus baseline. |
| SOTA012 | Public 4G/5G support for IoMusT, 2024 | M05 | Measurement gate | run route classification that refuses fastest mode unless jitter/loss remain inside the fixed playout target. | Refuse fastest mode on any route whose jitter/loss exceeds fixed playout target. |
| SOTA013 | 5G IoMusT architectures for remote immersive practice, 2024 | M15 | Deferred | none before wired baseline; later measure with carrier and campus edge paths documented. | Carrier and campus-edge routes wait until wired baseline and field-test reporting exist. |
| SOTA014 | Virtual ensemble concert music and networked audio, 2025 | M13 | Source validation partial | define setup UI probes that run outside the audio process and cannot block playout. | M13 records immutable config snapshots and read-only metrics boundaries; runtime app smoke must still prove setup UI cannot block playout. |
| SOTA015 | Composing improvisational cells for NMP, 2025 | M15 | Deferred | none for implementation; revisit for documentation/examples after core measurement exists. | Keep composition/documentation examples out of implementation until core measurement exists. |
| SOTA016 | JackTrip | M05 | Measurement gate | compare JackTrip-style redundancy and DSCP marking against plain one-block UDP PCM on the target campus path. | Compare redundancy and DSCP against plain one-block UDP PCM on the same campus path. |
| SOTA017 | AOO | M11 | Measurement gate | measure whether AOO-like control messages can be reused without coupling them to playout buffering. | Reuse AOO-like control ideas only if they stay outside playout buffering. |
| SOTA018 | SonoBus | M06 | Measurement gate | compare manual/fixed jitter targets against adaptive SonoBus-like policy under burst loss. | Compare manual fixed jitter target against adaptive policy without allowing default buffer growth. |
| SOTA019 | Jamulus | M05 | Deferred | measure server-mediated routes only after peer-to-peer baseline and relay decision criteria exist. | Server-mediated routes require peer-to-peer baseline and relay decision criteria first. |
| SOTA020 | JUCE realtime audio thread patterns | M02-M03 | Policy resolved | compare direct Core Audio IOProc/AUHAL against any JUCE wrapper on the same interface and frame sizes. | Direct Core Audio IOProc/AUHAL remains the baseline before any wrapper comparison. |
| SOTA021 | Direct Core Audio IOProc | M02-M03 | Measurement gate | verify accepted buffer size, safety offset, reported latency, callback p99/max, and analog loopback. | Verify accepted buffer size, safety offset, reported latency, callback p99/max, and analog loopback. |
| SOTA022 | Audio Workgroups | M06 | Measurement gate | prove any workgroup helper reduces missed deadlines before adopting it. | Adopt Audio Workgroups only after helper threads reduce missed deadlines. |
| SOTA023 | Core Audio buffer frame size | M02 | Measurement gate | map supported frame-size ranges for built-in, USB, Thunderbolt, AVB, and aggregate devices. | Map frame-size ranges for built-in, USB, Thunderbolt, AVB, and aggregate devices. |
| SOTA024 | Core Audio device latency property | M02-M03 | Measurement gate | compare reported properties to analog loopback per device. | Treat Core Audio latency properties as diagnostic until analog loopback confirms them. |
| SOTA025 | IEEE 1588-2019 PTP plus 2024 amendments | M07 | Measurement gate | read the applicable PTP profile and measure clock error on the target switches/endpoints. | Record applicable PTP profile and measured clock error on target switches/endpoints. |
| SOTA026 | PTP v2.1 current version note | M07 | Measurement gate | document campus PTP domains and whether endpoints actually lock to them. | Document campus PTP domains and endpoint lock state. |
| SOTA027 | AES67-2023, published/current in 2024 | M07 | Measurement gate | read full AES67-2023, then measure AES67 endpoints against direct UDP PCM on identical hardware. | Read full AES67-2023 before measuring endpoints against direct UDP PCM. |
| SOTA028 | AES67 standards news, 2024 | M07 | Measurement gate | classify target campus paths as local, enterprise-routed, or unsuitable before AES67 tests. | Classify campus paths before AES67 tests. |
| SOTA029 | Dante ST 2110-30/AES67 96 kHz update, 2025 | M07 | Measurement gate | measure DVS or hardware Dante one-way/round-trip latency and record firmware/controller versions. | Measure Dante software or hardware endpoint latency with firmware/controller versions. |
| SOTA030 | RAVENNA/AES67 | M07 | Measurement gate | measure with actual RAVENNA-capable endpoints and document clock master, PTP profile, and stream format. | Measure actual RAVENNA endpoints and record clock/profile/stream format. |
| SOTA031 | Merging ALSA RAVENNA/AES67 driver | M07 | Deferred | compile/test on a Linux measurement host and compare against direct Mac UDP PCM. | Linux RAVENNA driver comparison waits for a Linux measurement host. |
| SOTA032 | TSN in low-latency cyber-physical systems, 2024 | M07 | Measurement gate | measure worst-case latency under competing traffic, not only idle mean latency. | TSN claims require worst-case latency under competing traffic. |
| SOTA033 | Software-defined TSN cross-domain deterministic transmission, 2024 | M05 | Measurement gate | verify DSCP/QoS markings hop-by-hop and record rewritten/ignored markings. | DSCP/QoS markings must be captured hop-by-hop. |
| SOTA034 | Microservices-based TSN control plane, 2024 | M07 | User input required | document required switch/controller configuration before any TSN demo claim. | TSN demos require switch/controller feature inventory before implementation. |
| SOTA035 | Dynamic stream partitioning for TSN, 2024 | M10 | Measurement gate | stress audio with simultaneous video and lighting control streams on target switches. | Stress audio with simultaneous video and lighting control on target switches. |
| SOTA036 | Improved worst-case response-time analysis for AVB traffic, 2024 | M07 | Measurement gate | create WCRT-style stress scenarios with saturated non-audio traffic. | AVB reports require WCRT-style saturated non-audio traffic cases. |
| SOTA037 | Improved AVB-aware scheduling in TSN, 2025 | M07 | Measurement gate | test audio WCRT with and without concurrent scheduled video/control streams. | Compare audio WCRT with and without scheduled video/control streams. |
| SOTA038 | Unified inter-domain TSN QoS signaling, 2025 | M05 | Measurement gate | classify every route as honored, rewritten, ignored, or harmful for DSCP/QoS. | Classify every route as honored, rewritten, ignored, or harmful for DSCP/QoS. |
| SOTA039 | JPEG XS FPGA entropy encode/decode, 2024 | M09-M10 | Deferred | measure end-to-end video glass-to-glass latency and CPU/GPU isolation from audio. | JPEG XS must prove glass-to-glass latency and isolation from audio before adoption. |
| SOTA040 | JPEG XS FEC for low-latency streams, 2024 | M09 | Deferred | test FEC CPU/network overhead while audio callback runs at target frame sizes. | JPEG XS FEC waits for CPU/network overhead tests under audio load. |
| SOTA041 | JPEG XS Fraunhofer 2025 update | M09 | Deferred | identify Mac-available encoder/decoder paths and measure isolation from Core Audio. | Mac-available JPEG XS paths must be identified before implementation. |
| SOTA042 | RTP payload for JPEG XS third edition draft, 2025 | M09 | Implementation gate | re-check draft status before implementation and compare against RFC 9134. | Re-check JPEG XS RTP draft/RFC status before implementation. |
| SOTA043 | FPGA visually lossless JPEG XS encoder, 2025 | M09 | Deferred | identify available hardware and measure glass-to-glass latency with audio load. | FPGA video requires available hardware and glass-to-glass testing. |
| SOTA044 | RIST vs SRT 2024 comparison | M09 | Deferred | if tested, pin configured latency and prove audio remains on independent UDP PCM. | RIST/SRT remain WAN video fallback candidates with pinned latency only. |
| SOTA045 | UltraGrid | M10 | Measurement gate | run UltraGrid side-by-side with open-lola audio and verify no CPU/network interference. | UltraGrid can be side-by-side reference only after audio baseline exists. |
| SOTA046 | Apple AVFoundation capture | M08 | Measurement gate | measure capture callback latency and frame-drop policy under audio stress. | Measure AVFoundation capture latency and frame-drop policy under audio stress. |
| SOTA047 | Apple AVCaptureVideoDataOutput | M08-M10 | Measurement gate | quantify frame age at display and enforce video queue caps. | Quantify frame age at display and enforce video queue caps. |
| SOTA048 | Apple VideoToolbox | M09 | Measurement gate | measure VideoToolbox realtime mode, frame reordering settings, and CPU/GPU contention. | Measure VideoToolbox realtime mode, frame reordering, queue depth, and contention. |
| SOTA049 | ANSI E1.11-2024 DMX512-A | M12 | Implementation gate | read full ANSI E1.11-2024 before any DMX gateway claims. | Read full ANSI E1.11-2024 before any DMX gateway claim. |
| SOTA050 | ANSI E1.31-2025 sACN | M12 | Source validation partial | read full standard, then test one configured universe with packet timing and network isolation. | M12 records current E1.31-2025 identity and enforces explicit arm/isolation; full standard access and one configured universe with packet timing remain required. |
| SOTA051 | ANSI E1.20-2025 RDM | M12 | Implementation gate | read full E1.20-2025 and verify gateway support before implementing discovery. | Read full E1.20-2025 and verify gateway support before RDM discovery. |
| SOTA052 | ANSI E1.37-5-2024 RDM general messages | M12 | Implementation gate | read full standard before exposing general RDM parameters. | Read full E1.37-5-2024 before general RDM parameters. |
| SOTA053 | ANSI E1.17-2015 (R2025) ACN | M12 | Implementation gate | read ACN before designing a reusable lighting control model. | Read ACN before reusable lighting model design. |
| SOTA054 | ANSI E1.33-2019 RDMnet | M12 | Implementation gate | read full E1.33 and test only on isolated control networks. | Read full E1.33 and use isolated control networks only. |
| SOTA055 | ANSI E1.59-2021 (R2025) Object Transform Protocol | M12 | Implementation gate | read full E1.59 before mapping tracker data to lighting or spatial audio. | Read E1.59 before tracking-to-lighting or spatial-audio mapping. |
| SOTA056 | Art-Net 4 specification, 2024 PDF | M12 | Source validation partial | read the full spec and test unicast, broadcast, sequence, and sync behavior with OLA/QLC+. | M12 records official Art-Net 4 source and blocks broadcast unless policy allows it; full spec review and unicast/broadcast/sequence/sync tests with OLA/QLC+ remain required. |
| SOTA057 | Art-Net official site | M12 | User input required | verify current licensing/OEM terms before release. | M12 records credit/OEM-code licensing disposition as a release gate; verify actual OEM code and credit terms before release. |
| SOTA058 | Open Sound Control 1.0 | M11 | Measurement gate | define timestamp/cue semantics and measure cue jitter separately from audio. | Define OSC timestamp/cue semantics and measure cue jitter separately from audio. |
| SOTA059 | OSC 1.1 note | M11 | Measurement gate | test against Chataigne, Open Stage Control, and QLC+/OLA OSC behavior. | Test OSC 1.0 behavior against Chataigne, Open Stage Control, and QLC+/OLA. |
| SOTA060 | MIDI Show Control | M12 | Deferred | identify actual venue devices/software that require MSC. | MSC requires actual venue device/software demand. |
| SOTA061 | MIDI 2.0 core specification collection, 2025 | M12 | Deferred | test OS/framework support and target-device availability before implementation. | MIDI 2.0 waits for OS/framework and target-device availability. |
| SOTA062 | MIDI 2.0 UMP and jitter reduction timestamp concepts | M12 | Deferred | map MIDI timestamps to the open-lola show clock without coupling to audio callback work. | MIDI timestamp mapping must not touch audio callback work. |
| SOTA063 | Open Lighting Architecture | M12 | Measurement gate | M12 has an interop target field and PASS guards; measure OLA output jitter for sACN and Art-Net with audio running. | Measure OLA sACN/Art-Net output jitter while audio runs. |
| SOTA064 | OLA GitHub | M12 | Policy resolved | decide whether open-lola should talk to OLA first instead of direct DMX-over-IP. | M12 keeps direct DMX-over-IP output blocked and uses OLA/QLC+ as the first probe path. |
| SOTA065 | QLC+ Art-Net/sACN behavior | M12 | Measurement gate | M12 synthetic fixture targets QLC+ first; test one configured sACN universe and one Art-Net universe against QLC+ with jitter logging. | Test one sACN and one Art-Net universe against QLC+ with jitter logging. |
| SOTA066 | Open Fixture Library | M12 | User input required | verify whether required HfMT fixtures exist or can be imported cleanly. | Actual HfMT fixture availability must be verified before fixture metadata work. |
| SOTA067 | Open Fixture Library GitHub | M12 | Measurement gate | validate fixture JSON import/export round trips with actual target fixtures. | Validate fixture JSON round trips with actual target fixtures. |
| SOTA068 | libE131 | M12 | Deferred | compare libE131 behavior against E1.31-2025 and OLA/QLC+ interop. | libE131 remains an implementation reference only after E1.31-2025 and OLA/QLC+ interop. |
| SOTA069 | Chataigne | M11 | Measurement gate | measure cue jitter and message mapping between open-lola OSC and Chataigne modules. | Measure cue jitter and message mapping with Chataigne. |
| SOTA070 | Open Stage Control | M11 | Measurement gate | test headless server mode and round-trip OSC cue timing. | Test Open Stage Control headless server and round-trip OSC cue timing. |
| SOTA071 | OpenFollow, 2026 preview | M12 | Deferred | test actual output formats and timestamp behavior once available. | OpenFollow waits for actual output formats and timestamp behavior. |
| SOTA072 | PosiStageNet | M12 | Deferred | map PSN timestamps/coordinates to the open-lola show clock without audio dependency. | PSN mapping waits until show-clock input adapters are needed. |
| SOTA073 | Tally Arbiter | M15 | Deferred | none until open-lola has multiple control inputs/outputs. | Tally Arbiter is out until multiple control inputs/outputs exist. |
| SOTA074 | Impact of Audio Delay and Quality in Network Music Performance, 2025 | M01-M03 | Measurement gate | define pass/fail thresholds for audio latency, dropout rate, and subjective musical usability. | Define pass/fail thresholds for audio latency, dropout rate, and musical usability. |
| SOTA075 | Characterisation of Teensy 4.1 ecosystem for low-latency audio NMP, 2025 | M01-M03 | Measurement gate | compare Mac built-in audio, USB/Thunderbolt interface, and embedded endpoint timing. | Compare built-in, USB/Thunderbolt, and embedded endpoint timing where available. |
| SOTA076 | A novel low-latency scheduling approach of TSN for multi-link rate networking, 2024 | M07 | Measurement gate | repeat measurements on each topology instead of reusing one deterministic result. | Repeat TSN measurements per topology. |
| SOTA077 | Efficient Robust Schedules time-aware shaping for TSN, 2024 | M07 | Measurement gate | test TAS/TSN under bursty video/control/background traffic. | Test TAS/TSN under bursty video/control/background traffic. |
| SOTA078 | Advancing TSN flow scheduling without flow-isolation constraint, 2024 | M07 | Measurement gate | compare isolated audio schedule versus mixed schedule on same switches. | Compare isolated audio schedule against mixed schedule. |
| SOTA079 | Development of deterministic communication based on software-defined TSN, 2024 | M07 | User input required | define required switch features, controller settings, and verification commands. | Required switch features, controller settings, and verification commands must be known. |
| SOTA080 | Cyclic queuing and forwarding with preemption in TSN, 2024 | M07 | User input required | determine whether campus switches expose CQF/preemption and measure impact. | Campus CQF/preemption support must be identified before testing. |
| SOTA081 | Optimizing traffic scheduling using ML and TSN, 2024 | M07 | Deferred | revisit only if a deterministic, inspectable controller exists on the target network. | ML TSN scheduling waits for deterministic inspectable controller availability. |
| SOTA082 | FPGA-based visually lossless JPEG XS encoder, 2025 | M09 | Deferred | test with real hardware before designing abstractions around it. | FPGA JPEG XS abstractions require real hardware first. |
| SOTA083 | Design of a low-latency video encoder for reconfigurable hardware, 2025 | M09 | Deferred | measure hardware encoder latency against VideoToolbox and raw/intra-frame modes. | Hardware encoder latency must beat or justify VideoToolbox/raw modes. |
| SOTA084 | RTP payload format for JPEG XS third edition, 2025-2026 draft stream | M09 | Implementation gate | re-check datatracker status and compare against RFC 9134 at implementation time. | Re-check JPEG XS RTP datatracker status and RFC 9134 at implementation time. |
| SOTA085 | ANSI E1.31-2025 current sACN revision | M12 | Source validation partial | read full E1.31-2025 and validate IPv4/IPv6, synchronization, priority, and universe behavior against OLA/QLC+. | M12 records the current sACN revision and one-universe gate; full IPv4/IPv6, synchronization, priority, and universe behavior validation against OLA/QLC+ remains required. |

## Milestone Routing Summary

| Milestone | SOTA responsibility |
|---|---|
| M01 | Hardware inventory, report schema, audio latency thresholds, and reference route labels. |
| M02 | Core Audio inventory, accepted sample rates, buffer ranges, device latency diagnostics, and callback-safe reporting. |
| M03 | Analog loopback, 16/32/64/128-frame matrix, 48/96/192 kHz comparison, and fastest stable endpoint mode. |
| M04 | Strict native UDP PCM packet contract with one block per datagram in fastest mode. |
| M05 | Direct UDP route report validation and physical evidence fields exist; physical UDP route certification, DSCP classification, peer-to-peer baseline, and fallback-route rejection criteria remain measurement gates. |
| M06 | Drift/PLC source validation exists; real drift telemetry, same-deadline PLC comparison, fixed playout target proof, and Audio Workgroups adoption remain measurement gates. |
| M07 | AoIP report validation exists; real PTP, AVB, TSN, AES67, RAVENNA, Dante, and WCRT stress remain gated interop measurement lanes. |
| M08 | Test-pattern source validation exists; Blackmagic/ATEM production inventory is first, AVFoundation remains the generic fallback for macOS-exposed capture paths, and measured audio-impact probes remain before any PASS verdict or optional Desktop Video SDK adapter. |
| M09 | Raw transport source validation exists; physical raw/intra-frame route data, VideoToolbox runtime measurements, and JPEG XS/RIST/SRT latency-isolation reports remain gated. |
| M10 | Integrated report source validation exists; measured 30-minute headless A/V stress, multimodal QoE, and proof that video/control load degrades before audio remain gated. |
| M11 | OSC 1.0 cue-loop source validation exists; live loopback, Chataigne, and Open Stage Control interop remain measurement gates. |
| M12 | Lighting gate source validation exists; sACN, Art-Net, DMX/RDM/RDMnet, OLA/QLC+, fixtures, MIDI, PSN, and OTP remain behind standards, explicit arm, isolated-network, packet-capture, and audio-impact gates. |
| M13 | Native app shell source validation exists; UI/setup probes remain outside realtime paths with immutable configuration snapshots and read-only metrics boundaries until runtime app smoke proves app-vs-CLI metrics. |
| M14 | Recording/session artifact source validation, bounded artifact handoff, opt-in raw Core Audio input capture, and opt-in AVFoundation raw frame artifact writing exist; physical hardware recording, disk-pressure stress, and recording-off/recording-on media comparison remain gates. |
| M15 | Packaging field-test source validation and composite F09 readiness handoff exist; Q010 signing identity, real package, notarization, Gatekeeper, clean-Mac field test, fallback-route documentation, and deferred artistic/control integrations remain gates. |

## Manual inputs required

- Input required: [M01 hardware inventory] -> Identify real reference Macs, RME MADI path, and route labels for Q001 -> [use current HfMT Mac pairs / borrow dedicated test Macs / defer hardware closure]
- Input required: [M03 analog loopback setup] -> Provide the physical loopback path and target input/output device UID for Q002-Q003 -> [built-in acoustic probe only / USB or Thunderbolt interface analog loopback / defer M03 measurement]
- Input required: [M05 campus route access] -> Identify packet-capture points and permissions for Q004 -> [direct link only / dedicated switch / campus path with admin coordination]
- Input required: [F12 rendezvous and UDP forwarder host] -> Identify the self-hosted rendezvous/forwarder host, ports, operator, retention policy, and firewall rules for Q011 -> [existing VPS / Proxmox VM / defer NAT compatibility]
- Input required: [F11/F12 route permissions] -> Identify where ICMP, traceroute, UDP echo, DSCP, and packet capture are permitted for Q012 -> [direct lab only / campus with admin coordination / ISP/NAT field run]
- Input required: [M07 timing network] -> Identify PTP, AVB, AES67, RAVENNA, or Dante-capable switches/endpoints for Q005-Q006 -> [no interop hardware / AVB-only / professional AoIP endpoints]
- Input required: [M08 video capture hardware] -> Provide camera permission state, Blackmagic/ATEM/DeckLink/UltraStudio target identity, capture route, and packet-capture point for physical video TX/RX evidence -> [AVFoundation-visible Blackmagic/UVC path / Desktop Video SDK path after license review / defer physical video closure]
- Input required: [M12 lighting safety] -> Choose safe isolated universe, network, fixture target, and blackout behavior for Q009 -> [OLA/QLC+ virtual output / isolated physical fixture / defer live fixture output]
- Input required: [M15 distribution] -> Provide signing identity, notarization account/profile, entitlements, Gatekeeper acceptance target, and clean-Mac target for Q010 -> [ad-hoc local package / Developer ID signed package / defer packaging]
