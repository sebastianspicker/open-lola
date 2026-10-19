# Latency-first architecture

Audio deadlines drive the runtime design. Video, control, monitoring, recording,
and report work must degrade or stop before they add unbounded work to realtime
audio. The macOS and Rust runtimes implement this; physical end-to-end
performance has not been measured.

## Evidence Labels

| Choice | Label |
|---|---|
| Core Audio `AudioDeviceIOProc`, AUHAL, AVFoundation, and VideoToolbox APIs | `public API` |
| UDP, DSCP, PTP, and AVB vocabulary | `public standard` |
| Session profiles, packet formats, queue policies, and reports | `original open-lola design` |
| Hardware promotion thresholds | `experimentally derived requirement` |
| Direct-route lowest-buffer operation | `implementation hypothesis` until measured |

## Critical path

On macOS, audio goes from the device callback to a preallocated handoff, then
packetization, UDP send, receive and reassembly, the RX buffer policy, and the
output callback. Codecs run only when selected. Logging, allocation, blocking
file, process, or network calls, and report serialization never happen inside a
realtime callback.

The Rust station follows the same priorities with its own PortAudio/ASIO and
transport code. The retired Python connector was a compatibility harness and was
never meant for realtime scheduling.

## Scheduling and buffering

- Audio work is bounded by the negotiated frame count, channels, format, and MTU.
- Queues are bounded and report drops, late packets, underruns, and overruns.
- UDP audio is never retransmitted on the critical path.
- Packet loss concealment (PLC), silence, or repeat-last is a visible setting.
- RX buffering reports the latency it adds and never switches profile on its own.
- Video frames may be dropped when incomplete, late, or under load.
- Control, OSC, sACN, Art-Net, metrics, and file output stay off the audio
  callback.

## Timing and AV sync

Audio is the clock that presentation follows. Monotonic timestamps, sequence
numbers, packet age, jitter, drift, and buffer occupancy are all reported. Video
may be scheduled relative to audio, but audio is never delayed to save a late
video frame. A PTP or AVB-capable route is recorded as a route property; the
runtime does not assume either just because the platform exposes it.

## Fallback

A faster mode is used only when there is evidence for its device, route, buffer
size, callback timing, loss, and media content. Without that, the run must show
a visible downgrade, a `PARTIAL` result, or an error, never an optimistic latency
figure. Synthetic, localhost, and built-in-device probes are useful for
diagnosis but say nothing about physical end-to-end performance.

See [latency-profiles.md](latency-profiles.md) for the profiles,
[rx-buffering.md](rx-buffering.md) for buffer behavior, and
[benchmark-methodology.md](benchmark-methodology.md) for measurement rules.

VERDICT: PARTIAL
