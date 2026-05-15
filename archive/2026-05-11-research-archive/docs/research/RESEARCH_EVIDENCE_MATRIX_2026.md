# Open Lola Research Evidence Matrix 2026

Back to companion: [RESEARCH_COMPANION_2026.md](RESEARCH_COMPANION_2026.md)

Date: 2026-05-02  
Status: internal research ledger, current after public background-lane restructure
Source refresh date: 2026-05-02  
Canonical companion set: [RESEARCH_COMPANION_2026.md](RESEARCH_COMPANION_2026.md)

Scope: canonical evidence register for matters 1-85. This file records checked
Verdict: PARTIAL
URL/source status, source type, core claim, evidence quality, latency
implication, open-lola implementation implication, confidence, decision, and
required probe for each matter.

Hard rule: no PLC, codec, retransmission, QoS trick, video path, lighting path,
UI feature, or recording feature may increase default audio playout latency.
Robustness features are acceptable in fastest mode only when they operate inside
the same already-due audio block or are proven by measurement to fit inside the
selected fixed playout target.

## Source Status Legend

- `live`: URL opened or checked on 2026-05-02.
- `catalog`: public catalog or preview metadata only; full standard must be read
  before implementation.
- `snapshot`: source repository cloned outside this repo under
  `/tmp/open-lola-research-sources/`.
- `vendor claim`: official vendor/product page, useful for interoperability
  evidence but not enough for fastest-mode latency decisions.
- `mirror`: source is a repository mirror or public copy rather than the owning
  standards body or publisher.

## Source Snapshot Register

Third-party source snapshots were kept outside this repository. They are not
vendored into open-lola.

| Source | URL | Snapshot commit | Local path | Relevant files/functions |
|---|---|---:|---|---|
| JackTrip | <https://github.com/jacktrip/jacktrip.git> | `6b47162f5b16cf25098dd5f22087df7daa2b4451` | `/tmp/open-lola-research-sources/jacktrip` | `src/UdpDataProtocol.cpp` (`setSocketQos`, `receivePacket`, `sendPacket`, `run`), `src/AudioSocket.h` |
| AOO | <https://git.iem.at/aoo/aoo.git> | `dc2a5be2962ba02d6cebe297f31f2774f34e7bc7` | `/tmp/open-lola-research-sources/aoo` | `aoo/src/source.hpp` (`process`, `send`, `send_data`, `resend_data`), `aoo/src/sink.cpp`, `aoo/src/packet_buffer.cpp` (`jitter_buffer`) |
| SonoBus | <https://github.com/sonosaurus/sonobus.git> | `35f1062dab196b9838a4bb529c4bf6592b7f5987` | `/tmp/open-lola-research-sources/sonobus` | `Source/SonobusPluginProcessor.cpp`, `Source/LatencyMeasurer.cpp`, `Source/JitterBufferMeter.cpp`, `doc/SonoBus User Guide.md` |
| Jamulus | <https://github.com/jamulussoftware/jamulus.git> | `670beab09480dc6b1862928b2b5692bff90e151c` | `/tmp/open-lola-research-sources/jamulus` | `src/server.cpp`, `src/client.cpp`, `src/channel.cpp`, `src/buffer.cpp` |
| JUCE | <https://github.com/juce-framework/JUCE.git> | `501c07674e1ad693085a7e7c398f205c2677f5da` | `/tmp/open-lola-research-sources/juce` | `modules/juce_audio_devices/audio_io`, `modules/juce_audio_devices/native`, `modules/juce_audio_formats/codecs/juce_CoreAudioFormat.cpp` |
| Merging RAVENNA/AES67 ALSA | <https://bitbucket.org/MergingTechnologies/ravenna-alsa-lkm.git> | `30de2d555f3b0dc4acb2a764dfaa39ca13387821` | `/tmp/open-lola-research-sources/ravenna-alsa-lkm` | `driver/RTP_audio_stream.c`, `driver/PTP.c`, `driver/module_timer.c`, `driver/module_netlink.c`, `Butler/merging_ravenna_daemon.conf` |
| UltraGrid | <https://github.com/CESNET/UltraGrid.git> | `1e9d9ced0c9a434831f32281cd531ff8a5b84bd2` | `/tmp/open-lola-research-sources/ultragrid` | `src/video_rxtx.cpp`, `src/transmit.cpp`, `src/video_capture/avfoundation.mm`, `src/video_decompress/jpegxs.cpp`, `src/audio/capture/coreaudio.m` |
| OLA | <https://github.com/OpenLightingProject/ola.git> | `c6196f75358244c6e6e3b1779980b6b55fbea2bb` | `/tmp/open-lola-research-sources/ola` | `plugins/e131/E131Device.cpp`, `plugins/e131/E131Port.cpp`, `plugins/artnet/ArtNetNode.cpp`, `plugins/osc/OSCNode.cpp` |
| Open Fixture Library | <https://github.com/OpenLightingProject/open-fixture-library.git> | `6ba7852f6b11e506c5ae9cc9844780d7191e3017` | `/tmp/open-lola-research-sources/open-fixture-library` | `schemas/fixture.json`, `schemas/capability.json`, `plugins/qlcplus_4.12.2`, `plugins/gdtf` |
| libE131 | <https://github.com/hhromic/libe131.git> | `a134b1f818252107b987c1263a5dd04e4dc68bb3` | `/tmp/open-lola-research-sources/libe131` | `src/e131.c`, `src/e131.h`, `examples/test_client.c`, `examples/test_server.c` |
| Chataigne | <https://github.com/benkuper/Chataigne.git> | `4ca1e4af8766011b346ff2340f3771156435b26c` | `/tmp/open-lola-research-sources/chataigne` | `Source/Module/modules/osc`, `Source/Module/modules/dmx`, `Source/Module/modules/midi`, `Source/Module/modules/posistagenet`, `Source/Module/Routing` |
| Open Stage Control | <https://framagit.org/jean-emmanuel/open-stage-control.git> | `b89d254386b7468e15a17258d5b33045de8819ec` | `/tmp/open-lola-research-sources/open-stage-control-framagit` | `src/server/node/osc`, `src/server/node/midi.mjs`, `src/client/osc.mjs`, `src/client/widgets` |
| Tally Arbiter | <https://github.com/josephdadams/TallyArbiter.git> | `95d60c42512ca5d6eb2daedf44aead1adcd902c2` | `/tmp/open-lola-research-sources/tallyarbiter` | `src/sources`, `src/actions/OSC.ts`, `src/actions/UDP.ts`, `src/_models/TallyData.ts` |

Note: the older GitHub URL for the Merging ALSA RAVENNA/AES67 driver returned
`repository not found`; Merging's live product page now points to the Bitbucket
repository recorded above.

## Matrix

### 1. Burg PLC for NMP, 2024

- Source status: live, checked 2026-05-02, <https://link.springer.com/article/10.1007/s00779-024-01806-8>.
- Source type: paper.
- Core claim: Burg/autoregressive PLC can improve music-gap concealment and was evaluated for real-time NMP constraints, including embedded execution.
- Evidence quality: high; open-access peer-reviewed paper with implementation and timing discussion.
- Latency implication: PLC is useful only if it fills a block that is already due; it must not add a lookahead or larger jitter buffer.
- Implementation implication for open-lola: add Burg PLC only behind a same-deadline PLC benchmark, never as the fastest default before silence/repeat fallback is measured.
- Confidence: high.
- Decision: benchmark.
- Open questions and required probe: measure callback CPU p99/max for 16/32/64 frame blocks and compare silence, repeat, Burg, and no-PLC under synthetic loss.

### 2. Tilt Loss for Music PLC, 2026

- Source status: live, checked 2026-05-02, <https://link.springer.com/article/10.1186/s13636-025-00442-1>.
- Source type: paper.
- Core claim: training with a music-oriented perceptual loss can improve ML PLC quality without necessarily changing inference structure.
- Evidence quality: high for the learning objective; medium for fastest-mode deployment because model runtime still depends on implementation.
- Latency implication: improved training does not help if inference exceeds the audio block deadline.
- Implementation implication for open-lola: use as an offline model-selection reference only after a non-ML PLC baseline exists.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: identify any model small enough for same-block CPU-only inference and test worst-case execution under real callback pressure.

### 3. Perceptual Metric Gap for NMP PLC, 2025

- Source status: live, checked 2026-05-02, <https://www.researchgate.net/publication/396189172_On_the_Lack_of_a_Perceptually_Motivated_Evaluation_Metric_for_Packet_Loss_Concealment_in_Networked_Music_Performances>.
- Source type: paper/preprint landing page.
- Core claim: speech-oriented metrics do not fully capture music PLC perception in NMP.
- Evidence quality: medium; source is a public research landing page, not a standards body or implementation repo.
- Latency implication: quality scoring must not reward PLC that sounds smoother by adding playout delay.
- Implementation implication for open-lola: PLC benchmarks need both objective dropout counts and music-specific listening or artifact metrics.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: define a music PLC corpus with transient, sustained, and polyphonic material plus a no-added-latency acceptance gate.

### 4. OVBOX low-delay network audio, 2024

- Source status: live, checked 2026-05-02, <https://acta-acustica.edpsciences.org/articles/aacus/full_html/2024/01/aacus240009/aacus240009.html>.
- Source type: paper.
- Core claim: low-delay network audio should be evaluated by acoustic e2e behavior, not only software timestamps.
- Evidence quality: high; open paper from a relevant acoustics venue.
- Latency implication: reinforces analog or acoustic end-to-end measurement as the acceptance metric.
- Implementation implication for open-lola: reuse measurement framing and headless reporting ideas, but keep the transport simpler than OVBOX until direct UDP PCM is proven.
- Confidence: high.
- Decision: benchmark.
- Open questions and required probe: build an analog loopback and acoustic loopback report format that separates interface, OS, network, and playout contributions.

### 5. Corelink Audio, AES 2024

- Source status: live, checked 2026-05-02, <https://www.researchgate.net/publication/390172710_Corelink_Audio_A_JUCE-based_Networked_Music_Performance_Solution>.
- Source type: paper/vendor-adjacent academic system report.
- Core claim: JUCE plus Corelink can deliver NMP over high-speed research networks, using UDP and a jitter buffer between network and audio threads.
- Evidence quality: medium; useful architecture report, but not primary source code in this pass.
- Latency implication: relay and jitter buffering can be musically acceptable but are not automatically fastest.
- Implementation implication for open-lola: use Corelink as a later relay/federation comparison, not as the fastest direct-lane baseline.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: compare direct UDP peer-to-peer against a relay route with identical audio devices and fixed buffer targets.

### 6. NetMusic3D, 2025

- Source status: live, checked 2026-05-02, <https://www.politesi.polimi.it/handle/10589/240954>.
- Source type: thesis/research repository.
- Core claim: immersive NMP requires explicit handling of multichannel audio, jitter, drift, and software latency.
- Evidence quality: medium; relevant detailed thesis metadata, full conclusions require reading the full thesis.
- Latency implication: immersive processing can consume the same budget needed for musical timing.
- Implementation implication for open-lola: keep multichannel/spatial work modular and benchmarked outside the first stereo/direct UDP baseline.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: measure channel-count scaling and drift correction separately from the core transport.

### 7. Zero-delay spatial rendering for immersive NMP, 2025

- Source status: live, checked 2026-05-02, <https://www.researchgate.net/publication/398758112_Zero-Delay_Spatial_Audio_Rendering_for_Immersive_Networked_Music_Performances>.
- Source type: paper/preprint landing page.
- Core claim: spatial rendering for NMP can be designed around very low perceived latency.
- Evidence quality: medium; public research metadata, implementation details need full-paper review.
- Latency implication: spatial rendering cannot be allowed to sit inside the mandatory audio callback path unless bounded.
- Implementation implication for open-lola: treat spatial rendering as an optional post-capture/post-receive lane.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: benchmark renderer CPU p99 and cache behavior at target frame sizes before any audio-lane adoption.

### 8. Immersive NMP and XR quality of experience, 2024

- Source status: live, checked 2026-05-02, <https://www.fis.uni-hannover.de/portal/de/publications/immersive-networked-music-performance%286aa695fe-cbb0-4b67-98fb-2b21e2fa6a67%29.html>.
- Source type: paper metadata.
- Core claim: immersive/XR NMP quality depends on multimodal experience, not audio latency alone.
- Evidence quality: medium; useful QoE context, not an implementation source.
- Latency implication: video/XR may improve experience but must degrade before audio latency grows.
- Implementation implication for open-lola: later UI/video/XR work should use audio latency as a hard constraint, not a negotiable QoE trade.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: define a multimodal QoE test where video stutter is allowed but audio playout target is fixed.

### 9. Exploiting latency in NMP design, NIME 2025

- Source status: live, checked 2026-05-02, <https://nime.org/proc/nime2025_69/index.html>.
- Source type: paper.
- Core claim: some NMP designs can use latency as a creative parameter.
- Evidence quality: high for artistic design context; low for fastest-mode engineering.
- Latency implication: intentional latency is a fallback artistic mode, not the default product target.
- Implementation implication for open-lola: document creative-latency modes separately from the low-latency performance rig.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: none for fastest path; revisit only after the measured low-latency core exists.

### 10. Waveform autoencoding at perceivable latency, NIME 2025

- Source status: live, checked 2026-05-02, <https://www.nime.org/proc/nime2025_10/>.
- Source type: paper.
- Core claim: neural waveform autoencoding can operate near perceptual latency boundaries in interactive contexts.
- Evidence quality: high for NIME artifact context; medium for production transport.
- Latency implication: neural processing must be counted as end-to-end audio latency and cannot be hidden inside the transport.
- Implementation implication for open-lola: keep neural audio outside fastest transport and record it as a later creative-processing experiment.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: measure full encode/decode plus scheduling latency before any live-mode consideration.

### 11. 5G-enabled IoMusT latency/reliability, 2024

- Source status: live, checked 2026-05-02, <https://iris.unitn.it/handle/11572/382069>.
- Source type: paper/repository metadata.
- Core claim: 5G IoMusT can support remote music scenarios but still requires jitter/latency management.
- Evidence quality: medium; relevant metadata, path-specific results must be read in full.
- Latency implication: mobile networks are access/fallback routes, not the fastest academic-wired target.
- Implementation implication for open-lola: model 5G as a later compatibility mode with larger buffers and explicit non-fastest labeling.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: compare 5G, Wi-Fi, and wired campus routes with identical loopback instrumentation.

### 12. Public 4G/5G support for IoMusT, 2024

- Source status: live, checked 2026-05-02, <https://www.researchgate.net/publication/378818450_Is_Music_in_the_Air_Evaluating_4G_and_5G_Support_for_the_Internet_of_Musical_Things>.
- Source type: paper/preprint landing page.
- Core claim: public mobile networks impose realistic jitter and reliability constraints for IoMusT.
- Evidence quality: medium; relevant research page, not a standard or code source.
- Latency implication: any mobile mode needs more buffering than fastest wired mode.
- Implementation implication for open-lola: do not let mobile-network support change default audio playout behavior.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: run route classification that refuses fastest mode unless jitter/loss remain inside the fixed playout target.

### 13. 5G IoMusT architectures for remote immersive practice, 2024

- Source status: live, checked 2026-05-02, <https://ouci.dntb.gov.ua/en/works/7AJ3OeB4/>.
- Source type: paper metadata/index.
- Core claim: IoMusT architecture work treats 5G as an enabler for immersive remote practice.
- Evidence quality: low/medium; metadata index, full source review needed.
- Latency implication: architecture-level 5G claims are not sufficient for musical e2e guarantees.
- Implementation implication for open-lola: keep 5G architecture as background only until measured on target routes.
- Confidence: low.
- Decision: defer.
- Open questions and required probe: none before wired baseline; later measure with carrier and campus edge paths documented.

### 14. Virtual ensemble concert music and networked audio, 2025

- Source status: live, checked 2026-05-02, <https://www.mdpi.com/2813-2084/4/1/9>.
- Source type: paper.
- Core claim: networked ensemble workflows depend on operational, musical, and technical coordination.
- Evidence quality: medium; useful practice paper, not a low-level transport source.
- Latency implication: workflow support is valuable only if it does not add audio-path work.
- Implementation implication for open-lola: later UX should help setup, rehearsal, and route validation without touching the realtime audio callback.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: define setup UI probes that run outside the audio process and cannot block playout.

### 15. Composing improvisational cells for NMP, 2025

- Source status: live, checked 2026-05-02, <https://www.tandfonline.com/doi/abs/10.1080/13528165.2024.2537577>.
- Source type: paper.
- Core claim: composition can adapt to unavoidable network latency.
- Evidence quality: medium for artistic strategy; low for transport engineering.
- Latency implication: compositional adaptation is a fallback when physical path latency cannot be reduced.
- Implementation implication for open-lola: do not encode artistic-latency assumptions into fastest-mode defaults.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: none for implementation; revisit for documentation/examples after core measurement exists.

### 16. JackTrip

- Source status: live and snapshot, checked 2026-05-02, <https://github.com/jacktrip/jacktrip>.
- Source type: repository.
- Core claim: JackTrip is a mature uncompressed-audio NMP system with UDP packet handling, redundancy, QoS hooks, and cross-platform deployment.
- Evidence quality: high for source behavior; snapshot commit and relevant files recorded above.
- Latency implication: JackTrip proves the importance of small uncompressed UDP blocks, but its redundancy/jitter features remain benchmark choices.
- Implementation implication for open-lola: adopt the discipline of separate UDP/audio responsibilities and packet stats; do not copy adaptive buffering into fastest default.
- Confidence: high.
- Decision: benchmark.
- Open questions and required probe: compare JackTrip-style redundancy and DSCP marking against plain one-block UDP PCM on the target campus path.

### 17. AOO

- Source status: live and snapshot, checked 2026-05-02, <https://git.iem.at/aoo/aoo>.
- Source type: repository.
- Core claim: AOO separates audio-over-OSC style messaging, packet buffering, resend behavior, and jitter handling.
- Evidence quality: high for source design; snapshot commit and files recorded above.
- Latency implication: resend and jitter-buffer logic are useful references but can violate fastest-mode latency if enabled by default.
- Implementation implication for open-lola: study AOO's packet structure and control/data split; reject resend waits for fastest audio.
- Confidence: high.
- Decision: benchmark.
- Open questions and required probe: measure whether AOO-like control messages can be reused without coupling them to playout buffering.

### 18. SonoBus

- Source status: live and snapshot, checked 2026-05-02, <https://github.com/sonosaurus/sonobus>.
- Source type: repository.
- Core claim: SonoBus exposes practical user-facing latency, jitter, PCM, and Opus tradeoffs for real-time network audio.
- Evidence quality: high for source and user-guide behavior.
- Latency implication: automatic jitter growth is useful for general use but conflicts with a hard fixed fastest-mode playout target.
- Implementation implication for open-lola: borrow visible diagnostics and latency measurement ideas, not automatic default buffer growth.
- Confidence: high.
- Decision: benchmark.
- Open questions and required probe: compare manual/fixed jitter targets against adaptive SonoBus-like policy under burst loss.

### 19. Jamulus

- Source status: live and snapshot, checked 2026-05-02, <https://github.com/jamulussoftware/jamulus>.
- Source type: repository.
- Core claim: Jamulus is a widely used server-mix architecture with Opus low-delay configuration and explicit client/server audio mixing.
- Evidence quality: high for source behavior; snapshot commit recorded above.
- Latency implication: relay/server mix adds a topology cost and codec behavior that are not fastest for direct academic paths.
- Implementation implication for open-lola: use Jamulus as a contrast and possible rehearsal fallback model, not fastest baseline.
- Confidence: high.
- Decision: defer.
- Open questions and required probe: measure server-mediated routes only after peer-to-peer baseline and relay decision criteria exist.

### 20. JUCE realtime audio thread patterns

- Source status: live and snapshot, checked 2026-05-02, <https://github.com/juce-framework/JUCE>.
- Source type: repository.
- Core claim: JUCE provides portable audio callbacks and plugin/application infrastructure used by many network audio tools.
- Evidence quality: high for framework source; medium for open-lola fastest-mode suitability.
- Latency implication: abstraction convenience must be benchmarked against direct Core Audio HAL/AUHAL.
- Implementation implication for open-lola: use JUCE only for tools/prototypes unless direct Core Audio measurements show no penalty.
- Confidence: high.
- Decision: benchmark.
- Open questions and required probe: compare direct Core Audio IOProc/AUHAL against any JUCE wrapper on the same interface and frame sizes.

### 21. Direct Core Audio IOProc

- Source status: live, checked 2026-05-02, <https://developer.apple.com/documentation/coreaudio/1422884-audiodevicestart>.
- Source type: official docs.
- Core claim: Core Audio HAL/IOProc is the low-level macOS callback path closest to the device deadline.
- Evidence quality: high; official Apple documentation.
- Latency implication: this is the correct default macOS audio foundation for the fastest path.
- Implementation implication for open-lola: adopt direct Core Audio IOProc/AUHAL for the first serious headless rig.
- Confidence: high.
- Decision: adopt now.
- Open questions and required probe: verify accepted buffer size, safety offset, reported latency, callback p99/max, and analog loopback.

### 22. Audio Workgroups

- Source status: live, checked 2026-05-02, <https://developer.apple.com/documentation/audiotoolbox/understanding-audio-workgroups>.
- Source type: official docs.
- Core claim: Audio Workgroups coordinate real-time threads that share an audio deadline.
- Evidence quality: high; official Apple documentation.
- Latency implication: useful only for bounded helper work that shares the audio deadline; not a way to make arbitrary work realtime-safe.
- Implementation implication for open-lola: benchmark for helper threads after the simpler callback plus SPSC network threads are measured.
- Confidence: high.
- Decision: benchmark.
- Open questions and required probe: prove any workgroup helper reduces missed deadlines before adopting it.

### 23. Core Audio buffer frame size

- Source status: live, checked 2026-05-02, <https://developer.apple.com/documentation/coreaudio/audiohardwaredevice/bufferframesize>.
- Source type: official docs.
- Core claim: device buffer frame size is a first-order latency control and must be queried/set/verified.
- Evidence quality: high; official Apple documentation.
- Latency implication: theoretical frame duration is meaningless unless the device accepted the requested size.
- Implementation implication for open-lola: adopt a buffer-size probe and log requested versus accepted 16/32/64/128 frame sizes.
- Confidence: high.
- Decision: adopt now.
- Open questions and required probe: map supported frame-size ranges for built-in, USB, Thunderbolt, AVB, and aggregate devices.

### 24. Core Audio device latency property

- Source status: live, checked 2026-05-02, <https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertylatency>.
- Source type: official docs.
- Core claim: Core Audio exposes device latency properties that help explain measured e2e results.
- Evidence quality: high; official Apple documentation.
- Latency implication: reported latency is diagnostic, not the final acceptance metric.
- Implementation implication for open-lola: log device and stream latency beside analog loopback results.
- Confidence: high.
- Decision: adopt now.
- Open questions and required probe: compare reported properties to analog loopback per device.

### 25. IEEE 1588-2019 PTP plus 2024 amendments

- Source status: live/catalog, checked 2026-05-02, <https://standards.ieee.org/standard/1588-2019.html>.
- Source type: standard catalog.
- Core claim: IEEE 1588 PTP defines precision clock synchronization used by AVB, AES67, RAVENNA, Dante/ST 2110, and timing-aware systems.
- Evidence quality: high for standard identity; full standard text must be read before implementation.
- Latency implication: PTP can align clocks, but it does not by itself reduce playout latency.
- Implementation implication for open-lola: use PTP as a measurement and interop prerequisite, not a replacement for direct audio deadline design.
- Confidence: high.
- Decision: implementation gate.
- Open questions and required probe: read the applicable PTP profile and measure clock error on the target switches/endpoints.

### 26. PTP v2.1 current version note

- Source status: live, checked 2026-05-02, <https://sagroups.ieee.org/1588/2020/08/27/what-is-the-current-version-of-ptp/>.
- Source type: official working-group note.
- Core claim: IEEE 1588-2019 corresponds to PTP version 2.1 terminology.
- Evidence quality: high for version clarification.
- Latency implication: version/profile confusion can invalidate timing claims.
- Implementation implication for open-lola: record exact PTP version/profile/domain in every AVB/AES67/RAVENNA/Dante report.
- Confidence: high.
- Decision: adopt now.
- Open questions and required probe: document campus PTP domains and whether endpoints actually lock to them.

### 27. AES67-2023, published/current in 2024

- Source status: live/catalog, checked 2026-05-02, <https://aes.org/publications/standards-store/>.
- Source type: standard catalog/preview.
- Core claim: AES67-2023 defines interoperable high-performance audio-over-IP across synchronization, transport, encoding, streaming, SDP/session description, and connection management.
- Evidence quality: high for public AES metadata; full standard review remains required before implementation.
- Latency implication: AES67 targets professional low-latency LANs but still imposes RTP/PTP/session behavior outside open-lola's direct playout control.
- Implementation implication for open-lola: treat AES67 as an interoperability benchmark mode after direct UDP PCM is measured.
- Confidence: high.
- Decision: implementation gate.
- Open questions and required probe: read full AES67-2023, then measure AES67 endpoints against direct UDP PCM on identical hardware.

### 28. AES67 standards news, 2024

- Source status: live, checked 2026-05-02, <https://aes.org/publications/standards-store/>. The older AES blog URL from the survey returned 404 during link checking, while the current AES standards store still lists AES67-2023 public metadata.
- Source type: official standards store/catalog.
- Core claim: AES67 is framed by AES public metadata as high-performance streaming audio-over-IP interoperability for local and enterprise-scale networks.
- Evidence quality: high for AES context and public metadata; not a substitute for the standard.
- Latency implication: matches the academic wired-network target, but does not prove fastest-mode superiority.
- Implementation implication for open-lola: include AES67 only in certified local-network comparison plans.
- Confidence: high.
- Decision: benchmark.
- Open questions and required probe: classify target campus paths as local, enterprise-routed, or unsuitable before AES67 tests.

### 29. Dante ST 2110-30/AES67 96 kHz update, 2025

- Source status: live/vendor claim, checked 2026-05-02, <https://www.audinate.com/press/dante-expands-st-2110-30-and-aes67-support-empowering-greater-interoperability-in-broadcast-workflows/>.
- Source type: vendor docs/press.
- Core claim: Dante Controller support for ST 2110-30 and AES67 configuration, 96 kHz, PTPv2 clock DSCP, RTP payload IDs, and multicast ranges improves practical interop.
- Evidence quality: medium; official vendor claim, needs hardware/firmware verification.
- Latency implication: improves pro-audio workflow but can still add proprietary endpoint buffering.
- Implementation implication for open-lola: test Dante only as a professional interop mode, never as the initial fastest default.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: measure DVS or hardware Dante one-way/round-trip latency and record firmware/controller versions.

### 30. RAVENNA/AES67

- Source status: live, checked 2026-05-02, <https://ravenna-network.com/>.
- Source type: official ecosystem docs.
- Core claim: RAVENNA is a professional IP audio ecosystem aligned with AES67/RTP/PTP workflows.
- Evidence quality: medium/high; official ecosystem source, endpoint behavior depends on vendor devices.
- Latency implication: deterministic network behavior can be strong, but app loses some direct control over playout.
- Implementation implication for open-lola: include RAVENNA/AES67 in hardware interop tests after direct UDP PCM baseline.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: measure with actual RAVENNA-capable endpoints and document clock master, PTP profile, and stream format.

### 31. Merging ALSA RAVENNA/AES67 driver

- Source status: live and snapshot, checked 2026-05-02; product page <https://www.merging.com/products/alsa_ravenna_aes67_driver>, source <https://bitbucket.org/MergingTechnologies/ravenna-alsa-lkm.git>.
- Source type: vendor docs/repository.
- Core claim: Merging's Linux driver uses a kernel module plus daemon for RTP audio, PTP-driven timing, discovery, and RAVENNA/AES67 control.
- Evidence quality: high for public source snapshot and official product docs; vendor performance claims require measurement.
- Latency implication: kernel/daemon design may provide stable AoIP but is not the same as direct app-owned UDP PCM.
- Implementation implication for open-lola: use as a Linux gateway/reference, not as the Mac fastest path.
- Confidence: high.
- Decision: benchmark.
- Open questions and required probe: compile/test on a Linux measurement host and compare against direct Mac UDP PCM.

### 32. TSN in low-latency cyber-physical systems, 2024

- Source status: live, checked 2026-05-02, <https://ntnuopen.ntnu.no/ntnu-xmlui/handle/11250/3160787>.
- Source type: thesis/repository paper.
- Core claim: TSN mechanisms can provide strict latency guarantees when configured as a system.
- Evidence quality: medium; useful survey/checklist source, not a campus guarantee.
- Latency implication: TSN claims are worst-case/network-specific, not portable defaults.
- Implementation implication for open-lola: TSN mode requires a network certification checklist and stress tests.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: measure worst-case latency under competing traffic, not only idle mean latency.

### 33. Software-defined TSN cross-domain deterministic transmission, 2024

- Source status: live, checked 2026-05-02, <https://www.mdpi.com/2079-9292/13/7/1246>.
- Source type: paper.
- Core claim: deterministic TSN across domains needs explicit control-plane coordination.
- Evidence quality: medium/high; relevant paper, browser access may present publisher challenge pages.
- Latency implication: cross-domain paths cannot be assumed deterministic just because endpoints support QoS.
- Implementation implication for open-lola: record administrative domains and switch policies for any network test.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: verify DSCP/QoS markings hop-by-hop and record rewritten/ignored markings.

### 34. Microservices-based TSN control plane, 2024

- Source status: live, checked 2026-05-02, <https://www.mdpi.com/1999-5903/16/4/120/xml>.
- Source type: paper.
- Core claim: TSN deployment depends on control-plane tooling, not only endpoint code.
- Evidence quality: medium; relevant paper, publisher may gate automated access.
- Latency implication: operational complexity can make "deterministic" modes fragile in practice.
- Implementation implication for open-lola: keep fastest mode independent of TSN control-plane availability.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: document required switch/controller configuration before any TSN demo claim.

### 35. Dynamic stream partitioning for TSN, 2024

- Source status: live, checked 2026-05-02, <https://www.sciencedirect.com/science/article/abs/pii/S1389128624003244>.
- Source type: paper.
- Core claim: scheduling scalability matters when many TSN streams share a network.
- Evidence quality: medium; abstract/metadata checked, full paper needed for algorithms.
- Latency implication: adding video/lighting streams can affect audio if all share the same TSN schedule.
- Implementation implication for open-lola: keep audio as the first and protected stream in any deterministic-network plan.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: stress audio with simultaneous video and lighting control streams on target switches.

### 36. Improved worst-case response-time analysis for AVB traffic, 2024

- Source status: live, checked 2026-05-02, <https://colab.ws/articles/10.1109%2Frtss62706.2024.00021>.
- Source type: paper metadata.
- Core claim: AVB deterministic claims require worst-case response-time analysis, not only average timing.
- Evidence quality: medium; metadata source, full IEEE paper needed.
- Latency implication: mean audio latency can look good while WCRT violates musical deadlines.
- Implementation implication for open-lola: acceptance reports must include p99/max and worst observed under load.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: create WCRT-style stress scenarios with saturated non-audio traffic.

### 37. Improved AVB-aware scheduling in TSN, 2025

- Source status: live, checked 2026-05-02, <https://www.sciencedirect.com/science/article/pii/S014036642500249X>.
- Source type: paper.
- Core claim: TSN scheduled traffic can interact negatively with AVB traffic unless scheduling is AVB-aware.
- Evidence quality: medium; paper landing checked, full paper required.
- Latency implication: a campus TSN profile can harm audio if video/control schedules are not modeled.
- Implementation implication for open-lola: require audio-protected scheduling before adding video or lighting to deterministic networks.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: test audio WCRT with and without concurrent scheduled video/control streams.

### 38. Unified inter-domain TSN QoS signaling, 2025

- Source status: live, checked 2026-05-02, <https://www.researchgate.net/publication/396964463_A_Unified_Inter-Domain_QoS_Signaling_Scheme_for_Time-Sensitive_Networking>.
- Source type: paper/preprint landing page.
- Core claim: inter-domain TSN QoS remains an active research problem.
- Evidence quality: medium/low; public research page, not a deployable standard.
- Latency implication: path-wide QoS must be verified, not assumed.
- Implementation implication for open-lola: mark QoS/DSCP as path-certified only.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: classify every route as honored, rewritten, ignored, or harmful for DSCP/QoS.

### 39. JPEG XS FPGA entropy encode/decode, 2024

- Source status: live, checked 2026-05-02, <https://link.springer.com/article/10.1007/s11554-023-01410-8>.
- Source type: paper.
- Core claim: JPEG XS is designed for low-latency, high-quality professional video and can map well to hardware pipelines.
- Evidence quality: high for video codec direction.
- Latency implication: video may be low-latency, but it must never drive audio playout timing.
- Implementation implication for open-lola: evaluate JPEG XS only after audio is stable, with video dropping/degrading first.
- Confidence: high.
- Decision: defer.
- Open questions and required probe: measure end-to-end video glass-to-glass latency and CPU/GPU isolation from audio.

### 40. JPEG XS FEC for low-latency streams, 2024

- Source status: live, checked 2026-05-02, <https://publica.fraunhofer.de/entities/publication/e03b7602-c107-44ef-85e4-71fba399d14b>.
- Source type: paper.
- Core claim: FEC can improve robustness for low-latency JPEG XS streaming without retransmission waits.
- Evidence quality: medium/high; relevant video paper.
- Latency implication: FEC is acceptable for video if it stays out of audio and does not steal realtime resources.
- Implementation implication for open-lola: use FEC only in the video lane and degrade video before audio.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: test FEC CPU/network overhead while audio callback runs at target frame sizes.

### 41. JPEG XS Fraunhofer 2025 update

- Source status: live/vendor claim, checked 2026-05-02, <https://www.fraunhofer.de/en/press/research-news/2025/june-2025/jpeg-xs-forward-looking-standard-for-professional-all-ip-video-production.html>.
- Source type: vendor/research institute news.
- Core claim: professional IP video production continues to position JPEG XS as a low-latency visually lossless direction.
- Evidence quality: medium; official institute update, not an implementation benchmark.
- Latency implication: supports JPEG XS as a video candidate, not an audio decision.
- Implementation implication for open-lola: keep video codec abstraction open for JPEG XS hardware/software tests.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: identify Mac-available encoder/decoder paths and measure isolation from Core Audio.

### 42. RTP payload for JPEG XS third edition draft, 2025

- Source status: live, checked 2026-05-02, <https://www.ietf.org/archive/id/draft-bruylants-avtcore-rtp-jpegxs-3ed-00.html>.
- Source type: standards draft.
- Core claim: JPEG XS packetization is being updated for third-edition RTP payload behavior.
- Evidence quality: medium/high for current standards direction; draft status means not final.
- Latency implication: packetization affects video latency and loss behavior, but remains subordinate to audio.
- Implementation implication for open-lola: do not invent custom JPEG XS packetization before standard RTP payload work is evaluated.
- Confidence: medium.
- Decision: implementation gate.
- Open questions and required probe: re-check draft status before implementation and compare against RFC 9134.

### 43. FPGA visually lossless JPEG XS encoder, 2025

- Source status: live, checked 2026-05-02, <https://colab.ws/articles/10.1109%2Ficma65362.2025.11120545>.
- Source type: paper metadata.
- Core claim: FPGA JPEG XS encoder work confirms hardware-oriented low-latency video remains active.
- Evidence quality: medium; metadata checked, full paper required.
- Latency implication: hardware video can reduce video delay but must not add audio dependency.
- Implementation implication for open-lola: allow later external video hardware adapters without changing audio architecture.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: identify available hardware and measure glass-to-glass latency with audio load.

### 44. RIST vs SRT 2024 comparison

- Source status: live/vendor/industry, checked 2026-05-02, <https://www.rist.tv/articles-and-deep-dives/2024/3/7/2024-rist-vs-srt-comparison>.
- Source type: vendor/industry article.
- Core claim: RIST/SRT video transports rely on configurable latency, retransmission, and/or FEC choices.
- Evidence quality: medium; useful industry overview, not primary standard text.
- Latency implication: retransmission latency is unacceptable for fastest audio but may be valid for later WAN video.
- Implementation implication for open-lola: keep RIST/SRT out of fastest audio; consider only for degradable video over WAN.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: if tested, pin configured latency and prove audio remains on independent UDP PCM.

### 45. UltraGrid

- Source status: live and snapshot, checked 2026-05-02, <https://github.com/CESNET/UltraGrid>.
- Source type: repository.
- Core claim: UltraGrid is a mature academic low-latency A/V transport with many capture, codec, RTP, and display paths.
- Evidence quality: high for source design and feature surface.
- Latency implication: useful video/A/V reference, but integration must not couple video timing to audio playout.
- Implementation implication for open-lola: study UltraGrid capture/RTP/measurement patterns after direct audio baseline.
- Confidence: high.
- Decision: defer.
- Open questions and required probe: run UltraGrid side-by-side with open-lola audio and verify no CPU/network interference.

### 46. Apple AVFoundation capture

- Source status: live, checked 2026-05-02, <https://developer.apple.com/documentation/avfoundation/capture-setup>.
- Source type: official docs.
- Core claim: AVFoundation is the native macOS capture framework for camera/video input.
- Evidence quality: high; official Apple documentation.
- Latency implication: capture must be configured to drop or reduce video load before affecting audio.
- Implementation implication for open-lola: use AVFoundation for first Mac video capture adapter, outside the audio process.
- Confidence: high.
- Decision: defer.
- Open questions and required probe: measure capture callback latency and frame-drop policy under audio stress.

### 47. Apple AVCaptureVideoDataOutput

- Source status: live, checked 2026-05-02, <https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput>.
- Source type: official docs.
- Core claim: direct sample-buffer video output supports explicit frame handling rather than high-level playback pipelines.
- Evidence quality: high; official Apple documentation.
- Latency implication: video frames should be dropped late rather than delaying audio or building a queue.
- Implementation implication for open-lola: design video receive/display queues with "latest useful frame" behavior.
- Confidence: high.
- Decision: defer.
- Open questions and required probe: quantify frame age at display and enforce video queue caps.

### 48. Apple VideoToolbox

- Source status: live, checked 2026-05-02, <https://developer.apple.com/documentation/videotoolbox>.
- Source type: official docs.
- Core claim: VideoToolbox is Apple's hardware-accelerated video compression/decompression framework.
- Evidence quality: high; official Apple documentation.
- Latency implication: encoder/decode configuration must avoid frame reordering and isolate work from Core Audio.
- Implementation implication for open-lola: use only for bandwidth-constrained video mode, not first audio benchmark.
- Confidence: high.
- Decision: defer.
- Open questions and required probe: measure VideoToolbox realtime mode, frame reordering settings, and CPU/GPU contention.

### 49. ANSI E1.11-2024 DMX512-A

- Source status: live/catalog, checked 2026-05-02, <https://webstore.ansi.org/standards/esta/ansie1112024>.
- Source type: standard catalog.
- Core claim: DMX512-A defines asynchronous serial digital data transmission for controlling lighting equipment.
- Evidence quality: high for standard identity; full paid standard must be read before implementation.
- Latency implication: DMX is lighting control and must remain outside the audio path.
- Implementation implication for open-lola: understand universe/channel semantics before sending fixture-level output.
- Confidence: high.
- Decision: implementation gate.
- Open questions and required probe: read full ANSI E1.11-2024 before any DMX gateway claims.

### 50. ANSI E1.31-2025 sACN

- Source status: live/catalog, checked 2026-05-02, <https://webstore.ansi.org/standards/esta/ansie1312025>.
- Source type: standard catalog.
- Core claim: sACN carries DMX512-A data over IP using an ACN subset, with network management and synchronization behavior.
- Evidence quality: high for standard identity; full paid standard must be read before implementation.
- Latency implication: sACN is timestamped/control traffic; it must not compete with audio deadlines.
- Implementation implication for open-lola: first DMX-over-IP adapter should be gated by a full E1.31-2025 reading and multicast policy.
- Confidence: high.
- Decision: implementation gate.
- Open questions and required probe: read full standard, then test one configured universe with packet timing and network isolation.

### 51. ANSI E1.20-2025 RDM

- Source status: live/catalog, checked 2026-05-02, <https://webstore.ansi.org/standards/esta/ansie1202025>.
- Source type: standard catalog.
- Core claim: RDM enables bidirectional discovery, addressing, configuration, status, and fault reporting over DMX512 networks.
- Evidence quality: high for standard identity; full paid standard must be read before implementation.
- Latency implication: RDM is management/setup, not a live timing-critical audio or cue path.
- Implementation implication for open-lola: defer RDM to fixture management UI after simple output is stable.
- Confidence: high.
- Decision: implementation gate.
- Open questions and required probe: read full E1.20-2025 and verify gateway support before implementing discovery.

### 52. ANSI E1.37-5-2024 RDM general messages

- Source status: live/catalog, checked 2026-05-02, <https://webstore.ansi.org/standards/esta/ansie1372024>.
- Source type: standard catalog.
- Core claim: E1.37-5 extends RDM general-purpose parameter messages.
- Evidence quality: high for catalog metadata; full standard required.
- Latency implication: fixture metadata/control messages must not run in timing-critical lanes.
- Implementation implication for open-lola: defer until RDM support exists and needs general parameters.
- Confidence: high.
- Decision: implementation gate.
- Open questions and required probe: read full standard before exposing general RDM parameters.

### 53. ANSI E1.17-2015 (R2025) ACN

- Source status: live/catalog, checked 2026-05-02, <https://webstore.ansi.org/standards/esta/ansie1172015r2025>.
- Source type: standard catalog.
- Core claim: ACN defines a broader networked entertainment control architecture underlying sACN concepts.
- Evidence quality: high for standard identity; full standard required.
- Latency implication: ACN layering belongs to lighting/control, not audio callback scheduling.
- Implementation implication for open-lola: read ACN enough to avoid flawed sACN abstractions.
- Confidence: high.
- Decision: implementation gate.
- Open questions and required probe: read ACN before designing a reusable lighting control model.

### 54. ANSI E1.33-2019 RDMnet

- Source status: live/catalog, checked 2026-05-02, <https://webstore.ansi.org/standards/esta/ansie1332019>.
- Source type: standard catalog.
- Core claim: RDMnet transports RDM-compatible device management over IP networks.
- Evidence quality: high for standard identity; full standard required.
- Latency implication: RDMnet is device management and should not share audio realtime resources.
- Implementation implication for open-lola: defer to larger fixture/device management workflows.
- Confidence: high.
- Decision: implementation gate.
- Open questions and required probe: read full E1.33 and test only on isolated control networks.

### 55. ANSI E1.59-2021 (R2025) Object Transform Protocol

- Source status: live/catalog, checked 2026-05-02, <https://webstore.ansi.org/standards/esta/ansie1592021r2025>.
- Source type: standard catalog.
- Core claim: OTP transports position/orientation/velocity data for coordinating visual, audio, automation, and stage systems.
- Evidence quality: high for standard identity; full standard required.
- Latency implication: position streams can guide lighting/spatial systems but must not gate audio playout.
- Implementation implication for open-lola: accept OTP/position data as a later timestamped control input.
- Confidence: high.
- Decision: implementation gate.
- Open questions and required probe: read full E1.59 before mapping tracker data to lighting or spatial audio.

### 56. Art-Net 4 specification, 2024 PDF

- Source status: live, checked 2026-05-02, <https://art-net.org.uk/downloads/art-net.pdf>.
- Source type: official protocol specification.
- Core claim: Art-Net 4 defines practical DMX/RDM-over-Ethernet behavior including ArtDmx, ArtSync, ArtTimeCode, and ArtTrigger.
- Evidence quality: high; official specification PDF is public.
- Latency implication: Art-Net output must be a lighting lane with explicit broadcast/unicast control.
- Implementation implication for open-lola: implement only after internal lighting model exists and network broadcast policy is approved.
- Confidence: high.
- Decision: implementation gate.
- Open questions and required probe: read the full spec and test unicast, broadcast, sequence, and sync behavior with OLA/QLC+.

### 57. Art-Net official site

- Source status: live, checked 2026-05-02, <https://art-net.org.uk/>.
- Source type: official docs/site.
- Core claim: the Art-Net site provides protocol download and OEM/licensing context.
- Evidence quality: high for project/protocol authority.
- Latency implication: licensing/documentation obligations do not affect audio, but protocol behavior must stay in lighting.
- Implementation implication for open-lola: document OEM/credit obligations before publishing Art-Net output.
- Confidence: high.
- Decision: implementation gate.
- Open questions and required probe: verify current licensing/OEM terms before release.

### 58. Open Sound Control 1.0

- Source status: live, checked 2026-05-02, <https://opensoundcontrol.stanford.edu/spec-1_0.html>.
- Source type: official protocol specification.
- Core claim: OSC 1.0 defines address-patterned control messages suitable for high-level show-control cues.
- Evidence quality: high; public protocol spec.
- Latency implication: OSC is control data; it can schedule lighting/cues without touching audio playout.
- Implementation implication for open-lola: adopt OSC first for high-level lighting/show-control prototypes.
- Confidence: high.
- Decision: adopt now.
- Open questions and required probe: define timestamp/cue semantics and measure cue jitter separately from audio.

### 59. OSC 1.1 note

- Source status: live, checked 2026-05-02, <https://opensoundcontrol.stanford.edu/spec-1_1.html>.
- Source type: official protocol note.
- Core claim: OSC 1.1 was not published as a full spec in the same style as OSC 1.0.
- Evidence quality: high for version clarification.
- Latency implication: avoids ambiguous protocol assumptions in control-lane design.
- Implementation implication for open-lola: default to OSC 1.0 semantics unless a target tool explicitly requires another behavior.
- Confidence: high.
- Decision: adopt now.
- Open questions and required probe: test against Chataigne, Open Stage Control, and QLC+/OLA OSC behavior.

### 60. MIDI Show Control

- Source status: live, checked 2026-05-02, <https://midi.org/midi-show-control>.
- Source type: official docs/spec listing.
- Core claim: MIDI Show Control provides standard show cue commands such as GO/STOP/RESUME for theatrical and AV systems.
- Evidence quality: high for standard identity; full PDF should be checked before implementation.
- Latency implication: MSC is cue control and should not affect audio transport.
- Implementation implication for open-lola: add only for venue workflow compatibility after OSC lighting cues work.
- Confidence: high.
- Decision: defer.
- Open questions and required probe: identify actual venue devices/software that require MSC.

### 61. MIDI 2.0 core specification collection, 2025

- Source status: live/catalog, checked 2026-05-02, <https://midi.org/midi-2-0-core-specification-collection>.
- Source type: official docs/spec collection.
- Core claim: current MIDI 2.0 core package includes UMP, MIDI-CI, profile/property exchange, and update history.
- Evidence quality: high for official metadata; full download may require membership/login.
- Latency implication: MIDI 2.0 is control-surface/control-data infrastructure, not audio media transport.
- Implementation implication for open-lola: defer until a concrete controller or show-control device requires it.
- Confidence: high.
- Decision: defer.
- Open questions and required probe: test OS/framework support and target-device availability before implementation.

### 62. MIDI 2.0 UMP and jitter reduction timestamp concepts

- Source status: live, checked 2026-05-02, <https://midi.org/details-about-midi-2-0-midi-ci-profiles-and-property-exchange-updated-june-2023>.
- Source type: official docs/article.
- Core claim: MIDI 2.0 UMP includes timing concepts such as jitter reduction timestamps.
- Evidence quality: medium/high; official article, full spec required for implementation.
- Latency implication: useful model for control-event timing, not a license to add audio delay.
- Implementation implication for open-lola: borrow timestamp discipline for control messages only.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: map MIDI timestamps to the open-lola show clock without coupling to audio callback work.

### 63. Open Lighting Architecture

- Source status: live, checked 2026-05-02, <https://www.openlighting.org/ola/>.
- Source type: official docs.
- Core claim: OLA is a multi-protocol lighting framework and gateway for DMX/Art-Net/sACN/OSC-class workflows.
- Evidence quality: high for project authority.
- Latency implication: OLA can be a lighting backend or interop target, not an audio-lane dependency.
- Implementation implication for open-lola: use OLA as reference/gateway for lighting probes after OSC-first prototype.
- Confidence: high.
- Decision: benchmark.
- Open questions and required probe: measure OLA output jitter for sACN and Art-Net with audio running.

### 64. OLA GitHub

- Source status: live and snapshot, checked 2026-05-02, <https://github.com/OpenLightingProject/ola>.
- Source type: repository.
- Core claim: OLA source includes E1.31/sACN, Art-Net, OSC, and hardware DMX plugin implementations.
- Evidence quality: high; snapshot commit and relevant files recorded above.
- Latency implication: OLA confirms lighting protocols can stay behind a separate plugin/gateway boundary.
- Implementation implication for open-lola: study OLA plugin boundaries before writing protocol adapters.
- Confidence: high.
- Decision: benchmark.
- Open questions and required probe: decide whether open-lola should talk to OLA first instead of direct DMX-over-IP.

### 65. QLC+ Art-Net/sACN behavior

- Source status: live, checked 2026-05-02, <https://docs.qlcplus.org/v5/plugins/art-net> and <https://docs.qlcplus.org/v4/plugins/e1-31-sacn>.
- Source type: official tool docs.
- Core claim: QLC+ documents practical Art-Net and sACN universe/network behavior used by operators.
- Evidence quality: high for interop behavior; not a standards substitute.
- Latency implication: QLC+ is a lighting control target and must not affect audio scheduling.
- Implementation implication for open-lola: make QLC+ a concrete lighting interop target for one-universe probes.
- Confidence: high.
- Decision: benchmark.
- Open questions and required probe: test one configured sACN universe and one Art-Net universe against QLC+ with jitter logging.

### 66. Open Fixture Library

- Source status: live, checked 2026-05-02, <https://open-fixture-library.org/>.
- Source type: official data/tool site.
- Core claim: fixture metadata should be modeled as reusable data, not invented ad hoc per project.
- Evidence quality: high for data-model relevance.
- Latency implication: fixture metadata belongs to setup/offline paths, never the audio callback.
- Implementation implication for open-lola: use or map to OFL JSON before creating a custom fixture schema.
- Confidence: high.
- Decision: defer.
- Open questions and required probe: verify whether required HfMT fixtures exist or can be imported cleanly.

### 67. Open Fixture Library GitHub

- Source status: live and snapshot, checked 2026-05-02, <https://github.com/OpenLightingProject/open-fixture-library>.
- Source type: repository.
- Core claim: OFL source provides fixture schemas, capability schemas, and export/import plugins.
- Evidence quality: high; snapshot commit and files recorded above.
- Latency implication: schema work should be build/setup-time or UI-time only.
- Implementation implication for open-lola: reuse schema concepts and exporters rather than creating single-use fixture abstractions.
- Confidence: high.
- Decision: defer.
- Open questions and required probe: validate fixture JSON import/export round trips with actual target fixtures.

### 68. libE131

- Source status: live and snapshot, checked 2026-05-02, <https://github.com/hhromic/libe131>.
- Source type: repository.
- Core claim: libE131 is a compact C/C++ implementation reference for sACN packet handling.
- Evidence quality: medium/high; useful source reference, but standards text still controls correctness.
- Latency implication: lightweight sACN code can keep lighting overhead low, but must remain outside audio.
- Implementation implication for open-lola: use as packet-structure reference after full E1.31-2025 review.
- Confidence: medium.
- Decision: implementation gate.
- Open questions and required probe: compare libE131 behavior against E1.31-2025 and OLA/QLC+ interop.

### 69. Chataigne

- Source status: live and snapshot, checked 2026-05-02, <https://benjamin.kuperberg.fr/chataigne/>.
- Source type: tool/repository.
- Core claim: Chataigne is an open modular show-control hub supporting OSC, MIDI, DMX, Art-Net, sACN, UDP/TCP, WebSocket, Ableton Link, and PosiStageNet.
- Evidence quality: high for tool feature surface and source module boundaries.
- Latency implication: excellent control-lane interop target; not part of the audio callback.
- Implementation implication for open-lola: use Chataigne to test show-control routing before writing many direct adapters.
- Confidence: high.
- Decision: benchmark.
- Open questions and required probe: measure cue jitter and message mapping between open-lola OSC and Chataigne modules.

### 70. Open Stage Control

- Source status: live and snapshot, checked 2026-05-02, <https://ammd.net/Open-Stage-Control>; source moved to <https://framagit.org/jean-emmanuel/open-stage-control.git>.
- Source type: tool/repository.
- Core claim: Open Stage Control provides a modular OSC/MIDI control surface with a server/client architecture.
- Evidence quality: high for source/tool behavior; GitHub now only redirects by README.
- Latency implication: control UI must remain a client/control surface, not a realtime audio participant.
- Implementation implication for open-lola: use as an operator surface experiment for OSC control messages.
- Confidence: high.
- Decision: defer.
- Open questions and required probe: test headless server mode and round-trip OSC cue timing.

### 71. OpenFollow, 2026 preview

- Source status: live, checked 2026-05-02, <https://openfollow.app/>.
- Source type: tool/vendor/project site.
- Core claim: OpenFollow targets 3D object tracking for lighting, sound, and media with outputs including PSN, OTP, RTTrPM, and OSC.
- Evidence quality: medium; current product/project page, implementation maturity must be verified.
- Latency implication: tracking data is control input and must never gate audio playout.
- Implementation implication for open-lola: accept position/control streams later, but do not become the tracker.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: test actual output formats and timestamp behavior once available.

### 72. PosiStageNet

- Source status: live, checked 2026-05-02, <https://posistage.net/>.
- Source type: protocol/project site.
- Core claim: PSN provides real-time 3D position data for lighting, media, automation, and immersive audio systems.
- Evidence quality: medium/high for protocol identity; implementation details need target-tool testing.
- Latency implication: PSN can drive spatial lighting/media but must stay on the show-control lane.
- Implementation implication for open-lola: add PSN as a later position-data input adapter after OSC control works.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: map PSN timestamps/coordinates to the open-lola show clock without audio dependency.

### 73. Tally Arbiter

- Source status: live and snapshot, checked 2026-05-02, <https://www.tallyarbiter.com/>.
- Source type: tool/repository.
- Core claim: Tally Arbiter aggregates production tally/control state across inputs and actions.
- Evidence quality: high for architecture pattern; not a direct AVL latency source.
- Latency implication: useful model for non-audio state aggregation outside realtime audio.
- Implementation implication for open-lola: consider the aggregation pattern for lighting/show-control state, not media transport.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: none until open-lola has multiple control inputs/outputs.

### 74. Impact of Audio Delay and Quality in Network Music Performance, 2025

- Source status: live, checked 2026-05-02, <https://www.mdpi.com/1999-5903/17/8/337>.
- Source type: paper.
- Core claim: NMP experience is directly shaped by audio delay and quality, with audio remaining the primary product metric.
- Evidence quality: medium/high; relevant paper, browser access may present publisher challenge pages.
- Latency implication: confirms that video/lighting quality cannot justify growing audio delay.
- Implementation implication for open-lola: keep measured audio e2e latency as the top acceptance criterion.
- Confidence: high.
- Decision: adopt now.
- Open questions and required probe: define pass/fail thresholds for audio latency, dropout rate, and subjective musical usability.

### 75. Characterisation of Teensy 4.1 ecosystem for low-latency audio NMP, 2025

- Source status: live, checked 2026-05-02, <https://colab.ws/articles/10.1109%2Fis264627.2025.11284626>.
- Source type: paper metadata.
- Core claim: embedded low-latency audio experiments highlight hardware, driver, and buffering tradeoffs.
- Evidence quality: medium; metadata checked, full paper required.
- Latency implication: hardware timing matters as much as software architecture.
- Implementation implication for open-lola: measure analog e2e and device behavior before optimizing code paths.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: compare Mac built-in audio, USB/Thunderbolt interface, and embedded endpoint timing.

### 76. A novel low-latency scheduling approach of TSN for multi-link rate networking, 2024

- Source status: live, checked 2026-05-02, <https://www.sciencedirect.com/science/article/pii/S1389128624000161>.
- Source type: paper.
- Core claim: mixed link rates complicate TSN scheduling and latency guarantees.
- Evidence quality: medium; landing checked, full paper required.
- Latency implication: campus paths with mixed 1G/10G/Wi-Fi edges need path-specific certification.
- Implementation implication for open-lola: record every switch/link rate in network benchmark reports.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: repeat measurements on each topology instead of reusing one deterministic result.

### 77. Efficient Robust Schedules time-aware shaping for TSN, 2024

- Source status: live, checked 2026-05-02, <https://www.researchgate.net/publication/384827610_Efficient_Robust_Schedules_ERS_Time-Aware_Shaping_for_Time-Sensitive_Networking>.
- Source type: paper/preprint landing page.
- Core claim: robust TAS scheduling is needed for deterministic behavior under uncertainty.
- Evidence quality: medium; preprint/metadata source.
- Latency implication: idle-path tests are insufficient for audio acceptance.
- Implementation implication for open-lola: include stress traffic in any AVB/TSN acceptance profile.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: test TAS/TSN under bursty video/control/background traffic.

### 78. Advancing TSN flow scheduling without flow-isolation constraint, 2024

- Source status: live, checked 2026-05-02, <https://www.sciencedirect.com/science/article/pii/S1389128624005206>.
- Source type: paper.
- Core claim: TSN scheduling can trade flow isolation against capacity and schedulability.
- Evidence quality: medium; landing checked, full paper required.
- Latency implication: lack of isolation can let non-audio flows affect audio deadlines.
- Implementation implication for open-lola: require audio-flow isolation or measured non-interference before using shared TSN schedules.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: compare isolated audio schedule versus mixed schedule on same switches.

### 79. Development of deterministic communication based on software-defined TSN, 2024

- Source status: live, checked 2026-05-02, <https://www.mdpi.com/2075-1702/12/11/816>.
- Source type: paper.
- Core claim: SD-TSN demonstrates deterministic-network configuration burden and control-plane dependency.
- Evidence quality: high/medium; paper opened successfully.
- Latency implication: deterministic networking is an infrastructure mode, not an app-only toggle.
- Implementation implication for open-lola: create a network profile/certification document before claiming deterministic mode.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: define required switch features, controller settings, and verification commands.

### 80. Cyclic queuing and forwarding with preemption in TSN, 2024

- Source status: live, checked 2026-05-02, <https://saemobilus.sae.org/papers/simulative-assessments-cyclic-queuing-forwarding-preemption-vehicle-time-sensitive-networking-2024-01-1986>.
- Source type: paper metadata.
- Core claim: CQF and frame preemption can affect bounded latency under competing traffic.
- Evidence quality: medium; metadata checked, full paper required.
- Latency implication: preemption/CQF features need target-switch validation.
- Implementation implication for open-lola: treat switch feature claims as experimental profiles, not defaults.
- Confidence: medium.
- Decision: benchmark.
- Open questions and required probe: determine whether campus switches expose CQF/preemption and measure impact.

### 81. Optimizing traffic scheduling using ML and TSN, 2024

- Source status: live, checked 2026-05-02, <https://www.mdpi.com/2079-9292/13/14/2837>.
- Source type: paper.
- Core claim: ML-assisted TSN scheduling is an active research direction.
- Evidence quality: medium; paper source, operational maturity uncertain.
- Latency implication: opaque or dynamic scheduling cannot be trusted for fastest audio without deterministic verification.
- Implementation implication for open-lola: do not use ML scheduling in the first prototype.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: revisit only if a deterministic, inspectable controller exists on the target network.

### 82. FPGA-based visually lossless JPEG XS encoder, 2025

- Source status: live, checked 2026-05-02, <https://colab.ws/articles/10.1109%2Ficma65362.2025.11120545>.
- Source type: paper metadata.
- Core claim: FPGA JPEG XS confirms a hardware path for low-latency high-quality video.
- Evidence quality: medium; same metadata as item 43, full paper required.
- Latency implication: hardware video can be valuable only if it does not steal audio priority.
- Implementation implication for open-lola: keep video hardware adapters modular and degradable.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: test with real hardware before designing abstractions around it.

### 83. Design of a low-latency video encoder for reconfigurable hardware, 2025

- Source status: live, checked 2026-05-02, <https://www.mdpi.com/2227-7080/13/10/433>.
- Source type: paper.
- Core claim: reconfigurable hardware can be used to design low-latency video encoders.
- Evidence quality: medium/high; relevant paper, full implementation relevance needs reading.
- Latency implication: supports keeping video encoder choice modular.
- Implementation implication for open-lola: do not bind the video lane to one software codec; leave room for hardware benchmarks.
- Confidence: medium.
- Decision: defer.
- Open questions and required probe: measure hardware encoder latency against VideoToolbox and raw/intra-frame modes.

### 84. RTP payload format for JPEG XS third edition, 2025-2026 draft stream

- Source status: live, checked 2026-05-02, <https://datatracker.ietf.org/doc/html/draft-ietf-avtcore-rtp-jpegxs-3ed-00>.
- Source type: standards draft.
- Core claim: IETF avtcore is updating the RTP payload format for JPEG XS third edition.
- Evidence quality: high for draft status; final status must be rechecked before implementation.
- Latency implication: standard packetization is the right video transport starting point, but audio remains independent.
- Implementation implication for open-lola: use RFC/draft RTP behavior for JPEG XS instead of custom packetization.
- Confidence: high.
- Decision: implementation gate.
- Open questions and required probe: re-check datatracker status and compare against RFC 9134 at implementation time.

### 85. ANSI E1.31-2025 current sACN revision

- Source status: live/catalog, checked 2026-05-02, <https://webstore.ansi.org/standards/esta/ansie1312025>.
- Source type: standard catalog.
- Core claim: E1.31-2025 is the current public catalog entry for sACN DMX-over-IP revision status.
- Evidence quality: high for catalog metadata; full standard required.
- Latency implication: current sACN behavior matters for lighting correctness but must stay outside audio.
- Implementation implication for open-lola: implement from E1.31-2025, not legacy packet dumps or outdated blog examples.
- Confidence: high.
- Decision: implementation gate.
- Open questions and required probe: read full E1.31-2025 and validate IPv4/IPv6, synchronization, priority, and universe behavior against OLA/QLC+.

## Cross-Item Decisions

| Decision | Matters |
|---|---|
| Adopt now | 21, 23, 24, 26, 58, 59, 74 |
| Benchmark | 1, 3, 4, 5, 16, 17, 18, 20, 22, 28, 29, 30, 31, 32, 33, 35, 36, 37, 38, 63, 64, 65, 69, 75, 76, 77, 78, 79, 80 |
| Defer | 2, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 19, 34, 39, 40, 41, 43, 44, 45, 46, 47, 48, 60, 61, 62, 66, 67, 70, 71, 72, 73, 81, 82, 83 |
| Implementation gate | 25, 27, 42, 49, 50, 51, 52, 53, 54, 55, 56, 57, 68, 84, 85 |
| Reject | None as a research source; reject only specific default behaviors that add audio playout latency, such as retransmission waits, adaptive default jitter growth, video-gated audio, or lighting-triggered audio scheduling. |

## Required Benchmarks And Probes

1. Core Audio HAL/AUHAL/IOProc loopback: accepted buffer frame size, callback p50/p95/p99/max, misses, device/stream latency properties, analog e2e.
2. UDP PCM fastest lane: one datagram per block, sequence/timestamp/header guard, fixed zero/one-block receive target, silence or same-deadline PLC on missing block.
3. PLC lane: silence, repeat, Burg/AR, and any ML PLC must be compared with no increase in playout target.
4. QoS/DSCP lane: classify each network path as honored, rewritten, ignored, or harmful.
5. AVB/TSN/AES67/RAVENNA/Dante lane: record PTP profile/domain/master, stream format, switch path, link rates, and worst-case latency under stress.
6. Video lane: AVFoundation capture, VideoToolbox, UltraGrid, JPEG XS, and RTP/FEC must degrade before audio and must not run inside audio callback resources.
7. Lighting lane: OSC first; sACN and Art-Net only after full standards review, one-universe interop probes, and explicit network policy for multicast/broadcast.

## Paid Standard Gates

The ANSI/IEEE/AES catalog pages above were cited only from public metadata or
preview material. Before implementation that depends on those standards, read
the full purchased/member-access document and record:

- document version and publication/reaffirmation date;
- clauses used for packet/session/timing behavior;
- any licensing or redistribution constraints;
- conformance tests or interop probes required for open-lola.

## Verification Note

No local Markdown link checker was installed (`lychee`, `markdown-link-check`,
and `muffet` were unavailable). Live source verification was done manually
through browser checks plus a local URL sweep on 2026-05-02. The URL sweep of
this companion found 96 unique URLs: 70 returned OK/redirect status, 26 returned
publisher/vendor/standards 403 or challenge responses, and 0 failed.
