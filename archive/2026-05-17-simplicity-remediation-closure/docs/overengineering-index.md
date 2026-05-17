# Overengineering Index

Date: 2026-05-17

This is an audit-only index. No production code, tests, scripts, generated
artifacts, or archived files were changed while creating it. The only intended
write target is this file.

## Scope And Method

Inspected active first-party Swift, Python, shell, docs, and test surfaces with
`rg`, `find`, `wc`, and targeted line-number reads. I treated `archive/` as
historical trace evidence, not active authority, and did not audit vendored
Opus/JPEG XS internals as simplification targets.

The active source/test/script surface counted here is 560 Swift/Python/shell
files under `Sources/`, `Tests/`, `linux_connector/`, `scripts/`, and `script/`,
with 138677 physical lines. This is not a full file-by-file audit. Findings are
limited to candidates with concrete evidence. Where active usage or intent is
unclear, the finding says `UNCLEAR`.

The worktree was already dirty before this audit. Findings below describe the
live checkout as inspected, not a clean release state.

## Findings

### OE-001

- ID: OE-001
- File: `Sources/open-lola/main.swift`;
  `Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift`
- Symbol / function / class / module: `openLolaCommands()`,
  `CLICommandInventory.entries`
- Category: DUPLICATION
- Evidence: `main.swift` defines the executable command registry as
  `RegisteredCommand` entries at lines 79-203. `CLICommandInventory.entries`
  separately hand-maintains command names, owners, kinds, and related tests at
  lines 77-115, then expands more hand-maintained catalog entries via
  `CLICommandCatalogFamily`/`CLICommandCatalogEntry` at lines 122-183.
- Why this is more complex than necessary: The CLI has two command sources of
  truth: the executable router and a parallel inventory database. Every new or
  renamed command can drift unless both are updated.
- Simpler alternative: Add the small amount of inventory metadata needed by
  the actual command registry, then derive the inventory and help surfaces from
  that registry. If metadata does not belong in runtime code, generate the
  inventory from a single source during verification.
- What could break if simplified: `command-inventory`, top-level help,
  `CLICommandInventoryTests`, `MachineReadableSurfaceContractTests`,
  `VerificationToolingContractTests`, and release-readiness CLI probes.
- Verification needed: `swift test --filter CLICommandInventoryTests`,
  `swift test --filter MachineReadableSurfaceContractTests`,
  `swift test --filter VerificationToolingContractTests`, `swift build`, and
  the `command-inventory` CLI probe.
- Confidence: high

### OE-002

- ID: OE-002
- File: `Sources/OpenLolaCore/Support/Inventories/NetworkRouteCommandMatrix.swift`
- Symbol / function / class / module: `NetworkRouteCommandMatrix`
- Category: BOILERPLATE
- Evidence: The file defines matrix-specific enums and a 12-field entry type at
  lines 3-39, summary/report wrappers at lines 70-100, and a large static
  command matrix from lines 121-630. The helper at lines 637-665 only forwards
  arguments into the entry initializer. The matrix is active through
  `network-route-command-matrix`, release-readiness probe coverage, and
  dedicated tests.
- Why this is more complex than necessary: This is mostly documentation
  crosswalk data embedded in the production Swift target, duplicating CLI
  command names, owners, report names, representative commands, tests, and
  route evidence boundaries.
- Simpler alternative: Derive route-command rows from the CLI registry plus
  report schema metadata, or move the crosswalk to a docs/tooling data file that
  the CLI can print if the command must remain.
- What could break if simplified: `network-route-command-matrix`, route matrix
  tests, source ownership inventory references, release-readiness probes, and
  any docs that treat this command as an active verification surface.
- Verification needed: `swift test --filter NetworkRouteCommandMatrixTests`,
  `swift test --filter CLICommandInventoryTests`,
  `swift test --filter VerificationToolingContractTests`, and
  `bash scripts/verify-release-readiness.sh` if touching release probes.
- Confidence: high

### OE-003

- ID: OE-003
- File: `Sources/OpenLolaCore/Support/Inventories/VideoControlDegradeMatrix.swift`
- Symbol / function / class / module: `VideoControlDegradeMatrix`
- Category: BOILERPLATE
- Evidence: The file defines matrix-specific enums and a 13-field entry type at
  lines 3-40, report/summary wrappers at lines 73-101, static entries from
  lines 122-338, and a helper that hardcodes `passEvidenceRequired: true` and
  `destructiveControlArmedByDefault: false` at lines 341-369. Tests mostly
  assert rows have existing file paths, CLI inventory coverage, and expected
  flags (`VideoControlDegradeMatrixTests.swift` lines 7-64).
- Why this is more complex than necessary: A small set of video/control policy
  facts is encoded as another bespoke report/matrix type with custom enum
  families, summaries, file-path lists, CLI surface, and release probe coverage.
- Simpler alternative: Keep the hard policy checks that matter
  (`audioProtected`, disarmed control, degrade-before-audio-impact) as focused
  tests, and move file/doc crosswalk data to docs or generated tooling.
- What could break if simplified: `video-control-degrade-matrix`,
  `VideoControlDegradeMatrixTests`, `MachineReadableSurfaceContractTests`,
  source ownership references, and release-readiness probe expectations.
- Verification needed: `swift test --filter VideoControlDegradeMatrixTests`,
  `swift test --filter IntegratedAv`, `swift test --filter IntegratedProfile`,
  and the release-readiness CLI probe if the command changes.
- Confidence: high

### OE-004

- ID: OE-004
- File: `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift`
- Symbol / function / class / module: `SourceOwnershipInventory`
- Category: OVERENGINEERING
- Evidence: The file defines five inventory-specific enums at lines 3-67, a
  broad `SourceOwnershipEntry` with ownership, risk, status, confidence,
  validation, and recommendation fields at lines 69-86, resolution/coverage
  helpers at lines 146-188, and a static ownership database from lines 191-503.
  The inventory also owns the inventory family itself at lines 485-502.
- Why this is more complex than necessary: Source ownership, suggested move
  paths, refactor risk, and improvement recommendations are planning data, but
  they are encoded as a public Swift report in the production target.
- Simpler alternative: Move ownership data to a docs-maintained table or a
  deterministic generated artifact. Keep only a narrow file-existence or
  coverage check if the repo still needs one.
- What could break if simplified: `source-ownership-inventory`, release
  readiness, source naming tests, docs that depend on source ownership, and any
  future refactor workflow that consumes this report.
- Verification needed: `swift test --filter SourceOwnershipInventoryTests`,
  `swift test --filter SourceNamingConventionTests`,
  `swift test --filter VerificationToolingContractTests`, `swift build`, and
  the release-readiness probe.
- Confidence: high

### OE-005

- ID: OE-005
- File: `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`
- Symbol / function / class / module: `ReportSchemaInventory`
- Category: DUPLICATION
- Evidence: The entry type stores schema names, families, source files,
  validators, fixtures, smoke commands, related tests, evidence classes, false
  pass counts, and notes at lines 11-25. The report is exposed as a public
  Swift inventory at lines 78-99. Static schema rows span lines 101-166. Tests
  compare validators and fixtures against other static registries
  (`ReportSchemaInventoryTests.swift` lines 52-99 and 122-153).
- Why this is more complex than necessary: Report schema facts are duplicated
  across report types, validators, CLI commands, fixture directories, smoke
  commands, tests, and this static inventory. This makes adding or renaming a
  report a multi-registry operation.
- Simpler alternative: Derive schema inventory from a single validator/report
  registry, or keep the schema index as docs/tooling data generated from the
  concrete validator list and fixture tree.
- What could break if simplified: `report-schema-inventory`, false-pass fixture
  checks, fixture smoke matrix coupling, source naming tests, release-readiness
  probes, and docs expecting the CLI inventory command.
- Verification needed: `swift test --filter ReportSchemaInventoryTests`,
  `swift test --filter FixtureSmokeMatrixTests`,
  `swift test --filter SourceNamingConventionTests`,
  `swift test --filter MachineReadableSurfaceContractTests`, and the
  `report-schema-inventory` release probe.
- Confidence: high

### OE-006

- ID: OE-006
- File: `Sources/OpenLolaCore/Core/OpenLolaCLI.swift`
- Symbol / function / class / module: `OpenLolaCLI.*Data()` and
  `OpenLolaCLI.*JSONString()` pairs
- Category: BOILERPLATE
- Evidence: The file repeats a `Data` method and a `JSONString` method for each
  report surface at lines 47-160. Most `JSONString` methods only decode the
  matching `Data` method with `String(decoding:as:)`. The real shared behavior
  is already centralized in `jsonData` and `validatedJSONData` at lines 163-176.
- Why this is more complex than necessary: The facade doubles the number of
  methods for every report without adding behavior. The CLI uses strings, while
  tests use the `Data` half, preserving both layers.
- Simpler alternative: Expose one generic pretty-JSON helper or have CLI
  commands print `Data`/`String` through a single local helper.
- What could break if simplified: Public `OpenLolaCLI` call sites, the CLI
  command implementations, and tests that directly call `*Data()` wrappers.
- Verification needed: `swift test --filter MachineReadableSurfaceContractTests`,
  `swift test --filter CLICommandInventoryTests`, `swift build --product open-lola`,
  and smoke each affected CLI command.
- Confidence: high

### OE-007

- ID: OE-007
- File: `Tests/OpenLolaCoreTests/MachineReadableSurfaceContractTests.swift`
- Symbol / function / class / module:
  `machineReadableInventoryAndMatrixJSONSurfacesRoundTrip`
- Category: BOILERPLATE
- Evidence: The test builds a 10-case array of closures at lines 8-81. Each
  case calls an `OpenLolaCLI.*Data()` wrapper, decodes it, and compares it to
  the same static report factory. It then asserts `surfaceCases.count == 10` at
  line 83 and runs each closure at lines 84-87.
- Why this is more complex than necessary: It primarily tests that wrapper
  methods serialize their own static factory output. It does not validate CLI
  argument behavior, runtime behavior, or the underlying report contracts beyond
  equality with the same source data.
- Simpler alternative: Delete this wrapper-level test after OE-006, or replace
  it with a smaller CLI smoke that verifies the actual user-facing commands emit
  parseable JSON and the expected verdict line.
- What could break if simplified: Coverage for accidental removal of
  `OpenLolaCLI.*Data()` methods and a small amount of public facade coverage.
- Verification needed: Run the replacement CLI smoke plus the focused report
  tests for each inventory/report family.
- Confidence: high

### OE-008

- ID: OE-008
- File: `Tests/OpenLolaCoreTests/ReleaseRunConfigurationContractTests.swift`
- Symbol / function / class / module:
  `releaseRunConfigurationsAndTestingIndexDocumentActiveHarnessContracts`
- Category: BOILERPLATE
- Evidence: The test defines four `contracts` rows with `path`,
  `configuration`, and `documentation` fields at lines 8-29. It never uses
  those fields to check that the files exist, the configuration symbols exist,
  or the documentation strings are present. The assertions at lines 36-42 only
  check for a docs heading, `contracts.count == 4`, and five hardcoded strings
  in `docs/testing/README.md`.
- Why this is more complex than necessary: The test looks like a contract test
  but mostly asserts static text and an unused row count.
- Simpler alternative: Delete it if docs verification already owns this, or
  replace it with an actual deterministic check that each listed source file and
  configuration symbol exists and is referenced by the testing index.
- What could break if simplified: A weak guard that currently reminds the repo
  that release harness docs should mention active harnesses.
- Verification needed: `swift test --filter ReleaseRunConfigurationContractTests`
  before removal, then the replacement docs/source existence check and
  `bash scripts/verify-docs.sh`.
- Confidence: high

### OE-009

- ID: OE-009
- File: `Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift`;
  `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`
- Symbol / function / class / module: `ReportMetadataArtifact`,
  `assertReportMetadataArtifact`
- Category: SINGLE_USE_ABSTRACTION
- Evidence: `ReportMetadataArtifact` adds `title`, `capturedAt`, and `notes`
  requirements at lines 10-14. The only observed generic use is a no-op helper
  in `ReportSchemaInventoryTests.swift` line 166, called for a handful of
  reports at lines 52-57. The active runtime validator uses the base
  `ReportValidatingArtifact` protocol at `ReportValidatorSurface.swift`
  lines 32-46.
- Why this is more complex than necessary: The marker-style protocol creates
  extra conformance surface but currently appears to enforce metadata only
  through compile-time test calls, not shared runtime behavior.
- Simpler alternative: Remove the protocol and assert required metadata in
  concrete validation tests or schema inventory checks. Keep
  `ReportValidatingArtifact`, which is broadly used by CLI validators.
- What could break if simplified: Compile-time metadata conformance checks for
  the listed release/hardware reports and any external code importing the
  protocol.
- Verification needed: `swift test --filter ReportSchemaInventoryTests`,
  `swift test --filter ReportValidatorSurface`, all public validator command
  tests, and `swift build`.
- Confidence: medium

### OE-010

- ID: OE-010
- File: `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpPlan.swift`;
  `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpWorkflow.swift`
- Symbol / function / class / module: External connector NMP plan/preflight/
  endpoint/workflow stack
- Category: SPECULATIVE_FEATURE
- Evidence: `ExternalConnectorNmpPlanConfiguration` carries LoLa, UltraGrid,
  JackTrip, audio, video, raw-link, executable, and output settings at lines
  3-31 and accepts a broad option set at lines 93-149. The plan report notes a
  "Universal NMP A/V handoff plan for LoLa, MVTP/UltraGrid, and JackTrip" at
  lines 205-215. The workflow parser repeats much of that option surface at
  `ExternalConnectorNmpWorkflow.swift` lines 12-62, and its report wraps plan,
  preflight, and endpoint-run reports at lines 66-105. `docs/source-contracts`
  marks JackTrip, UltraGrid/MVTP, and NMP workflow reports as active comparison
  or verification surfaces at lines 53-55, while `docs/architecture/p2p-networking.md`
  says JackTrip and UltraGrid are not app-launchable and are external
  connector/NMP contracts only.
- Why this is more complex than necessary: For an Open LoLa direct-media
  implementation, a universal comparison workflow spanning multiple external
  tools and executable discovery is a much broader framework than the narrow
  product runtime path. Intent is `UNCLEAR`: active docs and tests say to keep
  it, but the product boundary says these modes are comparison-only.
- Simpler alternative: Keep a LoLa-only connector workflow in the product path
  and move UltraGrid/JackTrip comparison orchestration to docs/tooling or a
  separate research harness unless current release gates require it.
- What could break if simplified: NMP CLI commands, schema inventory rows,
  external connector tests, comparison workflows, Docker/native helper flows,
  and release documentation that currently classifies NMP as active.
- Verification needed: `swift test --filter ExternalConnectorNmp`,
  `swift test --filter ExternalConnectorConnectionPlanTests`,
  `swift test --filter ExternalConnectorExecutablePreflightTests`,
  `swift test --filter ReportSchemaInventoryTests`,
  `bash scripts/verify-docs.sh`, and any external connector smoke documented in
  `docs/source-contracts/README.md`.
- Confidence: medium

### OE-011

- ID: OE-011
- File: `linux_connector/lola_connector/ethernet.py`;
  `linux_connector/lola_connector/media.py`; `linux_connector/lola_connector/__init__.py`
- Symbol / function / class / module: `build_ethernet_ipv4_udp_frame`,
  `build_ipv4_udp_packet`, public package exports
- Category: SPECULATIVE_FEATURE
- Evidence: `ethernet.py` describes itself as an optional raw
  Ethernet/IPv4/UDP frame builder for AF_PACKET/libpcap style transmitters at
  lines 1-5. `media.py` explicitly says the media layer intentionally does not
  build raw Ethernet/IP/UDP headers and that normal UDP sockets are enough when
  LoLa's pcap RX can see packets at lines 1-5. The package exports the frame
  builder publicly at `__init__.py` lines 3 and 45-48. Observed active usage is
  tests and docs/roadmap references, not the Linux connector runtime. Intent is
  `UNCLEAR`.
- Why this is more complex than necessary: A public raw Ethernet packet builder
  exists beside a normal UDP runtime that explicitly avoids raw headers. That
  preserves a low-level transport path before there is observed runtime use in
  this checkout.
- Simpler alternative: Keep raw Ethernet construction as a private test fixture
  or documented future work until an AF_PACKET/libpcap transmitter uses it.
- What could break if simplified: Public Python imports, packet codec tests,
  roadmap promises, and any unobserved local scripts using the exported helper.
- Verification needed: `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`,
  plus a usage audit outside the repo if public Python exports are treated as a
  compatibility surface.
- Confidence: medium

### OE-012

- ID: OE-012
- File: `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift`;
  `scripts/code-line-budget-exceptions.txt`
- Symbol / function / class / module: `scopedCodeFilesStayWithinLineBudget`
- Category: OVERENGINEERING
- Evidence: The test hardcodes three LOC budgets and an exception ledger path
  at lines 4-7. It scans `Package.swift`, `Sources`, `Tests`, `scripts`,
  `script`, `linux_connector`, `private`, and `.github` at lines 15-24. It then
  implements custom file enumeration, exception parsing, stale exception
  detection, vendor exclusions, and physical line counting at lines 71-212. The
  current exception ledger only contains the header row.
- Why this is more complex than necessary: A repository-wide policy scanner and
  exception ledger parser inside the Swift unit-test suite is heavy machinery
  for enforcing "keep files small." Intent is partly `UNCLEAR`: the 720-line
  policy is active, but it is not clear that this belongs in Swift unit tests or
  that scanning `private` and `.github` is the minimum correct scope.
- Simpler alternative: Move LOC policy to a small deterministic script or
  release-hygiene check, or limit enforcement to first-party code changed in the
  current slice.
- What could break if simplified: The active line-budget gate and any workflow
  relying on Swift tests to catch oversized files before review.
- Verification needed: Run the current test before moving it, then run the new
  script/hygiene gate plus `swift test --filter CodeLineBudgetTests` until the
  old test is intentionally removed.
- Confidence: medium

### OE-013

- ID: OE-013
- File: `Sources/open-lola-app/AppExecutionController.swift`
- Symbol / function / class / module: `AppExecutionController`
- Category: OVERENGINEERING
- Evidence: The controller is 720 lines. It owns observable UI state, phase
  enums, process handles, paths, report state, metrics, and errors at lines
  47-73. It builds direct-peer and Windows LoLa commands at lines 112-157,
  writes plan artifacts at lines 168-187, validates report readiness and
  context at lines 209-321, owns process launching/termination and log file
  preparation at lines 374-547, and refreshes validation reports, capture
  reports, verdicts, and log paths at lines 549-719.
- Why this is more complex than necessary: One observable UI controller combines
  command construction, process lifecycle, validation orchestration, filesystem
  log handling, report decoding, runtime evidence interpretation, and status
  text. That makes every app-launch behavior change risky and hard to review.
- Simpler alternative: Keep the observable controller as a thin state owner and
  move command construction, process execution, report loading, and validation
  evidence interpretation into small existing or new helpers with focused tests.
- What could break if simplified: App status transitions, stop behavior,
  validation behavior, Windows LoLa report handling, log-file behavior, and UI
  evidence indicators.
- Verification needed: `swift test --filter AppShellBehaviorTests`,
  `swift test --filter AppShellSlice05Tests`,
  `swift test --filter NativeAppShellTests`, app build, and a launched app
  smoke before claiming the controller was safely simplified.
- Confidence: medium

## Highest-Impact Simplification Targets

1. The executable inventory family: OE-001 through OE-005 are the largest
   simplification cluster. They encode command, schema, route, video/control,
   fixture, and ownership crosswalks as public Swift reports. A single registry
   or generated docs/tooling data source would remove substantial duplication.
2. `AppExecutionController` (OE-013). It is not a deletion candidate, but it is
   the highest-impact app simplification target because it mixes process,
   validation, report, and UI state responsibilities.
3. The external connector NMP workflow (OE-010). If comparison workflows are not
   product-critical, narrowing this to the active LoLa path could remove a broad
   speculative framework. Current docs say it is active, so this needs proof
   before implementation.

## Low-Risk Deletion Or Inlining Candidates

1. OE-008: `ReleaseRunConfigurationContractTests` is the clearest low-risk
   deletion or replacement candidate because its contract rows are unused.
2. OE-006 plus OE-007: the `OpenLolaCLI.*Data()`/`*JSONString()` duplicate
   wrapper pairs and their wrapper-level round-trip test can likely be inlined
   together, provided CLI JSON output remains covered.
3. OE-009: `ReportMetadataArtifact` can likely be removed or replaced with
   concrete metadata assertions if no external user imports it.
4. OE-011: the public Python raw Ethernet exports are candidates for narrowing
   to private/test-only helpers if an external usage audit finds no consumers.

## Risky Areas That Need More Proof Before Simplification

1. Legacy `audioCompression` / `--audio-compression` looks like compatibility
   slop, but it is actively documented as a hidden migration path in
   `docs/source-contracts/README.md` lines 30-36 and tested by
   `DirectPeerSessionOpusCLITests.swift` lines 7-106. Do not remove it without
   fixture, stored-default, report, and script inventory evidence.
2. The NMP connector stack is broad, but `docs/source-contracts/README.md`
   lines 53-60 explicitly classifies it as active and warns not to delete
   connector modes without a connector-specific audit.
3. The LOC budget gate in OE-012 may be intentionally active policy. Simplify
   the mechanism only after confirming where this policy should live.
4. Large realtime and packet files such as
   `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`,
   `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift`, and
   `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift` are large
   but high-risk. Size alone is not enough evidence to simplify them.

## Files That Are Simple Enough And Should Not Be Touched

1. `Sources/open-lola/Commands/CLICommandHelpers.swift`: the inspected
   `validateReport` helper is a small 17-line wrapper around bounded file
   reading and `ReportValidatorSurface`; it removes repeated validator boilerplate
   across many CLI commands.
2. `Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift`: the base
   `ReportValidatingArtifact` and `ReportValidatorSurface.validate` path is
   compact and widely used. Only the `ReportMetadataArtifact` marker is flagged.
3. `linux_connector/lola_connector/media.py`: the inspected header and models
   are direct payload codec logic. The raw Ethernet side path is flagged, not
   the media payload codec.
4. `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift`
   and `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift`:
   although these are process wrappers, inspected usage shows they carry
   process-group cleanup and test injection for real external executable runs.
   They are not low-risk inlining targets.

## Remaining Uncertainty

- This is a targeted simplification audit, not a complete file-by-file
  repository audit. Files not listed here are either not inspected deeply enough
  for a finding or did not produce clear overengineering evidence in this pass.
- I did not audit archived historical plans, private evidence, or vendored codec
  internals as active simplification targets.
- For public CLI/report/schema surfaces, "simpler" may still be a breaking
  change because downstream scripts or historical artifacts may consume current
  names and JSON shapes.
- Several findings are active by tests and docs. They are simplification
  candidates, not instructions to delete without the listed verification.
