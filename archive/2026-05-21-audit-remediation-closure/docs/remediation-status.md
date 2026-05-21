# Remediation status

Updated: 2026-05-21

Source of truth: `docs/refactor-plan.md`. Post-plan audit-continuation fixes
are tracked below when they address unresolved audit findings without changing
the completed RFP slice list.

## Overall state

Refactor-plan implementation: COMPLETE.

Active goal completion: PARTIAL. Local audit-remediation slices are complete,
but `docs/benchmark-e2e-av.md` still requires physical two-peer benchmark
evidence before product `PASS`.

## Current or last slice

- Last completed slice: RFP-015, Prove vendored source boundaries before
  deletion.
- Last completed post-plan audit-continuation fix: POST-APP-VERIFY-F,
  native app accessibility/window verifier recheck.
- Current slice: none. All slices in `docs/refactor-plan.md` are complete.
- Current priority: continue only with bounded source-completable audit
  reductions; do not start broad app, parser, CLI router, or UI rewrites
  without a written slice plan.
- Current action: keep product benchmark status `PARTIAL` until physical
  two-peer evidence exists. The latest unsandboxed completion audit refresh on
  2026-05-21,
  `/private/tmp/open-lola-goal-completion-audit-2026-05-21-continuation-refresh-unsandboxed.json`,
  still reports `PARTIAL`:
  Core Audio inventory captured 2 devices, AVFoundation captured 2 video
  devices with camera permission authorized, but there are 0 RME MADI
  candidates, 0 Blackmagic/ATEM candidates, 0 Developer ID Application
  identities, and 21 completion blockers. The blocker classes are missing
  RME MADI hardware, missing physical receiver-side RME receive/mix evidence,
  missing physical two-peer/direct-route run evidence, missing Blackmagic/ATEM/
  DeckLink/UltraStudio hardware, missing field/signing/notarization evidence,
  pending license/notice/fixture-provenance decisions, missing reviewer
  signoff, and blocked public release approval. Fresh benchmark-specific source
  smokes on 2026-05-21 also remain `PARTIAL`: benchmark and hardware validation
  rows are synthetic/not measured, and the current evidence matrix still has
  11 open real-world tasks.

## Refactor-plan slice counts by status

| Status | Count |
|---|---:|
| NOT_STARTED | 0 |
| IN_PROGRESS | 0 |
| BLOCKED | 0 |
| DEFERRED | 0 |
| IMPLEMENTED | 0 |
| VERIFIED | 0 |
| COMPLETE | 15 |

These counts cover only the 15 implementation slices from
`docs/refactor-plan.md`. They do not count the active goal's external
benchmark, hardware, signing, release, and approval blockers; the latest
completion audit still records 21 such blockers.

## Highest remaining priority

The planned verification-infrastructure blockers, first false-success slices,
Direct P2P legacy audio compatibility lock, unsupported connector app execution
route, app execution-preparation owner, app-shell behavior-area test splits,
first CLI validator dispatch simplification, second CLI validator dispatch
simplification, custom-output milestone validator dispatch simplification,
milestone runtime report-write deduplication, milestone runtime stdout
JSON/verdict deduplication, vendored source-boundary proof, NMP active-use
proof, first external connector parser split, and connector-scoped
external-session flag rejection are remediated. App settings visibility now
uses the existing app execution route owner for unsupported connector modes.
Unused internal app execution command helpers are removed, and shared app
execution state/readiness definitions, command-preview generation, plan-write
preparation, and evidence/log/report helper types are split out of the
controller. `AppExecutionController.swift` is now 712 lines and below the base
line budget, so its exception row was removed. The duplicate app-console
validation-readiness helper is also deduped while the larger console model,
settings draft workflow, and app shell section views are now split below the
base line budget.
The native app launch verifier now passes on this host. Earlier strict
verifier failures printed captured accessibility stderr and visible-window
evidence, identifying the former blocker as missing System Events/AX window
access instead of a missing app window or generic missing-label failure.
POST-APP-VERIFY-C added explicit app activation before System Events capture
and reports frontmost before and after activation; the latest outside-sandbox
verifier still failed with `frontmostBeforeActivation=false`,
`frontmostAfterActivation=false`, and `accessibilityWindows=0` while
CoreGraphics saw the visible Open LoLa window.
POST-APP-VERIFY-D reran the strict app verifier after the app menu cleanup and
confirmed the current bundle still has the same AX blocker: CoreGraphics sees
the `Open LoLa` window, while System Events reports zero accessibility windows.
POST-APP-VERIFY-E reran the strict app verifier after the app execution
state/readiness split and confirmed the same blocker remained on that rebuilt
bundle. POST-APP-VERIFY-F reran the strict verifier outside the sandbox and it
now exits 0 with non-empty accessibility UI, window-list, and screenshot
evidence for `dist/OpenLoLa.app`; the previous app AX launch blocker is locally
closed.
The deprecation audit's next-target summary no longer points at the already
centralized unsupported JackTrip/UltraGrid app execution branches.
The logic audit's summary now distinguishes original findings from current
remediation status and no longer recommends already-completed LCA slices as
next work.
The refactor plan now separates the original planning baseline from the current
implementation status, so its pre-remediation Swift-suite failures are not
misread as the live state after the completed RFP slices.
The fixed-path CLI freshness helper now scopes freshness to the `open-lola`
product inputs and no longer treats app-only source changes as stale CLI
evidence. Direct P2P legacy audio compatibility was rechecked and remains an
active compatibility surface, not a deletion target without a separate
migration decision.
The last hand-rolled milestone stdout JSON/verdict path for
`latency-profile-synthetic-smoke` now uses the existing validated JSON helper;
POST-DSA-006-F rechecked the remaining runtime command special paths and
retained them because they have behavior-specific validation, extra public
output lines, source-report prevalidation, or multi-report writes. Runtime
command branch dispatch remains intentionally explicit.
POST-DSA-007-A rechecked the manual CLI command, report schema, source
ownership, and machine-readable surface inventory tables and retained them as
active public contract metadata. No generator should be introduced unless a
written slice replaces at least two duplicate tables with behavior-preserving
verification.
POST-DSA-016-B moved the repeated parity-backed output-directory fallback into
`parity_output_dir` for six UltraGrid/JackTrip RX/TX and comparison scripts,
and POST-DSA-016-C moved the repeated managed Docker RX/TX cleanup loop into
`parity_stop_docker_containers_by_name_prefix`, while keeping connector command
lines explicit.
The docs verifier no longer keeps the single-use `PUBLIC_CURRENT_STATE_DOCS`,
`WINDOWS_CORPUS`, or internal `ARCHIVED_DOC_IGNORE_PATHS` intermediates;
current docs-verifier policy remains otherwise unchanged.
External connector session parsing now rejects LoLa raw-link-only CLI flags for
UltraGrid and JackTrip before launch-plan validation. It also rejects
`--video-compression` and `--video-bayer` outside LoLa and rejects
`--lola-video-payload` for JackTrip, while preserving UltraGrid's active
`--lola-video-payload avfoundation-raw8` media-provider path.
POST-DSA-013-E rechecked the remaining shared parser flags against LoLa,
UltraGrid, JackTrip, and tests; no additional ignored connector-scoped CLI flag
was proven safe to delete without a new connector-specific behavior change.
POST-DSA-009-E now preserves the app validation preflight's
`Evidence incomplete` state after a validation exit code 0 when current runtime
evidence is missing, stale, or still `PARTIAL`; it no longer presents that
operator state as a generic last-validation-failed blocker.
The third-party notice draft no longer points at the archived
`docs/compliance` path; it points at the active release boundary and manifest.
The open-questions ledger also records the unsandboxed 2026-05-21 hardware and
release evidence instead of the older sandbox-inflated device/permission
summary.
Release readiness remains `PARTIAL` because the source license, documentation
license, notice finalization, fixture provenance, reviewer signoff, and public
release approval are human/legal/release decisions that must not be invented.
No planned refactor-plan slice remains open.

## Active goal completion audit

Objective restated: audit and fix remaining actionable issues from
`docs/benchmark-e2e-av.md`, `docs/deprecation-and-simplification-audit.md`,
`docs/refactor-plan.md`, and `docs/logic-and-correctness-audit.md`.

Checklist:

- `docs/refactor-plan.md`: all 15 RFP slices are implemented and recorded
  COMPLETE in `docs/remediation-ledger.md`.
- `docs/logic-and-correctness-audit.md`: LCA-001 through LCA-010 are mapped to
  completed RFP slices with passing verification evidence.
- `docs/deprecation-and-simplification-audit.md`: DSA findings with clear
  local fixes or proof slices are remediated. Deletion/migration candidates
  remain evidence-gated when runtime, git-history, legal, or compatibility
  proof is missing. POST-DSA-011-B removed the single-use
  `AppMenuActionHandling.isHandled` wrapper; the remaining handled-action ID
  set is still the explicit menu-action to surface-contract coverage point.
- `docs/benchmark-e2e-av.md`: source-level benchmark contracts and validators
  are covered, but the document still says `Verdict: PARTIAL` because physical
  two-peer benchmark evidence has not been collected in this checkout.
- Completion decision: do not mark the active goal complete while benchmark
  physical evidence, field/signing/notarization evidence, and release-approval
  gates remain open.

Prompt-to-artifact checklist:

| Requirement | Evidence inspected | Current result |
|---|---|---|
| Audit and fix `docs/refactor-plan.md` issues | `docs/remediation-ledger.md` rows RFP-001 through RFP-015, full `swift test --no-parallel`, and POST-RFP-PLAN-A | COMPLETE locally; all planned slices have passing recorded verification. POST-RFP-PLAN-A reconciled the plan header so it now points to the remediation ledger/status for current state and marks the old failures as the original planning baseline. |
| Audit and fix `docs/logic-and-correctness-audit.md` issues | LCA-001 through LCA-010 mapped to RFP-001, RFP-002, and RFP-004 through RFP-010 plus verification rows in `docs/remediation-ledger.md`; POST-LCA-SUMMARY-A and POST-LCA-ENTRY-A | COMPLETE locally; silent-wrong and false-success findings have targeted tests and broader verification. POST-LCA-SUMMARY-A reconciled the audit tail so it now names re-audit triggers and remaining runtime evidence gaps instead of stale already-completed implementation targets. POST-LCA-ENTRY-A reconciled the individual LCA-001 through LCA-010 entries so their status, missing-test, and suggested-fix fields point to completed RFP evidence while preserving original evidence. |
| Audit and fix actionable `docs/deprecation-and-simplification-audit.md` issues | RFP-003, RFP-004, RFP-010 through RFP-015, POST-DSA-005-A, POST-DSA-006-A through F, POST-DSA-007-A, POST-DSA-008-A through D, POST-DSA-009-A through E, POST-DSA-010-B through D, POST-DSA-011-B, POST-DSA-013-A through D, POST-DSA-014-A, POST-DSA-015-A through E, POST-DSA-016-A through C, POST-RFP-003-A through C, POST-DSA-012-A through K, DSA-011 recheck, and POST-DSA-LINE-A | COMPLETE for completed bounded slices; POST-DSA-013-B now rejects mismatched UltraGrid/JackTrip connector-specific session flags before defaults can silently ignore them, POST-DSA-013-C rejects LoLa raw-link-only CLI flags for UltraGrid/JackTrip before launch-plan validation, and POST-DSA-013-D rejects ignored LoLa video-control CLI flags outside LoLa while preserving UltraGrid's active `--lola-video-payload avfoundation-raw8` path. POST-DSA-010-C routes settings visibility through the existing app execution route owner instead of an unreachable unsupported-mode settings branch, and POST-DSA-010-D removes the stale next-target wording that still pointed at already-centralized unsupported JackTrip/UltraGrid app execution branches. POST-DSA-008-A removed unused internal app execution command helpers after source/test search showed no call sites, POST-DSA-008-B split shared execution state/readiness definitions out of the controller, POST-DSA-008-C split evidence/log/report helper types out of the controller, and POST-DSA-008-D split command preview plus plan-write/default-log helpers out while removing the controller line-budget exception. POST-DSA-009-A deduped app-console validation-readiness policy into one helper owned by the existing execution route, POST-DSA-009-B split validation-preflight models into a focused file while removing the console line-budget exception, POST-DSA-009-C split settings draft workflow into a focused file while removing the settings line-budget exception, POST-DSA-009-D split app shell section views into a focused file while removing the root-view line-budget exception, and POST-DSA-009-E preserves the app validation preflight's `Evidence incomplete` state after validation exit 0 when runtime evidence is missing, stale, or partial. POST-DSA-LINE-A refreshed stale line-count evidence for the remaining app controller and split app-shell test surfaces. POST-DSA-006-D centralized repeated milestone stdout JSON/verdict output, POST-DSA-006-E folded the remaining `latency-profile-synthetic-smoke` custom stdout path into that helper, POST-DSA-006-F retained the remaining special runtime command paths with evidence, and branch-visible command dispatch remains explicit. POST-DSA-007-A rechecked the active command/schema/source/machine-readable inventory tables and retained them as public contract metadata rather than introducing a speculative generator. POST-DSA-015-D removed two single-use docs-verifier constants after source/test/docs proof found no external references, and POST-DSA-015-E inlined the internal archived-doc-ignore manifest intermediate. POST-DSA-016-B deduped the repeated parity-backed output-directory fallback, and POST-DSA-016-C deduped the repeated managed Docker RX/TX cleanup loop while keeping connector command lines explicit. POST-DSA-010-B centralized app execution preparation while retaining JackTrip/UltraGrid planning-only behavior. POST-DSA-011-B removed the single-use `AppMenuActionHandling.isHandled` wrapper while retaining the handled-action ID set as explicit surface-contract coverage. Remaining deletion/migration candidates explicitly require git-history, runtime, legal, or compatibility proof before change. Large app/UI files, broad CLI router rewrites, and deeper connector-specific parser splits still require separately planned behavior-preserving slices before broad rewrites. |
| Make verification failures actionable without claiming runtime success | POST-APP-VERIFY-A through F, `script/build_and_run.sh`, and `AppBundleScriptSourcePolicyTests` | COMPLETE locally. Earlier verifier slices made AX/window failures actionable without claiming success. POST-APP-VERIFY-F reran `bash script/build_and_run.sh --verify` outside the sandbox; it exited 0 and produced `dist/app-launch-evidence/manifest.txt`, `window-list.txt`, `accessibility-ui.txt`, empty `accessibility-error.txt`, `os-log.txt`, `process.pid`, and `screenshot.png`. The local app AX launch gate is closed, while manual UI/product runtime evidence remains separate. |
| Do not delete compatibility paths without evidence | DSA-003, DSA-004, DSA-005, DSA-014, DSA-017 and `docs/source-contracts.md` | SATISFIED; compatibility paths are locked or canonical aliases were added without breaking old surfaces. |
| Keep benchmark/product evidence truthful | `docs/benchmark-e2e-av.md`, `/private/tmp/open-lola2-swiftpm-build/debug/open-lola e2e-benchmark-synthetic-smoke`, `hardware-validation-synthetic-smoke`, `current-evidence-status-matrix`, `goal-runtime-preflight-run`, and `goal-completion-audit-run` | BLOCKED for completion; all current benchmark/runtime evidence remains `PARTIAL` because physical two-peer/hardware evidence is absent. The POST-GOAL-REFRESH-D unsandboxed completion audit at `/private/tmp/open-lola-goal-completion-audit-2026-05-21-continuation-refresh-unsandboxed.json` emitted 21 blockers, while the sandboxed run still inflated that to 26. Refreshed benchmark/hardware/matrix smokes still report only synthetic or open real-world evidence. |

## Latest broad verification refresh

- `swift test --no-parallel`: PASS on 2026-05-21 after POST-DSA-016-B with
  868 Swift Testing tests.
  Swift Testing reported the existing 4 skipped LoLa UDP control
  retry/fallback tests.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`:
  PASS with 114 passed and 2 skipped. The skipped tests are still blocked by
  unavailable loopback alias capability on this host.
- `RUFF_CACHE_DIR=/private/tmp/open-lola2-final-ruff-cache ruff check linux_connector scripts/verify_docs scripts/lib/*.py`:
  PASS.
- `MYPY_CACHE_DIR=/private/tmp/open-lola2-final-mypy-cache python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`:
  PASS with no issues in 22 source files.
- `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh`:
  PASS.
- `OPEN_LOLA_DOCKER_PREFLIGHT_TIMEOUT_SECONDS=5 bash -lc 'source scripts/lib/parity.sh; parity_require_docker_daemon "Goal Docker parity refresh"'`:
  BLOCKED with exit 77 because Docker daemon did not respond within 5s to
  `docker ps`. A raw `docker ps` probe also hung and was terminated with exit
  143. Full Docker parity was not run.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with the known `sandbox_apply: Operation not permitted`
  manifest error; the outside-sandbox rerun passed and refreshed the fixed-path
  `open-lola` binary.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-post-statusb-unsandboxed.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial` plus
  `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-runtime-preflight-report /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-post-statusb-unsandboxed.json`:
  PASS and emitted `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-statusb-unsandboxed.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial`,
  `blockers: 21`, `next-actions: 21`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-statusb-unsandboxed.json`:
  PASS and emitted `blockers: 21`, `next-actions: 21`, and
  `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-statusb.json`
  in the sandbox: PASS but reported the sandbox-inflated `blockers: 26`; the
  unsandboxed POST-STATUS-B run above supersedes it for current status.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola open-source-release-readiness-run --output /private/tmp/open-lola-open-source-release-readiness-2026-05-21-final-current.json`:
  PASS and emitted `requirements: 9`, `blockers: 6`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-open-source-release-readiness-report /private/tmp/open-lola-open-source-release-readiness-2026-05-21-final-current.json`:
  PASS and emitted `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-continuation-refresh-unsandboxed.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial` plus
  `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-runtime-preflight-report /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-continuation-refresh-unsandboxed.json`:
  PASS and emitted `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-continuation-refresh-unsandboxed.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial`,
  `blockers: 21`, `next-actions: 21`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-continuation-refresh-unsandboxed.json`:
  PASS and emitted `blockers: 21`, `next-actions: 21`, and
  `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-continuation-refresh.json`
  in the sandbox: PASS but reported the sandbox-inflated `blockers: 26`; the
  unsandboxed POST-GOAL-REFRESH-D run above supersedes it for current status.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola open-source-release-readiness-run --output /private/tmp/open-lola-open-source-release-readiness-2026-05-21-continuation-refresh.json`:
  PASS and emitted `requirements: 9`, `blockers: 6`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-open-source-release-readiness-report /private/tmp/open-lola-open-source-release-readiness-2026-05-21-continuation-refresh.json`:
  PASS and emitted `VERDICT: PARTIAL`.
- `security find-identity -v -p codesigning`: PASS and reported 1 valid local
  identity, `Apple Configurator: Hochschule für Musik und Tanz Köln
  (B2C2A968-28C2-49BA-A389-2FB07AD66465)`, and no Developer ID Application
  identity.
- `codesign -dv --verbose=4 dist/OpenLoLa.app`: PASS for inspection and
  reported `Signature=adhoc` plus `TeamIdentifier=not set`.
- `spctl -a -vv dist/OpenLoLa.app`: FAIL with exit 1 and
  `internal error in Code Signing subsystem`.
- `xcrun notarytool history`: FAIL with exit 64 because credentials were not
  provided. Signing, Gatekeeper, and notarization remain blocked.
- `system_profiler SPAudioDataType SPCameraDataType SPThunderboltDataType SPUSBDataType`:
  PASS for inventory collection. The visible audio section was empty, both
  Thunderbolt/USB4 ports reported no connected device, and no USB hardware was
  listed.
- `system_profiler SPAudioDataType SPCameraDataType SPThunderboltDataType SPUSBDataType | rg -i "RME|MADI|Blackmagic|ATEM|DeckLink|UltraStudio"`:
  no matches, expected exit 1. RME MADI and Blackmagic/ATEM/DeckLink/
  UltraStudio hardware gates remain open.
- `bash script/build_and_run.sh --verify` outside the sandbox: PASS. The
  verifier rebuilt `open-lola-app` and `open-lola`, launched
  `dist/OpenLoLa.app`, and wrote native app launch evidence to
  `dist/app-launch-evidence`.
- `cat dist/app-launch-evidence/window-list.txt`: PASS and captured an
  `Open LoLa` window with bounds `Width = 1280`, `Height = 847`.
- `head -n 80 dist/app-launch-evidence/accessibility-ui.txt`: PASS and
  captured non-empty accessibility/menu/window UI including operator console
  sections.
- `cat dist/app-launch-evidence/accessibility-error.txt`: PASS with empty
  output.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola e2e-benchmark-synthetic-smoke`:
  PASS and emitted `VERDICT: PARTIAL`; all benchmark profile rows remain
  synthetic with `physicalEvidence: false`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola hardware-validation-synthetic-smoke`:
  PASS and emitted `VERDICT: PARTIAL`; all hardware lanes remain synthetic,
  not measured, and `physicalEvidence: false`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola current-evidence-status-matrix`:
  PASS and emitted `VERDICT: PARTIAL`; the matrix still lists 11 open
  real-world tasks and one blocked release-field-closure lane.
- `bash scripts/export-release-candidate.sh /private/tmp/open-lola-release-check-final-current`:
  PASS and emitted `RELEASE_HYGIENE_VERDICT: PASS` plus
  `RELEASE_CANDIDATE_EXPORT_VERDICT: PASS`.
- `bash scripts/verify-release-hygiene.sh`: first failed on generated local
  cache residue in `.ruff_cache` and `scripts/verify_docs/__pycache__`; after
  removing those generated caches, rerun passed with
  `LIVE_RESIDUE_HYGIENE_VERDICT: PASS`.
- `bash scripts/verify-docs.sh`: PASS after this status refresh.
- `git diff --check`: PASS after this status refresh.

## Last commands and result

- `swift test --filter AppUnsupportedConnectorExecutionTests --no-parallel`:
  PASS after POST-DSA-008-D, 2 Swift Testing tests.
- `swift test --filter AppShellExecutionControllerTests --no-parallel`: PASS
  after POST-DSA-008-D, 4 Swift Testing tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after removing
  the stale `AppExecutionController.swift` line-budget exception, 1 Swift
  Testing test.
- `wc -l Sources/open-lola-app/AppExecutionController.swift Sources/open-lola-app/AppExecutionCommandPreview.swift Sources/open-lola-app/AppExecutionEvidenceSupport.swift Sources/open-lola-app/AppExecutionPreparation.swift`:
  `AppExecutionController.swift` is 712 lines,
  `AppExecutionCommandPreview.swift` is 44 lines,
  `AppExecutionEvidenceSupport.swift` is 191 lines, and
  `AppExecutionPreparation.swift` is 37 lines after POST-DSA-008-D.
- `swift test --filter AppShellExecutionControllerTests --no-parallel`: PASS
  after POST-DSA-008-C, 4 Swift Testing tests.
- `swift test --filter AppShell --no-parallel`: PASS after POST-DSA-008-C,
  90 Swift Testing tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after lowering
  the `AppExecutionController.swift` line-budget exception to 788 lines, 1
  Swift Testing test.
- `wc -l Sources/open-lola-app/AppExecutionController.swift Sources/open-lola-app/AppExecutionEvidenceSupport.swift`:
  `AppExecutionController.swift` is 788 lines and
  `AppExecutionEvidenceSupport.swift` is 174 lines after POST-DSA-008-C.
- `swift test --filter CLICommandInventoryTests --no-parallel`: PASS after
  POST-DSA-007-A, 5 Swift Testing tests.
- `swift test --filter ReportSchemaInventoryTests --no-parallel`: PASS after
  POST-DSA-007-A, 6 Swift Testing tests.
- `swift test --filter SourceOwnershipInventoryTests --no-parallel`: PASS
  after POST-DSA-007-A, 4 Swift Testing tests.
- `swift test --filter MachineReadableSurfaceContractTests --no-parallel`:
  PASS after POST-DSA-007-A, 7 Swift Testing tests.
- `bash script/build_and_run.sh --verify` outside the sandbox: FAILED
  strictly after POST-APP-VERIFY-E. The verifier rebuilt the current app bundle
  and still failed with `frontmostBeforeActivation=false`,
  `frontmostAfterActivation=false`, and `accessibilityWindows=0` while
  CoreGraphics captured a visible `Open LoLa` window. This keeps the native app
  AX label gate blocked rather than closed.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola e2e-benchmark-synthetic-smoke`
  outside the sandbox: PASS after POST-GOAL-REFRESH-C and emitted
  `VERDICT: PARTIAL`; all benchmark profile rows remain synthetic with
  `physicalEvidence: false`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola hardware-validation-synthetic-smoke`
  outside the sandbox: PASS after POST-GOAL-REFRESH-C and emitted
  `VERDICT: PARTIAL`; all hardware-validation lanes remain synthetic and
  not measured.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola current-evidence-status-matrix`
  outside the sandbox: PASS after POST-GOAL-REFRESH-C and emitted
  `VERDICT: PARTIAL`; the matrix still lists 11 open real-world tasks.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-post-appverifye.json`
  outside the sandbox: PASS after POST-GOAL-REFRESH-C and emitted
  `VERDICT: PARTIAL`; runtime preflight reports 2 audio devices, 2 video
  devices, 0 RME MADI candidates, 0 Blackmagic/ATEM candidates, and
  0 Developer ID Application identities.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-appverifye.json`
  outside the sandbox: PASS after POST-GOAL-REFRESH-C and emitted
  `real-world-verdict: partial`, `blockers: 21`, `next-actions: 21`, and
  `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-appverifye.json`
  outside the sandbox: PASS after POST-GOAL-REFRESH-C and emitted
  `real-world-verdict: partial`, `blockers: 21`, `next-actions: 21`, and
  `VERDICT: PARTIAL`.
- `rg -n "isHandled\\(" Sources/open-lola-app Tests/OpenLolaCoreTests docs/deprecation-and-simplification-audit.md docs/remediation-status.md docs/remediation-ledger.md`:
  no matches after POST-DSA-011-B, expected exit 1.
- `swift test --filter AppShellSlice05Tests --no-parallel`: PASS after
  POST-DSA-011-B, 22 Swift Testing tests.
- `swift test --filter AppShell --no-parallel`: PASS after POST-DSA-011-B,
  90 Swift Testing tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after
  POST-DSA-011-B, 1 Swift Testing test.
- `bash scripts/verify-docs.sh`: PASS after POST-DSA-011-B docs updates.
- `git diff --check`: PASS after POST-DSA-011-B.
- `swift test --filter AppBundleScriptSourcePolicyTests --no-parallel`: PASS
  after POST-APP-VERIFY-C with 7 Swift Testing tests.
- `shellcheck -x script/build_and_run.sh`: PASS after POST-APP-VERIFY-C.
- `bash script/build_and_run.sh --verify` outside the sandbox: FAILED
  strictly after POST-APP-VERIFY-C. The verifier now attempts app activation
  before System Events capture and reports
  `frontmostBeforeActivation=false`, `frontmostAfterActivation=false`, and
  `accessibilityWindows=0` while CoreGraphics still sees the visible
  Open LoLa window.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-app-verify-c.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial`,
  `blockers: 21`, `next-actions: 21`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-app-verify-c.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 21`,
  `next-actions: 21`, and `VERDICT: PARTIAL`.
- `rg -n "ARCHIVED_DOC_IGNORE_PATHS" scripts/verify_docs Tests`: no matches
  after POST-DSA-015-E, expected exit 1.
- `python3 -m scripts.verify_docs`: PASS after POST-DSA-015-E.
- `ruff check scripts/verify_docs`: PASS after POST-DSA-015-E.
- `MYPY_CACHE_DIR=/private/tmp/open-lola2-dsa015e-mypy-cache python -m mypy --strict scripts/verify_docs`:
  PASS after POST-DSA-015-E, no issues in 10 source files.
- `swift test --filter DocsVerifierPolicyTests --no-parallel`: PASS after
  POST-DSA-015-E, 4 tests.
- `wc -l scripts/verify_docs/constants.py scripts/verify_docs/markdown_checks.py`:
  `constants.py` is 435 lines and `markdown_checks.py` is 463 lines after
  POST-DSA-015-E.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-continuation-refresh.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial`,
  `blockers: 21`, `next-actions: 21`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-continuation-refresh.json`
  outside the sandbox: PASS and emitted `blockers: 21`, `next-actions: 21`,
  and `VERDICT: PARTIAL`.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with the known `sandbox_apply: Operation not permitted`
  manifest error; the outside-sandbox rerun passed after POST-DSA-009-E and
  refreshed the fixed-path `open-lola` binary.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa009e-current.json`:
  sandboxed run passed but reported the sandbox-inflated `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`; superseded by the unsandboxed
  current audit below.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa009e-current-unsandboxed.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial`,
  `blockers: 21`, `next-actions: 21`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa009e-current-unsandboxed.json`:
  PASS and emitted `blockers: 21`, `next-actions: 21`, and
  `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola e2e-benchmark-synthetic-smoke`
  outside the sandbox: PASS and emitted `VERDICT: PARTIAL`; all benchmark
  profile rows remain synthetic with `physicalEvidence: false`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola hardware-validation-synthetic-smoke`
  outside the sandbox: PASS and emitted `VERDICT: PARTIAL`; all hardware lanes
  remain synthetic, not measured, and `physicalEvidence: false`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola current-evidence-status-matrix`
  outside the sandbox: PASS and emitted `VERDICT: PARTIAL`; the matrix still
  lists 11 open real-world tasks and one blocked release-field-closure lane.
- `python3 -c ... /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa009e-current-unsandboxed.json`:
  PASS. Confirmed the current unsandboxed completion audit reports
  `verdict partial`, 21 blockers, and 21 next actions.
- `bash scripts/verify-release-hygiene.sh`: PASS after the POST-DSA-009-E
  completion-audit status refresh with `LIVE_RESIDUE_HYGIENE_VERDICT: PASS`.
- `bash scripts/export-release-candidate.sh /private/tmp/open-lola-release-check-post-dsa009e-current`:
  PASS and emitted `RELEASE_HYGIENE_VERDICT: PASS` plus
  `RELEASE_CANDIDATE_EXPORT_VERDICT: PASS`; product release readiness still
  remains `PARTIAL` until license, notices, reviewer, signing, clean-Mac,
  hardware, and benchmark gates close.
- `swift test --no-parallel`: PASS after POST-DSA-009-E, 867 Swift Testing
  tests. Swift Testing reported the existing 4 skipped LoLa UDP control
  retry/fallback tests.
- `bash scripts/verify-docs.sh`: PASS after the POST-DSA-009-E
  completion-audit status refresh.
- `git diff --check`: PASS after the POST-DSA-009-E completion-audit status
  refresh.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`:
  PASS after the POST-DSA-009-E status refresh, 114 passed and 2 skipped.
  The skipped tests still require loopback alias support that is unavailable
  on this host.
- `swift test --filter AppShellBehaviorTests --no-parallel`: PASS after
  POST-DSA-009-E, 9 tests.
- `swift test --filter AppShell --no-parallel`: PASS after POST-DSA-009-E,
  90 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after
  POST-DSA-009-E, 1 test.
- `wc -l Sources/open-lola-app/AppValidationConsoleModels.swift Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`:
  `AppValidationConsoleModels.swift` is 257 lines and
  `AppShellBehaviorTests.swift` is 704 lines after POST-DSA-009-E.
- `bash scripts/verify-docs.sh`: PASS after POST-DSA-009-E docs updates.
- `git diff --check`: PASS after POST-DSA-009-E.
- `swift test --filter ExternalConnectorSessionParsingTests --no-parallel`: PASS
  after POST-DSA-013-D, 5 tests.
- `swift test --filter ExternalConnectorSession --no-parallel`: PASS after
  POST-DSA-013-D, 15 tests.
- `swift test --filter ExternalConnectorAvMatrixTests --no-parallel`: PASS
  after POST-DSA-013-D, 4 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after
  POST-DSA-013-D, 1 test.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox_apply: Operation not permitted`; rerun
  outside the sandbox passed after POST-DSA-013-D.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola external-connector-session-run --connector mvtp-ultragrid --role tx --peer 198.51.100.20 --output /private/tmp/open-lola2-ug-video-compression-reject.json --video-compression 1`:
  failed fast as expected with `unknownArgument("--video-compression")`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola external-connector-session-run --connector jacktrip --role tx --peer 203.0.113.10 --output /private/tmp/open-lola2-jacktrip-lola-video-payload-reject.json --peer-audio-port 4464 --lola-video-payload avfoundation-raw8`:
  failed fast as expected with `unknownArgument("--lola-video-payload")`.
- `swift test --filter CLICommandInventoryTests --no-parallel`: PASS after
  POST-DSA-013-D, 5 tests.
- `swift test --filter MachineReadableSurfaceContractTests --no-parallel`:
  PASS after POST-DSA-013-D, 7 tests.
- `wc -l Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionConfigurationParsing.swift Tests/OpenLolaCoreTests/ExternalConnectorSessionParsingTests.swift`:
  `ExternalConnectorSession.swift` is 642 lines,
  `ExternalConnectorSessionConfigurationParsing.swift` is 219 lines, and
  `ExternalConnectorSessionParsingTests.swift` is 148 lines.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa013d.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa013d.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`.
- `swift test --filter ExternalConnectorSessionParsingTests --no-parallel`: PASS
  after POST-DSA-013-C, 4 tests.
- `swift test --filter ExternalConnectorAvMatrixTests --no-parallel`: PASS
  after POST-DSA-013-C, 4 tests.
- `swift test --filter ExternalConnectorSession --no-parallel`: PASS after
  POST-DSA-013-C, 14 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after
  POST-DSA-013-C, 1 test.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox_apply: Operation not permitted`; rerun
  outside the sandbox passed after POST-DSA-013-C.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola external-connector-session-run --connector mvtp-ultragrid --role tx --peer 198.51.100.20 --output /private/tmp/open-lola2-ug-rawlink-reject.json --raw-link-interface en0`:
  failed fast as expected with `unknownArgument("--raw-link-interface")`.
- `wc -l Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionConfigurationParsing.swift Tests/OpenLolaCoreTests/ExternalConnectorSessionParsingTests.swift`:
  `ExternalConnectorSession.swift` is 642 lines,
  `ExternalConnectorSessionConfigurationParsing.swift` is 205 lines, and
  `ExternalConnectorSessionParsingTests.swift` is 104 lines.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa013c.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa013c.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`.
- `rg -n "PUBLIC_CURRENT_STATE_DOCS\|WINDOWS_CORPUS" scripts/verify_docs Tests docs`:
  returned no matches after POST-DSA-015-D, expected exit 1.
- `python3 -m scripts.verify_docs`: PASS after POST-DSA-015-D.
- `ruff check scripts/verify_docs`: PASS after POST-DSA-015-D.
- `MYPY_CACHE_DIR=/private/tmp/open-lola2-dsa015d-mypy-cache python -m mypy --strict scripts/verify_docs`:
  PASS after POST-DSA-015-D, no issues in 10 source files.
- `swift test --filter DocsVerifierPolicyTests --no-parallel`: PASS after
  POST-DSA-015-D, 4 tests.
- `python3 -c ... constants AST proof`: PASS after POST-DSA-015-D; reported
  `has_PUBLIC_CURRENT_STATE_DOCS False` and `has_WINDOWS_CORPUS False`.
- `wc -l scripts/verify_docs/constants.py scripts/verify_docs/markdown_checks.py`:
  `constants.py` is 436 lines and `markdown_checks.py` is 463 lines.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa015d.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa015d.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-current-refresh.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-current-refresh.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa006f.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa006f.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`.
- `rg -n "printValidatedJSONReport\|writeValidatedReport\|\\.validate\\(\\)\|prettyJSONString\|writeJSONData\|case let args" Sources/open-lola/Commands/MilestoneCommands.swift`:
  PASS after POST-DSA-006-F; remaining custom runtime paths are visible and
  behavior-specific.
- `nl -ba Sources/open-lola/Commands/MilestoneCommands.swift`: PASS after
  POST-DSA-006-F; rechecked line ranges for `latency-profile-synthetic-smoke`,
  `madi-tx-synthetic-smoke`, `native-app-shell-surface-probe`,
  `external-connector-synthetic-smoke`, and
  `external-connector-nmp-workflow-run`.
- `wc -l Sources/open-lola/Commands/Network/NetworkCommands.swift Sources/open-lola/Commands/MilestoneCommands.swift Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift`:
  `NetworkCommands.swift` is 441 lines, `MilestoneCommands.swift` is 556 lines,
  and `MilestoneValidationCommands.swift` is 320 lines after POST-DSA-006-F.
- `swift test --filter MachineReadableSurfaceContractTests --no-parallel`:
  first run failed before the helper fix because an app-only source change made
  the fixed `open-lola` binary look stale; rerun after POST-RFP-002-A passed
  with 7 tests, including the new app-only source freshness regression.
- `swift test --filter DirectPeerSessionOpusCLITests --no-parallel`: first run
  failed because the fixed-path CLI looked stale; rerun after POST-RFP-002-A
  passed with 6 tests.
- `swift test --filter DirectPeerSessionCLITests --no-parallel`: first run
  failed because the fixed-path CLI looked stale; rerun after POST-RFP-002-A
  passed with 5 tests.
- `swift test --filter DirectPeerAudioCompatibilityContractTests --no-parallel`:
  PASS after Direct P2P compatibility recheck, 5 tests.
- `swift test --filter DirectPeerRealtimeAudioGraphTests --no-parallel`: PASS
  after Direct P2P compatibility recheck, 10 tests.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox_apply: Operation not permitted`; rerun
  outside the sandbox passed.
- `git log --oneline --all -S audioCompression -- Sources Tests docs`: found
  recent checkpoint history, so legacy audio compression remains an active
  compatibility surface.
- `git log --oneline --all -S audioDeviceUID -- Sources Tests docs`: found
  recent checkpoint history, so legacy single-device UID compatibility remains
  an active compatibility surface.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  PASS outside the sandbox after POST-DSA-006-E.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola latency-profile-synthetic-smoke`:
  PASS after POST-DSA-006-E and still emitted JSON followed by
  `VERDICT: PARTIAL`.
- `swift test --filter CLICommandInventoryTests --no-parallel`: PASS after
  POST-DSA-006-E, 5 tests.
- `swift test --filter MachineReadableSurfaceContractTests --no-parallel`:
  PASS after POST-DSA-006-E, 7 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after
  POST-DSA-006-E, 1 test.
- `bash scripts/verify-docs.sh`: PASS after POST-DSA-006-E docs updates.
- `git diff --check`: PASS after POST-DSA-006-E.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa006e.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa006e.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`.
- `wc -l Sources/open-lola-app/AppShellRootView.swift Sources/open-lola-app/AppShellSectionViews.swift`:
  `AppShellRootView.swift` is 512 lines and
  `AppShellSectionViews.swift` is 689 lines after POST-DSA-009-D.
- `swift test --filter AppShell --no-parallel`: PASS after POST-DSA-009-D,
  90 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after removing
  the stale `AppShellRootView.swift` line-budget exception.
- `wc -l Sources/open-lola-app/AppSettings.swift Sources/open-lola-app/AppSettingsDraft.swift`:
  `AppSettings.swift` is 245 lines and `AppSettingsDraft.swift` is 587 lines
  after POST-DSA-009-C.
- `swift test --filter AppShellSettingsExecutionInputTests --no-parallel`:
  PASS after POST-DSA-009-C, 2 tests.
- `swift test --filter AppShell --no-parallel`: PASS after POST-DSA-009-C,
  90 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: initially failed
  after POST-DSA-009-C because the old `AppSettings.swift` exception was below
  the base line budget; after the stale exception was removed, the rerun passed
  with 1 test.
- `bash scripts/verify-docs.sh`: PASS after POST-DSA-009-C.
- `git diff --check`: PASS after POST-DSA-009-C.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa009c.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa009c.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola current-evidence-status-matrix`:
  PASS and emitted `VERDICT: PARTIAL`; the matrix still lists 11 open
  real-world tasks and one blocked release-field-closure lane.
- `wc -l Sources/open-lola-app/AppConsoleModels.swift Sources/open-lola-app/AppValidationConsoleModels.swift`:
  `AppConsoleModels.swift` is 582 lines and
  `AppValidationConsoleModels.swift` is 251 lines after POST-DSA-009-B.
- `swift test --filter AppShell --no-parallel`: PASS after POST-DSA-009-B,
  90 tests. The first run after moving the block failed because
  `appValidationReadiness` was still file-private; after making the shared
  helper module-internal, the rerun passed.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after removing
  the stale `AppConsoleModels.swift` line-budget exception.
- `rg -n -e "Implementation status" -e "Original planning baseline" docs/refactor-plan.md docs/remediation-status.md docs/remediation-ledger.md`:
  PASS after POST-RFP-PLAN-A; `docs/refactor-plan.md` now names the completed
  current implementation status separately from the original planning baseline.
- `rg -n "^## Current baseline$" docs/refactor-plan.md`: PASS/no matches as
  expected after POST-RFP-PLAN-A; the stale heading is gone from the plan.
- `rg -n -e "Recommended next audit targets" -e "LCA-001" -e "LCA-010" docs/logic-and-correctness-audit.md docs/remediation-ledger.md docs/remediation-status.md`:
  PASS after POST-LCA-SUMMARY-A; the logic audit summary now distinguishes
  original findings from completed remediation status and its next-target list
  no longer asks for the already-completed LCA implementation slices.
- `rg -n -e "unsupported JackTrip" -e "UltraGrid" -e "DSA-010" -e "Recommended Next Audit Targets" docs/deprecation-and-simplification-audit.md docs/remediation-ledger.md docs/remediation-status.md`:
  PASS after POST-DSA-010-D; the remaining deprecation-audit next target now
  names the app launch accessibility-window gate and oversized
  settings/console surfaces instead of an already-centralized unsupported-mode
  branch.
- `swift test --filter AppBundleScriptSourcePolicyTests --no-parallel`:
  PASS after POST-APP-VERIFY-B, 7 tests. The test now covers strict app launch
  verifier failures including the captured accessibility stderr header,
  missing accessibility-window diagnostic fields, and visible-window evidence
  printed before failure.
- `bash script/build_and_run.sh --verify` outside the sandbox after
  POST-APP-VERIFY-B: FAILED as expected for the current host gate. The verifier
  still emitted `accessibility label capture failed; required UI labels were
  not verified`, and now also printed `accessibility capture stderr:` followed
  by an `execution error: missing accessibility app window (process=OpenLoLa,
  displayedName=Open LoLa, bundleIdentifier=de.hfmt.open-lola.app,
  frontmost=false, accessibilityWindows=0) (-2700)`, then printed
  `visible window evidence captured before accessibility failure:` with the
  CoreGraphics window row for `owner=Open LoLa`.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox_apply: Operation not permitted`; rerun
  outside the sandbox passed.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola e2e-benchmark-synthetic-smoke`:
  PASS and emitted `VERDICT: PARTIAL`; all profile rows are synthetic with
  `physicalEvidence: false`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola hardware-validation-synthetic-smoke`:
  PASS and emitted `VERDICT: PARTIAL`; all hardware lanes are synthetic,
  `physicalEvidence: false`, and not measured.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola current-evidence-status-matrix`:
  PASS and emitted `VERDICT: PARTIAL`; the matrix still lists 11 open
  real-world tasks and one blocked release-field-closure lane.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-active-goal-refresh.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial` plus
  `VERDICT: PARTIAL`. The refreshed report records Core Audio inventory
  captured 2 devices, AVFoundation captured 2 video devices, 0 RME MADI
  candidates, 0 Blackmagic/ATEM candidates, 1 code-signing identity, and
  0 Developer ID Application identities.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-runtime-preflight-report /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-active-goal-refresh.json`:
  PASS and emitted `real-world-verdict: partial` plus `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-active-goal-refresh.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial`,
  `blockers: 21`, `next-actions: 21`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-active-goal-refresh.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 21`,
  `next-actions: 21`, and `VERDICT: PARTIAL`.
- `bash scripts/verify-docs.sh`: PASS after the active-goal refresh status
  update.
- `git diff --check`: PASS after the active-goal refresh status update.
- `find . -maxdepth 3 \( -name .DS_Store -o -name .ruff_cache -o -name .mypy_cache -o -name .pytest_cache -o -name __pycache__ -o -name '*.pyc' \) -print`:
  PASS, no matches.
- `bash scripts/verify-release-hygiene.sh`: PASS after POST-APP-VERIFY-A with
  `LIVE_RESIDUE_HYGIENE_VERDICT: PASS`.
- `bash scripts/verify-release-readiness.sh` outside the sandbox: FAILED after
  completing docs, shellcheck, ruff, Python tests, mypy, release hygiene,
  `swift build`, and the wrapper's `swift test --no-parallel` step. The
  failing step was the native app launch probe:
  `OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR=... ./script/build_and_run.sh --verify`,
  which emitted `accessibility label capture failed; required UI labels were not
  verified`.
- `bash script/build_and_run.sh --verify` outside the sandbox before
  POST-APP-VERIFY-A: FAILED with the same accessibility-label capture error.
  The launch evidence under
  `dist/app-launch-evidence` contained `process.pid`, `window-list.txt`,
  `screenshot.png`, and `os-log.txt`, but `accessibility-ui.txt` was empty and
  `accessibility-error.txt` reported `missing app window (-2700)`. CoreGraphics
  window evidence still saw an `Open LoLa` window, so the failure is specifically
  that System Events/AX did not expose a usable app window or required labels.
- Temporary host isolation probe: a minimal SwiftUI `WindowGroup` app created
  under `/private/tmp/open-lola-window-probe` built and launched, but System
  Events also reported `frontmost=false` and `0` windows for that process. The
  temporary probe was removed. This suggests the current host/windowing
  environment could not be trusted for the app accessibility-window gate at
  that point. POST-APP-VERIFY-F later superseded this host-gate state with a
  passing strict verifier run and non-empty accessibility/window evidence.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola open-source-release-readiness-run --output /private/tmp/open-lola-open-source-release-readiness-2026-05-21-continuation.json`:
  PASS and emitted `requirements: 9`, `blockers: 6`, and
  `VERDICT: PARTIAL`. The blockers are the expected release decision gates:
  final source license, documentation license, notices, fixture provenance,
  reviewer signoff, and public release approval.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-open-source-release-readiness-report /private/tmp/open-lola-open-source-release-readiness-2026-05-21-continuation.json`:
  PASS and emitted `VERDICT: PARTIAL`.
- `bash scripts/verify-release-hygiene.sh`: first failed because generated
  local artifacts `./.DS_Store`, `./.ruff_cache`, `./.mypy_cache`, and
  `./scripts/verify_docs/__pycache__` were present in the live checkout.
  Removed those generated artifacts and reran the command: PASS with
  `LIVE_RESIDUE_HYGIENE_VERDICT: PASS`.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox-exec: sandbox_apply: Operation not
  permitted`; rerun outside the sandbox passed.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola e2e-benchmark-synthetic-smoke`:
  PASS and emitted `VERDICT: PARTIAL`; all profile rows remain synthetic with
  `physicalEvidence: false`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola hardware-validation-synthetic-smoke`:
  PASS and emitted `VERDICT: PARTIAL`; all hardware lanes remain synthetic,
  `physicalEvidence: false`, and not measured.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola current-evidence-status-matrix`:
  PASS and emitted `VERDICT: PARTIAL`; the matrix still lists 11 open
  real-world tasks and one blocked release-field-closure lane.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-continuation-unsandboxed.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial` plus
  `VERDICT: PARTIAL`. The valid report records Core Audio inventory captured
  2 devices, AVFoundation captured 2 video devices with camera permission
  authorized, 0 RME MADI candidates, 0 Blackmagic/ATEM candidates,
  1 code-signing identity, and 0 Developer ID Application identities.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-runtime-preflight-report /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-continuation-unsandboxed.json`:
  PASS and emitted `real-world-verdict: partial` plus `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-continuation-unsandboxed.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial`,
  `blockers: 21`, `next-actions: 21`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-continuation-unsandboxed.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 21`,
  `next-actions: 21`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-continuation.json`:
  sandboxed run emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`, including Core Audio and camera
  permission blockers. This was not used as authoritative runtime evidence
  because the unsandboxed rerun captured Core Audio and AVFoundation correctly.

- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  outside the sandbox: PASS after POST-DSA-008-A, fresh executable confirmed.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa008a.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial`,
  `blockers: 21`, `next-actions: 21`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa008a.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 21`,
  `next-actions: 21`, and `VERDICT: PARTIAL`.
- `swift test --no-parallel`: PASS after POST-DSA-008-A with 864 tests in
  0 suites after 160.748 seconds. Swift Testing reported the existing 4 skipped
  LoLa UDP control retry/fallback tests.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox-exec: sandbox_apply: Operation not
  permitted`; rerun outside the sandbox passed.

- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  outside the sandbox: PASS after POST-DSA-013-B, fresh executable confirmed.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-post-dsa013b.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial` plus
  `VERDICT: PARTIAL`. The valid report records Core Audio inventory captured
  2 devices, AVFoundation captured 2 video devices with camera permission
  authorized, 0 RME MADI candidates, 0 Blackmagic/ATEM candidates,
  1 code-signing identity, and 0 Developer ID Application identities.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-runtime-preflight-report /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-post-dsa013b.json`:
  PASS and emitted `real-world-verdict: partial` plus `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa013b.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial`,
  `blockers: 21`, `next-actions: 21`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa013b.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 21`,
  `next-actions: 21`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-unsandboxed-refresh.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial` plus
  `VERDICT: PARTIAL`. The report captured Core Audio with 2 devices,
  AVFoundation with 2 video devices and camera permission authorized,
  0 RME MADI candidates, 0 Blackmagic/ATEM candidates, 1 code-signing identity,
  and 0 Developer ID Application identities.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-runtime-preflight-report /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-unsandboxed-refresh.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial` plus
  `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-unsandboxed-refresh.json`
  outside the sandbox: PASS on the authoritative final refresh and emitted
  `real-world-verdict: partial`, `blockers: 21`, `next-actions: 21`, and
  `VERDICT: PARTIAL`. The blocker list still includes invisible RME MADI
  hardware, missing physical receiver RME receive/mix evidence, invisible
  Blackmagic/ATEM/DeckLink/UltraStudio hardware, missing physical
  two-peer/direct-route run evidence, missing Developer ID Application signing
  identity, missing field/notarization/clean-Mac evidence, pending
  license/notice/fixture provenance decisions, missing reviewer signoff, and
  blocked public release approval.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-unsandboxed-refresh.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial`,
  `blockers: 21`, `next-actions: 21`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola open-source-release-readiness-run --output /private/tmp/open-lola-open-source-release-readiness-2026-05-21-after-notice-evidence-refresh.json`
  outside the sandbox: PASS and emitted `requirements: 9`, `blockers: 6`, and
  `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-open-source-release-readiness-report /private/tmp/open-lola-open-source-release-readiness-2026-05-21-after-notice-evidence-refresh.json`
  outside the sandbox: PASS and emitted `VERDICT: PARTIAL`.
- `swift test --no-parallel`: PASS after POST-DSA-013-B with 864 tests in
  0 suites. Swift Testing reported the existing 4 skipped LoLa UDP control
  retry/fallback tests.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola e2e-benchmark-synthetic-smoke`:
  PASS and emitted `VERDICT: PARTIAL`; all profile rows remain synthetic with
  `physicalEvidence: false`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola hardware-validation-synthetic-smoke`:
  PASS and emitted `VERDICT: PARTIAL`; all hardware lanes remain synthetic,
  `physicalEvidence: false`, and not measured.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola current-evidence-status-matrix`:
  PASS and emitted `VERDICT: PARTIAL`; the matrix still lists 11 open
  real-world tasks and one blocked release-field-closure lane.
- `docs/benchmark-e2e-av.md` current verification-state update: recorded the
  source-smoke commands and final-refresh blocker classes directly in the
  benchmark methodology while preserving `VERDICT: PARTIAL`.
- `bash scripts/verify-docs.sh`: PASS after the benchmark methodology and
  remediation-status updates.
- `git diff --check`: PASS after the benchmark methodology and
  remediation-status updates.

- `swift test --filter AppShell --no-parallel`: PASS after POST-DSA-009-A
  app console validation-readiness helper dedupe, 90 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after lowering
  the `AppConsoleModels.swift` line-budget exception to 831 lines, 1 test.
- `wc -l Sources/open-lola-app/AppConsoleModels.swift`: 831 lines.
- `bash scripts/verify-docs.sh`: PASS after the POST-DSA-009-A
  audit/index/ledger/status update.
- `git diff --check`: PASS after the POST-DSA-009-A documentation update.

- `swift test --filter AppShellWorkflowModePolicyTests --no-parallel`: PASS
  after POST-DSA-010-C settings visibility route-owner cleanup, 1 test.
- `swift test --filter AppShell --no-parallel`: PASS after POST-DSA-010-C,
  90 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after
  POST-DSA-010-C, 1 test.
- `wc -l Sources/OpenLolaCore/Platform/NativeAppShellSessionMode.swift`:
  360 lines.
- `bash scripts/verify-docs.sh`: PASS after the POST-DSA-010-C
  audit/ledger/status update.
- `git diff --check`: PASS after the POST-DSA-010-C documentation update.

- `rg -n "supervisorCommand\\(|validatorCommand\\(" Sources Tests`: after
  POST-DSA-008-A, only the still-used operator-surface
  `validatorCommand(executablePath:operatorSurface:)` helper and its tests
  remain; `supervisorCommand(executablePath:)` has no matches.
- `swift test --filter AppShell --no-parallel`: PASS after POST-DSA-008-A,
  90 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after lowering
  the `AppExecutionController.swift` line-budget exception to 1,038 lines,
  1 test.
- `wc -l Sources/open-lola-app/AppExecutionController.swift`: 1,038 lines.
- `bash scripts/verify-docs.sh`: PASS after the POST-DSA-008-A
  audit/index/ledger/status update, including the full Swift suite result.
- `git diff --check`: PASS after the POST-DSA-008-A documentation update.

- `swift test --filter AppShell --no-parallel`: PASS after POST-DSA-008-B,
  90 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after lowering
  the `AppExecutionController.swift` line-budget exception to 960 lines,
  1 test.
- `wc -l Sources/open-lola-app/AppExecutionController.swift Sources/open-lola-app/AppExecutionState.swift`:
  960 and 83 lines.
- `bash scripts/verify-docs.sh`: PASS after the POST-DSA-008-B
  audit/index/ledger/status update.
- `git diff --check`: PASS after the POST-DSA-008-B documentation update.

- `swift test --build-path /private/tmp/open-lola2-swiftpm-test-parser-scope --filter ExternalConnectorSessionParsingTests --no-parallel`:
  initial run after adding the regression failed with 3 expected issues because
  mismatched connector-specific flags were silently accepted. Rerun after the
  parser guard PASS, 3 tests.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-test-parser-scope --filter ExternalConnectorSession --no-parallel`:
  PASS, 13 tests.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-test-parser-scope --filter ExternalConnectorAvMatrixTests --no-parallel`:
  PASS, 4 tests.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-test-parser-scope --filter ExternalConnectorNmp --no-parallel`:
  PASS, 19 tests.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-test-parser-scope --filter CodeLineBudgetTests --no-parallel`:
  PASS, 1 test.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-test-parser-scope --filter CLICommandInventoryTests --no-parallel`:
  initial run failed because `/private/tmp/open-lola2-swiftpm-build/debug/open-lola`
  was stale; rerun after rebuilding PASS, 5 tests.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox-exec: sandbox_apply: Operation not
  permitted`; rerun outside the sandbox PASS.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-test-parser-scope --filter MachineReadableSurfaceContractTests --no-parallel`:
  PASS, 6 tests.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola external-connector-session-run --connector jacktrip --role tx --peer 203.0.113.10 --output /private/tmp/open-lola2-mismatched-connector.json --peer-audio-port 4464 --ultragrid-fec single-parity`:
  expected failure with exit 1 and `error: unknownArgument("--ultragrid-fec")`.
- `wc -l Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionConfigurationParsing.swift Tests/OpenLolaCoreTests/ExternalConnectorSessionParsingTests.swift`:
  199 and 80 lines.
- `bash scripts/verify-docs.sh`: PASS after the POST-DSA-013-B
  audit/ledger/status update.
- `git diff --check`: PASS after the POST-DSA-013-B documentation update.

- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  initial run after POST-DSA-006-D failed because `MadiTransmitSyntheticReport`
  did not satisfy the generic `ReportValidatingArtifact` helper constraint;
  after using the explicit validation-closure overload for that report, rerun
  outside the sandbox PASS.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-test-cli --filter CLICommandInventoryTests --no-parallel`:
  PASS, 5 tests.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-test-surface --filter MachineReadableSurfaceContractTests --no-parallel`:
  PASS, 6 tests.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-test-budget --filter CodeLineBudgetTests --no-parallel`:
  PASS, 1 test.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola latency-benchmark-synthetic-smoke`:
  PASS and emitted `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola video-capture-inventory`:
  PASS and emitted `VERDICT: PARTIAL`; this sandbox-visible run reported
  camera permission denied and no devices, so it is only a command-surface
  smoke, not current hardware evidence.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola native-app-shell-surface-probe`:
  PASS and emitted `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola release-hardening-synthetic-smoke`:
  PASS and emitted `VERDICT: PARTIAL`.
- `wc -l Sources/open-lola/Commands/MilestoneCommands.swift`: 556 lines.
- `bash scripts/verify-docs.sh`: PASS after the POST-DSA-006-D
  audit/index/ledger/status update.
- `git diff --check`: PASS after the POST-DSA-006-D documentation update.

- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox-exec: sandbox_apply: Operation not
  permitted`; rerun outside the sandbox PASS.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-unsandboxed.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial` plus
  `VERDICT: PARTIAL`. The valid report records Core Audio inventory captured
  2 devices, AVFoundation captured 2 video devices with camera permission
  authorized, 0 RME MADI candidates, 0 Blackmagic/ATEM candidates,
  1 code-signing identity, and 0 Developer ID Application identities.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-runtime-preflight-report /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-unsandboxed.json`:
  PASS and emitted `real-world-verdict: partial` plus `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-unsandboxed.json`
  outside the sandbox: PASS and emitted `real-world-verdict: partial`,
  `blockers: 21`, `next-actions: 21`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit-2026-05-21-unsandboxed.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 21`,
  `next-actions: 21`, and `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola e2e-benchmark-synthetic-smoke`:
  PASS and emitted `VERDICT: PARTIAL`; all profile rows remain synthetic with
  `physicalEvidence: false`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola hardware-validation-synthetic-smoke`:
  PASS and emitted `VERDICT: PARTIAL`; all hardware lanes remain synthetic and
  not measured.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-post-dsa010b.json`:
  sandboxed run PASS and emitted `real-world-verdict: partial` plus
  `VERDICT: PARTIAL`; superseded for current hardware evidence by the
  unsandboxed preflight above.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-post-dsa010b.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`,
  `next-actions: 26`, and `VERDICT: PARTIAL`; superseded for current blocker
  count by the unsandboxed completion audit above.

- `rg -n "func prepareExecution\|prepareExecutionForStart\|prepareExecution\\(" Sources/open-lola-app Tests/OpenLolaCoreTests/AppUnsupportedConnectorExecutionTests.swift`:
  confirmed only `AppExecutionController.prepareExecution(from:)` remains as
  the app execution-preparation owner; menu, transport, and banner call sites
  delegate to it.
- `swift test --filter AppUnsupportedConnectorExecutionTests --no-parallel`:
  PASS, 2 tests.
- `swift test --filter AppShell --no-parallel`: PASS, 90 tests. This command
  waited behind the focused unsupported-connector filter because SwiftPM
  serialized access to `.build`.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test after
  keeping `AppExecutionController.swift` at 1,046 lines and lowering the
  `AppShellRootView.swift` exception to 1,199 lines.
- `bash scripts/verify-docs.sh`: PASS after the POST-DSA-010-B documentation
  update.
- `git diff --check`: PASS after the POST-DSA-010-B documentation update.
- `swift build --product open-lola-app`: sandboxed run failed with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside the
  sandbox PASS.
- `wc -l Sources/open-lola-app/AppExecutionController.swift Sources/open-lola-app/AppExecutionPreparation.swift Sources/open-lola-app/OpenLolaApp.swift Sources/open-lola-app/AppTransportView.swift Sources/open-lola-app/AppShellRootView.swift Tests/OpenLolaCoreTests/AppUnsupportedConnectorExecutionTests.swift`:
  1,046, 15, 513, 398, 1,199, and 55 lines.

- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola e2e-benchmark-synthetic-smoke | tail -n 8`:
  PASS and emitted `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola hardware-validation-synthetic-smoke | tail -n 8`:
  PASS and emitted `VERDICT: PARTIAL`.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight-2026-05-21-continuation.json`:
  PASS and emitted `real-world-verdict: partial` plus `VERDICT: PARTIAL`.
  The report records 0 audio devices, 0 video devices, 0 RME MADI candidates,
  0 Blackmagic/ATEM candidates, and 0 Developer ID Application identities.
- `/private/tmp/open-lola2-swiftpm-build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit-2026-05-21-continuation.json`:
  PASS and emitted `real-world-verdict: partial`, `blockers: 26`, and
  `VERDICT: PARTIAL`.
- `bash scripts/verify-docs.sh`: PASS after the 2026-05-21 completion-audit
  status update.
- `git diff --check`: PASS after the 2026-05-21 completion-audit status
  update.

- `bash scripts/verify-docs.sh`: PASS after the DSA-011 retained-helper
  recheck documentation update.
- `git diff --check`: PASS after the DSA-011 retained-helper documentation
  update.

- `swift test --filter CLICommandInventoryTests --no-parallel`: initial run
  failed after POST-DSA-006-C source edits because the fixed-path
  `/private/tmp/open-lola2-swiftpm-build/debug/open-lola` executable was stale;
  rerun after rebuilding PASS, 5 tests.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox-exec: sandbox_apply: Operation not
  permitted`; rerun outside the sandbox PASS.
- `swift test --filter MachineReadableSurfaceContractTests --no-parallel`:
  PASS, 6 tests.
- `swift test --filter ExternalConnectorNmp --no-parallel`: PASS, 19 tests.
- `swift test --filter ReportSchemaInventoryTests --no-parallel`: PASS,
  6 tests.
- `swift test --filter ReportFixtureValidationContractTests --no-parallel`:
  PASS, 1 test.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test.
- `swift test --no-parallel`: PASS, 863 tests in 0 suites. Swift Testing
  reported the existing 4 skipped LoLa UDP control retry/fallback tests.
- `wc -l Sources/open-lola/Commands/MilestoneCommands.swift`: 586 lines.

- `swift test --filter CLICommandInventoryTests --no-parallel`: initial run
  failed after source edits because the fixed-path
  `/private/tmp/open-lola2-swiftpm-build/debug/open-lola` executable was stale;
  rerun after rebuilding PASS, 5 tests.
- `swift test --filter MachineReadableSurfaceContractTests --no-parallel`:
  initial run failed for the same stale fixed-path executable; rerun after
  rebuilding PASS, 6 tests.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  PASS outside the sandbox.
- `swift test --filter ReportSchemaInventoryTests --no-parallel`: PASS,
  6 tests.
- `swift test --filter ReportFixtureValidationContractTests --no-parallel`:
  PASS, 1 test.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test.
- `swift test --no-parallel`: PASS, 863 tests in 0 suites.
- `bash scripts/verify-docs.sh`: PASS after POST-DSA-006-B audit/index/status
  updates.
- `git diff --check`: PASS.
- `rg -n "switch arguments|args\[0\] ==|simpleMilestoneReportValidators|milestoneReportValidators|validate-current-evidence-status-matrix-report" Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift`:
  confirmed `MilestoneValidationCommands.swift` now exposes
  `milestoneReportValidators` and has no validation `switch arguments`,
  `args[0] ==`, or `simpleMilestoneReportValidators` remnants.
- `wc -l Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift`:
  320 lines.

- `swift test --filter KeyValueArgumentParserTests --no-parallel`: PASS,
  5 tests.
- `swift test --filter ExternalConnectorSessionParsingTests --no-parallel`:
  PASS, 2 tests.
- `swift test --filter ExternalConnectorSession --no-parallel`: PASS,
  12 tests.
- `swift test --filter ExternalConnectorAvMatrixTests --no-parallel`: PASS,
  4 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test.
- `swift test --filter ExternalConnectorNmp --no-parallel`: PASS, 19 tests.
- `swift test --filter UltraGridCompatibilityTests --no-parallel`: PASS,
  15 tests.
- `swift test --no-parallel`: initial post-change run failed after 863 tests
  were attempted because 20 fixed-path CLI tests rejected the stale
  `/private/tmp/open-lola2-swiftpm-build/debug/open-lola` executable as older
  than product sources.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox-exec: sandbox_apply: Operation not
  permitted`; rerun outside the sandbox PASS.
- `swift test --no-parallel`: PASS, 863 tests in 0 suites after the fixed-path
  CLI executable was rebuilt.
- `bash scripts/verify-docs.sh`: PASS after remediation status/ledger update.
- `git diff --check`: PASS.
- `wc -l Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionConfigurationParsing.swift Sources/OpenLolaCore/Connectors/Core/ExternalConnectorParsingDefaults.swift Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift Tests/OpenLolaCoreTests/ExternalConnectorSessionParsingTests.swift Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift Tests/OpenLolaCoreTests/KeyValueArgumentParserTests.swift`:
  `ExternalConnectorSession.swift` 642 lines,
  `ExternalConnectorSessionConfigurationParsing.swift` 145 lines,
  `ExternalConnectorParsingDefaults.swift` 503 lines,
  `KeyValueArgumentParser.swift` 223 lines,
  `ExternalConnectorSessionParsingTests.swift` 46 lines,
  `ExternalConnectorSessionTests.swift` 718 lines, and
  `KeyValueArgumentParserTests.swift` 123 lines.
- `rg --files Sources/OpenLolaCore/Connectors/NMP Tests/OpenLolaCoreTests docs scripts | rg "Nmp|NMP|nmp|source-contracts|CLICommandInventory|ReportSchemaInventory|NetworkRouteCommandMatrix"`:
  confirmed NMP source files, focused tests, and active source-contract docs are
  present.
- `rg -n "nmp|NMP|ExternalConnectorNmp|external-connector-nmp" Sources Tests docs/source-contracts.md docs/code-index.md docs/deprecation-and-simplification-audit.md docs/refactor-plan.md`:
  confirmed active NMP CLI runner, validator, schema inventory, source-contract,
  fixture, and test references.
- `git log --oneline -- Sources/OpenLolaCore/Connectors/NMP Tests/OpenLolaCoreTests/ExternalConnectorNmpPlanTests.swift Tests/OpenLolaCoreTests/ExternalConnectorNmpPreflightTests.swift Tests/OpenLolaCoreTests/ExternalConnectorNmpEndpointRunTests.swift Tests/OpenLolaCoreTests/ExternalConnectorNmpWorkflowTests.swift docs/source-contracts.md`:
  showed recent checkpoint commits touching the NMP surface.
- `swift test --filter ExternalConnectorNmp --no-parallel`: PASS, 19 tests.
- `swift test --filter ReportSchemaInventoryTests --no-parallel`: PASS,
  6 tests.
- `swift test --filter CLICommandInventoryTests --no-parallel`: PASS, 5 tests.
- `swift test --filter NetworkRouteCommandMatrixTests --no-parallel`: PASS,
  6 tests.
- `wc -l Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift Tests/OpenLolaCoreTests/UltraGridCompatibilityTests.swift Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift`:
  `AppShellBehaviorTests.swift` 694 lines, `AppShellSlice05Tests.swift` 713
  lines, `ReleaseArtifactHygieneContractTests.swift` 639 lines,
  `UltraGridCompatibilityTests.swift` 576 lines, and
  `DirectPeerSessionReport.swift` 892 lines.
- `wc -l Tests/OpenLolaCoreTests/*.swift`: inspected current Swift test-file
  line counts before refreshing `docs/code-index.md` hotspot ordering.
- `bash scripts/verify-docs.sh`: PASS after POST-DSA-012-K audit/index
  summary refresh.
- `git diff --check`: PASS.
- `rg -n "open_text|SOTA matrix missing Q" scripts/verify_docs/markdown_checks.py`:
  no matches, expected exit 1 after removing the duplicate folded-SOTA QID
  branch.
- `python3 -m scripts.verify_docs`: PASS after `check_sota_matrix` was updated
  to check `Q001` through `Q010` once against `docs/open-questions.md`.
- `swift test --filter DocsVerifierPolicyTests --no-parallel`: PASS,
  4 focused docs-verifier policy tests.
- `env RUFF_CACHE_DIR=/private/tmp/open-lola2-post-dsa015c-ruff-cache ruff check linux_connector scripts/verify_docs scripts/lib/*.py`:
  PASS.
- `env MYPY_CACHE_DIR=/private/tmp/open-lola2-post-dsa015c-mypy-cache python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`:
  PASS, no issues in 22 source files.
- `bash scripts/verify-docs.sh`: PASS after POST-DSA-015-C docs-verifier and
  remediation doc updates.
- `git diff --check`: PASS.
- `rg -n "SOTA_MATRIX" scripts/verify_docs Tests docs`: no matches, expected
  exit 1 after removing the duplicate SOTA/open-questions constant.
- `python3 -m scripts.verify_docs`: PASS after `check_sota_matrix` was updated
  to read `docs/open-questions.md` directly.
- `swift test --filter DocsVerifierPolicyTests --no-parallel`: PASS, focused
  docs-verifier policy tests.
- `env RUFF_CACHE_DIR=/private/tmp/open-lola2-post-dsa015b-ruff-cache ruff check linux_connector scripts/verify_docs scripts/lib/*.py`:
  PASS.
- `env MYPY_CACHE_DIR=/private/tmp/open-lola2-post-dsa015b-mypy-cache python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`:
  PASS, no issues in 22 source files.
- `swift test --filter UltraGridDockerPolicyTests --no-parallel`: PASS after
  moving duplicated Docker foreground cleanup into `scripts/lib/parity.sh` and
  adding fake-Docker UltraGrid client coverage.
- `swift test --filter VerificationToolingContractTests --no-parallel`: PASS;
  existing fake-Docker JackTrip client coverage still passes with the shared
  foreground cleanup helper.
- `shellcheck -x scripts/lib/parity.sh scripts/open-lola-ultragrid-docker-client.sh scripts/open-lola-jacktrip-docker-client.sh`:
  PASS.
- `swift test --filter VerificationToolingPairScriptTests --no-parallel`:
  PASS; fake Docker RX/TX and stress wrapper tests still pass after the parity
  helper change.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after the
  script/helper and test updates.
- `bash scripts/verify-docs.sh`: PASS after POST-DSA-016-A documentation
  updates.
- `git diff --check`: PASS.
- `swift test --filter AppShellOperationalCopyTests --no-parallel`: PASS after
  moving operational copy/accessibility/pasteboard assertions into a focused
  test file.
- `swift test --filter AppShellWorkflowModePolicyTests --no-parallel`: PASS
  after moving workflow-mode visibility assertions into a focused test file.
- `swift test --filter AppShellSlice05Tests --no-parallel`: PASS after the
  test split; remaining slice coverage passed with 22 tests.
- `swift test --filter AppShell --no-parallel`: PASS, 90 tests after the
  behavior-area split.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after removing
  the now-stale `AppShellSlice05Tests.swift` exception row.
- `wc -l Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift Tests/OpenLolaCoreTests/AppShellOperationalCopyTests.swift Tests/OpenLolaCoreTests/AppShellWorkflowModePolicyTests.swift`:
  `AppShellSlice05Tests.swift` 713 lines,
  `AppShellOperationalCopyTests.swift` 132 lines, and
  `AppShellWorkflowModePolicyTests.swift` 70 lines.
- `swift test --filter UltraGridReceiveAnalysisTests --no-parallel`: PASS after
  moving RTP quality and video reassembly failure assertions into a focused
  receive-analysis test file.
- `swift test --filter UltraGridCompatibilityTests --no-parallel`: PASS after
  the test split; remaining compatibility coverage passed with 15 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after removing
  the now-stale `UltraGridCompatibilityTests.swift` exception row.
- `wc -l Tests/OpenLolaCoreTests/UltraGridCompatibilityTests.swift Tests/OpenLolaCoreTests/UltraGridReceiveAnalysisTests.swift Tests/OpenLolaCoreTests/UltraGridCompatibilityTestSupport.swift`:
  `UltraGridCompatibilityTests.swift` 576 lines,
  `UltraGridReceiveAnalysisTests.swift` 139 lines, and
  `UltraGridCompatibilityTestSupport.swift` 24 lines.
- `swift test --filter UltraGridDockerPolicyTests --no-parallel`: PASS after
  moving UltraGrid Docker image-policy assertions into a focused test file.
- `swift test --filter ReleaseArtifactHygieneContractTests --no-parallel`: PASS
  after the test split.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS after removing
  the now-stale `ReleaseArtifactHygieneContractTests.swift` exception row.
- `wc -l Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift Tests/OpenLolaCoreTests/UltraGridDockerPolicyTests.swift`:
  `ReleaseArtifactHygieneContractTests.swift` 639 lines and
  `UltraGridDockerPolicyTests.swift` 142 lines.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-completion-audit-build`:
  sandboxed run failed with `sandbox_apply: Operation not permitted`; rerun
  outside the sandbox PASS.
- `/private/tmp/open-lola2-completion-audit-build/debug/open-lola e2e-benchmark-synthetic-smoke`:
  PASS and emitted `VERDICT: PARTIAL`; all profile rows remain synthetic with
  `physicalEvidence: false`.
- `/private/tmp/open-lola2-completion-audit-build/debug/open-lola hardware-validation-synthetic-smoke`:
  PASS and emitted `VERDICT: PARTIAL`; all hardware lanes remain synthetic and
  not measured.
- `/private/tmp/open-lola2-completion-audit-build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight-2026-05-20-continuation.json`:
  PASS and emitted `real-world-verdict: partial` plus `VERDICT: PARTIAL`.
  Current-host summary: 10/10 deliverables partial/blocked, 0 audio devices,
  0 RME MADI candidates, 0 video devices, 0 Blackmagic/ATEM candidates,
  1 code-signing identity, and 0 Developer ID Application identities.
- `/private/tmp/open-lola2-completion-audit-build/debug/open-lola validate-goal-runtime-preflight-report /private/tmp/open-lola-goal-runtime-preflight-2026-05-20-continuation.json`:
  PASS and emitted `real-world-verdict: partial` plus `VERDICT: PARTIAL`.
- `rg -n "PUBLIC_MILESTONE_" scripts Tests tests`: no matches, expected exit
  1 after the obsolete public milestone verifier constants were removed.
- `rg -n "public milestone section contract" scripts Tests tests`: no
  matches, expected exit 1 after the unreachable diagnostic was removed.
- `swift test --filter DocsVerifierPolicyTests --no-parallel`: PASS, focused
  docs-verifier policy tests.
- `bash scripts/verify-docs.sh`: PASS after POST-DSA-015-A docs-verifier and
  remediation doc updates.
- `env RUFF_CACHE_DIR=/private/tmp/open-lola2-post-dsa015-ruff-cache ruff check linux_connector scripts/verify_docs scripts/lib/*.py`:
  PASS.
- `env MYPY_CACHE_DIR=/private/tmp/open-lola2-post-dsa015-mypy-cache python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`:
  PASS, no issues in 22 source files.
- `git diff --check`: PASS.
- `swift test --filter AppShellUIPolicyTests --no-parallel`: PASS,
  10 tests.
- `swift test --filter AppShell --no-parallel`: PASS, 90 tests after moving
  sidebar session-indicator policy coverage into
  `Tests/OpenLolaCoreTests/AppShellUIPolicyTests.swift`.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test
  after removing the now-stale `AppShellBehaviorTests.swift` exception row.
- `wc -l Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift Tests/OpenLolaCoreTests/AppShellUIPolicyTests.swift`:
  `AppShellBehaviorTests.swift` 694 lines and
  `AppShellUIPolicyTests.swift` 217 lines.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test
  after lowering the `DirectPeerSessionReport.swift` exception to 892 lines.
- `wc -l Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift`:
  `DirectPeerSessionReport.swift` 892 lines.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test
  after lowering the `AppShellSlice05Tests.swift` exception to 903 lines.
- `wc -l Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`:
  `AppShellSlice05Tests.swift` 903 lines.
- `swift test --filter AppShellValidationEvidenceGraphTests --no-parallel`:
  PASS, 2 tests.
- `swift test --filter AppShell --no-parallel`: PASS, 90 tests after moving
  validation report graph assertions into
  `Tests/OpenLolaCoreTests/AppShellValidationEvidenceGraphTests.swift`.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test
  after lowering the `AppShellBehaviorTests.swift` exception to 721 lines.
- `wc -l Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift Tests/OpenLolaCoreTests/AppShellValidationEvidenceGraphTests.swift`:
  `AppShellBehaviorTests.swift` 721 lines and
  `AppShellValidationEvidenceGraphTests.swift` 419 lines.
- `swift test --filter AppShellRuntimeEvidenceTests --no-parallel`: PASS,
  5 tests.
- `swift test --filter AppShell --no-parallel`: PASS, 90 tests after moving
  runtime evidence/session-token assertions into
  `Tests/OpenLolaCoreTests/AppShellRuntimeEvidenceTests.swift`.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test
  after lowering the `AppShellBehaviorTests.swift` exception to 1,135 lines.
- `wc -l Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift Tests/OpenLolaCoreTests/AppShellRuntimeEvidenceTests.swift`:
  `AppShellBehaviorTests.swift` 1,135 lines and
  `AppShellRuntimeEvidenceTests.swift` 253 lines.
- `swift test --filter AppShellSettingsExecutionInputTests --no-parallel`:
  PASS, 2 tests.
- `swift test --filter AppShell --no-parallel`: PASS, 90 tests after moving
  settings draft persistence and executable-path resolver assertions into
  `Tests/OpenLolaCoreTests/AppShellSettingsExecutionInputTests.swift`.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test
  after lowering the `AppShellBehaviorTests.swift` exception to 1,383 lines.
- `wc -l Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift Tests/OpenLolaCoreTests/AppShellSettingsExecutionInputTests.swift`:
  `AppShellBehaviorTests.swift` 1,383 lines and
  `AppShellSettingsExecutionInputTests.swift` 87 lines.
- `swift test --filter AppShellExecutionControllerTests --no-parallel`: PASS,
  4 tests.
- `swift test --filter AppShell --no-parallel`: PASS, 90 tests after moving
  execution-controller lifecycle/log snapshot assertions into
  `Tests/OpenLolaCoreTests/AppShellExecutionControllerTests.swift`.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test
  after lowering the `AppShellBehaviorTests.swift` exception to 1,465 lines.
- `wc -l Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift Tests/OpenLolaCoreTests/AppShellExecutionControllerTests.swift Tests/OpenLolaCoreTests/AppShellTransportMenuPolicyTests.swift Tests/OpenLolaCoreTests/AppShellUIPolicyTests.swift Tests/OpenLolaCoreTests/AppShellTestSupport.swift Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift Tests/OpenLolaCoreTests/AppShellPacketMonitorTests.swift`:
  `AppShellBehaviorTests.swift` 1,465 lines,
  `AppShellExecutionControllerTests.swift` 114 lines,
  `AppShellTransportMenuPolicyTests.swift` 258 lines,
  `AppShellUIPolicyTests.swift` 190 lines,
  `AppShellTestSupport.swift` 355 lines,
  `AppShellSlice05Tests.swift` 903 lines, and
  `AppShellPacketMonitorTests.swift` 165 lines.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox_apply: Operation not permitted`; rerun
  outside the sandbox PASS.
- `swift test --filter CLICommandInventoryTests --no-parallel`: PASS,
  5 tests.
- `swift test --filter ReportSchemaInventoryTests --no-parallel`: PASS,
  6 tests.
- `swift test --filter MachineReadableSurfaceContractTests --no-parallel`:
  PASS, 6 tests.
- `swift test --filter NetworkRouteCommandMatrixTests --no-parallel`: first
  run failed because the route-matrix source scanner did not recognize
  table-backed network validators; rerun after updating the scanner PASS,
  6 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test.
- `swift test --filter ReportFixtureValidationContractTests --no-parallel`:
  PASS, 1 test.
- `swift test --no-parallel`: PASS, 859 tests; Swift Testing skipped four
  LoLa UDP fallback/retry tests.
- `bash scripts/verify-docs.sh`: PASS after POST-DSA-006-A remediation
  status updates.
- `git diff --check`: PASS.
- `.build/debug/open-lola e2e-benchmark-synthetic-smoke`: PASS and emitted
  `VERDICT: PARTIAL`; report rows are synthetic with `physicalEvidence: false`
  and TODO placeholders for M13 physical peer/hardware evidence.
- `.build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight-completion-audit.json`:
  PASS and emitted `real-world-verdict: partial` plus `VERDICT: PARTIAL`.
  Current-host summary: 10/10 deliverables partial/blocked, 0 audio devices,
  0 RME MADI candidates, 0 video devices, camera permission denied,
  0 Blackmagic/ATEM candidates, 1 code-signing identity, and 0 Developer ID
  Application identities.
- `.build/debug/open-lola validate-goal-runtime-preflight-report /private/tmp/open-lola-goal-runtime-preflight-completion-audit.json`:
  PASS and emitted `real-world-verdict: partial` plus `VERDICT: PARTIAL`.
- `.build/debug/open-lola hardware-validation-synthetic-smoke`: PASS and
  emitted `VERDICT: PARTIAL`; all hardware lanes are synthetic/not measured.
- `swift test --filter SourceNamingConventionTests --no-parallel`: PASS,
  1 test.
- `swift test --filter DirectPeerTwoPeerPrototypeReportTests --no-parallel`:
  PASS, 7 tests.
- `swift test --filter DirectPeerTwoPeerRunPlanTests --no-parallel`: PASS,
  7 tests.
- `swift test --filter ReportSchemaInventoryTests --no-parallel`: PASS,
  6 tests.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox_apply: Operation not permitted`; rerun
  outside the sandbox PASS.
- `swift test --filter CLICommandInventoryTests --no-parallel`: PASS,
  5 tests.
- `swift test --filter MachineReadableSurfaceContractTests --no-parallel`:
  PASS, 6 tests.
- `swift test --filter NetworkRouteCommandMatrixTests --no-parallel`: PASS,
  6 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test.
- `bash scripts/verify-docs.sh`: PASS after POST-DSA-005-A docs updates.
- `git diff --check`: PASS.
- `swift test --no-parallel`: PASS, 859 tests; Swift Testing skipped four
  LoLa UDP fallback/retry tests.
- `swift test --no-parallel`: PASS, 858 tests; Swift Testing skipped four LoLa
  UDP fallback/retry tests.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`:
  PASS, 114 passed and 2 skipped for unavailable loopback alias capability.
- `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`: PASS.
- `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`:
  PASS, no issues in 22 source files.
- `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh`:
  PASS.
- `swift run open-lola e2e-benchmark-synthetic-smoke`: sandboxed run failed
  with `sandbox_apply: Operation not permitted`; rerun outside the sandbox
  PASS and emitted `VERDICT: PARTIAL`.
- `.build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight-current.json`:
  PASS and emitted `VERDICT: PARTIAL`; current-host summary shows 10/10
  deliverables partial, 0 audio devices, 0 RME MADI candidates, 0 video
  devices, camera permission denied, 0 Blackmagic/ATEM candidates, and no
  Developer ID Application identity.
- `.build/debug/open-lola validate-goal-runtime-preflight-report /private/tmp/open-lola-goal-runtime-preflight-current.json`:
  PASS and emitted `VERDICT: PARTIAL`.
- `.build/debug/open-lola hardware-validation-synthetic-smoke`: PASS and
  emitted `VERDICT: PARTIAL`.
- `swift test --filter AppShell --no-parallel`: PASS, 90 tests after moving
  transport/menu policy tests to
  `Tests/OpenLolaCoreTests/AppShellTransportMenuPolicyTests.swift` and UI
  policy tests to `Tests/OpenLolaCoreTests/AppShellUIPolicyTests.swift`; shared
  app-shell builders now live in
  `Tests/OpenLolaCoreTests/AppShellTestSupport.swift`.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test after
  lowering the `AppShellBehaviorTests.swift` exception to 1,574 lines.
- `wc -l Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift Tests/OpenLolaCoreTests/AppShellTransportMenuPolicyTests.swift Tests/OpenLolaCoreTests/AppShellUIPolicyTests.swift Tests/OpenLolaCoreTests/AppShellTestSupport.swift Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift Tests/OpenLolaCoreTests/AppShellPacketMonitorTests.swift`:
  `AppShellBehaviorTests.swift` 1,574 lines,
  `AppShellTransportMenuPolicyTests.swift` 258 lines,
  `AppShellUIPolicyTests.swift` 190 lines,
  `AppShellTestSupport.swift` 355 lines,
  `AppShellSlice05Tests.swift` 903 lines,
  `AppShellPacketMonitorTests.swift` 165 lines.
- `bash scripts/verify-docs.sh`: PASS after post-plan audit-continuation
  status updates.
- `git diff --check`: PASS.
- `swift test --filter PeerSessionAVSupportTests --no-parallel`: PASS,
  12 tests.
- `swift test --no-parallel`: final post-remediation PASS, 858 tests; Swift
  Testing reported skipped LoLa UDP fallback/retry tests.
- `swift test --filter VendoredSourceBoundaryTests --no-parallel`: PASS,
  2 tests.
- `swift test --filter ReleaseArtifactHygieneContractTests --no-parallel`:
  PASS, 5 tests.
- `swift build --product open-lola`: sandboxed run failed with
  `sandbox_apply: Operation not permitted`; rerun outside the sandbox PASS.
- `bash scripts/export-release-candidate.sh /private/tmp/open-lola-vendor-boundary-check`:
  PASS with `RELEASE_HYGIENE_VERDICT: PASS` and
  `RELEASE_CANDIDATE_EXPORT_VERDICT: PASS`.
- `shellcheck -x scripts/verify-release-hygiene.sh scripts/export-release-candidate.sh`:
  PASS.
- `swift test --filter CodeLineBudgetTests --no-parallel`: first run failed
  after adding vendor-boundary proof to the already oversized release-hygiene
  test file; rerun after moving the proof into
  `VendoredSourceBoundaryTests.swift` PASS, 1 test.
- `bash scripts/verify-docs.sh`: PASS.
- `git diff --check`: PASS.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox_apply: Operation not permitted`; rerun
  outside the sandbox PASS.
- `swift test --filter CLICommandInventoryTests --no-parallel`: PASS, 4 tests.
- `swift test --filter ReportSchemaInventoryTests --no-parallel`: first run
  failed because `verify-direct-p2p-session-evidence-bundle` was classified as
  a report-schema validator; rerun after reclassifying it as `.probe` PASS,
  6 tests.
- `swift test --filter ReportFixtureValidationContractTests --no-parallel`:
  PASS, 1 test.
- `swift test --filter MachineReadableSurfaceContractTests --no-parallel`:
  PASS, 6 tests.
- `swift test --filter NetworkRouteCommandMatrixTests --no-parallel`: PASS,
  6 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test.
- `bash scripts/verify-docs.sh`: PASS after RFP-014 remediation status
  updates.
- `git diff --check`: PASS.
- `swift test --filter AppShellPacketMonitorTests --no-parallel`: PASS,
  3 tests.
- `swift test --filter AppShell --no-parallel`: PASS, 90 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test.
- `wc -l Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift Tests/OpenLolaCoreTests/AppShellPacketMonitorTests.swift`:
  `AppShellBehaviorTests.swift` 2352 lines, `AppShellSlice05Tests.swift`
  903 lines, `AppShellPacketMonitorTests.swift` 165 lines.
- `swift test --filter AppUnsupportedConnectorExecutionTests --no-parallel`:
  PASS, 2 tests.
- `swift test --filter NativeAppShell --no-parallel`: PASS, 16 tests.
- `swift test --filter AppShell --no-parallel`: PASS, 90 tests.
- `swift build --product open-lola-app`: sandboxed run failed with
  `sandbox_apply: Operation not permitted`; rerun outside the sandbox PASS.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test.
- `bash script/build_and_run.sh --verify`: sandboxed run failed with
  `sandbox_apply: Operation not permitted`; rerun outside the sandbox PASS and
  wrote ignored launch evidence under `dist/app-launch-evidence`.
- `swift test --filter DirectPeerAudioCompatibilityContractTests --no-parallel`:
  PASS, 5 tests.
- `swift test --filter DirectPeerRealtimeAudioGraphTests --no-parallel`: PASS,
  10 tests.
- `swift test --filter NativeAppShellOpusCommandTests --no-parallel`: PASS,
  2 tests.
- `swift test --filter DirectPeerTwoPeerRunPlanTests --no-parallel`: PASS,
  7 tests.
- `swift test --filter DirectPeerSessionOpusCLITests --no-parallel`: first run
  failed because the fixed-path `open-lola` executable was stale; rerun after
  rebuilding PASS, 6 tests.
- `swift test --filter DirectPeerSessionCLITests --no-parallel`: first run
  failed because the fixed-path `open-lola` executable was stale; rerun after
  rebuilding PASS, 5 tests.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox_apply: Operation not permitted`; rerun
  outside the sandbox PASS.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test.
- `swift test --filter ExternalConnectorSessionTests --no-parallel`: PASS,
  10 tests.
- `swift test --filter ExternalConnectorAvMatrixTests --no-parallel`: PASS,
  4 tests.
- `swift test --filter ExternalConnectorRuntimeEvidenceStateTests --no-parallel`:
  PASS, 3 tests.
- `swift test --filter UltraGridCompatibilityTests --no-parallel`: PASS,
  18 tests.
- `swift test --filter JackTripCompatibilityTests --no-parallel`: PASS,
  25 tests.
- `swift test --filter AppShellBehaviorTests --no-parallel`: PASS, 43 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test.
- `git diff --check`: PASS.
- `swift test --filter DirectPeerSessionAVQualityPolicyTests --no-parallel`:
  PASS, 2 tests.
- `swift test --filter DirectPeerSessionReportAVPassTests --no-parallel`:
  PASS, 11 tests.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox_apply: Operation not permitted`; rerun
  outside the sandbox PASS.
- `swift test --filter DirectPeerSessionCLITests --no-parallel`: PASS,
  4 tests.
- `swift test --filter DirectPeerSessionReport --no-parallel`: PASS,
  11 tests.
- `swift test --filter DirectPeerSession --no-parallel`: PASS, 32 tests.
- `git diff --check`: PASS.
- `bash scripts/verify-docs.sh`: PASS after RFP-009 remediation status
  updates.
- `bash scripts/verify-docs.sh`: PASS.
- `bash scripts/verify-release-hygiene.sh`: PASS with
  `LIVE_RESIDUE_HYGIENE_VERDICT: PASS`.
- `shellcheck -x scripts/verify-release-hygiene.sh scripts/export-release-candidate.sh`:
  PASS.
- `bash scripts/export-release-candidate.sh /private/tmp/open-lola-release-check`:
  PASS with `RELEASE_HYGIENE_VERDICT: PASS` and
  `RELEASE_CANDIDATE_EXPORT_VERDICT: PASS`.
- `swift test --filter ReleaseArtifactHygieneContractTests --no-parallel`: PASS,
  5 tests.
- `swift test --filter VerificationToolingContractTests --no-parallel`: PASS,
  5 tests.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox_apply: Operation not permitted`; rerun
  outside the sandbox PASS.
- `swift test --filter MachineReadableSurfaceContractTests --no-parallel`:
  PASS, 6 tests.
- `swift test --filter CLICommandInventoryTests --no-parallel`: PASS, 4 tests.
- `swift test --filter DirectPeerSessionCLITests --no-parallel`: PASS, 4 tests.
- `swift test --filter MadiFullDuplexSessionTests --no-parallel`: PASS,
  4 tests.
- `swift test --filter DirectPeerSessionOpusCLITests --no-parallel`: PASS,
  5 tests.
- `swift test --filter E2EBenchmarkReportTests --no-parallel`: PASS, 5 tests.
- `swift test --filter NetworkRouteCommandMatrixTests --no-parallel`: PASS,
  6 tests.
- `swift test --filter CodeLineBudgetTests --no-parallel`: PASS, 1 test.
- `swift test --no-parallel`: PASS, 835 tests; Swift Testing reported skipped
  LoLa UDP fallback/retry tests.
- `swift test --filter VerificationToolingPairScriptTests --no-parallel`: PASS,
  5 tests.
- `swift test --filter VerificationToolingContractTests --no-parallel`: PASS,
  5 tests.
- `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh`:
  PASS.
- `timeout 5 docker ps`: failed before Docker probe because `timeout` is not
  installed on this host.
- `/bin/bash -lc 'source scripts/lib/parity.sh; parity_require_docker_daemon "manual Docker parity preflight"'`:
  BLOCKED as expected on this host with exit 77 after Docker daemon did not
  respond within 5 seconds.
- `OPEN_LOLA_DOCKER_PREFLIGHT_TIMEOUT_SECONDS=1 bash scripts/compare-local-ultragrid-parity-docker.sh /private/tmp/open-lola-rfp004-ultragrid-preflight`:
  BLOCKED as expected with exit 77 and a clear Docker daemon prerequisite
  message.
- `swift test --filter DirectPeerSessionReportAVPassTests --no-parallel`:
  PASS, 5 tests.
- `swift test --filter DirectPeerSession --no-parallel`: first run failed
  because the fixed-path `open-lola` executable was stale after source edits;
  rerun after rebuilding PASS, 26 tests.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  PASS outside the sandbox.
- `bash scripts/verify-docs.sh`: PASS after DSCP PASS-contract doc update.
- `git diff --check`: PASS.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_codec.py linux_connector/tests/test_process_runtime.py`:
  PASS, 87 passed and 2 skipped.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`:
  PASS, 113 passed and 2 skipped.
- `RUFF_CACHE_DIR=/private/tmp/open-lola2-rfp008-ruff-cache ruff check linux_connector scripts/verify_docs scripts/lib/*.py`:
  PASS.
- `MYPY_CACHE_DIR=/private/tmp/open-lola2-rfp008-mypy-cache python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`:
  PASS, no issues in 22 source files.
- `git diff --check`: PASS.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_codec.py`:
  PASS, 43 tests.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`:
  PASS, 106 passed and 2 skipped.
- `RUFF_CACHE_DIR=/private/tmp/open-lola2-rfp007-ruff-cache ruff check linux_connector scripts/verify_docs scripts/lib/*.py`:
  PASS.
- `MYPY_CACHE_DIR=/private/tmp/open-lola2-rfp007-mypy-cache python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`:
  PASS, no issues in 22 source files.
- `git diff --check`: PASS.
- `swift test --filter directPeerSessionEvidenceBundle --no-parallel`: PASS,
  3 tests.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  sandboxed run failed with `sandbox_apply: Operation not permitted`; rerun
  outside the sandbox PASS.
- `swift test --filter DirectPeerSessionReportAVPassTests --no-parallel`:
  PASS, 9 tests.
- `swift test --filter GoalRuntimeEvidenceTemplateTests --no-parallel`: PASS,
  4 tests.
- `swift test --filter CLICommandInventoryTests --no-parallel`: PASS, 4 tests.
- `swift test --filter NetworkRouteCommandMatrixTests --no-parallel`: PASS,
  6 tests.
- `swift test --filter ReleaseArtifactHygieneContractTests --no-parallel`:
  PASS, 5 tests.
- `bash scripts/verify-docs.sh`: PASS after evidence-bundle verifier doc
  update.
- `git diff --check`: PASS.

## Uncertainty

- Full Swift suite passed after all source-completable slices, but runtime
  hardware, Docker daemon, signing, notarization, clean-Mac, and manual UI gates
  remain unverified. The native app launch accessibility gate is currently a
  known local failure on this host, not a pass: both OpenLoLa and a temporary
  minimal SwiftUI probe launched with menu bars but no System Events windows.
- Full Docker parity was not run because the new Docker daemon preflight
  classifies this host as blocked.
- `swift test --filter DirectPeerSessionReportTests --no-parallel` was not run
  because no such test file/filter exists; `DirectPeerSession` was used as the
  broader available filter.
- Vendor-boundary proof does not prove legal clearance for production
  distribution, upstream update policy, or runtime codec field readiness.

## Next slice

No next refactor-plan slice remains.
