# RME MADI audio

Status: Core Audio source paths implemented; physical RME evidence open
Verdict: PARTIAL

The macOS runtime uses public Core Audio APIs to enumerate devices and model
low-latency input and output operation. RME and MADI names describe an intended
hardware class; they are not evidence that a specific interface, driver, clocking
topology, or channel count has passed.

## Evidence Labels

| Boundary | Label |
|---|---|
| Core Audio HAL properties, `AudioDeviceIOProc`, and AUHAL | `public API` |
| MADI channel and clock vocabulary | `public standard` |
| Device reports, route metadata, and fastest-path validator | `original open-lola design` |
| Accepted buffer and latency values for a named device | `experimentally derived requirement` |

## Implemented source boundary

The media platform can read device identity, stream and channel counts, nominal
sample rates, buffer-frame ranges, latency, safety offsets, and clock-domain
information. Realtime and loopback code uses explicit callback ownership and
preallocated handoff paths. Reports keep requested settings, accepted device
settings, callback observations, route metadata, and missing evidence separate.

Device selection must use stable Core Audio identifiers rather than display names,
and input and output devices are independent choices. A same-device or built-in
loopback is diagnostic evidence only; it must not be described as a network or
RME/MADI result.

## Runtime rules

- Negotiate sample rate, channel count, format, and buffer size before starting
  media.
- Keep allocation, blocking I/O, logs, file writes, and network setup outside the
  callback.
- Preserve channel order explicitly across capture, packetization, receive,
  routing, and playback.
- Record clock source and domain and any drift correction; do not infer lock from
  matching nominal rates.
- Fail, or report a visible fallback, when the requested device or mode is
  unavailable.

## Physical validation

A hardware claim needs the exact interface and driver version, connection and
clock topology, sample rate, active channel count, requested and accepted buffer
sizes, sustained callback timing, underrun and overrun counts, loopback or
two-peer latency, and the evidence artifacts for the same revision. The source
tree and synthetic reports do not supply that proof.

Channel routing is defined in [audio-routing.md](audio-routing.md), MADI-specific
mapping in [rme-madi-routing.md](rme-madi-routing.md), and measurement practice in
[benchmark-methodology.md](benchmark-methodology.md).

VERDICT: PARTIAL
