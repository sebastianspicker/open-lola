# RME MADI audio

In code today: the macOS runtime reads Core Audio device properties, runs
multichannel MADI-style send, receive, and full-duplex paths over any Core Audio
device (`madi-*` CLI commands), and validates RME fastest-path reports. No RME
interface, driver, or clock setup has been tested, so the hardware sections are
design notes.

## Evidence Labels

| Area | Label |
|---|---|
| Core Audio HAL properties, `AudioDeviceIOProc`, and AUHAL | `public API` |
| MADI channel and clock vocabulary | `public standard` |
| Device reports, route metadata, and fastest-path validator | `original open-lola design` |
| Accepted buffer and latency values for a named device | `experimentally derived requirement` |

## What the code does

The media platform reads device identity, stream and channel counts, nominal
sample rates, buffer-frame ranges, latency, safety offsets, and clock domain.
Realtime and loopback code gives each callback its own storage and uses
preallocated handoff buffers. Reports keep requested settings, accepted device
settings, callback observations, route metadata, and missing evidence apart.

Select devices by their stable Core Audio UID, not their display name. Input and
output are separate choices. A same-device or built-in loopback is a diagnostic
only; never report it as a network or RME/MADI result.

## Runtime rules

- Negotiate sample rate, channel count, format, and buffer size before media
  starts.
- Keep allocation, blocking I/O, logging, file writes, and network setup out of
  the callback.
- Keep channel order fixed through capture, packetization, receive, routing, and
  playback.
- Record the clock source, clock domain, and any drift correction. Matching
  nominal rates do not mean the clocks are locked.
- If the requested device or mode is unavailable, fail or report a visible
  fallback.

## What a hardware result needs

Record all of this for one revision:

- interface model and driver version;
- connection and clock topology;
- sample rate and active channel count;
- requested and accepted buffer sizes;
- sustained callback timing, underrun and overrun counts;
- loopback or two-peer latency;
- the report files from that run.

See [audio-routing.md](audio-routing.md) for channel routing,
[rme-madi-routing.md](rme-madi-routing.md) for MADI mapping, and
[benchmark-methodology.md](benchmark-methodology.md) for measurement.

VERDICT: PARTIAL
