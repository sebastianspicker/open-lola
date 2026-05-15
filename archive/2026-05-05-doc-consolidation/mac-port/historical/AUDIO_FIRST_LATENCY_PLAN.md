# Audio-First Low-Latency Mac Port Plan

Status note: this was the first audio-first plan while Windows LoLa
compatibility was still being considered. The current strategy no longer
requires Windows LoLa compatibility and is superseded for implementation order
by `MAC_PORT_PLAN.md`. The audio latency principles in this file still apply.

## Purpose

This is the first durable plan for a macOS LoLa port optimized for the lowest
possible end-to-end musical interaction latency.

The priority is audio latency and audio jitter, not throughput, image quality,
UI completeness, or general conferencing comfort. Video can be visually
degraded if needed. Audio latency is the gate because it is what makes or breaks
musical use.

## Core Point

LoLa is fast because it refuses most things that normal conferencing software
does for comfort:

- No heavy audio codec path.
- No echo cancellation.
- No automatic gain control.
- No noise suppression.
- No adaptive "make it smooth" buffering.
- No NAT/firewall-friendly transport design as the primary constraint.
- No retransmission safety net.
- Minimal video processing when speed matters.

It pushes the burden onto hardware, drivers, operating-system scheduling, and
the network.

For the Mac version, the audio requirement is therefore not "good Core Audio
playback." The requirement is hard realtime full-duplex PCM with 32 or 64
sample buffers, tiny or zero receive buffering, stable clocking, and no hidden
processing.

## Evidence Baseline

The LoLa manual and paper point to five main reasons for LoLa-class latency.

### 1. Tiny Audio Hardware Buffers

The LoLa manual says to set the audio interface buffer to 32 samples, about
0.7 ms at 44.1 kHz, and to use 64 samples only if 32 is unsupported. It also
says LoLa checks this at launch and warns when the setting is wrong.

Source: LoLa Manual 2.0.0, audio setup:
<https://lola.conts.it/downloads/Lola_Manual_2.0.0_rev_001.pdf>

### 2. ASIO-First, Hardware-Driver-First Design

The Windows binary imports PortAudio and ASIO-specific functions. The manual
warns against ASIO4ALL because performance is unstable. LoLa's speed depends on
real low-latency hardware drivers, not generic system audio.

Source: LoLa Manual 2.0.0, audio hardware setup:
<https://lola.conts.it/downloads/Lola_Manual_2.0.0_rev_001.pdf>

### 3. Uncompressed Or Minimally Processed Audio

The protocol negotiates exact audio parameters. The manual states that audio
parameters must match exactly. The default is 44.1 kHz, 16-bit, stereo, and
LoLa 1.5+ also supports 48 kHz.

This implies no adaptive codec negotiation, no speech processing, and no
sample-rate conversion unless forced by a fallback path.

Source: LoLa Manual 2.0.0, connection negotiation:
<https://lola.conts.it/downloads/Lola_Manual_2.0.0_rev_001.pdf>

### 4. Minimal Buffering By Design

LoLa documentation says adding buffers adds latency. In a correct setup, video
buffers are normally 0, and audio buffers should be 0 if possible and not
exceed 5.

Source: LoLa Manual 2.0.0, buffer tuning:
<https://lola.conts.it/downloads/Lola_Manual_2.0.0_rev_001.pdf>

### 5. Low-Level Packet Handling And No Recovery Comfort

The original LoLa paper says low-level packet handling was used to avoid hidden
queueing, with ring buffers only for jitter compensation. It reports audio RTT,
excluding network delay, as low as 5 ms.

Source: Drioli, Allocchio, Buso, 2013:
<https://www.internetsociety.org/wp-content/uploads/2013/09/32_LOLA.pdf>

## Audio Targets

Minimum target for the Mac port:

- Full-duplex audio at 44.1 kHz and 48 kHz.
- 16-bit PCM compatibility for LoLa interop.
- 2 channels first.
- 4 channels second.
- Up to LoLa's observed 10-channel range after the stereo path is proven.
- Hardware buffer: 32 frames preferred.
- Hardware buffer: 64 frames acceptable.
- 128 frames only as fallback or debug mode.
- No Bluetooth, AirPlay, aggregate device, browser stack, or virtual routing in
  the critical path.
- No AEC, AGC, noise suppression, limiter, codec, sample-rate conversion, or
  adaptive comfort buffering in the target path.
- Endpoint audio latency budget, excluding network: aim for <= 5 ms
  RTT-equivalent, matching LoLa's stated class of performance.
- Receive jitter buffer: default 0 or 1 audio buffers.
- User-adjustable receive jitter buffer only upward, and only when measured
  network instability proves it is needed.

At 48 kHz:

```text
32 frames  = 0.67 ms
64 frames  = 1.33 ms
128 frames = 2.67 ms
```

A 128-frame design is already drifting away from LoLa. It may be useful as a
fallback/debug mode, not as the target.

## macOS Audio Approach

Use Core Audio, but treat it as a realtime system:

- Use AUHAL or direct HAL rather than AVFoundation playback/recording
  abstractions.
- Query and set the device buffer size with Core Audio device properties.
- Query HAL timing and latency reporting for diagnostics.
- Run the audio path in C/C++ or carefully written C-compatible Swift bridging,
  not SwiftUI.
- Keep the audio callback allocation-free and lock-free.
- Preallocate all buffers.
- Use single-producer/single-consumer ring buffers between audio and network
  threads.
- Do not log, allocate, open files, call Objective-C/Swift UI, or block inside
  the callback.
- Use Audio Workgroups on modern macOS for realtime helper threads that must
  meet the audio render deadline.

Apple documents Core Audio's HAL as the layer for realtime hardware access and
timing information. Apple documents Audio Workgroups for coordinating realtime
audio threads with common deadlines.

Sources:

- Apple Core Audio overview:
  <https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/WhatisCoreAudio/WhatisCoreAudio.html>
- Apple Audio Workgroups:
  <https://developer.apple.com/documentation/audiotoolbox/understanding-audio-workgroups>

## Implementation Shape

```text
Core Audio input callback
  -> copy PCM frames into lock-free capture ring
  -> timestamp with host time and sample counter

Network send thread
  -> read exact audio blocks
  -> packetize immediately
  -> UDP send

Network receive thread
  -> receive packet
  -> validate sequence and timestamp
  -> put into small jitter ring

Core Audio output callback
  -> read next remote audio block
  -> if missing, increment underrun counter and output silence or last-safe data
  -> never wait
```

Critical design rule: prefer a click or dropout over waiting. LoLa's speed comes
from choosing low latency over concealment. A Mac port that smooths every packet
loss with a large adaptive buffer may sound more stable, but it will no longer
be LoLa-class.

## First Prototype

The first prototype should be a headless Core Audio + UDP latency rig.

It should not include:

- A polished UI.
- Camera integration.
- Video encoding improvements.
- Recording features beyond diagnostic capture.
- NAT traversal.
- Authentication.
- WebRTC.
- A modern adaptive audio stack.

It should include:

- Device enumeration.
- Explicit input/output device selection.
- Sample-rate selection: 44.1 kHz and 48 kHz.
- Channel-count selection: stereo first.
- Hardware buffer query and set.
- Full-duplex callback.
- PCM capture ring.
- PCM playback ring.
- UDP sender.
- UDP receiver.
- Tiny receive jitter ring.
- Counters for all timing failures.
- CSV or plain-text diagnostics written outside the realtime callback.

## Milestones

### Milestone 0: Protocol And Hardware Dossier

Goal: avoid guessing on the parts Claudio or Windows packet traces can clarify.

Tasks:

- Ask Claudio for source, protocol notes, packet structures, and build context.
- Confirm default UDP ports: 7000, 19788, and 19798.
- Confirm which port maps to service, audio, and video.
- Document exact audio packet format.
- Document sequence number, timestamp, and session ID semantics.
- Document sample-rate, bit-depth, and channel negotiation.
- Document channel ordering for stereo, 4-channel, and higher channel counts.
- Confirm whether WinPcap is used for performance only or for behavior that
  normal UDP sockets cannot reproduce.
- Capture a Windows-to-Windows session if allowed.

Deliverable:

- `PROTOCOL_DOSSIER.md`

### Milestone 1: Headless Core Audio Rig

Goal: prove realtime macOS audio viability before any UI or video work.

Tasks:

- Enumerate Core Audio devices.
- Reject Bluetooth, AirPlay, aggregate devices, and virtual devices in target
  mode.
- Select input and output device.
- Set 44.1 kHz and 48 kHz where supported.
- Set 32-frame buffer where supported.
- Fall back to 64-frame buffer where needed.
- Run full-duplex audio for 30 minutes.
- Count callback deadline misses, underruns, overruns, and drift.
- Save a local diagnostic WAV from outside the callback.

Deliverable:

- Headless audio test tool.
- Hardware compatibility note.
- 30-minute stability report.

### Milestone 2: Analog Loopback Latency Measurement

Goal: measure the real endpoint audio latency instead of trusting software
counters.

Tasks:

- Send an impulse or click from output to input using a physical cable.
- Timestamp output scheduling and input detection.
- Compare software timing with recorded analog loopback timing.
- Repeat at 32 and 64 frames.
- Repeat at 44.1 kHz and 48 kHz.

Deliverable:

- Analog loopback latency report.
- Gate result: target path must approach LoLa-class <= 5 ms RTT-equivalent
  excluding network.

### Milestone 3: Mac-To-Mac UDP Audio Rig

Goal: measure real networked audio behavior on a controlled LAN.

Tasks:

- Packetize fixed PCM blocks immediately after capture.
- Send over UDP without retransmission.
- Receive into a 0 or 1-block jitter ring.
- Output from the Core Audio callback without waiting.
- Count packet loss, late packets, underruns, jitter depth, and drift.
- Test direct cable and LAN switch paths.

Deliverable:

- Mac-to-Mac LAN audio RTT report.
- Recommended default jitter depth.
- Known-good hardware and NIC notes.

### Milestone 4: Windows LoLa Compatibility

Goal: prove that the Mac audio path can interoperate with existing Windows LoLa
peers.

Tasks:

- Implement enough control negotiation for audio.
- Match sample rate exactly.
- Match bit depth exactly.
- Match channel count exactly.
- Match packet format exactly.
- Test 44.1 kHz, 16-bit, stereo first.
- Add 48 kHz only after the default path works.
- Verify behavior when parameters mismatch.

Deliverable:

- Mac-to-Windows audio compatibility report.
- Packet logs and decoded fields.
- List of confirmed incompatible assumptions.

### Milestone 5: Minimal Video Only After Audio Gate

Goal: add video without compromising audio deadlines.

Tasks:

- Keep video on separate threads and separate queues.
- Prefer degraded video over delayed audio.
- Start with compatibility-oriented video behavior.
- Avoid any video work on or near the audio callback deadline.
- Track CPU load and packet pressure against audio misses.

Deliverable:

- Audio-safe video prototype.
- Evidence that video load does not increase audio deadline misses.

### Milestone 6: Native App Shell

Goal: wrap proven realtime behavior in a usable Mac app.

Tasks:

- Build SwiftUI/AppKit UI only after the headless rig passes.
- Keep realtime code in the C/C++ core.
- Use a thin Swift bridge for commands and metrics.
- Show device setup, session state, audio counters, network counters, and jitter
  depth.
- Do not allow UI actions to block realtime threads.

Deliverable:

- First usable native macOS app shell.

## Acceptance Tests Before UI Work

Audio is the gate. Before UI work, prove:

1. Selected Mac audio hardware can run stable at 32 or 64 frames for
   30 minutes.
2. Callback deadline misses are measured.
3. Analog loopback round-trip is measured with cable and impulse.
4. Mac-to-Mac audio RTT over LAN is measured.
5. Mac-to-Windows LoLa compatibility works with exact sample rate, bit depth,
   and channel count.
6. Runtime metrics exist for underruns, overruns, dropped packets, late
   packets, jitter-buffer depth, clock drift, and sequence gaps.

## Metrics

Track at minimum:

- Hardware buffer size.
- Actual callback period.
- Callback duration.
- Callback deadline misses.
- Input overruns.
- Output underruns.
- Capture ring fill depth.
- Playback ring fill depth.
- Network receive jitter ring depth.
- UDP packets sent.
- UDP packets received.
- UDP packets dropped.
- UDP packets late.
- UDP sequence gaps.
- Audio clock drift.
- Endpoint loopback latency.
- Mac-to-Mac LAN RTT.
- Mac-to-Windows LoLa interop result.

## Design Rejection List

Do not put these in the target critical path:

- AVFoundation audio capture/playback abstractions.
- Bluetooth audio.
- AirPlay.
- Aggregate devices.
- Browser audio.
- WebRTC.
- Echo cancellation.
- Automatic gain control.
- Noise suppression.
- Limiters.
- Adaptive comfort buffering.
- Retransmission.
- Hidden sample-rate conversion.
- Heavy audio codecs.
- UI calls from realtime code.
- File I/O from realtime code.
- Logging from realtime code.
- Allocation from realtime code.
- Locks from realtime code.

## Open Questions

- Which exact Mac audio interface is the reference target?
- Can the reference hardware reliably expose 32-frame buffers on macOS?
- Is 64 frames acceptable for field use if 32 frames is unstable?
- Does Windows LoLa use UDP sockets for payload transport, WinPcap injection, or
  both?
- What are the exact audio payload headers?
- What are the exact timestamp units?
- How is clock drift corrected in the Windows implementation?
- Is silence preferred over last-safe sample repeat on underrun?
- Is Mac-to-Windows interop mandatory before Mac-to-Mac native work?
- Which LoLa version is the interop baseline: 1.5, 2.0, or both?

## First Implementation Bias

Prefer this order:

1. Protocol dossier.
2. Headless Core Audio rig.
3. Analog loopback measurement.
4. Mac-to-Mac UDP audio rig.
5. Mac-to-Windows audio interop.
6. Minimal video.
7. Native app shell.

Avoid this order:

1. UI first.
2. Camera first.
3. Video quality first.
4. Codec modernization first.
5. Adaptive buffering first.
6. General conferencing features first.
