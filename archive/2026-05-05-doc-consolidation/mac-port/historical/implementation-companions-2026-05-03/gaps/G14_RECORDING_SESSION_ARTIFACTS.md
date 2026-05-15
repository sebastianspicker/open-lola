# G14 Recording Session Artifacts

## LoLa Comparison

LoLa includes audio/video recording helpers. The Mac path can add recording
only as a side lane: disk pressure may drop recording data, but it must never
delay live audio/video deadlines.

## Current Repo State

- Related milestone: [../milestones/M14_RECORDING_SESSION_ARTIFACTS.md](../milestones/M14_RECORDING_SESSION_ARTIFACTS.md)
- Live status: [../status/M14_STATUS.md](../status/M14_STATUS.md)
- Existing source validates recording/session reports, side-lane policy,
  simulated slow-writer drops/gaps, and synthetic smoke.
- Existing source also has `recording-session-run`, a bounded artifact-writer
  handoff that reads an integrated baseline, writes session metadata,
  placeholder copied-media artifacts, gap markers, metrics, and a PARTIAL M14
  report without putting file I/O in realtime paths.
- Missing piece: real media recording writer, disk-pressure run, and
  recording-off comparison.

## Implementation Plan

1. Define recording artifact layout: report JSON, audio files, video files,
   dropped/gap markers, runtime config snapshot, and checksum/index.
2. Implement writer queues outside realtime callbacks with bounded memory and
   explicit drop-on-pressure policy.
3. Run recording-off baseline, then recording-on run with the accepted G10
   integrated workload.
4. Add disk-pressure stress that proves recording drops or gaps data instead of
   increasing media playout target or callback p99/max.
5. Validate report and artifact index after the writer is stopped.

## Acceptance Tests

- `validate-recording-session-report` accepts measured report.
- PASS requires configuration metadata, gap markers for drops,
  drop-on-pressure policy, and no realtime file I/O.
- PASS rejects audio p99/max increase, playout target change, and hidden growth.

## Blockers / TODO(human)

- Depends on G10 or a narrower accepted media baseline.
- TODO(human): [Recording artifact format] -> Choose first on-disk recording format -> [WAV plus raw/video metadata / AVAsset side lane / defer recording writer]

## Verification Commands

```bash
swift run open-lola recording-session-run --integrated-baseline <integrated-av-report.json> --duration-seconds <n> --output-dir <session-dir> --report <recording-report.json>
swift run open-lola validate-recording-session-report <recording-report.json>
swift test --filter RecordingSession
swift test
```

## Resume here

Use `recording-session-run` to create the bounded session artifact handoff
first. Keep M14 PARTIAL until a real media writer under disk pressure proves
recording drops data without changing live media deadlines.

VERDICT: PARTIAL
