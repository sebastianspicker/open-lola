# Source Audit

Date: 2026-05-05
Status: All source-folder batches implemented after read-only source audit
Verdict: PASS for source-folder restructuring; PARTIAL for real-world runtime evidence

This audit covers source code quality, naming, and structure for `Sources/`,
`Tests/`, `Package.swift`, and source-adjacent scripts that affect build,
test, CLI, release, or source ownership verification.

## Assumptions

- This checkout is not a Git worktree. `git status --short --branch` fails with
  `fatal: not a git repository (or any of the parent directories): .git`.
  Evidence is therefore filesystem- and command-based rather than diff-based.
- The initial audit phase made no source, test, package, or script changes.
  Later improvement phases implemented the structure batches from this file:
  release-readiness inventories, protocol/session contracts, Core Audio
  inventory, evidence/validator files, CLI command-family folders, and the
  remaining `OpenLolaCore` runtime/domain folders.
- Runtime behavior did not intentionally change during restructuring. Future
  behavior refactors still require an explicit implementation prompt.
- The existing `SourceOwnershipInventory` is authoritative starting evidence,
  but this audit still checks the live file layout and LOC pressure.
- Synthetic fixtures and localhost smokes remain structural evidence only. They
  must not be treated as real hardware or field evidence.

## Evidence Collected

| Evidence | Result |
|---|---|
| `git status --short --branch` | Not a Git repository. |
| `find Sources -type f -name '*.swift' -exec wc -l {} +` | 48,755 Swift LOC in source targets. |
| `find Tests -type f -name '*.swift' -exec wc -l {} +` | 18,315 Swift LOC in tests. |
| `find Sources/OpenLolaCore -maxdepth 1 -type f -name '*.swift'` | 0 root-level Swift files remain under `Sources/OpenLolaCore/`. |
| `find Sources/OpenLolaCore -maxdepth 3 -type d` | Domain folders now exist for `Audio/*`, `Benchmarks/*`, `Control`, `Core`, `Evidence`, `Integration`, `Network/*`, `Platform`, `Protocol`, `Release/Goal`, `Support/Inventories`, `Timing`, and `Video`. |
| `.build/debug/open-lola source-ownership-inventory` | 19 ownership groups, 1 moved group, 8 high-risk groups, `VERDICT: PARTIAL`; Batch 1 adds a physical folder move without changing the moved-in-C02 milestone count. |
| `Package.swift` inspection | One library target, two executable targets, no external SwiftPM dependencies. |
| `CodeLineBudgetTests.swift` inspection | Hard 550 LOC budget for Swift, Python, and shell files. |
| `CLICommandInventoryTests.swift` inspection | CLI command inventory is regex-checked against `Sources/open-lola`. |
| `ReportSchemaInventoryTests.swift` inspection | Validator commands, fixtures, synthetic smokes, owners, and tests are cross-checked. |

## Current Source Map

| Area | Current path shape | Evidence | Assessment |
|---|---|---|---|
| Package manifest | `Package.swift` | Swift tools 6.0, macOS 14, one `OpenLolaCore` target and two executable targets. | Simple and low dependency risk. |
| Core library | `Sources/OpenLolaCore/<domain>/` | 48,755 Swift LOC total across all sources at initial audit time; 0 Swift files now remain directly under `Sources/OpenLolaCore/`. | Folder ownership is corrected without splitting the SwiftPM target or changing behavior intentionally. |
| CLI executable | `Sources/open-lola/`, `Sources/open-lola/Commands/` | `main.swift`, domain command folders, ad hoc command output. | Existing command-family files are now under command ownership folders; broad milestone dispatcher is retained to avoid parser-order churn. |
| App executable | `Sources/open-lola-app/` | `OpenLolaApp.swift` only. | Clear boundary; keep UI separate from realtime ownership. |
| Source-adjacent scripts | `scripts/*.sh`, `scripts/verify_docs/*.py` | Release readiness calls docs, shellcheck, hygiene, build, test, and CLI probes. | Verification ownership is strong; Python docs verifier is outside runtime source. |

The current source target has this actual folder depth:

```text
Sources/
  OpenLolaCore/
    Audio/
      CoreAudio/
      MADI/
      Realtime/
      Routing/
    Benchmarks/
      E2E/
      Latency/
      Performance/
    Control/
    Core/
    Evidence/
    Integration/
    Network/
      Diagnostics/
      NAT/
      P2P/
      UDP/
    Platform/
    Protocol/
    Release/
      Goal/
    Support/
      Inventories/
    Timing/
    Video/
  open-lola/
    Commands/
      Audio/
      Benchmarks/
      Network/
      Validation/
  open-lola-app/
```

The source naming and folder structure now agree at the core-library boundary.
`Madi*`, `UdpPcm*`, `Nat*`, `Video*`, `Lighting*`, `Packaging*`, `Release*`,
and `Goal*` files no longer live directly under `Sources/OpenLolaCore/`.
Release-readiness inventory files moved to
`Sources/OpenLolaCore/Support/Inventories/` in Batch 1, protocol/session
contracts moved to `Sources/OpenLolaCore/Protocol/` in Batch 2, Core Audio
inventory files moved to `Sources/OpenLolaCore/Audio/CoreAudio/` in Batch 3,
evidence/validator files moved to `Sources/OpenLolaCore/Evidence/` in Batch 4,
existing CLI command-family files moved under `Sources/open-lola/Commands/` in
Batch 5, and the remaining runtime/domain files moved in the final
structure-only batch.

## Current Test Map

| Area | Current path shape | Evidence | Assessment |
|---|---|---|---|
| Unit and contract tests | `Tests/OpenLolaCoreTests/*.swift` | 18,315 Swift LOC. | Broad coverage, but flat source-adjacent test namespace mirrors the old flat library. |
| Fixtures | `Tests/OpenLolaCoreTests/Fixtures/<ReportFamily>/...` | Many fixture families by report/schema domain. | Fixture folder structure is clearer than the source folder structure. |
| Structure tests | `CodeLineBudgetTests.swift`, `SourceOwnershipInventoryTests.swift` | 550 LOC guard and ownership/source/test/doc path checks. | Strong guardrails for incremental moves. |
| CLI inventory tests | `CLICommandInventoryTests.swift` | Discovers commands with source regexes. | Useful contract, but brittle if command parsing structure changes. |
| Schema inventory tests | `ReportSchemaInventoryTests.swift` | 44 schemas, validator command coverage, fixture/smoke linkage. | Strong evidence boundary guard. |

## Ownership And Grouping Table

This table condenses the live `source-ownership-inventory` command.

| Group | Current state | Proposed path | Risk | Next action |
|---|---|---|---|---|
| `coreSupport` | Moved to `Sources/OpenLolaCore/Core/` | `Sources/OpenLolaCore/Core/` | Low | Complete; keep hardware logic out. |
| `protocolSession` | Moved to `Sources/OpenLolaCore/Protocol/` | `Sources/OpenLolaCore/Protocol/` | Medium | Batch 2 complete; keep session negotiation and packet metadata traceable. |
| `audioCoreAudio` | Moved to `Sources/OpenLolaCore/Audio/CoreAudio/` | `Sources/OpenLolaCore/Audio/CoreAudio/` | Medium | Batch 3 complete; keep platform inventory paths synchronized with fixtures and CLI inventory. |
| `audioMadiRme` | Moved to `Sources/OpenLolaCore/Audio/MADI/` | `Sources/OpenLolaCore/Audio/MADI/` | High | Complete for structure; behavior/hardware boundary semantics unchanged. |
| `audioRealtime` | Moved to `Sources/OpenLolaCore/Audio/Realtime/` | `Sources/OpenLolaCore/Audio/Realtime/` | High | Complete for structure; callback and latency behavior unchanged. |
| `audioRouting` | Moved to `Sources/OpenLolaCore/Audio/Routing/` | `Sources/OpenLolaCore/Audio/Routing/` | Medium | Complete for structure; receiver-mix ownership remains documented as routing. |
| `networkUdp` | Moved to `Sources/OpenLolaCore/Network/UDP/` | `Sources/OpenLolaCore/Network/UDP/` | High | Complete for structure; packet formats and CLI behavior unchanged. |
| `networkP2P` | Moved to `Sources/OpenLolaCore/Network/P2P/` | `Sources/OpenLolaCore/Network/P2P/` | High | Complete for structure; route semantics unchanged. |
| `networkNat` | Moved to `Sources/OpenLolaCore/Network/NAT/` | `Sources/OpenLolaCore/Network/NAT/` | High | Complete for structure; kept separate from fastest direct route proof. |
| `networkDiagnosticsAoip` | Moved to `Sources/OpenLolaCore/Network/Diagnostics/` | `Sources/OpenLolaCore/Network/Diagnostics/` | Medium | Complete for structure; diagnostics remain separate from route proof. |
| `timingLatencyBuffering` | Moved to `Sources/OpenLolaCore/Timing/` with latency benchmark reports under `Benchmarks/Latency/` | `Sources/OpenLolaCore/Timing/` | Medium | Complete for structure; behavioral split of clock/drift/profiles/buffering deferred. |
| `videoCaptureTransport` | Moved to `Sources/OpenLolaCore/Video/` | `Sources/OpenLolaCore/Video/` | High | Complete for structure; video/control matrix remains the guard. |
| `controlLightingAtemOsc` | Moved to `Sources/OpenLolaCore/Control/` | `Sources/OpenLolaCore/Control/` | High | Complete for structure; read-only/destructive-control safeguards must stay visible. |
| `evidenceReportsValidation` | Moved to `Sources/OpenLolaCore/Evidence/` | `Sources/OpenLolaCore/Evidence/` | Medium | Batch 4 complete; keep measured-evidence policy explicit. |
| `benchmarksPerformance` | Moved under `Sources/OpenLolaCore/Benchmarks/` | `Sources/OpenLolaCore/Benchmarks/` | Medium | Complete for structure; kept separate from release proof policy files. |
| `releaseProofPackaging` | Moved to `Sources/OpenLolaCore/Release/` with goal ledgers under `Release/Goal/` | `Sources/OpenLolaCore/Release/` | High | Complete for structure; signing, clean-Mac, and real field proof semantics unchanged. |
| `platformAppShell` | Moved to `Sources/OpenLolaCore/Platform/` | `Sources/OpenLolaCore/Platform/` | Medium | Complete for structure; app-shell contracts remain separate from SwiftUI presentation. |
| `cliApplication` | Existing command-family files moved under `Sources/open-lola/Commands/` | `Sources/open-lola/Commands/` | Medium | Batch 5 complete for folder ownership; milestone dispatcher split remains a later behavior-sensitive cleanup. |
| `releaseReadinessInventories` | Moved to `Sources/OpenLolaCore/Support/Inventories/` | `Sources/OpenLolaCore/Support/Inventories/` | Low | Batch 1 complete; keep runtime code out. |

## Naming Problems

1. `OpenLolaCore` file names encode domains, but folder names mostly do not.
   Names such as `UdpPcmRouteCertification`, `MadiFullDuplexRuntime`,
   `VideoTransportRunner`, and `PackagingFieldTest` are distinct individually,
   but lose navigability in the flat directory.
2. The `Report`, `Run`, `Validation`, `Helpers`, and `SyntheticSmoke` suffixes
   are useful but repeated across unrelated domains. Without folders, the
   suffix taxonomy does not reveal ownership.
3. `MilestoneCommands.swift` is too broad as a command-family name. It routes
   video, integrated A/V, hardware validation, OSC, ATEM, lighting, app,
   recording, packaging, field proof, faster-than-LoLa, and release hardening.
4. `NetworkCommands.swift` mixes device inventory, route validation, UDP PCM,
   NAT, relay, diagnostics, and direct P2P session commands.
5. Several configuration parsers duplicate the same "allowed argument, duplicate
   argument, missing value, typed conversion" shape under different names.
   Examples include `AudioLoopbackRunConfiguration`,
   `UdpPcmRouteRunConfiguration`, `VideoCaptureRunConfiguration`,
   `MadiFullDuplexCommandRun`, and direct P2P parser code in
   `NetworkCommands.swift`.
6. Six source files use `try!`: `SessionProfileBenchmark.swift`,
   `LatencyProfileContracts.swift`, `RealtimeAudioEngineSyntheticSmoke.swift`,
   `LatencyBenchmarkSyntheticSmoke.swift`, and `DriftPlcRun.swift`. Some are
   likely bounded fixture builders, but the names do not make the invariant
   obvious at call sites.

## Folder-Structure Problems

1. `Sources/OpenLolaCore/` no longer holds Swift files directly. The remaining
   structure question is whether this single SwiftPM target should eventually
   split pure protocol/evidence code from media-framework code.
2. Tests are still flat under `Tests/OpenLolaCoreTests/` even though fixtures are
   already grouped by schema/report family.
3. The SwiftPM package still uses one library target for all domains. This keeps
   setup simple, but it also links AVFoundation, CoreAudio, and CoreMedia at the
   full-core target boundary.
4. The source/test/doc crosswalk exists in code, but not in a root audit handoff
   before this file. Future agents could otherwise mistake archived review docs
   for active implementation instructions.
5. CLI command routing has source-level tests and command-family folders, but
   `MilestoneCommands.swift` remains intentionally broad to avoid parser-order
   churn in a structure-only pass.

## Prioritized Findings

### P1: SwiftPM Target Boundary Still Blurs Ownership

The original flat-folder issue is corrected: `Sources/OpenLolaCore/` has no
root-level Swift files. The remaining structural issue is target-level rather
than folder-level. The live inventory knows 19 groups, but the package still
builds them all through one `OpenLolaCore` target.

Evidence:
- `find Sources/OpenLolaCore -maxdepth 1 -type f -name '*.swift'` returns 0.
- `find Sources/OpenLolaCore -maxdepth 3 -type d` shows domain folders for all
  source ownership groups.
- `source-ownership-inventory` still reports `groupCount: 19`; the C02
  `movedInC02Count` metric remains a milestone metric, not a generic folder
  completion metric.

Recommendation: keep the existing single SwiftPM target until a Git-backed,
behavior-aware target split is explicitly requested. Treat that as architecture
work, not a continuation of folder cleanup.

### P1: Near-Budget Files Create Review Risk

The 550 LOC guard passes, but several files are close enough that normal feature
work can push them over the threshold:

| File | LOC |
|---|---:|
| `Sources/OpenLolaCore/Support/Inventories/NetworkRouteCommandMatrix.swift` | 550 |
| `Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift` | 548 |
| `Sources/OpenLolaCore/Network/Diagnostics/AoipEvaluationReport.swift` | 547 |
| `Sources/OpenLolaCore/Control/OscCueProbe.swift` | 546 |
| `Sources/OpenLolaCore/Release/Goal/GoalRuntimePreflight.swift` | 536 |
| `Sources/OpenLolaCore/Release/FieldReadyRuntimeProof.swift` | 527 |
| `Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift` | 527 |
| `Sources/OpenLolaCore/Video/VideoTransportPacket.swift` | 527 |
| `Sources/OpenLolaCore/Timing/RxBuffering.swift` | 525 |

Recommendation: split only when a future edit would otherwise modify these
files. Do not split for aesthetics alone.

### P1: CLI Command Dispatcher Is Still Broad For Safe Review

`Sources/open-lola/Commands/MilestoneCommands.swift` still owns many unrelated
runtime surfaces. The existing command inventory catches missing command
entries, and Batch 5 moved command-family files under `Commands/`, but review
still has to scan a broad milestone dispatcher.

Recommendation: split the milestone dispatcher by ownership domain only in a
dedicated command-parser batch that keeps parser order and CLI inventory checks
as the primary acceptance criteria.

### P2: Parser Logic Is Repeated Across Command And Run Configuration Surfaces

Many command/configuration parsers repeat flag scanning, duplicate detection,
missing-value handling, and typed conversion. This is a maintainability issue,
not a behavior bug.

Recommendation: after folder moves, consider a tiny internal
`ArgumentParsing/FlagParser.swift` helper only if it removes repeated parsing
code from at least three actively maintained command surfaces. Do not introduce
this before source moves, because it would couple unrelated batches.

### P2: Tests Mirror Old Flat Source Layout

Tests are broad and strong, but the folder layout is mostly flat. This makes it
harder to review future source moves because the test target does not show the
same ownership shape as fixtures and inventories.

Recommendation: move tests in parallel with source groups only after the source
paths are stable. For early batches, update `SourceOwnershipInventory` and keep
tests flat to reduce risk.

### P2: Target-Wide Framework Linkage Blurs Core Boundaries

`OpenLolaCore` links AVFoundation, CoreAudio, and CoreMedia for the full target.
That is currently simpler than multi-target restructuring, but it means pure
protocol, evidence, and CLI inventory code lives in a target with media
framework linkage.

Recommendation: do not split SwiftPM targets now. Revisit only after folders
are stable and the package has Git-backed change tracking.

### P3: `try!` Appears In Bounded Fixture/Synthetic Paths

The six `try!` instances appear in deterministic benchmark/smoke/report builder
paths, not arbitrary runtime parsing. Still, the invariant is not always visible
at the call site.

Recommendation: leave unchanged for now. If any of those files are edited for
other reasons, replace `try!` with small throwing builders or test-only
precondition helpers where the validation failure can be reported cleanly.

### P3: No Confirmed Dead Code In This Read-Only Pass

This audit did not prove any source file, public type, CLI command, validator,
or fixture family to be dead. The existing command, schema, fixture, and source
ownership inventories actively reduce dead-code risk by checking command
discovery, validator coverage, owner files, related tests, and fixture/smoke
links.

Limit: this was not a whole-program reachability analysis. Swift public API
reachability, test-only helpers, and future hardware-only paths cannot be
classified as dead from grep-style evidence alone.

Recommendation: do not delete source in a structure-only batch. If dead-code
cleanup is requested later, start with an explicit symbol inventory and require
`swift test`, `command-inventory`, `report-schema-inventory`, and the relevant
CLI smoke to prove removal is safe.

## Finding Classes

### Safe Mechanical Moves

Completed structure-only moves:

- `releaseReadinessInventories` -> `Sources/OpenLolaCore/Support/Inventories/`
- `protocolSession` -> `Sources/OpenLolaCore/Protocol/`
- `audioCoreAudio` -> `Sources/OpenLolaCore/Audio/CoreAudio/`
- `evidenceReportsValidation` -> `Sources/OpenLolaCore/Evidence/`
- CLI command families -> `Sources/open-lola/Commands/*`
- remaining core runtime/domain groups -> `Audio/*`, `Network/*`, `Timing`,
  `Video`, `Control`, `Benchmarks/*`, `Release`, `Release/Goal`, `Platform`,
  and `Integration`

These moves were kept behavior-neutral and paired with inventory/docs/test path
updates.

### Behavior-Neutral Naming Improvements

- Rename the broad milestone CLI dispatcher only after folder moves:
  `Sources/open-lola/Commands/MilestoneCommands.swift` -> domain command files
  under `Sources/open-lola/Commands/`.
- Rename parser helper functions only if a shared parser helper is introduced
  later.
- Prefer domain folder names over longer file names. Do not rename stable public
  report/schema types without a behavior-change prompt.

### Risky Runtime Refactors

- Changing behavior inside `audioMadiRme`, `audioRealtime`, `networkUdp`,
  `networkP2P`, `networkNat`, `videoCaptureTransport`,
  `controlLightingAtemOsc`, or `releaseProofPackaging` while presenting the work
  as structure-only.
- Splitting SwiftPM targets before folder-level ownership has settled.
- Introducing a generic argument parser before measuring real duplication in
  the post-folder structure.
- Any change that touches realtime audio callback behavior, packet formats,
  socket runtimes, video scheduling, ATEM/lighting safety, packaging gates, or
  false-PASS validators while claiming to be "structure only".

### Items Requiring Human Or Domain Decision

- TODO(human): [Audio routing ownership] -> Decide whether `ReceiverMixSnapshot` belongs under MADI, generic routing, or realtime audio before moving `audioRouting` -> [MADI-owned / generic Audio/Routing / defer]
- TODO(human): [SwiftPM target split] -> Decide whether long-term architecture should keep one `OpenLolaCore` target or split pure protocol/evidence from media framework code -> [single target / staged multi-target / defer until Git worktree]
- TODO(human): [Test folder mirroring] -> Decide whether tests should mirror source folders after the first source restructuring wave -> [flat tests with inventory / mirrored folders / defer]
- TODO(human): [CLI argument parser] -> Decide whether repeated command parsing justifies a tiny internal parser helper after command files are split -> [add helper / keep local parsers / defer]

## Proposed Target Folder Structure

Keep SwiftPM target names unchanged in the first restructuring wave.

```text
Sources/
  OpenLolaCore/
    Core/
    Protocol/
    Audio/
      CoreAudio/
      MADI/
      Realtime/
      Routing/
    Network/
      UDP/
      P2P/
      NAT/
      Diagnostics/
    Timing/
    Video/
    Control/
    Evidence/
    Benchmarks/
      E2E/
      Latency/
      Performance/
    Release/
      Goal/
    Platform/
    Integration/
    Support/
      Inventories/
  open-lola/
    Commands/
      Audio/
      Network/
      Benchmarks/
      Video/
      Control/
      Release/
      Validation/
  open-lola-app/
```

Potential later test shape:

```text
Tests/
  OpenLolaCoreTests/
    Core/
    Protocol/
    Audio/
    Network/
    Timing/
    Video/
    Control/
    Evidence/
    Benchmarks/
    Release/
    Platform/
    CLI/
    Fixtures/
```

Do not move fixtures until the source/test path churn has settled.

## Migration Batches

### Batch 0: Audit Only

Status: this document.

Files:
- `SOURCE_AUDIT.md`

Validation:
- `bash scripts/verify-docs.sh`
- `shellcheck scripts/*.sh`

Rollback:
- Delete `SOURCE_AUDIT.md`.

### Batch 1: Move Release-Readiness Inventories

Status: implemented.

Scope:
- Move inventory-only files to `Sources/OpenLolaCore/Support/Inventories/`.
- Update `SourceOwnershipInventory.swift`, affected tests, and docs references.

Candidate files:
- `Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift`
- `Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrix.swift`
- `Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift`
- `Sources/OpenLolaCore/Support/Inventories/RealtimeAudioPathInventory.swift`
- `Sources/OpenLolaCore/Support/Inventories/NetworkRouteCommandMatrix.swift`
- `Sources/OpenLolaCore/Support/Inventories/VideoControlDegradeMatrix.swift`
- `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift`
- `ReportSchemaInventory.swift` was not moved; it remains reserved for the
  later `Evidence/` batch.

Validation matrix:
- `swift test --filter SourceOwnershipInventoryTests`
- `swift test --filter CLICommandInventoryTests`
- `swift test --filter FixtureSmokeMatrixTests`
- `swift test --filter RealtimeAudioPathInventoryTests`
- `swift test --filter NetworkRouteCommandMatrixTests`
- `swift test --filter VideoControlDegradeMatrixTests`
- `swift test --filter ReportSchemaInventoryTests`
- `swift test --filter CodeLineBudgetTests`
- `swift build`
- `.build/debug/open-lola source-ownership-inventory`
- `.build/debug/open-lola command-inventory`
- `.build/debug/open-lola report-schema-inventory`
- `bash scripts/verify-docs.sh`
- `shellcheck scripts/*.sh`

Rollback:
- Move files back to `Sources/OpenLolaCore/`.
- Restore path strings in `SourceOwnershipInventory.swift`, tests, and docs.
- Rerun the same validation matrix.

### Batch 2: Move Protocol Session Contracts

Status: implemented.

Scope:
- Move session negotiation and protocol contracts to
  `Sources/OpenLolaCore/Protocol/`.

Candidate files:
- `Sources/OpenLolaCore/Protocol/SessionControlMessage.swift`
- `Sources/OpenLolaCore/Protocol/SessionProtocol.swift`
- `Sources/OpenLolaCore/Protocol/SessionNegotiation.swift`

Validation matrix:
- `swift test --filter SessionProtocolTests`
- `swift test --filter SessionNegotiationTests`
- `swift test --filter CLICommandInventoryTests`
- `swift test --filter SourceOwnershipInventoryTests`
- `swift test --filter CodeLineBudgetTests`
- `swift build`
- `.build/debug/open-lola session-capabilities`
- `bash scripts/verify-docs.sh`
- `shellcheck scripts/*.sh`

Rollback:
- Move files back to `Sources/OpenLolaCore/`.
- Restore source ownership paths.
- Rerun validation.

### Batch 3: Move Core Audio Inventory

Status: implemented.

Scope:
- Move platform inventory and stream descriptions to
  `Sources/OpenLolaCore/Audio/CoreAudio/`.

Candidate files:
- `Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventory.swift`
- `Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift`
- `Sources/OpenLolaCore/Audio/CoreAudio/AudioStreamDescription.swift`

Validation matrix:
- `swift test --filter CoreAudioInventoryTests`
- `swift test --filter SourceOwnershipInventoryTests`
- `swift test --filter CLICommandInventoryTests`
- `swift test --filter CodeLineBudgetTests`
- `swift build`
- `.build/debug/open-lola device-inventory`
- `bash scripts/verify-docs.sh`
- `shellcheck scripts/*.sh`

Rollback:
- Move files back to `Sources/OpenLolaCore/`.
- Restore path references.
- Rerun validation.

### Batch 4: Move Evidence And Validators

Status: implemented.

Scope:
- Move report validator, schema inventory, measurement report, reference rig,
  and hardware validation source to `Sources/OpenLolaCore/Evidence/`.

Candidate files:
- `Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift`
- `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`
- `Sources/OpenLolaCore/Evidence/MeasurementReport.swift`
- `Sources/OpenLolaCore/Evidence/ReferenceRigReport.swift`
- `Sources/OpenLolaCore/Evidence/ReferenceRigHelpers.swift`
- `Sources/OpenLolaCore/Evidence/ReferenceRigReportValidation.swift`
- `Sources/OpenLolaCore/Evidence/HardwareValidationReport.swift`
- `Sources/OpenLolaCore/Evidence/HardwareValidationRun.swift`

Validation matrix:
- `swift test --filter ReportSchemaInventoryTests`
- `swift test --filter MeasurementReportFixtureTests`
- `swift test --filter ReferenceRigReportTests`
- `swift test --filter HardwareValidationReportTests`
- `swift test --filter SourceOwnershipInventoryTests`
- `swift test --filter CodeLineBudgetTests`
- `swift build`
- `.build/debug/open-lola report-schema-inventory`
- `.build/debug/open-lola validate-reference-rig-report Tests/OpenLolaCoreTests/Fixtures/ReferenceRigReports/valid/reference-rig-partial.json`
- `bash scripts/verify-docs.sh`
- `shellcheck scripts/*.sh`

Rollback:
- Move files back and restore inventory paths.
- Rerun validation.

### Batch 5: Split CLI Commands By Domain

Status: implemented for command-folder ownership. The broad milestone
dispatcher remains a single file to keep this batch behavior-neutral.

Scope:
- Create `Sources/open-lola/Commands/`.
- Move command files by domain without changing parser behavior.

Implemented grouping:
- `Commands/Network/NetworkCommands.swift`
- `Commands/Audio/MadiReceiveCommands.swift`
- `Commands/Audio/MadiFullDuplexCommands.swift`
- `Commands/Audio/LatencyProfileCommands.swift`
- `Commands/Benchmarks/PerformanceCommands.swift`
- `Commands/Benchmarks/E2EBenchmarkCommands.swift`
- `Commands/MilestoneCommands.swift`
- `Commands/Validation/MilestoneValidationCommands.swift`
- `Commands/CLICommandHelpers.swift`

Validation matrix:
- `swift test --filter CLICommandInventoryTests`
- `swift test --filter SourceOwnershipInventoryTests`
- `swift test --filter CodeLineBudgetTests`
- `swift build`
- `.build/debug/open-lola command-inventory`
- `.build/debug/open-lola source-ownership-inventory`
- `bash scripts/verify-release-readiness.sh`

Rollback:
- Move command files back to `Sources/open-lola/`.
- Restore path references in inventories.
- Rerun validation.

### Batch 6: Move Remaining Core Runtime And Domain Files

Status: implemented.

Scope:
- Move the remaining root-level Swift files out of `Sources/OpenLolaCore/`.
- Preserve one SwiftPM target and behavior.
- Keep path updates mechanical across inventories, docs, tests, and audit
  artifacts.

Implemented grouping:
- `Sources/OpenLolaCore/Audio/MADI/`
- `Sources/OpenLolaCore/Audio/Realtime/`
- `Sources/OpenLolaCore/Audio/Routing/`
- `Sources/OpenLolaCore/Network/UDP/`
- `Sources/OpenLolaCore/Network/P2P/`
- `Sources/OpenLolaCore/Network/NAT/`
- `Sources/OpenLolaCore/Network/Diagnostics/`
- `Sources/OpenLolaCore/Timing/`
- `Sources/OpenLolaCore/Video/`
- `Sources/OpenLolaCore/Control/`
- `Sources/OpenLolaCore/Benchmarks/E2E/`
- `Sources/OpenLolaCore/Benchmarks/Latency/`
- `Sources/OpenLolaCore/Benchmarks/Performance/`
- `Sources/OpenLolaCore/Release/`
- `Sources/OpenLolaCore/Release/Goal/`
- `Sources/OpenLolaCore/Platform/`
- `Sources/OpenLolaCore/Integration/`

Validation matrix:
- `find Sources/OpenLolaCore -maxdepth 1 -type f -name '*.swift'`
- stale flat source path search across `Sources`, `Tests`, `docs`, `mac-port`,
  `README.md`, `MAC_PORT_PLAN.md`, `GOAL.md`, and this audit.
- focused domain tests for audio, network, timing, video, control, benchmark,
  integration, platform, release, ownership, schema, and LOC surfaces.
- full `swift test`
- `swift build`
- `.build/debug/open-lola source-ownership-inventory`
- `.build/debug/open-lola report-schema-inventory`
- `.build/debug/open-lola command-inventory`
- `.build/debug/open-lola fixture-smoke-matrix`
- `.build/debug/open-lola network-route-command-matrix`
- `.build/debug/open-lola video-control-degrade-matrix`
- `.build/debug/open-lola realtime-audio-path-inventory`
- `.build/debug/open-lola goal-codewise-closure`
- `bash scripts/verify-docs.sh`
- `shellcheck scripts/*.sh`
- `bash scripts/verify-release-readiness.sh`

Rollback:
- Move files back to `Sources/OpenLolaCore/`.
- Restore path references in inventories, docs, tests, and audit artifacts.
- Rerun the same validation matrix.

### Deferred Behavior And Target Batches

Do not start these until explicitly requested:

- behavior changes inside realtime audio, network packet/route handling, video
  scheduling, control-surface safety, packaging, release, or validator policy
- SwiftPM target splitting
- mirrored test folder restructuring
- generic command argument parser extraction

Each deferred batch requires its own source/test/doc crosswalk and domain
surface probe before code changes.

## Exact Audit Verification Matrix

Run these after this audit artifact is created:

```bash
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
swift test --filter SourceOwnershipInventoryTests
swift test --filter CodeLineBudgetTests
swift test --filter CLICommandInventoryTests
swift test --filter ReportSchemaInventoryTests
swift build
```

If SwiftPM fails with `sandbox-exec: sandbox_apply: Operation not permitted`,
rerun the SwiftPM command outside the sandbox and record that explicitly.

## Verification Results

Executed on 2026-05-05 after creating this artifact:

| Command | Result |
|---|---|
| `bash scripts/verify-docs.sh` | PASS; documentation contract accepted `SOURCE_AUDIT.md` in the active Markdown inventory. |
| `shellcheck scripts/*.sh` | PASS. |
| `swift test --filter SourceOwnershipInventoryTests` | PASS; 6 tests passed. |
| `swift test --filter CodeLineBudgetTests` | PASS; 1 test passed. |
| `swift test --filter CLICommandInventoryTests` | PASS; 5 tests passed. |
| `swift test --filter ReportSchemaInventoryTests` | PASS; 8 tests passed. |
| `swift build` | Initial sandboxed run failed with `sandbox-exec: sandbox_apply: Operation not permitted`; unsandboxed rerun passed. |

Executed on 2026-05-05 after implementing Batch 1:

| Command | Result |
|---|---|
| `rg` stale flat inventory paths | PASS; no references to the old flat inventory source paths remain in `Sources`, `Tests`, `docs`, `mac-port`, or this audit. |
| `swift test --filter SourceOwnershipInventoryTests` | PASS; 6 tests passed. |
| `swift test --filter CLICommandInventoryTests` | PASS; 5 tests passed. |
| `swift test --filter FixtureSmokeMatrixTests` | PASS; 5 tests passed. |
| `swift test --filter RealtimeAudioPathInventoryTests` | PASS; 4 tests passed. |
| `swift test --filter NetworkRouteCommandMatrixTests` | PASS; 5 tests passed. |
| `swift test --filter VideoControlDegradeMatrixTests` | PASS; 6 tests passed. |
| `swift test --filter ReportSchemaInventoryTests` | PASS; 8 tests passed. |
| `swift test --filter CodeLineBudgetTests` | PASS; 1 test passed. |
| `swift test` | PASS; 767 tests passed. |
| `shellcheck scripts/*.sh` | PASS. |
| `swift build` | Initial sandboxed run failed with `sandbox-exec: sandbox_apply: Operation not permitted`; unsandboxed rerun passed. |
| `.build/debug/open-lola source-ownership-inventory` | PASS; command ran and returned the expected source-ownership `VERDICT: PARTIAL`. |
| `.build/debug/open-lola command-inventory` | PASS; command ran and returned the expected command-inventory `VERDICT: PARTIAL`. |
| `.build/debug/open-lola report-schema-inventory` | PASS; command ran and returned the expected schema-inventory `VERDICT: PARTIAL`. |
| `bash scripts/verify-docs.sh` | PASS. |

Executed on 2026-05-05 after implementing Batch 4:

| Command | Result |
|---|---|
| `rg` stale flat evidence paths | PASS; no references to the old flat evidence source paths remain in `Sources`, `Tests`, `docs`, `mac-port`, or this audit. |
| `swift test --filter ReportSchemaInventoryTests` | PASS; 8 tests passed. |
| `swift test --filter MeasurementReportFixtureTests` | PASS; 6 tests passed. |
| `swift test --filter ReferenceRigReportTests` | PASS; 11 tests passed. |
| `swift test --filter HardwareValidationReportTests` | PASS; 12 tests passed. |
| `swift test --filter SourceOwnershipInventoryTests` | PASS; 6 tests passed. |
| `swift test --filter FixtureSmokeMatrixTests` | PASS; 5 tests passed. |
| `swift test --filter GoalCodewiseClosureTests` | PASS; 7 tests passed. |
| `swift test --filter CodeLineBudgetTests` | PASS; 1 test passed. |
| `swift test` | PASS; 767 tests passed. |
| `shellcheck scripts/*.sh` | PASS. |
| `swift build` | Initial sandboxed run failed with `sandbox-exec: sandbox_apply: Operation not permitted`; unsandboxed rerun passed. |
| `.build/debug/open-lola report-schema-inventory` | PASS; command ran and returned the expected schema-inventory `VERDICT: PARTIAL` with moved `Evidence/` paths. |
| `.build/debug/open-lola validate-reference-rig-report Tests/OpenLolaCoreTests/Fixtures/ReferenceRigReports/valid/reference-rig-partial.json` | PASS; command ran and returned the expected `VERDICT: PARTIAL`. |
| `bash scripts/verify-docs.sh` | PASS. |

Executed on 2026-05-05 after implementing Batches 2, 3, and 5:

| Command | Result |
|---|---|
| `rg` stale Batch 2/3/5 flat paths | PASS; no references to the old protocol, Core Audio inventory, or CLI command source paths remain in `Sources`, `Tests`, `docs`, `mac-port`, or this audit. |
| `swift test --filter SessionProtocolTests` | PASS; 7 tests passed. |
| `swift test --filter SessionNegotiationTests` | PASS; 13 tests passed. |
| `swift test --filter CoreAudioInventoryTests` | PASS; 7 tests passed. |
| `swift test --filter CLICommandInventoryTests` | PASS; 5 tests passed. |
| `swift test --filter SourceOwnershipInventoryTests` | PASS; 6 tests passed. |
| `swift test --filter CodeLineBudgetTests` | PASS; 1 test passed. |
| `swift test --filter FixtureSmokeMatrixTests` | PASS; 5 tests passed. |
| `swift test --filter NetworkRouteCommandMatrixTests` | PASS; 5 tests passed. |
| `swift test --filter ReportSchemaInventoryTests` | PASS; 8 tests passed. |
| `swift test --filter VideoControlDegradeMatrixTests` | PASS; 6 tests passed. |
| `swift test --filter GoalCodewiseClosureTests` | PASS; 7 tests passed. |
| `swift test` | PASS; 767 tests passed. |
| `swift build` | Initial sandboxed run failed with `sandbox-exec: sandbox_apply: Operation not permitted`; unsandboxed rerun passed. |
| `.build/debug/open-lola session-capabilities` | PASS; command ran and returned `VERDICT: PASS`. |
| `.build/debug/open-lola device-inventory` | PARTIAL; command reached the moved CLI/Core Audio surface but this host returned `open-lola: noDevices`. |
| `.build/debug/open-lola command-inventory` | PASS; command ran and returned the expected command-inventory `VERDICT: PARTIAL` with `Commands/` owner paths. |
| `.build/debug/open-lola source-ownership-inventory` | PASS; command ran and returned the expected source-ownership `VERDICT: PARTIAL` with moved Protocol, CoreAudio, and CLI paths. |
| `bash scripts/verify-docs.sh` | PASS. |
| `bash scripts/verify-release-readiness.sh` | Initial sandboxed run failed at its internal `swift build` with `sandbox-exec: sandbox_apply: Operation not permitted`; unsandboxed rerun passed and ended with `VERDICT: PASS`. |
| `shellcheck scripts/*.sh` | PASS. |

Executed on 2026-05-05 after implementing Batch 6:

| Command | Result |
|---|---|
| `find Sources/OpenLolaCore -maxdepth 1 -type f -name '*.swift' \| wc -l` | PASS; result is 0. |
| `rg "Sources/OpenLolaCore/[A-Za-z0-9]+\\.swift" Sources Tests docs mac-port SOURCE_AUDIT.md README.md MAC_PORT_PLAN.md GOAL.md` | PASS; no stale flat source path references found. |
| Focused audio/network domain tests | PASS; `Madi`, `RmeFastestAudioPathTests`, `RealtimeAudio`, `Udp`, `PeerSessionRunnerTests`, `NatFriendlyRouteTests`, `NetworkDiagnosticsTests`, `AoipEvaluationReportTests`, and `NetworkAoipCertification` passed. Initial sandboxed SwiftPM run failed with `sandbox-exec: sandbox_apply: Operation not permitted`; unsandboxed rerun passed. |
| Focused video/control/integration/platform/release/benchmark/inventory tests | PASS; all selected filters passed, including `Video`, `OscCueReportTests`, `LightingFixtureGateTests`, `Integrated`, `NativeAppShellTests`, release/packaging/field/recording filters, benchmark/latency filters, inventory filters, `GoalCodewiseClosureTests`, and `CodeLineBudgetTests`. |
| `swift test` | PASS; 767 tests passed. |
| `swift build` | PASS; unsandboxed run passed after the earlier SwiftPM sandbox limitation. |
| `bash scripts/verify-docs.sh` | PASS. |
| `shellcheck scripts/*.sh` | PASS. |
| `bash scripts/verify-release-readiness.sh` | PASS; ended with `VERDICT: PASS`. |
| CLI probes | PASS for command execution: `source-ownership-inventory` 19 groups, `command-inventory` 128 commands, `report-schema-inventory` 44 schemas, `fixture-smoke-matrix` 28 fixture groups, `network-route-command-matrix` 25 entries, `video-control-degrade-matrix` 9 entries, `realtime-audio-path-inventory` 25 entries, and `goal-codewise-closure` ran. Product-level verdicts remain intentionally `PARTIAL` where real hardware or field evidence is unavailable. |

## Completion Checklist

| Requirement | Evidence |
|---|---|
| Source code only scope | Audit covers `Sources/`, `Tests/`, `Package.swift`, and verification scripts only. |
| Initial no-source audit respected | The audit phase created only this artifact; later improvement phases changed only Batch 1, 2, 3, 4, and 5 source/doc paths. |
| Git worktree verified | `git status` failure recorded. |
| Quality issues identified | See prioritized findings and naming/structure sections. |
| Dead-code risk addressed | No confirmed dead code was proven; deletion is deferred to a dedicated reachability pass. |
| Structural issues identified | Flat core, flat tests, broad CLI files, one target, path crosswalk issues. |
| Distinct target folder structure implemented | See current source map and Batch 6. |
| Findings separated by class | Safe moves, naming improvements, risky refactors, human decisions. |
| No broad rewrite proposed | Batches are mechanical and incremental. |
| Assumptions included | See assumptions. |
| Current source map included | See current source map. |
| Current test map included | See current test map. |
| Ownership/grouping table included | See ownership and grouping table. |
| Naming problems included | See naming problems. |
| Folder-structure problems included | See folder-structure problems. |
| Prioritized findings included | See prioritized findings. |
| Migration batches included | See migration batches. |
| Exact validation matrix included | See audit and per-batch validation matrices. |
| Rollback notes included | Each batch has rollback notes. |
| `TODO(human)` open questions included | See items requiring human or domain decision. |
| Flat core structure corrected | `Sources/OpenLolaCore/` contains 0 root-level Swift files. |
| Remaining non-folder work separated | SwiftPM target splitting, mirrored test folders, parser extraction, and runtime behavior changes remain deferred architecture/behavior work. |

## Resume Here

All source-folder batches are implemented. `Sources/OpenLolaCore/` has no
root-level Swift files; runtime/domain code now lives under ownership folders.
Do not continue from here with behavior refactors, SwiftPM target splitting, or
test-folder mirroring unless explicitly asked, because those are architecture or
behavior-sensitive changes rather than flat-structure cleanup.

VERDICT: PASS
