enum AppRuntimeInputLock {
    static let lockedHelp = "Runtime inputs are locked while a process is active."

    static func mutatingInputsLocked(isRunning: Bool) -> Bool {
        isRunning
    }

    static func canStop(isRunning: Bool) -> Bool {
        isRunning
    }
}
