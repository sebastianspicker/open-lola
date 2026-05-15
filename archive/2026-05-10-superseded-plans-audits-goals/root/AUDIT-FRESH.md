# AUDIT-FRESH.md — open-lola2 Full Codebase Audit

**Date:** 2026-05-09  
**Method:** Fleet of 5 parallel explore agents, each reading source files in full.  
**Scope:** All 280 Swift source files (~73k LOC), 53 Python files, 176 test files, Bash scripts.  
**Prior art:** AUDIT.md (2026-05-08), CODE_AUDIT.md (2026-05-09) — this is a fresh, independent pass.  
**Output scope:** Findings only. No code was changed.

---

## Severity Legend

| Level | Meaning |
|---|---|
| 🔴 CRITICAL | Production crash, data corruption, resource leak, or security risk under realistic load |
| 🟠 HIGH | Correctness bug, race condition, or significant maintainability hazard |
| 🟡 MEDIUM | Fragile code, silent failure, UX gap, or structural problem |
| 🔵 LOW | Style inconsistency, minor inefficiency, or informational |

---

## Executive Summary

| Area | 🔴 CRITICAL | 🟠 HIGH | 🟡 MEDIUM | 🔵 LOW |
|---|---|---|---|---|
| General code quality | 0 | 4 | 6 | 7 |
| UI (SwiftUI app) | 3 | 8 | 10 | 3 |
| Realtime audio | 1 | 3 | 2 | 0 |
| UDP / network transport | 3 | 10 | 0 | 1 |
| P2P session | 0 | 3 | 0 | 0 |
| Video | 4 | 2 | 3 | 0 |
| Control / connectors | 0 | 6 | 2 | 0 |
| Test suite | 4 | 5 | 9 | 2 |
| **Total** | **15** | **41** | **32** | **13** |

**Highest-risk systems before any hardware session:** UDP socket lifecycle, video reassembly buffer, realtime audio callback state, and the SwiftUI subprocess controller.

---

## Pass 1 — General Code Quality

### 🟠 HIGH — Validation helper function explosion

**Files:** `PackagingFieldTestHelpers.swift`, `RecordingSessionHelpers.swift`, `ReferenceRigHelpers.swift`, `LatencyTuningReportValidation.swift`, `PerformanceAuditReportValidation.swift`, and ~20 others.

Each validation extension defines 8–15 private `require*` functions that are structurally identical and differ only in error type:

```swift
// PackagingFieldTestHelpers.swift
private func requirePackagingNonEmpty(_ value: String, _ field: String) throws { ... }
private func requirePackagingPositive(_ value: Int, _ field: String) throws { ... }

// RecordingSessionHelpers.swift
private func requireRecordingNonEmpty(_ value: String, _ field: String) throws { ... }
private func requireRecordingPositive(_ value: Int, _ field: String) throws { ... }
```

`ValidationPrimitives` exists but is not the single source — each module wraps it with its own error type. Total count: 217+ private helper functions doing the same structural thing. If validation logic changes, 20+ files need updating.

**Fix:** Generic error-mapping wrapper: `ValidationPrimitives.require(...) { error in MyError.fieldInvalid(error) }`.

---

### 🟠 HIGH — 59 empty protocol conformance extensions in ReportValidatorSurface

**File:** `Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift`, lines 50–108.

Every report type gets an empty `extension Foo: ReportValidatingArtifact {}` marker. No behaviour. 59 lines of structural noise that must be maintained when a new report type is added.

**Fix:** Default `validate()` implementation in the protocol; opt-in override where needed. Or a Swift macro.

---

### 🟠 HIGH — CommandLineArguments duplicates KeyValueArgumentParser

**Files:** `Sources/OpenLolaCore/Support/CommandLineArguments.swift` and `Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift`.

Both parse `--key value` CLI arguments with nearly identical logic and different APIs. No call site justifies two parsers.

**Fix:** Delete `CommandLineArguments.swift`; migrate call sites to `KeyValueArgumentParser`.

---

### 🟠 HIGH — Repetitive JSON output ceremony in CLI handlers

**File:** `Sources/open-lola/main.swift` and all command files under `Sources/open-lola/Commands/`.

Every command follows the same four-line ceremony:

```swift
let report = try SomeDomain.run(config)
print(try report.prettyJSONString())
try writeJSONData(try report.prettyJSONData(), to: outputPath)
print("VERDICT: \(report.verdict.rawValue.uppercased())")
```

This appears ~40 times. VERDICT printing is also inconsistent: some sites hardcode `"PASS"`, others read from `report.verdict`.

**Fix:** `func runAndPrint<R: ReportValidatingArtifact>(_ factory: () throws -> R, output: URL?) throws`.

---

### 🟡 MEDIUM — MeasurementMethodology.swift is a one-liner type alias

**File:** `Sources/OpenLolaCore/Core/MeasurementMethodology.swift`.

Entire file: `public typealias HardwareValidationRunMode = MeasurementMethodology`. Nothing else. Move inline or delete.

---

### 🟡 MEDIUM — Naming convention drift: Helpers vs Support vs Utilities

Mixed suffixes across utility files with no semantic distinction: `PackagingFieldTestHelpers`, `RecordingSessionHelpers`, `ReferenceRigHelpers` vs `DirectP2PSessionRunArgumentSupport`, `DirectP2PMeasuredEvidenceCommandSupport`. No rule governing when to use which.

**Fix:** Settle on `*Helpers` for validation/parsing utilities; `*Support` for CLI argument shims. Document the rule.

---

### 🟡 MEDIUM — Validation error types have no structural variation

32+ `ValidationError` enums across the codebase, each with cases like `.emptyField(String)`, `.nonPositiveField(String)`. They carry no different information — only the type name differs. This inflates the type namespace for no benefit.

**Fix:** Single `ValidationError<Context: Hashable>` generic, or a struct with a context tag.

---

### 🟡 MEDIUM — Large validation files mixing error definitions with orchestration

`LatencyTuningReportValidation.swift` (427 lines), `PerformanceAuditReportValidation.swift` (392 lines), `IntegratedAvReportValidation.swift` (384 lines) each define their error enum and the full validation logic in one file. Hard to navigate.

**Fix:** Split into `*ValidationErrors.swift` and `*Validation.swift`.

---

### 🟡 MEDIUM — DebugTrace has two inline JSONEncoder setups

**File:** `Sources/OpenLolaCore/Core/DebugTrace.swift`, lines 41–52 and 95–112.

Two `JSONEncoder()` construction + `outputFormatting` setup blocks, 10 lines apart, in a 120-line file.

**Fix:** Extract one private `static let encoder: JSONEncoder`.

---

### 🟡 MEDIUM — Python: incomplete type annotations and no strict mypy

**File:** `linux_connector/lola_connector/backends.py`.

`ProcessLifecycleMixin` and several functions lack return type annotations. No `mypy --strict` in CI. Type errors in the LoLa media codec and control socket paths will be invisible until runtime.

**Fix:** Add `mypy --strict linux_connector` to CI; annotate all public functions.

---

### 🔵 LOW — Package.swift repeats linker flag sets verbatim

**File:** `Package.swift`, lines 48–56 and 61–68.

Two executable targets share identical `unsafeFlags` linker settings copy-pasted. Drift risk.

**Fix:** Extract to a `let commonLinkerSettings: [LinkerSetting] = [...]` variable.

---

### 🔵 LOW — Bash scripts repeat error-handling patterns

**File:** `scripts/verify-release-readiness.sh` and `scripts/verify-docs.sh`.

Both define their own "require file exists" and "require pattern in file" helpers that are functionally identical. No shared `scripts/lib/common.sh` entry point.

**Fix:** Move common validators to `scripts/lib/common.sh` and `source` it.

---

### 🔵 LOW — OpenLolaCLI methods are structural copies

**File:** `Sources/OpenLolaCore/Core/OpenLolaCLI.swift`, lines 45–77.

~10 static methods each follow: create report → validate → call `prettyJSONData()` → return. No abstraction.

**Fix:** Single generic dispatcher `private static func reportJSON<R>(_ factory: () throws -> R) throws -> Data`.

---

### 🔵 LOW — VERDICT printing inconsistency

Some CLI handlers print `"VERDICT: PASS"` as a hardcoded string; others print `report.verdict.rawValue.uppercased()`. If a verdict case is renamed, some handlers silently diverge.

**Fix:** Always use the dynamic variant.

---

### 🔵 LOW — ReportSchemaInventory duplicates PrettyJSONCodable logic

**File:** `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`, lines 71–76.

Has its own `prettyJSONData()` that sets up a `JSONEncoder` instead of conforming to `PrettyJSONCodable`.

**Fix:** Conform to `PrettyJSONCodable`.

---

## Pass 2 — UI Audit (SwiftUI / open-lola-app)

### 🔴 CRITICAL — Timer never invalidated; memory leak in AppAudioLevelMeter

**File:** `Sources/open-lola-app/AppReceiverPreviewServices.swift`, line 166.

`Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true)` is created in `start()` and only invalidated in `stop()`. If the owning view is dismissed without calling `stop()` (e.g. parent view replaced), the timer fires indefinitely, pinning the object in memory and wasting CPU on a 12.5 Hz update loop.

**Fix:** Add `deinit { timer?.invalidate() }` to the owning class; add `.onDisappear { meter.stop() }` in the view.

---

### 🔴 CRITICAL — Subprocess never terminated on view dismiss

**File:** `Sources/open-lola-app/AppExecutionController.swift`, lines 74–82.

The running `Process` is stored in an `@ObservationIgnored` property. There is no `deinit`, no `.onDisappear` handler that calls `stop()`. If the user closes the window or navigates away while a CLI command is running, the subprocess becomes a zombie — still consuming CPU and holding file handles — with no way to kill it from the UI.

**Fix:**
```swift
deinit {
    process?.terminate()
}
```
And in the view: `.onDisappear { executionController.stop() }`.

---

### 🔴 CRITICAL — Published properties updated off main thread

**File:** `Sources/open-lola-app/AppReceiverPreviewServices.swift`, lines 40–43.

`AVCaptureDevice.requestAccess(for:)` delivers its completion handler on a background thread. The code wraps updates in `Task { @MainActor in }`, but if `self` is released between the closure capture and the task execution, `self?.startAuthorized()` is silently skipped with no error path — the UI stays in a stale "requesting" state forever.

**Fix:** Capture `[weak self]` explicitly inside the `Task` initializer and guard immediately.

---

### 🟠 HIGH — NativeAppShellSurface.swift is a 707-line god file

**File:** `Sources/OpenLolaCore/Platform/NativeAppShellSurface.swift`.

Contains: 6+ struct/enum type definitions (`AudioDeviceOption`, `VideoDeviceOption`, `LocalMediaSelection`, `LocalMediaInventory`, `DirectPeerCommandFields`, `LocalDirectPeerCommand`, `LocalCommandHandoff`, `OperatorPrototypeState`, `LaunchProbePlan`, `SurfaceContract`, `SurfaceSection`, `SurfaceAction`), validation errors, probe reports, and factory methods. Single-responsibility principle is absent. Any change touches the entire file.

**Fix:** Split into `NativeAppShellMediaDevices.swift`, `NativeAppShellMediaInventory.swift`, `NativeAppShellDirectPeerCommand.swift`, `NativeAppShellOperatorState.swift`, `NativeAppShellSurfaceContract.swift`.

---

### 🟠 HIGH — Business logic and side effects in view bodies

**File:** `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`, lines 22–27.

`Button("Refresh Inventory")` directly calls `AppLocalOperatorInventory.capture(...)` and mutates `operatorSurface` state. This is synchronous I/O in a button action inside a view — untestable, no loading state, no error path shown to the user.

**Fix:** Extract to a view model; return errors through a `@State var inventoryError: Error?` that triggers an `.alert`.

---

### 🟠 HIGH — @MainActor enforcement inconsistent in AppVideoPreviewController

**File:** `Sources/open-lola-app/AppReceiverPreviewServices.swift`, lines 9–11, 40–43.

`AppVideoPreviewController` is marked `@MainActor`, but its `start()` method sets up an `AVCaptureSession` — an operation that must run off the main thread. The `@MainActor` annotation blocks the wrong thread.

**Fix:** Mark class `@MainActor` for state access, but run capture session setup on a stored `DispatchQueue(label:, qos: .userInitiated)`.

---

### 🟠 HIGH — Unregistered Task in AppChannelMeterView

**File:** `Sources/open-lola-app/AppChannelMeterView.swift`, lines 140–152.

Peak decay `Task { @MainActor in }` is created on appearance and stored in `@State var peakDecayTask`. The `.onDisappear` cancels it, but if the view is unmounted before `onDisappear` fires (rapid navigation), the task modifies state on a deallocated view without crashing only by luck of `@State` reference counting.

**Fix:** Use a `@StateObject` wrapper for the task lifecycle, ensuring cancellation is tied to object dealloc.

---

### 🟠 HIGH — Timer publisher never explicitly cancelled in AppShellRootView

**File:** `Sources/open-lola-app/AppShellRootView.swift`, lines 86–88.

`Timer.publish(every: 1, ...).autoconnect()` sink is stored in a local `@State` but the cancellable is not retained across re-renders. The autoconnect publisher stays alive as long as the RunLoop schedules it — which is until the app quits.

**Fix:** Store `AnyCancellable` in `@State private var timerCancellable: AnyCancellable?`; cancel `.onDisappear`.

---

### 🟠 HIGH — NSLock in Core Audio meter tap callback path

**File:** `Sources/open-lola-app/AppReceiverPreviewServices.swift`, lines 181–242.

`AppCoreAudioInputMeterTap` uses `NSLock()` to protect `rawLevels`. If this tap is installed as a Core Audio render callback or tap notification, the lock is acquired on a real-time thread — a priority inversion hazard that can cause audio glitches.

**Fix:** Replace with `os_unfair_lock` (lower overhead, still a mutex) or a lock-free approach using `OSAtomicCompareAndSwap`.

---

### 🟠 HIGH — No error surface for file I/O failures in AppOperatorArtifactViews

**File:** `Sources/open-lola-app/AppOperatorArtifactViews.swift`, lines 107–115.

File write failures set a `status` string. If the plan file fails to write (permissions, disk full), the user sees a small text label that may scroll out of view. No alert, no disabling of dependent actions.

**Fix:** Add `@State var fileError: Error?` and `.alert` modifier.

---

### 🟠 HIGH — Binding recreation on every render in AppLocalOperatorSurfaceView

**File:** `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`, lines 104–112.

`remoteInventoryTextBinding()` is called from the view body and constructs a `Binding<String>` on every render pass. SwiftUI has no mechanism to memoize this — it re-evaluates on every parent invalidation.

**Fix:** Move binding construction to an `@State` or `@StateObject`; compute once.

---

### 🟡 MEDIUM — Fat view: AppShellDetailView is 173-line switch statement

**File:** `Sources/open-lola-app/AppShellRootView.swift`, lines 97–271.

`AppShellDetailView` body is a `switch` over 8 sections, each returning a complex view subtree inline. Makes it hard to reason about what any one section displays.

**Fix:** Extract each case to its own named view struct (`AppOverviewSectionView`, `AppSessionSectionView`, etc.).

---

### 🟡 MEDIUM — Type mismatch risk in @AppStorage integer properties

**File:** `Sources/open-lola-app/AppShellSettingsView.swift`, lines 25–41.

`@AppStorage("channelCount") private var channelCount = 64`. No bounds validation. A stale or manually edited UserDefaults value of `-1` or `100000` is accepted silently.

**Fix:** Add computed property wrapper that clamps to valid range.

---

### 🟡 MEDIUM — 39 storage keys, no usage map

**File:** `Sources/open-lola-app/AppStorageKeys.swift`.

39 string constants defined; no documentation of which views read/write which keys. Stale keys accumulate invisibly.

**Fix:** Add a comment block mapping each key to its read/write sites. Run a periodic grep to verify all keys are used.

---

### 🟡 MEDIUM — Hardcoded nil latency metrics on overview tab

**File:** `Sources/open-lola-app/AppShellRootView.swift`, lines 151–156.

`AppLatencyHeroView` is always called with `nil` values, so users always see `—` for latency, jitter, and packet loss — even after a session has run and captured metrics.

**Fix:** Wire up real metrics from `captureReport` when a session report is available.

---

### 🟡 MEDIUM — Error states not shown as alerts

**File:** `Sources/open-lola-app/AppExecutionView.swift`, lines 67–71.

`plan.validationError` is displayed inline in a `GroupBox` that may be below the fold. Critical errors (wrong executable path, missing plan) are invisible until the user scrolls.

**Fix:** Show validation errors as `.alert` or a sticky banner at the top of the view.

---

### 🟡 MEDIUM — No progress indicator on slow operations

**File:** `Sources/open-lola-app/AppExecutionView.swift`, lines 40–62.

"Write Plan", "Dry Run", "Start" buttons have no loading state. If the CLI launch is slow, the button stays enabled and a second tap will double-spawn.

**Fix:** Disable buttons and show `ProgressView` while `isRunning`.

---

### 🟡 MEDIUM — Unnecessary canvas redraws in AppChannelMeterView

**File:** `Sources/open-lola-app/AppChannelMeterView.swift`, lines 13–15, 130–138.

`@State var peakHolds: [Double]` and `@State var peakHoldTimers: [Double]` are updated every decay tick. Any element change causes the full 64-channel `Canvas` to re-render. No `Equatable` conformance to short-circuit unchanged redraws.

**Fix:** Wrap in a single `@State var peakState: PeakHoldState` with `Equatable` conformance; redraw only when values actually change.

---

### 🟡 MEDIUM — Missing loading state for inventory refresh

**File:** `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`.

Inventory refresh is synchronous in the button action. If `AppLocalOperatorInventory.capture()` is slow (scanning audio devices), the UI freezes with no indication.

**Fix:** Dispatch capture to a background task; show `ProgressView` in the button.

---

### 🟡 MEDIUM — No error path shown for inventory errors

**File:** `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`, lines 22–27.

If `inventoryErrors` is non-empty after capture, the errors are silently absorbed. User gets an incomplete inventory with no indication why.

**Fix:** Show inventory errors as an inline warning banner.

---

### 🔵 LOW — No cleanup of AVFoundation capture queue reference

**File:** `Sources/open-lola-app/AppReceiverPreviewServices.swift`, lines 77–78.

`DispatchQueue` passed to `setSampleBufferDelegate` is created inline and never stored. Delegate is released before the queue stops, risking use-after-free on teardown.

**Fix:** Store the queue as a property on the collector.

---

### 🔵 LOW — Preview structs broken by @State initialization

Several `#Preview` blocks create views that need `@State` or `@Binding` but use stub constants, making preview crashes invisible until Xcode renders them.

---

### 🔵 LOW — "SwiftUI is operator/control surface only" footer suggests incompleteness

**File:** `Sources/open-lola-app/AppConsoleChromeView.swift`, line 164.

Intentional but signals the UI is a prototype. Worth removing or replacing with proper messaging before release.

---

## Pass 3 — High-Risk Runtime Audit

### 3.1 Realtime Audio

#### 🔴 CRITICAL — Dictionary allocations in unused jitter buffer code

**File:** `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift`, lines 295–300.

`RealtimeAudioFixedTargetJitterBuffer.renderNextBlock()` calls `.keys.filter { ... }` and `.removeValue(forKey:)` on a `Dictionary` — both operations heap-allocate. This struct is currently **unused**, but it exists in source and could be activated. If it ever becomes a hot code path, it will violate every RT audio rule simultaneously.

**Fix:** Replace the Dictionary with a fixed-size ring keyed by sequence offset; remove or clearly isolate the struct until it is production-ready.

---

#### 🟠 HIGH — nextFrame counter not atomic in AudioLoopbackIOProcState

**File:** `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`, lines 711–713; `Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift`, lines 444–465.

`nextFrame += UInt64(framesPerBuffer)` is a non-atomic read-modify-write on a field shared between the audio callback thread and the teardown path. Swift does not guarantee this is atomic on any architecture.

**Fix:** Use `open_lola_atomic_u64_fetch_add` from `COpenLolaAtomics` for the counter; add a teardown barrier (e.g., `AudioDeviceStop` + callback completion semaphore) before deallocating `AudioLoopbackIOProcState`.

---

#### 🟠 HIGH — Data() copy on every network TX from ring buffer

**Files:** `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift`, line 156; `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`, line 204.

`let payload = Data(payloadStorage[payloadStart..<payloadEnd])` copies the entire audio frame from the ring into a new heap allocation on the network TX thread. At 48 kHz stereo with 64 channels, this is a ~100 KB/s allocation rate. Heap pressure from this path can cause latency spikes in the audio callback via the global allocator lock.

**Fix:** Use a `UnsafeBufferPointer` slice passed directly to `sendto()`; avoid the intermediate `Data` copy.

---

#### 🟠 HIGH — Buffer format masking with max(1, ...) hides bad devices

**File:** `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`, line 560.

```swift
let sourceChannels = max(1, Int(buffers[0].mNumberChannels))
```

If a device reports 0 channels (malformed device descriptor), this silently proceeds with `sourceChannels = 1` and writes garbage into the first channel slot of the output buffer. The audio callback has no mechanism to signal this error to the non-RT path.

**Fix:** Validate against expected channel count from the session configuration; if mismatch, set a lock-free error flag and produce silence.

---

#### 🟡 MEDIUM — Format mismatch drops silently

**File:** `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift`, lines 189–206.

`validInterleavedSource()` returns `false` on channel count mismatch, causing the capture to silently no-op. No counter, no error path. Users experiencing format mismatch (wrong device sample rate, etc.) will hear silence with no diagnostic.

**Fix:** Increment a lock-free atomic `formatMismatchCount` counter; expose in the session report.

---

#### 🟡 MEDIUM — SPSCAtomicRing ABA is safe in practice but unproven

**File:** `Sources/OpenLolaCore/Support/SPSCAtomicRing.swift`.

The ring uses `write - read < capacity` for full detection with wrapping 64-bit indices. This is correct for SPSC use as long as the ring is never empty and full simultaneously from two threads — which is guaranteed by the SPSC contract. However, this contract is not enforced: nothing prevents two threads calling `push()` concurrently.

**Fix:** Add a compile-time or assertion-level guard that exactly one producer and one consumer exist.

---

### 3.2 UDP Transport

#### 🔴 CRITICAL — Socket file descriptor leaked on setsockopt failure

**File:** `Sources/OpenLolaCore/Network/UDP/UdpPcmSocketOperations.swift`, `makeUdpSocket()`.

`setsockopt()` return value is never checked. If it fails, the socket is returned to the caller with no receive timeout configured. The caller has no way to know — and subsequent `recvfrom()` calls will block indefinitely on teardown. This also means a partial-setup socket can be leaked if the caller throws before closing it.

**Fix:**
```swift
if setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size)) != 0 {
    Darwin.close(descriptor)
    throw UdpPcmRouteProbeError.setSocketOptionFailed(errno)
}
```

---

#### 🔴 CRITICAL — TX and RX race on shared UdpMediaTransport

**File:** `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift`, lines 243–412.

Class is marked `@unchecked Sendable`. `send()` and `receive()` call into POSIX syscalls on `descriptor` without holding `stateLock`. Two threads can call `send()` simultaneously, interleaving `sendto()` calls on the same socket — resulting in corrupted or reordered packets. `close()` can race with an in-flight `send()` — use-after-free on the file descriptor.

**Fix:** Hold `stateLock` for the entire duration of each socket syscall. For performance-critical paths, consider a dedicated TX thread with a queue rather than lock contention.

---

#### 🔴 CRITICAL — errno captured after potential Swift interleaving

**File:** `Sources/OpenLolaCore/Network/UDP/UdpPcmSocketOperations.swift`, `sendConnectedDatagram()`.

`errno` is read after `send()` returns, but not as the immediate next statement. Any Swift runtime operation (ARC, closure evaluation) between the syscall return and the errno read can clobber errno in a multi-threaded process.

**Fix:** `let savedErrno = errno` as the very first statement after the syscall, before any Swift expression.

---

#### 🟠 HIGH — Sequence number wrap-around handled incorrectly

**File:** `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift`, `recordReceived()`.

```swift
if packet.header.sequenceNumber > expected {
    metricsState.packetsLost += Int(packet.header.sequenceNumber - expected)
}
nextSequenceByStream[key] = packet.header.sequenceNumber &+ 1
```

The comparison is unsigned, so wrap-around from `UInt64.max` → `0` evaluates `0 > max` as false. Packets after the rollover are not counted as lost. After ~100 hours of a 10 Mbps session (~4 billion packets), loss metrics silently become incorrect.

**Fix:** Use wrapping subtraction: `let delta = packet.header.sequenceNumber &- expected; if delta > 0 { metricsState.packetsLost += Int(delta) }`.

---

#### 🟠 HIGH — Clock skew produces silent zero-latency readings

**File:** `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift`, jitter calculation.

```swift
let transit = receivedAt >= packet.header.timestampNanoseconds
    ? Double(receivedAt - packet.header.timestampNanoseconds) / 1_000
    : 0
```

NTP adjustment or VM time jump causes `receivedAt < timestampNanoseconds`. The result is `transit = 0`, making jitter metrics report zero latency — a false reading that masks real network conditions.

**Fix:** Detect clock skew, skip jitter update for that packet, and increment a `clockSkewEventCount` counter.

---

#### 🟠 HIGH — Sender socket not bound before connect on wildcard address

**File:** `Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift`, lines 5–26.

If `bindHost == "0.0.0.0"`, the socket is created and connected without a prior `bind()`. POSIX does not guarantee the ephemeral port assignment or source address in this case; some configurations will assign an unexpected source.

**Fix:** Always call `bind(INADDR_ANY, port: 0)` before `connect()`.

---

#### 🟠 HIGH — Fragment planner does not validate final packet size against MTU

**File:** `Sources/OpenLolaCore/Network/UDP/UdpPcmV2FragmentPlanner.swift`, lines 174–209.

`channelsPerFragment` is computed as `payloadBudget / bytesPerChannel` (integer division), but the final check validates only channel count, not actual byte size. With certain channel/sample-rate combinations, the payload can exceed `maxTransmissionUnitBytes - header`.

**Fix:** After computing `payloadByteCount`, assert `UdpPcmV2PacketHeader.byteCount + payloadByteCount <= request.maxTransmissionUnitBytes`.

---

#### 🟠 HIGH — Out-of-bounds read in UdpMedia low-level byte helpers

**File:** `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift`, `readUdpMediaUInt16LE()`.

```swift
private func readUdpMediaUInt16LE(_ bytes: [UInt8], offset: Int) -> UInt16 {
    UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
}
```

No bounds check on `offset + 1 < bytes.count`. A packet exactly at the truncation boundary (e.g., truncated between header fields) causes an index-out-of-bounds crash — not a Swift error throw. This is a DoS vector if a peer sends a malformed packet.

**Fix:** Move bounds check into a guarded helper that throws `UdpPcmPacketError.truncatedPacket(byteCount:)`.

---

#### 🟠 HIGH — NAT traversal reports success even if loopback test fails

**File:** `Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift`, lines 182–189.

If `directTraversalResult.succeeded == true` but the subsequent loopback packet test fails, the code continues and reports the path as working. No fallback to relay is attempted.

**Fix:** Gate the success verdict on the loopback test outcome, not on `directTraversalResult.succeeded` alone.

---

#### 🟠 HIGH — P2P handshake has no global timeout

**File:** `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionSocketRunner.swift`, lines 96–110.

The multi-step handshake (begin → proposal → accept → capability) has no wallclock timeout. If the remote peer crashes mid-handshake, `receiveMessage()` blocks indefinitely on a socket with no read timeout set.

**Fix:** Wrap the handshake in a `Task` with `.timeout(seconds: 10)` or set `SO_RCVTIMEO` on the control socket before the first read.

---

#### 🟠 HIGH — Session teardown races media threads

**File:** `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift`.

`shutdown()` closes transport sockets but does not cancel or join the media receiver tasks first. A task blocked in `recvfrom()` on a now-closed descriptor will get `EBADF` or `EIO` — propagating as an unhandled error, potentially crashing the task.

**Fix:** Cancel all media tasks and await their completion before calling `transport.close()`.

---

#### 🟠 HIGH — Audio/video receive paths are not coordinated

**File:** `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift`.

Audio and video UDP sockets are polled on separate tasks with no shared timing reference. Under packet loss, one stream can fall behind the other with no playout-level compensation. The GOAL.md explicitly calls out AV sync as a requirement.

**Fix:** Add a shared playout timestamp anchor; video frames outside the audio playout window should be dropped or held rather than rendered immediately.

---

#### 🔵 LOW — receiveMessages(count:) count parameter not enforced

**File:** `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionSocketRunner.swift`.

`receiveMessages(count: 2, ...)` passes a count that the implementation may not enforce — it can return fewer messages. Callers that assume exactly N messages may silently proceed with partial state.

---

### 3.3 Video

#### 🔴 CRITICAL — Unbounded reassembly buffer; DoS via fragment flooding

**File:** `Sources/OpenLolaCore/Video/VideoTransportReassembly.swift`, lines 161–168.

```swift
while activeFrames.count >= maxActiveFrames {
    dropOldestActiveFrame()
}
```

Eviction is triggered only when the count reaches the limit. An attacker (or buggy peer) sending fragments with incrementing sequence numbers but no final fragment causes the buffer to grow to `maxActiveFrames` incomplete frames and hold them there. New frames displace old ones by key, but incomplete frames with many fragments each consume unbounded memory.

**Fix:** Add per-frame TTL: drop any frame whose first fragment arrived more than N ms ago, regardless of whether it is complete.

---

#### 🔴 CRITICAL — Truncated packet crash in VideoTransportFragment.decode

**File:** `Sources/OpenLolaCore/Video/VideoTransportPacket.swift`, lines 234–239.

```swift
guard bytes.count >= Self.fixedHeaderByteCount else { throw ... }
guard Array(bytes[0..<4]) == Self.magic else { throw ... }
let version = bytes[4]   // ← crash if bytes.count == 4
```

A 4-byte packet passes the magic check (4 bytes) but crashes on `bytes[4]`. The minimum validated size covers the magic number only.

**Fix:** Set `fixedHeaderByteCount` to include all header fields and validate it as a single guard at the top of `decode()`.

---

#### 🔴 CRITICAL — CMSampleBuffer reference held past error return in captureOutput

**File:** `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift`, lines 384–437.

`CMSampleBufferGetImageBuffer()` is called and the result used, but if `rawFrameBytes()` throws (or if the pixel format is unsupported), the `CMSampleBuffer` is not explicitly released — it stays retained until ARC collects it. Under sustained capture at 60 fps with frequent errors (wrong pixel format at startup), retained buffers accumulate before ARC rounds them up.

**Fix:** Use `autoreleasepool { }` around the capture callback body to bound the retention window.

---

#### 🔴 CRITICAL — AVFoundation pixel buffer lock held on empty return

**File:** `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift`, `rawFrameBytes()`.

When `CVPixelBufferGetBaseAddress()` returns nil, the function returns empty `Data()` without throwing. The `defer { CVPixelBufferUnlockBaseAddress() }` correctly unlocks, but the caller receives empty data with no indication of failure — silently dropping a frame and transmitting a zero-length payload to the network path.

**Fix:** Throw a typed error; let the caller decide whether to drop or retry.

---

#### 🟠 HIGH — VideoTransportRunner sleeps on indeterminate thread

**File:** `Sources/OpenLolaCore/Video/VideoTransportRunner.swift`, lines 112–114.

```swift
sleepUntilUptimeNanoseconds(
    DispatchTime.now().uptimeNanoseconds + configuration.frameIntervalNanoseconds
)
```

If this runner is ever dispatched on a thread with elevated QoS (e.g. `.userInteractive`), the sleep will not yield to audio-priority threads on lower-QoS queues — violating the "video never blocks audio" principle.

**Fix:** Verify explicitly that the video runner thread has QoS ≤ `.userInitiated`; add a runtime assertion.

---

#### 🟠 HIGH — AVFoundation capture queue not retained

**File:** `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift`, lines 290–293.

`DispatchQueue(label: "open-lola.video-capture.avfoundation", qos: .userInitiated)` is created inline and passed to `setSampleBufferDelegate`. If the delegate's owning object is released while the queue has inflight frames, the queue's block references a freed delegate.

**Fix:** Store the queue as a property on `AVFoundationSampleBufferCollector`.

---

#### 🟡 MEDIUM — dropOldestActiveFrame is O(n log n) per call

**File:** `Sources/OpenLolaCore/Video/VideoTransportReassembly.swift**, lines 275–287.

```swift
guard let key = activeFrames.keys.sorted { ... }.first else { return }
```

Called every time a new frame arrives and the buffer is full — O(n log n) per frame in the worst case. At 60 fps with a large `maxActiveFrames`, this is measurable CPU cost.

**Fix:** Maintain a sorted structure (e.g., `Heap` or insertion-ordered `Dictionary` variant) to make oldest-frame lookup O(1).

---

#### 🟡 MEDIUM — Large raw frame artifact accumulates without bound

**File:** `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift**, lines 425–435.

```swift
if retainRawFrameArtifact {
    rawFrameData.append(rawBytes)
    rawFrameIndex.append(rawIndexEntry)
}
```

`rawFrameData` grows without limit for the lifetime of the capture session. A 4K frame at 60 fps is ~500 MB/s. Even with a 1-second window, this will exhaust available RAM.

**Fix:** Implement a ring buffer capped at N frames; or write directly to disk with an append-only file handle.

---

#### 🟡 MEDIUM — RawBGRAAppKitPreviewWindow.submit() is fire-and-forget

**File:** `Sources/OpenLolaCore/Video/RawBGRAAppKitPreviewWindow.swift**, lines 61–72.

`Task { @MainActor in self.state.submit(...) }` is fire-and-forget. If the task queue backs up (main thread busy), frames accumulate without bound. No back-pressure or frame drop mechanism.

**Fix:** Use `Task.detached(priority: .userInitiated)` with a frame drop check: if the previous frame task is still pending, drop the incoming frame.

---

### 3.4 Control & Connectors (LoLa)

#### 🟠 HIGH — ATEM read-only claim is not enforced at runtime

**File:** `Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift`.

`armedCommandsAllowed: Bool` is validated only in the report, not at the TCP send site. Nothing in `LoLaTcpControlExchangeRuntime` checks the flag before calling `sendLoLaTcpControlAttempt()`. An operator who enables commands unintentionally (e.g. by setting the wrong config key) will send live switcher commands.

**Fix:** Add a pre-send guard: `guard !armedCommandsAllowed else { throw AtemError.commandsSuppressed }` at the top of every command-send method.

---

#### 🟠 HIGH — Lighting gate blocking not verified

**File:** `Sources/OpenLolaCore/Control/LightingFixtureGate.swift**, lines 79–97.

Gate state transitions are synchronous with no timeout. If DMX/OSC I/O is involved, the gate method can block for an unbounded duration. The GOAL.md requires control to be non-blocking from the audio thread's perspective — this is stated but not enforced by the implementation.

**Fix:** Execute gate transitions on a dedicated low-priority queue; return immediately from any audio-thread-visible API.

---

#### 🟠 HIGH — OSC receive has no enforced timeout

**File:** `Sources/OpenLolaCore/Control/OscCueRunners.swift**, lines 26–72.

Socket timeout is set during creation, but `receiveUdpOscMessage()` does not verify the timeout is still in effect before blocking. On macOS, `SO_RCVTIMEO` can be reset by certain socket operations.

**Fix:** Use `select()` with an explicit `timeval` immediately before `recvfrom()`.

---

#### 🟠 HIGH — OscCueProbe lacks bounds check on OSC string reads

**File:** `Sources/OpenLolaCore/Control/OscCueProbe.swift`.

`readOscString()` assumes null-terminated data at a cursor offset. If the packet is truncated (no null terminator within bounds), the function reads past the end of the `Data` buffer — undefined behaviour in the `UInt8` subscript path.

**Fix:** Add explicit `guard cursor < data.count` inside the string read loop.

---

#### 🟠 HIGH — LoLa fragment count overflow before guard

**File:** `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaCodec.swift**, lines 131–134.

```swift
let fragmentCount = max(1, Int(ceil(Double(body.count) / Double(maxFragmentBodyByteCount))))
```

If `body.count` is very large and `maxFragmentBodyByteCount` is 1, `fragmentCount` can exceed `Int.max` before the `guard fragmentCount <= maxVideoFragmentCount` check. `Int(ceil(...))` with an overflowed `Double` produces undefined results.

**Fix:** Check `body.count > maxVideoFragmentCount * maxFragmentBodyByteCount` before the `ceil()` call.

---

#### 🟠 HIGH — TCP control socket doesn't handle peer half-close

**File:** `Sources/OpenLolaCore/Connectors/LoLa/LoLaTcpControlExchangeRuntime.swift**.

If the peer performs a `shutdown(SHUT_WR)` (sends FIN) while the local side is waiting for an ACK message, `receiveLoLaTcpControlMessage()` reads 0 bytes (EOF). This is treated as an opaque error. The TCP connection is left in a half-open state consuming a file descriptor.

**Fix:** Explicitly check for 0-byte read → treat as `ECONNRESET`; call `shutdown(socket, SHUT_RDWR)` + `close()`.

---

#### 🟠 HIGH — UDP media socket cache keyed only by port, not (port, host)

**File:** `Sources/OpenLolaCore/Connectors/LoLa/LoLaSocketUdpMediaTransmitter.swift**, lines 39–46.

Socket cache is `[UInt16: Int32]` — keyed by port only. If audio and video use the same port on different interfaces, the second call returns the first socket, sending traffic to the wrong interface silently.

**Fix:** Cache key: `struct SocketCacheKey: Hashable { var port: UInt16; var host: String }`.

---

#### 🟠 HIGH — LoLa wire frame endianness is ambiguous

**File:** `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityWireFrame.swift**.

`readLoLaUInt16BE()` is used for some fields; raw byte comparisons are used for others. The magic constant definitions don't document whether they are in host or network byte order. On Apple Silicon (little-endian), a big-endian constant compared without byte-swapping will silently fail.

**Fix:** Audit every magic constant and field read; annotate each with explicit `// network byte order` or `// host byte order`; add a test that verifies parsing on a little-endian host.

---

---

## Pass 4 — Test Suite

### 🔴 CRITICAL — UdpPcmV2 packet codec has 1 test for 548 lines of source

**File:** `Tests/.../UdpPcmV2PacketTests.swift`.

The V2 packet is the primary multichannel audio transport encoding. Missing: truncated packet at every header field boundary, invalid magic, zero-length payload, fragment index > fragment count, channel count = 0, out-of-order reassembly, duplicate fragment, stream ID mismatch.

**Fix:** Add a property-based test that encodes then decodes across the full parameter space; add negative tests for each error case.

---

### 🔴 CRITICAL — Video reassembler has no duplicate fragment test

**File:** `Tests/.../VideoTransportReportTests.swift`.

`VideoFrameReassembler.receive()` is tested for in-order, out-of-order, and incomplete frames. Duplicate fragments (e.g. retransmit on a lossy link) are not tested. If the reassembler doesn't handle duplicates idempotently, the frame count or memory usage is wrong.

**Fix:** Add test: send every fragment twice; verify exactly one frame is reassembled.

---

### 🔴 CRITICAL — Realtime audio handoff has no burst-drop or buffer-exhaustion test

**File:** `Tests/.../RealtimeAudioEngineTests.swift`.

`realtimeAudioPacketHandoffDropsLatePacketsWithoutGrowingPlayout()` verifies one late packet. No test sends 10+ consecutive late packets, fills the ring to capacity and then late-sends, or alternates on-time and late packets. Ring buffer boundary bugs are invisible.

**Fix:** Add parameterized stress tests; verify `droppedPacketCount` increments correctly under each pattern.

---

### 🔴 CRITICAL — LoLa codec boundary: off-by-one at maxVideoFragmentCount

**File:** `Tests/.../LoLaCompatibilityMediaCodecTests.swift`.

Boundary at `maxVideoFragmentCount` is tested (reject), but `maxVideoFragmentCount - 1` (accept) is not. Classic off-by-one territory.

**Fix:** Add boundary tests for `n-1`, `n`, `n+1` for all limit values in the codec.

---

### 🟠 HIGH — 51 async tests with hardcoded ms/s sleep values

**Files:** `LoLaControlHandshakeValidationTests.swift`, `ExternalConnectorNmpEndpointRunTests.swift`, `PeerSessionRunnerTests.swift`, others.

Fixed sleeps of 500ms–1s will cause intermittent failures on heavily loaded CI runners. No retry logic or condition-variable synchronization.

**Fix:** Replace `Task.sleep(nanoseconds: 500_000_000)` with a semaphore-based handoff or a polling loop with a deadline.

---

### 🟠 HIGH — External subprocess tests are fragile and slow

**Files:** `ExternalConnectorSessionTests.swift` (720 lines), `ExternalConnectorNmpEndpointRunTests.swift` (436 lines).

Tests launch real subprocesses depending on PATH, shell availability, and specific binaries. Failures are environment-dependent and hard to reproduce on CI.

**Fix:** Introduce a `MockExternalConnectorProcessRunner` protocol; unit-test logic without process launching. Keep one integration test that is explicitly `@available(*, disabled: "requires hardware")`.

---

### 🟠 HIGH — 211 instances of `try #require` masking real failures

**Files:** `RealtimeAudioEngineTests.swift`, `DirectPeerRealtimeAudioGraphTests.swift`, others.

`try #require(try someFunc())` wraps both the call and a nil-unwrap. When `someFunc()` throws, the failure is reported as an unwrap failure at the `#require` site, not at the actual error origin.

**Fix:** `let result = try someFunc(); let value = try #require(result.optionalField)` — separate error handling from nil-unwrapping.

---

### 🟠 HIGH — SPSCAtomicRing has only a single-threaded test

**File:** `Tests/.../SPSCAtomicRingTests.swift` (17 lines).

A single push-pop-pop sequence. No concurrent producer/consumer test. The lock-free correctness of the ring (which backs the audio packet handoff) is untested under concurrency.

**Fix:** Add a stress test that runs a producer Task and a consumer Task concurrently for 100k iterations; assert no data loss and no corruption.

---

### 🟠 HIGH — PeerSessionRunnerTests requires full session state

**File:** `Tests/.../PeerSessionRunnerTests.swift` (720 lines).

Tests set up complete P2P session state to test individual behaviours. Failures anywhere in the setup chain obscure the actual bug.

**Fix:** Split into unit tests per component (negotiation, control exchange, media endpoint).

---

### 🟡 MEDIUM — Ring buffer tests only use capacity=2

**File:** `Tests/.../RealtimeAudioEngineTests.swift`, `realtimeAudioBlockRingStaysBoundedAndReportsDrops`.

Off-by-one bugs in ring boundary math only surface with specific capacities (powers of 2 where modulo wraps differ).

**Fix:** Parameterize: `@Test(arguments: [1, 2, 4, 8, 16, 256])`.

---

### 🟡 MEDIUM — Error assertions don't validate associated values

**File:** `Tests/.../UdpPcmPacketTests.swift`, lines 302–314.

`expectPacketError(.invalidMagic)` checks only the error type. `.truncatedPacket(byteCount:)` is not validated for the actual byte count — a test that throws with the wrong byteCount still passes.

**Fix:** Use `XCTAssertEqual` or pattern matching on the full error value.

---

### 🟡 MEDIUM — Video transport tests are report-validation-heavy; transport behaviour is sparse

**File:** `Tests/.../VideoTransportReportTests.swift` (410 lines).

20+ tests verify that `report.validate()` rejects invalid fields; only 3 test actual transport mechanics (reassembly). Fragment loss under packet corruption and concurrent fragment arrival are untested.

---

### 🟡 MEDIUM — AV timestamp policy tests don't test policy switches mid-session

**File:** `Tests/.../AVTimestampAlignmentTests.swift`.

Tests individual policies in isolation. A policy switch (e.g. from `directAudioFirst` to `balancedAV`) while frames are queued is not tested — race conditions in policy transitions are invisible.

---

### 🟡 MEDIUM — 278 private test helpers; duplication likely

Across the test suite, 278 private/internal test helper functions are defined. Many are likely near-duplicates of each other (e.g., fixture loaders, report builders). No shared `+TestSupport` conventions are enforced.

**Fix:** Audit helpers; consolidate into typed `*TestSupport.swift` files with clear ownership.

---

### 🟡 MEDIUM — Test artifacts not cleaned up

Several tests write to `/tmp/lola-*.json` and do not clean up. In long CI runs, stale artifacts from a previous test run can influence the next run if a test loads from a fixed path.

**Fix:** Use `FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)` for all test output; `defer { try? FileManager.default.removeItem(at: path) }`.

---

### 🟡 MEDIUM — Fixtures not validated against current encoder output

Packet fixture files (e.g. `valid-stereo-int16`) are compared against live decodes, but no test verifies the fixture itself is still what the current encoder produces. A codec change that also updates the fixture generator can silently break the fixture.

**Fix:** Add a "fixture regeneration" test that re-encodes and compares byte-for-byte.

---

### 🟡 MEDIUM — Large monolithic test files (720+ lines)

`PeerSessionRunnerTests.swift`, `ExternalConnectorSessionTests.swift`, `NativeAppShellTests.swift` each exceed 700 lines. Navigation is painful; failure attribution is slow.

**Fix:** Split by component responsibility. Target 200–300 lines per file.

---

### 🔵 LOW — M00/M02/M04 contract tests verify compilation, not behaviour

Source contract tests for milestone checks pass as long as the types compile with the expected API surface. They do not assert that the runtime behaviour matches the contract description.

---

### 🔵 LOW — No test for concurrent reassembler access

`VideoFrameReassembler` is a value type (`struct`). If two threads ever hold a copy and merge results, the semantics are wrong. No test proves single-owner discipline is maintained.

---

## Prioritized Remediation List

Ordered by: severity × blast radius × ease of fix.

### Tier 1 — Fix before any real hardware session

| # | Issue | File | Severity |
|---|---|---|---|
| 1 | TX/RX race on UdpMediaTransport | Network/UDP/UdpMediaTransport.swift | 🔴 |
| 2 | FD never closed on setsockopt failure | Network/UDP/UdpPcmSocketOperations.swift | 🔴 |
| 3 | errno captured after interleaving | Network/UDP/UdpPcmSocketOperations.swift | 🔴 |
| 4 | nextFrame not atomic in audio callback | Audio/Realtime/DirectPeerRealtimeAudioGraph.swift | 🟠 |
| 5 | Teardown races media threads | Network/P2P/PeerSessionRunner.swift | 🟠 |
| 6 | Subprocess never terminated on view dismiss | open-lola-app/AppExecutionController.swift | 🔴 |
| 7 | Timer leak in AppAudioLevelMeter | open-lola-app/AppReceiverPreviewServices.swift | 🔴 |
| 8 | Published props updated off main thread | open-lola-app/AppReceiverPreviewServices.swift | 🔴 |

### Tier 2 — Fix before sustained network testing

| # | Issue | File | Severity |
|---|---|---|---|
| 9 | Unbounded video reassembly buffer | Video/VideoTransportReassembly.swift | 🔴 |
| 10 | Truncated video packet crash | Video/VideoTransportPacket.swift | 🔴 |
| 11 | Out-of-bounds UInt16 read in UDP path | Network/UDP/UdpMediaTransport.swift | 🟠 |
| 12 | Fragment planner doesn't validate MTU | Network/UDP/UdpPcmV2FragmentPlanner.swift | 🟠 |
| 13 | Sequence wrap-around miscounts loss | Network/UDP/UdpMediaTransport.swift | 🟠 |
| 14 | LoLa fragment count overflow | Connectors/LoLa/LoLaCompatibilityMediaCodec.swift | 🟠 |
| 15 | LoLa UDP socket cache ignores host | Connectors/LoLa/LoLaSocketUdpMediaTransmitter.swift | 🟠 |
| 16 | TCP half-close not handled | Connectors/LoLa/LoLaTcpControlExchangeRuntime.swift | 🟠 |
| 17 | P2P handshake has no timeout | Network/P2P/DirectPeerSessionSocketRunner.swift | 🟠 |
| 18 | NAT reports success on broken path | Network/NAT/NatFriendlyRouteRunner.swift | 🟠 |
| 19 | CMSampleBuffer held past error return | Video/VideoCaptureAVFoundation.swift | 🔴 |
| 20 | ATEM command suppression not enforced | Control/AtemReadOnlyControl.swift | 🟠 |

### Tier 3 — Fix before release

| # | Issue | Area | Severity |
|---|---|---|---|
| 21 | UdpPcmV2 test coverage near-zero | Tests | 🔴 |
| 22 | Video reassembler duplicate fragment test missing | Tests | 🔴 |
| 23 | SPSCRing concurrency test missing | Tests | 🟠 |
| 24 | Hardcoded sleep in async tests | Tests | 🟠 |
| 25 | Data() copy on every RT audio TX | Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift | 🟠 |
| 26 | Dictionary in unused jitter buffer | Audio/Realtime/RealtimeAudioBuffers.swift | 🔴 (future) |
| 27 | NSLock in Core Audio meter callback | open-lola-app/AppReceiverPreviewServices.swift | 🔵 |
| 28 | Raw frame buffer unbounded | Video/VideoCaptureAVFoundation.swift | 🟡 |
| 29 | NativeAppShellSurface god file split | Platform/NativeAppShellSurface.swift | 🟠 |
| 30 | Validation helper explosion (217+ fns) | OpenLolaCore/Release/*, Evidence/* | 🟠 |

---

*End of AUDIT-FRESH.md*
