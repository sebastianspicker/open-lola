# M14 Recording Session Artifacts Validation Report

Date: 2026-05-02  
Milestone: [M14 Recording Session Artifacts](../milestones/M14_RECORDING_SESSION_ARTIFACTS.md)  
Status: PARTIAL

## Scope

This report validates the M14 source-level recording/session artifact contract:
session metadata, side-lane recording policy, deterministic slow-writer pressure
simulation, drop/gap counters, media-impact PASS guards, artifact manifest
metadata, fixture validation, and synthetic smoke output. The 2026-05-03
addendum also validates `recording-session-run`, a bounded artifact-writer
handoff that reads an integrated baseline, writes session metadata, placeholder
copied-media artifacts, gap markers, metrics, and a PARTIAL M14 report without
putting file I/O in realtime paths. It does not validate real media recording
files, real disk pressure, or recording-on media metrics against a
recording-off baseline.

## Recording Contract

The report records:

- session ID, profile, operator/configuration source, and start/end timestamps;
- whether file I/O is forbidden in realtime callbacks;
- whether recording is fed from already-copied media;
- whether the writer is asynchronous and bounded;
- drop-on-pressure policy;
- produced, written, dropped, gap-marker, max-queue, and writer-stall counts;
- recording-off and recording-on audio callback p99/max and playout target;
- audio underruns, video drop counts, and hidden playout growth flag;
- artifact manifest root, entries, checksums, configuration metadata flag, and
  verdict metadata flag;
- PASS, FAIL, or PARTIAL verdict.

PASS reports require a measured run, no realtime callback file I/O, copied-media
side-lane input, async writing, drop-and-mark-gap policy, slow-writer pressure
evidence, drop/gap evidence, unchanged audio callback p99/max, unchanged
playout target, zero underruns, no hidden playout growth, and manifest metadata
for configuration and verdict.

## Commands

```bash
swift test --filter RecordingSession
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
swift test
swift build
.build/debug/open-lola integrated-av-run --audio-baseline m05-route-baseline-required --video-capture on --video-transport on --osc-control on --atem-readonly off --duration-seconds 30 --output /private/tmp/open-lola-m10-integrated-av-smoke.json
.build/debug/open-lola recording-session-run --integrated-baseline /private/tmp/open-lola-m10-integrated-av-smoke.json --duration-seconds 30 --output-dir /private/tmp/open-lola-m14-session --report /private/tmp/open-lola-m14-recording-session-run.json
.build/debug/open-lola validate-recording-session-report /private/tmp/open-lola-m14-recording-session-run.json
.build/debug/open-lola validate-recording-session-report Tests/OpenLolaCoreTests/Fixtures/RecordingSessionArtifacts/valid/recording-session-partial.json
.build/debug/open-lola recording-session-synthetic-smoke
```

## Results

- Red test run before implementation failed on missing M14 recording/session
  artifact types.
- `swift test --filter RecordingSession` passed with 14 M14 tests.
- `bash scripts/verify-docs.sh` passed.
- `shellcheck scripts/*.sh` passed.
- `swift test` passed with 271 tests.
- `swift build` passed after rerunning outside the sandbox to avoid the known
  SwiftPM `sandbox-exec: sandbox_apply: Operation not permitted` manifest
  failure.
- The native recording session fixture validator passed with
  `VERDICT: PARTIAL`.
- The native recording session synthetic smoke command passed with
  `VERDICT: PARTIAL`.
- The bounded `recording-session-run` helper wrote five session artifacts and a
  valid PARTIAL recording-session report.

## Deferred Runtime Evidence

M14 cannot be marked PASS until real reports exist for:

- recording-on stress with a real media artifact writer;
- recording-off versus recording-on audio callback p99/max comparison;
- fixed playout target during recording;
- zero audio underruns and no hidden playout growth;
- disk-pressure behavior that drops recording data and writes gap markers;
- field-test session artifact directory layout with production media files.

## Verdict

M14 source validation and bounded artifact handoff are complete, but real media
recording file output, disk-pressure stress, and recording-off/recording-on
media certification remain open.

VERDICT: PARTIAL

## Resume here

Use `open-lola recording-session-run --integrated-baseline <path>
--duration-seconds <n> --output-dir <dir> --report <path>` for the bounded
handoff, then validate it with
`open-lola validate-recording-session-report <path>`. Keep M14 PARTIAL until a
real media writer proves disk pressure drops recording data without changing
live media deadlines.
