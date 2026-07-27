// Defines AppTransportPolicies decision policy, keeping selection rules independent from UI and execution flow.
import OpenLolaCore
import SwiftUI

enum AppTransportStopConfirmationPolicy {
    static let stopConfirmationTitle = "Stop active supervisor run?"
    static let stopConfirmationButtonTitle = "Stop Supervisor Run"
    static let stopConfirmationMessage = "Stopping ends the current active supervisor run."
    static let quitConfirmationTitle = "Quit while supervisor is running?"
    static let quitConfirmationButtonTitle = "Quit and Stop Supervisor"
    static let quitConfirmationMessage = "A supervisor run is active. Quitting will stop it."

    static func requiresConfirmation(sessionState: AppSessionState) -> Bool {
        switch sessionState {
        case .supervisorRunning:
            return true
        default:
            return false
        }
    }

    static func requiresConfirmation(isRunning: Bool, lastRunWasDryRun: Bool) -> Bool {
        isRunning && !lastRunWasDryRun
    }
}

enum AppTransportStatusToneKind: Equatable {
    case connecting
    case error
    case secondary

    var color: Color {
        switch self {
        case .connecting: AppDesignSystem.stateConnecting
        case .error: AppDesignSystem.stateError
        case .secondary: .secondary
        }
    }
}

enum AppTransportStatusTonePolicy {
    static func toneKind(
        isRunning: Bool,
        phase: AppExecutionPhase
    ) -> AppTransportStatusToneKind {
        if isRunning {
            return .connecting
        }
        switch phase {
        case .failedToStart, .runFailed, .validationFailed:
            return .error
        default:
            return .secondary
        }
    }
}

enum AppTransportWorkflowPolicy {
    static func isWorkflowAvailable(sessionMode: NativeAppShellSessionMode) -> Bool {
        sessionMode.supportsAppExecution
    }
}

enum AppTransportStatusModePolicy {
    static func title(
        sessionMode: NativeAppShellSessionMode,
        executionMode: DirectPeerTwoPeerRunExecutionMode
    ) -> String {
        switch sessionMode {
        case .directMacPeer:
            return executionMode.rawValue.uppercased()
        case .windowsLoLa, .jackTrip, .ultraGrid:
            return sessionMode.displayName.uppercased()
        }
    }

    static func help(
        sessionMode: NativeAppShellSessionMode,
        executionMode: DirectPeerTwoPeerRunExecutionMode
    ) -> String {
        if let unavailableReason = sessionMode.unavailableAppReason {
            return unavailableReason
        }
        return "Workflow: \(title(sessionMode: sessionMode, executionMode: executionMode))"
    }
}

enum AppTransportStartPolicy {
    static func canStart(
        armedForExecution: Bool,
        dryRunAvailable: Bool,
        lastValidationResult: AppValidationResult,
        hasValidatedRuntimeEvidence: Bool,
        requiresValidatedRuntimeEvidence: Bool = true
    ) -> Bool {
        let evidenceReady = !requiresValidatedRuntimeEvidence
            || (lastValidationResult == .passed && hasValidatedRuntimeEvidence)
        return armedForExecution
            && dryRunAvailable
            && evidenceReady
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
