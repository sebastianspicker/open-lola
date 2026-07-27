// Verifies that app sidebar session indicator uses non-color state cue.
import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func appSidebarSessionIndicatorUsesNonColorStateCue() {
    for state in AppSessionState.allCases {
        #expect(AppSidebarSessionIndicatorPolicy.systemImage(for: state) == state.systemImage)
        #expect(!AppSidebarSessionIndicatorPolicy.systemImage(for: state).isEmpty)
        #expect(AppSidebarSessionIndicatorPolicy.accessibilityLabel(for: state).contains(state.rawValue))
    }
    #expect(
        AppSidebarSessionIndicatorPolicy.systemImage(for: .ready)
            != AppSidebarSessionIndicatorPolicy.systemImage(for: .error)
    )
    #expect(
        AppSidebarSessionIndicatorPolicy.systemImage(for: .armed)
            != AppSidebarSessionIndicatorPolicy.systemImage(for: .validated)
    )
}

@Test
func appSignalDeskNavigationFollowsOperatorTasksAndKeepsSettingsNative() {
    let visibleIDs = AppSignalDeskNavigationPolicy.visibleSections(
        from: NativeAppShellSurfaceContract.releaseReadiness.sections
    ).map(\.id)

    #expect(visibleIDs == [
        .session,
        .devices,
        .routing,
        .streams,
        .packetMonitor,
        .validation,
        .diagnostics
    ])
    #expect(!visibleIDs.contains(.overview))
    #expect(!visibleIDs.contains(.settings))
}

@Test
func appSidebarBrandSignatureUsesMasterNameAndAccessibleDescriptor() throws {
    let sidebarSource = try String(contentsOf: appSourcePath("AppConsoleChromeView.swift"))
    let brandSource = try String(contentsOf: appSourcePath("AppBrandSignatureView.swift"))

    #expect(AppBrandSignaturePolicy.masterName == "Open LoLa")
    #expect(AppBrandSignaturePolicy.descriptor == "Signal Desk")
    #expect(AppBrandSignaturePolicy.accessibilityLabel == "Open LoLa Signal Desk")
    #expect(sidebarSource.contains("AppBrandSignature()"))
    #expect(brandSource.contains("Image(systemName: \"waveform\")"))
    #expect(brandSource.contains("Color.accentColor"))
    #expect(brandSource.contains("RoundedRectangle(cornerRadius: 6)"))
}

@Test
func appSignalDeskUsesOnePersistentMainWindowTransport() throws {
    let rootSource = try String(contentsOf: appSourcePath("AppShellRootView.swift"))
    let detailSource = try String(contentsOf: appSourcePath("AppShellRootDetailPanel.swift"))
    let sectionSources = try [
        "AppShellSectionViews.swift",
        "AppShellDetailView.swift",
        "AppOverviewSectionViews.swift",
        "AppSessionSectionViews.swift"
    ].map { try String(contentsOf: appSourcePath($0)) }
    let executionSource = try String(contentsOf: appSourcePath("AppExecutionView.swift"))
    let transportSource = try String(contentsOf: appSourcePath("AppTransportView.swift"))

    #expect(rootSource.components(separatedBy: "AppTransportView(").count - 1 == 1)
    #expect(!detailSource.contains("AppTransportView("))
    for sectionSource in sectionSources {
        #expect(!sectionSource.contains("AppTransportView("))
    }
    #expect(!executionSource.contains("Toggle(\"Arm session\""))
    #expect(transportSource.contains("ViewThatFits(in: .horizontal)"))
}

@Test
func appArtifactImportAndWriteStatusExposeValidationAndCounts() {
    let remoteInventory = appOperatorState(remoteSelectionComplete: true).remoteInventory
    let importSummary = AppRemoteInventoryImportStatus.summary(for: remoteInventory)
    #expect(importSummary.contains("host remote-mac"))
    #expect(importSummary.contains("audio input remote-rme"))
    #expect(importSummary.contains("audio output remote-rme"))
    #expect(importSummary.contains("video remote-atem"))

    let artifact = NativeAppShellGeneratedArtifactState(
        kind: .twoPeerRunPlan,
        generatedAt: "2026-05-20T12:00:00Z",
        path: "/tmp/open-lola/plan-2026-05-20T12-00-00Z.json",
        clipboardText: "{\"id\":\"new\"}",
        validationSummary: "new plan"
    )
    let result = NativeAppShellArtifactWriteResult(
        artifact: artifact,
        requestedPath: "/tmp/open-lola/plan.json",
        writtenPath: "/tmp/open-lola/plan-2026-05-20T12-00-00Z.json",
        writtenCount: 1,
        skippedCount: 1,
        failedCount: 0
    )
    let status = AppArtifactWriteStatus.message(result: result, copied: false)

    #expect(status.contains("Wrote 1 plan artifact"))
    #expect(status.contains("Skipped overwrite of existing target /tmp/open-lola/plan.json"))
    #expect(status.contains("Counts: written 1, skipped 1, failed 0"))
    #expect(status.contains("Pasteboard copy failed"))
}

@Test
func appOperatorArtifactPanelClearsStaleArtifactForRemoteInputAndFailures() {
    let artifact = NativeAppShellGeneratedArtifactState(
        kind: .twoPeerRunPlan,
        generatedAt: "2026-05-20T12:00:00Z",
        path: "/tmp/open-lola/plan.json",
        clipboardText: "{\"id\":\"old\"}",
        validationSummary: "old plan"
    )
    var panelState = AppOperatorArtifactPanelState()

    panelState.recordGeneratedArtifact(artifact, status: "Generated copyable plan JSON.")
    panelState.clearGeneratedArtifact(status: "Pasted remote inventory JSON. Review and import to validate IDs.")

    #expect(panelState.generatedArtifact == nil)
    #expect(panelState.status.contains("Review and import"))
    #expect(panelState.fileError == nil)

    panelState.recordGeneratedArtifact(artifact, status: "Generated copyable plan JSON.")
    panelState.setFailureStatus("Remote inventory import failed", NativeAppShellArtifactError.emptyClipboardText)

    #expect(panelState.generatedArtifact == nil)
    #expect(panelState.status.contains("Remote inventory import failed"))
    #expect(panelState.fileError == panelState.status)
}

@Test
func appConnectionTopologyAnimationRequiresPacketEvidence() {
    #expect(!AppConnectionTopologyAnimationPolicy.hasPacketEvidence(nil))
    #expect(!AppConnectionTopologyAnimationPolicy.hasPacketEvidence(
        appTopologyCaptureReport(packets: [])
    ))
    #expect(AppConnectionTopologyAnimationPolicy.hasPacketEvidence(appCaptureWithOneAudioPacket()))
    #expect(!AppConnectionTopologyAnimationPolicy.shouldAnimate(
        phase: .supervisorRunning,
        reduceMotion: false,
        packetEvidenceAvailable: false
    ))
    #expect(AppConnectionTopologyAnimationPolicy.shouldAnimate(
        phase: .supervisorRunning,
        reduceMotion: false,
        packetEvidenceAvailable: true
    ))
    #expect(!AppConnectionTopologyAnimationPolicy.shouldAnimate(
        phase: .validationPassed,
        reduceMotion: false,
        packetEvidenceAvailable: true
    ))
    #expect(!AppConnectionTopologyAnimationPolicy.shouldAnimate(
        phase: .runFinished,
        reduceMotion: false,
        packetEvidenceAvailable: true
    ))
    #expect(!AppConnectionTopologyAnimationPolicy.shouldAnimate(
        phase: .supervisorRunning,
        reduceMotion: true,
        packetEvidenceAvailable: true
    ))
}

private func appCaptureWithOneAudioPacket() -> LoLaCompatibilityCaptureReport {
    appTopologyCaptureReport(packets: [
        LoLaCompatibilityCapturePacketReport(
            index: 1,
            capturedLength: 80,
            originalLength: 80,
            stream: .audio,
            network: .init(
                sourceIP: "192.0.2.10",
                destinationIP: "198.51.100.20",
                sourcePort: 7000,
                destinationPort: 7000,
                payloadLength: 48
            ),
            media: .init(envelopeValid: true, payloadCandidate: .rawAudio)
        )
    ])
}

@MainActor
@Test
func appPreviewReceiverControlsRequireVerifiedActiveServiceState() {
    let previewState = AppPreviewReceiverState(videoPreviewEnabled: false)

    previewState.previewPhase = .active
    #expect(!previewState.previewIsActive)

    previewState.startReceiverPreview(audioInputUID: "input", videoDeviceID: nil)
    previewState.audioLevelMeter.phase = .active
    previewState.audioLevelMeter.status = "Meter samples flowing"
    #expect(previewState.verifiedPreviewPhase == .active)
    #expect(previewState.previewIsActive)

    previewState.audioLevelMeter.phase = .failed
    previewState.audioLevelMeter.status = "Audio meter unavailable: test failure"
    #expect(previewState.verifiedPreviewPhase == .failed)
    #expect(!previewState.previewIsActive)
}

@Test
func appPreviewUnsupportedLocalControlsRenderAsStatusCopyNotInputs() throws {
    let receiverSource = try String(contentsOf: appSourcePath("AppPreviewReceiverView.swift"))
    let settingsSource = try String(contentsOf: appSourcePath("AppShellSettingsTabs.swift"))

    for source in [receiverSource, settingsSource] {
        #expect(!source.contains("Text(\"Return blend\")"))
        #expect(!source.contains("IntField(\"Visible streams\""))
        #expect(!source.contains("IntField(\"Selected stream\""))
        #expect(source.contains("AppPreviewDisabledReasonCopy.unsupportedLocalPreviewControls"))
    }
}

@Test
func appSettingsSurfaceDoesNotUseStalePolicyConstants() throws {
    let sectionSources = try [
        "AppShellSectionViews.swift",
        "AppShellDetailView.swift",
        "AppOverviewSectionViews.swift",
        "AppSessionSectionViews.swift"
    ].map { try String(contentsOf: appSourcePath($0)) }

    for sectionSource in sectionSources {
        #expect(!sectionSource.contains("AppShellSettingsSurfacePolicy"))
        #expect(!sectionSource.contains("sidebarUsesReadOnlySummary"))
        #expect(!sectionSource.contains("nativeSettingsSceneUsesMutableEditor"))
    }
}

private func appTopologyCaptureReport(
    packets: [LoLaCompatibilityCapturePacketReport]
) -> LoLaCompatibilityCaptureReport {
    LoLaCompatibilityCaptureReport(
        identity: .init(
            id: "app-topology-capture",
            title: "App topology capture",
            capturedAt: "2026-05-22T00:00:00Z",
            inputPath: "fixtures/topology.pcapng",
            inputFormat: .pcapng
        ),
        content: .init(summary: LoLaCompatibilityCaptureSummary(packets: packets), packets: packets),
        outcome: .init(
            verdict: .partial,
            evidenceBoundary: "unit-test topology packet evidence",
            notes: "Synthetic topology animation policy fixture."
        )
    )
}

private func appSourcePath(_ filename: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/open-lola-app/\(filename)")
}

@Test
func appCommandPreviewKeepsExactCopySeparateFromReviewDisplay() {
    let command = [
        "/Applications/Open LoLa/bin/open-lola",
        "direct-p2p-session-run",
        "--plan",
        "/tmp/open lola/plan's.json",
        "--peer",
        "mac-studio-control-room-with-long-hostname.example.local"
    ]
    let shellLine = AppCommandPreview.shellLine(command)
    let multilineDisplay = AppCommandPreview.multilineDisplay(command)

    #expect(AppCommandPreview.copyText(command) == shellLine)
    #expect(
        shellLine ==
            "'/Applications/Open LoLa/bin/open-lola' direct-p2p-session-run "
            + "--plan '/tmp/open lola/plan'\\''s.json' "
            + "--peer mac-studio-control-room-with-long-hostname.example.local"
    )
    #expect(multilineDisplay != shellLine)
    #expect(multilineDisplay.contains(" \\\n  --plan"))
    #expect(multilineDisplay.contains("'/tmp/open lola/plan'\\''s.json'"))
}

@Test
func appCompactToolButtonSizingProvidesMinimumHitTarget() {
    #expect(AppCompactToolButtonSizing.minimumHitLength == 28)
}

@Test
func appChannelMetersOnlyShowWithActiveLocalPreviewEvidence() {
    #expect(AppChannelMeterVisibilityPolicy.showsMeters(
        phase: .supervisorRunning,
        audioPreviewEnabled: true,
        audioPreviewPhase: .active
    ))
    #expect(AppChannelMeterVisibilityPolicy.showsMeters(
        phase: .idle,
        audioPreviewEnabled: true,
        audioPreviewPhase: .active
    ))
    #expect(!AppChannelMeterVisibilityPolicy.showsMeters(
        phase: .supervisorRunning,
        audioPreviewEnabled: true,
        audioPreviewPhase: .idle
    ))
    #expect(!AppChannelMeterVisibilityPolicy.showsMeters(
        phase: .supervisorRunning,
        audioPreviewEnabled: true,
        audioPreviewPhase: .failed
    ))
    #expect(!AppChannelMeterVisibilityPolicy.showsMeters(
        phase: .supervisorRunning,
        audioPreviewEnabled: false,
        audioPreviewPhase: .active
    ))
}

@Test
func appPreviewVideoOutputStatusReflectsSelectedBlackmagicInventory() {
    let fallback = BlackmagicOutputBoundary.localPreviewFallback()
    let blackmagicDevice = NativeAppShellVideoDeviceOption(
        label: "Blackmagic UltraStudio",
        uniqueId: "blackmagic-output",
        manufacturer: "Blackmagic Design",
        transport: "Thunderbolt",
        sourcePolicy: .blackmagicFirstAvFoundationFallback,
        formatCount: 2
    )
    let genericDevice = NativeAppShellVideoDeviceOption(
        label: "FaceTime HD Camera",
        uniqueId: "generic-camera",
        manufacturer: "Apple",
        transport: "Built-in",
        sourcePolicy: .genericAvFoundation,
        formatCount: 1
    )

    let blackmagicStatus = AppPreviewVideoOutputStatusPolicy.status(
        boundary: fallback,
        selectedVideoDevice: blackmagicDevice
    )
    let genericStatus = AppPreviewVideoOutputStatusPolicy.status(
        boundary: fallback,
        selectedVideoDevice: genericDevice
    )

    #expect(blackmagicStatus.contains("Blackmagic video device selected"))
    #expect(blackmagicStatus.contains("DeckLink output remains unverified"))
    #expect(genericStatus == fallback.outputLimitationSummary)
}

@Test
func appProcessExitDisplayUsesOperatorLanguage() {
    #expect(AppProcessExitDisplay.title(nil) == "none")
    #expect(AppProcessExitDisplay.title(0) == "Exited cleanly")
    #expect(AppProcessExitDisplay.title(15) == "Stopped by operator")
    #expect(AppProcessExitDisplay.title(-15) == "Stopped by operator")
    #expect(AppProcessExitDisplay.title(143) == "Stopped by operator")
    #expect(AppProcessExitDisplay.title(2) == "Unexpected exit (code 2)")
}

@Test
func appLogOpenButtonPolicyExplainsUnavailableLogFiles() {
    let missingReason = AppLogOpenButtonPolicy.disabledReason(
        label: "stdout",
        path: "/tmp/open-lola/missing-stdout.log",
        canOpen: false
    )

    #expect(missingReason == "Stdout log unavailable. No file exists at /tmp/open-lola/missing-stdout.log.")
    #expect(AppLogOpenButtonPolicy.disabledReason(
        label: "stderr",
        path: "/tmp/open-lola/stderr.log",
        canOpen: true
    ) == nil)
    #expect(AppLogOpenButtonPolicy.openHelp(label: "stderr") == "Open stderr log file")
}
