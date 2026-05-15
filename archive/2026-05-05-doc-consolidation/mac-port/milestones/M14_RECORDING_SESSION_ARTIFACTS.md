# M14 Recording Session Artifacts

## Objective

Add recording and session artifacts outside live deadlines so disk pressure
drops recording data instead of delaying media.

## Background/Context

Recording is useful for diagnostics and session review, but it is subordinate
to live audio and video timing. Recording must never block the audio callback or
force media buffers to grow.

## Reverse-Engineering Findings

Static fact:
[../../reverse-engineering/REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md](../../reverse-engineering/REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md)
shows Windows LoLa had optional recording surfaces. That is evidence that
recording can exist, not evidence that it belongs in the realtime path.

## Research Findings

[../../research/RESEARCH_AUDIO_ENGINE_2026.md](../../research/RESEARCH_AUDIO_ENGINE_2026.md)
forbids file I/O in the callback.
[../../research/RESEARCH_BENCHMARK_ROADMAP_2026.md](../../research/RESEARCH_BENCHMARK_ROADMAP_2026.md)
requires recording features to preserve default audio playout latency.

Current source-validation baseline:

- `RecordingSessionArtifactReport` records session metadata, side-lane policy,
  slow-writer pressure counters, media-impact metrics, artifact manifest
  metadata, and PASS/PARTIAL verdict state.
- `RecordingSideLanePressureSimulator` provides deterministic slow-writer
  pressure evidence where recording data drops and gap markers are counted.
- `recording-session-run` reads an integrated baseline, writes bounded session
  metadata, placeholder copied-media artifacts, gap markers, metrics, and a
  PARTIAL M14 report without putting file I/O in realtime paths.
- PASS remains blocked until a measured recording-on stress report proves
  unchanged audio/video timing while writing real media session artifacts.

## Assumptions

- Recording is a side lane fed by already-copied data.
- Session artifacts are written asynchronously.
- Under disk pressure, recording drops or marks gaps instead of delaying media.

## Dependencies

- M10 integrated headless A/V.
- M13 app/session configuration if UI-owned session names are required.
- Report schema that can record dropped recording data.

## Affected Modules/Files

- `OpenLolaCore` recording/session artifact report and validation model.
- `open-lola` CLI report validator and synthetic smoke command.
- Recording/session artifact fixtures and focused unit tests.
- Future real artifact writer and measured disk-pressure report.

## Implementation Plan

1. Define session artifact format and metadata. Done for source validation with
   `RecordingArtifactManifest` and `RecordingSessionMetadata`.
2. Add side-lane recording queue outside callbacks. Source PASS gates now
   require copied-media side-lane input and no realtime callback file I/O.
3. Add drop-on-pressure policy and counters. Done for source validation with
   `RecordingDropPolicy.dropAndMarkGap` and writer pressure counters.
4. Add disk-pressure tests or simulated slow-writer tests. Done with a
   deterministic slow-writer pressure simulator.
5. Add reports showing media metrics unchanged during recording. Source PASS
   guards and bounded handoff writer exist; measured recording-on stress remains
   deferred.

## Test Plan

Before: no recording exists.

After:

- recording writer tests pass;
- simulated slow disk drops recording data;
- audio/video metrics remain unchanged;
- session artifact report validates.

Measured recording-on stress with real media artifacts remains required before
PASS.

## Validation Method

Run recording under normal and stressed disk conditions while comparing audio
callback and video frame metrics against recording-off baseline.

## Acceptance Criteria

- No file I/O occurs in the audio callback.
- Recording can mark gaps or drops.
- Disk pressure never delays media deadlines.
- Session artifacts include configuration and verdict metadata.

SOTA 2026 gate:

- Rows: M14 routing summary in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: recording/session artifacts remain side lanes and cannot affect live deadlines.

## Risks and Mitigations

- R003: file I/O could enter realtime path. Mitigation: side-lane queue and
  tests.
- R007: recording may compete with video and audio resources. Mitigation:
  pressure tests and drop policy.

## Known Blockers

- Final artifact format may depend on field-test workflow needs.
- Disk-pressure simulation can be platform-sensitive.

## Progress Checklist

- [x] Define session artifact format.
- [x] Add side-lane writer.
- [x] Add drop/gap counters.
- [x] Add slow-writer tests.
- [x] Add bounded recording-session-run artifact handoff.
- [ ] Run recording-on stress.
- [ ] Compare recording-off baseline.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

## Next Recommended Action

Use `recording-session-run` against the accepted M10 integrated headless
baseline, then run a measured recording-on stress report with the real media
writer.

## Resume here

Start from `RecordingSessionArtifacts.swift` and `recording-session-run`. The
next M14 closure step is a measured recording-on stress report that compares
recording-off and recording-on media metrics while a real media writer is under
disk pressure.
