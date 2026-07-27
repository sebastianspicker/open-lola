// Validates AppSessionStatePolicy acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import OpenLolaCore

extension AppSessionState {
    static func derive(_ input: AppSessionStateDerivationInput) -> AppSessionState {
        if let runningState = runningState(input) {
            return runningState
        }
        if let phaseState = terminalPhaseState(input) {
            return phaseState
        }
        if let exitState = exitCodeState(input) {
            return exitState
        }
        return configuredState(input)
    }

    private static func runningState(_ input: AppSessionStateDerivationInput) -> AppSessionState? {
        guard input.isRunning else {
            return nil
        }
        switch input.phase {
        case .dryRunRunning:
            return .dryRunRunning
        case .validationRunning:
            return .validating
        default:
            return .supervisorRunning
        }
    }

    private static func terminalPhaseState(_ input: AppSessionStateDerivationInput) -> AppSessionState? {
        switch input.phase {
        case .runFailed, .validationFailed, .failedToStart:
            return .error
        case .stopRequested:
            return input.isConfigured ? .ready : .unconfigured
        case .runFinished, .validationPassed:
            return completedState(hasValidatedRuntimeEvidence: input.hasValidatedRuntimeEvidence)
        default:
            return nil
        }
    }

    private static func exitCodeState(_ input: AppSessionStateDerivationInput) -> AppSessionState? {
        guard let code = input.lastExitCode else {
            return nil
        }
        guard code == 0 else {
            return .error
        }
        return completedState(hasValidatedRuntimeEvidence: input.hasValidatedRuntimeEvidence)
    }

    private static func configuredState(_ input: AppSessionStateDerivationInput) -> AppSessionState {
        guard input.isConfigured else {
            return .unconfigured
        }
        if input.commandIntent == .handoffRequested { return .connecting }
        if input.isArmed { return .armed }
        return .ready
    }

    private static func completedState(hasValidatedRuntimeEvidence: Bool) -> AppSessionState {
        hasValidatedRuntimeEvidence ? .validated : .awaitingEvidence
    }
}

struct AppSessionStateDerivationInput {
    let isRunning: Bool
    let isArmed: Bool
    let lastExitCode: Int?
    let isConfigured: Bool
    let commandIntent: NativeAppShellOperatorCommandIntent
    let phase: AppExecutionPhase
    var hasValidatedRuntimeEvidence: Bool = false
}
