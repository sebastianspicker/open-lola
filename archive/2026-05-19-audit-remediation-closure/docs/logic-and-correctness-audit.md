# Logic and Correctness Audit

**Scope**: Open LoLa 2 — `Sources/OpenLolaCore`, `Sources/open-lola`, `Sources/open-lola-app`, `Tests/OpenLolaCoreTests`
**Date**: 2025-05-19
**Constraint**: Read-only audit. No production code changed.

---

## How to read this document

Each finding has:
- **ID** — unique reference (LC-NNN)
- **Location** — file and approximate line
- **Evidence** — exact code or test output
- **Why it matters** — consequence in production
- **Minimal reproduction** — reasoning path, not speculation
- **Existing test coverage** — what currently tests this area
- **Missing test** — what test would catch it
- **Suggested minimal fix** — smallest correct change
- **Risk** — high / medium / low
- **Confidence** — high / medium / low
- **Verification** — how to confirm the finding

Findings are divided into:
- **Confirmed** — code alone proves the issue
- **Suspected** — requires runtime or concurrency analysis to confirm
- **Pre-existing known failures** — already in the test suite as red tests

---

## Confirmed Issues

---

### LC-001: `audioPayloadsDroppedBeforePlayout` double-counts `droppedByPlayoutQueue`

**Location**: `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift`, lines ~420–422

**Evidence**:
```swift
metrics.audioPayloadsDroppedBeforePlayout += audioRX.droppedBeforePlayout
metrics.audioPayloadsDroppedBeforePlayout += audioRX.droppedByPlayoutQueue  // ← added again
metrics.audioPayloadsDroppedByPlayoutQueue += audioRX.droppedByPlayoutQueue  // ← also added here
```
`droppedByPlayoutQueue` is accumulated into `audioPayloadsDroppedBeforePlayout` AND `audioPayloadsDroppedByPlayoutQueue`. The "dropped before playout" metric counts playout-queue rejections twice.

**Why it matters**: Reports and UI latency hero metrics derived from `audioPayloadsDroppedBeforePlayout` are inflated. Any quality gate or session verdict logic that uses this counter compares against an inflated value. The `validateUsefulMediaMoved` function uses `audioPayloadsQueuedForPlayout` (not the dropped counters), so runtime pass/fail is not directly affected — but exported session reports and dashboards are incorrect.

**Minimal reproduction**: Any session with at least one playout-queue rejection. `droppedByPlayoutQueue > 0` ⟹ `audioPayloadsDroppedBeforePlayout > droppedBeforePlayout + droppedByPlayoutQueue` in the report.

**Existing test coverage**: No test asserts the relationship between individual dropped sub-counters and the aggregate.

**Missing test**: A test that constructs a `DirectPeerAudioRXDrainResult` with known `droppedBeforePlayout = 3` and `droppedByPlayoutQueue = 2`, accumulates it into metrics via the socket runner's accumulation block, and asserts `audioPayloadsDroppedBeforePlayout == 5` (not 7) and `audioPayloadsDroppedByPlayoutQueue == 2`.

**Suggested minimal fix**: Remove the duplicate line:
```swift
// Remove: metrics.audioPayloadsDroppedBeforePlayout += audioRX.droppedByPlayoutQueue
```

**Risk**: Medium — incorrect reports; does not affect session runtime correctness.
**Confidence**: High — code alone proves the double-add.
**Verification**: `grep -n "droppedByPlayoutQueue" Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift`

---

### LC-002: UltraGrid `--peer` argument not last — launch plan argument order mismatch

**Location**: `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridLaunchPlan.swift`, lines 72–74 and 75–88; `Tests/OpenLolaCoreTests/ExternalConnectorAvMatrixTests.swift:78`

**Evidence** (confirmed by test run):
```
Expectation failed: (rx.arguments.last → "disabled") == "198.51.100.10"
```

The peer argument is inserted at lines 72–74:
```swift
if !peerArgument.isEmpty {
    arguments += ["--peer", peerArgument]
}
```
Then `--topology`, `--fec`, `--encryption disabled`, `--control disabled` are appended after. `arguments.last` is `"disabled"` (the control mode value) — not the peer IP.

**Why it matters**: If `uv`'s `native-mvtp` subcommand expects the peer address as a trailing positional argument (as the test author assumed), the current order means the peer is not last in the command, and the actual last argument is `"disabled"`. This produces a malformed launch command. No live `uv` binary is present in this checkout (the `uv` on PATH is Astral Python's package manager), so the mis-ordering has not been caught by integration tests.

**Minimal reproduction**: Run `swift test --filter ultraGridPlanUsesConfiguredProductionCaptureAndPlaybackModules`. Observe `rx.arguments.last → "disabled"`.

**Existing test coverage**: `ExternalConnectorAvMatrixTests.swift:78` catches this — it is an actively failing test.

**Missing test**: The test exists but is red. The fix verifies itself.

**Suggested minimal fix**: Move the `--peer` block to after all other flags, so it is the final argument:
```swift
// ...append topology/fec/encryption/control flags first...
if !peerArgument.isEmpty {
    arguments += ["--peer", peerArgument]
}
```

**Risk**: High — produces a malformed `uv` launch command in production; affects any UltraGrid TX or TxRx session with a non-empty peer.
**Confidence**: High — confirmed by failing test output.
**Verification**: `swift test --filter ultraGridPlanUsesConfiguredProductionCaptureAndPlaybackModules`

---

### LC-003: `validateAVConfiguration` validates `audioDeviceUID` (input only) — does not separately check `outputDeviceUID`

**Location**: `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift`, line 88; `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift`, line 131

**Evidence**:
```swift
// validateAVConfiguration (line ~88):
guard !configuration.audioDeviceUID.isEmpty else {
    throw DirectPeerSessionAVRuntimeError.missingAudioDeviceUID
}
```
`audioDeviceUID` is `@available(*, deprecated)` and returns `inputDeviceUID`. In `DirectPeerSessionAVRunConfiguration`, `audioDeviceUID = audioDeviceUID ?? inputDeviceUID`. A caller that sets `inputDeviceUID = "MyDevice"` and `outputDeviceUID = ""` will pass this check. `outputDeviceUID` is not validated in `validateAVConfiguration`.

The output device UID is only checked much later at line ~330 (during graph `start()`):
```swift
guard let outputDeviceID = preflight.outputDevice?.id else {
    throw DirectPeerAudioGraphError.missingDeviceUID(configuration.outputDeviceUID)
}
```
By that point the audio graph has already been configured and CoreAudio preflight has run.

**Why it matters**: A caller that sets `inputDeviceUID` correctly but leaves `outputDeviceUID` empty will pass early validation, build the graph with an empty output UID, fail during start with `DirectPeerAudioGraphError.missingDeviceUID("")`, and get a misleading error (empty string in the error message). The validation contract is silently incomplete.

**Minimal reproduction**: Pass a `DirectPeerSessionAVRunConfiguration` with non-empty `inputDeviceUID` and empty `outputDeviceUID` to `validateAVConfiguration`; observe no error thrown. The error surfaces later with a confusing empty-string device UID message.

**Existing test coverage**: No test probes this exact combination.

**Missing test**: A test that constructs a configuration with non-empty `inputDeviceUID`, empty `outputDeviceUID`, and calls `validateAVConfiguration`, expecting `missingAudioDeviceUID` (or a new `missingOutputDeviceUID`) to be thrown.

**Suggested minimal fix**: Add a separate output device check in `validateAVConfiguration`:
```swift
guard !configuration.outputDeviceUID.isEmpty else {
    throw DirectPeerSessionAVRuntimeError.missingAudioDeviceUID  // or a new missingOutputDeviceUID error
}
```

**Risk**: Medium — silent deferred validation failure; misleading error message in production.
**Confidence**: High — code alone proves the gap.
**Verification**: `grep -n "audioDeviceUID\|outputDeviceUID" Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift | head -20`

---

### LC-004: `reserveInputStartFrame()` advances the frame counter before copy success

**Location**: `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`, `copyInputToCaptureRing`, lines ~570–590

**Evidence**:
```swift
private func copyInputToCaptureRing(
    input: UnsafePointer<AudioBufferList>,
    hostTimeNanoseconds: UInt64
) {
    let buffers = ReadOnlyAudioBufferListPointer(input)
    guard !buffers.isEmpty else { return }
    let startFrame = reserveInputStartFrame()  // ← fetch_add: counter advances HERE
    let copyResult = copyMappedInput(from: buffers)
    guard copyResult == .copied else {
        increment(&droppedInputBlocks)
        return  // startFrame consumed; gap created in sequence
    }
    let result = captureRing.push(startFrame: startFrame, ...)
    recordCaptureResult(result)
}
```
`reserveInputStartFrame()` is an atomic fetch-add on `nextInputFrame`. If `copyMappedInput` fails (null buffer, wrong channel count, etc.), the counter has already advanced. The next successful copy gets `startFrame + 2` instead of `startFrame + 1`, creating a gap in the frame sequence that is never filled in the capture ring.

**Why it matters**: The output side's RX buffer correlates playout frame indices to received network frames. A gap in the local capture ring breaks this correlation for the TX side (sequence numbers derived from `startFrame` will skip a value). On the receiver, the missing sequence number will be treated as a dropped packet. The `droppedInputBlocks` counter is incremented, but the gap in `nextInputFrame` persists — it is not corrected.

**Minimal reproduction**: Trigger `copyMappedInput` failure (e.g., pass a CoreAudio buffer with 0 channels or a null data pointer to the IOProc callback); observe that the subsequent successful packet has a sequence number one higher than expected rather than consecutive.

**Existing test coverage**: None directly tests the copy-fail → gap behavior.

**Missing test**: A test that injects a nil-buffer input, then a valid buffer, and asserts that sequence numbers are still consecutive after the nil-buffer event (currently they would not be).

**Suggested minimal fix**: Reserve `startFrame` only after `copyMappedInput` succeeds:
```swift
let copyResult = copyMappedInput(from: buffers)
guard copyResult == .copied else {
    increment(&droppedInputBlocks)
    return
}
let startFrame = reserveInputStartFrame()
```

**Risk**: Medium — creates sequence gaps under pathological CoreAudio buffer conditions; not triggered in normal operation.
**Confidence**: High — code logic is unambiguous.
**Verification**: Read `copyInputToCaptureRing` and `reserveInputStartFrame` in `DirectPeerRealtimeAudioGraph.swift`.

---

### LC-005: IOProc returns `kAudioHardwareIllegalOperationError` on host-time overflow — silently stops the device

**Location**: `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphCallbacks.swift`, lines ~91 and ~117

**Evidence**:
```swift
guard let hostTimeNanoseconds = graph.nanoseconds(fromHostTime: inNow.pointee.mHostTime) else {
    return kAudioHardwareIllegalOperationError
}
```
`nanoseconds(fromHostTime:)` returns `nil` when `hostTime * numerator` overflows `UInt64`. Returning `kAudioHardwareIllegalOperationError` from an IOProc causes Core Audio to immediately stop the device. The graph's `ioProcRunning` flag is not cleared; no error is surfaced to the session layer; the session loop continues as if the IOProc is running.

**Why it matters**: If this path were ever triggered (high-uptime system, unusual Mach timebase values), audio would silently stop without the session layer detecting it. The `ioProcRunning` flag stays `true`, so `captureInjectedPayload` (test path) would still be gated open, and the session would not throw `audioGraphStopped`. Metrics would show zero packets in/out but no error.

**Practical reachability**: On Apple Silicon with the standard 1:1 Mach timebase (`numer=1, denom=1`), `hostTime` IS the nanosecond count directly (no multiply). The overflow would require ≈584 years of uptime. This is unreachable in practice.

**Minimal reproduction**: Construct a graph with `hostTimeNumerator = UInt64.max` (not normally possible via the public API) and call the IOProc; observe the error return and silent stop.

**Existing test coverage**: None.

**Missing test**: A unit test for `nanoseconds(fromHostTime:)` with overflow inputs, and documentation that the overflow is intentionally unreachable given standard Mach timebase values.

**Suggested minimal fix**: Add a comment documenting why overflow is unreachable. Alternatively, return `kAudioHardwareNoError` for the overflow case and zero-fill the output (the session would drop that block but not die):
```swift
guard let hostTimeNanoseconds = graph.nanoseconds(fromHostTime: inNow.pointee.mHostTime) else {
    // Mach timebase overflow is unreachable on standard Apple hardware.
    // Drop this callback block rather than stopping the device.
    return kAudioHardwareNoError
}
```

**Risk**: Low — unreachable in practice; catastrophic if triggered.
**Confidence**: High — code path is clear; consequence is well-documented CoreAudio behavior.
**Verification**: Read `directPeerRealtimeAudioIOProc` and `nanoseconds(fromHostTime:)`.

---

### LC-006: `UdpPcmSequenceTracker` throws on any gap — permanently fails on lossy networks

**Location**: `Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift`, `UdpPcmSequenceTracker`

**Evidence**: `accept()` throws `unexpectedSequence` for any `sequenceNumber != lastAccepted + 1`. No reset or resync path exists after a throw. The caller in the audio TX loop does not catch `unexpectedSequence` — it propagates, ending the session.

**Why it matters**: On any real UDP path with packet drops, a single dropped packet permanently breaks the sequence tracker. The session throws rather than continuing with degraded quality. Whether this is intentional ("loopback-only mode") is undocumented. The `UdpPcmSequenceTracker` name does not indicate this constraint.

**Minimal reproduction**: Send two UDP audio packets with sequence numbers 1 and 3 (skipping 2) to a peer using `UdpPcmSequenceTracker`; observe session failure.

**Existing test coverage**: `UdpPcmPacketTests.swift` tests valid sequential packets; no test exercises the gap/recovery behavior.

**Missing test**: A test that calls `accept()` with a gap and verifies the expected error; plus documentation clarifying whether gapless delivery is a hard requirement or a loopback assumption.

**Suggested minimal fix**: Either:
1. Document explicitly that `UdpPcmSequenceTracker` is only valid on lossless paths (rename to `UdpPcmLosslessSequenceTracker`), or
2. Add a gap-tolerance mode that counts lost packets and continues rather than throwing.

**Risk**: High — any real-network packet drop terminates the session immediately.
**Confidence**: High — code logic is unambiguous; behavior is confirmed by reading the throw path.
**Verification**: `grep -n "unexpectedSequence\|lastAccepted" Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift`

---

### LC-007: Stale test substring in `syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass`

**Location**: `Tests/OpenLolaCoreTests/SyntheticSmokeReportContractTests.swift:76`

**Evidence** (confirmed by test run):
```
Expectation failed: report.assumptions.contains { $0.contains("Swift-native UDP DEFAULT, JAMLINK, and EMPTY-header audio packetization") }
```
The production string in `ExternalConnectorReport.swift:315` is:
```
"JackTrip connector uses Swift-native UDP DEFAULT, JAMLINK, EMPTY-header, WebRTC data-channel, ..."
```
The test checks for `"JAMLINK, and EMPTY-header audio packetization"` which is neither a substring of the production string (`JAMLINK, EMPTY-header,` — no `and`, no `audio packetization` suffix) nor matches any other assumption string.

**Why it matters**: The test is permanently red and provides no safety net. Any change to the JackTrip assumption string would not be caught by this test. The test asserts a string that has diverged from the source.

**Minimal reproduction**: `swift test --filter syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass`.

**Existing test coverage**: The test itself is the coverage — but it is broken.

**Missing test**: The test should be updated to use a substring that actually appears in the current production assumption string.

**Suggested minimal fix**: Update the `contains` substring to match the current production string:
```swift
#expect(report.assumptions.contains { $0.contains("Swift-native UDP DEFAULT, JAMLINK, EMPTY-header") })
```

**Risk**: Low — test-only issue; no runtime impact.
**Confidence**: High — confirmed by running the test.
**Verification**: `swift test --filter syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass`

---

## Suspected Issues (Needs Runtime or Concurrency Verification)

---

### LC-008: `currentPlayoutTargetFrames()` acquires `NSLock` inside the receive-loop call chain — potential contention

**Location**: `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`, `queuePlayoutPayload` → `currentPlayoutTargetFrames()`; `rxBufferAdaptationLock` is an `NSLock`

**Evidence**: `queuePlayoutPayload` is called from `runAudioRXLoop`, which runs on the network receive task. `currentPlayoutTargetFrames()` acquires `rxBufferAdaptationLock`. `observeAdaptiveRxBuffer` is also called under this lock, and its body calls `DispatchTime.now().uptimeNanoseconds`.

The IOProc path (realtime thread) also accesses RX buffer state through `renderPlayout`. Whether `renderPlayout` takes `rxBufferAdaptationLock` needs verification.

**Why it matters**: If `renderPlayout` ever acquires `rxBufferAdaptationLock` from the CoreAudio realtime thread, this is a priority inversion and a realtime-safety violation. `NSLock` is not safe to acquire from a realtime thread. If it does not (playout reads committed state without the lock), the concern is reduced.

**Minimal reproduction**: Trace the call chain from `directPeerRealtimeAudioOutputIOProc` → `graph.processOutputIO` → `renderPlayout` and check for any `rxBufferAdaptationLock` acquisition.

**Existing test coverage**: None tests lock ordering on the realtime path.

**Missing test**: Not easily unit-testable; requires a thread-sanitizer run or explicit lock-order audit.

**Suggested minimal fix**: Confirm by code inspection that `renderPlayout` does NOT acquire `rxBufferAdaptationLock`. If it does, switch to `os_unfair_lock` or redesign the playout path to read committed state without locking.

**Risk**: High IF `renderPlayout` acquires the lock; Low otherwise.
**Confidence**: Low — needs targeted code inspection and/or thread-sanitizer.
**Verification**: `grep -n "rxBufferAdaptationLock\|renderPlayout" Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`

---

### LC-009: `AppExecutionController.validateReport()` lacks guard against concurrent double-invocation

**Location**: `Sources/open-lola-app/AppExecutionController.swift`, `validateReport` methods (lines ~209–252)

**Evidence**:
```swift
func validateReport(executablePath: String) {
    guard !isRunning else {
        lastError = "Cannot validate while a run is active."
        return
    }
    // ...
    runOneShot(arguments: arguments) { ... }
}
```
`isRunning` checks whether `process?.isRunning == true`. `runOneShot` also sets `self.process`. If two UI actions simultaneously call `validateReport` (e.g., double-tap in the SwiftUI view), the second call's `isRunning` check passes (the first `runOneShot` might not have set `self.process` yet, depending on MainActor scheduling), resulting in two concurrent validation processes, with the second overwriting `lastValidationExitCode`.

**Why it matters**: Double-validation could produce a misleading `validationPassed` or `validationFailed` state from whichever process exits last. `lastCommand`, `lastValidationExitCode`, and `errorLog` would be written by the second process, masking the first.

**Minimal reproduction**: Rapidly trigger `validateReport` twice from the UI. Requires MainActor scheduling analysis to confirm.

**Existing test coverage**: None — `AppExecutionController` has no unit tests.

**Missing test**: A MainActor unit test that calls `validateReport` twice in sequence without awaiting and asserts that only one process is launched.

**Suggested minimal fix**: Check `phase == .validationRunning` or `process != nil` in addition to `!isRunning`:
```swift
guard !isRunning, process == nil else { return }
```

**Risk**: Low — unlikely in practice with normal UI usage; no data corruption, just misleading state.
**Confidence**: Medium — requires MainActor concurrency analysis to confirm the race window.
**Verification**: Add `print` traces to `runOneShot` and call `validateReport` twice in a unit test.

---

## Pre-existing Known Test Failures

These failures were present before this audit and are catalogued in `docs/verification-baseline.md`. They are included here because two of them indicate correctness issues.

---

### LC-010: JackTrip files exceed 720-line code budget

**Location**: `Sources/OpenLolaCore/Connectors/JackTrip/JackTripCompatibility.swift` (764 lines), `Tests/OpenLolaCoreTests/JackTripCompatibilityTests.swift` (768 lines)

**Failing test**: `scopedCodeFilesStayWithinLineBudget`

**Why it matters**: A quality gate exists to catch files that are too large to reason about. Both files exceed it. This is a policy violation flagged by the test suite, not a runtime crash.

**Suggested action**: Split each file to bring both under 720 lines.

**Risk**: Low — does not affect runtime behavior.
**Confidence**: High.

---

### LC-011: UltraGrid RX launch plan produces wrong final argument

**Location**: `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridLaunchPlan.swift`; `Tests/OpenLolaCoreTests/ExternalConnectorAvMatrixTests.swift:78`

This is the same root cause as **LC-002** above. Documented here for cross-reference as a pre-existing failing test.

---

### LC-012: Fixture smoke matrix missing `JackTripCompatibilityMediaReports` and `UltraGridCompatibilityMediaReports` entries

**Location**: `Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift`; `Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift`

**Failing test**: `fixtureSmokeMatrixMatchesFixtureTree`

**Why it matters**: Fixture directories exist but are not registered in the smoke matrix. New fixtures added to these directories would not be automatically exercised by smoke tests.

**Suggested action**: Add the two missing entries to FixtureSmokeMatrixData.swift.

**Risk**: Low.
**Confidence**: High.

---

### LC-013: `externalConnectorNmpPreflightRuns*` fails due to `uv` PATH collision

**Location**: `Tests/OpenLolaCoreTests/ExternalConnectorNmpPreflightTests.swift`

**Why it matters**: Tests that shell out to `uv` are hitting Astral Python's `uv` (package manager) instead of UltraGrid's `uv`. Tests pass vacuously or fail with a confusing error. No real UltraGrid binary is being tested.

**Suggested action**: Gate these tests on the presence of a real UltraGrid binary at a specific path, or inject the binary path as a test environment variable.

**Risk**: Medium — provides false assurance that UltraGrid integration is tested.
**Confidence**: High.

---

## Not Inspected / Coverage Gaps

The following areas were not deeply audited in this pass:

| Area | File(s) | Risk | Reason Not Inspected |
|------|---------|------|----------------------|
| Adaptive RX buffer timing | `Sources/OpenLolaCore/Timing/RxBuffering.swift` | High | File not read in this audit |
| Network diagnostics | `Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift` | Medium | Large file, skipped for scope |
| Evidence status matrix verdict logic | `Sources/OpenLolaCore/Release/CurrentEvidenceStatusMatrix.swift` | Medium | Not read |
| Goal runtime preflight validation | `Sources/OpenLolaCore/Release/Goal/GoalRuntimePreflight.swift` | Medium | Not read |
| AES67 RTP clock mapping | `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift`, `aes67ClockMapper` | Medium | Clock drift accumulation not verified |
| Video RX reassembly and frame ordering | `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVVideoLoops.swift` | Medium | Not read |
| MilestoneCommands 62-arm switch | `Sources/open-lola/Commands/MilestoneCommands.swift` | Low | Noted in deprecation audit; no logic risk |
| Linux connector protocol logic | `linux_connector/lola_connector/` | Medium | Python code; pytest passes; not deeply audited here |
| `ExternalConnectorSession` report verdict accumulation | `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift` | Medium | Report building reviewed at the type level only |

---

## Summary Table

| ID | Location | Category | Risk | Confidence | Status |
|----|----------|----------|------|------------|--------|
| LC-001 | DirectPeerSessionAVSocketRunner.swift ~420 | Metric double-count | Medium | High | Confirmed |
| LC-002 | UltraGridLaunchPlan.swift 72–74 | Argument order wrong | High | High | Confirmed (failing test) |
| LC-003 | DirectPeerSessionAVSocketRunner.swift ~88 | Missing validation | Medium | High | Confirmed |
| LC-004 | DirectPeerRealtimeAudioGraph.swift ~570 | Frame counter pre-advance | Medium | High | Confirmed |
| LC-005 | DirectPeerRealtimeAudioGraphCallbacks.swift ~91 | IOProc stops device | Low (unreachable) | High | Confirmed |
| LC-006 | UdpPcmPacket.swift | No gap tolerance | High | High | Confirmed |
| LC-007 | SyntheticSmokeReportContractTests.swift:76 | Stale test string | Low | High | Confirmed (failing test) |
| LC-008 | DirectPeerRealtimeAudioGraph.swift | NSLock on RT path | High (if true) | Low | Suspected |
| LC-009 | AppExecutionController.swift | Double-validation race | Low | Medium | Suspected |
| LC-010 | Connectors/JackTrip/JackTripCompatibility.swift | Line budget exceeded | Low | High | Pre-existing |
| LC-011 | UltraGridLaunchPlan.swift | See LC-002 | High | High | Pre-existing |
| LC-012 | FixtureSmokeMatrix.swift | Missing fixture entries | Low | High | Pre-existing |
| LC-013 | ExternalConnectorNmpPreflightTests.swift | PATH collision | Medium | High | Pre-existing |

---

## Highest-Risk Findings

1. **LC-006** (`UdpPcmSequenceTracker` gap intolerance): Any UDP packet drop ends the session permanently. This is the highest practical runtime risk if the system is ever used on a non-loopback path.
2. **LC-002** (UltraGrid peer argument order): Produces a malformed launch command for every UltraGrid TX session with a peer. A failing test confirms this.
3. **LC-008** (NSLock on possible RT path): If `renderPlayout` acquires `rxBufferAdaptationLock`, realtime-safety is violated. Needs targeted verification.
4. **LC-004** (frame counter pre-advance): Silent frame sequence gaps under pathological CoreAudio buffer conditions; misattributes drops to the network layer.

## Verified vs. Suspected

**Verified by code inspection**: LC-001, LC-002, LC-003, LC-004, LC-005, LC-006, LC-007, LC-010, LC-011, LC-012, LC-013

**Suspected (needs runtime or concurrency verification)**: LC-008, LC-009

## Follow-up Actions Recommended

1. Fix LC-002 (UltraGrid peer argument order) — confirmed failing test, clear minimal fix.
2. Fix LC-007 (stale test substring) — one-line change restores a passing test.
3. Fix LC-001 (metric double-count) — remove one line; does not affect runtime correctness.
4. Investigate LC-008 (NSLock on RT path) — `grep -n "rxBufferAdaptationLock" DirectPeerRealtimeAudioGraph.swift` and trace from `renderPlayout`.
5. Document LC-006 — explicitly constrain `UdpPcmSequenceTracker` to lossless paths or add gap recovery.
