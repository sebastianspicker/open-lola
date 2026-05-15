# M12 Integrated Profile

Date: 2026-05-03  
Status: publication-safe milestone plan  
Verdict: PARTIAL

## Objective

Define and measure the integrated performance profile for audio, video, and
lighting/control together.

## Scope

Cover default fastest profile selection, optional profile labels, degradation
order, telemetry, and a full benchmark matrix.

## Affected Files

- [../architecture/latency-first-architecture.md](../architecture/latency-first-architecture.md)
- [../architecture/benchmark-methodology.md](../architecture/benchmark-methodology.md)
- [../architecture/implementation-roadmap.md](../architecture/implementation-roadmap.md)
- `Sources/OpenLolaCore/IntegratedProfileReport.swift`
- `Sources/OpenLolaCore/IntegratedAvReport.swift`
- Future integrated profile report files under `mac-port/reports/`

## Implementation Tasks

- Define `fastest-audio` as the default profile.
- Define optional video and lighting profiles with explicit latency cost.
- Record degradation order: video quality/frame rate first, lighting optional,
  audio latency last.
- Aggregate subordinate reports without hiding their verdicts.

## Test Plan

- Profile selection tests.
- Report aggregation tests.
- Negative tests for promoting PARTIAL subordinate evidence to PASS.
- Degradation-order tests.

## Benchmark Plan

Run the full matrix: audio only, audio plus video, audio plus control, and
audio plus video plus control. Record latency, jitter, loss, dropped frames,
cue timing, CPU, memory, and callback warnings.

## Acceptance Criteria

- Default profile remains audio-first.
- Optional features report measurable cost.
- Integrated profile uses only physical PASS evidence for PASS claims.

### Implementation Addendum

The source-level M12 implementation now lives in
`Sources/OpenLolaCore/IntegratedProfileReport.swift`. It defines:

- `fastest-audio` as the only default profile.
- Optional `audio-video`, `audio-lighting`, and `audio-video-lighting`
  profiles, each with an explicit latency-cost field.
- Subordinate evidence lanes for fastest audio, audio route, video capture,
  video transport, integrated A/V, and lighting/control. PASS rejects any
  `PARTIAL` or non-physical subordinate lane.
- Full benchmark matrix rows for audio only, audio plus video, audio plus
  control, and audio plus video plus control.
- Degradation order with video quality and frame rate first, lighting disable
  before audio impact, and audio latency as the last resort.

The CLI surface is:

```bash
open-lola validate-integrated-profile-report <path>
open-lola integrated-profile-synthetic-smoke
open-lola integrated-profile-run --fastest-audio <id> --integrated-av <id> --lighting-control <id> --audio-only <id> --audio-video <id> --audio-control <id> --audio-video-control <id> --output <path>
```

This is source validation and report aggregation. The physical benchmark matrix
is still open, so the milestone verdict remains `PARTIAL`.

## Risks

- Aggregated reports can hide a weak subordinate lane.
- Optional profiles can creep into defaults.
- Field users may choose quality profile without seeing latency cost.

## Blockers

Accepted M10 and M11 evidence, plus all subordinate hardware and route reports.

## Rollback Plan

Revert to the last accepted audio-only profile and mark integrated profile
PARTIAL.

## Progress Checklist

- [x] Default profile documented.
- [x] Optional profiles labeled.
- [ ] Full physical matrix measured.
- [x] Degradation order verified at source level.
- [x] M12 source-validation report stored.

## Resume Point

Resume at M13 after the integrated profile is stable enough for real hardware
field validation.

VERDICT: PARTIAL
