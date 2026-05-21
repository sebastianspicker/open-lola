# Code Index

Date: 2026-05-20
Scope: source-file inventory before cleanup or refactor.
Verdict: directory-first, partially file-level.

This is an inventory, not a cleanup plan. It was built from the live checkout
using `Package.swift`, `rg --files`, line-count scans, targeted source reads,
and the active documentation layout. The source-bearing surface is large:
1,512 files under `Sources/`, `Tests/`, `linux_connector/`, `scripts/`,
`script/`, `.github/`, `Package.swift`, and `pyproject.toml`. Vendored codec
trees and fixtures account for most of that count.

Because full file-by-file semantic review of all Swift, vendored C, fixture,
and test files is too large for one pass, this index uses file-level rows for
entrypoints, public contracts, app-shell files, platform contracts, Python
connector files, scripts, and obvious hotspots. Large first-party source areas
are represented by directory-level rows and are explicitly listed under
coverage gaps before any cleanup is attempted.

Status terms:

- `ACTIVE`: included by the current package, script, test, CI, docs, or command
  surface.
- `UNCLEAR`: present in an active area, but this pass did not prove live callers
  or runtime use. Proof needed: caller references, test coverage, CLI command,
  report validator, fixture/schema contract, app action, or documented manual
  gate.
- `VENDORED`: third-party/reference source; do not refactor as first-party code.
- `COMPATIBILITY`: intentionally shaped around LoLa, JackTrip, UltraGrid, WSL,
  or legacy storage/argument behavior. Removal requires usage evidence.
- `GENERATED-LIKE`: fixtures, generated reports, or copied evidence artifacts.

## Package And Build Surface

| Path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Package.swift` | SwiftPM manifest | Defines macOS SwiftPM products, executable targets, C targets, vendored codec targets, resources, and linker Info.plist injection. | `package`, `executableInfoPlistLinkerSettings` | config | SwiftPM, AppKit, AVFoundation, CoreAudio, C targets | ACTIVE | Mixed app/CLI/library/vendor concerns; unsafe linker flags are intentional but fragile. |
| `.github/workflows/release-readiness.yml` | GitHub Actions YAML | Runs release-readiness CI wrapper. | Workflow job definitions | config | `scripts/verify-release-readiness.sh`, SwiftPM, Python tooling | ACTIVE | CI truth depends on the shell wrapper; do not equate with field readiness. |
| `pyproject.toml` | Python config | Declares Python package metadata and dev verification dependencies. | project metadata, optional dev deps | config | pytest, ruff, mypy | ACTIVE | Dependency bounds are verification policy; keep in sync with scripts. |

## Directory-Level Source Areas

| Path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/OpenLolaContracts/` | Swift target | Shared public report/verdict contracts. | `MeasurementVerdict`, `MeasurementMethodology`, `ReportRunMode`, `JSONReportCoder`, `PrettyJSONCodable`, `RxBufferProfile` | domain logic / public contract | `Foundation` | ACTIVE | Raw values are compatibility surface; fixture/report churn likely if renamed. |
| `Sources/OpenLolaCore/Audio/` | Swift | Audio codecs, CoreAudio inventory, MADI TX/RX, realtime graph, loopback, routing, synthetic payloads. | `OpusCELTLowDelayCodec`, `CoreAudioInventoryReader`, `Madi*`, `DirectPeerRealtimeAudioGraph*`, `RealtimeAudio*`, `AudioLoopback*`, `DirectAudioMediaRouter` | runtime / domain logic / adapter | CoreAudio, Darwin, Dispatch, COpus, COpenLolaAtomics, OpenLolaContracts | ACTIVE | High-risk realtime callbacks, unclear state transitions, buffer/timing sensitivity, large helper files. |
| `Sources/OpenLolaCore/Benchmarks/` | Swift | E2E, latency, and performance reports, validators, runners, synthetic smokes. | `E2EBenchmark*`, `LatencyBenchmark*`, `PerformanceAudit*` | domain logic / report / test evidence | Foundation, Darwin/Glibc/os timing | ACTIVE | Synthetic reports can be mistaken for field proof. |
| `Sources/OpenLolaCore/Connectors/` | Swift | External connector orchestration and native LoLa, JackTrip, UltraGrid, NMP compatibility/runtime support. | `ExternalConnector*`, `LoLaCompatibility*`, `JackTrip*`, `UltraGrid*`, `ExternalConnectorNmp*` | runtime / adapter / compatibility | Darwin sockets, Dispatch, Foundation, CoreAudio, CoreGraphics/CoreImage/CoreVideo, CryptoKit, Security | ACTIVE / COMPATIBILITY | Compatibility shims, alternate protocol modes, process lifecycle, crypto/FEC, and partial-evidence PASS gates are high-risk. |
| `Sources/OpenLolaCore/Control/` | Swift | ATEM read-only control, lighting fixture gate, OSC cue reports and probes. | `AtemReadOnlyControl*`, `LightingFixtureGate*`, `OscCue*` | adapter / domain logic | Darwin sockets, Dispatch, Foundation | ACTIVE | UDP/control helpers and placeholder-sensitive validation repeat patterns from other areas. |
| `Sources/OpenLolaCore/Core/` | Swift | CLI primitives, argument parsing, peer identity, capability summary, validation primitives. | `OpenLolaCLI`, `KeyValueArgumentParser`, `PeerIdentity`, `ValidationPrimitives`, `CapabilitySummary`, `DebugTrace` | domain logic / config | Foundation, OpenLolaContracts aliases | ACTIVE | Parser and error text changes ripple through CLI and tests. |
| `Sources/OpenLolaCore/Evidence/` | Swift | Generic measurement, hardware, reference-rig, schema inventory, validator surface, verdict policy. | `MeasurementReport`, `HardwareValidationReport`, `ReferenceRigReport`, `ReportSchemaInventory`, `ReportValidatorSurface`, `VerdictValidationPolicy` | report / public contract | Foundation | ACTIVE | False `PASS` prevention lives here; cleanup without validator proof is risky. |
| `Sources/OpenLolaCore/Integration/` | Swift | Integrated AV/profile reports, validation, aggregation, runtime evidence. | `IntegratedAv*`, `IntegratedProfile*` | domain logic / report | Foundation | ACTIVE | Degrade-first and evidence aggregation can silently overstate runtime quality. |
| `Sources/OpenLolaCore/Network/` | Swift | Diagnostics, NAT/rendezvous/relay, Direct P2P, RTP/AES67, UDP PCM/media transport. | `NetworkDiagnostics`, `NatFriendlyRoute*`, `DirectPeerSession*`, `PeerSessionRunner*`, `UdpPcm*`, `UdpMediaTransport`, `AES67ST2110L24Transport` | runtime / protocol / adapter | Darwin sockets, Dispatch, CoreAudio, os, Foundation, OpenLolaContracts | ACTIVE | Highest packet/timing risk; socket lifecycle, packet loss/jitter/reordering, state transitions, and compatibility aliases require focused audit. |
| `Sources/OpenLolaCore/Platform/` | Swift | Native app shell contracts, operator state, command/settings validation, artifacts, media inventory, packet monitor/search. | `NativeAppShell*` | UI contract / adapter | Foundation, OpenLolaContracts, app support target | ACTIVE | UI truthfulness, storage compatibility, and app action contracts are public surface. |
| `Sources/OpenLolaCore/Protocol/` | Swift | Session capability, control message, negotiation, and protocol types. | `SessionCapabilityValidating`, `SessionControlMessage`, `SessionNegotiation`, `SessionProtocol` | protocol contract | Foundation | ACTIVE | Protocol vocabulary and negotiation behavior are compatibility surface. |
| `Sources/OpenLolaCore/Release/` | Swift | Release, packaging, recording, goal, current-evidence, field-readiness, and LoLa baseline reports. | `CurrentEvidenceStatusMatrix`, `OpenSourceReleaseReadiness`, `FieldReadyRuntimeProof`, `PackagingFieldTest*`, `RecordingSession*`, `Goal*`, `LoLaParityDeferredFeatures` | report / release contract | Foundation | ACTIVE / COMPATIBILITY | Synthetic and manual gates are easy to misread as release approval. |
| `Sources/OpenLolaCore/Support/` | Swift | File/process helpers, placeholders, monotonic deadlines, atomic ring, source inventories. | `BoundedFileReader`, `BoundedPipeCapture`, `ManagedProcessRunner`, `SPSCAtomicRing`, inventory types | support / adapter | Darwin, Dispatch, Foundation, COpenLolaAtomics | ACTIVE | Inventories drift; process kill/error paths need runtime tests. |
| `Sources/OpenLolaCore/Timing/` | Swift | Media clock, drift/PLC, latency profile contracts, RX buffering and impairment simulation. | `MediaClock`, `RxBuffering`, `DriftPlc*`, `LatencyProfileContracts`, `RxBufferBenchmark*` | domain logic | Foundation | ACTIVE | Buffer and timing state transitions are high-risk. |
| `Sources/OpenLolaCore/Video/` | Swift | AVFoundation capture, Blackmagic boundary, JPEG XS bridge, video packetization, sockets, preview/rendering, reports. | `VideoCapture*`, `VideoTransport*`, `JPEGXSReferenceCodec`, `RawBGRAAppKitPreviewWindow`, `VideoMediaSocket` | adapter / runtime / UI-adjacent | AppKit, AVFoundation, CoreMedia, CoreVideo, Foundation, CJpegXSReference | ACTIVE | Capture permissions, frame pacing, reassembly limits, render threading, and codec boundary risk. |
| `Sources/open-lola/` | Swift executable target | CLI command registry and command handlers. | `runOpenLolaCommand`, `openLolaCommandRegistry`, command handlers | entrypoint / adapter | OpenLolaCore, OpenLolaContracts, Foundation | ACTIVE | Large command dispatchers mix parsing, validation, reports, and process orchestration. |
| `Sources/open-lola-app/` | SwiftUI target | macOS app support, operator console, settings, execution controller, preview receiver, packet monitor, stored defaults. | `OpenLolaApp`, `AppSettings`, `AppExecutionController`, `AppShellRootView`, many SwiftUI views/models | UI / adapter | SwiftUI, AppKit, CoreAudio, AVFoundation, OpenLolaCore | ACTIVE | Large UI state surface; controls must reflect runtime evidence and saved settings. |
| `Sources/open-lola-app-main/` | Swift executable target | Thin `@main` app entrypoint. | `OpenLolaAppMain` | entrypoint | OpenLolaAppSupport | ACTIVE | Minimal. |
| `Sources/COpenLolaAtomics/` | C target | Local C11 atomic bridge used by Swift realtime rings. | `OpenLolaAtomicUInt64` API | adapter / support | C atomics, Swift C target | ACTIVE | Memory-order correctness boundary. |
| `Sources/opus-1.5.2/` | C vendored source | Vendored Opus/CELT/SILK codec code plus OpenLoLa bridge files. | Opus C symbols, `COpusBridge` | vendored / adapter | C compiler, SwiftPM C target | VENDORED / ACTIVE bridge | Do not simplify as first-party code; update/license/security audit only. |
| `Sources/xs_ref_sw_ed2/` | C vendored/reference source | JPEG XS reference implementation and programs; SwiftPM uses `Sources/xs_ref_sw_ed2/libjxs/`. | JPEG XS reference codec symbols | vendored / adapter | C compiler, CJpegXSReference target | VENDORED / ACTIVE target subset | Large third-party/reference surface; prove target membership before editing. |
| `Tests/OpenLolaCoreTests/` | Swift tests and fixtures | Swift Testing suite plus JSON/hex fixtures for reports, contracts, app shell, audio/video/network/connector behavior. | `@Test` functions, test support helpers, fixtures | test / generated-like fixtures | OpenLolaCore, OpenLolaContracts, OpenLolaAppSupport | ACTIVE | Some source-text/inventory tests are brittle; fixtures are contracts but not runtime proof. |
| `linux_connector/` | Python, shell, PowerShell, Docker, docs | Python LoLa compatibility seed, Windows/WSL lab support, packet decoder, tests. | `linux_connector.lola_connector.*`, env scripts, tests | compatibility / adapter / test / script | Python stdlib, asyncio, socket, subprocess, Docker/PowerShell where relevant | ACTIVE / COMPATIBILITY | Host-specific runtime behavior and protocol compatibility assumptions. |
| `scripts/` | shell, Python, Docker, text | Release/export/docs verification, UltraGrid/JackTrip local parity probes, Docker/native wrappers. | `verify-docs.sh`, `verify-release-*`, `export-release-candidate.sh`, parity helpers, `scripts.verify_docs` | script / config / release adapter | bash, Python, Docker, shellcheck, external connector tools | ACTIVE | Release policy and local-lab scripts are environment-sensitive. |
| `script/` | shell | Native app and CLI bundle build/sign/verify helpers. | `build_and_run.sh`, `build_cli_app_bundle.sh` | build script / runtime smoke | swift build, codesign, osascript, screencapture | ACTIVE | Singular directory looks legacy but is active; app verification has GUI side effects. |

## File-Level Inventory: Public Contracts

| Path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/OpenLolaContracts/MeasurementVerdict.swift` | Swift enum | Canonical verdict vocabulary. | `MeasurementVerdict` | public contract | Codable/Hashable/Sendable | ACTIVE | Raw values are public compatibility surface. |
| `Sources/OpenLolaContracts/MeasurementMethodology.swift` | Swift enum | Measurement provenance vocabulary. | `MeasurementMethodology` | public contract | Codable/Equatable/Sendable | ACTIVE | Raw values are report contract. |
| `Sources/OpenLolaContracts/ReportRunMode.swift` | Swift enum | Shared report run-mode vocabulary. | `ReportRunMode` | public contract | Codable/Equatable/Sendable | ACTIVE | Raw values affect report schemas. |
| `Sources/OpenLolaContracts/PrettyJSONCodable.swift` | Swift protocol/utility | Stable pretty JSON encoding/decoding helper. | `PrettyJSONCodable`, `JSONReportCoder` | public contract / adapter | Foundation JSONEncoder/JSONDecoder | ACTIVE | Formatting choices affect fixtures and validators. |
| `Sources/OpenLolaContracts/RxBufferProfile.swift` | Swift enum | Shared RX-buffer profile names used by CLI/runtime/app. | `RxBufferProfile` | public contract / config | Codable/CaseIterable | ACTIVE | Profile names map to operator/runtime policy; renames are migrations. |

## File-Level Inventory: CLI Entrypoints

| Path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/open-lola/main.swift` | Swift | Top-level CLI registry, dispatch, usage, JSON helpers, error descriptions. | `runOpenLolaCommand`, `openLolaCommandRegistry`, `openLolaCommands`, `RegisteredCommand`, `CommandError` | entrypoint | OpenLolaCore, OpenLolaContracts, Foundation | ACTIVE | Central command registry can drift from help/docs/tests. |
| `Sources/open-lola/Commands/CLICommandHelpers.swift` | Swift | Shared CLI report validation helper. | `validateReport` | adapter | Report validators | ACTIVE | Small but public-to-CLI behavior. |
| `Sources/open-lola/Commands/MilestoneCommands.swift` | Swift | Broad milestone/report generation dispatcher with shared validated JSON report writers for file and stdout runtime outputs. | `handleMilestoneCommand` | adapter | Many OpenLolaCore reports/runners | ACTIVE | Large if/else-style command fanout remains; repeated JSON output boilerplate is reduced. |
| `Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift` | Swift | Table-backed validation command dispatcher for report artifacts. | `handleMilestoneValidationCommand` | adapter | Report validators and fixture contracts | ACTIVE | Validator table must stay in sync with schema inventory and executable routing tests. |
| `Sources/open-lola/Commands/Audio/LatencyProfileCommands.swift` | Swift | Latency profile and RX-buffer benchmark CLI handlers. | `handleLatencyProfileCommand` | adapter | Timing/RX buffer reports | ACTIVE | Argument parsing embedded in handler. |
| `Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift` | Swift | MADI full-duplex command parser and runner. | `handleMadiFullDuplexCommand`, `MadiFullDuplexCommandRun` | adapter | MADI runtime, UDP PCM types, RxBufferProfile | ACTIVE | Complex parser/validation cluster. |
| `Sources/open-lola/Commands/Audio/MadiReceiveCommands.swift` | Swift | MADI receive/report command handler. | `handleMadiReceiveCommand` | adapter | MADI receive reports/runners | UNCLEAR | Prove current command coverage before cleanup. |
| `Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift` | Swift | E2E benchmark command handlers. | `handleE2EBenchmarkCommand` | adapter | E2E reports/validators | ACTIVE | Synthetic input helpers can blur with measured evidence. |
| `Sources/open-lola/Commands/Benchmarks/PerformanceCommands.swift` | Swift | Performance audit command handlers. | `handlePerformanceCommand` | adapter | Performance audit reports | ACTIVE | Report generation and validation close together. |
| `Sources/open-lola/Commands/Network/NetworkCommands.swift` | Swift | Network command dispatcher. | `handleNetworkCommand` | adapter | Network diagnostics, UDP, P2P, NAT, connector surfaces | ACTIVE | Broad branching and high-risk transport command surface. |
| `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift` | Swift | Direct P2P session-run argument parsing and config assembly. | `parseDirectP2PSessionRunArguments`, `directP2PSessionAVConfiguration` | adapter / protocol config | DirectPeer session types, AV config, compression policy | ACTIVE / COMPATIBILITY | Legacy aliases and many validation branches. |
| `Sources/open-lola/Commands/Network/DirectP2PSessionRunArgumentSupport.swift` | Swift | Allowed/public Direct P2P session-run arguments. | `directP2PSessionRunAllowedArguments`, `directP2PSessionRunPublicArguments` | config | CLI parser/help | ACTIVE | Must stay in sync with parser and docs. |
| `Sources/open-lola/Commands/Network/DirectP2PSessionQualityPolicyCommandSupport.swift` | Swift | Direct P2P quality policy derivation. | `directP2PQualityPolicy` | adapter | Direct peer session config | UNCLEAR | Needs command/test proof before changes. |
| `Sources/open-lola/Commands/Network/DirectP2PMeasuredEvidenceCommandSupport.swift` | Swift | Applies measured evidence and receive-proof artifacts to Direct P2P reports. | `directP2PApplyMeasuredEvidence`, receive-proof artifact helpers | adapter / evidence | DirectPeer reports, JSON artifacts | ACTIVE | Evidence promotion logic is high-risk. |
| `Sources/open-lola/Commands/Network/DirectP2PMeshArgumentSupport.swift` | Swift | Mesh topology/runtime argument parsing. | `parseDirectP2PMeshTopologyArguments`, `parseDirectP2PMeshRuntimeArguments` | adapter | Direct P2P mesh reports | ACTIVE | Repeated parser patterns. |
| `Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift` | Swift | Two-peer prototype report aggregation command. | `runDirectP2PTwoPeerPrototypeReportCommand` | adapter | DirectPeer reports/artifacts | UNCLEAR | Prove not superseded by local-run command before cleanup. |
| `Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift` | Swift | Coordinates local/remote two-peer Direct P2P process runs and artifact collection. | `runDirectP2PTwoPeerLocalRunCommand`, process/ready-file helpers | adapter / script orchestration | ManagedProcessRunner, shell/scp, DirectPeer reports | ACTIVE | Large process lifecycle, timeout, shell quoting, and artifact path surface. |

## File-Level Inventory: Native App And App Shell

| Path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/open-lola-app-main/OpenLolaAppMain.swift` | SwiftUI | Executable app `@main` wrapper. | `OpenLolaAppMain` | entrypoint | OpenLolaAppSupport | ACTIVE | Minimal. |
| `Sources/open-lola-app/OpenLolaApp.swift` | SwiftUI | App scene, menu commands, app state wiring, quit/menu policies. | `OpenLolaApp`, `OpenLolaAppScene`, `AppMenuActionPolicy`, `AppMenuActionHandling` | UI / entrypoint | SwiftUI, AppSettings, AppExecutionController | ACTIVE | Menu state can become misleading if decoupled from runtime; execution preparation now delegates to `AppExecutionController`. |
| `Sources/open-lola-app/AppSettings.swift` | Swift | Observable app settings and defaults hydration. | `AppSettings`, `AppPreviewDefaults` | UI / storage config | SwiftUI observation/defaults, OpenLolaCore enums | ACTIVE | Mutable settings map; storage migrations remain risky. |
| `Sources/open-lola-app/AppSettingsDraft.swift` | Swift | Observable settings draft, save/conflict handling, runtime-change detection, and draft fingerprinting. | `AppSettingsDraft`, `AppSettingsDraftCommitResult`, `AppSettingsDraftFingerprint` | UI / storage config | AppSettings, AppExecutionController, operator surface, preview state | ACTIVE | Large field copy/apply/fingerprint lists; stale-draft behavior is high-risk. |
| `Sources/open-lola-app/AppStorageKeys.swift` | Swift | Central app storage keys and artifact defaults. | `AppStorageKeys`, `AppOperatorArtifactDefaults` | storage contract | AppStorage/UserDefaults callers | ACTIVE | Key renames require migrations. |
| `Sources/open-lola-app/AppShellStoredDefaults.swift` | Swift | Stored defaults to operator-surface state mapping and legacy migration. | `AppShellStoredDefaults` | storage adapter / compatibility | Native app shell models | ACTIVE / COMPATIBILITY | Compatibility shim; prove old key usage before removal. |
| `Sources/open-lola-app/AppExecutionController.swift` | Swift | Process execution, validation, lifecycle state, and error classification. | `AppExecutionController` | UI adapter / process orchestration | Foundation Process, app settings, app execution state, app execution support files, OpenLolaCore reports | ACTIVE | Below the line budget after splits; process lifecycle and runtime-evidence decisions remain high-risk. |
| `Sources/open-lola-app/AppExecutionCommandPreview.swift` | Swift | Command preview and validator-command generation for app operator surfaces. | `AppExecutionController.executionCommand`, `AppExecutionController.validatorCommand` | UI adapter / command preview | AppExecutionController, app settings, operator surface, AppExecutablePathResolver | ACTIVE | Must stay aligned with actual start/validation routes and unsupported connector policy. |
| `Sources/open-lola-app/AppExecutionEvidenceSupport.swift` | Swift | Default log paths, log snapshot preservation, previous-run evidence snapshots, log opening, report loading, and execution report assembly. | `AppExecutionDefaultLogURLs`, `AppExecutionLogSnapshot`, `AppRunEvidenceSnapshot`, `AppExecutionLogFileOpener`, `AppExecutionReportLoader`, `AppExecutionReportAssembler` | UI adapter / report and log support | Foundation, AppKit, OpenLolaCore reports, AppExecutionController | ACTIVE | File split from controller; report/evidence labels must stay truthful and tests must cover behavior, not helper shape. |
| `Sources/open-lola-app/AppExecutionState.swift` | Swift | Shared execution phase, execution kind, validation result/readiness, and runtime-evidence invalidation policy definitions. | `AppExecutionPhase`, `AppExecutionKind`, `AppValidationResult`, `AppValidationReadiness`, `AppRuntimeEvidenceInvalidationPolicy` | UI model / state contract | App execution controller and validation console models | ACTIVE | State naming must stay aligned with user-visible validation and runtime-evidence truthfulness. |
| `Sources/open-lola-app/AppExecutionPreparation.swift` | Swift | Shared plan-write and app execution-preparation route for menu, transport, and banner start flows. | `AppExecutionController.writePlanOrLogError`, `AppExecutionController.prepareExecution(from:)` | UI adapter / process orchestration | AppExecutionController, NativeAppShell session modes | ACTIVE | Small extension; keep behavior tied to existing app execution route tests. |
| `Sources/open-lola-app/AppExecutablePathResolver.swift` | Swift | Resolves app/CLI executable path for bundled/debug modes. | `AppExecutablePathResolver`, `AppExecutablePathResolution` | adapter | Bundle/process environment | ACTIVE | Fallback behavior must match app bundle tests. |
| `Sources/open-lola-app/AppShellRootView.swift` | SwiftUI | Main operator console root, navigation state, search/selection clamping, derived surface refresh, and stop confirmation. | `AppShellRootView`, `AppSidebarLiveNavigationPolicy`, `AppUnavailableSectionCopy` | UI | SwiftUI, reports, app settings, operator plan, AppShellSectionViews | ACTIVE | Root state must not drift from runtime evidence; banner start delegates execution preparation. |
| `Sources/open-lola-app/AppShellSectionViews.swift` | SwiftUI | Operator console section router and overview/session/streams/routing/devices/diagnostics/validation/settings section views. | `AppShellDetailView`, `AppRemoteEvidenceStatusPolicy`, `AppShellSettingsSurfacePolicy` | UI | SwiftUI, reports, app settings, operator plan, validation console models | ACTIVE | Large section-view file; section copy and status must remain tied to runtime evidence. |
| `Sources/open-lola-app/AppConsoleModels.swift` | Swift | Derived console status, copy vocabulary, overview summary, section selection, packet-monitor empty state, and diagnostics copy. | `AppConsoleStatusSnapshot`, `AppOverviewOperatorSummary`, `AppConsoleSectionSelection`, `AppPacketMonitorEmptyState`, `AppDiagnosticsStatusModel` | UI model | Native app shell reports, operator plan | ACTIVE | Derived truthfulness risk; keep status copy tied to runtime evidence. |
| `Sources/open-lola-app/AppValidationConsoleModels.swift` | Swift | Validation rows, validation preflight state, blockers, and advanced-control recovery copy for the operator console. | `AppValidationRow`, `AppValidationPreflightModel`, `AppValidationBlocker`, `AppAdvancedControlRecoveryPolicy`, `appValidationReadiness` | UI model | Native app shell reports, operator plan, AppExecutionController | ACTIVE | Validation state must not turn partial, missing, or stale evidence into start-ready UI. |
| `Sources/open-lola-app/AppConsoleChromeView.swift` | SwiftUI | Sidebar, topbar, footer, and console chrome policies. | `AppConsoleSidebarView`, `AppConsoleTopBarView`, `AppConsoleFooterStripView`, `AppFooterTransportPolicy` | UI | SwiftUI, console models | ACTIVE | Mostly presentation; state cues must not be color-only. |
| `Sources/open-lola-app/AppDesignSystem.swift` | SwiftUI | Color/theme/spacing/window constants, status badges, panels. | `AppDesignSystem`, `AppColorRole`, `AppConstants`, `AppSessionState`, `DesignPanel` | UI support | SwiftUI | ACTIVE | Generic status visuals can hide false-success if callers misuse them. |
| `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift` | SwiftUI | Local operator workflow, device selection, peer fields, command intent controls. | `AppLocalOperatorSurfaceView`, `AppDeviceSetupRecoveryPolicy`, `AppCommandIntentControlPolicy` | UI | AppSettings, operator surface, local inventory | ACTIVE | Large view with many input state paths; controls must affect runtime. |
| `Sources/open-lola-app/AppShellSettingsView.swift` | SwiftUI | Settings window/container. | `AppShellSettingsView` | UI | AppSettings, settings tabs | ACTIVE | Large settings surface; stale draft and runtime-affecting change behavior are important. |
| `Sources/open-lola-app/AppShellSettingsTabs.swift` | SwiftUI | Execution, connector notice, Windows LoLa, peer, audio, video, preview, snapshot tabs. | `AppExecutionSettingsTab`, `AppWindowsLoLaSettingsTab`, `AppPeersSettingsTab`, etc. | UI | AppSettings, NativeAppShell session modes | ACTIVE / COMPATIBILITY | Mode-specific controls and unsupported connector tabs can mislead. |
| `Sources/open-lola-app/AppReceiverPreviewServices.swift` | Swift/AppKit/CoreAudio | Video preview layer and CoreAudio input meter services. | `AppVideoPreviewLayerView`, `AppCoreAudioInputMeterError`, audio meter IOProc helpers | UI adapter / runtime adapter | AppKit, AVFoundation, CoreAudio | ACTIVE | Core Audio callback/timer lifecycle in UI support layer is high-risk. |
| `Sources/open-lola-app/AppPreviewReceiverView.swift` | SwiftUI | Local preview window, preview control availability, meter empty states. | `AppPreviewReceiverView`, `AppReceiverWindowView`, `AppPreviewReceiverWarningPolicy`, `AppChannelMeterVisibilityPolicy` | UI | Preview services, AppSettings | ACTIVE | Preview state must reflect service evidence. |
| `Sources/open-lola-app/AppPacketMonitorView.swift` | SwiftUI | Packet monitor table, row details, empty/error states. | `AppPacketMonitorView`, `AppPacketMonitorRowsState`, `AppPacketMonitorRowDetailState` | UI | Native app packet monitor rows | ACTIVE | Status rows must be report-backed. |
| `Sources/open-lola-app/AppExecutionView.swift` | SwiftUI | Execution controls, command preview, reports/log views, error guidance. | `AppExecutionView`, `AppReportsView`, `AppLogsView`, `AppExecutionErrorGuidance` | UI | AppExecutionController, operator plan | ACTIVE | Error guidance must not mask failed runtime. |
| `Sources/open-lola-app/AppOperatorArtifactViews.swift` | SwiftUI | Artifact generation/write/reload UI and state. | `AppOperatorArtifactsView`, `AppOperatorArtifactPanelState`, `AppArtifactWriteStatus` | UI / storage adapter | Native app shell artifacts, AppSettings | ACTIVE | Artifact state can go stale after path/context changes. |
| `Sources/open-lola-app/AppOperatorPlanViews.swift` | SwiftUI/model | Operator plan/readiness and generated command display. | `AppOperatorPrototypePlan`, `AppOperatorReadinessView`, `AppOperatorCommandsView` | UI / command model | Native app shell operator state | ACTIVE | Readiness labels can become false-success. |
| `Sources/open-lola-app/AppChannelMeterView.swift` | SwiftUI | Channel meter rendering, peak hold, accessibility copy. | `AppChannelMeterView`, `ChannelMeterLevelSnapshot`, `PeakHoldState` | UI | SwiftUI timers/state | ACTIVE | Timer/animation state and active-meter evidence need runtime proof. |
| `Sources/open-lola-app/AppConnectionTopologyView.swift` | SwiftUI | Visual connection topology. | `AppConnectionTopologyView`, `AppConnectionTopologyAnimationPolicy` | UI | SwiftUI, operator plan | ACTIVE | Animation/labels must match runtime/report state. |
| `Sources/open-lola-app/AppDeviceCard.swift` | SwiftUI | Audio/video selectable device cards. | `AppAudioDeviceCard`, `AppVideoDeviceCard`, `AppDeviceIdentifierDisplayPolicy` | UI | SwiftUI, media inventory | ACTIVE | Device UID display/selection must stay wired to command fields. |
| `Sources/open-lola-app/AppLatencyHeroMetrics.swift` | Swift | Derived latency hero metrics. | `AppLatencyHeroMetrics` | UI model | report metrics | ACTIVE | Must not show unvalidated metrics as live proof. |
| `Sources/open-lola-app/AppLatencyHeroView.swift` | SwiftUI | Latency summary hero view. | `AppLatencyHeroView` | UI | AppLatencyHeroMetrics | ACTIVE | Visual prominence can overstate partial evidence. |
| `Sources/open-lola-app/AppLocalOperatorInventory.swift` | Swift | Local media inventory refresh/merge policy. | `AppLocalOperatorInventory`, `AppLocalOperatorInventoryRefreshMergePolicy` | UI adapter | Native media inventory | ACTIVE | Concurrent operator edits vs refresh merge can lose state. |
| `Sources/open-lola-app/AppPasteboard.swift` | Swift | Pasteboard copy abstraction and feedback. | `AppPasteboard`, `AppPasteboardCopyStatus`, `AppPasteboardCopyFeedback` | UI adapter | AppKit pasteboard | ACTIVE | Copy status should report failures before success. |
| `Sources/open-lola-app/AppPreviewBindings.swift` | Swift | Small preview binding helpers. | `appPreviewBinding`, `appPreviewIntBinding` | UI support | SwiftUI Binding | ACTIVE | Single-use abstraction candidate; keep only if multiple callers remain. |
| `Sources/open-lola-app/AppRemoteInventoryImport.swift` | Swift | Imports remote inventory into operator state. | `NativeAppShellOperatorPrototypeState` extension | UI adapter | Native media inventory | ACTIVE | State mutation must reject invalid imports. |
| `Sources/open-lola-app/AppRuntimeEvidenceScope.swift` | Swift enum | App-side runtime evidence scope names. | `AppRuntimeEvidenceScope` | UI model / contract | Swift enum | UNCLEAR | Prove multiple callers or inline if single-use. |
| `Sources/open-lola-app/AppRuntimeInputLock.swift` | Swift enum | Runtime input lock policy for mutating controls while execution is active. | `AppRuntimeInputLock` | UI policy | execution phase/settings | ACTIVE | State lock must keep stop controls available. |
| `Sources/open-lola-app/AppSessionStateBanner.swift` | SwiftUI | Session banner and accessibility announcement bridge. | `AppSessionStateBanner`, `AppSessionBannerAccessibilityPolicy`, `AppAccessibilityAnnouncementView` | UI | SwiftUI, AppKit/NSViewRepresentable | ACTIVE | Announcement policy must not claim success. |
| `Sources/open-lola-app/AppShellReadOnlyViews.swift` | SwiftUI | Read-only report overview/config/metrics/boundary/permissions/probe views. | `AppShellOverviewView`, `AppShellConfigurationView`, `AppShellProbeView` | UI | Native app shell report | ACTIVE | Report copy must stay evidence-bound. |
| `Sources/open-lola-app/AppShellSupportViews.swift` | SwiftUI | Shared fields, metrics grid, readable values, badges, warnings, copy helpers. | `UInt16Field`, `IntField`, `MetricsGrid`, `AppReadableMetric`, `AppStatusBadge`, `yesNo` | UI support | SwiftUI, AppPasteboard | ACTIVE | Shared status/copy helpers are easy to misuse. |
| `Sources/open-lola-app/AppTransportView.swift` | SwiftUI | Transport-oriented command/run controls. | `AppTransportView` | UI | AppExecutionController, operator plan | ACTIVE | Overlap with execution/local-operator views needs dedup audit; execution preparation is delegated to the controller. |
| `Sources/open-lola-app/Info.plist` | plist | App bundle metadata and usage descriptions. | Bundle keys | config | macOS app bundle | ACTIVE | Permission text and bundle identity are runtime/storage surfaces. |
| `Sources/open-lola-app/open-lola-app.entitlements` | plist | App entitlement settings. | Entitlement keys | config | codesign/app sandbox | ACTIVE | Permission boundary; changes require launch/signing checks. |

## File-Level Inventory: Platform Contracts

| Path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/OpenLolaCore/Platform/NativeAppShell.swift` | Swift report/runtime smoke | Native app configuration, permission readiness, runtime boundary, smoke report and synthetic smoke. | `NativeAppShellReport`, `NativeAppRuntimeSmoke`, `NativeAppShellSyntheticSmoke` | UI contract / report | Foundation, OpenLolaContracts | ACTIVE | Large report schema; synthetic smoke can be mistaken for runtime proof. |
| `Sources/OpenLolaCore/Platform/NativeAppShellArtifacts.swift` | Swift artifacts | Generated artifact/read/write state for inventories and plans. | `NativeAppShellArtifactKind`, `NativeAppShellGeneratedArtifactState`, artifact write/read extensions | storage / UI contract | Foundation, PrettyJSONCodable | ACTIVE | Artifact path and stale state behavior are compatibility surfaces. |
| `Sources/OpenLolaCore/Platform/NativeAppShellDirectPeerCommand.swift` | Swift command model | Direct peer command field model and handoff structures. | `NativeAppShellDirectPeerCommandFields`, `NativeAppShellLocalDirectPeerCommand`, `NativeAppShellLocalCommandHandoff` | UI contract / config | Direct peer session types | ACTIVE | Command fields mirror CLI flags; drift risk. |
| `Sources/OpenLolaCore/Platform/NativeAppShellDirectPeerSettingsValidation.swift` | Swift validation | Validates direct-peer app command settings. | `NativeAppShellDirectPeerCommandFields` validation extension | adapter | Direct peer config enums | ACTIVE | Validation duplication with CLI possible. |
| `Sources/OpenLolaCore/Platform/NativeAppShellExecution.swift` | Swift execution contract | Execution paths, settings, validation, execution report. | `NativeAppShellExecutionPaths`, `NativeAppShellExecutionSettings`, `NativeAppShellExecutionReport` | UI contract / storage | Foundation | ACTIVE | Executable path validation and timeout defaults affect launch safety. |
| `Sources/OpenLolaCore/Platform/NativeAppShellMediaDevices.swift` | Swift model | Audio/video device option models. | `NativeAppShellAudioDeviceOption`, `NativeAppShellVideoDeviceOption` | UI contract | Foundation | ACTIVE | Device identity must not be placeholder proof. |
| `Sources/OpenLolaCore/Platform/NativeAppShellMediaInventory.swift` | Swift report/model | Local media selection and inventory report. | `NativeAppShellLocalMediaSelection`, `NativeAppShellLocalMediaInventory` | UI contract / report | PrettyJSONCodable | ACTIVE | Inventory freshness matters for runtime settings. |
| `Sources/OpenLolaCore/Platform/NativeAppShellOperatorPrototypeState+RunPlan.swift` | Swift extension | Converts operator state to two-peer run plans and commands. | `twoPeerRunPlanConfiguration`, command/report helpers | adapter | Direct peer run plan/report types | ACTIVE | Command generation must match CLI contract. |
| `Sources/OpenLolaCore/Platform/NativeAppShellOperatorState.swift` | Swift model | Main operator prototype state. | `NativeAppShellOperatorPrototypeState` | UI contract / storage | Direct peer and session-mode models | ACTIVE | Large state object; unclear transitions if mutated from multiple views. |
| `Sources/OpenLolaCore/Platform/NativeAppShellSearchAndPacketMonitor.swift` | Swift model/policy | Packet monitor row filtering and section search. | `NativeAppPacketMonitorRows`, `NativeAppShellSectionSearch` | UI contract | Foundation | ACTIVE | Must distinguish unavailable vs empty evidence. |
| `Sources/OpenLolaCore/Platform/NativeAppShellSessionMode.swift` | Swift modes/config | App session/control/settings modes and Windows LoLa fields. | `NativeAppShellSessionMode`, `NativeAppShellControlMode`, `NativeAppShellWindowsLoLaPeerFields` | UI contract / compatibility | ExternalConnectorMediaMode | ACTIVE / COMPATIBILITY | Windows LoLa command validation and unsupported modes are compatibility-sensitive. |
| `Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift` | Swift app surface contract | Section/action inventory, launch probe plan, surface probe report and validator. | `NativeAppShellSurfaceContract`, `NativeAppShellActionInventory`, `NativeAppShellSurfaceProbe` | UI contract / report | Foundation, report validation | ACTIVE | Literal UI/action contract; app verifier can drift from visible labels. |

## File-Level Inventory: C Bridges And Vendored Code

| Path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/COpenLolaAtomics/OpenLolaAtomics.c` | C bridge | C11 atomic uint64 operations for Swift realtime rings. | C functions matching `OpenLolaAtomics.h` | adapter / support | C atomics | ACTIVE | Memory ordering is a realtime correctness boundary. |
| `Sources/COpenLolaAtomics/include/OpenLolaAtomics.h` | C header | Public C bridge declarations. | `OpenLolaAtomicUInt64`, init/load/store/fetch-add/CAS declarations | adapter / support | C atomics | ACTIVE | ABI contract. |
| `Sources/opus-1.5.2/openlola_bridge/COpusBridge.c` | C bridge | Local bridge between Swift wrapper and vendored Opus C implementation. | COpus bridge functions | adapter | Opus C sources | ACTIVE | Pointer lifecycle and codec error propagation need audit before edits. |
| `Sources/opus-1.5.2/openlola_bridge/include/COpusBridge.h` | C header | Public bridge declarations for COpus target. | COpus bridge API | adapter | Opus headers | ACTIVE | ABI contract. |
| `Sources/opus-1.5.2/` | C vendored tree | Opus 1.5.2 codec source, build metadata, tests, and documentation. | Opus/CELT/SILK C symbols | vendored | C compiler, SwiftPM source whitelist in `Package.swift` | VENDORED | Hundreds of files; do not refactor as first-party code. |
| `Sources/xs_ref_sw_ed2/libjxs/` | C vendored/reference target | JPEG XS reference library subset used by SwiftPM. | libjxs public headers and source | vendored / adapter | C compiler, SwiftPM target `CJpegXSReference` | VENDORED / ACTIVE subset | Reference-code boundary; prove exact linked files before changing. |
| `Sources/xs_ref_sw_ed2/programs/` | C vendored programs | JPEG XS command-line reference programs. | encoder/decoder utilities | vendored / unknown runtime | CMake/reference build, not SwiftPM product | UNCLEAR | Prove not used by scripts/docs before deletion; likely vendor collateral. |

## File-Level Inventory: Python Connector

| Path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `linux_connector/__init__.py` | Python package marker | Root Python package marker. | package namespace | config | Python import system | ACTIVE | Minimal. |
| `linux_connector/lola_connector/__init__.py` | Python exports | Connector package public export surface. | `__all__` for connector/protocol/media/runtime/backend names | public contract | internal Python modules | ACTIVE | Export drift possible. |
| `linux_connector/lola_connector/protocol.py` | Python protocol codec | LoLa control/media protocol constants, parsers, builders, validation. | `MediaSettings`, `ControlMessage`, `parse_control_datagram`, `build_*` | protocol contract / compatibility | ipaddress, struct, media constants | ACTIVE / COMPATIBILITY | Raw protocol values and OSC/text variants are compatibility-sensitive. |
| `linux_connector/lola_connector/media.py` | Python media codec | Media fragmentation, parsing, reassembly, audio/video payload helpers. | `Fragment`, `VideoPrelude`, `AudioFrame`, `VideoFrame`, `MediaReassembler`, parse/build helpers | domain logic / compatibility | struct, math, logging | ACTIVE / COMPATIBILITY | Reassembly bounds and frame-shape validation are high-risk. |
| `linux_connector/lola_connector/ethernet.py` | Python wire codec | Ethernet/IPv4/UDP frame construction and checksums. | `parse_mac`, `build_ipv4_udp_packet`, `build_ethernet_ipv4_udp_frame` | adapter / protocol | ipaddress, struct | ACTIVE | Byte-level contract; weak validation would corrupt packet evidence. |
| `linux_connector/lola_connector/connector.py` | Python async runtime | Async control connector/listener, session state, status checks, socket helpers. | `LolaConnector`, `Session`, `StatusCheckResult`, `QuickConnResult`, UDP helpers | runtime / compatibility | asyncio, socket, protocol/media modules | ACTIVE / COMPATIBILITY | Large async state machine; socket lifecycle and error handling are high-risk. |
| `linux_connector/lola_connector/runtime.py` | Python runtime bridge | Media runtime loop connecting connector sessions to capture/playback/display backends. | `LolaLinuxRuntime`, `RuntimeStats` | runtime / adapter | asyncio, sockets, backends, media parser | ACTIVE | Async media loop and stats can silently underreport failures. |
| `linux_connector/lola_connector/backends.py` | Python backends | Audio/video protocol interfaces and generated/process/memory backends. | `AudioCapture`, `AudioPlayback`, `VideoCapture`, `VideoDisplay`, process/generator classes | adapter | asyncio subprocess, shlex, math | ACTIVE | Large backend file; process lifecycle and generated media are broad. |
| `linux_connector/lola_connector/cli.py` | Python CLI | CLI parser, argument validation, backend construction, async run dispatcher. | `build_parser`, `run`, `validate_cli_args`, `main` | entrypoint / adapter | argparse, asyncio, connector/runtime/backends | ACTIVE | CLI validation and construction mixed together. |
| `linux_connector/lola_connector/selftest.py` | Python selftest | Memory-backend connector self-tests. | `run_control_handshake_selftest`, `run_bidirectional_selftest` | test/runtime support | asyncio, memory backends | ACTIVE | Synthetic success must not become field proof. |
| `linux_connector/env/` Windows UDP relay Python utility | Python utility | Windows UDP relay helper. Exact filename is omitted from this public index because the active docs verifier forbids that token in public release docs. | `DatagramSender`, `send_payload_nonblocking`, `main` | script / adapter | socket, subprocess, logging | ACTIVE / COMPATIBILITY | Host-specific behavior; prove on Windows lab hardware. |
| `linux_connector/tools/lola_packet_decoder.py` | Python CLI tool | Packet capture decoder for LoLa media/control payloads. | `LolaFragment`, `LolaVideoPrelude`, `parse_*`, `summarize`, `main` | script / adapter | scapy, struct, pathlib | ACTIVE / UNCLEAR dependency | Optional Scapy dependency not proven in default dev install. |

## File-Level Inventory: Scripts And Verification Helpers

| Path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `script/build_and_run.sh` | shell | Builds app/CLI products, stages/signs `dist/OpenLoLa.app`, captures launch/UI evidence. | `build_product`, `verify_launched_app_surface`, capture helpers | build script / runtime smoke | swift build, codesign, osascript, screencapture | ACTIVE | GUI side effects, literal UI-label contract, sandbox-sensitive SwiftPM build. |
| `script/build_cli_app_bundle.sh` | shell | Builds and signs CLI bundle. | shell entrypoint | build script | swift build, codesign, app bundle layout | ACTIVE | Minimal but signing-sensitive. |
| `scripts/verify-docs.sh` | shell | Runs docs verifier module. | shell entrypoint | script | Python `scripts.verify_docs` | ACTIVE | Shell/Python split. |
| `scripts/verify-release-readiness.sh` | shell | Release readiness wrapper with CLI probes, app launch probe, manual gate text. | `run_step`, `run_timed_step`, probe functions, `main` | release script | SwiftPM, CLI, docs, app script | ACTIVE | Can be mistaken for release approval; contains manual gate policy. |
| `scripts/verify-release-hygiene.sh` | shell | Live checkout and release-candidate hygiene checks. | manifest/path policy functions, `main` | release script | shell tools, `scripts/release-boundary-policy.txt` | ACTIVE | Many path policies; false positives possible. |
| `scripts/export-release-candidate.sh` | shell | Stages a release-candidate tree and removes generated/vendor collateral. | `validate_release_relative_path`, `copy_path`, `remove_*`, `usage` | release script | shell tools, cp/find | ACTIVE | Release boundary risk; changes must be tested on staged tree. |
| `scripts/verify_docs/main.py` | Python module entry | Dispatches docs verifier checks. | `has_internal_documentation_context`, `main` | script | check modules/constants | ACTIVE | Dispatcher must match docs policy. |
| `scripts/verify_docs/constants.py` | Python constants | Central docs/archive/public planning, Windows corpus, and source-surface constants. | many constant tuples/maps | config / script support | pathlib, archive topology manifest | ACTIVE / COMPATIBILITY | Large hardcoded policy/data file; high drift risk. |
| `scripts/verify_docs/markdown_checks.py` | Python checks | Markdown link/path/topic/ascii/archive/public-doc checks. | `check_links`, `check_backticked_source_paths`, `check_*` helpers | script | pathlib, regex, URL parsing | ACTIVE | Large multi-responsibility verifier file. |
| `scripts/verify_docs/archive_inventory.py` | Python helper | Archive index and archive-root pattern helpers. | `archive_index`, `archive_doc_patterns`, `archive_roots` | script support | pathlib, regex | ACTIVE | Archive topology can drift. |
| `scripts/verify_docs/windows_docs.py` | Python checks | Windows corpus/docs inventory and control-message extraction helpers. | `check_windows_mc01_hash_inventory`, metadata helpers | script / compatibility | pathlib, docs constants | ACTIVE / COMPATIBILITY | Reverse-engineering/documentation policy surface. |
| `scripts/verify_docs/windows_binary_checks.py` | Python checks | Windows binary metadata/import/export/signing/dependency checks. | `rabin2_*`, `check_windows_mc03_*` to `check_windows_mc06_*` | script / compatibility | subprocess, JSON, radare/rabin2 | ACTIVE / COMPATIBILITY | Tool availability and corpus assumptions. |
| `scripts/verify_docs/windows_control_checks.py` | Python checks | Windows control-message string/type checks. | `check_windows_mc07_control_message_strings`, type helpers | script / compatibility | file output, docs constants | ACTIVE / COMPATIBILITY | External binary evidence dependency. |
| `scripts/verify_docs/windows_media_checks.py` | Python checks | Windows network/audio/video/codec-split checks. | `check_windows_mc08_*` to `check_windows_mc11_*` | script / compatibility | binary/docs helpers | ACTIVE / COMPATIBILITY | Media-surface inference from binary/corpus evidence. |
| `scripts/lib/common.sh` | shell library | Shared shell failure and file assertion helpers. | `script_name`, `fail`, `require_file`, `require_file_contains` | script support | bash | ACTIVE | Minimal. |
| `scripts/lib/parity.sh` | shell library | Shared Docker/native parity log/wait/cleanup and output-directory fallback helpers. | `parity_*` functions, including Docker preflight, output directory, and foreground cleanup runner | script support | bash, Docker/native tools | ACTIVE | Environment-specific timing and log parsing. |
| `scripts/lib/extract-preflight-executable.py` | Python CLI | Extracts executable path from preflight JSON. | `main` | script support | json, sys | ACTIVE | Minimal. |
| `scripts/lib/write-connection-metrics.py` | Python CLI | Writes connection metrics JSON. | `main` | script support | json, sys | ACTIVE | Minimal. |
| `scripts/lib/write-ultragrid-parity-metrics.py` | Python CLI | Parses UltraGrid parity output into metrics and health requirements. | `endpoint_metrics`, `require_endpoint_health`, `main` | script support | argparse, json, regex | ACTIVE | Log parser fragility. |
| `scripts/run-reference-peer-parity-gate.sh` | shell | Reference peer readiness/parity gate wrapper. | shell entrypoint | script / manual evidence | external peer env vars, connector scripts | ACTIVE | Exit-77 skip-loud behavior must not count as PASS. |
| `scripts/compare-local-ultragrid-parity-docker.sh` | shell | Local Docker UltraGrid parity comparison. | cleanup/run/require/write helpers | script / compatibility | Docker, parity helpers | ACTIVE | Local process proof only, not reference-peer proof. |
| `scripts/compare-local-ultragrid-parity-native.sh` | shell | Native UltraGrid parity comparison. | cleanup/stop/wait helpers | script / compatibility | local UltraGrid executable | ACTIVE | Host/tool dependent. |
| `scripts/compare-local-jacktrip-parity-docker.sh` | shell | Local Docker JackTrip parity comparison. | cleanup/run/capture/require helpers | script / compatibility | Docker, parity helpers | ACTIVE | Timing/log assumptions. |
| `scripts/open-lola-ultragrid-docker-client.sh` | shell | UltraGrid Docker client wrapper. | shell entrypoint | script / compatibility | Docker, parity helpers | ACTIVE | Environment-specific. |
| `scripts/open-lola-ultragrid-native-client.sh` | shell | UltraGrid native client wrapper. | shell entrypoint | script / compatibility | local UltraGrid | ACTIVE | Host-specific. |
| `scripts/open-lola-jacktrip-docker-client.sh` | shell | JackTrip Docker client wrapper. | shell entrypoint | script / compatibility | Docker, parity helpers | ACTIVE | Environment-specific. |
| `scripts/open-lola-ultragrid-docker-policy.sh` | shell | UltraGrid Docker image policy. | `open_lola_required_ultragrid_docker_image` | config | Docker image naming | ACTIVE | Minimal. |
| `scripts/open-lola-jacktrip-docker-policy.sh` | shell | JackTrip Docker image policy. | `open_lola_required_jacktrip_docker_image` | config | Docker image naming | ACTIVE | Minimal. |
| `scripts/run-local-ultragrid-rxtx-docker.sh` | shell | Local Docker UltraGrid RX/TX runner. | cleanup, log wait, metrics helpers | script / compatibility | Docker, parity helpers | ACTIVE | Local-lab timing assumptions. |
| `scripts/run-local-ultragrid-rxtx-native.sh` | shell | Local native UltraGrid RX/TX runner. | cleanup, wait, metrics helpers | script / compatibility | native UltraGrid | ACTIVE | Host/tool dependent. |
| `scripts/run-local-jacktrip-rxtx-docker.sh` | shell | Local Docker JackTrip RX/TX runner. | cleanup shell helpers | script / compatibility | Docker | ACTIVE | Local proof only. |
| `scripts/stress-local-ultragrid-parity-docker.sh` | shell | Docker UltraGrid parity stress wrapper. | shell entrypoint | script / compatibility | Docker | ACTIVE | Stress timing/environment dependent. |
| `scripts/stress-local-ultragrid-parity-native.sh` | shell | Native UltraGrid parity stress wrapper. | shell entrypoint | script / compatibility | native UltraGrid | ACTIVE | Host/tool dependent. |
| `scripts/build-local-ultragrid-docker.sh` | shell | Builds local UltraGrid Docker image. | shell entrypoint | script / build adapter | Dockerfile under `scripts/ultragrid-docker/` | ACTIVE | External image reproducibility. |
| `scripts/ultragrid-docker/Dockerfile` | Dockerfile | UltraGrid local Docker environment. | Docker stages/commands | config / build adapter | apt/git/build tools | ACTIVE | Network/build dependency risk. |

## Tests And Fixtures Inventory

| Path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Tests/OpenLolaCoreTests/` | Swift Testing target | Broad unit/contract tests for reports, CLI, app shell, network, audio, video, connector behavior. | `@Test` functions | test | OpenLolaCore, OpenLolaContracts, OpenLolaAppSupport | ACTIVE | Large suite; source-text tests and broad files can be brittle. |
| `Tests/OpenLolaCoreTests/Fixtures/` | JSON/hex fixtures | Report and packet fixtures used by validator/contract tests. | fixture files | generated-like test contract | Swift test resources | ACTIVE / GENERATED-LIKE | Fixtures prove schemas, not live hardware/runtime behavior. |
| `Tests/OpenLolaCoreTests/*+TestSupport.swift` | Swift test support | Shared fixture builders, local ports, socket gating, peer runner support. | helper functions/types | test support | Swift Testing and target internals | ACTIVE | Helpers can hide weak test intent if overused. |
| `linux_connector/tests/` | Python tests | Pytest coverage for protocol/media/process/runtime connector behavior. | pytest test functions | test | pytest, linux_connector package | ACTIVE | Four Python test files cover a broad compatibility surface. |

Largest Swift test hotspots by line count:

- `Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift` (718 lines): external connector session contract tests.
- `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift` (713 lines): remaining app-shell slice coverage after behavior-area splits; below the line-budget ceiling but still near it.
- `Tests/OpenLolaCoreTests/JackTripCompatibilityTests.swift` (701 lines): JackTrip source-level compatibility tests; not reference-peer proof.
- `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift` (694 lines): remaining app-shell behavior coverage after focused splits; below the line-budget ceiling.
- `Tests/OpenLolaCoreTests/PeerSessionAVSupportTests.swift` (691 lines): direct-peer AV support behavior; high-value but large.
- `Tests/OpenLolaCoreTests/LoLaQuickConnectFallbackTests.swift` (664 lines): LoLa QuickConn compatibility fallback coverage.
- `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift` (639 lines): source/text release-hygiene contract tests after Docker-policy split.

## Large First-Party Areas Requiring Deeper File-Level Inspection

These areas are represented above but not fully reviewed file by file in this
pass. Do not delete, merge, or refactor inside them without proving callers,
tests, CLI/app/report contracts, and runtime impact.

| Path | File count | Why deeper inspection is needed | Proof needed before cleanup/refactor |
|---|---:|---|---|
| `Sources/OpenLolaCore/Network/P2P/` | 37 | Direct P2P runtime, AV loops, socket runners, reports, receive proof, two-peer orchestration. | Caller graph from CLI/app/tests, packet/report contracts, runtime smoke, teardown evidence. |
| `Sources/OpenLolaCore/Connectors/LoLa/` | 28 | Windows LoLa compatibility, control exchanges, UDP/raw-link media, video/audio bridges. | Compatibility lane tests, Windows peer evidence, raw-link/UDP command usage, fixture validators. |
| `Sources/OpenLolaCore/Video/` | 21 | Capture, render, packetization, reassembly, JPEG XS bridge, socket media. | Capture permission behavior, frame pacing, reassembly bounds, preview lifecycle tests. |
| `Sources/OpenLolaCore/Release/` | 21 | Release/manual evidence gates, packaging, recording, current evidence status. | Active CLI validators, docs release boundary, fixture schema tests, manual gate mapping. |
| `Sources/OpenLolaCore/Network/UDP/` | 20 | UDP PCM packets, loopback, socket operations, fragmented V2 packets, media transport. | Packet compatibility tests, socket lifecycle tests, loss/jitter/reordering checks. |
| `Sources/OpenLolaCore/Timing/` | 14 | Drift/PLC, media clock, RX buffering, latency profiles and benchmarks. | Boundary tests for clock drift, buffer underrun/overrun, profile mapping to runtime flags. |
| `Sources/OpenLolaCore/Connectors/JackTrip/` | 14 | JackTrip protocol modes, topology, TCP handshake, pass validation, compatibility runtime. | Source tests plus real `jacktrip` executable/reference-peer evidence. |
| `Sources/OpenLolaCore/Audio/MADI/` | 14 | MADI TX/RX/full-duplex runtime, buffers, reports, RME evidence. | Hardware route evidence, CoreAudio callback safety, buffer lifecycle tests. |
| `Sources/OpenLolaCore/Connectors/UltraGrid/` | 13 | UltraGrid RTP/MVTP, media IO/provider, FEC/encryption/control/topology. | Source tests plus external UltraGrid peer evidence; crypto/FEC review. |
| `Sources/OpenLolaCore/Audio/Realtime/` | 12 | CoreAudio realtime graph, callback helpers, rings, payload handoff. | No-blocking/no-allocation callback audit, memory ordering proof, underrun/overrun tests. |
| `Sources/OpenLolaCore/Platform/` | 12 | App shell public contracts and state. | App UI tests, bundle launch verifier, storage migration proof. |
| `Sources/open-lola-app/` | 38 | SwiftUI app shell and operator console. | Visual/manual smoke, accessibility evidence, runtime wiring proof for each control. |
| `Sources/open-lola/Commands/` | 16 | CLI command parsing, dispatch, evidence attachment, process orchestration. | Command inventory tests, parser behavior tests, docs/help sync. |
| `scripts/` and `script/` | 34 source/config files | Release/build/parity helpers with host and GUI side effects. | Shellcheck, local dry-runs, release-candidate proof, app launch evidence. |
| `linux_connector/` Python source | 15 Python source/test/tool files | Async socket compatibility seed and Windows/WSL support. | Pytest, WSL/Windows lab evidence, process backend tests. |
| `Sources/opus-1.5.2/` | 700+ files | Vendored Opus source and collateral; only a subset is in SwiftPM source list. | Package.swift source membership, license/security review, upstream update policy. |
| `Sources/xs_ref_sw_ed2/` | 90+ files | Vendored JPEG XS reference source/programs; only `libjxs` is a SwiftPM target. | Package.swift source membership, license/security review, bridge tests. |

## Highest-Risk Files

- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift` and `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphCallbacks.swift`: realtime CoreAudio callback and graph lifecycle.
- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift`, `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift`, and `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionSocketRunner.swift`: packet send/receive, media loops, teardown, timing.
- `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift` and `Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift`: protocol/packet compatibility and bounds.
- `Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeRuntime.swift`, `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMedia.swift`, and `Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityRawLink.swift`: Windows LoLa compatibility and transport behavior.
- `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridEncryption.swift` and `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridFEC.swift`: security/FEC-sensitive code.
- `Sources/open-lola-app/AppExecutionController.swift`, `Sources/open-lola-app/AppShellRootView.swift`, and `Sources/open-lola-app/AppConsoleModels.swift`: user-visible truthfulness and runtime state.
- `script/build_and_run.sh`: app bundle launch verifier, signing, GUI/accessibility evidence.
- `linux_connector/lola_connector/connector.py` and `linux_connector/lola_connector/runtime.py`: async compatibility runtime.

## Likely Dead Files

No first-party file is proven dead in this pass.

Likely-dead or cleanup-candidate areas must remain `UNCLEAR` until usage is
proved:

- `Sources/xs_ref_sw_ed2/programs/`: likely vendor collateral, not a SwiftPM
  target. Proof needed: no scripts/docs/tests invoke these programs and release
  candidate export policy preserves required license/source obligations.
- Some files under `Sources/opus-1.5.2/` outside the explicit `Package.swift`
  COpus source list: likely vendor collateral. Proof needed: exact SwiftPM C
  target source membership and license/update policy.
- `Sources/open-lola-app/AppRuntimeEvidenceScope.swift`: single enum in active
  app area. Proof needed: multiple active callers or a clearer inline location.
- `Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift`:
  may overlap with local-run command. Proof needed: command registry, tests,
  docs, or manual workflow still requires it.

## Likely Overcomplicated Files

- `Sources/open-lola-app/AppExecutionController.swift` (712 lines): process
  lifecycle and runtime-evidence decisions remain in one controller after
  shared state/readiness, command preview, preparation, and evidence/log/report
  helpers were split out.
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift` (953
  lines): realtime CoreAudio graph lifecycle and device state.
- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift` (892 lines):
  large report schema and validation surface.
- `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift` (764 lines):
  capture/runtime/framework adapter.
- `Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift`
  (625 lines): local/remote process orchestration and artifact collection.
- `scripts/verify_docs/constants.py` (436 lines): many hardcoded doc/source
  policy constants.

## Likely Deprecated Compatibility Paths

These are not deletion recommendations. They are compatibility surfaces that
need explicit proof before preservation or removal decisions:

- Windows LoLa compatibility files under `Sources/OpenLolaCore/Connectors/LoLa/`,
  especially TCP/UDP/raw-link variants and capture-report support.
- `Sources/open-lola-app/AppShellStoredDefaults.swift`: legacy stored-defaults
  migration.
- Direct P2P CLI argument aliases in
  `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift`.
- Python/WSL helper scripts under `linux_connector/env/`.
- Windows corpus checks under `scripts/verify_docs/windows_*`.
- Local Docker/native UltraGrid and JackTrip parity scripts under `scripts/`.

## Recommended Next Audit Targets

1. Direct P2P runtime audit: `Sources/OpenLolaCore/Network/P2P/` plus matching
   CLI command support and tests.
2. App-shell state truthfulness audit: `Sources/open-lola-app/AppExecutionController.swift`,
   `Sources/open-lola-app/AppShellRootView.swift`, `Sources/open-lola-app/AppShellSectionViews.swift`,
   `Sources/open-lola-app/AppConsoleModels.swift`,
   and platform contracts under `Sources/OpenLolaCore/Platform/`.
3. Realtime audio audit: `Sources/OpenLolaCore/Audio/Realtime/` and
   `Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift`.
4. Connector compatibility audit: LoLa, UltraGrid, JackTrip, and NMP directories
   under `Sources/OpenLolaCore/Connectors/`, with reference-peer evidence
   separated from source-level tests.
5. Verification trust audit: `script/build_and_run.sh`, `scripts/verify-release-readiness.sh`,
   `scripts/verify-release-hygiene.sh`, and `scripts/verify_docs/`.
6. Vendored boundary audit: `Sources/opus-1.5.2/`, `Sources/xs_ref_sw_ed2/`,
   bridge headers, package source lists, license/notices, and release export
   policy.

## Coverage Gaps And Uncertainty

- Full file-by-file semantic review was not completed for all 388 first-party
  Swift source files, 100+ Swift test files, vendored Opus/JPEG-XS trees, and
  report fixtures. The directory-level rows above are the authoritative scope
  map for follow-up.
- Runtime usage was not inferred from filenames alone. Where this pass did not
  inspect callers or tests deeply, status is `UNCLEAR` and proof criteria are
  named.
- Vendored trees are represented as boundaries, not reviewed internally. Treat
  them as `VENDORED` unless a file is explicitly listed in `Package.swift` or
  used by a bridge.
- Fixtures under `Tests/OpenLolaCoreTests/Fixtures/` were not indexed file by
  file. They are active test contracts, but they do not prove hardware,
  peer-to-peer, or field readiness.
- The exact filename for the Windows UDP relay utility under
  `linux_connector/env/` is intentionally omitted because the active public-docs
  verifier rejects that token in public release docs. Inspect the directory
  directly before cleanup.
- Active source inclusion proves build membership, not live runtime success.
  For runtime-critical cleanup, require targeted behavior tests plus broader
  verification from `docs/testing.md`.
