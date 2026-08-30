// Supplies transport-view formatting and actions, keeping presentational helpers out of the view body.
import SwiftUI

extension AppTransportView {
    var armButton: some View {
        Button {
            executionController.armedForExecution.toggle()
        } label: {
            Label(
                executionController.armedForExecution ? "Armed" : "Arm",
                systemImage: executionController.armedForExecution ? "checkmark.shield.fill" : "shield"
            )
            .frame(minWidth: 80, minHeight: 30)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(AppDesignSystem.stateArmed)
        .keyboardShortcut("e", modifiers: [.command, .shift])
        .disabled(armDisabled)
        .help(armHelp)
        .accessibilityHint(armHelp)
    }

    var dryRunButton: some View {
        Button(action: performDryRun) {
            Label("Dry Run", systemImage: "play.slash.fill")
                .frame(minWidth: 80, minHeight: 30)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(!dryRunAvailable)
        .help(dryRunAvailable ? "Prepare the route without starting media" : dryRunUnavailableHelp)
    }

    var startButton: some View {
        Button(action: startSession) {
            Label("Start", systemImage: "play.fill")
                .fontWeight(.semibold)
                .frame(minWidth: 80, minHeight: 30)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .tint(AppDesignSystem.interactionAccent)
        .disabled(!startAvailable)
        .help(startHelp)
        .accessibilityHint(startHelp)
    }

    var stopButton: some View {
        Button(role: .destructive, action: requestStopWithConfirmation) {
            Label("Stop", systemImage: "stop.fill")
                .frame(minWidth: 80, minHeight: 30)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(AppDesignSystem.stateError)
        .disabled(!executionController.isRunning)
        .help(executionController.isRunning ? "Stop the active session" : "No session is running")
    }

    var validateButton: some View {
        Button(action: validateReport) {
            Label("Validate", systemImage: "checkmark.seal")
                .frame(minWidth: 80, minHeight: 30)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(!validateAvailable)
        .help(validateHelp)
    }

    var routeSummary: String {
        let mode = plan.sessionMode.displayName
        let local = plan.topologyLocalPeer.trimmingCharacters(in: .whitespacesAndNewlines)
        let remote = plan.topologyRemotePeer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !local.isEmpty, !remote.isEmpty {
            return "\(mode) · \(local) → \(remote)"
        }
        if !remote.isEmpty {
            return "\(mode) · \(remote)"
        }
        if !local.isEmpty {
            return "\(mode) · \(local)"
        }
        return mode
    }

    var evidenceStatusTitle: String {
        if executionController.hasValidatedRuntimeEvidence {
            return "Measured · Validated"
        }
        if executionController.lastValidationExitCode == 0 {
            return "Evidence incomplete"
        }
        if executionController.lastValidationExitCode != nil {
            return "Validation failed"
        }
        return "Not measured"
    }

    var evidenceStatusTone: Color {
        if executionController.hasValidatedRuntimeEvidence {
            return AppDesignSystem.stateLive
        }
        if executionController.lastValidationExitCode != nil {
            return AppDesignSystem.stateWarning
        }
        return .secondary
    }

    var dryRunAvailable: Bool {
        isWorkflowAvailable && plan.isConfigured && !executionController.isRunning
    }

    var startAvailable: Bool {
        AppTransportStartPolicy.canStart(
            armedForExecution: executionController.armedForExecution,
            dryRunAvailable: dryRunAvailable,
            lastValidationResult: executionController.lastValidationResult,
            hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence,
            requiresValidatedRuntimeEvidence: !operatorSurface.sessionMode.usesPostRunValidationStart
        )
    }

    var validateAvailable: Bool {
        executionController.validationReadiness(operatorSurface: operatorSurface).isReady
    }

    var isWorkflowAvailable: Bool {
        AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: operatorSurface.sessionMode)
    }

    var armDisabled: Bool {
        AppRuntimeInputLock.mutatingInputsLocked(isRunning: executionController.isRunning) || !isWorkflowAvailable
    }

    var armHelp: String {
        if !isWorkflowAvailable {
            return "Choose a supported workflow before arming"
        }
        return executionController.armedForExecution ? "Disarm session" : "Arm session for an explicit start"
    }

    var startHelp: String {
        if operatorSurface.sessionMode.usesPostRunValidationStart {
            return startAvailable
                ? "Start the configured session; validate its report after the run"
                : "Configure and arm the session before starting"
        }
        if executionController.lastValidationResult != .passed
            || !executionController.hasValidatedRuntimeEvidence {
            return "Validate current runtime evidence before starting"
        }
        return startAvailable ? "Start the armed session" : "Arm the configured session before starting"
    }

    var dryRunUnavailableHelp: String {
        if executionController.isRunning { return "Stop the active session before a dry run" }
        if !isWorkflowAvailable { return "Choose a supported workflow before a dry run" }
        return "Complete the route configuration before a dry run"
    }

    var validateHelp: String {
        executionController.validationReadiness(operatorSurface: operatorSurface).unavailableMessage
            ?? "Validate the latest session report"
    }

    func performDryRun() {
        if executionController.prepareExecution(from: operatorSurface) {
            operatorSurface.commandIntent = .handoffRequested
            executionController.dryRun(operatorSurface: operatorSurface)
        }
    }

    func startSession() {
        guard executionController.prepareExecution(from: operatorSurface) else { return }
        if executionController.startArmed(operatorSurface: operatorSurface) {
            operatorSurface.commandIntent = .runRequested
        } else {
            operatorSurface.commandIntent = .idle
        }
    }

    func validateReport() {
        executionController.validateReport(operatorSurface: operatorSurface)
    }

    func requestStopWithConfirmation() {
        if AppTransportStopConfirmationPolicy.requiresConfirmation(
            isRunning: executionController.isRunning,
            lastRunWasDryRun: executionController.lastRunWasDryRun
        ) {
            showStopConfirmation = true
        } else {
            requestStop()
        }
    }

    func requestStop() {
        operatorSurface.commandIntent = .stopRequested
        executionController.stop()
    }
}
