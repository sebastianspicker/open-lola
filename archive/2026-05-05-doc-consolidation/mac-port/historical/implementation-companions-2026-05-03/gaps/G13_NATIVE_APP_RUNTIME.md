# G13 Native App Runtime

## LoLa Comparison

LoLa provides a GUI for setup, connect/disconnect, monitoring, local/remote
rendering, and buffer tuning. The Mac app can expose operator surfaces only
after the headless core proves that SwiftUI does not own realtime paths.

## Current Repo State

- Related milestone: [../milestones/M13_NATIVE_APP_SHELL.md](../milestones/M13_NATIVE_APP_SHELL.md)
- Live status: [../status/M13_STATUS.md](../status/M13_STATUS.md)
- Existing source has a SwiftUI target, native app shell report validation,
  immutable config boundary, read-only metrics observer, and synthetic smoke.
- Existing source also has `native-app-runtime-smoke`, a bounded helper that
  reads an integrated headless report and writes an M13 PARTIAL report with
  immutable app configuration, read-only metrics observation, and CLI metric
  comparison fields.
- Missing piece: launched GUI/app-bundle runtime smoke, permission prompts, and
  field app-vs-CLI metrics evidence.

## Implementation Plan

1. Keep CLI/headless runtime authoritative until G10 has measured evidence.
2. Launch `open-lola-app` and record app target build, runtime smoke, permission
   prompts, and read-only metrics observer behavior.
3. Add only immutable configuration snapshots from UI to runtime. Runtime
   restart or explicit user action is required for latency-changing settings.
4. Compare app-observed metrics with CLI report metrics for the same run.
5. Reject PASS if SwiftUI lifecycle owns audio/video/control paths or if the UI
   can silently change playout target.

## Acceptance Tests

- `validate-native-app-shell-report` accepts measured app report.
- PASS requires runtime smoke, CLI metrics comparison, immutable config
  snapshots, read-only observer, and no UI ownership of realtime lanes.
- App launch does not replace CLI verification.

## Blockers / TODO(human)

- Depends on G10 measured PASS or defensible PARTIAL.
- TODO(human): [M13 operator mode] -> Decide first app role after headless proof -> [read-only monitor / explicit-run launcher / defer app runtime]

## Verification Commands

```bash
swift build
swift run open-lola native-app-runtime-smoke --headless-report <integrated-av-report.json> --output <native-app-report.json>
swift run open-lola validate-native-app-shell-report <native-app-report.json>
swift test --filter NativeAppShell
```

## Resume here

Use `native-app-runtime-smoke` to record the app handoff against an integrated
headless report first. Then launch the packaged GUI as a read-only monitor. Do
not add operator controls that can change latency silently.

VERDICT: PARTIAL
