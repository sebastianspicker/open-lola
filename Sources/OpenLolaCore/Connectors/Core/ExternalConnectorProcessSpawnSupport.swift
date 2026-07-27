// Builds process arguments, pipes, and spawn attributes used by the external connector runner.
import Darwin
import Foundation

func spawnExternalConnectorProcess(
    executable: String,
    arguments: [String],
    environment: [String: String],
    stdout: Pipe,
    stderr: Pipe
) throws -> pid_t {
    let spawnPlan = externalConnectorSpawnPlan(
        executable: executable,
        arguments: arguments,
        environment: environment
    )
    var fileActions = try makeExternalConnectorSpawnFileActions(stdout: stdout, stderr: stderr)
    defer { posix_spawn_file_actions_destroy(&fileActions) }
    var attributes = try makeExternalConnectorSpawnAttributes()
    defer { posix_spawnattr_destroy(&attributes) }
    let processIdentifier = try spawnExternalConnectorProcess(
        spawnPlan,
        fileActions: &fileActions,
        attributes: &attributes
    )
    stdout.fileHandleForWriting.closeFile()
    stderr.fileHandleForWriting.closeFile()
    return processIdentifier
}

private struct ExternalConnectorSpawnPlan {
    var argv: [String]
    var envp: [String]
}

private struct ExternalConnectorSpawnPipeAction {
    var sourceDescriptor: Int32
    var targetDescriptor: Int32
    var operation: String
}

private struct ExternalConnectorSpawnCloseAction {
    var descriptor: Int32
    var operation: String
}

private func externalConnectorSpawnPlan(
    executable: String,
    arguments: [String],
    environment: [String: String]
) -> ExternalConnectorSpawnPlan {
    var mergedEnvironment = ProcessInfo.processInfo.environment
    for (key, value) in environment {
        mergedEnvironment[key] = value
    }
    return ExternalConnectorSpawnPlan(
        argv: ["env", executable] + arguments,
        envp: mergedEnvironment.map { "\($0.key)=\($0.value)" }.sorted()
    )
}

private func makeExternalConnectorSpawnFileActions(
    stdout: Pipe,
    stderr: Pipe
) throws -> posix_spawn_file_actions_t? {
    var fileActions: posix_spawn_file_actions_t?
    try checkExternalConnectorSpawnStatus(
        posix_spawn_file_actions_init(&fileActions),
        "posix_spawn_file_actions_init"
    )
    do {
        try addExternalConnectorSpawnPipeActions(&fileActions, stdout: stdout, stderr: stderr)
        return fileActions
    } catch {
        posix_spawn_file_actions_destroy(&fileActions)
        throw error
    }
}

private func addExternalConnectorSpawnPipeActions(
    _ fileActions: inout posix_spawn_file_actions_t?,
    stdout: Pipe,
    stderr: Pipe
) throws {
    let pipeActions: [ExternalConnectorSpawnPipeAction] = [
        ExternalConnectorSpawnPipeAction(
            sourceDescriptor: stdout.fileHandleForWriting.fileDescriptor,
            targetDescriptor: STDOUT_FILENO,
            operation: "posix_spawn_file_actions_adddup2 stdout"
        ),
        ExternalConnectorSpawnPipeAction(
            sourceDescriptor: stderr.fileHandleForWriting.fileDescriptor,
            targetDescriptor: STDERR_FILENO,
            operation: "posix_spawn_file_actions_adddup2 stderr"
        )
    ]
    for action in pipeActions {
        try checkExternalConnectorSpawnStatus(
            posix_spawn_file_actions_adddup2(
                &fileActions,
                action.sourceDescriptor,
                action.targetDescriptor
            ),
            action.operation
        )
    }

    let closeActions: [ExternalConnectorSpawnCloseAction] = [
        ExternalConnectorSpawnCloseAction(
            descriptor: stdout.fileHandleForReading.fileDescriptor,
            operation: "posix_spawn_file_actions_addclose stdout"
        ),
        ExternalConnectorSpawnCloseAction(
            descriptor: stderr.fileHandleForReading.fileDescriptor,
            operation: "posix_spawn_file_actions_addclose stderr"
        )
    ]
    for action in closeActions {
        try checkExternalConnectorSpawnStatus(
            posix_spawn_file_actions_addclose(&fileActions, action.descriptor),
            action.operation
        )
    }
}

private func makeExternalConnectorSpawnAttributes() throws -> posix_spawnattr_t? {
    var attributes: posix_spawnattr_t?
    try checkExternalConnectorSpawnStatus(
        posix_spawnattr_init(&attributes),
        "posix_spawnattr_init"
    )
    do {
        try checkExternalConnectorSpawnStatus(
            posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP)),
            "posix_spawnattr_setflags"
        )
        try checkExternalConnectorSpawnStatus(
            posix_spawnattr_setpgroup(&attributes, 0),
            "posix_spawnattr_setpgroup"
        )
        return attributes
    } catch {
        posix_spawnattr_destroy(&attributes)
        throw error
    }
}

private func spawnExternalConnectorProcess(
    _ spawnPlan: ExternalConnectorSpawnPlan,
    fileActions: inout posix_spawn_file_actions_t?,
    attributes: inout posix_spawnattr_t?
) throws -> pid_t {
    var processIdentifier = pid_t()
    let status = try withCStringArray(spawnPlan.argv) { argvPointer in
        try withCStringArray(spawnPlan.envp) { envPointer in
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
    return processIdentifier
}

private func checkExternalConnectorSpawnStatus(_ status: Int32, _ operation: String) throws {
    guard status == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(status), userInfo: [
            NSLocalizedDescriptionKey: "\(operation) failed with errno \(status)"
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

func externalConnectorExitStatus(from waitStatus: Int32?) -> Int32? {
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
