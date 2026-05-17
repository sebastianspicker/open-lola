# Minimum-Code Audit

Date: 2026-05-17

Scope: audit-only pass over the active first-party Swift, Python, shell, and test
surfaces. No production code was changed. This is not a line-by-line proof over
all 560 active source/test/script files; it is a targeted structural audit of the
largest and most contract-heavy areas, with uncertainty called out where a
simplification would require narrower proof.

Method:

- Counted active first-party `.swift`, `.py`, and `.sh` files under `Sources/`,
  `Tests/`, `linux_connector/`, `scripts/`, and `script/`: 560 files.
- Counted active first-party source/test/script lines in the same scope:
  138,677 physical lines.
- Read the active product status docs before judging code: `README.md`,
  `docs/current-state.md`, and `docs/source-contracts/README.md`.
- Inspected the largest first-party files and the release-readiness surfaces that
  act as executable inventories or evidence gates.
- Treated `archive/` as historical trace evidence only.

## Source Area Triage

| Area | Problem solved | Proportionality judgment | Action |
|---|---|---:|---|
| Core realtime audio, UDP, P2P, video, timing, and reports | Runtime media behavior, packet formats, evidence reports, validation, and partial/pass gates. | Large, but this pass did not find enough evidence to recommend broad simplification without behavior-specific tests. High-risk code should stay out of cleanup-only edits. | KEEP / INVESTIGATE |
| macOS app execution shell | User-facing command launch, validation, report loading, and UI status. | Too much state, process lifecycle, command construction, validation, report parsing, and UI status mutation are concentrated in one observable controller. | SIMPLIFY |
| CLI command and inventory surfaces | Register runnable commands and publish machine-readable command/report inventories. | Multiple hand-maintained ledgers duplicate command/schema ownership that already exists in executable routers, tests, and validators. | DEDUPLICATE / SIMPLIFY |
| External connector and NMP workflows | Preserve source-level LoLa, UltraGrid/MVTP, and JackTrip comparison surfaces. | The broad generic workflow is active by docs/tests, but it is wider than the default product route and needs connector-specific proof before narrowing. | INVESTIGATE |
| Python Linux connector | LoLa compatibility seed, normal UDP media codec, optional raw outer packet builder. | Normal UDP codec is direct. Public raw Ethernet helpers are optional and exported despite docs saying normal UDP is usually enough. | INVESTIGATE |
| Release/test policy tooling | Enforce line budgets, release harness presence, docs and release-readiness gates. | Useful intent, but some tests assert policy text or file existence instead of behavior and can make simplification harder. | SIMPLIFY |
| Legacy compatibility paths | Preserve hidden `audioCompression` and decode-only `audioDeviceUID` migration paths. | Current docs and tests show active compatibility requirements; do not delete from a simplicity audit alone. | KEEP |

## Findings

### MCA-001

- File: `Sources/open-lola-app/AppExecutionController.swift`
- Symbol / function / class / module: `AppExecutionController`
- Suggested action: SIMPLIFY
- Priority class: 1 - code that creates correctness risk; 2 - code that hides
  state or errors
- Current behavior:
  - The controller owns observable UI state, command settings, process handles,
    hidden execution kind, validation state, report paths, loaded external
    connector reports, latency metrics, capture reports, elapsed time, and error
    logs in one type (`AppExecutionController.swift:47-73`).
  - It builds direct and Windows LoLa execution/validation commands
    (`AppExecutionController.swift:120-157`), writes plan artifacts
    (`AppExecutionController.swift:168-187`), launches long-running and one-shot
    processes (`AppExecutionController.swift:441-540`), finishes reports and
    computes verdicts (`AppExecutionController.swift:549-601`), and loads
    external/capture reports while mutating user-visible status
    (`AppExecutionController.swift:639-685`).
  - Validation status depends on hidden `executionKind`,
    `lastValidationExitCode`, direct peer metrics, and external connector report
    state (`AppExecutionController.swift:85-92`, `323-339`).
- Required behavior, if inferable:
  - The app must launch only supported modes, keep unsupported connector modes as
    planning-only, report validation failures truthfully, and never mark runtime
    evidence as validated unless the report actually supports it.
- Complexity problem:
  - One observable UI controller is both state machine, command builder, process
    runner, report loader, error accumulator, and verdict presenter. That makes
    false-positive UI state more likely because the exact evidence used by
    `hasValidatedRuntimeEvidence` is spread across prior command-start and
    validation methods.
  - There are two start paths and two validation paths that repeat readiness,
    command construction, hidden state mutation, and status handling
    (`AppExecutionController.swift:209-251`, `374-438`).
- Minimal alternative:
  - Keep the same public app behavior, but reduce the controller to the minimum
    state transitions required by the UI. In a follow-up implementation, collapse
    duplicated start/validation state changes into shared private routines only
    where both existing call paths use them, and keep command construction and
    report loading explicit rather than adding a generic app execution framework.
- Risk of simplification:
  - High. This is user-visible app state around run/validate/pass/partial
    claims. A mistaken simplification could show `Validation passed` for
    missing evidence, lose external connector error detail, or break planning
    behavior for unsupported connector modes.
- Tests needed before simplification:
  - Keep and extend tests that assert `Validation evidence incomplete`,
    malformed external report handling, direct supervisor report handling, and
    unsupported connector behavior.
- Verification command or strategy:
  - `swift test --filter AppShellBehaviorTests`
  - `swift test --filter AppShellSlice05Tests`
  - `swift test --filter NativeAppShellTests`
  - App build or launch probe when touching user-visible shell behavior.
- Confidence: high

### MCA-002

- File: `Sources/open-lola/main.swift`;
  `Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift`
- Symbol / function / class / module: `openLolaCommands`,
  `openLolaCommandRegistry`, `CLICommandInventory`
- Suggested action: DEDUPLICATE
- Priority class: 4 - code that duplicates behavior
- Current behavior:
  - The runnable command registry is built from `openLolaCommands()`
    (`main.swift:75-80`), with command names and implementations declared in
    `main.swift:81-203` and other command modules.
  - `CLICommandInventory.entries` repeats command names, ownership, command
    kinds, and test references in a second hand-maintained list
    (`CLICommandInventory.swift:77-115`, `139-183`).
  - `scripts/verify-release-readiness.sh` actively probes `command-inventory`
    as a release-readiness CLI surface (`scripts/verify-release-readiness.sh:191-193`).
- Required behavior, if inferable:
  - The repo needs a machine-readable inventory for release/readiness evidence,
    and it must agree with the executable command surface.
- Complexity problem:
  - Command facts live in the runnable router and again in an inventory ledger.
    The private `CLICommandCatalogFamily` / `CLICommandCatalogEntry` wrappers add
    a mini catalog layer whose only visible purpose is feeding
    `CLICommandInventoryEntry` (`CLICommandInventory.swift:122-139`).
- Minimal alternative:
  - Make the inventory derive as much as possible from the actual registered
    command list, keeping only metadata that cannot be known from the registry
    as a compact side table keyed by command name. Do not introduce a new
    command framework unless multiple current command surfaces actually need it.
- Risk of simplification:
  - Medium. The inventory is an active release probe and tests expect the
    command inventory CLI to exist.
- Tests needed before simplification:
  - Verify command inventory still includes every executable command and still
    reports correct validator/run/smoke counts.
- Verification command or strategy:
  - `swift test --filter CLICommandInventoryTests`
  - `swift test --filter VerificationToolingContractTests`
  - `swift build --product open-lola`
  - `.build/debug/open-lola command-inventory`
- Confidence: high

### MCA-003

- File: `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`
- Symbol / function / class / module: `ReportSchemaInventory`,
  `ReportSchemaInventoryEntry`, `schema(...)`
- Suggested action: DEDUPLICATE
- Priority class: 4 - code that duplicates behavior
- Current behavior:
  - `ReportSchemaInventoryEntry` stores schema name, family, version policy,
    evidence class, source file, validators, fixtures, related tests, measured
    evidence requirement, false-pass count, and notes
    (`ReportSchemaInventory.swift:11-57`).
  - `ReportSchemaInventory.entries` is a long hand-maintained source ledger
    covering active report schemas and validators (`ReportSchemaInventory.swift:101-166`).
  - `ReportSchemaInventoryTests` cross-checks validators, fixture groups, smoke
    commands, source files, validation files, and test paths
    (`ReportSchemaInventoryTests.swift:59-98`, `122-153`).
  - Release readiness actively probes `report-schema-inventory`
    (`scripts/verify-release-readiness.sh:191-195`).
- Required behavior, if inferable:
  - The repo needs a current machine-readable schema inventory to keep report
    contracts, validators, fixtures, and false-pass tests synchronized.
- Complexity problem:
  - The source ledger duplicates facts that already exist in validators, fixture
    directories, CLI command inventory, and report types. The helper
    `schema(...)` mostly forwards parameters into the entry initializer
    (`ReportSchemaInventory.swift:169-199`).
- Minimal alternative:
  - Keep the report inventory CLI contract, but reduce hand-entered fields to
    the facts not derivable from validator registration, fixture folders, and
    existing report metadata. The minimal version should fail when executable
    validators and inventory entries drift.
- Risk of simplification:
  - Medium-high. Report schemas and false-pass fixtures are public validation
    contracts. Dropping a field or entry can hide a real PASS/partial boundary.
- Tests needed before simplification:
  - Schema inventory tests must still prove validators, fixtures, smoke commands,
    false-pass fixtures, and source/test paths match real files.
- Verification command or strategy:
  - `swift test --filter ReportSchemaInventoryTests`
  - `swift test --filter FixtureSmokeMatrixTests`
  - `swift test --filter MachineReadableSurfaceContractTests`
  - `.build/debug/open-lola report-schema-inventory`
- Confidence: high

### MCA-004

- File: `Sources/OpenLolaCore/Support/Inventories/NetworkRouteCommandMatrix.swift`
- Symbol / function / class / module: `NetworkRouteCommandMatrix`,
  `NetworkRouteCommandMatrixEntry`
- Suggested action: SIMPLIFY
- Priority class: 4 - code that duplicates behavior
- Current behavior:
  - The matrix defines route modes, evidence boundaries, an entry type with 12
    fields, a summary report, and a static entries list
    (`NetworkRouteCommandMatrix.swift:3-40`, `70-121`).
  - Each row repeats command name, command kind, parser description, output
    report, evidence boundary, representative command, related source files,
    related tests, and notes (`NetworkRouteCommandMatrix.swift:121-145` and
    continuing through the file).
  - A helper at the bottom mostly forwards values into the entry initializer
    (`NetworkRouteCommandMatrix.swift:637-665`).
  - Release readiness actively probes `network-route-command-matrix`
    (`scripts/verify-release-readiness.sh:201-203`).
- Required behavior, if inferable:
  - The repo needs a route-command crosswalk separating fastest direct evidence
    from NAT, diagnostics, loopback, and packet-contract-only evidence.
- Complexity problem:
  - This duplicates command inventory, schema inventory, test ownership, docs
    ownership, and release-probe facts in another Swift source ledger. It is
    executable only in the sense that it serializes static rows.
- Minimal alternative:
  - Keep the CLI report, but collapse redundant fields to command name plus the
    route/evidence facts that are unique to this matrix. Derive command kind,
    owner source file, and related test existence from the command inventory
    where possible.
- Risk of simplification:
  - Medium. Wrong simplification could blur direct route evidence versus NAT or
    localhost-only evidence, which would affect release-readiness claims.
- Tests needed before simplification:
  - Matrix tests must still prove every referenced command exists and every
    fastest/direct/NAT/diagnostic boundary is preserved.
- Verification command or strategy:
  - `swift test --filter NetworkRouteCommandMatrixTests`
  - `swift test --filter VerificationToolingContractTests`
  - `bash scripts/verify-release-readiness.sh` if touching release probes.
- Confidence: high

### MCA-005

- File: `Sources/OpenLolaCore/Support/Inventories/VideoControlDegradeMatrix.swift`
- Symbol / function / class / module: `VideoControlDegradeMatrix`,
  `VideoControlDegradeMatrixEntry`
- Suggested action: SIMPLIFY
- Priority class: 4 - code that duplicates behavior
- Current behavior:
  - The matrix defines surface kinds, evidence boundaries, an entry type with
    source/test/doc/command lists and audio-protection booleans
    (`VideoControlDegradeMatrix.swift:3-40`).
  - It returns an executable report with summary counts and static rows
    (`VideoControlDegradeMatrix.swift:93-122`).
  - The first row repeats video capture source files, tests, docs, commands, and
    evidence policy that also appears in command/report/docs surfaces
    (`VideoControlDegradeMatrix.swift:123-145`).
  - Release readiness actively probes `video-control-degrade-matrix`
    (`scripts/verify-release-readiness.sh:201-203`).
- Required behavior, if inferable:
  - The repo needs a machine-readable proof that video/control features degrade
    before audio and remain blocked from PASS without hardware evidence.
- Complexity problem:
  - The static ledger stores broad ownership metadata plus policy flags in
    production source. The actual unique behavior is the audio-protection and
    evidence-boundary decision, not every repeated source/test/doc path.
- Minimal alternative:
  - Keep the evidence-boundary report, but reduce repeated path and command
    metadata by deriving or cross-checking it from existing inventories. Preserve
    explicit audio-protection booleans where they are unique contract data.
- Risk of simplification:
  - Medium-high. This guards against video/control claims harming audio-first
    semantics. Removing the wrong flag could weaken a real release gate.
- Tests needed before simplification:
  - Matrix tests must still verify no destructive control is armed by default,
    audio baseline requirements remain explicit, and referenced commands exist.
- Verification command or strategy:
  - `swift test --filter VideoControlDegradeMatrixTests`
  - `swift test --filter IntegratedAvReportTests`
  - `swift test --filter VerificationToolingContractTests`
- Confidence: high

### MCA-006

- File: `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift`
- Symbol / function / class / module: `SourceOwnershipInventory`,
  `SourceOwnershipEntry`, `SourceOwnershipPathResolution`
- Suggested action: SIMPLIFY
- Priority class: 4 - code that duplicates behavior
- Current behavior:
  - The inventory defines ownership groups, runtime roles, risks, statuses,
    confidence values, ownership entries, path resolution, coverage reports, and
    a large static entries list (`SourceOwnershipInventory.swift:3-86`,
    `123-191`).
  - Entries repeat source paths, proposed future paths, test files, fixture
    paths, docs, validation commands, and recommendations. Examples include
    realtime audio (`SourceOwnershipInventory.swift:235-247`), UDP transport
    (`273-288`), P2P (`289-303`), external connectors (`324-373`), and the
    inventory files themselves (`485-502`).
  - Release readiness actively probes `source-ownership-inventory`
    (`scripts/verify-release-readiness.sh:191-193`).
- Required behavior, if inferable:
  - The repo needs enough ownership metadata to prevent risky broad moves and to
    keep high-risk runtime areas clearly labeled.
- Complexity problem:
  - This is a planning/refactor inventory embedded in production source, with
    future-oriented fields such as `proposedSourcePath`, `firstMoveCandidate`,
    `movedInC02`, and `improvementRecommendation`. Those are useful planning
    facts, but they are not runtime behavior and duplicate docs/test ownership
    elsewhere.
- Minimal alternative:
  - Keep only ownership data needed by active CLI/tests/release gates in source.
    Move future refactor guidance to docs, or generate it from a smaller
    machine-readable doc, after proving the current CLI and tests do not require
    every field.
- Risk of simplification:
  - Medium. The inventory currently protects high-risk areas from careless
    refactors. Removing it without replacement could make future cleanup less
    safe.
- Tests needed before simplification:
  - Ownership tests must still prove high-risk runtime directories are labeled
    and inventory coverage catches missing active source areas.
- Verification command or strategy:
  - `swift test --filter SourceOwnershipInventoryTests`
  - `.build/debug/open-lola source-ownership-inventory`
  - `bash scripts/verify-release-readiness.sh` if changing release probes.
- Confidence: high

### MCA-007

- File: `Sources/OpenLolaCore/Core/OpenLolaCLI.swift`;
  `Tests/OpenLolaCoreTests/MachineReadableSurfaceContractTests.swift`
- Symbol / function / class / module: `OpenLolaCLI.*Data`,
  `OpenLolaCLI.*JSONString`, `machineReadableInventoryAndMatrixJSONSurfacesRoundTrip`
- Suggested action: INLINE
- Priority class: 3 - code that makes tests difficult; 4 - code that duplicates
  behavior
- Current behavior:
  - `OpenLolaCLI` exposes many pairs of `Data` and `JSONString` methods where
    each string method only decodes the matching data method
    (`OpenLolaCLI.swift:47-160`).
  - Private helpers already centralize JSON encoding and validated JSON encoding
    (`OpenLolaCLI.swift:163-176`).
  - The machine-readable surface test calls ten data wrappers, decodes each
    result, and compares it with the underlying report factory
    (`MachineReadableSurfaceContractTests.swift:8-87`).
- Required behavior, if inferable:
  - CLI commands need printable JSON. Tests need to prove the machine-readable
    surfaces round-trip and keep the correct verdict vocabulary.
- Complexity problem:
  - The public facade doubles the method count for surfaces whose behavior is
    already one generic JSON operation. The test reinforces the wrapper count
    with `surfaceCases.count == 10` instead of primarily checking the executable
    CLI commands.
- Minimal alternative:
  - Prefer a single JSON-output path per current report surface. Keep only
    wrappers that are actually public API or used by more than one current call
    site; inline single-use `Data` wrappers into tests or CLI command handlers.
- Risk of simplification:
  - Medium. `OpenLolaCLI` is a source-level public facade inside the package, and
    tests may intentionally pin current helper names.
- Tests needed before simplification:
  - Replace wrapper-count assertions with behavior assertions against CLI output
    and decoded reports.
- Verification command or strategy:
  - `swift test --filter MachineReadableSurfaceContractTests`
  - `swift test --filter VerificationToolingContractTests`
  - CLI smoke for affected inventory/report commands.
- Confidence: high

### MCA-008

- File: `Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift`;
  `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`
- Symbol / function / class / module: `ReportMetadataArtifact`,
  `assertReportMetadataArtifact`
- Suggested action: INLINE
- Priority class: 5 - code that is merely ugly but safe
- Current behavior:
  - `ReportMetadataArtifact` adds `title`, `capturedAt`, and `notes` to
    `ReportValidatingArtifact` (`ReportValidatorSurface.swift:3-14`).
  - It is implemented by a small set of release/evidence report structs.
  - The only inspected use of the marker as a type constraint is a no-op test
    helper: `private func assertReportMetadataArtifact<Report:
    ReportMetadataArtifact>(_: Report.Type) {}` (`ReportSchemaInventoryTests.swift:51-57`,
    `166`).
- Required behavior, if inferable:
  - Some reports should expose metadata fields, but validation output only needs
    `id`, `verdict`, and `validate()` through `ReportValidatingArtifact`.
- Complexity problem:
  - The marker protocol mostly enforces a shape at compile time while adding no
    behavior. The no-op test proves conformance, not runtime correctness.
- Minimal alternative:
  - Inline the metadata checks into meaningful tests that decode real reports and
    assert non-empty metadata fields, then remove the marker only if no real
    current API requires it.
- Risk of simplification:
  - Low-medium. Removing the protocol changes generic constraints and report
    conformances, but the inspected behavior does not depend on it.
- Tests needed before simplification:
  - Add behavior tests for metadata in affected decoded report fixtures before
    removing the marker.
- Verification command or strategy:
  - `swift test --filter ReportSchemaInventoryTests`
  - `swift test --filter ReportValidatorSurface`
- Confidence: medium

### MCA-009

- File: `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpPlan.swift`;
  `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpWorkflow.swift`
- Symbol / function / class / module: `ExternalConnectorNmpPlanConfiguration`,
  `ExternalConnectorNmpWorkflowConfiguration`, `ExternalConnectorNmpWorkflowRunner`
- Suggested action: INVESTIGATE
- Priority class: 1 - potential correctness risk from broad connector surface;
  4 - duplicated behavior
- Current behavior:
  - NMP plan configuration accepts broad connector, executable override,
    media/control, run-directory, audio/video device, raw-link, MAC, interface,
    and packet options (`ExternalConnectorNmpPlan.swift:3-31`, `93-149`).
  - The runner emits a universal handoff plan for LoLa, MVTP/UltraGrid,
    JackTrip, and auxiliary UltraGrid video, then maps the generic NMP config
    into connector-specific connection-plan config
    (`ExternalConnectorNmpPlan.swift:194-240`).
  - The workflow parser repeats a broad option surface, runs plan, preflight,
    and endpoint execution, and forwards selected values back into plan
    arguments (`ExternalConnectorNmpWorkflow.swift:3-62`, `107-171`).
  - Current docs classify JackTrip, UltraGrid/MVTP, and NMP workflows as active
    comparison/verification surfaces and explicitly say not to delete connector
    modes without a connector-specific audit (`docs/source-contracts/README.md:49-60`).
- Required behavior, if inferable:
  - Keep source-level comparison workflows for external connectors while making
    clear that they are not default Open LoLa media paths and not measured
    interoperability proof.
- Complexity problem:
  - The NMP path is a generic orchestration layer for several connectors and
    modes, while the default product route is direct Open LoLa. The broad option
    surface and forwarding code make it easy for connector planning behavior to
    grow beyond verified use.
- Minimal alternative:
  - Do not delete now. Run a connector-specific audit first and preserve only
    options used by active CLI commands, schema inventory entries, tests, docs,
    and release workflows. Prefer direct connector-specific command paths over
    keeping a universal workflow when only one current connector/mode is in use.
- Risk of simplification:
  - High. Docs and tests currently mark these as active comparison contracts.
    Removing options or workflows without proof could break external endpoint
    handoff, preflight, or report schema validation.
- Tests needed before simplification:
  - Connector-specific tests proving each retained NMP option maps to a real
    command/report field, plus deletion tests proving removed options are not
    referenced by CLI, schemas, docs, or scripts.
- Verification command or strategy:
  - `swift test --filter ExternalConnectorNmpPlanTests`
  - `swift test --filter ExternalConnectorNmpWorkflowTests`
  - `swift test --filter ExternalConnectorConnectionPlanTests`
  - `swift test --filter ReportSchemaInventoryTests`
- Confidence: medium

### MCA-010

- File: `linux_connector/lola_connector/ethernet.py`;
  `linux_connector/lola_connector/__init__.py`;
  `linux_connector/lola_connector/media.py`
- Symbol / function / class / module: `build_ethernet_ipv4_udp_frame`,
  `build_ipv4_udp_packet`, public package exports
- Suggested action: INVESTIGATE
- Priority class: 4 - duplicated/special-case behavior
- Current behavior:
  - `ethernet.py` builds optional raw Ethernet/IPv4/UDP packets and says normal
    UDP payloads are usually sufficient, while preserving recovered outer packet
    format for AF_PACKET/libpcap transmitters (`ethernet.py:1-6`).
  - `media.py` says it intentionally does not build raw Ethernet/IP/UDP headers
    and that normal UDP sockets are enough when LoLa's pcap RX can see packets
    (`media.py:1-6`).
  - The package root publicly exports raw Ethernet helpers
    (`__init__.py:3`, `45-48`, `81-82`).
  - The inspected current runtime usage is tests only:
    `test_raw_outer_packet_layout` and invalid input tests in
    `linux_connector/tests/test_codec.py:331-376`. Docs mention it as an
    advanced fallback (`linux_connector/docs/roadmap.md:37-38`).
- Required behavior, if inferable:
  - The Linux connector should default to normal UDP sockets. Raw outer packet
    construction is optional compatibility evidence only if a target Windows
    LoLa path requires pcap-visible outer headers.
- Complexity problem:
  - A public exported raw Ethernet API invites production use of a fallback path
    that current docs describe as non-default. This broadens the supported
    surface beyond the minimum normal-UDP connector behavior.
- Minimal alternative:
  - Keep the raw builder as a private/test fixture or clearly opt-in
    compatibility module unless active runtime code, CLI, or measured evidence
    proves public raw-frame transmit is required.
- Risk of simplification:
  - Medium. Docs preserve it as an advanced fallback, and tests assert exact
    outer packet layout. Removing public exports could break downstream scripts
    even if none are visible in this checkout.
- Tests needed before simplification:
  - Inventory active import/use outside tests and docs; add a compatibility test
    around the retained opt-in surface if public API remains.
- Verification command or strategy:
  - `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`
  - `rg "build_ethernet_ipv4_udp_frame|build_ipv4_udp_packet|parse_mac" linux_connector Sources Tests docs -g '!archive/**'`
- Confidence: medium

### MCA-011

- File: `Tests/OpenLolaCoreTests/ReleaseRunConfigurationContractTests.swift`
- Symbol / function / class / module:
  `releaseRunConfigurationsAndTestingIndexDocumentActiveHarnessContracts`
- Suggested action: DELETE
- Priority class: 3 - code that makes tests difficult
- Current behavior:
  - The test creates a `contracts` array of four release harness paths,
    configuration type names, and documentation strings, but only asserts
    `contracts.count == 4` (`ReleaseRunConfigurationContractTests.swift:7-43`).
  - It does not use the listed paths, configuration type names, or
    documentation strings to verify the source files or symbols.
  - The remaining assertions check for fixed text in `docs/testing/README.md`
    (`ReleaseRunConfigurationContractTests.swift:31-42`).
- Required behavior, if inferable:
  - The repo needs confidence that release harnesses are active and documented.
- Complexity problem:
  - This is boilerplate that looks like source-to-doc contract coverage but
    mostly checks hardcoded docs text and an array length. It can create false
    confidence and adds friction to harmless doc wording changes.
- Minimal alternative:
  - Replace with a behavior-oriented test that verifies actual CLI commands,
    validators, or source files exist, or delete it if that behavior is already
    covered by `VerificationToolingContractTests` and release-readiness probes.
- Risk of simplification:
  - Low. Deleting or rewriting weak tests can reduce false coverage, but it may
    also remove a reminder to keep testing docs current.
- Tests needed before simplification:
  - Confirm `VerificationToolingContractTests` and release-readiness tests cover
    the intended release harness presence.
- Verification command or strategy:
  - `swift test --filter ReleaseRunConfigurationContractTests`
  - `swift test --filter VerificationToolingContractTests`
- Confidence: high

### MCA-012

- File: `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift`;
  `scripts/code-line-budget-exceptions.txt`
- Symbol / function / class / module: `scopedCodeFilesStayWithinLineBudget`
- Suggested action: SIMPLIFY
- Priority class: 3 - code that makes tests difficult; 5 - safe policy tooling
- Current behavior:
  - The Swift test walks `Package.swift`, `Sources`, `Tests`, `scripts`,
    `script`, `linux_connector`, `private`, and `.github`, applies file-type
    line budgets, skips vendored code and `__pycache__`, parses an exception
    ledger, detects stale exceptions, and counts bytes to enforce physical line
    counts (`CodeLineBudgetTests.swift:4-57`, `71-211`).
  - The exception ledger currently contains only the header
    (`scripts/code-line-budget-exceptions.txt:1`).
- Required behavior, if inferable:
  - The repo wants a guardrail against files growing beyond agreed line budgets.
- Complexity problem:
  - A broad repository scanner embedded in Swift unit tests is a lot of code for
    a policy gate. It touches private paths and shell/Python/YAML files from a
    Swift test suite, which couples source tests to repository layout and makes
    the unit test runner responsible for hygiene policy.
- Minimal alternative:
  - Keep the line-budget rule if it is still desired, but move repository-wide
    scanning to a dedicated verification script and let Swift tests cover Swift
    behavior. If it remains in Swift, reduce scope to current first-party Swift
    files and keep exceptions minimal.
- Risk of simplification:
  - Medium. The guardrail is intentional and currently catches oversized files.
    Moving it could weaken enforcement if CI/release scripts do not run the new
    location.
- Tests needed before simplification:
  - A verification test or script gate proving oversized first-party files still
    fail and stale exceptions still fail.
- Verification command or strategy:
  - `swift test --filter CodeLineBudgetTests`
  - Run the release/docs verification script that would own the policy if moved.
- Confidence: medium

### MCA-013

- File: `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift`;
  `Sources/open-lola-app/AppShellStoredDefaults.swift`;
  `Sources/OpenLolaCore/Network/P2P/*`;
  `docs/source-contracts/README.md`
- Symbol / function / class / module: legacy `audioCompression` /
  `--audio-compression`
- Suggested action: KEEP
- Priority class: compatibility path with active evidence; not a deletion
  candidate from this audit
- Current behavior:
  - Docs state `audioTransport` is canonical, while legacy `audioCompression` /
    `--audio-compression` remains a hidden compatibility path for old CLI
    arguments, stored app defaults, initializer fallback, and report decoding
    (`docs/source-contracts/README.md:30-36`).
  - CLI parsing still accepts the hidden legacy flag, maps it to transport, and
    rejects conflicts with `--audio-transport`
    (`DirectP2PSessionRunCommandSupport.swift:225-243`).
  - Tests assert help omits `--audio-compression`, invalid legacy values fail,
    conflicts fail, and hidden legacy input matches canonical transport behavior
    (`DirectPeerSessionOpusCLITests.swift:7-14`, `16-26`, `47-58`, `71-105`).
- Required behavior, if inferable:
  - Preserve hidden migration compatibility until a future audit proves old CLI,
    stored defaults, report decoding, and external scripts no longer require it.
- Complexity problem:
  - None recommended for simplification now. This looks like compatibility slop
    at first glance, but current docs and tests prove active intent.
- Minimal alternative:
  - No change in this audit. Only remove after an explicit migration/breaking
    change decision and proof that stored defaults, fixtures, reports, scripts,
    and CLI callers no longer use the legacy name.
- Risk of simplification:
  - High. Removing it could break hidden migration behavior and old reports.
- Tests needed before simplification:
  - Migration/breaking-change tests covering CLI flags, app defaults, initializer
    fallback, and report decoding.
- Verification command or strategy:
  - `swift test --filter DirectPeerSessionOpusCLITests`
  - `swift test --filter NativeAppShellOpusCommandTests`
  - Search for `audioCompression|audio-compression` across active sources,
    tests, docs, and scripts.
- Confidence: high

## Areas Simple Enough Or Not Proven Overcomplicated

- `Sources/OpenLolaContracts/`: shared verdict/report contract types appear
  central and are used across source and validation surfaces. No simplification
  recommendation from this pass.
- `Sources/OpenLolaCore/Audio/Realtime/`: high-risk realtime path. Large files
  require behavior-specific review, but the inspected inventory and docs show
  active ownership and release-critical constraints. Do not simplify casually.
- `Sources/OpenLolaCore/Network/UDP/` and `Sources/OpenLolaCore/Network/P2P/`:
  packet and route code is central to current product behavior. This pass found
  duplication in inventories around it, not enough evidence to shrink the
  runtime code itself.
- `Sources/OpenLolaCore/Video/` and `Sources/OpenLolaCore/Control/`: video and
  control surfaces are guarded by partial/pass evidence policy. The matrix
  metadata is a simplification target; runtime capture/control behavior was not
  proven overcomplicated in this pass.
- `linux_connector/lola_connector/media.py`: the inspected normal UDP media
  codec path is direct and explicitly avoids raw outer header construction. The
  optional raw Ethernet module is the concern, not the core media codec.
- Vendored/reference code under `Sources/opus-1.5.2/` and
  `Sources/xs_ref_sw_ed2/`: not first-party simplification targets.

## Highest-Impact Simplification Targets

1. `AppExecutionController` state/process/report responsibilities. This is the
   highest-impact target because complexity directly affects user-visible
   validation and false-success behavior.
2. Executable inventory family (`CLICommandInventory`,
   `ReportSchemaInventory`, `NetworkRouteCommandMatrix`,
   `VideoControlDegradeMatrix`, `SourceOwnershipInventory`,
   `RealtimeAudioPathInventory`). These are active gates, but they duplicate
   command/schema/docs/test facts across multiple Swift ledgers.
3. `OpenLolaCLI` machine-readable wrappers and wrapper-count tests. Shrinking
   these can reduce boilerplate without touching runtime media behavior.
4. Weak policy tests such as `ReleaseRunConfigurationContractTests`, where
   assertions do not prove the contract they appear to cover.
5. NMP and raw Ethernet fallback paths, after current-use inventory proves which
   options are actually required.

## Low-Risk Deletion Or Inlining Candidates

| Candidate | Suggested action | Why low risk is plausible | Proof still needed |
|---|---|---|---|
| `assertReportMetadataArtifact` no-op helper | INLINE / DELETE | It only proves compile-time conformance and has no body. | Behavior tests for actual metadata fields on decoded reports. |
| `ReleaseRunConfigurationContractTests` hardcoded docs assertions | DELETE / SIMPLIFY | The current test does not use its own harness path/type metadata. | Confirm release harness coverage exists in verification tooling tests or release-readiness probes. |
| Single-use `OpenLolaCLI.*Data` wrappers used only by tests | INLINE | `*JSONString` wrappers are the real CLI-facing behavior; generic JSON helpers already exist. | API-use search plus machine-readable CLI output tests. |
| `CLICommandCatalogFamily` / `CLICommandCatalogEntry` | INLINE | They appear to only convert a small catalog into inventory entries. | Keep command inventory metadata and counts stable. |

## Risky Areas Needing More Proof

- External connector/NMP workflows: docs explicitly classify them as active
  comparison/verification surfaces. Narrow only after connector-specific proof.
- Python raw Ethernet helpers: current visible runtime use is unclear outside
  tests/docs, but docs preserve an advanced fallback. Narrow only after import
  and workflow inventory.
- Legacy `audioCompression`: active compatibility path with docs/tests. Keep
  until migration proof exists.
- High-risk realtime, UDP, P2P, video, timing, and report validators: no
  structural cleanup should happen without behavior-specific failing tests and
  targeted verification.

## Remaining Uncertainty

- This audit did not inspect every active file line-by-line. It prioritized
  large files, release-readiness surfaces, and areas likely to accumulate
  abstraction or duplicated ledgers.
- The repo has many machine-readable inventory/report surfaces. Some duplication
  may be intentionally accepted to keep release evidence self-contained; this
  audit flags the minimum-code cost, not a deletion decision.
- Downstream use of Python raw Ethernet exports outside this checkout is
  unknown.
- Any simplification of app validation state needs a UI/runtime smoke pass, not
  only unit tests.

## Prioritized Remediation Table

| Rank | Finding | Action | Why first | Minimum next step | Verification |
|---:|---|---|---|---|---|
| 1 | MCA-001 | SIMPLIFY | Concentrated UI state can create false validation/pass behavior. | Add/confirm tests around direct and Windows validation evidence, then reduce duplicated state transitions inside `AppExecutionController`. | `swift test --filter AppShellBehaviorTests`; app shell build/probe |
| 2 | MCA-011 | DELETE / SIMPLIFY | Weak tests can hide missing release-harness coverage. | Replace docs-string assertions with real command/source coverage or delete if already covered. | `swift test --filter ReleaseRunConfigurationContractTests`; `swift test --filter VerificationToolingContractTests` |
| 3 | MCA-007 | INLINE | Wrapper boilerplate and count-based tests make surfaces harder to change. | Inventory actual public uses of `OpenLolaCLI.*Data` and collapse single-use wrappers. | `swift test --filter MachineReadableSurfaceContractTests`; CLI JSON probes |
| 4 | MCA-002 | DEDUPLICATE | Command facts are duplicated between router and inventory. | Derive inventory from current command registry plus a small metadata side table. | `swift test --filter CLICommandInventoryTests`; `.build/debug/open-lola command-inventory` |
| 5 | MCA-003 | DEDUPLICATE | Schema facts duplicate validators, fixtures, and tests. | Reduce report inventory fields to non-derivable evidence policy data. | `swift test --filter ReportSchemaInventoryTests`; `.build/debug/open-lola report-schema-inventory` |
| 6 | MCA-004, MCA-005, MCA-006 | SIMPLIFY | Static route/video/source ledgers repeat command/schema/docs/test facts. | Keep unique evidence-boundary/risk facts; derive repeated command/path facts. | Matrix and inventory tests; release-readiness probes |
| 7 | MCA-009 | INVESTIGATE | Broad connector workflow may exceed current product needs, but is active. | Run connector-specific current-use audit for every NMP option and mode. | External connector NMP test filters; schema inventory tests |
| 8 | MCA-010 | INVESTIGATE | Public optional raw Ethernet surface may exceed normal UDP requirement. | Inventory active runtime/import use and decide whether public export is required. | Python connector pytest; active-use `rg` |
| 9 | MCA-012 | SIMPLIFY | Line-budget scanner is useful but misplaced as broad Swift unit-test policy. | Move or narrow only if CI/release verification keeps enforcement. | `swift test --filter CodeLineBudgetTests`; replacement verifier |
| 10 | MCA-008 | INLINE | Marker protocol/no-op conformance test is small boilerplate. | Replace compile-only assertion with decoded metadata behavior checks. | `swift test --filter ReportSchemaInventoryTests` |
| 11 | MCA-013 | KEEP | Looks obsolete, but current docs/tests prove active compatibility. | No simplification until explicit migration proof exists. | Direct peer Opus/native shell tests |
