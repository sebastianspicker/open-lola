# Deprecation and Simplification Remediation Status

Source of truth: `docs/deprecation-and-simplification-audit.md`

Overall state: COMPLETE

Current/last slice: Final verification

Counts by status:

| Status | Count |
|---|---:|
| NOT_STARTED | 0 |
| IN_PROGRESS | 0 |
| BLOCKED | 0 |
| DEFERRED | 3 |
| IMPLEMENTED | 0 |
| VERIFIED | 0 |
| COMPLETE | 23 |

Highest remaining priority: None

Last commands/result:

- `sed -n '1,260p' docs/deprecation-and-simplification-audit.md` - read source audit findings DA-001 through DA-006.
- `sed -n '260,560p' docs/deprecation-and-simplification-audit.md` - read source audit findings DA-007 through DA-013 and summary.
- `ls docs/das-ledger.md docs/das-status.md` - both files were absent before this remediation run.
- `grep -r '"audioDeviceUID"' Tests/OpenLolaCoreTests/Fixtures private` - no saved fixture/private JSON uses the legacy key.
- `swift test --filter directPeerRealtimeAudioGraphConfigurationRequiresSplitDeviceUIDsWhenDecoding` - PASS, 1 Swift Testing test executed.
- `rg -n "syntheticG16\|LoLaParityDeferredSyntheticSmoke\|LoLaParityDeferredFixtures\|deprecated" Sources Tests --glob '*.swift'` - no deprecated synthetic G16 parity function or caller remains.
- `swift test --filter LoLaParityDeferredFeatures` - PASS, 2 Swift Testing tests executed.
- `rg -n "JSONReportCoder" Sources Tests --glob '*.swift'` - only `OpenLolaContracts` implementation and direct-import test references remain.
- `swift test --filter ReportSchemaInventory` - PASS, 6 Swift Testing tests executed.
- `swift test --filter OpenLolaContractsTarget` - PASS, 2 Swift Testing tests executed.
- `rg -n "LoLaParityLedgerRunMode\|MeasurementMethodology" Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift Tests/OpenLolaCoreTests/MeasurementMethodologyTests.swift --glob '*.swift'` - no `LoLaParityLedgerRunMode` references remain.
- `swift test --filter releaseAndEvidenceRunModesShareMeasurementMethodology` - PASS, 1 Swift Testing test executed.
- `rg -n "requireRx(NonEmpty\|Positive\|NonNegative)\|RxBufferPolicyValidator\|ReportValidationProtocol\|ValidationNon" Sources/OpenLolaCore/Timing/RxBuffering.swift Sources/OpenLolaCore/Timing/RxImpairmentSimulator.swift Tests/OpenLolaCoreTests/RxBufferingTests.swift --glob '*.swift'` - old RxBuffering helper names are absent and shared protocol adoption is present.
- `swift test --filter RxBuffer` - PASS, 12 Swift Testing tests executed.
- `rg -n "requireM05\|MadiFullDuplexValidator\|ReportValidationProtocol" Sources/OpenLolaCore/Audio/MADI --glob '*.swift'` - old M05 helper names are absent and shared protocol adoption is present.
- `swift test --filter MadiFullDuplex` - PASS, 4 Swift Testing tests executed.
- `rg -n "requireMadiReceive\|MadiReceiveValidator\|ReportValidationProtocol\|nonFiniteField" Sources/OpenLolaCore/Audio/MADI/MadiReceiveReport.swift Sources/OpenLolaCore/Audio/MADI/MadiReceiveTypes.swift --glob '*.swift'` - old MADI receive helper names are absent and shared protocol adoption is present.
- `swift test --filter MadiReceive` - PASS, 7 Swift Testing tests executed.
- `rg -n "requireMadiTransmit\|MadiTransmitValidator\|ReportValidationProtocol\|nonFiniteField" Sources/OpenLolaCore/Audio/MADI/MadiTransmit.swift --glob '*.swift'` - old MADI transmit helper names are absent and shared protocol adoption is present.
- `swift test --filter MadiTransmit` - PASS, 3 Swift Testing tests executed.
- `rg -n "requireRealtime\|RealtimeAudioEngineValidator\|ReportValidationProtocol" Sources/OpenLolaCore/Audio/Realtime --glob '*.swift'` - old realtime helper names are absent and shared protocol adoption is present.
- `swift test --filter RealtimeAudioEngine` - PASS, 4 Swift Testing tests executed.
- `rg -n "requireDrift(NonEmpty\|Positive\|NonNegative\|Finite)\|DriftPlcValidator\|ReportValidationProtocol" Sources/OpenLolaCore/Timing/DriftPlcHelpers.swift Sources/OpenLolaCore/Timing/DriftPlcReport.swift --glob '*.swift'` - old drift helper names are absent and shared protocol adoption is present.
- `swift test --filter DriftPlc` - PASS, 6 Swift Testing tests executed.
- `rg -n "requireDriftCertification\|requireLolaBaseline\|DriftPlcFixedTargetCertificationValidator\|LolaBaselineComparisonValidator\|ReportValidationProtocol" Sources/OpenLolaCore/Timing/DriftPlcFixedTargetCertification.swift --glob '*.swift'` - old certification and LoLa baseline helper names are absent and shared protocol adoption is present.
- `swift test --filter DriftPlcFixedTargetCertification` - PASS, 2 Swift Testing tests executed.
- `rg -n "requireE2E\|E2EBenchmarkValidator\|requirePercent\|ValidationPercentOutOfRangeFieldError" Sources/OpenLolaCore/Core/ValidationPrimitives.swift Sources/OpenLolaCore/Benchmarks/E2E --glob '*.swift'` - old E2E helper names are absent; shared validator and shared finite-percent primitive are present.
- `swift test --filter E2EBenchmark` - PASS, 5 Swift Testing tests executed.
- `rg -n "requireLatency\|LatencyBenchmarkValidator\|ValidationPercentOutOfRangeFieldError" Sources/OpenLolaCore/Benchmarks/Latency Sources/OpenLolaCore/Core/ValidationPrimitives.swift --glob '*.swift'` - old Latency helper names are absent; shared validator and percent-range error conformance are present.
- `swift test --filter LatencyBenchmark` - PASS, 6 Swift Testing tests executed.
- `rg -n "requireRxBenchmark\|RxBufferBenchmarkValidator\|ValidationPercentOutOfRangeFieldError" Sources/OpenLolaCore/Timing/RxBufferBenchmarkReport.swift Tests/OpenLolaCoreTests/ValidationPrimitivesTests.swift --glob '*.swift'` - old RxBuffer benchmark helper names are absent; existing validator now adopts the shared validation protocol and percent-range error conformance.
- `swift test --filter RxBuffer` - PASS, 12 Swift Testing tests executed.
- `rg -n "requireProfileMetric\|SessionProfileBenchmarkValidator\|ReportValidationProtocol" Sources/OpenLolaCore/Timing/SessionProfileBenchmark.swift --glob '*.swift'` - old profile metric helper names are absent; file-local validator preserves the LatencyBenchmark validation error domain.
- `swift test --filter LatencyBenchmark` - PASS, 6 Swift Testing tests executed.
- `rg -n "requireVideoCapture\|VideoCaptureValidator\|requireOptionalNonEmpty\|FixedWidthInteger" Sources/OpenLolaCore/Core/ValidationPrimitives.swift Sources/OpenLolaCore/Video Tests/OpenLolaCoreTests --glob '*.swift'` - primitive `requireVideoCapture*` wrappers are absent except the domain-specific packet-age helper; shared optional non-empty and unsigned-positive validator methods are present.
- `swift test --filter VideoCapture` - PASS, 7 Swift Testing tests executed.
- `rg -n "requireTransport(NonEmpty\|Positive\|NonNegative\|Finite)\|VideoTransportValidator" Sources/OpenLolaCore --glob '*.swift'` - old transport primitive helper names are absent; shared validator call sites cover video transport, multi-video, and AV-sync validation.
- `swift test --filter VideoTransport` - PASS, 20 Swift Testing tests executed.
- `rg -n "requireRunNonEmpty\|AudioLoopbackRunValidator\|ValidationEmptyFieldError" Sources/OpenLolaCore/Audio/Routing Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift --glob '*.swift'` - old audio loopback report non-empty helper is absent; shared validator is present.
- `swift test --filter AudioLoopback` - PASS, 5 Swift Testing tests executed.
- `sed -n '1,220p' Sources/OpenLolaCore/Video/MediaGeometrySizing.swift` - inspected local sizing contract and value-carrying error.
- `rg -n "MediaGeometrySizing\|invalidPositiveField\|requirePositive" Sources/OpenLolaCore/Video/MediaGeometrySizing.swift Tests/OpenLolaCoreTests --glob '*.swift'` - confirmed `invalidPositiveField(field, value)` is the local public error shape; deferred migration to avoid losing the rejected value.
- `wc -l Sources/open-lola/Commands/MilestoneCommands.swift Sources/open-lola/Commands/Network/NetworkCommands.swift` - confirmed `MilestoneCommands.swift` is 610 lines and below the cited 720-line budget.
- `rg -n "MilestoneCommands\|handleMilestoneCommand\|NetworkCommands\|handleNetworkCommand\|direct-p2p\|video-transport" Tests Sources/open-lola --glob '*.swift'` - found CLI coverage around individual commands but no dedicated milestone dispatcher parity suite.
- `sed -n '1,80p' Sources/open-lola/Commands/MilestoneCommands.swift` - inspected load-bearing switch entry point and validation-command pre-dispatch.
- `rg -n "Promotion requires\|direct-p2p-two-peer-prototype\|DirectPeerTwoPeerPrototypeReport" Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlanReportTypes.swift Tests/OpenLolaCoreTests/SourceNamingConventionTests.swift --glob '*.swift'` - confirmed promotion criteria comment and active public schema/command references.
- `swift test --filter SourceNamingConvention` - PASS, 1 Swift Testing test executed.
- `swift test --filter DirectPeerTwoPeerPrototypeReport` - PASS, 7 Swift Testing tests executed.
- `rg -n "Staged multi-stream\|dodMultiVideoSupportedOrStaged\|VideoTransportMultiStreamRuntime\|multi-video" Sources/OpenLolaCore/Video/VideoTransportMultiStreamRuntime.swift Sources/OpenLolaCore/Release/Goal/GoalCodewiseClosure.swift Tests/OpenLolaCoreTests/VideoTransportRunnerTests.swift --glob '*.swift'` - confirmed staged runtime comment and goal-closure staged requirement.
- `swift test --filter VideoTransportRunner` - PASS, 6 Swift Testing tests executed.
- `swift test --filter GoalCodewiseClosure` - PASS, 7 Swift Testing tests executed.
- `rg -n -C 3 "AudioObject(Get\|Set)PropertyData" Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift Sources/OpenLolaCore/Audio/Routing/AudioLoopbackHelpers.swift Sources/open-lola-app/AppReceiverPreviewServices.swift` - inspected each listed HAL call site.
- `rg -n "throwAudioMeterStatusIfNeeded\|coreAudioStatus\|noErr\|guard AudioObject\|let status = AudioObject" Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift Sources/OpenLolaCore/Audio/Routing/AudioLoopbackHelpers.swift Sources/open-lola-app/AppReceiverPreviewServices.swift` - confirmed each listed HAL call checks status through `noErr` guards or local throwing helpers.
- `swift test --filter CoreAudioInventory` - PASS, 4 Swift Testing tests executed.
- `swift test --filter AppShellSlice05` - PASS, 13 Swift Testing tests executed.
- `sed -n '1,260p' Sources/OpenLolaCore/Connectors/JackTrip/JackTripLaunchPlan.swift` - inspected JackTrip topology, argument, facts, references, and evidence-boundary assembly.
- `sed -n '1,280p' Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridLaunchPlan.swift` - inspected UltraGrid topology, argument, facts, references, and evidence-boundary assembly.
- `rg -n "ExternalConnectorLaunchPlan\|LaunchPlan\|build.*Plan\|protocolFacts\|validate.*Topology" Sources/OpenLolaCore/Connectors Tests/OpenLolaCoreTests --glob '*.swift'` - confirmed LoLa is a third launch-plan builder and shared plan-field validation is exercised through connector session reports.
- `swift test --filter ExternalConnectorSession` - PASS, 7 Swift Testing tests executed.
- `swift test --filter ExternalConnectorAvMatrix` - PASS, 4 Swift Testing tests executed.
- `swift test --filter JackTripTopology` - PASS, 4 Swift Testing tests executed.
- `sed -n '1,90p' Sources/open-lola/Commands/Network/NetworkCommands.swift` - inspected load-bearing network command switch entry point; deferred structural split for lack of a full dispatcher parity gate.
- `rg -n "Single production conformer\|ExternalConnectorProcessRunning\|MockExternalConnectorProcessRunner" Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift --glob '*.swift'` - confirmed protocol intent comment and mock runner coverage.
- `swift test --filter ExternalConnectorProcessGroup` - PASS, 7 Swift Testing tests executed.
- `git status --short` - inspected full dirty tree before final closeout; worktree contains DAS remediation changes plus pre-existing unrelated local changes.
- `git diff --stat` - inspected full dirty diff; DAS remediation is mixed with broader pre-existing local worktree changes, so final review treated unrelated files as out of scope and did not revert them.
- `git diff --check` - PASS, no whitespace errors reported.
- `bash scripts/verify-docs.sh` - PASS, documentation verification passed.
- `swift build` - initial sandboxed attempt failed with SwiftPM manifest sandboxing (`sandbox_apply: Operation not permitted`); rerun outside the sandbox PASS, debug build complete.
- `swift test --no-parallel` - PASS, 732 Swift Testing tests executed by the full suite.
- `bash scripts/verify-release-hygiene.sh` - initial run failed on untracked generated `.DS_Store` residue; removed four untracked `.DS_Store` files and reran PASS with `HYGIENE_VERDICT: PASS`.

Uncertainty:

- Final verification ran against the current dirty worktree, which includes unrelated pre-existing local changes. The DAS ledger records the intended remediation scope; unrelated dirty files were not reverted.
- MediaGeometrySizing retains a local positive helper because the shared validator protocol cannot preserve `invalidPositiveField(field, value)` without a new one-off abstraction.
- DA-006 and DA-007 are public CLI dispatcher refactors deferred until full command parity coverage exists.
- Hardware/manual field runtime smoke was not run; DAS remediation was verified with source inspection, focused tests, full Swift tests, docs verification, build, and release hygiene.

Next slice: None - DAS remediation complete.
