import Foundation
import Darwin
import Testing

@testable import OpenLolaCore

@Test
func jackTripAudioVideoProcessRunStartsAudioAndVideoTogether() throws {
    let processRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 41_001,
            terminatedAfterDuration: true
        ),
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 41_002,
            terminatedAfterDuration: true
        ),
    ])
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        executable: "/definitely/not/jacktrip",
        videoExecutable: "/definitely/not/uv",
        outputPath: "/tmp/jacktrip-av-concurrent-process.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1,
        peerAudioPort: 4464
    )

    let report = try ExternalConnectorSessionRunner.run(configuration: configuration, processRunner: processRunner)

    try report.validate()
    #expect(report.process?.launched == true)
    #expect(report.process?.terminatedAfterDuration == true)
    #expect(report.auxiliaryProcesses.count == 1)
    #expect(report.auxiliaryProcesses[0].launched)
    #expect(report.auxiliaryProcesses[0].terminatedAfterDuration)
    #expect(processRunner.invocations.count == 2)
    #expect(report.notes.contains("process group launch"))
}

@Test
func externalConnectorSessionUsesInjectedProcessRunnerWithoutLaunchingBinaries() throws {
    let processRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 42_001,
            terminatedAfterDuration: true,
            standardOutputPrefix: "mock-primary"
        ),
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 42_002,
            terminatedAfterDuration: true,
            standardOutputPrefix: "mock-auxiliary"
        ),
    ])
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        executable: "/definitely/not/jacktrip",
        videoExecutable: "/definitely/not/uv",
        outputPath: "/tmp/jacktrip-av-mock-process.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1,
        peerAudioPort: 4464
    )

    let report = try ExternalConnectorSessionRunner.run(configuration: configuration, processRunner: processRunner)

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.runtimeError == nil)
    #expect(report.process?.processIdentifier == 42_001)
    #expect(report.auxiliaryProcesses.first?.processIdentifier == 42_002)
    #expect(processRunner.invocations.map(\.executable) == [
        "/definitely/not/jacktrip",
        "/definitely/not/uv",
    ])
}

@Test
func timedExternalConnectorRunKillsTermIgnoringDescendant() throws {
    let marker = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("open-lola-connector-child-\(UUID().uuidString)")
    defer {
        if let childPID = try? readChildPID(marker: marker) {
            kill(childPID, SIGKILL)
        }
        try? FileManager.default.removeItem(at: marker)
        try? FileManager.default.removeItem(at: marker.appendingPathExtension("pid"))
    }

    let result = runExternalConnectorProcess(ExternalConnectorProcessRunConfiguration(
        executable: "/usr/bin/env",
        arguments: ["python3", "-c", childSpawningPython(), marker.path],
        durationSeconds: 1
    ))

    #expect(result.launched)
    #expect(result.terminatedAfterDuration == true)
    let childPID = try readChildPID(marker: marker)
    #expect(processStops(pid: childPID))
}

@Test
func externalConnectorProcessDrainsLargeOutputWhileRunning() throws {
    let result = runExternalConnectorProcess(ExternalConnectorProcessRunConfiguration(
        executable: "/usr/bin/env",
        arguments: [
            "python3",
            "-c",
            """
            import sys
            sys.stdout.write("external-output-start\\n")
            sys.stdout.flush()
            sys.stdout.buffer.write(b"x" * (1024 * 1024))
            sys.stdout.flush()
            """,
        ],
        durationSeconds: 2
    ))

    #expect(result.launched)
    #expect(result.exitStatus == 0)
    #expect(result.terminatedAfterDuration == false)
    #expect(result.standardOutputPrefix.hasPrefix("external-output-start"))
}

@Test
func externalConnectorProcessGroupTestsUseEventDrivenHelpers() throws {
    let source = try readProcessGroupTestSource()
    let runnerSource = try readProcessSource("Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift")
    let sessionRuntimeSource = try readProcessSource("Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift")
    let sleepExecutableHelper = "makeConnector" + "SleepExecutable"
    let childExecutableHelper = "makeConnector" + "ChildSpawningExecutable"
    let shellHeader = "#!" + "/bin/sh"
    let pollingSleep = "Thread.sleep(forTimeInterval: " + "0.05)"

    #expect(!source.contains(sleepExecutableHelper))
    #expect(!source.contains(childExecutableHelper))
    #expect(!source.contains(shellHeader))
    #expect(!source.contains(pollingSleep))
    #expect(source.contains("kqueue()"))
    #expect(source.contains("childSpawningPython()"))
    #expect(!runnerSource.contains("Thread.sleep"))
    #expect(!sessionRuntimeSource.contains("Thread.sleep"))
    #expect(runnerSource.contains("externalConnectorWaitForExit"))
    #expect(runnerSource.contains("externalConnectorTerminateGraceSeconds"))
    #expect(!runnerSource.contains("timeout: 0.3"))
    #expect(runnerSource.contains("externalConnectorWaitStatusSignalMask"))
    #expect(runnerSource.contains("Darwin wait status layout mirrors WIFEXITED/WIFSIGNALED/WIFSTOPPED"))
    #expect(runnerSource.contains("externalConnectorWaitStatusStoppedMarker"))
    #expect(sessionRuntimeSource.contains("externalConnectorWaitForProcessesOrTimeout"))
    #expect(sessionRuntimeSource.contains("private struct ExternalConnectorProcessSlot"))
    #expect(!sessionRuntimeSource.contains("Array<RunningExternalConnectorProcess?>(repeating: nil"))
    #expect(!sessionRuntimeSource.contains("Array<ExternalConnectorProcessResult?>(repeating: nil"))
    #expect(runnerSource.contains("checkExternalConnectorSpawnStatus"))
    #expect(!runnerSource.contains("var isRunning: Bool"))
    #expect(runnerSource.contains("reapAndCheckRunning()"))
    #expect(runnerSource.contains("externalConnectorProcessGroupMatchesProcess"))
    #expect(runnerSource.contains("getpgid(processIdentifier) == processGroupIdentifier"))
    #expect(runnerSource.contains("stderr.fileHandleForWriting.closeFile()"))
    #expect(runnerSource.contains("ExternalConnectorPipeCapture"))
    #expect(runnerSource.contains("readHandle.readabilityHandler"))
}

@Test
func externalConnectorSessionRejectsMissingAuxiliaryProcessResult() throws {
    let processRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 43_001,
            terminatedAfterDuration: true
        ),
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 43_002,
            terminatedAfterDuration: true
        ),
    ])
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        executable: "/definitely/not/jacktrip",
        videoExecutable: "/definitely/not/uv",
        outputPath: "/tmp/jacktrip-av-process.json",
        dryRun: false,
        mediaMode: .audioVideo,
        peerAudioPort: 4464
    )
    var report = try ExternalConnectorSessionRunner.run(configuration: configuration, processRunner: processRunner)
    report.auxiliaryProcesses = []

    #expect(throws: ExternalConnectorSessionError.processLaunchFailed("auxiliary process result count mismatch")) {
        try report.validate()
    }
}

@Test
func ultraGridNonZeroProcessExitWritesFailureReport() throws {
    let processRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 44_001,
            exitStatus: 1,
            terminatedAfterDuration: false
        ),
    ])
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.20",
        executable: "/definitely/not/uv",
        outputPath: "/tmp/ultragrid-process-fail.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1
    ), processRunner: processRunner)

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == "primary process exited with status 1")
}

@Test
func ultraGridCleanEarlyExitWritesFailureReport() throws {
    let processRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 45_001,
            exitStatus: 0,
            terminatedAfterDuration: false
        ),
    ])
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.20",
        executable: "/definitely/not/uv",
        outputPath: "/tmp/ultragrid-process-early-exit.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1
    ), processRunner: processRunner)

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == "primary process exited before duration with status 0")
}

@Test
func jackTripAuxiliaryNonZeroProcessExitWritesFailureReport() throws {
    let processRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 46_001,
            terminatedAfterDuration: true
        ),
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 46_002,
            exitStatus: 1,
            terminatedAfterDuration: false
        ),
    ])
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        executable: "/definitely/not/jacktrip",
        videoExecutable: "/definitely/not/uv",
        outputPath: "/tmp/jacktrip-auxiliary-process-fail.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1,
        peerAudioPort: 4464
    ), processRunner: processRunner)

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == "auxiliary 0 process exited with status 1")
}

@Test
func ultraGridRealRunWithoutExplicitExecutableWritesHostReadinessReport() throws {
    let processRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: false,
            error: "mock host readiness: uv not executed"
        ),
    ])
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.20",
        outputPath: "/tmp/ultragrid-default-process.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1
    ), processRunner: processRunner)

    try report.validate()
    #expect(report.plan.executable == "uv")
    #expect(report.process != nil)
    #expect(!report.dryRun)
    #expect(report.process?.error == "mock host readiness: uv not executed")
}

@Test
func jackTripAvRealRunWithoutExplicitExecutablesWritesHostReadinessReport() throws {
    let processRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: false,
            error: "mock host readiness: jacktrip not executed"
        ),
        ExternalConnectorProcessResult(
            launched: false,
            error: "mock host readiness: uv not executed"
        ),
    ])
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-default-process.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1,
        peerAudioPort: 4464
    ), processRunner: processRunner)

    try report.validate()
    #expect(report.plan.executable == "jacktrip")
    #expect(report.plan.auxiliaryProcesses.first?.executable == "uv")
    #expect(report.process != nil)
    #expect(report.auxiliaryProcesses.count == 1)
    #expect(report.process?.error == "mock host readiness: jacktrip not executed")
    #expect(report.auxiliaryProcesses.first?.error == "mock host readiness: uv not executed")
}

private func childSpawningPython() -> String {
    """
    import os
    import signal
    import subprocess
    import sys
    import time

    marker = sys.argv[1]
    child = subprocess.Popen(
        [
            sys.executable,
            "-c",
            "import signal, time; signal.signal(signal.SIGTERM, signal.SIG_IGN); signal.signal(signal.SIGHUP, signal.SIG_IGN); signal.signal(signal.SIGINT, signal.SIG_IGN); time.sleep(30)",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    with open(marker + ".pid", "w", encoding="utf-8") as handle:
        handle.write(str(child.pid) + "\\n")
    with open(marker, "w", encoding="utf-8") as handle:
        handle.write("child-started\\n")

    def stop(_signum, _frame):
        sys.exit(0)

    signal.signal(signal.SIGTERM, stop)
    time.sleep(30)
    """
}

private func readChildPID(marker: URL) throws -> pid_t {
    let text = try String(contentsOf: marker.appendingPathExtension("pid"), encoding: .utf8)
    guard let pid = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        throw CocoaError(.fileReadCorruptFile)
    }
    return pid
}

private func processStops(pid: pid_t) -> Bool {
    if kill(pid, 0) != 0, errno == ESRCH {
        return true
    }

    let queue = kqueue()
    guard queue >= 0 else {
        return false
    }
    defer { close(queue) }

    var event = kevent(
        ident: UInt(pid),
        filter: Int16(EVFILT_PROC),
        flags: UInt16(EV_ADD | EV_ENABLE | EV_ONESHOT),
        fflags: UInt32(NOTE_EXIT),
        data: 0,
        udata: nil
    )
    guard kevent(queue, &event, 1, nil, 0, nil) == 0 else {
        return kill(pid, 0) != 0 && errno == ESRCH
    }

    var timeout = timespec(tv_sec: 1, tv_nsec: 0)
    var received = kevent(queue, nil, 0, &event, 1, &timeout)
    while received == -1, errno == EINTR {
        received = kevent(queue, nil, 0, &event, 1, &timeout)
    }
    return received > 0 || (kill(pid, 0) != 0 && errno == ESRCH)
}

private func readProcessGroupTestSource() throws -> String {
    try readProcessSource("Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift")
}

private func readProcessSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

final class MockExternalConnectorProcessRunner: ExternalConnectorProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private let results: [ExternalConnectorProcessResult]
    private var capturedInvocations: [ExternalConnectorProcessInvocation] = []

    init(results: [ExternalConnectorProcessResult]) {
        self.results = results
    }

    var invocations: [ExternalConnectorProcessInvocation] {
        lock.lock()
        defer { lock.unlock() }
        return capturedInvocations
    }

    func run(
        invocations: [ExternalConnectorProcessInvocation],
        durationSeconds _: Int
    ) -> [ExternalConnectorProcessResult] {
        lock.lock()
        capturedInvocations.append(contentsOf: invocations)
        lock.unlock()

        guard results.count >= invocations.count else {
            return invocations.map { invocation in
                ExternalConnectorProcessResult(
                    launched: false,
                    error: "missing mock result for \(invocation.executable)"
                )
            }
        }
        return Array(results.prefix(invocations.count))
    }
}
