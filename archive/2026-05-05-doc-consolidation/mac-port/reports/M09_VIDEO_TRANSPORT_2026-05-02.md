# M09 Video Transport Validation Report

Date: 2026-05-02  
Updated: 2026-05-03  
Milestone: [M09 Native Video Transport](../milestones/M09_NATIVE_VIDEO_TRANSPORT.md)  
Status: PARTIAL

## Scope

This report validates the M09 source-level video transport harness: raw
test-pattern frame packetization, encoded bounded video fragments,
out-of-order reassembly, incomplete-frame stale-drop behavior, latest-frame
receiver accounting, video transport report schema, degradation PASS guards,
VideoToolbox policy gates, fixture validation, synthetic smoke output, and the
raw `video-transport-run` report writer. It does not validate a real network
video route, VideoToolbox encoder runtime behavior, JPEG XS, RIST/SRT, or video
transport while live audio is running.

## Video Transport Contract

The report records:

- source kind, label, permission status, and device identifier when available;
- capture format width, height, nominal frame rate, and pixel format;
- transport mode, network protocol, payload format, reliable retransmission
  flag, max packet size, encoder queue depth, VideoToolbox availability,
  realtime setting, and frame reordering setting;
- frames and packets sent, dropped before send, and dropped in transport;
- fragmentation and reassembly metrics, including fragment counts, maximum
  fragments per frame, bounded payload size, missing fragments, late fragments,
  and incomplete frame drops;
- receiver queue policy, received/displayed/dropped/late frames, and observed
  queue depth;
- frame age p50/p95/p99/max;
- baseline and video-transport-on audio callback p99/max, playout target,
  underruns, and hidden audio-impact flag;
- degradation actions and whether degradation triggers before audio target
  changes;
- PASS, FAIL, or PARTIAL verdict.

PASS reports reject missing fragmentation/reassembly metrics, oversized
fragment payloads, incomplete reassembly, reliable retransmission, missing
pre-audio degradation, VideoToolbox frame reordering, missing VideoToolbox
realtime mode for VideoToolbox reports, encoder queue depth above one for
VideoToolbox reports, increased audio callback p99/max, playout-target changes,
underruns, and hidden audio impact.

## Commands

```bash
swift test --filter VideoTransportReportTests
swift test
swift build
.build/debug/open-lola validate-video-transport-report Tests/OpenLolaCoreTests/Fixtures/VideoTransportReports/valid/video-transport-partial.json
.build/debug/open-lola video-transport-synthetic-smoke
.build/debug/open-lola video-transport-run --mode raw --peer 127.0.0.1 --port 5004 --duration-seconds 1 --width 320 --height 240 --frame-rate 10 --queue-depth 1 --max-packet-bytes 1200 --route-kind localhost --packet-capture-point local-loopback --output /private/tmp/open-lola-m09-video-transport-run.json
.build/debug/open-lola validate-video-transport-report /private/tmp/open-lola-m09-video-transport-run.json
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Results

- Red test run before implementation failed on missing M09 video transport
  types.
- Red G09 test-first run failed on missing `VideoTransportRunConfiguration`,
  `VideoTransportRunConfigurationError`, and `VideoTransportRunner`.
- `swift test --filter VideoTransport` passed with 31 selected tests after
  adding encoded fragment, reassembly, stale-drop, malformed-fragment, and
  audio-impact guard coverage.
- `swift test` passed with 325 tests.
- `swift build` passed after rerunning outside the SwiftPM sandbox failure.
- The synthetic PARTIAL video transport fixture passed CLI validation.
- The synthetic smoke command emitted a PARTIAL report.
- The raw `video-transport-run` command wrote
  `/private/tmp/open-lola-m09-video-transport-run.json` with `framesSent: 10`,
  `displayedFrames: 1`, `droppedFrames: 9`, route kind `localhost`, and
  `packetCapturePoint: local-loopback`. The updated runner also records bounded
  fragment and reassembly metrics through the encoded-fragment path; the local
  1,200-byte packet run records `fragmentsSent: 2040`,
  `maxFragmentsPerFrame: 204`, `maxPayloadBytesPerFragment: 1130`, and
  `framesReassembled: 10`.
- The raw runner report passed `validate-video-transport-report` with
  `VERDICT: PARTIAL`.
- Documentation verification passed.
- Shellcheck passed for the docs verifier script.

## Deferred Runtime Evidence

M09 cannot be marked PASS until real reports exist for:

- an M08 measured camera or file-pattern source;
- a physical direct or isolated video route;
- raw or simple intra-frame frame age/drop measurements on that route;
- bounded fragmentation/reassembly evidence on that route;
- VideoToolbox availability, realtime mode, frame reordering, queue depth, and
  CPU/GPU contention if VideoToolbox is evaluated;
- audio-plus-video stress using an M05/M06 baseline;
- proof that video drops, degrades, or turns off before audio playout target
  changes.

## Verdict

M09 source validation now includes the bounded raw runner, encoded fragment
path, latest useful-frame reassembly, stale-drop behavior, and
fragmentation/reassembly PASS gates, but real physical video transport and
audio-isolation certification remain open.

VERDICT: PARTIAL

## Resume here

Use `open-lola video-transport-run --mode raw ... --output <path>` and
`open-lola validate-video-transport-report <path>` for the first measured raw
or intra-frame route report. Confirm fragment payload bounds and complete
reassembly on the physical route. Add VideoToolbox runtime code only after the
raw report path has physical route data, and keep M09 PARTIAL until the
audio-plus-video report proves unchanged audio timing.
