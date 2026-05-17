# Overengineering Index

Date: 2026-05-16

Scope: active repository source under `Sources/`, `Tests/`, `linux_connector/`,
`scripts/`, and active `docs/` references. Vendored codec/reference trees and
archived plans were treated as background only. This is an audit document only;
no production code was changed.

Method: deterministic searches for one-off abstractions, `manager/service/provider/factory/adapter`
terms, compatibility/deprecation paths, inventory/ledger/matrix surfaces, large
files, and wrapper-heavy UI/runtime code, followed by targeted source and
call-site inspection. Usage or intent that was not proven from current source is
marked `UNCLEAR`.

## Findings

### OE-001

- ID: OE-001
- File: `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`
- Symbol / function / class / module: `ReportSchemaInventory`, `ReportSchemaInventoryEntry`, `schema(...)`
- Category: OVERENGINEERING
- Evidence: Lines 11-57 define a rich schema-entry model with version policy,
  evidence class, source file, validation files, validator commands, fixtures,
  smoke command, tests, measured-evidence flags, false-pass counts, and notes.
  Lines 101-166 then hard-code every report schema. Call-site search shows it is
  exposed as `report-schema-inventory` in `Sources/open-lola/main.swift`, checked
  by tests, and consumed by release readiness, but not generated from the actual
  validators, CLI registry, or fixture tree.
- Why this is more complex than necessary: The inventory duplicates facts that
  already live in report types, validator commands, fixture directories,
  `FixtureSmokeMatrix`, and `CLICommandInventory`. Keeping all of that in Swift
  creates a second source of truth for metadata rather than deriving it.
- Simpler alternative: Generate or verify this index from existing CLI command
  registration, fixture directories, and report-conformance metadata, or reduce
  it to a small hand-written allowlist for only the facts that cannot be derived.
- What could break if simplified: Release readiness probes, schema inventory
  tests, source naming tests, and machine-readable contract tests that assert the
  exact inventory shape.
- Verification needed: `swift test --filter ReportSchemaInventoryTests`,
  `swift test --filter FixtureSmokeMatrixTests`,
  `swift test --filter MachineReadableSurfaceContractTests`, and
  `bash scripts/verify-release-readiness.sh`.
- Confidence: medium

### OE-002

- ID: OE-002
- File: `Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift`
- Symbol / function / class / module: `FixtureSmokeMatrix.fixtureGroups`, `syntheticSmokes`
- Category: DUPLICATION
- Evidence: Lines 1-6 compose fixture groups from three static arrays. Lines
  7-43 hard-code fixture names, counts, validator commands, smoke commands,
  source files, and tests. Lines 45-76 separately hard-code synthetic smoke
  commands and owners. `ReportSchemaInventory.swift` lines 101-166 repeat much
  of the same schema, validator, fixture, smoke, source, and test information.
- Why this is more complex than necessary: Fixture counts and validator links
  are maintained manually in a second matrix instead of being derived from
  fixture folders and the report schema inventory.
- Simpler alternative: Use deterministic filesystem enumeration for counts and
  derive validator/smoke links from one authoritative registry.
- What could break if simplified: Fixture smoke matrix tests, report schema
  cross-checks, release readiness probes, and any contract expecting the current
  machine-readable report shape.
- Verification needed: `swift test --filter FixtureSmokeMatrixTests`,
  `swift test --filter ReportSchemaInventoryTests`,
  `swift test --filter VerificationToolingContractTests`.
- Confidence: high

### OE-003

- ID: OE-003
- File: `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift`
- Symbol / function / class / module: `SourceOwnershipInventory`
- Category: OVERENGINEERING
- Evidence: The file defines ownership enums, entry/report/coverage types, path
  resolution helpers, and a large static `entries` array. Call-site search shows
  the surface is exported as `source-ownership-inventory`, checked by
  `SourceOwnershipInventoryTests`, and included in release readiness probes.
  It appears to encode repository governance data in compiled Swift rather than
  as docs or a generated manifest.
- Why this is more complex than necessary: Ownership and refactor-risk metadata
  is mostly static documentation. Compiling it into the product module adds
  public types, JSON report contracts, and tests for information that could live
  in a simpler maintained document or generated manifest.
- Simpler alternative: Move ownership rows to a docs/manifest file and keep a
  small verifier that checks every active source path has a matching owner.
- What could break if simplified: The `source-ownership-inventory` CLI, release
  readiness script, machine-readable surface tests, and source ownership tests.
- Verification needed: `swift test --filter SourceOwnershipInventoryTests`,
  `swift test --filter MachineReadableSurfaceContractTests`,
  `bash scripts/verify-release-readiness.sh`.
- Confidence: medium

### OE-004

- ID: OE-004
- File: `Sources/OpenLolaCore/Support/Inventories/NetworkRouteCommandMatrix.swift`
- Symbol / function / class / module: `NetworkRouteCommandMatrix`
- Category: OVERENGINEERING
- Evidence: Lines 3-92 define route/evidence enums plus entry, summary, and
  report types. Lines 121-631 hard-code command metadata. Call-site search shows
  the matrix is exported as `network-route-command-matrix`, tested by
  `NetworkRouteCommandMatrixTests`, and also listed in `CLICommandInventory`.
- Why this is more complex than necessary: A second command inventory exists for
  a subset of network route commands. It duplicates command names, expected
  evidence boundaries, tests, and explanations that are already present in CLI
  command registration, source modules, and docs.
- Simpler alternative: Add route/evidence annotations to the main CLI inventory
  or generate this report from one command registry plus a small route metadata
  table.
- What could break if simplified: Network route matrix tests, release readiness
  probes, machine-readable surface tests, and docs that reference the matrix
  command.
- Verification needed: `swift test --filter NetworkRouteCommandMatrixTests`,
  `swift test --filter CLICommandInventoryTests`,
  `swift test --filter MachineReadableSurfaceContractTests`.
- Confidence: medium

### OE-005

- ID: OE-005
- File: `Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift`
- Symbol / function / class / module: `LoLaParityDeferredLedgerReport`, `LoLaParityDeferredFixtures`, `LoLaParityDeferredSyntheticSmoke`
- Category: SPECULATIVE_FEATURE
- Evidence: Lines 3-33 define a feature-category/status model for deferred LoLa
  parity work. Lines 83-196 define a validated report and PASS promotion rules.
  Lines 198-221 create a synthetic fixture and deprecated synthetic smoke wrapper.
  Call-site search found validators, fixtures, schema inventory rows, and tests,
  but no runtime feature implementation using the deferred-feature rows.
- Why this is more complex than necessary: Deferred feature governance is encoded
  as executable product code with PASS rules and fixtures even though the current
  usage appears to be documentation/validation scaffolding. Intent beyond that is
  UNCLEAR.
- Simpler alternative: Keep deferred parity features in a docs ledger until a
  concrete runtime promotion path exists; retain only a minimal validator if the
  JSON fixture is still a public contract.
- What could break if simplified: `validate-lola-parity-deferred-ledger`,
  `LoLaParityDeferredFeaturesTests`, fixture validation, schema inventory, and
  release readiness expectations.
- Verification needed: `swift test --filter LoLaParityDeferredFeaturesTests`,
  `swift test --filter ReportFixtureValidationContractTests`,
  `swift test --filter ReportSchemaInventoryTests`.
- Confidence: medium

### OE-006

- ID: OE-006
- File: `Sources/OpenLolaCore/Audio/Routing/AudioRoutingAssumptionLedger.swift`
- Symbol / function / class / module: `AudioRoutingAssumptionLedger`
- Category: BOILERPLATE
- Evidence: Lines 3-18 define classification and status enums. Lines 20-43
  define a ledger row type. Lines 45-120+ hard-code assumption rows. Call-site
  search found this ledger used by `MultichannelTransportTests` and referenced
  from `SourceOwnershipInventory`, but no active runtime path consumes it.
- Why this is more complex than necessary: This is a source-compiled audit
  ledger. Its current proven behavior is test/documentation accountability, not
  runtime logic.
- Simpler alternative: Move the ledger to `docs/` or a simple fixture, then keep
  a verifier that checks required IDs if the audit trail must stay enforced.
- What could break if simplified: `MultichannelTransportTests` assertions that
  classify every fixed stereo assumption, plus any docs/tests depending on the
  exact row IDs.
- Verification needed: `swift test --filter MultichannelTransportTests`.
- Confidence: high

### OE-007

- ID: OE-007
- File: `Sources/open-lola-app/AppSettings.swift`, `Sources/open-lola-app/AppStorageKeys.swift`, `Sources/open-lola-app/AppShellStoredDefaults.swift`
- Symbol / function / class / module: `AppSettings`, `AppStorageKeys`, `AppShellStoredDefaults`
- Category: BOILERPLATE
- Evidence: `AppSettings.swift` lines 8-145 define dozens of individual
  properties whose `didSet` blocks write one value to `UserDefaults`.
  `AppStorageKeys.swift` lines 3-80 define matching string keys.
  `AppShellStoredDefaults.swift` lines 55-274 manually rehydrate the same
  fields into runtime structs.
- Why this is more complex than necessary: The same settings are represented as
  storage keys, observable properties, stored-default hydration, runtime command
  fields, and SwiftUI bindings. This creates a large manual synchronization
  surface where adding or renaming one field requires touching several places.
- Simpler alternative: Store typed settings structs as one versioned app-state
  payload per subsystem, or define a small field table that drives key,
  default, load, save, and binding behavior.
- What could break if simplified: UserDefaults migration, persisted operator
  settings, app launch defaults, UI bindings, and tests for persisted Opus/audio
  transport behavior.
- Verification needed: `swift test --filter AppShellBehaviorTests`,
  `swift test --filter AppShellSlice05Tests`,
  `swift test --filter NativeAppShellOpusCommandTests`, plus a launched app
  settings smoke check.
- Confidence: high

### OE-008

- ID: OE-008
- File: `Sources/open-lola-app/AppShellSettingsView.swift`
- Symbol / function / class / module: `AppSettingsMutationPolicy`
- Category: SINGLE_USE_ABSTRACTION
- Evidence: Lines 491-500 define `executionSettingsLocked(isRunning:)` as a
  direct `isRunning` return and `help(isRunning:)` as a two-string conditional.
  Call-site search shows the wrapper is used only by `AppShellSettingsView` and
  a narrow `AppShellSlice05Tests` assertion.
- Why this is more complex than necessary: The policy object does not encode a
  reusable policy beyond the local view's `executionController.isRunning` check
  and tooltip text.
- Simpler alternative: Inline the boolean and local help text in the settings
  view, or keep a private computed property if the text needs a name.
- What could break if simplified: Tooltip copy tests and the disabled-state
  behavior for execution settings.
- Verification needed: `swift test --filter AppShellSlice05Tests` and app UI
  smoke check while a process is running.
- Confidence: high

### OE-009

- ID: OE-009
- File: `Sources/OpenLolaCore/Platform/NativeAppShellSessionMode.swift`
- Symbol / function / class / module: `NativeAppShellSessionMode`, `NativeAppShellSettingsVisibility`
- Category: SPECULATIVE_FEATURE
- Evidence: Lines 3-8 define app session modes for `directMacPeer`,
  `windowsLoLa`, `jackTrip`, and `ultraGrid`. Lines 108-135 mark JackTrip and
  UltraGrid as not supporting app execution, with a message that the app has no
  wired launcher yet. Lines 32-54 still route settings visibility for those
  modes.
- Why this is more complex than necessary: The app exposes planning modes for
  external connectors that the app explicitly cannot execute. That may be useful
  as operator planning, but active runtime value is UNCLEAR from the inspected
  source.
- Simpler alternative: Keep unsupported external connectors in CLI docs until
  app launch behavior exists, or expose them as read-only informational rows
  rather than full session modes.
- What could break if simplified: App mode selector tests, settings tab
  visibility, external connector planning UI, and any user workflow relying on
  app-generated connector commands.
- Verification needed: `swift test --filter AppShellSlice05Tests`,
  `swift test --filter NativeAppShellTests`, and app navigation/UI smoke check.
- Confidence: medium

### OE-010

- ID: OE-010
- File: `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRunTypes.swift`
- Symbol / function / class / module: `DirectPeerSessionAudioCompression`, `DirectPeerSessionAudioTransport.legacyAudioCompression`, `DirectPeerSessionAVRunConfiguration.audioCompression`
- Category: COMPATIBILITY_SLOP
- Evidence: Lines 46-62 define the legacy `DirectPeerSessionAudioCompression`
  enum. Lines 64-89 define the newer `DirectPeerSessionAudioTransport` plus a
  `legacyAudioCompression` reverse mapping. Lines 416-419 expose an
  `audioCompression` computed property over `audioTransport`. The CLI still
  accepts `--audio-compression` and maps it to transport in
  `DirectP2PSessionRunCommandSupport.swift` lines 225-243.
- Why this is more complex than necessary: Two names model the same choice for
  raw vs Opus audio, and the old name cannot represent AES67/ST2110 L24. The
  compatibility path adds conflict handling and storage migration.
- Simpler alternative: Deprecate/remove `--audio-compression` after a documented
  migration window and keep `--audio-transport` as the single public option.
- What could break if simplified: Existing CLI scripts, persisted app settings
  under `openLola.audioCompression`, tests expecting migration behavior, and
  backward-compatible report encoding.
- Verification needed: `swift test --filter DirectPeerSessionCLITests`,
  `swift test --filter NativeAppShellOpusCommandTests`,
  `swift test --filter DirectPeerTwoPeerRunPlanTests`.
- Confidence: high

### OE-011

- ID: OE-011
- File: `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpWorkflow.swift`, `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpPlan.swift`, `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpPreflight.swift`
- Symbol / function / class / module: `ExternalConnectorNmpWorkflowRunner`, `ExternalConnectorNmpPlanRunner`, `ExternalConnectorNmpPreflightRunner`
- Category: OVERENGINEERING
- Evidence: Workflow configuration lines 3-63 parse about 30 options and
  synthesize subordinate plan/preflight/endpoint paths. Lines 107-142 run three
  subordinate reports and aggregate verdicts. Plan configuration lines 3-91
  carry connector executables, audio/video parameters, raw-link parameters, and
  media packet controls. Plan validation lines 166-190 validates a generated
  bundle, while preflight lines 45-84 validate a separate preflight report.
- Why this is more complex than necessary: The NMP layer is a generic
  multi-connector workflow framework over LoLa, UltraGrid, and JackTrip. The
  current product purpose is Mac-native Open LoLa; connector orchestration may
  be useful as compatibility evidence, but the broad "universal NMP A/V"
  framework looks larger than the proven runtime need.
- Simpler alternative: Keep one explicit LoLa compatibility path and one small
  external executable preflight helper; move UltraGrid/JackTrip orchestration to
  scripts/docs until live operator use justifies a compiled workflow.
- What could break if simplified: External connector NMP plan/preflight/endpoint
  commands, validators, fixtures, app external connector planning references,
  and release readiness/schema inventory rows.
- Verification needed: `swift test --filter ExternalConnectorNmpPlanTests`,
  `swift test --filter ExternalConnectorNmpPreflightTests`,
  `swift test --filter ExternalConnectorNmpEndpointRunTests`,
  `swift test --filter ExternalConnectorNmpWorkflowTests`.
- Confidence: medium

### OE-012

- ID: OE-012
- File: `Sources/OpenLolaCore/Core/ValidationPrimitives.swift`
- Symbol / function / class / module: `ValidationEmptyFieldError`, `ReportPrimitiveValidating`, `ReportValidationProtocol`, conditional extensions
- Category: OVERENGINEERING
- Evidence: Lines 3-27 define five tiny error capability protocols plus two
  validator protocols. Lines 57-106 add conditional static helper methods based
  on combinations of those protocols. Many report validators conform only to
  gain helper calls such as `requireNonEmpty` and `requirePositive`.
- Why this is more complex than necessary: The protocol lattice saves repeated
  validation helper calls but makes simple field validation depend on associated
  types and conditional protocol composition.
- Simpler alternative: Use free functions that accept concrete error builders,
  or keep one small validator helper namespace with explicit closures for
  `emptyField`, `emptyList`, and numeric errors.
- What could break if simplified: Most report validators and their exact error
  types, plus `ValidationPrimitivesTests`.
- Verification needed: `swift test --filter ValidationPrimitivesTests` plus
  report validator tests touched by any simplification.
- Confidence: medium

### OE-013

- ID: OE-013
- File: `Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift`
- Symbol / function / class / module: `ReportMetadataArtifact`
- Category: SINGLE_USE_ABSTRACTION
- Evidence: Lines 3-8 define the central `ReportValidatingArtifact` protocol.
  Lines 10-14 define `ReportMetadataArtifact` as a metadata-bearing refinement.
  Call-site search found `ReportMetadataArtifact` used by a few report structs
  and by `ReportSchemaInventoryTests.assertReportMetadataArtifact`, but no
  runtime validator path depends on the metadata refinement.
- Why this is more complex than necessary: `ReportValidatingArtifact` is clearly
  useful, but the metadata refinement appears to be a marker for tests rather
  than a behavior-bearing abstraction. Active intent is UNCLEAR.
- Simpler alternative: Remove the metadata refinement and test the concrete
  metadata fields through report-specific validation, or make the validator
  surface actually use the metadata contract.
- What could break if simplified: Type-conformance tests and any future generic
  metadata handling not visible in current call sites.
- Verification needed: `swift test --filter ReportSchemaInventoryTests`,
  `swift test --filter ReportFixtureValidationContractTests`.
- Confidence: low

### OE-014

- ID: OE-014
- File: `Sources/OpenLolaCore/Support/BoundedFileReader.swift`
- Symbol / function / class / module: `ReportValidatingArtifact.readValidated(...)`
- Category: BOILERPLATE
- Evidence: Lines 17-64 provide bounded data/string/JSON reads. Lines 66-82 add
  a `ReportValidatingArtifact` extension that decodes and validates report files.
  This convenience couples generic file reading to the report-validation
  protocol.
- Why this is more complex than necessary: The bounded file reader is simple and
  useful, but report validation is a separate concern. The extension hides
  decode-plus-validate behavior behind a protocol extension that may be used only
  by report validators.
- Simpler alternative: Keep `BoundedFileReader` as a pure file helper and call
  `Report.decode` plus `validate()` explicitly at report validator call sites,
  unless many call sites materially benefit from the extension.
- What could break if simplified: Any validator or CLI path using
  `Report.readValidated`; exact call-site count was not fully expanded in this
  pass.
- Verification needed: `rg -n "readValidated" Sources Tests` before editing,
  then run affected validator tests.
- Confidence: low

## Highest-Impact Simplification Targets

1. Collapse the compiled inventory/matrix family (`ReportSchemaInventory`,
   `FixtureSmokeMatrix`, `SourceOwnershipInventory`, `NetworkRouteCommandMatrix`)
   into one authority surface or generated manifests. This appears to offer the
   largest reduction in duplicate metadata and manual synchronization.
2. Simplify app settings persistence (`AppSettings`, `AppStorageKeys`,
   `AppShellStoredDefaults`) by reducing the many parallel field lists.
3. Re-scope external connector NMP workflow code to proven active compatibility
   needs, especially if UltraGrid/JackTrip app/operator workflows are not used.

## Low-Risk Deletion/Inlining Candidates

1. `AppSettingsMutationPolicy`: likely inlineable after preserving the disabled
   state and tooltip copy.
2. `AudioRoutingAssumptionLedger`: likely movable to docs or a fixture because
   current proven usage is test/documentation accountability.
3. `ReportMetadataArtifact`: potentially removable if no hidden generic metadata
   consumers exist; confidence is low until call sites are exhaustively checked.

## Risky Areas That Need More Proof Before Simplification

1. `DirectPeerSessionAudioCompression` and `--audio-compression`: old scripts,
   persisted app defaults, report encoding, and public CLI behavior may still
   rely on it.
2. `ReportSchemaInventory` and related matrices: release readiness and
   machine-readable contract tests currently depend on these reports.
3. External connector NMP workflows: even if over-broad, they may encode active
   compatibility evidence handoff flows outside the source inspected here.
4. Validation primitives: broad validator usage means a simplification could
   touch many reports and error contracts.

## Files That Are Simple Enough And Should Not Be Touched

1. `Sources/OpenLolaCore/Support/MonotonicDeadline.swift`: 31 lines, direct
   monotonic deadline behavior, no speculative abstraction found.
2. `Sources/OpenLolaCore/Network/P2P/DirectPeerFNV1A.swift`: 15 lines by `wc`,
   small hash helper; no overengineering signal found.
3. `Sources/OpenLolaCore/Network/UDP/NetworkByteReader.swift`: 29 lines by `wc`,
   compact binary-read helper; no overengineering signal found.
4. `Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift`: larger than the
   other examples, but it centralizes deterministic CLI parsing and error
   mapping; do not simplify unless a focused parser audit finds duplication.

## Remaining Uncertainty

- This index is evidence-backed but not a line-by-line inspection of all 1,511
  active source/test/script/doc files counted in the initial inventory.
- Some findings may be intentional guardrails against false PASS states. Those
  are marked medium/low confidence where runtime or release intent was UNCLEAR.
- External connector usage may happen through local/manual workflows not visible
  in source call sites.
- Vendored codec/reference code and archived historical plans were not audited
  for simplification because changing them is outside the active-source scope.
- Before implementing any simplification, rerun `rg` for the exact symbol,
  inspect tests and CLI/docs contracts, then remove one narrow slice at a time.
