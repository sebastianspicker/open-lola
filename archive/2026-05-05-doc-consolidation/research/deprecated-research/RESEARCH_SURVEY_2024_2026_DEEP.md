> Superseded research note (2026-05-02): this file is preserved for historical
> traceability. The canonical research entry point is
> [RESEARCH_COMPANION_2026.md](../RESEARCH_COMPANION_2026.md), with current
> decisions in the focused 2026 companion set.

# Deep Research Survey 2024-2026: Audio, Video, Lighting

Date: 2026-05-02

Evidence companion: `RESEARCH_SURVEY_2024_2026_EVIDENCE_MATRIX.md` records
the live-checked source status, source snapshots, quality/confidence ratings,
latency implications, implementation implications, decisions, and open probes
for matters 1-85. This file remains the concise survey index.

Goal: align the project with current 2024-2026 research and practice for a
Mac-native academic-network system where priority order is:

```text
1. audio
2. video
3. lighting
```

The fastest audio e2e target remains the controlling design constraint.

## Executive Result

The deeper 2024-2026 search reinforces the plan:

- Fastest audio should stay direct Core Audio + uncompressed PCM + UDP on
  certified wired academic paths.
- 16/32-frame and 48/96/192 kHz modes must be selected by measured analog e2e,
  not by theoretical buffer duration.
- TSN/AVB/AES67/RAVENNA/Dante/ST 2110 matter for deterministic academic local
  networks, but must be benchmarked against direct UDP PCM.
- Packet-loss concealment is useful only if it does not grow playout latency.
- Low-latency video research points to JPEG XS, UltraGrid, VideoToolbox, and
  raw/intra-frame paths, but video still cannot be the musical timing gate.
- Lighting should be a separate show-control lane using OSC, sACN, Art-Net,
  RDM/RDMnet, MIDI Show Control, PosiStageNet, and OTP where appropriate.
- Lighting timing should be scheduled against the shared show clock, but
  lighting traffic must never run in or block the audio path.

## Plan Implications

1. Add a lighting/show-control subsystem after audio and video are structurally
   safe.
2. Treat lighting as control data, not media.
3. Prefer high-level timestamped cues for lighting; use full DMX-universe
   streaming only for fixture interoperability.
4. Add `LIGHTING_CONTROL_PROBE_REPORT.md` and
   `INTEGRATED_HEADLESS_AVL_REPORT.md`.
5. Add AVB/TSN/AES67/RAVENNA as a first-class audio-over-IP comparison lane.
6. Add packet-loss concealment as an optional post-fastest-audio research lane.
7. Add JPEG XS and UltraGrid as video study lanes.
8. Keep WebRTC, Opus, 5G, SRT/RIST, and browser stacks out of the fastest audio
   path.

## 50+ Item Study Matrix

This matrix intentionally mixes papers, standards, repositories, software, and
concepts. The criterion is practical relevance to the 2026 SOTA for this system.

### Audio And Networked Music Performance

1. **Burg PLC for NMP, 2024**
   - Source: <https://link.springer.com/article/10.1007/s00779-024-01806-8>
   - Study because: it targets real-time packet-loss concealment for networked
     music, not speech.
   - Plan implication: implement PLC only as optional dropout reduction without
     increasing the 0/1 block playout target.

2. **Tilt Loss for Music PLC, 2026**
   - Source: <https://link.springer.com/article/10.1186/s13636-025-00442-1>
   - Study because: it improves learning objectives for music PLC without
     adding inference-time cost.
   - Plan implication: if using ML PLC, prefer training improvements that do not
     add realtime cost.

3. **Perceptual Metric Gap for NMP PLC, 2025**
   - Source:
     <https://www.researchgate.net/publication/396189172_On_the_Lack_of_a_Perceptually_Motivated_Evaluation_Metric_for_Packet_Loss_Concealment_in_Networked_Music_Performances>
   - Study because: normal speech metrics do not capture music glitch audibility
     well.
   - Plan implication: add music-specific PLC evaluation instead of relying on
     generic audio quality metrics.

4. **OVBOX low-delay network audio, 2024**
   - Source:
     <https://acta-acustica.edpsciences.org/articles/aacus/full_html/2024/01/aacus240009/aacus240009.html>
   - Study because: it is a practical low-delay music/speech system with
     acoustic e2e framing.
   - Plan implication: compare measurement methods and headless operation ideas.

5. **Corelink Audio, AES 2024**
   - Source:
     <https://www.researchgate.net/publication/390172710_Corelink_Audio_A_JUCE-based_Networked_Music_Performance_Solution>
   - Study because: it targets academic high-speed research networks and
     multimodal routing.
   - Plan implication: learn from its JUCE/Corelink architecture, but avoid DAW
     and relay latency in fastest mode.

6. **NetMusic3D, 2025**
   - Source: <https://www.politesi.polimi.it/handle/10589/240954>
   - Study because: it covers immersive NMP, multichannel audio, jitter, clock
     drift, and software latency.
   - Plan implication: study its drift and multichannel handling, but keep our
     fastest path simpler.

7. **Zero-delay spatial rendering for immersive NMP, 2025**
   - Source:
     <https://www.researchgate.net/publication/398758112_Zero-Delay_Spatial_Audio_Rendering_for_Immersive_Networked_Music_Performances>
   - Study because: spatial processing can consume latency budget.
   - Plan implication: spatial audio must be optional and benchmarked outside
     the core fastest stereo/multichannel path.

8. **Immersive NMP and XR quality of experience, 2024**
   - Source:
     <https://www.fis.uni-hannover.de/portal/de/publications/immersive-networked-music-performance%286aa695fe-cbb0-4b67-98fb-2b21e2fa6a67%29.html>
   - Study because: it links XR/spatial audio to NMP QoE.
   - Plan implication: useful for later video/XR modes, not fastest audio.

9. **Exploiting latency in NMP design, NIME 2025**
   - Source: <https://nime.org/proc/nime2025_69/index.html>
   - Study because: it treats latency as a design material.
   - Plan implication: useful fallback philosophy, but opposite of our fastest
     realistic-interaction path.

10. **Waveform autoencoding at perceivable latency, NIME 2025**
    - Source: <https://www.nime.org/proc/nime2025_10/>
    - Study because: it reports interactive neural audio around perceptual
      latency boundaries.
    - Plan implication: neural audio belongs outside fastest transport unless
      its full e2e latency is measured.

11. **5G-enabled IoMusT latency/reliability, 2024**
    - Source: <https://iris.unitn.it/handle/11572/382069>
    - Study because: it gives measured 5G NMP behavior including jitter buffer.
    - Plan implication: 5G remains fallback/access mode, not fastest academic
      wired mode.

12. **Public 4G/5G support for IoMusT, 2024**
    - Source:
      <https://www.researchgate.net/publication/378818450_Is_Music_in_the_Air_Evaluating_4G_and_5G_Support_for_the_Internet_of_Musical_Things>
    - Study because: it shows realistic public mobile-network constraints.
    - Plan implication: confirms that Wi-Fi/mobile are not fastest-mode targets.

13. **5G IoMusT architectures for remote immersive practice, 2024**
    - Source: <https://ouci.dntb.gov.ua/en/works/7AJ3OeB4/>
    - Study because: it is a 2024 architecture-level IoMusT reference.
    - Plan implication: useful for later remote modes; keep out of fastest path.

14. **Virtual ensemble concert music and networked audio, 2025**
    - Source: <https://www.mdpi.com/2813-2084/4/1/9>
    - Study because: it documents practice-based networked performance workflows.
    - Plan implication: useful for UI/workflow later, not core latency.

15. **Composing improvisational cells for NMP, 2025**
    - Source: <https://www.tandfonline.com/doi/abs/10.1080/13528165.2024.2537577>
    - Study because: it addresses composition under network latency.
    - Plan implication: fallback musical strategy if physical latency cannot be
      solved for a route.

16. **JackTrip**
    - Source: <https://github.com/jacktrip/jacktrip>
    - Study because: it is a mature low-latency uncompressed-audio NMP system.
    - Plan implication: study packetization, playout, stats, and deployment
      assumptions.

17. **AOO**
    - Source: <https://git.iem.at/cm/aoo>
    - Study because: it is an audio-over-OSC/NMP-oriented system.
    - Plan implication: study OSC-style network audio/control separation.

18. **SonoBus**
    - Source: <https://github.com/sonosaurus/sonobus>
    - Study because: it is a practical open network audio tool.
    - Plan implication: study user-facing jitter/latency tradeoffs but keep our
      fastest path stricter.

19. **Jamulus**
    - Source: <https://github.com/jamulussoftware/jamulus>
    - Study because: it represents a popular server-based remote rehearsal
      design.
    - Plan implication: useful contrast; relay/server modes are not fastest on
      direct academic paths.

20. **JUCE realtime audio thread patterns**
    - Source: <https://github.com/juce-framework/JUCE>
    - Study because: several 2024/2025 NMP systems use JUCE.
    - Plan implication: useful for plugin/prototype tooling, but fastest native
      Mac path should benchmark direct Core Audio.

### Core Audio, Clocking, And Transport

21. **Direct Core Audio IOProc**
    - Source: <https://developer.apple.com/documentation/coreaudio/1422884-audiodevicestart>
    - Study because: it is the low-level macOS path closest to ASIO-style
      callback audio.
    - Plan implication: first serious audio rig should use direct IOProc/AUHAL.

22. **Audio Workgroups**
    - Source: <https://developer.apple.com/documentation/audiotoolbox/understanding-audio-workgroups>
    - Study because: helper-thread scheduling matters at 16/32 frames.
    - Plan implication: use for realtime-adjacent network/audio helper threads.

23. **Core Audio buffer frame size**
    - Source: <https://developer.apple.com/documentation/coreaudio/audiohardwaredevice/bufferframesize>
    - Study because: hardware buffer size is a core acceptance gate.
    - Plan implication: benchmark 16/32/64/128 frames explicitly.

24. **Core Audio device latency property**
    - Source: <https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertylatency>
    - Study because: reported hardware latency helps explain analog results.
    - Plan implication: log device latency alongside loopback measurements.

25. **IEEE 1588-2019 PTP plus 2024 amendments**
    - Source: <https://standards.ieee.org/standard/1588-2019.html>
    - Study because: clock sync affects audio, video, and lighting alignment.
    - Plan implication: evaluate PTP-capable network paths for show clock and
      AVB/AES67 tests.

26. **PTP v2.1 current version note**
    - Source:
      <https://sagroups.ieee.org/1588/2020/08/27/what-is-the-current-version-of-ptp/>
    - Study because: clarifies 1588-2019 protocol versioning.
    - Plan implication: document exact PTP profile/version in network reports.

27. **AES67-2023, published/current in 2024**
    - Source: <https://www.aes.org/publications/standards/search.cfm?docID=96.>
    - Study because: it defines high-performance interoperable audio-over-IP
      with less than 10 ms live-sound class latency.
    - Plan implication: evaluate as reliable professional mode, not assumed
      fastest.

28. **AES67 standards news, 2024**
    - Source:
      <https://www.aes.org/standards/blog/2024/2/aes67-2023-aes-standard-for-audio>
    - Study because: it frames AES67 for wired LAN and enterprise networks, not
      public Internet.
    - Plan implication: matches academic network assumptions.

29. **Dante ST 2110-30/AES67 96 kHz update, 2025**
    - Source:
      <https://www.audinate.com/press/dante-expands-st-2110-30-and-aes67-support-empowering-greater-interoperability-in-broadcast-workflows/>
    - Study because: professional systems are moving 96 kHz and PTP/DSCP control
      into practical tools.
    - Plan implication: study for academic/pro-audio interop and DSCP/PTP
      lessons.

30. **RAVENNA/AES67**
    - Source: <https://ravenna-network.com/>
    - Study because: it is a professional AES67/RTP/PTP ecosystem.
    - Plan implication: evaluate as deterministic local audio mode.

31. **Merging ALSA RAVENNA/AES67 driver**
    - Source: <https://github.com/MergingTechnologies/ALSA-RAVENNA-AES67-Driver>
    - Study because: open driver code reveals real implementation constraints.
    - Plan implication: Linux-side reference for future gateways or measurement
      hosts.

32. **TSN in low-latency cyber-physical systems, 2024**
    - Source: <https://ntnuopen.ntnu.no/ntnu-xmlui/handle/11250/3160787>
    - Study because: surveys TSN mechanisms for strict latency guarantees.
    - Plan implication: use as AVB/TSN evaluation checklist.

33. **Software-defined TSN cross-domain deterministic transmission, 2024**
    - Source: <https://www.mdpi.com/2079-9292/13/7/1246>
    - Study because: academic networks may cross administrative domains.
    - Plan implication: do not assume QoS across domains unless measured.

34. **Microservices-based TSN control plane, 2024**
    - Source: <https://www.mdpi.com/1999-5903/16/4/120/xml>
    - Study because: TSN configuration/control planes affect deployability.
    - Plan implication: AVB/TSN mode needs operational tooling, not just code.

35. **Dynamic stream partitioning for TSN, 2024**
    - Source: <https://www.sciencedirect.com/science/article/abs/pii/S1389128624003244>
    - Study because: scheduling scalability affects multi-stream environments.
    - Plan implication: keep fastest mode simple before adding many flows.

36. **Improved worst-case response-time analysis for AVB traffic, 2024**
    - Source: <https://colab.ws/articles/10.1109%2Frtss62706.2024.00021>
    - Study because: AVB worst-case latency analysis matters for deterministic
      claims.
    - Plan implication: report worst-case behavior, not only mean latency.

37. **Improved AVB-aware scheduling in TSN, 2025**
    - Source: <https://www.sciencedirect.com/science/article/pii/S014036642500249X>
    - Study because: scheduled traffic can hurt AVB traffic if not modeled.
    - Plan implication: campus TSN design must protect audio flows.

38. **Unified inter-domain TSN QoS signaling, 2025**
    - Source:
      <https://www.researchgate.net/publication/396964463_A_Unified_Inter-Domain_QoS_Signaling_Scheme_for_Time-Sensitive_Networking>
    - Study because: real academic routes may cross QoS domains.
    - Plan implication: DSCP/QoS must be verified per path.

### Video

39. **JPEG XS FPGA entropy encode/decode, 2024**
    - Source: <https://link.springer.com/article/10.1007/s11554-023-01410-8>
    - Study because: JPEG XS is designed for low-latency professional video.
    - Plan implication: later video mode should study JPEG XS before H.264 if
      latency matters.

40. **JPEG XS FEC for low-latency streams, 2024**
    - Source:
      <https://publica.fraunhofer.de/entities/publication/e03b7602-c107-44ef-85e4-71fba399d14b>
    - Study because: FEC can reduce loss without retransmission.
    - Plan implication: useful for video, not audio fastest path unless measured.

41. **JPEG XS Fraunhofer 2025 update**
    - Source:
      <https://www.fraunhofer.de/en/press/research-news/2025/june-2025/jpeg-xs-forward-looking-standard-for-professional-all-ip-video-production.html>
    - Study because: current professional low-latency IP video direction.
    - Plan implication: study for video lane after audio is stable.

42. **RTP payload for JPEG XS third edition draft, 2025**
    - Source:
      <https://www.ietf.org/archive/id/draft-bruylants-avtcore-rtp-jpegxs-3ed-00.html>
    - Study because: packetization matters for low-latency video.
    - Plan implication: if using JPEG XS, use standard RTP payload work.

43. **FPGA visually lossless JPEG XS encoder, 2025**
    - Source: <https://colab.ws/articles/10.1109%2Ficma65362.2025.11120545>
    - Study because: hardware pipelines can keep latency to line-cycle scale.
    - Plan implication: hardware video acceleration is a later option.

44. **RIST vs SRT 2024 comparison**
    - Source: <https://www.rist.tv/articles-and-deep-dives/2024/3/7/2024-rist-vs-srt-comparison>
    - Study because: reliable low-latency video transports use programmable
      latency and retransmission/FEC.
    - Plan implication: useful for video over WAN, not fastest audio.

45. **UltraGrid**
    - Source: <https://github.com/CESNET/UltraGrid>
    - Study because: mature academic low-latency A/V over networks.
    - Plan implication: study capture, codec, RTP, and measurement approaches.

46. **Apple AVFoundation capture**
    - Source: <https://developer.apple.com/documentation/avfoundation/capture-setup>
    - Study because: vendor-neutral Mac camera input.
    - Plan implication: first video capture adapter should be AVFoundation.

47. **Apple `AVCaptureVideoDataOutput`**
    - Source: <https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput>
    - Study because: direct frame delivery avoids high-level playback pipelines.
    - Plan implication: use late-frame discard and explicit formats.

48. **Apple VideoToolbox**
    - Source: <https://developer.apple.com/documentation/videotoolbox>
    - Study because: native hardware video encode/decode path.
    - Plan implication: use for bandwidth-constrained video mode, not first
      audio benchmark.

### Lighting, Show Control, And Shared Timing

49. **ANSI E1.11-2024 DMX512-A**
    - Source: <https://webstore.ansi.org/standards/esta/ansie1112024>
    - Study because: current DMX512-A standard.
    - Plan implication: understand DMX universe payload semantics and physical
      gateway constraints.

50. **ANSI E1.31-2025 sACN**
    - Source: <https://webstore.ansi.org/standards/esta/ansie1312025>
    - Study because: current lightweight DMX-over-IP standard with IPv4/IPv6 and
      synchronization method.
    - Plan implication: first DMX-over-IP standards adapter should include sACN.

51. **ANSI E1.20-2025 RDM**
    - Source: <https://webstore.ansi.org/standards/esta/ansie1202025>
    - Study because: current RDM discovery/config/status over DMX.
    - Plan implication: use only for setup/management, not live fastest cue path.

52. **ANSI E1.37-5-2024 RDM general messages**
    - Source: <https://webstore.ansi.org/standards/esta/ansie1372024>
    - Study because: extends RDM with general parameters.
    - Plan implication: relevant for fixture management UI later.

53. **ANSI E1.17-2015 (R2025) ACN**
    - Source: <https://webstore.ansi.org/standards/esta/ansie1172015r2025>
    - Study because: underlying architecture for networked entertainment
      control.
    - Plan implication: understand ACN layering before implementing sACN deeply.

54. **ANSI E1.33-2019 RDMnet**
    - Source: <https://webstore.ansi.org/standards/esta/ansie1332019>
    - Study because: RDM over IP networks for larger systems.
    - Plan implication: study for device management, not realtime lighting cues.

55. **ANSI E1.59-2021 (R2025) Object Transform Protocol**
    - Source: <https://webstore.ansi.org/standards/esta/ansie1592021r2025>
    - Study because: transfers position/orientation/velocity to coordinate
      visual and audio elements.
    - Plan implication: strong candidate for performer/object position data.

56. **Art-Net 4 specification, 2024 PDF**
    - Source: <https://art-net.org.uk/downloads/art-net.pdf>
    - Study because: common practical DMX/RDM-over-Ethernet protocol with
      ArtDmx, ArtSync, ArtTimeCode, ArtTrigger.
    - Plan implication: implement Art-Net adapter after internal lighting model.

57. **Art-Net official site**
    - Source: <https://art-net.org.uk/>
    - Study because: official protocol/OEM and licensing conditions.
    - Plan implication: document OEM/credit obligations before shipping.

58. **Open Sound Control 1.0**
    - Source: <https://opensoundcontrol.stanford.edu/spec-1_0.html>
    - Study because: OSC is the most practical high-level cue/control protocol.
    - Plan implication: use OSC first for high-level lighting cues.

59. **OSC 1.1 note**
    - Source: <https://opensoundcontrol.stanford.edu/spec-1_1.html>
    - Study because: clarifies that OSC 1.1 is paper-based, not a formal spec
      like 1.0.
    - Plan implication: use OSC 1.0 semantics unless a target tool needs more.

60. **MIDI Show Control**
    - Source: <https://midi.org/midi-show-control>
    - Study because: standard show-control cue commands remain common.
    - Plan implication: add only when venue workflow requires MSC.

61. **MIDI 2.0 core specification collection, 2025**
    - Source: <https://midi.org/midi-2-0-core-specification-collection>
    - Study because: current MIDI 2.0 package includes newer updates and UMP.
    - Plan implication: MIDI 2.0 is useful for control surfaces, not first
      lighting output.

62. **MIDI 2.0 UMP and jitter reduction timestamp concepts**
    - Source:
      <https://midi.org/details-about-midi-2-0-midi-ci-profiles-and-property-exchange-updated-june-2023>
    - Study because: UMP timing ideas are relevant to control-event jitter.
    - Plan implication: use as a control timing reference, not audio transport.

63. **Open Lighting Architecture**
    - Source: <https://www.openlighting.org/ola/>
    - Study because: OLA supports Art-Net, sACN, OSC, RDM, and many DMX devices.
    - Plan implication: use as reference/gateway or optional backend.

64. **OLA GitHub**
    - Source: <https://github.com/OpenLightingProject/ola>
    - Study because: real implementation of multi-protocol lighting adapters.
    - Plan implication: study protocol plugins and Mac support.

65. **QLC+ Art-Net/sACN behavior**
    - Source: <https://docs.qlcplus.org/v5/plugins/art-net>
    - Study because: practical cross-platform lighting controller behavior.
    - Plan implication: interop target for our lighting probe.

66. **Open Fixture Library**
    - Source: <https://open-fixture-library.org/>
    - Study because: fixture definitions are a data-model problem, not just
      protocol output.
    - Plan implication: do not invent fixture metadata if OFL covers enough.

67. **Open Fixture Library GitHub**
    - Source: <https://github.com/OpenLightingProject/open-fixture-library>
    - Study because: schema and export plugins are reusable references.
    - Plan implication: adopt or map to OFL JSON where possible.

68. **libE131**
    - Source: <https://github.com/hhromic/libe131>
    - Study because: small C/C++ sACN packet library.
    - Plan implication: useful reference for a lightweight sACN adapter.

69. **Chataigne**
    - Source: <https://benjamin.kuperberg.fr/chataigne/>
    - Study because: open show-control hub with OSC, MIDI, DMX, Art-Net, sACN,
      TCP/UDP, MQTT, WebSocket, Ableton Link, and PosiStageNet.
    - Plan implication: study as an interop target and workflow reference.

70. **Open Stage Control**
    - Source: <https://osc.ammd.net/>
    - Study because: OSC/MIDI control surface pattern.
    - Plan implication: useful for operator control surface experiments.

71. **OpenFollow, 2026 preview**
    - Source: <https://openfollow.app/>
    - Study because: open 3D tracking/show-control tool with PSN, OTP, RTTrPM,
      and OSC outputs.
    - Plan implication: lighting lane should accept position/control streams
      without becoming the tracking system itself.

72. **PosiStageNet**
    - Source: <https://posistage.net/>
    - Study because: open protocol for live 3D position data used by lighting,
      media, automation, and immersive audio.
    - Plan implication: add as later position-data adapter for spatial lighting
      and audio.

73. **Tally Arbiter**
    - Source: <https://www.tallyarbiter.com/>
    - Study because: open production control aggregation model.
    - Plan implication: useful architecture pattern for non-audio control state.

### Additional 2024-2026 Current-Research Refresh

These items tighten the date window. They are not all first-implementation
dependencies, but they should inform benchmark design and later architecture
decisions.

74. **Impact of Audio Delay and Quality in Network Music Performance, 2025**
    - Source: <https://www.mdpi.com/1999-5903/17/8/337>
    - Study because: it directly evaluates audio delay and quality for NMP
      experience.
    - Plan implication: keep audio e2e latency as the primary product metric;
      video is important for experience, but cannot become the timing gate.

75. **Characterisation of Teensy 4.1 ecosystem for low-latency audio NMP, 2025**
    - Source: <https://colab.ws/articles/10.1109%2Fis264627.2025.11284626>
    - Study because: embedded low-latency audio experiments expose hardware,
      driver, and buffering tradeoffs outside desktop stacks.
    - Plan implication: keep a hardware timing mindset and measure analog e2e,
      not just software timestamps.

76. **A novel low-latency scheduling approach of TSN for multi-link rate networking, 2024**
    - Source: <https://www.sciencedirect.com/science/article/pii/S1389128624000161>
    - Study because: mixed link rates are realistic in campus networks.
    - Plan implication: AVB/TSN tests must record the exact switch path and
      link rates; do not assume one deterministic result transfers to another
      topology.

77. **Efficient Robust Schedules time-aware shaping for TSN, 2024**
    - Source: <https://www.researchgate.net/publication/384827610_Efficient_Robust_Schedules_ERS_Time-Aware_Shaping_for_Time-Sensitive_Networking>
    - Study because: robust TAS scheduling affects whether deterministic
      Ethernet can keep latency stable under mixed load.
    - Plan implication: AVB/TSN certification should include stress traffic,
      not only idle-path measurements.

78. **Advancing TSN flow scheduling without flow-isolation constraint, 2024**
    - Source: <https://www.sciencedirect.com/science/article/pii/S1389128624005206>
    - Study because: practical TSN deployments trade isolation against network
      capacity and schedulability.
    - Plan implication: direct UDP PCM remains the reference baseline; TSN is
      adopted only when measured jitter/latency improves on the target path.

79. **Development of deterministic communication based on software-defined TSN, 2024**
    - Source: <https://www.mdpi.com/2075-1702/12/11/816>
    - Study because: SD-TSN shows the operational burden of configured
      deterministic networks.
    - Plan implication: academic-network mode needs a profile/certification
      document, not a single generic network setting.

80. **Cyclic queuing and forwarding with preemption in TSN, 2024**
    - Source: <https://saemobilus.sae.org/papers/simulative-assessments-cyclic-queuing-forwarding-preemption-vehicle-time-sensitive-networking-2024-01-1986>
    - Study because: CQF and frame preemption are relevant to bounded latency
      under competing traffic.
    - Plan implication: if campus switches expose preemption/CQF features, test
      them as a separate deterministic profile.

81. **Optimizing traffic scheduling using ML and TSN, 2024**
    - Source: <https://www.mdpi.com/2079-9292/13/14/2837>
    - Study because: newer scheduling research explores automated TSN
      configuration.
    - Plan implication: useful for future tooling, but not for the first
      fastest-audio prototype because runtime opacity is a risk.

82. **FPGA-based visually lossless JPEG XS encoder, 2025**
    - Source: <https://colab.ws/articles/10.1109%2Ficma65362.2025.11120545>
    - Study because: hardware JPEG XS confirms the direction for sub-frame,
      low-latency video where quality still matters.
    - Plan implication: JPEG XS belongs in the later video path, especially
      where external hardware encoders are available.

83. **Design of a low-latency video encoder for reconfigurable hardware, 2025**
    - Source: <https://www.mdpi.com/2227-7080/13/10/433>
    - Study because: low-latency video can be optimized with hardware-oriented
      encoders rather than conferencing codecs.
    - Plan implication: keep the software video path modular so hardware video
      encoders can be evaluated without touching audio.

84. **RTP payload format for JPEG XS third edition, 2025-2026 draft stream**
    - Source: <https://datatracker.ietf.org/doc/html/draft-ietf-avtcore-rtp-jpegxs-3ed-00>
    - Study because: transport details matter if JPEG XS becomes the preferred
      video mode.
    - Plan implication: do not invent a custom JPEG XS packetization unless the
      standard RTP payload fails a measured requirement.

85. **ANSI E1.31-2025 current sACN revision**
    - Source: <https://webstore.ansi.org/standards/esta/ansie1312025>
    - Study because: lighting output should track the current sACN revision,
      including IPv4/IPv6 behavior.
    - Plan implication: implement sACN from the current standard, not from
      old blog examples or legacy packet dumps.

## Lighting Architecture Implication

Lighting should not be implemented as "send DMX from the audio process".

Correct shape:

```text
show clock
  -> lighting event queue
  -> lighting scheduler thread
  -> protocol adapter
  -> OSC / sACN / Art-Net / MSC / PSN / OTP
```

The audio engine may publish timing state. It must not publish lighting packets.

Recommended first lighting scope:

1. OSC cue send/receive.
2. sACN output for one configured universe.
3. Art-Net output for one configured universe.
4. Test pattern output and blackout.
5. Cue jitter measurement.
6. Interop with OLA/QLC+/Chataigne.

Defer:

- RDM/RDMnet discovery,
- large fixture library UI,
- moving-light tracking,
- PSN/OTP position streams,
- MIDI 2.0,
- full console replacement behavior.

## Updated Priority Model

Runtime priority:

```text
audio callback
  > audio packet sender/receiver
  > audio drift correction
  > video capture/transport/display
  > lighting cue scheduling
  > lighting universe streaming
  > recording
  > UI
```

Degrade order under load:

```text
lighting visual completeness
  -> lighting update rate
  -> video quality
  -> video frame rate
  -> video off
  -> audio dropout only when unavoidable
```

Never degrade by adding audio latency.

## Concrete Next Study Actions

1. Read JackTrip packet and playout code.
2. Read AOO/SonoBus network and jitter code.
3. Read Corelink Audio paper and compare relay topology against direct UDP.
4. Read NetMusic3D for multichannel/drift design.
5. Read Burg PLC and Tilt Loss papers.
6. Build a PLC benchmark plan that forbids added playout latency.
7. Read AES67-2023 and Dante's 2025 ST 2110/AES67 update.
8. Compare AES67/RAVENNA/AVB setup burden with direct UDP PCM.
9. Study TSN WCRT/AVB-aware scheduling papers for worst-case metrics.
10. Read JPEG XS RTP/FEC papers for later video.
11. Read ANSI E1.31-2025 before implementing sACN.
12. Read Art-Net 4 spec before implementing Art-Net.
13. Study OLA and QLC+ as lighting interop references.
14. Study Open Fixture Library schema before inventing fixture metadata.
15. Study Chataigne/OpenFollow/PSN for show-control workflows.

## Bottom Line

The 2024-2026 state of the art supports a three-lane architecture:

```text
Audio:
  direct Core Audio + UDP PCM + certified academic network + measured e2e

Video:
  degradable low-latency presence/cueing path, with JPEG XS/UltraGrid/VideoToolbox
  as study references

Lighting:
  timestamped show-control lane using OSC first, sACN/Art-Net for DMX-over-IP,
  and RDM/RDMnet/PSN/OTP later
```

The project should not become a general conferencing app, a lighting console, or
a video production suite. It should be a music-first realtime system whose
video and lighting are useful because they stay out of the audio path.
