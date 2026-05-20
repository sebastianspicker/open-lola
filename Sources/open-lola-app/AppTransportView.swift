import OpenLolaCore
import SwiftUI

// MARK: - Transport Control Strip

/// Logic Pro-style ARM / DRY RUN / START / STOP transport controls.
struct AppTransportView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let executionController: AppExecutionController
    let plan: AppOperatorPrototypePlan
    let sessionState: AppSessionState

    @State private var showStopConfirmation = false
    @FocusState private var focusedButton: AppTransportFocusedButton?

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            armButton
            AppVerticalDivider(height: 28)
            dryRunButton
            startButton
            stopButton
            AppVerticalDivider(height: 28)
            validateButton
            Spacer(minLength: 0)
            statusPills
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.xs)
        .background(AppDesignSystem.elevatedBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppDesignSystem.panelBorder).frame(height: 1)
        }
        .confirmationDialog(
            AppTransportStopConfirmationPolicy.stopConfirmationTitle,
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                AppTransportStopConfirmationPolicy.stopConfirmationButtonTitle,
                role: .destructive,
                action: requestStop
            )
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(AppTransportStopConfirmationPolicy.stopConfirmationMessage)
        }
    }

    // MARK: - Buttons

    private var armButton: some View {
        Button {
            executionController.armedForExecution.toggle()
        } label: {
            Label(
                executionController.armedForExecution ? "Armed" : "Arm",
                systemImage: executionController.armedForExecution
                    ? "checkmark.shield.fill"
                    : "shield"
            )
            .font(.callout.weight(.semibold))
            .foregroundStyle(executionController.armedForExecution ? AppDesignSystem.onStateFillText : AppDesignSystem.stateArmed)
            .padding(.horizontal, AppSpacing.s)
            .padding(.vertical, AppSpacing.xxs + 2)
            .background(
                executionController.armedForExecution
                    ? AppDesignSystem.stateArmed
                    : AppDesignSystem.stateArmed.opacity(0.12),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(AppDesignSystem.stateArmed.opacity(0.55), lineWidth: 1)
            }
            .overlay {
                transportFocusRing(isFocused: focusedButton == .arm)
            }
            .transportHitTarget()
        }
        .buttonStyle(AppTransportButtonStyle())
        .focused($focusedButton, equals: .arm)
        .keyboardShortcut("e", modifiers: [.command, .shift])
        .disabled(armDisabled)
        .help(armHelp)
    }

    private var dryRunButton: some View {
        Button {
            if prepareExecution() {
                operatorSurface.commandIntent = .handoffRequested
                executionController.dryRun(operatorSurface: operatorSurface)
            }
        } label: {
            Label("Dry Run", systemImage: "play.slash.fill")
                .font(.callout)
                .foregroundStyle(dryRunAvailable ? AppDesignSystem.stateArmed : .secondary)
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, AppSpacing.xxs + 2)
                .background(
                    dryRunAvailable ? AppDesignSystem.stateArmed.opacity(0.10) : Color.secondary.opacity(0.06),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(dryRunAvailable ? AppDesignSystem.stateArmed.opacity(0.30) : Color.secondary.opacity(0.15), lineWidth: 1)
                }
                .overlay {
                    transportFocusRing(isFocused: focusedButton == .dryRun)
                }
                .transportHitTarget()
        }
        .buttonStyle(AppTransportButtonStyle())
        .focused($focusedButton, equals: .dryRun)
        .disabled(!dryRunAvailable)
        .help("Write plan and perform a dry run without executing")
    }

    private var startButton: some View {
        Button {
            guard prepareExecution() else {
                return
            }
            if executionController.startArmed(operatorSurface: operatorSurface) {
                operatorSurface.commandIntent = .runRequested
            } else {
                operatorSurface.commandIntent = .idle
            }
        } label: {
            Label("Start", systemImage: "play.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(startAvailable ? AppDesignSystem.onStateFillText : .secondary)
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, AppSpacing.xxs + 2)
                .background(
                    startAvailable ? AppDesignSystem.stateLive : Color.secondary.opacity(0.2),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(startAvailable ? AppDesignSystem.stateLive.opacity(0.65) : Color.secondary.opacity(0.25), lineWidth: 1)
                }
                .overlay {
                    transportFocusRing(isFocused: focusedButton == .start)
                }
                .transportHitTarget()
        }
        .buttonStyle(AppTransportButtonStyle())
        .focused($focusedButton, equals: .start)
        .disabled(!startAvailable)
        .help(startHelp)
    }

    private var stopButton: some View {
        Button {
            if AppTransportStopConfirmationPolicy.requiresConfirmation(
                isRunning: executionController.isRunning,
                lastRunWasDryRun: executionController.lastRunWasDryRun
            ) {
                showStopConfirmation = true
            } else {
                requestStop()
            }
        } label: {
            Label("Stop", systemImage: "stop.fill")
                .font(.callout)
                .foregroundStyle(executionController.isRunning ? AppDesignSystem.stateError : .secondary)
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, AppSpacing.xxs + 2)
                .background(
                    executionController.isRunning ? AppDesignSystem.stateError.opacity(0.10) : Color.secondary.opacity(0.06),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(executionController.isRunning ? AppDesignSystem.stateError.opacity(0.30) : Color.secondary.opacity(0.15), lineWidth: 1)
                }
                .overlay {
                    transportFocusRing(isFocused: focusedButton == .stop)
                }
                .transportHitTarget()
        }
        .buttonStyle(AppTransportButtonStyle())
        .focused($focusedButton, equals: .stop)
        .disabled(!executionController.isRunning)
        .help("Stop the running session")
    }

    private var validateButton: some View {
        Button {
            executionController.validateReport(operatorSurface: operatorSurface)
        } label: {
            Label("Validate", systemImage: "checkmark.seal")
                .font(.callout)
                .foregroundStyle(validateAvailable ? .primary : .secondary)
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, AppSpacing.xxs + 2)
                .background(Color.secondary.opacity(validateAvailable ? 0.08 : 0.04), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.secondary.opacity(validateAvailable ? 0.25 : 0.12), lineWidth: 1)
                }
                .overlay {
                    transportFocusRing(isFocused: focusedButton == .validate)
                }
                .transportHitTarget()
        }
        .buttonStyle(AppTransportButtonStyle())
        .focused($focusedButton, equals: .validate)
        .disabled(!validateAvailable)
        .help(validateHelp)
    }

    // MARK: - Status pills

    private var statusPills: some View {
        HStack(spacing: AppSpacing.xs) {
            AppStatusBadge(
                title: executionController.status,
                systemImage: executionController.isRunning ? "play.fill" : "circle.fill",
                tone: statusTone
            )
            AppStatusBadge(
                title: statusModeTitle,
                systemImage: "network",
                tone: .blue
            )
            if operatorSurface.commandIntent != .idle {
                AppStatusBadge(
                    title: "Intent: \(AppCommandIntentDisplay.title(operatorSurface.commandIntent))",
                    systemImage: "hand.point.up.left",
                    tone: .secondary
                )
                .help("Current handoff intent: \(operatorSurface.commandIntent.rawValue)")
            }
        }
    }

    // MARK: - Helpers

    private var dryRunAvailable: Bool {
        isWorkflowAvailable && plan.isConfigured && !executionController.isRunning
    }

    private var startAvailable: Bool {
        AppTransportStartPolicy.canStart(
            armedForExecution: executionController.armedForExecution,
            dryRunAvailable: dryRunAvailable,
            lastValidationResult: executionController.lastValidationResult,
            hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence
        )
    }

    private var startHelp: String {
        if executionController.lastValidationResult != .passed || !executionController.hasValidatedRuntimeEvidence {
            return "Run a passing validation with current runtime evidence before starting"
        }
        return startAvailable
            ? "Start session (requires arm)"
            : "Arm and configure all fields before starting"
    }

    private var validateAvailable: Bool {
        executionController.validationReadiness(operatorSurface: operatorSurface).isReady
    }

    private var isWorkflowAvailable: Bool {
        AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: operatorSurface.sessionMode)
    }

    private var armDisabled: Bool {
        AppRuntimeInputLock.mutatingInputsLocked(isRunning: executionController.isRunning) || !isWorkflowAvailable
    }

    private var armHelp: String {
        if !isWorkflowAvailable {
            return "Switch to a supported workflow in Settings to arm execution"
        }
        return executionController.armedForExecution ? "Disarm (⌘⇧E)" : "Arm for execution (⌘⇧E)"
    }

    private var validateHelp: String {
        executionController.validationReadiness(operatorSurface: operatorSurface).unavailableMessage
            ?? "Validate the session report artifact"
    }

    private var statusTone: Color {
        if executionController.isRunning { return AppDesignSystem.stateConnecting }
        if executionController.status.localizedCaseInsensitiveContains("fail") { return AppDesignSystem.stateError }
        return .secondary
    }

    private func prepareExecution() -> Bool {
        switch operatorSurface.sessionMode {
        case .directMacPeer:
            return executionController.writePlanOrLogError(from: operatorSurface)
        case .windowsLoLa:
            return true
        case .jackTrip, .ultraGrid:
            return false
        }
    }

    private func requestStop() {
        operatorSurface.commandIntent = .stopRequested
        executionController.stop()
    }

    @ViewBuilder
    private func transportFocusRing(isFocused: Bool) -> some View {
        if isFocused {
            Capsule()
                .stroke(Color.accentColor, lineWidth: 2)
                .padding(-2)
        }
    }

    private var statusModeTitle: String {
        switch operatorSurface.sessionMode {
        case .directMacPeer:
            return executionController.settings.executionMode.rawValue.uppercased()
        case .windowsLoLa:
            return operatorSurface.sessionMode.displayName.uppercased()
        case .jackTrip, .ultraGrid:
            return "\(operatorSurface.sessionMode.displayName.uppercased()) UNAVAILABLE"
        }
    }
}

private enum AppTransportFocusedButton: Hashable {
    case arm
    case dryRun
    case start
    case stop
    case validate
}

private struct AppTransportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1.0)
    }
}

private extension View {
    func transportHitTarget() -> some View {
        frame(minWidth: 44, minHeight: 44)
            .contentShape(Capsule())
    }
}

enum AppTransportStopConfirmationPolicy {
    static let stopConfirmationTitle = "Stop active supervisor run?"
    static let stopConfirmationButtonTitle = "Stop Supervisor Run"
    static let stopConfirmationMessage = "Stopping ends the current active supervisor run."
    static let quitConfirmationTitle = "Quit while supervisor is running?"
    static let quitConfirmationButtonTitle = "Quit and Stop Supervisor"
    static let quitConfirmationMessage = "A supervisor run is active. Quitting will stop it."

    static func requiresConfirmation(sessionState: AppSessionState) -> Bool {
        switch sessionState {
        case .supervisorRunning, .live:
            return true
        default:
            return false
        }
    }

    static func requiresConfirmation(isRunning: Bool, lastRunWasDryRun: Bool) -> Bool {
        isRunning && !lastRunWasDryRun
    }
}

enum AppTransportWorkflowPolicy {
    static func isWorkflowAvailable(sessionMode: NativeAppShellSessionMode) -> Bool {
        sessionMode.supportsAppExecution
    }
}

enum AppTransportStartPolicy {
    static func canStart(
        armedForExecution: Bool,
        dryRunAvailable: Bool,
        lastValidationResult: AppValidationResult,
        hasValidatedRuntimeEvidence: Bool
    ) -> Bool {
        armedForExecution
            && dryRunAvailable
            && lastValidationResult == .passed
            && hasValidatedRuntimeEvidence
    }
}

enum AppCommandIntentDisplay {
    static func title(_ intent: NativeAppShellOperatorCommandIntent) -> String {
        switch intent {
        case .idle:
            return "Idle"
        case .handoffRequested:
            return "Handoff requested"
        case .startRequested:
            return "Start requested"
        case .runRequested:
            return "Run requested"
        case .stopRequested:
            return "Stop requested"
        }
    }
}
