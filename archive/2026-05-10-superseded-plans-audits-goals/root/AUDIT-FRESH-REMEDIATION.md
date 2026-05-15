# AUDIT-FRESH.md remediation progress

Date: 2026-05-10
Source audit: `AUDIT-FRESH.md`
Checkout note: this folder has no `.git` metadata, so progress evidence is file/test based.

## Current status

VERDICT: PASS

Every concrete `AUDIT-FRESH.md` finding has been fixed, source-covered,
or proven stale/mitigated against the current tree. This is an audit-remediation
verdict only; it does not promote hardware/field-readiness claims beyond the
existing source-level and measured-evidence gates.

## Completed in this remediation pass

| Audit item | Status | Evidence |
|---|---|---|
| Tier 1 #1 TX/RX race on `UdpMediaTransport` | Fixed | `UdpMediaTransport` serializes connect/send/receive/tryReceive/close through the state lock; focused `UdpMediaTransportTests` pass. |
| Tier 1 #2 FD not closed on `setsockopt` failure | Fixed | `makeUdpSocket` now closes the descriptor and throws `setSocketOptionFailed`; focused UDP tests compile/pass. |
| Tier 1 #3 errno captured after interleaving | Fixed for shared UDP socket helpers | `sendConnectedDatagram`, `sendDatagram`, `receiveDatagram`, and `receiveDatagramIfAvailable` save `errno` immediately after the syscall. |
| Tier 1 #4 `nextFrame` non-atomic in audio callback | Fixed for `AudioLoopbackIOProcState` | Uses `OpenLolaAtomicUInt64` and `open_lola_atomic_u64_fetch_add`; `AudioLoopbackRunTests` pass. |
| Tier 1 #6 subprocess not terminated on view dismiss | Fixed source-level | `AppExecutionController.deinit` terminates the active process; `AppExecutionView.onDisappear` stops a running process. |
| Tier 1 #7 audio meter timer leak | Fixed source-level | `AppAudioLevelMeter.deinit` invalidates the timer and stops the Core Audio tap; receiver window already stops on disappear. |
| Tier 1 #8 camera/microphone permission callback state | Fixed source-level | Permission callbacks guard `self` inside `Task { @MainActor [weak self] ... }`; video preview setup is queued off main and generation-guarded. |
| Tier 2 #9 unbounded video reassembly buffer | Fixed source-level | `VideoFrameReassembler` has per-frame TTL and `maxFragmentsPerFrame`; focused video tests pass. |
| Tier 2 #10 truncated video packet crash | Verified/fixed | Existing 72-byte fixed header is covered by new truncation-boundary test; empty-payload decode no longer slices with a closed range. |
| Tier 2 #11 UDP media low-level reads | Improved/covered | Envelope truncation boundaries now test every short header length; helper preconditions remain internal-only after the top-level byte-count guard. |
| Tier 2 #12 UDP PCM V2 MTU final packet validation | Fixed | Planner now guards every computed packet byte count against MTU; boundary test passes. |
| Tier 2 #13 sequence wrap loss miscount | Fixed | Loss accounting uses wrapping subtraction; rollover regression test passes. |
| Tier 2 #14 LoLa fragment count overflow | Fixed | Fragment count uses integer arithmetic and pre-checks max body bytes before fragment planning; max/n+1 boundary test passes. |
| Tier 2 #15 LoLa UDP socket cache ignores host | Fixed source-level | Cache key is now `(host, port)` instead of port only. |
| Tier 2 #16 TCP half-close not handled | Fixed | TCP receive now treats `recv == 0` as peer close, shuts down the socket, and throws a socket failure; focused TCP half-close test passes. |
| Tier 2 #18 NAT reports success on broken path | Fixed | Direct traversal success is gated by a byte-exact loopback path; validation rejects direct-traversal success with failed loopback. |
| Tier 2 #19 AVFoundation buffer lifetime hazards | Fixed source-level | Capture output now uses the retained capture queue, wraps processing in `autoreleasepool`, bounds retained raw-frame artifacts, and rejects empty pixel-buffer base addresses explicitly. |
| Tier 2 #20 ATEM command suppression | Already enforced in current source | The probe only performs TCP reachability, emits `armedCommandsAllowed: false`, and validation rejects armed commands; existing ATEM tests cover both paths. |
| Tier 3 #21 UDP PCM V2 codec coverage | Improved | Added round-trip, every-truncated-header-boundary, header-guard, and payload-length mismatch tests. |
| Tier 3 #22 video duplicate fragment test gap | Fixed | `VideoTransportReportTests` sends every fragment twice and verifies one completed frame plus duplicate counts. |
| Tier 3 #23 SPSC ring concurrency test missing | Fixed | Added concurrent producer/consumer order-preservation test for `SPSCUInt64Ring`. |
| SPSC ring producer/consumer contract unenforced | Fixed | `SPSCUInt64Ring` now records producer and consumer owner thread IDs with atomic compare-exchange and preconditions on multi-producer or multi-consumer misuse. |
| Tier 3 #26 dictionary in unused jitter buffer | Fixed | `RealtimeAudioFixedTargetJitterBuffer` now uses bounded array storage with explicit capacity instead of `[UInt64: Packet]`; drift/PLC tests pass. |
| Tier 3 #28 raw frame buffer unbounded | Fixed source-level | AVFoundation raw-frame artifacts now retain at most 120 frames and normalize offsets after trimming. |
| Clock-skew zero-latency metric from UDP transport section | Fixed | `UdpMediaMetrics.clockSkewEventCount` records skew and skips jitter update; regression test passes. |
| Realtime handoff burst/drop coverage | Improved | Added tests for capture-ring burst drops and playout-buffer exhaustion. |
| Realtime format mismatch silent drop | Fixed/source-covered | `RealtimeAudioPacketHandoff.recordCaptureResult` increments `invalidInputBlocks`, `droppedInputBlocks`, and `callbackOverrunBlocks` for invalid capture input; `realtimeAudioPacketHandoffReportsInvalidInterleavedInputShape` asserts the diagnostic counters. |
| Debug trace JSON encoder duplication | Fixed | `DebugTraceJSONEncoder` centralizes pretty/sorted JSON output for trace reports. |
| CLI JSON output ceremony duplication | Improved | `OpenLolaCLI` now routes static report JSON through `jsonData` / `validatedJSONData`; `ReportSchemaInventoryReport` uses `PrettyJSONCodable`. |
| Report validator decode contract duplication | Improved | `ReportValidatingArtifact` now inherits `PrettyJSONCodable` instead of restating `static decode(from:)`; `ReportSchemaInventoryTests` enforces the relationship while preserving explicit nominal report conformances. |
| Validation helper function explosion | Improved source-level | `ReportPrimitiveValidating` now exposes shared protocol-based scalar validators plus `requireNonEmptyStrings`; release/evidence/goal report families route through typed validators (`GoalCompletionAuditValidator`, `GoalRuntimeEvidenceTemplateValidator`, `GoalRuntimePreflightValidator`, `GoalCodewiseClosureValidator`, `HardwareValidationValidator`, `MeasurementReportValidator`, `ReleaseHardeningValidator`, `OpenSourceReleaseReadinessValidator`, `FieldReadyRuntimeValidator`, `LoLaParityDeferredValidator`, `FasterThanLoLaClosureValidator`) instead of private per-report primitive wrappers. |
| Linker setting duplication in package manifest | Fixed | `Package.swift` now uses `executableInfoPlistLinkerSettings(_:)` for executable targets. |
| CLI key/value parser duplication | Fixed | `CommandLineArguments.swift` was deleted; parse/coercion helpers now live on `KeyValueArgumentParser`, direct parser construction uses `KeyValueArgumentParser(allowedKeys:)`, `rg 'CommandLineArguments' Sources Tests` finds no matches, and focused release/network/audio/external-connector parser tests pass. |
| App audio meter callback lock | Fixed source-level | `AppCoreAudioInputMeterTap` uses `os_unfair_lock` instead of `NSLock` in the Core Audio callback path. |
| App root elapsed timer lifecycle | Fixed source-level | `AppShellRootView` stores the Combine timer subscription and cancels it on disappear. |
| Local operator inventory blocks UI | Fixed source-level | `AppLocalOperatorSurfaceView` refreshes inventory off-main, disables the button while loading, and shows progress. |
| Inventory errors are visually underreported | Improved source-level | `AppLocalOperatorSurfaceView` now renders local and remote `inventoryErrors` through top-level warning banners instead of low-emphasis loose labels. |
| Remote inventory binding recreation | Improved source-level | `AppLocalOperatorSurfaceView` now binds remote input/output/video UID text fields to stable `@State` draft values, synchronizes them from remote inventory selection, and writes back only on draft changes. |
| Business logic and side effects in view bodies | Improved source-level | `AppLocalOperatorSurfaceView` delegates local inventory refresh to `AppLocalOperatorInventoryController`; the controller owns off-main capture, loading state, and warning surfacing, while source-contract tests reject direct `Task.detached` and `AppLocalOperatorInventory.capture` calls in the view. |
| Artifact file failures are swallowed into status text | Improved | `AppOperatorArtifactViews` now presents an artifact-error alert while keeping status text. |
| Error states not shown as alerts | Improved source-level | `AppExecutionView` surfaces plan and execution errors through top warning banners above the fold, satisfying the audit's alert-or-sticky-banner requirement without hiding critical failures inside lower `GroupBox` content. |
| Execution errors and slow run actions lack visible state | Improved source-level | `AppExecutionView` now surfaces plan/execution errors in top warning banners, disables plan writes while a run is active, and shows a `ProgressView` beside run controls while `isRunning`. |
| Channel meter peak-hold state redraw churn | Improved source-level | `AppChannelMeterView` now stores peak holds and timers in one `Equatable` `PeakHoldState` and only assigns changed state during peak update/decay. |
| Unnecessary canvas redraws in `AppChannelMeterView` | Improved source-level | The previous separate peak-hold arrays are collapsed into one `Equatable` `PeakHoldState`; decay and peak updates assign state only when the computed state changes, reducing avoidable full-canvas invalidations. |
| Channel meter peak-decay task lifecycle | Fixed source-level | `AppChannelMeterView` now owns the repeating decay task through a `@StateObject` `PeakDecayTaskOwner` that cancels on disappear and deinit; the view no longer stores the task in `@State` or uses raw nanosecond sleep. |
| Prototype-sounding SwiftUI footer copy | Fixed | `AppConsoleFooterStripView` no longer renders the "SwiftUI is operator/control surface only" footer sentence; the footer remains focused on status badges. |
| Fat `AppShellDetailView` switch body | Improved source-level | `AppShellRootView` now routes detail sections through named section views (`AppOverviewSectionView`, `AppSessionSectionView`, `AppStreamsSectionView`, `AppRoutingSectionView`, `AppDevicesSectionView`, `AppDiagnosticsSectionView`, `AppValidationSectionView`) instead of large inline computed subtrees. |
| Hardcoded nil latency metrics on overview tab | Improved source-level | `AppLatencyHeroMetrics` loads direct-peer session metrics from the supervisor report path and feeds measured packet loss, jitter, and fastest-AV latency into `AppLatencyHeroView` instead of hardcoded `nil` values. |
| Naming convention drift: Helpers vs Support vs Utilities | Mitigated | `docs/architecture/clean-room-design-rules.md` now defines the `*Helpers`, `*Support`, and discouraged `*Utilities` suffix boundary, with source-contract coverage in `SourceNamingConventionTests`. |
| App storage key ownership unclear | Improved | `AppStorageKeys` now includes an ownership map for execution, peer/audio/video/AV, and preview keys. |
| UDP PCM V2 codec negative coverage | Improved | Added invalid magic, zero-channel, invalid fragment-index, duplicate, out-of-order, and stream-mismatch tests. |
| LoLa video fragment boundary coverage | Improved | Tests now cover below-max, max, and overflow fragment counts. |
| Realtime ring capacity coverage | Improved | `realtimeAudioBlockRingStaysBoundedAndReportsDrops` now covers capacities 1, 2, 4, 8, 16, and 256. |
| Video reassembler corruption coverage | Improved | Added a corrupt-fragment-metadata regression test. |
| AV timestamp policy switch coverage | Improved | Added a queued-frame decision test that re-evaluates the same timestamps after a profile switch. |
| UDP PCM fixture regeneration coverage | Improved | V1 packet fixtures now re-encode byte-for-byte from the current decoder/encoder pair. |
| OSC string-read bounds check | Fixed | `readOscString` now guards OSC padding advancement against the data boundary; missing-final-padding regression test passes. |
| OSC receive timeout enforcement | Fixed | `receiveUdpOscMessage` now gates `recv` with an immediate `select` timeout; timeout regression test passes. |
| UDP sender bind-before-connect | Fixed | Continuous UDP PCM sender paths now bind an ephemeral local endpoint before `connect`, including wildcard binds; `UdpPcmRouteReportTests` pass. |
| Realtime graph zero-channel masking | Fixed | `DirectPeerRealtimeAudioGraph` rejects zero-channel interleaved input/output buffers instead of coercing them to one channel; focused graph tests pass. |
| Audio/video receive paths are not coordinated | Improved source-level | `DirectPeerSessionAVSocketRunner` now maintains a shared audio playout timestamp anchor and drops preview submission for video frames outside the audio window; `DirectPeerSessionAVRuntimeMetrics.videoFramesDroppedOutsideAudioWindow` records the count, and pass validation requires video proof frames to match the frames inside that window. |
| Realtime input-format mismatch diagnostics | Covered/mitigated | `RealtimeAudioPacketHandoff` records `invalidInputBlocks` for invalid interleaved input shape; focused handoff regression test passes. |
| Realtime audio zero-copy TX handoff | Fixed source-level | `RealtimeAudioPayloadCaptureRing` and `DirectPeerAudioPayloadRing` now expose borrowed-pop closures, `RealtimeAudioPacketHandoff.sendNextV2Packets` and the direct-peer AV TX loop packetize from borrowed ring-slot bytes, `UdpPcmV2Packetizer` accepts `UnsafeRawBufferPointer` input without a whole-frame `Data` materialization, and focused realtime/MADI/AV packetizer tests pass. Legacy value-returning `pop()`/V1 packet APIs still copy because their public return types own `Data`. |
| Validation error types have no structural variation | Mitigated by option-A shared structure | User selected the shared-protocol path instead of a disruptive generic-error replacement. `ValidationPrimitives` now exposes typed primitive-error protocols (`ValidationEmptyFieldError`, `ValidationEmptyListError`, `ValidationNonPositiveFieldError`, `ValidationNegativeFieldError`, `ValidationNonFiniteFieldError`) and `ReportPrimitiveValidating` routes repeated primitive checks through one structural surface while preserving existing public report-specific error enums and tests. `VerdictValidationPolicy` separately centralizes invalid-PASS rule structure for release/evidence validators. |
| Validation helper protocol branch | Completed option-A scope | User selected option A. `ValidationPrimitives` now exposes protocol-based validators through `ReportPrimitiveValidating` plus typed empty-field, empty-list, positive, non-negative, finite-error, and non-empty string-list helpers. `RxBufferBenchmarkValidator`, `LatencyTuningValidator`, `PerformanceAuditValidator`, `PackagingFieldValidator`, `RecordingSessionArtifactValidator`, `ReferenceRigValidator`, and the later release/evidence/goal validators route primitive validation through the shared path; the audit-named primitive helper wrappers in `LatencyTuningReportValidation.swift`, `PerformanceAuditReportValidation.swift`, `PackagingFieldTestHelpers.swift`, `RecordingSessionHelpers.swift`, `ReferenceRigHelpers.swift`, and release/evidence/goal report families were removed from validation call paths. `ValidationPrimitivesTests` covers the shared protocol surface. |
| `ReportValidatorSurface.swift` empty conformance extensions | Fixed source-level | The 59 empty `extension FooReport: ReportValidatingArtifact {}` / metadata marker extensions were removed from `ReportValidatorSurface.swift`; the report structs now declare `ReportValidatingArtifact` or `ReportMetadataArtifact` directly at their type declarations. `ReportSchemaInventoryTests.reportValidatorArtifactSurfaceDefinesValidatorContract` rejects the old empty-extension pattern, `rg 'extension .*: ReportValidatingArtifact|extension .*: ReportMetadataArtifact' Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift Sources/OpenLolaCore` finds no matches, and the report-surface validator tests pass. |
| External connector subprocess/readiness cleanup branch | Fixed for audited connector subprocess path | User selected option A. `ExternalConnectorSessionTests` now waits on a readiness continuation instead of a fixed 1 ms polling sleep; `ExternalConnectorProcessGroupTests` uses mock process-runner coverage plus a single Python-based process-group integration probe, kqueue exit waits, and no generated shell executable helpers; `ExternalConnectorProcessRunner` and `ExternalConnectorSessionRuntime` now use kqueue-based process-exit waits instead of `Thread.sleep`. |
| Video reassembler oldest-frame eviction cost | Fixed | `VideoFrameReassembler` now tracks insertion order and skips stale keys for amortized O(1) capacity eviction; capacity regression test passes. |
| Video reassembler value-type ownership ambiguity | Fixed | `VideoFrameReassembler` is now a final reference type with identity equality, so aliases share one reassembly state instead of drifting as independent value copies; `videoFrameReassemblerAliasesShareOneReassemblyState` covers the ownership contract. |
| No test for concurrent reassembler access | Fixed | `VideoFrameReassembler` now serializes all mutable state (`activeFrames`, insertion order, completed-frame cursors, metrics, and mutable limits) behind a private lock; `videoFrameReassemblerSerializesConcurrentFragmentReceive` feeds one shared reassembler from concurrent tasks and verifies exactly one completed frame plus clean metrics. |
| M00/M02/M04 contract tests verify compilation, not behaviour | Improved/source-covered | Added runtime behavior assertions for M00 summary description derivation, M02 latency-profile RX-buffer policy rejection during real session negotiation, and M04 UDP PCM packet mode mismatch rejection. Existing Core Audio inventory and UDP packet tests already cover decode/validation/round-trip behavior. |
| Raw BGRA preview task buildup | Fixed source-level | `RawBGRAAppKitPreviewWindow` now allows only one pending main-actor preview submission and drops additional frames until it completes; focused receive/render tests compile/pass. |
| VERDICT printing inconsistency in Swift CLI | Fixed | Swift CLI command handlers now route verdict output through `printVerdict(_:)`; `rg 'print\\(\"VERDICT:' Sources/open-lola` finds only the shared helper in `main.swift`, and `CLICommandInventoryTests` enforces the source contract. |
| LoLa wire frame endianness ambiguity | Mitigated | Ethernet/IPv4/UDP constants and read/write helpers are annotated as network byte order; byte-level wire-frame tests continue to pass on the local little-endian host. |
| Python connector strict typing gate | Fixed for production package | `scripts/verify-release-readiness.sh` now runs `python -m mypy --strict linux_connector/lola_connector`, CI installs pinned `mypy==1.14.1`, and the verification matrix documents the package-only scope. |
| Full-tree Python strict typing for tests and optional tools | Fixed | `linux_connector/tools/lola_packet_decoder.py`, `linux_connector/lola_connector/selftest.py`, and `linux_connector/tests/test_codec.py` now type-check under `python -m mypy --strict linux_connector`; the full-tree gate reports no issues in 13 files. |
| Hardcoded async sleeps in LoLa control-handshake tests | Improved | `LoLaControlHandshakeValidationTests` now uses socket-ready semaphores for controlled peers and deadline-bounded send/connect retries for receiver-owned bind/listen paths instead of fixed `Task.sleep(nanoseconds: 500_000_000)` waits. |
| Hardcoded startup sleep in external connector LoLa loopback test | Fixed | `ExternalConnectorSessionTests.lolaControlLoopbackExchangesQuickConnectAck` now waits for an internal `onLoLaControlReady` signal fired after the receiver binds its control socket; the source-contract test rejects the old fixed `Task.sleep(for: .seconds(1))` startup wait. |
| Nested throwing `try #require` call sites | Fixed | `rg '#require\\(try|try #require\\(try' Tests/OpenLolaCoreTests Sources` now finds no matches; affected packet handoff, MADI transmit, realtime engine, performance audit, video transport, and UDP media tests separate throwing calls from optional unwrapping. Remaining direct `try #require(optional)` sites are plain optional unwraps, not the audited nested-throwing failure mode. |
| Hardcoded sleeps in LoLa quick-connect fallback tests | Improved | `LoLaQuickConnectFallbackTests` now uses bound-socket semaphores for test peers and deadline-bounded UDP send-until-ack helpers instead of startup sleeps; `rg 'Task\\.sleep\\(nanoseconds|usleep\\(250_000\\)' Tests/OpenLolaCoreTests/LoLaQuickConnectFallbackTests.swift` finds no matches. |
| Hardcoded sleep in LoLa TCP control loopback test | Improved | `LoLaCompatibilityTcpControlTests` now starts the receiver and retries the transmitter with a deadline until `/MESG_QUICKCONN_ACK` is observed instead of using a fixed 1-second startup sleep; `rg 'Task\\.sleep\\(nanoseconds' Tests/OpenLolaCoreTests/LoLaCompatibilityTcpControlTests.swift` finds no matches. |
| Raw nanosecond sleeps in Swift tests | Improved | Peer-session readiness gates now use `Duration` call sites and `Task.sleep(for:)`; `rg 'Task\\.sleep\\(nanoseconds|timeoutNanoseconds' Tests/OpenLolaCoreTests Sources/open-lola Sources/OpenLolaCore` finds no matches. Remaining fixed waits and subprocess readiness are still tracked separately below. |
| Direct P2P supervisor fixed responder delay | Improved | `direct-p2p-session-run` now accepts a supervisor-only `--ready-file`, manual direct-P2P socket runners write it via their existing `onReady` hook, and `direct-p2p-two-peer-local-run` waits for that readiness marker with early responder-exit detection before launching the initiator instead of blindly sleeping for `--readiness-delay-ms`; source-contract and CLI/network inventory tests pass. |
| External subprocess test fragility | Improved | `ExternalConnectorSessionRunner` now has an internal `ExternalConnectorProcessRunning` seam with the real process runner as the default public path; session-level process success, nonzero exit, early exit, auxiliary failure, and default executable readiness reports use a mock runner with nonexistent executable paths. The remaining real subprocess coverage is limited to process-group timing/termination integration. |
| `NativeAppShellSurface.swift` god file split | Fixed source-level | The deleted 707-line monolith is split into `NativeAppShellMediaDevices.swift`, `NativeAppShellMediaInventory.swift`, `NativeAppShellDirectPeerCommand.swift`, `NativeAppShellOperatorState.swift`, and `NativeAppShellSurfaceContract.swift`; source ownership and report-schema paths now point at the split files. |
| NativeAppShell test file line budget | Improved | Channel-meter and app-shell source-contract assertions moved out of `NativeAppShellTests.swift` into focused source-contract files; `NativeAppShellTests.swift` is now 576 lines, `AppShellSourceContractTests.swift` is 143 lines, and `CodeLineBudgetTests` passes. |
| PeerSessionRunner test file line budget | Improved | AV configuration, audio-payload ring, realtime preflight, and raw BGRA preview support tests moved into `PeerSessionAVSupportTests.swift`; `PeerSessionRunnerTests.swift` is now 552 lines and `CodeLineBudgetTests` passes. |
| ExternalConnectorSession test file line budget | Improved | LoLa recovered-control, media-model, wire-frame, control-message, parser, and raw-link dry-run contract tests moved into `ExternalConnectorLoLaCompatibilityTests.swift`; `ExternalConnectorSessionTests.swift` is now 405 lines and `CodeLineBudgetTests` passes. |
| LoLa packet fixture test artifact cleanup | Fixed for live writer | `LoLaCompatibilityPacketFixtureTests` now writes the synthetic capture into a UUID-scoped temporary directory and removes it with `defer`; the source-contract test rejects the old fixed `/tmp/open-lola-lola-packet-fixture-test` artifact path. Remaining `/tmp/*.json` hits in connector tests are configuration or plan strings unless a CLI command writes them. |
| `DirectPeerRealtimeAudioGraph.swift` line-budget edge | Improved | Error/config/preflight/counter DTOs moved into `DirectPeerRealtimeAudioGraphTypes.swift`; `DirectPeerRealtimeAudioGraph.swift` is now 585 lines, the new types file is 135 lines, focused realtime graph/AV tests pass, and `CodeLineBudgetTests` passes. |
| VideoTransportRunner thread QoS sleep risk | Fixed source-level | `VideoTransportRunner.run` now preconditions that the runner is not executing at user-interactive QoS before its frame pacing sleeps; `VideoTransportRunnerTests` covers the user-interactive rejection and user-initiated/default allowance. |
| `RecordingSessionArtifacts.swift` line-budget edge | Improved | `RecordingSessionArtifactValidationError` moved into `RecordingSessionArtifactValidationError.swift`; `RecordingSessionArtifacts.swift` is now 668 lines, the new validation-error file is 31 lines, focused recording-session artifact tests pass, and `CodeLineBudgetTests` passes. |
| `NetworkCommands.swift` line-budget edge | Improved | Direct-P2P mesh argument helpers moved into `DirectP2PMeshArgumentSupport.swift`; `NetworkCommands.swift` is now 611 lines, the new support file is 87 lines, focused CLI/network route tests pass, and `CodeLineBudgetTests` passes. |
| `PeerSessionRunner.swift` line-budget edge | Improved | Lifecycle/error/metrics DTOs moved into `PeerSessionRunnerTypes.swift`; `PeerSessionRunner.swift` is now 648 lines, the new types file is 49 lines, focused peer-session runner tests pass, and `CodeLineBudgetTests` passes. |
| `LoLaCompatibilityCaptureReport.swift` line-budget edge | Improved | Public capture report DTOs and validation moved into `LoLaCompatibilityCaptureReportTypes.swift`; `LoLaCompatibilityCaptureReport.swift` is now 470 lines, the new types file is 205 lines, focused LoLa capture/report schema tests pass, and `CodeLineBudgetTests` passes. |
| `DirectPeerSessionAVSocketRunner.swift` line-budget edge | Improved | AV mode/profile/error/policy/configuration types moved into `DirectPeerSessionAVRunTypes.swift`; `DirectPeerSessionAVSocketRunner.swift` is now 472 lines, the new types file is 188 lines, focused AV session tests pass, and `CodeLineBudgetTests` passes. |
| `DirectPeerSessionReport.swift` line-budget edge | Improved | Direct peer session report metrics and validation error types moved into `DirectPeerSessionReportTypes.swift`; `DirectPeerSessionReport.swift` is now 524 lines, the new types file is 132 lines, focused direct-peer report/session tests pass, and `CodeLineBudgetTests` passes. |
| `DirectPeerTwoPeerRunPlan.swift` line-budget edge | Improved | Two-peer command/reference/report/prototype DTOs and prototype report builder moved into `DirectPeerTwoPeerRunPlanReportTypes.swift`; `DirectPeerTwoPeerRunPlan.swift` is now 306 lines, the new report-types file is 290 lines, focused direct-peer two-peer/app-shell/inventory tests pass, and `CodeLineBudgetTests` passes. |

## Focused verification completed

```sh
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter UdpMediaTransportTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter VideoTransportReportTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'MultichannelTransportTests|LoLaCompatibilityMediaCodecTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter AudioLoopbackRunTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter NatFriendlyRouteTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter LoLaCompatibilityTcpControlTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter VideoCaptureReportTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter SPSCAtomicRingTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter RealtimeAudioPacketHandoffTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter UdpPcmV2PacketTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter DriftPlcReportTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'DebugTraceTests|ReportSchemaInventoryTests|CLICommandInventoryTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'AudioLoopbackRunTests|NatFriendlyRouteTests|UdpPcmRouteReportTests|OpenSourceReleaseReadinessTests|ReleaseHardeningTests|FieldReadyRuntimeProofTests|RecordingSessionArtifactTests|FasterThanLoLaClosureTests|ExternalConnectorSessionTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter NativeAppShellTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter AppLatencyHeroMetricsSourceTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter AppLocalOperatorSurfaceSourceTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter SourceNamingConventionTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter LoLaCompatibilityMediaCodecTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter RealtimeAudioEngineTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter VideoTransportReportTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter AVTimestampAlignmentTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter UdpPcmPacketTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter OscCueReportTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter UdpPcmRouteReportTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter DirectPeerRealtimeAudioGraphTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter RealtimeAudioPacketHandoffTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter BlackmagicReceiveRenderTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CodeLineBudgetTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'CLICommandInventoryTests|UdpPcmRouteReportTests|ReleaseArtifactHygieneContractTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'ExternalConnectorSessionTests|LoLaCompatibilityMediaCodecTests|LoLaCompatibilityMediaEnvelopeValidationTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter LoLaControlHandshakeValidationTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'RealtimeAudioPacketHandoffTests|PerformanceAuditTests|MadiTransmitTests|RealtimeAudioEngineTests|VideoTransportReportTests|UdpMediaTransportTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter LoLaQuickConnectFallbackTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter LoLaCompatibilityTcpControlTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter ExternalConnectorSessionTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'PeerSessionRunnerTests|PeerSessionAVFastestTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter ExternalConnectorProcessGroupTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'ExternalConnectorSessionTests|ExternalConnectorNmpEndpointRunTests|ExternalConnectorNmpWorkflowTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'NativeAppShellTests|NativeAppShellArtifactTests|SourceOwnershipInventoryTests|ReportSchemaInventoryTests|CodeLineBudgetTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CLICommandInventoryTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter NativeAppShellTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'NativeAppShellTests|AppChannelMeterSourceTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'nativeAppShell|openLolaAppUsesCoreSurfaceContract|buildAndRunScript' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CodeLineBudgetTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'PeerSessionRunnerTests|PeerSessionAVSupportTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CodeLineBudgetTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'ExternalConnectorSessionTests|ExternalConnectorLoLaCompatibilityTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CodeLineBudgetTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'ExternalConnectorSessionTests|ExternalConnectorProcessGroupTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter LoLaCompatibilityPacketFixtureTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'DirectPeerRealtimeAudioGraphTests|PeerSessionAVSupportTests|PeerSessionAVFastestTests|DirectPeerSessionProductionAVRegressionTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'SourceOwnershipInventoryTests|RealtimeAudioPathInventoryTests|ReportSchemaInventoryTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter VideoTransportRunnerTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter RecordingSessionArtifactTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'CLICommandInventoryTests|NetworkRouteCommandMatrixTests|DirectPeerSessionCLITests|DirectPeerTwoPeerRunPlanTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'PeerSessionRunnerTests|PeerSessionAVSupportTests|DirectPeerSessionAVRXBufferProfileTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'LoLaCompatibilityCaptureReportTests|LoLaCompatibilityPacketFixtureTests|ReportSchemaInventoryTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'DirectPeerSessionAVRXBufferProfileTests|PeerSessionAVFastestTests|PeerSessionAVSupportTests|DirectPeerSessionProductionAVRegressionTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'DirectPeerSessionReportAVPassTests|DirectPeerSessionProductionAVRegressionTests|DirectPeerTwoPeerRunPlanTests|PeerSessionRunnerTests|PeerSessionAVFastestTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'DirectPeerTwoPeerRunPlanTests|NativeAppShellArtifactTests|CLICommandInventoryTests|NetworkRouteCommandMatrixTests|CodeLineBudgetTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'AudioLoopbackRunTests|NatFriendlyRouteTests|UdpPcmRouteReportTests|ReleaseHardeningTests|OpenSourceReleaseReadinessTests|FieldReadyRuntimeProofTests|RecordingSessionArtifactTests|FasterThanLoLaClosureTests|PackagingFieldTestTests|ExternalConnectorSessionTests|ExternalConnectorConnectionPlanTests|ExternalConnectorNmpWorkflowTests|CodeLineBudgetTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'VideoTransportReportTests|BlackmagicReceiveRenderTests|BlackmagicCaptureTransmitTests|UdpMediaTransportTests|VideoTransportRunnerTests|DirectPeerSessionProductionAVRegressionTests|CodeLineBudgetTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'DirectPeerSessionCLITests|DirectPeerTwoPeerRunPlanTests|CLICommandInventoryTests|NetworkRouteCommandMatrixTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'ReportSchemaInventoryTests|CLICommandInventoryTests|GoalRuntimePreflightTests|OpenSourceReleaseReadinessTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'RealtimeAudioPacketHandoffTests|DirectPeerRealtimeAudioGraphTests|MadiTransmitTests|PeerSessionAVSupportTests|DirectPeerSessionProductionAVRegressionTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'UdpPcmV2PacketTests|MultichannelTransportTests|MadiReceiveTests|DirectPeerSessionAVRXBufferProfileTests|CodeLineBudgetTests|RealtimeAudioPathInventoryTests|SourceOwnershipInventoryTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'ValidationPrimitivesTests|RxBufferBenchmarkTests|ExternalConnectorSessionTests|ExternalConnectorProcessGroupTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'ExternalConnectorSessionTests|ExternalConnectorProcessGroupTests|ExternalConnectorNmpEndpointRunTests|ExternalConnectorNmpWorkflowTests|VerificationToolingContractTests|CodeLineBudgetTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'ValidationPrimitivesTests|RxBufferBenchmarkTests|ReportSchemaInventoryTests|CLICommandInventoryTests|CodeLineBudgetTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'ValidationPrimitivesTests|LatencyTuningReportTests|PerformanceAuditTests|ReferenceRigReportTests|RecordingSessionArtifactTests|PackagingFieldTestTests|ReportSchemaInventoryTests|CodeLineBudgetTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'ReportSchemaInventoryTests|GoalRuntimePreflightTests|GoalRuntimeEvidenceTemplateTests|GoalCompletionAuditTests|GoalCodewiseClosureTests|DirectPeerTwoPeerRunPlanTests|CLICommandInventoryTests|CodeLineBudgetTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'ValidationPrimitivesTests|MeasurementReportFixtureTests|GoalCompletionAuditTests|GoalRuntimeEvidenceTemplateTests|GoalRuntimePreflightTests|GoalCodewiseClosureTests|HardwareValidationReportTests|ReleaseHardeningTests|OpenSourceReleaseReadinessTests|FieldReadyRuntimeProofTests|LoLaParityDeferredFeaturesTests|FasterThanLoLaClosureTests|ReportSchemaInventoryTests|CodeLineBudgetTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'DirectPeerSessionReportAVPassTests|PeerSessionAVFastestTests|PeerSessionAVSupportTests|DirectPeerSessionProductionAVRegressionTests|DirectPeerTwoPeerRunPlanTests|ReportSchemaInventoryTests|CodeLineBudgetTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'VideoTransportReportTests|BlackmagicReceiveRenderTests|UdpMediaTransportTests|ReportSchemaInventoryTests|CodeLineBudgetTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'AppLocalOperatorSurfaceSourceTests|NativeAppShellTests|AppShellSourceContractTests|CodeLineBudgetTests' --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter 'CapabilitySummaryTests|SessionProtocolTests|UdpPcmPacketTests|CoreAudioInventoryTests|CodeLineBudgetTests' --no-parallel
python -m mypy --strict linux_connector/lola_connector
python -m mypy --strict linux_connector
python -m pytest linux_connector/tests
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter VerificationToolingContractTests --no-parallel
```

All focused verification commands listed above passed.

## Full verification completed

```sh
swift test --build-path /private/tmp/open-lola2-swiftpm-build --no-parallel
/private/tmp/open-lola2-swiftpm-build/debug/open-lola session-capabilities
bash scripts/verify-docs.sh
shellcheck scripts/*.sh scripts/lib/*.sh
python -m mypy --strict linux_connector/lola_connector
python -m mypy --strict linux_connector
python -m pytest linux_connector/tests
bash scripts/verify-release-readiness.sh
```

Latest full Swift test result: 1144 tests passed in 99.784 seconds after the
final audit-remediation slice. The run covered the concurrent
`VideoFrameReassembler` locking contract, app inventory refresh controller
boundary, M00/M02/M04 behavioral assertions, AV receive coordination,
validation helper migration, UI/source-contract cleanup, socket/runtime fixes,
line-budget checks, and the existing release/evidence validation matrix.

CLI surface probe result: `session-capabilities` emitted JSON and ended with
`VERDICT: PASS`.

Docs/script/Python result: documentation contract passed again after the latest
ledger update; shellcheck reported no findings in the earlier full matrix;
strict mypy found no issues in 9 production connector files or in the 13-file
full `linux_connector` tree; pytest reported 23 passed and 2 skipped Linux
connector tests. The sandboxed
release-readiness run reached the new mypy gate and then failed at SwiftPM
manifest `sandbox_apply`; the escalated run completed `swift build`,
`swift test --no-parallel`, all CLI probes, and ended with `VERDICT: PASS`.

## Evidence-proven stale or already mitigated

| Audit item | Status | Evidence |
|---|---|---|
| Tier 2 #17 P2P handshake has no timeout | Stale against current source | `DirectPeerSessionControlSocket` uses nonblocking sockets, `receiveTimeoutNanoseconds`, and deadline-based receive loops; no duplicate timeout layer added. |
| Tier 1 #5 teardown races media threads | Stale against current source | Current `PeerSessionRunner` owns no detached media task list; AV socket runs are synchronous loops with `defer` cleanup for graph/video/preview plus top-level `runner.shutdown`. |
| Measurement methodology one-line alias | Stale against current source | `MeasurementMethodology` is now a concrete enum; run modes are covered by `MeasurementMethodologyTests`. |
| DebugTrace duplicate JSONEncoder setup | Stale against current source | `DebugTrace` now routes event and fallback-line encoding through the single private `DebugTraceJSONEncoder.encode(_:)` helper. |
| Package.swift repeated linker flag sets | Stale against current source | Both executable targets call `executableInfoPlistLinkerSettings(_:)` instead of repeating the unsafe linker flag array inline. |
| Bash helper duplication in release scripts | Stale/mitigated | `scripts/verify-release-readiness.sh` sources `scripts/lib/common.sh`; `verify-docs.sh` does not define duplicate `require_*` helpers. |
| Large validation files mixing error definitions with orchestration | Stale against current source | `LatencyTuningValidationError`, `PerformanceAuditValidationError`, and `IntegratedAvValidationError` live in their report DTO files, while the corresponding validation logic remains in dedicated `*Validation.swift` files. |
| UDP PCM error assertions ignore associated values | Stale against current tests | `expectPacketError` and `expectV2PacketError` compare the full `Equatable` error value, including associated payloads. |
| App storage integer bounds missing | Stale/mitigated | `AppShellSettingsView.positiveIntBinding` clamps positive integers and `uint16Binding` uses `UInt16(clamping:)`. |
| `receiveMessages(count:)` may return fewer messages | Stale against current source | `DirectPeerSessionControlSocket.receiveMessages(count:label:)` performs exactly `count` single-message receives and throws on the first missing message. |
| Lighting gate blocking on I/O | Stale against current source | `LightingGatePolicy.decision(for:)` is pure policy evaluation over value types; no DMX/OSC/network I/O occurs in the gate decision path. |
| `AppVideoPreviewController` main-actor capture setup | Stale/mitigated | Current `AppVideoPreviewController` is main-actor isolated for state but starts authorized capture setup on its stored `DispatchQueue` and returns to the main actor only to publish session/status changes. |
| App preview AVFoundation queue cleanup | Stale/mitigated | `AppVideoPreviewController` stores its preview queue as an instance property, disconnects the preview layer in `stop()`, and stops the current session on that queue; there is no inline throwaway preview queue left in the app preview path. |
| Preview structs broken by `@State` initialization | Stale against current source | `rg '#Preview|PreviewProvider' Sources/open-lola-app -g '*.swift'` finds no SwiftUI preview blocks in the current app source, so there are no broken preview-only `@State`/`@Binding` initializers to fix. |

## Completion audit

The two previously open human choices are resolved as option A for both. A fresh
heading-to-ledger coverage check over `AUDIT-FRESH.md` reports
`lowmatch_count=0`, meaning every concrete `###` audit finding has a matching
completed, stale, or mitigated row in this remediation ledger. Remaining
`require*` hits in the scoped release/evidence scan are run-configuration
parsers, semantic validators, or the two custom double validators that preserve
older non-finite behavior for error enums without a `nonFiniteField` case; they
are outside the audited primitive-wrapper duplication scope. The
`ReportValidatorSurface.swift` empty conformance extension issue is fixed in
current source, and the enforced source/test line-budget gate is clean.

Fresh completion-audit evidence:
`rg 'makeConnectorSleepExecutable|makeConnectorChildSpawningExecutable|#!/bin/sh|Thread\.sleep\(forTimeInterval: 0\.05\)|Task\.sleep\(for: \.milliseconds\(1\)'
Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift
Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift` finds no matches;
`rg 'Thread\.sleep'
Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift
Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift`
finds no matches; and
`rg 'extension .*: ReportValidatingArtifact|func require[A-Z]|private func
require[A-Z]|func required[A-Z]|private func required[A-Z]' Sources/OpenLolaCore
Sources/open-lola` still finds parser and semantic helper sites outside the
primitive-wrapper scope. A narrower release/evidence scan now reports 15
`require*`/`required*` hits; only `MeasurementReportValidator.requireNonNegative`
and `ReferenceRigValidator.requirePositive` still call `ValidationPrimitives`
directly, intentionally preserving the older double behavior for error enums
that do not yet expose `nonFiniteField`.

Fresh report-validator-surface evidence:
`rg 'extension .*: ReportValidatingArtifact|extension .*: ReportMetadataArtifact'
Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift Sources/OpenLolaCore`
finds no matches, and 59 report declarations now carry `ReportValidatingArtifact`
or `ReportMetadataArtifact` directly.
