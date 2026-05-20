# Fail-Loud Audit

Audit for false success, hidden uncertainty, swallowed failures, and claims
that something worked without proof.

**Scope**: All Swift sources under `Sources/` and `Sources/open-lola-app/`.
**Hard rules**: No code changes. No test changes. Observation only.
**Date**: 2025-07

---

## Findings

---

### FL-01 — Silent second concurrent transmit error

| Field | Detail |
|-------|--------|
| **ID** | FL-01 |
| **File** | `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaLive.swift` |
| **Symbol** | `LoLaLiveTransmitErrors`, lines 74–117; `errors.first` at line 324 |
| **Evidence** | `LoLaLiveTransmitErrors` collects errors via `append(_:)` from two concurrent `DispatchQueue` blocks (audio TX loop and video TX loop). After `group.wait()`, only `errors.first` is thrown. If both loops fail, only the first appended error surfaces. |
| **What success is claimed** | Caller sees one thrown error and concludes "transmit failed for this reason." |
| **What is actually proven** | At most one failure reason is propagated. A second concurrent error (e.g., video loop also failed) is permanently discarded. |
| **Missing signal** | There is no multi-error surface. Second-or-later failures are invisible to the report, to the verdict, and to logs. |
| **Runtime / user impact** | A bidirectional live run where both audio and video transmit loops fail shows only one failure. Post-mortem diagnosis may be incorrect or incomplete. Release evidence cannot rely on "only one error" meaning "only one thing broke." |
| **Suggested remediation** | Throw an aggregate error (e.g., `AggregateError([Error])`) or collect all errors and include all messages in the thrown value. |
| **Test needed** | Inject failure into both audio and video dispatch queues simultaneously; assert both error messages appear in the thrown error. |
| **Verification** | `swift test --filter LoLaCompatibilityUdpMediaLiveTests` (if such a test is added). |
| **Confidence** | High — code path is explicit. |

---

### FL-02 — Video reassembly failure silently becomes "zero failures"

| Field | Detail |
|-------|--------|
| **ID** | FL-02 |
| **File** | `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibilityRunner.swift` |
| **Symbol** | `countVideoFrameReassemblyFailures`, line 376 |
| **Evidence** | `let videoFragments = (try? UltraGridCompatibility.recoverVideoFragments(from: videoPackets)) ?? []`. If `recoverVideoFragments` throws, `videoFragments` is `[]`. The subsequent loop iterates over an empty array and returns `count = 0`. |
| **What success is claimed** | The report records `0` video reassembly failures. |
| **What is actually proven** | Nothing: `0` is indistinguishable from "recovery itself failed" vs. "recovery succeeded and found no failures." |
| **Missing signal** | The recovery error is swallowed. The report field `videoFrameReassemblyFailureCount: 0` cannot be trusted when recovery throws. |
| **Runtime / user impact** | A report may claim clean video reassembly when the reassembly function itself threw, meaning no frames were ever examined. This directly undermines the validity of any video evidence claim. |
| **Suggested remediation** | Either propagate the throw (make the function `throws`), or record a distinct "recovery failed" state separate from "zero counted failures." |
| **Test needed** | Inject a throwing `recoverVideoFragments`; assert the report does not claim `0` failures and instead records an error. |
| **Verification** | `swift test --filter UltraGridCompatibilityRunnerTests` |
| **Confidence** | High — the `?? []` pattern is unambiguous. |

---

### FL-03 — SIGTERM failure always silent in process group termination

| Field | Detail |
|-------|--------|
| **ID** | FL-03 |
| **File** | `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift` |
| **Symbol** | `terminateExternalConnectorProcessGroup`, lines 197, 199, 209 |
| **Evidence** | `_ = kill(-running.processGroupIdentifier, SIGTERM)` at line 197 — result discarded. `_ = externalConnectorWaitForExit(...)` at line 199 — result discarded. `_ = kill(-running.processGroupIdentifier, SIGKILL)` at line 209 — result discarded. All three signal and wait results are unconditionally ignored. |
| **What success is claimed** | `terminateExternalConnectorProcessGroup` implicitly signals that it attempted graceful shutdown. |
| **What is actually proven** | Signals may have failed at the OS level (no such process group, EPERM, etc.) without any indication. The subsequent `cleanupExternalConnectorProcessGroup` call DOES check SIGKILL and returns `"failed: SIGKILL..."`, but only for a *second* SIGKILL in the cleanup path, not for the termination-path signals. |
| **Missing signal** | No tracking for SIGTERM failure or the SIGKILL inside `terminateExternalConnectorProcessGroup`. |
| **Runtime / user impact** | If the external connector process group is already dead (e.g., crashed before termination), signals fail silently. Post-run reports may indicate "completed" or "forced-kill" without this context. No user-visible indicator that termination signals did not reach the process. |
| **Suggested remediation** | Log or record errno from `kill()` calls inside `terminateExternalConnectorProcessGroup`. Return a richer status struct from that function. |
| **Test needed** | Mock a dead process group; assert that signal failure is recorded in the run result or logs. |
| **Verification** | `swift test --filter ExternalConnectorProcessRunnerTests` |
| **Confidence** | High — all `kill()` return values are explicitly discarded with `_ =`. |

---

### FL-04 — Core Audio graph cleanup result discarded at two call sites

| Field | Detail |
|-------|--------|
| **ID** | FL-04 |
| **File 1** | `Sources/OpenLolaCore/Connectors/LoLa/LoLaCoreAudioLiveBridge.swift`, line 139 |
| **File 2** | `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift`, line 316 |
| **Symbol** | `DirectPeerRealtimeAudioGraph.stop()` — annotated `@discardableResult` |
| **Evidence** | `graph.stop()` (LoLaCoreAudioLiveBridge) and `audioGraph.stop()` (DirectPeerSessionAVSocketRunner) are called as void expressions. `stop()` returns `DirectPeerRealtimeAudioGraphCleanupResult` which contains `failures: [DirectPeerRealtimeAudioGraphCleanupFailure]`, each recording an operation name and `OSStatus`. Both call sites compile without warnings because of `@discardableResult`. |
| **What success is claimed** | The audio graph was stopped and the device was cleaned up. |
| **What is actually proven** | The stop path ran. Whether any of the Core Audio cleanup operations (`AudioDeviceStop`, `AudioDeviceDestroyIOProcID`, sample rate restore, buffer size restore) failed is completely unknown at these call sites. |
| **Missing signal** | Core Audio stop/destroy/restore failures vanish. No error is logged, no report field is set, no verdict is downgraded. |
| **Runtime / user impact** | A realtime audio session that failed to restore the device's original sample rate or buffer size would leave the device in a degraded state, affecting subsequent runs and other apps. The report would not reflect this. |
| **Suggested remediation** | Capture and log the cleanup result at both call sites. If any `failures` are present, record them in the session report or post-run evidence. Consider removing `@discardableResult` to force explicit handling. |
| **Test needed** | Mock `AudioDeviceStop` to return a non-zero `OSStatus`; assert the `CleanupResult` is non-empty and visible in the callers. |
| **Verification** | Code review of both call sites. `swift test --filter DirectPeerRealtimeAudioGraphTests` |
| **Confidence** | High — `@discardableResult` makes the silent discard explicit. |

---

### FL-05 — AudioDeviceDestroyIOProcID / AudioDeviceStop OSStatus discarded in cleanup paths

| Field | Detail |
|-------|--------|
| **ID** | FL-05 |
| **File 1** | `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`, line 249 |
| **File 2** | `Sources/OpenLolaCore/Release/RecordingSessionLiveCapture.swift`, lines 95, 105 |
| **Symbol** | `makeAndStartIOProc` startup error path; `RecordingSessionLiveCapture` defer block |
| **Evidence** | In `DirectPeerRealtimeAudioGraph`, when `AudioDeviceStart` fails (startup error path), the cleanup calls `_ = AudioDeviceDestroyIOProcID(deviceID, createdIOProcID)`. In `RecordingSessionLiveCapture`, the `defer` block calls `_ = AudioDeviceDestroyIOProcID(...)` and `_ = AudioDeviceStop(...)`. In both cases the `OSStatus` is explicitly discarded. |
| **What success is claimed** | On startup failure, the half-started graph's IOProcID was destroyed. After recording, the device was stopped and the IOProcID destroyed. |
| **What is actually proven** | The cleanup calls were made. Success is not verified. If cleanup fails, the device may be left running or the IOProcID may leak. |
| **Missing signal** | Secondary cleanup failure after a primary failure is completely invisible. The caller only sees the original start error; any compound failure state is lost. |
| **Runtime / user impact** | A leaked IOProcID could affect device state for subsequent sessions, impact other Core Audio clients, or cause device errors on next run. |
| **Suggested remediation** | Log the cleanup `OSStatus` in error paths. In `RecordingSessionLiveCapture`, at minimum log failures to `os_log`. |
| **Test needed** | Inject a failing `AudioDeviceDestroyIOProcID`; assert the failure is surfaced as a log entry or secondary error. |
| **Verification** | Inspection only without Core Audio mocking infrastructure. |
| **Confidence** | High — `_ =` usage is unambiguous. |

---

### FL-06 — `.partial` conflates "ran OK with incomplete evidence" and "no detected error"

| Field | Detail |
|-------|--------|
| **ID** | FL-06 |
| **Files** | `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRunner.swift` (lines 95, 210); `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibilityRunner.swift` (line 108); `Sources/OpenLolaCore/Connectors/JackTrip/JackTripCompatibility.swift` (line 621) |
| **Symbol** | `runtimeError == nil ? .partial : .fail` (three separate instances) |
| **Evidence** | All three connectors assign `verdict: runtimeError == nil ? .partial : .fail`. This makes `.partial` both the outcome for "ran without any detected error but PASS is not yet earned" and the outcome for "the run completed without error." |
| **What success is claimed** | `.partial` is the honest admission that PASS is not yet proven — which is correct. |
| **What is actually proven** | `.partial` cannot be distinguished from "ran OK without any detected runtime error" versus "ran OK but has potential undetected issues." A future verdict consumer cannot tell the difference. |
| **Missing signal** | There is no `verdictReason` or `runtimeErrorFree: Bool` alongside `.partial` to clarify whether the run was error-free. |
| **Runtime / user impact** | Report consumers and release tooling treat all `.partial` verdicts as "not passing," which is correct behavior. The risk is diagnostic: a `.partial` result for a clean 2-peer run versus a `.partial` for a run with silent socket failures looks identical in the report. This makes debugging harder and creates false confidence when a clean partial run is compared to a problematic partial run. |
| **Suggested remediation** | Add a `runtimeErrorMessage: String?` or separate `runtimeErrorFree: Bool` field to distinguish these two partial sub-states. Alternatively, define `.partialClean` and `.partialUnknown` if the type is internal. |
| **Test needed** | Assert that a run producing a runtime error and a run producing no runtime error produce distinguishable report fields even when both have `.partial` verdict. |
| **Verification** | Inspect all callers of `MeasurementVerdict` to find whether any downstream logic relies on the clean/unclean distinction. |
| **Confidence** | Medium — the ambiguity is documented by design (`PASS remains blocked until...` notes), but the signal loss is real. |

---

### FL-07 — LoLa TX report with zero bytes sent does not fail

| Field | Detail |
|-------|--------|
| **ID** | FL-07 |
| **File** | `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMedia.swift`, lines 270–280 |
| **Symbol** | `transmitReport(configuration:socket:address:)`, `sentByteCounts.reduce(0, +)` |
| **Evidence** | `transmitReport` assembles a report from transmitted datagrams and calls `makeLoLaMediaSessionReport(...)` with default `verdict: .partial`. The total sent bytes (`sentByteCounts.reduce(0, +)`) appears only in the `notes` string. There is no guard that fails the report when total sent bytes is zero. |
| **What success is claimed** | TX run returned `.partial` (expected for a real-link run without a responding Windows LoLa peer). |
| **What is actually proven** | The TX function ran and assembled a report. Whether any bytes actually traversed the socket is only visible in notes text, not in the verdict or in a structured field. |
| **Missing signal** | A run where all UDP `sendto` calls appeared to succeed but the socket silently dropped every packet (e.g., buffer full, ICMP unreachable swallowed) would produce `sentBytesTotal = 0` in the notes with `.partial` verdict — indistinguishable from a run where transmit worked. |
| **Runtime / user impact** | False confidence in TX evidence. Zero-byte-sent runs look like normal partial runs. |
| **Suggested remediation** | Add a structured `sentBytesTotal: Int` field to the report. Downgrade to `.fail` or add a `runtimeError` when `sentBytesTotal == 0` after a non-dry-run. |
| **Test needed** | Inject a socket mock that always succeeds but reports zero sent bytes; assert the verdict or a structured field reflects the anomaly. |
| **Verification** | `swift test --filter LoLaCompatibilityUdpMediaTests` |
| **Confidence** | Medium — the pattern is observable; whether zero-byte-sent is operationally reachable depends on platform socket behavior. |

---

### FL-08 — Corrupt report file treated as "no evidence"

| Field | Detail |
|-------|--------|
| **ID** | FL-08 |
| **File** | `Sources/open-lola-app/AppLatencyHeroMetrics.swift`, line 37 |
| **Symbol** | `AppLatencyHeroMetrics.load(from:sessionToken:)` |
| **Evidence** | `guard let data = try? BoundedFileReader.data(atPath: path) else { return nil }` and `guard let decoded = try? DirectPeerTwoPeerLocalRunReport.decode(from: data) else { return nil }`. Both I/O and JSON decode failures silently produce `nil`. |
| **What success is claimed** | `nil` return means "no evidence is present." |
| **What is actually proven** | Either the file does not exist OR the file exists and is unreadable/corrupt. Both outcomes produce `nil`. The UI/session state shows "awaiting evidence" for both cases. |
| **Missing signal** | A mid-write crash producing a partially written report, disk I/O error, or JSON format regression would be invisible to the user. The user sees "awaiting evidence" with no indication the file is damaged. |
| **Runtime / user impact** | If a run completes and writes a corrupt report, the user cannot distinguish "run did not produce evidence" from "run produced evidence but it is damaged." Repeated runs under a damaged-report condition would all appear to produce no evidence. |
| **Suggested remediation** | Return `Result<AppLatencyHeroMetrics?, LoadError>` or distinguish between `nil` (file absent) and an error case (file present but unreadable/corrupt). Surface the error in the UI. |
| **Test needed** | Write a corrupt JSON file to the report path; assert the UI or session state distinguishes "evidence corrupt" from "evidence absent." |
| **Verification** | `swift test --filter AppLatencyHeroMetricsTests` |
| **Confidence** | High — both `try?` silences are explicit. |

---

### FL-09 — Session token I/O error treated as token mismatch

| Field | Detail |
|-------|--------|
| **ID** | FL-09 |
| **File** | `Sources/open-lola-app/AppRuntimeEvidenceScope.swift`, line 71 |
| **Symbol** | `sessionTokenMatches(_:evidenceURL:)` |
| **Evidence** | `try? String(contentsOf: sessionTokenURL(...))` — if reading the session token file fails for any reason (permission denied, sandboxing restriction, disk full), the result is `nil`, and `nil != token` is `true`, so `sessionTokenMatches` returns `false`. |
| **What success is claimed** | `false` means "session token does not match — this evidence is from a different run." |
| **What is actually proven** | Either the token file doesn't exist, or the token doesn't match, or there was an I/O error reading the file. All three map to `false`. |
| **Missing signal** | A file permission error or sandbox restriction looks identical to a stale evidence file. The user is told to run again when the real problem is a file system issue. |
| **Runtime / user impact** | A genuine I/O error permanently blocks `hasValidatedRuntimeEvidence` from returning `true` for the current run, causing the UI to show "awaiting evidence" indefinitely. The user has no signal that the problem is environmental, not behavioral. |
| **Suggested remediation** | Distinguish file-absent (`nil`) from file-read-error (throw). Return a `TokenMatchResult` enum: `.match`, `.mismatch(storedToken:)`, `.absent`, `.readError(Error)`. |
| **Test needed** | Mock `String(contentsOf:)` to throw a permissions error; assert `sessionTokenMatches` propagates a distinct error state, not `false`. |
| **Verification** | `swift test --filter AppRuntimeEvidenceScopeTests` |
| **Confidence** | High — `try?` on file I/O is explicit. |

---

### FL-10 — Release readiness file error returns `exists: false` with no detail

| Field | Detail |
|-------|--------|
| **ID** | FL-10 |
| **File** | `Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift`, line 275 |
| **Symbol** | `readText(_:repositoryRoot:)` |
| **Evidence** | `guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return (false, "") }`. Any error (file missing, encoding error, permission denied) returns `(exists: false, contents: "")`. The caller uses `exists: false` to determine that a required documentation file is absent. |
| **What success is claimed** | `exists: false` means the required file is not present. |
| **What is actually proven** | Either the file is absent, or it is present and failed to decode as UTF-8, or there was an I/O error. All three produce the same signal. |
| **Missing signal** | A present-but-corrupt or present-but-unreadable file is reported as "missing" in the release readiness check. The release can then falsely indicate a documentation gap when the real problem is a file system or encoding issue. |
| **Runtime / user impact** | Release readiness report incorrectly flags existing documentation as absent. Releases may be blocked by a phantom "missing docs" condition that is actually a UTF-8 encoding or permission problem. |
| **Suggested remediation** | Return a three-state result: `(exists: Bool, contents: String?, readError: Error?)`. Log or surface the error separately from the existence check. |
| **Test needed** | Write a non-UTF-8 file to a required doc path; assert `readText` does not silently return `(false, "")` but instead surfaces a read error. |
| **Verification** | `swift test --filter OpenSourceReleaseReadinessTests` |
| **Confidence** | High — `try?` is explicit. |

---

### FL-11 — Release manifest PASS check is a substring match

| Field | Detail |
|-------|--------|
| **ID** | FL-11 |
| **File** | `Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift`, line 247 |
| **Symbol** | `publicReleaseApproval` requirement check |
| **Evidence** | `ready: releaseManifest.exists && releaseManifest.contents.contains("Verdict: PASS")`. This checks whether the string `"Verdict: PASS"` appears anywhere in the manifest file. |
| **What success is claimed** | The release manifest has been approved with a PASS verdict. |
| **What is actually proven** | The manifest file contains the character sequence `"Verdict: PASS"` somewhere in its content. |
| **Missing signal** | A draft manifest with a comment like `# Target: Verdict: PASS`, a negation like `# Verdict: NOT PASS`, or any accidental occurrence of the substring would satisfy this check. There is no structured parse of the manifest. |
| **Runtime / user impact** | The release approval gate is bypassable by any unintentional or intentional occurrence of the magic string in the manifest file. This is a high-severity false-success risk for the release workflow. |
| **Suggested remediation** | Parse the manifest with a structured format (YAML, TOML, or a key-value pair like `^Verdict: PASS$` with anchoring). Alternatively, require a dedicated field in a structured manifest file. |
| **Test needed** | Write a manifest containing `"Verdict: PASS"` in a comment; assert the gate does not pass. Write a conforming manifest; assert the gate passes. |
| **Verification** | `swift test --filter OpenSourceReleaseReadinessTests` |
| **Confidence** | High — `.contains` is not semantically equivalent to "manifest declares PASS." |

---

### FL-12 — LoLa capture report: per-packet envelope errors downgraded to notes strings

| Field | Detail |
|-------|--------|
| **ID** | FL-12 |
| **File** | `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityCaptureReport.swift`, lines 81–84 |
| **Symbol** | `LoLaCompatibilityCaptureReport.buildReport`, catch block |
| **Evidence** | Non-`LoLaCompatibilityCaptureDecodeError` errors caught during per-packet processing are appended to `notes: ["LoLa media envelope check failed: \(error)"]`. The packet is emitted with `mediaEnvelopeValid: false` but the report verdict is not updated. Multiple such failures accumulate only as unstructured note strings. |
| **What success is claimed** | The report's `verdict` field reflects packet quality; per-packet errors in `notes` are informational. |
| **What is actually proven** | Only typed `LoLaCompatibilityCaptureDecodeError` cases influence the verdict. An unexpected error type from packet processing is silently downgraded to a note string and does not affect the overall verdict. |
| **Missing signal** | If a new packet-processing code path throws an unexpected error type, the report verdict will not reflect the failure. The `notes` strings are not machine-readable and are not part of the structured verdict signal. |
| **Runtime / user impact** | A systematic packet processing regression that throws a new error type would produce a report with `.partial` verdict and degraded `notes` text, rather than a `.fail` verdict. Automated pipeline checks on verdict would pass while real failures exist in the notes. |
| **Suggested remediation** | Track a count of unexpected packet errors; downgrade verdict to `.fail` if any are present. Or use a broader error type that includes "unexpected processing error." |
| **Test needed** | Inject a packet processing function that throws an unexpected error type; assert the report verdict is `.fail`, not `.partial`. |
| **Verification** | `swift test --filter LoLaCompatibilityCaptureReportTests` |
| **Confidence** | High — the catch block's behavior is explicit. |

---

### FL-13 — `closeOutputHandles()` return value discarded in AppExecutionController

| Field | Detail |
|-------|--------|
| **ID** | FL-13 |
| **File** | `Sources/open-lola-app/AppExecutionController.swift`, lines 552, 597, 794 |
| **Symbol** | `finished.closeOutputHandles()`, `process?.closeOutputHandles()` |
| **Evidence** | `ManagedProcess.closeOutputHandles()` returns `[ManagedProcessCleanupWarning]` documenting stdout/stderr handle close failures. All three call sites in `AppExecutionController` call `closeOutputHandles()` as a void expression and discard the returned warnings. |
| **What success is claimed** | Process output handles were closed after the run. |
| **What is actually proven** | The close was attempted. Failures are invisible. |
| **Missing signal** | If stdout or stderr handle close fails (e.g., underlying pipe already invalid), the warning is silently discarded. If the handle failure is significant (e.g., incomplete write flush), no post-run log or UI status reflects it. |
| **Runtime / user impact** | Log file corruption or truncated output from a failed handle close would be invisible. Users relying on stdout/stderr log paths for post-run debugging might see incomplete logs with no error context. |
| **Suggested remediation** | Log `ManagedProcessCleanupWarning` instances via `os_log`. The warnings are already structured; they just need a log call. |
| **Test needed** | Mock a failing file handle; assert cleanup warnings are logged. |
| **Verification** | `swift test --filter AppExecutionControllerTests`; also review `ManagedProcessRunner` test coverage. |
| **Confidence** | Medium — warnings may be benign in practice; the close failure path is possible but may be rare. |

---

### FL-14 — `_ = stopUnlocked()` in startup error path: cleanup result discarded

| Field | Detail |
|-------|--------|
| **ID** | FL-14 |
| **File** | `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`, line 202 |
| **Symbol** | `startUnlocked()`, startup error catch block |
| **Evidence** | When `makeAndStartIOProc` throws (e.g., `AudioDeviceStart` fails), the error recovery calls `_ = stopUnlocked()`. The `stopUnlocked()` return value is `DirectPeerRealtimeAudioGraphCleanupResult`, which is explicitly discarded. |
| **What success is claimed** | On startup failure, the partial graph was cleaned up before rethrowing the error. |
| **What is actually proven** | `stopUnlocked()` was called. Secondary cleanup failures (e.g., `AudioDeviceDestroyIOProcID` also fails) are invisible. The caller only sees the original start error. |
| **Missing signal** | A compound failure (start fails + cleanup fails) looks identical to a simple failure (start fails, cleanup succeeds). Device may be left in a half-stopped state. |
| **Runtime / user impact** | Compound startup-failure scenarios could leave the audio device in an inconsistent state that affects subsequent runs. No diagnostic information about the compound failure is available. |
| **Suggested remediation** | Store the cleanup result in `latestCleanupResult` unconditionally (it already is), but also log it or include it in the thrown error's context. |
| **Test needed** | Inject failures in both `AudioDeviceStart` and `AudioDeviceDestroyIOProcID`; assert the resulting error or log entry references both failures. |
| **Verification** | Inspection only without Core Audio mocking infrastructure. |
| **Confidence** | Medium — `latestCleanupResult` is stored inside `stopUnlocked` regardless (line 347), so callers that inspect the graph state can see it; the issue is that direct callers of the throwing `start()` path cannot easily retrieve it. |

---

### FL-15 — `AppSessionState.live` derivation is correctly gated (NOT a finding)

This was investigated and confirmed as not a false-success path.

- `.live` requires `lastExitCode == 0` AND `hasValidatedRuntimeEvidence`.
- For `.directMacPeer`: `hasValidatedRuntimeEvidence` requires the supervisor report to be present, non-partial (`supervisorVerdict != .partial`), and session token to match.
- For `.windowsLoLa`: requires `externalConnectorReport?.verdict == .pass`, which no current run path produces.
- The `.live` state is unreachable without genuine measured evidence.
- **Status**: No action needed.

---

## Summary

### 1. Highest-risk false-success paths

| ID | Risk | Reason |
|----|------|--------|
| FL-11 | **Critical** | Release manifest PASS gate is a substring match — bypassable by comment or coincidental string occurrence |
| FL-02 | **High** | Video reassembly failure produces "zero failures" count in report — direct evidence integrity issue |
| FL-08 | **High** | Corrupt run report treated as "no evidence" — user cannot distinguish damaged evidence from absent evidence |
| FL-07 | **High** | LoLa TX run with zero bytes sent returns `.partial` (no error) — zero-transmission and successful partial transmit are identical in the report |
| FL-12 | **High** | Per-packet LoLa capture errors downgraded to unstructured notes — systematic failures invisible to automated verdict checks |

---

### 2. Places needing explicit result types/counts/status

| ID | Symbol | What is needed |
|----|--------|----------------|
| FL-01 | `LoLaLiveTransmitErrors.errors` | All concurrent errors, not just `errors.first` |
| FL-06 | `MeasurementVerdict.partial` | Distinguish `runtimeErrorFree: Bool` alongside `.partial` verdict |
| FL-07 | `transmitReport` | Structured `sentBytesTotal` field; not just notes text |
| FL-12 | `LoLaCompatibilityCaptureReport` | Count of unexpected-error packets; must influence verdict |
| FL-10 | `readText(_:repositoryRoot:)` | Three-state: absent / present-and-readable / present-but-unreadable |

---

### 3. Places needing better error propagation

| ID | Symbol | What should propagate |
|----|--------|----------------------|
| FL-03 | `terminateExternalConnectorProcessGroup` | `kill(SIGTERM)` and `kill(SIGKILL)` errno should be recorded in the process run result |
| FL-04 | `LoLaCoreAudioLiveBridge.stop()`, `DirectPeerSessionAVSocketRunner.stop()` | `DirectPeerRealtimeAudioGraphCleanupResult` must be inspected, not discarded |
| FL-05 | `DirectPeerRealtimeAudioGraph` startup path, `RecordingSessionLiveCapture` defer | Secondary Core Audio cleanup errors should be logged or included in thrown error context |
| FL-09 | `sessionTokenMatches` | I/O error must not be mapped to `false`; needs its own error signal |
| FL-13 | `AppExecutionController.closeOutputHandles` | `[ManagedProcessCleanupWarning]` should be logged |
| FL-14 | `startUnlocked` startup error path | Secondary cleanup result should be logged alongside the primary start error |

---

### 4. Places needing UI status correction

| ID | Symbol | Issue |
|----|--------|-------|
| FL-08 | `AppLatencyHeroMetrics.load` → `hasValidatedRuntimeEvidence` | "Awaiting evidence" shown for both absent evidence AND corrupt evidence; user cannot act correctly |
| FL-09 | `sessionTokenMatches` | "Awaiting evidence" shown for both "stale evidence" AND "file system error"; user given wrong action |

No instances of `connected`, `streaming`, `healthy`, or `100%` UI status were found without runtime backing. `AppSessionState.live` is correctly gated (FL-15).

---

### 5. Remaining uncertainty

- **NAT keepalive JSON decode silences** (`NatFriendlyRouteRunner.swift:91`, `NatRendezvousRelayRunners.swift:144,216`): `try? JSONDecoder().decode(...)` silently ignores malformed keepalive/rendezvous messages. In a UDP context, dropping malformed packets may be intentional. Whether a systematic decode failure (e.g., format regression) is detectable in run metrics was not fully traced. _Confidence: low that this is a real risk; tagged for inspection._

- **UdpPcmLoopbackSocketRunners non-PCM datagram handling** (line 332): Non-PCM datagrams in the looper path are recorded as `"non-pcm-datagram-ignored"` in `DebugTrace` but not counted in any report metric. Whether this debug-only signal is sufficient depends on how `DebugTrace` events are consumed downstream. Not fully traced.

- **FL-06 downstream consequence**: Callers of `MeasurementVerdict.partial` were not exhaustively traced to determine whether any currently distinguishes "error-free partial" from "undetected-error partial." The risk is primarily diagnostic rather than operational. A full call-graph trace of `.partial` consumers would clarify whether ambiguity causes downstream behavioral differences.

- **`LoLaCompatibilityUdpMedia` expected datagram count**: `expectedDatagramCount` is stored in the report but not used in verdict determination. Whether receiving zero datagrams produces a `.fail` verdict was not fully confirmed. The `LoLaCompatibilityMediaSession.receiveReport` path returns `.fail` only when `malformedCount > 0`, not for short-packet runs. A receive run that times out returns via a separate `timeoutReport` path that uses `.fail`. The zero-datagrams-received-but-no-timeout case may still return `.partial`. This case was not fully exercised.

- **`AppExecutionController` phase after zero-datagram run**: `phase = .runFinished` is set based on `terminationStatus == 0`. Whether the supervisor process can exit with code 0 while producing zero datagrams and no runtime error was not traced end-to-end. This would produce a `.runFinished` phase alongside a `.partial` verdict — correct UI but ambiguous evidence signal.
