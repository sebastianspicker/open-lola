# Code Index

Source-file inventory before cleanup or refactor. This is an index, not a
remediation plan.

Generated from repository inspection on 2026-05-16. The checkout is large, with
hundreds of Swift files plus vendored C code and tests, so this pass indexes by
source area first. Smaller public/entrypoint surfaces are listed file by file.
Large areas list their files and mark deeper inspection needs explicitly.

Usage status uses:

- ACTIVE: referenced by current package, command, test, script, or docs surface.
- UNCLEAR: exists in a source area but needs caller/test/build proof before
  cleanup decisions.
- GENERATED/VENDORED: third-party or generated-like code; do not refactor as
  first-party code.
- DEPRECATED/COMPATIBILITY: intentionally retained compatibility surface.

## Package And Build Surface

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Package.swift` | SwiftPM manifest | Defines products, targets, C targets, executable products, and app linker settings. | `executableInfoPlistLinkerSettings` | config | SwiftPM, COpus, COpenLolaAtomics, app Info.plist | ACTIVE | Multiple products and vendored targets make accidental target coupling likely; inspect before changing gates. |
| `.github/workflows/release-readiness.yml` | GitHub Actions YAML | Release-readiness CI workflow. | Workflow jobs | config | shell scripts, SwiftPM, Python tooling | ACTIVE | Needs workflow-level audit before treating local verification as release-equivalent. |

## Source Areas

| Area | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/OpenLolaContracts/` | Swift | Small shared contract target for verdicts, report JSON helpers, methodologies, and RX buffer profile vocabulary. | `MeasurementVerdict`, `MeasurementMethodology`, `JSONReportCoder`, `PrettyJSONCodable`, `RxBufferProfile` | domain logic / public contract | Foundation | ACTIVE | Public vocabulary; changing raw values is a compatibility break. |
| `Sources/OpenLolaCore/Audio/` | Swift | Audio codecs, Core Audio inventory, MADI routes, realtime audio graph, audio loopback, routing ledgers. | `OpusCELTLowDelayCodec`, `CoreAudioInventory`, `Madi*`, `DirectPeerRealtimeAudioGraph*`, `RealtimeAudioEngine*`, `AudioLoopback*`, `DirectAudioMediaRouter` | domain logic / adapter | CoreAudio, Darwin sockets, Dispatch, COpenLolaAtomics, COpus, OpenLolaContracts | ACTIVE | High-risk realtime paths; line-count hotspots and legacy accessors need careful audit. |
| `Sources/OpenLolaCore/Benchmarks/` | Swift | E2E, latency, and performance report schemas, validators, and synthetic smoke runners. | `E2EBenchmarkReport`, `LatencyBenchmarkReport`, `PerformanceAuditReport`, related runners/validators | domain logic / test evidence | Foundation, Darwin/Glibc/os for latency timing | ACTIVE | Synthetic placeholders are intentional but dangerous if promoted to PASS. |
| `Sources/OpenLolaCore/Connectors/` | Swift | External connector orchestration plus JackTrip, UltraGrid, NMP, and Windows LoLa compatibility surfaces. | `ExternalConnector*`, `LoLaCompatibility*`, `LoLaControl*`, `LoLaCoreAudioLiveBridge`, `JackTripLaunchPlan`, `UltraGridLaunchPlan`, `ExternalConnectorNmp*` | adapter / domain logic | Darwin sockets, Dispatch, Foundation, CoreAudio, CoreGraphics/CoreImage/CoreVideo, OpenLolaContracts | ACTIVE / COMPATIBILITY | Compatibility shims and partial-evidence paths are dense; several files are large and require focused audit. |
| `Sources/OpenLolaCore/Control/` | Swift | ATEM read-only probe, lighting gate, OSC cue reports/runners/helpers. | `AtemReadOnlyControlReport`, `AtemReadOnlyControlProbe`, `LightingFixtureGate*`, `OscCue*` | adapter / domain logic | Darwin sockets, Dispatch, Foundation | ACTIVE | Placeholder-sensitive validation and UDP helpers duplicate validation patterns across subsystems. |
| `Sources/OpenLolaCore/Core/` | Swift | CLI support primitives, argument parsing, peer identity, validation primitives, debug trace, contract aliases. | `OpenLolaCLI`, `KeyValueArgumentParser`, `PeerIdentity`, `SessionValidation`, `ValidationPrimitives`, aliases | domain logic / config | Foundation, OpenLolaContracts | ACTIVE | Central helpers; changing errors or parsing can ripple into CLI/tests. |
| `Sources/OpenLolaCore/Evidence/` | Swift | Generic and hardware evidence reports, report-schema inventory, validator surface, verdict policy. | `MeasurementReport`, `HardwareValidationReport`, `ReferenceRigReport`, `ReportSchemaInventory`, `ReportValidatorSurface`, `VerdictValidationPolicy` | domain logic / public contract | Foundation | ACTIVE | Placeholder/PASS gating is high-risk because it controls truthful status. |
| `Sources/OpenLolaCore/Integration/` | Swift | Integrated AV/profile report schemas, validation, and aggregation runners. | `IntegratedAvReport`, `IntegratedAvRun`, `IntegratedProfileReport`, `IntegratedProfileRun`, validators/helpers | domain logic | Foundation | ACTIVE | Repeated validation helper patterns; PASS/placeholder behavior needs source-level proof before cleanup. |
| `Sources/OpenLolaCore/Network/` | Swift | Network diagnostics, NAT/rendezvous/relay, Direct P2P, RTP/AES67 L24, UDP PCM and media transport. | `NetworkDiagnostics`, `NatFriendlyRoute*`, `DirectPeerSession*`, `PeerSessionRunner*`, `MacToMac*`, `AES67ST2110L24*`, `Udp*`, `PacketCodec` | domain logic / adapter | Darwin sockets, Dispatch, CoreAudio, os, Foundation, OpenLolaContracts | ACTIVE | Highest runtime-risk area; large socket runners, compatibility fallbacks, legacy transport aliases, and state transitions need dedicated audit. |
| `Sources/OpenLolaCore/Platform/` | Swift | Native app shell contract, app execution bridge, media inventory, artifacts, operator state, and surface models. | `NativeAppShell*` | adapter / UI contract | AppKit, Foundation, OpenLolaContracts | ACTIVE | UI status/report truthfulness risk; storage and command-surface compatibility. |
| `Sources/OpenLolaCore/Protocol/` | Swift | Session control messages, negotiation, protocol validation, capabilities. | `SessionControlMessage`, `SessionNegotiation`, `SessionProtocol`, `SessionCapabilityValidating` | domain logic / protocol contract | Foundation | ACTIVE | Public protocol vocabulary; inspect tests before changing. |
| `Sources/OpenLolaCore/Release/` | Swift | Release-readiness, field-readiness, packaging, recording artifacts, goal closure, current evidence status. | `CurrentEvidenceStatusMatrix`, `FieldReadyRuntimeProof`, `OpenSourceReleaseReadiness`, `PackagingFieldTest*`, `RecordingSession*`, `Goal*`, `LoLaParityDeferredFeatures` | domain logic / public evidence | Foundation | ACTIVE / COMPATIBILITY | Deprecated synthetic parity fixture and placeholder gates are intentional but easy to misuse. |
| `Sources/OpenLolaCore/Support/` | Swift | Shared file/process helpers, inventories, placeholder detection, lock-free ring, monotonic deadline. | `BoundedFileReader`, `BoundedPipeCapture`, `ManagedProcessRunner`, `SPSCAtomicRing`, `CLICommandInventory`, `SourceOwnershipInventory`, `MonotonicDeadline` | support / domain logic | COpenLolaAtomics, Darwin/Dispatch/Foundation depending on file | ACTIVE | Inventories can drift from code; process runner error/kill paths require tests. |
| `Sources/OpenLolaCore/Timing/` | Swift | Media clock, drift/PLC reports, latency tuning, RX buffering, impairment simulation. | `MediaClock`, `AVTimestampAligner`, `RxBuffering`, `DriftPlc*`, `LatencyTuningReport`, `RxBufferBenchmark*` | domain logic | Foundation | ACTIVE | Timing and buffer state transitions are high-risk; several files are large. |
| `Sources/OpenLolaCore/Video/` | Swift | AVFoundation/Blackmagic/JPEG XS video capture, packetization, sockets, reassembly, preview/rendering, reports. | `VideoCapture*`, `VideoTransport*`, `JPEGXSReferenceCodec`, `RawBGRAAppKitPreviewWindow`, `MultiVideoStreams`, `VideoMediaSocket` | adapter / domain logic / UI-adjacent | AVFoundation/CoreMedia/CoreVideo/AppKit likely by file, Foundation | ACTIVE | Capture/render/socket/reassembly paths need runtime proof; vendored JPEG XS bridge boundaries are sensitive. |
| `Sources/open-lola/` | Swift executable | CLI command registry and command handlers for audio, network, benchmarks, milestones, validation. | `runOpenLolaCommand`, `Command`, `RegisteredCommand`, `handle*Command`, `directP2P*` helpers | entrypoint / adapter | OpenLolaCore, OpenLolaContracts, Foundation | ACTIVE | Large command handlers contain parsing, validation, process orchestration, and compatibility aliases in one layer. |
| `Sources/open-lola-app/` | SwiftUI macOS app library | Operator console UI, settings, execution controller, local inventory, preview receiver, packet monitor, app storage keys. | `OpenLolaApp`, `OpenLolaAppScene`, `AppSettings`, `AppExecutionController`, `AppShellRootView`, many SwiftUI views | UI / adapter | SwiftUI, AppKit, CoreAudio, OpenLolaCore | ACTIVE | UI truthfulness risk, storage migrations, and large view/controller files. |
| `Sources/open-lola-app-main/` | Swift executable | Thin app entrypoint for bundled app executable. | `OpenLolaAppMain` | entrypoint | SwiftUI app target | ACTIVE | Minimal. |
| `Sources/COpenLolaAtomics/` | C / header | Local C atomics bridge used by realtime rings/audio graph. | `OpenLolaAtomics.c`, `OpenLolaAtomics.h` | adapter / support | C atomics, Swift C target | ACTIVE | Realtime correctness boundary; audit memory ordering before edits. |
| `Sources/opus-1.5.2/` | C vendored | Vendored Opus codec source used by the COpus target. | Opus C library symbols | vendored / generated-like | C toolchain, SwiftPM C target | VENDORED | Do not cleanup as first-party code; license/security/update audit only. |
| `Sources/xs_ref_sw_ed2/` | C vendored/reference | JPEG XS reference software and encoder/decoder programs. | JPEG XS reference codec symbols | vendored / generated-like / adapter input | C toolchain | VENDORED / UNCLEAR runtime linkage | Large third-party surface; prove build linkage and license boundary before changes. |
| `Tests/OpenLolaCoreTests/` | Swift tests + fixtures | Swift Testing suite for core reports, runtime logic, CLI contracts, fixtures, app shell, network/audio/video behavior. | `@Test` functions, fixture builders, `*TestSupport` helpers | test | OpenLolaCore, OpenLolaContracts, Swift Testing, fixtures | ACTIVE | Large suite; source-text/contract tests may be brittle and need behavior-first audit. |
| `linux_connector/lola_connector/` | Python package | Python LoLa compatibility seed: protocol, media parsing/reassembly, connector control, runtime, CLI, backends. | `LolaConnector`, `LolaLinuxRuntime`, `MediaSettings`, packet/media helpers, backend classes | adapter / domain logic / entrypoint | asyncio, socket, struct, logging, dataclasses | ACTIVE / COMPATIBILITY | Compatibility gate logic, async socket state, and process backends are high-risk. |
| `linux_connector/tests/` | Python tests | Pytest suite for codec, runtime, process/backend behavior. | pytest test functions | test | pytest, linux_connector package | ACTIVE | Only three test files cover a broad compatibility surface. |
| `linux_connector/env/` | Python/shell/PowerShell/Docker/YAML | WSL/Npcap/Windows lab setup and UDP relay utilities. | `npcap_udp_relay.py`, setup/probe scripts, Docker/Compose files | script / adapter / config | socket, subprocess, PowerShell, Docker | ACTIVE / COMPATIBILITY | Environment-specific; usage can be host-dependent. |
| `linux_connector/tools/` | Python tool | Packet decode helper for LoLa media/control captures. | `lola_packet_decoder.py` | script / adapter | scapy, argparse, pathlib | ACTIVE / UNCLEAR dependency availability | Scapy dependency may not be in default install path. |
| `scripts/` | shell/Python/text/Docker | Release/export/readiness/docs verification, local JackTrip/UltraGrid parity probes, Docker/native wrappers. | `verify-docs.sh`, `verify-release-*`, `export-release-candidate.sh`, parity scripts, `scripts.verify_docs` package | script / config | bash, shellcheck, Python stdlib, Docker, external tools | ACTIVE | Scripts encode release policy; several compatibility/local-lab wrappers are environment-specific. |
| `script/` | shell | Native macOS app bundle build/run helpers. | `build_and_run.sh`, `build_cli_app_bundle.sh` | script / build adapter | swift build, codesign, app bundle layout | ACTIVE | Singular `script/` is legacy-shaped but active. |

## File-Level Inventory: Public Contracts

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/OpenLolaContracts/MeasurementVerdict.swift` | Swift | Canonical verdict vocabulary. | `MeasurementVerdict` | public contract | Swift Codable/Sendable | ACTIVE | Raw values are compatibility surface. |
| `Sources/OpenLolaContracts/MeasurementMethodology.swift` | Swift | Measurement methodology vocabulary. | `MeasurementMethodology` | public contract | Codable/Equatable/Sendable | ACTIVE | Raw values are compatibility surface. |
| `Sources/OpenLolaContracts/PrettyJSONCodable.swift` | Swift | Stable pretty JSON encoding/decoding helper protocol. | `JSONReportCoder`, `PrettyJSONCodable` | public contract / support | Foundation JSONEncoder/Decoder | ACTIVE | Formatting choices affect report fixtures. |
| `Sources/OpenLolaContracts/RxBufferProfile.swift` | Swift | Shared RX buffer profile enum. | `RxBufferProfile` | public contract | Codable/CaseIterable | ACTIVE | Values map to CLI/runtime policy; do not rename casually. |

## File-Level Inventory: CLI Entrypoints

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/open-lola/main.swift` | Swift | Top-level CLI registry, dispatch, JSON helpers, usage, and error printing. | `runOpenLolaCommand`, `Command`, `RegisteredCommand`, `openLolaCommandRegistry`, `openLolaCommands`, `CommandError` | entrypoint | OpenLolaCore, OpenLolaContracts, Foundation | ACTIVE | Long command registry can drift from inventory docs/tests. |
| `Sources/open-lola/Commands/CLICommandHelpers.swift` | Swift | Shared CLI validation helper for report artifacts. | `validateReport` | adapter | OpenLolaCore report protocols | ACTIVE | Minimal. |
| `Sources/open-lola/Commands/Audio/LatencyProfileCommands.swift` | Swift | CLI handlers for latency profile and RX buffer benchmark commands. | `handleLatencyProfileCommand` | adapter | OpenLolaCore timing/benchmark types | ACTIVE | Argument parsing embedded in command file. |
| `Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift` | Swift | CLI handler and parser for MADI full-duplex runtime. | `handleMadiFullDuplexCommand`, `MadiFullDuplexCommandRun`, parser helpers | adapter | MADI runtime/config, UDP PCM sample formats, RxBufferProfile | ACTIVE | Large private parser/helper cluster; likely overcomplicated. |
| `Sources/open-lola/Commands/Audio/MadiReceiveCommands.swift` | Swift | CLI handler for MADI receive/report commands. | `handleMadiReceiveCommand` | adapter | MADI receive surfaces | ACTIVE | UNCLEAR until command tests are mapped. |
| `Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift` | Swift | CLI handlers for E2E benchmark reports and validation. | `handleE2EBenchmarkCommand` | adapter | E2E benchmark reports | ACTIVE | Input-data helpers should be checked against validator behavior. |
| `Sources/open-lola/Commands/Benchmarks/PerformanceCommands.swift` | Swift | CLI handlers for performance audit reports. | `handlePerformanceCommand` | adapter | Performance audit reports | ACTIVE | UNCLEAR usage details without command matrix. |
| `Sources/open-lola/Commands/MilestoneCommands.swift` | Swift | Broad milestone/report generation command handler. | `handleMilestoneCommand` | adapter | Many OpenLolaCore report builders | ACTIVE | 600+ lines; broad branching and mixed responsibilities likely. |
| `Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift` | Swift | Validation command handler for milestone/report artifacts. | `handleMilestoneValidationCommand` | adapter | Report validators | ACTIVE | Broad validation dispatcher can drift from schema inventory. |
| `Sources/open-lola/Commands/Network/NetworkCommands.swift` | Swift | Network command dispatcher and UDP/P2P/NAT/AoIP command handlers. | `handleNetworkCommand`, UDP route usage helpers | adapter | Network runners/reports | ACTIVE | Broad dispatcher with high branching; high audit priority. |
| `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift` | Swift | Parser and builder for direct P2P session-run configuration. | `parseDirectP2PSessionRunArguments`, `directP2PSessionAVConfiguration`, `directP2PValidateAudioCompressionScope` | adapter / protocol config | DirectPeer session types, audio/video transport enums | ACTIVE / COMPATIBILITY | Legacy `--audio-compression` alias and many validation branches. |
| `Sources/open-lola/Commands/Network/DirectP2PSessionRunArgumentSupport.swift` | Swift | Allowed/public argument sets for direct P2P session-run. | `directP2PSessionRunAllowedArguments`, `directP2PSessionRunPublicArguments` | config / adapter | CLI parser | ACTIVE | Must stay in sync with parser and help text. |
| `Sources/open-lola/Commands/Network/DirectP2PSessionQualityPolicyCommandSupport.swift` | Swift | Direct P2P quality policy derivation. | `directP2PQualityPolicy` | adapter | Direct peer session config | ACTIVE | UNCLEAR without tests. |
| `Sources/open-lola/Commands/Network/DirectP2PMeasuredEvidenceCommandSupport.swift` | Swift | Attaches measured evidence and receive-proof artifacts to direct P2P reports. | `directP2PApplyMeasuredEvidence`, `directP2PAttachGeneratedReceiveEvidence`, artifact helpers | adapter / evidence | DirectPeer reports, JSON evidence | ACTIVE | Evidence promotion logic is high-risk. |
| `Sources/open-lola/Commands/Network/DirectP2PMeshArgumentSupport.swift` | Swift | Parser helpers for mesh topology/runtime commands. | `parseDirectP2PMeshTopologyArguments`, `parseDirectP2PMeshRuntimeArguments` | adapter | DirectPeer mesh reports | ACTIVE | Repeated parser pattern. |
| `Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift` | Swift | CLI handler for two-peer prototype report aggregation. | `runDirectP2PTwoPeerPrototypeReportCommand` | adapter | DirectPeer session report and RX proof artifacts | ACTIVE | UNCLEAR if superseded by local-run command. |
| `Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift` | Swift | Launches/coordinates local or remote two-peer direct P2P processes and aggregates artifacts. | `runDirectP2PTwoPeerLocalRunCommand`, process/ready-file/SCP helpers | adapter / script orchestration | `ManagedProcessRunner`, shell/scp, DirectPeer reports | ACTIVE | 600+ lines; process lifecycle, timeout, shell quoting, and artifact collection are high-risk. |

## File-Level Inventory: macOS App Surface

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `Sources/open-lola-app-main/OpenLolaAppMain.swift` | SwiftUI | Executable app entrypoint. | `OpenLolaAppMain` | entrypoint | `OpenLolaApp` | ACTIVE | Minimal. |
| `Sources/open-lola-app/OpenLolaApp.swift` | SwiftUI | App scene, menu commands, top-level app state wiring. | `OpenLolaApp`, `OpenLolaAppScene`, `AppMenuActionHandling` | UI / entrypoint | SwiftUI, app shell state, settings | ACTIVE | Starts from placeholder report; ensure UI labels remain evidence-backed. |
| `Sources/open-lola-app/AppSettings.swift` | Swift | Observable settings for CLI/app command inputs. | `AppSettings`, `AppPreviewDefaults` | UI / config / storage | SwiftUI observation/storage, OpenLolaCore enums | ACTIVE | Storage/defaults compatibility; large settings object. |
| `Sources/open-lola-app/AppStorageKeys.swift` | Swift | Central storage keys and artifact defaults. | `AppStorageKeys`, `AppOperatorArtifactDefaults` | storage contract | SwiftUI/AppStorage callers | ACTIVE | Key renames are migrations. |
| `Sources/open-lola-app/AppShellStoredDefaults.swift` | Swift | Translates stored defaults into operator surface state, including legacy migration. | `AppShellStoredDefaults` | storage adapter / compatibility | Native app shell models | ACTIVE / COMPATIBILITY | Legacy audio-compression migration path; prove before removal. |
| `Sources/open-lola-app/AppExecutionController.swift` | Swift | Runs commands, tracks execution phase, validation readiness, reports/logs/errors. | `AppExecutionController`, `AppExecutionPhase`, `AppExecutionKind`, `AppValidationReadiness` | UI adapter / process orchestration | Foundation process APIs, app settings, OpenLolaCore reports | ACTIVE | 700+ lines; process state transitions and error reporting are high-risk. |
| `Sources/open-lola-app/AppExecutablePathResolver.swift` | Swift | Resolves bundled/debug CLI executable path. | `AppExecutablePathResolver` | adapter | Bundle/process environment | ACTIVE | UNCLEAR fallback behavior without app bundle tests. |
| `Sources/open-lola-app/AppShellRootView.swift` | SwiftUI | Main operator console layout and report-derived details. | `AppShellRootView` and nested section views | UI | SwiftUI, app shell reports/settings | ACTIVE | 600+ lines; UI state and report truthfulness risk. |
| `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift` | SwiftUI | Local operator workflow/device/network command input surface. | `AppLocalOperatorSurfaceView`, workflow/device/peer subviews | UI | App settings, media inventory, command intent state | ACTIVE | 550+ lines; duplicated UI state and validation likely. |
| `Sources/open-lola-app/AppShellSettingsView.swift` | SwiftUI | Settings container for execution, connector, peer, audio/video, preview, snapshots. | `AppShellSettingsView` | UI | AppSettings, tab subviews | ACTIVE | 498 lines; may mix unrelated settings. |
| `Sources/open-lola-app/AppShellSettingsTabs.swift` | SwiftUI | Individual settings tabs. | `AppExecutionSettingsTab`, `AppWindowsLoLaSettingsTab`, `AppPeersSettingsTab`, etc. | UI | AppSettings and storage bindings | ACTIVE | Many settings surfaces; check that every control affects runtime. |
| `Sources/open-lola-app/AppReceiverPreviewServices.swift` | Swift/AppKit/CoreAudio | Video preview layer and Core Audio input meter tap services. | `AppVideoPreviewController`, `AppAudioLevelMeter`, `AppCoreAudioInputMeterTap` | UI adapter / runtime adapter | AppKit, AVFoundation/CoreAudio APIs | ACTIVE | Core Audio callbacks/timers in UI layer; high-risk for leaks/state. |
| `Sources/open-lola-app/AppPreviewReceiverView.swift` | SwiftUI | Receiver preview window state and controls. | `AppPreviewReceiverState`, `AppPreviewReceiverView`, `AppReceiverWindowView` | UI | Preview services, app settings | ACTIVE | UI availability must match service state. |
| `Sources/open-lola-app/AppPacketMonitorView.swift` | SwiftUI | Packet monitor table/empty/error states. | `AppPacketMonitorView`, `AppPacketMonitorRowsState` | UI | Native app shell packet rows | ACTIVE | Status rows must be report-backed. |
| `Sources/open-lola-app/AppConsoleModels.swift` | Swift | Derived console snapshot and section selection models. | `AppConsoleStatusSnapshot`, `AppConsoleSectionSelection`, `AppValidationRow` | UI model | Native app shell report | ACTIVE | Derived truthfulness risk. |
| `Sources/open-lola-app/AppDesignSystem.swift` | SwiftUI | App colors, spacing, constants, status badge, design panel. | `AppDesignSystem`, `AppColorRole`, `AppConstants`, `AppSessionState`, `DesignPanel` | UI support | SwiftUI | ACTIVE | Design state names can mislead if decoupled from runtime evidence. |
| `Sources/open-lola-app/AppConsoleChromeView.swift` | SwiftUI | Sidebar/topbar/footer/panel shell chrome. | `AppConsoleSidebarView`, `AppConsoleTopBarView`, `AppConsoleFooterStripView`, `AppConsolePanel` | UI | SwiftUI | ACTIVE | Mostly presentation. |
| `Sources/open-lola-app/AppChannelMeterView.swift` | SwiftUI | Audio channel meter visualization and peak decay. | `AppChannelMeterView`, `ChannelMeterLevelSnapshot`, `PeakHoldState` | UI | SwiftUI timers/state | ACTIVE | Timer/peak decay behavior should be tested visually/runtime. |
| `Sources/open-lola-app/AppConnectionTopologyView.swift` | SwiftUI | Visual connection topology. | `AppConnectionTopologyView` | UI | SwiftUI | ACTIVE | UNCLEAR exact report inputs without deeper view inspection. |
| `Sources/open-lola-app/AppDeviceCard.swift` | SwiftUI | Audio/video selectable device cards. | `AppAudioDeviceCard`, `AppVideoDeviceCard` | UI | SwiftUI | ACTIVE | Selection must be wired to runtime device UID. |
| `Sources/open-lola-app/AppExecutionView.swift` | SwiftUI | Execution controls, report/log display, error guidance. | `AppExecutionView`, `AppReportsView`, `AppLogsView`, `AppExecutionErrorGuidance`, `AppCommandPreview` | UI | AppExecutionController | ACTIVE | Error guidance must not hide failed runtime state. |
| `Sources/open-lola-app/AppLatencyHeroMetrics.swift` | Swift | Derived latency hero metrics. | `AppLatencyHeroMetrics` | UI model | Report metrics | ACTIVE | Derived metrics need report truthfulness. |
| `Sources/open-lola-app/AppLatencyHeroView.swift` | SwiftUI | Hero latency summary visualization. | `AppLatencyHeroView` | UI | AppLatencyHeroMetrics | ACTIVE | Avoid optimistic hero claims. |
| `Sources/open-lola-app/AppLocalOperatorInventory.swift` | Swift | Local media inventory controller. | `AppLocalOperatorInventoryController`, `AppLocalOperatorInventory` | UI adapter | Native media inventory | ACTIVE | Inventory refresh/state errors need audit. |
| `Sources/open-lola-app/AppOperatorArtifactViews.swift` | SwiftUI | Operator artifact/report path display. | `AppOperatorArtifactsView` | UI | Artifact defaults/report paths | ACTIVE | Must distinguish generated/missing artifacts. |
| `Sources/open-lola-app/AppOperatorPlanViews.swift` | SwiftUI | Operator readiness/plan/command views. | `AppOperatorPrototypePlan`, `AppOperatorReadinessView`, `AppOperatorCommandsView` | UI | Native app shell operator fields | ACTIVE | Readiness labels can become false-success. |
| `Sources/open-lola-app/AppPreviewBindings.swift` | Swift | Preview binding helpers. | `appPreviewBinding`, `appPreviewIntBinding` | UI support | SwiftUI Binding | ACTIVE | Minimal. |
| `Sources/open-lola-app/AppRemoteInventoryImport.swift` | Swift | Imports remote inventory data into operator state. | `NativeAppShellOperatorPrototypeState` extension | UI adapter | Native media inventory | ACTIVE | State mutation requires tests. |
| `Sources/open-lola-app/AppRuntimeEvidenceScope.swift` | Swift | App-side runtime evidence scope vocabulary. | `AppRuntimeEvidenceScope` | UI model / contract | Swift enum | ACTIVE / UNCLEAR | Newly added in dirty tree; prove command/report use before cleanup. |
| `Sources/open-lola-app/AppSessionStateBanner.swift` | SwiftUI | Session state banner rendering. | `AppSessionStateBanner`, `AppSessionState` extension | UI | SwiftUI, design system | ACTIVE | State labels must be evidence-backed. |
| `Sources/open-lola-app/AppShellReadOnlyViews.swift` | SwiftUI | Read-only report sections. | `AppShellOverviewView`, `AppShellConfigurationView`, `AppShellMetricsView`, etc. | UI | Native app shell report | ACTIVE | Report-derived labels need no optimism. |
| `Sources/open-lola-app/AppShellSupportViews.swift` | SwiftUI | Shared fields, metric tiles, badges, warning banner, helpers. | `UInt16Field`, `IntField`, `MetricsGrid`, `AppReadableMetric`, `AppStatusBadge`, `yesNo` | UI support | SwiftUI, pasteboard | ACTIVE | Generic status badge can make false-success easier. |
| `Sources/open-lola-app/AppTransportView.swift` | SwiftUI | Transport-focused app view. | `AppTransportView` | UI | SwiftUI/OpenLolaCore transport models | ACTIVE | UNCLEAR depth; inspect with callers. |
| `Sources/open-lola-app/Info.plist` | plist | App bundle metadata. | Bundle keys | config | macOS app bundle | ACTIVE | App identity/storage consequences. |
| `Sources/open-lola-app/open-lola-app.entitlements` | plist | App sandbox/entitlement settings. | Entitlement keys | config | codesign, app bundle | ACTIVE | Runtime permissions boundary. |

## File-Level Inventory: Python Connector

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `linux_connector/lola_connector/__init__.py` | Python | Package export surface. | imports/exports backend, ethernet, media, protocol, runtime names | public contract | internal modules | ACTIVE | Export drift possible. |
| `linux_connector/lola_connector/protocol.py` | Python | LoLa control/media protocol constants and parsers/builders. | `MediaSettings`, `MESG_*`, packet builders/parsers | protocol contract | `ipaddress`, `struct`, media constants | ACTIVE / COMPATIBILITY | Windows compatibility assumptions; raw protocol values are sensitive. |
| `linux_connector/lola_connector/media.py` | Python | Media payload parsing, frame builders, reassembly, audio/video helpers. | `Fragment`, `VideoPrelude`, `MediaReassembler`, `parse_*`, `expected_audio_payload_size` | domain logic | `struct`, `math`, logging | ACTIVE / COMPATIBILITY | Packet grammar and reassembly state are high-risk. |
| `linux_connector/lola_connector/ethernet.py` | Python | Ethernet/IPv4/UDP frame construction and checksum helpers. | `build_ethernet_ipv4_udp_frame`, `build_ipv4_udp_packet`, `internet_checksum`, `parse_mac` | adapter / protocol | `ipaddress`, `struct` | ACTIVE | Low-level byte contract. |
| `linux_connector/lola_connector/connector.py` | Python | Async control-plane connector/listener and session management. | `LolaConnector`, `Session`, status/control helpers | adapter / runtime | `asyncio`, `socket`, media/protocol modules | ACTIVE / COMPATIBILITY | 570+ lines; async state, compatibility rejection, and socket lifecycle are high-risk. |
| `linux_connector/lola_connector/runtime.py` | Python | Runtime bridge from connector sessions to media capture/playback/display. | `LolaLinuxRuntime`, `RuntimeStats` | adapter / runtime | asyncio, sockets, backends, media parser | ACTIVE | Async media loop and stats/error handling need deeper audit. |
| `linux_connector/lola_connector/backends.py` | Python | Audio/video backend abstractions and process/memory/pattern implementations. | `AudioCapture`, `AudioPlayback`, `VideoCapture`, `VideoDisplay`, memory/process/pattern classes | adapter | asyncio subprocess, math, shlex | ACTIVE | 570+ lines; process backends and generated media are broad. |
| `linux_connector/lola_connector/cli.py` | Python | CLI parser and run dispatcher for connector. | `build_parser`, `validate_cli_args`, `run`, builders | entrypoint / adapter | argparse, asyncio, backend/runtime modules | ACTIVE | CLI validation mixed with construction. |
| `linux_connector/lola_connector/selftest.py` | Python | Connector self-tests with memory backends. | `run_bidirectional_selftest`, `run_control_handshake_selftest` | test/runtime support | asyncio, memory backends | ACTIVE | Synthetic success must not become field proof. |
| `linux_connector/env/npcap_udp_relay.py` | Python | Npcap/Windows UDP relay utility. | `send_payload_nonblocking`, CLI relay functions | script / adapter | socket, subprocess, logging | ACTIVE / COMPATIBILITY | Host-specific behavior; prove on Windows/Npcap. |
| `linux_connector/tools/lola_packet_decoder.py` | Python | Capture decoder for LoLa packets. | CLI decoder/data classes | script / adapter | scapy, struct, pathlib | ACTIVE / UNCLEAR dependency | Optional Scapy dependency. |

## File-Level Inventory: Verification Scripts

| File path | Language/type | Primary responsibility | Main exports/classes/functions | Runtime role | Direct dependencies worth knowing | Status | Obvious smells |
|---|---|---|---|---|---|---|---|
| `scripts/verify-docs.sh` | shell | Runs docs verifier. | shell entrypoint | script | Python module `scripts.verify_docs` | ACTIVE | Shell/Python split. |
| `scripts/verify-release-hygiene.sh` | shell | Release hygiene boundary checks. | shell entrypoint | script | find/grep, release boundary policy | ACTIVE | Encodes release policy; false positives possible. |
| `scripts/verify-release-readiness.sh` | shell | Broader release-readiness gate. | shell entrypoint | script | Swift/Python/docs checks | ACTIVE | Needs audit before calling it comprehensive. |
| `scripts/export-release-candidate.sh` | shell | Stages release candidate export. | shell entrypoint | script / release | rsync/cp/find, release policy | ACTIVE | Release boundary risk; many exclusions. |
| `scripts/verify_docs/main.py` | Python | Python docs verifier dispatcher. | `main` | script | check modules/constants | ACTIVE | Central dispatcher; keep in sync with docs policy. |
| `scripts/verify_docs/markdown_checks.py` | Python | Markdown link/style/TODO checks. | many check helpers | script | pathlib, regex, URL parsing | ACTIVE | 500+ lines; likely overcomplicated. |
| `scripts/verify_docs/constants.py` | Python | Shared docs verifier paths/constants. | constants | config | pathlib, archive inventory | ACTIVE | Path policy can drift. |
| `scripts/verify_docs/archive_inventory.py` | Python | Archive inventory pattern helpers. | `archive_doc_patterns` | script support | regex/pathlib | ACTIVE | UNCLEAR without tests. |
| `scripts/verify_docs/windows_binary_checks.py` | Python | Windows binary/static artifact checks. | check helpers | script | subprocess, JSON, windows docs helpers | ACTIVE / COMPATIBILITY | Host/artifact dependent. |
| `scripts/verify_docs/windows_control_checks.py` | Python | Windows control-plane docs/corpus checks. | check helpers | script | windows binary/docs constants | ACTIVE / COMPATIBILITY | Reverse-engineering policy surface. |
| `scripts/verify_docs/windows_docs.py` | Python | Windows docs hash/path checks. | check helpers | script | hashlib, regex | ACTIVE / COMPATIBILITY | Corpus path assumptions. |
| `scripts/verify_docs/windows_media_checks.py` | Python | Windows media corpus/docs checks. | check helpers | script | windows binary/docs helpers | ACTIVE / COMPATIBILITY | Legacy residue checks and media assumptions. |
| `scripts/lib/common.sh` | shell | Shared shell helper library. | shell functions | script support | bash | ACTIVE | Must inspect callers before editing. |
| `scripts/lib/parity.sh` | shell | Shared parity wrapper helpers. | shell functions | script support | bash, Docker/native clients | ACTIVE | Environment-specific. |
| `scripts/lib/extract-preflight-executable.py` | Python | Extracts executable path from preflight JSON. | CLI script | script support | json, sys | ACTIVE | Minimal. |
| `scripts/lib/write-connection-metrics.py` | Python | Writes connection metrics JSON. | CLI script | script support | json, sys | ACTIVE | Minimal. |
| `scripts/lib/write-ultragrid-parity-metrics.py` | Python | Parses UltraGrid parity output and writes metrics. | CLI script | script support | argparse, json, regex | ACTIVE | Parser fragility likely. |
| `script/build_and_run.sh` | shell | Builds and signs app bundle, optional verify/run path. | shell entrypoint | build script | swift build, codesign, app bundle files | ACTIVE | Legacy singular directory but active; signing/runtime side effects. |
| `script/build_cli_app_bundle.sh` | shell | Builds CLI app bundle. | shell entrypoint | build script | swift build, codesign | ACTIVE | Minimal but signing-sensitive. |

## Large Areas Needing Deeper File-By-File Inspection

These areas are represented above but were not manually audited file by file in
this pass. For any cleanup/refactor, prove usage with callers, tests, package
membership, command inventory, and runtime/report contracts before edits.

### `Sources/OpenLolaCore/Audio/`

Files: `Audio/Codecs/OpusCELTLowDelayCodec.swift`; `Audio/CoreAudio/AudioStreamDescription.swift`, `CoreAudioInventory.swift`, `CoreAudioInventoryReader.swift`; `Audio/MADI/MadiChannelCounts.swift`, `MadiFullDuplexReport.swift`, `MadiFullDuplexRuntime.swift`, `MadiFullDuplexSocketRunner.swift`, `MadiFullDuplexTypes.swift`, `MadiFullDuplexValidation.swift`, `MadiReceive.swift`, `MadiReceiveBuffers.swift`, `MadiReceiveReport.swift`, `MadiReceiveTypes.swift`, `MadiTransmit.swift`, `RmeFastestAudioPath.swift`, `RmeMatrixMetadata.swift`, `SyntheticAudioPayload.swift`; `Audio/Realtime/DirectPeerAudioPayloadRing.swift`, `DirectPeerRealtimeAudioGraph.swift`, `DirectPeerRealtimeAudioGraphCallbacks.swift`, `DirectPeerRealtimeAudioGraphRxBuffering.swift`, `DirectPeerRealtimeAudioGraphTypes.swift`, `RealtimeAudioBuffers.swift`, `RealtimeAudioEngine.swift`, `RealtimeAudioEngineHelpers.swift`, `RealtimeAudioEngineReportValidation.swift`, `RealtimeAudioEngineSyntheticSmoke.swift`, `RealtimeAudioPacketHandoff.swift`, `RealtimeAudioPayloadCaptureRing.swift`; `Audio/Routing/AudioBaselineEvidence.swift`, `AudioLoopbackHelpers.swift`, `AudioLoopbackRun.swift`, `AudioLoopbackRunConfiguration.swift`, `AudioRoutingAssumptionLedger.swift`, `DirectAudioMediaRouter.swift`, `ReceiverMixSnapshot.swift`.

Deeper proof needed: realtime callback safety, buffer bounds, Core Audio device
state, MADI TX/RX lifecycle, and whether legacy v1 compatibility ledgers still
serve active callers.

### `Sources/OpenLolaCore/Network/`

Files: `Network/Diagnostics/*`, `Network/NAT/*`, `Network/P2P/*`,
`Network/RTP/AES67ST2110L24Transport.swift`, `Network/UDP/*`.

Deeper proof needed: UDP socket lifecycle, packet loss/jitter/reordering
behavior, relay fallback semantics, Direct P2P readiness files, media TX/RX
state transitions, and legacy `audioCompression` compatibility accessors.

### `Sources/OpenLolaCore/Connectors/`

Files: `Connectors/Core/*`, `Connectors/JackTrip/*`, `Connectors/LoLa/*`,
`Connectors/NMP/*`, `Connectors/UltraGrid/*`.

Deeper proof needed: Windows LoLa compatibility boundaries, raw-link vs UDP
media paths, TCP/UDP control fallback behavior, external process lifecycle,
and whether JackTrip/UltraGrid wrappers are still active release gates.

### `Sources/OpenLolaCore/Video/`

Files: `Video/BlackmagicOutputBoundary.swift`,
`JPEGXSReferenceCodec.swift`, `MediaGeometrySizing.swift`,
`MultiVideoStreams.swift`, `RawBGRAAppKitPreviewWindow.swift`,
`VideoCaptureAVFoundation.swift`, `VideoCaptureHelpers.swift`,
`VideoCaptureProbe.swift`, `VideoCaptureReport.swift`,
`VideoCaptureRunConfiguration.swift`, `VideoCaptureRunner.swift`,
`VideoMediaSocket.swift`, `VideoOutputRenderer.swift`,
`VideoStreamDescription.swift`, `VideoTransportHelpers.swift`,
`VideoTransportMultiStreamRuntime.swift`, `VideoTransportPacket.swift`,
`VideoTransportProbe.swift`, `VideoTransportReassembly.swift`,
`VideoTransportReport.swift`, `VideoTransportRunner.swift`.

Deeper proof needed: capture permissions, frame pacing, packet reassembly
limits, preview/render threading, and JPEG XS reference-code boundary.

### `Tests/OpenLolaCoreTests/`

Files: 225 Swift test/support/fixture files plus JSON/hex fixtures under
`Tests/OpenLolaCoreTests/Fixtures/`.

Deeper proof needed: distinguish behavior tests from source-text/fixture
contract tests, identify low-signal duplicated tests, and map each high-risk
runtime path to at least one meaningful failure test.

### Vendored C Sources

`Sources/opus-1.5.2/` has 714 files and `Sources/xs_ref_sw_ed2/` has 98 files
in the inspected tree. They are represented as vendored/reference code, not
first-party cleanup targets. Usage must be proven through `Package.swift`,
target linkage, license notices, and codec tests before any change.

## Highest-Risk Files

- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`:
  realtime Core Audio graph, atomics, callback coordination, 714 lines.
- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift`:
  AV socket runtime, media loops, readiness/metrics/control, 685 lines.
- `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift`: UDP media
  transport and socket behavior, 697 lines.
- `Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift`:
  external connector session orchestration and report semantics, 691 lines.
- `Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeRuntime.swift`:
  Windows LoLa control exchange, timeouts, UDP/TCP behavior, 622 lines.
- `Sources/open-lola-app/AppExecutionController.swift`: app process execution
  and UI-visible phase/error state, 701 lines.
- `Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift`:
  multi-process local/remote orchestration and artifact collection, 634 lines.
- `linux_connector/lola_connector/connector.py` and
  `linux_connector/lola_connector/runtime.py`: async control/media runtime
  compatibility seed.

## Likely Dead Files

No file is safe to call dead from this first pass. Candidates requiring proof:

- `Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift`:
  UNCLEAR whether superseded by two-peer local-run aggregation. Prove with CLI
  registry, tests, docs, and command inventory before removal.
- `Sources/OpenLolaCore/Connectors/JackTrip/*` and
  `Sources/OpenLolaCore/Connectors/UltraGrid/*`: UNCLEAR whether they remain
  active release/parity gates or historical comparison wrappers. Prove through
  scripts, docs/testing, and tests.
- `linux_connector/WINDOWS_LOLA_VALIDATION.md` and
  `linux_connector/WINDOWS_WSL_LINUX_LOLA_BRINGUP.md`: documented
  compatibility pointers, not source files; likely retained for links.
- Vendored/reference program entrypoints under `Sources/xs_ref_sw_ed2/programs/`:
  UNCLEAR package linkage; prove via SwiftPM target membership and codec tests.

## Likely Overcomplicated Files

- `Sources/open-lola/Commands/MilestoneCommands.swift`: broad report-generation
  dispatcher with many responsibilities.
- `Sources/open-lola/Commands/Network/NetworkCommands.swift`: broad network
  command dispatcher.
- `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift`:
  parser, validation, transport policy, and compatibility aliases in one file.
- `Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift`:
  command parsing, process lifecycle, shell/SCP, readiness, and aggregation.
- `Sources/open-lola-app/AppExecutionController.swift`: execution lifecycle,
  logs, validation readiness, and UI-facing error state in one object.
- `Sources/open-lola-app/AppShellRootView.swift` and
  `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`: large SwiftUI
  files with many nested surfaces.
- `scripts/verify_docs/markdown_checks.py`: many docs policy checks in one
  module.

## Likely Deprecated Compatibility Paths

- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift`:
  deprecated `audioDeviceUID` compatibility accessor for split input/output
  device UIDs.
- `Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift`,
  `Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift`,
  `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRunTypes.swift`,
  `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRuntimeReport.swift`,
  and `Sources/OpenLolaCore/Platform/NativeAppShellDirectPeerCommand.swift`:
  legacy `audioCompression`/`--audio-compression` compatibility surfaces.
- `Sources/open-lola-app/AppShellStoredDefaults.swift`: migration from legacy
  stored `audioCompression` to `audioTransport`.
- `Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift`: deprecated
  synthetic parity ledger fixture path.
- `Sources/OpenLolaCore/Network/NAT/*`: rendezvous/relay fallback paths marked
  compatibility-only in reports and matrix notes.
- `linux_connector/docs/*` and `linux_connector/env/*`: Windows LoLa/Npcap/WSL
  compatibility lanes; active but environment-specific.

## Recommended Next Audit Targets

1. Realtime audio graph and atomics: `DirectPeerRealtimeAudioGraph*`,
   `RealtimeAudioPacketHandoff.swift`, `SPSCAtomicRing.swift`,
   `COpenLolaAtomics`.
2. Direct P2P AV runtime: `DirectPeerSessionAVSocketRunner.swift`,
   audio/video loop files, report builder, control/metrics service, and CLI
   parser.
3. Windows LoLa compatibility path: `ExternalConnectorSession*`,
   `LoLaControlExchangeRuntime.swift`, `LoLaCompatibilityUdpMedia*`,
   `LoLaCompatibilityRawLink.swift`, Python `linux_connector`.
4. UI truthfulness path: `AppExecutionController.swift`,
   `AppShellRootView.swift`, `AppOperatorPlanViews.swift`,
   `AppSessionStateBanner.swift`, `AppPacketMonitorView.swift`.
5. Verification/tooling drift: `ReportSchemaInventory.swift`,
   `ReportValidatorSurface.swift`, `CLICommandInventory.swift`,
   `NetworkRouteCommandMatrix.swift`, `scripts/verify_docs/*`.

## Coverage Gaps And Uncertainty

- This pass did not manually inspect every Swift/C/Python file body. It covered
  the full source tree by area, key public/entrypoint surfaces file by file,
  imports, symbol extraction, line-count hotspots, and compatibility markers.
- `Tests/OpenLolaCoreTests/` is represented as a test area, not individually
  audited. A separate test-quality index should map each test file to the
  behavior it proves and flag source-text-only assertions.
- Vendored `opus-1.5.2` and `xs_ref_sw_ed2` were not audited internally.
  Treat them as third-party/reference code unless package linkage, license
  obligations, and security/update needs justify inspection.
- Usage status is conservative. When marked UNCLEAR, the proof needed is:
  caller search, package target membership, CLI registry or app navigation
  reachability, tests, docs command matrix, and if runtime-facing, a report or
  smoke probe.
- The working tree was already dirty during this index. This document does not
  attempt to distinguish committed baseline from unrelated in-progress edits.
