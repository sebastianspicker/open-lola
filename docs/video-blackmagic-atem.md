# Blackmagic and ATEM video

In code today: the macOS runtime captures from any AVFoundation-visible camera,
sends and receives raw video over UDP, shows a local preview, and has a read-only
ATEM reachability probe. Blackmagic Desktop Video SDK capture and DeckLink output
are not implemented, and no Blackmagic or ATEM hardware has been tested.

Video is secondary: it uses bounded resources and drops or degrades before audio
timing changes.

## Evidence Labels

| Area | Label |
|---|---|
| AVFoundation, VideoToolbox, and Blackmagic Desktop Video SDK references | `public API` |
| UDP fragmentation and timestamp vocabulary | `public standard` |
| Stream descriptors, drop rules, reports, and multi-stream selection | `original open-lola design` |
| Physical capture and render and audio-impact thresholds | `experimentally derived requirement` |

## What the code does

The macOS runtime can:

- list and capture from AVFoundation-visible devices;
- flag Blackmagic, ATEM, DeckLink, and UltraStudio devices by the name they
  report;
- fragment raw frames and send and receive them in UDP media envelopes;
- reassemble complete frames and show a local preview;
- report capture, packet, queue, drop, and presentation values;
- run up to four synthetic raw-fragment streams for local multi-stream tests.

The source also models VideoToolbox and JPEG XS payloads and has a placeholder
for Blackmagic output. If the Desktop Video SDK module is present at build time,
the placeholder reports it as linked but enumerates no hardware and outputs
nothing.

## Stream and scheduling rules

- Before media starts, negotiate stable stream IDs, role, format, dimensions,
  frame rate, priority, queue depth, and bandwidth budget.
- Keep queues bounded and prefer the latest complete frame.
- Drop incomplete, duplicate, late, or lower-priority video before delaying
  audio.
- Keep counters and selection state per stream.
- Audio is the clock. Video may follow audio timing but never holds audio back
  for sync.
- Use compression only after encode and decode latency, queueing, reordering,
  CPU and memory use, and impact on audio have been measured.

ATEM support is a read-only TCP reachability probe. It does not check the
protocol, model, or switching, and the code sends no switching commands.

## What a hardware result needs

Record device, firmware, and driver identity, the API used, format and frame
rate, capture-to-packet and receive-to-display timing, fragment completeness,
drops, CPU and memory use, an audio callback comparison, and a packet capture of
the route. A multi-camera claim needs every selected input and output active in
the same measured run.

VERDICT: PARTIAL
