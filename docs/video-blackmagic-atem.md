# Blackmagic and ATEM video

Status: AVFoundation and UDP source paths implemented; physical hardware open
Verdict: PARTIAL

Video is an auxiliary path. It may consume only bounded resources and must drop
or degrade before audio timing changes.

## Evidence Labels

| Boundary | Label |
|---|---|
| AVFoundation, VideoToolbox, and Blackmagic Desktop Video SDK references | `public API` |
| UDP fragmentation and timestamp vocabulary | `public standard` |
| Stream descriptors, drop rules, reports, and multi-stream selection | `original open-lola design` |
| Physical capture and render and audio-impact thresholds | `experimentally derived requirement` |

## Implemented source boundary

The macOS runtime can:

- enumerate and capture AVFoundation-visible devices;
- classify Blackmagic, ATEM, DeckLink, and UltraStudio candidates by reported
  identity;
- fragment raw frames and send and receive UDP media envelopes;
- reassemble complete frames and render a local preview;
- report capture, packet, queue, drop, and presentation observations; and
- stage up to four synthetic raw-fragment streams for local multi-stream testing.

The source also models VideoToolbox and JPEG XS payload choices and a Blackmagic
output boundary. A model, availability flag, selected device, or localhost
preview is not proof that the Desktop Video SDK is linked or that a physical
input or output path worked.

## Stream and scheduling rules

- Negotiate stable stream IDs, role, format, dimensions, frame rate, priority,
  queue depth, and bandwidth budget before media starts.
- Keep queues bounded and prefer the latest complete usable frame.
- Drop incomplete, duplicate, late, or lower-priority video before delaying
  audio.
- Maintain independent counters and selection state per stream.
- Keep audio the presentation master: video may follow audio-relative timing but
  may not hold audio for synchronization.
- Treat compression as eligible only after encode and decode latency, queueing,
  reordering, CPU and memory, and audio impact are measured.

ATEM control is read-only in the current source: a reachable TCP endpoint does not
prove protocol compatibility, model identity, or switching capability. No
switching command should be implied or armed by documentation.

## Physical validation

Record device, firmware, and driver identity, exposed API, format, frame rate,
capture-to-packet and receive-to-display timing, fragment completeness, drops,
CPU and memory, an audio callback comparison, and a packet-captured route.
Multi-camera claims need every selected input and output active in the same
measured run.

VERDICT: PARTIAL
