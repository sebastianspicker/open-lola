# M08 Status

## Current status

- Status: Partial.
- Verdict: PARTIAL 2026-05-02.
- Canonical milestone: [M08 Generic Video Capture Probe](../milestones/M08_GENERIC_VIDEO_CAPTURE_PROBE.md)
- Validation report: [M08 Video Capture Validation Report](../reports/M08_VIDEO_CAPTURE_2026-05-02.md)

Canonical objective:

Add a vendor-neutral video capture probe using AVFoundation and test-pattern
sources, with frame age and drop-count reporting that proves no audio impact.

Canonical assumptions:

- AVFoundation is the first real camera adapter.
- Test-pattern source exists for deterministic tests.
- Video capture runs outside audio callback resources.

Canonical dependencies:

- M03 fastest endpoint mode.
- M05 or M06 audio metrics baseline.
- macOS camera permissions for real devices.

## Completed work

- Added `CameraSource` as the vendor-neutral video source boundary.
- Added `TestPatternCameraSource` for deterministic timestamped frames without
  camera hardware.
- Added `LatestFrameQueue` with bounded latest-useful-frame retention and drop
  accounting.
- Added `VideoCaptureReport` schema and validation for source metadata, format,
  queue depth, frame age, frame accounting, and audio-impact metrics.
- Added PASS guards that reject AVFoundation-free reports, missing camera
  authorization, missing device UID, increased audio p99/max, playout-target
  changes, underruns, and hidden audio impact.
- Added `AVFoundationVideoDeviceInventoryReport` and
  `AVFoundationVideoDeviceInventoryReader` for read-only AVFoundation
  enumeration.
- Added `AVFoundationCameraSource` behind the existing `CameraSource`
  boundary, using `AVCaptureVideoDataOutput`, explicit active-format selection,
  fixed min/max frame duration, late-frame discard, and latest-frame queue
  retention.
- Added `AVFoundationVideoCaptureRunner` and `video-capture-run --device-id
  <id|auto> --duration-seconds <n> [--queue-depth <n>] [--frame-rate <hz>]
  --output <path>` for video-only PARTIAL capture reports.
- Added optional process CPU user/system deltas to `VideoCaptureReport`.
- The AVFoundation inventory records permission state, device label, device
  UID, model ID, manufacturer, transport, source policy, width/height, maximum
  FPS, and pixel format for each enumerated format.
- Added explicit `avFoundationFirst` source policy for ATEM USB webcam output,
  UVC devices, Blackmagic/DeckLink/UltraStudio names, and generic capture-card
  names when they appear as AVFoundation devices.
- Added `notLinkedOptionalBoundary` Blackmagic SDK status; generic Swift builds
  link Apple AVFoundation/CoreMedia only and do not import Blackmagic headers.
- Added a synthetic PARTIAL video capture report fixture.
- Added CLI validation with `open-lola validate-video-capture-report <path>`.
- Added CLI inventory output with `open-lola video-capture-inventory` and
  `open-lola video-capture-inventory --output <path>`.
- Added CLI inventory validation with
  `open-lola validate-video-capture-inventory <path>`.
- Added CLI live video-only capture output with `open-lola video-capture-run
  --device-id <id|auto> --duration-seconds <n> --output <path>`.
- Added CLI smoke output with `open-lola video-capture-synthetic-smoke`.
- Added [../reports/M08_VIDEO_CAPTURE_2026-05-02.md](../reports/M08_VIDEO_CAPTURE_2026-05-02.md).

## Verified work

- Red test run failed before implementation because M08 video capture types did
  not exist.
- `swift test --filter VideoCaptureReportTests` passed with 11 tests after
  AVFoundation inventory implementation.
- `swift test` passed with 149 tests after AVFoundation inventory implementation.
- `swift build` passed.
- Red G07 test-first run failed on missing `VideoCaptureRunConfiguration`,
  `AVFoundationCameraSourceSnapshot`, `AVFoundationVideoCaptureRunner`, and
  process CPU metrics.
- `swift test --filter VideoCapture` passed with 15 video-capture-related tests
  after adding the AVFoundation source and run report builder.
- The fixture validator accepted
  [../../Tests/OpenLolaCoreTests/Fixtures/VideoCaptureReports/valid/video-capture-partial.json](../../Tests/OpenLolaCoreTests/Fixtures/VideoCaptureReports/valid/video-capture-partial.json).
- The synthetic smoke command emitted a PARTIAL report.
- The local `open-lola video-capture-inventory --output
  /private/tmp/open-lola-m08-video-capture-inventory.json` run emitted
  `permissionStatus: denied`, `devices: []`, and
  `blackmagicSdkStatus: notLinkedOptionalBoundary`; this is concrete PARTIAL
  evidence, not AVFoundation capture PASS evidence.
- The local `open-lola video-capture-run --device-id auto --duration-seconds 1
  --output /private/tmp/open-lola-m08-video-capture-run.json` probe failed with
  `cameraNotAuthorized(OpenLolaCore.AVFoundationPermissionStatus.denied)`,
  confirming the live runner is wired but blocked by local camera permission.

## Partially completed work

- Source validation exists for the generic video capture boundary, deterministic
  source, latest-frame queue, report validation, AVFoundation inventory
  metadata, AVFoundation sample-buffer source, video-only capture runner, and
  optional Blackmagic SDK boundary.
- PASS-level runtime evidence is not complete because no real AVFoundation
  audio-on/video-on probe has been recorded.

## Deferred work

- Run macOS camera permission and device discovery probes on the target Mac and
  archive their JSON output.
- Run `video-capture-run` on the chosen physical camera or capture source and
  validate the video-only PARTIAL report.
- Run audio-off/video-on and audio-on/video-on measurements.
- Add file-pattern capture if needed before any vendor-specific camera adapter.
- Record device-specific capture-card latency if external capture hardware is
  used.

## Open tasks

Canonical progress checklist:

- [x] Define `CameraSource`.
- [x] Add test-pattern source.
- [x] Add AVFoundation inventory and permission probe.
- [x] Add AVFoundation source.
- [x] Add report fixture.
- [ ] Run audio-off/video-on probe.
- [ ] Run audio-on/video-on probe.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

SOTA 2026 routing:

- Rows: Q007, SOTA046, SOTA047 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: AVFoundation, file-pattern, and synthetic test-pattern capture
  precede any vendor adapter.

Faster-than-LoLa companion implementation plan:

- [x] Add a read-only AVFoundation inventory probe that records permission
  state, device UID, source policy, format dimensions, FPS, and pixel format.
- [x] Add `AVFoundationCameraSource` behind the existing `CameraSource`
  boundary. Keep `TestPatternCameraSource` unchanged for deterministic tests.
- [x] Add a CLI probe such as `open-lola video-capture-run --device-id <id>|auto
  --duration-seconds <n> --output <path>` that records discovery, permission
  state, device unique ID, active format, frame duration, pixel format, frame
  age, drop counts, and CPU load.
- [x] Configure AVFoundation explicitly: choose `activeFormat`, set min/max
  frame duration, use `AVCaptureVideoDataOutput`, set
  `alwaysDiscardsLateVideoFrames`, and avoid conversion-heavy BGRA defaults
  unless measurement justifies them.
- [x] Treat ATEM USB webcam output, UVC capture devices, and capture cards as
  AVFoundation sources first. Put Blackmagic Desktop Video/DeckLink support
  behind optional runtime/build boundaries only if AVFoundation cannot expose
  the needed source.
- [x] Keep default `swift build` and `swift test` independent of the Blackmagic
  SDK; the only current SDK status is `notLinkedOptionalBoundary`.
- [ ] Run audio-off/video-on first, then audio-on/video-on against the accepted
  M05/M06 audio baseline. PASS requires unchanged audio callback p99/max,
  underruns, and playout target.
- [x] Record unavailable or permission-denied states as concrete PARTIAL
  evidence; do not fail generic builds when no camera is attached.

## Known blockers

- Real camera hardware and macOS permissions may be unavailable.
- Capture-card latency may differ from built-in camera behavior.
- M05/M06 physical baseline evidence is still needed before a meaningful
  audio-impact video probe can close.
- Local camera permission may block `video-capture-run`; a denied/unavailable
  result remains concrete PARTIAL evidence until permission and hardware are
  intentionally provided.

## Test coverage status

Canonical test plan:

Before: no camera abstraction exists.

After:

- test-pattern source tests pass;
- AVFoundation probe runs on available camera or reports permission gap;
- frame age/drop report validates;
- audio metrics remain unchanged within accepted baseline.

Coverage state: source-level M08 coverage exists for deterministic frames,
latest-frame queue drop accounting, report JSON round trip, fixture validation,
PASS rejection rules, AVFoundation inventory JSON round trip, external
capture-device AVFoundation-first classification, `video-capture-run`
configuration parsing, AVFoundation capture snapshot report building, process
CPU metrics validation, and synthetic smoke output. Audio-on/video-on runtime
coverage is still missing.

## Relevant files touched

- [../../Package.swift](../../Package.swift)
- [../../Sources/OpenLolaCore/VideoCaptureProbe.swift](../../Sources/OpenLolaCore/VideoCaptureProbe.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift](../../Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/VideoCaptureReports/valid/video-capture-partial.json](../../Tests/OpenLolaCoreTests/Fixtures/VideoCaptureReports/valid/video-capture-partial.json)
- [../reports/M08_VIDEO_CAPTURE_2026-05-02.md](../reports/M08_VIDEO_CAPTURE_2026-05-02.md)
- [../milestones/M08_GENERIC_VIDEO_CAPTURE_PROBE.md](../milestones/M08_GENERIC_VIDEO_CAPTURE_PROBE.md)
- [../PROGRESS.md](../PROGRESS.md)
- [../STATUS_INDEX.md](../STATUS_INDEX.md)
- [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md)
- [../MILESTONE_INDEX.md](../MILESTONE_INDEX.md)
- [../../MAC_PORT_PLAN.md](../../MAC_PORT_PLAN.md)

## Latest verification

Commands:

```bash
swift test --filter VideoCaptureReportTests
swift test
swift build
.build/debug/open-lola validate-video-capture-report Tests/OpenLolaCoreTests/Fixtures/VideoCaptureReports/valid/video-capture-partial.json
.build/debug/open-lola video-capture-synthetic-smoke
.build/debug/open-lola video-capture-inventory --output /private/tmp/open-lola-m08-video-capture-inventory.json
.build/debug/open-lola validate-video-capture-inventory /private/tmp/open-lola-m08-video-capture-inventory.json
.build/debug/open-lola video-capture-run --device-id auto --duration-seconds 1 --output /private/tmp/open-lola-m08-video-capture-run.json
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

Result:

- Swift tests and build pass.
- CLI fixture validation, synthetic smoke, AVFoundation inventory output, and
  AVFoundation inventory validation pass.
- Latest local inventory result: `permissionStatus: denied`, `devices: []`,
  `blackmagicSdkStatus: notLinkedOptionalBoundary`.
- Latest local live run result:
  `cameraNotAuthorized(OpenLolaCore.AVFoundationPermissionStatus.denied)`.
- Documentation verification and shellcheck pass.
- 2026-05-02: faster-than-LoLa companion plan update passed
  `bash scripts/verify-docs.sh` and `shellcheck scripts/*.sh`.
- 2026-05-02: AVFoundation inventory implementation passed
  `swift test --filter VideoCaptureReportTests` with 11 focused tests.
- 2026-05-02: G07 AVFoundation source implementation passed
  `swift test --filter VideoCapture` with 15 video-capture-related tests.
- 2026-05-02: `swift build` passed after the SwiftPM manifest sandbox failure
  was rerun outside the sandbox.
- 2026-05-02: `swift test` passed with 249 tests after the SwiftPM manifest
  sandbox failure was rerun outside the sandbox.
- 2026-05-02: `.build/debug/open-lola validate-video-capture-report
  Tests/OpenLolaCoreTests/Fixtures/VideoCaptureReports/valid/video-capture-partial.json`
  passed and emitted `VERDICT: PARTIAL`.
- 2026-05-02: `.build/debug/open-lola video-capture-synthetic-smoke` passed
  and emitted `VERDICT: PARTIAL`.
- 2026-05-02: `.build/debug/open-lola video-capture-inventory --output
  /private/tmp/open-lola-m08-video-capture-inventory.json` passed and emitted
  `VERDICT: PARTIAL`.
- 2026-05-02: `.build/debug/open-lola validate-video-capture-inventory
  /private/tmp/open-lola-m08-video-capture-inventory.json` passed and emitted
  `VERDICT: PARTIAL`.
- 2026-05-02: `.build/debug/open-lola video-capture-run --device-id auto
  --duration-seconds 1 --output /private/tmp/open-lola-m08-video-capture-run.json`
  failed with
  `cameraNotAuthorized(OpenLolaCore.AVFoundationPermissionStatus.denied)`;
  this is the expected local permission blocker, not a source validation
  failure.
- 2026-05-02: `bash scripts/verify-docs.sh` passed after G07 documentation
  updates.
- 2026-05-02: `shellcheck scripts/*.sh` passed after G07 documentation
  updates.
- VERDICT: PARTIAL

## Next recommended steps

Run `open-lola video-capture-inventory` on the target Mac with the intended
ATEM/UVC/capture-card attached, archive the JSON output, then run
`open-lola video-capture-run --device-id <id|auto> --duration-seconds <n>
--output <path>` and validate the resulting report. Use that report as the
video-only input before the audio-on/video-on comparison.

## Resume here

Start by running `video-capture-run` on the chosen AVFoundation source and
validating the generated PARTIAL report with
`open-lola validate-video-capture-report <path>`. Keep M08 PARTIAL until the
audio-on/video-on probe proves unchanged audio timing.
