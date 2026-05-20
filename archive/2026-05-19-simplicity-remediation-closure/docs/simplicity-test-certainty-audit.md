# Simplicity, Test-Quality, and Certainty Audit

**Repository:** open-lola2
**Date:** 2026-05-19
**Hard rules:** No production code changed. No tests changed. Only this file created/updated.

This document consolidates and cross-references four prior audits:

| Audit | File | Findings |
|-------|------|----------|
| Over-Engineering Index | `docs/overengineering-index.md` | OE-01 – OE-20 |
| Minimum-Code Audit | `docs/minimum-code-audit.md` | MC-01 – MC-17 |
| Test Intent Audit | `docs/test-intent-audit.md` | TI-01 – TI-21 |
| Fail-Loud Audit | `docs/fail-loud-audit.md` | FL-01 – FL-15 |

**No finding in this document is invented.** Every finding traces to at least one source ID above.
Uncertainty preserved from source audits; conflicts are surfaced rather than averaged.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Source Audit Coverage](#2-source-audit-coverage)
3. [Consolidated Findings Index](#3-consolidated-findings-index)
4. [Minimum-Code Findings](#4-minimum-code-findings)
5. [Test-Intent Findings](#5-test-intent-findings)
6. [Fail-Loud Findings](#6-fail-loud-findings)
7. [Duplicates Merged](#7-duplicates-merged)
8. [Conflicts Between Source Audits](#8-conflicts-between-source-audits)
9. [Highest-Risk Issues](#9-highest-risk-issues)
10. [Low-Risk Simplification Candidates](#10-low-risk-simplification-candidates)
11. [Suggested Remediation Slices](#11-suggested-remediation-slices)
12. [Verification Strategy](#12-verification-strategy)
13. [Remaining Uncertainty](#13-remaining-uncertainty)

---

## 1. Executive Summary

The four source audits cover 68 original findings. After merging confirmed duplicates, 45 consolidated
findings remain across three themes.

**Critical items (P0)** — can cause false success in a critical path, silent data loss, or a
production correctness gap with no test catching it:

- Release manifest PASS gate is a plain substring match — trivially bypassable (C-FL-10)
- Video reassembly failure silently produces "zero failures" in the evidence report (C-FL-02)
- LoLa capture report: per-packet unexpected errors do not affect the verdict (C-FL-11)
- `DirectAudioMediaRouter` channel routing success is completely untested (C-TI-09)
- `RealtimeAudioPacketHandoff` concurrent access is completely untested (C-TI-12)
- LoLa QuickConnect fallback tests do not run in CI (4 tests skip silently) (C-TI-11)

**High-risk items (P1)** — likely correctness bugs, serious UX issues, or important missing
verification:

- Core Audio graph cleanup results discarded at two callers (C-FL-04)
- UI cannot distinguish "corrupt report file" from "no evidence" (C-FL-08)
- Session token I/O error is silently treated as "stale evidence" (C-FL-09)
- LoLa TX with zero bytes sent produces `.partial` (no error) (C-FL-07)
- `RealtimeAudioCallbackSafetyChecklist` is self-attested with no runtime measurement (C-MC-06)
- Synthetic smoke reports contain plausible-looking fabricated numeric metrics (C-MC-07)
- `UdpPcmLocalhostSmoke` test proves no crash but not payload correctness (C-TI-04)
- Reconnection does not test packet continuity or sequence reset (C-TI-10)
- `UdpPcmSequenceTracker` wrap-around at `UInt64.max → 0` untested (C-TI-13)

**Structural simplification targets (P2)** — duplication, boilerplate, and weak tests that increase
maintenance burden without adding safety:

- 10 identical `*RunMode` enums (C-MC-03)
- 40+ duplicated `require*` private helpers + validation protocol hierarchy (C-MC-01)
- 30+ caseless `*SyntheticSmoke` enum namespaces (C-MC-02)
- Inventory-as-code pattern: 5+ Swift files encoding metadata as literals (C-MC-11)
- Multiple snapshot tests that fail on every milestone advance or compiler update (C-TI-01, C-TI-07)
- `.partial` verdict conflates "ran without detected error" and "ran cleanly" (C-FL-06)

---

## 2. Source Audit Coverage

### Scope per audit

| Audit | Primary scope | Lines audited (approx.) |
|-------|--------------|------------------------|
| OE | `Sources/` Swift; `Tests/` | 68,000+ |
| MC | `Sources/` Swift; `Tests/OpenLolaCoreTests/` | 68,000+ |
| TI | `Tests/OpenLolaCoreTests/` (180 files, 748 `@Test`, 5203 `#expect`) | 40,000+ |
| FL | `Sources/` Swift; `Sources/open-lola-app/` | 68,000+ |

### Areas not fully covered by any audit

- `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift` and `AppShellSlice05Tests.swift` — partially audited; UI phase transitions tested but "no fake status text" rule not exhaustively verified
- `Sources/COpenLolaAtomics/`, `Sources/opus-1.5.2/`, `Sources/xs_ref_sw_ed2/` — excluded as vendored/C bridge code
- NAT rendezvous relay JSON decode silences — not fully traced (noted in FL uncertainty)
- `ExternalConnectorConnectionPlanConfiguration` field-by-field overlap with `ExternalConnectorSessionConfiguration` — estimated but not mechanically diffed

---

## 3. Consolidated Findings Index

### MINIMUM_CODE

| ID | Sources | Severity | Title |
|----|---------|----------|-------|
| C-MC-01 | OE-01, OE-04, OE-18, MC-03, MC-11 | P2 | Validation protocol hierarchy + 40+ duplicated require* helpers |
| C-MC-02 | MC-02, OE-10 | P3 | 30+ caseless `*SyntheticSmoke` enum namespaces |
| C-MC-03 | MC-01 | P2 | 10 identical `*RunMode` enums |
| C-MC-04 | OE-02, OE-05 | P2 | `KeyValueArgumentParser` over-structured; duplicated in NativeAppShell |
| C-MC-05 | OE-03 | P2 | `ExternalConnectorPipeCapture` / `BoundedPipeCapture` duplication |
| C-MC-06 | MC-04 | P1 | `RealtimeAudioCallbackSafetyChecklist` self-attested with no runtime check |
| C-MC-07 | MC-10 | P1 | Fabricated plausible-looking numeric metrics in synthetic smokes |
| C-MC-08 | OE-11, OE-12 | P2 | God struct `ExternalConnectorSessionConfiguration` + near-duplicate `ConnectionPlanConfiguration` |
| C-MC-09 | OE-07 | P3 | `PlaceholderDetection` over-engineered word-boundary scanner |
| C-MC-10 | OE-08 | P3 | `DebugTrace` caseless enum wrappers (3 single-use namespaces) |
| C-MC-11 | OE-14, OE-15, MC-08, MC-16 | P2 | Inventory-as-code pattern (5+ files encoding metadata as Swift literals) |
| C-MC-12 | OE-16 | P3 | `JSONReportCoder` intermediate enum wrapping 3 trivial calls |
| C-MC-13 | OE-17 | P3 | `UltraGridMediaFormatRegistry` single-use abstraction |
| C-MC-14 | OE-19 | P3 | `DebugTraceFieldPolicy` speculative configurability (UNCLEAR) |
| C-MC-15 | OE-13, OE-20 | P3 | `GoalCodewiseRequirementID` / `Area` / `Status` typed enum boilerplate |
| C-MC-16 | OE-09 | P3 | `OpenLolaContractsAliases.swift` re-export file |
| C-MC-17 | MC-05 | P2 | `CoreAudioFallbackIdentityCache` caches trivially computed strings |
| C-MC-18 | MC-13 | P3 | `PlaceholderDetection.matches` iteration loop duplicated 7+ times |
| C-MC-19 | MC-06 | P2 | `AudioRoutingAssumptionLedger` — documentation encoded as runtime Swift |
| C-MC-20 | MC-09, MC-17 | P2 | `RealtimeAudioBlockRing` — possible dead code |
| C-MC-21 | MC-14 | P3 | `LolaBaseline*` types defined in wrong file |
| C-MC-22 | MC-07 | P3 | `UdpPcmV2PacketHeader` defined in planner file, not packet file |
| C-MC-23 | MC-15 | P3 | `ExternalConnectorSessionRunner` vs `Runtime` split unclear (INVESTIGATE) |
| C-MC-24 | OE-06 | P3 | `CapabilitySummary` historical milestone statics (intent UNCLEAR) |

### TEST_INTENT

| ID | Sources | Severity | Title |
|----|---------|----------|-------|
| C-TI-01 | TI-01 | P2 | `CapabilitySummary` test is a milestone version snapshot |
| C-TI-02 | TI-02 | P2 | `SyntheticSmokeReportContractTests` frozen IDs + `> 0` bounds |
| C-TI-03 | TI-03, MC-06 | P2 | `AudioRoutingAssumptionLedger` test validates documentation, not routing |
| C-TI-04 | TI-04 | P1 | `udpPcmLocalhostSmokeRoundTripsPacket` proves no crash, not payload correctness |
| C-TI-05 | TI-05 | P2 | `VerdictValidationPolicy` prefix list asserted but not exercised end-to-end |
| C-TI-06 | TI-06 | P2 | `CodeLineBudgetTests` enforces LOC count, not behavioral intent |
| C-TI-07 | TI-07 | P2 | `rxBufferImpairmentSimulator` PRNG-fragile 9-decimal golden floats |
| C-TI-08 | TI-08 | P2 | `SourceNamingConventionTests` mixes doc linting with behavioral assertions |
| C-TI-09 | TI-09 | P0 | MISSING: `DirectAudioMediaRouter` routing success and channel mapping |
| C-TI-10 | TI-10 | P1 | MISSING: packet continuity (sequence, buffer) across reconnection |
| C-TI-11 | TI-11 | P0 | LoLa QuickConnect fallback: 4 substantive tests skip silently in CI |
| C-TI-12 | TI-12 | P0 | MISSING: concurrent `RealtimeAudioPacketHandoff.receive()` + `dequeue()` |
| C-TI-13 | TI-13 | P1 | MISSING: `UdpPcmSequenceTracker` wrap-around at `UInt64.max` → `0` |

### FAIL_LOUD

| ID | Sources | Severity | Title |
|----|---------|----------|-------|
| C-FL-01 | FL-01 | P1 | `LoLaLiveTransmitErrors.errors.first` — second concurrent TX error silent |
| C-FL-02 | FL-02 | P0 | `(try? recoverVideoFragments) ?? []` — recovery failure = "zero failures" |
| C-FL-03 | FL-03 | P1 | `terminateExternalConnectorProcessGroup`: SIGTERM/SIGKILL results discarded |
| C-FL-04 | FL-04, FL-14 | P1 | `graph.stop()` cleanup result discarded at two callers + startup error path |
| C-FL-05 | FL-05 | P1 | `AudioDeviceDestroyIOProcID` / `AudioDeviceStop` OSStatus discarded in defer/error paths |
| C-FL-06 | FL-06 | P2 | `.partial` conflates "ran without detected error" and "genuinely incomplete evidence" |
| C-FL-07 | FL-07 | P1 | LoLa TX with zero bytes sent returns `.partial`, not `.fail` |
| C-FL-08 | FL-08, FL-09 | P1 | UI cannot distinguish "corrupt evidence file" from "no evidence" or "file error" from "stale token" |
| C-FL-09 | FL-10 | P1 | Release readiness: file I/O error → `exists: false`, indistinguishable from absent |
| C-FL-10 | FL-11 | P0 | Release manifest PASS gate is a substring match — trivially bypassable |
| C-FL-11 | FL-12 | P0 | LoLa capture report: unexpected per-packet errors downgraded to notes, not verdict |
| C-FL-12 | FL-13 | P2 | `closeOutputHandles()` return value discarded in `AppExecutionController` |

---

## 4. Minimum-Code Findings

---

### C-MC-01 — Validation protocol hierarchy + 40+ duplicated `require*` helpers

| Field | Value |
|-------|-------|
| **ID** | C-MC-01 |
| **Source audits** | OE-01, OE-04, OE-18, MC-03, MC-11 |
| **Theme** | MINIMUM_CODE — duplicated abstractions |
| **Severity** | P2 |
| **File** | `Sources/OpenLolaCore/Core/ValidationPrimitives.swift` (364 lines); 10+ Platform, Connector, Audio, Network files |
| **Symbol** | `ReportPrimitiveValidating`, `ReportValidationProtocol` (empty sub-protocol), 40+ private `requireNonEmpty`/`requirePositive`/`validatePositive` functions across modules |
| **Evidence** | Six protocols for error-factory dispatch; `ReportValidationProtocol` extends `ReportPrimitiveValidating` and adds zero requirements. `ValidationPrimitives` free functions exist but 40+ per-file private copies of the same 2-line guard/throw also exist. `MC-11` names a specific instance in `ExternalConnectorReport.swift` (`requireExternalConnectorSession*`). `MC-03` names instances in `RealtimeAudioEngine.swift` and `UdpPcmV2FragmentPlanner.swift`. |
| **Why it matters** | The protocol hierarchy was built to eliminate the duplication. It failed: every module has its own private helpers anyway. The empty `ReportValidationProtocol` adds a second conformance declaration for no benefit. Any new error case type must invent yet another set of local wrappers or conform to the hierarchy. |
| **Suggested remediation** | (1) Delete `ReportValidationProtocol`; all conformances become `ReportPrimitiveValidating`. (2) Remove per-file private `require*` helpers; call `ValidationPrimitives` directly, or accept the local 2-liners and eliminate the protocol hierarchy entirely. |
| **Test / verification** | `swift test --no-parallel` after consolidation; `grep -rn "ReportValidationProtocol\|private func require" Sources/` to map scope. |
| **Risk of change** | Medium — every validator enum needs updating; build will fail until all conformances are resolved. |
| **Confidence** | High |

---

### C-MC-02 — 30+ caseless `*SyntheticSmoke` enum namespaces

| Field | Value |
|-------|-------|
| **ID** | C-MC-02 |
| **Source audits** | MC-02, OE-10 |
| **Theme** | MINIMUM_CODE — boilerplate |
| **Severity** | P3 |
| **File** | Every module: 30+ `*SyntheticSmoke.swift` files |
| **Symbol** | `RealtimeAudioEngineSyntheticSmoke`, `LatencyBenchmarkSyntheticSmoke`, ... (30+ names) |
| **Evidence** | Each is a caseless `enum` with one `public static func run() throws -> XxxReport`. Swift caseless enums are a namespace pattern with no encapsulation benefit. The `SyntheticSmoke` suffix is redundant with `runMode: .synthetic` on the returned report. |
| **Why it matters** | 30 boilerplate wrappers add file-per-smoke overhead and obscure the actual construction logic. Call sites must import the enum namespace rather than calling a function or factory. |
| **Suggested remediation** | Replace each `enum XxxSyntheticSmoke { static func run() }` with a free function `makeXxxSyntheticReport()` or a static factory `XxxReport.synthetic()`. No behavioral change. |
| **Test / verification** | `swift test --no-parallel`; `grep -rn "SyntheticSmoke" Sources/ Tests/` before and after. |
| **Risk of change** | Low — pure rename; all tests call `.run()` which would become the new function call. |
| **Confidence** | High |

---

### C-MC-03 — 10 identical `*RunMode` enums

| Field | Value |
|-------|-------|
| **ID** | C-MC-03 |
| **Source audits** | MC-01 |
| **Theme** | MINIMUM_CODE — duplicated abstractions |
| **Severity** | P2 |
| **File** | 10 separate files across Audio, Integration, Platform, Network, Benchmarks, Control, Timing |
| **Symbol** | `NativeAppShellRunMode`, `RealtimeAudioRunMode`, `IntegratedAvRunMode`, `MacToMacRouteCertificationRunMode`, `NetworkAoipCertificationRunMode`, `DriftPlcFixedTargetCertificationRunMode`, `LatencyTuningRunMode`, `PerformanceAuditRunMode`, `E2EBenchmarkRunMode`, `LightingFixtureGateRunMode` |
| **Evidence** | Each is `enum X: String, Codable, Equatable, Sendable { case synthetic; case measured }`. Raw values are identical across all 10. A new case (e.g., `replayed`) must be added in 10 places. |
| **Why it matters** | Any new run-mode case causes a 10-file sweep. JSON deserialization for all 10 types is already compatible with one shared type. No consumer writes `let x: RealtimeAudioRunMode = .synthetic` where using `ReportRunMode.synthetic` would fail. |
| **Suggested remediation** | One shared `public enum ReportRunMode: String, Codable, Equatable, Sendable { case synthetic; case measured }` in `OpenLolaContracts`. Each report struct uses `ReportRunMode`. Three enums with extra cases remain local. |
| **Test / verification** | `swift test --no-parallel`; confirm JSON round-trips for all report types. |
| **Risk of change** | Medium — every affected report struct changes its field type; tests deserializing JSON fixtures are unaffected if raw values are preserved. |
| **Confidence** | High |

---

### C-MC-04 — `KeyValueArgumentParser` over-structured; duplicated in `NativeAppShell`

| Field | Value |
|-------|-------|
| **ID** | C-MC-04 |
| **Source audits** | OE-02, OE-05 |
| **Theme** | MINIMUM_CODE — unnecessary configurability; duplication |
| **Severity** | P2 |
| **File** | `Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift` (202 lines); `Sources/OpenLolaCore/Platform/NativeAppShell.swift` (lines 297–325) |
| **Symbol** | `KeyValueArgumentParser`; `NativeAppRuntimeSmokeConfiguration.parse` |
| **Evidence** | `KeyValueArgumentParser` is a struct wrapping `allowedKeys` and `allowsDashPrefixedValues`, plus a static `parseValues` convenience wrapper that constructs and immediately calls the instance method. `NativeAppShell.swift` contains a hand-written duplicate of the same `--key value` argument parsing loop (same error cases, same guard logic). |
| **Why it matters** | The struct abstraction adds no state beyond two parameters. The duplicate parser in `NativeAppShell` means bug fixes to the parser must be applied twice. |
| **Suggested remediation** | Replace `KeyValueArgumentParser` struct with a free function `parseKeyValueArguments`. Replace the `NativeAppShell` duplicate parser with a call to the shared utility. |
| **Test / verification** | `swift test --filter KeyValueArgumentParserTests`; confirm `NativeAppRuntimeSmokeConfiguration` tests still pass. |
| **Risk of change** | Low — pure refactor of parsing logic; error semantics are identical. |
| **Confidence** | High |

---

### C-MC-05 — `ExternalConnectorPipeCapture` / `BoundedPipeCapture` duplication

| Field | Value |
|-------|-------|
| **ID** | C-MC-05 |
| **Source audits** | OE-03 |
| **Theme** | MINIMUM_CODE — duplicated abstractions |
| **Severity** | P2 |
| **File** | `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift` (lines 405–460); `Sources/OpenLolaCore/Support/BoundedPipeCapture.swift` (67 lines) |
| **Symbol** | `ExternalConnectorPipeCapture`, `BoundedPipeCapture` |
| **Evidence** | Identical structure: `readHandle`, `lock: NSLock`, `prefixData`, `limit`, `didClose/didFinish` idempotency guards, `readabilityHandler` in init, `stopAndSnapshot()/finish()`, `capture(_:)`, `prefix()`. Behavioral difference is cosmetic (character vs byte limiting in `prefix()`). |
| **Why it matters** | Bug fixes or thread-safety improvements must be applied to two independent implementations. |
| **Suggested remediation** | Merge into one `BoundedPipeCapture` with an optional parameter for character vs byte limit. |
| **Test / verification** | `swift test --filter BoundedPipeCaptureTests`; confirm `ExternalConnectorProcessRunner` integration tests pass. |
| **Risk of change** | Low — both call sites would use the merged type. |
| **Confidence** | High |

---

### C-MC-06 — `RealtimeAudioCallbackSafetyChecklist` self-attested with no runtime check

| Field | Value |
|-------|-------|
| **ID** | C-MC-06 |
| **Source audits** | MC-04 |
| **Theme** | MINIMUM_CODE — false confidence; stale compatibility paths |
| **Severity** | P1 |
| **File** | `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift` (lines 160–197) |
| **Symbol** | `RealtimeAudioCallbackSafetyChecklist`, `firstViolation` |
| **Evidence** | A 7-boolean struct where each field asserts a realtime safety property (`noAllocationInCallback`, `noLoggingInCallback`, etc.). In every production call site and synthetic smoke, all 7 fields are set to `true` by the programmer writing the report. The `validate()` gate checks `firstViolation != nil`. No test exercises `firstViolation` returning a non-nil value from real report data — confirmed by audit. |
| **Why it matters** | The validation gate is trivially bypassed by writing `true`. A developer who incorrectly marks `noAllocationInCallback = true` (the code does allocate in the callback) produces a report that passes validation with no indication of the real state. The checklist creates false confidence in realtime safety, which is a critical correctness property. |
| **Suggested remediation** | Option A: Keep the struct as documentation but add a code comment stating it is a self-attestation, not instrumented. Option B: Add a test that sets one field to `false` and confirms `validate()` rejects the report (confirming the gate is at least exercised). See also C-TI-04 (weak smoke test). |
| **Test / verification** | `grep -rn "firstViolation\|safety.firstViolation" Sources/ Tests/` to confirm no test exercises the failure path. `swift test --filter RealtimeAudioEngineTests`. |
| **Risk of change** | Medium for changing the validation gate; low for adding documentation comment. |
| **Confidence** | High |

---

### C-MC-07 — Fabricated plausible-looking numeric metrics in synthetic smokes

| Field | Value |
|-------|-------|
| **ID** | C-MC-07 |
| **Source audits** | MC-10 |
| **Theme** | MINIMUM_CODE — speculative features; false certainty risk |
| **Severity** | P1 |
| **File** | All `*SyntheticSmoke.swift` files that set numeric metric fields |
| **Symbol** | e.g., `LatencyBenchmarkSyntheticSmoke.run()`: `p50Microseconds: 80`, `p95Microseconds: 160`, `cpuP50Percent: 8`, etc. |
| **Evidence** | Synthetic smokes build structurally valid reports with invented numeric values that look like real measurements (e.g., `p50Microseconds: 80`, `oneWayEstimateMicroseconds: 2_400`). The only guard is `runMode: .synthetic` and `verdict: .partial`. Any consumer that does not check `runMode` will process fabricated data without warning. |
| **Why it matters** | A CI reporter or evidence aggregator that ingests synthetic smoke JSON artifacts without checking `runMode` would treat fabricated latency numbers as real measurements. Tests that assert `report.timing.p50Microseconds == 80` are testing a hardcoded constant, not any production behavior. |
| **Suggested remediation** | Replace numeric metric fields in synthetic smokes with sentinel values (e.g., `0`, or `SyntheticPlaceholder.latencyMicroseconds`) that are clearly not plausible measurements. Reports should still pass `validate()`. |
| **Test / verification** | `grep -rn "p50Microseconds\|p95Microseconds\|cpuP50" Tests/` to find assertions on synthetic data. Confirm `validate()` does not enforce minimum plausible ranges on these fields. |
| **Risk of change** | Medium — tests asserting exact synthetic numeric values would need updating. |
| **Confidence** | Medium |

---

### C-MC-08 — God struct `ExternalConnectorSessionConfiguration` + near-duplicate `ConnectionPlanConfiguration`

| Field | Value |
|-------|-------|
| **ID** | C-MC-08 |
| **Source audits** | OE-11, OE-12 |
| **Theme** | MINIMUM_CODE — excessive indirection; duplicated abstractions |
| **Severity** | P2 |
| **File** | `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift`; `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorConnectionPlan.swift` (684 lines) |
| **Symbol** | `ExternalConnectorSessionConfiguration` (40+ fields); `ExternalConnectorConnectionPlanConfiguration` (near-duplicate) |
| **Evidence** | `ExternalConnectorSessionConfiguration` holds fields for all three connectors (LoLa, UltraGrid, JackTrip) in a single struct. LoLa-specific fields are irrelevant for JackTrip. `ExternalConnectorConnectionPlanConfiguration` duplicates most of these fields with minor naming differences (`localHost`/`remoteHost` vs `peer`/`localHost`). |
| **Why it matters** | A God struct requires all builders to ignore irrelevant fields. Developers reading LoLa connector code see UltraGrid encryption fields and vice versa. The duplication between the two configuration types means changes (e.g., a new audio codec field) require two updates. |
| **Suggested remediation** | Extend the sub-struct pattern (already used for `jackTrip: JackTripRunConfiguration`) to LoLa and UltraGrid. Investigate whether `ConnectionPlanConfiguration` can be eliminated or unified. |
| **Test / verification** | High blast radius — map all `buildXPlan` functions and integration tests before acting. `grep -rn "ExternalConnectorSessionConfiguration\(" Sources/ Tests/`. |
| **Risk of change** | High — significant refactor; requires thorough integration test coverage. |
| **Confidence** | Medium |

---

### C-MC-09 — `PlaceholderDetection` over-engineered word-boundary scanner

| Field | Value |
|-------|-------|
| **ID** | C-MC-09 |
| **Source audits** | OE-07 |
| **Theme** | MINIMUM_CODE — overcomplicated flow |
| **Severity** | P3 |
| **File** | `Sources/OpenLolaCore/Support/PlaceholderDetection.swift` (152 lines) |
| **Symbol** | `PlaceholderDetection`, `PlaceholderPattern`, `FragmentBoundaryDirection` |
| **Evidence** | Manual `String.Index` arithmetic for word-boundary detection of 8 fixed fragment strings. An ad-hoc URI/token exclusion heuristic (`contains("://")`, `contains("@")`, `contains("::")`). 3× larger than an equivalent `NSRegularExpression`-with-`\b` implementation. |
| **Why it matters** | Implementation complexity exceeds the problem (8 fixed fragments, boundary detection). Existing tests define the behavioral contract; a simpler implementation must only pass them. |
| **Suggested remediation** | Replace with `NSRegularExpression` using `\b` word-boundary anchors, one compiled regex per fragment. Existing `PlaceholderDetectionTests` are the acceptance criterion. |
| **Test / verification** | `swift test --filter PlaceholderDetectionTests` — the replacement must pass all tests. |
| **Risk of change** | Medium — boundary cases are subtle; the tests are the contract. |
| **Confidence** | Medium |

---

### C-MC-10 — `DebugTrace` single-use caseless enum wrappers

| Field | Value |
|-------|-------|
| **ID** | C-MC-10 |
| **Source audits** | OE-08 |
| **Theme** | MINIMUM_CODE — boilerplate |
| **Severity** | P3 |
| **File** | `Sources/OpenLolaCore/Core/DebugTrace.swift` |
| **Symbol** | `DebugTraceJSONEncoder` (5 lines, 1 call site); `DebugTraceTimestampFormatter` (5 lines, 2 call sites); `DebugTraceEncodingFailureLine` (30 lines including a hand-written JSON escaper, 1 call site) |
| **Evidence** | Each is a caseless enum wrapping a single operation. `DebugTraceEncodingFailureLine` hand-implements JSON escaping for the fallback path when `JSONEncoder` fails — ironic use of manual JSON construction as the fallback for a failing encoder. |
| **Why it matters** | Three wrapper namespaces for code that could be 3 inlined expressions or one small private function. The hand-written JSON escaper re-implements what `JSONEncoder` should have done. |
| **Suggested remediation** | Inline `DebugTraceJSONEncoder` and `DebugTraceTimestampFormatter` at their call sites. Replace `DebugTraceEncodingFailureLine` with a `String(format:)` one-liner or a 2-field Codable struct. |
| **Test / verification** | Build check; confirm `jsonLines()` output format is unchanged. |
| **Risk of change** | None — internal to `DebugTrace`. |
| **Confidence** | High |

---

### C-MC-11 — Inventory-as-code pattern: 5+ Swift files encoding metadata as literals

| Field | Value |
|-------|-------|
| **ID** | C-MC-11 |
| **Source audits** | OE-14, OE-15, MC-08, MC-16 |
| **Theme** | MINIMUM_CODE — speculative features; stale compatibility paths |
| **Severity** | P2 |
| **File** | `Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift` (325 lines); `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift` (206 lines); `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift`; `Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrix.swift` + `FixtureSmokeMatrixData.swift`; `Sources/OpenLolaCore/Release/CurrentEvidenceStatusMatrix.swift`; `Sources/OpenLolaCore/Support/Inventories/VideoControlDegradeMatrix.swift` (unread) |
| **Symbol** | `CLICommandInventory`, `ReportSchemaInventory`, `SourceOwnershipInventory`, `FixtureSmokeMatrix`, `CurrentEvidenceStatusMatrix` |
| **Evidence** | Each file encodes source-level metadata (file paths, command names, schema validators, evidence lanes) as hardcoded Swift arrays of structs. Path strings go stale silently when files are renamed. `FixtureSmokeMatrix.expectedFileCount` is a manually maintained integer. These inventories produce JSON reports via CLI commands but drive no runtime logic. |
| **Why it matters** | Source metadata encoded as Swift requires a compile cycle for every editorial update. Path references are not validated at build time. The Swift encoding provides no correctness advantage over a JSON/TOML file (which would also be readable by scripts without compilation). |
| **Suggested remediation** | Move to static JSON/YAML config files. Keep the CLI commands but have them read from files. Verify whether any inventory is a required gate in `scripts/verify-release-readiness.sh` before acting. |
| **Test / verification** | `grep -rn "fixture-smoke-matrix\|current-evidence-status-matrix\|command-inventory\|report-schema-inventory" scripts/` to confirm which are CI gates. |
| **Risk of change** | Medium if any inventory is a CI gate; low otherwise. |
| **Confidence** | Medium |

---

### C-MC-12 — `JSONReportCoder` intermediate enum

| Field | Value |
|-------|-------|
| **ID** | C-MC-12 |
| **Source audits** | OE-16 |
| **Theme** | MINIMUM_CODE — single-use abstraction |
| **Severity** | P3 |
| **File** | `Sources/OpenLolaContracts/PrettyJSONCodable.swift` |
| **Symbol** | `JSONReportCoder` |
| **Evidence** | A caseless enum with 3 methods (`decode`, `prettyJSONData`, `prettyJSONString`), each 2-4 lines. Only called from `PrettyJSONCodable` default implementations. No independent use. |
| **Suggested remediation** | Delete `JSONReportCoder`. Inline the 3 trivial implementations into the `PrettyJSONCodable` extension directly. |
| **Risk of change** | None — internal to `PrettyJSONCodable.swift`. Confirm with `grep -rn "JSONReportCoder\." Sources/`. |
| **Confidence** | High |

---

### C-MC-13 — `UltraGridMediaFormatRegistry` single-use abstraction

| Field | Value |
|-------|-------|
| **ID** | C-MC-13 |
| **Source audits** | OE-17 |
| **Theme** | MINIMUM_CODE — single-use abstraction |
| **Severity** | P3 |
| **File** | Former `UltraGridMediaFormatRegistry.swift`; constants now belong beside `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibility.swift` |
| **Symbol** | `UltraGridMediaFormatRegistry` |
| **Evidence** | 4 static FourCC constants + one `rawVideoFourCC(bitsPerPixel:)` switch. Called from exactly one place: `UltraGridCompatibility.swift:380`. |
| **Suggested remediation** | Move 4 constants and 1 switch into `UltraGridCompatibility.swift`. Delete the registry file. |
| **Risk of change** | None — one call site. |
| **Confidence** | High |

---

### C-MC-14 — `DebugTraceFieldPolicy` speculative configurability

| Field | Value |
|-------|-------|
| **ID** | C-MC-14 |
| **Source audits** | OE-19 |
| **Theme** | MINIMUM_CODE — speculative feature (UNCLEAR) |
| **Severity** | P3 |
| **File** | `Sources/OpenLolaCore/Core/DebugTrace.swift` |
| **Symbol** | `DebugTraceFieldPolicy`, `DebugTraceFieldPolicy.allowing(_:)` |
| **Evidence** | A struct with 3 sets (`allowedFieldKeys`, `alwaysAllowedFieldKeys`, `unsafeFieldKeyFragments`) and a 3-way `allows()` check. One static default instance. The `allowing(_:)` mutating builder was not confirmed to have callers outside tests. |
| **Why it matters** | If `allowing` has no production callers, the struct is speculative configurability for a single-config system. UNCLEAR pending full grep. |
| **Suggested remediation** | `grep -rn "DebugTraceFieldPolicy\|\.allowing(" Sources/ Tests/`. If `allowing` has no callers: inline the `allows` check as a 5-line private function in `DebugTrace`. |
| **Risk of change** | Low if no custom policy callers exist. |
| **Confidence** | Low — needs grep confirmation. |

---

### C-MC-15 — `GoalCodewiseRequirementID` typed enum boilerplate

| Field | Value |
|-------|-------|
| **ID** | C-MC-15 |
| **Source audits** | OE-13, OE-20 |
| **Theme** | MINIMUM_CODE — overcomplicated flow; boilerplate |
| **Severity** | P3 |
| **File** | `Sources/OpenLolaCore/Release/Goal/GoalCodewiseClosure.swift` |
| **Symbol** | `GoalCodewiseRequirementID` (50 cases), `GoalCodewiseRequirementArea` (12 cases), `GoalCodewiseRequirementStatus` (2 cases) |
| **Evidence** | 50-case `CaseIterable` enum where validation loops immediately convert `.rawValue` to strings. `Area` and `Status` fields never drive runtime branching — they exist as JSON labels only. |
| **Suggested remediation** | Replace `GoalCodewiseRequirementID` with `static let allRequirementIDs: [String]`. Replace `Area`/`Status` enums with `String` fields. Preserve the exhaustiveness check. |
| **Risk of change** | Low for string replacement (raw values preserved); medium if fixture JSON is tested against typed decoding. |
| **Confidence** | Medium |

---

### C-MC-16 — `OpenLolaContractsAliases.swift` re-export file

| Field | Value |
|-------|-------|
| **ID** | C-MC-16 |
| **Source audits** | OE-09 |
| **Theme** | MINIMUM_CODE — single-use abstraction |
| **Severity** | P3 |
| **File** | `Sources/OpenLolaCore/Core/OpenLolaContractsAliases.swift` |
| **Symbol** | 4 `public typealias` re-exports of `OpenLolaContracts` types |
| **Evidence** | 4 lines re-exporting `MeasurementMethodology`, `MeasurementVerdict`, `PrettyJSONCodable`, `RxBufferProfile`. Consumers could import `OpenLolaContracts` directly (it is already a declared dependency). |
| **Suggested remediation** | `@_exported import OpenLolaContracts` in one shared file, or remove aliases and update import sites. |
| **Risk of change** | Low — search for `OpenLolaCore.MeasurementVerdict` etc. to find affected call sites. |
| **Confidence** | Medium |

---

### C-MC-17 — `CoreAudioFallbackIdentityCache` caches trivially computed strings

| Field | Value |
|-------|-------|
| **ID** | C-MC-17 |
| **Source audits** | MC-05 |
| **Theme** | MINIMUM_CODE — unnecessary configurability |
| **Severity** | P2 |
| **File** | `Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift` (lines 409–440) |
| **Symbol** | `CoreAudioFallbackIdentityCache`, `coreAudioFallbackIdentityCache` |
| **Evidence** | A lock-guarded class with two `[AudioObjectID: String]` dictionaries caching `"Unknown Core Audio device \(deviceID)"`. The cached values are deterministic functions of their inputs. Uses `@unchecked Sendable`, suppressing Swift Concurrency checking. |
| **Why it matters** | Caching deterministic, cheap string interpolation adds a lock, two dictionaries, and an `NSLock` for zero performance benefit on a degenerate fallback path. `@unchecked Sendable` suppresses concurrency analysis for a shared mutable object with no justification. |
| **Suggested remediation** | Delete `CoreAudioFallbackIdentityCache`. Return `"Unknown Core Audio device \(deviceID)"` inline at the fallback call site. |
| **Risk of change** | None — string values are identical. Confirm with `grep -rn "coreAudioFallbackIdentityCache"` (appears only at definition and one access). |
| **Confidence** | High |

---

### C-MC-18 — `PlaceholderDetection.matches` iteration loop duplicated 7+ times

| Field | Value |
|-------|-------|
| **ID** | C-MC-18 |
| **Source audits** | MC-13 |
| **Theme** | MINIMUM_CODE — boilerplate |
| **Severity** | P3 |
| **File** | `Sources/OpenLolaCore/Evidence/ReferenceRigReportValidation.swift`; `Sources/OpenLolaCore/Evidence/HardwareValidationReport.swift`; and 5+ other validation files |
| **Symbol** | `for field in fields { if PlaceholderDetection.matches(...) { throw ... } }` pattern |
| **Evidence** | `PlaceholderFieldCollection.swift` provides well-designed utilities for building field arrays. The consuming validation files then repeat the same 3-line loop to iterate and check. This loop appears 7+ times with identical structure. |
| **Suggested remediation** | One free function `checkNoPlaceholders(_ fields: [PlaceholderSensitiveField], ifFound: (String) throws -> Void) rethrows`. |
| **Risk of change** | Low — mechanical; loop body is trivial. |
| **Confidence** | Medium |

---

### C-MC-19 — `AudioRoutingAssumptionLedger` — documentation encoded as runtime Swift

| Field | Value |
|-------|-------|
| **ID** | C-MC-19 |
| **Source audits** | MC-06 |
| **Theme** | MINIMUM_CODE — stale compatibility paths |
| **Severity** | P2 |
| **File** | `Sources/OpenLolaCore/Audio/Routing/AudioRoutingAssumptionLedger.swift` (141 lines) |
| **Symbol** | `AudioRoutingAssumptionLedger`, `AudioRoutingAssumption` |
| **Evidence** | 11 structs encoding routing design decisions as Swift literals. `classification`, `assumption`, `action`, and `location` fields never drive runtime branching. Tests confirm the list is non-empty and has specific IDs, but do not verify any routing behavior. Every editorial update requires a compile cycle. |
| **Why it matters** | Documentation maintained as Swift source is subject to all Swift build and change-management overhead with none of the runtime benefit. Tests protect the ledger's completeness but not the correctness of any routing decision. See also C-TI-03. |
| **Suggested remediation** | Move to `docs/multichannel-routing-assumptions.md`. Replace Swift test with a file-reading test that confirms required IDs are present. |
| **Risk of change** | Low — the struct carries no runtime behavior. |
| **Confidence** | Medium |

---

### C-MC-20 — `RealtimeAudioBlockRing` — possible dead code

| Field | Value |
|-------|-------|
| **ID** | C-MC-20 |
| **Source audits** | MC-09, MC-17 |
| **Theme** | MINIMUM_CODE — stale compatibility paths |
| **Severity** | P2 |
| **File** | `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift` (lines 79–125) |
| **Symbol** | `RealtimeAudioBlockRing` |
| **Evidence** | A public FIFO ring type (46 lines). No call to `RealtimeAudioBlockRing(` found in Sources or Tests during audit. `RealtimeAudioDueBlockPlayout` appears to serve the same purpose in the active code path. |
| **Why it matters** | Dead code in a realtime audio buffer file creates confusion about which ring is actually in use. Maintaining two ring types with similar semantics increases reading overhead. |
| **Suggested remediation** | `grep -rn "RealtimeAudioBlockRing(" Sources/ Tests/`. If zero callers: delete. |
| **Risk of change** | None if dead. Needs grep confirmation. |
| **Confidence** | Medium — needs grep confirmation. |

---

### C-MC-21 — `LolaBaseline*` types defined in wrong file

| Field | Value |
|-------|-------|
| **ID** | C-MC-21 |
| **Source audits** | MC-14 |
| **Theme** | MINIMUM_CODE — code locality |
| **Severity** | P3 |
| **File** | `Sources/OpenLolaCore/Timing/DriftPlcFixedTargetCertification.swift` (lines 8–23) |
| **Symbol** | `LolaBaselineAvailability`, `LolaBaselineMeasurementMethod`, `LolaBaselineComparisonResult`, `LolaBaselineLatencyMetrics`, `LolaBaselineComparison` |
| **Evidence** | Five LoLa-baseline-comparison types defined inside a drift/PLC timing certification file. Used by `FasterThanLoLaClosure.swift` (a release gate). A developer reading `FasterThanLoLaClosure.swift` must know to look in the timing file for the base types. |
| **Suggested remediation** | Move to `Release/LolaBaselineComparison.swift` or `OpenLolaContracts`. File move only. |
| **Risk of change** | None — file move, no behavior change. |
| **Confidence** | High |

---

### C-MC-22 — `UdpPcmV2PacketHeader` defined in planner file

| Field | Value |
|-------|-------|
| **ID** | C-MC-22 |
| **Source audits** | MC-07 |
| **Theme** | MINIMUM_CODE — code locality |
| **Severity** | P3 |
| **File** | `Sources/OpenLolaCore/Network/UDP/UdpPcmV2FragmentPlanner.swift` (lines 3–67) |
| **Symbol** | `UdpPcmV2PacketHeader` |
| **Evidence** | The packet header struct is defined in the fragment planner file; its semantic home is with the packet codec (`UdpPcmV2Packet.swift`). |
| **Suggested remediation** | Move to `UdpPcmV2Packet.swift`. Build check only. |
| **Risk of change** | None. |
| **Confidence** | High |

---

### C-MC-23 — `ExternalConnectorSessionRunner` vs `Runtime` split unclear

| Field | Value |
|-------|-------|
| **ID** | C-MC-23 |
| **Source audits** | MC-15 |
| **Theme** | MINIMUM_CODE — INVESTIGATE |
| **Severity** | P3 |
| **File** | `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRunner.swift`; `ExternalConnectorSessionRuntime.swift` |
| **Symbol** | `ExternalConnectorSessionRunner`, `ExternalConnectorSessionRuntime` |
| **Evidence** | Both files exist in the same directory alongside `Session`, `Report`, `ProcessRunner`, `SessionModels`, `SessionValidation`, `ExecutablePreflight`, `ParsingDefaults`. The Runner/Runtime distinction was not confirmed in audit. |
| **Suggested remediation** | Read both files; map their public APIs and callers. Merge if one contains only lifecycle state that belongs in the other. |
| **Risk of change** | UNCLEAR until read. |
| **Confidence** | Low |

---

### C-MC-24 — `CapabilitySummary` historical milestone statics (intent UNCLEAR)

| Field | Value |
|-------|-------|
| **ID** | C-MC-24 |
| **Source audits** | OE-06 |
| **Theme** | MINIMUM_CODE — stale compatibility paths (UNCLEAR) |
| **Severity** | P3 |
| **File** | `Sources/OpenLolaCore/Core/CapabilitySummary.swift` |
| **Symbol** | `CapabilitySummary.m00Scaffold`, `.m02ProtocolSession`, `.m14ReleaseHardening` |
| **Evidence** | Three historical static instances used only in tests that assert their `.stage` and `.description` values. `CapabilitySummary.current` is the only runtime-used instance. |
| **Why it matters** | Historical snapshot statics have no runtime role. Tests that assert their field values only confirm that constants equal themselves. However, the intent may be to freeze milestone-version behavior as a stable contract. |
| **Suggested remediation** | Confirm intent with project maintainer. If documentation: move to CHANGELOG. If contract: add a behavioral test explaining what invariant the historical values protect. |
| **Risk of change** | Low for deletion; medium for intent mismatch if intentional. |
| **Confidence** | Medium |

---

## 5. Test-Intent Findings

---

### C-TI-01 — `CapabilitySummary` test is a milestone version snapshot

| Field | Value |
|-------|-------|
| **ID** | C-TI-01 |
| **Source audits** | TI-01 |
| **Theme** | TEST_INTENT — tests that assert trivia |
| **Severity** | P2 |
| **Test file** | `CapabilitySummaryTests.swift` |
| **Test name** | `capabilitySummaryExposesCurrentM15Surface` |
| **Evidence** | Asserts `summary == .m15PackagingFieldTest` and `summary.version == "0.0.0-m15"` — milestone-specific hardcoded values. |
| **Why it matters** | This test fails on every milestone advance (false positive) and passes even if `CapabilitySummary.current` returned a stale or mismatched value, as long as someone updated the assertion to match. It tests a constant, not a behavioral invariant. |
| **Better test** | `capabilitySummary_current_matchesActiveCompileTimeMilestoneConstant` — compare `current.summary` against a symbolic constant rather than a hardcoded string. |
| **Risk of change** | Low — existing test breaks on every milestone advance regardless. |
| **Confidence** | High |

---

### C-TI-02 — `SyntheticSmokeReportContractTests` frozen IDs + `> 0` bounds

| Field | Value |
|-------|-------|
| **ID** | C-TI-02 |
| **Source audits** | TI-02 |
| **Theme** | TEST_INTENT — tests that would pass if behavior were hardcoded |
| **Severity** | P2 |
| **Test file** | `SyntheticSmokeReportContractTests.swift` |
| **Test name** | `syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass` |
| **Evidence** | Among 23 per-smoke assertions: many assert frozen string IDs (e.g., `report.id == "m12-apple-silicon-performance-synthetic-smoke"`) and `sampleCount > 0`. The ID assertions test that a constant string equals itself. `> 0` accepts `1` — not plausible synthetic data. |
| **Why it matters** | `> 0` does not catch a smoke that ran one iteration instead of the expected count. Frozen IDs catch only a rename, not logic regressions. The high-value assertions (`verdict == .partial`, `syntheticEvidenceUsedForPass == false`) are valid. |
| **Better test** | Assert `sampleCount >= expectedSamples` where `expectedSamples` is derived from the smoke's declared frame count. Derive IDs from shared constants instead of inline strings. |
| **Risk of change** | Low behavioral risk; medium regression-detection risk for counter logic. |
| **Confidence** | High |

---

### C-TI-03 — `AudioRoutingAssumptionLedger` test validates documentation, not routing behavior

| Field | Value |
|-------|-------|
| **ID** | C-TI-03 |
| **Source audits** | TI-03, MC-06 |
| **Theme** | TEST_INTENT — tests that assert trivia; cross-cutting with C-MC-19 |
| **Severity** | P2 |
| **Test file** | `MultichannelTransportTests.swift` |
| **Test name** | `audioRoutingAssumptionLedgerClassifiesEveryFixedStereoAssumption` |
| **Evidence** | Asserts the ledger is non-empty, has no unclassified entries, and contains 11 specific IDs. The `assumption`, `action`, and `location` string fields are not checked. |
| **Why it matters** | If the audio router silently accepted incorrect channel configurations, this test would still pass as long as the ledger documentation remained complete. It provides false assurance about routing correctness. |
| **Better test** | `audioGraph_rejectsChannelCountViolatingStereoPairingAssumption` — feed an incorrect channel configuration and expect rejection. Keep the ledger completeness assertion separately with a documenting comment. |
| **Risk of change** | Low for adding the behavioral test alongside the current one. |
| **Confidence** | High |

---

### C-TI-04 — `udpPcmLocalhostSmokeRoundTripsPacket` proves no crash, not payload correctness

| Field | Value |
|-------|-------|
| **ID** | C-TI-04 |
| **Source audits** | TI-04 |
| **Theme** | TEST_INTENT — tests that assert trivia |
| **Severity** | P1 |
| **Test file** | `UdpPcmPacketTests.swift` |
| **Test name** | `udpPcmLocalhostSmokeRoundTripsPacket` |
| **Evidence** | Asserts `sequenceNumber == 1` and `senderHostTimeNanoseconds > 1`. Does not verify payload byte equality, multi-packet sequence tracking, or failure behavior. |
| **Why it matters** | A payload corruption bug (encoding or decoding changes audio bytes) would not be caught — the test only verifies that the smoke ran and returned a non-zero timestamp. Payload correctness is the primary contract for a PCM transport. |
| **Better test** | `udpPcmSmoke_receivedPayloadBytesMatchTransmittedPayload` — assert decoded audio bytes equal the transmitted test vector. Add multi-packet sequence (≥3 packets) and sequence-gap rejection. |
| **Risk of change** | Low — additive test alongside existing one. |
| **Confidence** | High |

---

### C-TI-05 — `VerdictValidationPolicy` prefix list asserted but not exercised end-to-end

| Field | Value |
|-------|-------|
| **ID** | C-TI-05 |
| **Source audits** | TI-05 |
| **Theme** | TEST_INTENT — tests that mirror implementation |
| **Severity** | P2 |
| **Test file** | `VerdictValidationPolicyTests.swift` |
| **Test name** | `verdictValidationPolicyCentralizesUniversalPassForbidPrefixes` |
| **Evidence** | Asserts the exact ordered list of 6 string prefixes. Does not verify that each prefix actually causes a PASS rejection on a real report. |
| **Better test** | For each prefix: construct a concrete report with an error whose name starts with that prefix; assert `validate()` throws the expected error. |
| **Risk of change** | Low — additive. |
| **Confidence** | Medium |

---

### C-TI-06 — `CodeLineBudgetTests` enforces LOC count, not behavioral intent

| Field | Value |
|-------|-------|
| **ID** | C-TI-06 |
| **Source audits** | TI-06 |
| **Theme** | TEST_INTENT — tests that assert trivia |
| **Severity** | P2 |
| **Test file** | `CodeLineBudgetTests.swift` |
| **Evidence** | Enforces file line-count budgets. No behavioral assertion. A file at exactly the budget limit full of dead code passes; a file one line over budget with a critical fix fails. |
| **Why it matters** | This creates team friction without behavioral protection. A core audio callback that begins allocating memory (a critical safety violation) is unaffected by these tests. |
| **Better approach** | Document these as process/hygiene tests with an explicit comment stating they are structural conventions, not behavioral contracts. Add an override mechanism for justified exceedances. |
| **Risk of change** | Low for adding documentation; would not remove existing tests. |
| **Confidence** | High |

---

### C-TI-07 — `rxBufferImpairmentSimulator` PRNG-fragile 9-decimal golden floats

| Field | Value |
|-------|-------|
| **ID** | C-TI-07 |
| **Source audits** | TI-07 |
| **Theme** | TEST_INTENT — tests that would pass if behavior were hardcoded |
| **Severity** | P2 |
| **Test file** | `RxBufferingTests.swift` |
| **Test name** | `rxBufferImpairmentSimulatorIsDeterministicAcrossRuns` |
| **Evidence** | Asserts 9-decimal-place golden float values (e.g., `abs(packetAges[0] - 145.0083667750024) < 0.000_000_001`). These are PRNG-algorithm-specific and may change on a new Swift version or platform. |
| **Why it matters** | The test fails for the wrong reason (compiler/PRNG update, not a logic regression). The golden values also assert nothing about whether `145.0083...` ns is meaningful for the simulation's purpose. |
| **Better test** | Run the simulator twice with the same seed; assert output equality. Separately assert that packet ages satisfy domain bounds (e.g., `>= 0 && < maxExpectedDelayNs`). |
| **Risk of change** | Low — additive replacement. |
| **Confidence** | High |

---

### C-TI-08 — `SourceNamingConventionTests` mixes doc linting with behavioral assertions

| Field | Value |
|-------|-------|
| **ID** | C-TI-08 |
| **Source audits** | TI-08 |
| **Theme** | TEST_INTENT — tests that mirror implementation |
| **Severity** | P2 |
| **Test file** | `SourceNamingConventionTests.swift` |
| **Test name** | `cleanRoomNamingPolicyAndTwoPeerPrototypeSurfaceStayDocumented` |
| **Evidence** | Mixed: `#expect(namingDoc.contains("*Helpers"))` (prose matching) alongside `#expect(commandNames.contains("direct-p2p-two-peer-prototype-report"))` (behavioral). |
| **Why it matters** | Doc reformatting without policy change breaks the test. The command-presence assertion is valid and meaningful; the markdown-prose matching is fragile and conveys no behavioral contract. |
| **Better approach** | Extract command-presence assertions to a dedicated test. Drop markdown-prose matching or move to a documentation lint step outside the test suite. |
| **Risk of change** | Low. |
| **Confidence** | High |

---

### C-TI-09 — MISSING: `DirectAudioMediaRouter` routing success and channel mapping

| Field | Value |
|-------|-------|
| **ID** | C-TI-09 |
| **Source audits** | TI-09 |
| **Theme** | TEST_INTENT — missing integration/runtime tests |
| **Severity** | P0 |
| **Test file** | `DirectAudioMediaRouterTests.swift` (only rejection path tested) |
| **Evidence** | The only test verifies that an unconfigured stream is rejected. No test for: correct routing of a configured stream, channel-offset math, multi-stream isolation, or buffer-full behavior. |
| **Why it matters** | A routing bug (stream A's packets sent to stream B's buffer) or a channel-offset math error (off-by-one in multichannel mapping) would cause silent audio corruption. No current test would catch either. |
| **Tests needed** | (1) `directAudioMediaRouter_routesPacketToRegisteredStreamAtCorrectChannelOffset` — verify payload at correct buffer offset. (2) `directAudioMediaRouter_multipleStreamsDontCorruptEachOther`. (3) Buffer-full behavior. |
| **Risk of testing** | Low — additive, no production code changes. |
| **Confidence** | High |

---

### C-TI-10 — MISSING: packet continuity across reconnection

| Field | Value |
|-------|-------|
| **ID** | C-TI-10 |
| **Source audits** | TI-10 |
| **Theme** | TEST_INTENT — missing state-transition tests |
| **Severity** | P1 |
| **Test file** | `ReconnectionTests.swift` |
| **Test name** | `reconnectAfterMediaSocketFailurePreservesAcceptedSessionConfiguration` |
| **Evidence** | Tests that `acceptedConfiguration` is preserved after a state transition. Does not test sequence number reset, RX buffer flush, or that pre-failure packets do not corrupt post-reconnect stream. |
| **Why it matters** | Incorrect reconnection behavior causes real-world audio glitches and stale state in the handoff layer. No current test catches sequence-tracking or buffer-state regressions after reconnect. |
| **Tests needed** | `reconnect_sequenceCounterResetsAndBufferFlushedAfterMediaSocketFailure`. Concurrent reconnect during active delivery. |
| **Risk of testing** | Medium — requires tracing through `PeerSessionRunner` and handoff layer. |
| **Confidence** | Medium |

---

### C-TI-11 — LoLa QuickConnect fallback: 4 substantive tests skip silently in CI

| Field | Value |
|-------|-------|
| **ID** | C-TI-11 |
| **Source audits** | TI-11 |
| **Theme** | TEST_INTENT — missing integration/runtime tests |
| **Severity** | P0 |
| **Test file** | `LoLaQuickConnectFallbackTests.swift` |
| **Test names** | `lolaUdpTransmitFallsBackToQuickConnectWhenStatusAckTimesOut` (and 3 others) |
| **Evidence** | `.enabled(if: secondaryLoopbackAliasAvailable())` — 4 tests skip silently in environments without `lo0:1`. Only the absence-check test runs in clean CI. The QuickConnect message exchange is never verified in CI. |
| **Why it matters** | QuickConnect fallback is a user-facing recovery path. If it breaks, users cannot establish sessions; CI will never catch it. The only test that runs verifies absence detection, not the fallback protocol. |
| **Tests needed** | `lolaQuickConnectFallback_messageSequenceIsCorrectWithoutRealInterface` — drive the fallback logic via an injected transport stub, no real socket required. Runs unconditionally in CI. |
| **Risk of testing** | Medium — requires transport injection if not already supported. |
| **Confidence** | High |

---

### C-TI-12 — MISSING: concurrent `RealtimeAudioPacketHandoff.receive()` + `dequeue()`

| Field | Value |
|-------|-------|
| **ID** | C-TI-12 |
| **Source audits** | TI-12 |
| **Theme** | TEST_INTENT — missing concurrency/timing tests |
| **Severity** | P0 |
| **Test file** | `RealtimeAudioPacketHandoffTests.swift` (no concurrent test) |
| **Evidence** | All existing tests invoke `receive()` and `dequeue()` sequentially on a single thread. Production usage: `receive()` from network thread; `dequeue()` from Core Audio render callback. This concurrent pattern is never tested. |
| **Why it matters** | Silent data corruption or crashes in the audio render callback have no user-visible error path. A threading regression in this layer is not caught by sequential tests. |
| **Tests needed** | `realtimeAudioPacketHandoff_concurrentReceiveAndDequeueProducesNoLostOrCorruptedBlocks` — use two `DispatchQueue` threads, verify payload equality and metric consistency. |
| **Risk of testing** | Low — pattern established by TI-14 (`SPSCAtomicRingTests` concurrent test). |
| **Confidence** | High |

---

### C-TI-13 — MISSING: `UdpPcmSequenceTracker` wrap-around at `UInt64.max` → `0`

| Field | Value |
|-------|-------|
| **ID** | C-TI-13 |
| **Source audits** | TI-13 |
| **Theme** | TEST_INTENT — missing edge/failure tests |
| **Severity** | P1 |
| **Test file** | `UdpPcmPacketTests.swift` |
| **Test name** | `udpPcmSequenceTrackerRejectsSkippedSequence` (existing) |
| **Evidence** | Implementation uses `packet.header.sequenceNumber &+ 1` (wrapping add). No test for `UInt64.max` → `0` wrap. |
| **Why it matters** | If the comparison branch uses non-wrapping arithmetic, `UInt64.max + 1` overflows silently in release builds. This would cause spurious sequence rejections after very long sessions. |
| **Tests needed** | `udpPcmSequenceTracker_acceptsWrapAroundFromMaxToZero` |
| **Risk of testing** | Low — additive. |
| **Confidence** | High |

---

## 6. Fail-Loud Findings

---

### C-FL-01 — `LoLaLiveTransmitErrors.errors.first` — second concurrent TX error silent

| Field | Value |
|-------|-------|
| **ID** | C-FL-01 |
| **Source audits** | FL-01 |
| **Theme** | FAIL_LOUD — partial failure reported as full success |
| **Severity** | P1 |
| **File** | `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaLive.swift` |
| **Symbol** | `LoLaLiveTransmitErrors`, `errors.first` at line 324 |
| **Evidence** | Two concurrent DispatchQueue blocks (audio TX + video TX) append errors to a shared `LoLaLiveTransmitErrors`. After `group.wait()`, only `errors.first` is thrown. If both loops fail, the second error is permanently discarded. |
| **Why it matters** | A bidirectional live run with two concurrent failures shows only one. Post-mortem diagnosis may be incomplete. Release evidence cannot rely on "one error thrown" meaning "only one thing broke." |
| **Suggested remediation** | Throw an aggregate error containing all errors. |
| **Test needed** | Inject failure into both dispatch queues simultaneously; assert both messages surface in the thrown error. |
| **Risk of change** | Low — callers that catch the error type will need to inspect multiple errors. |
| **Confidence** | High |

---

### C-FL-02 — `(try? recoverVideoFragments) ?? []` — recovery failure = "zero failures"

| Field | Value |
|-------|-------|
| **ID** | C-FL-02 |
| **Source audits** | FL-02 |
| **Theme** | FAIL_LOUD — false success state; skipped work hidden as success |
| **Severity** | P0 |
| **File** | `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibilityRunner.swift`, line 376 |
| **Symbol** | `countVideoFrameReassemblyFailures` |
| **Evidence** | `let videoFragments = (try? UltraGridCompatibility.recoverVideoFragments(from: videoPackets)) ?? []`. If `recoverVideoFragments` throws, fragments is `[]`; the for-loop iterates zero frames; `count = 0`. The report records "zero reassembly failures" when recovery itself failed entirely. |
| **Why it matters** | Zero reassembly failures is an evidence claim. The claim is false when recovery threw — no frames were examined. Any release or CI decision based on this count is using fabricated evidence. |
| **Suggested remediation** | Make the function `throws` and propagate the error; or record a distinct `recoveryFailed: Bool` field separate from the count. |
| **Test needed** | Inject a throwing `recoverVideoFragments`; assert the report records an error, not `0`. |
| **Risk of change** | Low for propagating the throw; callers would need updating. |
| **Confidence** | High |

---

### C-FL-03 — `terminateExternalConnectorProcessGroup`: SIGTERM/SIGKILL results discarded

| Field | Value |
|-------|-------|
| **ID** | C-FL-03 |
| **Source audits** | FL-03 |
| **Theme** | FAIL_LOUD — ignored return values |
| **Severity** | P1 |
| **File** | `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift`, lines 197, 199, 209 |
| **Symbol** | `terminateExternalConnectorProcessGroup` |
| **Evidence** | `_ = kill(-pg, SIGTERM)`, `_ = externalConnectorWaitForExit(...)`, `_ = kill(-pg, SIGKILL)` — all three signal and wait results are unconditionally discarded. The cleanup function (`cleanupExternalConnectorProcessGroup`) does check SIGKILL for a *second* kill, but this path's signals are not tracked. |
| **Why it matters** | If the process group is already dead (crashed before termination), signals fail silently. Post-run reports may say "completed" or "forced-kill" without this context. No user-visible indicator that termination signals failed. |
| **Suggested remediation** | Log or record `errno` from `kill()` calls inside `terminateExternalConnectorProcessGroup`. Return a richer status struct. |
| **Test needed** | Mock a dead process group; assert signal failure is recorded in the run result or logs. |
| **Risk of change** | Low — additive logging; struct shape change if result type is enriched. |
| **Confidence** | High |

---

### C-FL-04 — `graph.stop()` cleanup result discarded at callers and startup error path

| Field | Value |
|-------|-------|
| **ID** | C-FL-04 |
| **Source audits** | FL-04, FL-14 |
| **Theme** | FAIL_LOUD — ignored return values; hidden failure in cleanup |
| **Severity** | P1 |
| **File 1** | `Sources/OpenLolaCore/Connectors/LoLa/LoLaCoreAudioLiveBridge.swift`, line 139 |
| **File 2** | `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift`, line 316 |
| **File 3** | `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`, line 202 (startup error catch) |
| **Symbol** | `DirectPeerRealtimeAudioGraph.stop()` (`@discardableResult`); `startUnlocked()` error path `_ = stopUnlocked()` |
| **Evidence** | Both `LoLaCoreAudioLiveBridge` and `DirectPeerSessionAVSocketRunner` call `graph.stop()` / `audioGraph.stop()` as void expressions. The returned `DirectPeerRealtimeAudioGraphCleanupResult` (which contains `failures: [DirectPeerRealtimeAudioGraphCleanupFailure]`) is silently discarded. In the startup error path, `_ = stopUnlocked()` similarly discards the cleanup result. `@discardableResult` makes all three sites compile cleanly. |
| **Why it matters** | Core Audio `AudioDeviceStop`, `AudioDeviceDestroyIOProcID`, and sample rate/buffer size restore failures are invisible. A session that fails to restore the device's original sample rate leaves the device in a degraded state for subsequent runs and other apps. |
| **Suggested remediation** | Capture and log the cleanup result at both call sites. In the startup error path, log cleanup failures alongside the primary start error. Consider removing `@discardableResult` to force explicit handling. |
| **Test needed** | Mock `AudioDeviceStop` to return non-zero OSStatus; assert `CleanupResult` is non-empty and visible. |
| **Risk of change** | Low for logging; medium for removing `@discardableResult` (all callers would need to capture the result). |
| **Confidence** | High |

---

### C-FL-05 — `AudioDeviceDestroyIOProcID` / `AudioDeviceStop` OSStatus discarded in defer/error paths

| Field | Value |
|-------|-------|
| **ID** | C-FL-05 |
| **Source audits** | FL-05 |
| **Theme** | FAIL_LOUD — ignored return values |
| **Severity** | P1 |
| **File 1** | `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`, line 249 |
| **File 2** | `Sources/OpenLolaCore/Release/RecordingSessionLiveCapture.swift`, lines 95, 105 |
| **Symbol** | `makeAndStartIOProc` error path; `RecordingSessionLiveCapture` `defer` block |
| **Evidence** | `_ = AudioDeviceDestroyIOProcID(deviceID, createdIOProcID)` at line 249 in `DirectPeerRealtimeAudioGraph`. `_ = AudioDeviceDestroyIOProcID(...)` and `_ = AudioDeviceStop(...)` in `RecordingSessionLiveCapture`'s defer block. OSStatus values discarded. |
| **Why it matters** | A leaked IOProcID can affect device state for subsequent sessions and other Core Audio clients. Secondary cleanup failures after a primary error are completely invisible. |
| **Suggested remediation** | Log the cleanup `OSStatus` using `os_log`. In error paths, include cleanup failure context in the thrown error or a structured field. |
| **Test needed** | Core Audio mocking required to inject failing cleanup. |
| **Risk of change** | Low — additive logging; no behavioral change to primary flow. |
| **Confidence** | High |

---

### C-FL-06 — `.partial` conflates "ran without detected error" and "genuinely incomplete evidence"

| Field | Value |
|-------|-------|
| **ID** | C-FL-06 |
| **Source audits** | FL-06 |
| **Theme** | FAIL_LOUD — uncertainty hidden from users or callers |
| **Severity** | P2 |
| **File** | `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRunner.swift` (lines 95, 210); `UltraGridCompatibilityRunner.swift` (line 108); `JackTripCompatibility.swift` (line 621) |
| **Symbol** | `runtimeError == nil ? .partial : .fail` (three instances) |
| **Evidence** | `.partial` is assigned in all three connectors when `runtimeError == nil`. This makes `.partial` serve two distinct states: "ran cleanly but PASS not yet earned" vs. "ran, no detected error, unknown whether clean." |
| **Why it matters** | Report consumers correctly treat all `.partial` as non-passing. The loss is diagnostic: a clean 2-peer run and a run with silent socket failures look identical in the report. Debugging is harder and false confidence is possible when comparing partial runs. |
| **Suggested remediation** | Add `runtimeErrorFree: Bool` alongside `.partial`, or define sub-states within the report notes in a structured field. |
| **Test needed** | Assert that a run producing a runtime error and a run without one produce distinguishable report fields even when both return `.partial`. |
| **Risk of change** | Low for adding a field; medium for changing `MeasurementVerdict` if sub-states are added. |
| **Confidence** | Medium |

---

### C-FL-07 — LoLa TX with zero bytes sent returns `.partial`, not `.fail`

| Field | Value |
|-------|-------|
| **ID** | C-FL-07 |
| **Source audits** | FL-07 |
| **Theme** | FAIL_LOUD — false success state; missing processed/skipped/failed counts |
| **Severity** | P1 |
| **File** | `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMedia.swift`, lines 270–280 |
| **Symbol** | `transmitReport(configuration:socket:address:)`, `sentByteCounts.reduce(0, +)` |
| **Evidence** | Total sent bytes appears only in `notes` text. No guard downgrades the verdict when `sentBytesTotal == 0` after a non-dry-run. A run where all UDP `sendto` calls returned but no bytes were transmitted is indistinguishable from a successful partial transmit. |
| **Why it matters** | Zero-byte-sent runs look like normal partial runs. TX evidence is meaningless if "bytes actually sent" is not a structured field with a minimum threshold. |
| **Suggested remediation** | Add structured `sentBytesTotal: Int` field. Downgrade to `.fail` or add `runtimeError` when `sentBytesTotal == 0` on a real-link run. |
| **Test needed** | Inject a socket mock reporting zero sent bytes; assert verdict or structured field reflects the anomaly. |
| **Risk of change** | Low — additive field and conditional. |
| **Confidence** | Medium |

---

### C-FL-08 — UI cannot distinguish "corrupt evidence file" from "no evidence" or "file error" from "stale token"

| Field | Value |
|-------|-------|
| **ID** | C-FL-08 |
| **Source audits** | FL-08, FL-09 |
| **Theme** | FAIL_LOUD — optimistic UI/runtime status; uncertainty hidden from users |
| **Severity** | P1 |
| **File 1** | `Sources/open-lola-app/AppLatencyHeroMetrics.swift`, line 37 |
| **File 2** | `Sources/open-lola-app/AppRuntimeEvidenceScope.swift`, line 71 |
| **Symbol** | `AppLatencyHeroMetrics.load(from:sessionToken:)`; `sessionTokenMatches(_:evidenceURL:)` |
| **Evidence** | FL-08: `try? BoundedFileReader.data(atPath:)` + `try? ...decode(from:)` — both silently produce `nil` for absent file AND for corrupt/unreadable file. FL-09: `try? String(contentsOf: sessionTokenURL(...))` — permission error, sandbox restriction, or disk full all produce `nil`, which is then compared as "token doesn't match" (`nil != token` = `true`). Both result in "awaiting evidence" with no indication of the real problem. |
| **Why it matters** | A mid-write crash producing a corrupt report permanently blocks `hasValidatedRuntimeEvidence` while showing the user "awaiting evidence" — a state they cannot resolve by running again. A file permission issue looks identical to "run never produced evidence." |
| **Suggested remediation** | FL-08: Return `Result<AppLatencyHeroMetrics?, LoadError>` distinguishing absent from unreadable. FL-09: Return `TokenMatchResult` enum: `.match`, `.mismatch`, `.absent`, `.readError(Error)`. Surface errors in the UI. |
| **Test needed** | FL-08: Write a corrupt JSON file; assert UI distinguishes "corrupt" from "absent." FL-09: Mock file read to throw; assert `sessionTokenMatches` propagates a distinct error state. |
| **Risk of change** | Medium — callers of both functions need updating to handle richer return types. |
| **Confidence** | High |

---

### C-FL-09 — Release readiness file I/O error returns `exists: false`

| Field | Value |
|-------|-------|
| **ID** | C-FL-09 |
| **Source audits** | FL-10 |
| **Theme** | FAIL_LOUD — false success state |
| **Severity** | P1 |
| **File** | `Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift`, line 275 |
| **Symbol** | `readText(_:repositoryRoot:)` |
| **Evidence** | `guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return (false, "") }`. File missing, encoding error, and permission denied all return `(exists: false, contents: "")`. |
| **Why it matters** | A present-but-corrupt or present-but-unreadable required documentation file is reported as "missing." Releases may be blocked by a phantom missing-docs condition that is actually a file system issue. |
| **Suggested remediation** | Return `(exists: Bool, contents: String?, readError: Error?)`. Log or surface read errors separately from the existence check. |
| **Test needed** | Write a non-UTF-8 file to a required doc path; assert `readText` surfaces a read error rather than `(false, "")`. |
| **Risk of change** | Medium — callers need updating for the richer return type. |
| **Confidence** | High |

---

### C-FL-10 — Release manifest PASS gate is a substring match

| Field | Value |
|-------|-------|
| **ID** | C-FL-10 |
| **Source audits** | FL-11 |
| **Theme** | FAIL_LOUD — false success state in critical path |
| **Severity** | P0 |
| **File** | `Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift`, line 247 |
| **Symbol** | `publicReleaseApproval` requirement |
| **Evidence** | `ready: releaseManifest.exists && releaseManifest.contents.contains("Verdict: PASS")`. Any occurrence of the character sequence `"Verdict: PASS"` anywhere in the manifest file satisfies this gate — including a comment, a negation (`# Verdict: NOT PASS`), or an accidental occurrence. |
| **Why it matters** | The release approval gate is the final safeguard before a public release. A trivially bypassable substring match as the approval gate is a P0 false-success risk. |
| **Suggested remediation** | Parse the manifest with anchored regex (`^Verdict: PASS$` on its own line) or a structured format (YAML/TOML key-value). Reject any occurrence in a comment or prose context. |
| **Test needed** | (1) Manifest with `"Verdict: PASS"` in a comment → gate must NOT pass. (2) Conforming manifest with exactly `"Verdict: PASS"` on its own line → gate must pass. |
| **Risk of change** | Low — the fix is to tighten the check; no impact on a correctly formatted manifest. |
| **Confidence** | High |

---

### C-FL-11 — LoLa capture report: unexpected per-packet errors downgraded to notes

| Field | Value |
|-------|-------|
| **ID** | C-FL-11 |
| **Source audits** | FL-12 |
| **Theme** | FAIL_LOUD — partial failure reported as full success |
| **Severity** | P0 |
| **File** | `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityCaptureReport.swift`, lines 81–84 |
| **Symbol** | `LoLaCompatibilityCaptureReport.buildReport` catch block |
| **Evidence** | Only typed `LoLaCompatibilityCaptureDecodeError` cases influence the report verdict. Non-matching error types (any other exception during per-packet processing) are caught and appended to `notes` as unstructured strings. The verdict is not updated. Multiple such failures accumulate only as note text. |
| **Why it matters** | A systematic packet-processing regression that throws a new error type produces a `.partial` verdict with degraded `notes` text instead of a `.fail` verdict. Automated pipeline checks on `verdict` would pass while real failures exist only in notes. Any new code path that throws an unexpected error type silently downgrades to a note. |
| **Suggested remediation** | Track a count of unexpected packet errors as a structured field. Downgrade verdict to `.fail` if any are present. |
| **Test needed** | Inject a packet processing function that throws an unexpected error type; assert `verdict == .fail`. |
| **Risk of change** | Low — additive counter and conditional verdict. |
| **Confidence** | High |

---

### C-FL-12 — `closeOutputHandles()` return value discarded in `AppExecutionController`

| Field | Value |
|-------|-------|
| **ID** | C-FL-12 |
| **Source audits** | FL-13 |
| **Theme** | FAIL_LOUD — ignored return values |
| **Severity** | P2 |
| **File** | `Sources/open-lola-app/AppExecutionController.swift`, lines 552, 597, 794 |
| **Symbol** | `finished.closeOutputHandles()`, `process?.closeOutputHandles()` |
| **Evidence** | `ManagedProcess.closeOutputHandles()` returns `[ManagedProcessCleanupWarning]`. All three call sites discard the returned array. |
| **Why it matters** | Log file truncation or handle close failures are invisible. Users relying on stdout/stderr log paths for post-run debugging may see incomplete logs with no error context. |
| **Suggested remediation** | Log `ManagedProcessCleanupWarning` instances via `os_log`. |
| **Test needed** | Mock a failing file handle; assert cleanup warnings are logged. |
| **Risk of change** | Low — additive logging. |
| **Confidence** | Medium |

---

## 7. Duplicates Merged

The following source findings were merged into single consolidated IDs:

| Consolidated ID | Merged source IDs | Reason |
|----------------|-------------------|--------|
| C-MC-01 | OE-01, OE-04, OE-18, MC-03, MC-11 | All describe the same validation-helper duplication family: the protocol hierarchy, the empty sub-protocol, and the 40+ per-module private `require*` wrappers |
| C-MC-02 | MC-02, OE-10 | OE-10 describes `NativeAppShellSyntheticSmoke` specifically; MC-02 generalizes the pattern to all 30+ smoke namespaces |
| C-MC-04 | OE-02, OE-05 | OE-02 describes the struct over-structure; OE-05 describes the duplicate parser that the struct was supposed to replace — both are facets of the same parser complexity problem |
| C-MC-11 | OE-14, OE-15, MC-08, MC-16 | All describe the inventory-as-code anti-pattern in different Swift files |
| C-FL-04 | FL-04, FL-14 | Both describe `DirectPeerRealtimeAudioGraphCleanupResult` being discarded — FL-04 at the two external call sites, FL-14 at the internal startup error path |

The following source findings were **not** merged despite surface similarity:

| IDs not merged | Reason |
|----------------|--------|
| C-FL-08 (FL-08 + FL-09) | Merged because both produce the same UI symptom ("awaiting evidence") and require the same class of fix (richer return type for I/O failures). Different files, same root cause pattern. |
| C-MC-06 and C-TI-04 | Not merged: C-MC-06 is about the production checklist struct being self-attested; C-TI-04 is about the smoke test being too weak. Related but distinct issues in different layers. |
| C-MC-19 and C-TI-03 | Not merged: C-MC-19 is about the `AudioRoutingAssumptionLedger` being documentation-as-code (production concern); C-TI-03 is about the test protecting the documentation rather than the routing behavior (test concern). Both reference the same file but flag different problems. |

---

## 8. Conflicts Between Source Audits

### Conflict A: `CurrentEvidenceStatusMatrix` — speculative feature vs. required CI gate

- **OE-14** classifies `CurrentEvidenceStatusMatrix` as a speculative feature that should be moved to documentation, noting that "encoding project status as Swift means every editorial update requires a source change."
- **Uncertainty in OE and MC**: Both audits note they did not confirm whether `scripts/verify-release-readiness.sh` gates on the matrix CLI report being generated. If it is gated, removing the Swift literals would break CI.
- **Resolution**: Do not act on C-MC-11 for `CurrentEvidenceStatusMatrix` until `scripts/verify-release-readiness.sh` is inspected. If the CLI command is a CI gate, the simplification scope shrinks to "move data to a JSON file and have the CLI read from it" rather than "delete the matrix."

### Conflict B: `CapabilitySummary` historical instances — slop vs. intentional contract

- **OE-06** proposes deleting the three historical `m00Scaffold`, `m02ProtocolSession`, `m14ReleaseHardening` static instances.
- **TI-01** observes that `CapabilitySummaryTests.swift` tests these instances by name, implying they may be intentional contracts. The audit does not resolve whether the tests exist to protect a behavioral contract or simply as version snapshots.
- **Resolution**: Do not delete historical instances without confirming intent with the project maintainer. If the intent is to freeze milestone-version behavior as a compatibility contract, document that intent in code comments. If the intent is documentation, move to CHANGELOG.

### Conflict C: `RealtimeAudioCallbackSafetyChecklist` — false confidence vs. validation gate

- **MC-04** argues the checklist creates false confidence because all fields are set to `true` by developers and no test exercises `firstViolation != nil`.
- **TI-15** identifies `realtimeAudioEngineRejectsInvalidReportEvidence` as "one of the most thorough behavioral tests in the suite" and recommends preserving it. That test includes `safety.noAllocationInCallback = false` → `passWithCallbackSafetyViolation("noAllocationInCallback")`.
- **Apparent conflict**: TI-15 says the safety checklist validation IS exercised in tests; MC-04 says it is NOT.
- **Resolution**: TI-15's referenced test sets one field to `false` manually in the test itself — this is the test author setting the field, not a production code path. MC-04's point stands: no production call site would ever set a field to `false`. The test confirms the validation gate catches a `false` field when manually injected. The gap MC-04 identifies is that production reports always use `true`. Both findings are correct; they observe different layers. C-MC-06 preserves MC-04's concern; C-TI-04 notes the smoke test weakness.

### Conflict D: Test-intent audit flags TI-15 as high-value; MC-04 flags MC-04 as high-risk

- TI-15 (PRESERVE): `realtimeAudioEngineRejectsInvalidReportEvidence` is the reference pattern for mutation tests.
- C-MC-06 (P1): The checklist it guards is self-attested.
- **Resolution**: Both are correct simultaneously. The test is well-structured for what it tests. The production code it protects is self-attested. The test should be preserved AND the self-attestation nature of the checklist should be documented. No contradiction to resolve.

---

## 9. Highest-Risk Issues

P0 and P1 issues ordered by impact:

| Rank | ID | Severity | Title | Impact |
|------|----|----------|-------|--------|
| 1 | C-FL-10 | P0 | Release manifest PASS gate is a substring match | Any occurrence of `"Verdict: PASS"` in a comment passes the release approval gate |
| 2 | C-TI-09 | P0 | MISSING: `DirectAudioMediaRouter` routing and channel mapping tests | Audio data silently routed to wrong buffer with no test catching it |
| 3 | C-TI-12 | P0 | MISSING: concurrent `RealtimeAudioPacketHandoff` test | Race condition or data corruption in audio render callback uncaught |
| 4 | C-TI-11 | P0 | QuickConnect fallback tests skip silently in CI | User-facing recovery path regression invisible in CI |
| 5 | C-FL-02 | P0 | Video reassembly recovery failure = "zero failures" | Evidence report falsely claims clean video reassembly |
| 6 | C-FL-11 | P0 | LoLa capture unexpected errors → notes not verdict | Systematic regression produces `.partial` verdict while real failures hide in notes |
| 7 | C-MC-06 | P1 | `RealtimeAudioCallbackSafetyChecklist` self-attested | Safety gate trivially bypassed by writing `true`; no runtime instrumentation |
| 8 | C-MC-07 | P1 | Fabricated numeric metrics in synthetic smokes | Consumers not checking `runMode` process fake latency numbers as real measurements |
| 9 | C-FL-04 | P1 | Core Audio graph cleanup results discarded | Device left in degraded state; subsequent runs and other apps affected |
| 10 | C-FL-08 | P1 | UI cannot distinguish corrupt report from absent evidence | User cannot diagnose damaged evidence vs. missing evidence |
| 11 | C-FL-09 | P1 | Release readiness file I/O error = `exists: false` | Required documentation flagged as absent when actually unreadable |
| 12 | C-FL-07 | P1 | LoLa TX zero bytes sent = `.partial` | Zero-transmission and successful partial transmit are indistinguishable |
| 13 | C-TI-04 | P1 | UDP PCM smoke proves no crash, not payload correctness | Payload corruption undetected |
| 14 | C-TI-10 | P1 | Missing reconnection continuity tests | Reconnect causes silent stream corruption |
| 15 | C-TI-13 | P1 | `UdpPcmSequenceTracker` wrap-around untested | Overflow after long sessions undetected |

---

## 10. Low-Risk Simplification Candidates

These have no public API impact, one or two call sites, and can be inlined, deleted, or moved
without any test changes:

| ID | Action | File | Risk |
|----|--------|------|------|
| C-MC-12 | DELETE `JSONReportCoder` | `PrettyJSONCodable.swift` | None — 3 trivial inlines |
| C-MC-13 | DELETE `UltraGridMediaFormatRegistry.swift` | `UltraGridCompatibility.swift` | None — 1 call site |
| C-MC-17 | DELETE `CoreAudioFallbackIdentityCache` | `CoreAudioInventoryReader.swift` | None — deterministic string |
| C-MC-10 | INLINE `DebugTraceJSONEncoder`, `DebugTraceTimestampFormatter`, `DebugTraceEncodingFailureLine` | `DebugTrace.swift` | None — internal only |
| C-MC-21 | MOVE `LolaBaseline*` types | `DriftPlcFixedTargetCertification.swift` → new file | None — file move |
| C-MC-22 | MOVE `UdpPcmV2PacketHeader` | `UdpPcmV2FragmentPlanner.swift` → `UdpPcmV2Packet.swift` | None — file move |
| C-MC-04 (OE-05) | REPLACE `NativeAppShell` duplicate parser | One call to `KeyValueArgumentParser.parseValues` | Low |
| C-MC-20 | DELETE `RealtimeAudioBlockRing` if confirmed dead | `RealtimeAudioBuffers.swift` | None if no callers |

Verification for all of the above: `swift test --no-parallel` after each change.

---

## 11. Suggested Remediation Slices

Ordered by severity (P0 → P1 → P2 → P3), grouped by cohesion.

---

### Slice S-01 — Fix Release Approval Gate

| Field | Value |
|-------|-------|
| **Slice ID** | S-01 |
| **Findings addressed** | C-FL-10, C-FL-09 |
| **Severity** | P0 / P1 |
| **Title** | Replace substring PASS check; fix release readiness file read failure |
| **Minimal strategy** | (1) In `OpenSourceReleaseReadiness.swift`: replace `.contains("Verdict: PASS")` with an anchored line check (`NSRegularExpression` or `components(separatedBy: "\n").contains("Verdict: PASS")`). (2) Change `readText` to return a three-state result: absent, readable, or read-error — surface the error separately from `exists`. |
| **Files likely affected** | `Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift` |
| **Tests needed** | (1) Manifest with PASS in a comment → gate does not pass. (2) Conforming manifest → gate passes. (3) Non-UTF-8 file → `readText` surfaces error, not `exists: false`. |
| **Verification** | `swift test --filter OpenSourceReleaseReadinessTests` |
| **Risk level** | Low — the only change is tightening the check; correct manifests are unaffected. |
| **Definition of Done** | `OpenSourceReleaseReadiness` tests include the three test cases above and pass. |

---

### Slice S-02 — Fix Evidence Integrity: Video and Capture Reports

| Field | Value |
|-------|-------|
| **Slice ID** | S-02 |
| **Findings addressed** | C-FL-02, C-FL-11 |
| **Severity** | P0 |
| **Title** | Propagate video reassembly recovery errors; count unexpected capture errors in verdict |
| **Minimal strategy** | (1) In `UltraGridCompatibilityRunner.countVideoFrameReassemblyFailures`: make the function `throws` or add a `recoveryFailed: Bool` output alongside the count. (2) In `LoLaCompatibilityCaptureReport.buildReport`: add an `unexpectedErrorCount` counter; downgrade verdict to `.fail` when `unexpectedErrorCount > 0`. |
| **Files likely affected** | `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibilityRunner.swift`; `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityCaptureReport.swift` |
| **Tests needed** | (1) Inject throwing `recoverVideoFragments`; assert report records an error, not `0`. (2) Inject unexpected error type in per-packet processing; assert `verdict == .fail`. |
| **Verification** | `swift test --filter UltraGridCompatibilityRunnerTests` and `swift test --filter LoLaCompatibilityCaptureReportTests` |
| **Risk level** | Low — additive error propagation. |
| **Definition of Done** | Both tests above pass. No existing tests broken. |

---

### Slice S-03 — Add Missing Audio Router and Concurrency Tests

| Field | Value |
|-------|-------|
| **Slice ID** | S-03 |
| **Findings addressed** | C-TI-09, C-TI-12 |
| **Severity** | P0 |
| **Title** | Add `DirectAudioMediaRouter` routing tests; add concurrent `RealtimeAudioPacketHandoff` test |
| **Minimal strategy** | (1) In `DirectAudioMediaRouterTests.swift`: add routing success test (packet for stream A arrives at A's buffer), channel-offset test (4-channel fragment with `channelOffset == 2` writes to positions 2–5), and multi-stream isolation test. (2) In `RealtimeAudioPacketHandoffTests.swift`: add concurrent `receive()` + `dequeue()` test using two `DispatchQueue` threads with payload equality verification, following the pattern in `SPSCAtomicRingTests.swift`. |
| **Files likely affected** | `Tests/OpenLolaCoreTests/DirectAudioMediaRouterTests.swift`; `Tests/OpenLolaCoreTests/RealtimeAudioPacketHandoffTests.swift` |
| **Tests needed** | The tests are the deliverable. |
| **Verification** | `swift test --filter DirectAudioMediaRouterTests` and `swift test --filter RealtimeAudioPacketHandoffTests` |
| **Risk level** | None — additive tests only. |
| **Definition of Done** | New tests exist, pass, and would fail if routing logic or concurrent safety were broken. |

---

### Slice S-04 — Fix LoLa QuickConnect Fallback CI Coverage

| Field | Value |
|-------|-------|
| **Slice ID** | S-04 |
| **Findings addressed** | C-TI-11 |
| **Severity** | P0 |
| **Title** | Add unconditional transport-stub test for QuickConnect fallback message sequence |
| **Minimal strategy** | Add a new test in `LoLaQuickConnectFallbackTests.swift` that drives the fallback logic via an injected transport stub (no real socket). Test must run unconditionally (no `.enabled(if:)` guard). Verify the QuickConnect message exchange sequence, timeout behavior, and retry logic. |
| **Files likely affected** | `Tests/OpenLolaCoreTests/LoLaQuickConnectFallbackTests.swift` |
| **Tests needed** | The test is the deliverable. Requires confirming whether the fallback path accepts transport injection. |
| **Verification** | `swift test --filter lolaQuickConnectFallback` — must run and pass in a clean environment without `lo0:1`. |
| **Risk level** | Medium — may require transport injection infrastructure if not already present. |
| **Definition of Done** | Test runs in CI without environment prerequisites and would fail if the QuickConnect message sequence changed. |

---

### Slice S-05 — Fix Core Audio Cleanup Error Propagation

| Field | Value |
|-------|-------|
| **Slice ID** | S-05 |
| **Findings addressed** | C-FL-04, C-FL-05 |
| **Severity** | P1 |
| **Title** | Capture and log Core Audio cleanup results at all discard sites |
| **Minimal strategy** | (1) In `LoLaCoreAudioLiveBridge` and `DirectPeerSessionAVSocketRunner`: capture `graph.stop()` result; if `result.failures` is non-empty, log via `os_log`. (2) In `DirectPeerRealtimeAudioGraph.startUnlocked` error path: log cleanup result alongside the primary error. (3) In `RecordingSessionLiveCapture` defer block: log `AudioDeviceDestroyIOProcID` and `AudioDeviceStop` `OSStatus` when non-zero. |
| **Files likely affected** | `LoLaCoreAudioLiveBridge.swift`; `DirectPeerSessionAVSocketRunner.swift`; `DirectPeerRealtimeAudioGraph.swift`; `RecordingSessionLiveCapture.swift` |
| **Tests needed** | Core Audio mocking required; integration tests with mocked `AudioDeviceStop` returning non-zero OSStatus. |
| **Verification** | Code review of all four files; `swift build` to confirm compilation. |
| **Risk level** | Low — additive logging; no behavioral change to primary path. |
| **Definition of Done** | All four call sites capture and log cleanup failures. |

---

### Slice S-06 — Fix UI Evidence State Disambiguation

| Field | Value |
|-------|-------|
| **Slice ID** | S-06 |
| **Findings addressed** | C-FL-08 |
| **Severity** | P1 |
| **Title** | Distinguish corrupt/unreadable evidence from absent evidence; distinguish I/O error from stale session token |
| **Minimal strategy** | (1) `AppLatencyHeroMetrics.load`: return `Result<AppLatencyHeroMetrics?, LoadError>` where `LoadError` distinguishes absent file from I/O error from decode error. Surface in UI via `AppSessionStateBanner`. (2) `sessionTokenMatches`: return `TokenMatchResult` enum (`.match`, `.mismatch`, `.absent`, `.readError(Error)`). Update `hasValidatedRuntimeEvidence` accordingly. |
| **Files likely affected** | `Sources/open-lola-app/AppLatencyHeroMetrics.swift`; `Sources/open-lola-app/AppRuntimeEvidenceScope.swift`; `Sources/open-lola-app/AppSessionStateBanner.swift` |
| **Tests needed** | Corrupt JSON file → assert UI shows "evidence damaged, not absent." File permission error → assert `sessionTokenMatches` returns `.readError`, not `.mismatch`. |
| **Verification** | `swift test --filter AppLatencyHeroMetricsTests`; `swift test --filter AppRuntimeEvidenceScopeTests` |
| **Risk level** | Medium — callers of both functions need updating. |
| **Definition of Done** | UI banner shows a distinct message for "evidence file is corrupt" vs. "no evidence produced." |

---

### Slice S-07 — Add Missing Sequence and Reconnection Tests

| Field | Value |
|-------|-------|
| **Slice ID** | S-07 |
| **Findings addressed** | C-TI-10, C-TI-13 |
| **Severity** | P1 |
| **Title** | Add `UdpPcmSequenceTracker` wrap-around test; add reconnection continuity tests |
| **Minimal strategy** | (1) `UdpPcmPacketTests.swift`: add `udpPcmSequenceTracker_acceptsWrapAroundFromMaxToZero`. (2) `ReconnectionTests.swift`: add `reconnect_sequenceCounterResetsAndBufferFlushedAfterMediaSocketFailure` covering sequence number reset and RX buffer flush. |
| **Files likely affected** | `Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift`; `Tests/OpenLolaCoreTests/ReconnectionTests.swift` |
| **Tests needed** | The tests are the deliverable. |
| **Verification** | `swift test --filter udpPcmSequenceTracker` and `swift test --filter ReconnectionTests` |
| **Risk level** | Low for sequence tracker (additive). Medium for reconnection (requires tracing through `PeerSessionRunner`). |
| **Definition of Done** | Both new tests pass and would fail if the guarded behaviors changed. |

---

### Slice S-08 — Document / Fix Synthetic Smoke Metrics and Safety Checklist

| Field | Value |
|-------|-------|
| **Slice ID** | S-08 |
| **Findings addressed** | C-MC-06, C-MC-07 |
| **Severity** | P1 |
| **Title** | Replace fabricated numeric metrics with sentinels; document safety checklist as self-attestation |
| **Minimal strategy** | (1) Replace plausible numeric fields in `*SyntheticSmoke` reports with sentinel constants (e.g., `SyntheticPlaceholder.latencyMicroseconds = 0`). (2) Add a code comment on `RealtimeAudioCallbackSafetyChecklist` stating it is a self-attestation, not an instrumented measurement. Add a test that sets one field to `false` and confirms `validate()` rejects the report. |
| **Files likely affected** | All `*SyntheticSmoke.swift` files; `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift` |
| **Tests needed** | (1) `validate()` rejects a report with one safety field set to `false`. (2) Confirm `validate()` does not enforce minimum numeric ranges that would reject sentinel values. |
| **Verification** | `swift test --filter SyntheticSmokeReportContractTests`; `swift test --filter RealtimeAudioEngineTests` |
| **Risk level** | Medium — tests asserting exact synthetic numeric values need updating. |
| **Definition of Done** | No `*SyntheticSmoke` report contains plausible-looking non-sentinel numeric metrics. Safety checklist is documented as self-attested. |

---

### Slice S-09 — Consolidate RunMode Enums

| Field | Value |
|-------|-------|
| **Slice ID** | S-09 |
| **Findings addressed** | C-MC-03 |
| **Severity** | P2 |
| **Title** | Replace 10 identical `*RunMode` enums with one shared `ReportRunMode` |
| **Minimal strategy** | Add `public enum ReportRunMode: String, Codable, Equatable, Sendable { case synthetic; case measured }` to `OpenLolaContracts`. Update 10 report structs to use `ReportRunMode`. Leave the 3 enums with extra cases unchanged. |
| **Files likely affected** | `OpenLolaContracts` (new enum); 10 report struct files; tests deserializing these reports. |
| **Tests needed** | JSON round-trip for all 10 affected report types. `swift test --no-parallel`. |
| **Verification** | `grep -rn "RunMode: String, Codable, Equatable, Sendable" Sources/` — should return only the 3 non-identical ones after. |
| **Risk level** | Medium — breaking change for all 10 report struct field types. |
| **Definition of Done** | Only 3 `*RunMode` enums remain; all others use `ReportRunMode`. All tests pass. |

---

### Slice S-10 — Consolidate Validation Helpers

| Field | Value |
|-------|-------|
| **Slice ID** | S-10 |
| **Findings addressed** | C-MC-01 |
| **Severity** | P2 |
| **Title** | Remove empty `ReportValidationProtocol`; consolidate `require*` helpers |
| **Minimal strategy** | Phase 1: Delete `ReportValidationProtocol`; replace all 5 conformances with `ReportPrimitiveValidating`. Phase 2 (optional): Remove per-file private `require*` wrappers and call `ValidationPrimitives` directly, or accept per-file 2-liners and delete the protocol hierarchy entirely. |
| **Files likely affected** | `ValidationPrimitives.swift`; 5 files conforming to `ReportValidationProtocol`; 10+ files with private helpers. |
| **Tests needed** | `swift test --no-parallel` after each phase. |
| **Verification** | `grep -rn "ReportValidationProtocol" Sources/` → zero results. |
| **Risk level** | Medium — every conforming enum needs updating; build will fail until resolved. |
| **Definition of Done** | `ReportValidationProtocol` does not exist. All tests pass. |

---

### Slice S-11 — Rewrite Weak Snapshot Tests

| Field | Value |
|-------|-------|
| **Slice ID** | S-11 |
| **Findings addressed** | C-TI-01, C-TI-07 |
| **Severity** | P2 |
| **Title** | Replace milestone version snapshot; replace PRNG-fragile golden float assertions |
| **Minimal strategy** | (1) `CapabilitySummaryTests`: replace `summary == .m15PackagingFieldTest` with `summary.version == CapabilitySummary.current.version` (or equivalent symbolic comparison). (2) `RxBufferingTests`: replace golden float assertions with run-twice-same-seed equality check; add domain bounds assertion. |
| **Files likely affected** | `Tests/OpenLolaCoreTests/CapabilitySummaryTests.swift`; `Tests/OpenLolaCoreTests/RxBufferingTests.swift` |
| **Tests needed** | The replacements are the deliverable. |
| **Verification** | `swift test --filter CapabilitySummaryTests`; `swift test --filter RxBufferingTests` |
| **Risk level** | Low — the snapshot test breaks on every milestone advance anyway. |
| **Definition of Done** | `CapabilitySummary` test uses symbolic comparison. `rxBufferImpairmentSimulator` test uses equality-of-two-runs. Both pass. |

---

### Slice S-12 — Delete / Inline Low-Risk Single-Use Abstractions

| Field | Value |
|-------|-------|
| **Slice ID** | S-12 |
| **Findings addressed** | C-MC-12, C-MC-13, C-MC-17, C-MC-10 |
| **Severity** | P3 |
| **Title** | Delete `JSONReportCoder`, `UltraGridMediaFormatRegistry`, `CoreAudioFallbackIdentityCache`; inline `DebugTrace` wrappers |
| **Minimal strategy** | Four independent no-risk inlines/deletes. Each is a build-check-only change. |
| **Files likely affected** | `PrettyJSONCodable.swift`; `UltraGridMediaFormatRegistry.swift` (deleted); `CoreAudioInventoryReader.swift`; `DebugTrace.swift` |
| **Tests needed** | `swift build` only. |
| **Verification** | `swift test --no-parallel` |
| **Risk level** | None. |
| **Definition of Done** | All four files/symbols removed; build and tests pass. |

---

## 12. Verification Strategy

### Baseline (run before any change)

```bash
swift build
swift test --no-parallel
```

### Per-slice verification

| Slice | Command |
|-------|---------|
| S-01 | `swift test --filter OpenSourceReleaseReadinessTests` |
| S-02 | `swift test --filter UltraGridCompatibilityRunnerTests && swift test --filter LoLaCompatibilityCaptureReportTests` |
| S-03 | `swift test --filter DirectAudioMediaRouterTests && swift test --filter RealtimeAudioPacketHandoffTests` |
| S-04 | `swift test --filter lolaQuickConnectFallback` (must run without `lo0:1`) |
| S-05 | `swift build` + code review of 4 files |
| S-06 | `swift test --filter AppLatencyHeroMetricsTests && swift test --filter AppRuntimeEvidenceScopeTests` |
| S-07 | `swift test --filter udpPcmSequenceTracker && swift test --filter ReconnectionTests` |
| S-08 | `swift test --filter SyntheticSmokeReportContractTests && swift test --filter RealtimeAudioEngineTests` |
| S-09 | `swift test --no-parallel` (JSON round-trip for all 10 report types) |
| S-10 | `swift test --no-parallel` (after each phase) |
| S-11 | `swift test --filter CapabilitySummaryTests && swift test --filter RxBufferingTests` |
| S-12 | `swift build` |

### Full regression after any structural change

```bash
swift test --no-parallel
bash scripts/verify-docs.sh
bash scripts/verify-release-readiness.sh
```

### Preserved high-value tests (do not degrade)

These tests from the source audit are confirmed as high-value and must not be weakened:

| Test | Why preserved |
|------|---------------|
| `spscAtomicRingIsSafeUnderConcurrentProducerConsumer` (TI-14) | Only guard against threading regressions in ring buffers |
| `directPeerAudioPayloadRingIsSafeUnderConcurrentProducerConsumer` (TI-14) | Concurrent ring; verifies `ownerViolationCount == 0` |
| `realtimeAudioEngineRejectsInvalidReportEvidence` (TI-15) | 20+ typed-error mutations; reference pattern for validation tests |
| `udpPcmPacketRoundTripsAgainstHexFixture` + malformed rejection tests (TI-16) | Wire-format regression guard with byte-level assertions |
| `syntheticSmokeReportsRejectFalsePassMutations` (TI-18) | Sole guard preventing synthetic smoke from being promoted to runtime PASS |
| `commandInventoryCLIBinaryOutputsCommandListAndProducesExpectedExitCode` (TI-19) | Invokes compiled binary; catches build-level regressions |
| `lolaMediaReceiveAcceptsEphemeralSourcePortWhenDestinationPortMatches` + sibling tests (TI-21) | Real-socket LoLa protocol compatibility tests |

---

## 13. Remaining Uncertainty

The following items were not fully resolved by any of the four source audits. They are preserved
here to prevent future investigation from starting from zero.

**1. `CurrentEvidenceStatusMatrix` CI gate status** (C-MC-11)
Whether `scripts/verify-release-readiness.sh` or any other CI script invokes the `current-evidence-status-matrix` CLI command was not verified. If it is a gate, the simplification approach for C-MC-11 changes (from "delete Swift code" to "move data to a JSON file"). **Action before acting on C-MC-11**: `grep -rn "current-evidence-status-matrix\|fixture-smoke-matrix\|command-inventory" scripts/`.

**2. `DebugTraceFieldPolicy.allowing` callers** (C-MC-14)
Whether any test or production caller constructs a non-default `DebugTraceFieldPolicy` via `.allowing(_:)` was not fully confirmed. If no callers: C-MC-14 is a confirmed simplification. **Action before acting**: `grep -rn "DebugTraceFieldPolicy\|\.allowing(" Sources/ Tests/`.

**3. `RealtimeAudioBlockRing` callers** (C-MC-20)
Whether `RealtimeAudioBlockRing` has any callers was not fully confirmed in either source audit. **Action before acting**: `grep -rn "RealtimeAudioBlockRing(" Sources/ Tests/`. If zero results: delete.

**4. `ExternalConnectorSessionRunner` vs `Runtime` split** (C-MC-23)
The distinction between `Runner` and `Runtime` in the connector subsystem was not read. Before any merger or simplification: read both files, map their public APIs, and confirm whether the lifecycle split is justified.

**5. `CapabilitySummary` historical instance intent** (C-MC-24, Conflict B)
Whether the three historical static instances (`m00Scaffold`, `m02ProtocolSession`, `m14ReleaseHardening`) are intentional compatibility contracts or documentation slop was not confirmed. Do not delete without confirming intent.

**6. NAT keepalive JSON decode silences**
`NatFriendlyRouteRunner.swift:91` and `NatRendezvousRelayRunners.swift:144,216` use `try? JSONDecoder().decode(...)` silently ignoring malformed keepalive/rendezvous messages. In a UDP context, dropping malformed packets may be intentional. Whether a systematic decode regression (e.g., format change) is detectable in run metrics was not fully traced. Confidence: low that this is a real risk.

**7. `LoLaCompatibilityUdpMedia` zero-datagrams-received path**
Whether receiving zero datagrams without a timeout produces `.fail` or `.partial` was not fully exercised. The timeout path uses `.fail`; the zero-datagrams-but-no-timeout case may produce `.partial` silently. Related to C-FL-07.

**8. `DirectAudioMediaRouter` channel mapping in higher-level tests**
TI-09 is based on test-file inspection only. If channel mapping is exercised transitively through higher-level integration tests (e.g., `PeerSessionAVSupportTests`), the risk from C-TI-09 is lower. Full integration test map not confirmed.

**9. `LoLaQuickConnectFallback` transport injection feasibility**
Whether the fallback path in `LoLaQuickConnectFallback` accepts an injected transport (required for S-04) depends on its current architecture. If it uses a concrete socket directly, S-04 requires a modest refactor to inject a stub. This was not confirmed from test-file inspection alone.

**10. App UI state "no fake status text" exhaustive check**
`AppShellBehaviorTests.swift` and `AppShellSlice05Tests.swift` were not fully audited against the "no fake `connected`, `streaming`, `healthy`, or `100%` status text" requirement. The `AppSessionState.live` derivation was confirmed as correctly gated (FL-15), but full UI text coverage is not confirmed.
