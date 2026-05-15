# M08 Video Capture Validation Report

Date: 2026-05-02  
Updated: 2026-05-03  
Milestone: [M08 Blackmagic/ATEM Video Capture Probe](../milestones/M08_GENERIC_VIDEO_CAPTURE_PROBE.md)  
Status: PARTIAL

## Scope

This report validates the M08 source-level video capture harness: vendor-neutral
camera source boundary, deterministic test-pattern source, latest-frame queue,
video capture report schema, AVFoundation sample-buffer source, Blackmagic-first
auto selection, video-only run CLI, measured audio-impact report inputs,
production-capture PASS guards, fixture validation, and synthetic smoke output.
It does not validate target Blackmagic/ATEM camera activity while live audio is
running.

2026-05-03 policy update: the production capture priority is now
Blackmagic/ATEM first. AVFoundation remains the generic harness and fallback
for macOS-exposed Blackmagic/ATEM/UVC capture paths; Desktop Video SDK stays
optional until measured need.

## Video Capture Contract

The report records:

- source kind, label, permission status, and device identifier when available;
- production capture evidence for ATEM, DeckLink, UltraStudio, or Blackmagic
  capture hardware when a report claims PASS;
- capture format width, height, nominal frame rate, and pixel format;
- latest-frame queue policy, configured depth, observed depth, and dropped
  frames;
- captured and retained frame counts;
- frame age p50/p95/p99/max;
- frame interval p50/p95/p99/max when captured timestamps exist;
- baseline and video-on audio callback p99/max, playout target, underruns, and
  hidden audio-impact flag;
- optional process CPU user/system deltas for live video-only runs;
- optional process resident memory peak for live video-only runs;
- PASS, FAIL, or PARTIAL verdict.

PASS reports require an authorized AVFoundation source, concrete
Blackmagic/ATEM production capture evidence, matching AVFoundation device ID,
process CPU and memory metrics, stable frame accounting, unchanged audio
callback p99/max, unchanged playout target, zero underruns, no hidden audio
impact, and no speculative Desktop Video SDK requirement.

## Commands

```bash
swift test --filter VideoCaptureReportTests
swift test
swift build
.build/debug/open-lola validate-video-capture-report Tests/OpenLolaCoreTests/Fixtures/VideoCaptureReports/valid/video-capture-partial.json
.build/debug/open-lola video-capture-synthetic-smoke
.build/debug/open-lola video-capture-inventory --output /private/tmp/open-lola-m08-video-capture-inventory.json
.build/debug/open-lola validate-video-capture-inventory /private/tmp/open-lola-m08-video-capture-inventory.json
.build/debug/open-lola video-capture-run --device-id auto --duration-seconds 1 --output /private/tmp/open-lola-m08-video-capture-run.json
.build/debug/open-lola video-capture-run --device-id <id|auto> --duration-seconds <n> --queue-depth 1 --frame-rate 60 --baseline-callback-p99-us <us> --video-callback-p99-us <us> --baseline-callback-max-us <us> --video-callback-max-us <us> --baseline-playout-target-frames <n> --video-playout-target-frames <n> --audio-underruns <n> --hidden-audio-impact false --production-hardware atem --production-model <model> --production-manufacturer "Blackmagic Design" --production-connection usb-uvc --desktop-video-sdk-status not-linked --desktop-video-sdk-notes <notes> --verdict partial --output <path>
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Results

- Red test run before implementation failed on missing M08 video capture types.
- Red G07 test-first run failed on missing `VideoCaptureRunConfiguration`,
  `AVFoundationCameraSourceSnapshot`, `AVFoundationVideoCaptureRunner`, and
  process CPU metrics.
- `swift test --filter VideoCapture` passed with 15 video-capture-related
  tests after adding the AVFoundation source and run report builder.
- `swift test --filter VideoCaptureReportTests` passed with 26
  video-capture-related tests after adding real capture metrics, Blackmagic
  preference, measured audio-impact inputs, and process-memory PASS gates.
- `swift build` passed after rerunning outside the SwiftPM sandbox failure.
- `swift test` passed with 436 tests.
- The synthetic PARTIAL video capture fixture passed CLI validation.
- The synthetic smoke command emitted a PARTIAL report with frame-interval
  metrics.
- The live run CLI is intentionally PARTIAL and depends on camera permission;
  permission-denied or unavailable states remain environment blockers, not PASS
  evidence.
- The latest local inventory on 2026-05-03 at 19:30:44Z reported
  `permissionStatus: denied`,
  `devices: []`, and `blackmagicSdkStatus: notLinkedOptionalBoundary`; the
  inventory report validated successfully.
- The latest local live run failed with
  `cameraNotAuthorized(OpenLolaCore.AVFoundationPermissionStatus.denied)`.
- Documentation verification passed.
- Shellcheck passed for the docs verifier script.
- The 2026-05-03 F05 tightening rejects PASS for generic cameras, missing
  production capture evidence, mismatched AVFoundation device IDs, required
  Desktop Video SDK status, missing process CPU metrics, missing process memory
  metrics, and placeholder production evidence.
- `video-capture-run` now collects real AVFoundation sample buffers into the
  latest-frame queue instead of synthesizing a one-frame active-format report.
- `video-capture-run --frame-rate` now attempts to apply the requested frame
  duration when the active AVFoundation format supports it; actual intervals
  are still measured from callbacks.

## Deferred Runtime Evidence

M08 cannot be marked PASS until real reports exist for:

- AVFoundation camera discovery and permission handling;
- concrete Blackmagic/ATEM, DeckLink, UltraStudio, or Blackmagic capture
  hardware identity;
- capture callback timing and frame-drop policy;
- audio-off/video-on probe;
- audio-on/video-on probe using an M05/M06 baseline route;
- unchanged audio callback p99/max, playout target, and underrun count while
  video is active;
- device-specific camera or capture-card latency notes.

## Verdict

M08 source validation now includes the AVFoundation sample-buffer source,
video-only run CLI, requested frame-rate configuration, measured audio-impact
inputs, frame interval, process CPU and memory metrics, Blackmagic-first source
selection, and F05
production-capture PASS gates, but target hardware inventory and
audio-on/video-on impact certification remain open.

VERDICT: PARTIAL

## Resume here

Run `open-lola video-capture-inventory` with the target Blackmagic/ATEM source
attached, then run `open-lola video-capture-run --device-id <id|auto>
--duration-seconds <n> --output <path>` with measured audio-impact and
production-evidence arguments. Validate the report with `open-lola
validate-video-capture-report <path>`. Mark PASS only after that report proves
concrete Blackmagic/ATEM hardware identity and unchanged audio timing.
