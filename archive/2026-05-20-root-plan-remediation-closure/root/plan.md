# Open LoLa Authoritative Audit And Remediation Plan

Date: 2026-05-20
Status: PARTIAL authoritative audit and remediation plan
Scope rule: audit-only. This plan update changes only `plan.md`; it does not change production code, tests, scripts, generated files, fixtures, or docs outside this file.
Authority rule: Sections 1-14 are the current remediation control surface. The raw audit passes retained after section 14 are evidence appendices and should be used for line-level detail.
Verification rule: Every recommendation in the control surface must be implemented only with the verification path named in its finding row, remediation phase, or implementation slice. If a raw appendix recommendation is promoted into implementation work, first add or confirm its verification path in sections 6-12.

Coverage warning: this is not a completed whole-repository audit. Every file under `Sources/` is accounted for in the retained source inventory, but most are only partially inspected by metadata/content scan. Tests, scripts, docs, Linux connector files, fixtures, private evidence, and generated/archive material are not fully inventoried in this plan. Do not write "complete" for the audit until those gaps are closed.

## 1. Executive Summary

Overall codebase health: Open LoLa is source-rich and verification-oriented, but the active runtime product verdict remains `PARTIAL`. The strongest current risk is not absence of code; it is evidence trust. Several paths can report PASS, Live, Ready, Started, or useful media from partial, stale, synthetic, string-level, or structurally valid evidence that does not prove live audio/video/network data flow. Runtime-critical areas also still need boundedness and timing harnesses before cleanup or release-readiness claims can be trusted.

Highest-risk areas:
- App validation and UI runtime state: stale sidecar/report evidence, invalid report graphs, Live/Start states not consistently tied to active runtime proof.
- Direct P2P lifecycle and media reports: accepted session config, nil shutdown/error control messages, report PASS gates, and artifact/provenance validation.
- Real-time audio and UDP media paths: callback/timing evidence, RX buffer counters, packet loss/reorder/duplicate handling, and TX/RX loop fairness.
- Video capture and receive: unmeasured audio-impact defaults, capture memory growth, deferred-frame accounting, and missing device-loopback proof.
- Verification infrastructure: stale CLI binary tests, script all-green stubs without failure-path checks, missing hardware/degraded-network harnesses, and underrepresented false-pass fixtures.

Most urgent fixes:
1. Fix app false-success validation first: `LTV-FS-02`, then `LTV-FS-01`, with focused app/controller tests.
2. Fix stale executable verification: `LTV-TEST-05`, so machine-readable CLI tests cannot pass against an old binary.
3. Add artifact/provenance validation for Direct P2P PASS: `LTV-FS-03`, `LTV-FS-04`, `RT-06`, `HRA-P2P-08`.
4. Add PASS blockers for nonzero runtime degradation counters: `RT-05`, `HRA-AUDIO-04`, `HRA-P2P-08`, `HRA-VIDEO-01`.
5. Add lifecycle and boundedness tests before touching runtime loops: `RT-01` through `RT-04`, `HRA-P2P-01` through `HRA-P2P-06`.

What not to touch yet:
- Do not refactor real-time audio, UDP/P2P, TX/RX, video capture, or app runtime-state code for cleanup until the relevant P1 harnesses exist.
- Do not prune Opus/JPEG XS vendored/reference files without codec build proof, release export/hygiene, and legal/provenance review.
- Do not remove deprecated compatibility branches such as `audioCompression` or `audioDeviceUID` until active-use inventory and migration tests prove they are stale.
- Do not introduce new architecture or abstractions for parser/validator cleanup; use existing helpers only when multiple real call sites need them and focused tests protect behavior.

## 2. Audit Coverage

Coverage status: incomplete by design. This plan is authoritative for findings already evidenced, not a claim of full audit coverage.

Required coverage fields:
- Total files inspected or accounted: 1188 files under `Sources/` are accounted for in the retained source inventory; selected tests, scripts, docs, and runtime files were inspected during targeted passes. The exact whole-repository inspected-file total is not proven because non-`Sources/` files were not exhaustively inventoried.
- Fully inspected files: 17 UI/app-facing files were fully inspected for the UI audit scope only.
- Partially inspected files: 1188 `Sources/` inventory entries plus selected tests, scripts, docs, and runtime files.
- Uninspected files: non-`Sources/` repository files not explicitly listed, private evidence, most archive material, many tests/scripts/docs/fixtures, and generated outputs outside the retained source inventory.
- Reason for incomplete coverage: the stop rule prioritized a consolidated `plan.md`, source inventory, and high-risk runtime evidence; no live hardware/device/network run or exhaustive non-source inventory was performed.

| Coverage bucket | Count / status | Evidence and caveat |
| --- | --- | --- |
| Source files accounted under `Sources/` | 1188 | Retained inventory section lists every file under `Sources/`: 376 first-party/non-vendored files, 714 vendored Opus files, 98 JPEG XS reference files. Most entries are partial metadata/content inspection, not full semantic audit. |
| Fully inspected files | 17 UI/app-facing files for the UI pass | Fully inspected for that pass: `OpenLolaApp.swift`, `AppShellRootView.swift`, `AppConsoleChromeView.swift`, `AppTransportView.swift`, `AppLocalOperatorSurfaceView.swift`, `AppShellSettingsView.swift`, `AppShellSettingsTabs.swift`, `AppSettings.swift`, `AppPreviewReceiverView.swift`, `AppPacketMonitorView.swift`, `AppConsoleModels.swift`, `AppLatencyHeroView.swift`, `AppRuntimeEvidenceScope.swift`, `AppDesignSystem.swift`, `AppShellSupportViews.swift`, `NativeAppShellExecution.swift`, `NativeAppShellSurfaceContract.swift`. "Fully inspected" means for the UI audit scope, not a formal proof of all defects. |
| Partially inspected files | 1188 source inventory entries plus selected tests, scripts, docs, and runtime files | Runtime, logic, cleanup, UI, and verification passes read relevant files directly. Most source files, tests, scripts, and docs were not fully semantically audited. |
| Uninspected files | Non-`Sources/` repository files not explicitly listed; private evidence; most archive material; many tests/scripts/docs/fixtures | Reason: stop rules prioritized `plan.md` audit output and high-risk runtime paths. No live hardware/device/network run was performed. |
| Generated/vendor/reference material | Accounted where under `Sources/`, not semantically audited | Opus and JPEG XS trees require build/provenance/legal review before pruning or deep audit conclusions. |

Reason for incomplete coverage:
- The repository is broad, and prior passes were intentionally scoped: source inventory, runtime risk, cleanup, UI, and verification quality.
- Hardware/device behavior cannot be proven from source inspection.
- The dirty worktree already has deleted `plan-remediation-ledger.md` and `plan-remediation-status.md`; docs verification is expected to fail until that external state is resolved, and this task allows only `plan.md` edits.

Self-check result:
- All `Sources/` files are accounted for in the retained inventory.
- Not all repository files are accounted for.
- All enumerated findings from prior passes are preserved below and indexed here.
- No P0 finding is currently confirmed.

Next continuation prompt if full coverage is required:

```text
Continue the Open LoLa audit-only process. Focus on non-Sources coverage: Tests, scripts, script, linux_connector, docs, fixtures, CI workflows, release/export helpers, archive/private boundaries, and generated artifacts. Update only ./plan.md. Every file outside Sources must be listed as fully inspected, partially inspected, or not inspected with reason. Do not change code.
```

## 3. Runtime Architecture Summary

Audio path:
- Core Audio and realtime graph code feed capture/playout through `DirectPeerRealtimeAudioGraph*`, `RealtimeAudio*` buffers/rings, packet handoff, MADI/audio-loopback helpers, and report validators.
- High-risk boundaries are IOProc callback work, host-time conversion, RX buffer counters, lock-free versus lock-backed handoff, callback timing, and hardware loopback evidence.

UDP/P2P path:
- Session setup uses control messages, `PeerSessionRunner`, Direct P2P session/run-plan reports, UDP media transports, socket runners, NAT/route helpers, and report validators.
- High-risk boundaries are sessionAccept validation, nil/wrong-session shutdown/error messages, packet ordering/loss/jitter counters, artifact/provenance validation, and report PASS thresholds.

Video path:
- Capture and transport use `VideoCapture*`, AVFoundation collector paths, video transport/reassembly/rendering, Direct AV video loops, and video report validators.
- High-risk boundaries are capture memory retention, raw/default audio-impact evidence, frame reassembly/deferred frame accounting, device permissions, capture hardware proof, and audio-impact while video is active.

Control path:
- Control messages flow through `SessionControlMessage`, Direct P2P control sockets/services, peer session state machines, connector control paths, and app commands.
- High-risk boundaries are unsupported control messages treated as drops, pre-session shutdown/error handling, LoLa retry responder health, and UI/menu action parity.

TX path:
- TX drains captured audio/video payloads into UDP/media transports through Direct AV audio/video loops and codec/packetization paths.
- High-risk boundaries are unbounded per-iteration TX drain, heap/copy work in media loops, malformed packet send handling, and backpressure/drop metrics.

RX path:
- RX reads UDP/media datagrams, decodes payloads, reassembles raw audio/video, queues audio for playout, and records metrics.
- High-risk boundaries are duplicate-fragment floods, mixed payload types, missing internal routers treated as recoverable network errors, loss/reorder/duplicate counters, and malformed datagram accounting.

Local RX path:
- Localhost/direct local run paths and preview paths produce partial/source evidence unless paired with collected peer reports, receive proofs, or local preview state.
- High-risk boundaries are local preview state versus network RX state, local-only evidence being promoted to PASS, and selected stream controls not affecting actual preview routing.

UI-to-runtime path:
- SwiftUI app surfaces use stored defaults, app settings, app execution controller, runtime evidence loaders, session-state derivation, menu actions, transport policies, and report summaries.
- High-risk boundaries are stale report sidecars, invalid report graph loading, Start/Stop menu parity, Live/Ready wording, placeholder reports, and settings fields not mapped to runtime contracts.

## 4. Findings Index

| ID | Severity | Category | Subsystem | File | Short title | Confidence |
| --- | --- | --- | --- | --- | --- | --- |
| RT-01 | P1 | Buffering | RX | `DirectPeerSessionAVAudioLoops.swift` | Duplicate fragment flood can bypass pending-deadline cap | high |
| RT-02 | P1 | State machine | UDP/P2P | `PeerSessionRunner.swift` | Initiator accepts mutated session config | high |
| RT-03 | P1 | Lifecycle | UDP/P2P | `PeerSessionRunner.swift`; `SessionControlMessage.swift` | Nil-session shutdown can abort before accepted session | medium-high |
| RT-04 | P1 | Scheduling | TX/RX | `DirectPeerSessionAVAudioLoops.swift` | Audio TX loop has no per-iteration budget | medium-high |
| RT-05 | P1 | False success | Audio | `RealtimeAudioPacketHandoff.swift`; `RealtimeAudioEngineReportValidation.swift` | PASS validation misses RX buffer loss/reorder counters | high |
| RT-06 | P1 | False success | UDP/P2P | `DirectPeerSessionReport.swift`; `DirectPeerSessionAVSocketRunner.swift` | Direct P2P PASS validation misses drop/loss/underrun counters | high |
| RT-07 | P1 | Placeholder evidence | Video | `VideoCaptureRunner.swift`; `VideoCaptureReport.swift` | Default audio-impact metrics can support PASS without provenance | medium-high |
| RT-08 | P1 | Error handling | Control | `LoLaControlExchangeRuntime.swift` | Retry responder reports started while errors are swallowed | medium |
| RT-09 | P2 | Timing gap | Audio | `DirectPeerRealtimeAudioGraph*.swift` | CoreAudio callback workload lacks timing evidence | medium |
| RT-10 | P2 | Cleanup | Audio | `DirectPeerRealtimeAudioGraph.swift` | Cleanup clears retry-relevant handles after failure | medium |
| LC-01 | P1 | False success | Control/Connectors | `ExternalConnectorSession.swift` | Outer PASS misses runtime/nested evidence failures | high |
| LC-02 | P1 | Placeholder evidence | Tests/Reports | `E2EBenchmarkRunner.swift`; `E2EBenchmarkReportValidation.swift` | Measured E2E PASS can use placeholder metrics | high |
| LC-03 | P1 | False success | Tests/Release | `OpenSourceReleaseReadiness.swift` | Release PASS can omit requirement kinds | high |
| LC-04 | P1 | False success | Control/Connectors | `ExternalConnectorReport.swift`; connector validators | Connector PASS ignores rejected media count | high |
| LC-05 | P1 | Error classification | Video | `UltraGridCompatibilityRunner.swift` | UltraGrid reassembly failure remains non-fail | medium |
| SLOP-01 | P2 | SLOP | Structure | `MeasurementReport.swift` | Generic MeasurementReport stale compatibility candidate | medium |
| SLOP-02 | P2 | DEDUP | Structure | report validation files | Duplicated counter/percentile validation drifts | high |
| SLOP-03 | P2 | DEDUP | Structure | UltraGrid scripts | Native/Docker parity helpers duplicate evidence logic | high |
| SLOP-04 | P2 | SLOP | Structure | `Package.swift`; release scripts | Raw checkout carries release-excluded vendor noise | high |
| COMPAT-01 | P3 | Deprecated docs | Deprecated code | release docs/verifier constants | Stale docs/compliance pointers | high |
| UI-01 | P1 | UI state | UI | `AppSessionStateBanner.swift` | Live label can mean completed validated evidence | high |
| UI-02 | P1 | UI settings | UI | `AppShellSettingsTabs.swift`; `AppSettings.swift` | SSH mode exposed without required fallback fields | high |
| UI-03 | P1 | UI validation | UI | `AppConsoleModels.swift`; `AppExecutionController.swift` | Can I Run can say Ready while validation is disabled | high |
| UI-04 | P2 | UI state | UI | `AppTransportView.swift`; `AppConsoleChromeView.swift` | Armed can show while setup is incomplete | high |
| UI-05 | P2 | UI copy | UI | `AppConsoleModels.swift`; `AppPacketMonitorView.swift` | Packet Monitor unavailable label conflicts with reachable empty state | medium-high |
| TEST-01 | P2 | Test gap | Tests | report schema tests | False-pass registry misses pass-capable validators | high |
| TEST-02 | P2 | Verification wording | Tests | `verify-release-readiness.sh`; `docs/testing.md` | Source-gate pass wording can hide skipped manual gates | medium |
| TEST-03 | P2 | Missing stress tests | Tests | runtime tests | Stress/timing coverage missing for boundedness findings | medium |
| STRUCT-01 | P2 | Structure | Structure | validators/reports | Public validation policy drift | high |
| HRA-AUDIO-01 | P1 | Timing | Audio | `DirectPeerRealtimeAudioGraphCallbacks.swift` | Host-time overflow silently drops callback work | high |
| HRA-AUDIO-02 | P2 | Timing gap | Audio | realtime graph/ring files | Callback bounded workload needs timing proof | medium |
| HRA-AUDIO-03 | P2 | Cleanup | Audio | `DirectPeerRealtimeAudioGraph.swift` | Cleanup clears state after failed stop/destroy/restore | high |
| HRA-AUDIO-04 | P1 | False success | Audio | `RealtimeAudioEngineReportValidation.swift`; `RealtimeAudioPacketHandoff.swift` | PASS ignores RX buffer loss/duplicate/reorder/underrun counters | high |
| HRA-AUDIO-05 | P2 | Concurrency | Audio | `RealtimeAudioPacketHandoff.swift` | Lock-backed runtime wrapper could block callback path | medium |
| HRA-P2P-01 | P1 | State machine | UDP/P2P | `PeerSessionRunner.swift`; `DirectPeerSessionAVSocketRunner.swift` | sessionAccept transition validates too late/outside base runner | high |
| HRA-P2P-02 | P1 | Lifecycle | UDP/P2P | `PeerSessionRunner.swift`; `SessionControlMessage.swift` | Pre-session nil shutdown can close transports | high |
| HRA-P2P-03 | P1 | Lifecycle | UDP/P2P | `PeerSessionRunner.swift`; `SessionControlMessage.swift` | Pre-session nil/wrong error can fail handshake | high |
| HRA-P2P-04 | P1 | Buffering | RX | `DirectPeerSessionAVAudioLoops.swift` | Per-deadline packet array can grow on duplicate flood | high |
| HRA-P2P-05 | P1 | Scheduling | TX | `DirectPeerSessionAVAudioLoops.swift` | TX drain can monopolize AV loop and allocate per packet | high |
| HRA-P2P-06 | P1 | Error handling | RX | `DirectPeerSessionAVAudioLoops.swift`; `PeerSessionRunnerMediaIO.swift` | Missing router/stream treated as recoverable packet drop | high |
| HRA-P2P-07 | P2 | Diagnostics | RX | audio/video RX loops | Payload-type mismatch silently continues | high |
| HRA-P2P-08 | P1 | False success | UDP/P2P | Direct P2P session report/runtime files | Useful media/PASS ignores serious runtime counters | high |
| HRA-P2P-09 | P2 | Diagnostics | Control | `DirectPeerSessionAVControlService.swift` | Unsupported control messages lose detail | medium |
| HRA-VIDEO-01 | P1 | Placeholder evidence | Video | `VideoCaptureRunner.swift`; `VideoCaptureReport.swift` | Video PASS can use unmeasured audio-impact defaults | high |
| HRA-VIDEO-02 | P2 | Cleanup/accounting | Video | Direct AV video loop files | Shutdown omits final deferred frame accounting | high |
| HRA-VIDEO-03 | P1 | Memory bound | Video | `VideoCaptureAVFoundation.swift` | Video capture timestamps can grow without bound | high |
| HRA-ERR-01 | P2 | Error handling | Control/Tests | `DirectPeerSessionAVMetricsService.swift`; `DirectPeerSessionReport.swift` | Metrics socket failures remain nonnegative counters | high |
| HRA-UI-01 | P1 | UI state | UI | `AppTransportView.swift`; `AppExecutionController.swift` | Start is allowed for unknown validation state | high |
| SQA-DEDUP-01 | P2 | DEDUP | Deduplication | parser/config files | CLI key-value parsing duplicated | high |
| SQA-DEDUP-02 | P2 | DEDUP | Deduplication | parser helpers | Typed argument helpers duplicated | high |
| SQA-DEDUP-03 | P2 | DEDUP | Deduplication | validation helpers | Report validation primitive wrappers duplicated | high |
| SQA-STRUCT-01 | P2 | STRUCTURE | Structure/UI | `AppExecutionController.swift` | UI execution controller mixes too many responsibilities | high |
| SQA-STRUCT-02 | P2 | STRUCTURE | Structure/UI | `AppConsoleModels.swift` | Console models mix navigation, status, diagnostics, validation | high |
| SQA-STRUCT-03 | P2 | STRUCTURE | Structure/UDP/P2P | `DirectP2PTwoPeerLocalRunCommandSupport.swift` | P2P command support mixes process, SSH, proof, parser logic | high |
| SQA-STRUCT-04 | P2 | STRUCTURE | Structure | `NetworkCommands.swift` | Network command router is monolithic | high |
| SQA-DEAD-01 | P2 | DEAD_CODE | Dead code | `Sources/opus-1.5.2` | Opus non-target files may be dead/release noise | high |
| SQA-DEAD-02 | P2 | DEAD_CODE | Dead code | `Sources/xs_ref_sw_ed2` | JPEG XS programs/extras may be dead/release noise | high |
| SQA-SLOP-01 | P3 | SLOP | Dead code | `.DS_Store` under `Sources/` | Ignored generated source-tree clutter | high |
| SQA-DEPRECATED-01 | P2 | DEPRECATED | Deprecated code | audio transport compatibility files | `audioCompression` compatibility path needs sunset proof | high |
| SQA-DEPRECATED-02 | P3 | DEPRECATED | Deprecated code | audio graph config/docs/tests | `audioDeviceUID` compatibility path needs migration proof | high |
| SQA-OVER-01 | P2 | OVERENGINEERING | Structure/UI | app placeholder report files | Native app placeholder report blurs loading/evidence state | high |
| SQA-STRUCT-05 | P3 | STRUCTURE | Structure | direct-p2p prototype docs/router | Prototype naming is misleading for active contract | high |
| UIA-MENU-01 | P2 | UI menu | UI | settings/menu files | Advertised validation shortcut is not wired | high |
| UIA-MENU-02 | P1 | UI menu | UI | `OpenLolaApp.swift`; transport files | Menu Start uses weaker gating than transport Start | high |
| UIA-NAV-01 | P2 | UI nav | UI | `AppShellRootView.swift`; state banner | Validation/completed evidence can auto-navigate to Session | high |
| UIA-SESSION-01 | P1 | UI state | UI | `AppTransportView.swift`; controller | Start appears available before validation passes | high |
| UIA-CONTROL-01 | P2 | UI control | UI | `AppLocalOperatorSurfaceView.swift` | Intent controls look actionful but only mutate metadata | high |
| UIA-ACCESS-01 | P2 | UI accessibility | UI | stop/menu files | Stop confirmation inconsistent across active entrypoints | high |
| UIA-STREAM-01 | P2 | UI state | Local RX | `AppPreviewReceiverView.swift` | Preview health depends on status-string parsing | high |
| UIA-STREAM-02 | P2 | UI state | Local RX | `AppPreviewReceiverView.swift` | Local preview can be active while meters say no audio session | medium |
| UIA-DIAG-01 | P2 | UI diagnostics | UI | diagnostics/report files | Diagnostics can label source/placeholder facts as Ready | high |
| UIA-SETTINGS-01 | P1 | UI settings | UI | settings/execution files | SSH settings cannot satisfy runtime validation contract | high |
| UIA-SETTINGS-02 | P2 | UI settings | Local RX | preview/settings files | Selected stream setting is editable but not wired to preview routing | high |
| UIA-VIS-01 | P3 | UI visual | UI | chrome/support views | Status badges may clip long text | medium |
| UIA-VIS-02 | P3 | UI visual | UI | `AppLatencyHeroView.swift` | Latency hero may overflow narrow layout | low |
| UIA-STATE-01 | P1 | UI state | UI | session/banner/footer files | Completed or validated run can display Live | high |
| UIA-PLACEHOLDER-01 | P2 | UI placeholder | UI | app/diagnostics files | First-launch placeholder can look like report facts | high |
| LTV-FS-01 | P1 | False success | UI/Tests | app controller/evidence scope | Fresh sidecar token can still rely on stale report content | high |
| LTV-FS-02 | P1 | False success | UI/Tests | `AppLatencyHeroMetrics.swift`; app tests | App accepts invalid direct-peer PASS report graph | high |
| LTV-FS-03 | P1 | False success | UDP/P2P | Direct P2P local run report/tests | Two-peer PASS validates path strings, not artifacts | high |
| LTV-FS-04 | P1 | False success | UDP/P2P | Direct P2P session report/tests | Loopback-derived session can be mutated into physical PASS | high |
| LTV-FS-05 | P1 | False success | UDP/P2P | UDP route run/report files | Route PASS metadata not proven against actual socket topology | medium |
| LTV-FS-06 | P2 | False success | Tests/Release | release readiness files | Source-level release PASS is text-marker based | medium |
| LTV-TEST-01 | P2 | Test quality | Tests/UI | app shell tests | Tests codify questionable active-state policies | high |
| LTV-TEST-02 | P2 | Test gap | Tests/UI | controller tests | Validation failure with PASS-shaped report is not covered | medium |
| LTV-TEST-03 | P2 | Test gap | Tests | verification tooling tests | Release-readiness script test only proves all-green stub path | high |
| LTV-TEST-04 | P2 | Test harness | Tests | shell helper tests | Shell helpers can hang on large output or stuck children | medium |
| LTV-TEST-05 | P1 | Test false success | Tests | machine-readable CLI tests | CLI tests can use stale binary | high |
| LTV-TEST-06 | P2 | Test gap | Tests/UDP/P2P | Direct P2P PASS tests | PASS policy lacks loss, jitter, recovery edge tests | medium |
| LTV-TEST-07 | P2 | Test inventory | Tests | fixture inventory/tests | Connector false-pass fixtures underrepresented centrally | medium |
| LTV-TEST-08 | P2 | Test gap | Tests/UI | settings/runtime tests | Settings-to-runtime SSH fallback bridge untested | high |
| LTV-HARNESS-01 | P2 | Harness gap | Tests/UDP/P2P | testing docs/scripts/CI | Degraded-network/reference-peer gates are not default proof | high |
| LTV-HARNESS-02 | P1 | Harness gap | Audio/Video | testing docs/audio/video tests | Audio/video hardware loopback gates missing from standard proof | high |

## 5. P0 Findings

No P0 finding is confirmed in the current evidence. This is not proof that no P0 exists; it reflects partial audit coverage and no live hardware/runtime run.

## 6. P1 Findings

P1 issues are the primary remediation queue. Each item has a verification path; do not mark fixed without the named focused tests and any broader gate required by touched files.

| ID | Short title | Primary remediation | Verification path |
| --- | --- | --- | --- |
| RT-01 / HRA-P2P-04 | Duplicate fragment flood can grow RX storage | Bound per-deadline fragments and count duplicates before append | Duplicate-fragment flood unit/harness; `swift test --filter DirectPeerSession` focused tests |
| RT-02 / HRA-P2P-01 | Mutated sessionAccept can enter configured state | Validate accepted config against proposal before state transition | P2P control-state tests for mismatched endpoints/streams |
| RT-03 / HRA-P2P-02 | Nil shutdown can abort setup | Require bound session ID for remote shutdown after proposal | Idle/handshake/configured shutdown tests |
| RT-04 / HRA-P2P-05 | Audio TX loop lacks budget | Add per-iteration TX budget and backlog metric | AV loop fairness harness with TX backlog and RX/control service assertions |
| RT-05 / HRA-AUDIO-04 | Realtime audio PASS misses RX buffer counters | Make nonzero loss/reorder/duplicate/underrun counters PASS blockers or explicit degradation | RealtimeAudioEngine PASS validator fixtures with each counter nonzero |
| RT-06 / HRA-P2P-08 | Direct P2P PASS misses degradation counters | Define PASS thresholds for all drop/loss/underrun/corrupt/metrics counters | DirectPeerSessionReport PASS false-pass fixture matrix |
| RT-07 / HRA-VIDEO-01 | Video audio-impact defaults can support PASS | Require measured audio-impact provenance for PASS | VideoCaptureReport PASS test without provenance must fail |
| RT-08 | LoLa retry responder swallows background failures | Expose health/error counters and fail/degrade on repeated transport errors | Injectable transport failure test for retry responder |
| LC-01 | External connector outer PASS misses nested failures | Require no runtime error, runtimeErrorFree true, and nested evidence consistency | ExternalConnectorSession PASS-with-runtime-error/missing-media tests |
| LC-02 | E2E measured PASS can use placeholders | Require explicit recovery/network/impairment artifacts for measured PASS | E2E runner and validator tests for zero-impairment placeholder PASS |
| LC-03 | Release readiness PASS can omit requirements | Validate requirement-kind set against all required kinds | OpenSourceReleaseReadiness missing-kind PASS test |
| LC-04 | Connector PASS ignores rejected media | Block PASS when sink rejected media is nonzero | JackTrip/UltraGrid PASS tests with `rejectedMediaCount = 1` |
| LC-05 | UltraGrid reassembly failure stays non-fail | Define and enforce FAIL/PARTIAL policy for video reassembly failure | UltraGrid RX test for incomplete frame verdict |
| UI-01 / UIA-STATE-01 | Completed evidence can display Live | Split active live stream from validated completed evidence | AppSessionState/banner/footer tests and screenshots |
| UI-02 / UIA-SETTINGS-01 | SSH mode exposed without required fields | Hide SSH mode or add explicit fallback/reason UI and persistence | Settings save plus supervisor argument generation test |
| UI-03 | Can I Run says Ready while validation disabled | Include validation readiness in preflight model | Missing/stale report preflight tests |
| HRA-AUDIO-01 | Host-time overflow silently returns success | Add callback-safe overflow counter and PASS blocker | Host-time overflow callback/report validation test |
| HRA-P2P-03 | Nil/wrong pre-session error can fail handshake | Require peer/session correlation for fatal errors | Control-message tests across idle/handshake/configured/running states |
| HRA-P2P-06 | Internal missing router/stream treated as packet drop | Separate malformed datagrams from internal state errors | RX test forcing missing audio router/stream |
| HRA-VIDEO-03 | Video capture timestamps can grow unbounded | Bound samples or use streaming metrics; cap duration/frame-rate | Long-duration capture collector memory/snapshot test |
| HRA-UI-01 / UIA-SESSION-01 | Start allowed before validation passes | Require current passed validation or explicit unsafe override | AppTransportStartPolicy/Menu parity tests |
| UIA-MENU-02 | Menu Start weaker than transport Start | Reuse transport start policy for menu availability | Menu-action tests for configured/unvalidated/failed/running states |
| LTV-FS-01 | Fresh sidecar can rely on stale report | Bind report content identity/time/session to validation, not only sidecar | Fake-process stale-report harness |
| LTV-FS-02 | App accepts invalid direct-peer PASS graph | Validate supervisor and child reports before app evidence is complete | AppShellBehavior invalid supervisor/child PASS tests |
| LTV-FS-03 | Two-peer PASS validates strings, not artifacts | Add artifact-aware validator or separate artifact proof command | Bogus path/invalid artifact tests |
| LTV-FS-04 | Loopback-derived report can become physical PASS | Tie physical PASS evidence to non-loopback endpoints and real artifacts | Loopback-as-physical false-pass test |
| LTV-FS-05 | UDP PASS metadata not tied to socket topology | Compare bind/peer socket truth to route metadata before PASS | UDP route-run integration test with loopback/direct-link mismatch |
| LTV-TEST-05 | CLI tests can use stale binary | Build or inject current binary path before machine-readable tests | Isolated `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build` plus focused tests |
| LTV-HARNESS-02 | Hardware loopback gates missing | Add machine-readable audio/video loopback harnesses | RME/MADI/Core Audio loopback and AVFoundation/Blackmagic loopback commands |

## 7. P2 Findings

| ID | Short title | Remediation class | Verification path |
| --- | --- | --- | --- |
| RT-09 / HRA-AUDIO-02 | Callback workload lacks timing proof | Add instrumentation/harness before optimizing | Callback timing benchmark across channel/frame configs |
| RT-10 / HRA-AUDIO-03 | Cleanup clears state after failure | Preserve retry/diagnostic state or make cleanup terminal | Core Audio cleanup failure injection tests |
| SLOP-01 | Generic MeasurementReport may be stale | Active-use inventory before retirement | `rg` inventory plus fixture/schema tests |
| SLOP-02 / SQA-DEDUP-03 | Validation helpers drift | Use existing primitives only where policies match | Empty/zero/negative/nonfinite/percentile matrix tests |
| SLOP-03 | UltraGrid scripts duplicate evidence helpers | Move shared logic into `scripts/lib` only with dry-run tests | `shellcheck`; native/Docker fixture comparison |
| SLOP-04 / SQA-DEAD-01 / SQA-DEAD-02 | Vendor/reference noise | Classify/prune only after provenance proof | Swift build, codec tests, release export/hygiene, notices review |
| UI-04 | Armed can show while setup incomplete | Disable arm or change wording until configured | Transport policy tests |
| UI-05 | Packet Monitor unavailable wording conflicts | Rename to no evidence loaded/missing capture | Footer/sidebar/empty-state copy tests |
| TEST-01 / LTV-TEST-07 | False-pass registry gaps | Register false-pass fixtures or tested rationale | ReportSchemaInventory and FixtureSmokeMatrix tests |
| TEST-02 / LTV-FS-06 | Source PASS wording/text-marker risk | Keep product runtime partial and structure skipped gates | VerificationTooling/OpenSourceReleaseReadiness tests |
| TEST-03 | Runtime stress/timing tests missing | Add duplicate flood, TX fairness, callback timing tests | Focused runtime harnesses plus `swift test --no-parallel` when code changes |
| STRUCT-01 | Validator policy drift | Inventory pass-capable validators and shared policies | Central false-pass coverage tests |
| HRA-AUDIO-05 | Lock-backed wrapper may block callback | Prove not on callback path or replace callback use | Call graph test plus contention/deadline harness |
| HRA-P2P-07 | Payload-type mismatches uncounted | Add unexpected payload counters | Mixed-payload socket tests |
| HRA-P2P-09 | Dropped control messages lose detail | Track type/reason and escalate lifecycle mismatches | Control-service unsupported-message tests |
| HRA-VIDEO-02 | Deferred video frame omitted at shutdown | Account final deferred frame on exit | AV sync/shutdown test |
| HRA-ERR-01 | Metrics failures remain counters | Escalate sustained failures/degrade PASS | Metrics socket failure simulation |
| SQA-DEDUP-01 | CLI key-value parsing duplicated | Migrate one command family at a time to existing parser | Command parser tests and smoke checks |
| SQA-DEDUP-02 | Typed argument helpers duplicated | Inline no-value wrappers into existing helper calls | Parser tests and `rg` for old helpers |
| SQA-STRUCT-01 | AppExecutionController too broad | Split helpers after state fixes | App state/log/report tests plus app smoke |
| SQA-STRUCT-02 | AppConsoleModels too broad | Split model groups after UI tests | UI model tests for validation/diagnostics/packet states |
| SQA-STRUCT-03 | P2P local-run command support too broad | Split only after P2P harnesses exist | Local/SSH/timing/artifact tests |
| SQA-STRUCT-04 | NetworkCommands router monolithic | Split by command family after smoke coverage | CLI command inventory and help/smoke tests |
| SQA-DEPRECATED-01 | `audioCompression` compatibility needs proof | Inventory and sunset only with migration tests | `rg`, CLI hidden-help, stored defaults, report decode tests |
| SQA-OVER-01 / UIA-PLACEHOLDER-01 | Placeholder report blurs first-launch evidence | Make loading/placeholder explicit | First-launch app UI tests/screenshots |
| UIA-MENU-01 | Advertised shortcut not wired | Remove text or wire canonical shortcut | Menu/keyboard smoke test |
| UIA-NAV-01 | Validation can auto-navigate to Session | Only auto-navigate on active runtime transition | Sidebar state tests |
| UIA-CONTROL-01 | Intent controls look actionful | Rename as metadata or route through real actions | UI behavior tests |
| UIA-ACCESS-01 | Stop confirmation inconsistent | Shared stop confirmation policy | Stop tests for all entrypoints and running states |
| UIA-STREAM-01 | Preview health uses string parsing | Expose typed preview phase | Preview state tests |
| UIA-STREAM-02 | Preview active but meters inactive | Gate meters on preview/audio state | Local preview manual/UI test |
| UIA-DIAG-01 | Diagnostics source facts read as Ready | Label source/planned status explicitly | First-launch/loaded-report UI tests |
| UIA-SETTINGS-02 | Selected stream setting not wired | Disable or wire real preview stream selection | UI/manual preview setting test |
| LTV-TEST-01 | Tests codify questionable active-state policies | Rewrite tests around desired runtime invariants | AppShellBehavior policy tests |
| LTV-TEST-02 | Nonzero validation exit with PASS report untested | Add controller edge test | AppExecutionControllerValidationTests |
| LTV-TEST-03 | Release script test only all-green path | Add failure propagation tests | VerificationToolingContractTests |
| LTV-TEST-04 | Shell helpers can hang | Add timeout/concurrent draining | Large-output/sleep child tests |
| LTV-TEST-06 | Direct P2P PASS lacks loss/jitter/recovery tests | Encode PASS policy for counters | DirectPeerSessionReportAVPassTests |
| LTV-TEST-08 | Settings-to-runtime SSH bridge untested | Add settings contract bridge test | AppShellSlice05Tests + NativeAppShellTests |
| LTV-HARNESS-01 | Degraded-network/reference gates not default proof | Add opt-in deterministic harnesses | Reference peer gates plus degraded-network simulation |

## 8. P3 Findings

| ID | Short title | Remediation class | Verification path |
| --- | --- | --- | --- |
| COMPAT-01 | Stale docs/compliance pointers | Update pointers when docs edits are allowed | `bash scripts/verify-docs.sh` |
| SQA-SLOP-01 | Ignored `.DS_Store` source-tree clutter | Delete local ignored files when cleanup allowed | `find Sources -name .DS_Store`; `git status` |
| SQA-DEPRECATED-02 | `audioDeviceUID` compatibility needs migration proof | Keep until decode/encode inventory proves safe | `rg audioDeviceUID`; graph config encode/decode tests |
| SQA-STRUCT-05 | Prototype naming misleading | Rename only through schema/CLI migration | `rg` inventory; CLI alias/schema compatibility tests |
| UIA-VIS-01 | Status badges may clip | Verify before layout change | Minimum-width screenshots |
| UIA-VIS-02 | Latency hero may overflow | Verify before layout change | Responsive screenshots |

## 9. Findings By Subsystem

Audio:
- P1: `RT-05`, `HRA-AUDIO-01`, `HRA-AUDIO-04`, `LTV-HARNESS-02`.
- P2/P3: `RT-09`, `RT-10`, `HRA-AUDIO-02`, `HRA-AUDIO-03`, `HRA-AUDIO-05`.

UDP/P2P:
- P1: `RT-01`, `RT-02`, `RT-03`, `RT-06`, `HRA-P2P-01`, `HRA-P2P-02`, `HRA-P2P-03`, `HRA-P2P-04`, `HRA-P2P-08`, `LTV-FS-03`, `LTV-FS-04`, `LTV-FS-05`.
- P2/P3: `HRA-P2P-07`, `LTV-HARNESS-01`.

Video:
- P1: `RT-07`, `LC-05`, `HRA-VIDEO-01`, `HRA-VIDEO-03`, `LTV-HARNESS-02`.
- P2/P3: `HRA-VIDEO-02`, `UIA-VIS-02`.

Control:
- P1: `RT-08`, `LC-01`, `LC-04`, `HRA-P2P-03`.
- P2/P3: `HRA-P2P-09`, `HRA-ERR-01`.

TX:
- P1: `RT-04`, `HRA-P2P-05`.
- P2/P3: `TEST-03`.

RX:
- P1: `RT-01`, `HRA-P2P-04`, `HRA-P2P-06`.
- P2/P3: `HRA-P2P-07`, `HRA-VIDEO-02`.

Local RX:
- P2/P3: `UIA-STREAM-01`, `UIA-STREAM-02`, `UIA-SETTINGS-02`.
- Current evidence did not confirm a Local RX PASS promotion, but local preview/source evidence remains unverified on device.

UI:
- P1: `UI-01`, `UI-02`, `UI-03`, `HRA-UI-01`, `UIA-MENU-02`, `UIA-SESSION-01`, `UIA-SETTINGS-01`, `UIA-STATE-01`, `LTV-FS-01`, `LTV-FS-02`.
- P2/P3: `UI-04`, `UI-05`, `SQA-STRUCT-01`, `SQA-STRUCT-02`, `SQA-OVER-01`, `UIA-MENU-01`, `UIA-NAV-01`, `UIA-CONTROL-01`, `UIA-ACCESS-01`, `UIA-DIAG-01`, `UIA-PLACEHOLDER-01`, `UIA-VIS-01`, `UIA-VIS-02`, `LTV-TEST-08`.

Tests:
- P1: `LTV-TEST-05`, `LTV-HARNESS-02`.
- P2/P3: `TEST-01`, `TEST-02`, `TEST-03`, `LTV-FS-06`, `LTV-TEST-01`, `LTV-TEST-02`, `LTV-TEST-03`, `LTV-TEST-04`, `LTV-TEST-06`, `LTV-TEST-07`, `LTV-TEST-08`, `LTV-HARNESS-01`.

Structure:
- P2/P3: `STRUCT-01`, `SQA-STRUCT-01`, `SQA-STRUCT-02`, `SQA-STRUCT-03`, `SQA-STRUCT-04`, `SQA-STRUCT-05`, `SQA-OVER-01`.

Deprecated code:
- P2/P3: `COMPAT-01`, `SQA-DEPRECATED-01`, `SQA-DEPRECATED-02`.

Dead code:
- P2/P3: `SLOP-01`, `SLOP-04`, `SQA-DEAD-01`, `SQA-DEAD-02`, `SQA-SLOP-01`.

Deduplication:
- P2/P3: `SLOP-02`, `SLOP-03`, `SQA-DEDUP-01`, `SQA-DEDUP-02`, `SQA-DEDUP-03`.

## 10. Remediation Roadmap

Phase 0: safety and verification first
- Fix stale-binary testing and false-success harness foundations: `LTV-TEST-05`, `LTV-TEST-03`, `LTV-TEST-04`.
- Add app false-success tests before changing wording or runtime behavior: `LTV-FS-02`, `LTV-FS-01`.
- Verification: focused Swift tests for the changed test harnesses, `git diff --check`, then relevant `swift test --filter ... --no-parallel`.

Phase 1: P0 runtime fixes
- No confirmed P0 items exist now.
- If a P0 is discovered, freeze cleanup and UI polish, create a reproduction, fix with the smallest patch, and run targeted plus broad verification before resuming this roadmap.

Phase 2: P1 correctness fixes
- App validation/report graph and stale evidence: `LTV-FS-02`, `LTV-FS-01`, `UI-01`, `UI-03`, `HRA-UI-01`.
- Direct P2P lifecycle and report trust: `RT-02`, `RT-03`, `HRA-P2P-01`, `HRA-P2P-02`, `HRA-P2P-03`, `LTV-FS-03`, `LTV-FS-04`.
- Runtime false-success counters/provenance: `RT-05`, `RT-06`, `RT-07`, `HRA-AUDIO-04`, `HRA-P2P-08`, `HRA-VIDEO-01`.
- Boundedness and timing: `RT-01`, `RT-04`, `HRA-AUDIO-01`, `HRA-P2P-04`, `HRA-P2P-05`, `HRA-VIDEO-03`.
- Verification: focused tests per file family, then `swift test --no-parallel` for source changes touching shared contracts.

Phase 3: UI correctness fixes
- Align menu/transport policy: `UIA-MENU-02`, `UIA-SESSION-01`, `UIA-ACCESS-01`.
- Correct Live/Ready/placeholder wording: `UI-01`, `UIA-STATE-01`, `UIA-DIAG-01`, `UIA-PLACEHOLDER-01`.
- Wire or hide unsupported settings: `UI-02`, `UIA-SETTINGS-01`, `UIA-SETTINGS-02`.
- Verification: app-shell Swift tests, built app smoke, screenshots for required states, keyboard/menu manual check.

Phase 4: dead-code and deprecated-path deletion
- Start only after P1 verification is stable.
- Inventory and classify `SQA-DEAD-01`, `SQA-DEAD-02`, `SQA-DEPRECATED-01`, `SQA-DEPRECATED-02`, `SLOP-01`, `COMPAT-01`.
- Verification: `rg` active-use inventory, focused compatibility tests, codec builds, release export/hygiene, docs verifier.

Phase 5: deduplication and simplification
- Convert parser/validator duplication one command/report family at a time: `SQA-DEDUP-01`, `SQA-DEDUP-02`, `SQA-DEDUP-03`, `SLOP-02`, `SLOP-03`.
- Verification: command parser invalid-input tests, validator matrix tests, shellcheck/ruff as applicable.

Phase 6: structure cleanup
- Split only existing responsibilities after behavior is covered: `SQA-STRUCT-01`, `SQA-STRUCT-02`, `SQA-STRUCT-03`, `SQA-STRUCT-04`, `STRUCT-01`.
- Verification: no behavior change tests, command smoke tests, app smoke if app files move.

Phase 7: optional polish
- Visual/accessibility polish: `UIA-VIS-01`, `UIA-VIS-02`, `SQA-SLOP-01`, `SQA-STRUCT-05`.
- Verification: screenshots, keyboard traversal, docs/checks as relevant.

## 11. Suggested Future Implementation Slices

Slice 0: make machine-readable CLI tests use the current binary
- Scope: prevent stale executable false success.
- Findings addressed: `LTV-TEST-05`.
- Files affected: `Tests/OpenLolaCoreTests/MachineReadableSurfaceContractTests.swift`; possibly test helper only.
- Risk: medium; test infrastructure only, but public command surface coverage depends on it.
- Tests needed: stale `/private/tmp` binary, stale `.build` binary, missing binary, current isolated build path.
- Verification commands: `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`; `swift test --filter MachineReadableSurfaceContractTests --no-parallel`.
- Definition of Done: tests cannot execute an old binary and fail loudly when the current binary is unavailable.

Slice 1: app validation rejects invalid or stale direct-peer evidence
- Scope: validate supervisor/child report graph and stale report content before app evidence becomes validated.
- Findings addressed: `LTV-FS-02`, `LTV-FS-01`, `UI-01`, `UIA-STATE-01`.
- Files affected: `AppLatencyHeroMetrics.swift`, `AppExecutionController.swift`, `AppRuntimeEvidenceScope.swift`, app-shell tests.
- Risk: high; app UI-to-runtime truth boundary.
- Tests needed: invalid supervisor PASS, partial child report, invalid child report, fresh sidecar with stale report, nonzero validation exit with PASS-shaped report.
- Verification commands: `swift test --filter AppShellBehaviorTests --no-parallel`; `swift test --filter AppExecutionControllerValidationTests --no-parallel`.
- Definition of Done: app cannot show validation passed/live from stale or invalid report graph evidence.

Slice 2: align Start/Stop/menu runtime action policies
- Scope: make menu and transport use one policy for Start, Stop, validation, and dangerous active sessions.
- Findings addressed: `HRA-UI-01`, `UIA-MENU-02`, `UIA-SESSION-01`, `UIA-ACCESS-01`, `LTV-TEST-01`.
- Files affected: `OpenLolaApp.swift`, `AppTransportView.swift`, `AppConsoleChromeView.swift`, app-shell tests.
- Risk: medium-high; operator workflow behavior changes.
- Tests needed: unconfigured, validation unknown, failed, passed, running, dry-run, supervisor-running, live, stopped, menu/action parity.
- Verification commands: `swift test --filter AppShellBehaviorTests --no-parallel`; app bundle smoke after UI behavior changes.
- Definition of Done: no UI/menu path can start or stop with weaker policy than the visible transport controls.

Slice 3: Direct P2P session lifecycle validation
- Scope: reject mutated sessionAccept and nil/wrong pre-session shutdown/error messages.
- Findings addressed: `RT-02`, `RT-03`, `HRA-P2P-01`, `HRA-P2P-02`, `HRA-P2P-03`.
- Files affected: `PeerSessionRunner.swift`, `SessionControlMessage.swift`, Direct P2P tests.
- Risk: high; protocol lifecycle contract.
- Tests needed: mismatched endpoint/stream/sample-rate accept, nil shutdown during idle/handshake/proposal, wrong-session fatal error.
- Verification commands: focused Direct P2P/SessionStateMachine test filters; then `swift test --no-parallel` if public protocol behavior changes.
- Definition of Done: state cannot become configured/stopped/failed from unbound or mutated remote control messages unless policy explicitly allows it.

Slice 4: Direct P2P artifact-aware PASS validation
- Scope: ensure local two-peer PASS validates referenced artifacts and receive proofs.
- Findings addressed: `LTV-FS-03`, `LTV-FS-04`, `RT-06`, `HRA-P2P-08`.
- Files affected: `DirectPeerTwoPeerLocalRunReport.swift`, `DirectPeerSessionReport.swift`, validators/tests.
- Risk: high; report/public evidence contract.
- Tests needed: nonexistent paths, invalid JSON, partial child report, loopback-as-physical report, missing receive proof, missing packet capture artifact.
- Verification commands: `swift test --filter DirectPeerTwoPeerRunPlanTests --no-parallel`; `swift test --filter DirectPeerSessionReportAVPassTests --no-parallel`.
- Definition of Done: schema-only PASS cannot be mistaken for artifact/runtime PASS.

Slice 5: runtime degradation counters block PASS
- Scope: define PASS/degraded thresholds for realtime audio, Direct P2P AV, UDP route, video capture, and metrics-channel counters.
- Findings addressed: `RT-05`, `RT-06`, `RT-07`, `HRA-AUDIO-04`, `HRA-P2P-08`, `HRA-VIDEO-01`, `HRA-ERR-01`, `LTV-TEST-06`.
- Files affected: report validators and focused validator tests.
- Risk: medium-high; can change accepted reports.
- Tests needed: one fixture per nonzero degradation counter.
- Verification commands: focused validator test filters; `swift test --filter ReportSchemaInventoryTests --no-parallel`.
- Definition of Done: every PASS-capable report has explicit tests for its drop/loss/underrun/error counters.

Slice 6: RX/TX boundedness harnesses
- Scope: duplicate-fragment flood, TX budget fairness, mixed payload counters, missing router fatality.
- Findings addressed: `RT-01`, `RT-04`, `HRA-P2P-04`, `HRA-P2P-05`, `HRA-P2P-06`, `HRA-P2P-07`.
- Files affected: Direct AV audio/video loop tests and runtime code as needed.
- Risk: high; media loop scheduling and packet behavior.
- Tests needed: duplicate fragments, capture backlog, malformed datagrams, payload-type mismatch, missing internal router/stream.
- Verification commands: focused Direct P2P AV loop tests; `swift test --no-parallel` after runtime loop changes.
- Definition of Done: each loop has bounded work or counted/degraded behavior under adversarial packets/backlog.

Slice 7: Core Audio callback and cleanup harnesses
- Scope: host-time overflow, callback duration, lock contention, cleanup failure injection.
- Findings addressed: `HRA-AUDIO-01`, `RT-09`, `RT-10`, `HRA-AUDIO-02`, `HRA-AUDIO-03`, `HRA-AUDIO-05`.
- Files affected: realtime audio graph/callback tests and possibly report fields.
- Risk: high; real-time callback boundary.
- Tests needed: host-time overflow counter, max channel/frame callback timing, cleanup stop/destroy/restore failure, lock contention.
- Verification commands: focused realtime audio tests; Thread Sanitizer smoke where relevant.
- Definition of Done: callback failure/timing/cleanup behavior is measured or counted and cannot silently support PASS.

Slice 8: video capture and receive proof hardening
- Scope: video audio-impact provenance, capture memory bounds, deferred shutdown accounting.
- Findings addressed: `HRA-VIDEO-01`, `HRA-VIDEO-02`, `HRA-VIDEO-03`.
- Files affected: `VideoCaptureRunner.swift`, `VideoCaptureReport.swift`, `VideoCaptureAVFoundation.swift`, Direct AV video loops/tests.
- Risk: medium-high.
- Tests needed: PASS without measured audio impact, long-run capture timestamp retention, shutdown with deferred frame.
- Verification commands: focused video capture/transport tests; app/video smoke when device code changes.
- Definition of Done: video cannot claim audio-safe PASS from defaults, and capture/receive memory/accounting is bounded.

Slice 9: external connector and release false-pass closure
- Scope: connector session nested evidence, rejected media counters, UltraGrid reassembly failure, release readiness missing requirements.
- Findings addressed: `LC-01`, `LC-03`, `LC-04`, `LC-05`, `TEST-01`, `LTV-TEST-07`, `LTV-FS-06`.
- Files affected: connector validators/tests, release readiness validators/tests, fixture inventory.
- Risk: medium-high; public report contracts.
- Tests needed: false-pass fixtures for each public validator, connector rejected media, missing requirement kind, UltraGrid reassembly failure.
- Verification commands: connector focused tests; `swift test --filter ReportSchemaInventoryTests --no-parallel`; `swift test --filter OpenSourceReleaseReadinessTests --no-parallel`.
- Definition of Done: every pass-capable connector/release validator has a central false-pass fixture or explicit cannot-pass rationale.

Slice 10: UI settings and local preview truthfulness
- Scope: SSH settings bridge, preview typed state, selected-stream behavior, diagnostics source labels.
- Findings addressed: `UI-02`, `UI-03`, `UIA-SETTINGS-01`, `UIA-SETTINGS-02`, `UIA-STREAM-01`, `UIA-STREAM-02`, `UIA-DIAG-01`, `UIA-PLACEHOLDER-01`.
- Files affected: settings, preview, diagnostics, app model tests.
- Risk: medium.
- Tests needed: settings-to-runtime bridge, typed preview phases, selected stream disabled/wired, first-launch diagnostics copy.
- Verification commands: `swift test --filter AppShellSlice05Tests --no-parallel`; `swift test --filter NativeAppShellTests --no-parallel`; app screenshots.
- Definition of Done: every visible setting/state either maps to runtime behavior or is visibly disabled/source-level.

Slice 11: cleanup after P1 harnesses
- Scope: parser/validator dedup, structural splits, dead/deprecated inventory.
- Findings addressed: `SQA-DEDUP-*`, `SQA-STRUCT-*`, `SQA-DEAD-*`, `SQA-DEPRECATED-*`, `SLOP-*`, `STRUCT-01`.
- Files affected: one command/report family per slice.
- Risk: low to high depending on family; vendored/reference cleanup is high.
- Tests needed: focused parser/validator/decode/CLI tests; codec/provenance checks for vendor pruning.
- Verification commands: focused tests; `swift build`; `swift test --no-parallel`; `bash scripts/verify-release-hygiene.sh`; `bash scripts/verify-docs.sh`.
- Definition of Done: code is smaller or clearer with no behavior drift and no compatibility path removed without active-use proof.

## 12. Verification Strategy

Source/doc gates:
- `git diff --check`
- `bash scripts/verify-docs.sh`
- `PYTHONDONTWRITEBYTECODE=1 python3 -m scripts.verify_docs`
- `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh`
- `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`
- `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`

Build and unit gates:
- `swift build`
- `swift build --product open-lola`
- `swift build --product open-lola-app`
- `swift test --no-parallel`
- Focused filters listed in each slice before broad runs.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`

App gates:
- `bash script/build_and_run.sh --verify`
- Built app screenshots for first launch, configured/unvalidated, armed, running, validation passed, validation failed, completed run, local preview active, packet monitor empty/populated.
- Manual menu shortcut, keyboard traversal, VoiceOver/Accessibility Inspector, and dangerous Stop confirmation checks.

Release gates:
- `bash scripts/verify-release-readiness.sh`
- `bash scripts/verify-release-hygiene.sh`
- Release export candidate check before any public/release claim.
- Treat source-level PASS and product-runtime PARTIAL as separate facts.

Runtime/hardware gates still required:
- RME/MADI/Core Audio loopback with named device UIDs, fastest profile, callback counters, underrun/overrun counters, and cleanup proof.
- Two-Mac UDP/P2P direct run with packet capture, DSCP/PTP, jitter/loss/reorder/duplicate evidence, reconnect/disconnect behavior, and artifact-aware validation.
- AVFoundation/Blackmagic video capture loopback with frame timing, dropped frames, receive/render proof, device permission denial, device disconnect, and audio-impact measurement.
- Reference peer parity gates for UltraGrid and JackTrip when prerequisites are present; exit `77` remains not PASS.
- Degraded-network harness for loss, jitter, reordering, duplication, disconnect, reconnect, and route timeout.

Verification rule:
- Do not say tests pass unless the named commands ran.
- Do not say runtime works unless media/device/network evidence was produced and validated.
- Do not say audit complete unless all repository files are fully inspected, partially inspected with reason, or explicitly not inspected with reason.

## 13. Remaining Uncertainty

- Full repository file coverage is incomplete. `Sources/` is accounted for; tests, scripts, docs, Linux connector files, fixtures, generated files, private evidence, and archive material are not fully accounted.
- Most `Sources/` files are partially inspected by inventory, not semantically audited.
- No hardware audio/video device run, two-Mac network run, reference-peer run, degraded-network simulation, app Accessibility Inspector pass, or clean-Mac signing/notarization run was performed for this plan update.
- Several validators may intentionally be schema-only. If so, they need names/docs/tests that keep schema validation separate from artifact/runtime proof.
- Some findings are intentionally overlapping. They are not removed because they preserve different evidence: initial pass IDs, runtime pass IDs, UI pass IDs, and logic/test pass IDs may point to the same risk from different angles.
- Docs verification is currently blocked by missing dirty-worktree companion files `plan-remediation-ledger.md` and `plan-remediation-status.md`; this task only permits `plan.md` edits, so the blocker is documented rather than fixed.

## 14. Explicit Non-Goals

- No speculative features.
- No broad rewrite.
- No new abstraction without multiple real call sites and tests.
- No implementation during audit.
- No production code changes.
- No test updates during this finalization pass.
- No generated-file changes.
- No deletion of dead/deprecated/vendor/reference code without active-use, build, release, and provenance verification.
- No promotion of synthetic, localhost, source-level, stale, or placeholder evidence to product PASS.

<details>
<summary>Raw audit evidence appendices retained for traceability</summary>

# Open LoLa Runtime Audit Plan

Date: 2026-05-20
Status: PARTIAL initial audit scaffold and evidence pass
Scope rule: audit-only. This pass created this root plan.md and did not change production code, tests, generated files, scripts, or docs outside this file.
Coverage warning: this is not a completed whole-repository audit. It records initial coverage, initial evidence-backed findings, and the next areas to inspect.
Worktree warning: the checkout was already dirty before this pass. git status --short reported 142 entries, including plan.md deleted before this file was recreated.

## 1. Executive Summary

Open LoLa remains a PARTIAL product from the active public documentation: source-level, localhost, synthetic, archived, and placeholder evidence must not be promoted to field readiness. This audit pass prioritized real-time runtime behavior and false-success surfaces, with subagent slices for inventory, runtime-critical systems, logic/correctness, slop/dead-code/deduplication, UI/UX correctness, and test/verification.

Initial coverage is broad but shallow. The pass inspected active state docs, SwiftPM target layout, selected high-risk runtime files, selected UI state/evidence mapping, selected validators, selected tests, and selected release/evidence scripts. It did not inspect every source file, every validator, every CLI command, every fixture, every script, every Linux connector path, every vendored C source, or any real hardware run.

Initial findings emphasize false success and runtime safety: PASS validators can miss nested failures or missing evidence, Direct P2P setup accepts risky control/configuration states, RX/TX loops have boundedness/fairness gaps, some UI states overstate live/readiness status, and test coverage does not yet force every pass-capable report schema through false-pass fixtures.

Initial finding counts in this scaffold:
- P0: 0 confirmed in this partial pass.
- P1: 16 initial findings.
- P2: 12 initial findings.
- P3: 1 initial finding.

## 2. Audit Scope

In scope for this pass:
- Real-time audio, device I/O, buffering, packet ordering/loss/jitter, and callback boundaries.
- UDP networking and Direct P2P setup/lifecycle/TX/RX/local runtime seams.
- Video capture/transmit/receive report surfaces and deferred/reassembly behavior.
- Control messages, state machines, shutdown, cleanup, and error handling.
- UI correctness for operator-facing live/ready/armed/unavailable claims.
- Slop, boilerplate, dead-code candidates, duplication, deprecated APIs, stale compatibility paths, and report-schema drift.
- Tests and verification contracts that should catch false PASS states.

Out of scope for this pass:
- Fixes, refactors, formatting, deletions, production changes, test updates, or generated-file changes.
- Field validation with real two-Mac, RME/MADI, Blackmagic/ATEM, Windows-originated LoLa, UltraGrid, or JackTrip peers.
- Full security audit, full license audit, full vendored-code audit, full UI visual/accessibility pass, or full release-candidate export.

## 3. Coverage Table

| Priority area | Status | Inspected evidence | Coverage notes |
|---|---|---|---|
| Project verdict and active docs | Partial | README.md lines 16-28, 56-78; docs/current-state.md lines 47-66, 81-82, 107-112; docs/testing.md lines 20-50, 106-182 | Confirms PARTIAL boundary and missing field evidence. |
| SwiftPM module layout | Partial | Package.swift lines 22-262 | Products and targets mapped, including OpenLolaCore, OpenLolaContracts, CLI, app, C atomics, Opus, JPEG XS. |
| File inventory | Partial | find counts: 605 files in sampled core/app/CLI/test roots; 245 files in priority runtime/UI roots; 181 Swift tests | Counts do not mean files were fully inspected. |
| Real-time audio | Partial | DirectPeerRealtimeAudioGraph.swift, DirectPeerAudioPayloadRing.swift, RealtimeAudioPacketHandoff.swift, RealtimeAudioEngineReportValidation.swift | Device graph and selected validators inspected; full CoreAudio path and timing probes not complete. |
| UDP networking | Partial | UdpMediaTransport.swift, DirectPeerSessionAVSocketRunner.swift | Selected transport metrics/close paths inspected; NAT/relay/rendezvous not inspected. |
| P2P setup and lifecycle | Partial | PeerSessionRunner.swift, SessionControlMessage.swift | Handshake, accept, shutdown, and state-machine risks sampled. |
| Video capture/transmit/receive | Partial | VideoCaptureRunner.swift, VideoCaptureReport.swift, DirectPeerSessionAVVideoLoops.swift | Report/provenance and deferred-frame areas sampled; full AVFoundation runtime not complete. |
| Control messages | Partial | SessionControlMessage.swift, PeerSessionRunner.swift | Shutdown handling sampled; full control protocol not complete. |
| TX path | Partial | DirectPeerSessionAVAudioLoops.swift, DirectPeerSessionAVSocketRunner.swift | Audio TX fairness sampled; full video TX not complete. |
| RX path | Partial | DirectPeerSessionAVAudioLoops.swift, DirectPeerSessionAVVideoLoops.swift, RealtimeAudioPacketHandoff.swift | Audio reassembly and deferred video sampled; full RX path not complete. |
| Local RX path | Partial | DirectPeerRealtimeAudioGraph.swift, RxBuffering.swift | Local playout/buffer reporting sampled; full local RX runtime not complete. |
| Buffering and timing | Partial | RxBuffering.swift, RealtimeAudioEngineReportValidation.swift, LatencyTuningReportValidation.swift | Validation and metric drift sampled. |
| Packet ordering/loss/jitter | Partial | RealtimeAudioPacketHandoff.swift, UdpMediaTransport.swift, DirectPeerSessionReport.swift | Counters sampled; PASS rejection policy incomplete. |
| Device I/O | Partial | DirectPeerRealtimeAudioGraph.swift and callbacks | Callback workload and cleanup sampled; hardware not run. |
| Thread/concurrency boundaries | Partial | DirectPeerAudioPayloadRing.swift, DirectPeerRealtimeAudioGraph.swift, RealtimeAudioPacketHandoff.swift | Lock-free and lock-backed paths sampled; no Thread Sanitizer run. |
| State machines | Partial | SessionControlMessage.swift, PeerSessionRunner.swift | Shutdown and accept transitions sampled. |
| Error handling | Partial | LoLaControlExchangeRuntime.swift, PeerSessionRunner.swift, AppExecutionController.swift | Swallowed background errors and UI validation handling sampled. |
| Cleanup/shutdown | Partial | DirectPeerRealtimeAudioGraph.swift, PeerSessionRunner.swift | Cleanup handle/state behavior and remote shutdown sampled. |
| UI correctness | Partial | AppSessionStateBanner.swift, AppRuntimeEvidenceScope.swift, AppShellSettingsTabs.swift, AppSettings.swift, AppConsoleModels.swift, AppTransportView.swift, AppConsoleChromeView.swift | Semantic state sampled; no running app screenshot/accessibility pass. |
| Slop/dead-code/dedup/deprecated | Partial | MeasurementReport.swift, ReportSchemaInventory.swift, parity scripts, release hygiene scripts, THIRD_PARTY_NOTICES.md | Initial stale/duplicate candidates only. |
| Tests and verification | Partial | ReportSchemaInventoryTests.swift, ReportFixtureValidationContractTests.swift, focused runtime/UI tests | Coverage gaps identified; no tests run during discovery. |

## 4. Uninspected or Partially Inspected Files

Not fully inspected:
- Most files under Sources/OpenLolaCore beyond the sampled high-risk runtime/report paths.
- Most files under Sources/open-lola and Sources/open-lola-app-main.
- Most CLI command implementations and command argument parsing.
- Most Tests/OpenLolaCoreTests files, fixtures, and generated report-contract data.
- linux_connector and Python tests, except by active-doc context.
- Vendored/reference C sources under Sources/opus-1.5.2 and Sources/xs_ref_sw_ed2.
- Release export artifacts, archive contents, private evidence, historical reports, and generated output.
- NAT, rendezvous, relay, broader UltraGrid/JackTrip/LoLa live process lifecycle, and physical hardware behavior.
- Full SwiftUI visual layout, app bundle launch, accessibility tree, menu behavior, and screenshot evidence.

Partially inspected but not complete:
- Direct P2P AV socket runner and loop internals.
- Realtime CoreAudio graph callback paths.
- Report validators for public PASS/PARTIAL evidence.
- Release readiness and source/release gate wording.
- UI state mapping from report/runtime evidence.

## 5. Runtime Architecture Map

- Package.swift defines the main product boundary. OpenLolaCore holds core runtime, protocols, reports, validators, release harnesses, and audio/video/network/control implementations. OpenLolaContracts holds shared verdict/report contracts. Sources/open-lola is the CLI entry point. Sources/open-lola-app and Sources/open-lola-app-main provide SwiftUI app support and entry.
- Realtime audio flows through CoreAudio graph setup, IOProc callbacks, lock-free audio payload rings, RX buffering policy, packet handoff, and runtime evidence reports.
- Direct P2P flows through control negotiation, accepted session configuration, UDP transports for audio/video/metrics/control, TX/RX AV loops, playout buffering, and session reports.
- Video runtime spans capture inventory/capture reports, AVFoundation capture runner, Direct P2P video TX/RX loops, UltraGrid/JackTrip/LoLa connector media reports, and report validators.
- Report validators and release/evidence scripts are public trust boundaries because they decide whether source/runtime evidence is PASS, PARTIAL, or FAIL.
- SwiftUI app surfaces consume operator settings, runtime evidence scope, command previews, validation readiness, and session state mapping. Any Live, Ready, Armed, healthy, connected, or PASS label must match real evidence.

## 6. High-Risk Runtime Findings

- ID: RT-01
- Severity: P1
- Category: Buffering / memory bound
- Subsystem: Direct P2P AV audio RX
- File: Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift
- Line range or symbol: DirectPeerOpenLolaRawAudioReassemblyState.receive, around line 111
- Evidence: Pending deadlines are capped, but each deadline stores an append-only packet array. Duplicate fragments for the same incomplete deadline are appended before reassembly deduplicates. Existing sampled tests cover completion and max pending deadlines, not duplicate-fragment flood for one deadline.
- Why it matters: A noisy or hostile peer can grow memory and reassembly CPU inside one deadline, bypassing maxPendingDeadlines.
- Runtime/user impact: RX loop starvation, memory growth, audio drops, or process termination under malformed UDP input.
- Suggested remediation: Store fragments by index, drop/count duplicates before appending, and enforce max fragments per deadline.
- Verification required: Focused duplicate-fragment flood unit test plus Direct AV RX simulation.
- Suggested test: Send the same first fragment thousands of times without the missing fragments; assert pending storage stays bounded and later valid fragments still reassemble.
- Risk of change: Medium.
- Confidence: high

- ID: RT-02
- Severity: P1
- Category: Negotiation validation / state machine
- Subsystem: Direct P2P setup and media endpoint selection
- File: Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift
- Line range or symbol: receiveControlMessage(.sessionAccept) and startMedia, around line 401
- Evidence: Responder negotiation validates proposals, but the initiator accepts remote SessionConfiguration and stores it as acceptedConfiguration. startMedia then connects transports from that accepted config. The AV runner validates accepted audio payload type, but not the full proposed stream shape or endpoint contract.
- Why it matters: A peer can accept a different stream shape, peer identity mapping, or media endpoint than the initiator proposed.
- Runtime/user impact: Media can route to wrong ports/hosts or run with mismatched audio assumptions while the session reports configured/running.
- Suggested remediation: Validate accepted config against the stored proposal and local capabilities before entering configured.
- Verification required: Initiator-side tests for mutated accept configs.
- Suggested test: Mutate sample rate or accepted remote endpoint after a valid proposal; assert accept is rejected and acceptedConfiguration remains nil.
- Risk of change: Medium to high.
- Confidence: high

- ID: RT-03
- Severity: P1
- Category: Lifecycle / control-plane authorization
- Subsystem: P2P shutdown handling
- File: Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift; Sources/OpenLolaCore/Protocol/SessionControlMessage.swift
- Line range or symbol: .shutdown handling, acceptsShutdownSessionID, SessionStateMachine shutdown transition
- Evidence: Shutdown messages may omit sessionID. Before an accepted session exists, nil shutdown is accepted, and the state machine allows shutdown from idle. Existing lifecycle tests cover stale/current shutdown after accepted sessions, not pre-accept nil shutdown rejection.
- Why it matters: Setup can be aborted by a remote nil-session shutdown before session binding exists.
- Runtime/user impact: Manual P2P connection may close during handshake/configuration with confusing lifecycle state.
- Suggested remediation: Require an accepted session ID for remote shutdown, or separate local operator stop from remote control shutdown.
- Verification required: Idle/handshaking shutdown tests plus accepted-session shutdown regression.
- Suggested test: During handshaking, receive nil-session shutdown and assert it is rejected without closing transports; then verify accepted-session shutdown still closes.
- Risk of change: Medium.
- Confidence: medium-high

- ID: RT-04
- Severity: P1
- Category: Scheduling / backpressure
- Subsystem: Direct P2P AV TX/RX loop fairness
- File: Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift
- Line range or symbol: runAudioTXLoop, around line 9
- Evidence: Audio TX drains captured payloads in an unbounded while true until the capture ring is empty. The surrounding AV loop has explicit RX/video drain limits, but TX has no comparable packet or time budget.
- Why it matters: After scheduler stalls or slow sends, one loop iteration can spend too long transmitting backlog before servicing RX, control, or video.
- Runtime/user impact: Delayed shutdown/control handling, increased RX latency, video/audio drift, and dropped playout under load.
- Suggested remediation: Add a bounded per-iteration TX budget and backlog metric.
- Verification required: Fake-runner simulation with queued capture backlog and control/RX fairness assertions.
- Suggested test: Enqueue more payloads than budget; assert only the budget sends in one iteration and remaining work is deferred.
- Risk of change: Medium.
- Confidence: medium-high

- ID: RT-05
- Severity: P1
- Category: False-success validation risk
- Subsystem: Realtime audio RX buffering and packet ordering
- File: Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift; Sources/OpenLolaCore/Timing/RxBuffering.swift; Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineReportValidation.swift
- Line range or symbol: recordReceiveSequence lines 319-345; RxBufferMetrics validation lines 366-383; validatePassHandoff/validatePassRxBufferPolicy lines 216-303
- Evidence: recordReceiveSequence updates rxBuffer lostPackets, duplicatePackets, and reorderedPackets. RxBufferMetrics validates those counters as non-negative. PASS validation checks callback/handoff dropped/late/underrun/allocation fields and RX buffer policy bounds, but the sampled code did not reject nonzero rxBuffer lost, duplicate, reordered, underrun, or overrun counters.
- Why it matters: A runtime report can carry packet loss/reordering evidence while still passing if the loss is represented only in rxBuffer counters.
- Runtime/user impact: Audio impairment can be promoted as PASS, hiding jitter/loss problems from release or operator gates.
- Suggested remediation: Add explicit PASS guards for all RX buffer loss/reorder/duplicate/underrun/overrun counters, with documented exceptions if any counter is acceptable.
- Verification required: Focused RealtimeAudioEngine pass-validation tests.
- Suggested test: Mutate a PASS candidate to set runtime.handoff.rxBuffer.lostPackets = 1 and assert validation fails.
- Risk of change: Low to medium.
- Confidence: high

- ID: RT-06
- Severity: P1
- Category: False-success validation risk
- Subsystem: Direct P2P AV session reports
- File: Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift; Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift
- Line range or symbol: pass validation lines 191-276; AV runtime metrics validation lines 584-698; AV metrics aggregation lines 517-544
- Evidence: PASS validation requires measured physical evidence/artifacts and positive routed/sent counts, but sampled checks did not reject nonzero packetsLost, audio payload drops, playout drops, audio playout underruns, video frame drops, or remote underruns/overruns. Runtime aggregation records these counters.
- Why it matters: A Direct P2P report can prove that some media moved while still hiding unacceptable drop/underrun/loss evidence.
- Runtime/user impact: Operators and release gates may treat degraded sessions as successful.
- Suggested remediation: Define pass thresholds for drop/loss/underrun/video-drop counters and make PASS validation enforce them.
- Verification required: DirectPeerSessionReport validator tests with each nonzero degradation counter.
- Suggested test: Build a measured physical PASS candidate with avRuntime.runtimeMetrics.audioPlayoutUnderruns = 1 and assert validation fails or demotes to PARTIAL.
- Risk of change: Medium.
- Confidence: high

- ID: RT-07
- Severity: P1
- Category: Synthetic/default evidence overstatement
- Subsystem: Video capture audio-impact reporting
- File: Sources/OpenLolaCore/Video/VideoCaptureRunner.swift; Sources/OpenLolaCore/Video/VideoCaptureReport.swift
- Line range or symbol: makeReport lines 171-207; defaultVideoCaptureAudioImpact lines 279-289; PASS validation lines 319-390
- Evidence: VideoCaptureRunner.makeReport uses configuration.audioImpact or defaultVideoCaptureAudioImpact. The default returns fixed no-impact values. PASS validation checks audio-impact values, but sampled code did not require provenance proving those values were measured under the capture run.
- Why it matters: Video capture can claim no audio impact based on default constants rather than measured runtime evidence.
- Runtime/user impact: Video capture may be promoted as safe for audio-first low-latency operation without proof.
- Suggested remediation: Add an audio-impact provenance/evidence field and reject PASS when the values are defaults or unmeasured.
- Verification required: Video capture report validation tests and runner tests.
- Suggested test: Construct a pass-capable AVFoundation/raw candidate with default audioImpact and assert validation rejects missing measured provenance.
- Risk of change: Medium.
- Confidence: medium-high

- ID: RT-08
- Severity: P1
- Category: Error handling / false started state
- Subsystem: LoLa control retry responder
- File: Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeRuntime.swift
- Line range or symbol: startRetryResponder, around lines 174-222
- Evidence: The retry responder returns started: true after spawning a background loop. The loop catches all errors and continues, so repeated receive/parse/send failures do not change the returned report or expose a failure count in the sampled start report.
- Why it matters: The runtime can report the responder started while the background control path is repeatedly failing.
- Runtime/user impact: Connector control-plane readiness can be overstated and failures become hard to diagnose.
- Suggested remediation: Expose responder health, last error, and failure counters; fail start if the responder cannot perform an initial receive/send readiness step where practical.
- Verification required: Injectable transport failure tests.
- Suggested test: Inject repeated receive/send failure and assert responder report exposes degraded/failing health instead of only started: true.
- Risk of change: Medium.
- Confidence: medium

- ID: RT-09
- Severity: P2
- Category: Real-time callback workload
- Subsystem: CoreAudio device I/O
- File: Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift; Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphCallbacks.swift
- Line range or symbol: copyMappedInput, renderPlayout, copyMappedOutput, IOProc callbacks around line 603
- Evidence: IOProc paths perform full-buffer clears and frame-by-channel copies inside the callback. Tests cover synthetic mapping behavior but not callback duration or worst-case supported channel/frame sizes.
- Why it matters: Callback work is bounded by frame/channel counts, but the pass has no measured duration evidence for worst-case supported configurations.
- Runtime/user impact: Callback overruns, input drops, or output underruns on higher channel counts or slower devices.
- Suggested remediation: Add callback duration instrumentation first; then optimize direct-copy fast paths, precomputed copy plans, and unnecessary clears if measurement shows risk.
- Verification required: Callback timing benchmark/probe across supported channel/frame configurations.
- Suggested test: Synthetic IOProc benchmark for 2, 16, and 64 channels at 32 and 64 frames, asserting p99 callback time remains below the packet period.
- Risk of change: Low for instrumentation; medium/high for copy-path changes.
- Confidence: medium

- ID: RT-10
- Severity: P2
- Category: Cleanup/shutdown recoverability
- Subsystem: CoreAudio device I/O cleanup
- File: Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift
- Line range or symbol: stopUnlocked, around lines 283-371
- Evidence: stopUnlocked records cleanup failures but clears inputIOProcID, outputIOProcID, device IDs, and original device properties regardless of stop/destroy/restore success.
- Why it matters: If cleanup fails, the object may no longer retain enough handles/state to retry cleanup or escalate with precise device context.
- Runtime/user impact: Device state restoration failures can become harder to recover from after a partial stop.
- Suggested remediation: Preserve retry-relevant state until cleanup succeeds, or explicitly document/report unretryable cleanup failure with all needed handles before clearing.
- Verification required: Cleanup failure injection tests.
- Suggested test: Simulate stop/destroy/restore failure and assert the failure report retains enough state to retry or diagnose.
- Risk of change: Medium.
- Confidence: medium

## 7. Logic and Correctness Findings

- ID: LC-01
- Severity: P1
- Category: Missing validation / false success
- Subsystem: External connector session reports
- File: Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift; Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift
- Line range or symbol: validation errors lines 27-29; report fields lines 552-569; validate lines 609-653; tests lines 588-600
- Evidence: The session validator rejects PASS only for dry-run reports. It defines runtimePassMissingEvidence and runtimePassWithRuntimeError, but sampled validate code did not reject verdict: pass with runtimeError, runtimeErrorFree == false, missing connector media evidence, or non-pass nested media evidence. Tests cover dry-run pass rejection only.
- Why it matters: The outer connector session shell can claim PASS even when runtime failure state or missing nested evidence should prevent a pass.
- Runtime/user impact: Connector interoperability/session success can be overstated by validate-external-connector-session-report.
- Suggested remediation: Add pass-specific validation requiring no runtime error, runtimeErrorFree == true, connector media evidence present where applicable, and nested media/report verdicts consistent with the outer pass.
- Verification required: Focused ExternalConnectorSession validator tests.
- Suggested test: Create a non-dry-run ExternalConnectorSessionReport with verdict pass, runtimeError "late failure", and connectorMediaReport nil; assert validation fails with the existing runtime-pass error.
- Risk of change: Medium.
- Confidence: high

- ID: LC-02
- Severity: P1
- Category: Hardcoded placeholder metrics / synthetic evidence overstatement
- Subsystem: E2E benchmark reports
- File: Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkRunner.swift; Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReportValidation.swift; Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkSyntheticSmoke.swift; Sources/OpenLolaCore/Support/SyntheticPlaceholderMetrics.swift
- Line range or symbol: runner lines 72-130 and 312-360; validator lines 185-210; synthetic smoke lines 24-40 and 156-248; placeholder metrics lines 1-4
- Evidence: When subordinate reports are considered physical, the E2E runner can emit measured, physicalTwoPeerRig, and a pass verdict while using hardcoded jitter/loss/recovery/impairment values. Recovery is synthesized as one reconnect with 120000 microseconds, packet loss/reordered/duplicate counts are zero, and impairment runs can be measured/pass with injectedPackets: 0, observedPackets: 0, recoveredPackets: 0. The validator checks measured/pass flags but sampled code did not require nonzero injected/observed impairment evidence.
- Why it matters: A report can look like measured E2E runtime evidence even when critical E2E-specific network, impairment, and recovery observations were not actually collected.
- Runtime/user impact: Operators or release gates may trust a PASS E2E benchmark partly assembled from constants rather than measured session artifacts.
- Suggested remediation: Require explicit E2E evidence inputs for recovery, network counters, route evidence, and impairment injection before measured/pass is allowed.
- Verification required: E2E report validation tests and runner tests.
- Suggested test: Feed pass-capable subordinate reports into the runner without impairment/recovery artifacts and assert final E2E verdict remains PARTIAL; mutate a pass report to injectedPackets: 0 and assert validation fails.
- Risk of change: Medium.
- Confidence: high

- ID: LC-03
- Severity: P1
- Category: Missing validation / false success
- Subsystem: Release readiness report validation
- File: Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift; Tests/OpenLolaCoreTests/OpenSourceReleaseReadinessTests.swift
- Line range or symbol: validate lines 84-119; runner verdict lines 153-169; tests lines 22-31 and 175-193
- Evidence: The validator rejects empty requirements, duplicate kinds, invalid fields, release blockers, and partial individual requirements, but sampled code did not require the report to contain every OpenSourceReleaseRequirementKind.allCases entry. Tests assert the runner emits all current requirements, but public validator tests do not cover a forged/incomplete PASS report missing a required kind.
- Why it matters: A public readiness validator can accept an incomplete verdict pass report if the provided subset is finalized.
- Runtime/user impact: Release readiness can be overstated, especially for omitted categories like source license, reviewer signoff, packaging, or security posture.
- Suggested remediation: Make validate compare the submitted requirement-kind set against allCases and fail PASS reports with missing or extra requirement kinds.
- Verification required: OpenSourceReleaseReadiness validator tests.
- Suggested test: Remove one requirement from passCandidateReport while keeping verdict pass; assert validation fails with a missing-requirement error.
- Risk of change: Low to medium.
- Confidence: high

- ID: LC-04
- Severity: P1
- Category: False-success validation risk
- Subsystem: External connectors / media sink validation
- File: Sources/OpenLolaCore/Connectors/Core/ExternalConnectorReport.swift; Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibility.swift; Sources/OpenLolaCore/Connectors/JackTrip/JackTripPassValidation.swift
- Line range or symbol: ExternalConnectorMediaSinkReport.validate; UltraGridCompatibilityMediaReport.validatePassEvidence; JackTripCompatibilityMediaReport.validatePassEvidence
- Evidence: Sink validation checks non-negative counters and notes. UltraGrid/JackTrip PASS validation checks link/evidence/runtimeError, but sampled code did not reject sink.rejectedMediaCount > 0.
- Why it matters: A PASS report can include rejected decoded media without the validator rejecting it.
- Runtime/user impact: Connector interoperability can be overstated.
- Suggested remediation: Add PASS guards for rejected media and minimum expected decoded media for receiving roles.
- Verification required: Focused UltraGrid/JackTrip PASS-validation tests.
- Suggested test: Mutate existing PASS fixtures/tests to set sink.rejectedMediaCount = 1 and expect validation failure.
- Risk of change: Low to medium.
- Confidence: high

- ID: LC-05
- Severity: P1
- Category: Runtime failure classification
- Subsystem: UltraGrid video RX/reassembly
- File: Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibilityRunner.swift; Tests/OpenLolaCoreTests/UltraGridCompatibilityTests.swift
- Line range or symbol: runtimeErrors, countVideoFrameReassemblyFailures, ultraGridReceiveAnalysisReportsLossAndVideoReassemblyFailures
- Evidence: The runner fails on short receive count or recovery throw, while sampled test evidence asserts PARTIAL with videoFrameReassemblyFailureCount == 1 and sink.rejectedMediaCount == 1.
- Why it matters: Incomplete video reassembly is a media failure but remains PARTIAL rather than FAIL in the sampled path.
- Runtime/user impact: Operators may see a non-fail result for unusable video media.
- Suggested remediation: Define whether any RX reassembly failure in a live run is FAIL; update verdict logic accordingly.
- Verification required: Focused UltraGrid RX test for incomplete frame verdict.
- Suggested test: Expect FAIL or explicit runtimeError when videoFrameReassemblyFailureCount > 0 under RX or TX-RX.
- Risk of change: Medium.
- Confidence: medium

## 8. Slop, Boilerplate, Dead Code, and Deduplication Findings

- ID: SLOP-01
- Severity: P2
- Category: Stale compatibility / dead-code candidate
- Subsystem: Evidence/report fixtures
- File: Sources/OpenLolaCore/Evidence/MeasurementReport.swift; Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift; Tests/OpenLolaCoreTests/MeasurementReportFixtureTests.swift
- Line range or symbol: MeasurementReportKind, MeasurementReport, MeasurementReports
- Evidence: MeasurementReport is a generic endpoint/network/video/lighting/field-test schema. Current sampled references were fixture/inventory/test-only, and inventory text says it preserves a legacy/source contract shape.
- Why it matters: It duplicates newer domain-specific report contracts and keeps generic report fixtures alive without an obvious runtime or CLI surface.
- Runtime/user impact: Low direct runtime risk, but it adds schema/test noise and can confuse which report model is authoritative.
- Suggested remediation: Classify it as active contract or retire it with its fixtures/inventory entry.
- Verification required: rg -n "MeasurementReport|MeasurementReports" Sources Tests docs scripts README.md; focused fixture/schema tests.
- Suggested test: Remove or migrate one fixture path and ensure inventory/fixture tests fail usefully.
- Risk of change: Medium.
- Confidence: medium

- ID: SLOP-02
- Severity: P2
- Category: Duplicate validation code
- Subsystem: Benchmark/report validation
- File: Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReportValidation.swift; Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReportValidation.swift; Sources/OpenLolaCore/Timing/LatencyTuningReportValidation.swift
- Line range or symbol: validateE2ECounter, validatePacketAge, validateLatencyTuningTiming
- Evidence: Multiple validators repeat non-negative percentile checks and ordered percentile checks. PerformanceAudit requires positive sampleCount, while E2E only requires non-negative.
- Why it matters: Subtle policy drift in report validation can allow one report to accept empty counters another rejects.
- Runtime/user impact: Report validity and PASS/PARTIAL evidence trust can diverge.
- Suggested remediation: Extract shared counter/packet-age validators with explicit allow-empty policy, or document/test why each contract differs.
- Verification required: Focused tests for zero sample count, invalid samples, unordered percentiles, and non-finite values.
- Suggested test: One shared validation matrix reused by E2E, performance, and latency tuning reports.
- Risk of change: Medium.
- Confidence: high

- ID: SLOP-03
- Severity: P2
- Category: Deduplication / evidence-tool drift
- Subsystem: UltraGrid parity helpers
- File: scripts/run-local-ultragrid-rxtx-native.sh; scripts/run-local-ultragrid-rxtx-docker.sh; scripts/lib/parity.sh
- Line range or symbol: write_connection_metrics, wait_for_log_text, parity_wait_for_file_text
- Evidence: Native and Docker scripts duplicate connection-metric and polling logic. Native script defines wait_for_log_text while shared parity_wait_for_file_text already exists.
- Why it matters: Parity scripts are evidence tools; divergent helper behavior can make native vs Docker results incomparable.
- Runtime/user impact: Operator evidence may fail or pass differently depending on wrapper path.
- Suggested remediation: Move shared metric-writing and wait/poll logic into scripts/lib.
- Verification required: shellcheck plus focused dry-run/preflight failure checks for both native and Docker paths.
- Suggested test: Compare generated connection JSON shape for native and Docker runs with controlled log fixtures.
- Risk of change: Medium.
- Confidence: high

- ID: SLOP-04
- Severity: P2
- Category: Vendored/reference boundary noise
- Subsystem: Release/vendor hygiene
- File: Package.swift; scripts/export-release-candidate.sh; scripts/verify-release-hygiene.sh; docs/release-boundary.md
- Line range or symbol: COpus, CJpegXSReference, remove_uncompiled_vendor_artifacts
- Evidence: Package.swift compiles selected Opus/JPEG XS subsets, while release export strips upstream tests, DNN, training, extras, programs, and build metadata. A read-only git ls-files sample found 347 tracked files under stripped vendor-extra patterns.
- Why it matters: Raw-checkout audits repeatedly traverse material the release boundary already excludes.
- Runtime/user impact: Low runtime impact, but high review/audit noise and legal/release surface confusion.
- Suggested remediation: Keep as-is only if full upstream drops are required for provenance; otherwise prune to build subset plus license/origin metadata.
- Verification required: Release export, release hygiene, Swift build/tests for codec targets, and legal notice review.
- Suggested test: Release candidate still includes only selected build subset and passes hygiene after pruning.
- Risk of change: High without legal/provenance review.
- Confidence: high

## 9. Deprecated API and Compatibility Findings

- ID: COMPAT-01
- Severity: P3
- Category: Stale documentation / archived-doc churn
- Subsystem: Release docs
- File: THIRD_PARTY_NOTICES.md; docs/release-boundary.md; scripts/verify_docs/constants.py
- Line range or symbol: stale docs/compliance references
- Evidence: Active notices point to docs/compliance/README.md and docs/compliance/release-manifest.md, while active release docs are flat docs/release-boundary.md and docs/release-manifest.md. Docs verifier constants list several docs/compliance paths as stale.
- Why it matters: Release readers can follow dead paths during compliance review.
- Runtime/user impact: No runtime impact; release-review confusion.
- Suggested remediation: Update notice pointers to current flat docs or archive references.
- Verification required: bash scripts/verify-docs.sh when edits are allowed.
- Suggested test: Docs verifier should flag active references to retired docs/compliance paths.
- Risk of change: Low.
- Confidence: high

Deprecated/stale compatibility areas needing next audit:
- MeasurementReport legacy/source contract shape.
- Vendored reference source boundary versus release-candidate boundary.
- Archived documents and generated historical outputs that may still be referenced by active docs or scripts.
- Connector compatibility paths that preserve source-level parity without measured peer evidence.

## 10. UI/UX Correctness Findings

- ID: UI-01
- Severity: P1
- Category: Misleading runtime state
- Subsystem: App shell state/evidence mapping
- File: Sources/open-lola-app/AppSessionStateBanner.swift; Sources/open-lola-app/AppDesignSystem.swift
- Line range or symbol: AppSessionState.derive, AppSessionState.live
- Evidence: runFinished or validationPassed with hasValidatedRuntimeEvidence maps to .live, and .live renders as label Live, green, animated.
- Why it matters: Validated evidence after a completed run is not the same as an active connected/streaming session.
- Runtime/user impact: Operator can see Live after process completion and infer current streaming health.
- Suggested remediation: Split validated evidence from live/streaming; reserve Live for an active runtime stream with current evidence.
- Verification required: Semantic state tests plus rendered footer/banner label test.
- Suggested test: runFinished + validated evidence + !isRunning renders Evidence validated, not Live.
- Risk of change: Medium.
- Confidence: high

- ID: UI-02
- Severity: P1
- Category: Unwired setting / unreachable runtime mode
- Subsystem: Settings execution mode
- File: Sources/open-lola-app/AppShellSettingsTabs.swift; Sources/open-lola-app/AppSettings.swift; Sources/OpenLolaCore/Platform/NativeAppShellExecution.swift
- Line range or symbol: AppExecutionSettingsTab, AppSettingsDraft.apply(to:), NativeAppShellExecutionSettings.validate
- Evidence: UI exposes SSH execution mode and SSH targets, but sampled code did not expose/persist sshFallbackExplicitlySelected or sshFallbackReason. Core validation requires both.
- Why it matters: The app offers an execution mode that cannot successfully generate/run supervisor arguments from the UI.
- Runtime/user impact: SSH mode appears configured, then command preview/start fails with validation errors.
- Suggested remediation: Hide SSH mode until fully wired, or add explicit fallback confirmation/reason fields and persist them.
- Verification required: Settings commit test and command preview/run argument test for SSH mode.
- Suggested test: Saving SSH settings with explicit reason produces --ssh-fallback-explicit true and --ssh-fallback-reason.
- Risk of change: Medium.
- Confidence: high

- ID: UI-03
- Severity: P1
- Category: Misleading validation readiness
- Subsystem: Validation / Can I Run
- File: Sources/open-lola-app/AppConsoleModels.swift; Sources/open-lola-app/AppExecutionController.swift; Sources/open-lola-app/AppTransportView.swift
- Line range or symbol: AppValidationPreflightModel.make, validationReadiness
- Evidence: Preflight returns Ready after plan/surface checks without consulting missing/stale report readiness, while Validate button/menu are disabled through validationReadiness.
- Why it matters: Can I Run can say ready while validation cannot run against the current report path.
- Runtime/user impact: Operator gets contradictory guidance: ready panel, disabled validate action.
- Suggested remediation: Include validationReadiness(operatorSurface:) in the preflight model and show missing/stale report blockers.
- Verification required: Model tests for missing report, stale token, unreadable token.
- Suggested test: Missing supervisor report makes preflight Blocked or explicit report missing, not Ready.
- Risk of change: Low.
- Confidence: high

- ID: UI-04
- Severity: P2
- Category: Misleading armed state
- Subsystem: Transport controls / footer
- File: Sources/open-lola-app/AppTransportView.swift; Sources/open-lola-app/AppConsoleChromeView.swift; Sources/open-lola-app/OpenLolaApp.swift
- Line range or symbol: armButton, AppFooterTransportPolicy.stateTitle, arm-execution
- Evidence: Arm toggles when workflow is supported, even if plan.isConfigured is false. Footer displays Armed whenever armedForExecution is true.
- Why it matters: Armed is a readiness claim, but setup may still be incomplete.
- Runtime/user impact: Start remains disabled, but footer/transport can imply the session is armed.
- Suggested remediation: Disable arm until plan is configured, or render Setup required instead of Armed; apply the same guard to menu action.
- Verification required: Transport policy tests for unconfigured + armed.
- Suggested test: Unconfigured surface cannot enter visible Armed footer state.
- Risk of change: Low.
- Confidence: high

- ID: UI-05
- Severity: P2
- Category: Contradictory status label
- Subsystem: Packet Monitor
- File: Sources/open-lola-app/AppConsoleModels.swift; Sources/open-lola-app/AppPacketMonitorView.swift; Sources/open-lola-app/AppConsoleChromeView.swift
- Line range or symbol: packetTitle, AppPacketMonitorEmptyState, AppPacketMonitorSidebarPolicy
- Evidence: Footer says Packet monitor unavailable when no capture exists, but the section is intentionally reachable with a truthful empty state after configuration.
- Why it matters: Unavailable conflicts with the reachable monitor/recovery workflow.
- Runtime/user impact: Operator may think the feature is disabled rather than waiting for capture evidence.
- Suggested remediation: Rename status to No packet evidence loaded or Capture evidence missing.
- Verification required: Footer/sidebar/empty-state copy tests.
- Suggested test: Configured session with nil capture report renders reachable Packet Monitor and no unavailable status text.
- Risk of change: Low.
- Confidence: medium-high

## 11. Test and Verification Findings

- ID: TEST-01
- Severity: P2
- Category: Weak tests / skipped false-pass coverage
- Subsystem: Report schema and fixture validation tests
- File: Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift; Tests/OpenLolaCoreTests/ReportFixtureValidationContractTests.swift
- Line range or symbol: false-pass test lines 257-288; false-pass registry lines 392-511; accepted fixture registry lines 37-226
- Evidence: The central false-pass test only exercises validators registered in falsePassFixtureValidators. That registry covers a limited set of report families and does not include several pass-capable public validators involved in this audit, including E2E benchmark, open-source release readiness, and external connector session reports.
- Why it matters: The suite has a false-pass safety net, but important public validators can drift outside it.
- Runtime/user impact: New or existing report schemas can accept overclaimed PASS states without failing central report-contract tests.
- Suggested remediation: Require every pass-capable public report schema to register either false-pass fixtures or an explicit cannot-pass-by-design reason.
- Verification required: Add false-pass fixtures and run ReportSchemaInventoryTests plus focused validator tests.
- Suggested test: Add false-pass fixtures for incomplete release readiness, E2E zero-impairment measured pass, and connector session pass-with-runtime-error; assert each fails through the public validator entry point.
- Risk of change: Low to medium.
- Confidence: high

- ID: TEST-02
- Severity: P2
- Category: Skipped gates / ambiguous pass wording
- Subsystem: Release readiness verification script
- File: scripts/verify-release-readiness.sh; docs/testing.md
- Line range or symbol: manual gate output lines 66-70; automated gates lines 179-189; final verdict lines 224-226; docs lines 153-182
- Evidence: The script runs automated source checks, echoes manual hardware/signing gates, then emits source-gate-verdict: pass, product-runtime-verdict: partial, and VERDICT: PARTIAL. Manual gates are visible text, not a structured skipped-gate result.
- Why it matters: The final output is mostly truthful because product runtime remains PARTIAL, but source-gate-verdict: pass can be misread as complete release-readiness pass.
- Runtime/user impact: A human or parser may promote automated-source success while losing the list/count of skipped manual gates.
- Suggested remediation: Rename the line to automated-source-gate-verdict or emit structured manual-gates-skipped fields with stable gate names.
- Verification required: Script output check if available; otherwise run bash scripts/verify-release-readiness.sh after wording changes.
- Suggested test: Assert script output includes stable manual gate names and a skipped/manual verdict whenever final product verdict is PARTIAL.
- Risk of change: Low.
- Confidence: medium

- ID: TEST-03
- Severity: P2
- Category: Missing stress coverage
- Subsystem: Direct P2P AV RX/TX and realtime callbacks
- File: Tests/OpenLolaCoreTests; Sources/OpenLolaCore/Network/P2P; Sources/OpenLolaCore/Audio/Realtime
- Line range or symbol: duplicate-fragment flood, TX loop backlog, IOProc duration
- Evidence: Runtime findings RT-01, RT-04, and RT-09 all identify behavior whose current sampled tests cover normal/synthetic behavior but not stress, boundedness, or timing.
- Why it matters: Runtime safety properties are not proven by ordinary success-path tests.
- Runtime/user impact: Memory growth, loop starvation, or callback overruns may escape CI and appear only in field conditions.
- Suggested remediation: Add boundedness and timing tests before changing runtime behavior.
- Verification required: Focused tests plus broader swift test --no-parallel after fixes.
- Suggested test: Duplicate-fragment flood, one-iteration TX budget fairness, and synthetic callback timing probes.
- Risk of change: Low for tests; medium when they force runtime fixes.
- Confidence: medium

## 12. Structural and Code-Organization Findings

- ID: STRUCT-01
- Severity: P2
- Category: Public validation policy drift
- Subsystem: Report validators and release/evidence contracts
- File: Sources/OpenLolaCore/Benchmarks; Sources/OpenLolaCore/Connectors; Sources/OpenLolaCore/Release; Sources/OpenLolaCore/Timing
- Line range or symbol: repeated validator helpers and report-specific PASS gates
- Evidence: SLOP-02, LC-01, LC-02, LC-03, LC-04, and TEST-01 show related drift: duplicated validation helpers, incomplete PASS guards, and incomplete false-pass registry coverage.
- Why it matters: Open LoLa relies on report validators as evidence boundaries. Policy drift lets similar evidence fail in one report and pass in another.
- Runtime/user impact: Operators and release gates can receive inconsistent verdicts for similar runtime degradation.
- Suggested remediation: Create a minimal validation-policy inventory before adding abstractions. Consolidate only shared policies that are actually identical; document intentional differences.
- Verification required: Every pass-capable report validator has focused false-pass tests and inventory coverage.
- Suggested test: Central report-schema inventory requires explicit false-pass coverage or explicit cannot-pass-by-design rationale for each public PASS-capable validator.
- Risk of change: Medium.
- Confidence: high

## 13. Findings Index

| ID | Severity | Subsystem | Short title |
|---|---|---|---|
| RT-01 | P1 | Direct P2P AV audio RX | Duplicate fragment flood can bypass pending-deadline cap |
| RT-02 | P1 | Direct P2P setup | Initiator accepts mutated session config |
| RT-03 | P1 | P2P shutdown | Nil-session shutdown can abort before accepted session |
| RT-04 | P1 | Direct P2P TX/RX | Audio TX loop has no per-iteration budget |
| RT-05 | P1 | Realtime audio | PASS validation misses RX buffer loss/reorder counters |
| RT-06 | P1 | Direct P2P reports | PASS validation misses drop/loss/underrun counters |
| RT-07 | P1 | Video capture | Default audio-impact metrics can support PASS without provenance |
| RT-08 | P1 | LoLa control | Retry responder reports started while errors are swallowed |
| RT-09 | P2 | CoreAudio I/O | Callback workload lacks timing evidence |
| RT-10 | P2 | CoreAudio cleanup | Cleanup clears retry-relevant handles after failure |
| LC-01 | P1 | External connector sessions | Outer PASS misses runtime/nested evidence failures |
| LC-02 | P1 | E2E benchmark | Measured PASS can use placeholder metrics |
| LC-03 | P1 | Release readiness | PASS can omit requirement kinds |
| LC-04 | P1 | Connector media sink | PASS ignores rejected media count |
| LC-05 | P1 | UltraGrid video RX | Reassembly failure remains non-fail |
| SLOP-01 | P2 | Evidence schemas | MeasurementReport stale compatibility candidate |
| SLOP-02 | P2 | Validators | Duplicated counter/percentile validation drifts |
| SLOP-03 | P2 | UltraGrid scripts | Native/Docker parity helpers duplicate evidence logic |
| SLOP-04 | P2 | Vendor/release | Raw checkout carries release-excluded vendor noise |
| COMPAT-01 | P3 | Release docs | Stale docs/compliance pointers |
| UI-01 | P1 | App state | Live label can mean completed validated evidence |
| UI-02 | P1 | App settings | SSH mode is exposed without required fallback fields |
| UI-03 | P1 | Validation UI | Can I Run can say Ready while validation is disabled |
| UI-04 | P2 | Transport UI | Armed can show while setup is incomplete |
| UI-05 | P2 | Packet Monitor | Unavailable label conflicts with reachable empty state |
| TEST-01 | P2 | Report tests | False-pass registry misses pass-capable validators |
| TEST-02 | P2 | Release scripts | Source-gate pass wording can hide skipped manual gates |
| TEST-03 | P2 | Runtime tests | Stress/timing coverage missing for boundedness findings |
| STRUCT-01 | P2 | Report validators | Public validation policy drift |

## 14. P0 Findings

No P0 finding was confirmed in this partial pass. This is not evidence that no P0 issues exist. Full runtime, hardware, protocol, concurrency, and security coverage is still incomplete.

## 15. P1 Findings

- RT-01 Duplicate fragment flood can bypass pending-deadline cap.
- RT-02 Initiator accepts mutated session config.
- RT-03 Nil-session shutdown can abort before accepted session.
- RT-04 Audio TX loop has no per-iteration budget.
- RT-05 PASS validation misses RX buffer loss/reorder counters.
- RT-06 Direct P2P PASS validation misses drop/loss/underrun counters.
- RT-07 Default video audio-impact metrics can support PASS without measured provenance.
- RT-08 LoLa retry responder reports started while background errors are swallowed.
- LC-01 External connector session PASS misses runtime/nested evidence failures.
- LC-02 E2E benchmark measured PASS can use placeholder metrics.
- LC-03 Release readiness PASS can omit requirement kinds.
- LC-04 Connector media sink PASS ignores rejected media count.
- LC-05 UltraGrid video reassembly failure remains non-fail.
- UI-01 Live label can mean completed validated evidence.
- UI-02 SSH mode is exposed without required fallback fields.
- UI-03 Can I Run can say Ready while validation is disabled.

## 16. P2 Findings

- RT-09 CoreAudio callback workload lacks timing evidence.
- RT-10 CoreAudio cleanup clears retry-relevant handles after failure.
- SLOP-01 MeasurementReport stale compatibility candidate.
- SLOP-02 Duplicated counter/percentile validation drifts.
- SLOP-03 Native/Docker UltraGrid parity helpers duplicate evidence logic.
- SLOP-04 Raw checkout carries release-excluded vendor noise.
- UI-04 Armed can show while setup is incomplete.
- UI-05 Packet monitor unavailable label conflicts with reachable empty state.
- TEST-01 False-pass registry misses pass-capable validators.
- TEST-02 Source-gate pass wording can hide skipped manual gates.
- TEST-03 Stress/timing coverage missing for boundedness findings.
- STRUCT-01 Public validation policy drift.

## 17. P3 Findings

- COMPAT-01 Stale docs/compliance pointers in release notice surfaces.

## 18. Findings by Subsystem

| Subsystem | Findings |
|---|---|
| Realtime audio and CoreAudio I/O | RT-05, RT-09, RT-10, TEST-03 |
| UDP / Direct P2P AV | RT-01, RT-02, RT-03, RT-04, RT-06, TEST-03 |
| Video capture and video RX | RT-07, LC-05 |
| Control messages and state machines | RT-02, RT-03, RT-08 |
| Error handling and cleanup | RT-08, RT-10 |
| External connectors | LC-01, LC-04, LC-05, SLOP-03 |
| Release/evidence validators | LC-02, LC-03, TEST-01, TEST-02, STRUCT-01 |
| UI/app shell | UI-01, UI-02, UI-03, UI-04, UI-05 |
| Slop/dead-code/dedup/vendor | SLOP-01, SLOP-02, SLOP-03, SLOP-04, COMPAT-01 |

## 19. Prioritized Remediation Roadmap

1. Fix false-success validators first: RT-05, RT-06, LC-01, LC-02, LC-03, LC-04, TEST-01. These are trust-boundary issues where reports can overclaim PASS.
2. Fix Direct P2P setup/lifecycle safety: RT-02, RT-03. These can produce invalid state transitions and wrong media endpoints.
3. Fix runtime boundedness/fairness: RT-01, RT-04, TEST-03. These affect live RX/TX stability under malformed packets or backlog.
4. Fix UI truthfulness: UI-01, UI-02, UI-03, UI-04, UI-05. Operator labels and controls must not overstate live, ready, armed, or available states.
5. Add measurement before optimizing callback paths: RT-09, then evaluate whether copy/clear paths need runtime changes.
6. Improve cleanup observability/retry semantics: RT-10.
7. Classify cleanup candidates only after proof: SLOP-01, SLOP-02, SLOP-03, SLOP-04, COMPAT-01.

## 20. Suggested Future Implementation Slices

Slice 1: Report PASS validator hardening.
- Scope: RT-05, RT-06, LC-01, LC-03, LC-04.
- Files likely involved: focused validators and their tests only.
- Definition of done: Each nonzero degradation/missing evidence/nested failure case fails validation through public validator entry points.
- Verification: focused swift test filters, then broader relevant report-schema tests.

Slice 2: E2E benchmark evidence provenance.
- Scope: LC-02 and related synthetic placeholder metrics.
- Definition of done: Measured/PASS E2E output requires measured impairment/recovery/network evidence or remains PARTIAL.
- Verification: E2E benchmark report tests and synthetic smoke tests.

Slice 3: Direct P2P handshake/shutdown hardening.
- Scope: RT-02 and RT-03.
- Definition of done: Initiator rejects mutated accept configs; remote nil shutdown cannot abort unbound sessions.
- Verification: focused PeerSessionRunner/state-machine tests.

Slice 4: Direct P2P AV loop boundedness.
- Scope: RT-01 and RT-04.
- Definition of done: duplicate fragment storage is bounded; TX loop has a per-iteration budget and exposes backlog/defer metrics.
- Verification: duplicate-fragment flood test, TX fairness test, Direct AV RX/TX simulation.

Slice 5: UI evidence wording and settings reachability.
- Scope: UI-01 through UI-05.
- Definition of done: Live, Ready, Armed, unavailable, and SSH states map to actual current evidence and reachable behavior.
- Verification: app semantic tests and, when practical, app screenshot/manual smoke.

Slice 6: Cleanup and callback measurement.
- Scope: RT-09 and RT-10.
- Definition of done: callback timing evidence exists before optimization; cleanup failures retain retry/diagnostic state or document/report unretryable state.
- Verification: timing probes and cleanup failure injection.

Slice 7: Slop/deprecation proof inventory.
- Scope: SLOP-01 through SLOP-04 and COMPAT-01.
- Definition of done: each cleanup candidate has usage proof, replacement proof, and release-boundary proof before deletion/refactor.
- Verification: rg inventory, release hygiene, docs verification, shellcheck where scripts change.

## 21. Verification Strategy

For audit-only plan changes:
- bash scripts/verify-docs.sh, if current dirty tree allows it.
- git diff --check -- plan.md.
- git status --short plan.md to confirm only the allowed file was created/modified by this pass.

For future source slices:
- Start with the narrowest focused Swift test filter named in each finding.
- Use the public report validator entry point for false-pass tests, not private helper-only tests.
- After focused fixes, run broader relevant groups: report schema/fixture tests, Direct P2P tests, realtime audio tests, UI semantic tests, and then swift test --no-parallel when risk warrants it.
- For docs/script slices, run bash scripts/verify-docs.sh, shellcheck -x on touched scripts, and release-readiness scripts when relevant.
- For runtime-critical changes, add stress/boundedness tests before changing behavior, then run runtime simulations. Do not call field readiness PASS without physical peer/hardware evidence.

## 22. Remaining Uncertainty

- This pass did not execute tests, builds, app launch, SwiftUI screenshots, hardware checks, network sessions, or release export.
- Findings are against the current dirty worktree, not a clean checkout.
- Some line numbers may shift if the dirty worktree changes before implementation.
- Full coverage of linux_connector, vendored C sources, release scripts, archive/private evidence, CLI commands, and all report validators is still open.
- P0 absence is not proven.
- Some P1/P2 severity calls, especially LC-05 and RT-08, need confirmation against intended product policy before implementation.
- Cleanup/deletion candidates are not approved for deletion. They require explicit usage evidence and separate implementation scope.

## 23. Explicit Non-Goals

- No production code changes.
- No test changes.
- No refactors.
- No deletions.
- No formatting-only changes.
- No generated-file updates.
- No dependency changes.
- No protocol, report schema, storage, or public API migration in this audit pass.
- No claim that Open LoLa is field-ready.
- No claim that this audit is complete.

## 24. Repository Source Coverage Inventory

Source-file accounting definition for this pass: every file currently under Sources is accounted for. This includes first-party Swift/C/config files, app and CLI files, C bridge files, vendored Opus files, JPEG XS reference files, upstream build/test/docs/training artifacts, and .DS_Store files physically present under Sources.

Inventory counts from direct filesystem inspection:
- Total files under Sources: 1188.
- First-party/non-vendored files under Sources: 376.
- Vendored Opus files under Sources/opus-1.5.2: 714.
- JPEG XS reference files under Sources/xs_ref_sw_ed2: 98.

Inspection legend:
- fully inspected: complete semantic inspection in this pass. No file is marked fully inspected in this appendix because this pass prioritized full accounting over complete semantic review.
- partially inspected: file content was read for metadata, imports/includes, declarations, package role, and selected evidence, but not fully audited.
- not inspected: file is listed and accounted for, but semantic inspection was intentionally deferred; reason is included in notes or inherited group text.

The classification below uses direct content signals, imports/includes, package membership, and target location together. It does not claim runtime role from filename alone. Where direct callers were not enumerated, the entrypoint column says so.

### First-Party Source Inventory

| Path | Language/type | Approximate purpose | Runtime relevance | Classification | Kind | Main functions/classes/components | Important imports/dependencies | Immediate callers or likely entrypoints | Used/unused/duplicated/deprecated/generated/unclear | Inspection | Risk | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Sources/.DS_Store | macOS metadata | macOS Finder metadata under source tree; no runtime purpose | low | GENERATED | generated | none found | none found | none known | generated | not inspected | low | generated metadata; listed for accounting, not audited |
| Sources/COpenLolaAtomics/.DS_Store | macOS metadata | macOS Finder metadata under source tree; no runtime purpose | low | GENERATED | generated | none found | none found | none known | generated | not inspected | low | generated metadata; listed for accounting, not audited |
| Sources/COpenLolaAtomics/OpenLolaAtomics.c | C | symbols: open_lola_atomic_u64_init, open_lola_atomic_u64_load, open_lola_atomic_u64_store, open_lola_atomic_u64_fetch_add, open_lola_atomic_u64_compar | medium | CORE_RUNTIME | production | open_lola_atomic_u64_init, open_lola_atomic_u64_load, open_lola_atomic_u64_store, open_lola_atomic_u64_fetch_add, open_lola_atomic_u64_compare_exchang | OpenLolaAtomics.h, <stdatomic.h> | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/COpenLolaAtomics/include/OpenLolaAtomics.h | C header | symbols: open_lola_atomic_u64_init, open_lola_atomic_u64_load, open_lola_atomic_u64_store, open_lola_atomic_u64_fetch_add, open_lola_atomic_u64_compar | high | CORE_RUNTIME,NETWORKING | production | open_lola_atomic_u64_init, open_lola_atomic_u64_load, open_lola_atomic_u64_store, open_lola_atomic_u64_fetch_add, open_lola_atomic_u64_compare_exchang | <stdbool.h>, <stdint.h> | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaContracts/MeasurementMethodology.swift | Swift | symbols: MeasurementMethodology | medium | CORE_RUNTIME | production | MeasurementMethodology | none found | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaContracts/MeasurementVerdict.swift | Swift | symbols: MeasurementVerdict | medium | CORE_RUNTIME | production | MeasurementVerdict | none found | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaContracts/PrettyJSONCodable.swift | Swift | symbols: PrettyJSONCodable | high | RX | production | PrettyJSONCodable | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaContracts/ReportRunMode.swift | Swift | symbols: ReportRunMode | medium | CORE_RUNTIME | production | ReportRunMode | none found | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaContracts/RxBufferProfile.swift | Swift | symbols: RxBufferProfile | medium | CORE_RUNTIME | production | RxBufferProfile | none found | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/.DS_Store | macOS metadata | macOS Finder metadata under source tree; no runtime purpose | low | GENERATED | generated | none found | none found | none known | generated | not inspected | low | generated metadata; listed for accounting, not audited |
| Sources/OpenLolaCore/Audio/Codecs/OpusCELTLowDelayCodec.swift | Swift | symbols: OpusCELTLowDelayConstants, OpusCELTLowDelayCodecError, OpusCELTLowDelayCodecValidation, OpusCELTLowDelayEncoder, OpusCELTLowDelayDecoder | high | AUDIO,RX | production | OpusCELTLowDelayConstants, OpusCELTLowDelayCodecError, OpusCELTLowDelayCodecValidation, OpusCELTLowDelayEncoder, OpusCELTLowDelayDecoder | COpus, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/CoreAudio/AudioStreamDescription.swift | Swift | symbols: MediaStreamDirection, SessionPayloadType, AudioStreamDescription | high | AUDIO,TX,RX | production | MediaStreamDirection, SessionPayloadType, AudioStreamDescription | none found | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventory.swift | Swift | symbols: AudioValueRangeSnapshot, BufferFrameCandidates, AudioChannelLayoutScope, AudioChannelLayoutSnapshot, CoreAudioDeviceInventory | high | AUDIO,RX | production | AudioValueRangeSnapshot, BufferFrameCandidates, AudioChannelLayoutScope, AudioChannelLayoutSnapshot, CoreAudioDeviceInventory | CoreAudio, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift | Swift | symbols: CoreAudioInventoryReader, coreAudioPropertyAddress, CoreAudioDeviceIdentity, coreAudioDeviceIdentity, fourCharacterCode | high | AUDIO,CONFIG | production | CoreAudioInventoryReader, coreAudioPropertyAddress, CoreAudioDeviceIdentity, coreAudioDeviceIdentity, fourCharacterCode | CoreAudio, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/MADI/MadiChannelCounts.swift | Swift | no top-level symbols found in metadata scan | high | AUDIO | production | none found | none found | none known | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexReport.swift | Swift | symbols: MadiFullDuplexReport, MadiFullDuplexReceiverMixEvidence, MadiFullDuplexSyntheticSmoke, receiverMixEvidence | high | AUDIO,NETWORKING,VIDEO,TX,RX,CONFIG | production | MadiFullDuplexReport, MadiFullDuplexReceiverMixEvidence, MadiFullDuplexSyntheticSmoke, receiverMixEvidence | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexRuntime.swift | Swift | symbols: MadiFullDuplexMetrics, madiFullDuplexRxBufferPolicy, MadiFullDuplexSessionConfiguration, MadiFullDuplexSession | high | AUDIO,RX,CONFIG | production | MadiFullDuplexMetrics, madiFullDuplexRxBufferPolicy, MadiFullDuplexSessionConfiguration, MadiFullDuplexSession | Foundation, OpenLolaContracts | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexSocketRunner.swift | Swift | symbols: MadiFullDuplexSocketRunner | high | AUDIO,NETWORKING,UDP,RX,CONFIG | production | MadiFullDuplexSocketRunner | Darwin, Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexTypes.swift | Swift | symbols: MadiFullDuplexRunMode, MadiFullDuplexCorrectionAction, MadiFullDuplexError, MadiFullDuplexAudioPair, MadiFullDuplexCorrectionPolicy | high | AUDIO | production | MadiFullDuplexRunMode, MadiFullDuplexCorrectionAction, MadiFullDuplexError, MadiFullDuplexAudioPair, MadiFullDuplexCorrectionPolicy | Foundation, OpenLolaContracts | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexValidation.swift | Swift | symbols: MadiFullDuplexValidator | high | AUDIO | production | MadiFullDuplexValidator | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift | Swift | symbols: MadiReceiveEngine | high | AUDIO,NETWORKING,VIDEO,RX,CONFIG | production | MadiReceiveEngine | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/MADI/MadiReceiveBuffers.swift | Swift | symbols: MadiReceiveDeadlineKey, MadiReceivePendingDeadlineSlot, MadiReceivePendingDeadlineSlots, MadiReceivePendingInsertResult, MadiReceiveReadyBloc | high | AUDIO,NETWORKING,VIDEO | production | MadiReceiveDeadlineKey, MadiReceivePendingDeadlineSlot, MadiReceivePendingDeadlineSlots, MadiReceivePendingInsertResult, MadiReceiveReadyBlockStoreRes | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/MADI/MadiReceiveReport.swift | Swift | symbols: MadiReceiveSyntheticMeasurement, MadiReceiveSyntheticReport, MadiReceiveSyntheticSmoke, MadiReceiveValidator | high | AUDIO,NETWORKING,RX,CONFIG | production | MadiReceiveSyntheticMeasurement, MadiReceiveSyntheticReport, MadiReceiveSyntheticSmoke, MadiReceiveValidator | Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/MADI/MadiReceiveTypes.swift | Swift | symbols: MadiReceiveError, MadiReceiveOverrunPolicy, MadiReceiveConfiguration, MadiReceiveBufferLatency, MadiReceivePlayoutBlock | high | AUDIO,RX | production | MadiReceiveError, MadiReceiveOverrunPolicy, MadiReceiveConfiguration, MadiReceiveBufferLatency, MadiReceivePlayoutBlock | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/MADI/MadiTransmit.swift | Swift | symbols: MadiTransmitPacketizationMeasurement, MadiTransmitSyntheticReport, MadiTransmitValidationError, MadiTransmitSyntheticSmoke, MadiTransmitValid | high | AUDIO,TX,CONFIG | production | MadiTransmitPacketizationMeasurement, MadiTransmitSyntheticReport, MadiTransmitValidationError, MadiTransmitSyntheticSmoke, MadiTransmitValidator | Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift | Swift | symbols: RmeMadiDriverMode, RmeMadiDriverEvidence, RmeFastestAudioPathValidationError, RmeFastestAudioPathReport, requireRmeFastestNonEmpty | high | AUDIO,RX,LOCAL_RX | production | RmeMadiDriverMode, RmeMadiDriverEvidence, RmeFastestAudioPathValidationError, RmeFastestAudioPathReport, requireRmeFastestNonEmpty | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/MADI/RmeMatrixMetadata.swift | Swift | symbols: RmeMatrixMetadataProviderKind, RmeMatrixMetadataConfidence, RmeMatrixRouteMetadata, RmeMatrixMetadataValidationError, RmeMatrixMetadataSnapsh | high | AUDIO | production | RmeMatrixMetadataProviderKind, RmeMatrixMetadataConfidence, RmeMatrixRouteMetadata, RmeMatrixMetadataValidationError, RmeMatrixMetadataSnapshot | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/MADI/SyntheticAudioPayload.swift | Swift | symbols: SyntheticAudioPayload | high | AUDIO | production | SyntheticAudioPayload | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift | Swift | symbols: DirectPeerAudioPayloadRing, currentDirectPeerRingThreadID | high | CORE_RUNTIME,AUDIO,VIDEO | production | DirectPeerAudioPayloadRing, currentDirectPeerRingThreadID | COpenLolaAtomics, Foundation | Direct P2P realtime audio graph/AV runner | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift | Swift | symbols: DirectPeerInputCopyResult, DirectPeerReadOnlyAudioBufferLocation, DirectPeerMutableAudioBufferLocation, DirectPeerRealtimeAudioGraph | high | CORE_RUNTIME,AUDIO,VIDEO,CONFIG | production | DirectPeerInputCopyResult, DirectPeerReadOnlyAudioBufferLocation, DirectPeerMutableAudioBufferLocation, DirectPeerRealtimeAudioGraph | CoreAudio, COpenLolaAtomics, Darwin, Foundation, os | Direct P2P realtime audio graph/AV runner | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphCallbacks.swift | Swift | symbols: validateChannelMap, ReadOnlyAudioBufferListPointer, audioByteOffset, throwDirectPeerAudioStatusIfNeeded, nanosecondsFromHostTime | high | AUDIO,VIDEO | production | validateChannelMap, ReadOnlyAudioBufferListPointer, audioByteOffset, throwDirectPeerAudioStatusIfNeeded, nanosecondsFromHostTime | CoreAudio, Foundation | Direct P2P realtime audio graph/AV runner | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphRxBuffering.swift | Swift | symbols: DirectPeerRealtimeAudioGraph | high | AUDIO,NETWORKING,RX,CONFIG | production | DirectPeerRealtimeAudioGraph | Foundation | Direct P2P realtime audio graph/AV runner | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift | Swift | symbols: DirectPeerAudioGraphError, DirectPeerRealtimeAudioGraphCleanupFailure, DirectPeerRealtimeAudioGraphCleanupResult, directPeerRealtimeAudioClea | high | AUDIO,VIDEO,RX,CONFIG | production | DirectPeerAudioGraphError, DirectPeerRealtimeAudioGraphCleanupFailure, DirectPeerRealtimeAudioGraphCleanupResult, directPeerRealtimeAudioCleanupFailur | CoreAudio, Foundation | Direct P2P realtime audio graph/AV runner | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift | Swift | symbols: RealtimeAudioFrameBlock, RealtimeAudioPayloadShape, validatedRealtimeAudioPayloadByteCount, RealtimeAudioRingPushResult, RealtimeAudioBlockRi | high | AUDIO,NETWORKING | production | RealtimeAudioFrameBlock, RealtimeAudioPayloadShape, validatedRealtimeAudioPayloadByteCount, RealtimeAudioRingPushResult, RealtimeAudioBlockRing | Foundation | Direct P2P realtime audio graph/AV runner | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift | Swift | symbols: RealtimeAudioHardwarePath, RealtimeAudioCallbackOwner, RealtimeAudioEngineConfiguration, normalizedRealtimeAudioChannelMap, RealtimeAudioBuff | high | AUDIO,CONFIG | production | RealtimeAudioHardwarePath, RealtimeAudioCallbackOwner, RealtimeAudioEngineConfiguration, normalizedRealtimeAudioChannelMap, RealtimeAudioBufferConfigu | Foundation, OpenLolaContracts | Direct P2P realtime audio graph/AV runner | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineHelpers.swift | Swift | symbols: RealtimeAudioEngineValidator, isRealtimeRmeMadi, isRealtimePlaceholder | high | AUDIO | production | RealtimeAudioEngineValidator, isRealtimeRmeMadi, isRealtimePlaceholder | Foundation | Direct P2P realtime audio graph/AV runner | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineReportValidation.swift | Swift | symbols: RealtimeAudioEngineReport | high | AUDIO,CONFIG | production | RealtimeAudioEngineReport | Foundation | Direct P2P realtime audio graph/AV runner | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineSyntheticSmoke.swift | Swift | symbols: RealtimeAudioEngineSyntheticSmoke | high | AUDIO,NETWORKING,RX,CONFIG | production | RealtimeAudioEngineSyntheticSmoke | Foundation | Direct P2P realtime audio graph/AV runner | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift | Swift | symbols: RealtimeAudioPacketReceiveResult, RealtimeAudioPacketHandoffError, RealtimeAudioPacketHandoff, RealtimeAudioPacketHandoffRuntime, RealtimeAud | high | AUDIO,NETWORKING,RX,LOCAL_RX,CONFIG | production | RealtimeAudioPacketReceiveResult, RealtimeAudioPacketHandoffError, RealtimeAudioPacketHandoff, RealtimeAudioPacketHandoffRuntime, RealtimeAudioPacketH | CoreAudio, Darwin, Foundation | Direct P2P realtime audio graph/AV runner | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift | Swift | symbols: RealtimeAudioCaptureCopyKind, RealtimeAudioCapturePushResult, RealtimeAudioCapturedPayload, RealtimeAudioBufferListReader, RealtimeAudioPaylo | high | AUDIO,VIDEO | production | RealtimeAudioCaptureCopyKind, RealtimeAudioCapturePushResult, RealtimeAudioCapturedPayload, RealtimeAudioBufferListReader, RealtimeAudioPayloadCapture | CoreAudio, Darwin, Foundation | Direct P2P realtime audio graph/AV runner | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Routing/AudioBaselineEvidence.swift | Swift | symbols: SampleRateConversionState, isThunderboltPerformancePath, isClassCompliantDriverMode | high | AUDIO | production | SampleRateConversionState, isThunderboltPerformancePath, isClassCompliantDriverMode | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Routing/AudioLoopbackHelpers.swift | Swift | symbols: AudioLoopbackIOProcResult, makeRunReport, audioLoopbackCompletionNotes, audioLoopbackStatus, requiredString | high | AUDIO,LOCAL_RX,CONFIG | production | AudioLoopbackIOProcResult, makeRunReport, audioLoopbackCompletionNotes, audioLoopbackStatus, requiredString | CoreAudio, Darwin, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift | Swift | symbols: AudioLoopbackRunnerKind, AudioLoopbackRunState, AudioLoopbackPreflight, AudioLoopbackRunValidationError, AudioLoopbackRunValidator | high | CORE_RUNTIME,AUDIO,VIDEO,RX,LOCAL_RX,CONFIG | production | AudioLoopbackRunnerKind, AudioLoopbackRunState, AudioLoopbackPreflight, AudioLoopbackRunValidationError, AudioLoopbackRunValidator | COpenLolaAtomics, CoreAudio, Darwin, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRunConfiguration.swift | Swift | symbols: AudioLoopbackRunConfiguration, AudioLoopbackRunConfigurationError | high | AUDIO,VIDEO,RX,CONFIG | production | AudioLoopbackRunConfiguration, AudioLoopbackRunConfigurationError | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Routing/AudioRoutingAssumptionLedger.swift | Swift | symbols: AudioRoutingAssumptionClassification, AudioRoutingAssumptionStatus, AudioRoutingAssumption, AudioRoutingAssumptionLedger | high | AUDIO,NETWORKING,UDP,VIDEO,CONTROL,TX,RX,LOCAL_RX | production | AudioRoutingAssumptionClassification, AudioRoutingAssumptionStatus, AudioRoutingAssumption, AudioRoutingAssumptionLedger | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Routing/DirectAudioMediaRouter.swift | Swift | symbols: DirectAudioMediaRouterReceiver, DirectAudioMediaRouter, directAudioMediaRouterAudioMode, audioTransportLatencyProfile | high | AUDIO,NETWORKING,RX,CONFIG | production | DirectAudioMediaRouterReceiver, DirectAudioMediaRouter, directAudioMediaRouterAudioMode, audioTransportLatencyProfile | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Audio/Routing/ReceiverMixSnapshot.swift | Swift | symbols: ReceiverMixRoute, ReceiverMixSnapshot, ReceiverMixSnapshotError, PreparedReceiverMixRoute, PreparedReceiverMixSnapshot | high | AUDIO | production | ReceiverMixRoute, ReceiverMixSnapshot, ReceiverMixSnapshotError, PreparedReceiverMixRoute, PreparedReceiverMixSnapshot | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReport.swift | Swift | symbols: E2EBenchmarkEvidenceKind, E2EBenchmarkProfile, E2EBenchmarkImpairmentProfile, E2EBenchmarkValidationError, E2EBenchmarkPeerIdentity | high | AUDIO,NETWORKING,VIDEO | production | E2EBenchmarkEvidenceKind, E2EBenchmarkProfile, E2EBenchmarkImpairmentProfile, E2EBenchmarkValidationError, E2EBenchmarkPeerIdentity | Foundation, OpenLolaContracts | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReportValidation.swift | Swift | symbols: E2EBenchmarkReport, validateE2EAudio, validateE2EVideo, validateE2ENetwork, validateE2EResources | high | AUDIO,NETWORKING,VIDEO | production | E2EBenchmarkReport, validateE2EAudio, validateE2EVideo, validateE2ENetwork, validateE2EResources | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkRunner.swift | Swift | symbols: E2EBenchmarkRunConfiguration, E2EBenchmarkRunConfigurationError, E2EBenchmarkRunner, physicalInputs, e2eVerdict | high | AUDIO,NETWORKING,VIDEO,RX,CONFIG | production | E2EBenchmarkRunConfiguration, E2EBenchmarkRunConfigurationError, E2EBenchmarkRunner, physicalInputs, e2eVerdict | Foundation, OpenLolaContracts | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkSyntheticSmoke.swift | Swift | symbols: E2EBenchmarkSyntheticSmoke, report, profileRuns, profileRun, audioMetrics | high | AUDIO,NETWORKING,P2P,VIDEO,CONTROL,RX,LOCAL_RX | production | E2EBenchmarkSyntheticSmoke, report, profileRuns, profileRun, audioMetrics | Foundation, OpenLolaContracts | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmark.swift | Swift | symbols: LatencyBenchmarkSamplingConfiguration, LatencyBenchmarkSamplingConfigurationError, LatencyBenchmarkSampleSummary, LatencyBenchmark | high | AUDIO,CONFIG | production | LatencyBenchmarkSamplingConfiguration, LatencyBenchmarkSamplingConfigurationError, LatencyBenchmarkSampleSummary, LatencyBenchmark | Darwin, Glibc, Foundation, os | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift | Swift | symbols: LatencyBenchmarkReport, LatencyBenchmarkValidator | high | AUDIO,VIDEO,CONTROL | production | LatencyBenchmarkReport, LatencyBenchmarkValidator | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkSyntheticSmoke.swift | Swift | symbols: LatencyBenchmarkSyntheticSmoke | high | AUDIO,VIDEO,CONTROL,LOCAL_RX | production | LatencyBenchmarkSyntheticSmoke | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkTypes.swift | Swift | symbols: LatencyBenchmarkRunMode, LatencyBenchmarkEvidenceKind, LatencyBenchmarkCategory, LatencyMediaDomain, LatencyComponentCriticality | high | AUDIO,VIDEO,CONTROL | production | LatencyBenchmarkRunMode, LatencyBenchmarkEvidenceKind, LatencyBenchmarkCategory, LatencyMediaDomain, LatencyComponentCriticality | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReport.swift | Swift | symbols: PerformanceCounterSummary, performancePercentile, PerformanceAuditEvidenceKind, PerformanceHotPathSurface, PerformanceWorkerRole | high | CONTROL,RX | production | PerformanceCounterSummary, performancePercentile, PerformanceAuditEvidenceKind, PerformanceHotPathSurface, PerformanceWorkerRole | Foundation, OpenLolaContracts | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReportValidation.swift | Swift | symbols: PerformanceAuditValidator, PerformanceAuditReport | medium | CORE_RUNTIME | production | PerformanceAuditValidator, PerformanceAuditReport | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditSyntheticSmoke.swift | Swift | symbols: PerformanceAuditSyntheticSmoke, syntheticCounters, syntheticPerformanceHardware, syntheticPerformanceProcessContext, syntheticAppleSiliconPol | high | AUDIO,NETWORKING,VIDEO,CONTROL,TX,RX,LOCAL_RX | production | PerformanceAuditSyntheticSmoke, syntheticCounters, syntheticPerformanceHardware, syntheticPerformanceProcessContext, syntheticAppleSiliconPolicy | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/Core/ExternalConnectorExecutablePreflight.swift | Swift | symbols: ExternalConnectorExecutableIdentity, ExternalConnectorExecutablePreflightError, ExternalConnectorExecutablePreflightConfiguration, ExternalCo | high | AUDIO,CONTROL,CONFIG | production | ExternalConnectorExecutableIdentity, ExternalConnectorExecutablePreflightError, ExternalConnectorExecutablePreflightConfiguration, ExternalConnectorEx | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/Core/ExternalConnectorParsingDefaults.swift | Swift | symbols: requiredExecutable, requiredVideoExecutable, parseExternalConnectorKind, parseExternalConnectorMediaMode, parseExternalConnectorSessionRole | high | AUDIO,NETWORKING,UDP,VIDEO,CONTROL,TX,RX,CONFIG | production | requiredExecutable, requiredVideoExecutable, parseExternalConnectorKind, parseExternalConnectorMediaMode, parseExternalConnectorSessionRole | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift | Swift | symbols: ExternalConnectorProcessRunConfiguration, RunningExternalConnectorProcess, startExternalConnectorProcess, runExternalConnectorProcess, waitFo | medium | CONFIG | production | ExternalConnectorProcessRunConfiguration, RunningExternalConnectorProcess, startExternalConnectorProcess, runExternalConnectorProcess, waitForExternal | Darwin, Foundation, os | external connector CLI/runtime entrypoints | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/Core/ExternalConnectorReport.swift | Swift | symbols: ExternalConnectorKind, ExternalConnectorHandshakeKind, ExternalConnectorEvidenceClass, ExternalConnectorMediaProviderReport, ExternalConnecto | high | AUDIO,NETWORKING,UDP,VIDEO,CONTROL,TX,RX,LOCAL_RX,CONFIG | production | ExternalConnectorKind, ExternalConnectorHandshakeKind, ExternalConnectorEvidenceClass, ExternalConnectorMediaProviderReport, ExternalConnectorMediaSin | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift | Swift | symbols: ExternalConnectorSessionError, ExternalConnectorSessionConfiguration, ExternalConnectorMediaProfile, ExternalConnectorLaunchPlan, ExternalCon | high | AUDIO,NETWORKING,UDP,VIDEO,CONTROL,RX,CONFIG | production | ExternalConnectorSessionError, ExternalConnectorSessionConfiguration, ExternalConnectorMediaProfile, ExternalConnectorLaunchPlan, ExternalConnectorAux | Darwin, Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionModels.swift | Swift | symbols: ExternalConnectorSessionRole, ExternalConnectorLaunchKind, ExternalConnectorMediaMode, ExternalConnectorControlTransport, LoLaVideoPayloadKin | high | AUDIO,UDP,VIDEO,TX,RX | production | ExternalConnectorSessionRole, ExternalConnectorLaunchKind, ExternalConnectorMediaMode, ExternalConnectorControlTransport, LoLaVideoPayloadKind | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRunner.swift | Swift | symbols: ExternalConnectorSessionRunner, shouldStartLoLaControlRetryResponder, externalAuxiliaryProcessRuntimeError, externalProcessRuntimeError, appe | high | AUDIO,NETWORKING,UDP,VIDEO,CONTROL,TX,RX,CONFIG | production | ExternalConnectorSessionRunner, shouldStartLoLaControlRetryResponder, externalAuxiliaryProcessRuntimeError, externalProcessRuntimeError, appendExterna | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift | Swift | symbols: runExternalProcess, runExternalProcessGroup, runExternalAuxiliaryProcessGroup, ExternalConnectorProcessInvocation, ExternalConnectorProcessRu | high | NETWORKING | production | runExternalProcess, runExternalProcessGroup, runExternalAuxiliaryProcessGroup, ExternalConnectorProcessInvocation, ExternalConnectorProcessRunning | Darwin, Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionValidation.swift | Swift | symbols: validateExternalConnectorRuntimeInputs, validateJackTripRuntimeInputs, validateUltraGridPayloadType, validateExternalConnectorPort | high | NETWORKING,CONTROL,CONFIG | production | validateExternalConnectorRuntimeInputs, validateJackTripRuntimeInputs, validateUltraGridPayloadType, validateExternalConnectorPort | none found | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/JackTrip/JackTripAdvancedModes.swift | Swift | symbols: JackTripAdvancedModeCodec, JackTripWebRTCSignalingMessage | high | AUDIO,NETWORKING,UDP,VIDEO,RX | production | JackTripAdvancedModeCodec, JackTripWebRTCSignalingMessage | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/JackTrip/JackTripAudioPayloadCodec.swift | Swift | symbols: JackTripAudioPayloadCodec | high | AUDIO,NETWORKING,VIDEO | production | JackTripAudioPayloadCodec | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/JackTrip/JackTripAuxiliaryVideoPlan.swift | Swift | symbols: jackTripAuxiliaryProcesses | high | AUDIO,NETWORKING,UDP,VIDEO,TX,RX,CONFIG | production | jackTripAuxiliaryProcesses | none found | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/JackTrip/JackTripCompatibility.swift | Swift | symbols: JackTripCompatibilityDatagram, JackTripCompatibilityMediaReport, JackTripCompatibilityReceiveResult, JackTripAudioFrameProviding, JackTripSyn | high | AUDIO,NETWORKING,UDP,VIDEO,CONTROL,TX,RX,CONFIG | production | JackTripCompatibilityDatagram, JackTripCompatibilityMediaReport, JackTripCompatibilityReceiveResult, JackTripAudioFrameProviding, JackTripSyntheticAud | Darwin, Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/JackTrip/JackTripCompatibilityPayloads.swift | Swift | symbols: jackTripPayload, jackTripFloat32PCM, uint8 | high | AUDIO,CONFIG | production | jackTripPayload, jackTripFloat32PCM, uint8 | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/JackTrip/JackTripLaunchPlan.swift | Swift | symbols: buildJackTripPlan, jackTripTopologyArguments, validateJackTripTopology, jackTripLaunchPlanPeerRequired, validateJackTripVideoPeer | high | AUDIO,NETWORKING,P2P,UDP,VIDEO,TX,RX,CONFIG | production | buildJackTripPlan, jackTripTopologyArguments, validateJackTripTopology, jackTripLaunchPlanPeerRequired, validateJackTripVideoPeer | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/JackTrip/JackTripPassValidation.swift | Swift | symbols: JackTripCompatibilityMediaReport | medium | CORE_RUNTIME | production | JackTripCompatibilityMediaReport | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/JackTrip/JackTripProtocolModel.swift | Swift | symbols: JackTripCompatibilityError, JackTripSampleRate, JackTripBitResolution, JackTripDefaultHeader, JackTripAudioPacket | high | AUDIO,NETWORKING,UDP,RX | production | JackTripCompatibilityError, JackTripSampleRate, JackTripBitResolution, JackTripDefaultHeader, JackTripAudioPacket | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/JackTrip/JackTripReceiveAnalysis.swift | Swift | symbols: JackTripCompatibilityRunner | high | AUDIO,NETWORKING,UDP | production | JackTripCompatibilityRunner | none found | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/JackTrip/JackTripRunConfiguration.swift | Swift | symbols: JackTripRunConfiguration | high | AUDIO,UDP | production | JackTripRunConfiguration | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/JackTrip/JackTripTCPHandshake.swift | Swift | symbols: JackTripHubTCPHandshakeMode, JackTripTCPHandshakeState, JackTripAuthResponse, JackTripTCPHandshakeReport, JackTripTCPHandshakeCodec | medium | CORE_RUNTIME | production | JackTripHubTCPHandshakeMode, JackTripTCPHandshakeState, JackTripAuthResponse, JackTripTCPHandshakeReport, JackTripTCPHandshakeCodec | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/JackTrip/JackTripTCPHandshakeReportBuilder.swift | Swift | symbols: JackTripCompatibilityRunner | high | NETWORKING,UDP,CONFIG | production | JackTripCompatibilityRunner | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/JackTrip/JackTripTopology.swift | Swift | symbols: JackTripTopologyMode, JackTripTopologyRole, JackTripTopologyState, JackTripHubPatchMode, JackTripTopologyReport | high | NETWORKING,LOCAL_RX | production | JackTripTopologyMode, JackTripTopologyRole, JackTripTopologyState, JackTripHubPatchMode, JackTripTopologyReport | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/JackTrip/JackTripTopologyReportBuilder.swift | Swift | symbols: JackTripCompatibilityRunner | high | NETWORKING,CONFIG | production | JackTripCompatibilityRunner | none found | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaAVFoundationLiveRaw8Source.swift | Swift | symbols: LoLaLiveRaw8VideoSource, LoLaAVFoundationLiveRaw8Source | high | VIDEO,CONFIG | production | LoLaLiveRaw8VideoSource, LoLaAVFoundationLiveRaw8Source | Dispatch, Foundation, CoreMedia, CoreVideo | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaAVFoundationPayloadCollectors.swift | Swift | symbols: LoLaAVFoundationPayloadCollector, LoLaAVFoundationMjpegCollector, LoLaAVFoundationJpegXSCollector, LoLaAVFoundationRaw8Collector, captureTime | high | VIDEO,CONFIG | production | LoLaAVFoundationPayloadCollector, LoLaAVFoundationMjpegCollector, LoLaAVFoundationJpegXSCollector, LoLaAVFoundationRaw8Collector, captureTimeoutSecond | Foundation, Dispatch, CoreGraphics, CoreImage, CoreVideo | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityCaptureReport.swift | Swift | symbols: LoLaCompatibilityCaptureDecoder, LoLaCapturedPacket, DecodedCapturePacket, LoLaPacketCaptureParseResult, LoLaPacketCaptureParser | high | AUDIO,NETWORKING,UDP,VIDEO,CONTROL,RX | production | LoLaCompatibilityCaptureDecoder, LoLaCapturedPacket, DecodedCapturePacket, LoLaPacketCaptureParseResult, LoLaPacketCaptureParser | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityCaptureReportTypes.swift | Swift | symbols: LoLaCompatibilityCaptureFormat, LoLaCompatibilityCaptureStream, LoLaCompatibilityMediaPayloadCandidate, LoLaCompatibilityCapturePacketReport, | high | AUDIO,VIDEO,CONTROL | production | LoLaCompatibilityCaptureFormat, LoLaCompatibilityCaptureStream, LoLaCompatibilityMediaPayloadCandidate, LoLaCompatibilityCapturePacketReport, LoLaComp | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityControlMessage.swift | Swift | symbols: LoLaCompatibilityControlMessage | medium | CORE_RUNTIME | production | LoLaCompatibilityControlMessage | none found | external connector CLI/runtime entrypoints | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityControlSocket.swift | Swift | symbols: shouldBindLoLaTransmitControlPort, bindLoLaTransmitControlPort, externalConnectorUdpBindErrno, isLoLaSameHostLoopback, isLoLaLoopbackHost | high | NETWORKING,CONFIG | production | shouldBindLoLaTransmitControlPort, bindLoLaTransmitControlPort, externalConnectorUdpBindErrno, isLoLaSameHostLoopback, isLoLaLoopbackHost | Darwin | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaCodec.swift | Swift | symbols: LoLaCompatibilityMediaPacketKind, LoLaCompatibilityMediaCodecError, LoLaCompatibilitySerializedMediaBody, LoLaCompatibilityFragmentHeader, Lo | high | AUDIO,VIDEO,RX | production | LoLaCompatibilityMediaPacketKind, LoLaCompatibilityMediaCodecError, LoLaCompatibilitySerializedMediaBody, LoLaCompatibilityFragmentHeader, LoLaCompati | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaEnvelopeValidation.swift | Swift | symbols: LoLaCompatibilityMediaEnvelopeValidation | high | AUDIO,NETWORKING,VIDEO,RX,CONFIG | production | LoLaCompatibilityMediaEnvelopeValidation | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaModel.swift | Swift | symbols: LoLaCompatibilityMediaModel | high | AUDIO,NETWORKING,UDP,VIDEO | production | LoLaCompatibilityMediaModel | none found | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaSession.swift | Swift | symbols: LoLaCompatibilityMediaStream, LoLaCompatibilityMediaSessionRole, LoLaCompatibilityMediaFrame, LoLaCompatibilityMediaSessionReport, LoLaCompat | high | AUDIO,NETWORKING,UDP,VIDEO,TX,RX,CONFIG | production | LoLaCompatibilityMediaStream, LoLaCompatibilityMediaSessionRole, LoLaCompatibilityMediaFrame, LoLaCompatibilityMediaSessionReport, LoLaCompatibilityMe | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaSessionReportFactory.swift | Swift | symbols: makeLoLaMediaSessionReport | high | NETWORKING | production | makeLoLaMediaSessionReport | Foundation, OpenLolaContracts | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityPacketFixture.swift | Swift | symbols: LoLaCompatibilityPacketFixtureRunConfiguration, LoLaCompatibilityPacketFixtureReport, LoLaCompatibilityPacketFixtureRunner, classicLoLaSynthe | high | CORE_RUNTIME,AUDIO,NETWORKING,VIDEO,TX,RX,CONFIG | production | LoLaCompatibilityPacketFixtureRunConfiguration, LoLaCompatibilityPacketFixtureReport, LoLaCompatibilityPacketFixtureRunner, classicLoLaSyntheticPcap,  | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityRawLink.swift | Swift | symbols: LoLaRawLinkTransmitter, LoLaRawLinkReceiver, LoLaMemoryRawLinkTransmitter, LoLaMemoryRawLinkReceiver, LoLaBpfRawLinkTransmitter | high | AUDIO,NETWORKING,VIDEO,TX,RX,CONFIG | production | LoLaRawLinkTransmitter, LoLaRawLinkReceiver, LoLaMemoryRawLinkTransmitter, LoLaMemoryRawLinkReceiver, LoLaBpfRawLinkTransmitter | Darwin, Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMedia.swift | Swift | symbols: LoLaUdpMediaDatagram, LoLaUdpMediaTransmitter, LoLaUdpMediaReceiver, LoLaMemoryUdpMediaTransmitter, LoLaMemoryUdpMediaReceiver | high | AUDIO,NETWORKING,UDP,VIDEO,TX,RX,CONFIG | production | LoLaUdpMediaDatagram, LoLaUdpMediaTransmitter, LoLaUdpMediaReceiver, LoLaMemoryUdpMediaTransmitter, LoLaMemoryUdpMediaReceiver | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaHelpers.swift | Swift | symbols: udpDatagram, syntheticBidirectionalReceiveDatagrams, lolaUdpMediaFrameReadCount, syntheticUdpMediaDatagrams, udpDatagramWireFrame | high | AUDIO,NETWORKING,UDP,VIDEO,TX,RX,CONFIG | production | udpDatagram, syntheticBidirectionalReceiveDatagrams, lolaUdpMediaFrameReadCount, syntheticUdpMediaDatagrams, udpDatagramWireFrame | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaLive.swift | Swift | symbols: shouldUseLoLaLiveSocketTransmitter, enqueueLoLaLiveAudioIfNeeded, loLaLiveAudioSnapshotNote, requireLoLaBidirectionalTransmitReport, LoLaLive | high | AUDIO,NETWORKING,UDP,VIDEO,TX,RX,LOCAL_RX,CONFIG | production | shouldUseLoLaLiveSocketTransmitter, enqueueLoLaLiveAudioIfNeeded, loLaLiveAudioSnapshotNote, requireLoLaBidirectionalTransmitReport, LoLaLiveTransmitA | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaSocket.swift | Swift | symbols: LoLaSocketUdpMediaReceiver, makeLoLaUdpMediaSocket, bindLoLaUdpMediaSocket, receiveLoLaUdpMediaPayload, loLaUdpMediaAddress | high | AUDIO,NETWORKING,UDP,VIDEO,TX,RX | production | LoLaSocketUdpMediaReceiver, makeLoLaUdpMediaSocket, bindLoLaUdpMediaSocket, receiveLoLaUdpMediaPayload, loLaUdpMediaAddress | Darwin, Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityWireFrame.swift | Swift | symbols: LoLaEthernetAddress, LoLaIPv4Address, LoLaCompatibilityWireFrameError, LoLaCompatibilityWireFrame, appendLoLaUInt16BE | high | NETWORKING,UDP,RX | production | LoLaEthernetAddress, LoLaIPv4Address, LoLaCompatibilityWireFrameError, LoLaCompatibilityWireFrame, appendLoLaUInt16BE | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaConnectorLaunchPlan.swift | Swift | symbols: buildLoLaPlan | high | AUDIO,NETWORKING,UDP,VIDEO,CONTROL,TX,RX,CONFIG | production | buildLoLaPlan | none found | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaConnectorRawLinkMediaEvidence.swift | Swift | symbols: LoLaConnectorRawLinkMediaEvidence | high | NETWORKING,TX,RX,CONFIG | production | LoLaConnectorRawLinkMediaEvidence | none found | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeOutgoing.swift | Swift | symbols: LoLaExchangeState, LoLaOutgoingControlTransport, DarwinLoLaOutgoingControlTransport, sendLoLaControlAttempt, sendLoLaQuickConnectFallback | high | NETWORKING,TX,RX,CONFIG | production | LoLaExchangeState, LoLaOutgoingControlTransport, DarwinLoLaOutgoingControlTransport, sendLoLaControlAttempt, sendLoLaQuickConnectFallback | Darwin | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeRuntime.swift | Swift | symbols: LoLaControlRetryResponderReport, runLoLaControlExchange, LoLaControlExchangeAttempt, runLoLaControlExchangeAttempt, receiveLoLaControlAttempt | high | NETWORKING,UDP,TX,RX,CONFIG | production | LoLaControlRetryResponderReport, runLoLaControlExchange, LoLaControlExchangeAttempt, runLoLaControlExchangeAttempt, receiveLoLaControlAttempt | Darwin, Dispatch, Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaControlHandshakeValidation.swift | Swift | symbols: lolaExpectedStatusAckFields, lolaExpectedQuickConnectFields, lolaOutgoingHandshakeFailure, lolaIncomingHandshakeFailure, lolaHandshakeFieldMa | high | NETWORKING,CONFIG | production | lolaExpectedStatusAckFields, lolaExpectedQuickConnectFields, lolaOutgoingHandshakeFailure, lolaIncomingHandshakeFailure, lolaHandshakeFieldMatches | Darwin | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaControlNetworkPreflight.swift | Swift | symbols: lolaControlNetworkPreflightNote, appendLoLaControlNetworkPreflightNote, localIPv4Addresses, lolaSockaddrCarriesIPv4, isLoLaLoopbackAddress | high | NETWORKING,CONTROL,CONFIG | production | lolaControlNetworkPreflightNote, appendLoLaControlNetworkPreflightNote, localIPv4Addresses, lolaSockaddrCarriesIPv4, isLoLaLoopbackAddress | Darwin | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaCoreAudioLiveBridge.swift | Swift | symbols: LoLaCoreAudioLiveBridgeError, LoLaCoreAudioLiveSnapshot, LoLaCoreAudioLiveBridge, stableUnique, LoLaLinearPCMResampler | high | AUDIO,CONFIG | production | LoLaCoreAudioLiveBridgeError, LoLaCoreAudioLiveSnapshot, LoLaCoreAudioLiveBridge, stableUnique, LoLaLinearPCMResampler | CoreAudio, Foundation, os | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaSocketUdpMediaTransmitter.swift | Swift | symbols: LoLaSocketUdpMediaTransmitter, LoLaUdpMediaSocketCacheKey, sendLoLaUdpMediaPayload, loLaUdpMediaSleepUntil, retryLoLaUdpMediaSend | high | NETWORKING,UDP,VIDEO,TX | production | LoLaSocketUdpMediaTransmitter, LoLaUdpMediaSocketCacheKey, sendLoLaUdpMediaPayload, loLaUdpMediaSleepUntil, retryLoLaUdpMediaSend | Darwin, Dispatch, Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaTcpControlExchangeRuntime.swift | Swift | symbols: runLoLaTcpControlExchangeAttempt, sendLoLaTcpControlAttempt, sendLoLaTcpQuickConnectFallback, receiveLoLaTcpControlAttempt, receiveLoLaTcpCon | high | NETWORKING,TX,RX,CONFIG | production | runLoLaTcpControlExchangeAttempt, sendLoLaTcpControlAttempt, sendLoLaTcpQuickConnectFallback, receiveLoLaTcpControlAttempt, receiveLoLaTcpControlMessa | Darwin | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/LoLa/LoLaVideoPayloadProvider.swift | Swift | symbols: LoLaVideoPayloadError, LoLaVideoPayloadProvider, LoLaAVFoundationRaw8PayloadProvider, LoLaAVFoundationMjpegPayloadProvider, LoLaAVFoundationJ | high | VIDEO,CONFIG | production | LoLaVideoPayloadError, LoLaVideoPayloadProvider, LoLaAVFoundationRaw8PayloadProvider, LoLaAVFoundationMjpegPayloadProvider, LoLaAVFoundationJpegXSPayl | Foundation, Dispatch, CoreGraphics, CoreImage, CoreVideo | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorConnectionPlan.swift | Swift | symbols: ExternalConnectorConnectionSide, ExternalConnectorConnectionDirection, ExternalConnectorConnectionEndpoint, ExternalConnectorConnectionPlanCo | high | AUDIO,NETWORKING,P2P,VIDEO,CONTROL,TX,RX,CONFIG | production | ExternalConnectorConnectionSide, ExternalConnectorConnectionDirection, ExternalConnectorConnectionEndpoint, ExternalConnectorConnectionPlanConfigurati | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpEndpointRun.swift | Swift | symbols: ExternalConnectorNmpEndpointRunConfiguration, ExternalConnectorNmpEndpointRunResult, ExternalConnectorNmpEndpointRunReport, ExternalConnector | high | VIDEO,CONFIG | production | ExternalConnectorNmpEndpointRunConfiguration, ExternalConnectorNmpEndpointRunResult, ExternalConnectorNmpEndpointRunReport, ExternalConnectorNmpEndpoi | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpPlan.swift | Swift | symbols: ExternalConnectorNmpPlanConfiguration, ExternalConnectorNmpPlanReport, ExternalConnectorNmpPlanRunner, validateNmpRawLinkConfiguration, execu | high | AUDIO,UDP,VIDEO,CONTROL,CONFIG | production | ExternalConnectorNmpPlanConfiguration, ExternalConnectorNmpPlanReport, ExternalConnectorNmpPlanRunner, validateNmpRawLinkConfiguration, executable | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpPreflight.swift | Swift | symbols: ExternalConnectorNmpPreflightConfiguration, ExternalConnectorNmpPreflightResult, ExternalConnectorNmpPreflightReport, ExternalConnectorNmpPre | medium | CONFIG | production | ExternalConnectorNmpPreflightConfiguration, ExternalConnectorNmpPreflightResult, ExternalConnectorNmpPreflightReport, ExternalConnectorNmpPreflightRun | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpWorkflow.swift | Swift | symbols: ExternalConnectorNmpWorkflowConfiguration, ExternalConnectorNmpWorkflowReport, ExternalConnectorNmpWorkflowRunner, nmpWorkflowPlanArguments,  | high | AUDIO,VIDEO,CONTROL,CONFIG | production | ExternalConnectorNmpWorkflowConfiguration, ExternalConnectorNmpWorkflowReport, ExternalConnectorNmpWorkflowRunner, nmpWorkflowPlanArguments, aggregate | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridAudioPayloadCodec.swift | Swift | symbols: UltraGridAudioPayloadHeader, UltraGridAudioPayload | high | AUDIO,RX | production | UltraGridAudioPayloadHeader, UltraGridAudioPayload | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibility.swift | Swift | symbols: UltraGridCompatibilityError, ultraGridRawVideoFourCC, UltraGridCompatibilityDatagram, UltraGridTopologyState, UltraGridTopologyReport | high | AUDIO,NETWORKING,P2P,UDP,VIDEO,CONTROL,RX,CONFIG | production | UltraGridCompatibilityError, ultraGridRawVideoFourCC, UltraGridCompatibilityDatagram, UltraGridTopologyState, UltraGridTopologyReport | Darwin, Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibilityRunner.swift | Swift | symbols: UltraGridCompatibilityRunner | high | AUDIO,NETWORKING,UDP,VIDEO,CONTROL,TX,RX,CONFIG | production | UltraGridCompatibilityRunner | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridControl.swift | Swift | symbols: UltraGridControlCommand, UltraGridControlVolumeDirection, UltraGridControlState, UltraGridControlReport, UltraGridControlCodec | high | NETWORKING,CONTROL,TX,RX,CONFIG | production | UltraGridControlCommand, UltraGridControlVolumeDirection, UltraGridControlState, UltraGridControlReport, UltraGridControlCodec | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridEncryption.swift | Swift | symbols: UltraGridEncryptionConfiguration, UltraGridOpenSSLCipherMode, UltraGridCryptoPayloadHeader, UltraGridOpenSSLEncryption | medium | CONFIG | production | UltraGridEncryptionConfiguration, UltraGridOpenSSLCipherMode, UltraGridCryptoPayloadHeader, UltraGridOpenSSLEncryption | CryptoKit, Foundation, Security | external connector CLI/runtime entrypoints | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridFEC.swift | Swift | symbols: UltraGridFECPayloadHeader, UltraGridFECPayload, UltraGridFECRecovery | high | NETWORKING,RX | production | UltraGridFECPayloadHeader, UltraGridFECPayload, UltraGridFECRecovery | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridLaunchPlan.swift | Swift | symbols: UltraGridDeviceDefaults, buildUltraGridPlan, ultraGridPeerRequired, validateUltraGridTopology, validateUltraGridVideoDefaults | high | AUDIO,NETWORKING,UDP,VIDEO,CONTROL,CONFIG | production | UltraGridDeviceDefaults, buildUltraGridPlan, ultraGridPeerRequired, validateUltraGridTopology, validateUltraGridVideoDefaults | none found | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridMediaIO.swift | Swift | symbols: UltraGridCompatibilityMediaTransmitting, UltraGridCompatibilityMediaReceiving, UltraGridMemoryMediaTransmitter, UltraGridMemoryMediaReceiver, | high | AUDIO,NETWORKING,UDP,VIDEO,TX,RX | production | UltraGridCompatibilityMediaTransmitting, UltraGridCompatibilityMediaReceiving, UltraGridMemoryMediaTransmitter, UltraGridMemoryMediaReceiver, UltraGri | Darwin, Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridMediaProvider.swift | Swift | symbols: UltraGridMediaProviding, UltraGridSyntheticMediaProvider, UltraGridMediaProviderLifecycle, UltraGridSessionMediaProvider | high | AUDIO,VIDEO,CONFIG | production | UltraGridMediaProviding, UltraGridSyntheticMediaProvider, UltraGridMediaProviderLifecycle, UltraGridSessionMediaProvider | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridProtocolModel.swift | Swift | symbols: UltraGridCompatibilityPayloadType, UltraGridRTPPayloadClassification, UltraGridNegotiatedCodec, UltraGridRTPPayloadRegistry, UltraGridPCMAudi | high | AUDIO,NETWORKING,VIDEO | production | UltraGridCompatibilityPayloadType, UltraGridRTPPayloadClassification, UltraGridNegotiatedCodec, UltraGridRTPPayloadRegistry, UltraGridPCMAudioTag | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridRTPPacketCodec.swift | Swift | symbols: UltraGridRTPPacketCodec | high | AUDIO,NETWORKING,VIDEO,RX,CONFIG | production | UltraGridRTPPacketCodec | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridTopology.swift | Swift | symbols: UltraGridTopologyMode, UltraGridTopologyRole | high | NETWORKING | production | UltraGridTopologyMode, UltraGridTopologyRole | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridVideoPayloadCodec.swift | Swift | symbols: UltraGridFourCC, UltraGridVideoPayloadHeader, UltraGridVideoRawFragmentPayload, UltraGridRTPJPEGHeader, UltraGridRTPJPEGPayload | high | VIDEO,RX | production | UltraGridFourCC, UltraGridVideoPayloadHeader, UltraGridVideoRawFragmentPayload, UltraGridRTPJPEGHeader, UltraGridRTPJPEGPayload | Foundation | external connector CLI/runtime entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift | Swift | symbols: AtemReadOnlyHealth, AtemReadOnlyControlValidationError, AtemReadOnlyControlReport, AtemReadOnlyProbeConfiguration, AtemReadOnlyProbeConfigura | high | AUDIO,NETWORKING,CONTROL,CONFIG | production | AtemReadOnlyHealth, AtemReadOnlyControlValidationError, AtemReadOnlyControlReport, AtemReadOnlyProbeConfiguration, AtemReadOnlyProbeConfigurationError | Foundation, Darwin | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Control/AtemReadOnlyControlValidation.swift | Swift | symbols: AtemReadOnlyControlReport | high | CONTROL | production | AtemReadOnlyControlReport | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Control/LightingFixtureGate.swift | Swift | symbols: LightingControlProtocol, LightingStandardsReviewStatus, LightingInteropTarget, LightingCueTransport, LightingCueWorkflowEvidence | high | CONTROL | production | LightingControlProtocol, LightingStandardsReviewStatus, LightingInteropTarget, LightingCueTransport, LightingCueWorkflowEvidence | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Control/LightingFixtureGateHelpers.swift | Swift | symbols: requireLightingNonEmpty, requireLightingPassWorkflowText, requireLightingList, requireLightingPositive, requireLightingNonNegative | high | CONTROL,CONFIG | production | requireLightingNonEmpty, requireLightingPassWorkflowText, requireLightingList, requireLightingPositive, requireLightingNonNegative | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Control/LightingFixtureGateReport.swift | Swift | symbols: LightingFixtureGateReport | high | CONTROL,RX | production | LightingFixtureGateReport | Foundation, OpenLolaContracts | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Control/LightingFixtureGateRun.swift | Swift | symbols: LightingGateRunConfiguration, LightingGateRunConfigurationError, LightingGateRunError, LightingGateRunner, LightingCaptureTool | high | AUDIO,NETWORKING,CONTROL,CONFIG | production | LightingGateRunConfiguration, LightingGateRunConfigurationError, LightingGateRunError, LightingGateRunner, LightingCaptureTool | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Control/OscCueHelpers.swift | Swift | symbols: oscString, readOscString, boundUdpPort, sendUdpPacket, receiveUdpOscMessage | high | NETWORKING,CONTROL,CONFIG | production | oscString, readOscString, boundUdpPort, sendUdpPacket, receiveUdpOscMessage | Darwin, Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Control/OscCueProbe.swift | Swift | symbols: OscCuePeerKind, OscCueMessage, OscCuePacketError, OscCueError, OscCuePeerReport | high | AUDIO,NETWORKING,UDP,CONTROL,CONFIG | production | OscCuePeerKind, OscCueMessage, OscCuePacketError, OscCueError, OscCuePeerReport | Darwin, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Control/OscCueRunners.swift | Swift | symbols: OscCueExternalRunner, OscCueUdpLoopbackRunner, OscCueSyntheticLoopback, makeOscCueReport | high | NETWORKING,UDP,CONTROL,LOCAL_RX,CONFIG | production | OscCueExternalRunner, OscCueUdpLoopbackRunner, OscCueSyntheticLoopback, makeOscCueReport | Darwin, Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Core/CapabilitySummary.swift | Swift | symbols: DevelopmentStage, CapabilitySummary | high | NETWORKING,CONTROL | production | DevelopmentStage, CapabilitySummary | none found | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Core/DebugTrace.swift | Swift | symbols: DebugTraceEvent, DebugTraceFieldPolicy, DebugTrace, DebugTracedRunFailure, sanitized | high | CORE_RUNTIME,NETWORKING | production | DebugTraceEvent, DebugTraceFieldPolicy, DebugTrace, DebugTracedRunFailure, sanitized | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift | Swift | symbols: KeyValueArgumentParser, KeyValueArgumentError | medium | CONFIG | production | KeyValueArgumentParser, KeyValueArgumentError | none found | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Core/OpenLolaCLI.swift | Swift | symbols: OpenLolaCLI | high | AUDIO,NETWORKING,VIDEO | production | OpenLolaCLI | none found | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Core/OpenLolaContractsAliases.swift | Swift | no top-level symbols found in metadata scan | medium | CORE_RUNTIME | production | none found | OpenLolaContracts | none known | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Core/PeerIdentity.swift | Swift | symbols: PeerIdentity, SessionValidationError, SessionValidation | high | NETWORKING | production | PeerIdentity, SessionValidationError, SessionValidation | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Core/ValidationPrimitives.swift | Swift | symbols: ValidationEmptyFieldError, ValidationEmptyListError, ValidationMalformedFieldError, ValidationNonPositiveFieldError, ValidationNegativeFieldE | medium | CORE_RUNTIME | production | ValidationEmptyFieldError, ValidationEmptyListError, ValidationMalformedFieldError, ValidationNonPositiveFieldError, ValidationNegativeFieldError | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Evidence/HardwareValidationReport.swift | Swift | symbols: HardwareValidationLane, HardwareValidationHardwareIdentity, HardwareValidationEvidence, HardwareValidationRouteEvidence, HardwareValidationFi | high | AUDIO,VIDEO,CONTROL | production | HardwareValidationLane, HardwareValidationHardwareIdentity, HardwareValidationEvidence, HardwareValidationRouteEvidence, HardwareValidationFieldRunEvi | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Evidence/HardwareValidationRun.swift | Swift | symbols: HardwareValidationSyntheticSmoke, HardwareValidationRunConfiguration, HardwareValidationRunConfigurationError, HardwareValidationRunner, hard | high | AUDIO,NETWORKING,VIDEO,CONTROL,RX,CONFIG | production | HardwareValidationSyntheticSmoke, HardwareValidationRunConfiguration, HardwareValidationRunConfigurationError, HardwareValidationRunner, hardwareValid | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Evidence/MeasurementReport.swift | Swift | symbols: MeasurementReportKind, HardwareIdentity, RouteIdentity, AudioMode, TimingMetrics | high | NETWORKING,VIDEO,CONTROL,RX | production | MeasurementReportKind, HardwareIdentity, RouteIdentity, AudioMode, TimingMetrics | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Evidence/ReferenceRigHelpers.swift | Swift | symbols: ReferenceRigValidator, validateNonEmptyStrings, validatePositiveIntegers, requireReferenceRigDscpRange, isReferenceRigPlaceholder | medium | CORE_RUNTIME | production | ReferenceRigValidator, validateNonEmptyStrings, validatePositiveIntegers, requireReferenceRigDscpRange, isReferenceRigPlaceholder | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Evidence/ReferenceRigReport.swift | Swift | symbols: ReferenceNetworkTopology, ReferenceSampleRateDispositionState, ReferenceMacPowerSettings, ReferenceMacProfile, ReferenceBufferFrameRange | medium | CORE_RUNTIME | production | ReferenceNetworkTopology, ReferenceSampleRateDispositionState, ReferenceMacPowerSettings, ReferenceMacProfile, ReferenceBufferFrameRange | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Evidence/ReferenceRigReportValidation.swift | Swift | symbols: ReferenceRigStableBufferTargets, ReferenceRigReport | high | AUDIO,VIDEO | production | ReferenceRigStableBufferTargets, ReferenceRigReport | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift | Swift | symbols: ReportEvidenceClass, ReportSchemaInventoryEntry, ReportSchemaInventorySummary, ReportSchemaInventoryReport, ReportSchemaInventory | high | AUDIO,NETWORKING,P2P,UDP,VIDEO,CONTROL,TX,RX,LOCAL_RX,UI | production | ReportEvidenceClass, ReportSchemaInventoryEntry, ReportSchemaInventorySummary, ReportSchemaInventoryReport, ReportSchemaInventory | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift | Swift | symbols: ReportValidatingArtifact, ReportValidatorConsoleOutput, ReportValidatorSurface | high | RX | production | ReportValidatingArtifact, ReportValidatorConsoleOutput, ReportValidatorSurface | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Evidence/VerdictValidationPolicy.swift | Swift | symbols: InvalidPassValidationRule, InvalidPassValidationDescriptor, VerdictForbidCondition, VerdictValidationPolicy | high | NETWORKING | production | InvalidPassValidationRule, InvalidPassValidationDescriptor, VerdictForbidCondition, VerdictValidationPolicy | none found | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Integration/IntegratedAvHelpers.swift | Swift | symbols: IntegratedValidationField, validateIntegratedFieldSet, requireIntegratedNonEmpty, requireIntegratedOptionalNonEmpty, requireIntegratedPassPro | high | CONTROL,CONFIG | production | IntegratedValidationField, validateIntegratedFieldSet, requireIntegratedNonEmpty, requireIntegratedOptionalNonEmpty, requireIntegratedPassProofText | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Integration/IntegratedAvReport.swift | Swift | symbols: IntegratedAvMasterClock, IntegratedAvSyncPolicy, HeadlessOwnershipReport, IntegratedAudioMetrics, IntegratedVideoTimestampClock | high | AUDIO,VIDEO | production | IntegratedAvMasterClock, IntegratedAvSyncPolicy, HeadlessOwnershipReport, IntegratedAudioMetrics, IntegratedVideoTimestampClock | Foundation, OpenLolaContracts | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Integration/IntegratedAvReportValidation.swift | Swift | symbols: IntegratedAvReport | high | AUDIO,VIDEO | production | IntegratedAvReport | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Integration/IntegratedAvRun.swift | Swift | symbols: IntegratedAvRunConfiguration, IntegratedAvRunConfigurationError, IntegratedAvRunner, IntegratedHeadlessAvSyntheticSmoke, makeIntegratedAvRepo | high | AUDIO,UDP,VIDEO,CONTROL,RX,LOCAL_RX,CONFIG | production | IntegratedAvRunConfiguration, IntegratedAvRunConfigurationError, IntegratedAvRunner, IntegratedHeadlessAvSyntheticSmoke, makeIntegratedAvReport | Foundation, OpenLolaContracts | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Integration/IntegratedProfileReport.swift | Swift | symbols: IntegratedProfileReport, aggregateIntegratedProfileVerdicts, requireIntegratedProfileNonEmpty, requireIntegratedProfilePassText, requireInteg | high | VIDEO | production | IntegratedProfileReport, aggregateIntegratedProfileVerdicts, requireIntegratedProfileNonEmpty, requireIntegratedProfilePassText, requireIntegratedProf | Foundation, OpenLolaContracts | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Integration/IntegratedProfileRun.swift | Swift | symbols: IntegratedProfileSyntheticSmoke, IntegratedProfileRunConfiguration, IntegratedProfileRunConfigurationError, IntegratedProfileRunner, integrat | high | AUDIO,VIDEO,CONTROL,CONFIG | production | IntegratedProfileSyntheticSmoke, IntegratedProfileRunConfiguration, IntegratedProfileRunConfigurationError, IntegratedProfileRunner, integratedProfile | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Integration/IntegratedProfileRuntimeEvidence.swift | Swift | symbols: IntegratedProfileRuntimeEvidence, integratedProfileReportApplyingRuntimeEvidence, applyProfileOptions, applySubordinateEvidence, applyBenchma | high | AUDIO,VIDEO,CONTROL,CONFIG | production | IntegratedProfileRuntimeEvidence, integratedProfileReportApplyingRuntimeEvidence, applyProfileOptions, applySubordinateEvidence, applyBenchmarkRows | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Integration/IntegratedProfileTypes.swift | Swift | symbols: IntegratedProfileLabel, IntegratedProfileFeature, IntegratedProfileSubordinateLane, IntegratedProfileBenchmarkScenario, IntegratedProfileDegr | high | AUDIO,VIDEO,CONTROL,RX | production | IntegratedProfileLabel, IntegratedProfileFeature, IntegratedProfileSubordinateLane, IntegratedProfileBenchmarkScenario, IntegratedProfileDegradationSt | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/Diagnostics/AoipEvaluationReport.swift | Swift | symbols: AoipMode, AoipUsage, AoipPtpProfile, AoipEndpointProfile, AoipEndpointPair | high | NETWORKING,TX,RX | production | AoipMode, AoipUsage, AoipPtpProfile, AoipEndpointProfile, AoipEndpointPair | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/Diagnostics/NetworkAoipCertification.swift | Swift | symbols: NetworkAoipCertificationValidationError, NetworkAoipCertificationReport, NetworkAoipCertificationSyntheticSmoke, requireNetworkAoipNonEmpty,  | high | NETWORKING,TX,RX | production | NetworkAoipCertificationValidationError, NetworkAoipCertificationReport, NetworkAoipCertificationSyntheticSmoke, requireNetworkAoipNonEmpty, isNetwork | Foundation, OpenLolaContracts | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift | Swift | symbols: NetworkPingResult, NetworkTracerouteHop, NetworkTracerouteResult, NetworkDiagnosticsValidationError, NetworkDiagnosticsPassThresholds | high | AUDIO,NETWORKING,RX,CONFIG | production | NetworkPingResult, NetworkTracerouteHop, NetworkTracerouteResult, NetworkDiagnosticsValidationError, NetworkDiagnosticsPassThresholds | Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift | Swift | symbols: NatFriendlyRouteRole, NatFriendlyCompatibilityMode, NatEndpoint, NatTraversalEvidence, NatFriendlyRouteValidationError | high | NETWORKING,TX,RX,LOCAL_RX,CONFIG | production | NatFriendlyRouteRole, NatFriendlyCompatibilityMode, NatEndpoint, NatTraversalEvidence, NatFriendlyRouteValidationError | Darwin, Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteHelpers.swift | Swift | symbols: parseNatArguments, requiredNatString, requiredNatPositiveInteger, optionalNatPositiveInteger, validateNatPositiveIntegerBound | high | AUDIO,NETWORKING,UDP,VIDEO,TX,RX,LOCAL_RX,CONFIG | production | parseNatArguments, requiredNatString, requiredNatPositiveInteger, optionalNatPositiveInteger, validateNatPositiveIntegerBound | Darwin, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift | Swift | symbols: NatSkippedDatagramCounts, NatRendezvousReport, NatRendezvousRegistration, NatRendezvousRegistrationRequest, NatRendezvousRegistrationResponse | high | NETWORKING,RX | production | NatSkippedDatagramCounts, NatRendezvousReport, NatRendezvousRegistration, NatRendezvousRegistrationRequest, NatRendezvousRegistrationResponse | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift | Swift | symbols: NatRelayClient, NatDirectTraversalResult, NatTraversalKeepaliveMessage, NatDirectTraversalRunner, NatFriendlyRouteRunner | high | AUDIO,NETWORKING,P2P,UDP,TX,RX,LOCAL_RX,CONFIG | production | NatRelayClient, NatDirectTraversalResult, NatTraversalKeepaliveMessage, NatDirectTraversalRunner, NatFriendlyRouteRunner | Darwin, Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift | Swift | symbols: NatFriendlyRouteSyntheticSmoke, NatFriendlyRouteLocalhostSmoke, NatRendezvousLocalhostSmokeResult, NatRendezvousSmokeError, NatSmokeResultBox | high | NETWORKING,UDP,TX,RX,LOCAL_RX,CONFIG | production | NatFriendlyRouteSyntheticSmoke, NatFriendlyRouteLocalhostSmoke, NatRendezvousLocalhostSmokeResult, NatRendezvousSmokeError, NatSmokeResultBox | Darwin, Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/NAT/NatProtocolConstants.swift | Swift | symbols: NatProtocolMagic | high | NETWORKING | production | NatProtocolMagic | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/NAT/NatRendezvousRelayRunners.swift | Swift | symbols: NatRendezvousRunner, NatRendezvousClient, natRendezvousRegistrationResponseIsUsable, natEndpointIsUsable, NatRelayRunner | high | NETWORKING,P2P,UDP,RX,LOCAL_RX,CONFIG | production | NatRendezvousRunner, NatRendezvousClient, natRendezvousRegistrationResponseIsUsable, natEndpointIsUsable, NatRelayRunner | Darwin, Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectP2PLocalhostSmoke.swift | Swift | symbols: DirectP2PLocalhostSmokeResult, DirectP2PLocalhostSmoke | high | AUDIO,NETWORKING,P2P,LOCAL_RX,CONFIG | production | DirectP2PLocalhostSmokeResult, DirectP2PLocalhostSmoke | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerAVFoundationRawFrameSource.swift | Swift | symbols: DirectPeerAVFoundationRawFrameSource, DirectPeerAVFoundationFrameDeliveryGate, AVFoundationConfiguredVideoDevice, AVFoundationDeviceRestorePo | high | NETWORKING,P2P,VIDEO,CONFIG | production | DirectPeerAVFoundationRawFrameSource, DirectPeerAVFoundationFrameDeliveryGate, AVFoundationConfiguredVideoDevice, AVFoundationDeviceRestorePoint, next | Dispatch, Foundation, os, CoreMedia, CoreVideo | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerFNV1A.swift | Swift | symbols: directPeerFNV1A32 | high | NETWORKING,P2P | production | directPeerFNV1A32 | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerManualValidation.swift | Swift | symbols: DirectPeerManualNetworkShape, DirectPeerPortSet, DirectPeerManualEndpointValidator, DirectPeerSessionAVMediaShapeError, DirectPeerSessionAVMe | high | NETWORKING,P2P | production | DirectPeerManualNetworkShape, DirectPeerPortSet, DirectPeerManualEndpointValidator, DirectPeerSessionAVMediaShapeError, DirectPeerSessionAVMediaShape | Darwin, Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerMeshRuntimeReport.swift | Swift | symbols: DirectPeerMeshRuntimeRouteMetrics, DirectPeerMeshRuntimeMetrics, DirectPeerMeshRuntimeError, DirectPeerMeshRuntimeReport, DirectPeerMeshRunti | high | AUDIO,NETWORKING,P2P,UDP,VIDEO,CONTROL,TX,RX,CONFIG | production | DirectPeerMeshRuntimeRouteMetrics, DirectPeerMeshRuntimeMetrics, DirectPeerMeshRuntimeError, DirectPeerMeshRuntimeReport, DirectPeerMeshRuntimeSmoke | Dispatch, Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift | Swift | symbols: DirectPeerMeshRoute, DirectPeerMeshTopologyMetrics, DirectPeerMeshTopologyError, DirectPeerMeshTopologyReport, DirectPeerMeshTopologySmoke | high | NETWORKING,P2P,TX,RX,CONFIG | production | DirectPeerMeshRoute, DirectPeerMeshTopologyMetrics, DirectPeerMeshTopologyError, DirectPeerMeshTopologyReport, DirectPeerMeshTopologySmoke | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerMeshValidation.swift | Swift | symbols: DirectPeerMeshDirectedPair, requireDirectPeerMeshNonEmpty, requireDirectPeerMeshNonNegative, requireDirectPeerMeshMetric | high | NETWORKING,P2P,TX,RX | production | DirectPeerMeshDirectedPair, requireDirectPeerMeshNonEmpty, requireDirectPeerMeshNonNegative, requireDirectPeerMeshMetric | none found | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift | Swift | symbols: directPeerAES67SSRC, runAudioTXLoop, DirectPeerAudioRXDrainResult, DirectPeerAES67RTPHostTimeMapper, DirectPeerOpenLolaRawAudioReassemblyStat | high | AUDIO,NETWORKING,P2P,RX,LOCAL_RX,CONFIG | production | directPeerAES67SSRC, runAudioTXLoop, DirectPeerAudioRXDrainResult, DirectPeerAES67RTPHostTimeMapper, DirectPeerOpenLolaRawAudioReassemblyState | Dispatch, Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVControlService.swift | Swift | symbols: DirectPeerAVControlServiceResult, serviceDirectPeerAVControl | high | NETWORKING,P2P,CONTROL | production | DirectPeerAVControlServiceResult, serviceDirectPeerAVControl | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVMetricsService.swift | Swift | symbols: DirectPeerAVMetricsServiceResult, serviceDirectPeerAVMetrics | high | NETWORKING,P2P | production | DirectPeerAVMetricsServiceResult, serviceDirectPeerAVMetrics | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVReportBuilder.swift | Swift | symbols: buildAVReport, avRuntimeMetadata, avReportNotes, writeAoIPSDPIfNeeded, directPeerReportAES67SSRC | high | AUDIO,NETWORKING,P2P,UDP,VIDEO,CONTROL,RX,CONFIG | production | buildAVReport, avRuntimeMetadata, avReportNotes, writeAoIPSDPIfNeeded, directPeerReportAES67SSRC | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRunTypes.swift | Swift | symbols: DirectPeerSessionMediaMode, DirectPeerSessionAVProfile, DirectPeerSessionPreviewMode, DirectPeerSessionAVRunQualityPolicy, DirectPeerSessionV | high | AUDIO,NETWORKING,P2P,VIDEO,CONFIG | production | DirectPeerSessionMediaMode, DirectPeerSessionAVProfile, DirectPeerSessionPreviewMode, DirectPeerSessionAVRunQualityPolicy, DirectPeerSessionVideoCompr | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRuntimeReport.swift | Swift | symbols: DirectPeerSessionAVRuntimeMetadata, DirectPeerSessionVideoFormatReport, DirectPeerSessionVideoFrameProof, DirectPeerSessionVideoReceiveProofA | high | NETWORKING,P2P,RX | production | DirectPeerSessionAVRuntimeMetadata, DirectPeerSessionVideoFormatReport, DirectPeerSessionVideoFrameProof, DirectPeerSessionVideoReceiveProofArtifact | none found | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift | Swift | symbols: DirectPeerSessionSocketRunner, validateAVConfiguration, validateAcceptedVideoStream, validateAcceptedAudioStream, acceptedVideoFrameRateMatch | high | AUDIO,NETWORKING,P2P,VIDEO,CONTROL,TX,RX,LOCAL_RX,CONFIG | production | DirectPeerSessionSocketRunner, validateAVConfiguration, validateAcceptedVideoStream, validateAcceptedAudioStream, acceptedVideoFrameRateMatchesConfigu | Darwin, CoreAudio, Dispatch, Foundation, os | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVVideoLoops.swift | Swift | symbols: DirectPeerVideoRXDrainResult, DirectPeerAVPlayoutAnchor, directPeerVideoSyncDecision, runVideoRXLoop, DirectPeerVideoReassemblyMetricDelta | high | NETWORKING,P2P,VIDEO,RX | production | DirectPeerVideoRXDrainResult, DirectPeerAVPlayoutAnchor, directPeerVideoSyncDecision, runVideoRXLoop, DirectPeerVideoReassemblyMetricDelta | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVVideoReportSupport.swift | Swift | symbols: DirectPeerSessionAVRuntimeResult, directPeerSessionVideoFrameProof, directPeerVideoPayloadDigest, syntheticAVVideoFormatReport | high | NETWORKING,P2P,VIDEO,RX,CONFIG | production | DirectPeerSessionAVRuntimeResult, directPeerSessionVideoFrameProof, directPeerVideoPayloadDigest, syntheticAVVideoFormatReport | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionControlSocket.swift | Swift | symbols: DirectPeerSessionControlSocket, controlSourceMatches | high | NETWORKING,P2P,UDP,CONTROL,TX,RX | production | DirectPeerSessionControlSocket, controlSourceMatches | Dispatch, Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionEvidence.swift | Swift | symbols: DirectPeerSessionMeasuredEvidenceKind, DirectPeerSessionDSCPClassification, DirectPeerSessionEvidenceArtifact, DirectPeerSessionDSCPEvidence, | high | NETWORKING,P2P | production | DirectPeerSessionMeasuredEvidenceKind, DirectPeerSessionDSCPClassification, DirectPeerSessionEvidenceArtifact, DirectPeerSessionDSCPEvidence, DirectPe | none found | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionProductionAVPreflight.swift | Swift | symbols: DirectPeerSessionProductionAVPreflightReport, DirectPeerSessionProductionAVPreflight, directPeerProductionAVPreflightBlockers, selectedPrefli | high | AUDIO,NETWORKING,P2P,VIDEO,CONFIG | production | DirectPeerSessionProductionAVPreflightReport, DirectPeerSessionProductionAVPreflight, directPeerProductionAVPreflightBlockers, selectedPreflightVideoD | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReceiveProofArtifact.swift | Swift | symbols: DirectPeerSessionReceiveProofEvidenceMetadata, DirectPeerSessionRawVideoReceiveEvidenceArtifact, directPeerSessionReceiveProofDigestPayload,  | high | NETWORKING,P2P,VIDEO,RX,CONFIG | production | DirectPeerSessionReceiveProofEvidenceMetadata, DirectPeerSessionRawVideoReceiveEvidenceArtifact, directPeerSessionReceiveProofDigestPayload, DirectPee | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift | Swift | symbols: DirectPeerSessionReport, requireDirectPeerSessionConfiguration, requireDirectPeerSessionNonEmpty, requireDirectPeerSessionNonNegative, requir | high | NETWORKING,P2P,VIDEO,RX,CONFIG | production | DirectPeerSessionReport, requireDirectPeerSessionConfiguration, requireDirectPeerSessionNonEmpty, requireDirectPeerSessionNonNegative, requireDirectPe | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReportTypes.swift | Swift | symbols: DirectPeerSessionReportMetrics, DirectPeerSessionAVRuntimeMetrics, DirectPeerSessionReportError | high | NETWORKING,P2P | production | DirectPeerSessionReportMetrics, DirectPeerSessionAVRuntimeMetrics, DirectPeerSessionReportError | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerSessionSocketRunner.swift | Swift | symbols: DirectPeerSessionSocketRunnerError, DirectPeerSessionManualRole, directPeerValidatedPacketCount, DirectPeerSessionManualRunConfiguration, Dir | high | AUDIO,NETWORKING,P2P,UDP,CONTROL,TX,CONFIG | production | DirectPeerSessionSocketRunnerError, DirectPeerSessionManualRole, directPeerValidatedPacketCount, DirectPeerSessionManualRunConfiguration, DirectPeerSe | Darwin, Dispatch, Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerLocalRunReport.swift | Swift | symbols: DirectPeerTwoPeerLocalRunError, DirectPeerTwoPeerRunExecutionMode, DirectPeerTwoPeerPreflightSeverity, DirectPeerTwoPeerPreflightCheck, Direc | high | AUDIO,NETWORKING,P2P,VIDEO,CONTROL,RX,LOCAL_RX | production | DirectPeerTwoPeerLocalRunError, DirectPeerTwoPeerRunExecutionMode, DirectPeerTwoPeerPreflightSeverity, DirectPeerTwoPeerPreflightCheck, DirectPeerTwoP | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift | Swift | symbols: DirectPeerTwoPeerRunPlanError, DirectPeerTwoPeerRunPlanPeer, DirectPeerTwoPeerRunPlanConfiguration, directPeerTwoPeerSampleFormat, directPeer | high | AUDIO,NETWORKING,P2P,VIDEO,CONTROL,RX,CONFIG | production | DirectPeerTwoPeerRunPlanError, DirectPeerTwoPeerRunPlanPeer, DirectPeerTwoPeerRunPlanConfiguration, directPeerTwoPeerSampleFormat, directPeerTwoPeerVi | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlanReportTypes.swift | Swift | symbols: DirectPeerTwoPeerRunCommand, DirectPeerTwoPeerRunReportReference, DirectPeerTwoPeerRunPlanReport, DirectPeerTwoPeerPrototypePeerEvidence, Dir | high | NETWORKING,P2P,VIDEO,RX,CONFIG | production | DirectPeerTwoPeerRunCommand, DirectPeerTwoPeerRunReportReference, DirectPeerTwoPeerRunPlanReport, DirectPeerTwoPeerPrototypePeerEvidence, DirectPeerTw | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/EndpointLoopbackReport.swift | Swift | symbols: EndpointLoopbackDevice, EndpointCallbackMetrics, EndpointLoopbackMetrics, EndpointModeResult, SampleRateLoopbackResult | high | NETWORKING,P2P,RX,LOCAL_RX | production | EndpointLoopbackDevice, EndpointCallbackMetrics, EndpointLoopbackMetrics, EndpointModeResult, SampleRateLoopbackResult | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/MacToMacConnectionEstablishment.swift | Swift | symbols: MacToMacConnectionSetupMode, MacToMacConnectionSelectedRoute, MacToMacConnectionEstablishmentValidationError, MacToMacConnectionEstablishment | high | NETWORKING,P2P,UDP,RX,CONFIG | production | MacToMacConnectionSetupMode, MacToMacConnectionSelectedRoute, MacToMacConnectionEstablishmentValidationError, MacToMacConnectionEstablishmentReport, M | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/MacToMacRouteCertification.swift | Swift | symbols: MacToMacRouteCertificationCandidate, MacToMacRouteCertificationValidationError, MacToMacRouteCertificationReport, MacToMacRouteCertificationS | high | AUDIO,NETWORKING,P2P,TX,RX | production | MacToMacRouteCertificationCandidate, MacToMacRouteCertificationValidationError, MacToMacRouteCertificationReport, MacToMacRouteCertificationSyntheticS | Foundation, OpenLolaContracts | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift | Swift | symbols: PeerSessionRunner | high | AUDIO,NETWORKING,P2P,VIDEO,CONFIG | production | PeerSessionRunner | Darwin, Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerAudioHelpers.swift | Swift | symbols: PeerSessionRunner | high | AUDIO,NETWORKING,P2P,CONFIG | production | PeerSessionRunner | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerLoopbackPair.swift | Swift | symbols: PeerSessionRunnerLoopbackPair | high | NETWORKING,P2P,LOCAL_RX | production | PeerSessionRunnerLoopbackPair | none found | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerMediaIO.swift | Swift | symbols: peerSessionMediaReceiveByteBudget, PeerSessionRunner | high | AUDIO,NETWORKING,P2P,VIDEO,TX | production | peerSessionMediaReceiveByteBudget, PeerSessionRunner | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerMetrics.swift | Swift | symbols: PeerSessionRunner, combinedJitterMicroseconds | high | NETWORKING,P2P,TX,RX,CONFIG | production | PeerSessionRunner, combinedJitterMicroseconds | Dispatch, Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerRTPAudio.swift | Swift | symbols: PeerSessionRunner, directPeerRTPSequenceNumber, directPeerAES67RTPTimestamp | high | NETWORKING,P2P,RX | production | PeerSessionRunner, directPeerRTPSequenceNumber, directPeerAES67RTPTimestamp | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerSupport.swift | Swift | symbols: PeerSessionRunner, allocatedControlEndpoint, videoPixelFormatDescription | high | AUDIO,NETWORKING,P2P,VIDEO | production | PeerSessionRunner, allocatedControlEndpoint, videoPixelFormatDescription | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerTypes.swift | Swift | symbols: PeerSessionLifecycleState, PeerSessionRunnerError, DirectPeerSessionMetrics, PeerSessionReceivedAudioMediaPacket, PeerSessionReceivedVideoMed | high | NETWORKING,P2P | production | PeerSessionLifecycleState, PeerSessionRunnerError, DirectPeerSessionMetrics, PeerSessionReceivedAudioMediaPacket, PeerSessionReceivedVideoMediaPacket | Foundation | Direct P2P runtime/CLI entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/RTP/AES67ST2110L24Transport.swift | Swift | symbols: AES67ST2110L24Profile, RTPPacketError, RTPPacketHeader, RTPPacket, L24PCMCodecError | high | AUDIO,NETWORKING,TX,RX | production | AES67ST2110L24Profile, RTPPacketError, RTPPacketHeader, RTPPacket, L24PCMCodecError | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/AudioOpusCeltLowDelayPacket.swift | Swift | symbols: AudioOpusCeltLowDelayPacketError, AudioOpusCeltLowDelayPacketHeader, AudioOpusCeltLowDelayPacket, readCheckedOpusPacketUInt16LE, readCheckedO | high | NETWORKING,UDP,RX | production | AudioOpusCeltLowDelayPacketError, AudioOpusCeltLowDelayPacketHeader, AudioOpusCeltLowDelayPacket, readCheckedOpusPacketUInt16LE, readCheckedOpusPacket | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/MultichannelTransport.swift | Swift | symbols: AudioTransportProtocolVersion, AudioWirePackingMode, LatencyProfile, AudioChannelSourceKind, AudioChannelDescriptor | high | AUDIO,NETWORKING,UDP,TX,RX | production | AudioTransportProtocolVersion, AudioWirePackingMode, LatencyProfile, AudioChannelSourceKind, AudioChannelDescriptor | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/NetworkByteReader.swift | Swift | symbols: NetworkByteReader | high | NETWORKING,UDP | production | NetworkByteReader | none found | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/PacketCodec.swift | Swift | symbols: PacketCodec | high | NETWORKING,UDP,RX | production | PacketCodec | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift | Swift | symbols: UdpMediaPacketHeader, UdpMediaPacketError, UdpMediaMalformedDatagramError, UdpMediaPacket, UdpMediaDecodedPayload | high | AUDIO,NETWORKING,UDP,VIDEO,TX,RX | production | UdpMediaPacketHeader, UdpMediaPacketError, UdpMediaMalformedDatagramError, UdpMediaPacket, UdpMediaDecodedPayload | Darwin, Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift | Swift | symbols: UdpPcmContinuousRouteRunner, UdpPcmContinuousRouteLocalhostSmoke, requireContinuousReceiverCompletion, UdpPcmSenderLoopResult, UdpPcmReceiver | high | AUDIO,NETWORKING,UDP,TX,RX,CONFIG | production | UdpPcmContinuousRouteRunner, UdpPcmContinuousRouteLocalhostSmoke, requireContinuousReceiverCompletion, UdpPcmSenderLoopResult, UdpPcmReceiverLoopResul | Darwin, Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpPcmDataHelpers.swift | Swift | symbols: udpPcmHasBytes, readCheckedUdpPcmPacketUInt16LE, readCheckedUdpPcmPacketUInt32LE, readCheckedUdpPcmPacketUInt64LE, appendUdpPcmUInt16LE | high | NETWORKING,UDP | production | udpPcmHasBytes, readCheckedUdpPcmPacketUInt16LE, readCheckedUdpPcmPacketUInt32LE, readCheckedUdpPcmPacketUInt64LE, appendUdpPcmUInt16LE | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackDefaults.swift | Swift | symbols: UdpPcmLoopbackDefaults | high | NETWORKING,UDP | production | UdpPcmLoopbackDefaults | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackHelpers.swift | Swift | symbols: makeDiagnosticsComparison, makeSenderReport, makeLooperReport, udpPcmLoopbackReportID, redactedConfigurationFields | high | AUDIO,NETWORKING,UDP,TX,LOCAL_RX,CONFIG | production | makeDiagnosticsComparison, makeSenderReport, makeLooperReport, udpPcmLoopbackReportID, redactedConfigurationFields | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift | Swift | symbols: UdpPcmLoopbackRole, UdpPcmLoopbackDiagnosticsState, UdpPcmLoopbackRunConfiguration, UdpPcmLoopbackRunConfigurationError, LoopbackTimingMetric | high | AUDIO,NETWORKING,UDP,TX,RX,LOCAL_RX,CONFIG | production | UdpPcmLoopbackRole, UdpPcmLoopbackDiagnosticsState, UdpPcmLoopbackRunConfiguration, UdpPcmLoopbackRunConfigurationError, LoopbackTimingMetrics | Darwin, Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSmokes.swift | Swift | symbols: UdpPcmLoopbackSyntheticSmoke, UdpPcmLoopbackLooperResultBox, requireLoopbackLooperCompletion, UdpPcmLoopbackLocalhostSmoke | high | AUDIO,NETWORKING,UDP,TX,RX,LOCAL_RX,CONFIG | production | UdpPcmLoopbackSyntheticSmoke, UdpPcmLoopbackLooperResultBox, requireLoopbackLooperCompletion, UdpPcmLoopbackLocalhostSmoke | Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSocketRunners.swift | Swift | symbols: UdpPcmLoopbackEstablishedSocketRunner, runConnectedLooperLoop, UdpPcmLoopbackSenderResult, UdpPcmLoopbackLooperResult, runSender | high | AUDIO,NETWORKING,UDP,TX,RX,LOCAL_RX,CONFIG | production | UdpPcmLoopbackEstablishedSocketRunner, runConnectedLooperLoop, UdpPcmLoopbackSenderResult, UdpPcmLoopbackLooperResult, runSender | Darwin, Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift | Swift | symbols: UdpPcmSampleFormat, UdpPcmPacketHeader, UdpPcmPacketError, UdpPcmPacket, UdpPcmSequenceError | high | NETWORKING,UDP,VIDEO,TX,RX,LOCAL_RX | production | UdpPcmSampleFormat, UdpPcmPacketHeader, UdpPcmPacketError, UdpPcmPacket, UdpPcmSequenceError | Darwin, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift | Swift | symbols: UdpPcmRouteKind, UdpPcmDscpClassification, UdpPcmRouteEndpoint, UdpPcmPacketMode, UdpPcmDscpObservation | high | NETWORKING,UDP,TX,RX | production | UdpPcmRouteKind, UdpPcmDscpClassification, UdpPcmRouteEndpoint, UdpPcmPacketMode, UdpPcmDscpObservation | Darwin, Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpPcmRouteHelpers.swift | Swift | symbols: makeProbePacket, requiredRouteRunString, requiredRouteRunPositiveInteger, optionalRouteRunInteger, requiredRouteRunPort | high | AUDIO,NETWORKING,UDP,TX,RX,LOCAL_RX,CONFIG | production | makeProbePacket, requiredRouteRunString, requiredRouteRunPositiveInteger, optionalRouteRunInteger, requiredRouteRunPort | Darwin, Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpPcmRouteLocalhostSmoke.swift | Swift | symbols: UdpPcmRouteLocalhostSmoke, UdpPcmOneShotSender, UdpPcmOneShotReceiver | high | AUDIO,NETWORKING,UDP,TX,RX,LOCAL_RX | production | UdpPcmRouteLocalhostSmoke, UdpPcmOneShotSender, UdpPcmOneShotReceiver | Darwin, Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpPcmRouteRunConfiguration.swift | Swift | symbols: UdpPcmRouteRunRole, UdpPcmRouteRunConfiguration, UdpPcmRouteRunConfigurationError, UdpPcmRouteRunSummary, UdpPcmRouteProbeError | high | AUDIO,NETWORKING,UDP,VIDEO,TX,RX,CONFIG | production | UdpPcmRouteRunRole, UdpPcmRouteRunConfiguration, UdpPcmRouteRunConfigurationError, UdpPcmRouteRunSummary, UdpPcmRouteProbeError | Foundation, OpenLolaContracts | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpPcmSocketOperations.swift | Swift | symbols: makeUdpSocket, setUdpSocketBuffer, closeUdpSocket, setNonBlocking, setDscp | high | NETWORKING,UDP,TX,RX,LOCAL_RX | production | makeUdpSocket, setUdpSocketBuffer, closeUdpSocket, setNonBlocking, setDscp | Darwin, Foundation, os | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpPcmV2FragmentPlanner.swift | Swift | symbols: UdpPcmV2FragmentPlanRequest, UdpPcmV2FragmentPlanningError, UdpPcmV2ChannelFragmentPlan, UdpPcmV2FragmentPlanner, checkedFragmentPlanningProd | high | NETWORKING,UDP | production | UdpPcmV2FragmentPlanRequest, UdpPcmV2FragmentPlanningError, UdpPcmV2ChannelFragmentPlan, UdpPcmV2FragmentPlanner, checkedFragmentPlanningProduct | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift | Swift | symbols: UdpPcmV2PacketError, UdpPcmV2PacketHeader, UdpPcmV2Packet, UdpPcmV2PacketizerError, UdpPcmV2Packetizer | high | NETWORKING,UDP,VIDEO,RX | production | UdpPcmV2PacketError, UdpPcmV2PacketHeader, UdpPcmV2Packet, UdpPcmV2PacketizerError, UdpPcmV2Packetizer | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Platform/NativeAppShell.swift | Swift | symbols: NativeAppConfigurationSnapshot, NativeMetricsObserverProfile, NativeRealtimeBoundaryReport, NativePermissionReadiness, NativeAppShellSmokePro | high | AUDIO,VIDEO,CONTROL,RX,CONFIG | production | NativeAppConfigurationSnapshot, NativeMetricsObserverProfile, NativeRealtimeBoundaryReport, NativePermissionReadiness, NativeAppShellSmokeProbe | Foundation, OpenLolaContracts | app shell models/command generation | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Platform/NativeAppShellArtifacts.swift | Swift | symbols: NativeAppShellArtifactKind, NativeAppShellArtifactError, NativeAppShellGeneratedArtifactState, NativeAppShellLocalMediaInventory, NativeAppSh | high | CORE_RUNTIME,NETWORKING,P2P,RX,UI,CONFIG | production | NativeAppShellArtifactKind, NativeAppShellArtifactError, NativeAppShellGeneratedArtifactState, NativeAppShellLocalMediaInventory, NativeAppShellOperat | AppKit, Foundation | app shell models/command generation | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Platform/NativeAppShellDirectPeerCommand.swift | Swift | symbols: NativeAppShellDirectPeerCommandFields, NativeAppShellLocalDirectPeerCommand, NativeAppShellLocalCommandHandoff | high | P2P | production | NativeAppShellDirectPeerCommandFields, NativeAppShellLocalDirectPeerCommand, NativeAppShellLocalCommandHandoff | Foundation | app shell models/command generation | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Platform/NativeAppShellDirectPeerSettingsValidation.swift | Swift | symbols: NativeAppShellDirectPeerCommandFields, requireCommandText, requireAllowedCommandText, requirePositiveCommandValue, requireUInt32CommandValue | high | AUDIO,VIDEO | production | NativeAppShellDirectPeerCommandFields, requireCommandText, requireAllowedCommandText, requirePositiveCommandValue, requireUInt32CommandValue | Foundation | app shell models/command generation | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Platform/NativeAppShellExecution.swift | Swift | symbols: NativeAppShellExecutionPaths, NativeAppShellExecutionValidationError, NativeAppShellExecutionSettings, validateSupervisorExecutablePath, Nati | high | NETWORKING,P2P | production | NativeAppShellExecutionPaths, NativeAppShellExecutionValidationError, NativeAppShellExecutionSettings, validateSupervisorExecutablePath, NativeAppShel | Foundation, OpenLolaContracts | app shell models/command generation | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Platform/NativeAppShellMediaDevices.swift | Swift | symbols: NativeAppShellAudioDeviceOption, NativeAppShellVideoDeviceOption | medium | CORE_RUNTIME | production | NativeAppShellAudioDeviceOption, NativeAppShellVideoDeviceOption | Foundation | app shell models/command generation | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Platform/NativeAppShellMediaInventory.swift | Swift | symbols: NativeAppShellLocalMediaSelection, NativeAppShellLocalMediaInventory | high | NETWORKING | production | NativeAppShellLocalMediaSelection, NativeAppShellLocalMediaInventory | Foundation | app shell models/command generation | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Platform/NativeAppShellOperatorPrototypeState+RunPlan.swift | Swift | symbols: NativeAppShellOperatorPrototypeState, nativeAppShellOperatorNonEmpty, operatorChannelCSV | high | NETWORKING | production | NativeAppShellOperatorPrototypeState, nativeAppShellOperatorNonEmpty, operatorChannelCSV | Foundation | app shell models/command generation | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Platform/NativeAppShellOperatorState.swift | Swift | symbols: NativeAppShellOperatorPrototypeState | high | RX | production | NativeAppShellOperatorPrototypeState | Foundation | app shell models/command generation | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Platform/NativeAppShellSearchAndPacketMonitor.swift | Swift | symbols: NativeAppPacketStreamFilter, NativeAppPacketMonitorRow, NativeAppPacketMonitorRowsError, NativeAppPacketMonitorRows, NativeAppShellSectionSea | high | AUDIO,NETWORKING,VIDEO | production | NativeAppPacketStreamFilter, NativeAppPacketMonitorRow, NativeAppPacketMonitorRowsError, NativeAppPacketMonitorRows, NativeAppShellSectionSearch | Foundation | app shell models/command generation | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Platform/NativeAppShellSessionMode.swift | Swift | symbols: NativeAppShellSessionMode, NativeAppShellControlMode, NativeAppShellSettingsGroup, NativeAppShellSettingsVisibility, NativeAppShellWindowsLoL | high | AUDIO,NETWORKING,P2P,UDP,VIDEO,CONTROL | production | NativeAppShellSessionMode, NativeAppShellControlMode, NativeAppShellSettingsGroup, NativeAppShellSettingsVisibility, NativeAppShellWindowsLoLaPeerFiel | Foundation | app shell models/command generation | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift | Swift | symbols: NativeAppShellSurfaceSectionID, NativeAppShellOperatorCommandIntent, NativeAppShellSurfaceSection, NativeAppShellSurfaceAction, NativeAppShel | high | NETWORKING,RX,UI,CONFIG | production | NativeAppShellSurfaceSectionID, NativeAppShellOperatorCommandIntent, NativeAppShellSurfaceSection, NativeAppShellSurfaceAction, NativeAppShellLaunchPr | Foundation | app shell models/command generation | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Protocol/SessionCapabilityValidating.swift | Swift | symbols: SessionCapabilityValidating, SessionAudioCapabilityNegotiating, SessionVideoCapabilityNegotiating | high | CONTROL | production | SessionCapabilityValidating, SessionAudioCapabilityNegotiating, SessionVideoCapabilityNegotiating | none found | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Protocol/SessionControlMessage.swift | Swift | symbols: SessionControlMessageType, SessionRejection, SessionMediaCommand, SessionMetricsMessage, SessionErrorMessage | high | NETWORKING,CONTROL,RX,CONFIG | production | SessionControlMessageType, SessionRejection, SessionMediaCommand, SessionMetricsMessage, SessionErrorMessage | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Protocol/SessionNegotiation.swift | Swift | symbols: SessionNegotiation | high | AUDIO,NETWORKING,VIDEO,CONTROL | production | SessionNegotiation | none found | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Protocol/SessionProtocol.swift | Swift | symbols: SessionControlProtocol, SessionLatencyProfile, SessionVideoPressurePolicy, SessionContinuityPriority, SessionLatencyProfilePolicy | high | AUDIO,NETWORKING,VIDEO,CONTROL,CONFIG | production | SessionControlProtocol, SessionLatencyProfile, SessionVideoPressurePolicy, SessionContinuityPriority, SessionLatencyProfilePolicy | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/CurrentEvidenceStatusMatrix.swift | Swift | symbols: CurrentEvidenceStatus, CurrentEvidenceLaneID, CurrentRealWorldTestID, CurrentEvidenceStatusMatrixSource, CurrentEvidenceCrosswalkRow | high | AUDIO,NETWORKING,P2P,UDP,VIDEO,CONTROL,TX,RX,LOCAL_RX | production | CurrentEvidenceStatus, CurrentEvidenceLaneID, CurrentRealWorldTestID, CurrentEvidenceStatusMatrixSource, CurrentEvidenceCrosswalkRow | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/FasterThanLoLaClosure.swift | Swift | symbols: FasterThanLoLaClaimScope, FasterThanLoLaEvidenceLane, FasterThanLoLaEvidenceReference, FasterThanLoLaBenchmarkComparison, FasterThanLoLaClosu | medium | CONFIG | production | FasterThanLoLaClaimScope, FasterThanLoLaEvidenceLane, FasterThanLoLaEvidenceReference, FasterThanLoLaBenchmarkComparison, FasterThanLoLaClosureValidat | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/FasterThanLoLaClosureValidation.swift | Swift | symbols: FasterThanLoLaClosureReport | medium | CORE_RUNTIME | production | FasterThanLoLaClosureReport | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/FieldReadinessRun.swift | Swift | symbols: FieldReadinessRunConfiguration, FieldReadinessRunConfigurationError, FieldReadinessRunResult, FieldReadinessRunner, fieldReadinessPath | medium | CONFIG | production | FieldReadinessRunConfiguration, FieldReadinessRunConfigurationError, FieldReadinessRunResult, FieldReadinessRunner, fieldReadinessPath | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/FieldReadyRuntimeProof.swift | Swift | symbols: PrototypeRuntimeMode, FieldNotarizationStatus, FieldReadyP04Evidence, FieldReadyRuntimeEvidence, FieldReadyPermissionEvidence | high | CONTROL,CONFIG | production | PrototypeRuntimeMode, FieldNotarizationStatus, FieldReadyP04Evidence, FieldReadyRuntimeEvidence, FieldReadyPermissionEvidence | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/FieldReadyRuntimeProofValidation.swift | Swift | symbols: FieldReadyRuntimeProofReport | medium | CORE_RUNTIME | production | FieldReadyRuntimeProofReport | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/Goal/GoalCodewiseClosure.swift | Swift | symbols: GoalCodewiseRequirementArea, GoalCodewiseRequirementStatus, GoalCodewiseRequirementID, GoalCodewiseRequirement, GoalCodewiseDocumentationArea | high | AUDIO,NETWORKING,P2P,UDP,VIDEO,CONTROL,TX,RX,UI | production | GoalCodewiseRequirementArea, GoalCodewiseRequirementStatus, GoalCodewiseRequirementID, GoalCodewiseRequirement, GoalCodewiseDocumentationArea | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/Goal/GoalCompletionAudit.swift | Swift | symbols: GoalCompletionAuditItemKind, GoalCompletionAuditItem, GoalCompletionAuditNextAction, GoalCompletionAuditSummary, GoalCompletionAuditValidatio | high | NETWORKING,CONFIG | production | GoalCompletionAuditItemKind, GoalCompletionAuditItem, GoalCompletionAuditNextAction, GoalCompletionAuditSummary, GoalCompletionAuditValidationError | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/Goal/GoalRuntimeEvidenceTemplate.swift | Swift | symbols: GoalRuntimeEvidenceDeliverableID, GoalRuntimeEvidenceDeliverable, GoalRuntimeEvidenceTemplateSummary, GoalRuntimeEvidenceTemplateValidationEr | high | AUDIO,NETWORKING,P2P,UDP,VIDEO,CONTROL,TX,RX,LOCAL_RX | production | GoalRuntimeEvidenceDeliverableID, GoalRuntimeEvidenceDeliverable, GoalRuntimeEvidenceTemplateSummary, GoalRuntimeEvidenceTemplateValidationError, Goal | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/Goal/GoalRuntimePreflight.swift | Swift | symbols: GoalRuntimePreflightValidationError, GoalRuntimePreflightValidator, GoalRuntimePreflightAudioProbe, GoalRuntimePreflightVideoProbe, GoalRunti | high | AUDIO,NETWORKING,P2P,UDP,VIDEO,CONTROL,TX,RX | production | GoalRuntimePreflightValidationError, GoalRuntimePreflightValidator, GoalRuntimePreflightAudioProbe, GoalRuntimePreflightVideoProbe, GoalRuntimePreflig | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift | Swift | symbols: LoLaParityFeatureCategory, LoLaParityFeatureStatus, LoLaParityDeferredFeature, LoLaParityDeferredValidationError, LoLaParityDeferredValidator | high | AUDIO,NETWORKING,UDP,VIDEO,RX | production | LoLaParityFeatureCategory, LoLaParityFeatureStatus, LoLaParityDeferredFeature, LoLaParityDeferredValidationError, LoLaParityDeferredValidator | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/LolaBaselineComparison.swift | Swift | symbols: LolaBaselineAvailability, LolaBaselineMeasurementMethod, LolaBaselineComparisonResult, LolaBaselineLatencyMetrics, LolaBaselineComparisonVali | medium | CORE_RUNTIME | production | LolaBaselineAvailability, LolaBaselineMeasurementMethod, LolaBaselineComparisonResult, LolaBaselineLatencyMetrics, LolaBaselineComparisonValidationErr | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift | Swift | symbols: OpenSourceReleaseRequirementKind, OpenSourceReleaseRequirement, OpenSourceReleaseReadinessValidationError, OpenSourceReleaseReadinessValidato | high | NETWORKING,CONFIG | production | OpenSourceReleaseRequirementKind, OpenSourceReleaseRequirement, OpenSourceReleaseReadinessValidationError, OpenSourceReleaseReadinessValidator, OpenSo | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/PackagingFieldTest.swift | Swift | symbols: MacDistributionMethod, MacPackageArtifactKind, CodeSigningIdentityType, NotarizationSubmissionTool, MacPackageArtifact | high | RX | production | MacDistributionMethod, MacPackageArtifactKind, CodeSigningIdentityType, NotarizationSubmissionTool, MacPackageArtifact | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/PackagingFieldTestHelpers.swift | Swift | symbols: PackagingFieldValidator, requiredPackagingRunString, writePackagingFieldArtifacts, packagingFieldVerdict, packagingHostArchitecture | medium | CONFIG | production | PackagingFieldValidator, requiredPackagingRunString, writePackagingFieldArtifacts, packagingFieldVerdict, packagingHostArchitecture | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/PackagingFieldTestRun.swift | Swift | symbols: PackagingFieldRunConfiguration, PackagingFieldRunConfigurationError, PackagingFieldRunner, packagingFieldRunVerdict, packagingFieldRunNotes | high | AUDIO,NETWORKING,UDP,VIDEO,CONTROL,CONFIG | production | PackagingFieldRunConfiguration, PackagingFieldRunConfigurationError, PackagingFieldRunner, packagingFieldRunVerdict, packagingFieldRunNotes | CryptoKit, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/PackagingFieldTestValidation.swift | Swift | symbols: PackagingFieldTestReport, packagedPermissionEntitlementFields, packagingHashIsValidSHA256, packagingValueIsPlaceholder | high | AUDIO,NETWORKING,VIDEO,CONTROL | production | PackagingFieldTestReport, packagedPermissionEntitlementFields, packagingHashIsValidSHA256, packagingValueIsPlaceholder | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/RecordingSessionArtifactValidationError.swift | Swift | symbols: RecordingSessionArtifactValidationError | medium | CORE_RUNTIME | production | RecordingSessionArtifactValidationError | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/RecordingSessionArtifacts.swift | Swift | symbols: RecordingDropPolicy, RecordingArtifactKind, RecordingMediaSwitch, RecordingMediaArtifactState, RecordingAudioSampleFormat | high | AUDIO,VIDEO,RX | production | RecordingDropPolicy, RecordingArtifactKind, RecordingMediaSwitch, RecordingMediaArtifactState, RecordingAudioSampleFormat | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/RecordingSessionHelpers.swift | Swift | symbols: RecordingSessionArtifactValidator, RecordingSessionRunArgument, requiredRecordingRunString, requiredRecordingRunPositiveInteger, optionalReco | high | AUDIO,VIDEO,CONFIG | production | RecordingSessionArtifactValidator, RecordingSessionRunArgument, requiredRecordingRunString, requiredRecordingRunPositiveInteger, optionalRecordingRunP | CryptoKit, Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/RecordingSessionLiveCapture.swift | Swift | symbols: RecordingSessionLiveMediaCapture, RecordingLiveCaptureWait, CoreAudioRawInputRecorder, CoreAudioRawInputState, RecordingRawByteBuffer | high | CORE_RUNTIME,AUDIO,VIDEO,CONFIG | production | RecordingSessionLiveMediaCapture, RecordingLiveCaptureWait, CoreAudioRawInputRecorder, CoreAudioRawInputState, RecordingRawByteBuffer | Foundation, Dispatch, COpenLolaAtomics, os, CoreAudio | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/RecordingSessionMediaArtifacts.swift | Swift | symbols: RecordingCapturedAudio, RecordingCapturedVideo, RecordingCapturedMedia, RecordingWrittenMediaArtifacts, RecordingMediaArtifactWriter | high | AUDIO,VIDEO | production | RecordingCapturedAudio, RecordingCapturedVideo, RecordingCapturedMedia, RecordingWrittenMediaArtifacts, RecordingMediaArtifactWriter | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/RecordingSessionRun.swift | Swift | symbols: RecordingSideLanePressureSimulator, RecordingSessionRunConfiguration, recordingAudioCaptureSelection, recordingVideoCaptureSelection, Recordi | high | AUDIO,VIDEO,RX,CONFIG | production | RecordingSideLanePressureSimulator, RecordingSessionRunConfiguration, recordingAudioCaptureSelection, recordingVideoCaptureSelection, RecordingSession | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/ReleaseHardening.swift | Swift | symbols: ReleaseClaimEvidenceKind, ReleaseVerificationGateKind, ReleasePublicDocAudit, ReleaseClaimReference, ReleaseVerificationGate | medium | CORE_RUNTIME | production | ReleaseClaimEvidenceKind, ReleaseVerificationGateKind, ReleasePublicDocAudit, ReleaseClaimReference, ReleaseVerificationGate | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Release/ReleaseHardeningSyntheticSmoke.swift | Swift | symbols: ReleaseHardeningSyntheticSmoke, ReleaseHardeningRunner, cleanReleasePublicDocAudit, releaseHardeningClaims, releaseHardeningVerificationGates | high | AUDIO,CONFIG | production | ReleaseHardeningSyntheticSmoke, ReleaseHardeningRunner, cleanReleasePublicDocAudit, releaseHardeningClaims, releaseHardeningVerificationGates | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/BoundedFileReader.swift | Swift | symbols: BoundedFileReadError, BoundedFileReader, ReportValidatingArtifact | high | RX | production | BoundedFileReadError, BoundedFileReader, ReportValidatingArtifact | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/BoundedPipeCapture.swift | Swift | symbols: BoundedPipeCapture | medium | CORE_RUNTIME | production | BoundedPipeCapture | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/FileDescriptorSet.swift | Swift | symbols: openLolaFDZero, openLolaFileDescriptorFitsFDSet, openLolaRequireFileDescriptorFitsFDSet, openLolaFDSet, openLolaFDIsSet | medium | CORE_RUNTIME | production | openLolaFDZero, openLolaFileDescriptorFitsFDSet, openLolaRequireFileDescriptorFitsFDSet, openLolaFDSet, openLolaFDIsSet | Darwin | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift | Swift | symbols: CLICommandKind, CLICommandInventoryEntry, CLICommandInventorySummary, CLICommandInventoryReport, CLICommandInventory | high | AUDIO,NETWORKING,P2P,UDP,VIDEO,CONTROL,TX,RX,LOCAL_RX,CONFIG | production | CLICommandKind, CLICommandInventoryEntry, CLICommandInventorySummary, CLICommandInventoryReport, CLICommandInventory | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrix.swift | Swift | symbols: FixtureProvenanceClass, PublicReleasePosture, FixtureMatrixEntry, CLISmokeMatrixEntry, FixtureSmokeMatrixSummary | medium | CORE_RUNTIME | production | FixtureProvenanceClass, PublicReleasePosture, FixtureMatrixEntry, CLISmokeMatrixEntry, FixtureSmokeMatrixSummary | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift | Swift | symbols: FixtureSmokeMatrix, fixture, smoke | high | AUDIO,NETWORKING,P2P,UDP,VIDEO,CONTROL,TX,RX,LOCAL_RX | production | FixtureSmokeMatrix, fixture, smoke | none found | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/Inventories/NetworkRouteCommandMatrix.swift | Swift | symbols: NetworkRouteMode, NetworkRouteEvidenceBoundary, NetworkRouteCommandMatrixEntry, NetworkRouteCommandMatrixSummary, NetworkRouteCommandMatrixRe | high | AUDIO,NETWORKING,P2P,UDP,VIDEO,CONTROL,TX,RX,LOCAL_RX,CONFIG | production | NetworkRouteMode, NetworkRouteEvidenceBoundary, NetworkRouteCommandMatrixEntry, NetworkRouteCommandMatrixSummary, NetworkRouteCommandMatrixReport | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/Inventories/RealtimeAudioPathInventory.swift | Swift | symbols: RealtimeAudioPathClass, RealtimeAudioPathInventoryEntry, RealtimeAudioPathInventorySummary, RealtimeAudioPathInventoryReport, RealtimeAudioPa | high | AUDIO,NETWORKING,UDP,VIDEO,CONTROL,TX,RX,LOCAL_RX,CONFIG | production | RealtimeAudioPathClass, RealtimeAudioPathInventoryEntry, RealtimeAudioPathInventorySummary, RealtimeAudioPathInventoryReport, RealtimeAudioPathInvento | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift | Swift | symbols: SourceOwnershipGroup, SourceOwnershipRuntimeRole, SourceOwnershipRisk, SourceOwnershipStatus, SourceOwnershipConfidence | high | CORE_RUNTIME,AUDIO,NETWORKING,P2P,UDP,VIDEO,CONTROL,TX,RX,LOCAL_RX,UI,CONFIG | production | SourceOwnershipGroup, SourceOwnershipRuntimeRole, SourceOwnershipRisk, SourceOwnershipStatus, SourceOwnershipConfidence | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/Inventories/VideoControlDegradeMatrix.swift | Swift | symbols: VideoControlSurfaceKind, VideoControlEvidenceBoundary, VideoControlDegradeMatrixEntry, VideoControlDegradeMatrixSummary, VideoControlDegradeM | high | AUDIO,NETWORKING,UDP,VIDEO,CONTROL,LOCAL_RX | production | VideoControlSurfaceKind, VideoControlEvidenceBoundary, VideoControlDegradeMatrixEntry, VideoControlDegradeMatrixSummary, VideoControlDegradeMatrixRepo | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/ManagedProcessRunner.swift | Swift | symbols: ManagedProcess, ManagedProcessCleanupWarning, ManagedProcessTerminationResult, ManagedProcessRunner | medium | CORE_RUNTIME | production | ManagedProcess, ManagedProcessCleanupWarning, ManagedProcessTerminationResult, ManagedProcessRunner | Darwin, Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/MonotonicDeadline.swift | Swift | symbols: MonotonicDeadline | medium | CORE_RUNTIME | production | MonotonicDeadline | Dispatch, Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/PlaceholderDetection.swift | Swift | symbols: PlaceholderDetection | medium | CORE_RUNTIME | production | PlaceholderDetection | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/PlaceholderFieldCollection.swift | Swift | symbols: placeholderFields, placeholderIndexedFields | medium | CORE_RUNTIME | production | placeholderFields, placeholderIndexedFields | none found | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/SPSCAtomicRing.swift | Swift | symbols: SPSCAtomicRingResult, SPSCUInt64Ring, currentSPSCThreadID | medium | CORE_RUNTIME | production | SPSCAtomicRingResult, SPSCUInt64Ring, currentSPSCThreadID | COpenLolaAtomics, Darwin, Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Support/SyntheticPlaceholderMetrics.swift | Swift | symbols: SyntheticPlaceholderMetrics | medium | CORE_RUNTIME | production | SyntheticPlaceholderMetrics | none found | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Timing/DriftPlcFixedTargetCertification.swift | Swift | symbols: DriftPlcFixedTargetCertificationValidationError, DriftPlcFixedTargetCertificationReport, DriftPlcFixedTargetCertificationSyntheticSmoke, isDr | high | NETWORKING,TX,RX | production | DriftPlcFixedTargetCertificationValidationError, DriftPlcFixedTargetCertificationReport, DriftPlcFixedTargetCertificationSyntheticSmoke, isDriftCertif | Foundation, OpenLolaContracts | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Timing/DriftPlcHelpers.swift | Swift | symbols: DriftClockEstimate, DriftClockEstimator, fixedPlayoutTargetFrames, fixedTargetTelemetry, uniqueSortedCheckpoints | high | AUDIO,LOCAL_RX,CONFIG | production | DriftClockEstimate, DriftClockEstimator, fixedPlayoutTargetFrames, fixedTargetTelemetry, uniqueSortedCheckpoints | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Timing/DriftPlcReport.swift | Swift | symbols: SameDeadlinePlcPolicy, DriftCorrectionLocation, DriftTelemetrySample, SameDeadlinePlcEvent, DriftCorrectionEvent | high | AUDIO,RX | production | SameDeadlinePlcPolicy, DriftCorrectionLocation, DriftTelemetrySample, SameDeadlinePlcEvent, DriftCorrectionEvent | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Timing/DriftPlcRun.swift | Swift | symbols: DriftPlcRunConfiguration, DriftPlcRunConfigurationError, DriftPlcFixedTargetRunner, DriftPlcSyntheticSmoke | high | AUDIO,NETWORKING,UDP,TX,RX,LOCAL_RX,CONFIG | production | DriftPlcRunConfiguration, DriftPlcRunConfigurationError, DriftPlcFixedTargetRunner, DriftPlcSyntheticSmoke | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Timing/LatencyProfileContracts.swift | Swift | symbols: LatencyProfileWarning, LatencyProfileValidationError, LatencyProfilePolicy, LatencyProfileBudget, LatencyProfileSelectionRequest | high | LOCAL_RX | production | LatencyProfileWarning, LatencyProfileValidationError, LatencyProfilePolicy, LatencyProfileBudget, LatencyProfileSelectionRequest | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Timing/LatencyTuningReport.swift | Swift | symbols: LatencyTuningEvidenceKind, LatencyTuningValidationError, LatencyTuningThresholds, LatencyTuningCandidate, LatencyTuningChangeRecord | high | AUDIO,VIDEO | production | LatencyTuningEvidenceKind, LatencyTuningValidationError, LatencyTuningThresholds, LatencyTuningCandidate, LatencyTuningChangeRecord | Foundation, OpenLolaContracts | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Timing/LatencyTuningReportValidation.swift | Swift | symbols: LatencyTuningValidator, LatencyTuningReport, validateLatencyTuningHardware, validateLatencyTuningRoute, validateLatencyTuningTiming | medium | CORE_RUNTIME | production | LatencyTuningValidator, LatencyTuningReport, validateLatencyTuningHardware, validateLatencyTuningRoute, validateLatencyTuningTiming | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Timing/MediaClock.swift | Swift | symbols: MediaClockValidationError, MediaClock, MediaClockAnchor, MediaTimestampOrigin, MediaTimingPacket | high | NETWORKING | production | MediaClockValidationError, MediaClock, MediaClockAnchor, MediaTimestampOrigin, MediaTimingPacket | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Timing/RxBufferBenchmarkReport.swift | Swift | symbols: RxBufferBenchmarkEvidenceKind, RxBufferBenchmarkValidationError, RxBufferBenchmarkValidator, RxBufferBenchmarkRow, RxBufferBenchmarkReport | medium | CORE_RUNTIME | production | RxBufferBenchmarkEvidenceKind, RxBufferBenchmarkValidationError, RxBufferBenchmarkValidator, RxBufferBenchmarkRow, RxBufferBenchmarkReport | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Timing/RxBufferBenchmarkRunner.swift | Swift | symbols: RxBufferBenchmarkRunnerError, RxBufferBenchmarkRunner | high | AUDIO,RX | production | RxBufferBenchmarkRunnerError, RxBufferBenchmarkRunner | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Timing/RxBuffering.swift | Swift | symbols: RxBufferPolicyValidationError, RxBufferPolicyValidator, RxBufferPolicy, RxBufferTargetChangeEvent, RxBufferProfile | high | AUDIO,NETWORKING,RX | production | RxBufferPolicyValidationError, RxBufferPolicyValidator, RxBufferPolicy, RxBufferTargetChangeEvent, RxBufferProfile | Foundation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Timing/RxImpairmentSimulator.swift | Swift | symbols: RxImpairmentProfile, RxImpairedPacketEvent, RxImpairmentSimulationSummary, RxImpairmentSimulationResult, RxImpairmentSimulationError | medium | CORE_RUNTIME | production | RxImpairmentProfile, RxImpairedPacketEvent, RxImpairmentSimulationSummary, RxImpairmentSimulationResult, RxImpairmentSimulationError | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Timing/SessionProfileBenchmark.swift | Swift | symbols: SessionLatencyProfileBenchmarkMetrics, LatencyProfileBenchmarkSyntheticSmoke, validateProfilePacketAge, validateProfileJitter, SessionProfile | medium | CORE_RUNTIME | production | SessionLatencyProfileBenchmarkMetrics, LatencyProfileBenchmarkSyntheticSmoke, validateProfilePacketAge, validateProfileJitter, SessionProfileBenchmark | Foundation | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Timing/TimingValidationHelpers.swift | Swift | symbols: timingPercentilesAreOrdered | medium | CORE_RUNTIME | production | timingPercentilesAreOrdered | none found | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/BlackmagicOutputBoundary.swift | Swift | symbols: BlackmagicDesktopVideoSDKStatus, BlackmagicOutputBoundaryReport, BlackmagicOutputBoundary | high | VIDEO | production | BlackmagicDesktopVideoSDKStatus, BlackmagicOutputBoundaryReport, BlackmagicOutputBoundary | Foundation | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/JPEGXSReferenceCodec.swift | Swift | symbols: JPEGXSReferenceCodecError, JPEGXSReferenceCodec | high | VIDEO,RX | production | JPEGXSReferenceCodecError, JPEGXSReferenceCodec | Foundation, CJpegXSReference | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/MediaGeometrySizing.swift | Swift | symbols: MediaGeometrySizingError, MediaGeometrySizing | high | VIDEO | production | MediaGeometrySizingError, MediaGeometrySizing | Foundation | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/MultiVideoStreams.swift | Swift | symbols: VideoReceiverSelectionMode, VideoMultiViewLayoutKind, VideoMultiViewLayout, VideoReceiverSelection, VideoStreamTransportMetrics | high | NETWORKING,VIDEO,TX | production | VideoReceiverSelectionMode, VideoMultiViewLayoutKind, VideoMultiViewLayout, VideoReceiverSelection, VideoStreamTransportMetrics | Foundation | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/RawBGRAAppKitPreviewWindow.swift | Swift | symbols: RawBGRAPreviewError, RawBGRAPreviewSink, RawBGRATestablePreviewSink, RawBGRAImageFactory, RawBGRAAppKitPreviewWindow | high | VIDEO,RX,UI | production | RawBGRAPreviewError, RawBGRAPreviewSink, RawBGRATestablePreviewSink, RawBGRAImageFactory, RawBGRAAppKitPreviewWindow | AppKit, CoreGraphics, Foundation | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift | Swift | symbols: AVFoundationPermissionStatus, AVFoundationVideoSourcePolicy, AVFoundationVideoFormatDescription, AVFoundationVideoDeviceDescription, AVFounda | high | VIDEO,CONTROL | production | AVFoundationPermissionStatus, AVFoundationVideoSourcePolicy, AVFoundationVideoFormatDescription, AVFoundationVideoDeviceDescription, AVFoundationVideo | Foundation, Dispatch, CoreMedia, CoreVideo | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoCaptureHelpers.swift | Swift | symbols: VideoCaptureValidator, requireVideoCapturePacketAge, videoCapturePacketAge, videoCapturePercentile, videoCaptureFourCCString | high | VIDEO,CONFIG | production | VideoCaptureValidator, requireVideoCapturePacketAge, videoCapturePacketAge, videoCapturePercentile, videoCaptureFourCCString | Foundation | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoCaptureProbe.swift | Swift | symbols: VideoSourceKind, VideoQueuePolicy, CameraSource, VideoTimestampBasis, VideoCaptureStreamMetadata | high | VIDEO | production | VideoSourceKind, VideoQueuePolicy, CameraSource, VideoTimestampBasis, VideoCaptureStreamMetadata | Foundation, Darwin, CoreMedia, CoreVideo | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoCaptureReport.swift | Swift | symbols: ProductionVideoHardwareKind, ProductionVideoConnectionMethod, BlackmagicDesktopVideoSdkStatus, ProductionVideoCaptureEvidence, VideoCaptureVa | high | VIDEO,CONTROL | production | ProductionVideoHardwareKind, ProductionVideoConnectionMethod, BlackmagicDesktopVideoSdkStatus, ProductionVideoCaptureEvidence, VideoCaptureValidationE | Foundation | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoCaptureRunConfiguration.swift | Swift | symbols: VideoCaptureRunConfigurationError, VideoCaptureRunConfiguration, ProductionVideoCaptureEvidenceInput, optionalVideoCaptureVerdict, optionalVi | high | AUDIO,VIDEO,CONTROL,LOCAL_RX,CONFIG | production | VideoCaptureRunConfigurationError, VideoCaptureRunConfiguration, ProductionVideoCaptureEvidenceInput, optionalVideoCaptureVerdict, optionalVideoCaptur | Foundation, OpenLolaContracts | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoCaptureRunner.swift | Swift | symbols: VideoCaptureProbeError, AVFoundationCameraSourceSnapshot, VideoCaptureSyntheticSmoke, AVFoundationVideoCaptureRunner, waitForAVFoundationCapt | high | AUDIO,VIDEO,RX,CONFIG | production | VideoCaptureProbeError, AVFoundationCameraSourceSnapshot, VideoCaptureSyntheticSmoke, AVFoundationVideoCaptureRunner, waitForAVFoundationCaptureDurati | Foundation, Dispatch, os, Darwin, CoreMedia | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoMediaSocket.swift | Swift | symbols: VideoMediaPacketizer, videoMediaFragmentPacketByteLimit | high | VIDEO | production | VideoMediaPacketizer, videoMediaFragmentPacketByteLimit | Foundation | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoOutputRenderer.swift | Swift | symbols: VideoOutputBackendKind, VideoFramePacingPolicy, VideoOutputFrame, VideoOutputSubmitResult, VideoRenderOutputMetrics | high | NETWORKING,VIDEO | production | VideoOutputBackendKind, VideoFramePacingPolicy, VideoOutputFrame, VideoOutputSubmitResult, VideoRenderOutputMetrics | Foundation | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoStreamDescription.swift | Swift | symbols: VideoStreamRole, VideoPixelFormat, VideoTransportFormat, VideoResolution, VideoFrameRate | high | VIDEO | production | VideoStreamRole, VideoPixelFormat, VideoTransportFormat, VideoResolution, VideoFrameRate | none found | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoTransportHelpers.swift | Swift | symbols: VideoTransportValidator, isRawOrIntraFrameTransportMode, normalizedVideoPixelFormat, videoBytesPerPixel, requiredVideoTransportRunString | high | VIDEO,CONFIG | production | VideoTransportValidator, isRawOrIntraFrameTransportMode, normalizedVideoPixelFormat, videoBytesPerPixel, requiredVideoTransportRunString | Foundation | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoTransportMultiStreamRuntime.swift | Swift | symbols: VideoTransportStreamRunState, videoTransportStreamStates, videoTransportTotalFramesGenerated, videoTransportTotalFragmentsSent, recordVideoTr | high | NETWORKING,VIDEO,CONTROL,CONFIG | production | VideoTransportStreamRunState, videoTransportStreamStates, videoTransportTotalFramesGenerated, videoTransportTotalFragmentsSent, recordVideoTransportRe | Foundation | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoTransportPacket.swift | Swift | symbols: VideoTransportPacket, VideoTransportFragment, VideoTransportFragmentError, RawVideoFrameTransport, readVideoTransportUInt16LE | high | NETWORKING,VIDEO,RX | production | VideoTransportPacket, VideoTransportFragment, VideoTransportFragmentError, RawVideoFrameTransport, readVideoTransportUInt16LE | Foundation | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoTransportProbe.swift | Swift | symbols: VideoTransportMode, VideoDegradationAction, VideoTransportProfile, VideoTransportRouteKind, VideoTransportRouteEvidence | high | NETWORKING,VIDEO,CONFIG | production | VideoTransportMode, VideoDegradationAction, VideoTransportProfile, VideoTransportRouteKind, VideoTransportRouteEvidence | Foundation | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoTransportReassembly.swift | Swift | symbols: VideoFragmentationMetrics, VideoReassemblyMetrics, LatestVideoFrameReceiver, VideoFrameReassembler, VideoFrameReassemblyKey | high | NETWORKING,VIDEO,RX | production | VideoFragmentationMetrics, VideoReassemblyMetrics, LatestVideoFrameReceiver, VideoFrameReassembler, VideoFrameReassemblyKey | Dispatch, Foundation | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoTransportReport.swift | Swift | symbols: VideoTransportReport | high | VIDEO,RX | production | VideoTransportReport | Foundation | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/OpenLolaCore/Video/VideoTransportRunner.swift | Swift | symbols: VideoTransportSyntheticSmoke, VideoReceiveRenderSyntheticSmoke, VideoTransportRunner, nextVideoTransportFrameDeadline, videoTransportRunnerAl | high | AUDIO,NETWORKING,UDP,VIDEO,CONTROL,TX,RX,LOCAL_RX,CONFIG | production | VideoTransportSyntheticSmoke, VideoReceiveRenderSyntheticSmoke, VideoTransportRunner, nextVideoTransportFrameDeadline, videoTransportRunnerAllowsQoS | Darwin, Dispatch, Foundation | video CLI/runtime/report entrypoints | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app-main/OpenLolaAppMain.swift | Swift | symbols: OpenLolaAppMain | medium | UI | production-ui | OpenLolaAppMain | AppKit, OpenLolaAppSupport, SwiftUI | macOS app entrypoint | used | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppChannelMeterView.swift | Swift | symbols: AppChannelMeterView, ChannelMeterLevelSnapshot, PeakDecayTaskOwner, PeakHoldState, AppCompactMeterStrip | high | AUDIO,VIDEO,UI | production-ui | AppChannelMeterView, ChannelMeterLevelSnapshot, PeakDecayTaskOwner, PeakHoldState, AppCompactMeterStrip | SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppConnectionTopologyView.swift | Swift | symbols: AppConnectionTopologyView, AppConnectionTopologyAnimationPolicy | high | AUDIO,NETWORKING,P2P,VIDEO,CONTROL,UI | production-ui | AppConnectionTopologyView, AppConnectionTopologyAnimationPolicy | OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppConsoleChromeView.swift | Swift | symbols: AppConsoleSidebarView, AppConsoleSidebarRow, AppPacketMonitorSidebarPolicy, AppConsoleTopBarView, AppConsoleFooterStripView | high | VIDEO,UI,CONFIG | production-ui | AppConsoleSidebarView, AppConsoleSidebarRow, AppPacketMonitorSidebarPolicy, AppConsoleTopBarView, AppConsoleFooterStripView | OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppConsoleModels.swift | Swift | symbols: AppConsoleStatusSnapshot, AppOverviewStatusItem, AppOverviewNextAction, AppOverviewEvidenceSummary, AppOverviewOperatorSummary | high | NETWORKING,UI,CONFIG | production-ui | AppConsoleStatusSnapshot, AppOverviewStatusItem, AppOverviewNextAction, AppOverviewEvidenceSummary, AppOverviewOperatorSummary | OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppDesignSystem.swift | Swift | symbols: AppDesignSystem, AppColorRole, AppColorTheme, AppColorComponents, AppColorEnvironment | high | P2P,VIDEO,UI,CONFIG | production-ui | AppDesignSystem, AppColorRole, AppColorTheme, AppColorComponents, AppColorEnvironment | Foundation, AppKit, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppDeviceCard.swift | Swift | symbols: AppAudioDeviceCard, AppVideoDeviceCard, AppSelectableDeviceCard | high | AUDIO,VIDEO,UI | production-ui | AppAudioDeviceCard, AppVideoDeviceCard, AppSelectableDeviceCard | OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppExecutablePathResolver.swift | Swift | symbols: AppExecutablePathResolver, AppExecutablePathResolution, AppExecutablePathResolutionError | medium | UI | production-ui | AppExecutablePathResolver, AppExecutablePathResolution, AppExecutablePathResolutionError | Foundation, OSLog | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppExecutionController.swift | Swift | symbols: AppExecutionPhase, AppExecutionKind, AppValidationResult, AppValidationReadiness, AppExecutionController | high | AUDIO,NETWORKING,UI,CONFIG | production-ui | AppExecutionPhase, AppExecutionKind, AppValidationResult, AppValidationReadiness, AppExecutionController | Foundation, AppKit, Observation, OpenLolaCore | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppExecutionView.swift | Swift | symbols: AppExecutionView, AppExecutionErrorGuidance, AppProcessExitDisplay, AppCommandPreview, AppReportsView | high | AUDIO,NETWORKING,VIDEO,CONTROL,UI,CONFIG | production-ui | AppExecutionView, AppExecutionErrorGuidance, AppProcessExitDisplay, AppCommandPreview, AppReportsView | OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppLatencyHeroMetrics.swift | Swift | symbols: AppLatencyHeroMetrics | high | NETWORKING,RX,UI | production-ui | AppLatencyHeroMetrics | Foundation, OpenLolaCore | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppLatencyHeroView.swift | Swift | symbols: AppLatencyHeroView | high | AUDIO,NETWORKING,VIDEO,UI | production-ui | AppLatencyHeroView | OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppLocalOperatorInventory.swift | Swift | symbols: AppLocalOperatorInventoryController, AppLocalOperatorInventory | high | AUDIO,UI | production-ui | AppLocalOperatorInventoryController, AppLocalOperatorInventory | Foundation, Observation, OpenLolaCore | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppLocalOperatorSurfaceView.swift | Swift | symbols: AppLocalOperatorSurfaceView, AppWorkflowModeSelectorView, AppNormalMacToMacConnectionFieldsView, AppWindowsLoLaConnectionFieldsView, AppWorkf | high | AUDIO,NETWORKING,VIDEO,CONTROL,UI,CONFIG | production-ui | AppLocalOperatorSurfaceView, AppWorkflowModeSelectorView, AppNormalMacToMacConnectionFieldsView, AppWindowsLoLaConnectionFieldsView, AppWorkflowUnavai | OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppOperatorArtifactViews.swift | Swift | symbols: AppOperatorArtifactsView | high | VIDEO,UI | production-ui | AppOperatorArtifactsView | AppKit, OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppOperatorPlanViews.swift | Swift | symbols: AppOperatorPrototypePlan, AppOperatorReadinessView, windowsLoLaMediaPacketCountLabel, AppPeerDeviceView, AppOperatorCommandsView | high | AUDIO,NETWORKING,VIDEO,CONTROL,RX,UI,CONFIG | production-ui | AppOperatorPrototypePlan, AppOperatorReadinessView, windowsLoLaMediaPacketCountLabel, AppPeerDeviceView, AppOperatorCommandsView | OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppPacketMonitorView.swift | Swift | symbols: AppPacketMonitorView, AppPacketMonitorRowsState | high | AUDIO,NETWORKING,VIDEO,CONTROL,UI | production-ui | AppPacketMonitorView, AppPacketMonitorRowsState | Foundation, OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppPasteboard.swift | Swift | symbols: AppPasteboard, AppPasteboardCopyStatus | medium | UI | production-ui | AppPasteboard, AppPasteboardCopyStatus | AppKit | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppPreviewBindings.swift | Swift | symbols: appPreviewBinding, appPreviewIntBinding | medium | UI | production-ui | appPreviewBinding, appPreviewIntBinding | SwiftUI | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppPreviewReceiverView.swift | Swift | symbols: AppPreviewReceiverState, AppPreviewControlAvailability, AppPreviewReceiverWarningPolicy, AppPreviewReceiverView, AppReceiverWindowView | high | AUDIO,VIDEO,CONTROL,UI | production-ui | AppPreviewReceiverState, AppPreviewControlAvailability, AppPreviewReceiverWarningPolicy, AppPreviewReceiverView, AppReceiverWindowView | Observation, OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppReceiverPreviewServices.swift | Swift | symbols: AppVideoPreviewController, AppVideoPreviewLayerView, AppVideoPreviewNSView, AppAudioLevelMeter, AppAudioLevelMeterTimerTarget | high | CORE_RUNTIME,AUDIO,VIDEO,UI | production-ui | AppVideoPreviewController, AppVideoPreviewLayerView, AppVideoPreviewNSView, AppAudioLevelMeter, AppAudioLevelMeterTimerTarget | AppKit, COpenLolaAtomics, CoreAudio, Foundation, Observation | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppRemoteInventoryImport.swift | Swift | symbols: NativeAppShellOperatorPrototypeState, NativeAppShellLocalMediaInventory | high | VIDEO,UI | production-ui | NativeAppShellOperatorPrototypeState, NativeAppShellLocalMediaInventory | Foundation, OpenLolaCore | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppRuntimeEvidenceScope.swift | Swift | symbols: AppRuntimeEvidenceScope | high | CORE_RUNTIME,NETWORKING,UI | production-ui | AppRuntimeEvidenceScope | Foundation, OpenLolaCore | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppRuntimeInputLock.swift | Swift | symbols: AppRuntimeInputLock | medium | UI,CONFIG | production-ui | AppRuntimeInputLock | none found | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppSessionStateBanner.swift | Swift | symbols: AppSessionStateBanner, AppSessionBannerAccessibilityPolicy, AppAccessibilityAnnouncementView, SessionBannerCTAStyle, AppSessionState | high | VIDEO,RX,UI,CONFIG | production-ui | AppSessionStateBanner, AppSessionBannerAccessibilityPolicy, AppAccessibilityAnnouncementView, SessionBannerCTAStyle, AppSessionState | AppKit, OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppSettings.swift | Swift | symbols: AppSettings, AppSettingsDraft, AppPreviewDefaults | medium | UI,CONFIG | production-ui | AppSettings, AppSettingsDraft, AppPreviewDefaults | Foundation, Observation, OpenLolaCore | callers not enumerated in this pass | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppShellReadOnlyViews.swift | Swift | symbols: AppShellOverviewView, AppShellConfigurationView, AppShellMetricsView, AppShellBoundariesView, AppShellPermissionsView | high | AUDIO,NETWORKING,VIDEO,CONTROL,LOCAL_RX,UI,CONFIG | production-ui | AppShellOverviewView, AppShellConfigurationView, AppShellMetricsView, AppShellBoundariesView, AppShellPermissionsView | OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppShellRootView.swift | Swift | symbols: AppShellRootView, AppSidebarLiveNavigationPolicy, AppShellRootDetailPanel, AppUnavailableSectionView, AppShellExecutionDerivedInputs | high | AUDIO,NETWORKING,VIDEO,UI,CONFIG | production-ui | AppShellRootView, AppSidebarLiveNavigationPolicy, AppShellRootDetailPanel, AppUnavailableSectionView, AppShellExecutionDerivedInputs | OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppShellSettingsTabs.swift | Swift | symbols: AppExecutionSettingsTab, AppExternalConnectorNoticeTab, AppWindowsLoLaSettingsTab, AppPeersSettingsTab, AppAudioSettingsTab | high | AUDIO,NETWORKING,VIDEO,CONTROL,TX,RX,UI,CONFIG | production-ui | AppExecutionSettingsTab, AppExternalConnectorNoticeTab, AppWindowsLoLaSettingsTab, AppPeersSettingsTab, AppAudioSettingsTab | OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppShellSettingsView.swift | Swift | symbols: AppShellSettingsView, AppShellSettingsTabID, AppSettingsCommitFeedback, AppShellSettingsTabVisibility | high | AUDIO,VIDEO,UI,CONFIG | production-ui | AppShellSettingsView, AppShellSettingsTabID, AppSettingsCommitFeedback, AppShellSettingsTabVisibility | OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppShellStoredDefaults.swift | Swift | symbols: AppShellStoredDefaults | high | NETWORKING,UI,CONFIG | production-ui | AppShellStoredDefaults | Foundation, OpenLolaCore, OSLog | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppShellSupportViews.swift | Swift | symbols: UInt16Field, IntField, MetricsGrid, AppReadableMetric, AppReadableMetricAccessibility | high | VIDEO,UI | production-ui | UInt16Field, IntField, MetricsGrid, AppReadableMetric, AppReadableMetricAccessibility | AppKit, OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppStorageKeys.swift | Swift | symbols: AppStorageKeys, AppOperatorArtifactDefaults | high | AUDIO,NETWORKING,VIDEO,UI | production-ui | AppStorageKeys, AppOperatorArtifactDefaults | OpenLolaCore | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/AppTransportView.swift | Swift | symbols: AppTransportView, AppTransportFocusedButton, AppTransportButtonStyle, View, AppTransportStopConfirmationPolicy | high | AUDIO,NETWORKING,VIDEO,CONTROL,UI,CONFIG | production-ui | AppTransportView, AppTransportFocusedButton, AppTransportButtonStyle, View, AppTransportStopConfirmationPolicy | OpenLolaCore, SwiftUI | callers not enumerated in this pass | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/Info.plist | plist | bundle/config metadata | high | AUDIO,UDP,VIDEO,UI,CONFIG | config | none found | none found | none known | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/OpenLolaApp.swift | Swift | symbols: OpenLolaApp, OpenLolaAppScene, OpenLolaApplicationDelegate, AppQuitGuardPolicy, AppMenuActionHandling | high | NETWORKING,TX,RX,UI,CONFIG | production-ui | OpenLolaApp, OpenLolaAppScene, OpenLolaApplicationDelegate, AppQuitGuardPolicy, AppMenuActionHandling | AppKit, OpenLolaCore, SwiftUI | macOS app entrypoint | used | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola-app/open-lola-app.entitlements | plist | bundle/config metadata | high | NETWORKING,UI,CONFIG | config | none found | none found | none known | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/Audio/LatencyProfileCommands.swift | Swift | symbols: handleLatencyProfileCommand, latencyProfileBenchmarkSyntheticSmokeReport, rxBufferBenchmarkOutputPath, rxBufferBenchmarkPacketCount | high | AUDIO,RX,CONFIG | production-cli | handleLatencyProfileCommand, latencyProfileBenchmarkSyntheticSmokeReport, rxBufferBenchmarkOutputPath, rxBufferBenchmarkPacketCount | Foundation, OpenLolaCore | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift | Swift | symbols: handleMadiFullDuplexCommand, MadiFullDuplexCommandRun, parseKeyValues, fdRequired, fdPositiveInt | high | AUDIO,NETWORKING,UDP,RX,CONFIG | production-cli | handleMadiFullDuplexCommand, MadiFullDuplexCommandRun, parseKeyValues, fdRequired, fdPositiveInt | Foundation, OpenLolaCore | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/Audio/MadiReceiveCommands.swift | Swift | symbols: handleMadiReceiveCommand | high | AUDIO,RX,CONFIG | production-cli | handleMadiReceiveCommand | Foundation, OpenLolaCore | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift | Swift | symbols: handleE2EBenchmarkCommand, e2eBenchmarkInputData | high | AUDIO,VIDEO,RX,CONFIG | production-cli | handleE2EBenchmarkCommand, e2eBenchmarkInputData | Foundation, OpenLolaCore | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/Benchmarks/PerformanceCommands.swift | Swift | symbols: handlePerformanceCommand | medium | CONFIG | production-cli | handlePerformanceCommand | Foundation, OpenLolaCore | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/CLICommandHelpers.swift | Swift | symbols: validateReport | medium | CONFIG | production-cli | validateReport | Foundation, OpenLolaCore | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | medium | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/MilestoneCommands.swift | Swift | symbols: handleMilestoneCommand | high | AUDIO,NETWORKING,UDP,VIDEO,CONTROL,TX,RX,LOCAL_RX,CONFIG | production-cli | handleMilestoneCommand | Foundation, OpenLolaCore | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/Network/DirectP2PMeasuredEvidenceCommandSupport.swift | Swift | symbols: directP2PApplyMeasuredEvidence, directP2PAttachGeneratedReceiveEvidence, directP2PWriteReceiveProofArtifacts, directP2PWriteAutoEvidenceArtif | high | AUDIO,NETWORKING,P2P,VIDEO,RX,CONFIG | production-cli | directP2PApplyMeasuredEvidence, directP2PAttachGeneratedReceiveEvidence, directP2PWriteReceiveProofArtifacts, directP2PWriteAutoEvidenceArtifact, Dire | Foundation, OpenLolaCore | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/Network/DirectP2PMeshArgumentSupport.swift | Swift | symbols: parseDirectP2PMeshTopologyArguments, directP2PMeshTopologyOutputPath, directP2PMeshTopologyPeerCount, parseDirectP2PMeshRuntimeArguments, par | high | NETWORKING,CONFIG | production-cli | parseDirectP2PMeshTopologyArguments, directP2PMeshTopologyOutputPath, directP2PMeshTopologyPeerCount, parseDirectP2PMeshRuntimeArguments, parseDirectP | Foundation, OpenLolaCore | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/Network/DirectP2PSessionQualityPolicyCommandSupport.swift | Swift | symbols: directP2PQualityPolicy | high | NETWORKING,CONFIG | production-cli | directP2PQualityPolicy | OpenLolaCore | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/Network/DirectP2PSessionRunArgumentSupport.swift | Swift | symbols: directP2PSessionRunAllowedArguments, directP2PSessionRunPublicArguments | high | AUDIO,NETWORKING,VIDEO,CONTROL,RX,CONFIG | production-cli | directP2PSessionRunAllowedArguments, directP2PSessionRunPublicArguments | none found | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift | Swift | symbols: printDirectP2PSessionRunUsage, parseDirectP2PSessionRunArguments, directP2PSessionRunOutputPath, directP2PReadyFileWriter, directP2PSessionMe | high | AUDIO,NETWORKING,P2P,VIDEO,CONTROL,RX,CONFIG | production-cli | printDirectP2PSessionRunUsage, parseDirectP2PSessionRunArguments, directP2PSessionRunOutputPath, directP2PReadyFileWriter, directP2PSessionMediaMode | Foundation, OpenLolaCore | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift | Swift | symbols: runDirectP2PTwoPeerLocalRunCommand, runDirectP2PTwoPeerLocalProcesses, directP2PTwoPeerRunTimeoutSeconds, waitForDirectP2PProcessesToExit, te | high | NETWORKING,P2P,RX,CONFIG | production-cli | runDirectP2PTwoPeerLocalRunCommand, runDirectP2PTwoPeerLocalProcesses, directP2PTwoPeerRunTimeoutSeconds, waitForDirectP2PProcessesToExit, terminateEx | Dispatch, Foundation, OpenLolaCore | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift | Swift | symbols: printDirectP2PTwoPeerPrototypeReportUsage, runDirectP2PTwoPeerPrototypeReportCommand, parseDirectP2PTwoPeerPrototypeArguments, directP2PTwoPe | high | NETWORKING,P2P,RX,CONFIG | production-cli | printDirectP2PTwoPeerPrototypeReportUsage, runDirectP2PTwoPeerPrototypeReportCommand, parseDirectP2PTwoPeerPrototypeArguments, directP2PTwoPeerPrototy | Foundation, OpenLolaCore | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/Network/NetworkCommands.swift | Swift | symbols: handleNetworkCommand, printUdpPcmRouteRunUsage | high | AUDIO,NETWORKING,P2P,UDP,CONTROL,TX,RX,LOCAL_RX,CONFIG | production-cli | handleNetworkCommand, printUdpPcmRouteRunUsage | Darwin, Foundation, OpenLolaCore | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift | Swift | symbols: handleMilestoneValidationCommand | high | NETWORKING,VIDEO,CONTROL,RX,CONFIG | production-cli | handleMilestoneValidationCommand | Foundation, OpenLolaCore | CLI command dispatcher via Sources/open-lola/main.swift | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/Info.plist | plist | bundle/config metadata | high | AUDIO,NETWORKING,UDP,VIDEO,CONFIG | config | none found | none found | none known | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/main.swift | Swift | symbols: runOpenLolaCommand, Command, RegisteredCommand, openLolaCommandRegistry, openLolaCommands | high | CORE_RUNTIME,AUDIO,NETWORKING,UDP,VIDEO,CONTROL,TX,RX,LOCAL_RX,CONFIG | production-cli | runOpenLolaCommand, Command, RegisteredCommand, openLolaCommandRegistry, openLolaCommands | Darwin, Foundation, OpenLolaCore | CLI main dispatch | used | partially inspected | high | direct metadata scan; full semantic audit not completed |
| Sources/open-lola/open-lola.entitlements | plist | bundle/config metadata | high | NETWORKING,CONFIG | config | none found | none found | none known | unclear | partially inspected | high | direct metadata scan; full semantic audit not completed |

### Vendored Opus Inventory

Common inherited fields for every Opus row unless the role column says otherwise: approximate purpose is the listed upstream Opus or COpus bridge role; runtime relevance is codec boundary for compiled COpus rows and release-boundary/noise for uncompiled upstream extras; main symbols and imports were not extracted in this pass; immediate callers are Package.swift/OpenLola codec wrapper only for compiled bridge/core rows; inspection is partial only for compiled/bridge rows and not inspected for other upstream files; use status is used only for Package.swift-listed compiled rows, otherwise unclear.

| Path | Language/type | Role/purpose | Runtime relevance | Classification | Kind | Main functions/classes/components | Important imports/dependencies | Immediate callers or likely entrypoints | Used/unused/duplicated/deprecated/generated/unclear | Inspection | Risk | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Sources/opus-1.5.2/.github/workflows/autotools.yml | YAML | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/.github/workflows/cmake.yml | YAML | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/.github/workflows/dred.yml | YAML | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/.github/workflows/repository.yml | YAML | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/.gitlab-ci.yml | YAML | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/.gitmodules | unknown | upstream Opus ancillary artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/AUTHORS | docs/text | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/CMakeLists.txt | CMake | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/COPYING | docs/text | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/ChangeLog | unknown | upstream Opus ancillary artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/LICENSE_PLEASE_READ.txt | docs/text | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/Makefile.am | makefile | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/Makefile.mips | makefile | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/Makefile.unix | makefile | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/NEWS | docs/text | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/README | docs/text | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/README.draft | draft | upstream Opus ancillary artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/autogen.bat | bat | upstream Opus ancillary artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/autogen.sh | shell | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/_kiss_fft_guts.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arch.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/arm2gnu.pl | Perl | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO,SCRIPT | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/arm_celt_map.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/armcpu.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/armcpu.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/armopts.s.in | assembly | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/celt_fft_ne10.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/celt_mdct_ne10.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/celt_neon_intr.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/celt_pitch_xcorr_arm.s | assembly | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/fft_arm.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/fixed_arm64.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/fixed_armv4.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/fixed_armv5e.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/kiss_fft_armv4.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/kiss_fft_armv5e.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/mdct_arm.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/meson.build | build | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/pitch_arm.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/arm/pitch_neon_intr.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/bands.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/bands.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/celt.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/celt.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/celt_decoder.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/celt_encoder.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/celt_lpc.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/celt_lpc.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/cpu_support.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/cwrs.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/cwrs.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/dump_modes/Makefile | makefile | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO,CONFIG | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/dump_modes/dump_modes.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/dump_modes/dump_modes_arch.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/dump_modes/dump_modes_arm_ne10.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/ecintrin.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/entcode.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/entcode.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/entdec.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/entdec.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/entenc.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/entenc.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/fixed_c5x.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/fixed_c6x.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/fixed_debug.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/fixed_generic.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/float_cast.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/kiss_fft.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/kiss_fft.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/laplace.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/laplace.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/mathops.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/mathops.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/mdct.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/mdct.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/meson.build | build | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/mfrngcod.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/mips/celt_mipsr1.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/mips/fixed_generic_mipsr1.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/mips/kiss_fft_mipsr1.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/mips/mdct_mipsr1.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/mips/pitch_mipsr1.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/mips/vq_mipsr1.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/modes.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/modes.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/opus_custom_demo.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/os_support.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/pitch.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/pitch.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/quant_bands.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/quant_bands.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/rate.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/rate.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/stack_alloc.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/static_modes_fixed.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/static_modes_fixed_arm_ne10.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/static_modes_float.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/static_modes_float_arm_ne10.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/tests/meson.build | build | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO,TEST | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/tests/test_unit_cwrs32.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO,TEST | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/tests/test_unit_dft.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO,TEST | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/tests/test_unit_entropy.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO,TEST | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/tests/test_unit_laplace.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO,TEST | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/tests/test_unit_mathops.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO,TEST | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/tests/test_unit_mdct.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO,TEST | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/tests/test_unit_rotation.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO,TEST | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/tests/test_unit_types.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO,TEST | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/vq.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/vq.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/x86/celt_lpc_sse.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/x86/celt_lpc_sse4_1.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/x86/pitch_avx.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/x86/pitch_sse.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/x86/pitch_sse.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/x86/pitch_sse2.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/x86/pitch_sse4_1.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/x86/vq_sse.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/x86/vq_sse2.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/x86/x86_arch_macros.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/x86/x86_celt_map.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/x86/x86cpu.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt/x86/x86cpu.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt_headers.mk | makefile | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/celt_sources.mk | makefile | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/cmake/CFeatureCheck.cmake | CMake | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/cmake/OpusBuildtype.cmake | CMake | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/cmake/OpusConfig.cmake | CMake | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/cmake/OpusConfig.cmake.in | in | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/cmake/OpusFunctions.cmake | CMake | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/cmake/OpusPackageVersion.cmake | CMake | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/cmake/OpusSources.cmake | CMake | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/cmake/README.md | docs/text | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/cmake/RunTest.cmake | CMake | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/cmake/config.h.cmake.in | in | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/cmake/cpu_info_by_asm.c | C | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/cmake/cpu_info_by_c.c | C | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/cmake/vla.c | C | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/configure.ac | ac | upstream Opus ancillary artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/LPCNet.yml | YAML | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/README | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/README.md | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/adaconvtest.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,TEST | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/arm/arm_dnn_map.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/arm/dnn_arm.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/arm/nnet_dotprod.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/arm/nnet_neon.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/burg.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/burg.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/common.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/datasets.txt | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/download_model.bat | bat | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/download_model.sh | shell | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/dred_coding.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/dred_coding.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/dred_config.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/dred_decoder.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/dred_decoder.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/dred_encoder.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/dred_encoder.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/dred_rdovae.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/dred_rdovae_dec.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/dred_rdovae_dec.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/dred_rdovae_enc.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/dred_rdovae_enc.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/dump_data.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/dump_lpcnet_tables.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/fargan.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/fargan.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/fargan_demo.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/freq.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/freq.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/fwgan.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/fwgan.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/kiss99.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/kiss99.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/lossgen.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/lossgen.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/lossgen_demo.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/lpcnet.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/lpcnet.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/lpcnet_enc.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/lpcnet_plc.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/lpcnet_private.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/lpcnet_tables.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/meson.build | build | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/nndsp.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/nndsp.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/nnet.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/nnet.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/nnet_arch.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/nnet_default.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/osce.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/osce.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/osce_config.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/osce_features.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/osce_features.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/osce_structs.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/parse_lpcnet_weights.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/pitchdnn.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/pitchdnn.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/tansig_table.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/test_vec.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,TEST | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/dnntools/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/dnntools/quantization/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/dnntools/quantization/softquant.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/dnntools/relegance/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/dnntools/relegance/meta_critic.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/dnntools/relegance/relegance.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/dnntools/sparsification/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/dnntools/sparsification/base_sparsifier.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/dnntools/sparsification/common.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/dnntools/sparsification/conv1d_sparsifier.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/dnntools/sparsification/conv_transpose1d_sparsifier.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/dnntools/sparsification/gru_sparsifier.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/dnntools/sparsification/linear_sparsifier.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/dnntools/sparsification/utils.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/requirements.txt | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/dnntools/setup.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/fargan/README.md | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/fargan/adv_train_fargan.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/fargan/dataset.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/fargan/dump_fargan_weights.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/fargan/fargan.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/fargan/filters.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/fargan/rc.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/fargan/stft_loss.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/fargan/test_fargan.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/fargan/train_fargan.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/fwgan/dump_model_weights.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/fwgan/inference.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/fwgan/models/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/fwgan/models/fwgan400.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/fwgan/models/fwgan500.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lossgen/README.md | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lossgen/export_lossgen.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lossgen/lossgen.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lossgen/process_data.sh | shell | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lossgen/test_lossgen.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lossgen/train_lossgen.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/README.md | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/add_dataset_config.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/data/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/data/lpcnet_dataset.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/engine/lpcnet_engine.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/make_default_setup.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/make_test_config.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/models/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/models/lpcnet.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/models/multi_rate_lpcnet.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/print_lpcnet_complexity.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/scripts/collect_multi_run_results.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/scripts/loop_run.sh | shell | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/scripts/make_animation.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/scripts/modify_dataset_target.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/scripts/multi_run.sh | shell | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/scripts/run_inference_test.sh | shell | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/scripts/update_checkpoints.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/scripts/update_output_folder.sh | shell | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/scripts/update_setups.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/test_lpcnet.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/train_lpcnet.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/data.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/endoscopy.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/layers/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/layers/dual_fc.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/layers/pcm_embeddings.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/layers/subconditioner.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/misc.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/pcm.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/sample.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/sparsification/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/sparsification/common.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/sparsification/gru_sparsifier.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/templates.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/ulaw.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/lpcnet/utils/wav.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/neural-pitch/README.md | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/neural-pitch/data_augmentation.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/neural-pitch/download_demand.sh | shell | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/neural-pitch/evaluation.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/neural-pitch/experiments.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/neural-pitch/export_neuralpitch_weights.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/neural-pitch/models.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/neural-pitch/neural_pitch_update.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/neural-pitch/ptdb_process.sh | shell | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/neural-pitch/run_crepe.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/neural-pitch/training.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/neural-pitch/utils.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/README.md | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/adv_train_model.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/adv_train_vocoder.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/create_testvectors.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/data/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/data/lpcnet_vocoding_dataset.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/data/silk_conversion_set.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/data/silk_enhancement_set.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/engine/engine.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/engine/vocoder_engine.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/export_model_weights.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/losses/stft_loss.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/make_default_setup.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/models/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/models/fd_discriminator.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/models/lace.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/models/lavoce.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/models/lavoce_400.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/models/lpcnet_feature_net.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/models/nns_base.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/models/no_lace.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/models/scale_embedding.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/models/shape_up_48.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/models/silk_feature_net.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/models/silk_feature_net_pl.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/requirements.txt | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/resources/training_files.txt | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/resources/validation_files.txt | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/evaluation/create_input_data.sh | shell | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/evaluation/env.rc | rc | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/evaluation/evaluate.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/evaluation/lace_loss_metric.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/evaluation/make_boxplots.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/evaluation/make_boxplots_moctest.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/evaluation/make_tables.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/evaluation/make_tables_moctest.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/evaluation/moc.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/evaluation/moc2.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/evaluation/process_dataset.sh | shell | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/evaluation/run_nomad.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/presentation/endoscopy.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/presentation/lace_demo.ipynb | notebook | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/presentation/linear_prediction.ipynb | notebook | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/presentation/playback.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/presentation/postfilter.ipynb | notebook | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/stndrd/presentation/spectrogram.ipynb | notebook | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/test_model.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/test_vocoder.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/train_model.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/train_vocoder.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/ada_conv.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/complexity.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/endoscopy.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/layers/limited_adaptive_comb1d.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/layers/limited_adaptive_conv1d.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/layers/noise_shaper.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/layers/pitch_auto_correlator.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/layers/silk_upsampler.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/layers/td_shaper.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/lpcnet_features.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/misc.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/moc.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/pitch.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/silk_features.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/softquant.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/spec.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/osce/utils/templates.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/plc/export_plc.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/plc/plc.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/plc/plc_dataset.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/plc/train_plc.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/rdovae/README.md | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/rdovae/export_rdovae_weights.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/rdovae/fec_encoder.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/rdovae/import_rdovae_weights.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/rdovae/packets/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/rdovae/packets/fec_packets.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/rdovae/packets/fec_packets.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/rdovae/packets/fec_packets.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/rdovae/rdovae/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/rdovae/rdovae/dataset.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/rdovae/rdovae/rdovae.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/rdovae/requirements.txt | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/rdovae/train_rdovae.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/testsuite/README.md | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/testsuite/examples/lpcnet_c_example.yml | YAML | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/testsuite/examples/lpcnet_c_plc_example.yml | YAML | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/testsuite/examples/lpcnet_torch_example.yml | YAML | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/testsuite/requirements.txt | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/testsuite/run_test.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/testsuite/utils/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/testsuite/utils/files.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/testsuite/utils/pesq.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/testsuite/utils/pitch.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/weight-exchange/README.md | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/weight-exchange/requirements.txt | docs/text | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/weight-exchange/setup.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/weight-exchange/wexchange/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/weight-exchange/wexchange/c_export/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/weight-exchange/wexchange/c_export/c_writer.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/weight-exchange/wexchange/c_export/common.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/weight-exchange/wexchange/tf/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/weight-exchange/wexchange/tf/tf.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/weight-exchange/wexchange/torch/__init__.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/torch/weight-exchange/wexchange/torch/torch.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/dataloader.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/decode_rdovae.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/diffembed.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/dump_lpcnet.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/dump_plc.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/dump_rdovae.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/encode_rdovae.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/fec_encoder.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/fec_packets.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/fec_packets.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/fec_packets.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/keraslayerdump.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/lossfuncs.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/lpcnet.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/lpcnet_plc.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/mdense.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/pade.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/parameters.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/plc_loader.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/rdovae.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/rdovae_exchange.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/rdovae_import.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/test_lpcnet.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/test_plc.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/tf_funcs.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/train_lpcnet.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/train_plc.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/train_rdovae.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/ulaw.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/training_tf2/uniform_noise.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/vec.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/vec_avx.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/vec_neon.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/write_lpcnet_weights.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/x86/dnn_x86.h | C header | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/x86/nnet_avx2.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/x86/nnet_sse2.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/x86/nnet_sse4_1.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/dnn/x86/x86_dnn_map.c | C | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/Doxyfile.in | in | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/Makefile.am | makefile | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,CONFIG,DOCS | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/build_draft.sh | shell | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,SCRIPT,DOCS | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/build_isobmff.sh | shell | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,SCRIPT,DOCS | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/build_oggdraft.sh | shell | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,SCRIPT,DOCS | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/customdoxygen.css | CSS | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/draft-ietf-codec-oggopus.xml | XML | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/draft-ietf-codec-opus-update.xml | XML | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/draft-ietf-codec-opus.xml | XML | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/draft-ietf-payload-rtp-opus.xml | XML | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/footer.html | html | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/header.html | html | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/meson.build | build | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/opus_in_isobmff.css | CSS | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/opus_in_isobmff.html | html | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/opus_logo.svg | SVG | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/opus_update.patch | patch | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/release.txt | docs/text | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/doc/trivial_example.c | C | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/include/meson.build | build | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/include/opus.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/include/opus_custom.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/include/opus_defines.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/include/opus_multistream.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/include/opus_projection.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/include/opus_types.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/lpcnet_headers.mk | makefile | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/lpcnet_sources.mk | makefile | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/m4/as-gcc-inline-assembly.m4 | m4 | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/m4/ax_add_fortify_source.m4 | m4 | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/m4/opus-intrinsics.m4 | m4 | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/meson.build | build | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/meson/README.md | docs/text | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/meson/get-version.py | Python | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/meson/read-sources-list.py | Python | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/meson_options.txt | docs/text | upstream Opus documentation/notice artifact | low/medium release-boundary relevance | AUDIO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/openlola_bridge/COpusBridge.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/openlola_bridge/include/COpusBridge.h | C header | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/opus-uninstalled.pc.in | in | upstream Opus ancillary artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/opus.m4 | m4 | upstream Opus ancillary artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/opus.pc.in | in | upstream Opus ancillary artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/opus_headers.mk | makefile | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/opus_sources.mk | makefile | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/releases.sha2 | sha2 | upstream Opus ancillary artifact | low/medium release-boundary relevance | AUDIO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/scripts/dump_rnn.py | Python | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/scripts/local_build.py | Python | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/scripts/rnn_train.py | Python | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/scripts/shrink_model.sh | shell | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/A2NLSF.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/API.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/CNG.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/HP_variable_cutoff.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/Inlines.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/LPC_analysis_filter.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/LPC_fit.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/LPC_inv_pred_gain.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/LP_variable_cutoff.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/MacroCount.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/MacroDebug.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/NLSF2A.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/NLSF_VQ.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/NLSF_VQ_weights_laroia.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/NLSF_decode.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/NLSF_del_dec_quant.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/NLSF_encode.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/NLSF_stabilize.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/NLSF_unpack.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/NSQ.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/NSQ.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/NSQ_del_dec.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/PLC.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/PLC.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/SigProc_FIX.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/VAD.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/VQ_WMat_EC.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/ana_filt_bank_1.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/arm/LPC_inv_pred_gain_arm.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/arm/LPC_inv_pred_gain_neon_intr.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/arm/NSQ_del_dec_arm.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/arm/NSQ_del_dec_neon_intr.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/arm/NSQ_neon.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/arm/NSQ_neon.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/arm/SigProc_FIX_armv4.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/arm/SigProc_FIX_armv5e.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/arm/arm_silk_map.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/arm/biquad_alt_arm.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/arm/biquad_alt_neon_intr.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/arm/macros_arm64.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/arm/macros_armv4.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/arm/macros_armv5e.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/biquad_alt.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/bwexpander.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/bwexpander_32.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/check_control_input.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/code_signs.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/control.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/control_SNR.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/control_audio_bandwidth.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/control_codec.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/debug.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/debug.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/dec_API.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/decode_core.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/decode_frame.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/decode_indices.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/decode_parameters.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/decode_pitch.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/decode_pulses.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/decoder_set_fs.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/define.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/enc_API.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/encode_indices.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/encode_pulses.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/errors.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/LTP_analysis_filter_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/LTP_scale_ctrl_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/apply_sine_window_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/arm/warped_autocorrelation_FIX_arm.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/arm/warped_autocorrelation_FIX_neon_intr.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/autocorr_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/burg_modified_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/corrMatrix_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/encode_frame_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/find_LPC_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/find_LTP_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/find_pitch_lags_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/find_pred_coefs_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/k2a_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/k2a_Q16_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/main_FIX.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/mips/noise_shape_analysis_FIX_mipsr1.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/mips/prefilter_FIX_mipsr1.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/mips/warped_autocorrelation_FIX_mipsr1.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/noise_shape_analysis_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/pitch_analysis_core_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/process_gains_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/regularize_correlations_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/residual_energy16_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/residual_energy_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/schur64_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/schur_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/structs_FIX.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/vector_ops_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/warped_autocorrelation_FIX.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/x86/burg_modified_FIX_sse4_1.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/fixed/x86/vector_ops_FIX_sse4_1.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/LPC_analysis_filter_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/LPC_inv_pred_gain_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/LTP_analysis_filter_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/LTP_scale_ctrl_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/SigProc_FLP.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/apply_sine_window_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/autocorrelation_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/burg_modified_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/bwexpander_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/corrMatrix_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/encode_frame_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/energy_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/find_LPC_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/find_LTP_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/find_pitch_lags_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/find_pred_coefs_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/inner_product_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/k2a_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/main_FLP.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/noise_shape_analysis_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/pitch_analysis_core_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/process_gains_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/regularize_correlations_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/residual_energy_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/scale_copy_vector_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/scale_vector_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/schur_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/sort_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/structs_FLP.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/warped_autocorrelation_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/wrappers_FLP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/float/x86/inner_product_FLP_avx2.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/gain_quant.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/init_decoder.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/init_encoder.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/inner_prod_aligned.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/interpolate.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/lin2log.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/log2lin.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/macros.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/main.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/meson.build | build | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/mips/NSQ_del_dec_mipsr1.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/mips/macros_mipsr1.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/mips/sigproc_fix_mipsr1.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/pitch_est_defines.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/pitch_est_tables.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/process_NLSFs.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/quant_LTP_gains.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/resampler.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/resampler_down2.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/resampler_down2_3.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/resampler_private.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/resampler_private_AR2.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/resampler_private_IIR_FIR.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/resampler_private_down_FIR.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/resampler_private_up2_HQ.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/resampler_rom.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/resampler_rom.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/resampler_structs.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/shell_coder.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/sigm_Q15.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/sort.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/stereo_LR_to_MS.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/stereo_MS_to_LR.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/stereo_decode_pred.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/stereo_encode_pred.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/stereo_find_predictor.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/stereo_quant_pred.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/structs.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/sum_sqr_shift.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/table_LSF_cos.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/tables.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/tables_LTP.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/tables_NLSF_CB_NB_MB.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/tables_NLSF_CB_WB.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/tables_gain.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/tables_other.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/tables_pitch_lag.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/tables_pulses_per_block.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/tests/meson.build | build | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO,TEST | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/tests/test_unit_LPC_inv_pred_gain.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO,TEST | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/tuning_parameters.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/typedef.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/x86/NSQ_del_dec_avx2.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/x86/NSQ_del_dec_sse4_1.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/x86/NSQ_sse4_1.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/x86/SigProc_FIX_sse.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/x86/VAD_sse4_1.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/x86/VQ_WMat_EC_sse4_1.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/x86/main_sse.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk/x86/x86_silk_map.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk_headers.mk | makefile | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/silk_sources.mk | makefile | upstream Opus build/config/script artifact | low/medium release-boundary relevance | AUDIO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/analysis.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/analysis.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/extensions.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/mapping_matrix.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/mapping_matrix.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/meson.build | build | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/mlp.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/mlp.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/mlp_data.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/opus.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/opus_compare.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/opus_decoder.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/opus_demo.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/opus_encoder.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/opus_multistream.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/opus_multistream_decoder.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/opus_multistream_encoder.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/opus_private.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/opus_projection_decoder.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/opus_projection_encoder.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/repacketizer.c | C | compiled COpus bridge/core source listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/repacketizer_demo.c | C | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/src/tansig_table.h | C header | upstream Opus source/header; may support compiled COpus target but not all files are listed in Package.swift | codec/reference boundary | CORE_RUNTIME,AUDIO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/tests/meson.build | build | upstream Opus test/fuzzer support, not semantically audited | low/medium release-boundary relevance | AUDIO,TEST | test | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/tests/opus_build_test.sh | shell | upstream Opus test/fuzzer support, not semantically audited | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/tests/opus_decode_fuzzer.c | C | upstream Opus test/fuzzer support, not semantically audited | low/medium release-boundary relevance | AUDIO,TEST | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/tests/opus_decode_fuzzer.options | options | upstream Opus test/fuzzer support, not semantically audited | low/medium release-boundary relevance | AUDIO,TEST | test | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/tests/opus_encode_regressions.c | C | upstream Opus test/fuzzer support, not semantically audited | low/medium release-boundary relevance | AUDIO,TEST | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/tests/random_config.sh | shell | upstream Opus test/fuzzer support, not semantically audited | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/tests/run_vectors.sh | shell | upstream Opus test/fuzzer support, not semantically audited | low/medium release-boundary relevance | AUDIO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/tests/test_opus_api.c | C | upstream Opus test/fuzzer support, not semantically audited | low/medium release-boundary relevance | AUDIO,TEST | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/tests/test_opus_common.h | C header | upstream Opus test/fuzzer support, not semantically audited | low/medium release-boundary relevance | AUDIO,TEST | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/tests/test_opus_decode.c | C | upstream Opus test/fuzzer support, not semantically audited | low/medium release-boundary relevance | AUDIO,TEST | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/tests/test_opus_dred.c | C | upstream Opus test/fuzzer support, not semantically audited | low/medium release-boundary relevance | AUDIO,TEST | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/tests/test_opus_encode.c | C | upstream Opus test/fuzzer support, not semantically audited | low/medium release-boundary relevance | AUDIO,TEST | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/tests/test_opus_extensions.c | C | upstream Opus test/fuzzer support, not semantically audited | low/medium release-boundary relevance | AUDIO,TEST | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/tests/test_opus_padding.c | C | upstream Opus test/fuzzer support, not semantically audited | low/medium release-boundary relevance | AUDIO,TEST | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/tests/test_opus_projection.c | C | upstream Opus test/fuzzer support, not semantically audited | low/medium release-boundary relevance | AUDIO,TEST | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/training/rnn_dump.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/training/rnn_train.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/opus-1.5.2/training/txt2hdf5.py | Python | upstream Opus DNN/training support, release-excluded candidate | low/medium release-boundary relevance | AUDIO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |

### JPEG XS Reference Inventory

Common inherited fields for every JPEG XS row unless the role column says otherwise: approximate purpose is the listed CJpegXSReference or upstream JPEG XS role; runtime relevance is video codec/reference boundary for target-member rows and release-boundary/noise for programs/extras; main symbols and imports were not extracted in this pass; immediate callers are Package.swift/OpenLola JPEG XS wrapper only for target-member/bridge rows; inspection is partial for target-member/bridge rows and not inspected for other upstream files; use status is used only for target-member rows, otherwise unclear.

| Path | Language/type | Role/purpose | Runtime relevance | Classification | Kind | Main functions/classes/components | Important imports/dependencies | Immediate callers or likely entrypoints | Used/unused/duplicated/deprecated/generated/unclear | Inspection | Risk | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Sources/xs_ref_sw_ed2/CMakeLists.txt | CMake | upstream JPEG XS docs/build/support artifact | low/medium release-boundary relevance | VIDEO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/LICENSE.md | docs/text | upstream JPEG XS docs/build/support artifact | low/medium release-boundary relevance | VIDEO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/README.md | docs/text | upstream JPEG XS docs/build/support artifact | low/medium release-boundary relevance | VIDEO,DOCS | docs | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | low | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/extras/selftest_part4.sh | shell | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO,TEST,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/extras/validate_part4.sh | shell | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO,SCRIPT | script | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/CMakeLists.txt | CMake | upstream JPEG XS docs/build/support artifact | low/medium release-boundary relevance | VIDEO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/public/libjxs.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/public/open_lola_jxs_bridge.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/bitpacking.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/bitpacking.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/budget.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/budget.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/buf_mgmt.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/buf_mgmt.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/common.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/data_budget.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/data_budget.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/dwt.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/dwt.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/gcli_budget.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/gcli_budget.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/gcli_methods.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/gcli_methods.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/ids.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/ids.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/image.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/mct.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/mct.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/msbpack.c | C | upstream JPEG XS ancillary artifact | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/msbpack.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/nlt.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/nlt.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/open_lola_jxs_bridge.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/packing.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/packing.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/precinct.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/precinct.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/precinct_budget.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/precinct_budget.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/precinct_budget_table.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/precinct_budget_table.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/pred.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/pred.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/predbuffer.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/predbuffer.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/quant.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/quant.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/rate_control.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/rate_control.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/sb_weighting.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/sb_weighting.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/sig_flags.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/sig_flags.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/sigbuffer.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/sigbuffer.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/version.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/version.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/xs_config.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/xs_config.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/xs_config_parser.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/xs_dec.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/xs_enc.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/xs_gains.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/xs_markers.c | C | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/libjxs/src/xs_markers.h | C header | CJpegXSReference target member or public/header support | codec/reference boundary | CORE_RUNTIME,VIDEO | production | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | used | partially inspected | high | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/CMakeLists.txt | CMake | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO,CONFIG | config | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/cmdline_options.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/cmdline_options.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/argb.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/argb.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/helpers.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/helpers.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/mono.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/mono.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/pgx.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/pgx.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/planar.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/planar.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/ppm.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/ppm.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/rgb16.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/rgb16.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/uyvy8.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/uyvy8.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/v210.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/v210.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/yuv16.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/converters/yuv16.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/exports.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/file_io.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/file_io.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/file_sequence.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/file_sequence.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/image_open.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/image_open.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/xs_dec_main.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/programs/xs_enc_main.c | C | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
| Sources/xs_ref_sw_ed2/std/getopt.h | C header | upstream JPEG XS program/test/support artifact, not product runtime target | low/medium release-boundary relevance | VIDEO | unknown | not extracted in this pass | not extracted in this pass | Package.swift target if compiled; otherwise none known | unclear | not inspected | medium | listed from direct file inventory; vendored source not semantically audited |
## 25. Runtime Path Mapping

These path maps are evidence-backed from direct inspection and rg lookups in this pass, but remain partial. They are not proof that every edge case or caller is covered.

### Audio Input Path

1. Operator/CLI configuration enters through Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift or the app settings/surface files under Sources/open-lola-app and Sources/OpenLolaCore/Platform.
2. Direct AV runtime setup enters Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift.
3. CoreAudio device inventory is captured with CoreAudioInventoryReader in DirectPeerSessionAVSocketRunner.swift.
4. Realtime input capture is owned by Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift and callbacks in DirectPeerRealtimeAudioGraphCallbacks.swift.
5. captureInput copies mapped input and pushes payloads into DirectPeerAudioPayloadRing.
6. runAudioTXLoop in DirectPeerSessionAVAudioLoops.swift drains captured payloads for packetization/send.

### Audio Output Path

1. UDP/audio packets are received by DirectPeerSessionAVSocketRunner.swift through Direct P2P media runner methods.
2. runAudioRXLoop in DirectPeerSessionAVAudioLoops.swift decodes/reassembles UdpPcmV2Packet payloads with DirectPeerOpenLolaRawAudioReassemblyState.receive.
3. Accepted audio blocks are submitted to DirectPeerRealtimeAudioGraph for scheduled playout.
4. renderPlayout in DirectPeerRealtimeAudioGraph.swift drops stale payloads, copies due payloads, and writes the output AudioBufferList from the playout ring.
5. RX buffering policy and metrics are represented through DirectPeerRealtimeAudioGraphRxBuffering.swift and Sources/OpenLolaCore/Timing/RxBuffering.swift.

### Packet Send Path

1. CLI/app command surfaces build a Direct P2P run configuration.
2. DirectPeerSessionAVSocketRunner.swift binds audio/video/metrics/control sockets and invokes runAudioTXLoop.
3. runAudioTXLoop packetizes captured audio blocks into UDP PCM V2 packet data.
4. Video TX path is coordinated by DirectPeerSessionAVVideoLoops.swift and video transport packet types under Sources/OpenLolaCore/Video.
5. UdpMediaTransport.swift and UDP PCM helpers provide packet encode/send/metrics behavior for lower-level UDP routes.

### Packet Receive Path

1. UDP receive surfaces are in UdpMediaTransport.swift, DirectPeerSessionAVSocketRunner.swift, DirectPeerSessionAVAudioLoops.swift, and DirectPeerSessionAVVideoLoops.swift.
2. Audio receive decodes UdpPcmV2Packet, reassembles raw audio fragments, and passes valid blocks toward playout.
3. Video receive decodes media packets, receives raw fragments through VideoTransportReassembly.swift, and submits renderable frames to VideoOutputRenderer.swift or Direct P2P report support.
4. Metrics for loss/reorder/duplicate/late behavior are spread across UDP transport metrics, RX buffer metrics, Direct P2P runtime metrics, and report validators.

### TX Lifecycle

1. CLI/app builds command arguments and runtime configuration.
2. PeerSessionRunner begins handshake, creates proposals, accepts/records configuration, and startMedia emits mediaStart.
3. DirectPeerSessionAVSocketRunner starts audio graph/inventory/socket loops.
4. TX loop drains capture payloads and sends audio/video packets until deadline, stop, error, or shutdown.
5. Reports are built by DirectPeerSessionAVReportBuilder.swift and DirectPeerSessionReport.swift.

### RX Lifecycle

1. PeerSessionRunner handles capabilities/proposal/accept/mediaStart control state.
2. DirectPeerSessionAVSocketRunner starts receive loops.
3. Audio RX reassembly and video RX reassembly convert packets/fragments into playout/output candidates.
4. Runtime metrics and proof artifacts are emitted through DirectPeerSessionAVRuntimeReport.swift, DirectPeerSessionReceiveProofArtifact.swift, DirectPeerSessionReport.swift, and validation helpers.

### Local RX Path

1. Local loopback and playout surfaces appear in AudioLoopbackRun.swift, AudioLoopbackHelpers.swift, DirectPeerRealtimeAudioGraph.swift, DirectPeerRealtimeAudioGraphRxBuffering.swift, and RxBuffering.swift.
2. Captured or received payloads are scheduled into playout rings.
3. renderPlayout handles local output timing and drop/underrun accounting.
4. Local RX remains only partially audited; device/output hardware behavior was not run.

### Video Capture Path

1. Video capture CLI/app configuration feeds VideoCaptureRunConfiguration.swift.
2. AVFoundationVideoCaptureRunner in VideoCaptureRunner.swift selects AVFoundation device/format, configures capture session, collects sample buffers, and writes VideoCaptureReport.
3. VideoCaptureReport.swift validates capture metrics, production hardware evidence, raw capture, CPU/memory, and audio-impact metrics.
4. App preview capture/metering uses AppReceiverPreviewServices.swift.

### Video Receive/Render Path

1. DirectPeerSessionAVVideoLoops.swift receives decoded video media packets and handles deferred frame timing.
2. VideoTransportReassembly.swift reassembles fragments into raw frames.
3. VideoOutputRenderer.swift queues, drops, and renders frames based on deadlines and backend kind.
4. BlackmagicOutputBoundary.swift and RawBGRAAppKitPreviewWindow.swift are output/preview boundary files needing deeper audit.

### Control-Message Path

1. SessionControlMessage.swift defines capabilities, sessionPropose, sessionAccept, sessionReject, audioMetadata, mediaStart, mediaPause, metrics, error, and shutdown messages plus state-machine transitions.
2. PeerSessionRunner.swift sends/receives control messages and applies transitions.
3. DirectPeerSessionAVControlService.swift drains Direct AV control messages during runtime.
4. Connector-specific control paths include LoLaCompatibilityControlSocket.swift, LoLaControlExchangeRuntime.swift, LoLaTcpControlExchangeRuntime.swift, UltraGridControl.swift, JackTripTCPHandshake.swift, and NMP workflow files.

### UI-to-Runtime State Path

1. SwiftUI entry is OpenLolaApp.swift and OpenLolaAppMain.swift.
2. AppSettings.swift, AppShellStoredDefaults.swift, AppShellSettingsTabs.swift, and AppLocalOperatorSurfaceView.swift collect operator choices.
3. NativeAppShellOperatorState.swift, NativeAppShellDirectPeerCommand.swift, NativeAppShellSessionMode.swift, NativeAppShellExecution.swift, and NativeAppShellSurfaceContract.swift map UI state to command/runtime contracts.
4. AppExecutionController.swift launches/validates commands and updates phase/report paths.
5. AppRuntimeEvidenceScope.swift, AppSessionStateBanner.swift, AppConsoleModels.swift, AppTransportView.swift, and AppConsoleChromeView.swift map runtime evidence back into operator-facing labels and controls.

### Startup/Shutdown Path

1. CLI startup runs through Sources/open-lola/main.swift; app startup runs through OpenLolaAppMain.swift and OpenLolaApp.swift.
2. Direct P2P startup runs through PeerSessionRunner.beginHandshake, makeSessionProposal/respondToSessionProposal, sessionAccept, and startMedia.
3. Direct AV startup constructs sockets/audio graph/video sources in DirectPeerSessionAVSocketRunner.swift.
4. Shutdown flows through PeerSessionRunner.shutdown, SessionControlMessage.shutdown, DirectPeerSessionAVControlService, socket close paths, audio graph stop/cleanup, and report teardown.
5. Cleanup/shutdown is high-risk and only partially inspected.

## 26. File Risk Buckets Added By This Coverage Pass

### Files Most Likely To Contain P0/P1 Runtime Risks

- Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift
- Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphCallbacks.swift
- Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift
- Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift
- Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineReportValidation.swift
- Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift
- Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift
- Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift
- Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVVideoLoops.swift
- Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift
- Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift
- Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift
- Sources/OpenLolaCore/Video/VideoCaptureRunner.swift
- Sources/OpenLolaCore/Video/VideoCaptureReport.swift
- Sources/OpenLolaCore/Video/VideoTransportReassembly.swift
- Sources/OpenLolaCore/Video/VideoOutputRenderer.swift
- Sources/OpenLolaCore/Protocol/SessionControlMessage.swift
- Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift
- Sources/OpenLolaCore/Connectors/Core/ExternalConnectorReport.swift
- Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeRuntime.swift
- Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaLive.swift
- Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaSocket.swift
- Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibilityRunner.swift
- Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridRTPPacketCodec.swift
- Sources/OpenLolaCore/Connectors/JackTrip/JackTripPassValidation.swift
- Sources/OpenLolaCore/Release/FieldReadyRuntimeProof.swift
- Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift
- Sources/open-lola-app/AppExecutionController.swift
- Sources/open-lola-app/AppRuntimeEvidenceScope.swift
- Sources/open-lola-app/AppSessionStateBanner.swift

### Files Most Likely To Be Dead Code Or Stale Compatibility

- Sources/OpenLolaCore/Evidence/MeasurementReport.swift
- Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift, only if MeasurementReport has no active non-test/report-contract consumer.
- Sources/.DS_Store
- Sources/COpenLolaAtomics/.DS_Store
- Upstream Opus DNN/training/test/demo files under Sources/opus-1.5.2 that are not listed in the COpus Package.swift source list.
- Upstream JPEG XS programs/extras/std files under Sources/xs_ref_sw_ed2 outside the CJpegXSReference target path.
- Any source inventory row marked not inspected plus unclear use in the vendored inventory below.

### Files Most Likely To Contain Slop Or Boilerplate

- Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReportValidation.swift
- Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReportValidation.swift
- Sources/OpenLolaCore/Timing/LatencyTuningReportValidation.swift
- Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift
- Sources/open-lola/Commands/Network/DirectP2PSessionRunArgumentSupport.swift
- Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift
- Sources/open-lola-app/AppShellSettingsTabs.swift
- Sources/open-lola-app/AppShellSettingsView.swift
- Sources/open-lola-app/AppConsoleModels.swift
- Sources/open-lola-app/AppDesignSystem.swift

### Files Requiring Deeper Audit

- Every file listed under Files Most Likely To Contain P0/P1 Runtime Risks.
- Every file in Sources/OpenLolaCore/Audio/MADI.
- Every file in Sources/OpenLolaCore/Connectors/LoLa, Sources/OpenLolaCore/Connectors/UltraGrid, and Sources/OpenLolaCore/Connectors/JackTrip.
- Every file in Sources/OpenLolaCore/Network/NAT and Sources/OpenLolaCore/Network/RTP.
- Every report validator under Sources/OpenLolaCore that can emit or validate PASS.
- Every app state file under Sources/open-lola-app that renders Live, Ready, Armed, PASS, connected, healthy, or unavailable language.
- All C bridge/public header files in COpenLolaAtomics, COpus, and CJpegXSReference.

### Files That Should Not Be Touched Without Stronger Verification

- Sources/COpenLolaAtomics/OpenLolaAtomics.c
- Sources/COpenLolaAtomics/include/OpenLolaAtomics.h
- Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift
- Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphCallbacks.swift
- Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift
- Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift
- Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift
- Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift
- Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift
- Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift
- Sources/OpenLolaCore/Protocol/SessionControlMessage.swift
- Sources/OpenLolaCore/Video/VideoTransportPacket.swift
- Sources/OpenLolaCore/Video/VideoTransportReassembly.swift
- Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityWireFrame.swift
- Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaCodec.swift
- Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridRTPPacketCodec.swift
- Sources/opus-1.5.2/openlola_bridge/COpusBridge.c
- Sources/opus-1.5.2/openlola_bridge/include/COpusBridge.h
- Sources/xs_ref_sw_ed2/libjxs/public/open_lola_jxs_bridge.h
- Sources/xs_ref_sw_ed2/libjxs/src/open_lola_jxs_bridge.c

### Coverage Gaps And Uncertainty

- This pass accounts for every file under Sources, but most rows are metadata/declaration scans, not full semantic inspections.
- Vendored/reference trees are listed exhaustively but not semantically audited file by file.
- Immediate callers are only recorded where obvious from entrypoint structure or package target membership; full call graph was not built.
- Used/unused status is conservative. Most first-party production files remain unclear until call graph, CLI inventory, app shell inventory, report inventory, and tests are cross-checked.
- Generated, docs, config, and upstream helper files under Sources are listed because they are under the requested source tree, but many are not product runtime source.
- Runtime path maps are partial and evidence-backed from direct inspection/rg, not complete proof.

## 27. High-Risk Runtime Behavior Audit Pass

Date: 2026-05-20.

Scope of this continuation pass: real-time Core Audio callback surfaces, audio device start/stop, audio rings and RX buffer reporting, Direct P2P setup/lifecycle, UDP media send/receive, Direct AV TX/RX loops, local RX proof paths, video capture/reassembly/preview, control-message service paths, runtime state transitions, shutdown/cleanup, app runtime evidence mapping, and UI start/live state. This is still not full semantic coverage of every runtime source file.

### Runtime Path Coverage Notes

| Area | Inspected evidence | Current audit status |
| --- | --- | --- |
| Real-time audio path | DirectPeerRealtimeAudioGraphCallbacks.swift; DirectPeerRealtimeAudioGraph.swift; DirectPeerAudioPayloadRing.swift | Findings HRA-AUDIO-01, HRA-AUDIO-02; no heap allocation found inside graph callback setup itself, but bounded scans/copies need timing proof. |
| Audio device input/output | DirectPeerRealtimeAudioGraph.swift start/stop/configure/restore paths | Finding HRA-AUDIO-03; start failures throw after cleanup, but cleanup failure semantics need stronger recovery proof. |
| Audio buffering | DirectPeerAudioPayloadRing.swift; RxBuffering.swift; RealtimeAudioPacketHandoff.swift; RealtimeAudioEngineReportValidation.swift | Findings HRA-AUDIO-04, HRA-AUDIO-05; ring capacity is bounded, but PASS gates miss some RX buffer counters. |
| UDP networking | UdpMediaTransport.swift; PeerSessionRunnerMediaIO.swift | Findings HRA-P2P-07, HRA-P2P-08; no unbounded recent-sequence queue found, recent sequence storage is capped at 256. |
| P2P setup | PeerSessionRunner.swift; DirectPeerSessionAVSocketRunner.swift; SessionControlMessage.swift | Finding HRA-P2P-01; AV initiator validates accepted audio/video after receiving sessionAccept, but base runner accepts configuration first. |
| P2P reconnect/disconnect | PeerSessionRunner.beginRecovery/restartMedia/shutdown; DirectPeerSessionAVControlService | Findings HRA-P2P-02, HRA-P2P-03; recovery path was only partially inspected. |
| Packet send path | runAudioTXLoop; PeerSessionRunnerMediaIO; UdpMediaTransport.send | Finding HRA-P2P-05; UdpMediaTransport send is synchronized and encoded outside the lock, but TX drain has no per-loop budget. |
| Packet receive path | runAudioRXLoop; runVideoRXLoop; UdpMediaTransport.receiveDecoded | Findings HRA-P2P-04, HRA-P2P-06, HRA-P2P-07. |
| Local RX path | DirectP2PLocalhostSmoke; DirectPeerTwoPeerLocalRunReport; DirectP2PTwoPeerLocalRunCommandSupport | No finding with current evidence: localhost reports stay partial, and two-peer local-run PASS requires collected peer reports and RX proofs. |
| TX path | DirectPeerSessionAVSocketRunner main loop; runAudioTXLoop; sendRawVideoFrame | Finding HRA-P2P-05; video TX send is packetized through bounded raw-video budget validation for raw mode. |
| RX path | runAudioRXLoop; runVideoRXLoop; VideoFrameReassembler | Findings HRA-P2P-04, HRA-P2P-06, HRA-VIDEO-02; reassembler itself is bounded. |
| Video capture path | VideoCaptureRunner; VideoCaptureAVFoundation; VideoCaptureReport | Findings HRA-VIDEO-01, HRA-VIDEO-03. |
| Video frame handling | VideoTransportReassembly; VideoOutputRenderer; DirectPeerSessionAVVideoLoops | Findings HRA-VIDEO-02; no unbounded active-frame reassembly queue found. |
| Video transmit/receive path | sendRawVideoFrame; runVideoRXLoop; DirectPeerSessionAVSocketRunner | Findings HRA-P2P-07, HRA-VIDEO-02. |
| Control-message path | DirectPeerSessionControlSocket; DirectPeerSessionAVControlService; SessionControlMessage; PeerSessionRunner | Findings HRA-P2P-02, HRA-P2P-03, HRA-P2P-09. |
| Runtime state machines | SessionStateMachine; PeerSessionRunner lifecycle state | Findings HRA-P2P-01, HRA-P2P-02, HRA-P2P-03. |
| Timing and clock behavior | Core Audio host-time conversion; AES67 host-time mapper; AV loop deadlines | Finding HRA-AUDIO-01; AES67 mapper overflow is counted as dropped before playout in inspected code. |
| Packet loss, jitter, reordering, duplication | UdpMediaTransport metrics; RealtimeAudioPacketHandoff receive sequence; VideoFrameReassembler metrics | Findings HRA-AUDIO-04, HRA-P2P-08; UdpMediaTransport recent duplicate tracking is capped. |
| Threading/concurrency | Core Audio callbacks; NSLock-wrapped runtime handoff; video collector locks | Finding HRA-AUDIO-05; video collector has lock coverage but unbounded timestamp arrays. |
| Shutdown/cleanup | PeerSessionRunner.shutdown; DirectPeerRealtimeAudioGraph.stop; AV loop defer cleanup | Findings HRA-AUDIO-03, HRA-VIDEO-02. |
| Error propagation/logging | DirectPeerAVMetricsService; DirectPeerAVControlService; raw audio RX error recovery | Findings HRA-P2P-06, HRA-P2P-09, HRA-ERR-01. |
| UI-reported runtime state | AppRuntimeEvidenceScope; AppExecutionController; AppSessionStateBanner; AppTransportView; AppConsoleModels | Finding HRA-UI-01; no finding with current evidence for false Live state because Live requires validated runtime evidence. |

### Audio Findings

- ID: HRA-AUDIO-01
- Severity: P1
- Category: Silent callback failure / timing
- Subsystem: Audio
- File: Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphCallbacks.swift
- Line range or symbol: directPeerRealtimeAudioIOProc lines 97-100; directPeerRealtimeAudioInputIOProc lines 125-128; nanosecondsFromHostTime lines 76-80
- Exact evidence: Host-time multiplication overflow returns nil; both input and full-duplex callbacks return noErr without calling graph.processIO/processInputIO or incrementing a runtime counter.
- Why this can fail at runtime: A dropped callback block is reported to Core Audio as successful, so capture/playout continuity can be lost without any callback miss, drop, or clock-skew metric.
- Failure mode: silent, latency/jitter, data loss
- Suggested remediation: Add a callback-safe overflow counter and deterministic silence/output handling, and surface the counter in runtime reports and PASS validation.
- Required verification: Host-time overflow unit/harness test plus a callback-path report validation test that rejects nonzero host-time conversion failures.
- Suggested regression or harness test: Inject a graph timebase/hostTime pair that overflows and assert the callback records the fault, preserves output safety, and prevents PASS.
- Confidence: high

- ID: HRA-AUDIO-02
- Severity: P2
- Category: Real-time callback bounded workload / measurement gap
- Subsystem: Audio
- File: Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift; Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift
- Line range or symbol: renderPlayout lines 603-628; copyPayload lines 195-225; dropPayloads(before:) lines 261-281
- Exact evidence: The output callback calls dropPayloads(before:) and copyPayload(startFrame:), both of which scan read..<write, then clears/copies output buffers. The ring is capacity-bounded, but no inspected code records callback duration for this work.
- Why this can fail at runtime: Even bounded per-callback scans and full-buffer copies can exceed a 32-frame deadline under high channel counts, stale payload buildup, or device buffer pressure.
- Failure mode: latency/jitter, visible audio underruns
- Suggested remediation: Add callback-duration instrumentation or a synthetic Core Audio harness before changing implementation; only optimize if measured p99/max exceeds callback budget.
- Required verification: Stress harness with max channels, full playout ring, stale payloads, and 32-frame buffers.
- Suggested regression or harness test: Deterministic callback benchmark that asserts p99/max callback duration stays below one callback period and reports overruns.
- Confidence: medium

- ID: HRA-AUDIO-03
- Severity: P2
- Category: Cleanup/shutdown
- Subsystem: Audio
- File: Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift
- Line range or symbol: stopUnlocked lines 283-371
- Exact evidence: stopUnlocked records stop/destroy/restore failures, stores latestCleanupResult, then clears input/output IOProc IDs, device IDs, and original sample-rate/frame-size values unconditionally at lines 362-370.
- Why this can fail at runtime: If stop, destroy, or restore fails, the object loses retry-relevant handles/state, making a subsequent recovery or accurate operator diagnosis harder.
- Failure mode: visible, hidden cleanup failure
- Suggested remediation: Preserve enough failed cleanup state for retry/diagnostics or make cleanup failure terminal and reportable before clearing handles.
- Required verification: Inject stop/destroy/restore failures and assert retry/diagnostic behavior is deterministic.
- Suggested regression or harness test: Mock Core Audio property setters and IOProc destroy calls to fail, then verify cleanup result, retained failure details, and no false clean shutdown report.
- Confidence: high

- ID: HRA-AUDIO-04
- Severity: P1
- Category: False success / missing validation
- Subsystem: Audio
- File: Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineReportValidation.swift; Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift
- Line range or symbol: validatePassRuntime lines 216-230; validatePassRxBufferPolicy lines 266-304; renderCallback lines 269-276; recordReceiveSequence lines 319-345
- Exact evidence: RealtimeAudioPacketHandoff increments rxBuffer.underruns, lostPackets, duplicatePackets, and reorderedPackets. The PASS validator checks handoff drops, callback misses, and hidden growth, but validatePassRxBufferPolicy only checks policy/target/bounds/hiddenGrowth, not rxBuffer loss, duplicate, reorder, or underrun counters.
- Why this can fail at runtime: A report can preserve packet-order/loss evidence while the PASS gate ignores it, creating false confidence in runtime stability.
- Failure mode: silent, false success, data loss, latency/jitter
- Suggested remediation: Treat nonzero rxBuffer loss, duplicate, reorder, underrun, overrun, and PLC counters as PASS blockers or explicitly justified degradation counters.
- Required verification: Validator fixture with nonzero rxBuffer counters must fail PASS.
- Suggested regression or harness test: Build a RealtimeAudioEngineReport fixture with otherwise valid PASS data and rxBuffer.lostPackets = 1, then assert validation fails with a specific error.
- Confidence: high

- ID: HRA-AUDIO-05
- Severity: P2
- Category: Threading/concurrency boundary
- Subsystem: Audio
- File: Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift
- Line range or symbol: RealtimeAudioPacketHandoffRuntime lines 416-440
- Exact evidence: RealtimeAudioPacketHandoffRuntime wraps receive, renderCallback, and metricsSnapshot in a shared NSLock; renderCallback takes that lock at lines 430-433.
- Why this can fail at runtime: If this runtime wrapper is used from a real Core Audio callback, the callback can block behind receive or metricsSnapshot work.
- Failure mode: latency/jitter, visible audio underruns, potential deadlock
- Suggested remediation: Prove this wrapper is not used on the real callback path, or replace callback use with lock-free/preallocated handoff semantics.
- Required verification: Call graph audit plus a callback-thread harness that fails if renderCallback can block.
- Suggested regression or harness test: Concurrent receive/metricsSnapshot contention test with callback-deadline assertions, plus a source-level test documenting that DirectPeerRealtimeAudioGraph does not use this wrapper in IOProc.
- Confidence: medium

### UDP/P2P Findings

- ID: HRA-P2P-01
- Severity: P1
- Category: Invalid state/config transition
- Subsystem: UDP/P2P
- File: Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift; Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift
- Line range or symbol: receiveControlMessage(.sessionAccept) lines 401-407; validateAcceptedAudioStream/videoStream lines 150-186 and 226-231
- Exact evidence: Base PeerSessionRunner accepts a sessionAccept by applying the transition, assigning acceptedConfiguration, and setting state = configured. The Direct AV initiator later validates accepted audio/video streams, but the validation is not part of the base sessionAccept transition.
- Why this can fail at runtime: Non-AV or future callers can accept mutated remote media endpoints, streams, or MTU values before compatibility validation, producing wrong socket targets or payload assumptions.
- Failure mode: visible, silent wrong media routing, invalid state transition
- Suggested remediation: Move accepted-configuration validation into the sessionAccept transition or require a proposal-bound validator before acceptedConfiguration is assigned.
- Required verification: Mutated sessionAccept tests for base runner and AV runner.
- Suggested regression or harness test: Initiator proposes one stream/endpoint, receives sessionAccept with mismatched endpoint/payload type, and must reject before state becomes configured.
- Confidence: high

- ID: HRA-P2P-02
- Severity: P1
- Category: Invalid shutdown transition
- Subsystem: UDP/P2P
- File: Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift; Sources/OpenLolaCore/Protocol/SessionControlMessage.swift
- Line range or symbol: SessionShutdown.sessionID lines 91-98; SessionStateMachine.apply(.shutdown) lines 262-264; receiveControlMessage(.shutdown) lines 424-431; acceptsShutdownSessionID lines 474-479
- Exact evidence: SessionShutdown.sessionID is optional. The state machine moves to stopped for shutdown without an allowedFrom guard. PeerSessionRunner accepts nil shutdown when no acceptedConfiguration exists and then closes transports and sets state = closed.
- Why this can fail at runtime: A pre-session nil shutdown can abort setup before session identity is established.
- Failure mode: visible disconnect, invalid state transition
- Suggested remediation: Require a bound session ID after proposal, and restrict shutdown transitions to accepted/running/recovering states unless explicitly local.
- Required verification: Control-state tests for nil-session shutdown before and after proposal.
- Suggested regression or harness test: Deliver shutdown(sessionID: nil) during hello/capabilities/proposed states and assert it is rejected and transports remain open.
- Confidence: high

- ID: HRA-P2P-03
- Severity: P1
- Category: Invalid error transition / remote abort
- Subsystem: UDP/P2P
- File: Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift; Sources/OpenLolaCore/Protocol/SessionControlMessage.swift
- Line range or symbol: SessionError.sessionID lines 80-88; receiveControlMessage(.error) lines 449-458; acceptsErrorSessionID lines 481-486
- Exact evidence: acceptsErrorSessionID returns true whenever acceptedConfiguration is nil. A fatal error message then closes media transports and sets state = failed.
- Why this can fail at runtime: A nil-session or wrong-session error can fail a handshake before a session is bound, and fatal errors can close transports without proving they belong to the active session.
- Failure mode: visible disconnect, invalid state transition
- Suggested remediation: Require peer/session correlation for error messages once peer identity is known; treat pre-session errors as diagnostic unless they match the active handshake peer.
- Required verification: Control-message tests for nil/wrong session error in idle/handshaking/proposed/configured/running states.
- Suggested regression or harness test: Deliver fatal error(sessionID: nil) during handshaking and assert state does not become failed unless policy explicitly permits it.
- Confidence: high

- ID: HRA-P2P-04
- Severity: P1
- Category: Unbounded per-deadline packet storage
- Subsystem: UDP/P2P
- File: Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift
- Line range or symbol: DirectPeerOpenLolaRawAudioReassemblyState lines 111-146; DirectPeerOpenLolaRawAudioPendingDeadline lines 182-184
- Exact evidence: pendingDeadlines is capped at 8, but each pending deadline stores packets in an Array and receive appends every packet before reassembly. validateFragmentCount only checks packet.header.fragmentCount <= maxFragmentCount.
- Why this can fail at runtime: A duplicate-fragment flood for the same deadline can grow one bucket without a per-bucket packet cap, causing memory and CPU growth in RX.
- Failure mode: latency/jitter, memory growth, data loss
- Suggested remediation: Bound packets per deadline by fragmentCount or maxFragmentCount, reject duplicates before append, and count duplicate/oversize drops.
- Required verification: Fragment-flood simulation with repeated same deadline/fragment.
- Suggested regression or harness test: Feed thousands of duplicate fragments for one deadline and assert memory/count remains bounded and duplicate drop metrics increase.
- Confidence: high

- ID: HRA-P2P-05
- Severity: P1
- Category: TX fairness / per-loop allocation
- Subsystem: TX
- File: Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift
- Line range or symbol: runAudioTXLoop lines 16-31 and 34-71
- Exact evidence: Opus TX creates Data(opusEncodeScratch.prefix(encodedByteCount)) for every encoded packet, and the loop drains captured payloads until empty with no max-packet or time budget.
- Why this can fail at runtime: A capture backlog can monopolize the Direct AV loop, delaying RX, control, video, metrics, and socket waits; Opus mode adds per-packet heap/copy work in the TX path.
- Failure mode: latency/jitter, control lag, visible media degradation
- Suggested remediation: Add a per-iteration TX budget and avoid per-packet heap allocation where possible; preserve drop/backpressure metrics.
- Required verification: Backlog stress test covering raw, Opus, and AES67 transports.
- Suggested regression or harness test: Preload capture ring above budget and assert one AV loop iteration sends at most N payloads while RX/control still run.
- Confidence: high

- ID: HRA-P2P-06
- Severity: P1
- Category: Hidden invalid runtime state
- Subsystem: RX
- File: Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift; Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerMediaIO.swift
- Line range or symbol: runAudioRXLoop catch lines 246-252; isRecoverableOpenLolaRawAudioReceiveError lines 362-378; recordReceivedAudioOrTiming lines 292-307
- Exact evidence: recordReceivedAudioOrTiming throws missingAudioRouter when audioRouter is nil. runAudioRXLoop treats missingAudioRouter, missingAudioStream, and unsupportedControlMessage as recoverable raw-audio receive errors, increments droppedBeforePlayout, and continues.
- Why this can fail at runtime: Internal state/configuration defects can be converted into ordinary packet drops, hiding invalid state while the session keeps running.
- Failure mode: silent, data loss, false partial success
- Suggested remediation: Separate malformed network datagrams from internal state errors; make missing router/stream fatal or explicit runtime-error counters.
- Required verification: RX loop tests for malformed UDP versus missingAudioRouter/missingAudioStream.
- Suggested regression or harness test: Force audioRouter nil while receiving audioPcmV2 and assert the session fails loudly instead of only increasing droppedBeforePlayout.
- Confidence: high

- ID: HRA-P2P-07
- Severity: P2
- Category: Silent unexpected payload
- Subsystem: RX
- File: Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift; Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVVideoLoops.swift
- Line range or symbol: audio payload-type guards lines 255-256 and 290-292; video payload-type guard lines 93-96
- Exact evidence: Audio and video RX loops continue on payload-type mismatch without incrementing dropped/corrupt/unexpected counters.
- Why this can fail at runtime: Foreign or misrouted payloads consume receive budget but disappear from runtime evidence, masking wrong sockets, wrong negotiated payload types, or cross-stream contamination.
- Failure mode: silent, data loss, false diagnostics
- Suggested remediation: Add unexpectedPayloadType counters and include them in report validation/diagnostics.
- Required verification: Mixed-payload socket simulation.
- Suggested regression or harness test: Feed video payloads into audio RX and audio payloads into video RX and assert unexpected-payload metrics increase.
- Confidence: high

- ID: HRA-P2P-08
- Severity: P1
- Category: False success / weak runtime report gates
- Subsystem: UDP/P2P
- File: Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift; Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift; Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReportTypes.swift
- Line range or symbol: validateUsefulMediaMoved lines 582-611; DirectPeerSessionReport validatePassMeasuredEvidence lines 213-276; validateAVRuntimeMetrics lines 584-698; runtime metric fields lines 97-131
- Exact evidence: validateUsefulMediaMoved requires positive sent/queued/reassembled/proof counts but does not reject nonzero audio drops, playout underruns, callback overruns, corrupt/oversize video fragments, metrics publish failures, peer metrics drops, or remote underruns/overruns. DirectPeerSessionReport validates these counters only as nonnegative.
- Why this can fail at runtime: A future PASS or operator-facing "useful media" result can include serious drop/underrun/failure counters while still satisfying structural validation.
- Failure mode: false success, silent degradation, data loss, latency/jitter
- Suggested remediation: Define PASS and useful-media thresholds for every drop/error/underrun counter, with explicit degraded verdict semantics.
- Required verification: Report fixtures with nonzero drop/underrun/corrupt/metrics-failure counters must not validate as PASS/useful media.
- Suggested regression or harness test: Build DirectPeerSessionReport PASS fixtures with each nonzero runtime counter and assert validation fails with field-specific errors.
- Confidence: high

- ID: HRA-P2P-09
- Severity: P2
- Category: Control-message error swallowing
- Subsystem: Control
- File: Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVControlService.swift
- Line range or symbol: serviceDirectPeerAVControl lines 17-39
- Exact evidence: Unsupported control messages or PeerSessionRunnerError.unsupportedControlMessage are counted as controlMessagesDropped and processing continues. The service does not preserve the offending message type or error detail.
- Why this can fail at runtime: A peer can send invalid control for the current lifecycle and the local runtime only records a drop count, limiting diagnosis of protocol/state bugs.
- Failure mode: silent, visible state mismatch
- Suggested remediation: Track last dropped control type/error and escalate unexpected lifecycle messages that indicate protocol mismatch.
- Required verification: Control-service tests for unsupported messages in running state.
- Suggested regression or harness test: Feed sessionPropose/sessionReject during media run and assert diagnostics include message type and reason.
- Confidence: medium

### Video Findings

- ID: HRA-VIDEO-01
- Severity: P1
- Category: Placeholder runtime evidence
- Subsystem: Video
- File: Sources/OpenLolaCore/Video/VideoCaptureRunner.swift; Sources/OpenLolaCore/Video/VideoCaptureRunConfiguration.swift; Sources/OpenLolaCore/Video/VideoCaptureReport.swift
- Line range or symbol: makeReport lines 186-205; defaultVideoCaptureAudioImpact lines 279-289; optionalVideoCaptureAudioImpact lines 169-217; validatePassVerdict lines 319-390
- Exact evidence: Video capture reports use configuration.audioImpact or defaultVideoCaptureAudioImpact. The default reports equal baseline/video callback p99/max, unchanged playout target, zero underruns, and hiddenAudioImpactDetected false. PASS validation compares these values but does not require measured provenance.
- Why this can fail at runtime: Video capture can be presented with clean audio-impact numbers that were not measured during the run, masking video-induced audio deadline impact.
- Failure mode: false success, silent latency/jitter
- Suggested remediation: Add measured/provenance fields for audio impact and reject PASS when defaults or synthetic values are used.
- Required verification: PASS video capture report without explicit measured audio-impact provenance must fail.
- Suggested regression or harness test: Request --verdict pass without audio-impact arguments/provenance and assert validate-video-capture-report fails.
- Confidence: high

- ID: HRA-VIDEO-02
- Severity: P2
- Category: Shutdown accounting
- Subsystem: Video
- File: Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift; Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVVideoLoops.swift
- Line range or symbol: deferredVideoFrame storage line 388; runVideoRXLoop deferred handling lines 66-77 and 124-134; deferVideoFrameForSync lines 186-196; AV loop shutdown flush lines 517-534
- Exact evidence: The AV loop carries one deferredVideoFrame between RX iterations. On loop exit, shutdown flushes raw audio and incomplete video reassembly but does not count or clear a final deferredVideoFrame as dropped/deferred.
- Why this can fail at runtime: A frame waiting for audio sync at shutdown is omitted from drop/defer accounting, underreporting video receive behavior.
- Failure mode: silent, false diagnostics
- Suggested remediation: On loop exit, account any non-nil deferredVideoFrame as dropped/deferred-for-sync before building runtime metrics.
- Required verification: AV sync harness that exits with a deferred frame.
- Suggested regression or harness test: Force playoutAnchor.decision to return nil, stop the AV loop, and assert videoFramesDroppedForSync or a shutdown-deferred counter increments.
- Confidence: high

- ID: HRA-VIDEO-03
- Severity: P1
- Category: Unbounded capture-run memory growth
- Subsystem: Video
- File: Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift; Sources/OpenLolaCore/Video/VideoCaptureRunConfiguration.swift
- Line range or symbol: AVFoundationSampleBufferCollector state lines 361-382; record(sampleBuffer:) lines 454-456; snapshot lines 480-503; duration/frame-rate parsing lines 94-112
- Exact evidence: The collector appends every captured timestamp and callback arrival timestamp to arrays, and snapshot copies those arrays. VideoCaptureRunConfiguration requires positive duration/frame-rate but no inspected upper bound.
- Why this can fail at runtime: Long or high-frame-rate capture runs can grow memory and snapshot-copy cost with every frame, affecting capture latency or app/CLI memory pressure.
- Failure mode: latency/jitter, visible memory growth
- Suggested remediation: Bound timestamp samples or use streaming percentile/histogram metrics; add duration/frame-rate caps for production capture runs.
- Required verification: Long-duration capture simulation with memory ceiling assertions.
- Suggested regression or harness test: Simulate 30+ minutes of sampleBuffer records and assert collector memory/snapshot cost remains bounded.
- Confidence: high

No finding with current evidence: VideoFrameReassembler caps maxActiveFrames, maxFragmentsPerFrame, and maxFrameAge, and drops older/expired frames (VideoTransportReassembly.swift lines 119-165 and 207-360). VideoOutputRenderer queue is bounded by maxQueueDepth and records backpressure/late/continuity drops (VideoOutputRenderer.swift lines 143-194).

### Error Handling Findings

- ID: HRA-ERR-01
- Severity: P2
- Category: Swallowed runtime metrics errors
- Subsystem: Error handling
- File: Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVMetricsService.swift; Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift
- Line range or symbol: serviceDirectPeerAVMetrics lines 18-31 and 37-44; validateAVRuntimeMetrics lines 682-698
- Exact evidence: Peer metrics receive errors and publish errors are converted to counters and the loop continues. The report validator only checks metricsMessagesPublishFailures and peerMetricsMessagesDropped are nonnegative.
- Why this can fail at runtime: Loss of the metrics channel can hide remote underruns, packet loss, or callback-duration evidence while media continues and reports remain structurally valid.
- Failure mode: silent, false diagnostics
- Suggested remediation: Escalate sustained metrics-channel failures and make nonzero publish/drop counters block PASS or mark degraded.
- Required verification: Metrics socket failure simulation.
- Suggested regression or harness test: Force publishMetricsSnapshot to throw repeatedly and assert runtime result is degraded/failing, not only a nonnegative counter.
- Confidence: high

### UI Runtime State Findings

- ID: HRA-UI-01
- Severity: P1
- Category: UI start gating / runtime state correctness
- Subsystem: UI runtime state
- File: Sources/open-lola-app/AppTransportView.swift; Sources/open-lola-app/AppExecutionController.swift; Sources/open-lola-app/AppRuntimeEvidenceScope.swift
- Line range or symbol: AppTransportStartPolicy.canStart lines 356-363; finishValidation lines 380-399; hasValidatedRuntimeEvidence lines 116-124; evidence state lines 60-104
- Exact evidence: canStart returns true when armed, dryRunAvailable, and lastValidationResult != .failed. The .unknown validation state is therefore start-eligible. finishValidation sets .passed only when hasValidatedRuntimeEvidence is true, but start gating does not require .passed.
- Why this can fail at runtime: An operator can start a session after no validation run, reset validation, or stale/unknown validation state as long as the run is armed and configured.
- Failure mode: visible UX flaw, false operational readiness
- Suggested remediation: Require current .passed validation/evidence for Start unless an explicit unsafe/diagnostic override is selected and logged.
- Required verification: UI policy tests for unknown, failed, evidenceIncomplete, stale-token, and passed validation states.
- Suggested regression or harness test: Assert canStart is false for .unknown and true only for .passed with current validated runtime evidence.
- Confidence: high

No finding with current evidence: Live state is evidence-backed in the inspected app path. AppRuntimeEvidenceScope requires validationExitCode == 0 and non-partial direct-peer metrics or PASS external connector report; AppSessionState.derive returns .live only when hasValidatedRuntimeEvidence is true; AppExecutionController.finishValidation marks "Validation passed" only when hasValidatedRuntimeEvidence is true; AppConsoleModels shows an evidence-incomplete state when validator exit is 0 but runtime evidence is missing or partial.

### Local RX Notes

No finding with current evidence: DirectP2PLocalhostSmoke sends one local direction and reports verdict .partial, not PASS. DirectPeerTwoPeerLocalRunReport PASS requires execution, both child exit codes 0, aggregate report path, collected peer reports, and collected receive proof paths. DirectP2PTwoPeerLocalRunCommandSupport returns no aggregate for nonzero child exit codes and aggregatePeerInput requires report/proof paths for aggregation. Remaining uncertainty: the contents of DirectPeerSessionReceiveProofArtifact and DirectPeerTwoPeerPrototypeReportBuilder were not re-audited in this pass.

### P0/P1 Runtime Remediation Roadmap

1. Fix false-success gates first: HRA-AUDIO-04, HRA-P2P-08, HRA-VIDEO-01, HRA-UI-01. These determine whether operators and reports can overclaim runtime health.
2. Fix invalid P2P lifecycle transitions: HRA-P2P-01, HRA-P2P-02, HRA-P2P-03. These affect session identity, setup, shutdown, and remote abort behavior.
3. Bound RX/TX runtime work: HRA-P2P-04 and HRA-P2P-05. These are direct latency/jitter and memory-risk items in the media loop.
4. Separate malformed network input from internal runtime defects: HRA-P2P-06 and HRA-P2P-07.
5. Bound video capture memory and add measured audio-impact provenance: HRA-VIDEO-01 and HRA-VIDEO-03.
6. Add callback and metrics-channel harnesses before optimizing lower-severity callback/control/metrics findings.

### Runtime Verification Strategy

- Add deterministic unit tests for control state transitions: nil shutdown, nil/wrong-session errors, mutated sessionAccept, and invalid control messages during running.
- Add packet harnesses for raw-audio duplicate fragment floods, mixed payload types on audio/video sockets, malformed datagrams, and missing internal audioRouter state.
- Add Direct AV loop fairness tests with preloaded capture rings, proving TX budgets do not starve RX/control/video/metrics servicing.
- Add report validation fixtures for nonzero rxBuffer loss/duplicate/reorder/underrun counters, AV runtime drop/underrun/corrupt/metrics-failure counters, and video audio-impact defaults.
- Add callback timing harnesses around DirectPeerRealtimeAudioGraph IOProc paths with max channel maps, full rings, stale payloads, and 32-frame buffers.
- Add app policy tests for Start gating and Live/Validation state derivation across unknown, failed, stale-token, partial, and validated evidence.
- Add long-run video capture simulation or collector-level stress test proving timestamp/raw-frame retention remains bounded.

### Required Harnesses Or Simulations

- Core Audio host-time overflow and callback-duration harness.
- Direct P2P control-transition fuzzer for SessionControlMessage lifecycle states.
- UDP media impairment harness for loss, jitter, reordering, duplication, mixed payload types, malformed datagrams, and raw-audio duplicate fragment flood.
- Direct AV loop fairness harness that measures per-iteration service of TX, RX, control, video, and metrics under backlog.
- Video capture retention harness for long duration/high frame rate and raw capture enabled.
- Report validation fixture suite for PASS/degraded/partial boundaries.
- SwiftUI/app policy unit tests for runtime evidence gating and operator action availability.

### Remaining Runtime Uncertainty

- Connector-specific LoLa, UltraGrid, and JackTrip live media/control paths were not deeply re-audited in this pass.
- MADI full-duplex and endpoint loopback paths were not re-audited beyond source inventory/risk mapping.
- C atomics, Opus bridge, and JPEG XS bridge were not semantically audited for memory/thread safety in this pass.
- AVFoundation live device behavior and Core Audio callback timing were not measured on hardware.
- The current findings are source-evidence backed, but no tests or runtime harnesses were executed as part of this audit-only pass.

## 28. Structural Cleanup and Minimal-Code Audit Pass

This pass is cleanup-only: slop, boilerplate, dead-code candidates, duplicated code, overengineering, deprecated compatibility seams, and structural quality. These findings do not outrank P0/P1 runtime issues from sections 6 and 27. Cleanup should happen only after runtime false-success, state-machine, and boundedness risks have harness coverage.

### Cleanup Coverage

Directly inspected in this pass:

- Package membership and vendored target boundaries in Package.swift.
- Shared parser/validation primitives in Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift and Sources/OpenLolaCore/Core/ValidationPrimitives.swift.
- Representative hand-rolled parsers in Sources/OpenLolaCore/Video/VideoCaptureRunConfiguration.swift, Sources/OpenLolaCore/Control/LightingFixtureGateRun.swift, and Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift.
- Parser and helper usage via rg across Sources/OpenLolaCore and Sources/open-lola.
- Large app and command files: Sources/open-lola-app/AppExecutionController.swift, Sources/open-lola-app/AppConsoleModels.swift, Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift, and Sources/open-lola/Commands/Network/NetworkCommands.swift.
- Direct P2P audioTransport/audioCompression compatibility in Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRunTypes.swift, Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift, Sources/OpenLolaCore/Platform/NativeAppShellDirectPeerCommand.swift, Sources/open-lola-app/AppShellStoredDefaults.swift, Sources/open-lola-app/AppStorageKeys.swift, tests, and docs/source-contracts.md.
- Deprecated single-device audioDeviceUID compatibility in Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift and docs/source-contracts.md.
- App placeholder report path in Sources/open-lola-app/OpenLolaApp.swift and Sources/OpenLolaCore/Platform/NativeAppShell.swift.
- Ignored generated .DS_Store files under Sources.

Partially inspected:

- Unused symbols were not proven with a compiler symbol graph or dead-code analyzer. Findings below are evidence-backed candidates, not deletion approval.
- Vendored Opus/JPEG XS files were inspected for SwiftPM target membership and directory shape, not for legal/provenance requirements.
- Report-schema cleanup candidates from section 8 were not re-audited in depth in this pass.

Not run in this pass:

- No broad swift build/test/lint gate was run. The worktree is already heavily dirty, this is audit-only, and the requested scope permits only plan.md edits.

### Minimal-Code Remediation Principles

- Minimum code that solves the problem.
- No speculative features.
- No abstractions for single-use code.
- No compatibility branch without a documented active user or runtime requirement.
- If a senior engineer would call it overcomplicated, simplify it.
- Prefer deletion, inlining, and use of existing helpers over new architecture.
- Do not delete any compatibility path until active CLI flags, stored defaults, reports, fixtures, docs, and external scripts are inventoried.
- Do not touch realtime audio, UDP/P2P, media TX/RX, or app runtime-state files for cleanup while P0/P1 runtime findings lack harness coverage.

### Cleanup Findings Index

| ID | Severity | Category | File or cluster | Tier |
| --- | --- | --- | --- | --- |
| SQA-DEDUP-01 | P2 | DEDUP | CLI key-value parsing | Cleanup after parser tests |
| SQA-DEDUP-02 | P2 | DEDUP | CLI typed argument helpers | Cleanup after parser tests |
| SQA-DEDUP-03 | P2 | DEDUP | Report validation primitive wrappers | Cleanup after validation matrix |
| SQA-STRUCT-01 | P2 | STRUCTURE | AppExecutionController.swift | Defer until UI runtime-state fixes |
| SQA-STRUCT-02 | P2 | STRUCTURE | AppConsoleModels.swift | Defer until UI runtime-state fixes |
| SQA-STRUCT-03 | P2 | STRUCTURE | DirectP2PTwoPeerLocalRunCommandSupport.swift | Defer until P2P harnesses exist |
| SQA-STRUCT-04 | P2 | STRUCTURE | NetworkCommands.swift | Defer until command smoke coverage |
| SQA-DEAD-01 | P2 | DEAD_CODE | Sources/opus-1.5.2 non-target files | Investigate/provenance first |
| SQA-DEAD-02 | P2 | DEAD_CODE | Sources/xs_ref_sw_ed2 non-target files | Investigate/provenance first |
| SQA-SLOP-01 | P3 | SLOP | Ignored .DS_Store files | Safe local cleanup only |
| SQA-DEPRECATED-01 | P2 | DEPRECATED | audioCompression compatibility | Do not remove without active-use proof |
| SQA-DEPRECATED-02 | P3 | DEPRECATED | audioDeviceUID compatibility | Do not remove without migration proof |
| SQA-OVER-01 | P2 | OVERENGINEERING | Native app placeholder report | Defer until app state tests |
| SQA-STRUCT-05 | P3 | STRUCTURE | direct-p2p two-peer prototype naming | Contract migration only |

### Deduplication Findings

- ID: SQA-DEDUP-01
- Severity: P2
- Category: DEDUP
- File: Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift; Sources/OpenLolaCore/Video/VideoCaptureRunConfiguration.swift; Sources/OpenLolaCore/Control/LightingFixtureGateRun.swift; Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift
- Symbol or line range: KeyValueArgumentParser lines 1-201; VideoCaptureRunConfiguration.parse lines 52-92; LightingGateRunConfiguration.parse lines 51-84; AtemReadOnlyProbeConfiguration.parse lines 122-149
- Evidence: KeyValueArgumentParser already implements strict allowed-key, duplicate, and missing-value handling. VideoCaptureRunConfiguration, LightingGateRunConfiguration, and AtemReadOnlyProbeConfiguration each hand-roll the same values dictionary loop. Repository search found the same pattern in additional command parsers including OscCueProbe, IntegratedProfileRun, HardwareValidationRun, MadiFullDuplexCommands, VideoTransportProbe, AudioLoopbackRunConfiguration, NativeAppShell, UdpPcmRouteRunConfiguration, NMP connector parsers, MacToMacConnectionEstablishment, DirectPeerTwoPeerRunPlan, and ExternalConnectorExecutablePreflight. Other command families already call KeyValueArgumentParser.parseValues.
- Why this is harmful: Parser behavior can drift across commands. In the sampled files, dash-prefixed value handling differs: VideoCapture and Lighting reject values starting with "--", Atem only checks that a value exists, and KeyValueArgumentParser makes this policy explicit with allowsDashPrefixedValues.
- Suggested action: Deduplicate by converting one active command family at a time to the existing KeyValueArgumentParser. Do not create a new parser abstraction. Preserve each command's current error enum and dash-prefixed-value policy explicitly.
- Risk of change: Medium. CLI argument behavior is a public surface, and some commands may intentionally allow values beginning with "--".
- Verification needed: Focused parser tests for unknown, duplicate, missing, empty, dash-prefixed, negative numeric, and boolean values for each migrated command; then command help/smoke tests for affected CLI paths.
- Confidence: high

- ID: SQA-DEDUP-02
- Severity: P2
- Category: DEDUP
- File: Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift; Sources/OpenLolaCore/* helpers and command parsers
- Symbol or line range: KeyValueArgumentParser requiredString/optionalInteger/requiredPositiveInteger/optionalPositiveInteger/optionalNonNegativeInteger/optionalNonNegativeDouble/boolean lines 83-193; repeated required*String and optional/required numeric helpers across rg results
- Evidence: KeyValueArgumentParser already provides typed required/optional string, integer, positive integer, nonnegative integer/double, and boolean helpers. Repository search found many near-copy helpers with command prefixes, including requiredAtemProbeString, requiredLightingRunString, requiredOscExternalRunString, requiredIntegratedAvRunString, requiredE2EBenchmarkRunString, requiredHardwareValidationRunString, requiredNatString, requiredRouteRunString, requiredLoopbackString, requiredRecordingRunString, requiredVideoCaptureString, and related positive-integer helpers.
- Why this is harmful: Each wrapper repeats missing/invalid/nonpositive policy and increases the chance that one command accepts values another rejects. It also makes parser bug fixes hard to audit because behavior is spread across many small helper functions.
- Suggested action: Inline wrappers that add no domain-specific validation into KeyValueArgumentParser calls. Keep tiny domain wrappers only when they add real checks such as port ranges, host validation, enum parsing, or command-specific error text.
- Risk of change: Medium. Error text and typed error cases may be asserted by tests or scripts.
- Verification needed: Parser-focused tests before each helper removal; rg for old helper symbols; affected command smoke tests; broader swift test only after batching is complete.
- Confidence: high

- ID: SQA-DEDUP-03
- Severity: P2
- Category: DEDUP
- File: Sources/OpenLolaCore/Core/ValidationPrimitives.swift; Sources/OpenLolaCore/Control/LightingFixtureGateHelpers.swift; Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift; Sources/OpenLolaCore/Control/OscCueHelpers.swift; Sources/OpenLolaCore/Integration/IntegratedAvHelpers.swift; Sources/OpenLolaCore/Integration/IntegratedProfileReport.swift
- Symbol or line range: ReportPrimitiveValidating/ValidationPrimitives lines 64-139 and 149-331; requireLighting* lines 3-51; requireAtem* lines 387-396; requireOsc* lines 84-115; requireIntegrated* lines 40-117; requireIntegratedProfile* lines 398-432
- Evidence: A central ReportPrimitiveValidating/ValidationPrimitives layer exists and is already used by several validators. Multiple domain helper files still define thin wrappers for non-empty, non-empty list, positive, nonnegative, finite, and percent checks.
- Why this is harmful: Report validators are trust-boundary code. Repeated wrappers make it harder to prove PASS/PARTIAL policy consistency and can hide subtle differences in nonfinite, zero, empty-list, and percentage handling.
- Suggested action: Replace purely thin wrappers with the existing primitive validators, or use a private enum conforming to ReportPrimitiveValidating where a file has multiple real validation call sites. Do not introduce a new validation framework.
- Risk of change: Medium. Report validation error types and field names are public evidence contracts.
- Verification needed: Validation fixture matrix for empty, blank, zero, negative, nonfinite, unordered percentile, invalid percent, and PASS/PARTIAL boundary cases before removing wrappers.
- Confidence: high

### Structural Findings

- ID: SQA-STRUCT-01
- Severity: P2
- Category: STRUCTURE
- File: Sources/open-lola-app/AppExecutionController.swift
- Symbol or line range: whole file, 1003 lines; AppExecutionController lines 69-832; AppExecutionLogSnapshot lines 834-856; AppRunEvidenceSnapshot lines 858-917; AppExecutionLogFileOpener lines 919-934; AppExecutionReportLoader lines 936-974; AppExecutionReportAssembler lines 976-1003
- Evidence: The file combines observable UI execution state, command construction, process state, validation state, previous-run evidence snapshots, log file preservation/opening, report loading, and report assembly.
- Why this is harmful: Runtime-state truthfulness is already high-risk. When process control, UI labels, validation evidence, and log/report helpers live in one large file, a small UI change can accidentally alter runtime-state semantics or evidence loading.
- Suggested action: After HRA-UI-01 is fixed and covered, split only existing helper types into file-local responsibility files such as log snapshots, report loading, and report assembly. Do not change behavior or introduce a new app architecture during this cleanup.
- Risk of change: Medium-high. This file is a UI-to-runtime boundary and should not be touched for cosmetics while runtime-state tests are weak.
- Verification needed: AppShell runtime-state tests, validation/start gating tests, log/report load tests, and app launch smoke after any split.
- Confidence: high

- ID: SQA-STRUCT-02
- Severity: P2
- Category: STRUCTURE
- File: Sources/open-lola-app/AppConsoleModels.swift
- Symbol or line range: whole file, 640 lines; AppConsoleStatusSnapshot lines 4-122; overview models lines 124-327; AppConsoleSectionSelection lines 329-380; AppValidationRow lines 382-449; AppValidationPreflightModel lines 451-544; AppPacketMonitorEmptyState lines 546-565; AppDiagnosticsStatusModel lines 567-640
- Evidence: One file mixes top-level status text/tone, overview summaries, section navigation, validation rows, validation blocker policy, packet monitor empty state, and diagnostics status.
- Why this is harmful: The file concentrates several UI truth surfaces that can say readiness, validation, live evidence, packet availability, and diagnostics. Mixed responsibilities make it easy for stale or optimistic state rules to diverge from runtime evidence.
- Suggested action: Defer until UI runtime-state findings are fixed, then split by existing model groups or section ownership. Do not add a new state manager; keep the existing data flow and move code only when tests protect labels and gating.
- Risk of change: Medium.
- Verification needed: UI model tests for validation, packet empty state, diagnostics evidence labels, and section selection across unconfigured, configured, running, failed, partial, and validated states.
- Confidence: high

- ID: SQA-STRUCT-03
- Severity: P2
- Category: STRUCTURE
- File: Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift
- Symbol or line range: whole file, 625 lines; command entry/report write lines 8-49; process orchestration lines 51-110; child launch/readiness/SSH quoting lines 188-309; options model lines 311-416; aggregate/proof/SCP code lines 418-521; parser helpers lines 548-625
- Evidence: The file handles CLI entry, local and SSH child process launch, readiness polling, shell quoting, timeout/termination, aggregate report/proof loading, remote artifact collection through scp, and argument parsing.
- Why this is harmful: This is a high-risk P2P lifecycle/evidence path. Process supervision, remote shell behavior, evidence aggregation, and parsing in one file increase review burden and make cleanup risky without strong end-to-end harnesses.
- Suggested action: Do not refactor before P2P lifecycle and local RX proof harnesses exist. When covered, split along existing responsibilities only: options parsing, process launching/readiness, artifact collection, and aggregate report writing.
- Risk of change: High. This code controls local/SSH execution and report proof paths.
- Verification needed: Local two-peer dry-run, local executed run, SSH argument construction tests, readiness timeout tests, scp collection failure tests, aggregate report/proof validation, and command output contract checks.
- Confidence: high

- ID: SQA-STRUCT-04
- Severity: P2
- Category: STRUCTURE
- File: Sources/open-lola/Commands/Network/NetworkCommands.swift
- Symbol or line range: handleNetworkCommand lines 5-345; large switch cases lines 6-320
- Evidence: handleNetworkCommand is a 380-line command router with many case-let patterns, direct execution/report writing logic, nested role dispatch for udp-pcm-route-run, NAT commands, direct P2P commands, smoke commands, and validation commands.
- Why this is harmful: A monolithic router makes it hard to audit command ownership, help behavior, validation consistency, and report-writing conventions. It also encourages new commands to add more case branches instead of keeping command families locally testable.
- Suggested action: Split by existing command family only after command smoke coverage exists. Prefer moving direct code into already existing command support files over introducing a registry/table abstraction.
- Risk of change: Medium. CLI command names and output text are public surfaces.
- Verification needed: Command inventory test, help/smoke tests for every moved command, report-path write tests, and CLI output/verdict checks.
- Confidence: high

- ID: SQA-STRUCT-05
- Severity: P3
- Category: STRUCTURE
- File: docs/source-contracts.md; Sources/open-lola/Commands/Network/NetworkCommands.swift
- Symbol or line range: docs/source-contracts.md lines 42-45; direct-p2p-two-peer-prototype-report routing lines 290-295
- Evidence: docs/source-contracts.md states DirectPeerTwoPeerPrototypeReport and direct-p2p-two-peer-prototype-report remain active measured public contracts despite the prototype name, retained for existing report/validator compatibility.
- Why this is harmful: "Prototype" is misleading for an active measured public contract and can cause auditors or operators to mis-rank the path as experimental or dead.
- Suggested action: Do not rename immediately. First inventory active fixtures, validators, docs, scripts, and external users. If a replacement name is justified, add an explicit schema/command migration with tests; otherwise keep the compatibility name documented.
- Risk of change: Medium-high. Renaming report contracts can break fixtures and external scripts.
- Verification needed: rg for DirectPeerTwoPeerPrototypeReport and direct-p2p-two-peer-prototype-report across source/tests/docs/scripts; schema fixture compatibility tests; CLI alias/migration tests if renamed.
- Confidence: high

### Dead-Code Candidate Findings

- ID: SQA-DEAD-01
- Severity: P2
- Category: DEAD_CODE
- File: Package.swift; Sources/opus-1.5.2
- Symbol or line range: COpus target lines 89-231; non-target directories Sources/opus-1.5.2/doc, tests, training, .github, celt/tests, silk/tests, dnn, cmake, m4, meson, scripts
- Evidence: Package.swift defines COpus with an explicit sources list of selected openlola_bridge, src, celt, silk, and silk/float files. find counted 714 files under Sources/opus-1.5.2, including upstream docs, tests, training scripts, GitHub workflows, DNN, build-system files, and unit tests that are not in the explicit SwiftPM source list.
- Why this is harmful: Uncompiled upstream material under Sources increases audit surface, release/legal review noise, and search-result clutter. It also makes it harder to distinguish product runtime code from bundled provenance material.
- Suggested action: Investigate, do not delete yet. Classify each non-target group as required provenance/license material, active build input, test fixture, or removable upstream extra. If removable, prune from active Sources or move to an explicitly documented provenance/archive lane with release hygiene coverage.
- Risk of change: High without legal/provenance review. Codec licensing and upstream attribution must remain intact.
- Verification needed: swift build --product open-lola; codec-focused tests; release export; release hygiene; THIRD_PARTY_NOTICES/license review; rg for references to pruned paths.
- Confidence: high

- ID: SQA-DEAD-02
- Severity: P2
- Category: DEAD_CODE
- File: Package.swift; Sources/xs_ref_sw_ed2
- Symbol or line range: CJpegXSReference target lines 80-86; non-target directories Sources/xs_ref_sw_ed2/programs, extras, std
- Evidence: Package.swift points CJpegXSReference at Sources/xs_ref_sw_ed2/libjxs only and excludes CMakeLists.txt plus src/msbpack.c. find counted 98 files under Sources/xs_ref_sw_ed2 and listed non-target programs, converters, extras scripts, and std/getopt.h outside the libjxs target path.
- Why this is harmful: Non-target reference programs and extras under Sources create audit and release-boundary noise around a high-risk video codec bridge.
- Suggested action: Investigate, do not delete yet. Decide whether programs/extras/std are required for provenance or manual reference validation. If not required, prune or relocate them with a manifest explaining what remains compiled.
- Risk of change: High without codec/provenance review.
- Verification needed: swift build --product open-lola; JPEG XS bridge tests; release export/hygiene; license/provenance review; rg for references to programs/extras/std.
- Confidence: high

- ID: SQA-SLOP-01
- Severity: P3
- Category: SLOP
- File: Sources/.DS_Store; Sources/COpenLolaAtomics/.DS_Store; Sources/OpenLolaCore/.DS_Store
- Symbol or line range: generated filesystem files
- Evidence: find reported .DS_Store files under Sources, Sources/COpenLolaAtomics, and Sources/OpenLolaCore. git check-ignore shows they are ignored by .gitignore line 51, so they are local generated clutter, not tracked source.
- Why this is harmful: Low direct impact, but generated files in source directories create noise for local inventory/audit commands and can mask whether a directory contains only source-owned material.
- Suggested action: Delete local ignored .DS_Store files when cleanup edits are allowed. No source or test changes are needed.
- Risk of change: Low.
- Verification needed: find Sources -name .DS_Store returns no files; git status remains clean with respect to tracked files.
- Confidence: high

### Deprecated Compatibility Findings

- ID: SQA-DEPRECATED-01
- Severity: P2
- Category: DEPRECATED
- File: Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRunTypes.swift; Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift; Sources/OpenLolaCore/Platform/NativeAppShellDirectPeerCommand.swift; Sources/open-lola-app/AppShellStoredDefaults.swift; Sources/open-lola-app/AppStorageKeys.swift; docs/source-contracts.md; Tests/OpenLolaCoreTests/DirectPeerSessionOpusCLITests.swift; Tests/OpenLolaCoreTests/NativeAppShellOpusCommandTests.swift
- Symbol or line range: DirectPeerSessionAudioCompression lines 46-62; DirectPeerSessionAudioTransport.legacyAudioCompression lines 80-89; AV run initializer compatibility lines 377-420; two-peer plan compatibility lines 85-121 and 446-468; NativeAppShellDirectPeerCommand compatibility lines 51-124; AppShellStoredDefaults migration lines 94-104; docs/source-contracts.md lines 30-36
- Evidence: audioTransport is documented as canonical. Legacy audioCompression and --audio-compression remain hidden compatibility paths for CLI arguments, stored app defaults, initializer fallback, and report decoding. Tests assert the hidden flag is not in help, invalid legacy values fail, conflicting audioTransport/audioCompression fails, and stored defaults migrate from AppStorageKeys.audioCompression to audioTransport.
- Why this is harmful: Dual canonical/legacy names add ambiguity to runtime transport selection and report decoding. The legacy getter maps transports with no legacy compression, such as aes67-st2110-l24, back to .raw, which is acceptable only as a compatibility fallback and not as a precise representation.
- Suggested action: Investigate and sunset only with proof. Do not delete now. Build an active-use inventory across CLI flags, stored defaults, reports, fixtures, docs, and scripts; if no active external requirement remains, remove the hidden branch with a documented migration/breaking-change test.
- Risk of change: High. Existing stored defaults, legacy reports, tests, and external scripts may depend on this hidden path.
- Verification needed: rg for audioCompression, --audio-compression, AppStorageKeys.audioCompression, legacyAudioCompression; migration tests; CLI hidden-help tests; report decoding fixtures; app defaults migration tests; Direct P2P AV transport tests.
- Confidence: high

- ID: SQA-DEPRECATED-02
- Severity: P3
- Category: DEPRECATED
- File: Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift; docs/source-contracts.md; Tests/OpenLolaCoreTests/DirectPeerRealtimeAudioGraphTests.swift
- Symbol or line range: deprecated audioDeviceUID accessor lines 137-145; docs/source-contracts.md lines 37-41; legacy JSON tests referencing audioDeviceUID
- Evidence: DirectPeerRealtimeAudioGraphConfiguration exposes canonical inputDeviceUID and outputDeviceUID, but retains deprecated audioDeviceUID as a single-device compatibility accessor and initializer argument. docs/source-contracts.md says decoded graph configs must provide split UIDs and new encoded configs must write split UIDs, not the legacy key. Tests still include legacy JSON for audioDeviceUID.
- Why this is harmful: The legacy single-device name preserves full-duplex assumptions in a path where split input/output devices are now the canonical runtime model.
- Suggested action: Keep decode compatibility until fixture/report inventory proves it can be removed. Add a verification slice that proves new encoders never emit audioDeviceUID before considering removal of the deprecated accessor.
- Risk of change: High if old config/report decoding remains supported.
- Verification needed: rg for audioDeviceUID across source/tests/docs/fixtures/scripts; encode/decode tests proving split UID output and legacy input migration; app/runtime graph configuration tests.
- Confidence: high

### Overengineering and Placeholder Findings

- ID: SQA-OVER-01
- Severity: P2
- Category: OVERENGINEERING
- File: Sources/open-lola-app/OpenLolaApp.swift; Sources/OpenLolaCore/Platform/NativeAppShell.swift
- Symbol or line range: OpenLolaAppScene report state line 18; NativeAppShellReport.placeholder lines 195-197; NativeAppShellSyntheticSmoke.placeholder lines 387-393
- Evidence: The app initializes report state with NativeAppShellReport.placeholder(). The placeholder helper delegates to NativeAppShellSyntheticSmoke.placeholder(), which emits id m13-native-app-shell-placeholder and notes "Placeholder report used while the app refreshes synthetic metrics asynchronously." rg found this placeholder path only in the app initializer and the helper definitions.
- Why this is harmful: A placeholder report is modeled as a full NativeAppShellReport and injected into production UI state. That blurs loading/synthetic/measured states in a codebase where false PASS/PARTIAL/live evidence is already high-risk.
- Suggested action: Simplify the initial state once app state tests exist. Prefer making the loading state explicit at the app boundary or initializing directly from the real synthetic smoke path; delete the placeholder helper only if rg confirms no active tests/docs/scripts require it.
- Risk of change: Medium. App launch and first-render behavior can regress.
- Verification needed: App launch smoke, first-render tests, report refresh tests, and UI state assertions proving placeholder/loading cannot be mistaken for measured runtime evidence.
- Confidence: high

### Minimal-Code Remediation Tiers

Tier 0: Do not start cleanup before runtime trust fixes.
- HRA-AUDIO-04, HRA-P2P-08, HRA-VIDEO-01, and HRA-UI-01 remain higher priority than all findings in this section.
- P2P lifecycle findings HRA-P2P-01 through HRA-P2P-03 should also precede structural cleanup in Direct P2P command/runtime files.

Tier 1: Low-risk local cleanup.
- SQA-SLOP-01, because ignored generated files can be removed without source behavior changes.

Tier 2: Parser/validator dedup with tests.
- SQA-DEDUP-01, SQA-DEDUP-02, and SQA-DEDUP-03, one command/report family at a time, using existing helpers only.

Tier 3: Compatibility proof and removal planning.
- SQA-DEPRECATED-01, SQA-DEPRECATED-02, and SQA-STRUCT-05. These must start with active-use inventories and migration tests, not deletion.

Tier 4: Structural file splits.
- SQA-STRUCT-01 through SQA-STRUCT-04. These are cleanup-only and should wait until runtime/app command behavior is covered.

Tier 5: Vendored/reference pruning.
- SQA-DEAD-01 and SQA-DEAD-02. These require codec build proof, release export/hygiene, and legal/provenance review.

### Dead-Code Verification Plan

1. Build target membership evidence with Package.swift, swift package dump-package, and rg for product/target references.
2. For each candidate, classify it as compiled runtime code, public contract, fixture, script input, documentation/provenance, generated output, or unknown.
3. Before deletion, run rg across Sources, Tests, scripts, script, docs, linux_connector, README.md, Package.swift, and CI/release scripts for every symbol/path.
4. For Swift candidates, remove in a branch and run focused swift test filters, then relevant broader swift test/build gates.
5. For vendored codec candidates, verify package build, codec bridge tests, release export, release hygiene, and license/notice integrity.
6. For docs/script candidates, run PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh and relevant shellcheck/ruff gates.
7. If any candidate is unknown after steps 1-6, mark it unclear and keep it.

### Deprecated Compatibility Removal Plan

1. Inventory all compatibility tokens and storage keys with rg before changing behavior.
2. Separate active compatibility from stale compatibility:
   - Active means used by public CLI, app settings/defaults migration, validator/report decoding, fixtures, release scripts, external scripts, or current docs.
   - Stale means no active call site, no fixture/schema requirement, no documented user, and no release/export reference.
3. For active compatibility, add a sunset note and tests first; do not remove in the same slice unless the contract owner accepts a breaking change.
4. For stale compatibility, remove the branch and its tests/fixtures together only after focused decode/migration/CLI tests prove the replacement.
5. Preserve a short migration note in docs/source-contracts.md for any removed public-facing flag, key, or report field.

### Deduplication Plan

1. Prefer using existing helpers: KeyValueArgumentParser and ValidationPrimitives/ReportPrimitiveValidating.
2. Do not introduce new abstractions for a single command, a single report, or cosmetic grouping.
3. Migrate one command/report family at a time.
4. Preserve command-specific errors and public CLI text unless tests are updated in an implementation slice.
5. Treat parser and validator dedup as correctness work, not style cleanup: every migrated path needs invalid-input tests.
6. Stop if dedup makes the behavior harder to read or hides protocol/report policy.

### Files Most Likely To Be Dead Or Stale

- Sources/opus-1.5.2 non-target upstream docs/tests/training/DNN/build metadata, pending provenance review.
- Sources/xs_ref_sw_ed2 programs/extras/std outside the CJpegXSReference target path, pending provenance review.
- Sources/.DS_Store, Sources/COpenLolaAtomics/.DS_Store, Sources/OpenLolaCore/.DS_Store, local ignored generated clutter.
- MeasurementReport/MeasurementReports generic schema from SLOP-01, pending active contract proof.
- NativeAppShell placeholder report helpers, pending first-render/loading-state proof.

### Files Most Likely To Contain Slop Or Boilerplate

- Sources/OpenLolaCore command/configuration parsers that still hand-roll values dictionaries.
- Sources/OpenLolaCore helper files with prefixed required/optional argument functions.
- Sources/OpenLolaCore report validators with thin require* wrappers around ValidationPrimitives.
- Sources/open-lola/Commands/Network/NetworkCommands.swift.
- Sources/open-lola-app/AppExecutionController.swift.
- Sources/open-lola-app/AppConsoleModels.swift.
- Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift.

### Files Requiring Deeper Cleanup Audit

- Sources/OpenLolaCore/Connectors/LoLa, Sources/OpenLolaCore/Connectors/UltraGrid, and Sources/OpenLolaCore/Connectors/JackTrip for compatibility branches that may be source-level only.
- Sources/OpenLolaCore/Network/NAT for relay/rendezvous compatibility modes and fallback paths.
- Sources/OpenLolaCore/Platform and Sources/open-lola-app for placeholder/loading/report-state boundaries.
- All report-schema inventory and release evidence files that preserve older schema names.
- All vendored C/C codec bridge directories, with legal/provenance review.

### Files That Should Not Be Touched Without Stronger Verification

- Sources/OpenLolaCore/Audio/Realtime/*, because realtime callback and buffering risks outrank cleanup.
- Sources/OpenLolaCore/Network/P2P/* runtime files, because lifecycle and false-success findings are unresolved.
- Sources/OpenLolaCore/Network/UDP/* runtime files, because packet loss/reorder/jitter behavior needs harnesses.
- Sources/OpenLolaCore/Video/* runtime files, because capture/transport/report findings are unresolved.
- Sources/opus-1.5.2 and Sources/xs_ref_sw_ed2, because pruning needs codec and provenance proof.
- Sources/open-lola-app/AppExecutionController.swift and AppConsoleModels.swift, because they are UI-to-runtime truth surfaces.

### Cleanup Coverage Gaps And Uncertainty

- No compiler-backed unused-symbol report was generated, so unused functions/classes/components are only candidates where direct rg evidence supports them.
- No dependency or package-prune tool was run for vendored C/C material.
- No source changes were attempted, so deletion safety is unproven.
- Existing docs verification is expected to remain blocked while plan-remediation-ledger.md and plan-remediation-status.md are missing from the dirty worktree; this pass did not recreate them because only plan.md may be modified.

## 29. UI, UX, Menu, Navigation, Settings, And User-Facing Logic Audit Pass

Date: 2026-05-20.

Scope and method:
- Directly inspected SwiftUI/macOS app UI sources and app-facing runtime state code. No production code, tests, fixtures, scripts, or generated files were changed.
- This pass focused on user-visible correctness, menus, navigation, settings, state wording, local preview, packet/diagnostics surfaces, visual scaling, and accessibility affordances.
- No built app was launched and no screenshots were captured in this pass, so visual-layout findings remain source-evidence-backed candidates until rendered at runtime.

Files inspected for this UI pass:
- Fully inspected for this pass: `Sources/open-lola-app/OpenLolaApp.swift`, `Sources/open-lola-app/AppShellRootView.swift`, `Sources/open-lola-app/AppConsoleChromeView.swift`, `Sources/open-lola-app/AppTransportView.swift`, `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`, `Sources/open-lola-app/AppShellSettingsView.swift`, `Sources/open-lola-app/AppShellSettingsTabs.swift`, `Sources/open-lola-app/AppSettings.swift`, `Sources/open-lola-app/AppPreviewReceiverView.swift`, `Sources/open-lola-app/AppPacketMonitorView.swift`, `Sources/open-lola-app/AppConsoleModels.swift`, `Sources/open-lola-app/AppLatencyHeroView.swift`, `Sources/open-lola-app/AppRuntimeEvidenceScope.swift`, `Sources/open-lola-app/AppDesignSystem.swift`, `Sources/open-lola-app/AppShellSupportViews.swift`, `Sources/OpenLolaCore/Platform/NativeAppShellExecution.swift`, `Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift`.
- Partially inspected for UI-facing evidence: `Sources/open-lola-app/AppExecutionController.swift`, `Sources/open-lola-app/AppExecutionView.swift`, `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`, `Tests/OpenLolaCoreTests/NativeAppShellSurfaceActionTests.swift`.
- Not inspected in this pass: rendered app bundle, actual macOS menu tree, VoiceOver traversal, Accessibility Inspector output, keyboard hardware behavior, dark/light/high-contrast screenshots, live device permission prompts, and multi-monitor/window-resize behavior. Reason: audit-only source pass with the stop rule requiring `plan.md` update only.

Severity tiering for this UI pass:
- P1 user-visible correctness and runtime-state risk: UIA-STATE-01, UIA-SESSION-01, UIA-MENU-02, UIA-SETTINGS-01.
- P2 misleading controls, broken navigation, hidden state, or settings not mapped to behavior: UIA-MENU-01, UIA-CONTROL-01, UIA-NAV-01, UIA-STREAM-01, UIA-STREAM-02, UIA-SETTINGS-02, UIA-DIAG-01, UIA-ACCESS-01, UIA-PLACEHOLDER-01.
- P3 visual polish and readability candidates: UIA-VIS-01, UIA-VIS-02.
- No current P0 UI-only finding was confirmed in this pass. Several P1 findings can still contribute to runtime false-success or unsafe-start behavior.

### Navigation/Menu Findings

- ID: UIA-MENU-01
- Severity: P2
- File: `Sources/open-lola-app/AppShellSettingsTabs.swift`; `Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift`; `Sources/open-lola-app/OpenLolaApp.swift`
- Component/view/menu: Settings Execution tab and app command shortcut mapping
- Evidence: `AppExecutionSettingsTab` renders `Text("Shortcut: ⌘⇧V")` at `AppShellSettingsTabs.swift:39-42`; the `validate-supervisor-report` action has `keyboardShortcut: nil` at `NativeAppShellSurfaceContract.swift:289-298`; `AppMenuShortcut.init` only maps `command-r`, `command-shift-e`, and `command-shift-p` at `OpenLolaApp.swift:304-318`.
- User-visible impact: The Settings UI advertises a validation shortcut that is not backed by the command contract or menu shortcut parser.
- Runtime impact, if any: Operators may believe validation ran when a keyboard command actually does nothing, increasing false confidence around runtime readiness.
- Suggested remediation: Either remove the shortcut text or wire one canonical shortcut through `NativeAppShellSurfaceAction`, menu rendering, and focused UI tests.
- Verification needed: Menu/keyboard test that opens the app, invokes the advertised shortcut, and observes a validation command or verifies the shortcut is no longer advertised.
- Screenshot/manual test suggestion: Open Settings -> Execution and compare the displayed shortcut to the app menu shortcuts.
- Confidence: high

- ID: UIA-MENU-02
- Severity: P1
- File: `Sources/open-lola-app/OpenLolaApp.swift`; `Sources/open-lola-app/AppTransportView.swift`; `Sources/open-lola-app/AppExecutionController.swift`
- Component/view/menu: App command menu "Start Armed Supervisor"
- Evidence: The menu action for `start-armed-supervisor` is disabled only when execution is not armed or is already running at `OpenLolaApp.swift:128-136`; the transport button uses `AppTransportStartPolicy.canStart` with `dryRunAvailable` and `lastValidationResult` at `AppTransportView.swift:238-243` and `AppTransportView.swift:356-363`; `AppValidationResult` defaults to `.unknown` at `AppExecutionController.swift:81-83`.
- User-visible impact: The menu can offer a Start action under conditions where the visible transport Start button is disabled or where validation has not passed.
- Runtime impact, if any: A weaker menu path can attempt to launch runtime work without the same preflight/validation gating as the main control strip, producing false affordance or a late "Run failed to start" state.
- Suggested remediation: Make menu command availability call the same start policy used by the transport strip, including workflow availability, plan configuration, armed state, running state, and validation policy.
- Verification needed: Focused menu-action tests for unconfigured, unknown-validation, failed-validation, armed, running, and unsupported-workflow states.
- Screenshot/manual test suggestion: With a configured but unvalidated session, compare whether the transport Start button and app menu Start action are both consistently disabled.
- Confidence: high

- ID: UIA-NAV-01
- Severity: P2
- File: `Sources/open-lola-app/AppShellRootView.swift`; `Sources/open-lola-app/AppSessionStateBanner.swift`
- Component/view/menu: Sidebar navigation and session-state transition policy
- Evidence: `AppShellRootView` changes `selectedSection` whenever `derivedSurface.sessionState` transitions to `.live` at `AppShellRootView.swift:133-142`; `AppSidebarLiveNavigationPolicy` always returns `.session` for a transition into `.live` at `AppShellRootView.swift:203-213`; `AppSessionState.derive` can return `.live` for `.runFinished`, `.validationPassed`, or `lastExitCode == 0` with validated evidence while `isRunning` is false at `AppSessionStateBanner.swift:228-248`.
- User-visible impact: Validation or completed-run evidence can unexpectedly pull the operator away from Validation, Diagnostics, Packet Monitor, or Settings into Session.
- Runtime impact, if any: This can hide the evidence view the operator was inspecting and reinforce the misleading "Live" state from completed evidence.
- Suggested remediation: Only auto-navigate on an active live/run transition, or require a user-initiated start transition rather than any derived `.live` state.
- Verification needed: UI state tests covering validation success while selected on Validation and Packet Monitor.
- Screenshot/manual test suggestion: Select Validation, load/validate a passing report, and verify whether the sidebar selection remains stable.
- Confidence: high

### Session/Control UI Findings

- ID: UIA-SESSION-01
- Severity: P1
- File: `Sources/open-lola-app/AppTransportView.swift`; `Sources/open-lola-app/AppExecutionController.swift`
- Component/view/menu: Transport Start button
- Evidence: `AppTransportStartPolicy.canStart` returns true when `armedForExecution && dryRunAvailable && lastValidationResult != .failed` at `AppTransportView.swift:356-363`; `lastValidationResult` defaults to `.unknown` at `AppExecutionController.swift:81-83`; `startHelp` says "Start session (requires arm)" whenever `startAvailable` is true at `AppTransportView.swift:246-252`.
- User-visible impact: Start can appear available after arming and configuration even when no validation has passed.
- Runtime impact, if any: Operators can initiate a real run from an unvalidated state, which is a false-readiness risk in high-risk audio/video/network runtime paths.
- Suggested remediation: Require `lastValidationResult == .passed` for normal Start, or add an explicit, clearly labeled override path with its own warning and test coverage.
- Verification needed: Focused policy tests for `.unknown`, `.failed`, and `.passed`, plus UI/menu parity tests.
- Screenshot/manual test suggestion: Fresh launch, configure fields, arm, and confirm whether Start becomes active before any validation run.
- Confidence: high

- ID: UIA-CONTROL-01
- Severity: P2
- File: `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`; `Sources/open-lola-app/AppSessionStateBanner.swift`; `Sources/open-lola-app/AppTransportView.swift`
- Component/view/menu: Command Intent panel
- Evidence: `AppCommandIntentView` buttons set `.handoffRequested`, `.startRequested`, `.runRequested`, and `.stopRequested` directly at `AppLocalOperatorSurfaceView.swift:553-562`; `AppSessionState.derive` only treats `.handoffRequested` specially for `.connecting` at `AppSessionStateBanner.swift:250-255`; actual runtime Start and Stop live in `AppTransportView` at `AppTransportView.swift:115-124` and `AppTransportView.swift:296-299`.
- User-visible impact: Buttons labeled "Intent: Start", "Intent: Run", and "Intent: Stop" look actionful but only mutate an intent field; Stop is also enabled even when the plan is unconfigured or inputs are locked.
- Runtime impact, if any: This can create a displayed intent state that is not backed by actual runtime lifecycle action, confusing TX/RX operator state.
- Suggested remediation: Rename the panel to make it clearly read-only/metadata, or route these controls through the same transport actions and disable policies as the main controls.
- Verification needed: UI behavior tests proving each intent button either only changes metadata with clear wording or actually invokes the matching runtime action.
- Screenshot/manual test suggestion: Click "Intent: Run" and confirm whether any process starts or whether only the intent badge changes.
- Confidence: high

- ID: UIA-ACCESS-01
- Severity: P2
- File: `Sources/open-lola-app/AppTransportView.swift`; `Sources/open-lola-app/AppConsoleChromeView.swift`; `Sources/open-lola-app/OpenLolaApp.swift`; `Sources/open-lola-app/AppSessionStateBanner.swift`
- Component/view/menu: Dangerous Stop controls
- Evidence: The transport confirmation dialog is shown only when `AppTransportStopConfirmationPolicy.requiresConfirmation(sessionState:)` returns true, and that policy only checks `sessionState == .live` at `AppTransportView.swift:34-43` and `AppTransportView.swift:344-347`; an active non-dry-run process derives `.supervisorRunning` while `isRunning` is true at `AppSessionStateBanner.swift:218-226`; footer/top/menu stop entrypoints call stop directly at `AppConsoleChromeView.swift:214-224` and `OpenLolaApp.swift:138-142`.
- User-visible impact: Active supervisor runs can be stopped from several places without the same destructive-action confirmation.
- Runtime impact, if any: Accidental stop can terminate an active audio/video/network session and lose current run continuity.
- Suggested remediation: Apply one shared stop confirmation policy to all stop entrypoints for active non-dry runs, and distinguish dry-run stop from live media stop in the text.
- Verification needed: Tests for Stop behavior in `.supervisorRunning`, `.dryRunRunning`, `.live`, and idle states across transport, footer/top bar, and menu.
- Screenshot/manual test suggestion: Start a supervisor run and trigger Stop from the transport, footer, top bar, and menu; compare confirmation behavior.
- Confidence: high

### Stream UI Findings

- ID: UIA-STREAM-01
- Severity: P2
- File: `Sources/open-lola-app/AppPreviewReceiverView.swift`
- Component/view/menu: Local Preview status and warning policy
- Evidence: `verifiedPreviewPhase` classifies service health using status-string tests at `AppPreviewReceiverView.swift:123-141`; `isLiveStatus` requires `status.hasPrefix("Live ")` at `AppPreviewReceiverView.swift:150-152`; failure uses string fragments such as "No ", "unavailable", "denied", "restricted", and "unknown" at `AppPreviewReceiverView.swift:158-164`; main banner warning policy consumes that phase at `AppPreviewReceiverView.swift:174-188`.
- User-visible impact: Preview health can change if controller wording changes, and a textual status that does not match these fragments may be displayed as idle instead of failed/degraded.
- Runtime impact, if any: Local RX/preview failures may fail to raise the warning banner, or a healthy preview may fail to show active state.
- Suggested remediation: Have the preview controllers expose typed health/phase values and reserve strings for display only.
- Verification needed: Unit tests over typed controller states and UI snapshot/manual tests for active, starting, disabled, degraded, and failed preview.
- Screenshot/manual test suggestion: Force no camera, no audio input, denied permission, and active preview states and verify the main banner and preview status match.
- Confidence: high

- ID: UIA-STREAM-02
- Severity: P2
- File: `Sources/open-lola-app/AppPreviewReceiverView.swift`
- Component/view/menu: Local Preview audio meters
- Evidence: The Local Preview window starts preview services on appear at `AppPreviewReceiverView.swift:282-287` and `AppPreviewReceiverView.swift:405-409`; `AppPreviewReceiverState.previewIsActive` can become active from preview services at `AppPreviewReceiverView.swift:30-33`; meter visibility ignores preview activity and only returns true when `phase == .supervisorRunning` at `AppPreviewReceiverView.swift:436-439`; otherwise the UI shows "No audio session active" at `AppPreviewReceiverView.swift:340-351`.
- User-visible impact: A local audio preview can be active while the meter area still says no audio session is active.
- Runtime impact, if any: Operators may miss local input activity or diagnose the wrong failure before a supervisor run starts.
- Suggested remediation: Gate local preview meters on the preview/audio-meter state, not only supervisor execution phase.
- Verification needed: Manual or UI test with the preview window open while the app is idle, plus a supervisor-running case.
- Screenshot/manual test suggestion: Open Local Preview Window before starting a run and confirm whether audio meters display when the audio preview service is active.
- Confidence: medium

### Diagnostics UI Findings

- ID: UIA-DIAG-01
- Severity: P2
- File: `Sources/open-lola-app/AppConsoleModels.swift`; `Sources/open-lola-app/OpenLolaApp.swift`; `Sources/open-lola-app/AppShellRootView.swift`
- Component/view/menu: Diagnostics summary cards
- Evidence: Diagnostics titles are derived from `NativeAppShellReport` fields: permissions become "Ready" when planned permission fields are true at `AppConsoleModels.swift:580-595`, realtime safety becomes "Callback-safe" from source report flags at `AppConsoleModels.swift:597-604`, and evidence can be "Synthetic source" at `AppConsoleModels.swift:618-636`; app launch initializes `report = NativeAppShellReport.placeholder()` at `OpenLolaApp.swift:18`; the Diagnostics section renders the summary cards without adding "planned/source-level" to the card titles at `AppShellRootView.swift:893-911`.
- User-visible impact: "Permissions: Ready" and "Realtime Safety: Callback-safe" can read like current runtime/device facts even when they are source-report or placeholder-derived.
- Runtime impact, if any: Operators may over-trust app readiness without actual permission prompts, device capture, or measured runtime evidence.
- Suggested remediation: Label these cards as "Planned permissions" and "Source realtime boundary" unless backed by current runtime evidence.
- Verification needed: First-launch UI test and loaded-report UI test that assert source-level wording is explicit.
- Screenshot/manual test suggestion: Launch with no measured report and inspect Diagnostics card titles and details.
- Confidence: high

### Packet/Network UI Findings

No new packet/network UI correctness finding was confirmed in this pass. `AppPacketMonitorView` has an explicit no-capture state with an expected report path and recovery action at `AppPacketMonitorView.swift:27-49`, and it distinguishes empty filter results from row-building errors at `AppPacketMonitorView.swift:137-186`. Remaining uncertainty is visual/table scaling under large reports and keyboard traversal of SwiftUI `Table`; that requires rendered-app verification.

### Settings UI Findings

- ID: UIA-SETTINGS-01
- Severity: P1
- File: `Sources/open-lola-app/AppShellSettingsTabs.swift`; `Sources/open-lola-app/AppSettings.swift`; `Sources/OpenLolaCore/Platform/NativeAppShellExecution.swift`
- Component/view/menu: Settings -> Execution -> SSH Fallback
- Evidence: The Settings Execution tab exposes SSH execution mode and SSH target/executable fields at `AppShellSettingsTabs.swift:44-61`; `NativeAppShellExecutionSettings` includes `sshFallbackExplicitlySelected` and `sshFallbackReason` at `NativeAppShellExecution.swift:53-54`; validation requires those values for `.ssh` at `NativeAppShellExecution.swift:106-112`; supervisor arguments emit `--ssh-fallback-explicit` and `--ssh-fallback-reason` at `NativeAppShellExecution.swift:139-146`; `AppSettings` and `AppSettingsDraft` include mode/target/executable fields but no fallback-explicit or reason fields at `AppSettings.swift:7-30` and `AppSettings.swift:236-251`; applying settings only sets mode, targets, workdirs, and executables at `AppSettings.swift:538-549`.
- User-visible impact: Users can select SSH execution mode in Settings but cannot satisfy the runtime validation requirements from the UI.
- Runtime impact, if any: Save can appear successful while the subsequent command fails validation or start with `sshFallbackRequiresExplicitSelection` / `sshFallbackMissingReason`.
- Suggested remediation: Either expose the required explicit opt-in and reason fields, or hide/disable SSH execution mode until the UI supports the full runtime contract.
- Verification needed: Settings test that selects SSH, saves, and verifies command generation either succeeds with explicit fields or the UI blocks the unsupported state.
- Screenshot/manual test suggestion: Enable advanced Direct Mac Peer settings, select SSH, save, and attempt command preview/start.
- Confidence: high

- ID: UIA-SETTINGS-02
- Severity: P2
- File: `Sources/open-lola-app/AppPreviewReceiverView.swift`; `Sources/open-lola-app/AppShellSettingsTabs.swift`
- Component/view/menu: Preview stream settings
- Evidence: `AppPreviewControlAvailability.visibleStreamsEnabledInLocalPreview` is hardcoded false at `AppPreviewReceiverView.swift:167-172`; the Preview Controls UI disables "Visible streams" but leaves "Selected stream" editable at `AppPreviewReceiverView.swift:216-220`; Settings does the same at `AppShellSettingsTabs.swift:285-288`; preview startup only passes audio input UID and video device ID to `startReceiverPreview` at `AppPreviewReceiverView.swift:83-100`, while `selectedVideoStream` is only displayed in the subtitle at `AppPreviewReceiverView.swift:400-402`.
- User-visible impact: "Selected stream" looks like an active routing setting even though local preview is single-stream and the value is not used to select preview input.
- Runtime impact, if any: Operators may believe they are changing local RX stream selection while only changing display text/defaults.
- Suggested remediation: Disable selected-stream editing in local preview, or wire it to real multi-stream behavior when such behavior exists.
- Verification needed: UI test/manual test proving selected stream either changes actual preview stream selection or is visibly unavailable.
- Screenshot/manual test suggestion: Change Selected stream and observe whether video/audio preview source changes or only the subtitle changes.
- Confidence: high

### Visual Readability Findings

- ID: UIA-VIS-01
- Severity: P3
- File: `Sources/open-lola-app/AppConsoleChromeView.swift`; `Sources/open-lola-app/AppShellSupportViews.swift`
- Component/view/menu: Top bar and footer status badges
- Evidence: Top bar renders search, verdict, execution status, and three icon buttons in a single `HStack` at `AppConsoleChromeView.swift:135-165`; footer renders multiple `AppStatusBadge` values in one `HStack` at `AppConsoleChromeView.swift:184-225`; `AppStatusBadge` forces `.lineLimit(1)` at `AppShellSupportViews.swift:192-196`.
- User-visible impact: Long execution statuses or localized strings can be clipped in narrow windows. Help text preserves the full value, so this is readability, not confirmed data loss.
- Runtime impact, if any: Low direct runtime impact, but clipped failure/status text can slow operator diagnosis.
- Suggested remediation: Add responsive wrapping, priority, or a compact status popover after screenshot evidence confirms clipping.
- Verification needed: Rendered screenshots at minimum and narrow supported window sizes with long `executionController.status`.
- Screenshot/manual test suggestion: Simulate a long validation/start error and capture top bar/footer at minimum window width.
- Confidence: medium

- ID: UIA-VIS-02
- Severity: P3
- File: `Sources/open-lola-app/AppLatencyHeroView.swift`
- Component/view/menu: Latency hero metric layout
- Evidence: The latency hero uses three cells in one `HStack` at `AppLatencyHeroView.swift:24-50`; every cell has `frame(minWidth: 200, maxWidth: .infinity)` at `AppLatencyHeroView.swift:67-104`; the app's adaptive grid minimum is 340 at `AppShellRootView.swift:1073-1077`.
- User-visible impact: The metric hero may overflow or compress awkwardly in a narrow detail column, especially before the app reaches a full-width desktop layout.
- Runtime impact, if any: None beyond readability of latency/loss/jitter status.
- Suggested remediation: Verify with screenshots first; if confirmed, let hero cells wrap or use an adaptive grid rather than a fixed three-cell HStack.
- Verification needed: Rendered screenshots at minimum supported width, standard width, and large width.
- Screenshot/manual test suggestion: Open Session/Overview with latency metrics present and resize the window to minimum width.
- Confidence: low

### State Correctness Findings

- ID: UIA-STATE-01
- Severity: P1
- File: `Sources/open-lola-app/AppSessionStateBanner.swift`; `Sources/open-lola-app/AppConsoleModels.swift`; `Sources/open-lola-app/AppConsoleChromeView.swift`
- Component/view/menu: Session banner, overview, and footer state
- Evidence: `AppSessionState.derive` returns `.live` for `.runFinished` or `.validationPassed` when `hasValidatedRuntimeEvidence` is true at `AppSessionStateBanner.swift:228-237`; it also returns `.live` when `lastExitCode == 0` and evidence is validated at `AppSessionStateBanner.swift:241-248`; the Overview shows `sessionState.rawValue` at `AppConsoleModels.swift:166-170`; the footer shows the derived state via `AppFooterTransportPolicy.stateTitle` at `AppConsoleChromeView.swift:243-255`.
- User-visible impact: A completed or validated run can display as "Live" even when no process is running.
- Runtime impact, if any: This is a false active-state risk for operators monitoring audio/video/network sessions. It can make historical validated evidence look like current streaming.
- Suggested remediation: Split "active live stream" from "validated completed evidence"; reserve "Live" for active runtime data flow and use a separate "Validated" or "Evidence Passed" state after completion.
- Verification needed: State-machine tests for running, run-finished, validation-passed, exit-code-zero, dry-run, stopped, and stale-evidence cases.
- Screenshot/manual test suggestion: Complete a passing run, stop/exit the process, validate the report, and verify the banner/footer/overview wording.
- Confidence: high

- ID: UIA-PLACEHOLDER-01
- Severity: P2
- File: `Sources/open-lola-app/OpenLolaApp.swift`; `Sources/open-lola-app/AppConsoleModels.swift`; `Sources/open-lola-app/AppShellRootView.swift`
- Component/view/menu: First-launch report and diagnostics surfaces
- Evidence: App launch initializes the UI with `NativeAppShellReport.placeholder()` at `OpenLolaApp.swift:18` and `AppShellStoredDefaults.placeholderOperatorSurface()` at `OpenLolaApp.swift:37`; diagnostics evidence state reports "Synthetic source" for synthetic reports at `AppConsoleModels.swift:618-636`; Diagnostics renders summary cards from that report at `AppShellRootView.swift:893-911`.
- User-visible impact: Initial UI state can look populated by report facts rather than an explicit loading/placeholder state.
- Runtime impact, if any: Placeholder/source-level state can be mistaken for measured app or device readiness before inventory/report refresh completes.
- Suggested remediation: Use explicit first-launch loading/empty states for report and operator surface until current source/runtime evidence is loaded.
- Verification needed: First-launch UI test with empty defaults and no report artifacts.
- Screenshot/manual test suggestion: Clear app defaults, launch, and capture Overview/Diagnostics before any refresh.
- Confidence: high

### Accessibility Findings

Accessibility findings in this pass are covered by UIA-MENU-01 and UIA-ACCESS-01:
- UIA-MENU-01 is a keyboard accessibility issue because the UI advertises a shortcut that the command layer does not implement.
- UIA-ACCESS-01 is a dangerous-action issue because Stop confirmation behavior is inconsistent across active runtime states and entrypoints.

No additional source-backed VoiceOver-specific finding was confirmed. Several controls include `.accessibilityLabel` and `.help` text, for example top-bar icon buttons at `AppConsoleChromeView.swift:151-164`, packet-table copy buttons at `AppPacketMonitorView.swift:165-174`, and readable metric copy buttons at `AppShellSupportViews.swift:164-177`. Remaining uncertainty requires Accessibility Inspector and keyboard-only traversal.

### UI Findings Index Addition

- Navigation/menu: UIA-MENU-01, UIA-MENU-02, UIA-NAV-01.
- Session/control UI: UIA-SESSION-01, UIA-CONTROL-01, UIA-ACCESS-01.
- Stream UI: UIA-STREAM-01, UIA-STREAM-02.
- Diagnostics UI: UIA-DIAG-01.
- Packet/network UI: no confirmed new finding; visual/table scaling remains unverified.
- Settings UI: UIA-SETTINGS-01, UIA-SETTINGS-02.
- Visual readability: UIA-VIS-01, UIA-VIS-02.
- State correctness: UIA-STATE-01, UIA-PLACEHOLDER-01.
- Accessibility: UIA-MENU-01, UIA-ACCESS-01.

### UI Runtime Verification Strategy

1. Add focused state-policy tests before changing UI behavior: `AppSessionState.derive`, `AppTransportStartPolicy`, `AppSidebarLiveNavigationPolicy`, `AppTransportStopConfirmationPolicy`, and menu-command enablement.
2. Add settings contract tests for SSH mode and preview stream controls before changing Settings UI.
3. Add preview controller state tests that use typed phases instead of string matching before changing Local Preview.
4. Run targeted app-shell tests first, then broader app-shell/native shell filters.
5. Launch the built app and capture screenshots for first launch, configured/unvalidated, armed, running, validation passed, validation failed, completed run, local preview active, and packet-monitor empty/populated states.
6. Manually verify menu shortcuts, menu enabled/disabled states, stop confirmation consistency, VoiceOver labels for icon-only buttons, and keyboard-only traversal.

### UI Coverage Gaps And Remaining Uncertainty

- No screenshots were captured, so UIA-VIS-01 and UIA-VIS-02 are source-evidence layout risks, not confirmed rendered defects.
- No Accessibility Inspector pass was run, so VoiceOver order and keyboard traversal remain unverified.
- No actual macOS menu invocation was performed; menu findings are based on source-level action/shortcut mapping.
- No live camera/audio/permission prompts were exercised; preview and diagnostics findings are source-backed but not device-verified.
- No packet table with a very large capture report was rendered; packet/network UI scaling remains open.
- Existing docs verification is expected to remain blocked while `plan-remediation-ledger.md` and `plan-remediation-status.md` are missing from the dirty worktree; this pass did not recreate them because only `plan.md` may be modified.

### Next UI Audit Areas

- Rendered app screenshots across light/dark/high-contrast appearances and minimum window sizes.
- App menu smoke test against `NativeAppShellSurfaceContract.releaseReadiness` actions.
- Keyboard-only navigation through sidebar, transport controls, Settings tabs, Packet Monitor table, and Local Preview window.
- First-launch/defaults reset smoke test to verify placeholder/loading behavior.
- Device-permission manual run for microphone/camera/local-network wording.
- Local Preview manual run with no audio device, no camera, denied permission, active audio, and active video.

## 30. Logic Correctness, Test Quality, Verification, And False-Success Audit Pass

Date: 2026-05-20

Scope: audit-only continuation focused on false success, logic correctness, tests, verification quality, and runtime-proof gaps. This pass inspected source and tests directly and did not modify production code or tests.

Files and evidence inspected in this pass:
- `docs/testing.md`
- `.github/workflows/release-readiness.yml`
- `scripts/verify-release-readiness.sh`
- `script/build_and_run.sh`
- `Sources/open-lola-app/AppExecutionController.swift`
- `Sources/open-lola-app/AppRuntimeEvidenceScope.swift`
- `Sources/open-lola-app/AppLatencyHeroMetrics.swift`
- `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerLocalRunReport.swift`
- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift`
- `Sources/OpenLolaCore/Network/UDP/UdpPcmRouteRunConfiguration.swift`
- `Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift`
- `Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift`
- `Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift`
- `Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift`
- `Tests/OpenLolaCoreTests/AppExecutionControllerValidationTests.swift`
- `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`
- `Tests/OpenLolaCoreTests/NativeAppShellTests.swift`
- `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`
- `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift`
- `Tests/OpenLolaCoreTests/MachineReadableSurfaceContractTests.swift`
- `Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift`
- `Tests/OpenLolaCoreTests/DirectPeerSessionReportAVPassTests.swift`
- `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift`
- `Tests/OpenLolaCoreTests/OpenSourceReleaseReadinessTests.swift`
- `Tests/OpenLolaCoreTests/JackTripPassValidationTests.swift`
- `Tests/OpenLolaCoreTests/UltraGridCompatibilityTests.swift`
- `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`
- `Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift`

No P0 finding was confirmed in this pass. Several P1 false-success and stale-verification risks were confirmed or remain plausible with high enough impact to require targeted tests before runtime claims are upgraded.

### Evidence-Bounded Non-Findings And Limits

- UDP route report validation already has source-level checks for several false-pass cases: `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift:30-105` mutates DSCP, capture correlation, route kind, packet counts, receive errors, playout target, hidden playout growth, loss, duplicates, reordering, placeholder capture point, and packet accounting. This does not prove live route correctness.
- CI includes three focused Thread Sanitizer smokes at `.github/workflows/release-readiness.yml:53-60`, but those are not full concurrency coverage for app state, process lifecycle, UDP socket loops, audio callbacks, or video capture.
- The active verification index explicitly warns that source/policy/inventory tests are useful gates but are not runtime proof at `docs/testing.md:67-79`.
- The active verification index lists real-world closure as manual at `docs/testing.md:172-182`; this pass did not run hardware, two-Mac, camera, packet-capture, signing, or clean-Mac checks.

### False-Success And Logic Findings

- ID: LTV-FS-01
- Severity: P1
- File: `Sources/open-lola-app/AppExecutionController.swift`; `Sources/open-lola-app/AppRuntimeEvidenceScope.swift`
- Function/test/symbol: `validationReadiness`, `launchProcess`, `finishValidation`, `hasValidatedRuntimeEvidenceState`
- Evidence: `validationReadiness` only checks that the report path exists and the sidecar session token matches at `AppExecutionController.swift:314-337`; `launchProcess` writes a new token sidecar before the child process proves that it rewrote the report at `AppExecutionController.swift:512-534`; `finishValidation` accepts validation when `exitCode == 0` and `hasValidatedRuntimeEvidence` is true at `AppExecutionController.swift:380-399`; `hasValidatedRuntimeEvidenceState` checks the sidecar token and then trusts loaded metrics at `AppRuntimeEvidenceScope.swift:60-94`.
- Why existing verification is insufficient: Existing tests cover token mismatch and validation states, but this pass did not find a test where an old PASS report remains at the same path, a new sidecar token is written, and the new process exits `0` without producing current report content.
- What test should exist: A fake process or controller harness should start a run with a stale PASS report already present, write a fresh sidecar token, exit `0` without rewriting the report, and assert validation fails.
- What edge case should be checked: Fresh sidecar token with stale report content, stale captured timestamp, stale run id, unchanged file modification time, or unchanged embedded session identity.
- What command should verify it: `swift test --filter AppExecutionControllerValidationTests --no-parallel` and `swift test --filter AppShellBehaviorTests --no-parallel`.
- Confidence: high

- ID: LTV-FS-02
- Severity: P1
- File: `Sources/open-lola-app/AppLatencyHeroMetrics.swift`; `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- Function/test/symbol: `AppLatencyHeroMetrics.loadResult`, `AppLatencyHeroMetrics.isPartial`, `appExecutionValidationRequiresCompleteCurrentReportEvidence`
- Evidence: `loadResult` decodes `DirectPeerTwoPeerLocalRunReport` and child `DirectPeerSessionReport` values but does not call `validate()` on either report at `AppLatencyHeroMetrics.swift:49-82`; `isPartial` only checks supervisor verdict, loaded peer count, and load failures at `AppLatencyHeroMetrics.swift:13-15`; the app-shell test writes a supervisor `.pass` report with default missing aggregate and receive-proof fields at `AppShellBehaviorTests.swift:871-883`; the child helper returns a `.partial` `DirectPeerSessionReport` at `AppShellBehaviorTests.swift:1367-1415`; the test still expects validation passed and `hasValidatedRuntimeEvidence` true at `AppShellBehaviorTests.swift:889-896`.
- Why existing verification is insufficient: The test proves that app validation can turn a passing supervisor string plus loadable peer JSON into app-level validated evidence even when the report graph would not satisfy the deeper report validators.
- What test should exist: App validation should reject a supervisor `.pass` report that fails `DirectPeerTwoPeerLocalRunReport.validate()` or references child reports that fail `DirectPeerSessionReport.validate()`.
- What edge case should be checked: Supervisor PASS missing `aggregateReportPath`, `aggregateExecuted`, `collectedReportPath`, or `collectedReceiveProofPath`; child report `.partial`; invalid child metrics; child file decoded but validator failure.
- What command should verify it: `swift test --filter AppShellBehaviorTests --no-parallel`.
- Confidence: high

- ID: LTV-FS-03
- Severity: P1
- File: `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerLocalRunReport.swift`; `Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift`
- Function/test/symbol: `DirectPeerTwoPeerLocalRunReport.validate`, `DirectPeerTwoPeerLocalRunReportBuilder.makeReport`, `directPeerTwoPeerLocalRunReportHandlesPassDowngradeAndMissingAggregateEvidence`
- Evidence: PASS validation requires non-empty aggregate, collected report, and receive-proof path strings at `DirectPeerTwoPeerLocalRunReport.swift:169-184`, but does not check that those files exist or decode/validate referenced artifacts; the builder marks PASS from `aggregateExecuted`, non-empty paths, and zero exit codes at `DirectPeerTwoPeerLocalRunReport.swift:223-229`; the test constructs a passing report from path strings and calls `validate()` at `DirectPeerTwoPeerRunPlanTests.swift:101-124`.
- Why existing verification is insufficient: String-level report validation can produce a PASS-shaped artifact without proving the aggregate report, peer reports, or receive proofs are present and valid.
- What test should exist: A PASS candidate with nonexistent aggregate, collected report, or receive-proof paths should fail an artifact-aware validator, or the current validator should be explicitly scoped and a separate artifact validation command should be tested.
- What edge case should be checked: Nonexistent paths, empty files, invalid JSON files, child reports with `.partial`, and receive-proof files that do not match the peer report.
- What command should verify it: `swift test --filter DirectPeerTwoPeerRunPlanTests --no-parallel` plus the validator command for direct P2P two-peer reports once artifact validation exists.
- Confidence: high

- ID: LTV-FS-04
- Severity: P1
- File: `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift`; `Tests/OpenLolaCoreTests/DirectPeerSessionReportAVPassTests.swift`
- Function/test/symbol: `validatePassMeasuredEvidence`, `directPeerSessionAVPassRejectsInvalidPassEvidence`, `avPassCandidate`
- Evidence: PASS requires physical measured evidence and positive sent/received/routed counts at `DirectPeerSessionReport.swift:191-240`; the AV PASS candidate starts from `DirectPeerSessionSocketRunner.runLoopback(packetCount: 2)` at `DirectPeerSessionReportAVPassTests.swift:92-94`, then mutates fields to production devices, physical peer labels, packet capture paths, DSCP, clock, raw video evidence, and `.pass` at `DirectPeerSessionReportAVPassTests.swift:95-141`.
- Why existing verification is insufficient: The test proves validator shape rules with a locally synthesized loopback base, but it does not prove that PASS evidence is tied to non-loopback socket endpoints or real captured artifacts.
- What test should exist: PASS should be rejected when measured evidence claims `.physicalTwoPeerMacs` but the report configuration or generated metrics come from loopback/local endpoints or missing artifacts.
- What edge case should be checked: Loopback endpoints with physical labels, artifact paths that do not exist, packet capture path not correlated to peer endpoints, nonzero loss, recovery events, and out-of-budget jitter.
- What command should verify it: `swift test --filter DirectPeerSessionReportAVPassTests --no-parallel`.
- Confidence: high

- ID: LTV-FS-05
- Severity: P1
- File: `Sources/OpenLolaCore/Network/UDP/UdpPcmRouteRunConfiguration.swift`; `Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift`; `Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift`; `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift`
- Function/test/symbol: `UdpPcmRouteRunConfiguration.parse`, `runReceiverLoop`, `UdpPcmRouteReport.validatePassVerdict`, `udpPcmRouteReportRejectsInvalidEvidence`
- Evidence: The route runner accepts operator-provided metadata and verdict via `--route-kind`, endpoint labels/IPs, DSCP/capture fields, and `--verdict` at `UdpPcmRouteRunConfiguration.swift:199-260`; `runReceiverLoop` copies those fields into the report and uses `configuration.verdict` at `UdpPcmContinuousRouteRunner.swift:220-267`; PASS validation rejects localhost route kind, missing capture correlation, not-tested DSCP, loss, late, duplicate, reordered, hidden growth, harmful DSCP, and placeholder fields at `UdpPcmRouteCertification.swift:415-489`; tests cover many mutated report false-pass cases at `UdpPcmRouteReportTests.swift:30-105`.
- Why existing verification is insufficient: Existing tests validate report fields after construction, but they do not prove that operator-supplied physical metadata is consistent with the actual socket bind host, peer host, route kind, and packet capture. A localhost or same-host run can be labeled as a physical direct link unless consistency rules prove otherwise.
- What test should exist: A route-run harness should attempt to produce PASS with loopback or same-host sockets plus direct-link metadata and assert validation or report generation downgrades to PARTIAL.
- What edge case should be checked: `--peer 127.0.0.1` or same host with `--route-kind directLink`, capture-correlated true but no capture artifact, direct-link endpoint labels on loopback sockets, and mismatched sender/receiver IP metadata.
- What command should verify it: `swift test --filter UdpPcmRouteReportTests --no-parallel` plus a focused UDP route-run integration test.
- Confidence: medium

- ID: LTV-FS-06
- Severity: P2
- File: `Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift`; `Tests/OpenLolaCoreTests/OpenSourceReleaseReadinessTests.swift`; `scripts/verify-release-readiness.sh`
- Function/test/symbol: `OpenSourceReleaseReadinessRunner.run`, `releaseApprovalPassesConformingManifest`, `main`
- Evidence: Open-source readiness verdict becomes PASS when text-file requirements have no blockers at `OpenSourceReleaseReadiness.swift:153-170`; the conforming-manifest test creates minimal temporary files and a `Verdict: PASS` line and expects overall PASS at `OpenSourceReleaseReadinessTests.swift:79-99` and `OpenSourceReleaseReadinessTests.swift:229-274`; the release wrapper still prints `product-runtime-verdict: partial` and final `VERDICT: PARTIAL` at `scripts/verify-release-readiness.sh:224-226`.
- Why existing verification is insufficient: The source-level PASS is intentionally a preflight, but a text-marker PASS can be misread as runtime or publication proof unless script and docs tests keep the boundary explicit.
- What test should exist: A release-readiness integration test should assert that even when open-source readiness passes, the wrapper never emits product `PASS` unless manual runtime/hardware/signing gates are represented by validated artifacts.
- What edge case should be checked: Open-source PASS with missing staged release candidate, missing signed/notarized app, no hardware evidence, or stale release manifest.
- What command should verify it: `swift test --filter OpenSourceReleaseReadinessTests --no-parallel` and `swift test --filter VerificationToolingContractTests --no-parallel`.
- Confidence: medium

### Test And Verification Quality Findings

- ID: LTV-TEST-01
- Severity: P2
- File: `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`
- Function/test/symbol: `appTransportStopConfirmationOnlyBlocksLiveSessions`, `appTransportStartPolicyRequiresPassingValidationAfterFailure`, `appSidebarNavigatesToSessionOnlyOnLiveTransition`, `appStateAndRuntimeEvidenceScopeDoNotReportLiveWithoutValidatedEvidence`
- Evidence: Tests currently assert no stop confirmation for `.supervisorRunning` at `AppShellBehaviorTests.swift:63-70`; allow start when validation is `.unknown` at `AppShellBehaviorTests.swift:117-134`; only auto-navigate to Session on `.live`, not `.supervisorRunning`, at `AppShellBehaviorTests.swift:176-198`; and assert `.runFinished` plus validated evidence derives `.live` at `AppShellBehaviorTests.swift:347-420`.
- Why existing verification is insufficient: These tests lock in current policy choices that overlap with UI/runtime false-state findings instead of testing the operator intent that active, validated, failed, and completed states are visibly distinct.
- What test should exist: State-policy tests should express the desired invariant: active controls require active runtime proof, completed validated evidence is not "Live", dangerous stop confirmation applies to active supervisor runs, and start policy requires the selected validation contract.
- What edge case should be checked: Running-but-not-live, finished-with-evidence, finished-with-stale-evidence, validation unknown, validation failed, dry run, and stop-requested states.
- What command should verify it: `swift test --filter AppShellBehaviorTests --no-parallel`.
- Confidence: high

- ID: LTV-TEST-02
- Severity: P2
- File: `Tests/OpenLolaCoreTests/AppExecutionControllerValidationTests.swift`; `Sources/open-lola-app/AppExecutionController.swift`
- Function/test/symbol: `appExecutionValidationRejectsSecondLaunchWhileValidationIsInFlight`, `finishValidation`
- Evidence: The controller validation test file only covers rejecting a second launch while validation is in flight at `AppExecutionControllerValidationTests.swift:1-16`; `finishValidation` loads and summarizes a report before branching on nonzero validation exit at `AppExecutionController.swift:380-399`.
- Why existing verification is insufficient: There is no focused controller test that proves nonzero validation exit keeps app state failed even if a PASS-shaped report already exists at the configured path.
- What test should exist: A validation failure test should seed an otherwise passing direct-peer or connector report, call `finishValidation(exitCode: 1)`, and assert `phase == .validationFailed`, no validated evidence, no "Validation passed" status, and no live session state.
- What edge case should be checked: Exit code `1` with pass report, exit code `77` skip/readiness result, malformed report with exit code `0`, and missing report with exit code `0`.
- What command should verify it: `swift test --filter AppExecutionControllerValidationTests --no-parallel`.
- Confidence: medium

- ID: LTV-TEST-03
- Severity: P2
- File: `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`; `scripts/verify-release-readiness.sh`
- Function/test/symbol: `releaseReadinessScriptDefinesLocalVerificationMatrix`, `main`
- Evidence: The test stubs `run_step`, `run_timed_step`, CLI probes, goal probes, open-source readiness, and app launch to print success-like lines and then expects status `0` plus final verdict lines at `VerificationToolingContractTests.swift:5-67`; the real script prints final source/product verdicts after all probes at `scripts/verify-release-readiness.sh:179-226`.
- Why existing verification is insufficient: The contract test proves command enumeration, but it does not prove failure propagation or that final verdict lines are suppressed when a critical step fails.
- What test should exist: Failure-path contract tests should stub one step at a time to return nonzero or wrong verdict text and assert the script exits nonzero before printing final verdict lines.
- What edge case should be checked: Failing `swift test`, timed command failure, CLI probe emits PASS when PARTIAL expected, app launch verifier failure, open-source readiness failure, and goal probe missing blocker output.
- What command should verify it: `swift test --filter VerificationToolingContractTests --no-parallel`.
- Confidence: high

- ID: LTV-TEST-04
- Severity: P2
- File: `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`; `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift`
- Function/test/symbol: `runShell`, `runBashScript`
- Evidence: Both helpers call `process.waitUntilExit()` before draining stdout/stderr and have no timeout at `VerificationToolingContractTests.swift:248-269` and `ReleaseArtifactHygieneContractTests.swift:646-669`.
- Why existing verification is insufficient: A verbose or stuck child process can deadlock the test harness or hang indefinitely instead of failing with bounded output.
- What test should exist: A harness test should run a child that writes enough stdout/stderr to fill a pipe and another child that sleeps beyond a timeout, then assert bounded failure.
- What edge case should be checked: Large stdout, large stderr, mixed output, never-exiting child, and child killed by timeout.
- What command should verify it: `swift test --filter VerificationToolingContractTests --no-parallel` and `swift test --filter ReleaseArtifactHygieneContractTests --no-parallel`.
- Confidence: medium

- ID: LTV-TEST-05
- Severity: P1
- File: `Tests/OpenLolaCoreTests/MachineReadableSurfaceContractTests.swift`
- Function/test/symbol: `requiredOpenLolaCLIURL`, `runRequiredOpenLolaCLI`
- Evidence: The helper accepts the first executable found at `/private/tmp/open-lola2-swiftpm-build/debug/open-lola`, `.build/debug/open-lola`, or `.build/arm64-apple-macosx/debug/open-lola` and only checks executability at `MachineReadableSurfaceContractTests.swift:200-210`; command execution then uses that path at `MachineReadableSurfaceContractTests.swift:213-225`.
- Why existing verification is insufficient: Machine-readable CLI tests can pass against a stale binary from a previous build, which is a direct false-success risk for command/report surface changes.
- What test should exist: The test harness should build or receive the current product binary in an isolated build directory, or assert the binary timestamp/hash corresponds to the current source build.
- What edge case should be checked: Existing stale `/private/tmp` binary, stale `.build` binary after source edits, missing binary, and multiple architecture output paths.
- What command should verify it: `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build` followed by `swift test --filter MachineReadableSurfaceContractTests --no-parallel`.
- Confidence: high

- ID: LTV-TEST-06
- Severity: P2
- File: `Tests/OpenLolaCoreTests/DirectPeerSessionReportAVPassTests.swift`; `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift`
- Function/test/symbol: `directPeerSessionAVPassRejectsInvalidPassEvidence`, `validateMetrics`, `validatePassMeasuredEvidence`
- Evidence: Metrics validation requires nonnegative loss, jitter, and recovery events at `DirectPeerSessionReport.swift:63-85`; PASS evidence requires positive sent, received, and routed packet counts at `DirectPeerSessionReport.swift:191-240`; the invalid PASS test mutates many AV/evidence fields at `DirectPeerSessionReportAVPassTests.swift:5-75`, but this pass did not find loss, recovery, or jitter budget assertions.
- Why existing verification is insufficient: The intended PASS policy for loss, jitter, and recovery is not encoded in tests. If nonzero loss or excessive jitter should block PASS, current tests would not catch a false PASS.
- What test should exist: Add explicit PASS policy tests for loss, late packets, jitter budget, recovery events, and audio/video routing counters.
- What edge case should be checked: `packetsLost > 0`, `recoveryEvents > 0`, high `jitterMicroseconds`, `packetsSent != packetsReceived + packetsLost`, and video routed while receive proof frames disagree.
- What command should verify it: `swift test --filter DirectPeerSessionReportAVPassTests --no-parallel`.
- Confidence: medium

- ID: LTV-TEST-07
- Severity: P2
- File: `Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift`; `Tests/OpenLolaCoreTests/JackTripPassValidationTests.swift`; `Tests/OpenLolaCoreTests/UltraGridCompatibilityTests.swift`; `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`; `Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift`
- Function/test/symbol: `syntheticValidationFixtureGroups`, `jackTripInvalidSyntheticPassFixtureIsRejected`, `ultraGridInvalidSyntheticPassFixtureIsRejected`, `reportSchemaFalsePassFixturesFailThroughPublicValidators`, `fixtureSmokeMatrixTracksHighRiskFalsePassFixtures`
- Evidence: JackTrip and UltraGrid fixture groups are listed without `validator` or `falsePass` entries at `FixtureSmokeMatrixData.swift:32` and `FixtureSmokeMatrixData.swift:37`; connector-local tests reject invalid synthetic PASS fixtures at `JackTripPassValidationTests.swift:45-54` and `UltraGridCompatibilityTests.swift:458-467`; central false-pass inventory tests only cover registered false-pass fixtures at `ReportSchemaInventoryTests.swift:257-287` and `FixtureSmokeMatrixTests.swift:58-83`.
- Why existing verification is insufficient: Connector false-pass fixtures are tested locally but are not represented in the central false-pass inventory, so inventory-based release/report gates can undercount connector false-pass coverage.
- What test should exist: The fixture matrix should either register connector false-pass fixtures with public validators or explicitly mark them connector-local with a tested reason.
- What edge case should be checked: JackTrip and UltraGrid invalid synthetic PASS fixtures missing from central summary, missing public validator command, and fixture group count mismatches.
- What command should verify it: `swift test --filter ReportSchemaInventoryTests --no-parallel` and `swift test --filter FixtureSmokeMatrixTests --no-parallel`.
- Confidence: medium

- ID: LTV-TEST-08
- Severity: P2
- File: `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`; `Tests/OpenLolaCoreTests/NativeAppShellTests.swift`
- Function/test/symbol: `NativeAppShellSettingsVisibility.visibleGroups`, `NativeAppShellExecutionSettings.supervisorArguments`
- Evidence: Settings visibility tests assert SSH fallback controls are visible in advanced direct mode at `AppShellSlice05Tests.swift:228-248`; runtime execution tests require explicit SSH selection, reason, peer targets, work directories, and ssh/scp executables before generating SSH supervisor arguments at `NativeAppShellTests.swift:196-230`.
- Why existing verification is insufficient: This pass did not find a bridge test proving that the Settings UI fields persist into `NativeAppShellExecutionSettings` and generate the runtime SSH arguments required by the runtime contract.
- What test should exist: A UI/settings contract test should set advanced SSH fallback fields through app settings/state, build execution settings, and assert the resulting supervisor arguments contain all required SSH fields.
- What edge case should be checked: Visible but unwired SSH fallback fields, blank reason, one missing peer target, default local mode despite SSH UI selection, and stale persisted values after switching modes.
- What command should verify it: `swift test --filter AppShellSlice05Tests --no-parallel` and `swift test --filter NativeAppShellTests --no-parallel`.
- Confidence: high

### Runtime Harness And Integration Gap Findings

- ID: LTV-HARNESS-01
- Severity: P2
- File: `docs/testing.md`; `scripts/verify-release-readiness.sh`; `.github/workflows/release-readiness.yml`
- Function/test/symbol: active verification index, release readiness wrapper, CI workflow
- Evidence: The active verification index lists external connector parity commands and states exit `77` is not PASS at `docs/testing.md:110-127`; real-world closure remains manual for two-Mac UDP/P2P, packet capture, DSCP/PTP, jitter/loss, hardware, video, signing, and clean-Mac launch at `docs/testing.md:172-182`; the release wrapper runs source gates and probes but keeps product runtime partial at `scripts/verify-release-readiness.sh:179-226`; CI runs the wrapper and three TSan smokes at `.github/workflows/release-readiness.yml:50-60`.
- Why existing verification is insufficient: The default verification contract does not include degraded-network simulation, physical two-peer packet capture, reference-peer parity, or device-loopback evidence, so it cannot close runtime readiness.
- What test should exist: Opt-in but deterministic integration jobs should cover degraded UDP/P2P, reference-peer parity when prerequisites are present, and two-Mac evidence ingestion/validation.
- What edge case should be checked: Loss, jitter, reordering, duplication, peer reconnect, peer disconnect, route timeout, reference peer unavailable, and exit `77` misreported as pass.
- What command should verify it: `bash scripts/verify-release-readiness.sh`, `bash scripts/run-reference-peer-parity-gate.sh /private/tmp/open-lola-reference-peer-parity-ultragrid ultragrid`, and `bash scripts/run-reference-peer-parity-gate.sh /private/tmp/open-lola-reference-peer-parity-jacktrip jacktrip`.
- Confidence: high

- ID: LTV-HARNESS-02
- Severity: P1
- File: `docs/testing.md`; `Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift`; `Tests/OpenLolaCoreTests/VideoTransportRunnerTests.swift`
- Function/test/symbol: manual evidence gates, realtime audio tests, video transport tests
- Evidence: The testing index requires RME/MADI hardware, loopback, realtime callback ownership, two-Mac UDP/P2P packet capture, and Blackmagic/ATEM or reviewed video capture evidence at `docs/testing.md:172-182`; source-level audio and video tests exist, but this pass did not find evidence that they execute real Core Audio device I/O, physical audio loopback, camera capture, or Blackmagic/ATEM capture in the standard verification matrix.
- Why existing verification is insufficient: Source and synthetic runtime tests can catch logic regressions, but they do not prove callback deadline behavior, hardware route correctness, device permissions, device loss/recovery, capture timing, or audio-impact from video.
- What test should exist: Dedicated audio loopback and video loopback harnesses should run outside ordinary unit tests, produce machine-readable reports, and be required before field/runtime PASS claims.
- What edge case should be checked: Missing input/output device, denied microphone/camera permission, device disconnect during run, callback overrun/underrun, fastest 32-frame buffer, camera frame drop, video enabled while audio latency is measured, and shutdown cleanup.
- What command should verify it: A future hardware harness command, plus current source gates `swift test --filter RealtimeAudioEngineTests --no-parallel` and `swift test --filter VideoTransportRunnerTests --no-parallel` as non-hardware checks.
- Confidence: high

### Verification Contract

Status: source-level verification is defined, runtime verification remains PARTIAL until the harness gaps above are closed.

Build commands:
- `swift build`
- `swift build --product open-lola`
- `swift build --product open-lola-app`
- `bash script/build_and_run.sh --verify`
- `bash scripts/verify-release-readiness.sh`

Lint and docs commands:
- `bash scripts/verify-docs.sh`
- `python3 -m scripts.verify_docs`
- `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh`
- `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`
- `bash scripts/verify-release-hygiene.sh`
- `git diff --check`

Typecheck commands:
- `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`
- Swift typechecking is covered by `swift build` and focused `swift test` commands.

Unit test commands:
- `swift test --no-parallel`
- `swift test --filter AppExecutionControllerValidationTests --no-parallel`
- `swift test --filter AppShellBehaviorTests --no-parallel`
- `swift test --filter VerificationToolingContractTests --no-parallel`
- `swift test --filter MachineReadableSurfaceContractTests --no-parallel`
- `swift test --filter DirectPeerSessionReportAVPassTests --no-parallel`
- `swift test --filter DirectPeerTwoPeerRunPlanTests --no-parallel`
- `swift test --filter UdpPcmRouteReportTests --no-parallel`
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`

Integration test commands:
- `bash scripts/verify-release-readiness.sh`
- `bash scripts/run-reference-peer-parity-gate.sh /private/tmp/open-lola-reference-peer-parity-ultragrid ultragrid`
- `bash scripts/run-reference-peer-parity-gate.sh /private/tmp/open-lola-reference-peer-parity-jacktrip jacktrip`
- Docker/WSL connector helper probes documented from `scripts/README.md` remain process evidence unless paired with reference peers and packet/media proof.

Manual runtime checks:
- Stage and launch `dist/OpenLoLa.app` through `bash script/build_and_run.sh --verify`; treat any launch, accessibility-label, signing, or bundle mismatch as a user-visible caveat.
- Run clean-Mac app launch, Developer ID/notarization/Gatekeeper checks, and hardware route checks before release/runtime PASS.

UI checks:
- App-shell state tests for active, armed, running, validating, validation passed, validation failed, run finished, stopped, stale evidence, and first-launch placeholder states.
- Manual menu and keyboard traversal checks for command availability and dangerous actions.
- Screenshot checks for first launch, configured/unvalidated, running, validation passed, validation failed, completed run, Local Preview active, and Packet Monitor empty/populated states.

UDP/P2P degraded-network checks:
- Deterministic degraded-network harness for loss, jitter, reordering, duplication, late packets, disconnect, reconnect, and route timeout.
- Two-Mac direct P2P run with packet capture, DSCP/PTP evidence, and artifact-aware report validation.
- Explicit assertion that exit `77` or skipped prerequisites are not PASS.

Audio loopback checks:
- Hardware loopback with named Core Audio device UIDs, RME/MADI route, fastest 32-frame profile, callback deadline/underrun/overrun counters, input/output device loss, and shutdown cleanup.

Video loopback checks:
- AVFoundation and/or Blackmagic/ATEM capture with frame timing, frame drop, receive/render proof, audio-impact measurement, permission-denied state, and device disconnect recovery.

TX/RX state checks:
- TX should become active only after packet/media flow evidence exists.
- RX should become active only after receiving valid packets or frames, not after socket setup alone.
- Local RX should distinguish local preview/source activity from network receive.
- Teardown should clear active flags after process exit, stop request, failure, or validation-only runs.

### Test Gap Matrix

| Area | Current evidence | Gap | Required test or harness | Verification command |
| --- | --- | --- | --- | --- |
| App stale evidence | Sidecar token and metrics gates exist in `AppExecutionController` and `AppRuntimeEvidenceScope` | Fresh sidecar can be paired with stale report content | Fake process stale-report harness | `swift test --filter AppExecutionControllerValidationTests --no-parallel` |
| App report graph validation | App latency metrics decodes supervisor and peer reports | App does not validate supervisor or child report graph before declaring evidence complete | Invalid supervisor/child PASS rejection test | `swift test --filter AppShellBehaviorTests --no-parallel` |
| Direct P2P two-peer artifacts | Report validator requires non-empty artifact paths | No artifact existence/decode/provenance validation | Artifact-aware validator or separate validation command | `swift test --filter DirectPeerTwoPeerRunPlanTests --no-parallel` |
| Direct P2P PASS provenance | PASS shape tests start from loopback and mutate evidence | Physical evidence is not tied to non-loopback runtime endpoints | Loopback-as-physical false-pass test | `swift test --filter DirectPeerSessionReportAVPassTests --no-parallel` |
| UDP route metadata | Route report tests mutate false-pass fields | Actual socket endpoints are not checked against operator metadata | Loopback/direct-link mismatch integration test | `swift test --filter UdpPcmRouteReportTests --no-parallel` |
| Verification script failure paths | Matrix test stubs all steps as success | No negative contract tests for failed gates | Failure propagation tests for each critical step | `swift test --filter VerificationToolingContractTests --no-parallel` |
| Shell harness robustness | Helpers run child processes | No timeout or concurrent pipe draining | Timeout and large-output tests | `swift test --filter VerificationToolingContractTests --no-parallel` |
| CLI executable tests | Machine-readable tests use first executable found | Stale binary can satisfy tests | Isolated current-product build or freshness assertion | `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build` |
| App Settings to runtime | Runtime SSH settings are validated; settings group visibility is tested | No settings-to-execution bridge test | Advanced SSH UI contract test | `swift test --filter AppShellSlice05Tests --no-parallel` |
| Connector false-pass inventory | JackTrip/UltraGrid invalid fixtures rejected locally | Central inventory does not register those false-pass fixtures | Inventory registration or explicit connector-local exception | `swift test --filter ReportSchemaInventoryTests --no-parallel` |
| Release/source PASS boundary | Release wrapper keeps product partial | Text-marker source PASS can be misread as runtime proof | Wrapper negative/partial-boundary tests | `swift test --filter OpenSourceReleaseReadinessTests --no-parallel` |
| Degraded network | Some packet and route validators cover malformed/loss/reorder fields | No end-to-end degraded UDP/P2P runtime harness | Loss/jitter/reorder/duplicate/reconnect simulation | future harness plus `bash scripts/verify-release-readiness.sh` |
| Audio hardware | Source-level realtime audio tests exist | No standard hardware loopback gate | RME/MADI/Core Audio loopback harness | future hardware command |
| Video hardware | Source-level video transport tests exist | No standard capture/render loopback gate | AVFoundation/Blackmagic loopback harness | future hardware command |

### Runtime Harness Recommendations

1. Add a stale-report app validation harness before changing app state wording. It should exercise a child process that exits successfully without rewriting report content.
2. Add artifact-aware direct P2P validation. Keep schema validation separate if necessary, but do not let schema validation be presented as artifact proof.
3. Add a direct P2P provenance harness that rejects loopback-derived reports upgraded to physical PASS by field mutation alone.
4. Add a UDP route consistency harness that compares actual bind/peer socket addresses with route metadata before PASS.
5. Add release-readiness negative tests before relying on script-output tests as CI gate evidence.
6. Add an isolated current-binary contract for machine-readable CLI surface tests.
7. Add degraded-network simulations for UDP/P2P packet loss, jitter, reordering, duplication, disconnect, and reconnect.
8. Add RME/MADI/Core Audio loopback harness output that can be validated by CLI and app surfaces.
9. Add AVFoundation/Blackmagic video loopback output that can be validated without implying audio runtime PASS.
10. Add app UI state harnesses that prove "Live", "Streaming", "Connected", and "Healthy" only appear with current runtime proof.

### P0/P1 Logic And Verification Remediation Roadmap

1. Fix the app false-success validation gap first: LTV-FS-02, then LTV-FS-01. Verification target: focused app-controller/app-shell tests plus app state screenshots.
2. Fix stale executable verification next: LTV-TEST-05. Verification target: isolated build path and machine-readable surface tests.
3. Add artifact/provenance validation for Direct P2P PASS: LTV-FS-03 and LTV-FS-04. Verification target: direct P2P report tests and an artifact-aware validator command.
4. Add UDP route metadata/socket consistency tests: LTV-FS-05. Verification target: route report tests plus a small route-run integration harness.
5. Add hardware/runtime harnesses before any runtime PASS upgrade: LTV-HARNESS-02 and LTV-HARNESS-01.

### Findings Index Addition For This Pass

| ID | Severity | Area | Short title |
| --- | --- | --- | --- |
| LTV-FS-01 | P1 | App validation | Fresh sidecar token can still rely on stale report content |
| LTV-FS-02 | P1 | App validation | App latency metrics accepts invalid direct-peer PASS graph |
| LTV-FS-03 | P1 | Direct P2P | Two-peer PASS validates path strings, not artifacts |
| LTV-FS-04 | P1 | Direct P2P | Loopback-derived session can be mutated into physical PASS candidate |
| LTV-FS-05 | P1 | UDP | Route-run PASS metadata is not proven against actual socket topology |
| LTV-FS-06 | P2 | Release | Source-level release PASS is text-marker based |
| LTV-TEST-01 | P2 | App tests | Tests codify questionable active-state policies |
| LTV-TEST-02 | P2 | App tests | Validation failure with PASS-shaped report is not covered |
| LTV-TEST-03 | P2 | Verification | Release-readiness script test only proves all-green stub path |
| LTV-TEST-04 | P2 | Test harness | Shell helpers can hang on large output or stuck children |
| LTV-TEST-05 | P1 | CLI tests | Machine-readable surface tests can use stale binary |
| LTV-TEST-06 | P2 | Direct P2P tests | PASS policy lacks loss, jitter, and recovery edge tests |
| LTV-TEST-07 | P2 | Fixture inventory | Connector false-pass fixtures are underrepresented centrally |
| LTV-TEST-08 | P2 | App settings tests | Settings-to-runtime SSH fallback bridge is untested |
| LTV-HARNESS-01 | P2 | Integration | Degraded-network and reference-peer gates are not default proof |
| LTV-HARNESS-02 | P1 | Runtime harness | Audio/video hardware loopback gates are missing from standard proof |

### Remaining Uncertainty For This Pass

- No Swift tests, Python tests, app launches, hardware runs, or network simulations were executed during this audit pass.
- The plan now names specific test and harness tasks, but it does not prove those tasks will pass or that the proposed behavior is already correct.
- Some validators may intentionally be schema-only. Where that is the intended contract, the remediation should rename or document the boundary and add a separate artifact/runtime validator rather than overloading schema validation.
- UDP route PASS validation already rejects many report-level false-pass fields. The remaining risk is specifically metadata-to-socket consistency and runtime topology proof.
- Existing docs verification is expected to remain blocked while `plan-remediation-ledger.md` and `plan-remediation-status.md` are missing from the dirty worktree; this pass did not recreate them because only `plan.md` may be modified.

</details>
