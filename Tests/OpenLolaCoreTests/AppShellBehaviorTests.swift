import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func openLolaAppSupportInitializesTheSwiftUIAppSurface() {
    _ = OpenLolaApp()
}

@Test
func appSessionStateDoesNotReportLiveWithoutValidatedRuntimeEvidence() {
    let noEvidenceState = AppSessionState.derive(
        isRunning: false,
        isArmed: false,
        lastExitCode: 0,
        isConfigured: true,
        commandIntent: .idle,
        phase: .runFinished,
        hasValidatedRuntimeEvidence: false
    )
    let evidenceState = AppSessionState.derive(
        isRunning: false,
        isArmed: false,
        lastExitCode: 0,
        isConfigured: true,
        commandIntent: .idle,
        phase: .runFinished,
        hasValidatedRuntimeEvidence: true
    )
    let handoffState = AppSessionState.derive(
        isRunning: false,
        isArmed: false,
        lastExitCode: nil,
        isConfigured: false,
        commandIntent: .handoffRequested,
        phase: .idle,
        hasValidatedRuntimeEvidence: false
    )

    #expect(noEvidenceState == .awaitingEvidence)
    #expect(evidenceState == .live)
    #expect(handoffState == .unconfigured)
}

@MainActor
@Test
func appRuntimeEvidenceScopeRequiresCurrentValidatedRuntimeEvidence() {
    let metrics = AppLatencyHeroMetrics.make(from: [
        appDirectPeerSessionReport(
            id: "peer-a-report",
            packetsReceived: 90,
            packetsLost: 0,
            jitterMicroseconds: 2_500,
            latencyMicroseconds: 1_200
        ),
    ])

    #expect(AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
        executionKind: .directMacPeer,
        validationExitCode: 0,
        directPeerLatencyMetrics: metrics,
        externalConnectorReport: nil
    ))
    #expect(!AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
        executionKind: .directMacPeer,
        validationExitCode: nil,
        directPeerLatencyMetrics: metrics,
        externalConnectorReport: nil
    ))
    #expect(!AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
        executionKind: .windowsLoLa,
        validationExitCode: 0,
        directPeerLatencyMetrics: metrics,
        externalConnectorReport: nil
    ))
    #expect(AppRuntimeEvidenceScope.allowsDirectPeerCaptureEvidence(executionKind: .directMacPeer))
    #expect(!AppRuntimeEvidenceScope.allowsDirectPeerCaptureEvidence(executionKind: .windowsLoLa))
}

@MainActor
@Test
func appConsoleStatusSnapshotUsesControllerAndPlanState() {
    let controller = AppExecutionController()
    let unconfiguredPlan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: false))
    let configuredPlan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: true))

    let unconfigured = AppConsoleStatusSnapshot.make(
        report: NativeAppShellSyntheticSmoke.placeholder(),
        plan: unconfiguredPlan,
        executionController: controller,
        captureReport: nil
    )
    controller.lastValidationExitCode = 0
    let configured = AppConsoleStatusSnapshot.make(
        report: NativeAppShellSyntheticSmoke.run(),
        plan: configuredPlan,
        executionController: controller,
        captureReport: nil
    )

    #expect(unconfigured.validationTitle == "Plan incomplete")
    #expect(unconfigured.packetTitle == "Packet monitor unavailable")
    #expect(unconfigured.remoteStreamTitle == "Remote unavailable")
    #expect(configured.validationTitle == "Validation failed")
    #expect(configured.remoteStreamTitle == "Remote plan only")
}

@Test
func appRemoteInventoryImportTrimsSelectionAndRebuildsDerivedDevicesAtomically() {
    var state = appOperatorState(remoteSelectionComplete: false)

    state.importRemoteInventorySelection(keyPath: \.audioInputUID, value: " remote-rme ")
    state.importRemoteInventorySelection(keyPath: \.audioOutputUID, value: "remote-rme")
    state.importRemoteInventorySelection(keyPath: \.videoDeviceID, value: " remote-atem ")

    #expect(state.remoteInventory.selection.audioInputUID == "remote-rme")
    #expect(state.remoteInventory.selection.audioOutputUID == "remote-rme")
    #expect(state.remoteInventory.selection.videoDeviceID == "remote-atem")
    #expect(state.remoteInventory.audioDevices.count == 1)
    #expect(state.remoteInventory.audioDevices[0].name == "Remote duplex")
    #expect(state.remoteInventory.audioDevices[0].inputChannelCount == state.directPeerCommandFields.channelCount)
    #expect(state.remoteInventory.audioDevices[0].outputChannelCount == state.directPeerCommandFields.channelCount)
    #expect(state.remoteInventory.videoDevices.map(\.uniqueId) == ["remote-atem"])

    state.importRemoteInventorySelection(keyPath: \.audioInputUID, value: "   ")

    #expect(state.remoteInventory.selection.audioInputUID == nil)
    #expect(state.remoteInventory.audioDevices.count == 1)
    #expect(state.remoteInventory.audioDevices[0].name == "Remote output")
}

@Test
func appLatencyHeroMetricsLoadsSupervisorSessionReports() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-latency-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let reportAURL = directory.appendingPathComponent("peer-a.json")
    let reportBURL = directory.appendingPathComponent("peer-b.json")
    let supervisorURL = directory.appendingPathComponent("supervisor.json")
    try appDirectPeerSessionReport(
        id: "peer-a-report",
        packetsReceived: 90,
        packetsLost: 10,
        jitterMicroseconds: 2_500,
        latencyMicroseconds: 1_200
    ).prettyJSONData().write(to: reportAURL)
    try appDirectPeerSessionReport(
        id: "peer-b-report",
        packetsReceived: 50,
        packetsLost: 0,
        jitterMicroseconds: 5_000,
        latencyMicroseconds: 2_400
    ).prettyJSONData().write(to: reportBURL)
    let supervisor = DirectPeerTwoPeerLocalRunReport(
        id: "supervisor",
        capturedAt: "2026-05-14T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: [
            appProcessResult(peerID: "peer-a", reportPath: reportAURL.path),
            appProcessResult(peerID: "peer-b", reportPath: reportBURL.path),
        ],
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        preflightChecks: [
            DirectPeerTwoPeerPreflightCheck(id: "unit", severity: .pass, passed: true, message: "ok"),
        ],
        evidenceGates: ["unit"],
        verdict: .partial,
        notes: "unit test supervisor report"
    )
    try supervisor.prettyJSONData().write(to: supervisorURL)

    let metrics = try #require(AppLatencyHeroMetrics.load(fromSupervisorReportPath: supervisorURL.path))

    #expect(metrics.audioLatencyMs == 2.4)
    #expect(metrics.jitterMs == 5.0)
    #expect(abs((metrics.packetLossPercent ?? -1) - 6.6667) < 0.001)
    #expect(metrics.expectedPeerReportCount == 2)
    #expect(metrics.loadedPeerReportCount == 2)
    #expect(!metrics.isPartial)
    #expect(metrics.evidenceStatusMessage == nil)
    #expect(AppLatencyHeroMetrics.make(from: []) == nil)
}

@Test
func appLatencyHeroMetricsReportsPartialPeerEvidence() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-latency-partial-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let reportAURL = directory.appendingPathComponent("peer-a.json")
    let missingReportURL = directory.appendingPathComponent("peer-b.json")
    let supervisorURL = directory.appendingPathComponent("supervisor.json")
    try appDirectPeerSessionReport(
        id: "peer-a-report",
        packetsReceived: 90,
        packetsLost: 10,
        jitterMicroseconds: 2_500,
        latencyMicroseconds: 1_200
    ).prettyJSONData().write(to: reportAURL)
    let supervisor = DirectPeerTwoPeerLocalRunReport(
        id: "supervisor",
        capturedAt: "2026-05-14T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: [
            appProcessResult(peerID: "peer-a", reportPath: reportAURL.path),
            appProcessResult(peerID: "peer-b", reportPath: missingReportURL.path),
        ],
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        preflightChecks: [
            DirectPeerTwoPeerPreflightCheck(id: "unit", severity: .pass, passed: true, message: "ok"),
        ],
        evidenceGates: ["unit"],
        verdict: .partial,
        notes: "unit test supervisor report"
    )
    try supervisor.prettyJSONData().write(to: supervisorURL)

    let metrics = try #require(AppLatencyHeroMetrics.load(fromSupervisorReportPath: supervisorURL.path))

    #expect(metrics.audioLatencyMs == 1.2)
    #expect(metrics.expectedPeerReportCount == 2)
    #expect(metrics.loadedPeerReportCount == 1)
    #expect(metrics.isPartial)
    #expect(metrics.loadFailures.count == 1)
    #expect(metrics.evidenceStatusMessage?.contains("1/2 peer reports loaded") == true)
    #expect(metrics.evidenceStatusMessage?.contains("peer-b") == true)
}

@Test
func appChannelMeterSnapshotAndPeakStateAreDeterministic() {
    #expect(ChannelMeterLevelSnapshot(levels: [0.1, 0.2, 0.3], visibleChannels: 2).values == [0.1, 0.2])
    #expect(ChannelMeterLevelSnapshot(levels: [0.1, 0.2], visibleChannels: -1).values == [])

    let peakState = PeakHoldState(capacity: 64)
    #expect(peakState.holds.count == 64)
    #expect(peakState.timers.count == 64)
    #expect(peakState.holds.allSatisfy { $0 == 0 })
    #expect(peakState.timers.allSatisfy { $0 == 0 })
}

@Test
func appCommandPreviewKeepsLongCommandsReadableAndCopyable() {
    let command = [
        "/tmp/OpenLoLa.app/Contents/MacOS/open-lola",
        "direct-p2p-two-peer-local-run",
        "--plan",
        "/tmp/open-lola/very-long-supervisor-plan-name.json",
        "--execution-mode",
        "local",
    ]

    #expect(AppCommandPreview.shellLine(command).contains("direct-p2p-two-peer-local-run --plan"))
    #expect(AppCommandPreview.multilineDisplay(command).contains(" \\\n  --plan"))
    #expect(AppCommandPreview.multilineDisplay(command).contains("/tmp/open-lola/very-long-supervisor-plan-name.json"))
}

@Test
func appCommandPreviewShellEscapesCopiedAndDisplayedArguments() {
    let command = [
        "/Applications/Open LoLa/open-lola",
        "direct-p2p-session-run",
        "--output",
        "/Users/test/Application Support/OpenLoLa/report's.json",
        "",
    ]
    let oneLine = AppCommandPreview.shellLine(command)
    let multiline = AppCommandPreview.multilineDisplay(command)

    #expect(oneLine.contains("'/Applications/Open LoLa/open-lola'"))
    #expect(oneLine.contains("'/Users/test/Application Support/OpenLoLa/report'\\''s.json'"))
    #expect(oneLine.hasSuffix(" ''"))
    #expect(multiline.contains("'/Applications/Open LoLa/open-lola'"))
    #expect(multiline.contains(" \\\n  ''"))
}

@MainActor
@Test
func appExecutionValidationDoesNotPassWithoutCurrentDirectPeerReportEvidence() {
    let missingSupervisorPath = "/private/tmp/open-lola-missing-supervisor-\(UUID().uuidString).json"
    var settings = NativeAppShellExecutionSettings()
    settings.supervisorReportPath = missingSupervisorPath
    let controller = AppExecutionController(settings: settings)
    controller.lastLatencyMetrics = AppLatencyHeroMetrics.make(from: [
        appDirectPeerSessionReport(
            id: "stale-peer-report",
            packetsReceived: 1,
            packetsLost: 0,
            jitterMicroseconds: 1,
            latencyMicroseconds: 1
        ),
    ])

    controller.finishValidation(exitCode: 0)

    #expect(controller.phase == .validationFailed)
    #expect(controller.status == "Validation evidence incomplete.")
    #expect(!controller.hasValidatedRuntimeEvidence)
    #expect(controller.lastLatencyMetrics == nil)
    #expect(controller.lastError?.contains("Validated supervisor report missing or unreadable") == true)
}

@MainActor
@Test
func appExecutionValidationPassesOnlyWithCompleteCurrentDirectPeerEvidence() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-validation-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let reportAURL = directory.appendingPathComponent("peer-a.json")
    let supervisorURL = directory.appendingPathComponent("supervisor.json")
    try appDirectPeerSessionReport(
        id: "peer-a-report",
        packetsReceived: 90,
        packetsLost: 0,
        jitterMicroseconds: 2_500,
        latencyMicroseconds: 1_200
    ).prettyJSONData().write(to: reportAURL)
    try DirectPeerTwoPeerLocalRunReport(
        id: "supervisor",
        capturedAt: "2026-05-15T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: [
            appProcessResult(peerID: "peer-a", reportPath: reportAURL.path),
        ],
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        preflightChecks: [
            DirectPeerTwoPeerPreflightCheck(id: "unit", severity: .pass, passed: true, message: "ok"),
        ],
        evidenceGates: ["unit"],
        verdict: .partial,
        notes: "unit test supervisor report"
    ).prettyJSONData().write(to: supervisorURL)

    var settings = NativeAppShellExecutionSettings()
    settings.supervisorReportPath = supervisorURL.path
    let controller = AppExecutionController(settings: settings)

    controller.finishValidation(exitCode: 0)

    #expect(controller.phase == .validationPassed)
    #expect(controller.status == "Validation passed.")
    #expect(controller.hasValidatedRuntimeEvidence)
    #expect(controller.lastLatencyMetrics?.isPartial == false)
}

@MainActor
@Test
func appExecutionValidationDoesNotPassWindowsLoLaWithoutExternalReportEvidence() throws {
    var state = appOperatorState(remoteSelectionComplete: false)
    state.sessionMode = .windowsLoLa
    state.windowsLoLaPeerFields.outputPath = "/private/tmp/open-lola-missing-windows-lola-\(UUID().uuidString).json"
    let controller = AppExecutionController()

    _ = try controller.prepareValidationContext(operatorSurface: state)
    controller.finishValidation(exitCode: 0)

    #expect(controller.phase == .validationFailed)
    #expect(controller.status == "Validation evidence incomplete.")
    #expect(!controller.hasValidatedRuntimeEvidence)
    #expect(controller.lastExternalConnectorReport == nil)
    #expect(controller.lastError?.contains("Validated external connector report missing or unreadable") == true)
}

@MainActor
@Test
func appPreviewStopResetsServiceStatusesToIdle() {
    let previewState = AppPreviewReceiverState()
    previewState.videoPreviewController.status = "Live video preview: unit"
    previewState.audioLevelMeter.status = "Live input meter: unit"

    previewState.stopReceiverPreview()

    #expect(previewState.videoPreviewController.status == "Video preview idle.")
    #expect(previewState.audioLevelMeter.status == "Audio meter idle.")
    #expect(!previewState.previewIsActive)
}

@Test
func appPacketMonitorRowsStateSurfacesRowErrorsSeparatelyFromEmptyFilters() {
    let emptyReport = LoLaCompatibilityCaptureReport(
        id: "empty-capture",
        title: "Empty capture",
        capturedAt: "2026-05-14T00:00:00Z",
        inputPath: "fixtures/empty.pcapng",
        inputFormat: .pcapng,
        summary: LoLaCompatibilityCaptureSummary(packets: []),
        packets: [],
        verdict: .partial,
        evidenceBoundary: "unit-test packet monitor",
        notes: "empty capture"
    )

    #expect(AppPacketMonitorRowsState.make(
        report: emptyReport,
        streamFilter: .all,
        searchText: "no-match"
    ) == .rows([]))

    let failureState = AppPacketMonitorRowsState.make(
        report: emptyReport,
        streamFilter: .all,
        searchText: "",
        limit: -1
    )
    guard case .failure(let message) = failureState else {
        Issue.record("Expected row-building failure state")
        return
    }
    #expect(message.contains("negativeLimit"))
}

@Test
func appConsoleSelectionDoesNotRenderHiddenOrUnavailableSectionsAsActive() {
    let sections = NativeAppShellSurfaceContract.releaseReadiness.sections
    let settingsOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "settings")
    let packetOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "packet")

    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: settingsOnly,
        sessionState: .live,
        captureReportAvailable: true
    ) == .settings)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .unconfigured,
        captureReportAvailable: true
    ) == .overview)
    #expect(AppConsoleSectionSelection.activeSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .unconfigured,
        captureReportAvailable: true
    ) == nil)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .unconfigured,
        captureReportAvailable: true
    ) == nil)
}

@MainActor
@Test
func appExecutionControllerRecordsMissingLogOpenErrors() {
    let controller = AppExecutionController()
    let missingPath = "/private/tmp/open-lola-missing-log-\(UUID().uuidString).log"

    #expect(!controller.canOpenLogFile(missingPath))
    controller.openLogFile(missingPath)

    #expect(controller.lastError == "Log file missing: \(missingPath)")
    #expect(controller.errorLog == ["Log file missing: \(missingPath)"])
}

@MainActor
@Test
func appPreviewDisabledTogglesAreIdleNotActiveControls() async {
    let previewState = AppPreviewReceiverState(audioPreviewEnabled: false, videoPreviewEnabled: false)

    previewState.startReceiverPreview(audioInputUID: nil, videoDeviceID: nil)
    await Task.yield()

    #expect(previewState.previewPhase == .disabled)
    #expect(!previewState.previewIsActive)
    #expect(previewState.verifiedReceiverStatus == "Local device preview disabled.")
}

@Test
func appStoredDefaultsRejectOutOfRangePersistedPortsInsteadOfClamping() throws {
    let suiteName = "open-lola-app-port-defaults-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    defaults.set(70_000, forKey: AppStorageKeys.controlPort)
    defaults.set(-1, forKey: AppStorageKeys.audioPort)
    defaults.set(65_536, forKey: AppStorageKeys.windowsLoLaControlPort)
    defaults.set(-2, forKey: AppStorageKeys.windowsLoLaVideoPort)

    let directPeerFields = AppShellStoredDefaults.directPeerCommandFields(defaults: defaults)
    let windowsLoLaFields = AppShellStoredDefaults.windowsLoLaPeerFields(defaults: defaults)

    #expect(directPeerFields.controlPort == NativeAppShellDirectPeerCommandFields.appDefault.controlPort)
    #expect(directPeerFields.audioPort == NativeAppShellDirectPeerCommandFields.appDefault.audioPort)
    #expect(windowsLoLaFields.controlPort == NativeAppShellWindowsLoLaPeerFields.appDefault.controlPort)
    #expect(windowsLoLaFields.videoPort == NativeAppShellWindowsLoLaPeerFields.appDefault.videoPort)
    #expect(directPeerFields.controlPort != UInt16.max)
    #expect(directPeerFields.audioPort != UInt16.min)
    #expect(defaults.object(forKey: AppStorageKeys.controlPort) == nil)
    #expect(defaults.object(forKey: AppStorageKeys.audioPort) == nil)
    #expect(defaults.object(forKey: AppStorageKeys.windowsLoLaControlPort) == nil)
    #expect(defaults.object(forKey: AppStorageKeys.windowsLoLaVideoPort) == nil)
}

private func appOperatorState(remoteSelectionComplete: Bool) -> NativeAppShellOperatorPrototypeState {
    var remoteInventory = NativeAppShellLocalMediaInventory.editableRemotePlaceholder(peerName: "remote-mac")
    if remoteSelectionComplete {
        remoteInventory = NativeAppShellLocalMediaInventory(
            capturedAt: "2026-05-14T00:00:00Z",
            hostName: "remote-mac",
            audioDevices: [
                NativeAppShellAudioDeviceOption(
                    name: "Remote RME",
                    uid: "remote-rme",
                    inputChannelCount: 64,
                    outputChannelCount: 64,
                    nominalSampleRateHertz: 48_000,
                    currentBufferFrameSize: 32
                ),
            ],
            videoDevices: [
                NativeAppShellVideoDeviceOption(
                    label: "Remote ATEM",
                    uniqueId: "remote-atem",
                    manufacturer: "Blackmagic Design",
                    transport: "USB",
                    sourcePolicy: .blackmagicFirstAvFoundationFallback,
                    formatCount: 1
                ),
            ],
            selection: NativeAppShellLocalMediaSelection(
                audioInputUID: "remote-rme",
                audioOutputUID: "remote-rme",
                videoDeviceID: "remote-atem"
            ),
            inventoryErrors: []
        )
    }
    var fields = NativeAppShellDirectPeerCommandFields.appDefault
    fields.localHost = "192.0.2.10"
    fields.remoteHost = "192.0.2.20"
    return NativeAppShellOperatorPrototypeState(
        inventory: NativeAppShellLocalMediaInventory(
            capturedAt: "2026-05-14T00:00:00Z",
            hostName: "local-mac",
            audioDevices: [
                NativeAppShellAudioDeviceOption(
                    name: "Local RME",
                    uid: "local-rme",
                    inputChannelCount: 64,
                    outputChannelCount: 64,
                    nominalSampleRateHertz: 48_000,
                    currentBufferFrameSize: 32
                ),
            ],
            videoDevices: [
                NativeAppShellVideoDeviceOption(
                    label: "Local ATEM",
                    uniqueId: "local-atem",
                    manufacturer: "Blackmagic Design",
                    transport: "USB",
                    sourcePolicy: .blackmagicFirstAvFoundationFallback,
                    formatCount: 1
                ),
            ],
            selection: NativeAppShellLocalMediaSelection(
                audioInputUID: "local-rme",
                audioOutputUID: "local-rme",
                videoDeviceID: "local-atem"
            ),
            inventoryErrors: []
        ),
        remoteInventory: remoteInventory,
        commandIntent: .idle,
        remoteOrchestrationEnabled: false,
        startsLongRunningProcess: false,
        directPeerCommandFields: fields
    )
}

private func appDirectPeerSessionReport(
    id: String,
    packetsReceived: Int,
    packetsLost: Int,
    jitterMicroseconds: Double,
    latencyMicroseconds: Double
) -> DirectPeerSessionReport {
    DirectPeerSessionReport(
        id: id,
        capturedAt: "2026-05-14T00:00:00Z",
        configuration: appSessionConfiguration(),
        metrics: DirectPeerSessionReportMetrics(
            controlMessagesSent: 1,
            packetsSent: packetsReceived + packetsLost,
            packetsReceived: packetsReceived,
            packetsLost: packetsLost,
            jitterMicroseconds: jitterMicroseconds,
            audioPacketsRouted: packetsReceived,
            videoPacketsRouted: 0,
            recoveryEvents: 0,
            audioPayloadsSentOnControlChannel: 0
        ),
        avRuntime: DirectPeerSessionAVRuntimeMetadata(
            avProfile: .fastest,
            previewMode: .off,
            mediaSourceMode: .syntheticFixture,
            audioDeviceUID: "local-rme",
            sampleRateHertz: 48_000,
            selectedBufferFrameSize: 32,
            latencyProfile: .directAudioFirst,
            rxBufferProfile: .direct,
            videoDeviceID: "local-atem",
            videoFrameRate: 30,
            videoStreamID: 100,
            fastestPassBlockedReason: "unit test partial",
            fastestAVBaselineComparison: DirectPeerSessionFastestAVBaselineComparison(
                audioOnlyBaselineReportID: "audio-only",
                audioOnlyBaselineReportPath: "reports/audio-only.json",
                comparisonArtifactPath: "reports/comparison.json",
                audioOnlyLatencyP99Microseconds: latencyMicroseconds,
                fastestAVAudioLatencyP99Microseconds: latencyMicroseconds,
                audioLatencyEqualToBaseline: true,
                rxBufferEqualToBaseline: true,
                lossJitterEqualToBaseline: true
            )
        ),
        verdict: .partial,
        notes: "unit test partial report"
    )
}

private func appProcessResult(peerID: String, reportPath: String) -> DirectPeerTwoPeerLocalRunProcessResult {
    DirectPeerTwoPeerLocalRunProcessResult(
        peerID: peerID,
        role: peerID == "peer-a" ? .initiator : .responder,
        reportPath: reportPath,
        command: ["open-lola", "direct-p2p-session-run"],
        exitCode: 0,
        collectedReportPath: reportPath
    )
}

private func appSessionConfiguration() -> SessionConfiguration {
    SessionConfiguration(
        sessionID: "app-test-session",
        peers: [
            PeerIdentity(
                peerID: "peer-a",
                displayName: "Peer A",
                implementationName: "open-lola",
                implementationVersion: "test"
            ),
            PeerIdentity(
                peerID: "peer-b",
                displayName: "Peer B",
                implementationName: "open-lola",
                implementationVersion: "test"
            ),
        ],
        latencyProfile: .directAudioFirst,
        rxBufferProfile: .direct,
        audioStreams: [],
        videoStreams: [],
        controlEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 19_001),
        audioEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 19_002),
        videoEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 19_003),
        metricsEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 19_004),
        peerMediaEndpoints: [
            appPeerEndpoints(peerID: "peer-a", basePort: 19_001),
            appPeerEndpoints(peerID: "peer-b", basePort: 19_011),
        ],
        mtuBytes: 1_200,
        metricIntervalMilliseconds: 1_000,
        reconnectDeadlineMilliseconds: 1_000
    )
}

private func appPeerEndpoints(peerID: String, basePort: UInt16) -> SessionPeerMediaEndpoints {
    SessionPeerMediaEndpoints(
        peerID: peerID,
        controlEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: basePort),
        audioEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: basePort + 1),
        videoEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: basePort + 2),
        metricsEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: basePort + 3)
    )
}
