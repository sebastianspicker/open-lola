import OpenLolaCore

enum AppMenuActionPolicy {
    static func writePlanDisabledReason(
        sessionMode: NativeAppShellSessionMode,
        isRunning: Bool
    ) -> String? {
        if isRunning {
            return AppRuntimeInputLock.lockedHelp
        }
        if sessionMode != .directMacPeer {
            return "Switch to Direct Mac Peer mode to write a two-peer plan."
        }
        return nil
    }

    static func dryRunAvailable(
        sessionMode: NativeAppShellSessionMode,
        planIsConfigured: Bool,
        isRunning: Bool
    ) -> Bool {
        AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: sessionMode)
            && planIsConfigured
            && !isRunning
    }

    static func dryRunDisabledReason(
        sessionMode: NativeAppShellSessionMode,
        planIsConfigured: Bool,
        isRunning: Bool
    ) -> String? {
        if isRunning {
            return "Stop or let the current run complete before dry running again."
        }
        if !AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: sessionMode) {
            return "Switch to a supported workflow in Settings to dry run."
        }
        if !planIsConfigured {
            return "Configure local and remote session fields before dry run."
        }
        return nil
    }

    static func handoffIntentDisabledReason(
        planIsConfigured: Bool,
        isRunning: Bool
    ) -> String? {
        if isRunning {
            return AppRuntimeInputLock.lockedHelp
        }
        if !planIsConfigured {
            return "Configure local and remote session fields before setting handoff intent."
        }
        return nil
    }

    static func startAvailable(_ readiness: AppStartReadiness) -> Bool {
        AppTransportStartPolicy.canStart(
            armedForExecution: readiness.armedForExecution,
            dryRunAvailable: dryRunAvailable(
                sessionMode: readiness.sessionMode,
                planIsConfigured: readiness.planIsConfigured,
                isRunning: readiness.isRunning
            ),
            lastValidationResult: readiness.lastValidationResult,
            hasValidatedRuntimeEvidence: readiness.hasValidatedRuntimeEvidence,
            requiresValidatedRuntimeEvidence: !readiness.sessionMode.usesPostRunValidationStart
        )
    }

    static func startDisabledReason(_ readiness: AppStartReadiness) -> String? {
        if readiness.isRunning {
            return "Stop or let the current run complete before starting another run."
        }
        if !AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: readiness.sessionMode) {
            return "Switch to a supported workflow in Settings before starting."
        }
        if !readiness.planIsConfigured {
            return "Configure local and remote session fields before starting."
        }
        if !readiness.armedForExecution {
            return "Arm execution before starting."
        }
        if !readiness.sessionMode.usesPostRunValidationStart,
           readiness.lastValidationResult != .passed || !readiness.hasValidatedRuntimeEvidence {
            return "Run a passing validation with current runtime evidence before starting."
        }
        return nil
    }

    static func stopDisabledReason(isRunning: Bool) -> String? {
        isRunning ? nil : "No supervisor run is active."
    }

    static func validateDisabledReason(validationUnavailableMessage: String?) -> String? {
        validationUnavailableMessage
    }

    static func armDisabled(
        sessionMode: NativeAppShellSessionMode,
        isRunning: Bool
    ) -> Bool {
        AppRuntimeInputLock.mutatingInputsLocked(isRunning: isRunning)
            || !AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: sessionMode)
    }

    static func armDisabledReason(
        sessionMode: NativeAppShellSessionMode,
        isRunning: Bool
    ) -> String? {
        if AppRuntimeInputLock.mutatingInputsLocked(isRunning: isRunning) {
            return AppRuntimeInputLock.lockedHelp
        }
        if !AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: sessionMode) {
            return "Switch to a supported workflow in Settings to arm execution."
        }
        return nil
    }
}
