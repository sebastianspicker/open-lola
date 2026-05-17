import OpenLolaCore
import SwiftUI

// MARK: - Transport Control Strip

/// Logic Pro-style ARM / DRY RUN / START / STOP transport controls.
struct AppTransportView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let executionController: AppExecutionController
    let plan: AppOperatorPrototypePlan

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
        }
        .buttonStyle(.plain)
        .help(executionController.armedForExecution ? "Disarm (⌘⇧E)" : "Arm for execution (⌘⇧E)")
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
        }
        .buttonStyle(.plain)
        .foregroundStyle(dryRunAvailable ? .primary : .secondary)
        .disabled(!dryRunAvailable)
        .help("Write plan and perform a dry run without executing")
    }

    private var startButton: some View {
        Button {
            guard prepareExecution() else {
                return
            }
            operatorSurface.commandIntent = .runRequested
            executionController.startArmed(operatorSurface: operatorSurface)
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
        }
        .buttonStyle(.plain)
        .disabled(!startAvailable)
        .help(startAvailable
              ? "Start session (requires arm)"
              : "Arm and configure all fields before starting")
    }

    private var stopButton: some View {
        Button {
            operatorSurface.commandIntent = .stopRequested
            executionController.stop()
        } label: {
            Label("Stop", systemImage: "stop.fill")
                .font(.callout)
                .foregroundStyle(executionController.isRunning ? AppDesignSystem.stateError : .secondary)
        }
        .buttonStyle(.plain)
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
        }
        .buttonStyle(.plain)
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
        }
    }

    // MARK: - Helpers

    private var dryRunAvailable: Bool {
        plan.isConfigured && !executionController.isRunning
    }

    private var startAvailable: Bool {
        executionController.armedForExecution && dryRunAvailable
    }

    private var validateAvailable: Bool {
        executionController.validationReadiness(operatorSurface: operatorSurface).isReady
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

    private var statusModeTitle: String {
        switch operatorSurface.sessionMode {
        case .directMacPeer:
            return executionController.settings.executionMode.rawValue.uppercased()
        case .windowsLoLa:
            return "LOLA"
        case .jackTrip, .ultraGrid:
            return "\(operatorSurface.sessionMode.displayName.uppercased()) UNAVAILABLE"
        }
    }
}
