# Simplicity Remediation Plan

**Repository:** open-lola2
**Date:** 2026-05-19
**Source audit:** `docs/simplicity-test-certainty-audit.md`
**Hard rules:** No production code changed. No tests changed. Only this file created/updated.

This plan converts the 45 consolidated findings from the audit into independently
reviewable, verifiable remediation slices. Every slice has a clear outcome and rollback
strategy. Uncertain items get INVESTIGATION slices, not implementation slices.

---

## Slice Index

### Implementation slices

| ID | Priority | Title | Findings | Risk |
|----|----------|-------|----------|------|
| [R-01](#r-01) | P0 | Tighten release manifest PASS gate | C-FL-10 | Low |
| [R-02](#r-02) | P0 | Fix release readiness file read — 3-state result | C-FL-09 | Low |
| [R-03](#r-03) | P0 | Propagate video reassembly recovery failure | C-FL-02 | Low |
| [R-04](#r-04) | P0 | Count unexpected capture errors in LoLa verdict | C-FL-11 | Low |
| [R-05](#r-05) | P0 | Add DirectAudioMediaRouter routing tests | C-TI-09 | None |
| [R-06](#r-06) | P0 | Add concurrent RealtimeAudioPacketHandoff test | C-TI-12 | None |
| [R-07](#r-07) | P0 | Fix QuickConnect fallback CI coverage | C-TI-11 | Medium — blocked on I-06 |
| [R-08](#r-08) | P1 | Log Core Audio cleanup failures | C-FL-04, C-FL-05 | Low |
| [R-09](#r-09) | P1 | Disambiguate UI evidence state | C-FL-08 | Medium |
| [R-10](#r-10) | P1 | Aggregate LoLa TX concurrent errors | C-FL-01 | Low |
| [R-11](#r-11) | P1 | Fix LoLa TX zero-bytes verdict | C-FL-07 | Low |
| [R-12](#r-12) | P1 | Log SIGTERM/SIGKILL result in process cleanup | C-FL-03 | Low |
| [R-13](#r-13) | P1 | Document safety checklist; add gate test | C-MC-06 | Low |
| [R-14](#r-14) | P1 | Replace fabricated synthetic smoke metrics with sentinels | C-MC-07 | Medium |
| [R-15](#r-15) | P1 | Add UDP PCM payload correctness test | C-TI-04 | None |
| [R-16](#r-16) | P1 | Add sequence tracker wrap-around test | C-TI-13 | None |
| [R-17](#r-17) | P1 | Add reconnection continuity tests | C-TI-10 | Low |
| [R-18](#r-18) | P2 | Rewrite CapabilitySummary milestone snapshot test | C-TI-01 | Low |
| [R-19](#r-19) | P2 | Replace PRNG-fragile golden float test | C-TI-07 | Low |
| [R-20](#r-20) | P2 | Add `.partial` diagnostic field | C-FL-06 | Low |
| [R-21](#r-21) | P2 | Consolidate 10 `*RunMode` enums | C-MC-03 | Medium |
| [R-22](#r-22) | P2 | Remove empty `ReportValidationProtocol` | C-MC-01 | Medium |
| [R-23](#r-23) | P2 | Merge `ExternalConnectorPipeCapture` into `BoundedPipeCapture` | C-MC-05 | Low |
| [R-24](#r-24) | P3 | Delete `JSONReportCoder` | C-MC-12 | None |
| [R-25](#r-25) | P3 | Delete `UltraGridMediaFormatRegistry` | C-MC-13 | None |
| [R-26](#r-26) | P3 | Delete `CoreAudioFallbackIdentityCache` | C-MC-17 | None |
| [R-27](#r-27) | P3 | Inline `DebugTrace` single-use wrappers | C-MC-10 | None |
| [R-28](#r-28) | P3 | Move misplaced type definitions to correct files | C-MC-21, C-MC-22 | None |

### Investigation slices (must complete before acting on dependent implementation slices)

| ID | Title | Blocks | Findings |
|----|-------|--------|----------|
| [I-01](#i-01) | Confirm inventory-as-code CI gate status | R-29 (future) | C-MC-11 |
| [I-02](#i-02) | Confirm CapabilitySummary historical instance intent | R-30 (future) | C-MC-24 |
| [I-03](#i-03) | Confirm `RealtimeAudioBlockRing` callers | R-31 (future) | C-MC-20 |
| [I-04](#i-04) | Confirm `DebugTraceFieldPolicy.allowing` callers | R-32 (future) | C-MC-14 |
| [I-05](#i-05) | Map `SessionRunner` vs `SessionRuntime` split | R-33 (future) | C-MC-23 |
| [I-06](#i-06) | Map QuickConnect transport injection feasibility | R-07 | C-TI-11 |

---

## Implementation Slices

---

### R-01

**Title:** Tighten release manifest PASS gate — replace substring match with anchored line check

**Findings addressed:** C-FL-10

**Problem:**
`releaseManifest.contents.contains("Verdict: PASS")` passes for any occurrence of the string,
including inside a comment, prose negation, or accidental substring. This is the final approval
gate before a public release. A file containing `# Not ready: Verdict: PASS is not confirmed`
would pass the gate.

**Minimal fix strategy:**
Replace `.contains("Verdict: PASS")` with a line-level exact match:
```swift
releaseManifest.contents
    .components(separatedBy: "\n")
    .contains { $0.trimmingCharacters(in: .whitespaces) == "Verdict: PASS" }
```
No other logic in `publicReleaseApproval` needs to change. No schema change.

**Files likely affected:**
`Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift` (line 247, one-line change)

**Behavior affected:**
The gate now rejects a manifest where "Verdict: PASS" appears only in a comment or embedded in
prose. A correctly formatted manifest (`Verdict: PASS` on its own line) is unaffected.

**Tests to add:**
1. `releaseApproval_requiresVerdictPassOnItsOwnLine` — manifest with `"Verdict: PASS"` inside a
   comment → gate returns `ready: false`.
2. `releaseApproval_passesConformingManifest` — manifest with exactly `"Verdict: PASS"` alone on
   a line → gate returns `ready: true`.
3. `releaseApproval_rejectsMultiwordLineContainingVerdictPass` — `"# Verdict: PASS"` → gate
   returns `ready: false`.

**Verification commands:**
```bash
swift test --filter OpenSourceReleaseReadinessTests
swift build
```

**Risk level:** Low. The change tightens a check; no correctly formatted manifest is affected.

**Rollback strategy:** Revert the one-line change in `OpenSourceReleaseReadiness.swift`.

**Definition of Done:**
All three new tests pass. Existing `OpenSourceReleaseReadiness` tests pass. `swift build` clean.

---

### R-02

**Title:** Fix release readiness `readText` — distinguish file I/O error from absent file

**Findings addressed:** C-FL-09

**Problem:**
`guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return (false, "") }`
returns `(exists: false, contents: "")` for absent file, permission error, encoding error, and
disk failure alike. A present-but-unreadable required documentation file is misreported as
"missing," blocking a release with a phantom condition.

**Minimal fix strategy:**
Replace the `try?` collapse with explicit error discrimination:
```swift
func readText(_ path: String, repositoryRoot: URL) -> ReadTextResult {
    let url = repositoryRoot.appendingPathComponent(path)
    do {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return .found(contents)
    } catch CocoaError.fileReadNoSuchFile, CocoaError.fileNoSuchFile {
        return .absent
    } catch {
        return .readError(error)
    }
}
```
Where `ReadTextResult` is a `enum { case found(String); case absent; case readError(Error) }`.
Update all callers in `OpenSourceReleaseReadiness.swift` (estimated 3–5 call sites, all in the
same file) to treat `.readError` as a structured failure distinct from `.absent`.

**Files likely affected:**
`Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift` (definition + all internal callers)

**Behavior affected:**
Releases now fail with a distinct `readError` diagnostic when a required file is present but
unreadable, rather than silently reporting it as absent.

**Tests to add:**
1. `readText_returnsAbsentForMissingFile` — non-existent path → `.absent`.
2. `readText_returnsFoundForReadableFile` — real readable file → `.found(contents)`.
3. `readText_returnsReadErrorForUnreadableFile` — write a valid path, then inject a read error
   (non-UTF-8 bytes or permission change) → `.readError`.

**Verification commands:**
```bash
swift test --filter OpenSourceReleaseReadinessTests
swift build
```

**Risk level:** Low. Internal to `OpenSourceReleaseReadiness.swift`. No external callers confirmed.

**Rollback strategy:** Revert the `readText` function and all internal callers.

**Definition of Done:**
Three new tests pass. All existing release-readiness tests pass. `swift build` clean.

---

### R-03

**Title:** Propagate video reassembly recovery failure — stop returning "zero failures"

**Findings addressed:** C-FL-02

**Problem:**
`let videoFragments = (try? UltraGridCompatibility.recoverVideoFragments(from: videoPackets)) ?? []`
silently converts a recovery failure into an empty fragment array. The subsequent loop counts zero
reassembly failures because there are no fragments to check. The report claims "zero reassembly
failures" when the recovery function itself threw — no frames were examined.

**Minimal fix strategy:**
**Option A (preferred — minimal):** Add a separate Boolean output:
```swift
var videoRecoveryFailed = false
let videoFragments: [UltraGridVideoFragment]
do {
    videoFragments = try UltraGridCompatibility.recoverVideoFragments(from: videoPackets)
} catch {
    videoRecoveryFailed = true
    videoFragments = []
}
```
Add `videoRecoveryFailed: Bool` to the report struct or encode it in the `notes` field as a
structured key. Return `.fail` when `videoRecoveryFailed == true`.

**Option B (more complete):** Make `countVideoFrameReassemblyFailures` `throws` and let the
error propagate to the report builder. Choose whichever matches the pattern already used in
adjacent UltraGrid report fields.

**Files likely affected:**
`Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibilityRunner.swift` (lines ~370–390)

**Behavior affected:**
When `recoverVideoFragments` throws, the report now records `videoRecoveryFailed: true` (or
returns `.fail`) instead of `videoFragmentReassemblyFailureCount: 0`.

**Tests to add:**
1. `countVideoFrameReassemblyFailures_propagatesRecoveryError` — inject a throwing
   `recoverVideoFragments`; assert report verdict is `.fail` or `videoRecoveryFailed == true`.
2. `countVideoFrameReassemblyFailures_countsRealFailures` — inject fragments with deliberate
   reassembly breaks; assert failure count matches injected count.

**Verification commands:**
```bash
swift test --filter UltraGridCompatibilityRunnerTests
swift build
```

**Risk level:** Low. The change affects only the UltraGrid report builder. The fix makes failure
visible where it was silently hidden.

**Rollback strategy:** Revert the `videoFragments` assignment and any new report field.

**Definition of Done:**
Both new tests pass. No existing UltraGrid tests broken. `swift build` clean. Report no longer
shows `0` when recovery threw.

---

### R-04

**Title:** Count unexpected capture errors in LoLa verdict — do not downgrade to notes

**Findings addressed:** C-FL-11

**Problem:**
In `LoLaCompatibilityCaptureReport.buildReport`, only typed `LoLaCompatibilityCaptureDecodeError`
cases influence the verdict. Any other exception thrown during per-packet processing is caught and
appended to `notes` as an unstructured string; the verdict is not updated. A systematic regression
that throws a new error type produces `.partial` with degraded notes — not `.fail`.

**Minimal fix strategy:**
In the per-packet catch block that currently appends to `notes`:
```swift
} catch {
    unexpectedErrorCount += 1
    notes.append("Unexpected error on packet \(index): \(error)")
}
```
Add `var unexpectedErrorCount = 0` before the loop. After the loop:
```swift
if unexpectedErrorCount > 0 {
    verdict = .fail
}
```
Optionally: add `unexpectedPacketErrorCount: Int` to the report struct for diagnostic visibility.

**Files likely affected:**
`Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityCaptureReport.swift` (lines ~75–90)

**Behavior affected:**
Per-packet processing errors of any type now downgrade the verdict to `.fail`. Previously they
were silent in the verdict.

**Tests to add:**
1. `captureReport_unexpectedPacketErrorDowngradesVerdictToFail` — inject a packet that throws
   an error type not in `LoLaCompatibilityCaptureDecodeError`; assert `verdict == .fail`.
2. `captureReport_knownDecodeErrorsStillInfluenceVerdictUnchanged` — inject a typed
   `LoLaCompatibilityCaptureDecodeError`; assert existing verdict behavior is unchanged.

**Verification commands:**
```bash
swift test --filter LoLaCompatibilityCaptureReportTests
swift build
```

**Risk level:** Low. Additive counter and conditional. Existing typed-error paths unchanged.

**Rollback strategy:** Revert the `unexpectedErrorCount` counter and the post-loop conditional.

**Definition of Done:**
Both new tests pass. All existing capture report tests pass. `swift build` clean.

---

### R-05

**Title:** Add `DirectAudioMediaRouter` routing success and channel mapping tests

**Findings addressed:** C-TI-09

**Problem:**
The only existing test verifies that an unconfigured stream is rejected. No test exercises correct
routing of a configured stream, channel-offset math, multi-stream isolation, or buffer-full
behavior. A routing bug or channel-offset off-by-one causes silent audio corruption with no test
catching it.

**Minimal fix strategy:**
Add tests to `DirectAudioMediaRouterTests.swift`:

1. **Routing success:** Register stream A. Send a packet for stream A. Assert the payload arrives
   at stream A's buffer at the correct channel offset, not at stream B's or at offset 0.
2. **Channel offset math:** Register a 4-channel stream with `channelOffset = 2`. Send a packet.
   Assert audio data occupies buffer positions 2–5 and positions 0–1 are untouched.
3. **Multi-stream isolation:** Register streams A and B. Send a packet for A. Assert B's buffer
   is unchanged.
4. **Buffer-full behavior:** Fill a stream's buffer to capacity. Send another packet. Assert the
   behavior is either rejection with a logged error or a defined drop policy — not a crash or
   silent overwrite.

**Files likely affected:**
`Tests/OpenLolaCoreTests/DirectAudioMediaRouterTests.swift`

**Behavior affected:**
No production behavior changed. New tests only.

**Tests to add:**
As above (4 tests).

**Verification commands:**
```bash
swift test --filter DirectAudioMediaRouterTests
swift build
```

**Risk level:** None. Additive tests only.

**Rollback strategy:** Delete the new test methods.

**Definition of Done:**
All 4 new tests pass. No existing tests broken. Each test would fail if the relevant routing logic
were removed or broken.

---

### R-06

**Title:** Add concurrent `RealtimeAudioPacketHandoff.receive()` + `dequeue()` test

**Findings addressed:** C-TI-12

**Problem:**
All existing `RealtimeAudioPacketHandoffTests` invoke `receive()` and `dequeue()` sequentially on
a single thread. Production usage is concurrent: `receive()` from a network thread,
`dequeue()` from the Core Audio render callback. No test catches a threading regression or data
corruption in this concurrency pattern.

**Minimal fix strategy:**
Add one test to `RealtimeAudioPacketHandoffTests.swift`, following the established pattern in
`SPSCAtomicRingTests.swift` (confirmed high-value by the test-intent audit):

```swift
@Test func realtimeAudioPacketHandoff_concurrentReceiveAndDequeueProducesNoLostOrCorruptedBlocks() {
    let handoff = RealtimeAudioPacketHandoff(...)
    let produceQueue = DispatchQueue(label: "test.produce")
    let consumeQueue = DispatchQueue(label: "test.consume")
    // send N known packets on produceQueue concurrently with dequeue on consumeQueue
    // collect dequeued packets
    // assert: all N payloads received, in order, with no corruption
}
```

Key assertions:
- Total dequeued block count equals total enqueued count.
- Each block's payload bytes match the transmitted test vector.
- `metricsSnapshot().ownerViolationCount == 0` (if the type exposes this or equivalent).

**Files likely affected:**
`Tests/OpenLolaCoreTests/RealtimeAudioPacketHandoffTests.swift`

**Behavior affected:**
No production behavior changed.

**Tests to add:**
1 concurrent test as described.

**Verification commands:**
```bash
swift test --filter RealtimeAudioPacketHandoffTests
swift test --no-parallel
```

**Risk level:** None. Additive test only.

**Rollback strategy:** Delete the new test method.

**Definition of Done:**
The new test passes under `--no-parallel` and repeated runs. It would fail if the handoff's
concurrent access is not properly guarded.

---

### R-07

**Title:** Fix QuickConnect fallback CI coverage — unconditional transport-stub test

**Findings addressed:** C-TI-11
**Blocked on:** I-06 (transport injection feasibility)

**Problem:**
4 substantive tests in `LoLaQuickConnectFallbackTests.swift` are gated on
`.enabled(if: secondaryLoopbackAliasAvailable())`. They skip silently in all clean CI environments
without `lo0:1`. The QuickConnect message exchange, timeout, and retry logic are never verified
in CI.

**Minimal fix strategy (contingent on I-06 outcome):**

If the fallback path accepts transport injection (I-06 confirms): add one unconditional test that
drives the fallback logic via a `MockLoLaTransport` or equivalent stub — no real socket. Cover:
- QuickConnect message exchange sequence
- Timeout handling
- At least one retry cycle

If injection is not currently supported: add a minimal transport protocol extraction first (see
I-06 scope), then add the stub test.

**Files likely affected:**
`Tests/OpenLolaCoreTests/LoLaQuickConnectFallbackTests.swift`
Possibly: `Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeOutgoing.swift` (injection seam,
if not present — but that would be a production code change requiring a separate decision)

**Behavior affected:**
No production behavior changed if injection seam already exists.

**Tests to add:**
1 unconditional test: `lolaQuickConnectFallback_messageSequenceIsCorrectWithTransportStub`

**Verification commands:**
```bash
# Must pass in environment WITHOUT lo0:1
swift test --filter lolaQuickConnectFallback
```

**Risk level:** Medium. Depends on whether transport injection is available without a production
code change. Do not attempt until I-06 is complete.

**Rollback strategy:** Delete the new test. If a seam was added, revert it.

**Definition of Done:**
The new test runs and passes in a clean CI environment without `lo0:1`. It would fail if the
QuickConnect message sequence changed.

---

### R-08

**Title:** Log Core Audio cleanup failures — capture discarded `stop()` result and `OSStatus`

**Findings addressed:** C-FL-04, C-FL-05

**Problem:**
`graph.stop()` (`@discardableResult`) is called as a void expression at two callers. The returned
`DirectPeerRealtimeAudioGraphCleanupResult.failures` array is silently discarded. In the startup
error path, `_ = stopUnlocked()` similarly discards the result. `AudioDeviceDestroyIOProcID`
and `AudioDeviceStop` `OSStatus` values in defer/error paths are discarded with `_ = ...`.
Core Audio device state degradation is completely invisible.

**Minimal fix strategy:**
This is a logging-only change — no behavioral change to primary paths.

**Site 1** (`LoLaCoreAudioLiveBridge.swift`, line ~139):
```swift
let cleanupResult = graph.stop()
if !cleanupResult.failures.isEmpty {
    os_log(.error, "LoLa Core Audio graph cleanup failures: %{public}@",
           cleanupResult.failures.map(\.localizedDescription).joined(separator: "; "))
}
```

**Site 2** (`DirectPeerSessionAVSocketRunner.swift`, line ~316): same pattern.

**Site 3** (`DirectPeerRealtimeAudioGraph.startUnlocked` error catch, line ~202):
```swift
let cleanupResult = stopUnlocked()
if !cleanupResult.failures.isEmpty {
    os_log(.fault, "Audio graph cleanup during start failure also failed: %{public}@", ...)
}
```

**Sites 4–5** (`RecordingSessionLiveCapture.swift` defer block; `DirectPeerRealtimeAudioGraph`
line ~249): replace `_ = AudioDeviceDestroyIOProcID(...)` / `_ = AudioDeviceStop(...)` with:
```swift
let status = AudioDeviceDestroyIOProcID(deviceID, procID)
if status != kAudioHardwareNoError {
    os_log(.error, "AudioDeviceDestroyIOProcID failed: %d", status)
}
```

**Files likely affected:**
- `Sources/OpenLolaCore/Connectors/LoLa/LoLaCoreAudioLiveBridge.swift`
- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift`
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`
- `Sources/OpenLolaCore/Release/RecordingSessionLiveCapture.swift`

**Behavior affected:**
No behavioral change to primary flows. Cleanup failures become visible in os_log.

**Tests to add:**
None required for pure logging additions. Optional integration test: inject a mock `AudioDeviceStop`
that returns non-zero OSStatus; assert an error is logged. Only add if Core Audio mocking is
already established in the test suite.

**Verification commands:**
```bash
swift build
swift test --no-parallel
```

**Risk level:** Low. Additive logging only. `@discardableResult` can remain; callers now
explicitly capture and log.

**Rollback strategy:** Remove the logging additions at each call site.

**Definition of Done:**
`swift build` clean. All five sites capture their result and log failures. `swift test --no-parallel`
passes. No `_ = audioGraph.stop()` or `_ = AudioDeviceDestroyIOProcID(...)` remains in
production code without an explicit decision comment.

---

### R-09

**Title:** Disambiguate UI evidence state — distinguish corrupt/missing evidence and I/O error from stale token

**Findings addressed:** C-FL-08

**Problem:**
`try? BoundedFileReader.data(atPath:)` + `try? ...decode(from:)` in `AppLatencyHeroMetrics.load`
produce `nil` for both absent file and corrupt/unreadable file, resulting in "awaiting evidence"
for both. `try? String(contentsOf: sessionTokenURL(...))` in `sessionTokenMatches` produces `nil`
for both absent token and file permission error — both appear as "token doesn't match."

A mid-write crash that corrupts a report file permanently blocks `hasValidatedRuntimeEvidence`
with no actionable message.

**Minimal fix strategy:**
**`AppLatencyHeroMetrics.load`:** Change return type from `AppLatencyHeroMetrics?` to
`Result<AppLatencyHeroMetrics?, LoadError>` where:
```swift
enum LoadError {
    case absent
    case readFailure(Error)
    case decodeFailure(Error)
}
```
Update all callers (in `open-lola-app`) to handle the three cases. Surface `.readFailure` and
`.decodeFailure` as a distinct UI state (e.g., "Evidence file damaged — re-run to replace it").

**`sessionTokenMatches`:** Change return type from `Bool` to:
```swift
enum TokenMatchResult {
    case match
    case mismatch
    case absent
    case readError(Error)
}
```
Update `hasValidatedRuntimeEvidence` to treat `.readError` as a distinct diagnostic state, not
equivalent to `.mismatch`.

**Files likely affected:**
- `Sources/open-lola-app/AppLatencyHeroMetrics.swift`
- `Sources/open-lola-app/AppRuntimeEvidenceScope.swift`
- `Sources/open-lola-app/AppSessionStateBanner.swift` (UI message strings)
- Any app callers of `load(from:sessionToken:)` and `sessionTokenMatches`

**Behavior affected:**
Users now see a distinct error message when their evidence file is corrupt or unreadable, instead
of the same "awaiting evidence" message shown when no run has completed.

**Tests to add:**
1. `appLatencyHeroMetrics_distinguishesCorruptFileFromAbsentFile` — write corrupt JSON to report
   path; assert `.decodeFailure` not `.absent`.
2. `sessionTokenMatches_distinguishesReadErrorFromMismatch` — mock file read to throw; assert
   `.readError` not `.mismatch`.
3. `hasValidatedRuntimeEvidence_isFalseButDistinctWhenTokenReadFails` — confirm the evidence state
   propagates `.readError` separately from `.mismatch`.

**Verification commands:**
```bash
swift build
swift test --filter AppLatencyHeroMetricsTests
swift test --filter AppRuntimeEvidenceScopeTests
```

**Risk level:** Medium. All callers of both functions need updating. Map all call sites before
starting with `grep -rn "AppLatencyHeroMetrics.load\|sessionTokenMatches" Sources/`.

**Rollback strategy:** Revert the return type changes in both functions and their callers.

**Definition of Done:**
All three new tests pass. `swift build` clean. No caller uses the old `Bool` or `Optional` return
without handling all cases of the new enum.

---

### R-10

**Title:** Aggregate LoLa TX concurrent errors — stop discarding the second error

**Findings addressed:** C-FL-01

**Problem:**
`LoLaLiveTransmitErrors.errors.first` is thrown after `group.wait()`. If both the audio TX and
video TX `DispatchQueue` blocks fail, only the first error is thrown; the second is discarded
permanently. The run appears to have had one error when two things broke.

**Minimal fix strategy:**
After `group.wait()`, throw an aggregate if multiple errors are present:
```swift
switch errors.count {
case 0: break
case 1: throw errors[0]
default: throw LoLaLiveTransmitAggregateError(errors: errors)
}
```
Define `LoLaLiveTransmitAggregateError: Error` with a `localizedDescription` listing all errors.
Callers catching `LoLaLiveTransmitErrors` are unchanged; add a new `catch LoLaLiveTransmitAggregateError`
branch in callers that need both errors, or treat it as a single error in callers that only need
to know "something failed."

**Files likely affected:**
`Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaLive.swift` (lines ~320–330)

**Behavior affected:**
A bidirectional run with two concurrent TX failures now surfaces both errors to the report builder
instead of one.

**Tests to add:**
1. `lolaLiveTransmit_bothAudioAndVideoErrorsArePreserved` — inject failures into both dispatch
   queue blocks; assert the thrown error's `localizedDescription` references both failures.

**Verification commands:**
```bash
swift test --filter LoLaCompatibilityUdpMediaLiveTests
swift build
```

**Risk level:** Low. Callers catching the single-error type are not affected by the new aggregate
type unless they specifically need both errors.

**Rollback strategy:** Revert to `throw errors.first`.

**Definition of Done:**
New test passes. `swift build` clean. No existing test broken.

---

### R-11

**Title:** Fix LoLa TX zero-bytes verdict — add structured sent-bytes field

**Findings addressed:** C-FL-07

**Problem:**
`sentBytesTotal` appears only in unstructured `notes` text in the LoLa TX report. No guard
distinguishes a run where zero bytes were transmitted from a successful partial transmit. A
"black hole" UDP path (sockets appear to succeed but no bytes go anywhere) produces `.partial`
with no indication anything is wrong.

**Minimal fix strategy:**
Add `sentBytesTotal: Int` as a structured field to the LoLa TX report type (or equivalent).
After the TX loop, if `runMode == .measured && sentBytesTotal == 0`:
- Set `runtimeError` or a new `zeroBytesWarning: Bool = true` field.
- Include the zero-bytes state in the report verdict logic (`if zeroBytesWarning { verdict = .fail }`
  or equivalent).

Remove the duplicate text encoding of `sentBytesTotal` from `notes` once it is a typed field.

**Files likely affected:**
`Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMedia.swift` (lines ~265–285)
The TX report struct (likely in the same file or a companion `*Report.swift`)

**Behavior affected:**
A measured run that sends zero bytes now produces `.fail` or a structured warning field,
distinguishable from a normal `.partial` run.

**Tests to add:**
1. `lolaUdpTransmit_zeroBytesSentProducesFailOrWarningField` — mock socket returning success but
   zero bytes sent; assert `report.sentBytesTotal == 0` and `verdict == .fail` (or
   `zeroBytesWarning == true`).
2. `lolaUdpTransmit_successfulPartialTransmitRetainsPartialVerdict` — normal partial run still
   produces `.partial` without the warning.

**Verification commands:**
```bash
swift test --filter LoLaCompatibilityUdpMediaTests
swift build
```

**Risk level:** Low. Additive field and conditional. Does not change `.partial` semantics for
normal runs.

**Rollback strategy:** Remove the `sentBytesTotal` field and the zero-bytes guard.

**Definition of Done:**
Both tests pass. `swift build` clean. `sentBytesTotal` is a typed field not a note string.

---

### R-12

**Title:** Log SIGTERM/SIGKILL result in `terminateExternalConnectorProcessGroup`

**Findings addressed:** C-FL-03

**Problem:**
`_ = kill(-pg, SIGTERM)`, `_ = externalConnectorWaitForExit(...)`, `_ = kill(-pg, SIGKILL)` —
all three results are unconditionally discarded. If signals fail (process group already dead,
permission error), the cleanup path has no record of what happened. Post-run reports may claim
"forced-kill" when the group was never signalled successfully.

**Minimal fix strategy:**
Replace the three discards with logged checks:
```swift
let termResult = kill(-pg, SIGTERM)
if termResult != 0 {
    os_log(.error, "SIGTERM to process group %d failed: errno %d", pg, errno)
}
let waitResult = externalConnectorWaitForExit(...)
// log if wait indicates unexpected state
let killResult = kill(-pg, SIGKILL)
if killResult != 0 {
    os_log(.error, "SIGKILL to process group %d failed: errno %d", pg, errno)
}
```
No behavioral change. Pure logging.

**Files likely affected:**
`Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift` (lines ~195–215)

**Behavior affected:**
No behavioral change. Signal failures become visible in `os_log`.

**Tests to add:**
None required for pure logging additions. Mark with a comment: "Signal result logging is
observable via os_log; not unit-testable without a process-group mock."

**Verification commands:**
```bash
swift build
```

**Risk level:** Low. Additive `os_log` calls only.

**Rollback strategy:** Remove the log statements; restore `_ = kill(...)` pattern.

**Definition of Done:**
`swift build` clean. `grep -n "_ = kill" Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift`
returns zero results (all discards replaced).

---

### R-13

**Title:** Document `RealtimeAudioCallbackSafetyChecklist` as self-attestation; add gate validation test

**Findings addressed:** C-MC-06

**Problem:**
`RealtimeAudioCallbackSafetyChecklist` is a 7-boolean struct where all production call sites
set every field to `true` by developer declaration. The `validate()` gate checks `firstViolation != nil`,
but no production code path ever produces a `firstViolation` — the gate is only triggered if a
developer deliberately writes `false`. The struct creates false confidence in realtime safety.

**Minimal fix strategy (two parts):**

**Part 1 — Documentation comment (production code change, documentation-only):**
Add a comment to the struct definition:
```swift
/// Self-attestation checklist. Fields are set by the developer writing the report,
/// not by runtime instrumentation. This is a documentation aid, not a measured check.
/// A violation is only detectable if the developer explicitly sets a field to false.
```

**Part 2 — Gate validation test (test change):**
Add to `RealtimeAudioEngineTests.swift` (or a new `RealtimeAudioCallbackSafetyChecklistTests.swift`):
```swift
@Test func safetyChecklist_validateRejectsReportWithViolation() {
    var checklist = RealtimeAudioCallbackSafetyChecklist.allTrue
    checklist.noAllocationInCallback = false
    // assert validate() throws / returns a non-nil violation
}
```
This confirms the gate works when manually triggered, and documents the self-attestation nature
in the test name itself.

**Files likely affected:**
`Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift` (comment only)
`Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift` (new test)

**Behavior affected:**
No behavioral change. The comment makes intent explicit. The test confirms the validation gate
rejects a deliberately incorrect checklist.

**Tests to add:**
1. `safetyChecklist_validateRejectsReportWithAnyViolationField`.

**Verification commands:**
```bash
swift test --filter RealtimeAudioEngineTests
swift build
```

**Risk level:** Low. Comment + one test method.

**Rollback strategy:** Remove comment and test.

**Definition of Done:**
New test passes. Struct has a doc comment explaining self-attestation. `swift build` clean.

---

### R-14

**Title:** Replace fabricated synthetic smoke numeric metrics with sentinel values

**Findings addressed:** C-MC-07

**Problem:**
Synthetic smoke reports contain plausible-looking invented numeric values (e.g.,
`p50Microseconds: 80`, `cpuP50Percent: 8`, `oneWayEstimateMicroseconds: 2_400`). Any consumer
that reads the report without checking `runMode == .synthetic` would treat these as real
measurements. Tests asserting exact synthetic metric values are testing hardcoded constants.

**Minimal fix strategy:**
1. Define a shared constant set: `SyntheticPlaceholderMetrics.latencyMicroseconds = 0`,
   `SyntheticPlaceholderMetrics.cpuPercent = 0`, etc. Alternatively, use a clearly non-plausible
   sentinel such as `-1` or `Int.min` for integer metrics and `0.0` for floats.
2. Replace all plausible numeric literals in `*SyntheticSmoke.run()` functions with the sentinel
   constants.
3. Confirm `validate()` does not enforce minimum value thresholds that would reject sentinels.
   If it does, either add a `runMode == .synthetic` bypass in the validator, or use `0` (which
   is more likely to pass numeric range checks than `Int.min`).

**Files likely affected:**
All `*SyntheticSmoke.swift` files that set numeric metric fields (30+ files; use
`grep -rn "p50Microseconds\|p95Microseconds\|cpuP50Percent\|oneWayEstimate" Sources/` to scope).

**Behavior affected:**
Synthetic smoke reports no longer contain plausible metric values. Any consumer checking
`runMode == .synthetic` already knows to disregard metrics; sentinels make the same fact visible
to consumers that do not check `runMode`.

**Tests to add:**
1. `syntheticSmokeMetrics_allNumericFieldsAreSentinelNotPlausible` — for a representative set of
   smoke reports, assert that latency and CPU fields equal the defined sentinel constant.
2. `syntheticSmokeReports_stillValidateAfterSentinelReplacement` — assert `validate()` passes on
   a sentinel-populated synthetic report.

**Verification commands:**
```bash
swift test --filter SyntheticSmokeReportContractTests
swift build
```

**Risk level:** Medium. Tests currently asserting exact numeric smoke values will fail and need
updating. Map all such assertions first: `grep -rn "p50Microseconds.*==" Tests/`.

**Rollback strategy:** Restore original numeric literals in `*SyntheticSmoke.swift` files.

**Definition of Done:**
`grep -rn "p50Microseconds: [1-9]\|cpuP50Percent: [1-9]" Sources/` returns zero results.
Both new tests pass. All existing synthetic smoke contract tests pass (after updating value assertions).

---

### R-15

**Title:** Add UDP PCM payload correctness test

**Findings addressed:** C-TI-04

**Problem:**
`udpPcmLocalhostSmokeRoundTripsPacket` asserts `sequenceNumber == 1` and
`senderHostTimeNanoseconds > 1`. It proves the smoke ran without crashing, but not that audio
payload bytes survived the encode–transmit–decode cycle unchanged. A payload corruption bug
would not be caught.

**Minimal fix strategy:**
Add a test that encodes a known audio byte vector, round-trips it through the PCM codec, and
asserts decoded bytes equal the original:

```swift
@Test func udpPcmSmoke_decodedPayloadMatchesTransmittedPayload() {
    let testVector: [Float32] = (0..<256).map { Float32($0) / 256.0 }
    // encode → transmit (localhost or in-memory) → decode
    #expect(decodedVector == testVector)
}
```

Additionally: add a 3-packet sequence test (sequence numbers 1, 2, 3) and a sequence-gap
rejection test (gap from 1 to 3 → assert gap is reported).

**Files likely affected:**
`Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift`

**Behavior affected:**
No production behavior changed.

**Tests to add:**
1. `udpPcmSmoke_decodedPayloadMatchesTransmittedPayload` (payload correctness).
2. `udpPcmSmoke_threePacketSequenceIsAccepted` (sequence tracking).
3. `udpPcmSmoke_sequenceGapIsRejected` (sequence integrity).

**Verification commands:**
```bash
swift test --filter UdpPcmPacketTests
```

**Risk level:** None. Additive tests only.

**Rollback strategy:** Delete the new test methods.

**Definition of Done:**
All 3 new tests pass. `udpPcmSmoke_decodedPayloadMatchesTransmittedPayload` would fail if payload
byte encoding or decoding changed.

---

### R-16

**Title:** Add `UdpPcmSequenceTracker` wrap-around test

**Findings addressed:** C-TI-13

**Problem:**
The tracker implementation uses `&+` (wrapping add). No test exercises the `UInt64.max → 0`
transition. In a release build, non-wrapping arithmetic would overflow silently; the wrap-around
behavior is the intended contract, but it is unverified.

**Minimal fix strategy:**
Add one test to `UdpPcmPacketTests.swift`:

```swift
@Test func udpPcmSequenceTracker_acceptsWrapAroundFromMaxToZero() {
    var tracker = UdpPcmSequenceTracker(initial: UInt64.max)
    let nextPacket = makePacket(sequenceNumber: 0)
    #expect(tracker.accept(nextPacket) == .accepted)
}
```

Also add the inverse: `UInt64.max - 1 → UInt64.max` is accepted; `UInt64.max - 1 → UInt64.max + 2`
(a skip, wrapping) is rejected as a gap.

**Files likely affected:**
`Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift`

**Behavior affected:**
No production behavior changed.

**Tests to add:**
1. `udpPcmSequenceTracker_acceptsWrapAroundFromMaxToZero`.
2. `udpPcmSequenceTracker_rejectsSkipAcrossWrapBoundary`.

**Verification commands:**
```bash
swift test --filter udpPcmSequenceTracker
```

**Risk level:** None. Additive tests only.

**Rollback strategy:** Delete the two test methods.

**Definition of Done:**
Both tests pass. `_acceptsWrapAround` test would fail if wrapping arithmetic were removed.

---

### R-17

**Title:** Add reconnection continuity tests

**Findings addressed:** C-TI-10

**Problem:**
`reconnectAfterMediaSocketFailurePreservesAcceptedSessionConfiguration` tests that
`acceptedConfiguration` survives a state transition. No test verifies sequence number reset, RX
buffer flush, or that pre-failure packets do not corrupt the post-reconnect stream.

**Minimal fix strategy:**
Add tests to `ReconnectionTests.swift`:

1. `reconnect_sequenceCounterResetsAfterMediaSocketFailure` — simulate a disconnect event; assert
   the sequence tracker resets to 0 (or whatever the defined initial state is) before packets
   are accepted for the new session.
2. `reconnect_rxBufferIsFlushedAfterMediaSocketFailure` — populate the RX buffer with stale
   packets; simulate reconnect; assert stale packets are not delivered to the new session.
3. `reconnect_preFailurePacketsDoNotCorruptPostReconnectStream` — deliver 10 packets, simulate
   disconnect, reconnect, deliver 10 more packets; assert the second set arrives correctly and
   independently.

**Files likely affected:**
`Tests/OpenLolaCoreTests/ReconnectionTests.swift`

**Behavior affected:**
No production behavior changed.

**Tests to add:**
3 tests as described.

**Verification commands:**
```bash
swift test --filter ReconnectionTests
```

**Risk level:** Low. Additive tests only. Requires tracing the reconnect sequence in
`PeerSessionRunner` / handoff layer before writing.

**Rollback strategy:** Delete the new test methods.

**Definition of Done:**
All 3 new tests pass. Each test would fail if the guarded reconnect behavior changed.

---

### R-18

**Title:** Rewrite `CapabilitySummary` milestone snapshot test

**Findings addressed:** C-TI-01

**Problem:**
`capabilitySummaryExposesCurrentM15Surface` asserts `summary == .m15PackagingFieldTest` — a
hardcoded milestone-specific constant. This test fails on every milestone advance regardless of
correctness and passes even if `CapabilitySummary.current` returned a stale value, as long as
the assertion was updated to match.

**Minimal fix strategy:**
Replace the milestone-specific assertion with a symbolic comparison:
```swift
@Test func capabilitySummary_currentMatchesCompileTimeMilestoneConstant() {
    let summary = CapabilitySummary.current
    #expect(summary.version == CapabilitySummary.currentVersion) // symbolic constant
    #expect(summary.stage != nil)   // structural check
    #expect(!summary.description.isEmpty)
}
```
The test should verify structural and semantic invariants, not the specific string `"0.0.0-m15"`.

**Files likely affected:**
`Tests/OpenLolaCoreTests/CapabilitySummaryTests.swift`

**Behavior affected:**
No production behavior changed.

**Tests to add/update:**
Update `capabilitySummaryExposesCurrentM15Surface` in place (or add a replacement and mark the
old one as deprecated pending deletion).

**Verification commands:**
```bash
swift test --filter CapabilitySummaryTests
```

**Risk level:** Low. Test-only change. Existing test breaks on every milestone anyway.

**Rollback strategy:** Revert the test method.

**Definition of Done:**
Updated test passes. It will not need to change at the next milestone advance.

---

### R-19

**Title:** Replace PRNG-fragile golden float test

**Findings addressed:** C-TI-07

**Problem:**
`rxBufferImpairmentSimulatorIsDeterministicAcrossRuns` asserts 9-decimal-place golden floats
(e.g., `abs(packetAges[0] - 145.0083667750024) < 0.000_000_001`). These values are
PRNG-algorithm-specific and may change on a new Swift version or Apple silicon. The test fails
for the wrong reason and asserts nothing meaningful about simulation behavior.

**Minimal fix strategy:**
Replace with two distinct tests:
1. `rxBufferImpairmentSimulator_isReproducibleWithSameSeed` — run twice with the same seed;
   assert output arrays are equal. No golden values.
2. `rxBufferImpairmentSimulator_producesPacketAgesWithinDomainBounds` — assert all `packetAges`
   are `>= 0` and `<= maxExpectedDelayNanoseconds` for the simulation's parameters.

**Files likely affected:**
`Tests/OpenLolaCoreTests/RxBufferingTests.swift`

**Behavior affected:**
No production behavior changed.

**Tests to add/update:**
Replace `rxBufferImpairmentSimulatorIsDeterministicAcrossRuns` with the two tests above.

**Verification commands:**
```bash
swift test --filter RxBufferingTests
```

**Risk level:** Low. Test-only change.

**Rollback strategy:** Restore original test with golden values.

**Definition of Done:**
Both new tests pass. Neither test contains hardcoded floating-point literals from a specific PRNG run.

---

### R-20

**Title:** Add `.partial` diagnostic field — distinguish clean partial from error partial

**Findings addressed:** C-FL-06

**Problem:**
Three connector report builders assign `.partial` when `runtimeError == nil`. This makes `.partial`
serve two semantically distinct states: "ran cleanly but PASS not yet earned" vs. "ran, no
detected error, but unknown whether clean." A clean two-peer run and a run with silent socket
failures look identical in the report.

**Minimal fix strategy:**
Add `runtimeErrorFree: Bool` to the relevant report structs (or the base connector result type
if one exists). Set it to `true` when no `runtimeError` was produced during the run. This is
the minimum change that makes the distinction explicit without changing `MeasurementVerdict`
or its three values.

Do **not** add sub-states to `MeasurementVerdict` (a public contract change) unless a future
slice explicitly addresses the contracts. This slice is additive only.

**Files likely affected:**
`Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRunner.swift` (lines ~95, 210)
`Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibilityRunner.swift` (line ~108)
`Sources/OpenLolaCore/Connectors/JackTrip/JackTripCompatibility.swift` (line ~621)

**Behavior affected:**
`verdict` is unchanged. A new `runtimeErrorFree` field provides diagnostic context. Pipeline
checks on `verdict` are unaffected.

**Tests to add:**
1. `connectorReport_partialWithRuntimeError_hasRuntimeErrorFreeFalse`.
2. `connectorReport_partialWithoutRuntimeError_hasRuntimeErrorFreeTrue`.

**Verification commands:**
```bash
swift build
swift test --filter ExternalConnectorSessionRunnerTests
```

**Risk level:** Low. Additive field. No existing behavior changes.

**Rollback strategy:** Remove `runtimeErrorFree` field from all three structs.

**Definition of Done:**
Both tests pass. `swift build` clean. All three connectors set `runtimeErrorFree` correctly.

---

### R-21

**Title:** Consolidate 10 identical `*RunMode` enums into one shared `ReportRunMode`

**Findings addressed:** C-MC-03

**Problem:**
10 separate `enum X: String, Codable, Equatable, Sendable { case synthetic; case measured }`
definitions across Audio, Integration, Platform, Network, Benchmarks, Control, and Timing modules.
A new case (e.g., `replayed`) requires 10 identical edits. All 10 are compatible with one shared
type since their raw string values are identical.

**Minimal fix strategy:**
1. Add to `OpenLolaContracts`:
   ```swift
   public enum ReportRunMode: String, Codable, Equatable, Sendable {
       case synthetic
       case measured
   }
   ```
2. Update the 10 report structs to use `ReportRunMode` for their `runMode` field.
3. Leave unchanged the 3 enums that have extra cases beyond `synthetic`/`measured`.
4. Update JSON fixture files and tests that decode reports with an explicit run-mode field,
   if any — the raw string values are identical so no JSON changes are expected.

**Files likely affected:**
`Sources/OpenLolaContracts/` (new enum);
10 report struct files across `Sources/OpenLolaCore/` (field type change);
`Tests/` (any fixture JSON or test that decodes `runMode` as a specific type).

**Behavior affected:**
No behavioral change. JSON serialization is identical (same raw values).

**Tests to add/update:**
`swift test --no-parallel` — verify JSON round-trips for all 10 affected report types.

**Verification commands:**
```bash
swift build
swift test --no-parallel
grep -rn "RunMode: String, Codable, Equatable, Sendable" Sources/
# Should return only the 3 enums with extra cases
```

**Risk level:** Medium. All 10 report structs change their `runMode` field type. The build is
the primary gate; JSON round-trip tests are the acceptance criterion.

**Rollback strategy:** Remove `ReportRunMode` from `OpenLolaContracts`; restore individual enum
definitions in each report struct.

**Definition of Done:**
`grep` for `"RunMode: String, Codable, Equatable, Sendable"` returns exactly 3 results (the
enums with extra cases). `swift test --no-parallel` passes.

---

### R-22

**Title:** Remove empty `ReportValidationProtocol`

**Findings addressed:** C-MC-01 (Phase 1 of validation helper consolidation)

**Problem:**
`ReportValidationProtocol` extends `ReportPrimitiveValidating` and adds zero new requirements.
Every conformance to `ReportValidationProtocol` is equivalent to conforming to
`ReportPrimitiveValidating` directly. The empty sub-protocol adds a redundant declaration to
every conforming type for no benefit.

**Minimal fix strategy:**
Phase 1 only (safe, independent):
1. Remove `ReportValidationProtocol` declaration.
2. Replace all 5 `: ReportValidationProtocol` conformances with `: ReportPrimitiveValidating`.
3. Verify build. No behavior change.

Phase 2 (consolidating the 40+ private `require*` helpers — the larger part of C-MC-01) is a
separate, higher-risk slice not in this plan. Add it as a follow-on after Phase 1 proves safe.

**Files likely affected:**
`Sources/OpenLolaCore/Core/ValidationPrimitives.swift`;
5 files with `ReportValidationProtocol` conformances
(find with `grep -rn "ReportValidationProtocol" Sources/`).

**Behavior affected:**
No behavioral change. Protocol conformances are semantically identical.

**Tests to add/update:**
None. `swift build` is the test.

**Verification commands:**
```bash
swift build
grep -rn "ReportValidationProtocol" Sources/
# Should return zero results
```

**Risk level:** Medium. Every conforming enum must be updated; build fails until all 5 are
resolved. Do in a single commit to avoid a broken intermediate state.

**Rollback strategy:** Restore `ReportValidationProtocol` and revert the 5 conformance changes.

**Definition of Done:**
`grep` for `ReportValidationProtocol` in `Sources/` returns zero results. `swift build` clean.

---

### R-23

**Title:** Merge `ExternalConnectorPipeCapture` into `BoundedPipeCapture`

**Findings addressed:** C-MC-05

**Problem:**
`ExternalConnectorPipeCapture` and `BoundedPipeCapture` are structurally identical: both have
`readHandle`, `lock: NSLock`, `prefixData`, `limit`, idempotency guards, a `readabilityHandler`,
`stopAndSnapshot()`, `capture(_:)`, and `prefix()`. Bug fixes must be applied twice.

**Minimal fix strategy:**
1. Add an optional parameter to `BoundedPipeCapture` for character vs. byte limiting
   (the only behavioral difference between the two).
2. Replace `ExternalConnectorPipeCapture` usage in `ExternalConnectorProcessRunner.swift` with
   `BoundedPipeCapture(..., mode: .characters)`.
3. Delete `ExternalConnectorPipeCapture`.

**Files likely affected:**
`Sources/OpenLolaCore/Support/BoundedPipeCapture.swift` (parameter addition);
`Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift` (call site update);
`ExternalConnectorPipeCapture.swift` (deleted).

**Behavior affected:**
No behavioral change. `BoundedPipeCapture` with `.characters` mode is identical to the current
`ExternalConnectorPipeCapture`.

**Tests to add/update:**
`swift test --filter BoundedPipeCaptureTests` — confirm existing tests still pass.

**Verification commands:**
```bash
swift build
swift test --filter BoundedPipeCaptureTests
```

**Risk level:** Low. One call site. Both types have identical logic.

**Rollback strategy:** Restore `ExternalConnectorPipeCapture` and revert `ExternalConnectorProcessRunner`.

**Definition of Done:**
`ExternalConnectorPipeCapture` file deleted. `swift build` clean. All pipe capture tests pass.

---

### R-24

**Title:** Delete `JSONReportCoder` — inline its 3 trivial methods

**Findings addressed:** C-MC-12

**Problem:**
`JSONReportCoder` is a caseless enum with 3 methods of 2–4 lines each. It is only called from
`PrettyJSONCodable` default implementations in the same file. No independent use.

**Minimal fix strategy:**
Inline the 3 methods directly into the `PrettyJSONCodable` extension.
Delete `JSONReportCoder`.
Verify with `grep -rn "JSONReportCoder\." Sources/` — must return zero results.

**Files likely affected:**
`Sources/OpenLolaContracts/PrettyJSONCodable.swift` only.

**Behavior affected:**
None. Identical logic, fewer indirections.

**Tests to add/update:**
None. Build check only.

**Verification commands:**
```bash
swift build
grep -rn "JSONReportCoder" Sources/
# Must return zero results
```

**Risk level:** None. Internal to one file.

**Rollback strategy:** Restore `JSONReportCoder`.

**Definition of Done:**
`grep` for `JSONReportCoder` returns zero results. `swift build` clean.

---

### R-25

**Title:** Delete `UltraGridMediaFormatRegistry` — move constants to their only caller

**Findings addressed:** C-MC-13

**Problem:**
`UltraGridMediaFormatRegistry` holds 4 static FourCC constants and 1 `rawVideoFourCC(bitsPerPixel:)`
switch. Called from exactly one place: `UltraGridCompatibility.swift:380`.

**Minimal fix strategy:**
Move the 4 constants and the switch into `UltraGridCompatibility.swift` as file-private.
Delete `UltraGridMediaFormatRegistry.swift`.

**Files likely affected:**
`Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibility.swift` (constants moved in);
Former `UltraGridMediaFormatRegistry.swift` file (deleted).

**Behavior affected:**
None.

**Tests to add/update:**
None. Build check only.

**Verification commands:**
```bash
swift build
grep -rn "UltraGridMediaFormatRegistry" Sources/
# Must return zero results
```

**Risk level:** None. One call site confirmed.

**Rollback strategy:** Restore the file.

**Definition of Done:**
File deleted. Constants accessible from `UltraGridCompatibility.swift`. `swift build` clean.

---

### R-26

**Title:** Delete `CoreAudioFallbackIdentityCache` — return deterministic string inline

**Findings addressed:** C-MC-17

**Problem:**
`CoreAudioFallbackIdentityCache` is a lock-guarded class with two `[AudioObjectID: String]`
dictionaries caching `"Unknown Core Audio device \(deviceID)"`. The values are deterministic
functions of their inputs. The cache uses `@unchecked Sendable`, suppressing Swift Concurrency
checking on a shared mutable object with no justification.

**Minimal fix strategy:**
Delete `CoreAudioFallbackIdentityCache` and `coreAudioFallbackIdentityCache` global.
At each fallback call site, return `"Unknown Core Audio device \(deviceID)"` inline.
Verify: `grep -rn "coreAudioFallbackIdentityCache" Sources/` — confirm only one access site.

**Files likely affected:**
`Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift`

**Behavior affected:**
None. String values are identical. No caching for a deterministic string was warranted.

**Tests to add/update:**
None. Build check only.

**Verification commands:**
```bash
swift build
grep -rn "CoreAudioFallbackIdentityCache" Sources/
# Must return zero results
```

**Risk level:** None. Deterministic value; lock eliminated; `@unchecked Sendable` eliminated.

**Rollback strategy:** Restore the class.

**Definition of Done:**
Class deleted. `grep` returns zero results. `swift build` clean.

---

### R-27

**Title:** Inline `DebugTrace` single-use wrapper namespaces

**Findings addressed:** C-MC-10

**Problem:**
`DebugTraceJSONEncoder` (1 call site, 2-line method), `DebugTraceTimestampFormatter` (2 call
sites, 2-line method), and `DebugTraceEncodingFailureLine` (1 call site, includes a hand-written
JSON escaper) are caseless enum namespaces wrapping trivially inlineable logic.
`DebugTraceEncodingFailureLine` hand-implements JSON string escaping for a fallback path when
`JSONEncoder` fails — ironic given the context.

**Minimal fix strategy:**
Inline all three at their call sites inside `DebugTrace.swift`. The hand-written JSON escaper
in `DebugTraceEncodingFailureLine` can be replaced with a 2-field `Codable` struct or
`String(format:)` — whichever produces identical output to the current implementation.
Confirm output format is unchanged by comparing before/after `jsonLines()` output in a test.

**Files likely affected:**
`Sources/OpenLolaCore/Core/DebugTrace.swift` only.

**Behavior affected:**
None. Same output from `jsonLines()`.

**Tests to add/update:**
Before making the change: `swift test --filter DebugTraceTests` to capture baseline output.
After: re-run the same tests to confirm no output change.

**Verification commands:**
```bash
swift build
swift test --filter DebugTraceTests
```

**Risk level:** None. Internal to one file.

**Rollback strategy:** Restore the three wrapper enums.

**Definition of Done:**
`grep -rn "DebugTraceJSONEncoder\|DebugTraceTimestampFormatter\|DebugTraceEncodingFailureLine" Sources/`
returns zero results. `swift build` clean. `DebugTraceTests` pass.

---

### R-28

**Title:** Move misplaced type definitions to their semantic home files

**Findings addressed:** C-MC-21, C-MC-22

**Problem:**
Five `LolaBaseline*` types (`LolaBaselineAvailability`, `LolaBaselineMeasurementMethod`,
`LolaBaselineComparisonResult`, `LolaBaselineLatencyMetrics`, `LolaBaselineComparison`) are
defined in `DriftPlcFixedTargetCertification.swift` but used by `FasterThanLoLaClosure.swift`.
`UdpPcmV2PacketHeader` is defined in `UdpPcmV2FragmentPlanner.swift` but belongs with
`UdpPcmV2Packet.swift`.

**Minimal fix strategy:**
File moves only:
1. Move the 5 `LolaBaseline*` types to a new
   `Sources/OpenLolaCore/Release/LolaBaselineComparison.swift`.
2. Move `UdpPcmV2PacketHeader` to `UdpPcmV2Packet.swift`.

No logic changes. No API changes.

**Files likely affected:**
`Sources/OpenLolaCore/Timing/DriftPlcFixedTargetCertification.swift` (types removed);
`Sources/OpenLolaCore/Release/LolaBaselineComparison.swift` (new file, types moved in);
`Sources/OpenLolaCore/Network/UDP/UdpPcmV2FragmentPlanner.swift` (header removed);
`Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift` (header added).

**Behavior affected:**
None.

**Tests to add/update:**
None. Build check only.

**Verification commands:**
```bash
swift build
```

**Risk level:** None. File moves only.

**Rollback strategy:** Revert the moves.

**Definition of Done:**
`UdpPcmV2PacketHeader` is in `UdpPcmV2Packet.swift`. `LolaBaseline*` types are in
`LolaBaselineComparison.swift`. `swift build` clean.

---

## Investigation Slices

---

### I-01

**Title:** Confirm inventory-as-code CI gate status before acting on C-MC-11

**Findings addressed:** C-MC-11

**Problem:**
5+ Swift files encode source metadata (file paths, command names, schema validators, evidence
lanes) as hardcoded Swift literals that go stale silently. The audit recommends moving these
to static data files. However, if any inventory is a required gate in
`scripts/verify-release-readiness.sh` or another CI script, the simplification scope changes
from "delete Swift code" to "move data to a JSON file."

**Investigation scope:**
```bash
grep -rn "current-evidence-status-matrix\|fixture-smoke-matrix\|command-inventory\|report-schema-inventory\|source-ownership-inventory" scripts/
grep -rn "CLICommandInventory\|ReportSchemaInventory\|SourceOwnershipInventory\|FixtureSmokeMatrix\|CurrentEvidenceStatusMatrix" scripts/
```

For each inventory found in scripts: determine whether it is a **gate** (failure blocks CI) or
an **informational report** (failure produces a report artifact but does not block).

**Expected output:**
A short mapping: `{ inventory_name: "gate" | "informational" | "not in scripts" }` for each of
the 5 inventories.

**Blocks:**
A follow-on R-29 slice: "Move inventory-as-code to static data files." The strategy differs
depending on whether the inventory is gated.

**Verification:**
The investigation is done when `grep` output for all 5 inventory names is documented.

---

### I-02

**Title:** Confirm intent of `CapabilitySummary` historical static instances

**Findings addressed:** C-MC-24

**Problem:**
`CapabilitySummary.m00Scaffold`, `.m02ProtocolSession`, `.m14ReleaseHardening` are three static
instances used only in tests that assert their `.stage` and `.description` values. The audit
cannot determine whether these are intentional compatibility contracts (freeze milestone behavior)
or documentation slop (should be in a CHANGELOG). The audit recorded a conflict between OE-06
(delete as slop) and TI-01 (may be intentional contract).

**Investigation scope:**
1. Read the test methods that reference these statics. Ask: do the asserted values represent a
   behavioral contract (e.g., "when we said m00Scaffold, these were the exact capabilities
   available") or do they only assert that constants equal themselves?
2. Check `CHANGELOG.md`, `docs/`, or commit history for the introduction of these statics.
3. Determine: if `m14ReleaseHardening.description` changed, would any behavior break?

**Expected output:**
One of: "These are intentional compatibility contracts — keep and document them" OR "These are
version snapshots with no behavioral contract — move to CHANGELOG."

**Blocks:**
A follow-on R-30 slice: either "Add behavioral contract comment to historical statics" or
"Move historical statics to CHANGELOG and delete from Swift."

---

### I-03

**Title:** Confirm `RealtimeAudioBlockRing` has no callers

**Findings addressed:** C-MC-20

**Problem:**
The audit identified `RealtimeAudioBlockRing` as possible dead code. A FIFO ring for realtime
audio blocks with no confirmed callers in `Sources/` or `Tests/`. `RealtimeAudioDueBlockPlayout`
appears to serve the same purpose in the active code path.

**Investigation scope:**
```bash
grep -rn "RealtimeAudioBlockRing(" Sources/ Tests/
grep -rn "RealtimeAudioBlockRing\b" Sources/ Tests/
```

**Expected output:**
Zero call sites → R-31 slice: "Delete `RealtimeAudioBlockRing`."
One or more call sites → Close I-03 with a note on where it is used; no deletion slice.

**Blocks:**
R-31 (future): "Delete `RealtimeAudioBlockRing` — confirmed dead code."

---

### I-04

**Title:** Confirm `DebugTraceFieldPolicy.allowing` has no production callers

**Findings addressed:** C-MC-14

**Problem:**
`DebugTraceFieldPolicy` has a mutating `allowing(_:)` builder method suggesting multiple
policies could be created. The audit noted that only one static default instance was observed in
production code. If `allowing` has no callers outside tests, the struct's configurability is
speculative.

**Investigation scope:**
```bash
grep -rn "DebugTraceFieldPolicy\|\.allowing(" Sources/ Tests/
```

**Expected output:**
If `allowing` has no production callers: R-32 slice: "Inline `DebugTraceFieldPolicy.allows()`
as a private function in `DebugTrace`; delete the struct."
If `allowing` has production callers: Close I-04 with a note; `DebugTraceFieldPolicy` is
justified.

**Blocks:**
R-32 (future): "Inline `DebugTraceFieldPolicy` if confirmed no callers for `allowing`."

---

### I-05

**Title:** Map `ExternalConnectorSessionRunner` vs `SessionRuntime` split

**Findings addressed:** C-MC-23

**Problem:**
`ExternalConnectorSessionRunner.swift` and `ExternalConnectorSessionRuntime.swift` coexist in
the same directory alongside `Session`, `Report`, `ProcessRunner`, `SessionModels`,
`SessionValidation`, `ExecutablePreflight`, and `ParsingDefaults`. The audit could not determine
whether the Runner/Runtime distinction represents a meaningful lifecycle split or is an artifact
of an earlier refactoring that was never finished.

**Investigation scope:**
1. Read the public APIs of both files.
2. Map callers of each (`grep -rn "ExternalConnectorSessionRunner\.\|ExternalConnectorSessionRuntime\." Sources/ Tests/`).
3. Determine: do they represent distinct lifecycle phases? Could one be merged into the other?

**Expected output:**
Either "The split is justified — keep both" OR "One wraps the other with no added value — merge
them" (R-33 slice).

**Blocks:**
R-33 (future): "Merge `ExternalConnectorSessionRunner` into `SessionRuntime` or vice versa."

---

### I-06

**Title:** Map QuickConnect transport injection feasibility

**Findings addressed:** C-TI-11
**Blocks:** R-07

**Problem:**
R-07 (fix QuickConnect fallback CI coverage) requires adding an unconditional test that drives
the fallback logic via an injected transport stub. Whether the fallback path in
the QuickConnect fallback path currently accepts an injected transport (protocol/closure
abstraction over the socket) is not confirmed. If it uses a concrete socket directly, R-07 would
require a production code change to add an injection seam.

**Investigation scope:**
1. Read `Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeOutgoing.swift` and the socket/runtime helpers it calls.
2. Determine: does it depend on a concrete socket type, or on an injectable transport protocol?
3. If injectable: confirm the protocol is testable with a mock.
4. If concrete: describe the minimum change needed to add a seam (and whether that change is
   appropriate for a test-only purpose).

**Expected output:**
One of:
- "Injection seam exists → R-07 can proceed with a stub test, no production code change."
- "Concrete socket → R-07 requires a minimal protocol extraction in production code; document
  the scope."

**Blocks:**
R-07. Do not implement R-07 until I-06 is complete.

---

## Section 5: Recommended Execution Order

### Phase 1 — False success in critical paths (P0, do first, no dependencies)

| Order | Slice | Title | Effort |
|-------|-------|-------|--------|
| 1 | R-01 | Tighten release manifest PASS gate | 1–2 h |
| 2 | R-02 | Fix release readiness 3-state result | 2–3 h |
| 3 | R-03 | Propagate video reassembly recovery failure | 2–3 h |
| 4 | R-04 | Count unexpected capture errors in LoLa verdict | 1–2 h |
| 5 | R-05 | Add DirectAudioMediaRouter routing tests | 3–4 h |
| 6 | R-06 | Add concurrent PacketHandoff test | 2–3 h |
| 7 | R-16 | Add sequence tracker wrap-around test | 0.5 h |
| 8 | R-15 | Add UDP PCM payload correctness test | 2–3 h |

**Run in parallel with Phase 1:**

| Order | Slice | Title | Effort |
|-------|-------|-------|--------|
| — | I-06 | Map QuickConnect transport injection feasibility | 1 h |

### Phase 2 — Broken or missing tests; P1 correctness (after Phase 1 complete)

| Order | Slice | Title | Effort |
|-------|-------|-------|--------|
| 9 | R-07 | Fix QuickConnect fallback CI (after I-06) | 2–4 h |
| 10 | R-08 | Log Core Audio cleanup failures | 2–3 h |
| 11 | R-09 | Disambiguate UI evidence state | 3–4 h |
| 12 | R-10 | Aggregate LoLa TX concurrent errors | 1–2 h |
| 13 | R-11 | Fix LoLa TX zero-bytes verdict | 1–2 h |
| 14 | R-12 | Log SIGTERM/SIGKILL result | 0.5–1 h |
| 15 | R-13 | Document safety checklist; add gate test | 0.5–1 h |
| 16 | R-14 | Replace fabricated synthetic smoke metrics | 3–4 h |
| 17 | R-17 | Add reconnection continuity tests | 3–4 h |

**Run in parallel with Phase 2 (investigation slices):**

| Order | Slice | Title | Effort |
|-------|-------|-------|--------|
| — | I-01 | Confirm inventory-as-code CI gate status | 0.5 h |
| — | I-02 | Confirm CapabilitySummary historical instance intent | 0.5 h |
| — | I-03 | Confirm RealtimeAudioBlockRing callers | 0.25 h |
| — | I-04 | Confirm DebugTraceFieldPolicy.allowing callers | 0.25 h |
| — | I-05 | Map Runner vs Runtime split | 1 h |

### Phase 3 — Structural (P2, after Phase 2 complete)

| Order | Slice | Title | Effort |
|-------|-------|-------|--------|
| 18 | R-18 | Rewrite CapabilitySummary snapshot test | 0.5 h |
| 19 | R-19 | Replace PRNG-fragile golden float test | 0.5 h |
| 20 | R-20 | Add `.partial` diagnostic field | 1–2 h |
| 21 | R-21 | Consolidate 10 RunMode enums | 2–3 h |
| 22 | R-22 | Remove empty `ReportValidationProtocol` | 1–2 h |
| 23 | R-23 | Merge PipeCapture types | 1–2 h |

### Phase 4 — Low-risk P3 deletions / moves (after investigations complete)

| Order | Slice | Title | Effort |
|-------|-------|-------|--------|
| 24 | R-24 | Delete `JSONReportCoder` | 0.5 h |
| 25 | R-25 | Delete `UltraGridMediaFormatRegistry` | 0.5 h |
| 26 | R-26 | Delete `CoreAudioFallbackIdentityCache` | 0.5 h |
| 27 | R-27 | Inline `DebugTrace` wrappers | 1 h |
| 28 | R-28 | Move misplaced type definitions | 0.5 h |

---

## Section 6: P0/P1 Slices Summary

| ID | Finding | Why P0/P1 | Verifiable outcome |
|----|---------|-----------|-------------------|
| R-01 | C-FL-10 | Release gate bypassable with comment | Test rejects `"# Verdict: PASS"` |
| R-02 | C-FL-09 | File read error = absent file | Test returns `.readError`, not `.absent` |
| R-03 | C-FL-02 | Recovery failure = "zero failures" | Test: inject throw → report records failure |
| R-04 | C-FL-11 | Unexpected error type → notes not verdict | Test: inject unexpected throw → `verdict == .fail` |
| R-05 | C-TI-09 | Audio routing completely untested | 4 new routing tests pass |
| R-06 | C-TI-12 | Concurrent handoff completely untested | Concurrent test passes repeatedly |
| R-07 | C-TI-11 | CI fallback tests skip silently | Test passes without `lo0:1` |
| R-08 | C-FL-04/05 | Core Audio cleanup silently fails | All `_ = AudioDevice...` discards replaced; `swift build` clean |
| R-09 | C-FL-08 | UI cannot diagnose corrupt evidence | UI shows distinct state for corrupt vs absent |
| R-10 | C-FL-01 | Second TX error permanently discarded | Test confirms both errors surface |
| R-11 | C-FL-07 | Zero TX bytes looks like partial success | Test confirms `verdict == .fail` for zero-byte run |
| R-12 | C-FL-03 | Signal failures completely silent | `grep "_ = kill"` returns zero results |
| R-13 | C-MC-06 | Safety checklist self-attested | Test confirms gate rejects `false` field |
| R-14 | C-MC-07 | Fabricated metrics look like real data | `grep "p50Microseconds: [1-9]"` returns zero results |
| R-15 | C-TI-04 | Payload corruption undetectable | Payload equality test passes |
| R-16 | C-TI-13 | Wrap-around behavior unverified | Wrap-around test passes |
| R-17 | C-TI-10 | Reconnect state corruption undetectable | 3 continuity tests pass |

---

## Section 7: Low-Risk Quick Wins

These slices have no dependencies, zero or near-zero risk, and can be done in any order.
Each takes under one hour.

| Slice | Risk | Effort | Outcome |
|-------|------|--------|---------|
| R-16 | None | 30 min | 2 sequence tracker tests added |
| R-24 | None | 30 min | `JSONReportCoder` deleted; `swift build` clean |
| R-25 | None | 30 min | `UltraGridMediaFormatRegistry` deleted; `swift build` clean |
| R-26 | None | 30 min | `CoreAudioFallbackIdentityCache` deleted; `swift build` clean |
| R-12 | Low | 30 min | SIGTERM logging added; `grep "_ = kill"` = 0 |
| R-13 | Low | 30 min | Safety checklist comment + 1 test |
| R-18 | Low | 30 min | Snapshot test uses symbolic comparison |
| R-19 | Low | 30 min | Golden float test replaced with seed-equality check |
| I-03 | None | 15 min | `grep` result closes the finding |
| I-04 | None | 15 min | `grep` result closes or scopes the finding |

---

## Section 8: Blocked / Uncertain Items

| Slice | Blocked by | Reason | Action |
|-------|-----------|--------|--------|
| R-07 | I-06 | Transport injection feasibility unknown | Complete I-06 first |
| R-29 (inventory-as-code simplification) | I-01 | CI gate status unknown | Complete I-01 first |
| R-30 (CapabilitySummary statics) | I-02 | Intent unknown | Complete I-02; may close as KEEP |
| R-31 (delete `RealtimeAudioBlockRing`) | I-03 | Callers not confirmed | Complete I-03; may close as KEEP |
| R-32 (inline `DebugTraceFieldPolicy`) | I-04 | Callers not confirmed | Complete I-04; may close as KEEP |
| R-33 (merge Runner/Runtime) | I-05 | Lifecycle split reason unknown | Complete I-05; may close as KEEP |

Items that will not be addressed in this plan (out of scope, too risky without more evidence):
- `ExternalConnectorSessionConfiguration` God struct (C-MC-08) — High blast radius; requires
  full integration test map first. Not in this plan.
- `PlaceholderDetection` replacement (C-MC-09) — Medium risk, medium confidence; defer until
  boundary-case behavior is confirmed by a full test run.
- `AudioRoutingAssumptionLedger` move (C-MC-19) — Low priority; structural/documentation only.
  Follow-on after Phase 3.
- `KeyValueArgumentParser` restructure (C-MC-04) — Medium effort, medium confidence; needs
  `NativeAppRuntimeSmokeConfiguration` test coverage confirmed before acting.
- `GoalCodewiseRequirementID` simplification (C-MC-15) — Low priority; possible fixture JSON
  impact not confirmed.
- `OpenLolaContractsAliases.swift` removal (C-MC-16) — Needs full import-site map before acting.

---

## Section 9: Final Verification Plan

### After each implementation slice

```bash
swift build                    # Must be clean
swift test --no-parallel       # Full suite must pass
```

### After Phase 1 complete (all P0 slices done)

```bash
swift build
swift test --no-parallel
bash scripts/verify-release-readiness.sh
```

Confirm:
- `grep -rn "\.contains(\"Verdict: PASS\")" Sources/` → zero results
- `grep -rn "try? String(contentsOf.*releaseManifest\|try? String(contentsOf.*required" Sources/` → zero results
- `grep -rn "(try? recoverVideoFragments)" Sources/` → zero results
- `grep -rn "errors\.first" Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaLive.swift` → zero results

### After Phase 2 complete (all P1 slices done)

```bash
swift build
swift test --no-parallel
```

Confirm:
- `grep -rn "_ = audioGraph\.stop()\|_ = graph\.stop()" Sources/` → zero results
- `grep -rn "_ = kill(-" Sources/` → zero results
- `grep -rn "p50Microseconds: [1-9]\|cpuP50Percent: [1-9]" Sources/` → zero results

### After Phase 3 complete (all P2 slices done)

```bash
swift build
swift test --no-parallel
```

Confirm:
- `grep -rn "ReportValidationProtocol" Sources/` → zero results
- `grep -rn "RunMode: String, Codable, Equatable, Sendable" Sources/` → 3 results (not 10)

### After Phase 4 complete (all P3 slices done)

```bash
swift build
swift test --no-parallel
```

Confirm:
- `grep -rn "JSONReportCoder\|UltraGridMediaFormatRegistry\|CoreAudioFallbackIdentityCache" Sources/` → zero results
- `grep -rn "DebugTraceJSONEncoder\|DebugTraceTimestampFormatter\|DebugTraceEncodingFailureLine" Sources/` → zero results

### Preserved high-value tests — must not regress at any phase

| Test | Why preserved |
|------|---------------|
| `spscAtomicRingIsSafeUnderConcurrentProducerConsumer` | Only guard on ring buffer threading |
| `realtimeAudioEngineRejectsInvalidReportEvidence` | 20+ typed-error mutation validation tests |
| `udpPcmPacketRoundTripsAgainstHexFixture` + malformed-rejection tests | Wire-format regression guard |
| `syntheticSmokeReportsRejectFalsePassMutations` | Only guard preventing synthetic → runtime PASS |
| `commandInventoryCLIBinaryOutputsCommandListAndProducesExpectedExitCode` | Binary-level regression |
| `lolaMediaReceiveAcceptsEphemeralSourcePortWhenDestinationPortMatches` + siblings | Real-socket LoLa protocol tests |
