# Fail-Loud Audit

Date: 2026-05-16

Scope: code paths that can claim, imply, or surface success for runtime,
validation, UI, release-hygiene, process, UDP, and LoLa connector workflows
without enough evidence. This is an audit-only document; no production code or
tests were changed.

Method: searched Swift, Python, and shell code for optimistic status, PASS
labels, swallowed errors, ignored return values, cleanup suppression, ambiguous
booleans, and failure-path tests. Then inspected representative callers and
tests for the highest-risk surfaces.

## Findings

### FLA-001: App stop finalizes a report before process exit is observed

- ID: FLA-001
- File: `Sources/open-lola-app/AppExecutionController.swift`
- Symbol / function / flow: `AppExecutionController.stop()`
- Evidence: `stop()` sets `stopWasRequested`, calls `process.terminate()`, sets
  status to `Stop requested.`, and immediately calls `finishReport(stopRequested:
  true)` before the termination handler records `lastExitCode` or closes output
  handles. The termination handler later records the exit code and calls
  `finishReport` again.
- What success is claimed: the app creates a finished execution report for a
  stopped run.
- What is actually proven: only that termination was requested.
- Missing failure/uncertainty signal: no report field or phase distinguishes
  `termination requested` from `process exited and logs closed`.
- Runtime or user impact: the operator can see a finished report while the child
  process is still running, hung, or failing teardown.
- Suggested remediation: make stop completion a distinct pending state until the
  termination handler observes exit, or include explicit `terminationPending` /
  `terminationObserved` evidence in the report.
- Test needed: an app-controller test that starts a long-running process, calls
  `stop()`, and asserts the report is not final or is explicitly pending until
  process termination is observed.
- Verification needed: targeted app shell tests plus a manual app stop of a real
  long-running command with report inspection.
- Confidence: high

### FLA-002: App validation start failure can leave validation without completion

- ID: FLA-002
- File: `Sources/open-lola-app/AppExecutionController.swift`
- Symbol / function / flow: `runOneShot(arguments:completion:)`
- Evidence: if `ManagedProcessRunner.start` throws, `runOneShot` sets
  `lastError`, `status = "Validation failed to start."`, and
  `phase = .validationFailed`, but it does not call the completion closure and
  does not set `lastValidationExitCode`.
- What success is claimed: the app moves to a validation-failed UI state.
- What is actually proven: validation never launched.
- Missing failure/uncertainty signal: the final validation result path may not
  receive an exit-code-like failure, so callers cannot uniformly distinguish
  `validation ran and failed` from `validation never started`.
- Runtime or user impact: UI state can be failed while report fields and
  validation completion paths remain incomplete or stale.
- Suggested remediation: route start failure through the same completion/report
  path with an explicit `launchFailed` validation status rather than relying on
  phase/status strings alone.
- Test needed: an app-controller validation test using a missing validator
  executable that asserts status, phase, validation exit evidence, error log, and
  report state.
- Verification needed: targeted `AppShellBehaviorTests` or equivalent app shell
  test filter.
- Confidence: medium

### FLA-003: Internal LoLa executable preflight reports PASS while nothing was launched

- ID: FLA-003
- File: `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorExecutablePreflight.swift`
- Symbol / function / flow: `lolaInternalProbe()`
- Evidence: the LoLa internal probe sets `requiredForAudioVideo: true`,
  `launched: false`, `detectedIdentity: .internalLoLa`, and `verdict: .pass`.
  The report note says executable identity checks are not endpoint
  interoperability evidence.
- What success is claimed: executable preflight PASS for the LoLa connector.
- What is actually proven: no external executable is required for this internal
  connector path.
- Missing failure/uncertainty signal: the result type cannot distinguish
  `passed because executable launched and matched` from `not applicable because
  no executable exists`.
- Runtime or user impact: operators or downstream validators can read a PASS as
  launch readiness even though `launched` is false.
- Suggested remediation: add an explicit probe status such as `notRequired` or
  `internalPath`, and keep aggregate PASS only for probes whose evidence class is
  clear.
- Test needed: preflight report tests that assert internal LoLa is not serialized
  as a launched executable pass and that aggregate wording remains scoped.
- Verification needed: focused `ExternalConnectorExecutablePreflightTests`.
- Confidence: high

### FLA-004: Swift external connector process cleanup hides wait/kill failures

- ID: FLA-004
- File: `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift`
- Symbol / function / flow: `waitForExternalConnectorProcess`,
  `terminateExternalConnectorProcessGroup`, `cleanupExternalConnectorProcessGroup`
- Evidence: the wait result at the duration deadline is ignored; SIGTERM and
  SIGKILL return values are ignored; cleanup ignores the final wait result and
  any forced kill result. `RunningExternalConnectorProcess` maps `ECHILD` to
  `Int32.min`, which then flows into process results as an exit status.
- What success is claimed: a process result reports launched, exit status, and
  `terminatedAfterDuration`.
- What is actually proven: the runner attempted wait and cleanup operations.
- Missing failure/uncertainty signal: no cleanup status, signal status, or
  `unknownExitStatus` state is propagated.
- Runtime or user impact: a connector run can look cleanly bounded while process
  group cleanup failed or exit status was unknown.
- Suggested remediation: return a structured process lifecycle result with
  launch, deadline, termination signal, kill, wait, cleanup, and exit-status
  evidence.
- Test needed: process-group tests that simulate or isolate failed kill/wait
  outcomes and assert visible uncertainty in the report.
- Verification needed: focused `ExternalConnectorProcessGroupTests`.
- Confidence: high

### FLA-005: ManagedProcessRunner suppresses teardown errors and final wait result

- ID: FLA-005
- File: `Sources/OpenLolaCore/Support/ManagedProcessRunner.swift`
- Symbol / function / flow: `ManagedProcess.killImmediately`,
  `ManagedProcess.closeOutputHandles`, `ManagedProcessRunner.terminate`
- Evidence: `killImmediately()` ignores the `kill` return value,
  `closeOutputHandles()` uses `try?`, and `terminate()` ignores the second
  `waitUntilExit` result after SIGKILL.
- What success is claimed: process termination utility completes without error.
- What is actually proven: terminate/kill/close operations were attempted.
- Missing failure/uncertainty signal: callers receive no indication that kill,
  handle close, or post-kill wait failed.
- Runtime or user impact: app and CLI flows can clear process state and write
  final reports despite incomplete teardown evidence.
- Suggested remediation: keep the nonblocking API where needed, but return or
  log structured teardown evidence for callers that create user-visible reports.
- Test needed: unit tests around `terminate` that assert failed post-kill wait or
  close failures are surfaced through a result type.
- Verification needed: focused `ManagedProcessRunnerTests`.
- Confidence: high

### FLA-006: Python connector process cleanup is caller-invisible

- ID: FLA-006
- File: `linux_connector/lola_connector/backends.py`
- Symbol / function / flow: `ManagedProcessCapture._close_process`
- Evidence: terminate, wait, kill, and wait-after-kill `OSError`s are logged at
  debug level as suppressed cleanup failures; `self.process` is then set to
  `None` in `finally`.
- What success is claimed: the capture backend has no active process after
  cleanup.
- What is actually proven: cleanup was attempted and the local handle was
  cleared.
- Missing failure/uncertainty signal: callers do not receive a cleanup result or
  visible warning when the process could not be terminated or waited.
- Runtime or user impact: Linux connector runtime can proceed as if a backend is
  closed while the external process state is uncertain.
- Suggested remediation: return cleanup status or accumulate cleanup warnings in
  runtime stats/report output.
- Test needed: extend existing process-runtime tests beyond debug-log assertions
  to assert caller-visible cleanup uncertainty.
- Verification needed: `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p
  no:cacheprovider linux_connector`.
- Confidence: high

### FLA-007: UDP loopback treats invalid or unreachable echo as ordinary loss

- ID: FLA-007
- File: `Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSocketRunners.swift`
- Symbol / function / flow: `runSenderLoop`, `waitForConnectedEcho`,
  `runLooperLoop`
- Evidence: sender decode uses `try?`; `waitForConnectedEcho` silently continues
  past malformed or wrong-sized datagrams and returns `nil` for fatal connected
  UDP receive errors; looper decode uses `try?` and records only
  `non-pcm-datagram-ignored`.
- What success is claimed: loopback metrics report echoed, lost, byte-exact, and
  RTT values.
- What is actually proven: valid echoes were counted, but invalid echoes and
  fatal receive errors are not separated from timeout/loss in the sender
  summary.
- Missing failure/uncertainty signal: no counters for malformed echoes,
  wrong-sized echoes, fatal connected receive errors, or ignored non-PCM packets
  in the sender-facing report.
- Runtime or user impact: a route with active bad traffic or ICMP errors can
  look like simple packet loss instead of a protocol or connectivity failure.
- Suggested remediation: add explicit counters and notes for malformed echo,
  wrong-size echo, and fatal connected receive error.
- Test needed: socket-loopback tests that inject malformed echo payloads and
  assert report-visible malformed/uncertain status.
- Verification needed: focused UDP loopback tests plus local loopback smoke.
- Confidence: medium-high

### FLA-008: Continuous UDP route localhost smoke ignores receiver completion timeout

- ID: FLA-008
- File: `Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift`
- Symbol / function / flow: `UdpPcmContinuousRouteLocalhostSmoke.run`
- Evidence: after sending packets, the code ignores `_ = done.wait(timeout:
  .now() + 2)` and then reads `receiverBox.result()`, which only reports whether
  the receiver stored a result.
- What success is claimed: localhost continuous route smoke returns a receiver
  report.
- What is actually proven: if a result exists, the receiver produced a report;
  the ignored wait result does not prove the receiver completed within the
  intended join deadline.
- Missing failure/uncertainty signal: no explicit `receiverJoinTimedOut` state.
- Runtime or user impact: a stalled or late receiver can be reported as generic
  receive timeout rather than a concurrency/teardown failure.
- Suggested remediation: check the `done.wait` result and throw or record a
  distinct receiver completion timeout before reading the box.
- Test needed: a localhost smoke test with an intentionally blocked receiver
  path that asserts the specific join-timeout failure.
- Verification needed: focused `UdpPcmContinuousReceiverTests` and route report
  tests.
- Confidence: medium

### FLA-009: Continuous UDP receiver can accept caller-provided PASS despite receive errors

- ID: FLA-009
- File: `Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift`
- Symbol / function / flow: `runReceiverLoop`, `collectReceiverMetrics`
- Evidence: packet mode mismatches increment `receiveErrors`, but
  `runReceiverLoop` assigns `verdict: configuration.verdict` directly instead
  of deriving or downgrading verdict from receive errors, lost packets, or zero
  packets.
- What success is claimed: the receiver report verdict can be PASS if the caller
  supplied PASS.
- What is actually proven: the report contains metrics; the verdict is not
  proven by local failure counters in this function.
- Missing failure/uncertainty signal: no local guard prevents PASS with
  `receiveErrors > 0`, high loss, or no received packets.
- Runtime or user impact: a caller bug or optimistic config can promote a bad
  receiver run to PASS.
- Suggested remediation: add verdict validation or derivation that blocks PASS
  unless counters satisfy explicit acceptance criteria.
- Test needed: route receiver tests that force receive errors or zero valid
  packets with a PASS configuration and assert rejection or downgrade.
- Verification needed: focused `UdpPcmContinuousReceiverTests` and route report
  validation tests.
- Confidence: medium-high

### FLA-010: LoLa status probe collapses timeout and negative status into `false`

- ID: FLA-010
- File: `linux_connector/lola_connector/connector.py`
- Symbol / function / flow: `LolaConnector.check_status`,
  `_receive_control_until`
- Evidence: `check_status` returns `True` only for
  `MESG_CHECKLOLASTATUS_ACK`; timeout returns `False`; malformed control
  datagrams are ignored after warning in `_receive_control_until`.
- What success is claimed: a boolean status answer.
- What is actually proven: either an ACK was observed or no ACK was observed
  before timeout.
- Missing failure/uncertainty signal: timeout, malformed traffic, wrong peer,
  and explicit negative conditions are all collapsed into `False`.
- Runtime or user impact: callers cannot distinguish `peer says not ready`,
  `no response`, `malformed response`, or `wrong source`.
- Suggested remediation: replace the boolean with a small result type carrying
  `ack`, `timeout`, `malformedCount`, `wrongPeerCount`, and elapsed time.
- Test needed: connector tests for timeout, malformed response, wrong-peer
  response, and successful ACK.
- Verification needed: focused linux connector pytest tests.
- Confidence: high

### FLA-011: Release hygiene scripts print unscoped `VERDICT: PASS`

- ID: FLA-011
- File: `scripts/export-release-candidate.sh`,
  `scripts/verify-release-hygiene.sh`
- Symbol / function / flow: release candidate export and hygiene verification
- Evidence: `export-release-candidate.sh` prints that product release readiness
  remains PARTIAL, then prints `VERDICT: PASS`; `verify-release-hygiene.sh`
  prints `VERDICT: PASS` even when no release candidate is supplied and only the
  live checkout residue scan ran. Tests assert the generic PASS string.
- What success is claimed: PASS.
- What is actually proven: export/hygiene checks passed for the specific script
  mode that ran.
- Missing failure/uncertainty signal: the PASS line itself does not name the
  evidence class, and one mode explicitly says a candidate path is needed for a
  fuller release-boundary scan.
- Runtime or user impact: CI logs or copied snippets can be misread as product
  release PASS despite the project-wide PARTIAL status.
- Suggested remediation: scope the verdict text, for example
  `HYGIENE_VERDICT: PASS` or `SOURCE_CANDIDATE_HYGIENE: PASS`, and keep the
  product PARTIAL line.
- Test needed: update release artifact hygiene tests to assert scoped verdicts
  and absence of product-level PASS.
- Verification needed: focused `ReleaseArtifactHygieneContractTests` plus
  `bash scripts/verify-release-hygiene.sh`.
- Confidence: high

### FLA-012: Failure-behavior test coverage is uneven around cleanup and UI stop

- ID: FLA-012
- File: `Tests/OpenLolaCoreTests`, `linux_connector/tests`
- Symbol / function / flow: failure-path coverage for app stop, process cleanup,
  UDP malformed/loss handling, and release PASS labels
- Evidence: existing tests cover important failure gates, including app
  validation evidence incompleteness, external connector early-exit handling,
  malformed LoLa control, malformed media counters, and release hygiene output.
  The inspected test inventory did not show coverage that asserts app stop waits
  for termination evidence, Swift process cleanup failures become
  caller-visible, UDP loopback malformed echoes are report-visible, or release
  PASS labels are scoped to hygiene rather than product readiness.
- What success is claimed: current tests verify many happy and failure paths.
- What is actually proven: selected failure modes are covered; cleanup,
  stop-finalization, and ambiguity regressions remain weak.
- Missing failure/uncertainty signal: no executable test currently fails if
  these ambiguous states remain ambiguous.
- Runtime or user impact: future changes can preserve false-success behavior
  while maintaining a green test suite.
- Suggested remediation: add behavior tests for the specific failure signals in
  FLA-001, FLA-004, FLA-007, and FLA-011 before changing implementations.
- Test needed: focused tests per finding, using behavior/result assertions
  rather than source-text guards.
- Verification needed: targeted tests first, then the broader matrix from
  `docs/testing/README.md` when implementation begins.
- Confidence: high

## Existing Fail-Loud Patterns Worth Preserving

- App validation does not mark validation passed unless runtime evidence exists;
  malformed or partial supervisor/external reports become validation failures.
- External connector session reports convert LoLa media/control runtime errors,
  process start failure, early exit with status 0, and nonzero process exit into
  failed report state.
- UDP media transport counts malformed datagrams in transport metrics before
  throwing decode errors.
- Public status documentation keeps the product verdict at PARTIAL and warns not
  to promote synthetic/local evidence to product PASS.

## Highest-Risk False-Success Paths

1. App stop report finalization before process exit is observed.
2. Generic release-hygiene `VERDICT: PASS` labels that can be detached from the
   surrounding PARTIAL caveat.
3. Internal LoLa executable preflight PASS with `launched: false`.
4. Continuous UDP receiver accepting caller-provided PASS despite local error
   counters.

## Places Needing Explicit Result Types/Counts/Status

- App process stop lifecycle: requested, signal sent, exited, logs closed,
  cleanup failed.
- External connector process lifecycle: wait, timeout, SIGTERM, SIGKILL,
  cleanup, unknown exit status.
- UDP loopback sender: malformed echo count, wrong-size echo count, fatal
  connected receive errors.
- LoLa status probe: ACK, timeout, malformed count, wrong-peer count, dialects
  attempted.
- Release scripts: scoped verdict labels that identify the evidence class.

## Places Needing Better Error Propagation

- Swift process cleanup and handle-close failures.
- Python backend terminate/wait/kill cleanup failures.
- App validation process start failures.
- UDP loopback receive/decode failures that are currently downgraded to generic
  loss or debug-only events.

## Places Needing UI Status Correction

- `Stop requested.` should not imply a final stopped report until process exit
  is observed or the report says termination remains pending.
- Validation start failure should surface as `validation did not launch`, not
  only a generic validation failed state.
- Any UI surface that displays release/script PASS output should include the
  scoped evidence class and product PARTIAL caveat.

## Remaining Uncertainty

- This audit inspected representative high-risk surfaces rather than every
  source file line-by-line.
- I did not execute runtime probes, so findings are based on source and test
  evidence only.
- I did not inspect every UI view that renders app controller state; UI impact is
  inferred from controller status/report behavior.
- Some cleanup failures are hard to trigger deterministically on macOS; proposed
  tests may need injectable process abstractions or isolated helper binaries.
- Broad Swift and Python verification was intentionally not run before writing
  this audit document because no production code or tests were changed.
