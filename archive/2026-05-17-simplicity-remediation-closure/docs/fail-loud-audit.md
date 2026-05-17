# Fail-Loud Audit

Date: 2026-05-17

Scope: targeted audit of false success, hidden uncertainty, swallowed failures,
ignored return values, optimistic UI/runtime status, and tests that miss failure
behavior. The pass covered high-risk runtime and verification surfaces in
`Sources/OpenLolaCore`, `Sources/open-lola`, `Sources/open-lola-app`,
`script/`, `scripts/`, `linux_connector/lola_connector`, and relevant tests.

Constraint followed: docs-only. No production code, test code, refactor, or
deletion was performed. Only this file was created.

Judgment rule: a finding is recorded only where the current checkout contains
direct evidence that a caller, report, UI, or script can receive a success-like
state while some relevant failure is not represented, counted, or propagated.
If intent is unclear, the finding says so.

## Findings

### FLA-001

- ID: FLA-001
- Severity: P1
- File: `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`
- Symbol / function / flow: `DirectPeerRealtimeAudioGraph.stopUnlocked()`
- Evidence: `stopUnlocked()` calls `AudioDeviceStop` and
  `AudioDeviceDestroyIOProcID` with ignored return values, then writes
  `ioProcRunning = 0` and clears device/proc state. It also restores original
  sample rate and buffer frame size with `try?`, discarding any restore error
  (`DirectPeerRealtimeAudioGraph.swift:254-299`).
- What success is claimed: the graph is stopped, IOProcs are destroyed, and
  device settings are restored/forgotten.
- What is actually proven: the method attempted stop/destroy/restore calls.
  The code does not prove that Core Audio accepted those calls.
- Missing failure/uncertainty signal: no returned shutdown result, no thrown
  cleanup error, no cleanup-warning field in the runtime report, and no count
  of failed Core Audio cleanup/restoration operations.
- Runtime or user impact: a run can continue to report a clean shutdown or let
  later state infer the graph is stopped while an IOProc may still be active or
  a device may remain at the test sample rate/buffer size.
- Suggested remediation: make shutdown return an explicit cleanup result, or
  record stop/destroy/restore errors into the AV runtime/report metadata before
  clearing state.
- Test needed: Core Audio shim/injection test where stop, destroy, and restore
  calls fail; assert the graph/report exposes those failures and does not mark
  shutdown as fully successful.
- Verification needed: focused Swift test for the injected failure path plus a
  native runtime probe confirming reports include cleanup status.
- Confidence: high

### FLA-002

- ID: FLA-002
- Severity: P1
- File: `Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift`
- Symbol / function / flow: `AudioLoopbackRunner.runIOProc(...)`
- Evidence: the report is built with `state: .completed` and notes saying the
  IOProc run completed (`AudioLoopbackRun.swift:245-251`). The method restores
  original device sample rate/frame size with `try?` in a `defer` and destroys
  the IOProc with an ignored `AudioDeviceDestroyIOProcID` return value
  (`AudioLoopbackRun.swift:269-285`, `311-326`).
- What success is claimed: a single Core Audio IOProc run completed.
- What is actually proven: `AudioDeviceStop` succeeded before report creation;
  destroy and device-property restoration are only attempted.
- Missing failure/uncertainty signal: no report field for cleanup/restoration
  failure, no warning count, and no test-visible distinction between "completed
  and restored" and "completed but cleanup/restoration failed".
- Runtime or user impact: the report can look complete while the user's audio
  device remains altered or an IOProc destroy failure went unreported.
- Suggested remediation: capture destroy/restore status and surface it in the
  report; downgrade the run or add explicit cleanup warnings when cleanup is
  uncertain.
- Test needed: injectable Core Audio property/IOProc cleanup failures, asserting
  the report records cleanup uncertainty instead of a plain completed state.
- Verification needed: focused audio loopback cleanup test and a validator rule
  rejecting PASS/completed claims when cleanup status is failed or unknown.
- Confidence: high

### FLA-003

- ID: FLA-003
- Severity: P1
- File: `Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSmokes.swift`
- Symbol / function / flow: `UdpPcmLoopbackSmoke.run(...)`
- Evidence: the looper runs on a background queue; any looper error is caught,
  written only to a local `DebugTrace(limit: 0)`, and not rethrown
  (`UdpPcmLoopbackSmokes.swift:77-91`). The caller then ignores whether
  `done.wait(...)` succeeded and returns a sender report
  (`UdpPcmLoopbackSmokes.swift:102-113`).
- What success is claimed: a localhost UDP PCM loopback smoke report is
  returned.
- What is actually proven: the sender loop returned metrics. The looper may
  have failed or not completed within the wait window.
- Missing failure/uncertainty signal: no looper result, no looper error, no
  completion timeout, and no receive-side packet count in the returned report.
- Runtime or user impact: a loopback smoke can be treated as evidence even when
  the loopback receiver failed, which is exactly the path that should prove the
  packet loop.
- Suggested remediation: store the looper result in a result box, require
  `done.wait` success, and fail or mark the report uncertain when the looper
  failed or timed out.
- Test needed: inject a looper failure or timeout and assert
  `UdpPcmLoopbackSmoke.run` fails or emits explicit partial/failed loopback
  evidence.
- Verification needed: targeted Swift test for looper failure plus existing UDP
  loopback tests.
- Confidence: high

### FLA-004

- ID: FLA-004
- Severity: P1
- File: `script/build_and_run.sh`; `scripts/verify-release-readiness.sh`;
  `Tests/OpenLolaCoreTests/AppBundleScriptSourcePolicyTests.swift`
- Symbol / function / flow: native app launch verification and release
  readiness probe
- Evidence: `capture_app_ui_evidence` verifies detailed accessibility labels
  only if the AppleScript succeeds. If it fails, the script writes a fallback
  line saying accessibility label capture is unavailable and still returns
  success if visible-window and screenshot evidence exist
  (`build_and_run.sh:356-372`). The release readiness probe only requires
  non-empty `process.pid`, `accessibility-ui.txt`, and `screenshot.png`, then
  prints `native app launch probe -> PASS`
  (`verify-release-readiness.sh:167-176`). The current test only checks source
  text contains label guards, not that the fallback path fails release readiness
  (`AppBundleScriptSourcePolicyTests.swift:17-35`).
- What success is claimed: native app launch probe `PASS`.
- What is actually proven: process evidence, screenshot evidence, and a
  non-empty accessibility text file exist. If AppleScript failed, the required
  labels were not proven.
- Missing failure/uncertainty signal: no separate status for "visible window
  observed but accessibility labels unavailable"; release readiness does not
  fail or degrade the native app probe on missing label evidence.
- Runtime or user impact: the release gate can overstate UI launch evidence,
  especially on machines without Accessibility permission or where UI traversal
  fails.
- Suggested remediation: make label capture mandatory for `--verify`, or emit
  an explicit PARTIAL/UNCERTAIN app-launch result that release readiness does
  not print as PASS.
- Test needed: harness test where `osascript` fails but screenshot/window
  capture succeeds; assert `build_and_run.sh --verify` or
  `verify-release-readiness.sh` fails or reports uncertainty.
- Verification needed: `swift test --filter AppBundleScriptSourcePolicyTests`
  with a behavior-level harness, plus a manual app launch probe on a machine
  with Accessibility disabled.
- Confidence: high

### FLA-005

- ID: FLA-005
- Severity: P2
- File: `Sources/OpenLolaCore/Network/NAT/NatRendezvousRelayRunners.swift`;
  `Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift`
- Symbol / function / flow: NAT rendezvous and relay datagram loops
- Evidence: rendezvous drops invalid JSON or wrong-session registration
  datagrams with `try? ... decode` and `continue`
  (`NatRendezvousRelayRunners.swift:19-28`). Relay similarly treats malformed
  or non-registration datagrams as unregistered traffic and continues
  (`NatRendezvousRelayRunners.swift:198-220`). The public reports expose
  registrations/completed responses or forwarded datagrams, but no malformed,
  wrong-session, skipped, or rejected datagram counts
  (`NatFriendlyRouteReports.swift:3-13`, `89-98`).
- What success is claimed: rendezvous/relay reports summarize the run.
- What is actually proven: how many accepted registrations, completed
  responses, or forwarded datagrams were recorded.
- Missing failure/uncertainty signal: no accounting for malformed, wrong
  session, unsafe, or ignored packets.
- Runtime or user impact: a report cannot distinguish an idle network from a
  noisy or malformed one, making NAT failure analysis weaker and allowing
  partial failure to look like simple timeout/no peer behavior.
- Suggested remediation: add explicit skipped/malformed/wrong-session counters
  to NAT reports and validators.
- Test needed: send malformed and wrong-session datagrams during a rendezvous
  or relay smoke and assert the report counts them.
- Verification needed: focused `NatFriendlyRouteTests` additions and validator
  checks for the new accounting.
- Confidence: high

### FLA-006

- ID: FLA-006
- Severity: P2
- File: `linux_connector/lola_connector/connector.py`
- Symbol / function / flow: `LolaConnector._receive_control_until(...)`,
  `initiate(...)`, `accept_once(...)`
- Evidence: malformed LoLa control datagrams parsed as `None` are skipped with
  `continue`; handler `ValueError`s are logged and skipped
  (`connector.py:224-256`). `initiate` reports only `TimeoutError("LoLa
  QuickConn ACK timed out")` after that path (`connector.py:258-276`). The
  status probe has richer counts and reasons (`connector.py:278-339`), but the
  QuickConn/accept control path does not expose equivalent counts.
- What success is claimed: on timeout, the user sees only that the ACK timed
  out; on success, the returned session hides preceding malformed noise.
- What is actually proven: no accepted handler result arrived before timeout.
- Missing failure/uncertainty signal: malformed datagram count, unexpected
  datagram count, wrong-peer count, and last response kind are not returned for
  QuickConn/accept attempts.
- Runtime or user impact: live compatibility debugging can misclassify "peer
  responded with malformed/wrong data" as a plain timeout.
- Suggested remediation: use an explicit control-attempt result for QuickConn
  and accept paths, matching `StatusCheckResult` accounting.
- Test needed: malformed QuickConn ACK and wrong-peer QuickConn datagrams
  should produce a failure result with counts, not an indistinct timeout.
- Verification needed: `python -m pytest -p no:cacheprovider
  linux_connector/tests/test_process_runtime.py` after focused tests are added.
- Confidence: high

### FLA-007

- ID: FLA-007
- Severity: P2
- File: `Sources/open-lola-app/AppExecutablePathResolver.swift`;
  `Sources/open-lola-app/AppExecutionController.swift`
- Symbol / function / flow: app executable path resolution
- Evidence: `AppExecutablePathResolver.resolve` logs a warning when the path
  cannot be verified, then returns the unverified candidate path anyway
  (`AppExecutablePathResolver.swift:8-24`). Command builders wrap that in
  `Result { ... }`, so command construction can succeed even when the
  executable path is not executable; launch failure is deferred
  (`AppExecutionController.swift:112-157`, `303-315`, `374-438`).
- What success is claimed: command arguments can be generated and displayed as
  runnable.
- What is actually proven: only string resolution happened; executable
  existence was not verified.
- Missing failure/uncertainty signal: the resolver does not return
  `.verified`/`.unverified` or throw for a missing executable, so preview and
  command state cannot distinguish verified command construction from
  best-effort path guessing.
- Runtime or user impact: the app can show a plausible command and proceed to a
  later launch failure instead of failing early at command construction.
- Suggested remediation: return a typed resolution result or throw on
  unverified executable paths for launch/validation commands while keeping any
  preview-only behavior explicit.
- Test needed: command generation with a nonexistent executable should produce
  an unavailable/failed state before launch, not a successful command preview.
- Verification needed: focused app shell command/resolver tests.
- Confidence: medium

### FLA-008

- ID: FLA-008
- Severity: P2
- File: `Sources/open-lola-app/AppOperatorArtifactViews.swift`;
  `Sources/open-lola-app/AppExecutionView.swift`;
  `Sources/open-lola-app/AppPacketMonitorView.swift`;
  `Sources/open-lola-app/AppShellSupportViews.swift`
- Symbol / function / flow: pasteboard copy helpers
- Evidence: multiple helpers call `NSPasteboard.general.setString(...)` and
  ignore its Boolean return (`AppOperatorArtifactViews.swift:190-194`,
  `AppExecutionView.swift:141-144`, `AppPacketMonitorView.swift:202-205`,
  `AppShellSupportViews.swift:284-287`). `AppOperatorArtifactViews` sets user
  status text such as `Copied local inventory JSON.` and `Copied SSH supervisor
  command.` immediately after the unchecked copy call
  (`AppOperatorArtifactViews.swift:81-87`, `157-168`).
- What success is claimed: content was copied to the pasteboard.
- What is actually proven: the app attempted to clear and set the pasteboard.
- Missing failure/uncertainty signal: the set failure is ignored and no UI
  error state exists for pasteboard rejection.
- Runtime or user impact: an operator can believe a plan, command, or packet
  value was copied when the pasteboard write failed.
- Suggested remediation: check `setString` and set explicit failure status when
  it returns false.
- Test needed: injectable pasteboard adapter returning false; assert the UI
  does not say copied.
- Verification needed: app unit test for copy failure plus a manual pasteboard
  smoke check if adapters are not yet injectable.
- Confidence: high

### FLA-009

- ID: FLA-009
- Severity: P2
- File: `Sources/OpenLolaCore/Support/ManagedProcessRunner.swift`
- Symbol / function / flow: `ManagedProcess.closeOutputHandles()`,
  `killImmediately()`, and termination result
- Evidence: `killImmediately()` ignores the `kill(..., SIGKILL)` return value
  (`ManagedProcessRunner.swift:36-38`). `closeOutputHandles()` closes stdout
  and stderr with `try?` (`ManagedProcessRunner.swift:45-48`). The termination
  result includes process count and whether a forced kill was sent/exited, but
  not kill errno or log-handle close failures (`ManagedProcessRunner.swift:51-60`,
  `141-170`). Existing tests cover forced-kill outcome but not kill failure or
  close failure (`ManagedProcessRunnerTests.swift:42-72`).
- What success is claimed: process termination/log cleanup is represented by
  `ManagedProcessTerminationResult`.
- What is actually proven: a SIGKILL was attempted and a polling result was
  observed; output handles were asked to close.
- Missing failure/uncertainty signal: kill failure cause and log close failure
  are lost.
- Runtime or user impact: process cleanup or log flush failures can disappear
  from app/report state, leaving operators without evidence of why logs are
  incomplete or processes remain.
- Suggested remediation: include cleanup warnings/errors in
  `ManagedProcessTerminationResult` and expose handle-close failures where logs
  matter.
- Test needed: injectable process/handle wrapper that simulates kill and close
  failures; assert warnings are preserved.
- Verification needed: focused `ManagedProcessRunnerTests` after injection.
- Confidence: medium

### FLA-010

- ID: FLA-010
- Severity: P2
- File: `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift`
- Symbol / function / flow: `AVFoundationFrameRecorder.record(...)` and
  `rawFrameBytes(from:)`
- Evidence: when raw capture is enabled, raw extraction uses
  `try? rawFrameBytes(from:)`, so unsupported pixel formats, missing base
  address, invalid layout, or other thrown errors become `nil`
  (`VideoCaptureAVFoundation.swift:409-424`). The frame is still enqueued and
  counted as captured; raw data is saved only if non-empty
  (`VideoCaptureAVFoundation.swift:436-448`). `rawFrameBytes` also ignores the
  `CVPixelBufferLockBaseAddress` return value before reading/unlocking
  (`VideoCaptureAVFoundation.swift:637-685`).
- What success is claimed: frames are captured and retained in the camera
  snapshot.
- What is actually proven: metadata was recorded; raw frame payload capture may
  have failed silently.
- Missing failure/uncertainty signal: no raw extraction failure count, no last
  raw extraction error, and no distinction between "raw capture disabled" and
  "raw capture requested but failed".
- Runtime or user impact: AV/raw-video evidence can look like frame capture
  succeeded while the payload needed for transport or recording was not
  captured.
- Suggested remediation: record raw extraction attempts/failures and fail or
  mark reports partial when raw capture is required but unavailable.
- Test needed: simulated unsupported/invalid pixel buffer path should increment
  a raw extraction failure count and prevent raw evidence claims.
- Verification needed: AVFoundation frame recorder unit test with injectable
  pixel-buffer extraction, plus direct P2P AV report validation for missing raw
  payload evidence.
- Confidence: medium

### FLA-011

- ID: FLA-011
- Severity: P2
- File: `Sources/OpenLolaCore/Release/PackagingFieldTestRun.swift`
- Symbol / function / flow: `packagingFieldRunVerdict(...)`
- Evidence: if subordinate runtime evidence is pass-like, the function mutates
  a pass candidate and runs `try? passCandidate.validate()`. A validation
  failure is collapsed to `.partial`; the actual validation error is discarded
  (`PackagingFieldTestRun.swift:167-177`).
- What success is claimed: no false PASS is claimed; the code correctly
  downgrades to PARTIAL when validation fails.
- What is actually proven: the candidate did not validate as PASS, but not why.
- Missing failure/uncertainty signal: the specific blocked gate is not recorded
  in the generated report notes, blockers, or validation summary.
- Runtime or user impact: release operators must rerun or manually infer why a
  packaging field run stayed PARTIAL, which slows closure and can hide the
  actual missing proof.
- Suggested remediation: capture the validation error string as a blocked-gate
  note when downgrading from pass candidate to partial.
- Test needed: force each packaging pass-candidate validation error during run
  construction and assert the generated partial report names the blocker.
- Verification needed: focused `PackagingFieldTestTests` for downgrade reason
  propagation.
- Confidence: high

### FLA-012

- ID: FLA-012
- Severity: P3
- File: `linux_connector/lola_connector/connector.py`;
  `linux_connector/lola_connector/cli.py`
- Symbol / function / flow: `LolaConnector.check_status(...)`
- Evidence: `check_status_result` carries `acknowledged`, reason, response
  peer/kind, malformed counts, wrong-peer counts, unexpected counts, and sent
  dialects (`connector.py:278-337`). The convenience `check_status` collapses
  all of that to a Boolean (`connector.py:338-339`). The CLI uses the richer
  result and prints counts (`cli.py:102-111`).
- What success is claimed: callers of the Boolean method only get
  true/false.
- What is actually proven: for false, only that no usable ACK was accepted.
- Missing failure/uncertainty signal: false does not distinguish timeout,
  malformed response, wrong peer, or unexpected response.
- Runtime or user impact: any caller using the convenience method can hide the
  diagnostic reason already available in the richer result type.
- Suggested remediation: deprecate or restrict the Boolean method, or rename it
  to make the loss explicit and prefer `check_status_result` in runtime paths.
- Test needed: ensure no production CLI/runtime path uses `check_status` where
  reason/counts should be surfaced.
- Verification needed: `rg "check_status\\(" linux_connector/lola_connector
  linux_connector/tests` plus targeted Python tests if the method remains.
- Confidence: medium

## Highest-Risk False-Success Paths

1. `DirectPeerRealtimeAudioGraph.stopUnlocked()` can clear realtime audio state
   after unverified Core Audio stop/destroy/restore calls (FLA-001).
2. `UdpPcmLoopbackSmoke.run(...)` can return loopback evidence while the looper
   failed or did not finish (FLA-003).
3. Native app release readiness can print `native app launch probe -> PASS`
   when accessibility label capture was unavailable (FLA-004).
4. `AudioLoopbackRunner.runIOProc(...)` can report completed after hidden
   restore/destroy failures (FLA-002).
5. Raw AVFoundation capture can count frames while raw payload extraction failed
   silently (FLA-010).

## Places Needing Explicit Result Types/Counts/Status

- Core Audio graph shutdown/restoration should return or report cleanup status
  and failed-operation counts (FLA-001, FLA-002).
- UDP loopback smoke needs sender, looper, timeout, and receive-side result
  fields instead of a sender-only report (FLA-003).
- NAT rendezvous/relay reports need malformed, wrong-session, unsafe, skipped,
  and ignored datagram counts (FLA-005).
- Python QuickConn/accept flows need the same kind of reason/count structure as
  `StatusCheckResult` (FLA-006).
- Managed process cleanup needs explicit kill/close warning fields (FLA-009).
- Packaging field run downgrade needs a blocker/reason field when a pass
  candidate fails validation (FLA-011).

## Places Needing Better Error Propagation

- Propagate Core Audio `AudioDeviceStop`, `AudioDeviceDestroyIOProcID`, and
  device-property restore failures instead of discarding them (FLA-001,
  FLA-002).
- Turn UDP loopback looper exceptions and completion timeout into thrown errors
  or explicit failed/uncertain report status (FLA-003).
- Treat native app accessibility evidence failure as an app-launch verification
  failure or explicit uncertainty in release readiness (FLA-004).
- Preserve raw AVFoundation extraction errors and `CVPixelBufferLockBaseAddress`
  failures (FLA-010).
- Preserve process kill and log-handle close failures (FLA-009).

## Places Needing UI Status Correction

- App artifact copy actions should not say `Copied ...` unless
  `NSPasteboard.setString` returns true (FLA-008).
- App command construction should distinguish verified executable paths from
  unverified path strings, especially before launch/validation controls become
  active (FLA-007).
- Native app release probe status should separate "window visible" from
  "required labels verified" (FLA-004).

## Remaining Uncertainty

- This was a targeted fail-loud audit, not a line-by-line proof of every source
  file. The scan prioritized realtime audio, UDP/P2P/NAT, LoLa connector,
  app/runtime status, shell release probes, process cleanup, and tests around
  those areas.
- Some cleanup paths cannot be fully classified without injectable Core Audio,
  AVFoundation, process, and pasteboard adapters. Those findings are based on
  ignored return values and missing report/status fields in the current code.
- `try?` and `continue` are sometimes correct for parser loops and cleanup
  best-effort code. Findings above are limited to places where the surrounding
  report, UI, or script can create a stronger success impression than the code
  proves.
- Tests already cover several fail-loud areas well, especially app validation
  failure on missing/malformed reports, external connector process cleanup
  failures, Python runtime worker cleanup, and report validators rejecting false
  PASS fixtures. The remaining gaps are the specific hidden-failure paths listed
  above.
