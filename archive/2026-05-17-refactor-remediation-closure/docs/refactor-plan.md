# Refactor And Code-Quality Plan

Date: 2026-05-17

Verdict: PARTIAL

Purpose: convert the current audit set into small, independently reviewable
implementation slices. This is a plan only. Do not treat any slice as complete
until its listed verification has been run and recorded.

Inputs:

- `AGENTS.md`
- `docs/code-index.md`
- `docs/verification-baseline.md`
- `docs/architecture-map.md`
- `docs/deprecation-and-simplification-audit.md`
- `docs/logic-and-correctness-audit.md`

Ordering policy:

1. Fix verification infrastructure first.
2. Fix silent wrong behavior before style.
3. Fix high-risk runtime paths before cosmetic cleanup.
4. Remove dead/deprecated code only when usage evidence is clear.
5. Simplify before abstracting.
6. Avoid touching unrelated files.
7. Prefer many small PRs over one large cleanup.

## Execution Rules

- Work one slice at a time.
- Before editing a slice, re-read the listed files, direct callers, affected
  tests, public contracts, and docs named in the slice.
- Keep each slice to the files listed unless live inspection proves another file
  is required.
- If a slice changes public CLI, JSON, app storage, report, protocol, or
  compatibility behavior, document the compatibility impact in the same slice.
- For Swift build/test commands on this Mac, use an isolated build path under
  `/private/tmp` and run outside strict sandboxing if SwiftPM hits
  `sandbox-exec: sandbox_apply: Operation not permitted`.
- Do not claim full verification while `swift test --no-parallel`,
  `verify-release-hygiene.sh`, or manual runtime gates remain skipped or red.

## Slice RP-001 - Restore Release Hygiene Trust

- ID: RP-001
- Title: Remove generated residue from the live verification surface.
- Problem: `docs/verification-baseline.md` records
  `bash scripts/verify-release-hygiene.sh` failing on `.ruff_cache`, with
  `.mypy_cache` also present as likely next residue.
- Findings addressed: verification baseline release-hygiene failure; DS-007.
- Files affected: generated/cache paths only, expected `.ruff_cache/`,
  `.mypy_cache/`, and any already-generated `__pycache__` files found by the
  hygiene script. Do not edit production code.
- Behavior affected: release hygiene should fail only on real policy violations,
  not stale local cache files.
- Public contracts affected: release hygiene contract; no CLI/protocol/storage
  contract change.
- Storage/migration impact: none; generated local caches are disposable.
- Tests to add or update: none unless the hygiene script exposes an unclear
  generated-file rule.
- Verification commands:
  - `bash scripts/verify-release-hygiene.sh`
  - `bash scripts/verify-docs.sh`
  - `git diff --check`
- Rollback strategy: restore removed cache files only if they were intentionally
  tracked evidence; otherwise rerun tools to regenerate local caches.
- Risk level: low.
- Ordering rationale: release-readiness cannot be trusted until the hygiene gate
  is green or has only real blockers.
- Definition of Done: hygiene passes, docs verifier passes, no production files
  changed, and any remaining generated residue is listed with evidence.

## Slice RP-002 - Unblock The Broad Swift Test Gate

- ID: RP-002
- Title: Bring `linux_connector/tests/test_process_runtime.py` back under the
  720-line policy.
- Problem: the broad Swift test suite is red only because
  `CodeLineBudgetTests` reports `830/720 linux_connector/tests/test_process_runtime.py`.
- Findings addressed: verification baseline Swift test failure; code-index
  line-count hotspot; DS-012.
- Files affected: `linux_connector/tests/test_process_runtime.py` and one or
  more new focused Python test files under `linux_connector/tests/`.
- Behavior affected: no runtime behavior change; test organization only.
- Public contracts affected: none.
- Storage/migration impact: none.
- Tests to add or update: split existing tests by behavior area, preserving
  assertions. Do not weaken or delete coverage to satisfy the line budget.
- Verification commands:
  - `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_process_runtime.py linux_connector/tests/<new-test-file>.py`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp002 --no-parallel --filter CodeLineBudgetTests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp002 --no-parallel`
- Rollback strategy: revert the test-file split if any behavior assertion is
  lost or broad Swift tests surface unrelated failures that cannot be isolated.
- Risk level: medium.
- Ordering rationale: this is the current blocker for claiming the broad Swift
  test gate is green.
- Definition of Done: `CodeLineBudgetTests` passes, the moved Python tests pass,
  and broad Swift tests no longer fail on the line-budget guard.

## Slice RP-003 - Make Environment-Skipped UDP Selftests Truthful

- ID: RP-003
- Title: Report missing loopback alias as skipped, not passed.
- Problem: the UDP selftests in `linux_connector/tests/test_process_runtime.py`
  return successfully when `127.0.0.2` is unavailable, so no UDP behavior runs
  but pytest reports green.
- Findings addressed: LC-003.
- Files affected: the Python test file that owns
  `test_bidirectional_udp_runtime_selftest`,
  `test_control_handshake_udp_selftest`, and loopback capability helpers after
  RP-002's split.
- Behavior affected: test reporting only; runtime behavior unchanged.
- Public contracts affected: none.
- Storage/migration impact: none.
- Tests to add or update: update the two selftests to use `pytest.skip(message)`
  when the alias is missing; keep a dedicated unit test for
  `loopback_alias_capability()` missing-alias messaging.
- Verification commands:
  - `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests -k "selftest or loopback_alias"`
  - `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`
- Rollback strategy: revert to the prior tests only if the repo decides missing
  loopback alias should be a hard failure instead; do not return to false green.
- Risk level: low.
- Ordering rationale: verification credibility comes before runtime refactors.
- Definition of Done: machines without the alias report skipped UDP selftests,
  machines with the alias still execute and assert bidirectional media/control
  behavior, and full Python tests pass.

## Slice RP-004 - Fix Audio-Only Python Runtime Startup

- ID: RP-004
- Title: Do not bind the video UDP port for audio-only Python runtime runs.
- Problem: `LolaLinuxRuntime.start()` binds both audio and video sockets even
  when `transmit_video == false`, `video_capture == nil`, and `receive == false`.
- Findings addressed: LC-001.
- Files affected:
  - `linux_connector/lola_connector/runtime.py`
  - `linux_connector/lola_connector/cli.py` only if CLI option wiring must make
    the runtime intent clearer
  - relevant Python runtime tests
- Behavior affected: audio-only runs should no longer fail because the video
  port is unavailable.
- Public contracts affected: Python connector runtime behavior; CLI options
  should remain compatible.
- Storage/migration impact: none.
- Tests to add or update: add a test that pre-binds the video port and proves an
  audio-only run can start/stop without touching video resources; keep no-video
  TX assertions.
- Verification commands:
  - `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_runtime_contracts.py`
  - `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`
  - `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`
  - `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`
- Rollback strategy: restore unconditional socket binding if a documented LoLa
  compatibility requirement proves both ports must always be bound; otherwise
  keep the narrower binding.
- Risk level: high.
- Ordering rationale: this is confirmed silent wrong behavior in an active
  compatibility runtime path.
- Definition of Done: audio-only mode no longer depends on the video port,
  Python tests/lint/typecheck pass, and docs or comments explain any remaining
  port-binding requirements.

## Slice RP-005 - Align App Validation Status With Execution Report Semantics

- ID: RP-005
- Title: Make direct Mac app validation status and report verdict unambiguous.
- Problem: direct Mac validation can set app phase/status to passed while
  `NativeAppShellExecutionReport.verdict` remains `.partial` because report
  verdict derives only from external connector reports.
- Findings addressed: LC-002; architecture-map UI/report truthfulness contract;
  DS-016.
- Files affected:
  - `Sources/open-lola-app/AppExecutionController.swift`
  - `Sources/OpenLolaCore/Platform/NativeAppShellExecution.swift` only if report
    semantics need a contract adjustment
  - `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
  - app/report docs only if the public meaning changes
- Behavior affected: app validation and machine-readable execution reports
  should not disagree silently.
- Public contracts affected: native app shell execution report verdict semantics
  and UI status semantics.
- Storage/migration impact: none expected; if persisted reports change meaning,
  note compatibility impact.
- Tests to add or update: direct Mac passing, partial, and failed supervisor
  tests must assert `phase`, `status`, `hasValidatedRuntimeEvidence`, and
  `lastReport.verdict` or an explicitly separate product/readiness field.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp005 --filter AppShellBehaviorTests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp005 --filter NativeAppShell`
  - `bash scripts/verify-docs.sh`
- Rollback strategy: revert report derivation changes if they conflate product
  readiness with validation success; keep the tests documenting the intended
  distinction.
- Risk level: medium.
- Ordering rationale: false or ambiguous success states are high-risk UI/report
  behavior and should precede cleanup.
- Definition of Done: app status and report verdict semantics are explicitly
  tested for every direct-Mac validation outcome, and any `PARTIAL` product
  readiness distinction remains visible.

## Slice RP-006 - Fail Loudly On Malformed LoLa Media In Receive Reports

- ID: RP-006
- Title: Record malformed LoLa media payloads as media failures, not only valid
  envelopes.
- Problem: `LoLaCompatibilityMediaSession.receiveReport()` can mark every wire
  envelope as validated while decoded media is `.malformedFragment`.
- Findings addressed: LC-005.
- Files affected:
  - `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaSession.swift`
  - `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaCodec.swift`
    only if decode error propagation needs adjustment
  - `Tests/OpenLolaCoreTests/LoLaCompatibilityMediaSessionTests.swift`
  - report schema/inventory fixtures only if fields are added
- Behavior affected: malformed LoLa media should be visible in report fields,
  validation behavior, and tests.
- Public contracts affected: `LoLaCompatibilityMediaSessionReport` JSON schema
  if new malformed counters or error fields are added.
- Storage/migration impact: report schema change possible; preserve decoding of
  old reports unless intentionally breaking with docs.
- Tests to add or update: valid UDP envelope with malformed LoLa payload; valid
  TX/RX generated round trip; report validation for malformed counts/errors.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp006 --filter LoLaCompatibilityMediaSessionTests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp006 --filter LoLaCompatibilityMediaCodecTests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp006 --filter ExternalConnectorLoLaCompatibilityTests`
  - `bash scripts/verify-docs.sh`
- Rollback strategy: if report schema expansion is too broad, first add tests
  that document current behavior as partial and split schema work into a later
  compatibility slice.
- Risk level: medium.
- Ordering rationale: malformed compatibility media is a silent wrong-result
  risk and belongs before structural cleanup.
- Definition of Done: malformed media cannot look like clean media evidence,
  generated media still validates, and report contract changes are documented.

## Slice RP-007 - Surface Adaptive RX Buffer Controller Setup Failures

- ID: RP-007
- Title: Replace swallowed adaptive RX buffer controller creation with an
  explicit error path.
- Problem: `DirectPeerRealtimeAudioGraph` uses `try?` when creating
  `RxBufferAdaptiveController`, so an invalid adaptive policy can leave a
  snapshot saying adaptive buffering is configured with no controller.
- Findings addressed: LC-006.
- Files affected:
  - `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`
  - `Tests/OpenLolaCoreTests/DirectPeerRealtimeAudioGraphRxBufferingTests.swift`
  - `Tests/OpenLolaCoreTests/RxBufferingTests.swift` if policy fixtures need
    adjustment
- Behavior affected: invalid adaptive RX buffer setup should fail graph
  initialization instead of silently disabling adaptation.
- Public contracts affected: realtime graph initializer error behavior.
- Storage/migration impact: none.
- Tests to add or update: prove valid adaptive policy still creates a
  controller; prove invalid adaptive controller setup throws or prove the state
  is unconstructible through public API.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp007 --filter DirectPeerRealtimeAudioGraphRxBufferingTests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp007 --filter RxBufferingTests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp007 --filter DirectPeerRealtimeAudioGraphTests`
- Rollback strategy: restore prior behavior only with a test proving nil
  adaptive controller is intentionally reported and cannot be mistaken for
  active adaptation.
- Risk level: medium.
- Ordering rationale: realtime buffering correctness precedes cleanup and parser
  simplification.
- Definition of Done: controller setup failures are impossible or explicit, and
  adaptive RX buffering tests protect both success and failure paths.

## Slice RP-008 - Make RX Buffer Policy Invalid Input Recoverable

- ID: RP-008
- Title: Replace public RX buffer precondition trap with typed validation or a
  narrower construction boundary.
- Problem: public `RxBufferPolicy.init(...)` traps on `framesPerPacket <= 0`
  before validation can return `RxBufferPolicyValidationError`.
- Findings addressed: LC-007.
- Files affected:
  - `Sources/OpenLolaCore/Timing/RxBuffering.swift`
  - `Tests/OpenLolaCoreTests/RxBufferingTests.swift`
  - any report/fixture decode tests that cover RX buffer policy JSON
- Behavior affected: invalid policy data should be rejected through a typed
  error path or isolated as intentionally impossible.
- Public contracts affected: public initializer behavior for `RxBufferPolicy`.
- Storage/migration impact: possible only if decoded historical reports can
  contain invalid policy values.
- Tests to add or update: invalid `framesPerPacket` construction/decode path;
  existing factory validation tests for direct/small/adaptive/stable WAN.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp008 --filter RxBufferingTests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp008 --filter RealtimeAudioEngineTests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp008 --filter DirectPeerSessionAVRXBufferProfileTests`
- Rollback strategy: if public initializer trapping is intentional, document the
  boundary and add an isolated trap test or explicit API note instead of changing
  behavior.
- Risk level: medium.
- Ordering rationale: recoverable validation in timing contracts is safer before
  larger realtime refactors.
- Definition of Done: invalid RX buffer policy input has documented and tested
  behavior, with no accidental process crash in normal report/runtime paths.

## Slice RP-009 - Add Behavior Gates For Text-Only Verification Tests

- ID: RP-009
- Title: Separate policy text checks from behavior-proving verification.
- Problem: several tests assert source/doc/workflow text and can pass while the
  named behavior drifts.
- Findings addressed: LC-004; verification baseline "policy-only" tests note.
- Files affected:
  - `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift`
  - `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`
  - `Tests/OpenLolaCoreTests/RealtimeAudioPathInventoryTests.swift`
  - `docs/testing/README.md` if test categories are documented
- Behavior affected: test reporting and verification trust; production runtime
  unchanged.
- Public contracts affected: verification matrix expectations only.
- Storage/migration impact: none.
- Tests to add or update: add at least one command-level probe for the highest
  risk text-only checks, or explicitly classify them as documentation/policy
  tests in names/docs so they are not counted as runtime proof.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp009 --filter ReleaseArtifactHygieneContractTests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp009 --filter VerificationToolingContractTests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp009 --filter RealtimeAudioPathInventoryTests`
  - `bash scripts/verify-docs.sh`
- Rollback strategy: revert probe changes if they duplicate existing stronger
  gates; keep naming/docs that prevent false runtime claims.
- Risk level: low to medium.
- Ordering rationale: after correctness fixes, make test semantics honest before
  cleanup increases test churn.
- Definition of Done: policy/text tests are clearly separated from behavior
  tests, and at least the release-hygiene/tooling checks have executable
  behavior gates.

## Slice RP-010 - Simplify Python Process Backend Duplication

- ID: RP-010
- Title: Consolidate repeated Python process backend lifecycle code without a
  generic framework.
- Problem: `ProcessAudioCapture`, `ProcessRawVideoCapture`,
  `ProcessJpegVideoCapture`, `ProcessAudioPlayback`, and `ProcessVideoDisplay`
  repeat subprocess readiness, cleanup, and early-exit handling.
- Findings addressed: DS-012; code-index Python connector hotspot; RP-002 line
  budget follow-up.
- Files affected:
  - `linux_connector/lola_connector/backends.py`
  - Python process/backend tests split in RP-002
- Behavior affected: subprocess capture/playback/display lifecycle should remain
  identical or fail louder.
- Public contracts affected: Python backend error text may be public to tests
  and operators; keep or update intentionally.
- Storage/migration impact: none.
- Tests to add or update: process start failure, stdoutless subprocess cleanup,
  early exit, dead playback/display, JPEG/raw frame size, cleanup warnings.
- Verification commands:
  - `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_process_runtime.py linux_connector/tests/<backend-test-file>.py`
  - `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`
  - `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`
- Rollback strategy: revert to duplicated code if shared helper obscures
  behavior or weakens backend-specific error handling.
- Risk level: medium.
- Ordering rationale: simplification comes after correctness and verification
  trust, and this has multiple real call sites.
- Definition of Done: duplicated lifecycle code is reduced, behavior tests still
  pass, and no broad process framework is introduced.

## Slice RP-011 - Migrate One High-Risk Hand-Rolled Parser To The Shared Parser

- ID: RP-011
- Title: Replace the two-peer local-run hand-rolled parser with
  `KeyValueArgumentParser`.
- Problem: many command files keep custom `while index < arguments.count`
  parsers beside the shared parser. `DirectP2PTwoPeerLocalRunCommandSupport`
  is a high-risk orchestration file and a line-count hotspot.
- Findings addressed: DS-009; code-index overcomplicated CLI parser surfaces.
- Files affected:
  - `Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift`
  - `Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift`
  - key/value parser tests if shared parser behavior needs additional coverage
- Behavior affected: two-peer local-run argument parsing should retain current
  accepted flags, duplicate handling, missing-value behavior, and SSH fallback
  validation.
- Public contracts affected: CLI flags and error behavior for
  `direct-p2p-two-peer-local-run`.
- Storage/migration impact: none.
- Tests to add or update: duplicate/missing/unknown arg coverage for this
  command, `--require-preflight`, SSH fallback requirements, and dash-prefixed
  value behavior if supported.
- Verification commands:
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp011 --filter KeyValueArgumentParserTests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp011 --filter DirectPeerTwoPeerRunPlanTests`
  - `.build/debug/open-lola direct-p2p-two-peer-local-run --help` after a build,
    or an equivalent CLI smoke for parser output
- Rollback strategy: revert parser migration if exact CLI compatibility cannot
  be preserved in one slice.
- Risk level: medium.
- Ordering rationale: parser simplification is useful but must wait until
  higher-risk silent runtime behavior is handled.
- Definition of Done: one command parser is simpler, no new parser abstraction
  exists, and command-specific behavior is covered by tests/smoke.

## Slice RP-012 - Decide The `--audio-compression` Compatibility Horizon

- ID: RP-012
- Title: Prove whether legacy `audioCompression` / `--audio-compression` is
  still required before deletion.
- Problem: canonical behavior is `audioTransport`, but parser, report, app
  defaults, and stored migration paths still carry the old name.
- Findings addressed: DS-002; architecture-map compatibility layer.
- Files affected:
  - planning/inventory docs if the decision is keep/deprecate
  - if deletion is proven safe:
    `Sources/open-lola/Commands/Network/DirectP2PSessionRunArgumentSupport.swift`,
    `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift`,
    `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift`,
    `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRunTypes.swift`,
    `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRuntimeReport.swift`,
    `Sources/OpenLolaCore/Platform/NativeAppShellDirectPeerCommand.swift`,
    `Sources/open-lola-app/AppShellStoredDefaults.swift`,
    `Sources/open-lola-app/AppStorageKeys.swift`,
    related tests/docs/fixtures
- Behavior affected: CLI/report/app compatibility for legacy audio transport
  naming.
- Public contracts affected: CLI flags, JSON fields, app stored defaults.
- Storage/migration impact: high if removed; old app defaults and reports may
  stop migrating unless a deliberate migration note is kept.
- Tests to add or update: first add proof tests or inventory assertions for the
  decision; if deleting, update CLI alias tests, report fixture validation, app
  stored-default migration tests, and docs.
- Verification commands:
  - `rg -n "audioCompression|audio-compression|legacyAudioCompression|AppStorageKeys.audioCompression" .`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp012 --filter DirectPeerSessionOpusCLITests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp012 --filter NativeAppShellOpusCommandTests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp012 --filter ReportFixtureValidation`
  - `bash scripts/verify-docs.sh`
- Rollback strategy: if any live fixture, app migration, or documented workflow
  still needs the legacy name, keep compatibility and document a removal
  horizon instead of deleting.
- Risk level: high.
- Ordering rationale: deletion of compatibility paths comes after correctness
  and requires evidence, per repo policy.
- Definition of Done: a keep/remove decision exists with usage evidence; any
  code removal has matching tests/docs and explicit compatibility notes.

## Slice RP-013 - Decide The Deprecated `audioDeviceUID` Compatibility Horizon

- ID: RP-013
- Title: Prove whether the single-device realtime audio UID fallback is still
  required.
- Problem: `audioDeviceUID` is deprecated but still accepted as fallback for
  split input/output UIDs in realtime audio graph configuration.
- Findings addressed: DS-003; code-index audio realtime compatibility path.
- Files affected:
  - `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift`
  - related Core Audio/realtime graph tests and fixtures
  - docs if the compatibility horizon changes
- Behavior affected: old single-device config decoding and split device
  validation.
- Public contracts affected: JSON/config compatibility for realtime audio graph
  configuration.
- Storage/migration impact: possible old config/report decode break if removed.
- Tests to add or update: inventory old JSON/config usage; if removal is safe,
  update decode tests and add migration/explicit failure tests for old config.
- Verification commands:
  - `rg -n "audioDeviceUID" .`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp013 --filter DirectPeerRealtimeAudioGraphTests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp013 --filter DirectPeerSessionProductionAVRegressionTests`
  - `bash scripts/verify-docs.sh`
- Rollback strategy: keep the deprecated accessor if old configs/fixtures remain
  active; document why it is compatibility, not current API.
- Risk level: high.
- Ordering rationale: high-risk realtime storage compatibility should not be
  removed without proof.
- Definition of Done: compatibility decision is evidence-backed; any removal or
  retention is tested and documented.

## Slice RP-014 - Clarify The Direct P2P Prototype Report Contract

- ID: RP-014
- Title: Decide whether `DirectPeerTwoPeerPrototypeReport` is active public API
  or should be promoted/renamed.
- Problem: active measured behavior still uses "prototype" naming, which can
  mislead future cleanup into deleting or de-prioritizing the path.
- Findings addressed: DS-013; code-index likely-dead/UNCLEAR prototype command
  candidate.
- Files affected:
  - `Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift`
  - `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`
  - direct two-peer prototype/local-run tests
  - docs/command inventory if naming or status changes
- Behavior affected: report naming/status clarity only unless a rename is
  chosen.
- Public contracts affected: CLI command/report schema names if renamed.
- Storage/migration impact: high if old report schema names are changed.
- Tests to add or update: command inventory/schema inventory tests proving the
  path is active; if renamed, compatibility tests for old command/report names
  or explicit removal tests.
- Verification commands:
  - `rg -n "DirectPeerTwoPeerPrototype|direct-p2p-two-peer-prototype" Sources Tests docs scripts`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp014 --filter DirectPeerTwoPeerPrototypeReportTests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp014 --filter DirectPeerTwoPeerRunPlanTests`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp014 --filter ReportSchemaInventoryTests`
  - `bash scripts/verify-docs.sh`
- Rollback strategy: keep current names if any active public/report contract
  depends on them; add rationale instead of renaming.
- Risk level: high.
- Ordering rationale: naming/compatibility cleanup follows correctness and
  requires usage proof.
- Definition of Done: the prototype path is either documented as active public
  compatibility or renamed through a tested compatibility-aware slice.

## Slice RP-015 - Audit And Narrow External Connector Surfaces

- ID: RP-015
- Title: Decide which JackTrip, UltraGrid, and NMP surfaces remain active.
- Problem: external connector wrappers and reports are broad. The architecture
  map says they are external connector contracts and not app-launchable, while
  schema/tests/scripts still reference them.
- Findings addressed: DS-015; architecture-map external connector flow.
- Files affected:
  - `Sources/OpenLolaCore/Connectors/JackTrip/`
  - `Sources/OpenLolaCore/Connectors/UltraGrid/`
  - `Sources/OpenLolaCore/Connectors/NMP/`
  - `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`
  - connector tests, scripts, and docs only as proven necessary
- Behavior affected: none in the first decision pass; possible removal or
  documentation narrowing in follow-up.
- Public contracts affected: report schemas, CLI commands, scripts, docs.
- Storage/migration impact: possible old report/schema impact if removed later.
- Tests to add or update: add an inventory test or docs table that classifies
  each connector surface as active verification, comparison-only, or archival
  before deletion.
- Verification commands:
  - `rg -n "JackTrip|UltraGrid|NMP|external-connector" Sources Tests docs scripts`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp015 --filter ExternalConnector`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp015 --filter VerificationToolingPairScriptTests`
  - `bash scripts/verify-docs.sh`
- Rollback strategy: if usage is unclear, do not delete; leave a documented
  classification and split later removal into smaller connector-specific PRs.
- Risk level: medium to high.
- Ordering rationale: compatibility and comparison surfaces should be narrowed
  only after core verification/correctness work.
- Definition of Done: every external connector surface has an evidence-backed
  active/comparison/archive classification; no deletion occurs without tests and
  docs proving it is safe.

## Slice RP-016 - Prune Only Proven Unused Generated/Vendored Extras

- ID: RP-016
- Title: Reduce generated and vendored noise only after provenance proof.
- Problem: generated caches/backups and large vendored/reference extras add
  search/audit noise; vendored source must not be treated as first-party cleanup.
- Findings addressed: DS-007; DS-017; code-index vendored coverage gaps.
- Files affected:
  - generated residue found by release hygiene
  - possibly `Sources/opus-1.5.2/` extras and `Sources/xs_ref_sw_ed2/programs/`
    only after license/provenance approval
  - `THIRD_PARTY_NOTICES.md` and release manifest if vendored content changes
- Behavior affected: none intended for generated residue; vendored pruning could
  affect codec build/linkage if done incorrectly.
- Public contracts affected: license/release boundary, not runtime API.
- Storage/migration impact: none.
- Tests to add or update: no test changes for cache deletion; vendor pruning
  needs build/linkage/license coverage.
- Verification commands:
  - `swift build --build-path /private/tmp/open-lola2-refactor-rp016`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp016 --filter Opus`
  - `swift test --build-path /private/tmp/open-lola2-refactor-rp016 --filter JPEG`
  - `bash scripts/verify-release-hygiene.sh`
  - `bash scripts/verify-docs.sh`
- Rollback strategy: restore vendored content immediately if build, license
  notice, or provenance evidence becomes unclear.
- Risk level: low for generated cache cleanup; medium for vendored pruning.
- Ordering rationale: cleanup after behavior and compatibility decisions, with
  strong proof before deletion.
- Definition of Done: generated residue is gone; any vendor pruning has proven
  package linkage, license notices, and release hygiene intact.

## Full Closure Gate After The Last Slice

Run and record:

```bash
bash scripts/verify-docs.sh
python3 -m scripts.verify_docs
ruff check linux_connector scripts/verify_docs scripts/lib/*.py
PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector
python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py
shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh
git diff --check
bash scripts/verify-release-hygiene.sh
swift build --build-path /private/tmp/open-lola2-refactor-closure
swift test --build-path /private/tmp/open-lola2-refactor-closure --no-parallel
```

Then run `bash scripts/verify-release-readiness.sh` only after release hygiene
and broad Swift tests are green. Hardware, app-launch, signing, notarization,
Windows LoLa, Docker/native connector, and field route checks remain separate
manual/runtime evidence gates unless explicitly run.
