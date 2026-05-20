# Minimum-Code Audit

An audit of the `open-lola2` codebase against the principle: **minimum code that solves the
problem**. Every line of code is a liability. Code that does not need to exist should not exist.

**Scope:** `Sources/` (Swift), `Tests/OpenLolaCoreTests/`.
**Date:** 2026-05-19
**Rules:** No production code changed. No deletions. Only this file created.

Related prior document: `docs/overengineering-index.md` (OE-01 through OE-20).
This document covers new issues not addressed there, with emphasis on:
1. Code that creates correctness risk
2. Code that hides state or errors
3. Code that makes tests difficult
4. Code that duplicates behavior
5. Code that is merely ugly but safe

---

## Table of Contents

1. [Findings](#findings)
2. [Prioritized Remediation Table](#prioritized-remediation-table)

---

## Findings

---

### MC-01 — Ten identical `*RunMode` enums

| Field | Value |
|---|---|
| **ID** | MC-01 |
| **Files** | `Audio/Realtime/RealtimeAudioEngine.swift`, `Audio/MADI/MadiFullDuplexTypes.swift` (different), `Integration/IntegratedProfileTypes.swift`, `Integration/IntegratedAvReport.swift`, `Platform/NativeAppShell.swift`, `Network/P2P/MacToMacRouteCertification.swift`, `Network/Diagnostics/NetworkAoipCertification.swift`, `Timing/DriftPlcFixedTargetCertification.swift`, `Timing/LatencyTuningReport.swift`, `Benchmarks/Latency/LatencyBenchmarkTypes.swift` (4 cases), `Benchmarks/Performance/PerformanceAuditReport.swift`, `Benchmarks/E2E/E2EBenchmarkReport.swift`, `Control/LightingFixtureGateReport.swift` |
| **Symbol** | `NativeAppShellRunMode`, `RealtimeAudioRunMode`, `IntegratedProfileRunMode`, `IntegratedAvRunMode`, `MacToMacRouteCertificationRunMode`, `NetworkAoipCertificationRunMode`, `DriftPlcFixedTargetCertificationRunMode`, `LatencyTuningRunMode`, `PerformanceAuditRunMode`, `E2EBenchmarkRunMode`, `LightingFixtureGateRunMode` |
| **Current behavior** | Each report module declares its own `*RunMode: String, Codable, Equatable, Sendable` enum with identical body `{ case synthetic; case measured }`. 10 of the 13 variants are byte-for-byte equivalent. The remaining three (`MadiFullDuplexRunMode`, `LatencyBenchmarkRunMode`, `DriftPlcFixedTargetCertificationRunMode`) have additional cases. |
| **Required behavior** | A report struct needs a field that records whether the session was synthesized or measured from hardware. |
| **Complexity problem** | 10 copies of a 4-line enum declaration. Any future case (e.g., `case network`) must be added in 10 places. Consumers cannot be written generically against a shared type; each report uses its own. Serialized JSON raw values (`"synthetic"`, `"measured"`) are identical across all 10 — the type distinction produces no observable difference. |
| **Minimal alternative** | One shared `public enum ReportRunMode: String, Codable, Equatable, Sendable { case synthetic; case measured }` in `OpenLolaContracts` or a shared `Core` file. Each report struct uses `ReportRunMode` directly. The three enums with additional cases remain module-local (they are not duplicates). |
| **Risk of simplification** | Medium. Every conforming report struct must change its `runMode` field type. Tests that deserialize JSON fixtures with `"synthetic"/"measured"` are unaffected if raw values are preserved. |
| **Tests needed before simplification** | Run `swift test --no-parallel` to confirm JSON round-trips for all report types using the shared enum. |
| **Verification** | `grep -rn "RunMode: String, Codable, Equatable, Sendable" Sources/` — should return only the three non-identical ones after consolidation. |
| **Confidence** | high |
| **Action** | DEDUPLICATE |

---

### MC-02 — 30+ `*SyntheticSmoke` enum namespaces

| Field | Value |
|---|---|
| **ID** | MC-02 |
| **Files** | Every module: `RealtimeAudioEngineSyntheticSmoke.swift`, `LatencyBenchmarkSyntheticSmoke.swift`, `ReleaseHardeningSyntheticSmoke.swift`, `E2EBenchmarkSyntheticSmoke.swift`, `PerformanceAuditSyntheticSmoke.swift`, plus 25+ inline enums in individual `.swift` files |
| **Symbol** | `RealtimeAudioEngineSyntheticSmoke`, `LatencyBenchmarkSyntheticSmoke`, `MadiReceiveSyntheticSmoke`, `MadiTransmitSyntheticSmoke`, `MadiFullDuplexSyntheticSmoke`, `DriftPlcFixedTargetCertificationSyntheticSmoke`, `NetworkDiagnosticsSyntheticSmoke`, `MacToMacRouteCertificationSyntheticSmoke`, `UdpPcmLoopbackSyntheticSmoke`, `NatFriendlyRouteSyntheticSmoke`, `ExternalConnectorSyntheticSmoke`, `VideoTransportSyntheticSmoke`, `VideoCaptureSyntheticSmoke`, `IntegratedHeadlessAvSyntheticSmoke`, `IntegratedProfileSyntheticSmoke`, `NativeAppShellSyntheticSmoke`, `RecordingSessionSyntheticSmoke`, `FieldReadyRuntimeSyntheticSmoke`, `FasterThanLoLaClosureSyntheticSmoke`, `PackagingFieldTestSyntheticSmoke`, `ReleaseHardeningSyntheticSmoke`, `GoalRuntimePreflightSyntheticSmoke`, `LatencyBenchmarkSyntheticSmoke`, `LatencyProfileBenchmarkSyntheticSmoke`, `LatencyTuningSyntheticSmoke`, `DriftPlcSyntheticSmoke`, `SessionProfileBenchmarkSyntheticSmoke`, `RxBufferBenchmarkSyntheticSmoke`, `E2EBenchmarkSyntheticSmoke`, `PerformanceAuditSyntheticSmoke` |
| **Current behavior** | Each report module has a `public enum XxxSyntheticSmoke` (caseless) with `public static func run() throws -> XxxReport`. This is the only entry point for constructing a test-valid synthetic report instance. |
| **Required behavior** | A way to construct a known-good synthetic instance of each report type for use in tests and as a CLI-accessible probe. |
| **Complexity problem** | A caseless `enum` namespace is Swift boilerplate for "a group of static functions." The namespace adds no value beyond scoping. Every module invents the same pattern independently. The name suffix `SyntheticSmoke` is the only signal that a function returns synthetic data — but this is already conveyed by the returned report's `runMode: .synthetic` field. `public enum XxxSyntheticSmoke { public static func run() }` is identical to `public func xxxSyntheticSmoke() -> XxxReport` plus a naming convention. |
| **Minimal alternative** | Replace each `enum XxxSyntheticSmoke { static func run() }` with `func makeSyntheticXxxReport()` (or `XxxReport.synthetic()` static factory). The enum wrappers add zero encapsulation or access-control value. |
| **Risk of simplification** | Low for call sites (tests and CLI dispatch). Call sites would change from `XxxSyntheticSmoke.run()` to the new function name. No behavioral change. |
| **Tests needed before simplification** | None beyond a build check. All tests call `XxxSyntheticSmoke.run()` and would be updated mechanically. |
| **Verification** | `grep -rn "SyntheticSmoke" Sources/ Tests/` to enumerate all call sites before and after. |
| **Confidence** | high |
| **Action** | SIMPLIFY |

---

### MC-03 — `validatePositive` / `validateNonNegative` free functions in `RealtimeAudioEngine.swift`

| Field | Value |
|---|---|
| **ID** | MC-03 |
| **File** | `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift` (lines 123-133) and `Sources/OpenLolaCore/Network/UDP/UdpPcmV2FragmentPlanner.swift` (line 256) |
| **Symbol** | `validatePositive(_:_:)`, `validateNonNegative(_:_:)` (in `RealtimeAudioEngine.swift`); `UdpPcmV2FragmentPlanner.requirePositive(_:_:)` (in `UdpPcmV2FragmentPlanner.swift`) |
| **Current behavior** | `RealtimeAudioEngine.swift` defines two module-internal free functions `validatePositive` and `validateNonNegative` that throw `RealtimeAudioBufferConfigurationError`. Used by `DirectPeerRealtimeAudioGraphTypes.swift` and `RealtimeAudioBuffers.swift`. `UdpPcmV2FragmentPlanner` has a private static `requirePositive` doing the same thing. Both are independent re-implementations of the global `ValidationPrimitives` helpers. |
| **Required behavior** | Throw an error if a configuration value is not positive or non-negative. |
| **Complexity problem** | Three separate implementations of a 3-line guard/throw across realtime audio, network, and the ValidationPrimitives utility. Each throws a module-specific error type (`RealtimeAudioBufferConfigurationError`, `UdpPcmV2FragmentPlanningError`), which prevents using a shared function directly. The module-specific error type is the real reason for the duplication — but that design choice means each module must maintain its own validator wrappers. |
| **Minimal alternative** | If module-specific error types must be preserved (they carry field-specific context in the `.nonPositiveField(String)` case), the 3-line implementations are acceptable. The problem is the non-use of `ValidationPrimitives` despite its existence. A shared `requirePositive<E: ValidationNonPositiveFieldError>(_ value: Int, _ field: String, error: (String) -> E) throws` free function would unify all variants. Alternatively, accept the per-module 3-liners and remove `ValidationPrimitives` entirely (see OE-01). |
| **Risk of simplification** | Low. Each function body is trivial. |
| **Tests needed before simplification** | Confirm all callers handle the correct error type. Build check sufficient. |
| **Verification** | `grep -rn "validatePositive\|validateNonNegative\|requirePositive" Sources/` to map all variants. |
| **Confidence** | high |
| **Action** | DEDUPLICATE (blocked on OE-01 resolution) |

---

### MC-04 — `RealtimeAudioCallbackSafetyChecklist` — self-asserted booleans

| Field | Value |
|---|---|
| **ID** | MC-04 |
| **File** | `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift` (lines 160-197) |
| **Symbol** | `RealtimeAudioCallbackSafetyChecklist`, `firstViolation` |
| **Current behavior** | A 7-field `Bool` struct where each field asserts a realtime safety property: `noAllocationInCallback`, `noLoggingInCallback`, `noFileIOInCallback`, `noLocksOrUnboundedWaitsInCallback`, `noNetworkSetupInCallback`, `noReportWritingInCallback`, `countersOnlyInCallback`. Validated in `RealtimeAudioEngineReportValidation.swift` via `safety.firstViolation`. In both synthetic smoke and the production report builder, every field is set to `true` by the programmer writing the report. |
| **Required behavior** | Express whether the audio callback implementation meets realtime-safe constraints. |
| **Complexity problem** | This is a self-attestation: the developer writes `noAllocationInCallback: true` in the source code and then later validates that the boolean is `true`. The struct adds no runtime measurement; it is a documentation format embedded in a report. The 7 named fields can each be set to any value by whoever constructs the report. A passing `firstViolation` check proves only that the programmer wrote `true`. The check provides a **false sense of correctness assurance** because a developer could accidentally or deliberately set a field to `true` without the claimed property actually holding. There is no test that exercises `firstViolation` returning a non-nil value from real report data. |
| **Minimal alternative** | Keep the struct as report documentation (it is useful for human review and JSON output). Remove the `validate()`-path check that treats `firstViolation != nil` as an error — since it can always be bypassed by setting fields to `true`. Add a code comment stating this is a self-attestation, not an instrumented check. |
| **Risk of simplification** | Low for removing the validation gate. High if the gate is relied on to reject incorrect reports. |
| **Tests needed before simplification** | Add a test that sets one checklist field to `false` and confirms `firstViolation` returns the expected string. Confirm that `validate()` rejects such a report. This confirms whether the gate is exercised. |
| **Verification** | `grep -rn "firstViolation\|safety.firstViolation" Sources/ Tests/` to confirm only one production call site and no test exercises the failure path. |
| **Confidence** | high |
| **Action** | INVESTIGATE (possible hidden correctness risk: the validation gate exists but is trivially bypassed) |

---

### MC-05 — `CoreAudioFallbackIdentityCache` caches trivially computed strings

| Field | Value |
|---|---|
| **ID** | MC-05 |
| **File** | `Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift` (lines 409-440) |
| **Symbol** | `CoreAudioFallbackIdentityCache`, `coreAudioFallbackIdentityCache` |
| **Current behavior** | A lock-guarded class with two `[AudioObjectID: String]` dictionaries that cache fallback strings: `"Unknown Core Audio device \(deviceID)"` and `"unknown-\(deviceID)"`. The cache is a module-level `private let` singleton. It is accessed when the real Core Audio property lookup fails (the "fallback" path). |
| **Required behavior** | When a Core Audio device ID cannot produce its name or UID via the real API, return a stable placeholder string. |
| **Complexity problem** | The cached values are deterministic functions of their inputs — `"Unknown Core Audio device \(deviceID)"` for every `deviceID`. They are cheap to compute. Caching deterministic, allocation-light string computations adds a lock, two dictionaries, an `NSLock`, and a class allocation for zero performance benefit. The fallback path is by definition a degenerate path (called only when the real API fails) and should not be on the hot path. The class also uses `@unchecked Sendable` which suppresses Swift Concurrency checking for a shared mutable object. |
| **Minimal alternative** | Remove `CoreAudioFallbackIdentityCache`. At each fallback call site, return `"Unknown Core Audio device \(deviceID)"` inline. Two lines replaced by nothing. |
| **Risk of simplification** | None. The returned string values are identical. The cache only speeds up repeat lookups of degenerate IDs, which is not a performance-sensitive path. |
| **Tests needed before simplification** | None beyond a build check and confirming the string format matches any snapshot test that checks fallback device names. |
| **Verification** | Search for `coreAudioFallbackIdentityCache` — it appears only twice (definition + access), confirming no other consumers. |
| **Confidence** | high |
| **Action** | DELETE |

---

### MC-06 — `AudioRoutingAssumptionLedger` — documentation in Swift

| Field | Value |
|---|---|
| **ID** | MC-06 |
| **File** | `Sources/OpenLolaCore/Audio/Routing/AudioRoutingAssumptionLedger.swift` (141 lines) |
| **Symbol** | `AudioRoutingAssumptionLedger`, `AudioRoutingAssumption`, `AudioRoutingAssumptionClassification`, `AudioRoutingAssumptionStatus` |
| **Current behavior** | A static array of 11 `AudioRoutingAssumption` structs encoding multi-channel routing design decisions (e.g., "localhost smokes default to channelCount: 2", "receiver defaults to identity routing"). Tested in `MultichannelTransportTests.swift` with three assertions: entries array is non-empty, unclassifiedEntries is empty, and a fixed set of required IDs is a subset of the ledger IDs. |
| **Required behavior** | Communicate and track multi-channel routing assumptions so they are not silently changed. |
| **Complexity problem** | The ledger is editorial documentation encoded as runtime Swift types. The `classification` and `status` fields never drive runtime branching — they appear only in the struct and in `entries.filter`. The three test assertions confirm: (1) the array is non-empty, (2) no entry has `.unclassified` classification, and (3) 10 specific IDs exist. These tests protect the list's completeness but not the content of any entry — the `assumption`, `action`, and `location` fields are unchecked strings. Maintaining this as Swift requires a compile + build cycle for every editorial update. |
| **Minimal alternative** | Move the ledger to `docs/multichannel-routing-assumptions.md`. Keep a single test that reads a static JSON file and confirms a set of required IDs is present. This gives the same completeness guarantee with zero Swift code. |
| **Risk of simplification** | Low. The struct carries no runtime behavior. The `unclassifiedEntries` computed property is used only in the test. |
| **Tests needed before simplification** | Replace the three Swift assertions with a file-reading test if the ledger moves to a JSON file. |
| **Verification** | `grep -rn "AudioRoutingAssumptionLedger\." Sources/ Tests/` — all callers are in one test file. |
| **Confidence** | medium (the pattern may be intentional as a compile-time completeness gate) |
| **Action** | SIMPLIFY |

---

### MC-07 — `UdpPcmV2PacketHeader` defined in `UdpPcmV2FragmentPlanner.swift`

| Field | Value |
|---|---|
| **ID** | MC-07 |
| **File** | `Sources/OpenLolaCore/Network/UDP/UdpPcmV2FragmentPlanner.swift` (lines 3-67) |
| **Symbol** | `UdpPcmV2PacketHeader` |
| **Current behavior** | The packet header struct `UdpPcmV2PacketHeader` is declared in `UdpPcmV2FragmentPlanner.swift`. It is the primary type used by `UdpPcmV2Packet.swift` — the file responsible for encoding and decoding the full packet. |
| **Required behavior** | `UdpPcmV2PacketHeader` must be accessible to both the fragment planner and the packet codec. |
| **Complexity problem** | The definition is in the wrong file. `UdpPcmV2PacketHeader` is a packet format type. The fragment planner uses the header's field names (`UdpPcmV2PacketHeader.byteCount`, `.magic`, `.currentVersion`, `.headerGuard`) to compute fragment layouts, but the header's semantic home is with the packet, not the planner. Developers reading `UdpPcmV2Packet.swift` will look for the header definition and not find it there. This is a locality issue that obscures where the packet format is defined. |
| **Minimal alternative** | Move `UdpPcmV2PacketHeader` to `UdpPcmV2Packet.swift`. |
| **Risk of simplification** | None beyond a file move. No behavior change. |
| **Tests needed before simplification** | Build check only. |
| **Verification** | `grep -rn "UdpPcmV2PacketHeader" Sources/` to confirm the header is used in both files and nowhere else. |
| **Confidence** | high |
| **Action** | SIMPLIFY |

---

### MC-08 — `FixtureSmokeMatrix` and `FixtureMatrixEntry` — another inventory-as-code

| Field | Value |
|---|---|
| **ID** | MC-08 |
| **File** | `Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrix.swift` (138 lines), `Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift` (120 lines) |
| **Symbol** | `FixtureSmokeMatrix`, `FixtureMatrixEntry`, `CLISmokeMatrixEntry`, `FixtureProvenanceClass`, `PublicReleasePosture` |
| **Current behavior** | A typed inventory of fixture groups and CLI smoke commands. Each `FixtureMatrixEntry` stores: group name, expected file count, file extensions, provenance class, release posture, validator command, smoke command, related source files, related test files, `requiresFalsePassFixture`, and `falsePassFixtures`. Each `CLISmokeMatrixEntry` stores: command string, source file path, expected verdict, `syntheticOnly` flag, related fixture group, and owner string. |
| **Required behavior** | A machine-readable catalog of fixtures and their CLI verification commands, used by the `fixture-smoke-matrix` CLI command. |
| **Complexity problem** | This is the same "source metadata as code" pattern as `CLICommandInventory` and `ReportSchemaInventory` (see OE-15). The entries contain string file paths that drift silently when files are renamed. The `expectedFileCount` field is a manually maintained integer that will be wrong whenever a fixture is added or removed without updating this file. `relatedSourceFiles` and `relatedTestFiles` are strings that reference actual paths — these paths are never validated at build time. `PublicReleasePosture` is an enum with two cases (`reviewPending`, `internalOnly`) that appear in JSON output but drive no conditional logic. |
| **Minimal alternative** | Move to a static JSON or YAML configuration file. The Swift structs add no validation or encapsulation over plain data; they only add a compile dependency. |
| **Risk of simplification** | Low if the CLI command is adapted to read from a file. Medium if tests assert the matrix report's exact content. |
| **Tests needed before simplification** | Check whether any test asserts specific `FixtureMatrixEntry` field values beyond "is the list non-empty". |
| **Verification** | `grep -rn "FixtureSmokeMatrix\." Sources/ Tests/` to map consumers. Check `scripts/verify-release-readiness.sh` for `fixture-smoke-matrix` invocations. |
| **Confidence** | medium |
| **Action** | SIMPLIFY |

---

### MC-09 — `RealtimeAudioBlockRing` vs `RealtimeAudioDueBlockPlayout` — two rings for one handoff path

| Field | Value |
|---|---|
| **ID** | MC-09 |
| **File** | `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift` |
| **Symbol** | `RealtimeAudioBlockRing` (lines 79-125), `RealtimeAudioDueBlockPlayout` (lines 132-201) |
| **Current behavior** | `RealtimeAudioBlockRing` is a simple FIFO ring (push/pop, capacity-bounded). `RealtimeAudioDueBlockPlayout` is a slot-addressed ring (enqueue/renderNextBlock, frame-indexed). Both hold `RealtimeAudioFrameBlock?` arrays with `readIndex`/`writeIndex` and `count`/`dropped` counters. Both have `capacity: Int`, array-backed storage, and overflow guards. |
| **Required behavior** | The handoff path needs: (a) a FIFO input queue for captured blocks, (b) a frame-indexed jitter buffer for network-received blocks. |
| **Complexity problem** | `RealtimeAudioBlockRing` appears to exist as a simpler ring used by an early code path, while `RealtimeAudioDueBlockPlayout` handles the more complex frame-indexed scheduling. Examining usage: `RealtimeAudioBlockRing` is defined but its callers are UNCLEAR (no `RealtimeAudioBlockRing(` found from quick grep below). If it has no active call site, it is dead code. |
| **Minimal alternative** | INVESTIGATE — if `RealtimeAudioBlockRing` has no callers, delete it. If it does, document the distinction clearly. |
| **Risk of simplification** | UNCLEAR without call-site confirmation. |
| **Tests needed before simplification** | `grep -rn "RealtimeAudioBlockRing(" Sources/ Tests/` to find callers. |
| **Verification** | Same grep. |
| **Confidence** | low (need caller confirmation) |
| **Action** | INVESTIGATE |

---

### MC-10 — Synthetic smoke reports embed fabricated numeric metrics

| Field | Value |
|---|---|
| **ID** | MC-10 |
| **File** | Multiple: `RealtimeAudioEngineSyntheticSmoke.swift`, `LatencyBenchmarkSyntheticSmoke.swift`, `PerformanceAuditSyntheticSmoke.swift`, and all other `*SyntheticSmoke` files that construct hardcoded report structs. |
| **Symbol** | All `*SyntheticSmoke.run()` implementations that set `p50Microseconds: 40`, `p95Microseconds: 80`, `cpuP50Percent: 8`, `oneWayEstimateMicroseconds: 2_400`, etc. |
| **Current behavior** | Each synthetic smoke builds a complete report struct with concrete numeric metrics. For example: `LatencyBenchmarkSyntheticSmoke.run()` sets `p50Microseconds: 80`, `p95Microseconds: 160`, `p99Microseconds: 240`, `maxMicroseconds: 320`, `oneWayEstimateMicroseconds: 2_400`, `cpuP50Percent: 8`, `cpuP95Percent: 16`. These are invented numbers with no relation to actual measurements. |
| **Required behavior** | Synthetic smokes must produce a structurally valid report that can be validated by `report.validate()` and used in tests as a mutation base. |
| **Complexity problem** | Embedding specific numeric values creates a trap: tests that call `XxxSyntheticSmoke.run()` and then assert on fields will get the fabricated numbers. A test that says `#expect(report.timing.p50Microseconds == 80)` is testing the smoke's hardcoded constant, not any real behavior. Worse, the `verdict: .partial` on all synthetic smokes means they pass schema validation while containing metrics that look like measurements. Any code that reads these reports from disk (e.g., a CI reporter that ingests `*SyntheticSmoke` JSON artifacts) would process fabricated data. The `runMode: .synthetic` field is the only guard — and its enforcement depends on downstream consumers checking it. |
| **Minimal alternative** | Numeric performance metrics in synthetic reports should be sentinel values (e.g., `0`, or constants like `RealtimeAudioHandoffMetrics.syntheticPlaceholder`) that are clearly not real data, rather than plausible-looking numbers. The reports should still pass `validate()`. |
| **Risk of simplification** | Medium. Tests that currently use exact numeric assertions against synthetic reports would need updating. Any external tool that ingests synthetic smoke JSON with plausible-looking numbers would change behavior. |
| **Tests needed before simplification** | Audit all tests that call `XxxSyntheticSmoke.run()` and check numeric fields. Confirm whether `validate()` enforces any numeric range constraints on the metric fields. |
| **Verification** | `grep -rn "p50Microseconds\|p95Microseconds\|cpuP50" Tests/` to find numeric assertions on synthetic data. |
| **Confidence** | medium |
| **Action** | INVESTIGATE |

---

### MC-11 — `ExternalConnectorReport.swift` private `require*` helpers re-duplicate `ValidationPrimitives`

| Field | Value |
|---|---|
| **ID** | MC-11 |
| **File** | `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorReport.swift` |
| **Symbol** | `requireExternalConnectorSessionNonEmpty`, `requireExternalConnectorSessionNonEmptyList`, `requireExternalConnectorSessionPositive` |
| **Current behavior** | Three private functions at the bottom of `ExternalConnectorReport.swift` that wrap `if value.isEmpty { throw }` and `if value <= 0 { throw }`. Each is named with the `requireExternalConnectorSession*` prefix to produce errors of type `ExternalConnectorSessionValidationError`. Used only within the file. |
| **Required behavior** | Validate non-empty strings and positive integers in the connector report, throwing domain-specific errors. |
| **Complexity problem** | This is the same pattern documented in OE-04 (40+ duplicated private `require*` helpers). This specific occurrence was not fully enumerated in OE-04. These three functions are local to one file and have no callers outside it. The entire body of each is 2-3 lines. |
| **Minimal alternative** | Inline the guards at their call sites (there are fewer than 5 total calls in this file). Or use `ValidationPrimitives` directly once the OE-01 issue is resolved. |
| **Risk of simplification** | None. Private to file. |
| **Tests needed before simplification** | Build check only. |
| **Verification** | `grep -rn "requireExternalConnectorSession" Sources/` — should return only the defining file. |
| **Confidence** | high |
| **Action** | INLINE |

---

### MC-12 — `RxBufferPolicy` has four `static func` factory methods that repeat the same `RxBufferPolicy(...)` + `try policy.validate()` pattern

| Field | Value |
|---|---|
| **ID** | MC-12 |
| **File** | `Sources/OpenLolaCore/Timing/RxBuffering.swift` (lines 87-168) |
| **Symbol** | `RxBufferPolicy.direct`, `RxBufferPolicy.small`, `RxBufferPolicy.adaptive`, `RxBufferPolicy.stableWan` |
| **Current behavior** | Four static factory methods, each constructing an `RxBufferPolicy` with profile-specific defaults, calling `try policy.validate()`, and returning the result. Each method has different defaults and a slightly different validation constraint (the `switch profile` in `validate()` checks profile-specific rules). |
| **Required behavior** | Create validated `RxBufferPolicy` instances for the four supported profiles with correct default parameters. |
| **Complexity problem** | The pattern `let policy = RxBufferPolicy(profile: X, ...); try policy.validate(); return policy` appears 4 times with different parameter combinations. The four factories are well-scoped and their differences are real (different defaults, different validation rules per profile). However, the `notes` field in each factory is a hardcoded string that is set but then overridden by callers who know nothing about the notes content. The `validate()` method contains a `switch profile { case .direct: ... case .small: ... }` that duplicates the intent of the four factories. |
| **Minimal alternative** | The four factories are acceptable. The `notes` field could be removed from the public init and computed from the profile automatically (a 4-case switch in a computed property), eliminating the need to pass `notes:` in every factory call. The `validate()` `switch profile` block is already proportional to the four cases. |
| **Risk of simplification** | Low for removing `notes` from the init. Medium if any caller sets a custom `notes` value. |
| **Tests needed before simplification** | Confirm `notes` is only accessed in JSON serialization, not in any conditional logic. |
| **Verification** | `grep -rn "\.notes" Sources/ Tests/ | grep RxBuffer` |
| **Confidence** | low (the factories are reasonably scoped; this is a minor improvement) |
| **Action** | KEEP (minor only) |

---

### MC-13 — `MeasurementReport`, `HardwareValidationReport`, `ReferenceRigReport` each define their own placeholder-field collection pattern

| Field | Value |
|---|---|
| **ID** | MC-13 |
| **File** | `Sources/OpenLolaCore/Evidence/ReferenceRigReportValidation.swift`, `Sources/OpenLolaCore/Evidence/HardwareValidationReport.swift` |
| **Symbol** | `placeholderSensitiveFields(...)` — each report's `validate()` calls the free functions `placeholderFields(...)`, `placeholderIndexedFields(...)` from `PlaceholderFieldCollection.swift` |
| **Current behavior** | `PlaceholderFieldCollection.swift` provides 4 overloads of a `placeholderFields` free function that build `[(name: String, value: String)]` arrays. These arrays are then iterated by `validate()` to call `PlaceholderDetection.matches(...)` on each field. The calling code in each validation file assembles these arrays via repeated `fields.append(contentsOf: placeholderFields(...))` calls. |
| **Required behavior** | Check that user-supplied evidence fields do not contain placeholder strings before a PASS verdict is accepted. |
| **Complexity problem** | The free-function overloads in `PlaceholderFieldCollection.swift` are well-designed utilities. However, each validation file repeats the same structural pattern: build a `[PlaceholderSensitiveField]` array, then call `for field in fields { if PlaceholderDetection.matches(...) { throw ... } }`. This loop appears at least 7 times across different validation files. A helper `func checkNoPlaceholders(in fields: [PlaceholderSensitiveField], throw: (String) -> Error) throws` would unify the loop. |
| **Minimal alternative** | Add one free function `checkNoPlaceholders(_ fields: [PlaceholderSensitiveField], ifFound: (String) throws -> Void) rethrows` and replace the 7+ iteration loops with a single call. |
| **Risk of simplification** | Low. The loop body is trivial; refactoring is mechanical. |
| **Tests needed before simplification** | Build check only. `PlaceholderDetectionTests` already covers the detection logic. |
| **Verification** | `grep -rn "PlaceholderDetection.matches" Sources/` to count call sites and confirm they share the same loop structure. |
| **Confidence** | medium |
| **Action** | DEDUPLICATE |

---

### MC-14 — `LolaBaselineAvailability`, `LolaBaselineMeasurementMethod`, `LolaBaselineComparisonResult` defined in `DriftPlcFixedTargetCertification.swift` but used in `FasterThanLoLaClosure.swift`

| Field | Value |
|---|---|
| **ID** | MC-14 |
| **File** | `Sources/OpenLolaCore/Timing/DriftPlcFixedTargetCertification.swift` (lines 8-23), used by `Sources/OpenLolaCore/Release/FasterThanLoLaClosure.swift` |
| **Symbol** | `LolaBaselineAvailability`, `LolaBaselineMeasurementMethod`, `LolaBaselineComparisonResult`, `LolaBaselineLatencyMetrics`, `LolaBaselineComparison` |
| **Current behavior** | Five types related to "LoLa baseline comparison" (comparing open-lola latency against reference LoLa measurements) are defined inside `DriftPlcFixedTargetCertification.swift`, a file about drift/PLC timing certification. They are also used by `FasterThanLoLaClosure.swift`, which is a release gate. |
| **Required behavior** | Encode the LoLa baseline comparison model and make it available to both the certification and the release gate. |
| **Complexity problem** | These five types do not belong in the drift/PLC certification file — they model a cross-cutting "are we faster than LoLa" concept. Their placement in `DriftPlcFixedTargetCertification.swift` means a developer reading `FasterThanLoLaClosure.swift` must know to look in the timing certification file for the base types. This is a code-locality violation that increases reading effort. |
| **Minimal alternative** | Move the five types to a shared file: `Release/LolaBaselineComparison.swift` or add them to `OpenLolaContracts` if they are a public contract. |
| **Risk of simplification** | None. File move only. No behavior change. |
| **Tests needed before simplification** | Build check only. |
| **Verification** | `grep -rn "LolaBaseline" Sources/` to confirm the complete set of files that use these types. |
| **Confidence** | high |
| **Action** | SIMPLIFY |

---

### MC-15 — `ExternalConnectorSessionRunner.swift` and `ExternalConnectorSessionRuntime.swift` — unclear split

| Field | Value |
|---|---|
| **ID** | MC-15 |
| **File** | `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRunner.swift`, `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift` |
| **Symbol** | `ExternalConnectorSessionRunner`, `ExternalConnectorSessionRuntime` |
| **Current behavior** | UNCLEAR — the split between "Runner" and "Runtime" is not immediately apparent from names alone. In this codebase, the `*Runner` pattern typically owns a `run(configuration:)` entry point and `*Runtime` typically owns stateful lifecycle. |
| **Required behavior** | UNCLEAR without reading both files fully. |
| **Complexity problem** | The existence of both a `Runner` and a `Runtime` for external connectors (in addition to the `Session`, `Report`, `ProcessRunner`, `SessionModels`, `SessionValidation`, `ExecutablePreflight`, and `ParsingDefaults` files in the same directory) suggests the connector subsystem may be split across too many files for its actual complexity. Excessive file-splitting hides the overall structure without adding modularity. |
| **Minimal alternative** | INVESTIGATE — determine if `ExternalConnectorSessionRunner` and `ExternalConnectorSessionRuntime` can be merged, or if the distinction is justified by concurrency/lifecycle requirements. |
| **Risk of simplification** | UNCLEAR. |
| **Tests needed before simplification** | Read both files and map their public APIs and callers. |
| **Verification** | `grep -rn "ExternalConnectorSessionRunner\|ExternalConnectorSessionRuntime" Sources/ Tests/` to map all callers. |
| **Confidence** | low |
| **Action** | INVESTIGATE |

---

### MC-16 — `NetworkVideoControlDegradeMatrix` and `VideoControlDegradeMatrix` — unclear relationship

| Field | Value |
|---|---|
| **ID** | MC-16 |
| **File** | `Sources/OpenLolaCore/Support/Inventories/VideoControlDegradeMatrix.swift` |
| **Symbol** | `VideoControlDegradeMatrix` |
| **Current behavior** | UNCLEAR — a `VideoControlDegradeMatrix` file exists in `Support/Inventories/`. Its content and callers were not read. |
| **Required behavior** | UNCLEAR. |
| **Complexity problem** | Another inventory file whose purpose and call sites were not fully confirmed. Given the pattern of the other inventory files (OE-15, MC-08), it likely follows the same documentation-as-code pattern. |
| **Minimal alternative** | INVESTIGATE. |
| **Risk of simplification** | UNCLEAR. |
| **Tests needed before simplification** | Read the file and grep for callers. |
| **Verification** | `cat Sources/OpenLolaCore/Support/Inventories/VideoControlDegradeMatrix.swift && grep -rn "VideoControlDegradeMatrix" Sources/ Tests/` |
| **Confidence** | low |
| **Action** | INVESTIGATE |

---

### MC-17 — `RealtimeAudioBlockRing` may be dead code

| Field | Value |
|---|---|
| **ID** | MC-17 |
| **File** | `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift` (lines 79-125) |
| **Symbol** | `RealtimeAudioBlockRing` |
| **Current behavior** | A public FIFO ring type (`push`/`peek`/`pop`) for `RealtimeAudioFrameBlock` instances. 46 lines. No call to `RealtimeAudioBlockRing(` was found in a quick grep across `Sources/` and `Tests/`. |
| **Required behavior** | UNCLEAR — possibly intended for use in a path that uses `RealtimeAudioDueBlockPlayout` instead. |
| **Complexity problem** | If this type has no callers, it is dead code that increases reading burden and suggests an alternative implementation that was never activated or was replaced by `RealtimeAudioDueBlockPlayout`. |
| **Minimal alternative** | Delete if no callers exist. |
| **Risk of simplification** | None if dead. |
| **Tests needed before simplification** | `grep -rn "RealtimeAudioBlockRing(" Sources/ Tests/` to confirm zero callers. |
| **Verification** | Same grep. |
| **Confidence** | medium (needs grep confirmation) |
| **Action** | INVESTIGATE → DELETE if no callers |

---

## Prioritized Remediation Table

Ordered by: (1) correctness/test risk, (2) duplication magnitude, (3) code size reduction.

| Priority | ID | Action | File(s) | Risk | Confidence | Rationale |
|---|---|---|---|---|---|---|
| 1 | **MC-04** | INVESTIGATE | `RealtimeAudioEngine.swift`, `RealtimeAudioEngineReportValidation.swift` | medium | high | Self-asserted safety checklist creates false confidence; validation gate is trivially bypassed by setting booleans to `true`. No test exercises the failure path. |
| 2 | **MC-10** | INVESTIGATE | All `*SyntheticSmoke.swift` files | medium | medium | Fabricated numeric metrics in synthetic smokes look like real measurements. Any downstream consumer that does not check `runMode == .synthetic` will process fake data without warning. |
| 3 | **MC-17** | INVESTIGATE → DELETE | `RealtimeAudioBuffers.swift` | low | medium | Possible dead code in realtime audio path. Dead code in a realtime buffer file creates reading confusion about which ring is actually used. |
| 4 | **MC-01** | DEDUPLICATE | 10 `*RunMode` files | medium | high | 10 identical enum declarations. High duplication surface; any new run mode case must be added in 10 places. Consolidate to one shared type. |
| 5 | **MC-03** | DEDUPLICATE | `RealtimeAudioEngine.swift`, `UdpPcmV2FragmentPlanner.swift` | low | high | `validatePositive`/`validateNonNegative` duplicated again in addition to the 40+ cases in OE-04. Blocked on OE-01 resolution. |
| 6 | **MC-11** | INLINE | `ExternalConnectorReport.swift` | none | high | Three private 2-line require helpers; inline at their 5 call sites. |
| 7 | **MC-05** | DELETE | `CoreAudioInventoryReader.swift` | none | high | Cache for trivially-computed strings; `@unchecked Sendable` suppresses concurrency checking for no benefit. |
| 8 | **MC-14** | SIMPLIFY | `DriftPlcFixedTargetCertification.swift` → new file | none | high | Five LoLa-baseline types defined in the wrong file; move to `LolaBaselineComparison.swift`. |
| 9 | **MC-07** | SIMPLIFY | `UdpPcmV2FragmentPlanner.swift` → `UdpPcmV2Packet.swift` | none | high | `UdpPcmV2PacketHeader` struct defined in the planner file but semantically belongs with the packet codec. |
| 10 | **MC-02** | SIMPLIFY | All 30+ `*SyntheticSmoke` files | low | high | Replace caseless enum namespaces with free functions or static factories. Pure boilerplate. |
| 11 | **MC-13** | DEDUPLICATE | `ReferenceRigReportValidation.swift`, `HardwareValidationReport.swift`, others | low | medium | `PlaceholderDetection.matches(...)` called in 7+ identical loops; add one helper to unify them. |
| 12 | **MC-06** | SIMPLIFY | `AudioRoutingAssumptionLedger.swift` | low | medium | Documentation-as-code; move to Markdown. |
| 13 | **MC-08** | SIMPLIFY | `FixtureSmokeMatrix.swift`, `FixtureSmokeMatrixData.swift` | medium | medium | Another inventory-as-code file with manually maintained string paths. |
| 14 | **MC-15** | INVESTIGATE | `ExternalConnectorSessionRunner.swift`, `ExternalConnectorSessionRuntime.swift` | low | low | Unclear Runner vs Runtime split in an already-complex connector subsystem. |
| 15 | **MC-16** | INVESTIGATE | `VideoControlDegradeMatrix.swift` | low | low | Unread inventory file; may be another documentation-as-code pattern. |
| 16 | **MC-12** | KEEP | `RxBuffering.swift` | n/a | low | Four factory methods are proportional; `notes` field is a minor improvement only. |

---

## Cross-Reference with `docs/overengineering-index.md`

The following findings in this document are NEW (not covered in the over-engineering index):

| This document | Issue |
|---|---|
| MC-01 | 10 identical `*RunMode` enums |
| MC-02 | 30+ `*SyntheticSmoke` enum namespaces |
| MC-04 | Self-asserted safety checklist |
| MC-05 | `CoreAudioFallbackIdentityCache` |
| MC-06 | `AudioRoutingAssumptionLedger` |
| MC-07 | `UdpPcmV2PacketHeader` in wrong file |
| MC-10 | Fabricated metrics in synthetic smokes |
| MC-14 | `LolaBaseline*` types in wrong file |
| MC-15 | Runner vs Runtime split (UNCLEAR) |
| MC-17 | `RealtimeAudioBlockRing` possible dead code |

The following overlap with or extend prior findings:

| This document | Prior finding | Extension |
|---|---|---|
| MC-02 | OE-10 (`NativeAppShellSyntheticSmoke`) | Generalizes to all 30+ smoke namespaces |
| MC-03 | OE-04 (40+ private require* helpers) | Names two additional instances in realtime/network |
| MC-08 | OE-15 (inventory-as-code) | Adds `FixtureSmokeMatrix` to the inventory list |
| MC-11 | OE-04 (40+ private require* helpers) | Names specific connector instance |
| MC-13 | OE-07 (`PlaceholderDetection`) | Notes the call-site loop duplication pattern |
