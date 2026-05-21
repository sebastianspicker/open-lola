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
    #expect(AppTransportStopConfirmationPolicy.requiresConfirmation(sessionState: .live))
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
func appSessionBannerAccessibilityAnnouncementTargetsErrorAndPreviewWarningOnly() {
    #expect(AppSessionBannerAccessibilityPolicy.announcementMessage(
        state: .error,
        label: "failure"
    ) == "Session state: Error. failure")
    #expect(AppSessionBannerAccessibilityPolicy.announcementMessage(
        state: .receiverWarning,
        label: "preview degraded"
    ) == "Session state: Preview Warning. preview degraded")
    #expect(AppSessionBannerAccessibilityPolicy.announcementMessage(state: .live, label: "live") == nil)
    #expect(AppSessionBannerAccessibilityPolicy.announcementMessage(state: .ready, label: "ready") == nil)
}

@Test
func appPreviewWindowRequestFeedbackDoesNotClaimDisplaySuccess() {
    #expect(AppPreviewWindowRequestFeedback.statusMessage.contains("request sent"))
    #expect(AppPreviewWindowRequestFeedback.statusMessage.contains("not confirmed"))
    #expect(AppPreviewWindowRequestFeedback.statusMessage.contains("reopen Local Preview"))
    #expect(!AppPreviewWindowRequestFeedback.statusMessage.localizedCaseInsensitiveContains("opened"))
    #expect(AppPreviewWindowRequestFeedback.menuHelp.contains("Request"))
    #expect(AppPreviewWindowRequestFeedback.menuHelp.contains("not confirmed"))
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
    #expect(!AppMenuActionPolicy.startAvailable(
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
    #expect(AppMenuActionPolicy.armDisabled(sessionMode: .ultraGrid, isRunning: false))
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
    )?.contains("supported workflow") == true)
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
    #expect(AppMenuActionPolicy.stopDisabledReason(isRunning: false) == "No supervisor run is active.")
    #expect(AppMenuActionPolicy.stopDisabledReason(isRunning: true) == nil)
    #expect(AppMenuActionPolicy.validateDisabledReason(
        validationUnavailableMessage: "Load a report before validating."
    ) == "Load a report before validating.")
    #expect(AppMenuActionPolicy.armDisabledReason(
        sessionMode: .ultraGrid,
        isRunning: false
    )?.contains("supported workflow") == true)
}
