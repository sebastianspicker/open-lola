# M13 Status

## Current status

- Status: Partial.
- Verdict: PARTIAL 2026-05-03.
- Canonical milestone: [M13 Native App Shell](../milestones/M13_NATIVE_APP_SHELL.md)
- Validation report: [M13 Native App Shell Validation Report](../reports/M13_NATIVE_APP_SHELL_2026-05-02.md)

Canonical objective:

Build a native app shell around the proven headless core so the UI configures
and observes realtime paths without owning them.

Canonical assumptions:

- SwiftUI or AppKit can be used for UI after the headless core is proven.
- The app communicates through immutable config snapshots and metrics streams.
- UI actions cannot change latency silently.

Canonical dependencies:

- M10 integrated headless A/V.
- M11/M12 control gates if show-control UI is included.
- Stable configuration and metrics APIs.

## Completed work

- Added `NativeAppShellReport` with app configuration snapshot, read-only
  metrics observer profile, realtime boundary report, permission-readiness
  fields, app smoke probe fields, and PASS/PARTIAL verdict validation.
- Added `NativeAppShellSyntheticSmoke` for deterministic source validation.
- Added PASS guards that reject UI ownership of realtime audio/video/control
  lanes, blocking metrics observers, SwiftUI lifecycle dependencies, mutable
  config handoff, silent latency changes, settings persistence inside callback
  paths, missing app target build, missing runtime smoke, and missing CLI metrics
  comparison.
- Added a SwiftUI executable target named `open-lola-app`.
- Added a minimal macOS `NavigationSplitView` shell that displays overview,
  configuration, metrics, and realtime-boundary state from a synthetic report.
- Added CLI validation with `open-lola validate-native-app-shell-report <path>`.
- Added CLI smoke output with `open-lola native-app-shell-synthetic-smoke`.
- Added `NativeAppRuntimeSmokeConfiguration` and `NativeAppRuntimeSmoke` for a
  bounded `open-lola native-app-runtime-smoke --headless-report <path> --output
  <path>` helper that reads an integrated headless report and writes an M13
  PARTIAL report with immutable app configuration, read-only metrics
  observation, runtime-smoke fields, and CLI metric comparison fields.
- Added a synthetic PARTIAL native app shell fixture.
- Added [../reports/M13_NATIVE_APP_SHELL_2026-05-02.md](../reports/M13_NATIVE_APP_SHELL_2026-05-02.md).

## Verified work

- Red test run failed before implementation because M13 native app shell types
  did not exist.
- `swift test --filter NativeAppShell` passed with 13 tests.
- The focused M13 test build compiled the `open-lola-app` SwiftUI executable
  target.
- `bash scripts/verify-docs.sh` passed.
- `shellcheck scripts/*.sh` passed.
- `swift test` passed with 268 tests.
- `swift build` passed after rerunning outside the sandbox to avoid the known
  SwiftPM `sandbox-exec: sandbox_apply: Operation not permitted` manifest
  failure.
- `.build/debug/open-lola validate-native-app-shell-report Tests/OpenLolaCoreTests/Fixtures/NativeAppShellReports/valid/native-app-shell-partial.json`
  passed with `VERDICT: PARTIAL`.
- `.build/debug/open-lola native-app-shell-synthetic-smoke` passed with
  `VERDICT: PARTIAL`.
- `.build/debug/open-lola native-app-runtime-smoke --headless-report
  /private/tmp/open-lola-m10-integrated-av-smoke.json --output
  /private/tmp/open-lola-m13-native-app-runtime-smoke.json` wrote a validated
  PARTIAL app runtime handoff report.

## Partially completed work

- Source validation exists for immutable UI configuration snapshots, read-only
  metrics observation, SwiftUI/realtime ownership separation, and app target
  build coverage.
- PASS-level runtime evidence is not complete because no launched GUI/app-bundle
  runtime probe, GUI interaction pass, permission prompt check, or field
  app-vs-CLI metrics comparison has been recorded.
- Directly running `.build/debug/open-lola-app --help` launches the GUI process
  rather than a CLI help path; that is not a valid runtime smoke probe.

## Deferred work

- Launch `open-lola-app` as a real app process and record a GUI smoke report.
- Compare packaged app-observed metrics against CLI synthetic or measured
  reports.
- Add app bundle metadata, entitlements, and permission strings in M15 packaging.
- Add real device/session selection once M03/M05/M10 measured baselines exist.
- Add UI automation only after the app is packaged or has a stable launch path.

## Open tasks

Canonical progress checklist:

- [x] Define app configuration boundary.
- [x] Add app target.
- [x] Add metrics observer.
- [x] Add UI tests or smoke probe.
- [x] Add bounded native-app-runtime-smoke handoff.
- [ ] Compare launched app and CLI metrics.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

SOTA 2026 routing:

- Rows: SOTA014 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: UI/setup probes run outside realtime paths, use immutable config
  snapshots, observe metrics read-only, and cannot block audio playout.

Faster-than-LoLa companion implementation plan:

- [ ] Keep M13 behind M10. Do not make the app shell the owner of audio, video,
  OSC, ATEM, or recording runtime paths.
- [ ] Add a GUI-safe runtime smoke after M10 evidence exists. The report should
  record app launch, permission readiness, selected config snapshot, metrics
  observer state, and CLI-vs-app metric comparison.
- [x] Add a CLI helper if needed, such as `open-lola native-app-runtime-smoke
  --headless-report <path> --output <path>`, to produce the app-shell report
  without depending on interactive UI automation.
- [ ] Keep configuration handoff immutable: app creates or selects a config
  snapshot, headless core consumes it, app observes read-only metrics.
- [ ] Add microphone, camera, and local-network purpose-string readiness here as
  report fields, but let M15 own final entitlements, signing, and clean-Mac
  validation.
- [ ] PASS requires app-observed metrics to match CLI/headless metrics and no
  silent latency changes from UI actions.

## Known blockers

- Runtime app smoke needs a GUI-capable launch/probe path.
- Camera, microphone, and local-network permissions need bundle metadata and
  entitlements before field testing.
- PASS-level comparison depends on accepted CLI/headless metrics from earlier
  milestones.

## Test coverage status

Canonical test plan:

Before: no UI exists.

After:

- app target builds;
- UI configuration tests pass;
- metrics observation tests pass;
- headless tests remain green;
- UI smoke test verifies configuration without owning realtime paths.

Coverage state: source-level M13 coverage exists for report fixture decoding,
synthetic smoke, JSON round trip, UI realtime ownership PASS gates, blocking
metrics observer gate, SwiftUI lifecycle dependency gate, immutable config
snapshot gate, silent latency-change gate, runtime smoke gate, runtime-smoke
argument parsing, bounded runtime handoff generation from an integrated
headless report, and CLI metrics comparison gate. Full launched GUI,
permission, and field app-vs-CLI metrics coverage remain missing.

## Relevant files touched

- [../../Package.swift](../../Package.swift)
- [../../Sources/OpenLolaCore/NativeAppShell.swift](../../Sources/OpenLolaCore/NativeAppShell.swift)
- [../../Sources/open-lola-app/OpenLolaApp.swift](../../Sources/open-lola-app/OpenLolaApp.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/NativeAppShellTests.swift](../../Tests/OpenLolaCoreTests/NativeAppShellTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/NativeAppShellReports/valid/native-app-shell-partial.json](../../Tests/OpenLolaCoreTests/Fixtures/NativeAppShellReports/valid/native-app-shell-partial.json)
- [../reports/M13_NATIVE_APP_SHELL_2026-05-02.md](../reports/M13_NATIVE_APP_SHELL_2026-05-02.md)
- [../milestones/M13_NATIVE_APP_SHELL.md](../milestones/M13_NATIVE_APP_SHELL.md)
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
swift test --filter NativeAppShell
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
swift test
swift build
.build/debug/open-lola integrated-av-run --audio-baseline m05-route-baseline-required --video-capture on --video-transport on --osc-control on --atem-readonly off --duration-seconds 30 --output /private/tmp/open-lola-m10-integrated-av-smoke.json
.build/debug/open-lola native-app-runtime-smoke --headless-report /private/tmp/open-lola-m10-integrated-av-smoke.json --output /private/tmp/open-lola-m13-native-app-runtime-smoke.json
.build/debug/open-lola validate-native-app-shell-report /private/tmp/open-lola-m13-native-app-runtime-smoke.json
.build/debug/open-lola validate-native-app-shell-report Tests/OpenLolaCoreTests/Fixtures/NativeAppShellReports/valid/native-app-shell-partial.json
.build/debug/open-lola native-app-shell-synthetic-smoke
```

Result:

- Focused M13 tests pass with 13 tests.
- The focused build compiles the `open-lola-app` target.
- Full Swift/docs verification passes.
- The M13 runtime-smoke helper, generated report validator, fixture validator,
  and synthetic smoke command pass with
  `VERDICT: PARTIAL`.
- `swift build` requires the existing sandbox escalation in this environment
  because SwiftPM manifest compilation fails under `sandbox-exec`.
- 2026-05-02: faster-than-LoLa companion plan update passed
  `bash scripts/verify-docs.sh` and `shellcheck scripts/*.sh`.
- VERDICT: PARTIAL

## Next recommended steps

After M10 has measured headless evidence, use `native-app-runtime-smoke` as the
bounded handoff and then add a launched GUI/app-bundle metrics comparison. Keep
app bundle metadata and final permission validation for M15.

## Resume here

Start from `NativeAppShell.swift`, `native-app-runtime-smoke`, and
`Sources/open-lola-app/OpenLolaApp.swift`. Keep SwiftUI outside realtime
ownership. The next M13 closure step is a launched app report that compares
app-observed metrics with the accepted M10 CLI/headless metrics.
