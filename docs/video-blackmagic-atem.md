# Blackmagic And ATEM Video Plan

Date: 2026-05-21
Status: source-level AVFoundation video, transport, and Blackmagic/ATEM gates implemented; physical hardware evidence pending
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| AVFoundation, VideoToolbox, Blackmagic Desktop Video SDK, and ATEM references | `public API` |
| Video degrading before audio latency changes | `original open-lola design` |
| Raw or intra-frame fastest profile before compression | `implementation hypothesis` |
| Frame-age, CPU, and audio-impact reports as closure evidence | `experimentally derived requirement` |

## Objective

Add reliable low-latency video after the audio path is measurable. Video must
never increase default audio playout latency.

## Capture API Path

Initial path:

- AVFoundation inventory and capture for macOS-exposed cameras, ATEM feeds,
  UltraStudio, DeckLink, or compatible devices;
- Blackmagic Desktop Video SDK adapter only if AVFoundation does not expose the
  required device or adds unacceptable latency;
- ATEM control remains read-only until explicit safety and workflow gates exist.

Current source status:

- AVFoundation capture is implemented for macOS-visible devices and classifies
  ATEM, DeckLink, and UltraStudio names as Blackmagic production candidates.
- Source-level RX/render uses a local preview renderer, bounded pacing/drop
  metrics, and a Blackmagic output boundary; DeckLink output is not linked.
- Source-level video TX/RX exists for raw fragments and UDP media-envelope
  payloads with stream IDs, source role, timestamp basis, dimensions, pixel
  format, frame rate, duplicate/late/incomplete counts, and render/output
  latency metrics.
- Multi-stream local test-pattern staging is implemented, currently capped at
  four raw-fragment streams; physical multi-camera route evidence remains open.
- Stream metadata negotiation exists through `VideoStreamDescription` and
  session negotiation, but peer-session hardware evidence remains open.

## Format Strategy

Fastest profile:

- raw or intra-frame-only path first;
- latest-frame queue;
- queue depth of one unless measurement proves otherwise;
- `video-transport-run` sends raw frame fragments through UDP sockets and
  reassembles only received fragments; it can also stage up to four
  test-pattern streams with `--stream-count` and `--visible-streams`.
  Localhost socket probes remain PARTIAL until production Blackmagic/ATEM
  hardware and packet-captured route evidence exist;
- bounded video fragments carry frame sequence, timestamp, fragment
  index/count, payload offset, and payload length;
- drop stale frames;
- no reliable retransmission on the video media path;
- no frame reordering for the fastest profile.

Quality profile:

- higher resolution or compressed formats only after benchmark evidence;
- VideoToolbox is optional and must prove queue depth, encode latency, decode
  latency, CPU load, and no audio impact.

## Initial Profiles

| Profile | Purpose | Notes |
|---|---|---|
| `video-fastest-720p60` | low-latency proof | raw/intra, latest frame, audio protected |
| `video-fastest-540p60` | bandwidth fallback | lower bandwidth, same timing policy |
| `video-quality-1080p30` | optional quality | only after audio PASS |
| `video-quality-1080p60` | optional quality | requires route and CPU headroom |

## AV Sync Policy

Audio is master. Video frames carry monotonic timestamps and are rendered as
nearest/latest useful frames. The renderer may drop video; it must not hold
audio to maintain visual sync.

## Validation

Required measurements:

- frame age at capture;
- frame interval at capture;
- capture-to-packet time;
- fragment count and reassembly completeness;
- dropped frames;
- CPU load with audio active;
- process memory pressure with audio active;
- audio callback timing before and during video;
- packet-captured physical route for transport claims.

## Resume here

Do not start M08/M09 physical closure until the audio path and direct route are
accepted. Then attach Blackmagic/ATEM hardware and run inventory before adding
any Desktop Video SDK adapter.

VERDICT: PARTIAL
