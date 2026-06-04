import AppKit
import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@Test
func appTransportStopConfirmationCoversActiveNonDryRuns() {
    #expect(AppTransportStopConfirmationPolicy.stopConfirmationTitle == "Stop active supervisor run?")
    #expect(AppTransportStopConfirmationPolicy.stopConfirmationButtonTitle == "Stop Supervisor Run")
    #expect(AppTransportStopConfirmationPolicy.stopConfirmationMessage.contains("active supervisor run"))
    #expect(AppTransportStopConfirmationPolicy.quitConfirmationTitle == "Quit while supervisor is running?")
    #expect(AppTransportStopConfirmationPolicy.quitConfirmationButtonTitle == "Quit and Stop Supervisor")
    #expect(AppTransportStopConfirmationPolicy.quitConfirmationMessage.contains("supervisor run is active"))
    #expect(AppTransportStopConfirmationPolicy.requiresConfirmation(sessionState: .supervisorRunning))
    #expect(!AppTransportStopConfirmationPolicy.requiresConfirmation(sessionState: .armed))
    #expect(!AppTransportStopConfirmationPolicy.requiresConfirmation(sessionState: .dryRunRunning))
    #expect(!AppTransportStopConfirmationPolicy.requiresConfirmation(sessionState: .awaitingEvidence))
    #expect(!AppTransportStopConfirmationPolicy.requiresConfirmation(sessionState: .error))
    #expect(AppTransportStopConfirmationPolicy.requiresConfirmation(isRunning: true, lastRunWasDryRun: false))
    #expect(!AppTransportStopConfirmationPolicy.requiresConfirmation(isRunning: true, lastRunWasDryRun: true))
    #expect(!AppTransportStopConfirmationPolicy.requiresConfirmation(isRunning: false, lastRunWasDryRun: false))
}

@Test
func appTransportStatusToneUsesTypedExecutionPhase() {
    #expect(AppTransportStatusTonePolicy.toneKind(
        isRunning: true,
        phase: .idle
    ) == .connecting)
    #expect(AppTransportStatusTonePolicy.toneKind(
        isRunning: false,
        phase: .failedToStart
    ) == .error)
    #expect(AppTransportStatusTonePolicy.toneKind(
        isRunning: false,
        phase: .validationFailed
    ) == .error)
    #expect(AppTransportStatusTonePolicy.toneKind(
        isRunning: false,
        phase: .runFailed
    ) == .error)
    #expect(AppTransportStatusTonePolicy.toneKind(
        isRunning: false,
        phase: .idle
    ) == .secondary)
}

@Test
func appTransportConnectorStatusNamesRunnableWorkflow() {
    for mode in [NativeAppShellSessionMode.jackTrip, .ultraGrid] {
        #expect(AppTransportStatusModePolicy.title(
            sessionMode: mode,
            executionMode: .local
        ) == mode.displayName.uppercased())
        #expect(AppTransportStatusModePolicy.help(
            sessionMode: mode,
            executionMode: .local
        ) == "Workflow: \(mode.displayName.uppercased())")
    }
}

@Test
func appFooterTransportStripShowsStopOnlyForActiveRuns() {
    #expect(AppFooterTransportPolicy.showsStopButton(isRunning: true))
    #expect(!AppFooterTransportPolicy.showsStopButton(isRunning: false))
    #expect(AppFooterTransportPolicy.stateTitle(
        sessionState: .supervisorRunning,
        armedForExecution: true,
        isRunning: true
    ) == "Active: Supervisor Running")
    #expect(AppFooterTransportPolicy.stateTitle(
        sessionState: .ready,
        armedForExecution: true,
        isRunning: false
    ) == "Armed")
}

@MainActor
@Test
func appTerminationDelegateCancelsOnlyWhenConfirmationIsRequested() {
    let delegate = OpenLolaApplicationDelegate()
    var confirmationRequests = 0
    delegate.requestTerminationConfirmation = {
        confirmationRequests += 1
    }

    delegate.shouldRequestTerminationConfirmation = { false }
    #expect(delegate.applicationShouldTerminate(.shared) == .terminateNow)
    #expect(confirmationRequests == 0)

    delegate.shouldRequestTerminationConfirmation = { true }
    #expect(delegate.applicationShouldTerminate(.shared) == .terminateCancel)
    #expect(confirmationRequests == 1)
}

@Test
func appSessionBannerAccessibilityAnnouncementTargetsKeyStateTransitions() {
    #expect(AppSessionBannerAccessibilityPolicy.announcementMessage(
        state: .armed,
        label: "armed"
    ) == "Session state: Armed. armed")
    #expect(AppSessionBannerAccessibilityPolicy.announcementMessage(
        state: .supervisorRunning,
        label: "running"
    ) == "Session state: Supervisor Running. running")
    #expect(AppSessionBannerAccessibilityPolicy.announcementMessage(
        state: .validated,
        label: "validated"
    ) == "Session state: Evidence Validated. validated")
    #expect(AppSessionBannerAccessibilityPolicy.announcementMessage(
        state: .error,
        label: "failure"
    ) == "Session state: Error. failure")
    #expect(AppSessionBannerAccessibilityPolicy.announcementMessage(
        state: .receiverWarning,
        label: "preview degraded"
    ) == "Session state: Preview Warning. preview degraded")
    #expect(AppSessionBannerAccessibilityPolicy.announcementMessage(state: .ready, label: "ready") == nil)
}

@Test
func appExecutionModeUnavailableHelpUsesOperatorFacingCopy() {
    let help = AppExecutionModeAvailability.unsupportedSettingsHelp

    #expect(
        help == "SSH launch is not available in Settings. Use Local execution here, or copy an SSH supervisor command from the operator artifacts."
    )
    #expect(!help.localizedCaseInsensitiveContains("runtime fallback contract"))
    #expect(!help.localizedCaseInsensitiveContains("orchestration"))
}

@Test
func appPreviewWindowRequestFeedbackDoesNotClaimDisplaySuccess() {
    #expect(AppPreviewWindowRequestFeedback.statusMessage.contains("request sent"))
    #expect(AppPreviewWindowRequestFeedback.statusMessage.contains("Waiting for visible window confirmation"))
    #expect(!AppPreviewWindowRequestFeedback.statusMessage.localizedCaseInsensitiveContains("opened"))
    #expect(AppPreviewWindowRequestFeedback.menuHelp.contains("Request"))
    #expect(AppPreviewWindowRequestFeedback.menuHelp.contains("not confirmed"))
}

@MainActor
@Test
func appPreviewWindowStateReportsRequestVisibleAndHiddenPhases() {
    let previewState = AppPreviewReceiverState()

    #expect(previewState.previewWindowStatus == "Local preview window not requested.")

    previewState.requestPreviewWindow()
    #expect(previewState.previewWindowPhase == .requested)
    #expect(previewState.previewWindowStatus.contains("request sent"))

    previewState.markPreviewWindowVisible()
    #expect(previewState.previewWindowStatus == "Local preview window visible.")

    previewState.markPreviewWindowHidden()
    #expect(previewState.previewWindowStatus == "Local preview window not visible.")
}

@Test
func appCommandIntentDisplayUsesHumanReadableLabels() {
    #expect(AppCommandIntentDisplay.title(.idle) == "Idle")
    #expect(AppCommandIntentDisplay.title(.handoffRequested) == "Handoff requested")
    #expect(AppCommandIntentDisplay.title(.runRequested) == "Run requested")
    #expect(AppCommandIntentDisplay.title(.stopRequested) == "Stop requested")
}

@Test
func appCommandIntentStopControlIsMetadataOnlyWhileRuntimeIsActive() {
    #expect(AppCommandIntentControlPolicy.stopIntentTitle == "Mark Stop Intent")
    #expect(AppCommandIntentControlPolicy.title(for: .handoffRequested) == "Mark Handoff Intent")
    #expect(AppCommandIntentControlPolicy.title(for: .startRequested) == "Mark Start Intent")
    #expect(AppCommandIntentControlPolicy.title(for: .runRequested) == "Mark Run Intent")
    #expect(AppCommandIntentControlPolicy.title(for: .idle) == "Clear Command Intent")
    #expect(AppCommandIntentControlPolicy.stopIntentDisabled(inputsLocked: true))
    #expect(!AppCommandIntentControlPolicy.stopIntentDisabled(inputsLocked: false))
    #expect(AppCommandIntentControlPolicy.stopIntentHelp(
        inputsLocked: true
    ).contains("transport Stop control"))
    #expect(AppCommandIntentControlPolicy.stopIntentHelp(
        inputsLocked: false
    ).contains("metadata"))
    #expect(AppCommandIntentControlPolicy.help(
        for: .startRequested,
        inputsLocked: false
    ).contains("without starting a process"))
    #expect(AppCommandIntentControlPolicy.help(
        for: .runRequested,
        inputsLocked: true
    ) == AppRuntimeInputLock.lockedHelp)
}

@Test
func appTransportStartPolicyRequiresPassingValidationAfterFailure() {
    #expect(!AppTransportStartPolicy.canStart(
        armedForExecution: true,
        dryRunAvailable: true,
        lastValidationResult: .unknown,
        hasValidatedRuntimeEvidence: false
    ))
    #expect(!AppTransportStartPolicy.canStart(
        armedForExecution: true,
        dryRunAvailable: true,
        lastValidationResult: .failed,
        hasValidatedRuntimeEvidence: false
    ))
    #expect(!AppTransportStartPolicy.canStart(
        armedForExecution: true,
        dryRunAvailable: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: false
    ))
    #expect(AppTransportStartPolicy.canStart(
        armedForExecution: true,
        dryRunAvailable: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    ))
    #expect(AppTransportStartPolicy.canStart(
        armedForExecution: true,
        dryRunAvailable: true,
        lastValidationResult: .unknown,
        hasValidatedRuntimeEvidence: false,
        requiresValidatedRuntimeEvidence: false
    ))
}

@Test
func appMenuStartPolicyMatchesTransportStartPolicy() {
    let menuStart = AppMenuActionPolicy.startAvailable(
        sessionMode: .directMacPeer,
        planIsConfigured: true,
        isRunning: false,
        armedForExecution: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    )
    let transportStart = AppTransportStartPolicy.canStart(
        armedForExecution: true,
        dryRunAvailable: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    )

    #expect(menuStart == transportStart)
    #expect(!AppMenuActionPolicy.startAvailable(
        sessionMode: .directMacPeer,
        planIsConfigured: true,
        isRunning: false,
        armedForExecution: true,
        lastValidationResult: .unknown,
        hasValidatedRuntimeEvidence: false
    ))
    #expect(!AppMenuActionPolicy.startAvailable(
        sessionMode: .directMacPeer,
        planIsConfigured: false,
        isRunning: false,
        armedForExecution: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    ))
    #expect(AppMenuActionPolicy.startAvailable(
        sessionMode: .ultraGrid,
        planIsConfigured: true,
        isRunning: false,
        armedForExecution: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    ))
    #expect(!AppMenuActionPolicy.startAvailable(
        sessionMode: .directMacPeer,
        planIsConfigured: true,
        isRunning: true,
        armedForExecution: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    ))
    #expect(AppMenuActionPolicy.armDisabled(sessionMode: .directMacPeer, isRunning: true))
    #expect(!AppMenuActionPolicy.armDisabled(sessionMode: .ultraGrid, isRunning: false))
    #expect(!AppMenuActionPolicy.armDisabled(sessionMode: .directMacPeer, isRunning: false))
}

@Test
func appMenuActionPolicyReportsDisabledRecoveryReasons() {
    #expect(AppMenuActionPolicy.writePlanDisabledReason(
        sessionMode: .windowsLoLa,
        isRunning: false
    )?.contains("Direct Mac Peer") == true)
    #expect(AppMenuActionPolicy.writePlanDisabledReason(
        sessionMode: .directMacPeer,
        isRunning: false
    ) == nil)
    #expect(AppMenuActionPolicy.dryRunDisabledReason(
        sessionMode: .directMacPeer,
        planIsConfigured: false,
        isRunning: false
    )?.contains("Configure") == true)
    #expect(AppMenuActionPolicy.dryRunDisabledReason(
        sessionMode: .ultraGrid,
        planIsConfigured: true,
        isRunning: false
    ) == nil)
    #expect(AppMenuActionPolicy.handoffIntentDisabledReason(
        planIsConfigured: false,
        isRunning: false
    )?.contains("Configure") == true)
    #expect(AppMenuActionPolicy.startDisabledReason(
        sessionMode: .directMacPeer,
        planIsConfigured: true,
        isRunning: false,
        armedForExecution: false,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    ) == "Arm execution before starting.")
    #expect(AppMenuActionPolicy.startDisabledReason(
        sessionMode: .directMacPeer,
        planIsConfigured: true,
        isRunning: false,
        armedForExecution: true,
        lastValidationResult: .unknown,
        hasValidatedRuntimeEvidence: false
    )?.contains("passing validation") == true)
    #expect(AppMenuActionPolicy.startDisabledReason(
        sessionMode: .directMacPeer,
        planIsConfigured: true,
        isRunning: false,
        armedForExecution: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    ) == nil)
    #expect(AppMenuActionPolicy.startDisabledReason(
        sessionMode: .jackTrip,
        planIsConfigured: true,
        isRunning: false,
        armedForExecution: true,
        lastValidationResult: .unknown,
        hasValidatedRuntimeEvidence: false
    ) == nil)
    #expect(AppMenuActionPolicy.stopDisabledReason(isRunning: false) == "No supervisor run is active.")
    #expect(AppMenuActionPolicy.stopDisabledReason(isRunning: true) == nil)
    #expect(AppMenuActionPolicy.validateDisabledReason(
        validationUnavailableMessage: "Load a report before validating."
    ) == "Load a report before validating.")
    #expect(AppMenuActionPolicy.armDisabledReason(
        sessionMode: .ultraGrid,
        isRunning: false
    ) == nil)
}
