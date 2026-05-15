# M14 Status

## Current status

- Status: Partial.
- Verdict: PARTIAL 2026-05-03.
- Canonical milestone: [M14 Recording Session Artifacts](../milestones/M14_RECORDING_SESSION_ARTIFACTS.md)
- Validation report: [M14 Recording Session Artifacts Validation Report](../reports/M14_RECORDING_SESSION_ARTIFACTS_2026-05-02.md)

Canonical objective:

Add recording and session artifacts outside live deadlines so disk pressure
drops recording data instead of delaying media.

Canonical assumptions:

- Recording is a side lane fed by already-copied data.
- Session artifacts are written asynchronously.
- Under disk pressure, recording drops or marks gaps instead of delaying media.

Canonical dependencies:

- M10 integrated headless A/V.
- M13 app/session configuration if UI-owned session names are required.
- Report schema that can record dropped recording data.

Canonical affected modules/files:

- Future recording side-lane module.
- Future session artifact writer.
- Future disk-pressure tests.
- Future session report fixtures.

Canonical implementation sequence:

1. Define session artifact format and metadata.
2. Add side-lane recording queue outside callbacks.
3. Add drop-on-pressure policy and counters.
4. Add disk-pressure tests or simulated slow-writer tests.
5. Add reports showing media metrics unchanged during recording.

Canonical acceptance criteria:

- No file I/O occurs in the audio callback.
- Recording can mark gaps or drops.
- Disk pressure never delays media deadlines.
- Session artifacts include configuration and verdict metadata.

Rollback/recovery notes:

- Documentation-only changes: restore the preserved historical copy when one exists, or revert the specific changed file.
- Source changes: revert the smallest affected change set and rerun `swift test`.
- Hardware, network, audio, video, lighting, recording, or packaging reports: mark the report invalid rather than deleting it, then rerun measurement.

## Completed work

- Added `RecordingSessionArtifactReport` with session metadata, side-lane
  policy, slow-writer pressure counters, media-impact metrics, artifact
  manifest fields, and PASS/PARTIAL verdict validation.
- Added `RecordingSideLanePressureSimulator` for deterministic slow-writer
  source validation.
- Added `RecordingSessionSyntheticSmoke` for deterministic source validation.
- Added `RecordingSessionRunConfiguration` and `RecordingSessionRunner` for a
  bounded `open-lola recording-session-run --integrated-baseline <path>
  --duration-seconds <n> --output-dir <dir> --report <path>` artifact-writer
  handoff that reads an integrated baseline, writes session metadata,
  placeholder copied-media artifacts, gap markers, metrics, and a PARTIAL M14
  report without putting file I/O in realtime paths.
- Added PASS guards that reject realtime callback file I/O, missing copied-media
  side lane, non-async writing, blocking/growing drop policies, missing
  slow-writer pressure evidence, missing drop/gap evidence, audio callback
  p99/max increases, playout target changes, audio underruns, hidden playout
  growth, missing configuration metadata, and missing verdict metadata.
- Added CLI validation with `open-lola validate-recording-session-report <path>`.
- Added CLI smoke output with `open-lola recording-session-synthetic-smoke`.
- Added a synthetic PARTIAL recording session artifact fixture.
- Added [../reports/M14_RECORDING_SESSION_ARTIFACTS_2026-05-02.md](../reports/M14_RECORDING_SESSION_ARTIFACTS_2026-05-02.md).

## Verified work

- Red test run failed before implementation because M14 recording/session types
  did not exist.
- `swift test --filter RecordingSession` passed with 14 tests.
- `.build/debug/open-lola recording-session-run --integrated-baseline
  /private/tmp/open-lola-m10-integrated-av-smoke.json --duration-seconds 30
  --output-dir /private/tmp/open-lola-m14-session --report
  /private/tmp/open-lola-m14-recording-session-run.json` wrote five session
  artifacts and a validated PARTIAL report.
- `.build/debug/open-lola validate-recording-session-report Tests/OpenLolaCoreTests/Fixtures/RecordingSessionArtifacts/valid/recording-session-partial.json`
  passed with `VERDICT: PARTIAL`.
- `.build/debug/open-lola recording-session-synthetic-smoke` passed with
  `VERDICT: PARTIAL`.
- `bash scripts/verify-docs.sh` passed.
- `shellcheck scripts/*.sh` passed.
- `swift test` passed with 271 tests.
- `swift build` passed after rerunning outside the sandbox to avoid the known
  SwiftPM `sandbox-exec: sandbox_apply: Operation not permitted` manifest
  failure.

## Partially completed work

- Source validation exists for recording/session artifact metadata, side-lane
  policy, simulated slow-writer drops/gaps, bounded artifact-writer handoff,
  and media-impact PASS guards.
- PASS-level runtime evidence is not complete because no real media writer
  under disk-pressure stress or recording-off baseline comparison has been
  recorded.

## Deferred work

- Real media recording file writer.
- Recording-on stress under real disk pressure.
- Recording-off versus recording-on media metric comparison.
- Session artifact directory layout for packaged field-test runs.

## Open tasks

Canonical progress checklist:

- [x] Define session artifact format.
- [x] Add side-lane writer.
- [x] Add drop/gap counters.
- [x] Add slow-writer tests.
- [x] Add bounded recording-session-run artifact handoff.
- [ ] Run recording-on stress.
- [ ] Compare recording-off baseline.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

SOTA 2026 routing:

- Rows: M14 routing summary in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: recording/session artifacts remain side lanes and cannot affect live deadlines.

Faster-than-LoLa companion implementation plan:

- [ ] Keep M14 behind M10. Recording is not part of the faster audio deadline;
  it is a side lane fed by already-copied media.
- [ ] Add a real artifact writer with an explicit session directory layout:
  config snapshot, measurement reports, logs/counters, gap manifest, and
  verdict file. Do not perform file I/O in audio/video/control callbacks.
- [x] Add a CLI stress path such as `open-lola recording-session-run
  --integrated-baseline <path> --duration-seconds <n> --output-dir <dir>
  --report <path>`.
- [ ] Implement drop-on-pressure behavior: if disk or writer pressure rises,
  recording data is dropped and gaps are marked; media deadlines are never
  delayed.
- [ ] Compare recording-off and recording-on metrics using the same M10
  integrated baseline. Record audio callback p99/max, packet age, underruns,
  frame age, control jitter, dropped recording blocks, and gap markers.
- [ ] PASS requires unchanged media metrics, gap/drop evidence under pressure,
  and session artifacts containing configuration and verdict metadata.

## Known blockers

- Final artifact format may depend on field-test workflow needs.
- Disk-pressure simulation can be platform-sensitive.
- PASS-level runtime validation depends on the M10 integrated A/V baseline for
  measured recording-off and recording-on comparison.

## Test coverage status

Canonical test plan:

Before: no recording exists.

After:

- recording writer tests pass;
- simulated slow disk drops recording data;
- audio/video metrics remain unchanged;
- session artifact report validates.

Coverage state: source-level M14 coverage exists for report fixture decoding,
synthetic smoke, JSON round trip, slow-writer drop/gap simulation, realtime file
I/O PASS gate, drop-on-pressure PASS gate, gap-marker PASS gate, audio p99 PASS
gate, playout-target PASS gate, hidden playout growth PASS gate, artifact
configuration metadata PASS gate, run argument parsing, bounded artifact
writing, and manifest entry validation. Real media writer, disk pressure, and
measured recording-off/recording-on coverage remain missing.

## Relevant files touched

Planned affected modules/files:

- Future real recording side-lane writer.
- Future session artifact writer.
- Future disk-pressure tests.
- Future measured session report fixtures.

Live files touched:

- [../../Sources/OpenLolaCore/RecordingSessionArtifacts.swift](../../Sources/OpenLolaCore/RecordingSessionArtifacts.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/RecordingSessionArtifactTests.swift](../../Tests/OpenLolaCoreTests/RecordingSessionArtifactTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/RecordingSessionArtifacts/valid/recording-session-partial.json](../../Tests/OpenLolaCoreTests/Fixtures/RecordingSessionArtifacts/valid/recording-session-partial.json)
- [../reports/M14_RECORDING_SESSION_ARTIFACTS_2026-05-02.md](../reports/M14_RECORDING_SESSION_ARTIFACTS_2026-05-02.md)
- [../milestones/M14_RECORDING_SESSION_ARTIFACTS.md](../milestones/M14_RECORDING_SESSION_ARTIFACTS.md)
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

Result:

- Focused M14 tests pass with 14 tests.
- Full Swift/docs verification passes.
- The M14 bounded run, generated report validator, fixture validator, and
  synthetic smoke command pass with
  `VERDICT: PARTIAL`.
- `swift build` requires the existing sandbox escalation in this environment
  because SwiftPM manifest compilation fails under `sandbox-exec`.
- 2026-05-02: faster-than-LoLa companion plan update passed
  `bash scripts/verify-docs.sh` and `shellcheck scripts/*.sh`.
- VERDICT: PARTIAL

## Next recommended steps

Use `recording-session-run` against the accepted M10 integrated headless
baseline, then replace placeholder copied-media artifacts with a real media
writer and measured recording-on disk-pressure stress report.

## Resume here

Start from `RecordingSessionArtifacts.swift` and `recording-session-run`. Keep
recording as a side lane fed by already-copied media. The next M14 closure step
is a real media writer and measured recording-on stress report that compares
recording-off and recording-on media metrics while the writer is under disk
pressure.
