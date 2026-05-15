> Superseded research note (2026-05-02): this file is preserved for historical
> traceability. The canonical research entry point is
> [RESEARCH_COMPANION_2026.md](../RESEARCH_COMPANION_2026.md), with current
> decisions in the focused 2026 companion set.

# Research Survey 2022-2026: Fastest Audio E2E For Networked Music

Date: 2026-05-02

Scope: recent research, software, and protocol work relevant to building a
Mac-native system for the lowest possible end-to-end musical audio latency on
high-end hardware and academic/research networks.

This survey is not about general conferencing. It is about networked music
performance where latency and jitter determine whether the system is playable.

## Executive Result

The 2022-2026 evidence supports the current plan:

- For the fastest mode, use uncompressed PCM, not a speech/music codec.
- Use tiny hardware buffers and direct realtime audio APIs.
- Use best-effort UDP-style transport, not TCP/QUIC/WebRTC media stacks.
- Run on controlled wired networks when the musical goal is lowest latency.
- Treat video as subordinate and degradable.
- Study packet-loss concealment, but do not use PLC as an excuse to increase
  playout buffering.
- Study AVB/TSN/AES67/RAVENNA-style systems for deterministic local academic
  networks, but benchmark them against direct UDP PCM instead of assuming they
  are faster.

The key implementation change is measurement discipline: "faster than LoLa" is
not proven by buffer settings. It is proven by measured audio e2e:

```text
ADC + Core Audio input path + packetization + network propagation/queueing
  + receive scheduling + playout target + Core Audio output path + DAC
```

## Search Themes

Search focused on:

- networked music performance after 2022,
- low-latency audio over academic/research networks,
- JackTrip, SonoBus/AOO, Jamulus, UltraGrid, Corelink/NetMusic3D,
- WebRTC PCM and browser-based NMP,
- packet-loss concealment for NMP,
- AVB/TSN/AES67/RAVENNA audio-over-IP,
- Apple Core Audio, Audio Workgroups, AVB, AVFoundation, VideoToolbox,
- 5G/edge NMP research,
- hardware/offload approaches.

## Findings

### 1. Uncompressed UDP PCM Remains The Fastest Musical Baseline

The strongest NMP systems still start from the same core idea:

```text
small audio callback block
  -> uncompressed or lightly processed PCM
  -> immediate packetization
  -> best-effort network transport
  -> tiny playout target
  -> dropout over waiting
```

This is visible in the design of JackTrip, AOO/SonoBus-style systems, LoLa, and
other NMP tools. It also appears indirectly in newer research: when systems move
to browser stacks, 5G paths, or codec-heavy designs, latency grows and the
system becomes a fallback or access-enabling path rather than the fastest path.

Implication for our plan:

- Keep float32 PCM over UDP as the fastest academic-network default.
- Use int16/int24 only if it improves measured packet behavior.
- Keep Opus as low-bandwidth fallback only.
- Do not build the first implementation around WebRTC, QUIC, TCP, or a
  conferencing stack.

Software to study:

- JackTrip: <https://github.com/jacktrip/jacktrip>
- AOO: <https://git.iem.at/cm/aoo>
- SonoBus: <https://github.com/sonosaurus/sonobus>
- Jamulus: <https://github.com/jamulussoftware/jamulus>

### 2. Endpoint Latency Is The First Battle

Recent research and production systems repeatedly show that network latency is
only one part of the musical delay. Hardware buffers, driver scheduling,
converter group delay, and hidden processing can dominate once the network is
good.

For high-end Mac systems, this points to:

- direct Core Audio `AudioDeviceIOProc` or AUHAL,
- Audio Workgroups for realtime helper scheduling,
- 32-frame target,
- 16-frame stretch target,
- 48/96/192 kHz benchmark matrix,
- no hidden sample-rate conversion,
- no AVFoundation audio queues in the realtime path.

Implication for our plan:

- Keep `AUDIO_HARDWARE_BENCHMARK.md` and analog loopback as mandatory first
  deliverables.
- Do not claim 96 or 192 kHz is faster until analog loopback proves it.
- Benchmark converter/interface families, not only Macs.

Primary Apple material to study:

- Core Audio overview:
  <https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/WhatisCoreAudio/WhatisCoreAudio.html>
- Audio Workgroups:
  <https://developer.apple.com/documentation/audiotoolbox/understanding-audio-workgroups>
- Core Audio `AudioDeviceStart` / IOProc:
  <https://developer.apple.com/documentation/coreaudio/1422884-audiodevicestart>
- Core Audio buffer frame size:
  <https://developer.apple.com/documentation/coreaudio/audiohardwaredevice/bufferframesize>
- Core Audio latency property:
  <https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertylatency>

### 3. Academic Networks Change The Best Default

For consumer Internet, codec and NAT strategies matter. For academic/research
networks, the default can be much more aggressive:

- wired Ethernet only,
- direct link or dedicated switch for baseline tests,
- dedicated VLAN where available,
- DSCP/QoS only if the network honors it,
- no VPN overlay,
- no Wi-Fi,
- no consumer NAT traversal in the fastest path,
- no codec to save bandwidth unless measurement requires it.

Implication for our plan:

- Add `ACADEMIC_NETWORK_PROFILE.md` before media benchmarking.
- Treat direct link, dedicated switch, campus VLAN, and academic WAN as separate
  profiles.
- Packet rate and scheduling jitter matter more than raw bandwidth.

At one packet per audio block:

```text
48 kHz / 32 frames   = 1500 packets/s per direction
48 kHz / 16 frames   = 3000 packets/s per direction
96 kHz / 32 frames   = 3000 packets/s per direction
96 kHz / 16 frames   = 6000 packets/s per direction
192 kHz / 32 frames  = 6000 packets/s per direction
192 kHz / 16 frames  = 12000 packets/s per direction
```

Study:

- Campus network QoS/DSCP behavior.
- NIC interrupt coalescing and socket buffer behavior on macOS.
- Direct link vs switch vs routed campus path.

### 4. AVB/TSN/AES67/RAVENNA Are Important, But Must Be Benchmarked

Professional audio-over-IP standards are highly relevant in academic music and
media environments.

They offer:

- clocking,
- deterministic local-network behavior,
- multichannel support,
- interoperability with professional hardware,
- known deployment patterns in studios and institutions.

But they are not automatically the fastest possible Mac-to-Mac path. They may
use buffering and scheduling choices optimized for reliability, interoperability,
and large professional systems rather than absolute minimum interactive latency.

Implication for our plan:

- Evaluate AVB/TSN as a first-class same-room/same-building academic-network
  mode.
- Compare against direct UDP PCM on the same hardware/network.
- If AVB/TSN beats UDP PCM, promote it to fastest local mode.
- If it is more stable but slower, keep it as reliable professional mode.

Standards/software to study:

- AES67 standard overview:
  <https://www.aes.org/publications/standards/search.cfm?docID=96>
- RAVENNA:
  <https://ravenna-network.com/>
- Merging Technologies AES67/RAVENNA Linux driver:
  <https://github.com/MergingTechnologies/ALSA-RAVENNA-AES67-Driver>
- Apple Audio MIDI Setup AVB support:
  <https://support.apple.com/guide/audio-midi-setup/set-up-audio-devices-ams59f301fda/mac>
- Avnu Alliance AVB/TSN resources:
  <https://avnu.org/>

### 5. Packet-Loss Concealment Is A Study Lane, Not A Latency Strategy

Recent research explicitly targets packet-loss concealment for networked music
performance. This matters because a system that drops instead of buffering can
sound rough under packet loss.

The right use:

- reduce audible artifacts when a packet is missing,
- run without adding playout delay,
- keep the audio deadline,
- remain optional and measurable.

The wrong use:

- hide network problems with a large adaptive buffer,
- add algorithmic lookahead,
- add expensive model inference on the realtime path.

Key recent paper:

- "Tilt Loss: A Spectral Loss for Packet Loss Concealment in Networked Music
  Performance", EURASIP Journal on Audio, Speech, and Music Processing, 2026:
  <https://link.springer.com/article/10.1186/s13636-025-00442-1>

Earlier related methods/software to study:

- AR/Burg-style optimized packet-loss concealment for NMP.
- IEEE Audio Deep Packet Loss Concealment Challenge artifacts.
- Any open implementations that can run with zero or one packet lookahead.

Implication for our plan:

- Add PLC as an optional post-MVP research lane.
- Benchmark PLC CPU cost and added delay.
- Never allow PLC to increase the default playout target.

### 6. 5G/Edge Research Is Useful For Fallbacks, Not The Fastest Academic Path

Recent 5G and edge-computing NMP research is valuable, especially for access
outside wired academic networks. But the fastest target in this project assumes
high-end wired academic infrastructure.

Recent 5G work tends to show:

- private 5G standalone plus edge can be viable,
- public/non-standalone 5G is often not enough for strict musical latency,
- jitter buffers still consume meaningful latency budget,
- routing and radio scheduling variance matter.

Implication for our plan:

- Do not make 5G part of fastest mode.
- Keep it as a later deployment/fallback study if required.

Representative paper:

- "Unveiling 5G Potential for Networked Music Performance: Measurements and
  Analysis", 2024:
  <https://ieeexplore.ieee.org/document/10646790>

### 7. Browser/WebRTC Research Is Valuable For Access, Not Fastest Mode

Browser-based NMP systems make access easier but generally accept higher
latency and less control over audio scheduling.

A 2022 browser/WebRTC PCM study reported usable browser-based NMP, but the
latency class is not the target for our fastest native system.

Implication for our plan:

- Do not use WebRTC for fastest audio.
- Study WebRTC only for future accessibility or rehearsal fallback.

Representative paper/software:

- "Browser-based Networked Music Performance with Sharedarraybuffers", 2022:
  <https://www.researchgate.net/publication/360010803_Browser-based_Networked_Music_Performance_with_Sharedarraybuffers>
- Pion WebRTC as implementation reference only:
  <https://github.com/pion/webrtc>

### 8. Hardware Offload Is A Long-Term Fastest-Path Question

Once the Mac software path is optimized, remaining delay may be dominated by:

- audio interface converter delay,
- USB/Thunderbolt driver behavior,
- NIC scheduling,
- operating-system scheduling jitter.

Research systems using embedded processors or FPGA-style audio/network
coprocessors are relevant as future directions.

Implication for our plan:

- First build the fastest Mac-native software system.
- Then decide whether a dedicated network-audio hardware endpoint could beat
  Mac userspace for endpoint and network scheduling latency.

Study:

- Elk Audio OS:
  <https://github.com/elk-audio/elk-audio-os>
- JACK2 realtime audio server:
  <https://github.com/jackaudio/jack2>
- FPGA/embedded low-latency networked audio papers from 2022-2026.

### 9. Video Research Does Not Change The Audio Priority

Recent low-latency video work offers useful tools, but video cannot define the
musical latency target. At 60 fps the frame period alone is 16.67 ms. Even 120
fps has an 8.33 ms frame period.

Implication for our plan:

- video remains presence/cueing,
- video is allowed to drop/degrade,
- raw or very light intra-frame video is acceptable on academic networks,
- VideoToolbox low-latency H.264/HEVC is useful only when bandwidth or CPU
  requires it.

Software to study:

- UltraGrid:
  <https://github.com/CESNET/UltraGrid>
- Apple AVFoundation capture:
  <https://developer.apple.com/documentation/avfoundation/capture-setup>
- Apple `AVCaptureVideoDataOutput`:
  <https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput>
- Apple VideoToolbox:
  <https://developer.apple.com/documentation/videotoolbox>

## Recommended Study Priority

### Tier 1: Directly Relevant To Fastest Audio

1. Core Audio HAL/AUHAL and `AudioDeviceIOProc`.
2. Audio Workgroups.
3. JackTrip source and packet/audio design.
4. AOO and SonoBus source.
5. BSD UDP media hot path on macOS.
6. AVB/TSN/AES67/RAVENNA local-network audio.
7. macOS socket scheduling, NIC behavior, and packet timestamping.

### Tier 2: Useful For Robustness Without Latency Growth

1. NMP packet-loss concealment papers, especially Tilt Loss 2026.
2. Burg/AR-style PLC for music.
3. Clock drift correction without buffer growth.
4. Duplicate-current-block packet experiments.
5. QoS/DSCP behavior on the actual academic network.

### Tier 3: Useful For Later Modes

1. Opus low-bandwidth native mode.
2. 5G/edge NMP work.
3. WebRTC/browser NMP.
4. VideoToolbox low-latency video.
5. UltraGrid video/audio transport patterns.
6. Hardware offload and embedded network-audio endpoints.

## Implications For `MAC_PORT_PLAN.md`

The plan should remain:

```text
measurement rig
  -> academic network profile
  -> Core Audio endpoint benchmark
  -> UDP PCM Mac-to-Mac benchmark
  -> fastest measured e2e mode selection
  -> drift correction
  -> AVB/TSN comparison
  -> video only after audio
```

Additions implied by the research:

- Create `ACADEMIC_NETWORK_PROFILE.md` before media benchmarking.
- Add packet-rate stress tests up to 12k packets/s per direction.
- Add 192 kHz tests, but accept them only if analog e2e improves.
- Add packet-loss concealment as an optional research lane.
- Add AVB/TSN/AES67/RAVENNA comparison as first-class local-network research.
- Do not add WebRTC, Opus, or 5G to the fastest path.

## Papers, Repos, And Software To Study

### Papers / Research Artifacts

- Tilt Loss, 2026:
  <https://link.springer.com/article/10.1186/s13636-025-00442-1>
- Networked music performance survey/review literature from 2022-2026:
  <https://link.springer.com/article/10.1007/s00779-024-01806-8>
- Browser-based NMP with SharedArrayBuffers, 2022:
  <https://www.researchgate.net/publication/360010803_Browser-based_Networked_Music_Performance_with_Sharedarraybuffers>
- 5G NMP measurements, 2024:
  <https://ieeexplore.ieee.org/document/10646790>
- AES67 standard:
  <https://www.aes.org/publications/standards/search.cfm?docID=96>
- Opus RFC 6716:
  <https://datatracker.ietf.org/doc/rfc6716/>

### Repos / Software

- JackTrip:
  <https://github.com/jacktrip/jacktrip>
- AOO:
  <https://git.iem.at/cm/aoo>
- SonoBus:
  <https://github.com/sonosaurus/sonobus>
- Jamulus:
  <https://github.com/jamulussoftware/jamulus>
- UltraGrid:
  <https://github.com/CESNET/UltraGrid>
- Merging Technologies ALSA RAVENNA/AES67 driver:
  <https://github.com/MergingTechnologies/ALSA-RAVENNA-AES67-Driver>
- Elk Audio OS:
  <https://github.com/elk-audio/elk-audio-os>
- JACK2:
  <https://github.com/jackaudio/jack2>
- Pion WebRTC:
  <https://github.com/pion/webrtc>

### Apple Platform Docs

- Core Audio overview:
  <https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/WhatisCoreAudio/WhatisCoreAudio.html>
- Audio Workgroups:
  <https://developer.apple.com/documentation/audiotoolbox/understanding-audio-workgroups>
- Core Audio IOProc:
  <https://developer.apple.com/documentation/coreaudio/1422884-audiodevicestart>
- Core Audio buffer frame size:
  <https://developer.apple.com/documentation/coreaudio/audiohardwaredevice/bufferframesize>
- Core Audio latency property:
  <https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertylatency>
- AVFoundation capture setup:
  <https://developer.apple.com/documentation/avfoundation/capture-setup>
- `AVCaptureVideoDataOutput`:
  <https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput>
- VideoToolbox:
  <https://developer.apple.com/documentation/videotoolbox>
- Network UDP:
  <https://developer.apple.com/documentation/network/nwprotocoludp>
- AVB in Audio MIDI Setup:
  <https://support.apple.com/guide/audio-midi-setup/set-up-audio-devices-ams59f301fda/mac>

## Bottom Line

The best 2022-2026 direction for this project is not to imitate one existing
tool. It is to combine:

- LoLa/JackTrip style no-wait audio discipline,
- direct Core Audio endpoint optimization,
- high-end academic-network UDP PCM,
- AVB/TSN benchmarking for deterministic local paths,
- zero/one-block playout targets,
- explicit drift correction without buffer growth,
- optional PLC that does not add latency,
- video that degrades before audio does.

The fastest version is not the most compatible version. It is the version that
measures lowest audio e2e on the reference hardware and academic network.
