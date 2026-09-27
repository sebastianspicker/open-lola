// Exercises Quiet navigation and its evidence boundaries without launching an operator session.
import Foundation
import OpenLolaCore
import XCTest
@testable import OpenLolaAppSupport

@MainActor
final class AppQuietNavigationTests: XCTestCase {
    func testWorkspaceSectionsResolveToTheirPresentationPhase() {
        XCTAssertEqual(quietPhase(.devices), .setup)
        XCTAssertEqual(quietPhase(.routing), .setup)
        XCTAssertEqual(quietPhase(.settings), .setup)
        XCTAssertEqual(quietPhase(.streams), .live)
        XCTAssertEqual(quietPhase(.diagnostics), .review)
        XCTAssertEqual(quietPhase(.validation), .review)
        XCTAssertEqual(quietPhase(.packetMonitor), .review)
        XCTAssertEqual(quietPhase(.session, requested: .live, current: .ready), .live)
        XCTAssertEqual(quietPhase(.overview, requested: nil, current: .review), .review)
    }

    func testNavigationDoesNotGrantStartOrStopPermission() {
        let readiness = AppStartReadiness(
            sessionMode: .directMacPeer,
            planIsConfigured: true,
            isRunning: false,
            armedForExecution: false,
            lastValidationResult: .unknown,
            hasValidatedRuntimeEvidence: false
        )

        XCTAssertEqual(quietPhase(.streams, requested: .live, current: .ready), .live)
        XCTAssertFalse(AppMenuActionPolicy.startAvailable(readiness))
        XCTAssertNotNil(AppMenuActionPolicy.startDisabledReason(readiness))
        XCTAssertEqual(
            AppMenuActionPolicy.stopDisabledReason(isRunning: false),
            "No supervisor run is active."
        )
    }

    func testSyntheticSourceReportDoesNotBecomeValidatedRuntimeEvidence() {
        let sourceReport = NativeAppShellSyntheticSmoke.run()
        XCTAssertEqual(sourceReport.runMode, .synthetic)
        XCTAssertEqual(sourceReport.verdict, .partial)
        XCTAssertFalse(AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
            executionKind: .directMacPeer,
            validationExitCode: 0,
            directPeerLatencyMetrics: nil,
            externalConnectorReport: nil
        ))
    }

    func testRuntimeEvidenceInvalidationRetainsIntentOnlyChangesAndCatchesConfigurationChanges() {
        let original = configuredOfflineSurface()
        var intentOnly = original
        intentOnly.commandIntent = .runRequested
        XCTAssertFalse(AppRuntimeEvidenceInvalidationPolicy.shouldInvalidateRuntimeEvidence(
            oldSurface: original,
            newSurface: intentOnly
        ))

        var configurationChanged = original
        configurationChanged.inventory.hostName = "changed-fixture-host"
        XCTAssertTrue(AppRuntimeEvidenceInvalidationPolicy.shouldInvalidateRuntimeEvidence(
            oldSurface: original,
            newSurface: configurationChanged
        ))
    }

    func testExistingPaletteContrastContractsRemainSatisfied() {
        XCTAssertTrue(AppDesignSystem.appBackgroundMeetsSecondaryTextContrast)
        XCTAssertTrue(AppDesignSystem.interactionAccentMeetsLightModeTextContrast)
        XCTAssertGreaterThanOrEqual(
            AppDesignSystem.statusBadgeMinimumTextContrastRatio,
            AppDesignSystem.minimumNormalTextContrastRatio
        )
        XCTAssertGreaterThanOrEqual(
            AppDesignSystem.warningBannerMinimumTextContrastRatio,
            AppDesignSystem.minimumNormalTextContrastRatio
        )
    }

    func testOfflineConfiguredFixtureCanProduceAPlanWithoutExecutingIt() {
        XCTAssertTrue(AppOperatorPrototypePlan.make(operatorSurface: configuredOfflineSurface()).isConfigured)
    }

    func testJackTripDeviceRequirementsDoNotRequireVideoInput() {
        var surface = configuredOfflineSurface()
        surface.sessionMode = .jackTrip

        let requirements = AppRequiredDevicePolicy.requirements(for: surface)

        XCTAssertTrue(requirements.audioInput)
        XCTAssertTrue(requirements.audioOutput)
        XCTAssertFalse(requirements.videoInput)
        XCTAssertFalse(AppQuietSessionSummary(
            surface: surface,
            plan: AppOperatorPrototypePlan.make(operatorSurface: surface)
        ).rows.contains { $0.label == "Camera" })
    }

    func testAutomaticNavigationOnlyFollowsActualRunLifecycle() {
        XCTAssertEqual(AppQuietNavigationPolicy.automaticPhase(after: .supervisorRunning), .live)
        XCTAssertEqual(AppQuietNavigationPolicy.automaticPhase(after: .dryRunRunning), .live)
        XCTAssertEqual(AppQuietNavigationPolicy.automaticPhase(after: .runFinished), .review)
        XCTAssertEqual(AppQuietNavigationPolicy.automaticPhase(after: .runFailed), .review)
        XCTAssertEqual(AppQuietNavigationPolicy.automaticPhase(after: .failedToStart), .review)

        XCTAssertNil(AppQuietNavigationPolicy.automaticPhase(after: .validationRunning))
        XCTAssertNil(AppQuietNavigationPolicy.automaticPhase(after: .validationPassed))
        XCTAssertNil(AppQuietNavigationPolicy.automaticPhase(after: .validationFailed))
    }
}

private func quietPhase(
    _ section: NativeAppShellSurfaceSectionID,
    requested: AppSessionPhase? = nil,
    current: AppSessionPhase = .ready
) -> AppSessionPhase {
    AppQuietNavigationPolicy.phase(section: section, requested: requested, current: current)
}

func configuredOfflineSurface() -> NativeAppShellOperatorPrototypeState {
    let audio = NativeAppShellAudioDeviceOption(
        name: "Synthetic offline audio interface",
        uid: "synthetic-offline-audio",
        inputChannelCount: 64,
        outputChannelCount: 64,
        nominalSampleRateHertz: 48_000,
        currentBufferFrameSize: 32
    )
    let video = NativeAppShellVideoDeviceOption(
        label: "Synthetic offline video source",
        uniqueId: "synthetic-offline-video",
        manufacturer: "Open LoLa test fixture",
        transport: "offline",
        sourcePolicy: .genericAvFoundation,
        formatCount: 1
    )
    let selection = NativeAppShellLocalMediaSelection(
        audioInputUID: audio.uid,
        audioOutputUID: audio.uid,
        videoDeviceID: video.uniqueId
    )
    let local = NativeAppShellLocalMediaInventory(
        capturedAt: "synthetic-offline-fixture",
        hostName: "offline-local",
        audioDevices: [audio],
        videoDevices: [video],
        selection: selection,
        inventoryErrors: []
    )
    let remote = NativeAppShellLocalMediaInventory(
        capturedAt: "synthetic-offline-fixture",
        hostName: "offline-remote",
        audioDevices: [audio],
        videoDevices: [video],
        selection: selection,
        inventoryErrors: []
    )
    return NativeAppShellOperatorPrototypeState(
        workflow: .init(
            commandIntent: .idle,
            remoteOrchestrationEnabled: false,
            startsLongRunningProcess: false
        ),
        inventories: .init(local: local, remote: remote)
    )
}
