// Supplies DirectP2PTwoPeerLocalRunProcessSupport helpers, keeping command assembly details out of the primary CLI flow.
import Dispatch
import Foundation
import OpenLolaCore

private let directP2PTwoPeerTerminationGraceSeconds = 2
private let directP2PTwoPeerReadinessProbeMaximumSeconds = 5

func waitForDirectP2PProcessesToExit(
    _ processes: [RunningDirectP2PProcess],
    deadline: DispatchTime
) -> Bool {
    ManagedProcessRunner.waitUntilExit(processes.map(\.process), deadline: deadline)
}

func terminateExpiredDirectP2PProcesses(_ processes: [RunningDirectP2PProcess]) {
    ManagedProcessRunner.terminate(
        processes.map(\.process),
        graceSeconds: TimeInterval(directP2PTwoPeerTerminationGraceSeconds)
    )
}

func directP2PExitCode(for process: ManagedProcess) -> Int {
    process.isRunning ? -1 : Int(process.terminationStatus)
}

struct RunningDirectP2PProcess {
    var command: DirectPeerTwoPeerRunCommand
    var process: ManagedProcess
    var launchedArguments: [String]
    var stdoutPath: String
    var stderrPath: String
    var executionMode: DirectPeerTwoPeerRunExecutionMode
    var remoteTarget: String?
    var startedAt: String

    func result(
        exitCode: Int,
        options: DirectP2PTwoPeerLocalRunOptions,
        runDirectory: String
    ) throws -> DirectPeerTwoPeerLocalRunProcessResult {
        let collected = try collectArtifactsIfNeeded(
            command: command,
            exitCode: exitCode,
            options: options,
            runDirectory: runDirectory,
            remoteTarget: remoteTarget
        )
        return DirectPeerTwoPeerLocalRunProcessResult(
            identity: processIdentity,
            execution: processExecution(exitCode: exitCode),
            collection: .init(
                remoteTarget: remoteTarget,
                reportPath: collected.reportPath,
                receiveProofPath: collected.receiveProofPath,
                startedAt: startedAt,
                finishedAt: ISO8601DateFormatter().string(from: Date())
            )
        )
    }

    private var processIdentity: DirectPeerTwoPeerLocalRunProcessResult.Identity {
        .init(peerID: command.peerID, role: command.role, reportPath: command.outputReportPath)
    }

    private func processExecution(
        exitCode: Int
    ) -> DirectPeerTwoPeerLocalRunProcessResult.Execution {
        .init(
            command: launchedArguments,
            stdoutPath: stdoutPath,
            stderrPath: stderrPath,
            exitCode: exitCode,
            mode: executionMode
        )
    }
}

func startDirectP2PProcess(
    command: DirectPeerTwoPeerRunCommand,
    runDirectory: String,
    options: DirectP2PTwoPeerLocalRunOptions,
    readyFilePath: String?
) throws -> RunningDirectP2PProcess {
    guard !command.arguments.isEmpty else {
        throw CommandError.invalidArgument("empty child command for \(command.peerID)")
    }
    let childArguments = directP2PChildArguments(
        command.arguments,
        executablePath: options.executablePath(for: command),
        readyFilePath: readyFilePath
    )
    let remoteTarget = options.sshTarget(for: command)
    let launchedArguments = try directP2PLaunchedArguments(
        command: command,
        childArguments: childArguments,
        options: options,
        remoteTarget: remoteTarget
    )
    let stdoutPath = "\(runDirectory)/\(command.peerID)-stdout.log"
    let stderrPath = "\(runDirectory)/\(command.peerID)-stderr.log"
    // In SSH mode the supervisor holds ssh's standard input open; its EOF is what stops the remote peer.
    let process = try ManagedProcessRunner.start(
        executable: launchedArguments[0],
        arguments: Array(launchedArguments.dropFirst()),
        standardOutputPath: stdoutPath,
        standardErrorPath: stderrPath,
        holdsStandardInputOpen: options.executionMode == .ssh
    )
    return RunningDirectP2PProcess(
        command: command,
        process: process,
        launchedArguments: launchedArguments,
        stdoutPath: stdoutPath,
        stderrPath: stderrPath,
        executionMode: options.executionMode,
        remoteTarget: remoteTarget,
        startedAt: ISO8601DateFormatter().string(from: Date())
    )
}

private func directP2PLaunchedArguments(
    command: DirectPeerTwoPeerRunCommand,
    childArguments: [String],
    options: DirectP2PTwoPeerLocalRunOptions,
    remoteTarget: String?
) throws -> [String] {
    guard options.executionMode == .ssh else {
        return childArguments
    }
    guard let remoteTarget else {
        throw CommandError.invalidArgument("missing SSH target for \(command.peerID)")
    }
    try RemoteProcessTarget.validate(remoteTarget)
    return [options.sshExecutable, "--", remoteTarget] + remoteShellArguments(
        childArguments,
        workingDirectory: options.remoteWorkingDirectory(for: command)
    )
}

func directP2PChildArguments(
    _ arguments: [String],
    executablePath: String?,
    readyFilePath: String?
) -> [String] {
    var childArguments = arguments
    if let executablePath, !executablePath.isEmpty {
        childArguments[0] = executablePath
    }
    if let readyFilePath {
        childArguments += ["--ready-file", readyFilePath]
    }
    return childArguments
}

func directP2PReadyFilePath(runDirectory: String, peerID: String) -> String {
    "\(runDirectory)/\(peerID)-ready"
}

func waitForDirectP2PReadyFile(_ process: RunningDirectP2PProcess, timeoutMilliseconds: Int) throws {
    let deadline = DispatchTime.now() + .milliseconds(timeoutMilliseconds)
    while DispatchTime.now() < deadline {
        if try directP2PReadyFileExists(process, deadline: deadline) {
            return
        }
        if !process.process.isRunning {
            throw CommandError.invalidArgument(
                "responder exited before readiness marker: \(process.stderrPath)"
            )
        }
        _ = DispatchSemaphore(value: 0).wait(timeout: .now() + .milliseconds(10))
    }
    throw CommandError.invalidArgument("responder readiness marker timed out: \(process.command.peerID)")
}

/// Reports whether the readiness marker exists; throws when an SSH probe fails in a way waiting cannot fix.
func directP2PReadyFileExists(_ process: RunningDirectP2PProcess, deadline: DispatchTime? = nil) throws -> Bool {
    guard let readyFilePath = directP2PReadyFilePath(from: process.launchedArguments) else {
        return true
    }
    guard process.executionMode == .ssh, let remoteTarget = process.remoteTarget else {
        return FileManager.default.fileExists(atPath: readyFilePath)
    }
    try RemoteProcessTarget.validate(remoteTarget)
    // An exhausted deadline is reported by the caller as a readiness timeout.
    guard let timeoutSeconds = try? directP2PReadinessProbeTimeoutSeconds(deadline: deadline) else {
        return false
    }
    switch runDirectP2PReadinessProbe(process, remoteTarget, readyFilePath, timeoutSeconds: timeoutSeconds) {
    case .ready: return true
    case .notReady: return false
    case .permanentFailure(let message):
        throw CommandError.invalidArgument("\(process.command.peerID) readiness probe failed: \(message)")
    }
}

private func runDirectP2PReadinessProbe(
    _ process: RunningDirectP2PProcess,
    _ remoteTarget: String,
    _ readyFilePath: String,
    timeoutSeconds: Int
) -> RemoteReadinessProbeOutcome {
    let stderrPath = NSTemporaryDirectory() + "open-lola-ssh-probe-\(UUID().uuidString).err"
    defer { try? FileManager.default.removeItem(atPath: stderrPath) }
    let exitCode: Int32
    do {
        exitCode = try ManagedProcessRunner.runToExit(
            executable: process.launchedArguments[0],
            arguments: [
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=\(min(directP2PTwoPeerReadinessProbeMaximumSeconds, timeoutSeconds))",
                "-o", "ConnectionAttempts=1",
                "--", remoteTarget, "test -f \(shellQuoted(readyFilePath))"
            ],
            standardErrorPath: stderrPath,
            timeoutSeconds: TimeInterval(timeoutSeconds)
        )
    } catch {
        // A probe that timed out or could not be spawned is retried until the readiness deadline.
        return .notReady
    }
    let stderr = (try? String(contentsOfFile: stderrPath, encoding: .utf8)) ?? ""
    return RemoteReadinessProbeOutcome.classify(exitCode: exitCode, stderr: stderr)
}

private func directP2PReadinessProbeTimeoutSeconds(deadline: DispatchTime?) throws -> Int {
    guard let deadline else { return directP2PTwoPeerReadinessProbeMaximumSeconds }
    let now = DispatchTime.now().uptimeNanoseconds
    let deadlineNanoseconds = deadline.uptimeNanoseconds
    guard deadlineNanoseconds > now else {
        throw CommandError.invalidArgument("responder readiness marker timed out")
    }
    let remainingNanoseconds = deadlineNanoseconds - now
    let remainingSeconds = Int((remainingNanoseconds + 999_999_999) / 1_000_000_000)
    return max(1, remainingSeconds)
}

private func directP2PReadyFilePath(from arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: "--ready-file"),
          index + 1 < arguments.count else {
        return nil
    }
    return arguments[index + 1]
}

/// The remote peer is stopped with SIGTERM when ssh's standard input reaches EOF, which happens when the
/// supervisor terminates ssh or exits; ssh runs without a pty, so no hangup signal would reach it otherwise.
private func remoteShellArguments(_ arguments: [String], workingDirectory: String?) -> [String] {
    let command = RemoteProcessHangupWrapper.command(arguments.map(shellQuoted).joined(separator: " "))
    guard let workingDirectory, !workingDirectory.isEmpty else {
        return [command]
    }
    return ["cd \(shellQuoted(workingDirectory)) && \(command)"]
}

private func shellQuoted(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
}
