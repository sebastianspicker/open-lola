# Mac-Native Low-Latency A/V Implementation Plan

This is the current implementation plan after the decision that Windows LoLa
compatibility is not required.

The Windows reverse-engineering work remains useful as evidence: it shows why
LoLa is fast and which design traps to avoid. It no longer constrains the Mac
wire format, camera model, codec choice, transport shape, or UI.

Primary target:

```text
lowest possible measured end-to-end musical audio latency on macOS
```

Secondary target:

```text
best-effort low-latency video that never harms audio timing
```

Tertiary target:

```text
time-aligned lighting/control information that never harms audio or video
```

## Strategic Decision

We are no longer building a Windows LoLa-compatible peer as the main product.
We are building a Mac-native successor optimized for speed.

That means:

- no LoLa packet format requirement,
- no WinPcap compatibility requirement,
- no 16-bit PCM compatibility requirement,
- no XIMEA dependency,
- no MJPEG requirement,
- no MFC UI inheritance,
- no obligation to preserve Windows LoLa's 30-slot video ring,
- no need to match LoLa's exact control/session messages.

What we keep from LoLa:

- audio first,
- tiny hardware buffers,
- uncompressed audio for the fastest mode,
- no echo cancellation,
- no noise suppression,
- no automatic gain control,
- no adaptive audio comfort buffering,
- no retransmission wait,
- dropout over delay,
- video quality is subordinate to audio,
- lighting/control is subordinate to audio and video.

## Deployment Assumptions

We can assume a favorable professional/academic environment:

- high-end Mac hardware,
- high-end wired USB/Thunderbolt audio interfaces,
- wired Ethernet, not Wi-Fi,
- academic/campus/research networks with high bandwidth,
- operator access to network configuration where needed,
- possible dedicated VLANs or direct wired links for tests,
- possible QoS/DSCP policy on managed networks,
- no consumer NAT traversal requirement for the fastest mode,
- no bandwidth-driven need for speech codecs in the default mode.

This changes the plan: optimize for absolute audio end-to-end latency first,
then add fallback modes only if a measured deployment needs them.

## Current Evidence Base

Canonical research companion set:

- `research/RESEARCH_COMPANION_2026.md`
- `research/RESEARCH_AUDIO_ENGINE_2026.md`
- `research/RESEARCH_NETWORK_TIMING_2026.md`
- `research/RESEARCH_VIDEO_PIPELINE_2026.md`
- `research/RESEARCH_LIGHTING_SHOW_CONTROL_2026.md`
- `research/RESEARCH_EVIDENCE_MATRIX_2026.md`
- `research/RESEARCH_BENCHMARK_ROADMAP_2026.md`

Canonical reverse-engineering companion set:

- `reverse-engineering/REVERSE_ENGINEERING_COMPANION_2026.md`
- `reverse-engineering/REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md`
- `reverse-engineering/REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md`
- `reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md`
- `reverse-engineering/REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md`

Historical local evidence:

- `reverse-engineering/deprecated-reverse-engineering/AUDIO_WORKFLOW_REVERSE_ENGINEERING.md`
- `reverse-engineering/deprecated-reverse-engineering/VIDEO_WORKFLOW_REVERSE_ENGINEERING.md`
- `AUDIO_FIRST_LATENCY_PLAN.md`
- `MAC_NATIVE_SOTA_AV_STRATEGY_2026.md`
- `research/deprecated-research/RESEARCH_SURVEY_2022_2026.md`
- `research/deprecated-research/RESEARCH_SURVEY_2024_2026_DEEP.md`
- `research/deprecated-research/RESEARCH_SURVEY_2024_2026_EVIDENCE_MATRIX.md`
- `research/deprecated-research/RESEARCH_DOSSIER_AUDIO_FIRST_2026.md`
- `reverse-engineering/README.md`

Key Windows findings used only as benchmark evidence:

- LoLa audio is callback-driven.
- LoLa uses 64-frame 16-bit PCM callback blocks.
- LoLa relies on ASIO-class hardware drivers.
- LoLa does not block the audio callback for network recovery.
- LoLa video is threaded/best-effort and can drop.

Mac-native opportunity:

- Core Audio HAL/AUHAL or direct `AudioDeviceIOProc` can remove PortAudio as a
  layer.
- Stable 32-frame operation can beat a 64-frame LoLa endpoint.
- Stable 16-frame operation, if the reference hardware supports it, is a
  stretch path.
- 96 kHz can reduce per-buffer time at the cost of CPU/bandwidth and must be
  measured, not assumed.
- 192 kHz is allowed as an experiment on high-end hardware, but only the analog
  loopback result matters.
- AVB/TSN-style local audio can be a faster deterministic mode on suitable
  managed Ethernet.

## Success Definition

Minimum success:

- fastest stable end-to-end audio mode selected from measured data,
- stable 32-frame operation on reference Mac hardware or evidence that the
  specific interface cannot do it,
- Mac-to-Mac academic-network audio with no adaptive comfort buffer,
- endpoint, network, and playout latency measured separately,
- video can run or fail without changing audio metrics.

Stretch success:

- 96 kHz at 32 frames or better if stable,
- 16-frame operation at 48/96 kHz if stable,
- 192 kHz modes benchmarked on high-end hardware,
- analog end-to-end audio latency below LoLa-class endpoint targets,
- Mac-to-Mac one-way media latency limited mostly by physical network
  propagation and switching,
- AVB/TSN-style local mode accepted if it beats UDP PCM on measured paths.

Non-success:

- a prettier conferencing app,
- stable video with delayed audio,
- fewer dropouts achieved by hidden buffering,
- high-quality video that changes audio callback timing.
- lighting sync achieved by delaying audio or video.

## Architecture

```text
Headless tools first
  audio-latency-rig
  udp-pcm-rig
  avb-evaluator
  camera-latency-rig
  video-transport-rig

Native app later
  SwiftUI/AppKit operational shell
  device/session/settings UI
  metrics and recording controls

Realtime core in C/C++/Objective-C++
  Core Audio HAL/AUHAL/direct IOProc
  SPSC audio rings
  UDP PCM transport
  clock drift controller
  packet metrics
  video source adapters
  video transport adapters
  lighting/control transport adapters
  show clock / cue scheduler

Swift bridge
  immutable config snapshots
  command API
  metrics stream
```

The UI configures and observes. It does not participate in realtime media.

## Audio Design

### API Choice

First serious implementation:

- direct Core Audio `AudioDeviceIOProc` or AUHAL,
- no `AVAudioEngine` as the primary realtime transport,
- no AVFoundation recording/playback queues in the live path.

Use Audio Workgroups for realtime helper threads where supported.

Use AudioDriverKit only if later hardware or virtual-device requirements demand
it. It is not the first implementation path.

### Buffer Targets

Benchmark in this order:

1. 48 kHz, 32 frames.
2. 96 kHz, 32 frames.
3. 48 kHz, 16 frames.
4. 96 kHz, 16 frames.
5. 192 kHz, 32 frames.
6. 192 kHz, 16 frames.
7. 48 kHz, 64 frames as fallback.
8. 96 kHz, 64 frames as fallback.

Acceptance:

- 32 frames stable is the main target.
- 16 frames stable is accepted if analog end-to-end measurements improve.
- 64 frames is fallback only on the fastest-audio track.
- 128 frames is diagnostic/fallback only.

At 48 kHz:

```text
16 frames = 0.33 ms
32 frames = 0.67 ms
64 frames = 1.33 ms
128 frames = 2.67 ms
```

At 96 kHz:

```text
16 frames = 0.17 ms
32 frames = 0.33 ms
64 frames = 0.67 ms
128 frames = 1.33 ms
```

At 192 kHz:

```text
16 frames = 0.08 ms
32 frames = 0.17 ms
64 frames = 0.33 ms
128 frames = 0.67 ms
```

Higher sample rates are not automatically better. ADC/DAC converter group
delay, driver behavior, CPU load, packet rate, and clock stability can erase
the theoretical buffer-duration gain. The analog loopback measurement decides.

### End-To-End Audio Budget

The metric is not callback buffer size. The metric is measured audio e2e:

```text
ADC / input hardware delay
  + input safety offset / hardware buffer
  + Core Audio callback handoff
  + packetization
  + network send scheduling
  + physical network propagation
  + switch/router queueing
  + receive scheduling
  + playout target depth
  + output hardware buffer
  + DAC / output hardware delay
```

Report these separately where possible:

- analog endpoint loopback on each Mac,
- packet send-to-receive timing using monotonic host time,
- network RTT and one-way estimate,
- playout depth in audio blocks,
- final analog end-to-end Mac-to-Mac measurement.

### Audio Format

Internal native mode:

- use the device-native Core Audio format where possible,
- likely float32 PCM in the callback/core,
- avoid sample-rate conversion,
- avoid format conversion in the callback unless measured harmless.

Network fastest mode:

- uncompressed PCM,
- one UDP datagram per audio block when it fits MTU,
- float32 PCM by default on controlled LAN,
- optional int24/int16 only if it reduces measured e2e latency or packet loss,
- no Opus/AAC in the fastest mode.

Bandwidth is not the main constraint on high-end academic networks:

```text
48 kHz stereo float32 ~= 3.1 Mbit/s before packet overhead
96 kHz stereo float32 ~= 6.1 Mbit/s before packet overhead
192 kHz stereo float32 ~= 12.3 Mbit/s before packet overhead
48 kHz 8ch float32    ~= 12.3 Mbit/s before packet overhead
96 kHz 8ch float32    ~= 24.6 Mbit/s before packet overhead
192 kHz 8ch float32   ~= 49.2 Mbit/s before packet overhead
```

That is acceptable on wired academic networks. The relevant cost is packet rate,
driver scheduling, and jitter, not raw bandwidth.

Approximate packet rates for one packet per audio block:

```text
48 kHz / 32 frames   = 1500 packets/s per direction
48 kHz / 16 frames   = 3000 packets/s per direction
96 kHz / 32 frames   = 3000 packets/s per direction
96 kHz / 16 frames   = 6000 packets/s per direction
192 kHz / 32 frames  = 6000 packets/s per direction
192 kHz / 16 frames  = 12000 packets/s per direction
```

High-end networks can carry this, but the Mac userspace receive/send loop must
prove it can do so without jitter that forces a larger playout depth.

### Callback Contract

Inside the audio callback:

- no allocation,
- no locks,
- no file I/O,
- no logging,
- no Swift or Objective-C UI calls,
- no socket calls,
- no video work,
- no codec work,
- no waiting,
- no sample-rate conversion unless the benchmark proves it harmless.

Allowed:

- copy input PCM into preallocated capture ring,
- read remote PCM from preallocated playout ring,
- output silence when remote PCM is missing,
- update atomics,
- signal a helper with a realtime-safe primitive.

### Audio Transport

Use BSD UDP sockets for the media hot path.

Rules:

- connected UDP socket per peer,
- nonblocking send/receive,
- packetize immediately after capture,
- receive into preallocated buffers,
- one audio block per packet where possible,
- DSCP/QoS marking when the academic network honors it,
- dedicated NIC/VLAN/direct link where available for test runs,
- optional duplicate current-block packet only if it reduces dropouts without
  increasing playout depth,
- no retransmission wait,
- no TCP,
- no QUIC for fastest mode,
- no WebRTC stack for fastest mode.

Network.framework remains useful for:

- setup/control,
- path monitoring,
- diagnostics,
- non-realtime state.

It should not be assumed fastest for the hot media path until measured.

### Academic Network Profile

Fastest mode assumes:

- wired 1/10/25 GbE where available,
- no Wi-Fi,
- no VPN overlay in the media path,
- no consumer NAT traversal,
- stable switch path,
- no congested shared uplink,
- QoS/DSCP available where campus policy allows,
- network path documented before each benchmark.

For same-room or same-building tests, prefer:

1. direct wired link,
2. dedicated switch,
3. dedicated VLAN,
4. managed campus path,
5. routed academic WAN only when that is the real deployment target.

Do not tune for arbitrary consumer Internet in the fastest-audio milestone.

### Jitter And Drift

Default receive target:

- 0 or 1 audio block.

When packets are late:

- output silence or a tiny dropout policy,
- never wait for missing audio.

Clock drift correction:

- measure local sample time and remote packet cadence,
- keep a tiny target playout depth,
- correct slow drift outside the callback with either:
  - occasional single-sample slip with crossfade, or
  - a very small low-latency fractional resampler,
- never solve drift by growing a comfort buffer.

### AVB Mode

Evaluate AVB/TSN-style local audio as a first-class academic-network option.

Use when:

- same building,
- controlled wired Ethernet,
- AVB-capable hardware/switching,
- deterministic clocked audio is more important than Internet reach.

Do not use AVB as the general routed academic WAN or Internet mode. It is a
same-room/same-building candidate.

## Video Design

Video is subordinate.

Video goals:

- presence,
- cueing,
- low CPU load,
- graceful degradation,
- no impact on audio callback timing.

### Vendor-Neutral Camera Strategy

The core must build without any vendor camera SDK.

Camera interface:

```text
CameraSource
  frame_id
  host_time
  pixel_format
  width
  height
  stride
  buffer_ref
```

Adapters:

- `AVFoundationCameraSource`,
- `FilePatternSource`,
- `SyntheticTestPatternSource`,
- optional `CoreMediaIOCameraSource`,
- optional `XimeaCameraSource`,
- optional capture-card/vendor SDK adapters.

First implementation:

- AVFoundation external camera/capture card,
- file/test-pattern camera,
- no XIMEA dependency.

### AVFoundation Rules

Use:

- `AVCaptureDevice.DiscoverySession`,
- explicit `activeFormat`,
- explicit `activeVideoMinFrameDuration`,
- explicit `activeVideoMaxFrameDuration`,
- `AVCaptureVideoDataOutput`,
- `alwaysDiscardsLateVideoFrames = true`,
- native pixel formats where possible.

Avoid:

- defaulting to BGRA if the camera has a more native low-conversion format,
- still-photo-oriented capture formats,
- stabilization,
- HDR/depth/portrait processing,
- capture presets that hide format decisions,
- camera work on audio threads.

### Video Encoding

Fastest controlled-LAN modes:

- raw low-resolution frame payload,
- raw grayscale where acceptable,
- optionally simple intra-frame compression if CPU cost is lower than network
  cost.

Bandwidth-constrained native mode:

- VideoToolbox low-latency H.264/HEVC,
- no B-frames,
- realtime encoder properties,
- short GOP,
- drop late frames.

MJPEG:

- acceptable as a simple intra-frame fallback,
- not mandatory,
- not assumed fastest.

Video can use larger buffers than audio, but only inside the video subsystem.
Those buffers must not backpressure audio or network audio.

## Lighting And Show-Control Design

Lighting is third priority:

```text
audio > video > lighting
```

Lighting goals:

- carry cue triggers,
- carry fixture/universe state when useful,
- align lighting changes to the shared show clock,
- interoperate with common academic/stage protocols,
- never touch the audio callback,
- never backpressure audio or video.

### Lighting Information Types

Support three levels:

1. High-level cues:
   - cue id,
   - cue name,
   - go/stop/blackout,
   - scene/preset id,
   - optional scheduled host time.
2. Parameter events:
   - fixture id,
   - parameter id,
   - normalized value,
   - fade time,
   - optional curve.
3. Universe frames:
   - DMX-style 512-channel universe payloads,
   - sequence number,
   - priority/source id,
   - optional timestamp.

High-level cues are preferred for musical use because they are low bandwidth and
easy to schedule. Full universe streaming is useful for interoperability and
fixtures, but it must remain a separate best-effort path.

### Lighting Protocols To Support

First-class study/support candidates:

- OSC for high-level cues and custom show-control messages.
- sACN / ANSI E1.31 for DMX-over-IP universes.
- Art-Net 4 for DMX-over-IP interoperability.
- RDM / RDMnet for fixture discovery and management, not live low-latency cues.
- MIDI Show Control or MIDI 2.0 only if the target venue workflow needs it.

The internal app model should not be Art-Net-specific or sACN-specific. Use an
internal `LightingEvent` and `LightingFrame` model, then adapters.

### Lighting Timing Model

Lighting follows the same master timebase as audio/video metrics, but not the
audio realtime thread.

Recommended model:

```text
audio host time / monotonic clock
  -> shared show clock estimate
  -> lighting scheduler thread
  -> protocol adapter
  -> sACN / Art-Net / OSC packet
```

For academic networks:

- evaluate PTP where the network supports it,
- otherwise exchange monotonic clock-offset probes,
- timestamp outgoing lighting events,
- measure cue send time, network arrival time, and fixture/controller response
  where possible.

Lighting does not need sub-audio-buffer timing. It needs predictable, measured
cue timing that does not degrade audio. A useful target is cue scheduling jitter
below a video frame and preferably below 5 ms on controlled local networks.

### Lighting Transport Rules

- no lighting work in the audio callback,
- no fixture discovery during a live fastest-audio benchmark,
- no blocking DNS or service discovery in live media paths,
- no retransmission wait in the audio/video path,
- rate-limit full-universe streaming,
- prefer high-level timestamped cues over continuous universe streaming,
- if lighting packets are late, apply hold-last/drop policy rather than
  delaying media.

### Lighting Safety

Lighting has venue-safety implications that audio/video do not:

- explicit allowed universe list,
- blackout command,
- hold-last/stop-output policy,
- rate limits,
- test mode before live output,
- no accidental broadcast floods,
- operator-visible output state.

### Lighting Metrics

Track:

- cue scheduled time,
- cue sent time,
- protocol packet count,
- dropped/late lighting events,
- sACN/Art-Net sequence gaps,
- universe frame rate,
- queue depth,
- output adapter errors,
- measured controller/fixture response where available.

## Modes

### Fastest Native LAN Mode

Audio:

- Core Audio direct IOProc/AUHAL,
- 32 frames baseline target,
- 16 frames stretch target,
- 48/96/192 kHz benchmark matrix,
- float32 PCM over UDP,
- 0/1 block receive target,
- academic wired network profile,
- dropout over wait.

Video:

- AVFoundation source,
- raw or very light intra-frame payload,
- frame dropping enabled,
- video off/degrade if CPU or network threatens audio.

### Native Internet Mode

Audio:

- same Core Audio path,
- PCM if academic WAN bandwidth and jitter allow,
- optional int16/int24 PCM only if it improves measured packet behavior,
- optional Opus only if bandwidth requires it and added codec delay is accepted.

Video:

- lower FPS/resolution,
- VideoToolbox low-latency encode if bandwidth constrained,
- aggressive late-frame drop.

### AVB Local Mode

Audio:

- use macOS AVB-capable device/virtual AVB path where available,
- treat it as a native controlled-network transport,
- benchmark against UDP PCM.

Video:

- independent best-effort video path.

Lighting:

- independent best-effort lighting/control path,
- high-level cue messages preferred,
- sACN/Art-Net only on configured networks/universes.

## Milestones And Gates

### Milestone 0: Reference Hardware And Measurement Rig

Goal: define the hardware and measurement method before optimizing blindly.

Tasks:

- choose reference Mac models,
- choose reference high-end wired audio interfaces,
- choose reference external generic camera/capture card,
- document academic network paths,
- define direct-link, dedicated-switch, campus-VLAN, and academic-WAN test
  profiles where available,
- document switch/NIC speed, MTU, QoS/DSCP handling, and routing,
- create analog loopback measurement setup,
- create packet timestamp/logging tools,
- define pass/fail e2e audio latency thresholds.

Gate:

- measurement method is repeatable,
- analog loopback can detect endpoint latency changes,
- packet logs include monotonic host time,
- network profiles are documented before audio transport benchmarks.

### Milestone 1: Headless Core Audio Rig

Goal: find the fastest stable Mac endpoint audio mode.

Tasks:

- enumerate Core Audio devices,
- query sample rates, buffer frame size range, latency, and clock domain,
- run direct IOProc or AUHAL full-duplex,
- benchmark 48/96/192 kHz and 16/32/64/128 frame settings,
- preallocate all buffers,
- count deadline misses, underruns, overruns,
- run 30-minute stability tests,
- measure analog loopback latency,
- rank modes by measured analog endpoint latency, not theoretical buffer time.

Gate:

- fastest stable endpoint mode selected from measured data,
- 32 frames stable or documented why hardware cannot do it,
- 16-frame and 192 kHz attempts documented,
- no callback contract violations,
- analog loopback report exists.

### Milestone 2: Mac-To-Mac UDP PCM

Goal: prove the fastest native audio network path on academic networks.

Tasks:

- implement UDP PCM packet format,
- one packet per audio block where possible,
- receive into preallocated buffers,
- run with 0/1 block playout target,
- implement drift metrics,
- implement dropout policy,
- measure Mac-to-Mac LAN one-way/round-trip behavior,
- test 48/96/192 kHz modes,
- test direct-link, dedicated-switch, and academic/campus paths where
  available,
- test DSCP/QoS only where the network honors it,
- test packet duplication only if dropouts occur without congestion.

Gate:

- 30-minute Mac-to-Mac LAN run,
- no adaptive comfort buffer,
- endpoint and network latency measured separately,
- packet loss causes dropout, not hidden delay,
- fastest e2e audio mode selected from measured endpoint plus network data.

### Milestone 3: Drift Correction

Goal: run long sessions without buffer creep.

Tasks:

- measure clock drift between peers,
- implement single-sample slip/crossfade correction,
- benchmark tiny fractional resampler as alternative,
- verify both strategies outside the callback,
- compare audible artifacts and latency impact.

Gate:

- 60-minute run without growing receive buffer,
- chosen drift correction has measured artifact/latency profile.

### Milestone 4: AVB Evaluation

Goal: determine whether native AVB/TSN-style audio beats UDP PCM on controlled
academic local networks.

Tasks:

- set up AVB-capable path in Audio MIDI Setup,
- measure endpoint and network behavior,
- compare against UDP PCM,
- document setup burden and hardware constraints.

Gate:

- AVB/TSN-style audio is either accepted as optional fastest local mode or
  rejected with evidence.

### Milestone 5: Generic Video Probe

Goal: add vendor-neutral video without touching audio timing.

Tasks:

- implement `CameraSource`,
- implement AVFoundation camera source,
- implement file/test-pattern source,
- select active format and frame duration explicitly,
- use native pixel formats,
- discard late frames,
- timestamp frames,
- measure capture-to-display latency.

Gate:

- generic camera captures timestamped frames,
- core builds without XIMEA SDK,
- video off/on does not change audio callback metrics.

### Milestone 6: Native Video Transport

Goal: send useful low-latency video as best effort.

Tasks:

- raw low-resolution video payload,
- grayscale mode,
- VideoToolbox low-latency mode for constrained links,
- frame drop/degrade policy,
- display on non-realtime path,
- CPU/network monitoring.

Gate:

- video can degrade or turn off automatically,
- audio metrics remain within audio-only baseline tolerance.

### Milestone 7: Integrated Headless A/V

Goal: prove coexistence before UI.

Tasks:

- run audio and video together,
- make audio the master service,
- stress CPU and network,
- degrade video under load,
- record metrics.

Gate:

- 30-minute integrated run,
- audio callback timing stays within baseline tolerance,
- video never backpressures audio.

### Milestone 8: Lighting/Show-Control Probe

Goal: add lighting information after audio and video paths are structurally
safe.

Tasks:

- implement internal `LightingEvent` and `LightingFrame` model,
- implement OSC cue sender/receiver,
- implement sACN output adapter,
- implement Art-Net output adapter,
- implement test-pattern lighting output,
- add hold-last/drop/blackout policy,
- measure cue scheduling jitter,
- verify lighting traffic cannot affect audio metrics.

Gate:

- lighting cue loop runs without changing audio callback metrics,
- sACN/Art-Net output is limited to configured networks/universes,
- late lighting events do not delay audio or video.

### Milestone 9: Integrated Headless A/V/L

Goal: prove audio, video, and lighting can coexist with the required priorities.

Tasks:

- run audio, video, and lighting together,
- stress lighting cue and universe output,
- degrade lighting first, then video, never audio,
- record combined metrics.

Gate:

- 30-minute integrated A/V/L run,
- audio callback timing stays within audio-only baseline tolerance,
- video remains second priority,
- lighting remains third priority.

### Milestone 10: Native App Shell

Goal: wrap proven behavior in a Mac app.

Tasks:

- SwiftUI/AppKit operational UI,
- audio hardware selection and warnings,
- camera selection,
- lighting protocol and universe setup,
- network peer setup,
- metrics panes,
- degrade controls,
- recording controls,
- settings persistence.

Gate:

- app controls the proven headless core,
- UI activity does not change audio timing.

### Milestone 11: Recording And Utilities

Goal: add secondary features without touching live media timing.

Tasks:

- local audio recording,
- remote audio recording,
- video frame recording,
- lighting cue/event log,
- session metadata,
- export tools.

Gate:

- disk backpressure drops recording data instead of delaying live media.

### Milestone 12: Packaging And Field Testing

Goal: make the native system installable and measurable on real machines.

Tasks:

- signing,
- notarization,
- microphone/camera/local-network permission handling,
- setup guide,
- reference hardware guide,
- field tests in real rooms/networks.

Gate:

- signed test build runs on a clean Mac,
- field test report includes endpoint latency, network latency, dropouts, drift,
  video behavior, lighting behavior, and failure modes.

## Implementation Order

1. Measurement rig.
2. Academic network profile certification.
3. Core Audio direct IOProc/AUHAL.
4. Fastest stable endpoint mode selection.
5. Mac-to-Mac UDP PCM on certified paths.
6. Fastest e2e mode selection.
7. Drift correction.
8. AVB/TSN evaluation.
9. Generic camera source.
10. Native video transport.
11. Integrated headless A/V.
12. Lighting/show-control probe.
13. Integrated headless A/V/L.
14. App shell.
15. Recording.
16. Packaging.

## Design Rejection List

Reject for the fastest native path:

- Windows LoLa compatibility as a design constraint.
- UI first.
- video first.
- Bluetooth audio.
- AirPlay audio.
- browser media stack.
- WebRTC media stack.
- AVFoundation audio playback/recording queues for realtime audio.
- `AVAudioEngine` as the primary low-latency transport engine.
- echo cancellation.
- automatic gain control.
- noise suppression.
- limiter in the audio path.
- Opus/AAC in fastest mode.
- H.264/HEVC in fastest audio benchmark.
- adaptive audio comfort buffering.
- TCP media transport.
- QUIC media transport for fastest mode.
- VPN overlay in fastest mode.
- Wi-Fi in fastest mode.
- blocking disk recording in live media paths.
- SwiftUI calls from callbacks.
- Objective-C allocation from callbacks.
- logging from callbacks.
- video encode/decode on audio realtime threads.
- lighting/protocol output on audio realtime threads.
- fixture discovery during fastest-audio benchmarks.
- vendor-specific camera dependency in the core.

## Open Questions

- Which Mac model is the reference target?
- Which wired audio interface is the reference target?
- Can the reference interface run 32 frames at 48 kHz for 30 minutes?
- Can it run 32 frames at 96 kHz for 30 minutes?
- Can it run 32 frames at 192 kHz for 30 minutes?
- Is 16-frame operation stable on any available interface?
- Is AVB-capable network hardware available at HfMT?
- Which academic network profile is the real first target: direct link,
  dedicated switch, campus VLAN, or routed academic WAN?
- Can we mark DSCP/QoS for media packets on that network?
- How many audio channels are required for the first real use case?
- What generic external camera or capture card is the first target?
- Is any vendor-specific camera actually required?
- Which lighting protocols are required first: OSC, sACN, Art-Net, MIDI Show
  Control, or something venue-specific?
- How many DMX universes are needed?
- Is lighting driven by high-level cues, full universe streaming, or both?

## First Deliverables

- `MEASUREMENT_METHOD.md`
- `ACADEMIC_NETWORK_PROFILE.md`
- `research/RESEARCH_COMPANION_2026.md`
- `research/RESEARCH_EVIDENCE_MATRIX_2026.md`
- `research/RESEARCH_BENCHMARK_ROADMAP_2026.md`
- `AUDIO_HARDWARE_BENCHMARK.md`
- `AUDIO_LOOPBACK_LATENCY_REPORT.md`
- `MAC_TO_MAC_UDP_PCM_REPORT.md`
- `CLOCK_DRIFT_REPORT.md`
- `AVB_EVALUATION.md`
- `GENERIC_CAMERA_PROBE_REPORT.md`
- `INTEGRATED_HEADLESS_AV_REPORT.md`
- `LIGHTING_CONTROL_PROBE_REPORT.md`
- `INTEGRATED_HEADLESS_AVL_REPORT.md`

## Core Principle

The priority order is now:

```text
measured audio deadline
  > measured audio e2e latency
  > endpoint latency
  > network propagation and queueing
  > packet immediacy
  > drift stability without buffer growth
  > audio robustness by dropout, not delay
  > vendor-neutral video presence
  > video quality
  > lighting cue timing
  > lighting visual completeness
  > recording
  > UI polish
```

If a choice can make audio faster and does not make the system unreliable, take
it. If a choice makes video or lighting better but audio slower, reject it. If a
choice makes lighting better but video worse, reject it unless audio/video are
explicitly out of scope for that run.
