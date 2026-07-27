// Derives when runtime controls must be locked, centralizing safety rules for active execution.
enum AppRuntimeInputLock {
    static let lockedHelp = "Runtime inputs are locked while a process is active."
    static let validationLockedHelp = "Settings locked while validation is running."

    static func mutatingInputsLocked(isRunning: Bool) -> Bool {
        isRunning
    }

    static func canStop(isRunning: Bool) -> Bool {
        isRunning
    }

    static func reason(phase: AppExecutionPhase, isRunning: Bool) -> String? {
        guard isRunning else {
            return nil
        }
        return phase == .validationRunning ? validationLockedHelp : lockedHelp
    }
}
