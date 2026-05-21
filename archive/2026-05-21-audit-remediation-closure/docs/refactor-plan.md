# Refactor and code-quality plan

Created: 2026-05-20

Scope: implementation plan derived from `AGENTS.md`, `docs/code-index.md`,
`docs/verification-baseline.md`, `docs/architecture-map.md`,
`docs/deprecation-and-simplification-audit.md`, and
`docs/logic-and-correctness-audit.md`.

This plan is executable sequence guidance, not implementation. It intentionally
orders verification trust before silent wrong behavior, runtime risk before UI
and cleanup, and evidence-gated deletion after compatibility proof.

## Implementation status

Updated 2026-05-21: all 15 planned RFP slices are implemented locally and
tracked as `COMPLETE` in `docs/remediation-ledger.md` and
`docs/remediation-status.md`. This file remains the executable slice sequence
and rationale; use the remediation ledger/status for current implementation
state and command evidence.

Product/runtime readiness is still `PARTIAL` because physical two-peer,
hardware, field, signing/notarization, clean-Mac, manual UI, and
release-approval evidence remain open. The native app accessibility/window
launch verifier passed locally after POST-APP-VERIFY-F.

## Original planning baseline

- Source verification was `PARTIAL` when this plan was created.
- Docs, Python, shell, mypy, ruff, live hygiene, and Swift builds passed in the
  planning baseline.
- The full Swift suite failed because of line-budget failures, stale fixed-path
  CLI executable tests before refresh, and a release-candidate export verifier
  failure.
- Product runtime readiness was unproven. Hardware, reference peer, Docker
  parity, app launch, signing, notarization, clean-Mac, and manual UI gates were
  not run in the planning baseline.

## Execution rules

- Implement one slice per PR unless a later reviewer explicitly combines
  adjacent low-risk test-only work.
- Do not touch files outside each slice's listed area without updating this
  plan first.
- Add or update tests before changing behavior when the slice fixes a bug.
- Do not delete compatibility paths until the slice names the usage evidence
  proving removal is safe.
- Keep `PARTIAL` and blocker language truthful unless measured evidence closes
  the stated gate.

## Sequence overview

1. RFP-001: Restore release-candidate verification truth.
2. RFP-002: Make executable CLI tests reject stale binaries consistently.
3. RFP-003: Make the line-budget gate a useful no-growth ratchet.
4. RFP-004: Add bounded Docker daemon preflight for parity scripts.
5. RFP-005: Reject weak DSCP evidence in Direct P2P PASS validation.
6. RFP-006: Add evidence-bundle verification for declared PASS artifacts.
7. RFP-007: Reject corrupt Python media reassembly gaps and overlaps.
8. RFP-008: Reject ambiguous Python control media settings.
9. RFP-009: Make structural Direct P2P quality policy visibly non-media-proof.
10. RFP-010: Prevent `runtimeErrorFree` from acting as a standalone health flag.
11. RFP-011: Lock Direct P2P legacy audio compatibility before migration.
12. RFP-012: Centralize app unsupported connector-mode behavior.
13. RFP-013: Split app-shell behavior tests without weakening coverage.
14. RFP-014: Simplify one CLI validator dispatch family.
15. RFP-015: Prove vendored source boundaries before deletion.

## Slices

### RFP-001: Restore release-candidate verification truth

- ID: RFP-001
- Title: Restore release-candidate verification truth.
- Problem: The baseline records that live docs/hygiene checks can pass while the
  staged release candidate fails. `scripts/verify-release-hygiene.sh` also uses
  the same `HYGIENE_VERDICT: PASS` label for a no-candidate live scan and a
  candidate scan, which can be misread as release-boundary proof.
- Findings addressed: LCA-005, verification-baseline release-candidate failure,
  architecture-map release candidate wrong-result risk.
- Files affected:
  - `scripts/verify-release-hygiene.sh`
  - `scripts/export-release-candidate.sh`
  - `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift`
  - `docs/code-index.md`
  - `docs/testing.md` if public command wording changes
- Behavior affected: Release hygiene output distinguishes live generated-residue
  checks from staged candidate checks. Candidate export no longer fails because
  active docs reference paths excluded from the candidate.
- Public contracts affected: Release script stdout labels and release-candidate
  docs path policy. Keep old labels only if tests prove an active consumer still
  requires them; otherwise document the label change.
- Storage/migration impact: None.
- Tests to add or update:
  - Update release hygiene tests to assert separate live and candidate verdict
    labels.
  - Add or update a staged-candidate test that catches docs references to
    allowlist-excluded paths.
  - Keep existing candidate export test as the release-boundary proof.
- Verification commands:
  - `bash scripts/verify-docs.sh`
  - `bash scripts/export-release-candidate.sh /private/tmp/open-lola-release-check`
  - `swift test --filter ReleaseArtifactHygieneContractTests --no-parallel`
  - `swift test --filter VerificationToolingContractTests --no-parallel`
- Rollback strategy: Revert the script label changes, test updates, and the docs
  path-policy adjustment together. Re-run the current baseline to confirm any
  regression is understood.
- Risk level: High.
- Ordering rationale: Release-candidate truth is a verification trust blocker;
  later slices need a reliable gate.
- Definition of Done:
  - Candidate export stages a tree and runs hygiene successfully.
  - Live no-candidate hygiene cannot be mistaken for candidate hygiene.
  - The targeted release-hygiene tests pass.
  - Any remaining product-release blocker is reported as `PARTIAL`, not `PASS`.

### RFP-002: Make executable CLI tests reject stale binaries consistently

- ID: RFP-002
- Title: Make executable CLI tests reject stale binaries consistently.
- Problem: Several executable-behavior tests prefer
  `/private/tmp/open-lola2-swiftpm-build/debug/open-lola` without the freshness
  check already present in `MachineReadableSurfaceContractTests`.
- Findings addressed: LCA-006, verification-baseline stale CLI blocker,
  architecture-map hidden coupling around fixed CLI paths.
- Files affected:
  - `Tests/OpenLolaCoreTests/MachineReadableSurfaceContractTests.swift`
  - `Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift`
  - `Tests/OpenLolaCoreTests/DirectPeerSessionCLITests.swift`
  - `Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift`
  - Other tests found by `rg "/private/tmp/open-lola2-swiftpm-build/debug/open-lola" Tests`
  - A shared test-support file under `Tests/OpenLolaCoreTests/` if reuse is
    needed by at least two current call sites
- Behavior affected: Tests fail loudly when the fixed external CLI binary is
  stale instead of passing or failing against old code.
- Public contracts affected: None. This is verification infrastructure.
- Storage/migration impact: None.
- Tests to add or update:
  - Add shared helper coverage for stale-binary rejection if practical.
  - Replace local executable-candidate helpers with the shared freshness-aware
    helper.
- Verification commands:
  - `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  - `swift test --filter MachineReadableSurfaceContractTests --no-parallel`
  - `swift test --filter CLICommandInventoryTests --no-parallel`
  - `swift test --filter DirectPeerSessionCLITests --no-parallel`
  - `swift test --filter MadiFullDuplexSessionTests --no-parallel`
- Rollback strategy: Revert the shared helper and restore previous per-test
  executable lookup.
- Risk level: Medium.
- Ordering rationale: Executable tests must point at current code before they
  can be trusted to validate later behavior changes.
- Definition of Done:
  - Every fixed-path executable test uses the same freshness rule.
  - A stale fixed binary produces an actionable failure.
  - Refreshed fixed-path builds make the targeted tests pass.

### RFP-003: Make the line-budget gate a useful no-growth ratchet

- ID: RFP-003
- Title: Make the line-budget gate a useful no-growth ratchet.
- Problem: The full Swift suite currently fails on six line-budget violations.
  Some oversized files were already in the exception ledger, while newer growth
  made the gate fail again. The gate should prevent further growth without
  blocking unrelated correctness work.
- Findings addressed: Verification-baseline line-budget blocker, DSA-008,
  DSA-009, DSA-012.
- Files affected:
  - `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift`
  - `scripts/code-line-budget-exceptions.txt`
  - Only the exact oversized files if a small behavior-preserving reduction is
    chosen instead of an exception ratchet
- Behavior affected: The line-budget test becomes an actionable ratchet: current
  known oversized files are named with reasons, stale exceptions still fail, and
  new growth above the ratchet fails.
- Public contracts affected: None.
- Storage/migration impact: None.
- Tests to add or update:
  - Update the exception ledger with current measured maximums and durable
    reasons, or reduce the exact oversized files below current limits.
  - Preserve stale-exception checks so deleted or improved files lower the
    budget.
- Verification commands:
  - `swift test --filter CodeLineBudgetTests --no-parallel`
  - `swift test --no-parallel` after RFP-001 and RFP-002 are merged
- Rollback strategy: Revert the exception ledger and any line-budget test
  policy changes.
- Risk level: Medium.
- Ordering rationale: A red global suite hides later regressions. This slice
  restores trust without doing a broad UI or test refactor.
- Definition of Done:
  - `CodeLineBudgetTests` passes.
  - Each exception names the exact file and why the temporary ceiling exists.
  - The gate still fails for newly oversized files and stale exceptions.

### RFP-004: Add bounded Docker daemon preflight for parity scripts

- ID: RFP-004
- Title: Add bounded Docker daemon preflight for parity scripts.
- Problem: Docker CLI exists on the audited host, but `docker ps` hung. Parity
  scripts call Docker commands without an explicit bounded daemon-health check.
- Findings addressed: LCA-007, DSA-016, verification-baseline Docker blocker.
- Files affected:
  - `scripts/lib/parity.sh`
  - `scripts/compare-local-ultragrid-parity-docker.sh`
  - `scripts/compare-local-jacktrip-parity-docker.sh`
  - Docker client or local RX/TX scripts under `scripts/` only if they call
    Docker before shared preflight
  - Shell policy tests if present or a new focused script test if needed
- Behavior affected: Docker parity exits quickly with a clear prerequisite
  failure when the daemon is unavailable or unresponsive.
- Public contracts affected: Script exit behavior and diagnostic text. Exit 77
  is acceptable only if existing skip-loud conventions already use it for
  missing external prerequisites.
- Storage/migration impact: None.
- Tests to add or update:
  - Add a deterministic helper test or shell-level dry-run path that simulates
    unavailable Docker and asserts bounded failure text.
  - Keep script syntax portable for macOS shell.
- Verification commands:
  - `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh`
  - `timeout 5 docker ps`
  - Run one Docker parity preflight path on a host where Docker daemon state is
    known.
- Rollback strategy: Revert shared preflight helper and script call sites.
- Risk level: Medium.
- Ordering rationale: This is a verification blocker for connector parity and
  should be fixed before connector-runtime claims rely on Docker gates.
- Definition of Done:
  - Docker scripts do not hang before reporting daemon prerequisites.
  - The failure is classified as blocked/skipped, not product failure or PASS.
  - ShellCheck passes.

### RFP-005: Reject weak DSCP evidence in Direct P2P PASS validation

- ID: RFP-005
- Title: Reject weak DSCP evidence in Direct P2P PASS validation.
- Problem: Direct P2P PASS validation requires a DSCP artifact but does not
  reject harmful, ignored, rewritten, or unobserved DSCP evidence.
- Findings addressed: LCA-001.
- Files affected:
  - `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift`
  - `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionEvidence.swift` only if a
    helper or contract name is needed
  - `Tests/OpenLolaCoreTests/DirectPeerSessionReportAVPassTests.swift`
  - Contract docs only if the accepted PASS DSCP policy changes publicly
- Behavior affected: PASS reports with harmful, ignored, rewritten, or
  unobserved DSCP evidence are rejected instead of validating.
- Public contracts affected: Direct P2P PASS validation contract and any JSON
  fixtures that previously relied on weak DSCP values.
- Storage/migration impact: Existing historical reports with weak DSCP evidence
  may validate differently. Keep archived reports as trace evidence, but do not
  promote them as current PASS proof.
- Tests to add or update:
  - Add rejection tests for `.harmful`, `.ignored`, `.rewritten`, and
    `observed == nil`.
  - Keep existing positive PASS fixture coverage for honored observed DSCP if it
    exists; add it if missing.
- Verification commands:
  - `swift test --filter DirectPeerSessionReportAVPassTests --no-parallel`
  - `swift test --filter DirectPeerSessionReportTests --no-parallel`
  - Broader Direct P2P report/fixture filters if fixture behavior changes
- Rollback strategy: Revert the validation guard and tests together.
- Risk level: High.
- Ordering rationale: This is confirmed silent wrong behavior in a high-risk
  network PASS gate.
- Definition of Done:
  - Weak DSCP evidence cannot validate as PASS.
  - Tests prove why each rejected DSCP state matters.
  - Any compatibility impact on old reports is documented.

### RFP-006: Add evidence-bundle verification for declared PASS artifacts

- ID: RFP-006
- Title: Add evidence-bundle verification for declared PASS artifacts.
- Problem: PASS report validation checks artifact declarations and hash shape,
  but the audited validator does not prove that the referenced artifact exists
  or matches the hash.
- Findings addressed: LCA-010.
- Files affected:
  - `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift`
  - A release or evidence verifier under `Sources/OpenLolaCore/Release/` or
    `Sources/OpenLolaCore/Evidence/` if bundle verification is kept separate
    from pure schema validation
  - Direct P2P PASS tests and release/evidence verifier tests
  - Public docs that explain report schema validation versus evidence-bundle
    validation
- Behavior affected: Schema validation remains portable if needed, but release
  or evidence promotion must fail when declared PASS artifacts are absent or
  hash-mismatched.
- Public contracts affected: PASS promotion workflow and evidence bundle
  verification surface. Avoid changing pure report decoding unless the contract
  explicitly moves file IO into validation.
- Storage/migration impact: Historical reports without bundled artifacts remain
  historical trace, not current promotion evidence.
- Tests to add or update:
  - Missing artifact rejection.
  - Hash mismatch rejection.
  - Existing syntactic report validation still works when used as pure schema
    validation, if that separation is retained.
- Verification commands:
  - `swift test --filter DirectPeerSessionReportAVPassTests --no-parallel`
  - `swift test --filter ReleaseArtifactHygieneContractTests --no-parallel`
  - A focused new evidence-bundle verifier filter
- Rollback strategy: Revert the new verifier and tests. Do not leave docs
  claiming artifact verification if the code is rolled back.
- Risk level: Medium.
- Ordering rationale: This closes another PASS-promotion gap before runtime or
  UI work can rely on artifact evidence.
- Definition of Done:
  - There is a deterministic verifier for declared artifact existence and hash
    content.
  - PASS promotion workflows use it.
  - Pure schema validation behavior is either preserved or intentionally
    migrated with tests.

### RFP-007: Reject corrupt Python media reassembly gaps and overlaps

- ID: RFP-007
- Title: Reject corrupt Python media reassembly gaps and overlaps.
- Problem: `MediaReassembler` can assemble frames with overlapping fragments or
  zero-filled gaps because it checks only fragment count and basic bounds.
- Findings addressed: LCA-002.
- Files affected:
  - `linux_connector/lola_connector/media.py`
  - `linux_connector/tests/test_codec.py`
- Behavior affected: Fragment sets must cover the declared frame byte range
  exactly once before a complete frame is returned.
- Public contracts affected: Python LoLa media compatibility parser. Malformed
  media that previously assembled silently will now be rejected.
- Storage/migration impact: None.
- Tests to add or update:
  - Overlapping offset rejection.
  - Missing middle range rejection.
  - Exact contiguous coverage success case.
  - Existing duplicate/out-of-range tests remain.
- Verification commands:
  - `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_codec.py`
  - `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`
  - `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`
  - `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`
- Rollback strategy: Revert `media.py` and the added tests together.
- Risk level: High.
- Ordering rationale: This is confirmed silent media corruption in the active
  compatibility seed.
- Definition of Done:
  - Malformed fragment coverage cannot produce a completed frame.
  - Tests fail for overlap and gap cases before the fix and pass after.
  - Full Python verification still passes except any known host-specific skips.

### RFP-008: Reject ambiguous Python control media settings

- ID: RFP-008
- Title: Reject ambiguous Python control media settings.
- Problem: Python control parsing truncates fractional numeric media fields and
  accepts duplicate ASCII fields with last-write-wins behavior.
- Findings addressed: LCA-003, LCA-004.
- Files affected:
  - `linux_connector/lola_connector/protocol.py`
  - `linux_connector/lola_connector/connector.py` only if QuickConn/ACK
    required-field policy belongs there
  - `linux_connector/tests/test_codec.py`
  - `linux_connector/tests/test_process_runtime.py`
- Behavior affected: Fractional numeric settings and duplicate or missing
  required QuickConn/ACK media fields are rejected unless real compatibility
  evidence proves a narrower tolerance is required.
- Public contracts affected: Python LoLa control parsing compatibility. Any
  tolerated OSC integer-valued doubles must be explicitly documented by tests.
- Storage/migration impact: None.
- Tests to add or update:
  - Reject fractional ASCII media settings.
  - Reject non-integer OSC doubles except integer-valued doubles if kept.
  - Reject duplicate QuickConn/ACK media fields.
  - Reject missing required QuickConn/ACK media fields or document a proven
    compatibility fallback.
- Verification commands:
  - `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_codec.py linux_connector/tests/test_process_runtime.py`
  - `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`
  - `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`
  - `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`
- Rollback strategy: Revert parser and tests. If compatibility evidence appears
  during the slice, narrow the rejection and document the allowed case.
- Risk level: Medium.
- Ordering rationale: This is confirmed silent wrong negotiation behavior, but
  it is lower risk than PASS evidence and media corruption.
- Definition of Done:
  - Ambiguous or fractional media settings fail loudly.
  - Any accepted compatibility tolerance has a named test and evidence comment.
  - Python full verification remains green.

### RFP-009: Make structural Direct P2P quality policy visibly non-media-proof

- ID: RFP-009
- Title: Make structural Direct P2P quality policy visibly non-media-proof.
- Problem: The structural quality policy can complete without useful media
  checks. That may be useful diagnostics, but it is easy to overread as media
  evidence unless reports and UI expose the policy clearly.
- Findings addressed: LCA-009, architecture-map Direct P2P wrong-result risk.
- Files affected:
  - `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift`
  - `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVReportBuilder.swift`
  - `Sources/open-lola/Commands/Network/DirectP2PSessionQualityPolicyCommandSupport.swift`
  - `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift`
  - Direct P2P report/CLI tests
  - App/report summary files only if they display quality-policy state
- Behavior affected: Structural runs stay valid as structural diagnostics, but
  cannot be mistaken for useful-media proof.
- Public contracts affected: Direct P2P report schema if a new explicit
  quality-policy or useful-media-proof field is added.
- Storage/migration impact: Report schema migration may be needed if a field is
  added. Preserve decoding of old reports as missing/unknown policy, not media
  proof.
- Tests to add or update:
  - Structural policy report stays `PARTIAL`.
  - Report includes explicit structural/no-useful-media-proof state.
  - Validators or UI summaries refuse to promote structural reports as useful
    media evidence.
- Verification commands:
  - `swift test --filter DirectPeerSessionCLITests --no-parallel`
  - `swift test --filter PeerSessionAVSupportTests --no-parallel`
  - `swift test --filter DirectPeerSessionReport --no-parallel`
- Rollback strategy: Revert schema/report/test changes together. If schema
  fields were added, keep backward decode tests until the rollback is complete.
- Risk level: Medium.
- Ordering rationale: This suspected false-success path sits in high-risk Direct
  P2P runtime evidence and should be closed before UI or release summaries rely
  on it.
- Definition of Done:
  - Structural mode is machine-readable and visibly not media proof.
  - Tests distinguish structural completion from useful media.
  - Old reports do not become false PASS evidence.

### RFP-010: Prevent `runtimeErrorFree` from acting as a standalone health flag

- ID: RFP-010
- Title: Prevent `runtimeErrorFree` from acting as a standalone health flag.
- Problem: External connector reports can be `PARTIAL` while
  `runtimeErrorFree == true`. That field is valid as "no error recorded" but is
  misleading if consumers display it as connected, healthy, validated, or PASS.
- Findings addressed: LCA-008, architecture-map external connector evidence
  risk, DSA-013.
- Files affected:
  - `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift`
  - `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibility.swift`
  - `Sources/OpenLolaCore/Connectors/JackTrip/JackTripCompatibility.swift`
  - `Sources/open-lola-app/` files that display external connector state
  - `Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift`
  - App-shell tests for connector status if UI wording changes
- Behavior affected: Report and UI consumers pair runtime-error absence with
  verdict and evidence completeness before showing healthy or validated states.
- Public contracts affected: Existing JSON field name is a contract. Prefer
  preserving `runtimeErrorFree` and adding clearer derived display state over
  renaming the field unless compatibility impact is explicitly accepted.
- Storage/migration impact: Existing fixtures with `runtimeErrorFree` remain
  decodable.
- Tests to add or update:
  - Partial reports with `runtimeErrorFree == true` do not produce healthy/PASS
    display state.
  - PASS validation still rejects reports with runtime errors.
  - Fixtures continue to decode.
- Verification commands:
  - `swift test --filter ExternalConnectorSessionTests --no-parallel`
  - `swift test --filter ExternalConnectorAvMatrixTests --no-parallel`
  - Focused app-shell connector-status tests if app files change
- Rollback strategy: Revert derived-state/UI changes while preserving fixture
  compatibility.
- Risk level: Medium.
- Ordering rationale: This is confirmed misleading state that can surface to
  users, but it is downstream of PASS validation and Python media correctness.
- Definition of Done:
  - `runtimeErrorFree` is never the sole source of healthy/connected/PASS UI or
    summary state.
  - Tests prove partial no-error reports remain partial in all changed
    consumers.

### RFP-011: Lock Direct P2P legacy audio compatibility before migration

- ID: RFP-011
- Title: Lock Direct P2P legacy audio compatibility before migration.
- Problem: Legacy `audioCompression`, hidden `--audio-compression`, and
  single-device `audioDeviceUID` compatibility paths remain active. They may be
  removable later, but current audits found active callers, fixtures, stored
  defaults, and report decoding concerns.
- Findings addressed: DSA-003, DSA-004, architecture-map compatibility layers.
- Files affected:
  - `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRunTypes.swift`
  - `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift`
  - `Sources/OpenLolaCore/Platform/NativeAppShellDirectPeerCommand.swift`
  - `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRuntimeReport.swift`
  - `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift`
  - `Sources/open-lola-app/AppShellStoredDefaults.swift`
  - Focused Direct P2P, realtime graph, and app defaults tests
- Behavior affected: No removal in this slice. The outcome is a tested,
  evidence-backed compatibility boundary that states which legacy paths are
  required now and which can be removed later.
- Public contracts affected: Hidden CLI flag behavior, report decode/encode,
  app defaults migration, realtime graph config decode.
- Storage/migration impact: App defaults and historical JSON reports are storage
  contracts. Any future removal must include migration or explicit breakage
  documentation.
- Tests to add or update:
  - Decode old reports with `audioCompression` and single `audioDeviceUID`.
  - Verify new reports prefer `audioTransport`, `inputDeviceUID`, and
    `outputDeviceUID`.
  - Verify app stored-defaults migration from legacy compression to transport.
  - Verify hidden flag is either still accepted deterministically or explicitly
    rejected with a documented compatibility impact.
- Verification commands:
  - `swift test --filter DirectPeerSessionOpusCLITests --no-parallel`
  - `swift test --filter DirectPeerRealtimeAudioGraphTests --no-parallel`
  - `swift test --filter NativeAppShellOpusCommandTests --no-parallel`
  - `swift test --filter DirectPeerSessionCLITests --no-parallel`
- Rollback strategy: Revert tests and any compatibility-boundary code changes.
  Do not remove legacy behavior in the rollback.
- Risk level: High.
- Ordering rationale: Deprecated compatibility paths should not be deleted until
  usage evidence and migration tests are clear.
- Definition of Done:
  - Current legacy behavior is either protected by tests or explicitly marked as
    unsupported with tests.
  - A later deletion slice can cite concrete proof instead of guessing.

### RFP-012: Centralize app unsupported connector-mode behavior

- ID: RFP-012
- Title: Centralize app unsupported connector-mode behavior.
- Problem: JackTrip and UltraGrid are selectable for planning but not app
  execution. Multiple app files repeat unsupported-mode branches, which risks
  contradictory UI state.
- Findings addressed: DSA-010, architecture-map app flow, LCA-008 downstream UI
  risk.
- Files affected:
  - `Sources/OpenLolaCore/Platform/NativeAppShellSessionMode.swift`
  - `Sources/open-lola-app/OpenLolaApp.swift`
  - `Sources/open-lola-app/AppShellRootView.swift`
  - `Sources/open-lola-app/AppTransportView.swift`
  - `Sources/open-lola-app/AppExecutionController.swift`
  - `Sources/open-lola-app/AppConsoleModels.swift`
  - App-shell tests covering session modes and unsupported execution
- Behavior affected: Unsupported app execution for JackTrip and UltraGrid is
  represented by one current owner. Planning remains available; app launch still
  fails loudly or stays disabled until runtime evidence exists.
- Public contracts affected: App UI/action disabled-state behavior and operator
  guidance. No CLI connector behavior should change.
- Storage/migration impact: None unless stored session-mode defaults are
  changed, which this slice should avoid.
- Tests to add or update:
  - Each selectable session mode has one expected app-execution capability.
  - Unsupported modes show a consistent disabled reason and do not launch.
  - CLI-only connector paths remain available outside the app.
- Verification commands:
  - `swift test --filter NativeAppShell --no-parallel`
  - `swift test --filter AppShell --no-parallel`
  - `swift build --product open-lola-app`
  - `bash script/build_and_run.sh --verify` when app UI/runtime behavior changes
- Rollback strategy: Revert centralization and restore prior branch logic.
- Risk level: Medium.
- Ordering rationale: This is UI truthfulness and duplication cleanup after the
  core connector state semantics are fixed.
- Definition of Done:
  - Unsupported connector mode behavior has one source of truth.
  - App tests prove planning-only modes cannot appear executable.
  - No new connector launch capability is introduced.

### RFP-013: Split app-shell behavior tests without weakening coverage

- ID: RFP-013
- Title: Split app-shell behavior tests without weakening coverage.
- Problem: `AppShellBehaviorTests.swift` and `AppShellSlice05Tests.swift` are
  oversized and literal-heavy. They currently contribute to line-budget failure
  and make UI truthfulness changes expensive.
- Findings addressed: DSA-012, verification-baseline line-budget blocker.
- Files affected:
  - `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
  - `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
  - New focused test files under `Tests/OpenLolaCoreTests/` only for existing
    behavior groups
  - Shared test support only when at least two current tests use it
- Behavior affected: No product behavior changes. Test organization becomes
  behavior-focused: execution gating, validation readiness, unsupported modes,
  menu/action contracts, and evidence truthfulness.
- Public contracts affected: App-shell behavior tests continue to protect public
  UI/action contracts.
- Storage/migration impact: None.
- Tests to add or update:
  - Move existing tests without lowering assertions.
  - Replace implementation-trivia assertions only when an equivalent
    user-visible behavior assertion exists.
  - Keep false-success and disabled-reason coverage intact.
- Verification commands:
  - `swift test --filter AppShellBehaviorTests --no-parallel` before the split
    as baseline if still available
  - `swift test --filter AppShell --no-parallel`
  - `swift test --filter CodeLineBudgetTests --no-parallel`
- Rollback strategy: Revert moved tests and restore original files.
- Risk level: Medium.
- Ordering rationale: Test simplification should follow behavior fixes so it
  does not hide silent wrong UI states.
- Definition of Done:
  - App-shell test coverage remains behavior-focused and passes.
  - The line-budget ratchet improves or at least does not regress.
  - No production app code changes are included in this test-only slice.

### RFP-014: Simplify one CLI validator dispatch family

- ID: RFP-014
- Title: Simplify one CLI validator dispatch family.
- Problem: CLI command and validator dispatchers contain broad hand-written
  branching that can drift from command inventory and schema inventory.
- Findings addressed: DSA-006, architecture-map CLI dispatch hidden coupling.
- Files affected:
  - `Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift`
  - `Sources/open-lola/Commands/CLICommandHelpers.swift`
  - Matching command inventory and schema tests
  - Do not touch unrelated command families in this slice
- Behavior affected: One validator dispatch family uses a smaller explicit
  table or helper for repeated `validateReport` routing. Public command names,
  help, output, and validator behavior remain unchanged.
- Public contracts affected: CLI validator command names and output must not
  change.
- Storage/migration impact: None.
- Tests to add or update:
  - Command inventory still lists the same validator commands.
  - Schema inventory and fixture validation still cover the same report types.
  - A before/after golden CLI output check if existing tests do not already
    cover the changed validators.
- Verification commands:
  - `swift test --filter CLICommandInventoryTests --no-parallel`
  - `swift test --filter ReportSchemaInventoryTests --no-parallel`
  - `swift test --filter ReportFixtureValidationContractTests --no-parallel`
  - `swift test --filter MachineReadableSurfaceContractTests --no-parallel`
- Rollback strategy: Revert validator dispatch changes and tests.
- Risk level: Medium.
- Ordering rationale: This is maintainability work and should wait until
  verification and correctness blockers are closed.
- Definition of Done:
  - The chosen validator family is simpler and still explicit.
  - Public command behavior is unchanged.
  - No broad CLI rewrite occurs.

### RFP-015: Prove vendored source boundaries before deletion

- ID: RFP-015
- Title: Prove vendored source boundaries before deletion.
- Problem: The audits identified likely vendor collateral in Opus and JPEG XS
  trees, but no first-party source file is proven safe to delete. Deletion needs
  build membership, license/update, script/doc, and release-candidate evidence.
- Findings addressed: DSA-001, DSA-002, code-index likely-dead candidates.
- Files affected:
  - `Package.swift`
  - `Sources/opus-1.5.2/`
  - `Sources/xs_ref_sw_ed2/`
  - `scripts/export-release-candidate.sh`
  - `scripts/verify-release-hygiene.sh`
  - `THIRD_PARTY_NOTICES.md`
  - Vendor boundary tests or release-hygiene tests
- Behavior affected: No deletion in the proof slice. The outcome is a checked
  source-membership and release-boundary proof that can support a later deletion
  PR if evidence is clear.
- Public contracts affected: Third-party notices and release-candidate source
  contents.
- Storage/migration impact: None.
- Tests to add or update:
  - A source-membership check that identifies exactly which vendored files are
    compiled or required by bridge headers.
  - A release-candidate test proving excluded vendor collateral is absent while
    required license/origin files remain.
  - No deletion until the proof is reviewed.
- Verification commands:
  - `swift build --product open-lola`
  - `swift test --filter ReleaseArtifactHygieneContractTests --no-parallel`
  - `bash scripts/export-release-candidate.sh /private/tmp/open-lola-vendor-boundary-check`
  - `bash scripts/verify-docs.sh`
- Rollback strategy: Revert proof tests and any release-boundary adjustments.
  Do not delete vendor files as part of rollback.
- Risk level: Medium.
- Ordering rationale: Vendor cleanup is lower priority than verification,
  correctness, and runtime truthfulness. It is still worth planning because it
  can shrink future audit surface once proven safe.
- Definition of Done:
  - The repo can prove which vendored files are compiled, released, or retained
    for license/update reasons.
  - Any future deletion PR has concrete evidence and commands to cite.
  - No unsupported vendor deletion is performed in this slice.

## Deferred work

The following areas remain important but should not start until the slices above
close or produce new evidence:

- Broad app-shell view decomposition beyond the unsupported-mode and test split
  slices.
- Direct P2P `audioCompression` or `audioDeviceUID` removal.
- Prototype-named Direct P2P two-peer command/report migration.
- NMP workflow deletion or merge into connector commands.
- Docs verifier constant/module decomposition beyond rules proven unused.
- Realtime CoreAudio graph or AVFoundation capture refactors without focused
  runtime and callback-safety tests.
- Any product `PASS` wording change without physical peer, hardware, packet,
  teardown, and report evidence.

## Verification ladder after each slice

Use the narrowest relevant checks from the slice first. Before merging a source
or verification-infrastructure slice, run the broader gates that are practical
for the changed surface:

```bash
bash scripts/verify-docs.sh
shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh
ruff check linux_connector scripts/verify_docs scripts/lib/*.py
PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector
python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py
swift build --product open-lola
swift build --product open-lola-app
swift test --no-parallel
```

If a broader check is skipped, record the exact command, reason, and next-best
verification in the PR or final response.
