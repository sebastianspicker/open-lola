// Verifies that app diagnostics labels placeholder and source-level facts explicitly.
import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func appDiagnosticsLabelsPlaceholderAndSourceLevelFactsExplicitly() {
    let controller = AppExecutionController()
    let placeholder = AppDiagnosticsStatusModel.make(
        report: NativeAppShellReport.placeholder(),
        executionController: controller
    )

    #expect(placeholder.permissionsTitle == "Planned ready")
    #expect(placeholder.realtimeSafetyTitle == "Source boundary safe")
    #expect(placeholder.evidenceTitle == "Source checks · Not measured")
}

@Test
func appRemoteEvidenceStatusSeparatesPlanPreviewFromPacketEvidence() {
    let noCapture = AppRemoteEvidenceStatusPolicy.make(
        plan: AppOperatorPrototypePlan.make(operatorSurface: appWorkflowSurface()),
        captureReport: nil
    )
    #expect(noCapture.runtimeState == "Remote plan only; no received-media proof")
    #expect(noCapture.evidence == "No remote packet or media evidence measured")
    #expect(noCapture.packetCount == "Not measured")

    let withCapture = AppRemoteEvidenceStatusPolicy.make(
        plan: AppOperatorPrototypePlan.make(operatorSurface: appWorkflowSurface()),
        captureReport: appEmptyCaptureReport(capturedAt: "2026-05-20T00:00:00Z")
    )
    #expect(withCapture.evidence == "Packet capture report loaded")
    #expect(withCapture.packetCount == "0")
}

@Test
func appPreviewReceiverWarningPolicyOnlyWarnsDuringRuntimeEvidenceStates() {
    #expect(AppPreviewReceiverWarningPolicy.showsMainBannerWarning(
        phase: .degraded,
        audioPreviewEnabled: true,
        videoPreviewEnabled: false,
        sessionState: .awaitingEvidence
    ))
    #expect(AppPreviewReceiverWarningPolicy.showsMainBannerWarning(
        phase: .failed,
        audioPreviewEnabled: false,
        videoPreviewEnabled: true,
        sessionState: .supervisorRunning
    ))
    #expect(!AppPreviewReceiverWarningPolicy.showsMainBannerWarning(
        phase: .failed,
        audioPreviewEnabled: false,
        videoPreviewEnabled: false,
        sessionState: .supervisorRunning
    ))
    #expect(!AppPreviewReceiverWarningPolicy.showsMainBannerWarning(
        phase: .failed,
        audioPreviewEnabled: true,
        videoPreviewEnabled: true,
        sessionState: .ready
    ))
    #expect(!AppPreviewReceiverWarningPolicy.showsMainBannerWarning(
        phase: .active,
        audioPreviewEnabled: true,
        videoPreviewEnabled: true,
        sessionState: .awaitingEvidence
    ))
}

@Test
func appRuntimeInputLockBlocksMutatingInputsButKeepsStopAvailable() {
    #expect(AppRuntimeInputLock.mutatingInputsLocked(isRunning: true))
    #expect(!AppRuntimeInputLock.mutatingInputsLocked(isRunning: false))
    #expect(AppRuntimeInputLock.canStop(isRunning: true))
    #expect(!AppRuntimeInputLock.canStop(isRunning: false))
    #expect(AppRuntimeInputLock.lockedHelp.contains("locked"))
    #expect(AppRemoteInventoryEditPolicy.fieldsDisabled(inputsLocked: true))
    #expect(!AppRemoteInventoryEditPolicy.fieldsDisabled(inputsLocked: false))
    #expect(AppRemoteInventoryEditPolicy.help(inputsLocked: true) == AppRuntimeInputLock.lockedHelp)
}

@Test
func appInventoryRefreshMergePreservesConcurrentOperatorEdits() {
    var current = appWorkflowSurface()
    current.remoteInventory.hostName = "edited-remote-label"
    current.directPeerCommandFields.remoteHost = "198.51.100.44"
    current.inventory.selection = NativeAppShellLocalMediaSelection(
        audioInputUID: "current-input",
        audioOutputUID: "current-output",
        videoDeviceID: "current-video"
    )

    let refreshResult = appWorkflowRefreshResultWithCurrentSelections()

    let merged = AppLocalOperatorInventoryRefreshMergePolicy.merge(
        current: current,
        refreshResult: refreshResult
    )

    #expect(merged.inventory.hostName == "refreshed-local")
    #expect(merged.inventory.selection.audioInputUID == "current-input")
    #expect(merged.inventory.selection.audioOutputUID == "current-output")
    #expect(merged.inventory.selection.videoDeviceID == "current-video")
    #expect(merged.remoteInventory.hostName == "edited-remote-label")
    #expect(merged.directPeerCommandFields.remoteHost == "198.51.100.44")
    #expect(merged.commandIntent == current.commandIntent)
}

func appWorkflowRefreshResultWithCurrentSelections() -> NativeAppShellOperatorPrototypeState {
    var refreshResult = appWorkflowSurface()
    refreshResult.remoteInventory.hostName = "stale-remote-label"
    refreshResult.directPeerCommandFields.remoteHost = "192.0.2.99"
    refreshResult.inventory = appWorkflowInventory(
        hostName: "refreshed-local",
        inputUID: "fallback-input",
        outputUID: "fallback-output",
        videoID: "fallback-video"
    )
    refreshResult.inventory.audioDevices.append(contentsOf: [
        NativeAppShellAudioDeviceOption(
            name: "Current Input",
            uid: "current-input",
            inputChannelCount: 2,
            outputChannelCount: 0,
            nominalSampleRateHertz: 48_000,
            currentBufferFrameSize: 120
        ),
        NativeAppShellAudioDeviceOption(
            name: "Current Output",
            uid: "current-output",
            inputChannelCount: 0,
            outputChannelCount: 2,
            nominalSampleRateHertz: 48_000,
            currentBufferFrameSize: 120
        )
    ])
    refreshResult.inventory.videoDevices.append(NativeAppShellVideoDeviceOption(
        label: "Current Video",
        uniqueId: "current-video",
        manufacturer: "Test",
        transport: "virtual",
        sourcePolicy: .blackmagicFirstAvFoundationFallback,
        formatCount: 1
    ))
    return refreshResult
}

@MainActor
@Test
// swiftlint:disable:next function_body_length
func appWorkflowModesDoNotLeakRunnablePlansAcrossModes() throws {
    var surface = appWorkflowSurface()
    surface.directPeerCommandFields.audioTransport = .openLolaOpusCeltLowDelay
    surface.directPeerCommandFields.framesPerPacket = OpusCELTLowDelayConstants.frameCount
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
    for (mode, connector, outputPath) in [
        (
            NativeAppShellSessionMode.jackTrip,
            ExternalConnectorKind.jackTrip,
            "/tmp/open-lola-app/jacktrip-session.json"
        ),
        (.ultraGrid, .mvtpUltraGrid, "/tmp/open-lola-app/ultragrid-session.json")
    ] {
        surface.sessionMode = mode
        let plan = AppOperatorPrototypePlan.make(operatorSurface: surface)
        #expect(plan.isConfigured)
        #expect(plan.validationError == nil)
        #expect(plan.externalConnectorCommand?.contains(connector.appCLIValue) == true)
        #expect(controller.validationReadiness(operatorSurface: surface) == .missingReport(outputPath))

        let executionCommand = try controller.executionCommand(
            executablePath: "/bin/echo",
            operatorSurface: surface,
            dryRun: true
        ).get()
        #expect(executionCommand.contains(connector.appCLIValue))
        #expect(executionCommand.contains(outputPath))

            let validatorCommand = try controller.validatorCommand(
                executablePath: "/bin/echo",
                operatorSurface: surface).get()
        #expect(validatorCommand == ["/bin/echo", "validate-external-connector-session-report", outputPath])
    }
}

func appWorkflowSurface() -> NativeAppShellOperatorPrototypeState {
    return NativeAppShellOperatorPrototypeState(
        workflow: NativeAppShellOperatorWorkflow(
            commandIntent: .runRequested,
            remoteOrchestrationEnabled: false,
            startsLongRunningProcess: false
        ),
        inventories: NativeAppShellOperatorInventories(
            local: appWorkflowInventory(
                hostName: "local-mac",
                inputUID: "local-input",
                outputUID: "local-output",
                videoID: "local-video"
            ),
            remote: appWorkflowInventory(
                hostName: "remote-mac",
                inputUID: "remote-input",
                outputUID: "remote-output",
                videoID: "remote-video"
            )
        ),
        peerFields: NativeAppShellOperatorPeerFields(
            directPeer: appWorkflowDirectPeerFields(),
            windowsLoLa: appWorkflowWindowsLoLaPeerFields()
        )
    )
}

private func appWorkflowDirectPeerFields() -> NativeAppShellDirectPeerCommandFields {
    var fields = NativeAppShellDirectPeerCommandFields.appDefault
    fields.channelCount = 2
    fields.sampleRateHertz = 48_000
    fields.framesPerPacket = 32
    fields.videoWidth = 1_280
    fields.videoHeight = 720
    fields.videoFrameRate = 30
    fields.avProfile = .balanced
    fields.rxBufferProfile = .small
    return fields
}

private func appWorkflowWindowsLoLaPeerFields() -> NativeAppShellWindowsLoLaPeerFields {
    var fields = NativeAppShellWindowsLoLaPeerFields.appDefault
    fields.payloadMode = .avFoundationJpegXS
    return fields
}

@MainActor
func appShellSettingsView() -> AppShellSettingsView {
    var surface = AppShellStoredDefaults.placeholderOperatorSurface()
    return AppShellSettingsView(
        configuration: NativeAppConfigurationSnapshot(
            profile: .init(name: "test", audioDeviceSelection: "test-input", outputDeviceUID: nil),
            audio: .init(sampleRateHertz: 48_000, framesPerBuffer: 128, requestedPlayoutTargetFrames: 128),
            features: .init(
                videoEnabled: true,
                showControlEnabled: false,
                lightingEnabled: false,
                createdByUI: true,
                immutableHandoff: true
            )
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

func appWorkflowInventory(
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
            )
        ],
        videoDevices: [
            NativeAppShellVideoDeviceOption(
                label: "Video",
                uniqueId: videoID,
                manufacturer: "Test",
                transport: "virtual",
                sourcePolicy: .blackmagicFirstAvFoundationFallback,
                formatCount: 1
            )
        ],
        selection: NativeAppShellLocalMediaSelection(
            audioInputUID: inputUID,
            audioOutputUID: outputUID,
            videoDeviceID: videoID
        ),
        inventoryErrors: []
    )
}
