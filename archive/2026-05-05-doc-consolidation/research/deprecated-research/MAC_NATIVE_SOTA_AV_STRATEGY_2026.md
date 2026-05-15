# Mac-Native A/V Strategy For Faster-Than-LoLa Latency

This document elaborates the 2026 state-of-the-art direction for a Mac-native
low-latency A/V system inspired by LoLa, but no longer constrained by Windows
LoLa compatibility.

The key conclusion is simple:

- For audio, macOS can plausibly beat Windows LoLa's endpoint latency when
  using Core Audio HAL/AUHAL or direct `AudioDeviceIOProc` correctly and when
  the reference interface is stable at smaller buffers or higher sample rates.
- With high-end academic hardware and networks, the default should be
  uncompressed PCM over controlled wired paths, not bandwidth-saving codecs.
- For video, XIMEA should be one optional capture adapter, not the architecture.
  The Mac-native baseline should be AVFoundation/Core Media I/O plus optional
  vendor adapters.
- For transport, normal UDP should be tested first; raw packet mechanisms
  should not be part of the fastest native path unless measurement proves a
  need.

## Sources Checked

Primary/current platform sources used for this plan:

- Apple Core Audio overview:
  <https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/WhatisCoreAudio/WhatisCoreAudio.html>
- Apple Audio Workgroups:
  <https://developer.apple.com/documentation/audiotoolbox/understanding-audio-workgroups>
- Apple Core Audio `AudioDeviceStart` / IOProc APIs:
  <https://developer.apple.com/documentation/coreaudio/1422884-audiodevicestart>
- Apple Core Audio `AudioDeviceCreateIOProcIDWithBlock`:
  <https://developer.apple.com/documentation/coreaudio/audiodevicecreateioprocidwithblock%28_%3A_%3A_%3A_%3A%29>
- Apple Core Audio buffer frame size property:
  <https://developer.apple.com/documentation/coreaudio/audiohardwaredevice/bufferframesize>
- Apple Core Audio device latency property:
  <https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertylatency>
- Apple AVFoundation capture setup:
  <https://developer.apple.com/documentation/avfoundation/capture-setup>
- Apple `AVCaptureVideoDataOutput`:
  <https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput>
- Apple `AVCaptureDevice.activeFormat`:
  <https://developer.apple.com/documentation/avfoundation/avcapturedevice/activeformat>
- Apple `AVCaptureDevice.activeVideoMinFrameDuration`:
  <https://developer.apple.com/documentation/avfoundation/avcapturedevice/activevideominframeduration>
- Apple Core Media I/O camera extensions:
  <https://developer.apple.com/documentation/coremediaio/creating-a-camera-extension-with-core-media-i-o>
- Apple VideoToolbox:
  <https://developer.apple.com/documentation/videotoolbox>
- Apple Network `NWProtocolUDP`:
  <https://developer.apple.com/documentation/network/nwprotocoludp>
- Apple Network `NWConnection`:
  <https://developer.apple.com/documentation/network/nwconnection>
- Apple Network `NWEthernetChannel`:
  <https://developer.apple.com/documentation/network/nwethernetchannel>
- Apple AudioDriverKit:
  <https://developer.apple.com/documentation/audiodriverkit/creating-an-audio-device-driver>
- Apple Audio MIDI Setup AVB support:
  <https://support.apple.com/guide/audio-midi-setup/set-up-audio-devices-ams59f301fda/mac>
- IETF Opus RFC 6716:
  <https://datatracker.ietf.org/doc/rfc6716/>
- AES67-2023 official AES listing:
  <https://www.aes.org/publications/standards/search.cfm?docID=96.>
- ESTA published standards list:
  <https://tsp.esta.org/tsp/documents/published_docs.php>
- Art-Net official site:
  <https://art-net.org.uk/>
- OSC 1.0 specification:
  <https://opensoundcontrol.stanford.edu/spec-1_0.html>

## 2026-05-02 Source Refresh

The SOTA routing pass refreshed the drift-prone platform and standards sources.
The current planning defaults remain unchanged:

- Core Audio HAL/AUHAL or direct `AudioDeviceIOProc` is still the fastest audio
  starting point; Audio Workgroups are adopted only after measurement.
- UDP remains the first media transport; custom Ethernet paths require
  entitlement review and are not the default.
- AVFoundation/test-pattern capture remains the first video probe; VideoToolbox
  remains a later bandwidth-constrained probe.
- Apple still documents virtual AVB connections for same-local-network audio,
  including 44.1 kHz to 192 kHz streams, so AVB remains an optional local
  benchmark.
- AES67 remains a professional interop gate, not the native fastest default.
- ESTA lists ANSI E1.31-2025 as the current checked sACN revision and ANSI
  E1.11-2024 as the current checked DMX512-A revision.
- Art-Net remains usable only after specification review, credit handling, and
  OEM-code/licensing review.
- OSC 1.0 remains the first show-control cue-loop semantics.

The full open-question routing is now tracked in
[mac-port/SOTA_2026_OPEN_QUESTION_MATRIX.md](../../mac-port/SOTA_2026_OPEN_QUESTION_MATRIX.md).

## Audio: Where Mac-Native Can Beat LoLa

### Why Mac Can Be Faster

Windows LoLa's audio advantage is not Windows itself. The reverse-engineered
path shows:

- ASIO hardware driver.
- PortAudio callback mode.
- 64-frame 16-bit PCM blocks.
- no codec in the compatibility path.
- tiny receive buffering.
- no wait in the audio callback.

The macOS equivalent is:

```text
Core Audio HAL/AUHAL or direct AudioDeviceIOProc
  -> 32/64-frame hardware buffers
  -> full-duplex callback
  -> preallocated PCM rings
  -> immediate UDP packetization
  -> 0/1 block receive buffer
  -> silence/dropout instead of waiting
```

Apple documents Core Audio as macOS's low-latency audio infrastructure and says
real-time audio can access hardware through the HAL. That is the same class of
interface ASIO provides on Windows, but native to macOS.

At 48 kHz:

```text
32 frames = 0.67 ms
64 frames = 1.33 ms
128 frames = 2.67 ms
```

At 44.1 kHz:

```text
32 frames = 0.73 ms
64 frames = 1.45 ms
128 frames = 2.90 ms
```

At 192 kHz:

```text
32 frames = 0.17 ms
64 frames = 0.33 ms
128 frames = 0.67 ms
```

If the interface and driver are good, the Mac endpoint can land in the same
class as LoLa. It can be faster if:

- the Mac audio interface is stable at 32 frames where the Windows setup uses
  64,
- the Mac audio interface is stable at 16 frames,
- the whole analog path improves at 96 or 192 kHz,
- the Mac path avoids PortAudio and uses HAL/AUHAL directly,
- packetization is done with fewer copies,
- Audio Workgroups improve scheduling of helper threads,
- no hidden sample-rate conversion is allowed,
- no aggregate/Bluetooth/AirPlay path is used.

### Recommended Audio API Stack

Use this order:

1. Direct Core Audio `AudioDeviceIOProc` or AUHAL for the first serious rig.
2. Audio Workgroups for realtime helper threads that must meet the audio
   deadline.
3. BSD UDP sockets for media transport, isolated from the callback.
4. Swift only for configuration, status, and UI.
5. AudioDriverKit only if the project later needs to expose a virtual device or
   support custom hardware.

Avoid for the core realtime path:

- `AVAudioEngine` as the primary transport engine.
- AVFoundation recording/playback abstractions.
- Bluetooth, AirPlay, Continuity microphone, and aggregate devices.
- sample-rate conversion.
- automatic voice processing.
- blocking dispatch queues in the callback.

### Direct HAL vs AUHAL

Two viable Mac-native audio paths:

#### Direct `AudioDeviceIOProc`

Best for the lowest measurable overhead and the cleanest latency experiment.

Use when:

- building the headless latency rig,
- measuring hardware buffer stability,
- aligning I/O directly to host time,
- avoiding audio-unit graph overhead.

The relevant Core Audio APIs include:

- `AudioDeviceCreateIOProcID`
- `AudioDeviceCreateIOProcIDWithBlock`
- `AudioDeviceStart`
- `AudioDeviceStartAtTime`
- `AudioDeviceStop`
- `AudioDeviceGetCurrentTime`
- `AudioDeviceTranslateTime`

#### AUHAL

Best when the app needs a slightly more conventional Core Audio shape while
remaining low-level enough for realtime use.

Use when:

- direct device I/O is too cumbersome,
- channel mapping through audio units is useful,
- later graph integration is needed.

Do not use a general AVFoundation playback/recording queue for the LoLa-class
path.

### Audio Format Strategy

Mac native fastest mode:

- The device callback may use native Core Audio float32 if that is what the
  device path wants.
- Use float32 PCM on the wire on controlled LANs unless bandwidth measurements
  show a reason to use int24/int16.
- Convert only when it reduces measured end-to-end latency or bandwidth pressure
  without adding buffering.
- Do not resample unless the selected hardware cannot run the negotiated rate.
- Prefer 48 kHz for broad stability, then benchmark 96 kHz for lower
  per-buffer time.
- On high-end hardware, also benchmark 192 kHz.
- Prefer 32-frame buffers, then benchmark 16-frame buffers as a stretch target.

Important detail:

Core Audio commonly uses native-endian 32-bit floating-point PCM internally.
Hidden sample-rate conversion and buffering are much more dangerous than PCM
sample-format conversion. Do not choose int16 just because LoLa did. Choose the
wire format that measures fastest for the native path.

The measurement target is audio e2e, not only buffer duration:

```text
ADC + input buffer + callback + packetization + network
  + receive scheduling + playout depth + output buffer + DAC
```

On high-end hardware, converter group delay can dominate after buffers become
very small. The analog loopback result decides whether 96/192 kHz and 16-frame
settings are actually faster.

### Clock Drift Strategy

Two independent audio interfaces will drift. A low-latency Mac implementation
needs an explicit policy:

1. Measure remote arrival timing and local hardware sample time.
2. Keep the target audio receive depth at 0 or 1 callback block.
3. If drift accumulates, correct it outside the callback by:
   - occasional single-sample slip with a tiny crossfade, or
   - a very small low-latency fractional resampler in the network/playout
     preparation path.
4. Never solve drift by growing a large adaptive jitter buffer.

For controlled local networks, also evaluate AVB.

### AVB As A Native "Faster Than LoLa" Local Mode

macOS Audio MIDI Setup supports AVB devices and virtual AVB connections. Apple
documents AVB streams with:

- 1 to 32 channels,
- 44.1 kHz to 192 kHz,
- AM-824 or AAF streaming formats,
- local Ethernet requirements.

This is not Windows LoLa compatibility. It is a Mac-native/local-network mode.

Where AVB can beat LoLa:

- same room,
- same building,
- controlled AVB-capable Ethernet,
- multiple Macs or AVB devices,
- need for clocked, deterministic network audio.

Where AVB does not replace LoLa:

- routed Internet sessions,
- NAT/firewall traversal,
- Windows LoLa peer compatibility,
- unmanaged campus/Wi-Fi links.

Plan consequence:

- Keep UDP/PCM as the general native network path.
- Add AVB as an optional native local-network mode if HfMT hardware/networking
  makes it useful and if measurement beats UDP/PCM.

### Opus Is A Fallback, Not The Fastest Musical Mode

Opus is excellent for interactive audio and supports 2.5 ms frames, but the RFC
also documents algorithmic delay and codec lookahead. For bandwidth-limited
Internet use, Opus can be a good native-mode fallback.

For lowest musical latency on good networks, uncompressed PCM is still the
first target because it avoids:

- codec frame accumulation,
- algorithmic lookahead,
- packet loss concealment buffering,
- encoder/decoder scheduling variance.

Use Opus only as:

- `native-low-bandwidth` mode,
- not the first endpoint-latency benchmark.

## Network: Mac-Native Without Copying WinPcap Blindly

Windows LoLa uses WinPcap and constructs Ethernet/IP/UDP packets. For the native
Mac system, that is historical evidence, not a requirement. The fastest path is
whatever measures best on macOS.

### First Choice: BSD UDP Sockets

Use connected nonblocking UDP sockets for media.

Reasons:

- lowest practical complexity,
- no special raw-packet entitlement,
- no BPF permission problem,
- compatible with normal firewall prompts,
- no raw-packet entitlement or installer burden.

Academic-network assumptions for fastest mode:

- wired 1/10/25 GbE where available,
- direct link, dedicated switch, or dedicated VLAN for benchmarks,
- no Wi-Fi,
- no VPN overlay,
- no consumer NAT traversal requirement,
- DSCP/QoS only where the managed network actually honors it,
- packet capture and monotonic host-time logging for every benchmark.

Use Network.framework for:

- control/discovery,
- path status,
- diagnostics,
- non-realtime session management.

Use BSD sockets for the media hot path if measurement shows Network.framework
callback scheduling adds avoidable variance.

### Packet Capture Is Mandatory

Even if media uses UDP sockets, capture packets for:

- fixture generation,
- timing proof,
- byte-order confirmation,
- packet-shape confirmation,
- drop/reorder testing.

### Raw Packet Fallbacks

If UDP sockets measure too slow or too jittery:

1. Identify whether the issue is scheduling, socket buffering, NIC, switch, or
   packet size before changing APIs.
2. Try lower-level BSD socket tuning and tighter receive loops.
3. Evaluate BPF/libpcap only if there is evidence it helps on macOS.
4. Evaluate Network.framework `NWEthernetChannel` only for native custom
   Ethernet modes. It is for custom Ethernet frame types and requires a custom
   protocol entitlement, so it is not assumed to be a drop-in IPv4/UDP injector.
5. Avoid Network Extension packet tunnels unless the project explicitly becomes
   a VPN/tunnel product. They add entitlement and deployment complexity and are
   not the natural path for low-latency media packets.

On academic networks, raw bandwidth is not the limiting factor for stereo or
multichannel float32 PCM. Packet rate, scheduling jitter, switch queueing, and
clock drift are the real constraints.

## Video: Avoid XIMEA Lock-In

The Windows v2.0 binary proves XIMEA support, but that should not determine the
Mac architecture.

The Mac camera strategy should be adapter-based:

```text
CameraSource interface
  -> AVFoundationCameraSource
  -> CoreMediaIOCameraSource
  -> XimeaCameraSource
  -> BlackmagicOrCaptureCardSource
  -> FilePatternSource
  -> SyntheticTestPatternSource
```

The rest of the video pipeline should not know which camera produced the frame.
It should only see:

```text
frame_id
host_time
pixel_format
width
height
stride
buffer_ref
```

### First-Class Mac-Native Camera Path: AVFoundation

Use AVFoundation for generic camera input:

- UVC webcams,
- USB capture cards,
- Continuity/external cameras where acceptable,
- many class-compliant industrial cameras,
- file/test devices exposed as capture devices.

Use `AVCaptureDevice.DiscoverySession` to enumerate devices and
`AVCaptureVideoDataOutput` to receive frames.

Low-latency AVFoundation rules:

- Select `activeFormat` explicitly.
- Set `activeVideoMinFrameDuration` and `activeVideoMaxFrameDuration` to the
  target FPS supported by that format.
- Use `AVCaptureVideoDataOutput`.
- Set `alwaysDiscardsLateVideoFrames = true`.
- Prefer native pixel formats; Apple explicitly warns not to default to BGRA
  because it may require conversion and more memory.
- Avoid capture presets that silently pick high-resolution still-photo formats.
- Disable stabilization, HDR, beauty/portrait/depth paths, and other processing
  unless proven harmless.
- Timestamp frames at receipt using CMSampleBuffer timing plus host time.

When AVFoundation is fast enough, it gives us vendor neutrality.

When AVFoundation is not fast enough for a specific industrial camera, add a
vendor adapter behind the same interface.

### Core Media I/O Camera Extensions

Core Media I/O camera extensions are the modern macOS way to support custom
camera devices securely. Apple recommends replacing legacy DAL plug-ins with
Core Media I/O extensions.

Use a camera extension when:

- a device needs a custom driver-like integration,
- we want a non-XIMEA camera exposed as a normal system camera,
- we need a virtual test camera for repeatable latency tests,
- we want deployment through a signed app bundle instead of old plug-ins.

Do not use a camera extension as the first latency rig unless a concrete camera
requires it. It is a driver/deployment mechanism, not a substitute for measuring
capture latency.

### Optional Vendor Adapters

Vendor adapters are allowed, but not allowed to define the core:

- XIMEA xiAPI adapter.
- Blackmagic DeckLink adapter.
- other industrial camera SDK adapters.

Rules:

- Each adapter is a plugin or isolated module.
- Each adapter maps to the same `CameraSource` contract.
- A missing vendor SDK must not break generic AVFoundation builds.
- CI must build the core without vendor SDKs.
- Vendor-specific controls are exposed as optional capability dictionaries, not
  core fields.

### Video Transport Modes

Native mode:

- raw or MJPEG for lowest local latency,
- VideoToolbox H.264/HEVC low-latency mode only when bandwidth matters more
  than absolute minimum delay,
- no B-frames,
- short GOP,
- realtime encoder settings,
- late-frame drop policy.

VideoToolbox is useful because it gives direct access to hardware encoders and
decoders. It is not automatically faster end-to-end than raw/MJPEG at low
resolution on a strong LAN. It is a bandwidth/CPU tool first, not an audio
latency tool.

### Video Latency Reality Check

Video has a hard floor that audio does not:

```text
minimum video delay >= exposure time + frame period + capture transfer
```

Examples:

```text
60 fps  frame period = 16.67 ms
120 fps frame period = 8.33 ms
240 fps frame period = 4.17 ms
```

Therefore video cannot be the benchmark for LoLa-class musical latency. It must
serve presence and cueing while audio carries musical timing.

## SOTA 2026 Architecture Recommendation

Build one native fastest path first. Treat LoLa compatibility as historical
reference only unless it is explicitly reintroduced later.

### Mac-Native Low-Latency Mode

Purpose:

- exploit macOS and controlled Mac/Mac deployments without Windows constraints.

Audio:

- direct Core Audio IOProc or AUHAL,
- 32-frame target,
- 16-frame stretch target if hardware is stable,
- 96 kHz benchmark path if hardware remains stable,
- 192 kHz benchmark path on high-end interfaces,
- float32 internally if device-native,
- float32 PCM over UDP on controlled academic networks,
- optional AVB/TSN local mode,
- optional Opus only for bandwidth-limited sessions.

Video:

- AVFoundation camera source,
- native pixel format,
- late frame discard,
- raw or simple intra-frame transport for local low latency,
- VideoToolbox low-latency encode when bandwidth is constrained,
- Core Media I/O camera extension only when a device or virtual camera needs
  it.

## Updated Hardware Strategy

Audio reference hardware matters more than camera vendor.

Audio hardware requirements:

- class-compliant or vendor driver with stable 32/64-frame operation,
- 16-frame capability preferred,
- 96/192 kHz capability preferred if analog latency improves,
- wired USB/Thunderbolt, not Bluetooth/AirPlay,
- reliable clock,
- controllable sample rate,
- multichannel support if needed,
- no hidden DSP path.

Video hardware requirements:

- generic AVFoundation support preferred,
- UVC/capture-card path preferred for first vendor-neutral build,
- 60 fps minimum, 120 fps preferred for responsive presence video,
- native low-conversion pixel formats,
- exposure control,
- fixed frame duration support,
- timestamp access.

Do not choose the project architecture around one camera. Choose cameras that
fit the architecture.

## Revised Milestone Bias

Replace "XIMEA camera prototype" with:

1. AVFoundation generic camera probe.
2. File/test-pattern camera source.
3. XIMEA adapter only if the real deployment hardware requires it.
4. Core Media I/O extension only if we need custom camera publishing or a
   virtual test source.

Audio milestone remains first:

1. Direct HAL/AUHAL audio rig.
2. 32-frame stability, then 16-frame stretch testing.
3. analog loopback measurement.
4. academic network profile certification.
5. Mac-to-Mac UDP PCM on certified paths.
6. fastest measured e2e mode selection.
7. drift correction without buffer growth.
8. AVB/TSN evaluation if hardware exists.
9. only then video.

## Success Criteria

Audio success:

- 32 or 64 frames stable for 30 minutes.
- endpoint analog loopback measured.
- no callback allocation/locks/logging.
- 0 or 1 block receive buffer.
- silence/dropout instead of waiting.
- Mac-to-Mac UDP PCM measured on academic network profiles.
- 96/192 kHz and 16-frame modes benchmarked where hardware permits.
- fastest mode chosen by measured e2e audio latency, not theory.

Video success:

- AVFoundation source works with at least one generic external camera.
- file/test source works for reproducible protocol tests.
- raw/MJPEG protocol works without a camera.
- XIMEA is optional.
- video can be disabled or degraded without changing audio metrics.

Project success:

- the core builds without XIMEA SDK.
- the app can ship a generic camera/audio path.
- vendor SDKs are optional plugins.
- Windows compatibility is not a design constraint.
