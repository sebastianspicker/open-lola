# M11 Status

## Current status

- Status: Partial.
- Verdict: PARTIAL 2026-05-03.
- Canonical milestone: [M11 OSC Show-Control Probe](../milestones/M11_OSC_SHOW_CONTROL_PROBE.md)
- Validation report: [M11 OSC Cue Validation Report](../reports/M11_OSC_CUE_2026-05-02.md)

Canonical objective:

Add an OSC show-control probe with timestamped cue-loop timing and unchanged
audio metrics.

Canonical assumptions:

- OSC 1.0 semantics are the default unless a target tool requires otherwise.
- Chataigne or Open Stage Control can be used as the first peer.
- OSC runs outside realtime audio code.

Canonical dependencies:

- M10 integrated headless A/V metrics or at least M05/M06 audio metrics.
- OSC parser/serializer choice.
- Local OSC peer or loopback responder.

## Completed work

- Added `OscCueMessage` with minimal OSC 1.0-compatible string-argument packet
  encoding and decoding for `/open-lola/cue`.
- Added `OscCueReport` schema and validation for peer availability, cue message
  profile, live UDP transport evidence, first external peer evidence, cue
  timing, jitter summary, audio-impact metrics, and verdict.
- Added `OscCueSyntheticLoopback` with deterministic timestamped cue samples.
- Added `OscCueUdpLoopbackRunner` for live UDP loopback on `127.0.0.1`, with
  sent/received packet counts and measured jitter.
- Added optional `audioImpact.baselineReportId` and
  `OscCueExternalRunConfiguration` / `OscCueExternalRunner` for bounded PARTIAL
  reports that combine live local UDP loopback, a selected first external peer,
  and an operator-supplied audio baseline ID.
- Added PASS guards that reject unavailable peers, non-loopback PASS reports,
  missing live UDP loopback evidence, missing first external peer evidence,
  increased audio p99/max, playout-target changes, underruns, and hidden audio
  impact.
- Added `AtemReadOnlyControlReport` with IP address, model, firmware, program
  source, preview source, tally, audio mixer state, health, and
  `armedCommandsAllowed`.
- Added ATEM read-only validation that rejects any report where
  `armedCommandsAllowed` is true.
- Added G08 ATEM read-only reachability evidence fields: control port,
  protocol label, network interface, same-network-as-audio flag, read-only poll
  interval, connection-attempt duration, and error message.
- Added G08 ATEM PASS guards that reject missing network evidence and
  placeholder model, firmware, program/preview, tally, audio mixer, protocol,
  network-interface, or notes fields.
- Added a synthetic PARTIAL OSC cue report fixture.
- Added CLI validation with `open-lola validate-osc-cue-report <path>`.
- Added CLI validation with `open-lola validate-atem-control-report <path>`.
- Added CLI smoke output with `open-lola osc-cue-synthetic-smoke`.
- Added CLI live loopback with `open-lola osc-cue-run --peer 127.0.0.1 --port
  <port> --count <n> --output <path>`.
- Added CLI external-peer handoff with `open-lola osc-cue-external-run
  --audio-baseline <report-id> --port <port> --count <n>
  --first-external-peer chataigne|openStageControl|qlcPlus|ola
  --external-host <host> --external-port <port> --external-available
  true|false [--external-unavailable-reason <text>] --output <path>`.
- Added CLI ATEM read-only PARTIAL output with `open-lola atem-readonly-probe
  --host <ip> --output <path>`.
- Extended `open-lola atem-readonly-probe` with `--port`,
  `--timeout-milliseconds`, `--poll-interval-milliseconds`,
  `--network-interface`, and `--same-network-as-audio`.
- Added [../reports/M11_OSC_CUE_2026-05-02.md](../reports/M11_OSC_CUE_2026-05-02.md).

## Verified work

- Red test run failed before implementation because M11 OSC cue types did not
  exist.
- `swift test --filter OscCueReportTests` passed with 16 tests after live UDP
  OSC loopback and ATEM read-only report implementation.
- `swift test` passed with 161 tests after the live UDP/ATEM update.
- `swift build` passed.
- The synthetic PARTIAL OSC cue fixture passed CLI validation.
- The synthetic smoke command emits a PARTIAL report.
- The local live UDP OSC loopback command emitted a PARTIAL report and the OSC
  validator accepted it.
- The local ATEM read-only command emitted `armedCommandsAllowed: false`,
  `health: timeout`, `protocolName: tcp-reachability`, port `9910`, and
  unknown ATEM hardware fields as concrete PARTIAL evidence; the ATEM
  validator accepted it.
- Red G08 test-first run failed on missing `AtemReadOnlyProbeConfiguration`,
  `AtemReadOnlyNetworkObservation`, `AtemReadOnlyControlProbe.makeReport`, and
  placeholder PASS evidence rejection.
- `swift test --filter OscCueReportTests` passed with 20 focused OSC/ATEM tests
  after adding bounded ATEM reachability reporting.
- `swift build` passed after rerunning outside the SwiftPM sandbox failure.
- `swift test` passed with 253 tests after adding bounded ATEM reachability
  reporting.
- 2026-05-03: `swift test --filter OscCue` passed with 23 focused tests after
  adding the external-peer/audio-baseline report writer.
- The bounded ATEM reachability probe wrote
  `/private/tmp/open-lola-m11-atem-readonly.json`; validation accepted it with
  `VERDICT: PARTIAL`.
- Documentation verification passed.
- Shellcheck passed for the docs verifier script.

## Partially completed work

- Source validation exists for OSC cue packet shape, local synthetic loopback
  timing, live UDP loopback timing, jitter reporting, external peer PASS gates,
  bounded external-peer/audio-baseline PARTIAL report writing, ATEM read-only
  report validation, ATEM reachability evidence, and audio-impact PASS gates.
- PASS-level runtime evidence is not complete because no first external peer,
  real ATEM protocol/status probe, or audio-active cue-loop run has been
  recorded.

## Deferred work

- Run live UDP OSC loopback with accepted audio baseline active.
- Run cue-loop probe with an accepted M05/M06 or M10 audio baseline active.
- Test Chataigne as the preferred external peer.
- Test Open Stage Control as fallback if Chataigne is unavailable.
- Run ATEM read-only probe against real ATEM hardware/network access.
- Add real read-only ATEM protocol or SDK-backed status extraction behind an
  optional boundary before claiming model/firmware/program PASS evidence.
- Test QLC+/OLA OSC behavior if lighting control depends on it.
- Record real peer availability and interop notes.

## Open tasks

Canonical progress checklist:

- [x] Define OSC cue message.
- [x] Add loopback tests.
- [x] Add live UDP OSC loopback runner.
- [x] Add jitter report fixture.
- [x] Add bounded external-peer/audio-baseline report writer.
- [ ] Run with audio baseline active.
- [ ] Test one external peer where available.
- [x] Add ATEM read-only report contract.
- [x] Update [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md).
- [x] Update [../PROGRESS.md](../PROGRESS.md).

SOTA 2026 routing:

- Rows: Q008, SOTA017, SOTA058, SOTA059, SOTA069, SOTA070 in
  [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: OSC 1.0 cue loop starts local, then Chataigne first and Open
  Stage Control fallback external peer tests measure jitter separately from
  audio.

Faster-than-LoLa companion implementation plan:

- [x] Add live UDP OSC loopback before external peers. The CLI surface is
  `open-lola osc-cue-run --peer <ip> --port <port> --count <n>
  --output <path>`.
- [ ] Run Chataigne as the first external OSC peer and Open Stage Control as the
  fallback peer only if Chataigne is unavailable.
- [x] Add an operator-facing external-peer handoff command that records the
  chosen peer and audio baseline ID while keeping the report PARTIAL until real
  peer/audio evidence exists.
- [x] Add first external peer evidence fields to `OscCueReport`; PASS requires
  an available external peer after live UDP loopback evidence exists.
- [x] Add ATEM read-only control as a subordinate M11 control lane, not as video
  or audio ownership. Create `AtemReadOnlyControlReport`, tests, and
  CLI validation `open-lola validate-atem-control-report <path>`.
- [x] Add `open-lola atem-readonly-probe --host <ip> --output <path>` to record
  IP, model, firmware, program source, preview source, tally, audio mixer state,
  health, and `armedCommandsAllowed: false`.
- [x] Extend `atem-readonly-probe` to record bounded reachability, port,
  timeout, polling interval, network interface, same-network-as-audio flag,
  duration, and error text.
- [x] Do not implement ATEM switching commands in this pass. Any future switch
  command must require an explicit arm state and a separate safety plan.
- [ ] Run OSC and ATEM probes with the accepted M05/M06 or M10 audio baseline
  active. PASS requires unchanged audio p99/max, underruns, route verdict, and
  playout target.

## Known blockers

- First real OSC peer choice is Chataigne unless unavailable; Open Stage Control
  remains fallback.
- Tool-specific OSC behavior may differ.
- ATEM read-only probe needs ATEM network access and a read-only ATEM protocol
  or SDK adapter before it can report real model, firmware, program/preview,
  tally, audio mixer state, and PASS health.
- M05/M06/M10 audio baseline evidence is still needed before audio-impact
  closure.

## Test coverage status

Canonical test plan:

Before: no cue timing tests exist.

After:

- OSC message tests pass;
- loopback jitter report validates;
- audio metrics remain unchanged;
- peer interop report exists or records peer unavailability.

Coverage state: source-level M11 coverage exists for OSC cue packet round trip,
synthetic loopback jitter, live UDP loopback, fixture validation, cue-count
accounting, report JSON round trip, peer availability PASS gate, live UDP
loopback PASS gate, first external peer PASS gate, external-run argument
parsing, local-loopback-as-external rejection, audio baseline ID recording,
PARTIAL external-peer report generation, ATEM read-only JSON round trip, ATEM
command-disarmed validation, ATEM reachability report building, ATEM probe
configuration parsing, ATEM placeholder PASS rejection, audio p99 gate, and
playout target gate. Real external-peer, real ATEM protocol/status, and
audio-active coverage are still missing.

## Relevant files touched

- [../../Sources/OpenLolaCore/AtemReadOnlyControl.swift](../../Sources/OpenLolaCore/AtemReadOnlyControl.swift)
- [../../Sources/OpenLolaCore/OscCueProbe.swift](../../Sources/OpenLolaCore/OscCueProbe.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/OscCueReportTests.swift](../../Tests/OpenLolaCoreTests/OscCueReportTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/OscCueReports/valid/osc-cue-partial.json](../../Tests/OpenLolaCoreTests/Fixtures/OscCueReports/valid/osc-cue-partial.json)
- [../reports/M11_OSC_CUE_2026-05-02.md](../reports/M11_OSC_CUE_2026-05-02.md)
- [../milestones/M11_OSC_SHOW_CONTROL_PROBE.md](../milestones/M11_OSC_SHOW_CONTROL_PROBE.md)
- [../PROGRESS.md](../PROGRESS.md)
- [../STATUS_INDEX.md](../STATUS_INDEX.md)
- [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md)
- [../MILESTONE_INDEX.md](../MILESTONE_INDEX.md)
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)
- [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md)
- [../RISK_REGISTER.md](../RISK_REGISTER.md)
- [../../MAC_PORT_PLAN.md](../../MAC_PORT_PLAN.md)

## Latest verification

Commands:

```bash
swift test --filter OscCueReportTests
swift test
swift build
.build/debug/open-lola validate-osc-cue-report Tests/OpenLolaCoreTests/Fixtures/OscCueReports/valid/osc-cue-partial.json
.build/debug/open-lola osc-cue-synthetic-smoke
.build/debug/open-lola osc-cue-run --peer 127.0.0.1 --port 0 --count 3 --output /private/tmp/open-lola-m11-osc-live-loopback.json
.build/debug/open-lola validate-osc-cue-report /private/tmp/open-lola-m11-osc-live-loopback.json
.build/debug/open-lola osc-cue-external-run --audio-baseline m05-route-baseline-required --port 0 --count 3 --first-external-peer chataigne --external-host 192.0.2.20 --external-port 8000 --external-available false --external-unavailable-reason "Chataigne not running" --output /private/tmp/open-lola-m11-osc-external.json
.build/debug/open-lola validate-osc-cue-report /private/tmp/open-lola-m11-osc-external.json
.build/debug/open-lola atem-readonly-probe --host 192.0.2.10 --port 9910 --timeout-milliseconds 100 --poll-interval-milliseconds 1000 --network-interface en5 --same-network-as-audio false --output /private/tmp/open-lola-m11-atem-readonly.json
.build/debug/open-lola validate-atem-control-report /private/tmp/open-lola-m11-atem-readonly.json
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

Result:

- Swift tests and build pass; latest full suite: 262 tests.
- CLI fixture validation, synthetic smoke, live UDP OSC loopback,
  external-peer PARTIAL output, ATEM read-only PARTIAL output, and validators
  pass.
- Documentation verification and shellcheck pass.
- 2026-05-02: live UDP OSC and ATEM read-only implementation passed
  `swift test --filter OscCueReportTests` with 16 focused tests.
- 2026-05-02: live UDP OSC and ATEM read-only implementation passed
  `swift test` with 161 tests.
- 2026-05-03: G08 ATEM reachability implementation passed
  `swift test --filter OscCueReportTests` with 20 focused OSC/ATEM tests.
- 2026-05-03: G08 ATEM reachability implementation passed `swift test` with
  253 tests.
- 2026-05-03: Full G11 verification passed with `swift test` (262 tests),
  `swift build` after rerunning outside the SwiftPM sandbox failure,
  `osc-cue-external-run`, generated-report validation, fixture validation,
  synthetic smoke, live UDP loopback, ATEM read-only probe, ATEM validation,
  `bash scripts/verify-docs.sh`, and `shellcheck scripts/*.sh`.
- Latest local ATEM output: `ipAddress: 192.0.2.10`, `controlPort: 9910`,
  `protocolName: tcp-reachability`, `networkInterface: en5`,
  `sameNetworkAsAudio: false`, `health: timeout`,
  `connectionAttemptMilliseconds: 103.25002670288086`,
  `errorMessage: connect timed out`, `armedCommandsAllowed: false`,
  `model: unknown`, `firmware: unknown`, `programSource: unknown`,
  `previewSource: unknown`, `tally: unknown`, `audioMixerState: unknown`.
- 2026-05-02: faster-than-LoLa companion plan update passed
  `bash scripts/verify-docs.sh` and `shellcheck scripts/*.sh`.
- VERDICT: PARTIAL

## Next recommended steps

Run live UDP OSC loopback with an audio baseline active, then test Chataigne as
the first external peer. Run ATEM read-only reachability against real ATEM
hardware, then add a real read-only status adapter behind an optional boundary;
commands remain disarmed and no switching command exists in this pass.

## Resume here

Start from `OscCueProbe.swift` for the first external OSC peer evidence and
`AtemReadOnlyControl.swift` for real ATEM read-only status extraction. Validate
OSC with `open-lola validate-osc-cue-report <path>` and ATEM with `open-lola
validate-atem-control-report <path>`. Keep M11 PARTIAL until live control
traffic proves unchanged audio timing.
