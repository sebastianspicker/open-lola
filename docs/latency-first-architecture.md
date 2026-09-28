# Latency-first architecture

Status: implemented source architecture; physical performance unverified
Verdict: PARTIAL

Audio deadlines govern the runtime. Video, control, monitoring, recording, and
evidence work must degrade or stop before they add unbounded work to realtime
audio paths.

## Evidence Labels

| Choice | Label |
|---|---|
| Core Audio `AudioDeviceIOProc`, AUHAL, AVFoundation, and VideoToolbox boundaries | `public API` |
| UDP, DSCP, PTP, and AVB vocabulary | `public standard` |
| Session profiles, packet formats, queue policies, and reports | `original open-lola design` |
| Hardware promotion thresholds | `experimentally derived requirement` |
| Direct-route lowest-buffer operation | `implementation hypothesis` until measured |

## Critical path

The macOS audio path runs from device callback to preallocated handoff,
packetization, UDP transport, receive and reassembly, RX policy, and output
callback. Codec work is explicitly selected. Logging, allocation, blocking
file, process, and network work, and report serialization all stay outside
realtime callbacks.

The Rust station follows the same operational priority with independently
implemented PortAudio/ASIO and transport code. The retired Python connector was a
compatibility harness and never claimed native realtime scheduling.

## Scheduling and buffering

- Audio work is bounded by the negotiated frames, channels, format, and MTU.
- Queues are bounded and expose drop, late, underrun, and overrun observations.
- UDP audio is not retransmitted on the critical path.
- Packet loss concealment (PLC), silence, or repeat-last behavior is selected
  explicitly rather than hidden.
- RX buffering exposes its added latency and never silently changes profile.
- Video frames may be dropped when incomplete, late, or under pressure.
- Control, OSC, sACN, Art-Net, metrics, and file output remain off the audio
  callback.

## Timing and AV synchronization

Audio is the presentation master. Monotonic timestamps, sequence numbers, packet
age, jitter, drift, and buffer occupancy are reportable observations. Video
scheduling may use audio-relative timing but may not delay audio to save an
expired video frame. PTP or an AVB-capable route can be recorded as a route
capability; neither is assumed merely because the platform exposes it.

## Fallback behavior

A faster mode is eligible only when its device, route, buffer, callback, loss,
and useful-media evidence exists. Failure to meet that scope must produce a
visible downgrade, `PARTIAL`, or error rather than an optimistic latency claim.
Synthetic, localhost, and built-in-device probes remain useful diagnostics but
cannot qualify physical end-to-end performance.

The concrete profiles are in [latency-profiles.md](latency-profiles.md), buffer
behavior in [rx-buffering.md](rx-buffering.md), and measurement rules in
[benchmark-methodology.md](benchmark-methodology.md).

VERDICT: PARTIAL
