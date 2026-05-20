# Over-Engineering Index

Audit of over-engineering, unnecessary abstraction, speculative features, boilerplate, and code
more complex than the problem requires.

**Scope:** `Sources/` (Swift), `Tests/` (Swift).
**Date:** 2026-05-19
**Rules:** No production code changed. No deletions. This file is the only output.

---

## Table of Contents

1. [Findings](#findings)
2. [Highest-Impact Simplification Targets](#highest-impact-simplification-targets)
3. [Low-Risk Deletion / Inlining Candidates](#low-risk-deletion--inlining-candidates)
4. [Risky Areas That Need More Proof Before Simplification](#risky-areas-that-need-more-proof-before-simplification)
5. [Files That Are Simple Enough — Do Not Touch](#files-that-are-simple-enough--do-not-touch)
6. [Remaining Uncertainty](#remaining-uncertainty)

---

## Findings

---

### OE-01

| Field | Value |
|---|---|
| **ID** | OE-01 |
| **File** | `Sources/OpenLolaCore/Core/ValidationPrimitives.swift` |
| **Symbol** | `ValidationPrimitives`, `ReportPrimitiveValidating`, `ReportValidationProtocol`, `ValidationEmptyFieldError`, `ValidationEmptyListError`, `ValidationMalformedFieldError`, `ValidationNonPositiveFieldError`, `ValidationNegativeFieldError`, `ValidationNonFiniteFieldError`, `ValidationPercentOutOfRangeFieldError` |
| **Category** | OVERENGINEERING |
| **Evidence** | 364 lines. Six protocols for error-factory dispatch. A two-level protocol hierarchy (`ReportPrimitiveValidating` → `ReportValidationProtocol`). Twenty+ extension methods on the protocols. Every validator enum in the codebase must declare conformance to whichever subset of the six protocols applies to its error type, then gets the `static func requireNonEmpty`, `requirePositive`, etc. methods injected. The underlying primitives (`ValidationPrimitives.requireNonEmpty`, etc.) are free-standing functions that do a single `if value.isEmpty { throw }`. |
| **Why more complex than necessary** | The protocol dispatch machinery exists purely so each module can call `requireNonEmpty(x, "field")` without needing to write the error constructor twice. The same goal is served by passing the error factory as a closure argument or by calling `ValidationPrimitives` directly. The indirection adds 6 protocols, 1 unused protocol extension level (`ReportValidationProtocol` adds nothing over `ReportPrimitiveValidating`), and requires every consumer enum to declare multi-protocol conformance. |
| **Simpler alternative** | Remove the protocol hierarchy. Each validator file calls `ValidationPrimitives.requireNonEmpty(value, field: field, empty: ValidationError.emptyField)` directly, or each adopts a two-line `typealias V = ValidationError` plus a local `require*` wrapper. Alternatively, keep one protocol with an associated `ValidationError` and no per-category sub-protocols. |
| **What could break if simplified** | Every file that declares `enum FooValidator: ReportPrimitiveValidating` would need to be updated. Tests that exercise validator enums would break until updated. |
| **Verification needed** | Confirm `ReportValidationProtocol` is never used directly as an existential or generic constraint beyond the two files that declare conformance to it. |
| **Confidence** | high |

---

### OE-02

| Field | Value |
|---|---|
| **ID** | OE-02 |
| **File** | `Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift` |
| **Symbol** | `KeyValueArgumentParser` |
| **Category** | OVERENGINEERING |
| **Evidence** | 202 lines. A struct with an initializer + `parse(_:mapError:)` instance method, plus a static `parseValues` convenience wrapper that constructs the struct and calls the instance method (lines 60-81). Also four static helpers (`requiredString`, `optionalInteger`, `requiredPositiveInteger`, `optionalPositiveInteger`, `optionalNonNegativeInteger`, `optionalNonNegativeDouble`, `boolean`) — all of them just wrappers around one-to-three lines of guard/throw logic. |
| **Why more complex than necessary** | The struct adds no state beyond `allowedKeys` and `allowsDashPrefixedValues`. The instance method only exists to avoid passing those two values as arguments on every call. The static `parseValues` wrapper constructs the struct and forwards immediately — it is a 16-line function that could be removed in favor of calling `KeyValueArgumentParser(...).parse(...)`. The seven static helper functions each wrap one `guard let / guard >0 / guard >=0` check and are called in fewer than 5 locations. |
| **Simpler alternative** | Keep the parser as a pure free function `parseKeyValueArguments(_:allowed:allowsDashPrefixed:mapError:) -> [String:String]`. Remove the struct. Keep the static helpers as free functions in a file-scope extension or inline the 1-3 line bodies at call sites. |
| **What could break if simplified** | Call sites that currently `try KeyValueArgumentParser.parseValues(...)` would change syntax. Tests that target the struct would break until updated. |
| **Verification needed** | Grep for `KeyValueArgumentParser(` to confirm no subclassing or protocol conformance. |
| **Confidence** | high |

---

### OE-03

| Field | Value |
|---|---|
| **ID** | OE-03 |
| **File** | `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift` (lines 405-460) and `Sources/OpenLolaCore/Support/BoundedPipeCapture.swift` |
| **Symbol** | `ExternalConnectorPipeCapture`, `BoundedPipeCapture` |
| **Category** | DUPLICATION |
| **Evidence** | Two classes with an identical structure: `readHandle: FileHandle`, `lock: NSLock`, `prefixData: Data`, `limit: Int`, `didClose/didFinish: Bool`, `readabilityHandler` setup in `init`, a `stopAndSnapshot()/finish()` method with an idempotency guard, a `capture(_:)` method that appends up to limit, and a `prefix()` method that returns `String`. `BoundedPipeCapture` is 67 lines. `ExternalConnectorPipeCapture` is 56 lines. Differences are cosmetic (field names, character vs byte limiting in `prefix()`). |
| **Why more complex than necessary** | One class covering the behavior of both (bounded prefix capture from a pipe) would suffice. Both classes lock the same invariant, have the same thread-safety contract, and are called identically from their respective runner files. |
| **Simpler alternative** | Merge into a single `BoundedPipeCapture` used by both paths. The one behavioral difference (character truncation in ExternalConnector variant) can be a parameter or removed. |
| **What could break if simplified** | Callers in `ExternalConnectorSession.swift` use `ExternalConnectorPipeCapture` and `ManagedProcessRunner`/`RecordingSession`-level callers use `BoundedPipeCapture`. Both call sites would need updating. |
| **Verification needed** | Confirm BoundedPipeCapture is not public API consumed by tests directly. |
| **Confidence** | high |

---

### OE-04

| Field | Value |
|---|---|
| **ID** | OE-04 |
| **File** | Multiple Platform files — `NativeAppShell.swift`, `NativeAppShellExecution.swift`, `NativeAppShellDirectPeerSettingsValidation.swift`, `NativeAppShellSessionMode.swift`, `NativeAppShellSurfaceContract.swift` |
| **Symbol** | `requireNativeAppNonEmpty`, `requireNativeAppPositive`, `requireNativeAppNonNegative`, `requireNativeAppFinite`, `requireNativeAppExecutionNonEmpty`, `requireNativeAppExecutionPositive`, `requireCommandText`, `requireAllowedCommandText`, `requirePositiveCommandValue`, `requireWindowsLoLaCommandText`, `requirePositiveWindowsLoLaCommandValue`, etc. |
| **Category** | DUPLICATION |
| **Evidence** | `grep -rn "private func require"` inside `Sources/OpenLolaCore/Platform/` returns 12+ private helper functions across 5 files. All of them are 2-to-5 line wrappers: `if value.isEmpty { throw SomeError.emptyField(field) }`. Each Platform file has its own flavor named after the local error enum. There are also duplicates in `Sources/OpenLolaCore/Connectors/`, `Sources/OpenLolaCore/Video/`, `Sources/OpenLolaCore/Integration/`, and `Sources/OpenLolaCore/Evidence/`. The total across the codebase is over 40 variants of the same 2-line guard/throw. |
| **Why more complex than necessary** | The `ValidationPrimitives` utility (OE-01) was created precisely to avoid this duplication, yet every module has its own private helpers anyway. The private helpers provide no abstraction beyond giving the local error type a name. |
| **Simpler alternative** | Call `ValidationPrimitives` directly, or inline the 2-line guard/throw at each call site. The Protocol-based system in OE-01 should either be used consistently or eliminated. |
| **What could break if simplified** | Only internal to each file. No public surface. Safe to consolidate once the overall validation approach (OE-01) is resolved. |
| **Verification needed** | None beyond a build check. |
| **Confidence** | high |

---

### OE-05

| Field | Value |
|---|---|
| **ID** | OE-05 |
| **File** | `Sources/OpenLolaCore/Platform/NativeAppShell.swift` (lines 297-325) |
| **Symbol** | `NativeAppRuntimeSmokeConfiguration.parse(_:)` |
| **Category** | DUPLICATION |
| **Evidence** | A hand-written `--key value` argument parser loop (lines 305-319) that duplicates `KeyValueArgumentParser`'s logic exactly — same `while index < arguments.count`, same `!arguments[valueIndex].hasPrefix("--")` guard, same `unknownArgument/duplicateArgument/missingValue` error cases. The project already has `KeyValueArgumentParser` (OE-02) for this purpose. |
| **Why more complex than necessary** | `KeyValueArgumentParser` was built to avoid this. This is a second copy of the same parser wheel. |
| **Simpler alternative** | Use `KeyValueArgumentParser.parseValues(arguments, allowed: [...], unknown: ..., duplicate: ..., missingValue: ...)`. |
| **What could break if simplified** | `NativeAppRuntimeSmokeConfigurationError` error enum must still exist because the CLI maps to it. The parsing logic itself is a one-for-one replacement. |
| **Verification needed** | Confirm `NativeAppRuntimeSmokeConfigurationError` cases match `KeyValueArgumentError` semantics. |
| **Confidence** | high |

---

### OE-06

| Field | Value |
|---|---|
| **ID** | OE-06 |
| **File** | `Sources/OpenLolaCore/Core/CapabilitySummary.swift` |
| **Symbol** | `CapabilitySummary.m00Scaffold`, `CapabilitySummary.m02ProtocolSession`, `CapabilitySummary.m14ReleaseHardening` |
| **Category** | COMPATIBILITY_SLOP |
| **Evidence** | `CapabilitySummary` holds 4 static instances for milestones m00 through m15. Only `CapabilitySummary.current` (= `m15PackagingFieldTest`) is used at runtime (found in `main.swift:243`). The historical instances `m00Scaffold`, `m02ProtocolSession`, and `m14ReleaseHardening` appear only in tests that assert their `.stage` and `.description` values — i.e., tests that only verify that the static constants still exist and haven't changed. |
| **Why more complex than necessary** | Historical milestone snapshots have no runtime role. Tests that only check field values of hardcoded constants confirm no useful invariant — they would pass equally well whether the constants were right or wrong, since the test input and the definition live in the same codebase. |
| **Simpler alternative** | Remove the three historical static instances and their three `DevelopmentStage` cases (`m00Scaffold`, `m02ProtocolSession`, `m14ReleaseHardening`). Retain only `.current`. If milestone history is needed, it belongs in a CHANGELOG or docs. |
| **What could break if simplified** | The three CapabilitySummary tests would break. `DevelopmentStage` enum would shrink. |
| **Verification needed** | Confirm `DevelopmentStage` cases are not serialized into any fixture JSON or report artifact that must remain decodable. |
| **Confidence** | medium (tests explicitly reference the historical instances; intent may be to protect the contract) |

---

### OE-07

| Field | Value |
|---|---|
| **ID** | OE-07 |
| **File** | `Sources/OpenLolaCore/Support/PlaceholderDetection.swift` |
| **Symbol** | `PlaceholderDetection`, `PlaceholderPattern`, `FragmentBoundaryDirection`, `containsDelimitedFragment`, `isFragmentBoundary`, `isInsideNonPlaceholderToken`, `tokenContaining` |
| **Category** | OVERENGINEERING |
| **Evidence** | 152 lines. Inner `PlaceholderPattern` struct. `FragmentBoundaryDirection` enum. Three private functions implementing word-boundary scanning with manual `String.Index` arithmetic to detect whether a known fragment appears at a word boundary and is not inside a URI/email/IPv6 token. The fragment list is 8 fixed strings ("todo(human)", "placeholder", "not supplied", etc.). |
| **Why more complex than necessary** | For the actual use case — detecting whether a free-text evidence field looks like a placeholder — the boundary detection machinery exists to handle false positives like `"prerequired"` containing `"required"`. This is a valid concern, but the implementation is 3x larger than needed: `NSRegularExpression` with `\b` word-boundary anchors, or even a simple `components(separatedBy:).contains` split-and-set lookup, would handle the same cases in 15-20 lines. The "token contains `://` or `@` or `::`" heuristic is an ad-hoc fallback that signals the boundary logic doesn't fully cover the case. |
| **Simpler alternative** | Replace with `NSRegularExpression`-based word-boundary matching for each fragment (one compiled regex per fragment, cached), or use `rangeOfCharacter(from:)` boundary checks in 20-30 lines. Retain the existing tests as the acceptance contract. |
| **What could break if simplified** | False-positive rate for placeholder detection may change slightly. The existing test suite (`PlaceholderDetectionTests.swift`) is the contract. |
| **Verification needed** | Run `swift test --filter PlaceholderDetectionTests` to confirm the replacement passes the existing tests. |
| **Confidence** | medium (boundary cases are subtle; the existing logic is well-tested) |

---

### OE-08

| Field | Value |
|---|---|
| **ID** | OE-08 |
| **File** | `Sources/OpenLolaCore/Core/DebugTrace.swift` |
| **Symbol** | `DebugTraceJSONEncoder`, `DebugTraceTimestampFormatter`, `DebugTraceEncodingFailureLine` |
| **Category** | BOILERPLATE |
| **Evidence** | Three private enums at the bottom of `DebugTrace.swift`. `DebugTraceJSONEncoder` is a 5-line wrapper: create `JSONEncoder`, set `.sortedKeys`, encode — one call site. `DebugTraceTimestampFormatter` is a 5-line wrapper: create `Date.ISO8601FormatStyle()`, call `.format(date)` — two call sites. `DebugTraceEncodingFailureLine` is a 30-line manual JSON builder that constructs a fallback line when `JSONEncoder` fails — called once. The manual JSON string builder `jsonEscaped` inside it (22 lines) reproduces standard JSON escape logic from scratch. |
| **Why more complex than necessary** | Each of these "enum namespaces" wraps a single operation. The 30-line manual JSON builder for the encoding-failure fallback is ironic: it hand-implements what the already-failing JSONEncoder should have done. `String(format:)` or `JSONEncoder` on a minimal struct would be simpler for the fallback. |
| **Simpler alternative** | Inline `DebugTraceJSONEncoder` and `DebugTraceTimestampFormatter` at their call sites (each is one line). Replace `DebugTraceEncodingFailureLine` with a single `String(format:)` or a 2-line hard-coded fallback. |
| **What could break if simplified** | No public surface. Internal to `DebugTrace`. Tests would still pass. |
| **Verification needed** | None beyond a build check and confirming `jsonLines()` output format matches any fixture that parses it. |
| **Confidence** | high |

---

### OE-09

| Field | Value |
|---|---|
| **ID** | OE-09 |
| **File** | `Sources/OpenLolaCore/Core/OpenLolaContractsAliases.swift` |
| **Symbol** | `MeasurementMethodology`, `MeasurementVerdict`, `PrettyJSONCodable`, `RxBufferProfile` (typealiases) |
| **Category** | SINGLE_USE_ABSTRACTION |
| **Evidence** | 4 lines of `public typealias X = OpenLolaContracts.X`. The entire file re-exports 4 types from `OpenLolaContracts` into `OpenLolaCore` so callers don't need to write the module prefix. |
| **Why more complex than necessary** | Swift's `@_exported import` would achieve the same effect without a separate file. Alternatively, `OpenLolaCore` consumers that need these types could import `OpenLolaContracts` directly — it is already a declared dependency. The aliases add an indirection level that makes it harder to trace which module owns the type. |
| **Simpler alternative** | Add `@_exported import OpenLolaContracts` to one file in `OpenLolaCore` (e.g., `OpenLolaCLI.swift`), or remove the aliases and let callers import `OpenLolaContracts` where needed. |
| **What could break if simplified** | Any call site that currently resolves the type via `OpenLolaCore.MeasurementVerdict` would need to use `OpenLolaContracts.MeasurementVerdict` instead, or import both modules. |
| **Verification needed** | Search for `OpenLolaCore.MeasurementVerdict` (and the others) in app and test targets to find affected imports. |
| **Confidence** | medium |

---

### OE-10

| Field | Value |
|---|---|
| **ID** | OE-10 |
| **File** | `Sources/OpenLolaCore/Platform/NativeAppShell.swift` |
| **Symbol** | `NativeAppShellSyntheticSmoke`, `NativeAppRuntimeSmoke` |
| **Category** | BOILERPLATE |
| **Evidence** | `NativeAppShellSyntheticSmoke` is an enum with `run()` and `placeholder()` — both call a private `report(id:title:capturedAt:notes:)` factory that builds a hardcoded `NativeAppShellReport`. `NativeAppRuntimeSmoke` is a second enum with a `run(configuration:headlessReport:)` method that also builds a hardcoded `NativeAppShellReport`. Three enum namespaces and a 4-argument private factory for constructing what are, at runtime, two fixed structs and one derived struct. |
| **Why more complex than necessary** | `run()` and `placeholder()` could be two static `let` constants (or free-standing functions). The private `report(...)` factory is only called from those two, so it could be inlined. `NativeAppRuntimeSmoke.run(...)` could be a static function on `NativeAppShellReport` directly or a simple free function. |
| **Simpler alternative** | Reduce to: `static let syntheticSmoke: NativeAppShellReport = ...` and `static let placeholder: NativeAppShellReport = ...`. Keep `NativeAppRuntimeSmoke.run` as a free function if the namespace matters. |
| **What could break if simplified** | Call sites in `FieldReadinessRun.swift` and `MilestoneCommands.swift` would need minor adjustments. |
| **Verification needed** | Confirm neither enum is used as a type parameter or protocol conformance. |
| **Confidence** | high |

---

### OE-11

| Field | Value |
|---|---|
| **ID** | OE-11 |
| **File** | `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift` |
| **Symbol** | `ExternalConnectorSessionConfiguration` |
| **Category** | OVERENGINEERING |
| **Evidence** | A single configuration struct with 40+ fields covering three entirely different connectors: LoLa, UltraGrid, and JackTrip. The LoLa-specific fields (`lolaVideoPayload`, `rawLinkInterface`, `sourceMAC`, `destinationMAC`, `videoBayer`, `videoCompression`) are irrelevant when using JackTrip. The UltraGrid-specific fields (`ultraGridTopologyMode`, `ultraGridTopologyRole`, `ultraGridFECMode`, `ultraGridEncryptionMode`, `ultraGridEncryptionPassphrase`, `ultraGridControlMode`, `ultraGridControlCommands`, `ultraGridAudioPayloadType`, `ultraGridVideoPayloadType`) are irrelevant when using LoLa. The JackTrip sub-config (`jackTrip: JackTripRunConfiguration`) is a nested struct of its own. |
| **Why more complex than necessary** | A God struct that passes all possible fields through the call chain, relying on callers to ignore the irrelevant fields. The `buildLoLaPlan`, `buildJackTripPlan`, `buildUltraGridPlan` functions each extract the small connector-specific subset. |
| **Simpler alternative** | A sum type or a shared base config plus connector-specific extensions. At minimum, the `jackTrip: JackTripRunConfiguration` sub-struct pattern should be extended to UltraGrid and LoLa so the main struct has 10-15 fields rather than 40+. |
| **What could break if simplified** | Significant refactor. The `parse(_:)` method would need restructuring. All `buildXPlan` functions and their tests would be affected. High blast radius. |
| **Verification needed** | Map which fields are accessed only inside each connector's build function. |
| **Confidence** | medium (justified complexity: cross-connector UX is real; but the struct has grown beyond what's needed) |

---

### OE-12

| Field | Value |
|---|---|
| **ID** | OE-12 |
| **File** | `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorConnectionPlan.swift` |
| **Symbol** | `ExternalConnectorConnectionPlanConfiguration` |
| **Category** | DUPLICATION |
| **Evidence** | A second large configuration struct (684-line file) for the "connection plan" command path, overlapping significantly with `ExternalConnectorSessionConfiguration` (OE-11). Fields like `connector`, `localHost`, `remoteHost`, `mediaMode`, `controlTransport`, `channels`, `sampleRateHertz`, `framesPerPacket`, `videoWidth/Height/FrameRate/BitsPerPixel`, `audioCapture/Playback`, `videoCapture/Display`, `ultraGridTopologyMode`, `ultraGridFECMode`, `jackTrip`, `controlPort`, `audioPort`, `videoPort`, `executable`, `videoExecutable`, `durationSeconds`, `sessionID`, `mediaPacketCount` are duplicated from `ExternalConnectorSessionConfiguration`. Only a few fields differ (e.g., `localHost`/`remoteHost` vs `peer`/`localHost`, `localRawLinkInterface`/`remoteRawLinkInterface` vs `rawLinkInterface`). |
| **Why more complex than necessary** | The two structs share most fields and differ only in the caller's "single endpoint" vs "pair of endpoints" framing. |
| **Simpler alternative** | UNCLEAR — the `ExternalConnectorConnectionPlanConfiguration` owns the two-peer plan generation for NMP. Whether it should extend or compose with `ExternalConnectorSessionConfiguration` requires more analysis. |
| **What could break if simplified** | The NMP workflow and its own `parse(_:)` would need restructuring. |
| **Verification needed** | Map field-by-field overlap to confirm the extent of duplication. |
| **Confidence** | medium |

---

### OE-13

| Field | Value |
|---|---|
| **ID** | OE-13 |
| **File** | `Sources/OpenLolaCore/Release/Goal/GoalCodewiseClosure.swift` |
| **Symbol** | `GoalCodewiseRequirementID` (CaseIterable enum, ~50 cases) |
| **Category** | SPECULATIVE_FEATURE |
| **Evidence** | A 50-case `CaseIterable` enum where each case corresponds to one GOAL.md requirement. The enum is used in `allCases`-based exhaustiveness checks in validation functions (lines 280, 228). Only two call sites use `allCases`. The enum cases are never individually matched in a `switch` outside of validation loops that treat all cases uniformly. The `GoalCodewiseRequirementStatus` enum (`codeImplemented` / `assumedPassedPendingMeasurement`) appears in the report struct but contributes no runtime branching. |
| **Why more complex than necessary** | The typed enum adds compile-time enforcement that all GOAL.md requirements appear in the closure report, but the same check could be done with a `Set<String>` of raw string IDs. The enum provides no uniqueness or type-safety advantage over a set of string constants because the validation loops immediately convert cases to `.rawValue` strings anyway. |
| **Simpler alternative** | Replace with a `static let allRequirementIDs: [String]` array. The exhaustiveness check becomes `allRequirementIDs.filter { !seen.contains($0) }`. |
| **What could break if simplified** | The `GoalCodewiseRequirementID` type in the report model would disappear or become a `String`; fixtures using it as a JSON key would remain compatible if the raw values are preserved. |
| **Verification needed** | Confirm no test constructs a `GoalCodewiseRequirementID` enum case by name rather than by raw value. |
| **Confidence** | medium |

---

### OE-14

| Field | Value |
|---|---|
| **ID** | OE-14 |
| **File** | `Sources/OpenLolaCore/Release/CurrentEvidenceStatusMatrix.swift` |
| **Symbol** | `CurrentEvidenceLaneID`, `CurrentRealWorldTestID`, `CurrentEvidenceCrosswalkRow`, `CurrentRealWorldTestTask`, `CurrentEvidenceStatusMatrixSummary`, `CurrentEvidenceStatusMatrixSource` |
| **Category** | SPECULATIVE_FEATURE |
| **Evidence** | A complete typed data model for a project-level evidence kanban board. `CurrentEvidenceLaneID` has 11 cases. `CurrentRealWorldTestID` has 11 cases. Each is `CaseIterable`. The `CurrentEvidenceCrosswalkRow` struct carries `lane`, `status`, `finding`, `doneNow: [String]`, `missingBeforePass: [String]`, `realWorldTaskIDs`, and `sourceEvidence: [String]`. The full data is a large static array of hardcoded rows. The `allCases` check validates that every lane and task ID is represented in the static arrays. |
| **Why more complex than necessary** | This is a structured project status tracker encoded as runtime Swift types. Its content (`finding`, `doneNow`, `missingBeforePass`) is pure editorial text that changes as the project evolves. Encoding it as Swift means every editorial update requires a source code change, rebuild, and test run. The typed ID enums guarantee internal consistency but the actual data is strings. A JSON or Markdown document achieves the same result at zero maintenance overhead. |
| **Simpler alternative** | Move the crosswalk data to `docs/current-state.md` (already exists) or a static JSON file. Keep only the summary computation and verdict if a CLI report is needed. |
| **What could break if simplified** | The `current-evidence-status-matrix` CLI command and its validator would need to read from a file rather than from Swift literals. Fixture tests for the matrix report would change. |
| **Verification needed** | Confirm the matrix report is not used as a required gate in `scripts/verify-release-readiness.sh`. |
| **Confidence** | medium |

---

### OE-15

| Field | Value |
|---|---|
| **ID** | OE-15 |
| **File** | `Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift`, `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`, `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift` |
| **Symbol** | `CLICommandInventory`, `ReportSchemaInventory`, `SourceOwnershipInventory` |
| **Category** | SPECULATIVE_FEATURE |
| **Evidence** | Three "inventory" modules that encode source-level metadata (which Swift files own which CLI commands, which schemas have which validators, which source files own which subsystems) as hardcoded Swift arrays of structs. `CLICommandInventory.swift` is 325 lines of literals listing every CLI command with its source file, parser, and test paths. `ReportSchemaInventory.swift` is 206 lines of schema metadata. The inventories produce CLI-queryable reports (`command-inventory`, `report-schema-inventory`). |
| **Why more complex than necessary** | Source-level metadata that references file paths and command names in strings inside Swift source is fragile: renaming a file or command does not trigger a compile error, only a stale inventory. The value is in having a machine-readable catalog, but the Swift encoding is not more reliable than a YAML/JSON equivalent. Moreover, the data never drives any runtime behavior — it is only serialized to JSON for human review. |
| **Simpler alternative** | Keep the inventory commands but read from static JSON or TOML configuration files. Or generate the inventory from a simple script that parses command registration in `main.swift` rather than maintaining it by hand. |
| **What could break if simplified** | The CLI commands would need to read from files. Tests that fixture the inventory report would change. |
| **Verification needed** | Confirm inventories are not used in CI gates (check `scripts/verify-release-readiness.sh`). |
| **Confidence** | medium |

---

### OE-16

| Field | Value |
|---|---|
| **ID** | OE-16 |
| **File** | `Sources/OpenLolaContracts/PrettyJSONCodable.swift` |
| **Symbol** | `JSONReportCoder`, `PrettyJSONCodable` |
| **Category** | SINGLE_USE_ABSTRACTION |
| **Evidence** | `JSONReportCoder` is a 3-method enum: `decode`, `prettyJSONData`, `prettyJSONString` — each one is a trivial 2-4 line wrapper around `JSONDecoder` / `JSONEncoder`. `PrettyJSONCodable` is a protocol with 3 methods that default-implement by forwarding to `JSONReportCoder`. Every report type in the codebase adopts `PrettyJSONCodable` to get `prettyJSONString()`. |
| **Why more complex than necessary** | `JSONReportCoder` is only called from `PrettyJSONCodable` default implementations; it has no independent use. The protocol could just hold the 3-line implementations directly without the intermediate enum. Or the default implementations could be a single protocol extension directly on `Codable` gated by a typealiased condition. At minimum, `JSONReportCoder` is redundant with `PrettyJSONCodable`. |
| **Simpler alternative** | Remove `JSONReportCoder` and inline its 3 trivial implementations into the `PrettyJSONCodable` extension. |
| **What could break if simplified** | Any call site calling `JSONReportCoder.decode(...)` directly rather than going through the protocol. Quick check: `grep -rn "JSONReportCoder\."` should show only the 3 forwarding calls in `PrettyJSONCodable`. |
| **Verification needed** | Confirm `JSONReportCoder` is not called outside `PrettyJSONCodable.swift`. |
| **Confidence** | high |

---

### OE-17

| Field | Value |
|---|---|
| **ID** | OE-17 |
| **File** | Former `UltraGridMediaFormatRegistry.swift`; constants now belong beside `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibility.swift` |
| **Symbol** | `UltraGridMediaFormatRegistry` |
| **Category** | SINGLE_USE_ABSTRACTION |
| **Evidence** | An enum "registry" that holds 4 `static let` FourCC constants (`rgb24`, `rgba`, `uyvy`, `v210`) and one `static func rawVideoFourCC(bitsPerPixel:)` that switch-cases over 3 bit-depth values to return one of the 3 used constants. Called in exactly one place: `UltraGridCompatibility.swift:380`. |
| **Why more complex than necessary** | Four constants and a 5-case switch do not justify a "registry" abstraction. The constants and the lookup belong inline in `UltraGridCompatibility` or in the file that uses them. |
| **Simpler alternative** | Move the 4 constants and the switch to `UltraGridCompatibility.swift` or inline the 4-value lookup. Delete `UltraGridMediaFormatRegistry.swift`. |
| **What could break if simplified** | One call site in `UltraGridCompatibility.swift`. No public API impact unless downstream code references the registry type directly. |
| **Verification needed** | Confirm `UltraGridMediaFormatRegistry` is not imported or referenced outside `UltraGridCompatibility.swift`. |
| **Confidence** | high |

---

### OE-18

| Field | Value |
|---|---|
| **ID** | OE-18 |
| **File** | `Sources/OpenLolaCore/Core/ValidationPrimitives.swift` |
| **Symbol** | `ReportValidationProtocol` |
| **Category** | SINGLE_USE_ABSTRACTION |
| **Evidence** | `ReportValidationProtocol` extends `ReportPrimitiveValidating` and adds zero requirements or default implementations of its own. Its only content is inheriting the parent protocol. 18 files declare conformance to `ReportPrimitiveValidating` and 5 files declare conformance to `ReportValidationProtocol`. No code uses `ReportValidationProtocol` as a generic constraint or existential that is different from `ReportPrimitiveValidating`. |
| **Why more complex than necessary** | It is a protocol that does nothing. It exists as a semantic label without adding behavior or requirements. |
| **Simpler alternative** | Remove `ReportValidationProtocol`. Files conforming to it conform to `ReportPrimitiveValidating` directly. |
| **What could break if simplified** | Conformances in `VideoCaptureHelpers.swift`, `VideoTransportHelpers.swift`, `SessionProfileBenchmark.swift`, `RxBuffering.swift`, `DriftPlcFixedTargetCertification.swift` would change to `ReportPrimitiveValidating`. |
| **Verification needed** | Confirm no generic constraint is written as `where T: ReportValidationProtocol`. |
| **Confidence** | high |

---

### OE-19

| Field | Value |
|---|---|
| **ID** | OE-19 |
| **File** | `Sources/OpenLolaCore/Core/DebugTrace.swift` |
| **Symbol** | `DebugTraceFieldPolicy` |
| **Category** | OVERENGINEERING |
| **Evidence** | `DebugTraceFieldPolicy` is a struct with an `allowedFieldKeys: Set<String>`, `alwaysAllowedFieldKeys: Set<String>`, `unsafeFieldKeyFragments: [String]`, and a `func allows(_ fieldKey: String) -> Bool` logic that checks: (a) always-allowed, (b) not containing an unsafe fragment, AND (c) in the allowed set. The only call site that builds a policy is `DebugTraceFieldPolicy.default` (one static instance). The `allowing(_ fieldKeys:)` method returns a modified copy; it is called nowhere in production (UNCLEAR — would need full grep). |
| **Why more complex than necessary** | The three-set logic and the `allowing` builder exist to make the policy "configurable", but there is one consumer and one static configuration. The allow/deny behavior could be a 5-line inline filter directly in `DebugTrace.record(event:fields:)` without a separate policy struct. |
| **Simpler alternative** | Inline the `allows` check as a private function or a closure in `DebugTrace`. Remove `DebugTraceFieldPolicy` struct if `allowing` has no real callers. |
| **What could break if simplified** | Any caller that constructs a custom `DebugTraceFieldPolicy`. Tests or production code that uses `allowing(...)`. |
| **Verification needed** | `grep -rn "DebugTraceFieldPolicy\|\.allowing("` to confirm whether the policy or its builder is used outside the one static default. |
| **Confidence** | low (the policy struct may justify itself if custom policies are needed) |

---

### OE-20

| Field | Value |
|---|---|
| **ID** | OE-20 |
| **File** | `Sources/OpenLolaCore/Release/Goal/GoalCodewiseClosure.swift` |
| **Symbol** | `GoalCodewiseRequirementArea`, `GoalCodewiseRequirementStatus` |
| **Category** | BOILERPLATE |
| **Evidence** | `GoalCodewiseRequirementArea` has 12 cases (`productGoal`, `priority`, `principle`, `compliance`, `architecture`, `definitionOfDone`, `artifact`, `validation`, `performance`, `decisionRule`). `GoalCodewiseRequirementStatus` has 2 cases (`codeImplemented`, `assumedPassedPendingMeasurement`). Both are Codable/Equatable/Sendable. They appear as fields in the `GoalCodewiseRequirementEntry` struct. The `area` field is set to a fixed value per entry but never drives any runtime branching — there is no `switch entry.area`. The `status` field similarly only appears in the JSON output but is not used for filtering or conditional logic at runtime. |
| **Why more complex than necessary** | Two enums whose values never influence program flow. They exist purely as JSON labels in the output report. String fields would serve the same purpose with less compile-time overhead. |
| **Simpler alternative** | Replace `GoalCodewiseRequirementArea` and `GoalCodewiseRequirementStatus` with `String` fields in `GoalCodewiseRequirementEntry`, or keep the enums but remove `CaseIterable` if it is unused. |
| **What could break if simplified** | Fixture JSON files that deserialize `area` and `status` as enum raw values would fail if the raw values change. No runtime behavior changes. |
| **Verification needed** | Confirm neither enum is used in a `switch` or `if case` anywhere. |
| **Confidence** | medium |

---

## Highest-Impact Simplification Targets

These have the most code to remove and the most cognitive noise to eliminate.

| # | Finding | Approximate Scope | Why High Impact |
|---|---|---|---|
| 1 | **OE-01** `ValidationPrimitives` protocol hierarchy | 364 lines + 20+ conformance declarations scattered across the codebase | Removes 6 protocols, 1 empty protocol extension layer, and 40+ repeated private helpers (OE-04) in one move |
| 2 | **OE-04** Duplicated private `require*` helpers | 40+ functions across 10+ files | Every module re-implements the same 2-line guard/throw in a uniquely-named function; consolidation removes the noise and points at OE-01 |
| 3 | **OE-11 + OE-12** God struct `ExternalConnectorSessionConfiguration` + duplicate `ExternalConnectorConnectionPlanConfiguration` | Two files, 700+ lines each, 40+ fields each | Most connector-specific complexity is silently absorbed or ignored; structuring per-connector sub-configs reduces the reading burden significantly |
| 4 | **OE-03** Duplicate pipe capture classes | ~120 lines | Exact duplication; one class, one test surface |

---

## Low-Risk Deletion / Inlining Candidates

These have one or two call sites, no public API impact, and can be inlined or deleted without protocol/test changes.

| # | Finding | Action |
|---|---|---|
| 1 | **OE-16** `JSONReportCoder` | Inline 3 trivial methods into `PrettyJSONCodable` extension; delete the enum |
| 2 | **OE-17** `UltraGridMediaFormatRegistry` | Move 4 constants and 1 switch to `UltraGridCompatibility.swift`; delete the file |
| 3 | **OE-08** `DebugTraceJSONEncoder`, `DebugTraceTimestampFormatter`, `DebugTraceEncodingFailureLine` | Inline at their single call sites in `DebugTrace.swift` |
| 4 | **OE-18** `ReportValidationProtocol` | Replace conformances with `ReportPrimitiveValidating`; delete the empty protocol |
| 5 | **OE-05** `NativeAppRuntimeSmokeConfiguration.parse` | Replace with `KeyValueArgumentParser.parseValues`; one-line change |
| 6 | **OE-10** `NativeAppShellSyntheticSmoke` / `NativeAppRuntimeSmoke` enum wrappers | Flatten to static constants / free functions |

---

## Risky Areas That Need More Proof Before Simplification

| # | Finding | Risk |
|---|---|---|
| 1 | **OE-07** `PlaceholderDetection` | The word-boundary and URI/token exclusion logic handles real edge cases. The existing test suite is the contract. A replacement must pass all tests before the current code is removed. |
| 2 | **OE-11** `ExternalConnectorSessionConfiguration` | The God struct is the single parse point for a complex CLI surface. Splitting it risks regressions in connector-specific argument handling. Requires thorough integration test coverage per connector. |
| 3 | **OE-14** `CurrentEvidenceStatusMatrix` | If the matrix is gated in `scripts/verify-release-readiness.sh`, removing it as Swift literals could break the CI gate. Needs script inspection first. |
| 4 | **OE-19** `DebugTraceFieldPolicy.allowing` | If any test or production caller constructs custom policies, inlining the default removes a tested extension point. Needs a full usage grep before acting. |
| 5 | **OE-13** `GoalCodewiseRequirementID` enum | The `allCases` validation in `GoalCodewiseClosure.swift` and `GoalCompletionAudit.swift` is a real completeness gate. Any simplification must preserve that the audit fails when a requirement ID is missing from the report. |

---

## Files That Are Simple Enough — Do Not Touch

| File | Reason |
|---|---|
| `Sources/OpenLolaContracts/MeasurementVerdict.swift` | 5 lines, one enum, three cases. Perfect. |
| `Sources/OpenLolaContracts/MeasurementMethodology.swift` | 4 lines, one enum, two cases. Perfect. |
| `Sources/OpenLolaContracts/RxBufferProfile.swift` | 6 lines. Correct scope for a shared contract enum. |
| `Sources/OpenLolaCore/Support/MonotonicDeadline.swift` | 31 lines. Clean, well-scoped. The overflow guard is justified for deadline arithmetic. |
| `Sources/OpenLolaCore/Timing/MediaClock.swift` → `nanoseconds(forFrameCount:sampleRateHertz:)` | The full-width arithmetic is necessary for precision. Not over-engineered. |
| `Sources/OpenLolaCore/Network/P2P/DirectPeerFNV1A.swift` | UNCLEAR in file, but FNV1A is a known algorithm; expected to be compact. |
| `Sources/OpenLolaCore/Core/OpenLolaCLI.swift` | 44 lines, one static factory. Simple and correct. |
| `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaModel.swift` | Constants and formulas. Justified by the protocol evidence anchors in comments. |
| `Sources/OpenLolaCore/Audio/Codecs/OpusCELTLowDelayCodec.swift` | Single codec file; complexity belongs to the codec domain. |
| All files in `Sources/opus-1.5.2/` and `Sources/xs_ref_sw_ed2/` | Vendored reference code. Do not audit. |
| All files in `Sources/COpenLolaAtomics/` | C bridge. Minimal by design. |

---

## Remaining Uncertainty

1. **`DebugTraceFieldPolicy.allowing`** — Could not confirm whether any test or production caller constructs a non-default policy. If custom policies are used in tests, OE-19 is partially justified.

2. **`ExternalConnectorConnectionPlanConfiguration` vs `ExternalConnectorSessionConfiguration` overlap** (OE-12) — A full field-by-field diff was not completed. The extent of duplication is estimated; a mechanical diff is needed before acting.

3. **`CurrentEvidenceStatusMatrix` CI gating** (OE-14) — Whether `scripts/verify-release-readiness.sh` or any other gate depends on the matrix report being generated from hardcoded Swift data was not verified. If it is gated, the simplification scope shrinks.

4. **`CapabilitySummary` historical instances** (OE-06) — Tests reference the instances by name. The intent may be to freeze milestone-version behavior as a stable contract. If that is the design intent, the instances are not slop.

5. **`ReportSchemaInventory` and `CLICommandInventory` path accuracy** (OE-15) — It was not verified whether these inventories are cross-checked against actual file paths at build or test time. If they are, the Swift encoding has a correctness advantage over a JSON file.

6. **Connector launch plan `protocolFacts` string arrays** — Long string arrays in `JackTripLaunchPlan.swift` and `LoLaConnectorLaunchPlan.swift` are evidence anchors. They look like documentation-in-code but may be required for the compatibility compliance model. Not flagged as over-engineering without further review.
