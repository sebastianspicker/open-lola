# Deprecation and Simplification Audit

Generated from static analysis, grep-based call-site enumeration, and a background
exploration agent. All findings include evidence, risk, and a verification path.

Evidence basis: no runtime execution was performed; all findings are
**static only**. Where call-site counts were obtained by grep, the count
reflects files scanned under `Sources/` and `Tests/`.

---

## Index

| ID | Category | Location | Risk | Action |
|----|----------|----------|------|--------|
| [DA-001](#da-001) | Deprecated API — legacy CodingKey | `DirectPeerRealtimeAudioGraphTypes.swift:130` | Low | Investigate migration then delete |
| [DA-002](#da-002) | Deprecated internal API — scaffolding | `LoLaParityDeferredFeatures.swift:216` | Low | Confirm scope, then delete call sites |
| [DA-003](#da-003) | Dead alias | `OpenLolaContractsAliases.swift` (`JSONReportCoder`) | Low | Delete single alias |
| [DA-004](#da-004) | Trivial typealias | `LoLaParityDeferredFeatures.swift:3` | Low | Inline at call site |
| [DA-005](#da-005) | Duplicated validation helpers | 15+ files in `Sources/OpenLolaCore/` | Medium | Migrate to `ValidationPrimitives.swift` |
| [DA-006](#da-006) | Overcomplicated switch chain | `MilestoneCommands.swift` (610 lines, 62 arms) | Medium | Split into sub-dispatchers |
| [DA-007](#da-007) | Overcomplicated switch chain | `NetworkCommands.swift` (380 lines, ~46 arms) | Medium | Split into sub-dispatchers |
| [DA-008](#da-008) | Single-use testability protocol | `ExternalConnectorSessionRuntime.swift:90` | Low | Keep — justified for DI |
| [DA-009](#da-009) | Parallel connector launch-plan structure | `JackTripLaunchPlan.swift`, `UltraGridLaunchPlan.swift` | Low | Investigate shared template |
| [DA-010](#da-010) | `ReportValidationProtocol` — underadopted | `ValidationPrimitives.swift` | Medium | Migrate report validators |
| [DA-011](#da-011) | Stale "prototype" name | `DirectP2PTwoPeerPrototypeCommandSupport.swift` | Low | Keep until schema promotion |
| [DA-012](#da-012) | Incomplete staged feature | `VideoTransportMultiStreamRuntime.swift` | Low | Clarify scope in inventory |
| [DA-013](#da-013) | Low-level HAL C API usage | `CoreAudioInventoryReader.swift`, `AudioLoopbackHelpers.swift`, `AppReceiverPreviewServices.swift` | Low | Keep; verify error handling |

---

## Findings

### DA-001

**Category:** Deprecated internal API — legacy CodingKey migration shim
**Location:** `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift:130`
**Risk:** Low

**Evidence:**

```
@available(*, deprecated, message:
  "Use inputDeviceUID and outputDeviceUID; audioDeviceUID is retained for
   legacy config migration only.")
```

The `@available(*, deprecated)` marker sits on a single `CodingKey` case (`audioDeviceUID`) in the `Codable` decode path, not on the `audioDeviceUID` field itself. The field is actively used across ~15 files:
`DirectPeerSessionAVRunTypes.swift`, `DirectPeerSessionAVRuntimeReport.swift`,
`DirectPeerSessionAVSocketRunner.swift` (3 sites), `DirectPeerSessionReport.swift`,
`DirectPeerSessionAVReportBuilder.swift`, `E2EBenchmarkReportValidation.swift` (2 sites),
`E2EBenchmarkSyntheticSmoke.swift`.

**Why it matters:** The deprecated `CodingKey` decode branch silently accepts old configs
that use `audioDeviceUID` in JSON. If no live configs still use that key the branch
is dead. If some do, removal is a breaking change for those configs.

**What could break:** Removing the legacy decode branch breaks deserialization of any
saved JSON that uses the `audioDeviceUID` key. Field rename or split (`inputDeviceUID`
/ `outputDeviceUID`) must be complete before removal.

**Suggested action:** Audit saved reports and config fixtures for the `audioDeviceUID`
JSON key. If none found, delete the deprecated decode branch.

**Verification needed:** `grep -r '"audioDeviceUID"' Tests/Fixtures/ private/`

---

### DA-002

**Category:** Deprecated internal API — documentation/fixture scaffolding
**Location:** `Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift:216`
**Risk:** Low

**Evidence:**

```
@available(*, deprecated, message:
  "Synthetic G16 parity ledger is fixture/documentation scaffolding only;
   use LoLaParityDeferredFixtures.partialLedger() for tests and measured
   LoLaParityDeferredLedgerReport evidence for promotion decisions.")
```

The deprecated function generates a synthetic G16 parity ledger. It is not called
from any CLI command or app surface; the active CLI path goes through
`LoLaParityDeferredFixtures.partialLedger()` in tests and the validator at
`MilestoneValidationCommands.swift:80`.

**Why it matters:** A `@available(*, deprecated)` marker in production source is a compiler
warning surface. If the function is genuinely unused it should be deleted, not annotated.

**Suggested action:** Confirm the deprecated function is not called from any CLI,
app, or test surface beyond `LoLaParityDeferredFeatures.swift` itself, then delete it.

**Verification needed:**
`grep -rn "syntheticG16\|LoLaParityDeferredSyntheticSmoke" Sources/ Tests/`

---

### DA-003

**Category:** Dead alias
**Location:** `Sources/OpenLolaCore/Core/OpenLolaContractsAliases.swift`
**Risk:** Low

**Evidence:**

`OpenLolaContractsAliases.swift` re-exports five symbols from `OpenLolaContracts`
into the `OpenLolaCore` namespace:

| Alias | Call sites outside the alias file |
|-------|----------------------------------|
| `JSONReportCoder` | **0** (grep found no usage in `Sources/` outside `OpenLolaContracts/PrettyJSONCodable.swift`) |
| `MeasurementMethodology` | Active — used in 8+ files |
| `MeasurementVerdict` | Active — used in ~296 files |
| `PrettyJSONCodable` | Active — used in ~71 files |
| `RxBufferProfile` | Active — used in ~92 files |

Seven `OpenLolaCore` files already import `OpenLolaContracts` directly, showing
the alias file is not the sole access path.

**Why it matters:** `JSONReportCoder` is an alias with zero verified call sites.
It is dead export surface that makes the API boundary harder to understand.

**Suggested action:** Delete the `JSONReportCoder` typealias line from
`OpenLolaContractsAliases.swift`. The other four aliases are active convenience
re-exports; keep them unless the module boundary is redesigned.

**Verification needed:**
`grep -rn "JSONReportCoder" Sources/ Tests/ --include="*.swift"` — should return
only `OpenLolaContractsAliases.swift` and `PrettyJSONCodable.swift`.

---

### DA-004

**Category:** Trivial typealias adding no semantic value
**Location:** `Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift:3`
**Risk:** Low

**Evidence:**

```swift
public typealias LoLaParityLedgerRunMode = MeasurementMethodology
```

The alias is confirmed equivalent by a test:
`Tests/OpenLolaCoreTests/MeasurementMethodologyTests.swift:13`:

```swift
#expect(LoLaParityLedgerRunMode.synthetic == MeasurementMethodology.synthetic)
```

Call sites in `LoLaParityDeferredFeatures.swift` use `LoLaParityLedgerRunMode` only
inside the same file. No other file uses this typealias.

**Why it matters:** It is a one-file alias that renames a shared type for no
semantic reason. The rename obfuscates that the run mode is the general-purpose
`MeasurementMethodology`.

**Suggested action:** Replace all `LoLaParityLedgerRunMode` references inside
`LoLaParityDeferredFeatures.swift` with `MeasurementMethodology`, delete the
typealias, and delete the test assertion.

**Verification needed:** Static only — `grep -rn "LoLaParityLedgerRunMode" Sources/`.

---

### DA-005

**Category:** Duplicated validation helpers — widespread pattern
**Location:** 15+ files across `Sources/OpenLolaCore/`
**Risk:** Medium

**Evidence:**

`ValidationPrimitives.swift` defines a fully generic `ReportValidationProtocol`
extension providing `requireNonEmpty`, `requirePositive`, `requireNonNegative`,
`requireFinite` as static methods. Only two validators conform to it:
`LatencyTuningValidator` and `PerformanceAuditValidator`.

Every other domain module implements its own private/internal free functions
following the identical pattern (`value, field: String`) → throw domain-scoped error:

| File | Helper functions |
|------|-----------------|
| `MadiFullDuplexValidation.swift` | `requireM05NonEmpty`, `requireM05Positive`, `requireM05NonNegative`, `requireM05Finite`, `requireM05PositiveFinite` |
| `MadiReceiveReport.swift` | `requireMadiReceiveNonEmpty`, `requireMadiReceivePositive`, `requireMadiReceiveNonNegative` (×2) |
| `MadiTransmit.swift` | `requireMadiTransmitNonEmpty`, `requireMadiTransmitPositive`, `requireMadiTransmitNonNegative` (×2) |
| `RealtimeAudioEngineHelpers.swift` | `requireRealtimeNonEmpty`, `requireRealtimeNonNegative` (×2), `requireRealtimePositive` |
| `DriftPlcHelpers.swift` | `requireDriftNonEmpty`, `requireDriftPositive`, `requireDriftNonNegative`, `requireDriftFinite` |
| `DriftPlcFixedTargetCertification.swift` | `requireDriftCertificationNonEmpty`, `requireLolaBaselineNonEmpty`, `requireLolaBaselinePositive`, `requireLolaBaselineNonNegative` |
| `E2EBenchmarkReportValidation.swift` | `requireE2ENonEmpty` (×2), `requireE2EPositive` (×2), `requireE2ENonNegative` (×2), `requireE2EFinite`, `requireE2EPercent` |
| `LatencyBenchmarkReport.swift` | `requireLatencyNonEmpty`, `requireLatencyPositive` (×2), `requireLatencyNonNegative` (×2), `requireLatencyPercent` |
| `RxBufferBenchmarkReport.swift` | `requireRxBenchmarkNonEmpty`, `requireRxBenchmarkPositive`, `requireRxBenchmarkNonNegative` (×2), `requireRxBenchmarkPercent` |
| `RxBuffering.swift` | `requireRxNonEmpty`, `requireRxPositive`, `requireRxNonNegative` (×2) |
| `SessionProfileBenchmark.swift` | `requireProfileMetricNonNegative` (×2) |
| `VideoCaptureHelpers.swift` | `requireVideoCaptureNonEmpty`, `requireVideoCaptureOptionalNonEmpty`, `requireVideoCapturePositive` (×4), `requireVideoCaptureNonNegative` (×2), `requireVideoCaptureFinite` |
| `VideoTransportHelpers.swift` | `requireTransportNonEmpty`, `requireTransportPositive` (×2), `requireTransportNonNegative` (×2), `requireTransportFinite` |
| `AudioLoopbackHelpers.swift` | `requireRunNonEmpty` |
| `MediaGeometrySizing.swift` | `requirePositive` |

**Why it matters:** Approximately 50 free functions implement the same 5-pattern
validation logic (nonEmpty, positive, nonNegative, finite, percent) across 15 files.
`ValidationPrimitives.swift` already has the correct shared implementation; it is
simply not adopted. The duplication means bug fixes or threshold changes must be
applied 15 times.

**What could break:** Each wrapper throws a domain-specific error type. Migration
requires either adopting `ReportValidationProtocol` (which binds an associated
`ValidationError` type) or refactoring the error-type propagation. This is
medium-effort, not high-risk.

**Suggested action:** Adopt `ReportValidationProtocol` in each report validator
enum. Delete the per-module free functions. One module at a time to reduce blast
radius. Start with `RxBuffering.swift` (self-contained, well-tested).

**Verification needed:** Before each migration, run the targeted test suite for
that module.

---

### DA-006

**Category:** Overcomplicated switch chain
**Location:** `Sources/open-lola/Commands/MilestoneCommands.swift`
**Risk:** Medium

**Evidence:**

610 lines, 28 `case [...]` arms, 34 `case let args` arms = **62 total switch arms**
in a single function `handleMilestoneCommand`. All arms follow the same three-step
pattern: run synthetic smoke or parse configuration → run/validate → write report.

No shared dispatch table or command registry is used. Adding a new milestone command
requires inserting a new arm into this function.

**Why it matters:** The file is a maintenance hazard. The 720-line budget test
(`scopedCodeFilesStayWithinLineBudget`) already flags two files at 764 and 768 lines;
`MilestoneCommands.swift` at 610 lines is approaching that boundary.

**Suggested action:** Split into focused sub-dispatchers by domain area
(audio, video, network, timing, release). Wire them from a thin
`handleMilestoneCommand` that delegates by command prefix.

**What could break:** CLI command names and behavior must remain identical. This is
a structural refactor only. Risk is medium because the file is load-bearing.

**Verification needed:** `swift test --filter MilestoneCommandsTests` (if it exists);
otherwise, manual smoke of representative commands.

---

### DA-007

**Category:** Overcomplicated switch chain
**Location:** `Sources/open-lola/Commands/Network/NetworkCommands.swift`
**Risk:** Medium

**Evidence:**

380 lines, ~46 `case [...]` arms covering UDP-PCM routes, direct-P2P sessions,
connector sessions, network diagnostics, video transport, reference rig, and
more. Structural pattern is identical to DA-006.

**Suggested action:** Same approach as DA-006: split by sub-domain, delegate
from a thin dispatcher.

---

### DA-008

**Category:** Single-use production protocol — justified
**Location:** `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift:90`
**Risk:** Low

**Evidence:**

```swift
protocol ExternalConnectorProcessRunning: Sendable { ... }
struct RealExternalConnectorProcessRunner: ExternalConnectorProcessRunning { ... }
```

One production conformer. However, the protocol is injected in 6 test files via
`MockExternalConnectorProcessRunner` (in `ExternalConnectorProcessGroupTests.swift`,
`ExternalConnectorSessionTests.swift`, `LoopbackUdpPort+TestSupport.swift`).

**Why it is justified:** The protocol exists solely to enable deterministic
process-runner substitution in tests. This is a standard dependency-injection
pattern. The mock conformer has substantial test coverage.

**Suggested action:** Keep as-is. Document the intent in the protocol comment
if not already present.

---

### DA-009

**Category:** Parallel structure — connector launch-plan builders
**Location:** `Sources/OpenLolaCore/Connectors/JackTrip/JackTripLaunchPlan.swift` (176 lines),
`Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridLaunchPlan.swift` (200 lines)
**Risk:** Low

**Evidence:**

Both files implement the same structure:
1. `buildXxxPlan(configuration:)` — top-level entry point
2. `validateXxxTopology` — guard topology is valid
3. Argument assembly — connector-specific flags
4. `protocolFacts` — string array of compatibility notes
5. Return `ExternalConnectorLaunchPlan`

The shared contract `ExternalConnectorLaunchPlan` already exists in
`ExternalConnectorSession.swift:351`. The two builders share no base logic.

**Why it matters:** Any change to the launch-plan contract (new field, new validation
rule) must be applied to both files independently. A third connector would require
a third copy.

**What could break:** The two connectors have genuinely different argument structures;
a shared template abstraction would need to handle connector-specific variation cleanly.
Wrong abstraction here would make the code harder, not easier.

**Suggested action:** Investigate before acting. Check whether a shared validator
helper for `ExternalConnectorLaunchPlan` fields (not argument assembly) can be
extracted without forcing artificial generalization. Risk of over-engineering is real.

**Verification needed:** Needs runtime or git-history verification to confirm
no third connector is planned that would justify earlier abstraction.

---

### DA-010

**Category:** Underadopted shared abstraction
**Location:** `Sources/OpenLolaCore/Core/ValidationPrimitives.swift` (845 lines),
`ReportValidationProtocol` conformers
**Risk:** Medium

**Evidence:**

`ValidationPrimitives.swift` provides `ReportValidationProtocol` — a protocol
with generic static `requireXxx` methods covering all common validation patterns.
Only **2 of ~20+ report validator types** conform to it:
- `LatencyTuningValidator`
- `PerformanceAuditValidator`

All others use standalone free functions (see DA-005).

**Why it matters:** `ValidationPrimitives.swift` at 845 lines is one of the
largest files in the codebase but has near-zero adoption. It adds complexity
without delivering the deduplication it was designed to provide.

**Suggested action:** This finding is the root-cause context for DA-005.
Fix DA-005 (migrate module validators to `ReportValidationProtocol`) or
acknowledge that the pattern was tried and abandoned, and document why.

---

### DA-011

**Category:** Stale "prototype" name in public CLI surface
**Location:** `Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift`
**Risk:** Low

**Evidence:**

The file comment reads:
> "Keep 'prototype' in this aggregate report until a promoted non-prototype schema
> exists; the local supervisor and validator commands depend on this public name."

The CLI command name `direct-p2p-two-peer-prototype-report` is a public contract.
The schema is active (called from `NetworkCommands.swift:293-295`).

**Why it matters:** The word "prototype" in a shipped CLI command name creates
user confusion and suggests the report format is unstable. The constraint is
intentional but the exit condition is undefined.

**Suggested action:** Define the promotion criteria for `DirectPeerTwoPeerPrototypeReport`
in a doc or TODO comment. When criteria are met, plan the schema migration
with a deprecation cycle.

**Verification needed:** Needs schema review — determine if the struct has stabilized
enough to drop "prototype."

---

### DA-012

**Category:** Incomplete staged feature — not in CLI path
**Location:** `Sources/OpenLolaCore/Video/VideoTransportMultiStreamRuntime.swift`
**Risk:** Low

**Evidence:**

`VideoTransportRunner.swift` is the active CLI-facing runner:
`MilestoneCommands.swift:124` calls `VideoTransportRunner.run(configuration:)`.

`VideoTransportMultiStreamRuntime.swift` is referenced in:
- `GoalCodewiseClosure.swift` (staged capability)
- `SourceOwnershipInventory.swift` (listed as owned video source)
- `VideoControlDegradeMatrix.swift` (degradation matrix reference)

No CLI command calls `VideoTransportMultiStreamRuntime` directly.

**Why it matters:** The file is listed as staged in goal-closure evidence but
has no active CLI or app invocation path. Its status as "staged" vs "not yet
implemented" is UNCLEAR.

**Suggested action:** Add a comment to `VideoTransportMultiStreamRuntime.swift`
clarifying its readiness state and the promotion gate. If it is permanently
staged with no promotion path, mark it as such in the inventory.

**Verification needed:** Check `GoalCodewiseClosure.swift` for the exact
staging condition and whether it has a prerequisite milestone.

---

### DA-013

**Category:** Low-level HAL C API usage — no higher-level alternative available
**Location:** `Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift`,
`Sources/OpenLolaCore/Audio/Routing/AudioLoopbackHelpers.swift`,
`Sources/open-lola-app/AppReceiverPreviewServices.swift`
**Risk:** Low

**Evidence:**

All three files use `AudioObjectGetPropertyData` / `AudioObjectSetPropertyData` —
the Core Audio Hardware Abstraction Layer (HAL) C API. These are the correct
production APIs for device enumeration, UID lookup, and stream configuration
on macOS. They are not deprecated by Apple as of macOS 14/15.

**Why it matters:** The HAL C API has no safe Swift-native replacement for the
use cases in these files. The risk is in error handling: `AudioObjectGetPropertyData`
returns an `OSStatus` that must be checked. Weak error handling here would cause
silent misconfiguration at device I/O time.

**Suggested action:** Audit that every `AudioObjectGetPropertyData` /
`AudioObjectSetPropertyData` call checks the returned `OSStatus` and propagates
errors. Do not replace the API.

**Verification needed:** `grep -A2 "AudioObjectGetPropertyData\|AudioObjectSetPropertyData" Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift` — confirm `OSStatus` is checked.

---

## Summary

### 1. Highest-risk files

| File | Risk driver |
|------|-------------|
| `Sources/open-lola/Commands/MilestoneCommands.swift` | 610-line 62-arm switch; approaching line budget; every new milestone command widens blast radius |
| `Sources/open-lola/Commands/Network/NetworkCommands.swift` | 380-line ~46-arm switch; similar structural problem |
| `Sources/OpenLolaCore/Core/ValidationPrimitives.swift` | 845-line shared abstraction with ~2% adoption; represents significant unrealized deduplication |

### 2. Likely dead files

None identified with certainty. All source files have at least one active call
site or are listed in CLI command inventories.

**Likely dead symbol (not file):**
- `JSONReportCoder` typealias in `OpenLolaContractsAliases.swift` — 0 external call sites found.

### 3. Likely overcomplicated files

| File | Issue |
|------|-------|
| `Sources/open-lola/Commands/MilestoneCommands.swift` | 62-arm switch in one function |
| `Sources/open-lola/Commands/Network/NetworkCommands.swift` | ~46-arm switch in one function |
| `Sources/OpenLolaCore/Core/ValidationPrimitives.swift` | Elaborate protocol hierarchy with minimal adoption |
| `Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift` | 337 lines of ledger scaffolding for a documentation-only artifact; contains `@available(*, deprecated)` function and a trivial typealias |

### 4. Likely deprecated compatibility paths

| Item | Location | Evidence |
|------|----------|----------|
| Legacy `audioDeviceUID` CodingKey decode branch | `DirectPeerRealtimeAudioGraphTypes.swift:130` | `@available(*, deprecated)` marker; field migrated to `inputDeviceUID`/`outputDeviceUID` |
| Synthetic G16 parity ledger function | `LoLaParityDeferredFeatures.swift:216` | `@available(*, deprecated)` marker; replaced by `LoLaParityDeferredFixtures.partialLedger()` |
| `LoLaParityLedgerRunMode` typealias | `LoLaParityDeferredFeatures.swift:3` | Aliases `MeasurementMethodology` with no semantic difference; confirmed by test |

### 5. Recommended next audit targets

1. **DA-005 migration (highest value):** Pick one self-contained module (e.g. `RxBuffering.swift`)
   and migrate its `requireRxXxx` helpers to `ReportValidationProtocol`. Verify tests pass.
   If the migration is clean, proceed module by module.

2. **DA-001 verification:** Search fixture and config directories for any JSON containing
   `"audioDeviceUID"` key to determine if the legacy CodingKey branch can be deleted.

3. **DA-002 deletion:** Confirm `LoLaParityDeferredSyntheticSmoke` deprecated function
   has no active callers, then delete it.

4. **DA-003 deletion:** Delete `JSONReportCoder` alias line — zero-risk, zero call sites.

5. **DA-006 / DA-007 split:** The milestone and network command dispatchers will
   need splitting before they hit the 720-line budget threshold.

### 6. Coverage gaps and uncertainty

- **No runtime analysis performed.** All findings are static. A symbol with zero
  grep hits may still be reachable via reflection, `@_disfavoredOverload`, or
  runtime string dispatch.

- **Fixture/private JSON not scanned.** The `Tests/Fixtures/` and `private/`
  directories were not searched for saved JSON containing deprecated field names
  (DA-001). This is required before deleting the legacy CodingKey branch.

- **`OpenLolaContractsAliases.swift` — shim justification unclear.** Seven
  `OpenLolaCore` files already import `OpenLolaContracts` directly. Whether the
  aliases prevent a broader transitive-import problem (e.g. in the CLI or app
  targets) was not verified. Full removal of the aliases file requires checking
  all non-`OpenLolaCore` targets for transitive symbol resolution.

- **CoreAudio `OSStatus` error handling** in `CoreAudioInventoryReader.swift`,
  `AudioLoopbackHelpers.swift`, `AppReceiverPreviewServices.swift` was identified
  but not verified line-by-line (DA-013).

- **`VideoTransportMultiStreamRuntime.swift` promotion gate** is documented in
  `GoalCodewiseClosure.swift` but the precise prerequisite milestone was not
  fully read (DA-012).

- **`MilestoneCommands.swift` and `NetworkCommands.swift`:** The full arm list
  was counted but not cross-referenced against `CLICommandInventory.swift` to
  confirm every arm corresponds to a registered command. Unregistered arms would
  be dead code.
