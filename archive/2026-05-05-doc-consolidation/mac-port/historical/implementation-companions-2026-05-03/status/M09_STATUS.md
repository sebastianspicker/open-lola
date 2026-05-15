# M09 Status

## Current status

- Status: Partial.
- Verdict: PARTIAL 2026-05-03.
- Canonical milestone: [M09 Native Video Transport](../milestones/M09_NATIVE_VIDEO_TRANSPORT.md)
- Validation report: [M09 Video Transport Validation Report](../reports/M09_VIDEO_TRANSPORT_2026-05-02.md)

Canonical objective:

Add native best-effort video transport probes and prove raw, intra-frame, or
VideoToolbox video degrades before audio.

Canonical assumptions:

- M08 provides timestamped frames.
- Audio metrics baseline is active during transport tests.
- Reliable video retransmission protocols are out of fastest-mode scope.

Canonical dependencies:

- M08 camera/test-pattern source.
- M05 route metrics.
- M06 audio/drift metrics where available.
- VideoToolbox framework for encoder probes.

## Completed work

- Added `RawVideoFrameTransport` for deterministic raw frame packetization from
  M08 `CapturedVideoFrame` values.
- Added `LatestVideoFrameReceiver` for latest-frame receiver retention and drop
  accounting.
- Added `VideoTransportReport` schema and validation for transport mode,
  receiver accounting, frame age, audio-impact metrics, VideoToolbox policy
  fields, and degradation policy.
- Added `VideoTransportRouteEvidence` schema for physical route kind, route
  label, packet-capture point, raw/intra-frame baseline report ID, baseline
  mode, baseline route verdict, and video-active route verdict.
- Added PASS guards that reject reliable retransmission, missing pre-audio
  degradation, missing degradation-before-route-impact proof, non-physical
  route evidence, non-PASS baseline route verdict, route verdict changes,
  VideoToolbox without raw/intra-frame baseline evidence, VideoToolbox frame
  reordering, missing VideoToolbox realtime mode, encoder queue depth above one
  for VideoToolbox, increased audio p99/max, playout-target changes, underruns,
  and hidden audio impact.
- Added a synthetic PARTIAL video transport report fixture.
- Added CLI validation with `open-lola validate-video-transport-report <path>`.
- Added CLI smoke output with `open-lola video-transport-synthetic-smoke`.
- Added `VideoTransportRunConfiguration` and `VideoTransportRunner` for
  bounded raw test-pattern `video-transport-run` reports with frame/drop
  accounting, route kind, packet-capture point, and latest-frame receiver
  metrics.
- Added CLI report writing with `open-lola video-transport-run --mode raw
  --peer <ip> --port <port> --duration-seconds <n> --output <path>`.
- Added [../reports/M09_VIDEO_TRANSPORT_2026-05-02.md](../reports/M09_VIDEO_TRANSPORT_2026-05-02.md).

## Verified work

- Red test run failed before implementation because M09 video transport types
  did not exist.
- `swift test --filter VideoTransportReportTests` passed with 14 tests after
  physical-route PASS gate implementation.
- `swift test` passed with 154 tests after the physical-route gate update.
- `swift build` passed.
- The synthetic PARTIAL video transport fixture passed CLI validation.
- The synthetic smoke command emits a PARTIAL report.
- Red G09 test-first run failed on missing `VideoTransportRunConfiguration`,
  `VideoTransportRunConfigurationError`, and `VideoTransportRunner`.
- `swift test --filter VideoTransportReportTests` passed with 17 focused tests
  after adding the raw `video-transport-run` surface.
- `swift test` passed with 256 tests after adding the raw runner.
- `swift build` passed after rerunning outside the SwiftPM sandbox failure.
- The raw `video-transport-run` CLI wrote a PARTIAL report and the video
  transport validator accepted it.
- Documentation verification passed.
- Shellcheck passed for the docs verifier script.

## Partially completed work

- Source validation exists for raw frame packetization, latest-frame receiver
  accounting, transport report validation, degradation policy gates, and
  VideoToolbox measurement-policy gates.
- `video-transport-run --mode raw` can write a bounded PARTIAL test-pattern
  route report, but it is not a physical route PASS proof by itself.
- PASS validation now requires physical route evidence and raw/intra-frame route
  evidence before any VideoToolbox PASS can be accepted.
- PASS-level runtime evidence is not complete because no real video route,
  VideoToolbox runtime probe, or audio-plus-video stress run has been recorded.

## Deferred work

- Run raw or simple intra-frame transport on a physical route first.
- Add VideoToolbox runtime probing only after physical raw/intra-frame route
  evidence exists and validates.
- Measure VideoToolbox realtime mode, frame reordering, queue depth, and CPU/GPU
  contention.
- Keep JPEG XS, RIST, and SRT deferred until explicit latency and
  audio-isolation reports justify them.
- Run audio-plus-video stress using an M05/M06 baseline route.

## Open tasks

Canonical progress checklist:

- [x] Add raw/intra-frame transport probe.
- [x] Add receiver report path.
- [x] Add physical route evidence and PASS gate.
- [ ] Add VideoToolbox probe.
- [x] Add degradation policy tests.
- [ ] Run audio-plus-video stress.
- [x] Record verdict.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

SOTA 2026 routing:

- Rows: SOTA039, SOTA040, SOTA041, SOTA042, SOTA043, SOTA044, SOTA048,
  SOTA082, SOTA083, SOTA084 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: raw/intra-frame video is the local baseline; VideoToolbox, JPEG
  XS, RIST, and SRT require explicit latency and audio-isolation reports.

Faster-than-LoLa companion implementation plan:

- [x] Add the first raw video transport report runner. The CLI surface is
  `open-lola video-transport-run --mode raw
  --peer <ip> --port <port> --duration-seconds <n> --output <path>`.
- [ ] Use raw or simple intra-frame transport as the first physical route
  baseline. Record packetization overhead, sender drops, receiver latest-frame
  retention, frame age p50/p95/p99/max, and network load.
- [ ] Run the first video transport probe on the same direct wired route used by
  M05 where possible. Record audio metrics while video is active.
- [x] Make PASS validation reject VideoToolbox reports unless a physical
  raw/intra-frame baseline report ID and baseline mode are present.
- [ ] Add VideoToolbox runtime probing only after raw route evidence exists. The
  probe must record hardware availability, realtime mode, queue depth, frame
  reordering, GOP policy, CPU/GPU load, and audio-impact metrics.
- [ ] Keep JPEG XS, RIST, SRT, and reliable retransmission modes deferred until
  a specific bandwidth-limited requirement exists.
- [x] PASS requires degradation before audio or route impact: drop/skip/reduce
  video before audio callback p99/max, underruns, route verdict, or playout
  target worsens.

## Known blockers

- VideoToolbox behavior may depend on hardware encoder availability.
- Raw video may exceed network bandwidth except on controlled local paths.
- M08 real capture and M05/M06 physical audio-route evidence are still needed
  before a meaningful audio-plus-video stress result can close.

## Test coverage status

Canonical test plan:

Before: no frame transport tests exist.

After:

- frame transport fixture tests pass;
- raw/intra-frame probe report validates;
- VideoToolbox probe report validates or records unavailable status;
- audio metrics remain unchanged under video transport load.

Coverage state: source-level M09 coverage exists for raw packet generation,
latest-frame receiver drop accounting, raw runner configuration parsing, raw
runner report building, report JSON round trip, fixture validation, PASS
rejection rules, degradation policy, physical-route evidence gates,
VideoToolbox raw-baseline gating, route-verdict comparison, VideoToolbox policy
gates, and synthetic smoke output. Runtime VideoToolbox, real M08 camera source
transport, physical packet capture, and audio-active route coverage are still
missing.

## Relevant files touched

- [../../Sources/OpenLolaCore/VideoTransportProbe.swift](../../Sources/OpenLolaCore/VideoTransportProbe.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/VideoTransportReportTests.swift](../../Tests/OpenLolaCoreTests/VideoTransportReportTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/VideoTransportReports/valid/video-transport-partial.json](../../Tests/OpenLolaCoreTests/Fixtures/VideoTransportReports/valid/video-transport-partial.json)
- [../reports/M09_VIDEO_TRANSPORT_2026-05-02.md](../reports/M09_VIDEO_TRANSPORT_2026-05-02.md)
- [../milestones/M09_NATIVE_VIDEO_TRANSPORT.md](../milestones/M09_NATIVE_VIDEO_TRANSPORT.md)
- [../PROGRESS.md](../PROGRESS.md)
- [../STATUS_INDEX.md](../STATUS_INDEX.md)
- [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md)
- [../MILESTONE_INDEX.md](../MILESTONE_INDEX.md)
- [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md)
- [../RISK_REGISTER.md](../RISK_REGISTER.md)
- [../../MAC_PORT_PLAN.md](../../MAC_PORT_PLAN.md)

## Latest verification

Commands:

```bash
swift test --filter VideoTransportReportTests
swift test
swift build
.build/debug/open-lola validate-video-transport-report Tests/OpenLolaCoreTests/Fixtures/VideoTransportReports/valid/video-transport-partial.json
.build/debug/open-lola video-transport-synthetic-smoke
.build/debug/open-lola video-transport-run --mode raw --peer 127.0.0.1 --port 5004 --duration-seconds 1 --width 320 --height 240 --frame-rate 10 --queue-depth 1 --route-kind localhost --packet-capture-point local-loopback --output /private/tmp/open-lola-m09-video-transport-run.json
.build/debug/open-lola validate-video-transport-report /private/tmp/open-lola-m09-video-transport-run.json
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

Result:

- Swift tests and build pass; latest full suite: 256 tests.
- CLI fixture validation, synthetic smoke, raw runner report writing, and raw
  runner validation pass.
- Documentation verification and shellcheck pass.
- 2026-05-02: physical-route PASS gate update passed
  `swift test --filter VideoTransportReportTests` with 14 focused tests.
- 2026-05-02: physical-route PASS gate update passed `swift test` with 154
  tests.
- 2026-05-03: raw `video-transport-run` implementation passed
  `swift test --filter VideoTransportReportTests` with 17 focused tests.
- 2026-05-03: raw `video-transport-run` implementation passed `swift test`
  with 256 tests.
- Latest local raw runner output: `framesSent: 10`, `displayedFrames: 1`,
  `droppedFrames: 9`, `routeKind: localhost`,
  `packetCapturePoint: local-loopback`, `verdict: partial`.
- 2026-05-02: faster-than-LoLa companion plan update passed
  `bash scripts/verify-docs.sh` and `shellcheck scripts/*.sh`.
- VERDICT: PARTIAL

## Next recommended steps

Run `video-transport-run --mode raw` on a physical direct route and record
packet-capture point, baseline route verdict, video-active route verdict, frame
age, receiver drops, network load, and audio metrics with the video lane
active. Do not add the VideoToolbox runtime probe until that raw/intra-frame
route report exists.

## Resume here

Start from `VideoTransportRunConfiguration`, `VideoTransportRunner`, and the
existing `VideoTransportRouteEvidence` contract. Run the first physical
raw/intra-frame route report, validate it with `open-lola
validate-video-transport-report <path>`, then add VideoToolbox only after raw
route evidence exists and audio timing plus route verdict remain unchanged.
