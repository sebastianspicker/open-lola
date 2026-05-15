# AUDIT.md - structured code audit

Date: 2026-05-08

Scope:
- Audited every repository file outside `linux_connector/`.
- Deep-reviewed maintained source, tests, scripts, and active docs under `Sources/`, `Tests/`, `scripts/`, `docs/`, `mac-port/`, `research/`, and `reverse-engineering/`.
- Inventory-reviewed generated, archive, binary, cache, and build surfaces such as `.build/`, `archive/`, `dist/`, `re_out/`, `win-compiled/`, `.ruff_cache/`, and `.pytest_cache/`.
- This checkout is not a Git worktree, so file state is filesystem-derived rather than diff-derived.

Non-goals:
- No runtime/source fixes were made in this pass.
- No behavior, CLI argument, report schema, protocol layout, evidence-boundary, or docs-status semantics should change as a result of this audit.
- `linux_connector/` was intentionally excluded from audit findings except where top-level tooling references it.

## Repository Map

`Package.swift` defines the current spine: `OpenLolaCore`, `COpenLolaAtomics`, `open-lola`, `open-lola-app`, and `OpenLolaCoreTests`. The Swift package is the authoritative build/test unit for the maintained implementation.

The main source flow is:

1. `Sources/open-lola/main.swift` dispatches CLI commands.
2. CLI command-family files under `Sources/open-lola/Commands/` parse arguments and call `OpenLolaCore`.
3. `Sources/OpenLolaCore/` owns the runtime domains: audio, video, network, LoLa connector compatibility, control, timing, release readiness, support inventories, and report schemas.
4. `Tests/OpenLolaCoreTests/` locks command behavior, source contracts, report schemas, release readiness, line budgets, and synthetic runtime paths.
5. `scripts/` verifies docs, release readiness, release hygiene, and source/report artifacts.
6. `docs/`, `mac-port/`, `research/`, and `reverse-engineering/` describe the implementation state, compatibility boundary, source contracts, and historical evidence.

Measured inventory:

- Non-`linux_connector` files in the checkout: 5,885.
- Maintained files in active source/test/script/doc surfaces: 541.
- Largest raw filesystem areas outside `linux_connector/`: `.build/` 4,741 files, `archive/` 269, `Sources/` 231, `re_out/` 201, `Tests/` 163, `win-compiled/` 103, `docs/` 75, `scripts/` 38.
- CLI inventory probe: 164 commands, 58 validator commands, 48 run commands, 31 synthetic smoke commands, 9 localhost smoke commands.
- Source ownership probe: 20 groups, 8 high-risk groups, 10 medium-risk groups, 2 low-risk groups.
- Report schema probe: 59 schemas, 58 validator commands, 29 fixture-backed schemas, 30 schemas requiring measured evidence, 9 false-pass fixture risks.

## Verification Snapshot

Passing checks:

- `ruff check scripts/verify_docs`: PASS.
- `shellcheck scripts/*.sh`: PASS.
- `bash scripts/verify-docs.sh`: PASS.
- `bash scripts/verify-release-hygiene.sh`: PASS.
- `swift build`: PASS when run outside the workspace sandbox. The sandboxed run failed before SwiftPM could build with `sandbox-exec: sandbox_apply: Operation not permitted`.
- `.build/debug/open-lola command-inventory`: command completed and reported `VERDICT: PARTIAL`, as expected for a source/inventory probe.
- `.build/debug/open-lola source-ownership-inventory`: command completed and reported `VERDICT: PARTIAL`, as expected for a source/inventory probe.
- `.build/debug/open-lola report-schema-inventory`: command completed and reported `VERDICT: PARTIAL`, as expected for a source/inventory probe.
- `.build/debug/open-lola goal-runtime-preflight`: command completed and reported `VERDICT: PARTIAL`, correctly reflecting missing local audio/video/signing runtime evidence.

Incomplete checks:

- `swift test` built and started hundreds of tests, then stopped producing output for several minutes and had to be terminated. No failing assertion was observed before termination, but the full suite did not produce a final pass/fail result.
- `bash scripts/verify-release-readiness.sh` reached its nested `swift build` step while the hung `swift test` still owned `.build`; SwiftPM waited on the build lock and the script was terminated with signal 15. Release-readiness is therefore inconclusive in this audit run.

VERDICT: PARTIAL for this audit, because full `swift test` and full release readiness did not complete.

## Remediation Progress

Status timestamp: 2026-05-08.

| Finding | Status | Files changed | Verification evidence | Remaining risk |
|---|---|---|---|---|
| 1. Verification can hang or self-serialize on `.build` | Remediated in local gate | `scripts/verify-release-readiness.sh`, `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`, `scripts/README.md`, `docs/testing/verification-matrix.md` | `swift test --filter VerificationToolingContractTests`: PASS. Script now wraps `swift build` with `SWIFT_BUILD_TIMEOUT_SECONDS=600` and `swift test` with `SWIFT_TEST_TIMEOUT_SECONDS=1800`, captures timed-step logs to temp files, and terminates child process trees on timeout. `bash scripts/verify-release-readiness.sh`: PASS. | Standalone `swift test` remains outside this wrapper; use `bash scripts/verify-release-readiness.sh` as the bounded full gate. |
| 2. Key/value CLI argument parsing is reimplemented | Partially remediated, incremental | `Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift`, `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorParsingDefaults.swift`, `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpEndpointRun.swift`, `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityPacketFixture.swift` | Targeted parser tests in `ExternalConnectorNmpEndpointRunTests` and `LoLaCompatibilityPacketFixtureTests`: PASS. | Many same-shape parser loops intentionally remain for later mechanical migration. |
| 3. Pretty JSON encoding is duplicated | Partially remediated, incremental | `Sources/OpenLolaCore/Control/LightingFixtureGateReport.swift`, `Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift` | `LightingFixtureGateTests`, `CLICommandInventoryTests`, and inventory JSON round-trip tests: PASS. | Other byte-equivalent pretty JSON methods remain and can migrate safely in later waves. |
| 4. Process execution is duplicated with different timeout semantics | Partially remediated, incremental | `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift`, `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift`, `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorExecutablePreflight.swift`, `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpEndpointRun.swift` | `ExternalConnectorExecutablePreflightTests`, `ExternalConnectorNmpEndpointRunTests`, and process-group targeted tests: PASS. NMP endpoint dry-runs and single-endpoint runs now avoid blocking dispatch-group waits under Swift Testing parallelism. | `GoalRuntimePreflight` and network diagnostics process helpers still use local process code. |
| 5. CLI dispatch, usage, and inventories have multiple manual sources of truth | Partially remediated, incremental | `Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift` | `CLICommandInventoryTests`, `ReportSchemaInventoryTests`, and `SourceOwnershipInventoryTests`: PASS. | Only the network inventory family uses the internal catalog; dispatch and usage text remain unchanged by design. |
| 6. Source and report inventories are valuable but too static | Documented carry-forward | `AUDIT.md` | Inventory tests and probes still pass with the existing static contracts. | Missing-path/unknown-command detection beyond current tests remains future work. |
| 7. Ignored generated files are present in the raw checkout | Remediated | Raw checkout cleanup only | Allowlisted ignored artifact count before cleanup: 5,983. After cleanup: 0. `bash scripts/verify-release-hygiene.sh`: PASS. | `.build/` is recreated by SwiftPM during verification and remains ignored/generated. |
| 8. Several files are at or near the line-budget ceiling | Guarded | `Tests/OpenLolaCoreTests/ReservedLocalUdpPorts+TestSupport.swift`, `Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift` | `swift test --filter scopedCodeFilesStayWithinLineBudget`: PASS. `PeerSessionRunnerTests.swift` is 642 LOC after moving shared UDP reservation helpers to a dedicated test-support file. | Future reductions should follow real extracted boundaries. |
| 9. `try!` appears in synthetic or fixture builders | Remediated for audited occurrences | `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineSyntheticSmoke.swift`, `Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkSyntheticSmoke.swift`, `Sources/OpenLolaCore/Timing/DriftPlcRun.swift`, `Sources/OpenLolaCore/Timing/LatencyProfileContracts.swift`, `Sources/OpenLolaCore/Timing/SessionProfileBenchmark.swift`, related command/test callers | Targeted synthetic smoke/report tests: PASS. | Public smoke APIs now throw where construction can fail; CLI callers already throw. |
| 10. LoLa video payload generation and AVFoundation polling | Remediated for generated-array and capture-wait paths | `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaSession.swift`, `Sources/OpenLolaCore/Connectors/LoLa/LoLaVideoPayloadProvider.swift` | `LoLaCompatibilityMediaSessionTests` and `LoLaVideoPayloadProviderTests`: PASS. | Generated frames still allocate one frame at a time; this preserves byte pattern and avoids prebuilding the full frame array. |

Verification notes:

- `ruff check scripts/verify_docs`: PASS.
- `shellcheck scripts/*.sh`: PASS.
- `bash scripts/verify-docs.sh`: PASS before this progress-section update.
- `bash scripts/verify-release-hygiene.sh`: PASS.
- Sandboxed `swift build`: FAIL with the known SwiftPM `sandbox-exec: sandbox_apply: Operation not permitted` manifest issue.
- Unsandboxed `swift build`: PASS.
- Targeted touched-area Swift tests: PASS, 120 Swift Testing tests.
- `swift test --filter directPeerSessionManualAudioVideoModeRoutesAudioAndVideo`: PASS after reserving the selected UDP ports until both peers are ready to bind.
- `swift test --filter 'PeerSessionRunnerTests|PeerSessionAVFastestTests'`: PASS, 25 Swift Testing tests.
- `swift test --filter 'ExternalConnectorNmpEndpointRunTests|ExternalConnectorNmpWorkflowTests'`: PASS, 13 Swift Testing tests.
- `swift test --filter 'scopedCodeFilesStayWithinLineBudget|ExternalConnectorNmpEndpointRunTests|PeerSessionRunnerTests|PeerSessionAVFastestTests'`: PASS, 33 Swift Testing tests.
- Full standalone `swift test`: PASS, 999 Swift Testing tests in 0 suites.
- `bash scripts/verify-release-readiness.sh`: PASS. Timed `swift build` and `swift test` completed under the default `600s` and `1800s` budgets.
- Release-readiness surface probes completed with expected local verdicts: command/source/schema/runtime inventories remain `VERDICT: PARTIAL`; `goal-codewise-closure` remains `VERDICT: PASS` with `real-world-verdict: partial`; runtime evidence, preflight, completion audit, and open-source release readiness remain `VERDICT: PARTIAL`.

Remediation verdict: `VERDICT: PARTIAL`. Local code remediation and the bounded release-readiness gate pass; real-world hardware, signing, clean-Mac, benchmark, and field evidence remain explicit manual gates.

## Findings

### 1. Verification Can Hang Or Self-Serialize On `.build`

- severity: high
- lens: quality, efficiency
- evidence:
  - `scripts/verify-release-readiness.sh:197-202` runs docs, shellcheck, release hygiene, `swift build`, and `swift test`.
  - `.github/workflows/release-readiness.yml:16-17` protects CI with a 30-minute job timeout, but the local script has no per-step timeout or no-output guard.
  - `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift:8-38` intentionally locks the release-readiness script contract, including `swift test` and final `VERDICT: PASS`.
- observed behavior: A standalone `swift test` run hung or went silent after many passing tests. A concurrent release-readiness run then waited on SwiftPM's `.build` lock and had to be terminated.
- simplification: Make release readiness the single owner of the full Swift verification path during local runs, or add a local no-output/timeout wrapper around `swift test`. Avoid running a separate `swift test` concurrently with `verify-release-readiness.sh`.
- why this matters: Without bounded local verification, a green or red result can be replaced by an indefinite wait. This blocks reliable closure for later refactor passes.
- proposed first fix: Add a small Bash timeout helper around expensive local steps and update the tooling contract tests to require that guard. Keep the CI job timeout as the outer safety net.

### 2. Key/Value CLI Argument Parsing Is Reimplemented Across The Codebase

- severity: high
- lens: reuse, quality
- evidence:
  - Shared helper exists in `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorParsingDefaults.swift:79-101`.
  - Shared value helpers exist in `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorParsingDefaults.swift:125-163`.
  - `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityPacketFixture.swift:208-230` reimplements the key/value state machine.
  - `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityPacketFixture.swift:232-250` reimplements required and positive-integer helpers.
  - `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpEndpointRun.swift:24-42` reimplements the parser and then calls the shared value helpers.
  - `Sources/OpenLolaCore/Control/LightingFixtureGateRun.swift:52-84` reimplements allowed-key, unknown-key, duplicate-key, and missing-value behavior.
  - `Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift:429-451` reimplements the same parser shape with a domain-specific error type.
  - Similar parser loops appear in `AtemReadOnlyControl.swift`, `OscCueProbe.swift`, `E2EBenchmarkRunner.swift`, `FieldReadinessRun.swift`, `ReleaseHardening.swift`, `OpenSourceReleaseReadiness.swift`, `FieldReadyRuntimeProof.swift`, `RecordingSessionRun.swift`, `FasterThanLoLaClosure.swift`, `PackagingFieldTestRun.swift`, `AudioLoopbackRunConfiguration.swift`, `IntegratedProfileRun.swift`, `ExternalConnectorNmpPlan.swift`, and `ExternalConnectorConnectionPlan.swift`.
- simplification: Promote the current external connector parser into a generic internal argument parser that accepts an allowed-key set and an error-mapping strategy. Keep command-specific allowed keys, defaults, and public error wording local where tests require it.
- why behavior can be preserved: The duplicated state machines already reject the same classes of malformed input: unknown option, duplicate option, missing value, and invalid positive integer. Refactor by migrating one low-risk command family at a time with before/after tests.

### 3. Pretty JSON Encoding Is Duplicated Despite A Shared Protocol

- severity: medium
- lens: reuse
- evidence:
  - `Sources/OpenLolaCore/Core/PrettyJSONCodable.swift:3-18` defines `PrettyJSONCodable` with default `prettyJSONData()` and `prettyJSONString()` implementations.
  - `Sources/OpenLolaCore/Control/LightingFixtureGateReport.swift:57-65` manually implements the same pretty JSON methods.
  - `Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift:256-264` manually implements the same methods.
  - `Sources/OpenLolaCore/Timing/DriftPlcReport.swift:219-227` manually implements the same methods.
  - A repository search found 34 `func prettyJSONData() throws -> Data` implementations across report and inventory types.
- simplification: Conform report structs to `PrettyJSONCodable` wherever the manual implementation is byte-equivalent, then delete the repeated methods.
- why behavior can be preserved: The shared protocol already uses `.prettyPrinted` and `.sortedKeys`, matching the repeated implementation shape. Tests should compare stable JSON output before removing manual methods from high-value reports.

### 4. Process Execution Is Duplicated With Different Timeout Semantics

- severity: medium
- lens: quality, efficiency
- evidence:
  - `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift:120-139` starts processes through `/usr/bin/env`, captures stdout/stderr pipes, and returns a running process.
  - `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorExecutablePreflight.swift:331-360` repeats process setup and waits synchronously.
  - `Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift:388-425` has its own timeout-aware process runner.
  - `Sources/OpenLolaCore/Release/GoalRuntimePreflight.swift:102-129` has another process runner for signing identity probing.
- simplification: Add one internal `ProcessRunner` or `ProcessProbe` helper that supports timeout, environment, `/usr/bin/env` wrapping, separated or combined output, and prefix clipping. Migrate callers without changing report structs first.
- why behavior can be preserved: The helper can expose the current behavior as options. The immediate gain is consistent timeout handling and less duplicated pipe/process lifecycle code.

### 5. CLI Dispatch, Usage, And Inventories Have Multiple Manual Sources Of Truth

- severity: medium
- lens: reuse, quality
- evidence:
  - `Sources/open-lola/main.swift:14-45` cascades top-level handlers before falling through to a large switch.
  - `Sources/open-lola/main.swift:45-140` begins the large command switch; usage text starts at `Sources/open-lola/main.swift:141`.
  - `Sources/open-lola/Commands/MilestoneCommands.swift` is 641 lines and repeats the validate/write/print pattern across many commands.
  - `Sources/open-lola/Commands/Network/NetworkCommands.swift` is 649 lines and repeats similar command dispatch patterns.
  - `Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift:63-80` starts a static command inventory that must be kept aligned with the router, usage text, tests, and docs.
- simplification: Introduce command descriptors per family with `name`, `kind`, `handler`, inventory metadata, and usage text. Start with inventory-only validators or one narrow command family rather than rewriting the whole CLI.
- why behavior can be preserved: Command handlers can stay as-is. The descriptor table would first remove duplicate metadata, then dispatch can migrate incrementally.

### 6. Source And Report Inventories Are Valuable But Too Static

- severity: medium
- lens: reuse, quality
- evidence:
  - `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift` holds large static path groups and recommendations.
  - `Sources/OpenLolaCore/Support/Inventories/ReportSchemaInventory.swift:81` starts a static schema-entry list. The probe currently reports 59 schemas and 58 validator commands.
  - The report-schema probe reports 30 schemas that still require measured evidence and 9 false-pass fixture risks.
- simplification: Keep inventories, but move repeated metadata into small manifest fragments or add checks that detect missing file paths, unknown command names, and schema entries without matching validator commands.
- why behavior can be preserved: Inventories are already contract surfaces. The improvement is to make stale entries harder to create, not to weaken the contract.

### 7. Ignored Generated Files Are Present In The Raw Checkout

- severity: medium
- lens: quality
- evidence:
  - `.gitignore:7-9` ignores SwiftPM build products.
  - `.gitignore:17-21` ignores app artifacts.
  - `.gitignore:23-30` ignores Python caches.
  - `.gitignore:32-38` ignores local output directories.
  - `.gitignore:47-48` ignores `.DS_Store`.
  - Present raw files include `.DS_Store` files under the root, `Sources/`, `docs/`, `mac-port/`, `reverse-engineering/`, `win-compiled/`, and `archive/`.
  - Present raw files also include `.pytest_cache/`, `.ruff_cache/`, `scripts/verify_docs/__pycache__/`, and `dist/OpenLoLa*.app` artifacts.
- simplification: Run a separate hygiene pass that deletes ignored generated/cache/app artifacts from the raw checkout, then rerun release hygiene. Do not mix this with source refactors.
- why behavior can be preserved: These files are already declared non-source by `.gitignore`. The only caution is that this checkout is not a Git worktree, so cleanup should be explicit and reviewed before deletion.

### 8. Several Files Are At Or Near The Line-Budget Ceiling

- severity: medium
- lens: quality
- evidence:
  - `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift:4-36` enforces a 720-line maximum for scoped code files.
  - Current near-limit files include:
    - `Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift`: 720 lines.
    - `Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeRuntime.swift`: 712 lines.
    - `Sources/OpenLolaCore/Release/RecordingSessionArtifacts.swift`: 702 lines.
    - `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift`: 701 lines.
    - `Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift`: 685 lines.
    - `Sources/open-lola/Commands/Network/NetworkCommands.swift`: 649 lines.
    - `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityCaptureReport.swift`: 643 lines.
    - `Sources/open-lola/Commands/MilestoneCommands.swift`: 641 lines.
    - `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift`: 622 lines.
    - `Sources/OpenLolaCore/Support/Inventories/NetworkRouteCommandMatrix.swift`: 609 lines.
- simplification: Do not split files just because they are large. First extract duplicated parser, process, JSON, and command metadata patterns. Only split files when the extracted boundary is already real.
- why behavior can be preserved: This is a refactor ordering point. Mechanical file moves should follow tested reductions, not precede them.

### 9. `try!` Appears In Synthetic Or Fixture Builders

- severity: low
- lens: quality
- evidence:
  - `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineSyntheticSmoke.swift:5`
  - `Sources/OpenLolaCore/Timing/DriftPlcRun.swift:235`
  - `Sources/OpenLolaCore/Timing/LatencyProfileContracts.swift:416`
  - `Sources/OpenLolaCore/Timing/SessionProfileBenchmark.swift:77`
  - `Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkSyntheticSmoke.swift:10`
- simplification: Replace with throwing fixture builders where the call path already throws. Where the invariant is intentionally static, add a narrow test that proves the fixture cannot fail.
- why behavior can be preserved: Most occurrences appear in synthetic smoke or static evidence construction. This is not urgent, but it is a small reliability cleanup.

### 10. LoLa Video Payload Generation Allocates Full Frames Per Synthetic Payload

- severity: low
- lens: efficiency
- evidence:
  - `Sources/OpenLolaCore/Connectors/LoLa/LoLaVideoPayloadProvider.swift:49-65` allocates `Data(count: fullFrameBytes)` and fills every byte for each generated frame.
  - `Sources/OpenLolaCore/Connectors/LoLa/LoLaVideoPayloadProvider.swift:386-392` waits for AVFoundation capture by polling every 10 ms.
- simplification: Keep current deterministic bytes, but consider a reusable buffer path or lazy frame stream for high frame counts. For AVFoundation capture, prefer a synchronization primitive over polling if this path becomes a runtime hotspot.
- why behavior can be preserved: The generated payload byte pattern is deterministic and can be locked by tests before changing allocation strategy.

## Recommended Implementation Order

1. Fix local verification boundedness first: add no-output/timeout protection around expensive Swift verification steps and update verification-tooling tests.
2. Clean ignored generated/cache/app artifacts in a separate hygiene pass.
3. Extract the generic key/value argument parser and migrate low-risk command families first.
4. Replace byte-equivalent pretty JSON implementations with `PrettyJSONCodable` conformance.
5. Introduce a shared process runner with explicit timeout behavior.
6. Add command descriptors for one command family, then use the result to reduce CLI dispatch/inventory duplication.
7. Reduce near-limit files through the real extractions above; avoid cosmetic file splitting.
8. Replace or test `try!` fixture builders.
9. Revisit LoLa video payload allocation only after correctness-preserving tests pin the byte pattern.

## Acceptance Criteria For A Follow-Up Refactor Wave

- `swift build`: PASS.
- `swift test`: PASS with bounded runtime and no indefinite wait.
- `bash scripts/verify-release-readiness.sh`: PASS or a bounded, explicit failure.
- `bash scripts/verify-docs.sh`: PASS.
- `bash scripts/verify-release-hygiene.sh`: PASS.
- `ruff check scripts/verify_docs`: PASS.
- `shellcheck scripts/*.sh`: PASS.
- CLI probes for command inventory, source ownership inventory, report schema inventory, and goal runtime preflight still complete and preserve their expected `PARTIAL` evidence-boundary verdicts where real-world evidence is missing.

Final audit verdict: `VERDICT: PARTIAL`.
