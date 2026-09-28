// Supplies transport-view formatting and actions, keeping presentational helpers out of the view body.
import SwiftUI

extension AppTransportView {
    var armButton: some View {
        Button {
            executionController.armedForExecution.toggle()
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: executionController.armedForExecution ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(AppDesignSystem.interactionAccent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Arm this run")
                        .font(.callout.weight(.semibold))
                    Text(executionController.armedForExecution ? "Ready to start" : "Allows capture and transmission")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 164, minHeight: 38, alignment: .leading)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("e", modifiers: [.command, .shift])
        .disabled(armDisabled)
        .help(armHelp)
        .accessibilityLabel("Arm this run")
        .accessibilityValue(executionController.armedForExecution ? "Armed" : "Not armed")
        .accessibilityHint(armHelp)
    }

    var startButton: some View {
        Button(action: startSession) {
            HStack(spacing: AppSpacing.xs) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(AppDesignSystem.signalAccent)
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
                Text("Start run")
                Image(systemName: "arrow.right")
                    .accessibilityHidden(true)
            }
            .font(.callout.weight(.semibold))
            .frame(minWidth: 164, minHeight: 36)
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
            HStack(spacing: AppSpacing.xs) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(AppDesignSystem.stateError)
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
                Text("Stop run")
            }
            .font(.callout.weight(.semibold))
            .frame(minWidth: 164, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(AppDesignSystem.stateError)
        .help("Stop the active session")
    }

    @ViewBuilder
    var runControl: some View {
        if executionController.isRunning {
            stopButton
        } else {
            startButton
        }
    }

    var moreActionsMenu: some View {
        Menu {
            Button("Dry Run", systemImage: "play.slash.fill", action: performDryRun)
                .disabled(!dryRunAvailable)
                .help(dryRunAvailable ? "Prepare the route without starting media" : dryRunUnavailableHelp)
            Button("Validate Report", systemImage: "checkmark.seal", action: validateReport)
                .disabled(!validateAvailable)
                .help(validateHelp)
        } label: {
            Label("More", systemImage: "ellipsis")
                .frame(minWidth: 60, minHeight: 36)
        }
        .menuStyle(.borderedButton)
        .fixedSize()
        .help("Dry run and report validation")
        .accessibilityLabel("More run actions")
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
