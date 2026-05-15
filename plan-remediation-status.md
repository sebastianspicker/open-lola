# Open LoLa Remediation Status

Source plan: `plan.md`

Status snapshot: all plan slices have been processed from the 2026-05-14
`plan.md` authority. SLICE-02 remains blocked on local TSan launch policy, and
SLICE-09 is blocked on missing physical runtime hardware/routes/evidence.

## Overall State

Overall remediation state: `BLOCKED`

Reason: `SLICE-00`, `SLICE-01`, `SLICE-03`, `SLICE-04`, `SLICE-05`,
`SLICE-06`, `SLICE-07`, and `SLICE-08` are complete.
`SLICE-02` has source-level audio receive and adaptive RX buffering changes with
broad non-sanitized verification, but cannot be closed because the required TSan
lane cannot launch on this local platform. `SLICE-09` has source commands and
validators available, but cannot be closed because the required physical
two-Mac, RME/MADI, Blackmagic/ATEM, degraded-network, paired TX/RX, signing,
clean-Mac, and field evidence is absent on this host.

Current slice: none active.

Next recommended action: run the blocked evidence lanes on suitable hardware/CI:
`SLICE-02` TSan on a compatible host, and `SLICE-09` physical runtime harnesses
on real two-Mac/RME/video/signing/field infrastructure.

Highest remaining severity: `P1`

## Counts By Status

| Status | Count |
|---|---:|
| NOT_STARTED | 0 |
| IN_PROGRESS | 0 |
| BLOCKED | 2 |
| DEFERRED | 0 |
| IMPLEMENTED | 0 |
| VERIFIED | 0 |
| COMPLETE | 8 |

## Counts By Slice Severity

| Severity | Slice count |
|---|---:|
| P0 | 1 |
| P1 | 5 |
| P2 | 4 |
| P3 | 0 |
| P4 | 0 |

## Counts By Finding Severity

| Severity | Finding count covered by ledger |
|---|---:|
| P0 | 2 |
| P1 | 26 |
| P2 | 20 |
| P3 | 2 |
| P4 | 2 |

## Blocked Slices

| Slice ID | Blocker | Next action |
|---|---|---|
| `SLICE-02` | Required TSan lane cannot launch on this local Xcode/macOS install because `dyld` rejects `libclang_rt.tsan_osx_dynamic.dylib` with `Sanitizer load violates platform policy`. | Run TSan on a compatible host/CI runner or accept a documented platform waiver. |
| `SLICE-09` | Required physical runtime evidence is absent on this host: no visible Core Audio/RME inventory, no two-Mac direct route and impairment captures, no Blackmagic/ATEM video device evidence, no paired direct Mac/Windows LoLa TX/RX freshness artifacts, and no signing/notarization/clean-Mac/field evidence. | Run the listed runtime harness commands on suitable hardware/routes and attach validating reports. |

## Deferred Slices

None.

## Verification Baseline

Baseline state: `SLICE-00` complete on 2026-05-15.

Commands run and results:

- Baseline `bash scripts/verify-docs.sh` -> FAIL: `plan.md` was active but the
  docs verifier still required old `plan-findings-ledger.md` /
  `plan-status.md` names instead of the requested `plan-remediation-*`
  companions.
- Baseline `bash scripts/verify-release-hygiene.sh` -> FAIL: live checkout
  contained forbidden generated artifacts `./.DS_Store` and then
  `./docs/.DS_Store`.
- `bash scripts/verify-docs.sh` -> PASS after docs companion contract update.
- `bash scripts/verify-release-hygiene.sh` -> PASS after active-tree generated
  residue cleanup.
- Focused Swift filters for release artifact hygiene, goal completion audit,
  direct peer CLI/plans, verification tooling, UDP readiness source contract,
  and network diagnostics -> PASS.
- `ruff check linux_connector scripts/verify_docs scripts/lib/*.py` -> PASS.
- `python -m pytest -p no:cacheprovider linux_connector` -> PASS
  (`88 passed, 2 skipped`).
- `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`
  -> PASS.
- `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh`
  -> PASS.
- `swift build --build-path /private/tmp/open-lola2-swiftpm-build` -> PASS
  when run outside the command sandbox after SwiftPM sandbox setup failed
  inside it.
- `SLICE-03` start criteria checked: source findings `AUD-P1-VIDEO-001`,
  `AUD-P1-DEVICE-001`, `AUD-P1-DEVICE-002`, and the source-level video harness
  path re-read from `plan.md`; affected runtime path confirmed as AV video
  reassembly, AVFoundation startup/restore, live capture restore, and app
  receiver audio-meter callback hygiene.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter PeerSessionAVSupportVideoTests --no-parallel`
  -> PASS (`16` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter PeerSessionRunnerTests --no-parallel`
  -> PASS (`31` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter VideoCaptureReportTests --no-parallel`
  -> PASS (`33` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter RecordingSessionArtifactTests --no-parallel`
  -> PASS (`26` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter AppShellSourceContractTests --no-parallel`
  -> PASS (`5` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter AppShellBehaviorTests --no-parallel`
  -> PASS (`14` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter AppBundleScriptSourcePolicyTests --no-parallel`
  -> PASS (`2` tests).
- `OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR=/private/tmp/open-lola2-app-launch-slice03-final ./script/build_and_run.sh --verify`
  -> PASS; evidence includes `process.pid`, `manifest.txt`, `os-log.txt`,
  `window-list.txt`, `screenshot.png`, and the Accessibility fallback note.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --no-parallel`
  -> PASS (`1738` tests) after SLICE-03 changes.
- `bash scripts/verify-docs.sh` -> PASS.
- `bash scripts/verify-release-hygiene.sh` -> PASS.
- `swift build --build-path /private/tmp/open-lola2-swiftpm-build` -> PASS
  when run outside the command sandbox after SwiftPM sandbox setup failed
  inside it.
- `SLICE-02` start criteria checked: source findings `AUD-P1-AUDIO-001`
  through `AUD-P1-AUDIO-005`, `AUD-P1-BUFFER-001`, `AUD-P2-AUDIO-006`, and
  `TEST-CONCURRENCY-001` re-read from `plan.md`; affected runtime path
  confirmed as audio, RX, local RX, TX-adjacent realtime handoff, packet
  reassembly, RTP/AES67 validation, and playout/drop telemetry.
- `OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR=/private/tmp/open-lola-app-evidence ./script/build_and_run.sh --verify`
  -> PASS.
- `bash scripts/verify-release-readiness.sh` -> PASS. Final lines:
  `source-gate-verdict: pass`, `product-runtime-verdict: partial`,
  `VERDICT: PARTIAL`.
- `SLICE-01` start criteria checked: source findings `AUD-P1-NET-001` through
  `AUD-P1-NET-005` re-read from `plan.md`; affected runtime path confirmed as
  UDP/P2P control, RX, media transports, shutdown lifecycle, malformed media
  decode, and MTU-bound receive buffers.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CodeLineBudgetTests --no-parallel`
  -> PASS.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter PeerSessionRunnerLifecycleTests --no-parallel`
  -> PASS.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter PeerSession --no-parallel`
  -> PASS (`137` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --no-parallel`
  -> PASS (`1727` tests).
- `swift build --build-path /private/tmp/open-lola2-swiftpm-build` -> PASS
  when run outside the command sandbox after SwiftPM sandbox setup failed
  inside it.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter DirectPeerAudioPayloadRing --no-parallel`
  -> PASS (`8` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter DirectPeerRealtimeAudioGraph --no-parallel`
  -> PASS (`25` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter MadiReceiveTests --no-parallel`
  -> PASS (`19` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter RxBufferingTests --no-parallel`
  -> PASS (`22` tests; includes the adaptive realtime graph target-change test
  by name match).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter DirectPeerSessionReport --no-parallel`
  -> PASS (`15` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter PeerSessionAVSupportTests --no-parallel`
  -> PASS (`20` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter RealtimeAudioPacketHandoffTests --no-parallel`
  -> PASS (`22` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter AES67ST2110L24TransportTests --no-parallel`
  -> PASS (`7` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter SPSCAtomicRing --no-parallel`
  -> PASS (`3` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CodeLineBudgetTests --no-parallel`
  -> PASS.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter directPeerRawAudioSameDeadlineComparisonDocumentsFullMetadataBoundary --no-parallel`
  -> PASS after restoring the source-contract comment required by the test.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --no-parallel`
  -> PASS (`1732` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --no-parallel`
  -> PASS (`1734` tests) after adaptive RX buffering source changes.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --sanitize=thread --filter DirectPeerAudioPayloadRing --no-parallel`
  -> BLOCKED inside and outside the command sandbox: the test binary builds,
  but `dyld` refuses to load `libclang_rt.tsan_osx_dynamic.dylib` with
  `Sanitizer load violates platform policy`.
- `bash scripts/verify-docs.sh` -> PASS.
- `bash scripts/verify-release-hygiene.sh` -> PASS.
- `swift build --build-path /private/tmp/open-lola2-swiftpm-build` -> PASS
  when run outside the command sandbox after SwiftPM sandbox setup failed
  inside it.
- `SLICE-04` start criteria checked: findings `AUD-P1-UI-001`,
  `AUD-P1-UI-002`, `AUD-P1-UI-003`, `UI-SESSION-002`, `UI-STATE-001`,
  `LOGIC-STATE-001`, and `LOGIC-PLAN-001` re-read from `plan.md`; affected
  runtime path confirmed as app execution state, validation/report evidence,
  root/overview live-state derivation, command preview/copy handoff, app shell
  surface action contract, preview service live/idle status, and operator-plan
  error reporting.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter AppShellBehaviorTests --no-parallel`
  -> PASS (`19` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter NativeAppShellTests --no-parallel`
  -> PASS (`32` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-appshell-build --filter AppShell --no-parallel`
  -> PASS (`81` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-native-build --filter NativeAppShellWindowsLoLaTests --no-parallel`
  -> PASS (`4` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CodeLineBudgetTests --no-parallel`
  -> PASS after moving the new surface-action contract test out of
  `NativeAppShellTests.swift`.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-surface-action-build --filter NativeAppShellSurfaceActionTests --no-parallel`
  -> PASS (`1` test).
- `OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR=/private/tmp/open-lola2-app-launch-slice04 ./script/build_and_run.sh --verify`
  -> PASS; evidence written under `/private/tmp/open-lola2-app-launch-slice04`.
- `bash scripts/verify-docs.sh` -> PASS.
- `bash scripts/verify-release-hygiene.sh` -> PASS.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --no-parallel`
  -> initially FAIL only on `CodeLineBudgetTests`
  (`Tests/OpenLolaCoreTests/NativeAppShellTests.swift` at `736/715` lines),
  then PASS (`1744` tests) after the test-file split.
- `swift build --build-path /private/tmp/open-lola2-swiftpm-build` -> PASS
  when run outside the command sandbox after SwiftPM sandbox setup failed
  inside it.
- Generated-residue scan found only `./.build/arm64-apple-macosx/.DS_Store`,
  which remains outside the release candidate boundary and is ignored by release
  hygiene.
- `SLICE-05` start criteria checked: findings `UI-NAV-001`, `UI-SESSION-001`,
  `UI-STREAM-001`, `UI-SETTINGS-001`, `UI-DIAG-001`, `UI-PACKET-001`,
  `UI-VIS-001`, `UI-A11Y-001`, and `TEST-UI-001` re-read from `plan.md`;
  affected runtime path confirmed as UI validation/report handoff, menu/action
  dispatch, settings state, diagnostics, packet monitor, accessibility, and app
  launch probe behavior.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter AppShellSlice05Tests --no-parallel`
  -> PASS (`6` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter AppShell --no-parallel`
  -> PASS (`87` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter NativeAppShellTests --no-parallel`
  -> PASS (`31` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CodeLineBudgetTests --no-parallel`
  -> PASS.
- `OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR=/private/tmp/open-lola-ui ./script/build_and_run.sh --verify`
  -> PASS; evidence includes `process.pid`, `manifest.txt`, `os-log.txt`,
  `window-list.txt`, `screenshot.png`, and the Accessibility fallback note.
- `shellcheck -x script/build_and_run.sh` -> PASS.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter AppBundleScriptSourcePolicyTests --no-parallel`
  -> PASS (`2` tests).
- `bash scripts/verify-docs.sh` -> PASS.
- `bash scripts/verify-release-hygiene.sh` -> PASS.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --no-parallel`
  -> PASS (`1750` tests).
- `swift build --build-path /private/tmp/open-lola2-swiftpm-build` -> PASS
  when run outside the command sandbox after SwiftPM sandbox setup failed
  inside it.
- `bash scripts/verify-release-readiness.sh` -> PASS for source gate and native
  app launch probe. Final lines: `source-gate-verdict: pass`,
  `product-runtime-verdict: partial`, `VERDICT: PARTIAL`.
- `SLICE-06` start criteria checked: findings `AUD-P1-DEPRECATED-001`,
  `AUD-P2-COMPAT-001`, and `AUD-P2-STALE-001` re-read from `plan.md`; affected
  source/report path confirmed as CLI command inventory, fixture smoke matrix,
  report schema inventory, direct P2P AV CLI compatibility parsing/help, LoLa
  launch-plan references, and external connector report references.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CLICommandInventoryTests --no-parallel`
  -> PASS (`10` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter ReportSchemaInventoryTests --no-parallel`
  -> PASS (`15` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter FixtureSmokeMatrixTests --no-parallel`
  -> PASS (`6` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter DirectPeerSessionOpusCLITests --no-parallel`
  -> PASS (`5` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter LoLaParityDeferredFeaturesTests --no-parallel`
  -> PASS (`9` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter ExternalConnectorLoLaCompatibilityTests --no-parallel`
  -> PASS (`14` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter ExternalConnectorReportTests --no-parallel`
  -> PASS (`8` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CodeLineBudgetTests --no-parallel`
  -> PASS.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --no-parallel`
  -> PASS (`1752` tests).
- `bash scripts/verify-docs.sh` -> PASS.
- `bash scripts/verify-release-hygiene.sh` -> PASS.
- `swift build --build-path /private/tmp/open-lola2-swiftpm-build` -> PASS
  when run outside the command sandbox after SwiftPM sandbox setup failed
  inside it.
- `bash scripts/verify-release-readiness.sh` -> PASS for source gate and native
  app launch probe. Final lines: `source-gate-verdict: pass`,
  `product-runtime-verdict: partial`, `VERDICT: PARTIAL`.
- `SLICE-07` start criteria checked: findings `AUD-P2-DUP-001`,
  `AUD-P2-DOCS-001`, `AUD-P2-TESTS-001`, and `TEST-QUALITY-001` re-read from
  `plan.md`; affected policy/test path confirmed as release hygiene policy,
  docs verifier archive topology/inventory, release artifact contract tests, and
  source-string-heavy parser coverage.
- `bash scripts/verify-docs.sh` -> PASS.
- `bash scripts/verify-release-hygiene.sh` -> PASS.
- `shellcheck -x scripts/verify-docs.sh scripts/verify-release-hygiene.sh script/build_and_run.sh`
  -> PASS.
- `ruff check --no-cache scripts/verify_docs scripts/lib/*.py` -> PASS.
- `python3 -m mypy --strict scripts/verify_docs scripts/lib/*.py` -> PASS.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter ReleaseArtifactHygieneContractTests --no-parallel`
  -> PASS (`12` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter DocsVerifierPolicyTests --no-parallel`
  -> PASS (`2` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter AudioLoopbackRunTests --no-parallel`
  -> PASS (`27` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CodeLineBudgetTests --no-parallel`
  -> PASS.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter NativeAppShellTests --no-parallel`
  -> PASS (`31` tests).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter AppShell --no-parallel`
  -> PASS (`87` tests).
- `OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR=/private/tmp/open-lola-ui ./script/build_and_run.sh --verify`
  -> PASS; evidence written under `/private/tmp/open-lola-ui`.
- `bash scripts/verify-release-readiness.sh` -> PASS for source gate, full Swift
  suite, CLI probes, and native app launch probe. Final lines:
  `source-gate-verdict: pass`, `product-runtime-verdict: partial`,
  `VERDICT: PARTIAL`.
- `SLICE-08` start criteria checked: findings `AUD-P2-STRUCT-001` and
  `AUD-P2-SLOP-001` re-read from `plan.md`; affected path confirmed as
  line-budget test policy, source inventory caps, archive provenance, docs
  verifier policy, and release/docs inventory. No runtime path is changed.
- `find archive -maxdepth 1 -type f -name '* copy.md' -print` -> PASS with no
  output after moving former copy files into
  `archive/2026-05-15-ambiguous-plan-copy-files/`.
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CodeLineBudgetTests --no-parallel`
  -> PASS (`1` test).
- `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter DocsVerifierPolicyTests --no-parallel`
  -> PASS (`3` tests).
- `bash scripts/verify-docs.sh` -> PASS.
- `ruff check --no-cache scripts/verify_docs scripts/lib/*.py` -> PASS.
- `MYPY_CACHE_DIR=/private/tmp/open-lola2-mypy-cache python3 -m mypy --strict scripts/verify_docs scripts/lib/*.py`
  -> PASS.
- `bash scripts/verify-release-hygiene.sh` -> PASS.
- `bash scripts/verify-release-readiness.sh` -> PASS for source gate, full Swift
  suite, CLI probes, and native app launch probe. Final lines:
  `source-gate-verdict: pass`, `product-runtime-verdict: partial`,
  `VERDICT: PARTIAL`.
- `SLICE-09` start criteria checked: findings `HARNESS-NET-001`,
  `HARNESS-AUDIO-001`, `HARNESS-VIDEO-001`, and `HARNESS-TXRX-001` re-read
  from `plan.md`; affected path confirmed as physical UDP/P2P degraded-network
  evidence, physical audio loopback/RME evidence, physical video
  capture/transport evidence, and paired TX/RX report freshness.
- `.build/debug/open-lola --help` -> PASS; required runtime commands and
  validators are present, including `audio-loopback-run`, `video-capture-run`,
  `direct-p2p-session-run`, `e2e-benchmark-run`, and corresponding validators.
- `.build/debug/open-lola current-evidence-status-matrix-run --output /private/tmp/open-lola2-current-evidence-status-matrix.json`
  -> `VERDICT: PARTIAL`; validator -> `VERDICT: PARTIAL`.
- `.build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola2-goal-runtime-preflight.json`
  -> `VERDICT: PARTIAL`; validator -> `VERDICT: PARTIAL`.
- `.build/debug/open-lola goal-runtime-evidence-template-run --output /private/tmp/open-lola2-goal-runtime-evidence-template.json`
  -> `VERDICT: PARTIAL`; validator -> `VERDICT: PARTIAL`.
- `.build/debug/open-lola device-inventory` -> BLOCKED: `error: noDevices`.
- `.build/debug/open-lola video-capture-inventory` -> `VERDICT: PARTIAL`; no
  devices returned and `permissionStatus` is `denied`.
- Product/runtime readiness remains intentionally `PARTIAL`.
- Hardware, two-Mac P2P, RME/MADI, Blackmagic/ATEM, WAN, signing,
  notarization, clean-Mac, and reviewer evidence remain absent.

## Remaining Uncertainty

- The ledger normalizes Section 11's eight suggested implementation slices into
  ten slices to cover every canonical finding ID from Section 4.
- `SLICE-09` depends on physical hardware/routes for final evidence, but it is
  not marked blocked because `plan.md` treats the evidence as absent rather than
  declaring remediation impossible.
- `SLICE-00` is source-gate complete. It does not provide physical product
  runtime evidence; that remains owned by later runtime/harness slices.
- `SLICE-01` is source-level complete. No two-Mac physical runtime claim is
  made for this slice.
- `SLICE-02` source-level audio receive remediation is implemented but blocked
  from closure until required TSan evidence can run on a compatible platform or
  is explicitly waived.
- `SLICE-03` is source-level complete. The native app launch probe now records
  visible-window and screenshot evidence even when macOS Accessibility does not
  expose SwiftUI window labels; physical video closure remains part of
  `SLICE-09`.
- `SLICE-04` is source-level complete. UI validation/live state is now gated on
  current runtime evidence, shell command handoff is escaped for POSIX shells,
  preview services reset idle/live status truthfully, and operator-plan failures
  surface exact errors. Physical runtime evidence remains part of later
  runtime/hardware slices, not `SLICE-04` closure.
- `SLICE-05` is source-level complete. Accessibility label capture was not
  available on this host, so menu-action label assertions were not executed by
  the launch probe. Focused behavior/policy tests passed, and the launch probe
  captured visible-window and screenshot evidence. Physical runtime evidence
  remains part of later runtime/hardware slices, not `SLICE-05` closure.
- `SLICE-06` is source-level complete. Legacy `--audio-compression` remains
  accepted as a hidden migration/parser compatibility path, but is no longer
  shown in direct P2P help. The deprecated LoLa parity smoke alias remains only
  as a deprecated source compatibility symbol; active CLI, inventory, fixture
  smoke, schema, and tests use non-deprecated validation/fixture paths.
- `SLICE-07` is source-level complete. Policy duplication was reduced by moving
  release-boundary and archive-topology data into small canonical manifests, and
  the docs archive inventory is derived from `archive/README.md`. The native
  launch probe now verifies required menu/action labels when Accessibility
  capture is available. Product/runtime remains `PARTIAL` pending physical,
  signing, clean-Mac, and field evidence.
- `SLICE-08` is policy/archive complete. Existing oversized source/test files
  remain intentionally unsplit in this slice, but each now has a capped exception
  row and future growth or new files over the 500-line default fail the line
  budget gate. Former ambiguous top-level archive copy files are preserved under
  a dated archive folder and future top-level `* copy.md` archive files fail the
  docs verifier.
- `SLICE-09` is externally blocked, not source-complete. The command/report
  surface exists, but the slice requires current physical evidence from real
  hardware/routes. Local probes show absent audio devices and partial/no video
  device evidence, and the runtime preflight reports keep real-world verdicts at
  `PARTIAL`.
- `AUD-P1-BUFFER-001` is source-level remediated: adaptive RX now changes
  runtime targets outside audio callbacks for DirectPeer realtime graph and
  MADI receive, and AV runtime metrics can carry the RX buffer target-change
  snapshot. Physical impairment evidence remains part of later runtime/hardware
  slices, not `SLICE-02` closure.
- A `.DS_Store` remains under `.build/`, which is ignored by the release hygiene
  policy and not part of the release candidate boundary.
