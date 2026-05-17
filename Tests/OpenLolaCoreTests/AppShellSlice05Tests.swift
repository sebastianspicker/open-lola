import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@Test
func appMenuActionHandlingCoversEveryContractAction() {
    let contractActionIDs = Set(NativeAppShellSurfaceContract.releaseReadiness.actions.map(\.id))

    #expect(contractActionIDs == AppMenuActionHandling.handledActionIDs)
    #expect(AppMenuActionHandling.isHandled("validate-supervisor-report"))
    #expect(!AppMenuActionHandling.isHandled("future-unmapped-action"))
}

@MainActor
@Test
func appValidationBlocksMissingReportArtifactsBeforeLaunching() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-slice05-validation-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let controller = AppExecutionController()
    var surface = AppShellStoredDefaults.placeholderOperatorSurface()
    let missingDirectReport = directory.appendingPathComponent("missing-supervisor.json").path
    controller.settings.supervisorReportPath = missingDirectReport

    #expect(controller.validationReadiness(operatorSurface: surface) == .missingReport(missingDirectReport))
    controller.validateReport(operatorSurface: surface)
    #expect(controller.lastCommand.isEmpty)
    #expect(controller.status == "Validation unavailable.")
    #expect(controller.phase == .validationFailed)
    #expect(controller.lastError == "Cannot validate missing report artifact: \(missingDirectReport)")

    surface.sessionMode = .windowsLoLa
    let missingWindowsReport = directory.appendingPathComponent("missing-windows-lola.json").path
    surface.windowsLoLaPeerFields.outputPath = missingWindowsReport
    #expect(controller.validationReadiness(operatorSurface: surface) == .missingReport(missingWindowsReport))
}

@Test
func appPacketMonitorSelectionRequiresCaptureReportEvidence() {
    let sections = NativeAppShellSurfaceContract.releaseReadiness.sections
    let packetOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "packet")

    #expect(AppConsoleSectionSelection.activeSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .ready,
        captureReportAvailable: false
    ) == nil)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .ready,
        captureReportAvailable: false
    ) == .overview)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .ready,
        captureReportAvailable: false
    ) == nil)
    #expect(AppConsoleSectionSelection.activeSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .ready,
        captureReportAvailable: true
    ) == .packetMonitor)
}

@MainActor
@Test
func appSlice05UiPoliciesExposeTruthfulOperatorStates() {
    #expect(!AppPreviewControlAvailability.returnBlendEnabledInLocalPreview)
    #expect(!AppPreviewControlAvailability.visibleStreamsEnabledInLocalPreview)
    #expect(AppPreviewControlAvailability.unsupportedLocalPreviewHelp.contains("single-stream"))

    let settingsView = appShellSettingsView()
    #expect(!settingsView.executionSettingsLocked)
    #expect(settingsView.executionSettingsHelp.contains("next generated command"))
    #expect(AppShellSettingsView.executionSettingsHelp(isRunning: true).contains("locked"))

    #expect(AppWindowSize.operatorMinWidth == 1024)
    #expect(AppWindowSize.operatorMinHeight == 720)
}

@Test
func appWorkflowModesAndControlVisibilityAreExplicit() {
    #expect(NativeAppShellSessionMode.allCases.map(\.displayName) == ["Mac-to-Mac", "LoLa", "JackTrip", "UltraGrid"])
    #expect(NativeAppShellSessionMode.directMacPeer.supportsAppExecution)
    #expect(NativeAppShellSessionMode.windowsLoLa.externalConnectorKind == .lola)
    #expect(NativeAppShellSessionMode.jackTrip.externalConnectorKind == .jackTrip)
    #expect(NativeAppShellSessionMode.ultraGrid.externalConnectorKind == .mvtpUltraGrid)
    #expect(!NativeAppShellSessionMode.jackTrip.supportsAppExecution)
    #expect(!NativeAppShellSessionMode.ultraGrid.supportsAppExecution)
    #expect(NativeAppShellSessionMode.jackTrip.appStatusLabel == "External connector CLI only")
    #expect(NativeAppShellSessionMode.ultraGrid.appStatusLabel == "External connector CLI only")
    #expect(NativeAppShellSessionMode.jackTrip.unavailableAppReason?.contains("operator planning") == true)
    #expect(NativeAppShellSessionMode.ultraGrid.unavailableAppReason?.contains("operator planning") == true)
    #expect(NativeAppShellSessionMode.jackTrip.unavailableAppReason?.contains("external connector or NMP CLI contracts") == true)
    #expect(NativeAppShellSessionMode.ultraGrid.unavailableAppReason?.contains("external connector or NMP CLI contracts") == true)

    let normalDirect = Set(NativeAppShellSettingsVisibility.visibleGroups(
        sessionMode: .directMacPeer,
        controlMode: .normal
    ))
    #expect(normalDirect.contains(.workflow))
    #expect(normalDirect.contains(.connection))
    #expect(!normalDirect.contains(.ports))
    #expect(!normalDirect.contains(.audioCodec))
    #expect(!normalDirect.contains(.videoCodec))
    #expect(!normalDirect.contains(.sshFallback))

    let advancedDirect = Set(NativeAppShellSettingsVisibility.visibleGroups(
        sessionMode: .directMacPeer,
        controlMode: .advanced
    ))
    #expect(advancedDirect.contains(.ports))
    #expect(advancedDirect.contains(.audioCodec))
    #expect(advancedDirect.contains(.videoCodec))
    #expect(advancedDirect.contains(.sshFallback))

    let externalOnly = Set(NativeAppShellSettingsVisibility.visibleGroups(
        sessionMode: .jackTrip,
        controlMode: .advanced
    ))
    #expect(externalOnly.contains(.externalConnectorNotice))
    #expect(!externalOnly.contains(.execution))
    #expect(!externalOnly.contains(.ports))

    for mode in [NativeAppShellSessionMode.jackTrip, .ultraGrid] {
        #expect(
            NativeAppShellSettingsVisibility.visibleGroups(
                sessionMode: mode,
                controlMode: .normal
            ) == [.workflow, .externalConnectorNotice]
        )
        #expect(
            NativeAppShellSettingsVisibility.visibleGroups(
                sessionMode: mode,
                controlMode: .advanced
            ) == [.workflow, .externalConnectorNotice]
        )
    }
}

@MainActor
@Test
func appWorkflowModesDoNotLeakRunnablePlansAcrossModes() {
    var surface = appWorkflowSurface()
    surface.directPeerCommandFields.audioTransport = .openLolaOpusCeltLowDelay
    surface.directPeerCommandFields.videoCompression = .jpegXS

    let directPlan = AppOperatorPrototypePlan.make(operatorSurface: surface)
    #expect(directPlan.isConfigured)
    #expect(directPlan.audioTransport == .openLolaOpusCeltLowDelay)
    #expect(directPlan.videoCompression == .jpegXS)

    surface.sessionMode = .windowsLoLa
    surface.windowsLoLaPeerFields.payloadMode = .avFoundationJpegXS
    let lolaPlan = AppOperatorPrototypePlan.make(operatorSurface: surface)
    #expect(lolaPlan.isConfigured)
    #expect(lolaPlan.windowsLoLaCommand?.contains("lola") == true)
    #expect(lolaPlan.windowsLoLaCommand?.contains(LoLaVideoPayloadKind.avFoundationJpegXS.rawValue) == true)
    #expect(lolaPlan.validationError == nil)
    #expect(lolaPlan.report == nil)

    surface.windowsLoLaPeerFields.outputPath = ""
    let invalidWindowsPlan = AppOperatorPrototypePlan.make(operatorSurface: surface)
    #expect(!invalidWindowsPlan.isConfigured)
    #expect(invalidWindowsPlan.windowsLoLaCommand == nil)
    #expect(invalidWindowsPlan.validationError?.contains("invalidCommandField(\"outputPath\")") == true)

    surface.windowsLoLaPeerFields.outputPath = "/tmp/open-lola-app/windows-lola-session.json"
    surface.sessionMode = .directMacPeer
    surface.directPeerCommandFields.localHost = ""
    let invalidDirectPlan = AppOperatorPrototypePlan.make(operatorSurface: surface)
    #expect(!invalidDirectPlan.isConfigured)
    #expect(invalidDirectPlan.report == nil)
    #expect(invalidDirectPlan.validationError?.contains("invalidCommandField(\"localHost\")") == true)

    let controller = AppExecutionController()
    surface.directPeerCommandFields.localHost = "192.0.2.10"
    for mode in [NativeAppShellSessionMode.jackTrip, .ultraGrid] {
        surface.sessionMode = mode
        let plan = AppOperatorPrototypePlan.make(operatorSurface: surface)
        #expect(!plan.isConfigured)
        #expect(plan.validationError?.contains("operator planning") == true)
        #expect(plan.validationError?.contains("no wired runtime launcher") == true)
        #expect(controller.validationReadiness(operatorSurface: surface).isReady == false)
        #expect(
            controller.validationReadiness(operatorSurface: surface)
                .unavailableMessage?
                .contains("no wired runtime launcher") == true
        )

        #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")) {
            try controller.executionCommand(
                executablePath: ".build/debug/open-lola",
                operatorSurface: surface,
                dryRun: true
            ).get()
        }
        #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")) {
            try controller.validatorCommand(
                executablePath: ".build/debug/open-lola",
                operatorSurface: surface
            ).get()
        }
    }
}

@Test
func appExecutionErrorGuidanceClassifiesCommonFailureTypes() {
    #expect(AppExecutionErrorGuidance.detail(
        for: "Cannot validate missing report artifact: /tmp/supervisor.json"
    ).contains("report path"))
    #expect(AppExecutionErrorGuidance.detail(
        for: "No such file or executable"
    ).contains("executable path"))
    #expect(AppExecutionErrorGuidance.detail(
        for: "plan validation failed"
    ).contains("plan fields"))
    #expect(AppExecutionErrorGuidance.detail(
        for: "process exited 42"
    ).contains("log paths"))
}

@Test
func appReadableMetricAccessibilityIncludesMetricContext() {
    #expect(AppReadableMetricAccessibility.valueLabel(metric: "Plan", value: "/tmp/plan.json") == "Plan: /tmp/plan.json")
    #expect(AppReadableMetricAccessibility.copyLabel(metric: "Audio input UID") == "Copy Audio input UID value")
}

@MainActor
@Test
func appPasteboardCopyReportsWriteResultBeforeSuccessStatus() {
    let originalWriter = AppPasteboard.writeString
    defer {
        AppPasteboard.writeString = originalWriter
    }
    var copiedValues: [String] = []
    AppPasteboard.writeString = { value in
        copiedValues.append(value)
        return true
    }

    #expect(AppPasteboard.copyString("open-lola --dry-run"))
    #expect(copiedValues == ["open-lola --dry-run"])

    AppPasteboard.writeString = { _ in false }
    #expect(!AppPasteboard.copyString("open-lola --dry-run"))

    let copiedStatuses = [
        (
            success: "Copied local inventory JSON.",
            failure: "Copy failed for local inventory JSON."
        ),
        (
            success: "Generated copyable plan JSON.",
            failure: "Generated plan JSON, but pasteboard copy failed."
        ),
        (
            success: "Wrote plan artifact to /tmp/plan.json.",
            failure: "Wrote plan artifact, but pasteboard copy failed."
        ),
        (
            success: "Reloaded plan artifact from /tmp/plan.json.",
            failure: "Reloaded plan artifact, but pasteboard copy failed."
        ),
        (
            success: "Copied SSH supervisor command.",
            failure: "Copy failed for SSH supervisor command."
        ),
    ]

    for status in copiedStatuses {
        #expect(AppPasteboardCopyStatus.message(
            copied: true,
            success: status.success,
            failure: status.failure
        ) == status.success)
        let failedMessage = AppPasteboardCopyStatus.message(
            copied: false,
            success: status.success,
            failure: status.failure
        )
        #expect(failedMessage == status.failure)
        #expect(!failedMessage.hasPrefix("Copied"))
        #expect(!failedMessage.hasPrefix("Generated copyable"))
    }
}

private func appWorkflowSurface() -> NativeAppShellOperatorPrototypeState {
    var directFields = NativeAppShellDirectPeerCommandFields.appDefault
    directFields.localPeer = "mac-a"
    directFields.remotePeer = "mac-b"
    directFields.localHost = "192.0.2.10"
    directFields.remoteHost = "192.0.2.20"
    directFields.channelCount = 2
    directFields.sampleRateHertz = 48_000
    directFields.framesPerPacket = 120
    directFields.sampleFormat = "float32"
    directFields.videoWidth = 1_280
    directFields.videoHeight = 720
    directFields.videoPixelFormat = "bgra8"
    directFields.videoFrameRate = 30
    directFields.avProfile = .balanced
    directFields.rxBufferProfile = .small

    return NativeAppShellOperatorPrototypeState(
        inventory: appWorkflowInventory(
            hostName: "local-mac",
            inputUID: "local-input",
            outputUID: "local-output",
            videoID: "local-video"
        ),
        remoteInventory: appWorkflowInventory(
            hostName: "remote-mac",
            inputUID: "remote-input",
            outputUID: "remote-output",
            videoID: "remote-video"
        ),
        commandIntent: .runRequested,
        remoteOrchestrationEnabled: false,
        startsLongRunningProcess: false,
        directPeerCommandFields: directFields,
        windowsLoLaPeerFields: NativeAppShellWindowsLoLaPeerFields(
            executablePath: ".build/debug/open-lola",
            localHost: "0.0.0.0",
            windowsHost: "192.0.2.30",
            payloadMode: .avFoundationJpegXS
        )
    )
}

@MainActor
private func appShellSettingsView() -> AppShellSettingsView {
    var surface = AppShellStoredDefaults.placeholderOperatorSurface()
    return AppShellSettingsView(
        configuration: NativeAppConfigurationSnapshot(
            profileName: "test",
            audioDeviceSelection: "test-input",
            outputDeviceUID: nil,
            sampleRateHertz: 48_000,
            framesPerBuffer: 128,
            requestedPlayoutTargetFrames: 128,
            videoEnabled: true,
            showControlEnabled: false,
            lightingEnabled: false,
            createdByUI: true,
            immutableHandoff: true
        ),
        operatorSurface: Binding(
            get: { surface },
            set: { surface = $0 }
        ),
        executionController: AppExecutionController(),
        previewState: AppPreviewReceiverState(),
        appSettings: AppSettings()
    )
}

private func appWorkflowInventory(
    hostName: String,
    inputUID: String,
    outputUID: String,
    videoID: String
) -> NativeAppShellLocalMediaInventory {
    NativeAppShellLocalMediaInventory(
        capturedAt: "2026-05-16T00:00:00Z",
        hostName: hostName,
        audioDevices: [
            NativeAppShellAudioDeviceOption(
                name: "Input",
                uid: inputUID,
                inputChannelCount: 2,
                outputChannelCount: 0,
                nominalSampleRateHertz: 48_000,
                currentBufferFrameSize: 120
            ),
            NativeAppShellAudioDeviceOption(
                name: "Output",
                uid: outputUID,
                inputChannelCount: 0,
                outputChannelCount: 2,
                nominalSampleRateHertz: 48_000,
                currentBufferFrameSize: 120
            ),
        ],
        videoDevices: [
            NativeAppShellVideoDeviceOption(
                label: "Video",
                uniqueId: videoID,
                manufacturer: "Test",
                transport: "virtual",
                sourcePolicy: .blackmagicFirstAvFoundationFallback,
                formatCount: 1
            ),
        ],
        selection: NativeAppShellLocalMediaSelection(
            audioInputUID: inputUID,
            audioOutputUID: outputUID,
            videoDeviceID: videoID
        ),
        inventoryErrors: []
    )
}
