import Darwin
import Foundation
import os

private let externalConnectorTerminateGraceSeconds: TimeInterval = 2
private let externalConnectorWaitStatusSignalMask: Int32 = 0x7f
private let externalConnectorWaitStatusStoppedMarker: Int32 = 0x7f
private let externalConnectorWaitStatusExitCodeShift: Int32 = 8

struct ExternalConnectorProcessRunConfiguration: Sendable {
    var executable: String
    var arguments: [String]
    var environment: [String: String]
    var durationSeconds: Int?

    init(
        executable: String,
        arguments: [String],
        environment: [String: String] = [:],
        durationSeconds: Int? = nil
    ) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.durationSeconds = durationSeconds
    }
}

struct RunningExternalConnectorProcess {
    var processIdentifier: pid_t
    var processGroupIdentifier: pid_t
    var stdout: BoundedPipeCapture
    var stderr: BoundedPipeCapture
    private var status: Int32?
    private var statusKnown: Bool

    init(
        processIdentifier: pid_t,
        processGroupIdentifier: pid_t,
        stdout: Pipe,
        stderr: Pipe
    ) {
        self.processIdentifier = processIdentifier
        self.processGroupIdentifier = processGroupIdentifier
        self.stdout = BoundedPipeCapture(pipe: stdout, limit: 4096, mode: .characters)
        self.stderr = BoundedPipeCapture(pipe: stderr, limit: 4096, mode: .characters)
        status = nil
        statusKnown = true
    }

    mutating func reapAndCheckRunning() -> Bool {
        reapIfExited(options: WNOHANG) == nil && statusKnown
    }

    var terminationStatus: Int32? {
        mutating get {
            externalConnectorExitStatus(from: waitUntilExitStatus())
        }
    }

    var waitStatusKnown: Bool {
        mutating get {
            _ = waitUntilExitStatus()
            return statusKnown
        }
    }

    @discardableResult
    mutating func waitUntilExitStatus() -> Int32? {
        if let status {
            return status
        }
        if !statusKnown {
            return nil
        }
        while true {
            var nextStatus: Int32 = 0
            let result = waitpid(processIdentifier, &nextStatus, 0)
            if result == processIdentifier {
                status = nextStatus
                return nextStatus
            }
            if result == -1, errno == EINTR {
                continue
            }
            if result == -1, errno == ECHILD {
                statusKnown = false
                status = nil
                return nil
            }
            status = nextStatus
            return nextStatus
        }
    }

    @discardableResult
    private mutating func reapIfExited(options: Int32) -> Int32? {
        if let status {
            return status
        }
        if !statusKnown {
            return nil
        }
        var nextStatus: Int32 = 0
        let result = waitpid(processIdentifier, &nextStatus, options)
        if result == processIdentifier {
            status = nextStatus
            return nextStatus
        }
        if result == -1, errno == ECHILD {
            statusKnown = false
            status = nil
            return nil
        }
        return nil
    }
}

func startExternalConnectorProcess(
    _ configuration: ExternalConnectorProcessRunConfiguration
) throws -> RunningExternalConnectorProcess {
    let stdout = Pipe()
    let stderr = Pipe()
    let processIdentifier = try spawnExternalConnectorProcess(
        executable: configuration.executable,
        arguments: configuration.arguments,
        environment: configuration.environment,
        stdout: stdout,
        stderr: stderr
    )
    return RunningExternalConnectorProcess(
        processIdentifier: processIdentifier,
        processGroupIdentifier: processIdentifier,
        stdout: stdout,
        stderr: stderr
    )
}

func runExternalConnectorProcess(
    _ configuration: ExternalConnectorProcessRunConfiguration
) -> ExternalConnectorProcessResult {
    do {
        var running = try startExternalConnectorProcess(configuration)
        let lifecycle = waitForExternalConnectorProcess(
            &running,
            durationSeconds: configuration.durationSeconds
        )
        return ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: running.processIdentifier,
            exitStatus: running.terminationStatus,
            terminatedAfterDuration: lifecycle.terminatedAfterDuration,
            standardOutputPrefix: externalConnectorPipePrefix(running.stdout),
            standardErrorPrefix: externalConnectorPipePrefix(running.stderr),
            waitStatusKnown: running.waitStatusKnown,
            cleanupStatus: lifecycle.cleanupStatus
        )
    } catch {
        return ExternalConnectorProcessResult(
            launched: false,
            error: String(describing: error)
        )
    }
}

func waitForExternalConnectorProcess(
    _ running: inout RunningExternalConnectorProcess,
    durationSeconds: Int?
) -> (terminatedAfterDuration: Bool, cleanupStatus: String) {
    guard let durationSeconds else {
        running.waitUntilExitStatus()
        let cleanupStatus = cleanupExternalConnectorProcessGroup(&running)
        return (false, cleanupStatus)
    }

    let deadline = MonotonicDeadline(seconds: TimeInterval(max(1, durationSeconds)))
    _ = externalConnectorWaitForExit(
        processIdentifier: running.processIdentifier,
        timeout: deadline.remainingSeconds
    )
    let stillRunningAtDeadline = running.reapAndCheckRunning()
    if stillRunningAtDeadline {
        terminateExternalConnectorProcessGroup(&running)
    }
    running.waitUntilExitStatus()
    let cleanupStatus = cleanupExternalConnectorProcessGroup(&running)
    return (stillRunningAtDeadline, cleanupStatus)
}

func terminateExternalConnectorProcessGroup(_ running: inout RunningExternalConnectorProcess) {
    guard running.reapAndCheckRunning(),
          externalConnectorProcessGroupMatchesProcess(
              running.processGroupIdentifier,
              processIdentifier: running.processIdentifier
          ) else {
        return
    }
    let termResult = kill(-running.processGroupIdentifier, SIGTERM)
    if termResult != 0 {
        let termErrno = errno
        os_log(
            .error,
            "SIGTERM to external connector process group %{public}d failed with errno %{public}d",
            running.processGroupIdentifier,
            termErrno
        )
    }

    let didExitAfterTerm = externalConnectorWaitForExit(
        processIdentifier: running.processIdentifier,
        timeout: externalConnectorTerminateGraceSeconds
    )
    if !didExitAfterTerm {
        os_log(
            .error,
            "External connector process %{public}d did not exit after SIGTERM grace period",
            running.processIdentifier
        )
    }

    if running.reapAndCheckRunning(),
       externalConnectorProcessGroupMatchesProcess(
           running.processGroupIdentifier,
           processIdentifier: running.processIdentifier
       ) {
        let killResult = kill(-running.processGroupIdentifier, SIGKILL)
        if killResult != 0 {
            let killErrno = errno
            os_log(
                .error,
                "SIGKILL to external connector process group %{public}d failed with errno %{public}d",
                running.processGroupIdentifier,
                killErrno
            )
        }
    }
}

func cleanupExternalConnectorProcessGroup(_ running: inout RunningExternalConnectorProcess) -> String {
    _ = externalConnectorWaitForExit(processIdentifier: running.processIdentifier, timeout: 0.2)
    guard externalConnectorProcessGroupExists(running.processGroupIdentifier) else {
        return "completed"
    }
    let killResult = kill(-running.processGroupIdentifier, SIGKILL)
    guard killResult == 0 else {
        return "failed: SIGKILL process group \(running.processGroupIdentifier) errno \(errno)"
    }
    return "forced-kill"
}

private func externalConnectorProcessGroupExists(_ processGroupIdentifier: pid_t) -> Bool {
    kill(-processGroupIdentifier, 0) == 0 || errno == EPERM
}

private func externalConnectorProcessGroupMatchesProcess(
    _ processGroupIdentifier: pid_t,
    processIdentifier: pid_t
) -> Bool {
    getpgid(processIdentifier) == processGroupIdentifier
}

private func externalConnectorWaitForExit(processIdentifier: pid_t, timeout: TimeInterval) -> Bool {
    if kill(processIdentifier, 0) != 0, errno == ESRCH {
        return true
    }
    let queue = kqueue()
    guard queue >= 0 else {
        return false
    }
    defer { close(queue) }

    var event = kevent(
        ident: UInt(processIdentifier),
        filter: Int16(EVFILT_PROC),
        flags: UInt16(EV_ADD | EV_ENABLE | EV_ONESHOT),
        fflags: UInt32(NOTE_EXIT),
        data: 0,
        udata: nil
    )
    guard kevent(queue, &event, 1, nil, 0, nil) == 0 else {
        return kill(processIdentifier, 0) != 0 && errno == ESRCH
    }

    let deadline = MonotonicDeadline(seconds: max(0, timeout))
    var wait = externalConnectorTimeSpec(seconds: deadline.remainingSeconds)
    var received = kevent(queue, nil, 0, &event, 1, &wait)
    while received == -1, errno == EINTR {
        var wait = externalConnectorTimeSpec(seconds: deadline.remainingSeconds)
        received = kevent(queue, nil, 0, &event, 1, &wait)
    }
    return received > 0 || (kill(processIdentifier, 0) != 0 && errno == ESRCH)
}

private func externalConnectorTimeSpec(seconds: TimeInterval) -> timespec {
    let boundedSeconds = max(0, seconds)
    return timespec(
        tv_sec: Int(boundedSeconds),
        tv_nsec: Int((boundedSeconds - floor(boundedSeconds)) * 1_000_000_000)
    )
}

private func spawnExternalConnectorProcess(
    executable: String,
    arguments: [String],
    environment: [String: String],
    stdout: Pipe,
    stderr: Pipe
) throws -> pid_t {
    var mergedEnvironment = ProcessInfo.processInfo.environment
    for (key, value) in environment {
        mergedEnvironment[key] = value
    }

    var fileActions: posix_spawn_file_actions_t?
    try checkExternalConnectorSpawnStatus(
        posix_spawn_file_actions_init(&fileActions),
        "posix_spawn_file_actions_init"
    )
    defer { posix_spawn_file_actions_destroy(&fileActions) }
    try checkExternalConnectorSpawnStatus(
        posix_spawn_file_actions_adddup2(&fileActions, stdout.fileHandleForWriting.fileDescriptor, STDOUT_FILENO),
        "posix_spawn_file_actions_adddup2 stdout"
    )
    try checkExternalConnectorSpawnStatus(
        posix_spawn_file_actions_adddup2(&fileActions, stderr.fileHandleForWriting.fileDescriptor, STDERR_FILENO),
        "posix_spawn_file_actions_adddup2 stderr"
    )
    try checkExternalConnectorSpawnStatus(
        posix_spawn_file_actions_addclose(&fileActions, stdout.fileHandleForReading.fileDescriptor),
        "posix_spawn_file_actions_addclose stdout"
    )
    try checkExternalConnectorSpawnStatus(
        posix_spawn_file_actions_addclose(&fileActions, stderr.fileHandleForReading.fileDescriptor),
        "posix_spawn_file_actions_addclose stderr"
    )

    var attributes: posix_spawnattr_t?
    try checkExternalConnectorSpawnStatus(
        posix_spawnattr_init(&attributes),
        "posix_spawnattr_init"
    )
    defer { posix_spawnattr_destroy(&attributes) }
    let flags = Int16(POSIX_SPAWN_SETPGROUP)
    try checkExternalConnectorSpawnStatus(
        posix_spawnattr_setflags(&attributes, flags),
        "posix_spawnattr_setflags"
    )
    try checkExternalConnectorSpawnStatus(
        posix_spawnattr_setpgroup(&attributes, 0),
        "posix_spawnattr_setpgroup"
    )

    let argv = ["env", executable] + arguments
    let envp = mergedEnvironment.map { "\($0.key)=\($0.value)" }.sorted()
    var processIdentifier = pid_t()
    let status = try withCStringArray(argv) { argvPointer in
        try withCStringArray(envp) { envPointer in
            posix_spawn(
                &processIdentifier,
                "/usr/bin/env",
                &fileActions,
                &attributes,
                argvPointer,
                envPointer
            )
        }
    }
    if status != 0 {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(status))
    }
    stdout.fileHandleForWriting.closeFile()
    stderr.fileHandleForWriting.closeFile()
    return processIdentifier
}

private func checkExternalConnectorSpawnStatus(_ status: Int32, _ operation: String) throws {
    guard status == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(status), userInfo: [
            NSLocalizedDescriptionKey: "\(operation) failed with errno \(status)",
        ])
    }
}

private func withCStringArray<Result>(
    _ strings: [String],
    _ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> Result
) throws -> Result {
    var allocations: [UnsafeMutablePointer<CChar>] = []
    allocations.reserveCapacity(strings.count)
    var cStrings: [UnsafeMutablePointer<CChar>?] = []
    cStrings.reserveCapacity(strings.count + 1)
    for string in strings {
        guard let cString = strdup(string) else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOMEM))
        }
        allocations.append(cString)
        cStrings.append(cString)
    }
    cStrings.append(nil)
    defer {
        for cString in allocations {
            free(cString)
        }
    }
    return try cStrings.withUnsafeMutableBufferPointer { buffer in
        guard let baseAddress = buffer.baseAddress else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(EINVAL))
        }
        return try body(baseAddress)
    }
}

private func externalConnectorExitStatus(from waitStatus: Int32?) -> Int32? {
    guard let waitStatus else {
        return nil
    }
    // Darwin wait status layout mirrors WIFEXITED/WIFSIGNALED/WIFSTOPPED:
    // low signal bits are zero for normal exits, nonzero for signals, and
    // exactly 0x7f for stopped processes. Stopped status is not an exit code,
    // so preserve the raw wait status for that rare non-terminal state.
    let signal = waitStatus & externalConnectorWaitStatusSignalMask
    if signal == 0 {
        return (waitStatus >> externalConnectorWaitStatusExitCodeShift) & 0xff
    }
    if signal != externalConnectorWaitStatusStoppedMarker {
        return signal
    }
    return waitStatus
}

func externalConnectorPipePrefix(_ capture: BoundedPipeCapture) -> String {
    capture.prefix()
}
