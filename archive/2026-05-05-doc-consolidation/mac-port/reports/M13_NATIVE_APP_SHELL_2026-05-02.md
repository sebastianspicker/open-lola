# M13 Native App Shell Validation Report

Date: 2026-05-02  
Milestone: [M13 Native App Shell](../milestones/M13_NATIVE_APP_SHELL.md)  
Status: PARTIAL

## Scope

This report validates the M13 source-level native app shell: immutable
configuration snapshot fields, read-only metrics observer fields, realtime
boundary PASS guards, a minimal SwiftUI executable target, fixture validation,
and synthetic smoke output. The 2026-05-03 addendum also validates
`native-app-runtime-smoke`, a bounded helper that reads an integrated headless
report and writes an M13 PARTIAL report with immutable app configuration,
read-only metrics observation, runtime-smoke fields, and CLI metric comparison
fields. It does not validate a launched app bundle, GUI interaction, permission
prompts, or field app-observed metrics against CLI metrics. The 2026-05-04 C11
update adds a core-owned app-shell surface contract and source-level surface
probe, but it still keeps launched GUI evidence outside the PASS boundary.

## App Shell Contract

The report records:

- app-owned configuration snapshot for profile, audio device selection, sample
  rate, frame size, playout target, video, show-control, and lighting toggles;
- whether the configuration handoff is immutable;
- metrics stream name, read-only status, main-actor publication, polling
  interval, and whether observation can block realtime paths;
- realtime ownership boundaries for audio, video, and control;
- whether realtime code depends on SwiftUI lifecycle;
- whether latency changes require explicit user action;
- whether settings are persisted outside callback paths;
- permission readiness for microphone, camera, local network, and network
  client entitlement planning;
- app target build, runtime smoke, and CLI metrics comparison status;
- PASS, FAIL, or PARTIAL verdict.
- C11 surface sections for overview, configuration, metrics, boundaries,
  permissions, and launch-probe state.
- read-only app-shell actions and a launch probe plan that blocks PASS without
  recorded window evidence.

PASS reports require the app target to build, runtime app smoke to exist, CLI
metrics comparison to exist, immutable configuration handoff, read-only
nonblocking metrics observation, no UI-owned realtime lanes, no SwiftUI
lifecycle dependency, explicit latency-change action, and settings persistence
outside callback paths.

## Commands

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
.build/debug/open-lola native-app-shell-surface-probe
```

## Results

- Red test run before implementation failed on missing M13 native app shell
  types.
- `swift test --filter NativeAppShell` passed with 13 M13 tests.
- The focused M13 test build compiled the `open-lola-app` SwiftUI executable
  target.
- `bash scripts/verify-docs.sh` passed.
- `shellcheck scripts/*.sh` passed.
- `swift test` passed with 268 tests.
- `swift build` passed after rerunning outside the sandbox to avoid the known
  SwiftPM `sandbox-exec: sandbox_apply: Operation not permitted` manifest
  failure.
- The native app shell fixture validator passed with `VERDICT: PARTIAL`.
- The native app shell synthetic smoke command passed with `VERDICT: PARTIAL`.
- The bounded `native-app-runtime-smoke` helper wrote a valid PARTIAL app
  runtime handoff report from an integrated headless report.
- The C11 `native-app-shell-surface-probe` source-level report validates the
  read-only SwiftUI surface contract and intentionally returns
  `VERDICT: PARTIAL` until a launched app window is observed.
- Running `.build/debug/open-lola-app --help` launches the app process rather
  than a CLI help path, so it is not counted as runtime GUI smoke evidence.

## Deferred Runtime Evidence

M13 cannot be marked PASS until real reports exist for:

- launched `open-lola-app` GUI/app-bundle runtime smoke;
- recorded screenshot/log evidence for the C11 overview, configuration,
  metrics, boundaries, permissions, and launch-probe sections;
- packaged app-observed metrics compared with CLI/headless metrics;
- permission prompt and entitlement readiness;
- app bundle metadata and signing/packaging path in M15;
- proof that UI actions cannot change audio playout latency silently.

## Verdict

M13 source validation is complete, but runtime GUI, permission, and app-vs-CLI
metric certification remain open.

VERDICT: PARTIAL

## Resume here

Use `open-lola native-app-runtime-smoke --headless-report <path> --output
<path>` for the bounded handoff, run `open-lola native-app-shell-surface-probe`
for source-level surface checks, then use
`open-lola validate-native-app-shell-report <path>` for measured app shell
reports. Keep M13 PARTIAL until a launched app runtime probe proves UI
configuration and metrics observation without realtime ownership.
