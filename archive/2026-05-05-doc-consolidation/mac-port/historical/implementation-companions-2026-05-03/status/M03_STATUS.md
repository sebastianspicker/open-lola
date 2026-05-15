# M03 Status

## Current status

- Status: Partial.
- Canonical milestone: [M03 Endpoint Loopback Fastest Mode](../milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md)

Canonical objective:

Measure endpoint loopback and select the fastest stable hardware mode using a
16/32/64/128 frame matrix and a 30-minute stability run.

Canonical assumptions:

- M02 can enumerate devices and reported candidate-mode ranges; M03 owns any
  requested-mode probe.
- 32 frames is the main target; 16 frames is accepted only if measured results
  improve.
- 64 and 128 frames are fallback or diagnostic modes.

Canonical dependencies:

- M00 scaffold.
- M01 report schema.
- M02 device inventory.
- Analog loopback cable or measurement interface.

Canonical affected modules/files:

- Future audio loopback rig.
- Future endpoint latency report fixtures.
- Future callback metrics module.
- [../RISK_REGISTER.md](../RISK_REGISTER.md)

Canonical implementation sequence:

1. Add loopback rig with fixed test signal and capture path.
2. Probe 48/96/192 kHz where supported.
3. Probe 16/32/64/128 frame modes.
4. Record callback p50/p95/p99/max, misses, underruns, overruns, and measured
   analog round-trip.
5. Run a 30-minute fixed-target stability test on candidate fastest mode.
6. Select fastest stable mode with a dated verdict.

Canonical acceptance criteria:

- 16/32/64/128 frame matrix is recorded for each tested rate.
- Selected mode has stable callback p99/max and no hidden buffer growth.
- M03 PASS requires RME MADI inventory visibility, a real Core Audio
  `AudioDeviceIOProc` or AUHAL loopback runner, measured 16/32/64/128 frame
  rows at 48 kHz and 96 kHz where supported, callback p99/max, underruns,
  analog latency, and hidden-conversion evidence.
- Report includes `VERDICT: PASS`, `VERDICT: FAIL`, or `VERDICT: PARTIAL`.

Rollback/recovery notes:

- Documentation-only changes: restore the preserved historical copy when one exists, or revert the specific changed file.
- Source changes: revert the smallest affected change set and rerun `swift test`.
- Hardware, network, audio, video, lighting, recording, or packaging reports: mark the report invalid rather than deleting it, then rerun measurement.

## Completed work

- Added an `EndpointLoopbackReport` model for M03 mode matrices, callback
  metrics, analog loopback metrics, selected mode, stability run, and verdict.
- Added validation for required 48/96/192 kHz disposition, 16/32/64/128 frame
  rows for supported rates, accepted/rejected mode state, callback metrics,
  analog loopback metrics, selected-mode stability, 30-minute stability
  duration, dropout events, and hidden buffer growth.
- Added valid and invalid M03 endpoint loopback fixtures.
- Added Swift tests for fixture decoding, required matrix rows, accepted-mode
  loopback metrics, 30-minute stability duration, hidden buffer growth, and
  JSON round-trip behavior.
- Added `open-lola validate-loopback-report <path>` CLI validation.
- Added test-first `AudioLoopbackRunConfiguration`, `AudioLoopbackPreflight`,
  and `AudioLoopbackRunReport` coverage for the headless runner surface.
- Added a real Core Audio `AudioDeviceIOProc` loopback runner for same-device
  full-duplex RME paths. The callback records host-time callback intervals and
  copies input buffers to output buffers without logging, file I/O, or network
  work in the realtime path.
- Added `open-lola audio-loopback-run --input-uid <uid> --output-uid <uid>
  --sample-rate <hz> --frames <n> --duration-seconds <n> --output <path>`.
  It writes a machine-readable single-run report and blocks before starting
  Core Audio when the RME MADI device, sample rate, frame size, or full-duplex
  route is not visible.
- Added the G02 `RmeFastestAudioPathReport` model, PARTIAL template fixture,
  CLI validator, and PASS guards for RME MADI visibility, driver/firmware
  evidence, TotalMix snapshot evidence, M03 loopback PASS, 48/96 kHz stable
  supported rows, 16/32/64/128 matrix coverage, no hidden growth, and measured
  fastest-stable default selection.
- Added [../reports/M03_ENDPOINT_LOOPBACK_2026-05-02.md](../reports/M03_ENDPOINT_LOOPBACK_2026-05-02.md).

## Verified work

- Red test run before implementation failed on missing
  `EndpointLoopbackReport` and `EndpointLoopbackValidationError`.
- `swift test` passed with 17 tests after implementation.
- `swift run open-lola validate-loopback-report
  Tests/OpenLolaCoreTests/Fixtures/EndpointLoopback/valid/endpoint-loopback-valid.json`
  passed.
- `swift run open-lola validate-loopback-report
  Tests/OpenLolaCoreTests/Fixtures/EndpointLoopback/invalid/missing-32-frame.json`
  failed as expected with
  `missingRequiredFrameSize(sampleRateHertz: 48000, framesPerBuffer: 32)`.
- `swift build` passed.
- `swift run open-lola` passed.
- `swift run open-lola device-inventory` passed and captured 3 local Core
  Audio devices.
- `bash scripts/verify-docs.sh` passed.
- `shellcheck scripts/*.sh` passed.
- Red test run for the headless loopback runner failed on the missing
  `AudioLoopbackRunConfiguration`, `AudioLoopbackPreflight`, and
  `AudioLoopbackRunReport` types before implementation.
- `swift test --filter AudioLoopbackRunTests` passed with 8 tests after the
  Core Audio runner and CLI support were added.
- `swift build` passed after the loopback runner and CLI support were added.
- `swift test` passed with 136 tests after the loopback runner and CLI support
  were added.
- `swift run open-lola audio-loopback-run --input-uid missing-rme-uid
  --output-uid missing-rme-uid --sample-rate 48000 --frames 32
  --duration-seconds 1 --output
  /private/tmp/open-lola-audio-loopback-preflight.json` wrote a blocked
  preflight report with `VERDICT: PARTIAL`.
- Red G02 test run failed before implementation because
  `RmeFastestAudioPathReport` and related validation types did not exist.
- `swift test` passed with 199 tests after adding the G02 report model,
  fixture, and PASS guards.
- `bash scripts/verify-docs.sh` passed after the M03 status update.
- `shellcheck scripts/*.sh` passed after the M03 status update.

## Partially completed work

- The report contract, fixture validation, CLI validation surface, headless
  runner configuration, RME preflight, and same-device Core Audio IOProc runner
  exist.
- The G02 RME fastest-audio validator exists and can validate a PARTIAL
  report template without claiming measured hardware PASS.
- The IOProc runner has not completed on RME MADI hardware in this workspace.
- No real 16/32/64/128 matrix, analog loopback result, or 30-minute stability
  result exists yet.

## Deferred work

- Physical analog loopback measurement is deferred until the target
  input/output device and loopback path are provided.
- Fastest stable endpoint selection remains deferred until the real M03 report
  validates.

## Open tasks

Canonical progress checklist:

- [ ] Add loopback rig.
- [x] Add headless loopback CLI.
- [x] Add same-device Core Audio IOProc runner.
- [x] Add mode matrix report.
- [x] Add G02 RME fastest-audio report gate.
- [x] Add callback metrics.
- [ ] Run short matrix.
- [ ] Run 30-minute stability test.
- [ ] Select fastest stable mode.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

SOTA 2026 routing:

- Rows: Q002, Q003, SOTA004, SOTA021, SOTA024, SOTA074, SOTA075 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: analog loopback and 16/32/64/128-frame plus 48/96/192 kHz matrix select fastest stable mode by measurement only.

Faster-than-LoLa companion implementation plan:

- [x] Add a headless Core Audio loopback runner before any product UI work. The
  CLI surface should be `open-lola audio-loopback-run --input-uid <uid>
  --output-uid <uid> --sample-rate <hz> --frames <n> --duration-seconds <n>
  --output <path>`.
- [x] Implement the first runner with direct `AudioDeviceIOProc` or AUHAL, not
  `AVAudioEngine`; setup may allocate, but the callback may only do bounded
  stack work, timestamp capture, preallocated buffer copy, atomic counters, and
  ring push/pop.
- [x] Add tests before source implementation for run-configuration validation,
  accepted/rejected frame rows, callback-metric accounting, and report
  validation. Keep hardware execution behind CLI/runtime probes.
- [ ] Run RME MADI 48 kHz and 96 kHz matrices at 16/32/64/128 frames where the
  driver accepts the mode; add 192 kHz only after 48/96 kHz reports validate.
- [ ] Record requested frame size, accepted frame size, callback p50/p95/p99/max,
  missed deadlines, underruns/overruns, analog round-trip, corrected one-way
  estimate, safety offsets, and hidden conversion/buffer evidence.
- [ ] Select fastest stable mode by measured analog latency and 30-minute fixed
  target stability. Do not choose 16 or 32 frames from API range alone.

## Known blockers

- Requires physical loopback setup.
- Requires explicit RME MADI target input/output device UID. Built-in Mac audio
  remains a smoke/preflight fixture and cannot close M03 PASS.
- Separate input/output UID operation requires an AUHAL or aggregate-device
  path; the implemented IOProc runner is intentionally limited to same-device
  full-duplex RME paths.
- Some interfaces may hide real conversion or safety buffering; the validator
  now requires this to be measured rather than assumed.

## Test coverage status

Canonical test plan:

Before: no loopback report exists.

After:

- mode matrix report validates;
- callback metric tests pass;
- 30-minute stability report exists for selected mode;
- `swift build` and `swift test` pass.

Coverage state: Swift tests cover fixture decoding, required matrix rows,
accepted-mode callback and loopback metric requirements, 30-minute stability
duration, hidden-buffer-growth rejection, headless loopback-run argument
validation, RME preflight acceptance/rejection, selected non-RME endpoint
rejection when RME is visible, G02 RME fastest-audio fixture validation, G02
PASS rejection for non-RME devices, placeholder driver evidence, missing
loopback PASS, hidden buffer growth, unsupported 96 kHz, and non-fastest stable
default selection, and single-run report round-trip behavior.
Runtime audio capture remains untested on RME hardware.

## Relevant files touched

Planned affected modules/files:

- Future audio loopback rig.
- Future endpoint latency report fixtures.
- Future callback metrics module.
- [../RISK_REGISTER.md](../RISK_REGISTER.md)

Live files touched:

- [../../Sources/OpenLolaCore/AudioLoopbackRun.swift](../../Sources/OpenLolaCore/AudioLoopbackRun.swift)
- [../../Sources/OpenLolaCore/EndpointLoopbackReport.swift](../../Sources/OpenLolaCore/EndpointLoopbackReport.swift)
- [../../Sources/OpenLolaCore/RmeFastestAudioPath.swift](../../Sources/OpenLolaCore/RmeFastestAudioPath.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift](../../Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift)
- [../../Tests/OpenLolaCoreTests/EndpointLoopbackReportTests.swift](../../Tests/OpenLolaCoreTests/EndpointLoopbackReportTests.swift)
- [../../Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift](../../Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/EndpointLoopback/valid/endpoint-loopback-valid.json](../../Tests/OpenLolaCoreTests/Fixtures/EndpointLoopback/valid/endpoint-loopback-valid.json)
- [../../Tests/OpenLolaCoreTests/Fixtures/EndpointLoopback/invalid/missing-32-frame.json](../../Tests/OpenLolaCoreTests/Fixtures/EndpointLoopback/invalid/missing-32-frame.json)
- `../../Tests/OpenLolaCoreTests/Fixtures/RmeFastestAudioPathReports/`
- [../reports/M03_ENDPOINT_LOOPBACK_2026-05-02.md](../reports/M03_ENDPOINT_LOOPBACK_2026-05-02.md)
- [../milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md](../milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md)
- [../PROGRESS.md](../PROGRESS.md)
- [../STATUS_INDEX.md](../STATUS_INDEX.md)
- [../../MAC_PORT_PLAN.md](../../MAC_PORT_PLAN.md)
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)
- [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md)
- [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md)

## Latest verification

- 2026-05-02: `swift test` passed with 17 tests.
- 2026-05-02: `swift run open-lola validate-loopback-report
  Tests/OpenLolaCoreTests/Fixtures/EndpointLoopback/valid/endpoint-loopback-valid.json`
  passed.
- 2026-05-02: invalid M03 fixture CLI probe failed with the expected missing
  32-frame validation error.
- 2026-05-02: `swift build` passed.
- 2026-05-02: `swift run open-lola` passed.
- 2026-05-02: `swift run open-lola device-inventory` passed and captured 3
  local Core Audio devices.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- 2026-05-02: faster-than-LoLa companion plan update passed
  `bash scripts/verify-docs.sh` and `shellcheck scripts/*.sh`.
- 2026-05-02: red test-first loopback-run pass failed on missing runner types
  before implementation.
- 2026-05-02: `swift test --filter AudioLoopbackRunTests` passed with 8 tests.
- 2026-05-02: `swift build` passed.
- 2026-05-02: `swift test` passed with 136 tests.
- 2026-05-02: `swift run open-lola audio-loopback-run --input-uid
  missing-rme-uid --output-uid missing-rme-uid --sample-rate 48000 --frames 32
  --duration-seconds 1 --output
  /private/tmp/open-lola-audio-loopback-preflight.json` wrote a blocked
  preflight report with RME visibility false and `VERDICT: PARTIAL`.
- 2026-05-02: red G02 test-first run failed on missing
  `RmeFastestAudioPathReport` before implementation.
- 2026-05-02: `swift test` passed with 199 tests after G02 implementation.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- VERDICT: PARTIAL

## Next recommended steps

Use the M02 inventory output to pick RME input/output UID values, connect the
analog loopback path, then run `audio-loopback-run` for the first real
32-frame RME probe.

## Resume here

Run `swift run open-lola device-inventory`, choose the RME target devices,
connect the analog loopback path, then run:

```bash
swift run open-lola audio-loopback-run --input-uid <rme-uid> --output-uid <rme-uid> --sample-rate 48000 --frames 32 --duration-seconds 60 --output reports/m03-rme-48000-32.json
```

Use the single-run output to fill a real `EndpointLoopbackReport` beginning
with the 32-frame RME row. Keep M03 PARTIAL until RME MADI visibility, the
48/96 kHz 16/32/64/128 matrix where supported, analog latency,
hidden-conversion evidence, and the 30-minute stability run validate.
