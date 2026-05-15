# M13 Native App Shell

## Objective

Build a native app shell around the proven headless core so the UI configures
and observes realtime paths without owning them.

## Background/Context

The UI is intentionally late. Headless tools must prove audio, network, video,
and control behavior first so the app shell cannot hide latency or mutate
realtime contracts.

## Reverse-Engineering Findings

Static fact:
[../../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](../../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md)
identifies Windows LoLa as an MFC GUI distribution with helper tools. The Mac UI
does not inherit MFC behavior or Windows session/control messages.

## Research Findings

[../../research/RESEARCH_AUDIO_ENGINE_2026.md](../../research/RESEARCH_AUDIO_ENGINE_2026.md)
allows Swift/AppKit/SwiftUI to configure and observe the engine, but not own the
audio deadline. [../../research/RESEARCH_VIDEO_PIPELINE_2026.md](../../research/RESEARCH_VIDEO_PIPELINE_2026.md)
keeps video best-effort and subordinate.

Current source-validation baseline:

- `NativeAppShellReport` records immutable UI configuration snapshots,
  read-only metrics observation, realtime ownership boundaries, permission
  readiness, and app smoke status.
- `open-lola-app` is a SwiftUI executable target that displays synthetic
  overview, configuration, metrics, boundary, permission, and launch-probe
  state through the core-owned `NativeAppShellSurfaceContract`.
- `NativeAppShellSurface` records the required C11 app-shell sections,
  read-only action contract, and launch probe plan. Its source-level probe
  stays `PARTIAL` until launched-window evidence is recorded.
- `native-app-runtime-smoke` reads an integrated headless report and writes a
  bounded M13 PARTIAL handoff with immutable app configuration, read-only
  metrics observation, runtime-smoke fields, and CLI metric comparison fields.
- PASS remains blocked until launched GUI/app-bundle runtime smoke and field
  app-vs-CLI metrics comparison exist.

## Assumptions

- SwiftUI or AppKit can be used for UI after the headless core is proven.
- The app communicates through immutable config snapshots and metrics streams.
- UI actions cannot change latency silently.

## Dependencies

- M10 integrated headless A/V.
- M11/M12 control gates if show-control UI is included.
- Stable configuration and metrics APIs.

## Affected Modules/Files

- `OpenLolaCore` native app shell report and validation model.
- `OpenLolaCore` native app shell surface contract and probe report.
- `open-lola-app` SwiftUI executable target.
- `open-lola` CLI report validators, synthetic smoke command, runtime smoke,
  and app-shell surface probe.
- Future app bundle metadata, entitlements, and runtime UI probe.

## Implementation Plan

1. Define UI-owned configuration model separate from realtime state. Done for
   source validation with `NativeAppConfigurationSnapshot`.
2. Add immutable config snapshot handoff to the headless core. Source PASS gate
   exists; real headless handoff remains deferred until measured baselines
   exist.
3. Add metrics stream read-only observation. Source PASS gate exists.
4. Add device/session/settings UI around existing headless capabilities. Minimal
   synthetic SwiftUI target exists; real device/session selection remains
   deferred.
5. Add tests that UI state does not call realtime callback paths. Source PASS
   guards exist.
6. Add bounded runtime handoff from integrated headless metrics. Done with
   `native-app-runtime-smoke`; launched GUI evidence remains deferred.
7. Add source-level surface contract and launch probe plan. Done with
   `native-app-shell-surface-probe`; real launched-window evidence remains
   deferred.

## Test Plan

Before: no UI exists.

After:

- app target builds;
- UI configuration tests pass;
- metrics observation tests pass;
- headless tests remain green;
- UI smoke test verifies configuration without owning realtime paths.

Launched GUI/app-bundle metrics comparison remains required before PASS.

## Validation Method

Run the app against the headless core in a controlled mode and compare realtime
metrics with CLI operation.

## Acceptance Criteria

- UI can configure devices/session settings through a narrow API. Source
  snapshot boundary exists; measured device/session wiring deferred.
- UI can observe metrics without blocking media. Source PASS guard and bounded
  runtime-smoke handoff exist.
- Realtime code does not depend on SwiftUI lifecycle. Source PASS guard exists.
- No UI feature increases default audio playout latency. Source PASS guard
  exists; measured comparison deferred.

SOTA 2026 gate:

- Rows: SOTA014 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: UI/setup probes run outside realtime paths and cannot block audio playout.

## Risks and Mitigations

- R003: UI could dispatch into realtime paths. Mitigation: immutable snapshots
  and metrics stream separation.
- R010: app permissions may differ from CLI tools. Mitigation: record permission
  requirements early.

## Known Blockers

- App framework choice should follow the proven headless API shape.
- Camera, microphone, and network permissions may need app entitlements.

## Progress Checklist

- [x] Define app configuration boundary.
- [x] Add app target.
- [x] Add metrics observer.
- [x] Add UI tests or smoke probe.
- [x] Add bounded native-app-runtime-smoke handoff.
- [x] Add C11 app-shell surface contract and probe.
- [ ] Compare launched app and CLI metrics.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

## Next Recommended Action

Use `native-app-shell-surface-probe` and `native-app-runtime-smoke` as
source-level gates, then run a real `open-lola-app` GUI smoke after a stable
launch path and bundle metadata are ready.

## Resume here

Start from `NativeAppShell.swift`, `NativeAppShellSurface.swift`,
`native-app-shell-surface-probe`, `native-app-runtime-smoke`, and
`Sources/open-lola-app/OpenLolaApp.swift`. Keep SwiftUI outside realtime
ownership. The next M13 closure step is a launched app report that records the
six C11 surface sections and compares app-observed metrics with CLI/headless
metrics.
