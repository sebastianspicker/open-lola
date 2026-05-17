import Darwin
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func managedProcessRunnerRunsProcessToExitAndCapturesOutput() throws {
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-managed-process-\(UUID().uuidString).txt")
    defer {
        try? FileManager.default.removeItem(at: outputURL)
    }

    let exitCode = try ManagedProcessRunner.runToExit(
        executable: "/bin/echo",
        arguments: ["managed-process-ok"],
        standardOutputPath: outputURL.path
    )

    #expect(exitCode == 0)
    #expect(try String(contentsOf: outputURL, encoding: .utf8) == "managed-process-ok\n")
}

@Test
func managedProcessRunnerWaitDeadlineUsesElapsedTimeWithoutFalseExit() throws {
    let process = try ManagedProcessRunner.start(executable: "/bin/sleep", arguments: ["1"])
    defer {
        ManagedProcessRunner.terminate([process], graceSeconds: 0.05)
    }

    let exited = ManagedProcessRunner.waitUntilExit(
        [process],
        deadline: .now() + .milliseconds(10),
        pollIntervalSeconds: 0.001
    )

    #expect(!exited)
    #expect(process.isRunning)
}

@Test
func managedProcessRunnerTerminationResultExposesForcedKillOutcome() throws {
    let marker = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-managed-process-ready-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: marker)
    }
    let process = try ManagedProcessRunner.start(
        executable: "/usr/bin/env",
        arguments: [
            "python3",
            "-c",
            """
            import pathlib, signal, sys, time
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
            pathlib.Path(sys.argv[1]).write_text("ready", encoding="utf-8")
            time.sleep(30)
            """,
            marker.path,
        ]
    )
    #expect(waitForFile(at: marker))

    let result = ManagedProcessRunner.terminate([process], graceSeconds: 0.05)

    #expect(result.processCount == 1)
    #expect(result.exitedAfterTerminate == false)
    #expect(result.forcedKillSent)
    #expect(result.exitedAfterKill)
    #expect(result.allExited)
    #expect(result.cleanupWarnings.isEmpty)
    #expect(!process.isRunning)
}

@Test
func managedProcessRunnerTerminationResultPreservesKillFailureWarning() throws {
    let marker = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-managed-process-kill-failure-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: marker)
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
        "python3",
        "-c",
        """
        import pathlib, signal, sys, time
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        pathlib.Path(sys.argv[1]).write_text("ready", encoding="utf-8")
        time.sleep(30)
        """,
        marker.path,
    ]
    try process.run()
    defer {
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
            process.waitUntilExit()
        }
    }
    #expect(waitForFile(at: marker))
    let managed = ManagedProcess(
        process: process,
        standardOutputHandle: nil,
        standardErrorHandle: nil,
        killProcess: { _ in
            errno = EPERM
            return -1
        }
    )

    let result = ManagedProcessRunner.terminate([managed], graceSeconds: 0.05)

    #expect(result.processCount == 1)
    #expect(result.exitedAfterTerminate == false)
    #expect(result.forcedKillSent)
    #expect(result.exitedAfterKill == false)
    #expect(result.cleanupWarnings.count == 1)
    #expect(result.cleanupWarnings[0].operation == "kill")
    #expect(result.cleanupWarnings[0].message.contains("SIGKILL process"))
    #expect(result.cleanupWarnings[0].message.contains("errno \(EPERM)"))
}

@Test
func managedProcessRunnerTerminationResultPreservesStdoutCloseFailureWarning() throws {
    let closeFailure = try managedProcessWithInjectedCloseFailure(failingStream: .stdout)

    let result = ManagedProcessRunner.terminate([closeFailure.process], graceSeconds: 0.05)

    #expect(result.exitedAfterTerminate)
    #expect(result.cleanupWarnings.count == 1)
    #expect(result.cleanupWarnings[0].operation == "stdout-close")
    #expect(result.cleanupWarnings[0].message.contains("stdout close failed"))
    closeFailure.closeHandles()
}

@Test
func managedProcessRunnerTerminationResultPreservesStderrCloseFailureWarning() throws {
    let closeFailure = try managedProcessWithInjectedCloseFailure(failingStream: .stderr)

    let result = ManagedProcessRunner.terminate([closeFailure.process], graceSeconds: 0.05)

    #expect(result.exitedAfterTerminate)
    #expect(result.cleanupWarnings.count == 1)
    #expect(result.cleanupWarnings[0].operation == "stderr-close")
    #expect(result.cleanupWarnings[0].message.contains("stderr close failed"))
    closeFailure.closeHandles()
}

@Test
func managedProcessRunnerTerminationResultCleanTerminationHasNoCleanupWarnings() throws {
    let process = try ManagedProcessRunner.start(executable: "/usr/bin/env", arguments: ["true"])
    process.waitUntilExit()

    let result = ManagedProcessRunner.terminate([process], graceSeconds: 0.05)

    #expect(result.exitedAfterTerminate)
    #expect(result.cleanupWarnings.isEmpty)
}

private func waitForFile(at url: URL, timeoutSeconds: TimeInterval = 2) -> Bool {
    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
        if FileManager.default.fileExists(atPath: url.path) {
            return true
        }
        Thread.sleep(forTimeInterval: 0.01)
    }
    return false
}

private enum ManagedProcessTestStream {
    case stdout
    case stderr
}

private struct ManagedProcessCloseFailure {
    let process: ManagedProcess
    let stdoutHandle: FileHandle
    let stderrHandle: FileHandle

    func closeHandles() {
        try? stdoutHandle.close()
        try? stderrHandle.close()
    }
}

private struct ManagedProcessTestCloseError: Error, CustomStringConvertible {
    let description: String
}

private func managedProcessWithInjectedCloseFailure(
    failingStream: ManagedProcessTestStream
) throws -> ManagedProcessCloseFailure {
    let stdoutURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-managed-process-stdout-\(UUID().uuidString).log")
    let stderrURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-managed-process-stderr-\(UUID().uuidString).log")
    FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
    FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
    let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
    let stderrHandle = try FileHandle(forWritingTo: stderrURL)
    let rawProcess = Process()
    rawProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    rawProcess.arguments = ["true"]
    try rawProcess.run()
    rawProcess.waitUntilExit()
    let managedProcess = ManagedProcess(
        process: rawProcess,
        standardOutputHandle: stdoutHandle,
        standardErrorHandle: stderrHandle,
        closeHandle: { handle in
            if failingStream == .stdout, handle === stdoutHandle {
                throw ManagedProcessTestCloseError(description: "injected stdout close failure")
            }
            if failingStream == .stderr, handle === stderrHandle {
                throw ManagedProcessTestCloseError(description: "injected stderr close failure")
            }
            try handle.close()
        }
    )
    return ManagedProcessCloseFailure(
        process: managedProcess,
        stdoutHandle: stdoutHandle,
        stderrHandle: stderrHandle
    )
}
