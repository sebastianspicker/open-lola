# G07 AVFoundation Capture

## LoLa Comparison

LoLa uses specialized camera hardware and low-latency video capture. The
Mac-native path starts with AVFoundation and generic capture devices, but video
is subordinate: frame age and drops are acceptable, audio p99/max increases are
not.

## Current Repo State

- Related milestone: [../milestones/M08_GENERIC_VIDEO_CAPTURE_PROBE.md](../milestones/M08_GENERIC_VIDEO_CAPTURE_PROBE.md)
- Live status: [../status/M08_STATUS.md](../status/M08_STATUS.md)
- Existing source has test-pattern capture, latest-frame queue, AVFoundation
  inventory reporting, report validation, and synthetic smoke.
- Existing source also has an `AVFoundationCameraSource` backed by
  `AVCaptureVideoDataOutput`, a `video-capture-run` CLI that requests camera
  permission only for an intentional live run, and PARTIAL video-only reports
  with frame age, drop counts, and process CPU deltas.
- Missing piece: audio-on/video-on evidence against an accepted M05/M06
  baseline.

## Implementation Plan

1. Run video inventory and record permission state, device unique ID, transport,
   format, frame-rate options, and external capture candidacy.
2. Request camera permission only when a live probe is intentionally run.
3. Add the smallest AVFoundation frame source that reports frame timestamps,
   frame age, drops, queue depth, pixel format, and CPU load.
4. Run audio-only baseline first, then audio-on/video-on capture.
5. PASS only if audio callback p99/max, playout target, underruns, and route
   verdict are unchanged.
6. Keep vendor SDKs optional and outside this generic AVFoundation baseline.

## Acceptance Tests

- `video-capture-inventory` reports concrete device or permission state.
- `video-capture-run --device-id <id|auto> --duration-seconds <n> --output
  <path>` creates an AVFoundation video-only PARTIAL report when permission and
  frames are available.
- `validate-video-capture-report` accepts measured or video-only PARTIAL
  reports.
- PASS requires AVFoundation source, device unique ID, audio-impact metrics, and
  no audio p99/max or playout target increase.

## Blockers / TODO(human)

- TODO(human): [M08 camera probe] -> Choose the first physical capture source -> [built-in/Continuity camera unavailable state / UVC capture device / Blackmagic or ATEM USB webcam]
- Requires camera permission or an explicit denied/unavailable report.

## Verification Commands

```bash
swift run open-lola video-capture-inventory --output mac-port/reports/<inventory>.json
swift run open-lola validate-video-capture-inventory mac-port/reports/<inventory>.json
swift run open-lola video-capture-run --device-id auto --duration-seconds 2 --output mac-port/reports/<capture-report>.json
swift run open-lola validate-video-capture-report <capture-report.json>
swift test --filter VideoCapture
```

## Resume here

Start with inventory and permission state, then run `video-capture-run` on the
chosen physical source. Do not mark G07/M08 PASS until audio-on/video-on
measurement proves unchanged audio timing.

VERDICT: PARTIAL
