# Deprecation And Simplification Audit

Date: 2026-05-17
Scope: current checkout source, tests, scripts, Linux connector, active docs,
and existing source/architecture/verification inventories.
Verdict: PARTIAL. This is a static audit plus lightweight Python/shell checks.
It did not modify production code, run Swift build/tests, launch the app, run
hardware/network probes, or inspect git history.

Do not delete a compatibility path from this document without proving current
callers, fixtures, docs, reports, and runtime evidence. If usage cannot be
proven from the live tree, the finding says "needs runtime or git-history
verification."

## Commands Run

```bash
ruff check --no-cache linux_connector scripts/verify_docs scripts/lib/*.py
python -m mypy --cache-dir /private/tmp/open-lola2-mypy-audit-cache --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py
shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh
rg -n "deprecated|legacy|compatibility|fallback|backward|obsolete|TODO|FIXME|HACK|placeholder|deferred|unused|single-use|shim|wrapper|alias" Sources Tests linux_connector scripts docs -g '!archive/**'
rg -n "ProcessBackendError|class AudioBackend|LoLaParityDeferredSyntheticSmoke|ReportValidationLifecycle|validateLifecycle|var index = 0|while index < arguments.count" Sources linux_connector Tests scripts script docs -g '!archive/**'
rg -n "@available\(\*, deprecated|audioDeviceUID|audioCompression|--audio-compression|legacyAudioCompression|OpenLolaContractsAliases|typealias JSONReportCoder|WINDOWS_LOLA_VALIDATION.md|This file is kept as a compatibility pointer|control-dialect|osc15|legacy peers" Sources linux_connector Tests docs -g '!archive/**'
rg -n "KeyValueArgumentParser|parseValues|while index < arguments.count|var index = 0" Sources/open-lola Sources/OpenLolaCore Tests/OpenLolaCoreTests -g '!archive/**'
find . -path './.git' -prune -o -path './.build' -prune -o -path './Sources/opus-1.5.2' -prune -o -path './Sources/xs_ref_sw_ed2' -prune -o -type f \( -name '*.pyc' -o -name '.DS_Store' -o -name '*.bak' -o -name '*~' -o -name '*.old' -o -name '*.orig' -o -name '*.tmp' \) -print
find Sources/OpenLolaCore Sources/open-lola Sources/open-lola-app linux_connector/lola_connector scripts/verify_docs -type f \( -name '*.swift' -o -name '*.py' -o -name '*.sh' \) -exec wc -l {} + | sort -nr | head -40
```

Static checks:

- `ruff check --no-cache ...`: PASS.
- `python -m mypy --cache-dir /private/tmp/open-lola2-mypy-audit-cache --strict ...`: PASS.
- `shellcheck -x ...`: PASS.

No repo-local cache was intentionally created by this audit. Existing
`scripts/verify_docs/__pycache__/*.pyc` files were already present and remain.

## Findings

### DS-001

- ID: DS-001
- Category: deprecated internal API / unused export
- Location: `Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift:216`
- Evidence: `LoLaParityDeferredSyntheticSmoke` is explicitly marked
  `@available(*, deprecated, ...)` and only delegates to
  `LoLaParityDeferredFixtures.partialLedger()`. Current `rg` found only its
  declaration in live source.
- Why it is likely obsolete or harmful: it preserves an old synthetic-smoke name
  after tests and schema inventory already use the fixture/report path directly.
- What could break if changed: out-of-repo callers importing the deprecated
  symbol, archived scripts, or historical commands not present in this checkout.
- Suggested action: delete after public/API history check; otherwise keep with a
  documented removal horizon.
- Risk level: low to medium.
- Verification needed: `rg -n "LoLaParityDeferredSyntheticSmoke" .`, full Swift
  build, `swift test --filter LoLaParityDeferredFeaturesTests`, and runtime or
  git-history verification for external callers.

### DS-002

- ID: DS-002
- Category: obsolete compatibility branch / hidden CLI alias
- Location:
  `Sources/open-lola/Commands/Network/DirectP2PSessionRunArgumentSupport.swift:1`,
  `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift:225`,
  `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift:63`,
  `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRunTypes.swift:80`,
  `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRuntimeReport.swift:101`,
  `Sources/OpenLolaCore/Platform/NativeAppShellDirectPeerCommand.swift:52`,
  `Sources/open-lola-app/AppShellStoredDefaults.swift:98`,
  `Sources/open-lola-app/AppStorageKeys.swift:39`
- Evidence: `--audio-compression` is accepted in the allowed argument set but
  removed from public help. Code maps it to `audioTransport`, rejects conflicts,
  persists/decodes `audioCompression` compatibility fields, and migrates stored
  app defaults. Tests assert hidden alias behavior and legacy default migration.
- Why it is likely obsolete or harmful: canonical behavior is now
  `audioTransport`; the legacy name keeps parser branches, report fields,
  stored-default migration, and duplicate API accessors alive.
- What could break if changed: old scripts, old reports/plans, app user defaults,
  direct-peer report fixtures, and external CLI users.
- Suggested action: investigate. If no live old artifacts remain, remove the
  alias, JSON compatibility field, initializer fallback, and stored-default
  migration in one planned compatibility-breaking slice. If still needed, keep
  and document the deprecation horizon.
- Risk level: high.
- Verification needed: `DirectPeerSessionOpusCLITests`,
  `NativeAppShellOpusCommandTests`, two-peer run-plan tests, report fixture
  validation, docs command inventory, and runtime or git-history verification of
  old artifacts.

### DS-003

- ID: DS-003
- Category: deprecated internal API / obsolete config compatibility
- Location:
  `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift:110`
- Evidence: `audioDeviceUID` is marked deprecated with the message to use
  `inputDeviceUID` and `outputDeviceUID`; decoding still accepts legacy
  `audioDeviceUID` as fallback for both split UIDs.
- Why it is likely obsolete or harmful: it keeps a single-device config shape in
  the realtime audio graph and can mask split input/output device assumptions.
- What could break if changed: old JSON configs, tests that still construct with
  `audioDeviceUID`, and report/runtime code that expects the compatibility
  accessor.
- Suggested action: investigate before deletion. Remove only after old config
  artifacts are inventoried and migrated.
- Risk level: high.
- Verification needed: full search for old JSON artifacts, git-history check,
  `swift test --filter DirectPeerRealtimeAudioGraphTests`, direct peer AV tests,
  and a Core Audio runtime smoke on known hardware.

### DS-004

- ID: DS-004
- Category: obsolete compatibility branch / protocol dialect compatibility
- Location:
  `linux_connector/lola_connector/cli.py:44`,
  `linux_connector/lola_connector/protocol.py:295`,
  `linux_connector/lola_connector/connector.py:279`,
  `linux_connector/lola_connector/runtime.py:318`
- Evidence: the Python connector supports `--control-dialect ascii|osc15|auto`.
  Code sends both dialects in auto mode, builds/parses OSC15 datagrams, and
  comments say legacy peers need mirrored fields. Tests still cover OSC15 and
  auto-dialect behavior.
- Why it is likely obsolete or harmful: if OSC15 is no longer a tested live
  compatibility lane, it doubles control-plane parsing/response behavior and
  can drift from the active ASCII path.
- What could break if changed: LoLa 1.5/Tester compatibility probes, packet
  reproduction, tests, and any operator workflows using `--control-dialect
  osc15|auto`.
- Suggested action: keep until a live compatibility decision is made. If no
  current runtime need exists, delete the OSC15 branch and tests in a dedicated
  compatibility slice.
- Risk level: medium.
- Verification needed: Python codec/runtime/process tests, one live or
  fixture-backed OSC15 probe if retained, docs update, and needs runtime or
  git-history verification.

### DS-005

- ID: DS-005
- Category: legacy protocol compatibility path
- Location:
  `docs/architecture/audio-routing.md:52`,
  `docs/architecture/multichannel-transport.md:33`,
  `Sources/OpenLolaCore/Core/OpenLolaCLI.swift`,
  `Sources/OpenLolaCore/Network/UDP/MultichannelTransport.swift`
- Evidence: active docs classify UDP PCM v1 as legacy/fallback, while source
  capability and transport code still support v1 alongside v2.
- Why it is likely obsolete or harmful: carrying a v1 packet shape increases
  protocol negotiation and test surface while current multichannel/realtime work
  is v2-oriented.
- What could break if changed: v1 fixtures, old route smokes, v1-only peers, and
  docs that still document v1 fallback.
- Suggested action: keep for now. Only delete after proving no supported peer,
  fixture, or report validator depends on v1.
- Risk level: high.
- Verification needed: UDP packet tests, multichannel transport tests, route
  report tests, fixture validation, and needs runtime or git-history verification
  for v1 peers.

### DS-006

- ID: DS-006
- Category: compatibility pointer docs / likely obsolete files
- Location:
  `linux_connector/WINDOWS_LOLA_VALIDATION.md:1`,
  `linux_connector/WINDOWS_WSL_LINUX_LOLA_BRINGUP.md:1`
- Evidence: both root files state they are kept only as compatibility pointers
  for older links and redirect to canonical docs under `linux_connector/docs/`.
- Why it is likely obsolete or harmful: they duplicate navigation and keep old
  link surfaces alive after canonical docs moved.
- What could break if changed: external bookmarks, older local scripts/docs, or
  archived references that expect these root paths.
- Suggested action: investigate link usage. Delete or move to archive only if
  inbound links/git history show they are no longer needed; otherwise keep as
  intentional compatibility shims.
- Risk level: low.
- Verification needed: `rg` for path references, docs verifier, external link
  check if available, and needs runtime or git-history verification.

### DS-007

- ID: DS-007
- Category: generated residue / unused files
- Location:
  `scripts/verify_docs/__pycache__/*.pyc`,
  `archive/2026-05-10-superseded-plans-audits-goals/generated/re_out/ghidra_proj/LolaGhidra.rep/*/~index.bak`
- Evidence: `find` found Python bytecode under `scripts/verify_docs/__pycache__`
  and two Ghidra `~index.bak` files under archived generated output. The
  verification baseline records release hygiene is sensitive to generated cache
  residue.
- Why it is likely obsolete or harmful: bytecode and backup files are generated
  artifacts, not source; they add noise and can trip release-hygiene policy.
- What could break if changed: local tool speed for bytecode; archive forensic
  traceability for Ghidra backups if those files were intentionally retained.
- Suggested action: delete generated cache files in a cleanup-only task; review
  archive provenance before deleting Ghidra backups.
- Risk level: low.
- Verification needed: `bash scripts/verify-release-hygiene.sh`,
  `bash scripts/verify-docs.sh`, Python checks with `PYTHONDONTWRITEBYTECODE=1`,
  and archive provenance review.

### DS-008

- ID: DS-008
- Category: wrapper/re-export compatibility layer
- Location:
  `Sources/OpenLolaCore/Core/OpenLolaContractsAliases.swift:1`,
  `Tests/OpenLolaCoreTests/OpenLolaContractsTargetTests.swift:22`
- Evidence: `OpenLolaCore` publicly typealiases five `OpenLolaContracts`
  symbols. Tests explicitly assert that `OpenLolaCore` re-exports extracted
  contracts for existing callers.
- Why it is likely obsolete or harmful: it duplicates public names across
  targets and hides whether callers can depend on the smaller contract target.
- What could break if changed: existing Swift callers importing only
  `OpenLolaCore`, plus tests and any external package source.
- Suggested action: keep until a deliberate public API cleanup. Do not delete as
  incidental simplification.
- Risk level: high.
- Verification needed: full Swift build/tests, package import smoke, release
  notes, and needs runtime or git-history verification for external callers.

### DS-009

- ID: DS-009
- Category: duplicated parser logic / boilerplate
- Location:
  `Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift:1`,
  `Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift:105`,
  `Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift:570`,
  `Sources/OpenLolaCore/Control/LightingFixtureGateRun.swift:69`,
  `Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift:133`,
  `Sources/OpenLolaCore/Control/OscCueProbe.swift:509`,
  `Sources/OpenLolaCore/Evidence/HardwareValidationRun.swift:103`,
  `Sources/OpenLolaCore/Network/P2P/MacToMacConnectionEstablishment.swift:332`,
  `Sources/OpenLolaCore/Video/VideoCaptureRunConfiguration.swift:77`,
  `Sources/OpenLolaCore/Connectors/NMP/*.swift`
- Evidence: a shared `KeyValueArgumentParser` exists and is used by some
  commands, but many live parsers still hand-roll `var index = 0` /
  `while index < arguments.count` loops with duplicate unknown/duplicate/missing
  value checks.
- Why it is likely obsolete or harmful: duplicate CLI parsing logic makes error
  behavior drift and keeps boilerplate in runtime command types.
- What could break if changed: exact error text, acceptance of dash-prefixed
  values, command-specific optional semantics, and tests that assert parser
  behavior.
- Suggested action: replace hand-rolled loops with `KeyValueArgumentParser`
  opportunistically when editing a command. Do not create another parser
  abstraction.
- Risk level: medium.
- Verification needed: `KeyValueArgumentParserTests`, command-specific tests,
  command inventory/schema inventory checks, and CLI smoke probes for changed
  commands.

### DS-010

- ID: DS-010
- Category: endless switch chains / command-surface boilerplate
- Location:
  `Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift:4`,
  `Sources/open-lola/Commands/MilestoneCommands.swift:4`,
  `Sources/open-lola/Commands/Network/NetworkCommands.swift:5`
- Evidence: validation, milestone, and network command routing are long switch
  chains with many repeated `args.count == 2 && args[0] == "validate-..."` and
  report-write cases. `NetworkCommands.swift` and `MilestoneCommands.swift` are
  also line-count hotspots.
- Why it is likely obsolete or harmful: every new report requires repeated edits
  across router, schema inventory, tests, docs, and output text; drift is easy.
- What could break if changed: CLI command names, stdout wording, validator
  output, `VERDICT` behavior, app command builders, scripts, and docs.
- Suggested action: investigate a small table-driven router only if a command
  surface change is already in scope and at least two routers benefit. Avoid a
  broad framework for cleanup alone.
- Risk level: medium to high.
- Verification needed: `command-inventory`, `report-schema-inventory`,
  `CLICommandInventoryTests`, report validator tests, release-readiness probes,
  docs verifier, and scripts that call `open-lola`.

### DS-011

- ID: DS-011
- Category: wrapper helpers that add little value / duplicated validation style
- Location:
  `Sources/OpenLolaCore/Video/VideoCaptureHelpers.swift:3`,
  `Sources/OpenLolaCore/Core/ValidationPrimitives.swift:109`
- Evidence: video capture helpers such as `requireVideoCaptureNonEmpty`,
  `requireVideoCapturePositive`, and `requireVideoCaptureFinite` mostly forward
  directly to `ValidationPrimitives`, while other report families use
  `ReportPrimitiveValidating` extensions.
- Why it is likely obsolete or harmful: subsystem-specific wrappers obscure a
  common validation style and add helper names without much behavior.
- What could break if changed: exact `VideoCaptureValidationError` cases,
  UInt32/UInt64 helper coverage, and video-specific packet-age ordering.
- Suggested action: simplify by inlining trivial wrappers or migrating to the
  common primitive style when editing video validation. Keep domain-specific
  functions such as packet-age ordering and percentile calculation.
- Risk level: medium.
- Verification needed: `VideoCaptureReportTests`, video capture inventory/tests,
  fixture validation, and docs verifier for any report schema changes.

### DS-012

- ID: DS-012
- Category: duplicated subprocess backend logic / overengineering risk
- Location: `linux_connector/lola_connector/backends.py:342`
- Evidence: `ProcessAudioCapture`, `ProcessRawVideoCapture`, and
  `ProcessJpegVideoCapture` repeat command normalization, process storage,
  start/read/aclose patterns; `ProcessAudioPlayback` and `ProcessVideoDisplay`
  repeat stdin write lifecycle. A `ProcessLifecycleMixin` already centralizes
  part of this behavior.
- Why it is likely obsolete or harmful: subprocess cleanup and early-exit fixes
  can be applied to one backend and missed in another.
- What could break if changed: async process cleanup, cancellation, stdout/stderr
  error text, media pacing, and tests simulating process exit.
- Suggested action: simplify only with a focused backend task. A small helper is
  justified by current multiple read-side and write-side call sites; do not add
  a generic process framework.
- Risk level: medium.
- Verification needed: `python -m pytest linux_connector/tests/test_process_runtime.py`,
  ruff, mypy, and a subprocess capture/playback smoke if available.

### DS-013

- ID: DS-013
- Category: misleading name / stale prototype terminology
- Location:
  `Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift:3`,
  `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift:114`
- Evidence: source comments say to keep "prototype" until a promoted
  non-prototype schema exists. Schema inventory still exposes
  `DirectPeerTwoPeerPrototypeReport` as a measured report, while local supervisor
  commands also exist.
- Why it is likely obsolete or harmful: active measured behavior named
  "prototype" can mislead cleanup work into treating the path as disposable or
  less public than it is.
- What could break if changed: public command/report names, schema inventory,
  tests, app/supervisor output references, archived reports, and docs.
- Suggested action: investigate promotion status. Either keep with explicit
  rationale or rename in a planned compatibility-aware slice with old-name
  deprecation.
- Risk level: high.
- Verification needed: command inventory, schema inventory, two-peer plan/local
  run tests, source naming tests, docs verifier, and needs runtime or git-history
  verification.

### DS-014

- ID: DS-014
- Category: compatibility branches for old behavior
- Location:
  `Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift:86`,
  `Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift:186`,
  `Sources/OpenLolaCore/Network/P2P/MacToMacConnectionEstablishment.swift:130`,
  `docs/architecture/p2p-networking.md`
- Evidence: NAT reports track `rendezvousOnly` and `relayFallback`; Mac-to-Mac
  connection establishment treats relay fallback as a blocker; docs call
  relay/rendezvous compatibility/fallback, not default fastest media.
- Why it is likely obsolete or harmful: fallback compatibility code can expand
  setup complexity and false-success risk if confused with direct UDP/IP proof.
- What could break if changed: NAT-friendly route tests, app preflight, route
  evidence reports, and operators behind NAT/firewall who need explicit fallback
  evidence.
- Suggested action: keep as explicit compatibility evidence. Do not delete until
  field evidence and product policy say relay/rendezvous are unsupported.
- Risk level: high.
- Verification needed: NAT route tests, Mac-to-Mac connection tests, app shell
  tests, route docs, and live route probes.

### DS-015

- ID: DS-015
- Category: wrappers / external connector overengineering risk
- Location:
  `Sources/OpenLolaCore/Connectors/JackTrip/`,
  `Sources/OpenLolaCore/Connectors/UltraGrid/`,
  `Sources/OpenLolaCore/Connectors/NMP/`,
  `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`
- Evidence: architecture map says JackTrip and UltraGrid are external connector
  contracts and are not app-launchable; schema inventory nevertheless includes
  connection-plan, preflight, endpoint-run, workflow, and executable-preflight
  reports for external connectors.
- Why it is likely obsolete or harmful: if these external connector workflows
  are not active verification gates, they add a broad planning/runtime surface
  that can distract from direct Open LoLa and Windows LoLa work.
- What could break if changed: NMP plans, connector preflight tests, scripts,
  external process workflows, and docs comparing NMP tools.
- Suggested action: investigate usage. Keep report contracts that are active in
  tests/docs; delete only proven-unused connector modes or app-facing controls.
- Risk level: medium to high.
- Verification needed: connector tests, scripts grep, docs/testing review,
  command inventory, and needs runtime or git-history verification.

### DS-016

- ID: DS-016
- Category: mixed responsibilities / overcomplicated file
- Location: `Sources/open-lola-app/AppExecutionController.swift:1`
- Evidence: the file is 701 lines and owns app execution phase, arming, command
  building, process lifecycle, log file preparation/opening, validation
  readiness, external connector report refresh, latency/capture evidence, and
  report finishing.
- Why it is likely obsolete or harmful: a UI-facing controller with process,
  filesystem, validation, and evidence aggregation responsibilities is difficult
  to reason about and can produce misleading status if one branch drifts.
- What could break if changed: app run/stop/validate behavior, status text,
  stdout/stderr log handling, external connector validation, and runtime evidence
  gating.
- Suggested action: simplify only after an app execution audit. Prefer extracting
  or inlining toward existing app/core boundaries only where it removes concrete
  responsibility mixing; do not add generic controller frameworks.
- Risk level: high.
- Verification needed: app shell behavior tests, native app shell tests, Windows
  LoLa app command tests, command preview checks, docs verifier, and launched-app
  runtime probe.

### DS-017

- ID: DS-017
- Category: vendored/reference unused files / boilerplate
- Location:
  `Sources/opus-1.5.2/`,
  `Sources/xs_ref_sw_ed2/programs/`,
  `Package.swift`
- Evidence: `Package.swift` lists an explicit small source subset for `COpus`
  and sets `CJpegXSReference` path to `Sources/xs_ref_sw_ed2/libjxs`. The
  checkout still contains large Opus training/docs/tests/demo trees and JPEG XS
  program entrypoints outside `libjxs`.
- Why it is likely obsolete or harmful: vendored extras inflate repository size
  and audit noise, and first-party searches return irrelevant TODO/FIXME and
  training code.
- What could break if changed: license obligations, upstream-vendor update
  ability, reference-code provenance, codec tests, or scripts expecting the full
  vendor tree.
- Suggested action: investigate vendor-pruning policy. Do not edit vendored
  code as first-party cleanup; if pruning is approved, preserve license/notices
  and document exact upstream source provenance.
- Risk level: medium.
- Verification needed: Swift build, Opus/JPEG XS codec tests, license notice
  review, release candidate export/hygiene, and needs git-history verification.

## Highest-Value Deletion Candidates

1. `LoLaParityDeferredSyntheticSmoke` if external usage is disproven.
2. Existing generated caches and backup files after a cleanup-only task.
3. Root Windows connector compatibility pointer docs if link usage is disproven.
4. Vendored extras only after a deliberate vendor-pruning policy decision.

## Highest-Risk Compatibility Candidates

1. `--audio-compression` / `audioCompression` compatibility.
2. Deprecated `audioDeviceUID` realtime graph config fallback.
3. UDP PCM v1 compatibility.
4. Direct P2P "prototype" report naming.
5. OpenLolaCore contract re-export aliases.
6. NAT rendezvous/relay fallback paths.

## Likely Overcomplicated Areas

- CLI validation, milestone, and network command routers.
- Hand-rolled key/value parsers beside `KeyValueArgumentParser`.
- App execution/process/report controller.
- Python process-backed media backend lifecycle.
- External connector NMP/JackTrip/UltraGrid planning surfaces.
- Vendored/reference source trees that are larger than the compiled target
  surface.

## Areas Not Proven Safe To Delete

- LoLa compatibility code: active tests and docs still protect it.
- JackTrip/UltraGrid/NMP connectors: current report schema/tests mention them.
- `OpenLolaContractsAliases.swift`: tests prove it is deliberate compatibility.
- UDP PCM v1 support: still documented as legacy/fallback and likely fixture
  backed.
- NAT fallback/rendezvous: compatibility evidence lane, not default path.
- Vendored Opus/JPEG XS code: requires license/provenance review.

## Recommended Next Audit Targets

1. Run a git-history/public-API check for `--audio-compression`,
   `audioCompression`, `audioDeviceUID`, and `LoLaParityDeferredSyntheticSmoke`.
2. Inventory old report/config fixtures for legacy keys before deleting any
   JSON decode fallback.
3. Audit command inventory, schema inventory, and router switches together.
4. Audit `AppExecutionController` with a running-app probe before changing its
   phases or report refresh behavior.
5. Decide whether JackTrip/UltraGrid/NMP are active product surfaces, comparison
   docs, or archival compatibility lanes.
6. Decide whether vendored codec trees must remain full upstream snapshots.

## Coverage Gaps And Uncertainty

- Swift build and Swift tests were not run for this audit.
- No app UI, hardware, Windows LoLa, Docker, JackTrip, UltraGrid, or real network
  runtime was exercised.
- No git-history analysis was run, so compatibility paths marked investigate
  need runtime or git-history verification.
- Public API usage outside this checkout was not checked.
- The working tree was already dirty. This audit records live-tree evidence but
  does not distinguish committed baseline from unrelated in-progress edits.
