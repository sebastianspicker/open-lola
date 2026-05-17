import Foundation
import Darwin
import Testing

@testable import OpenLolaCore

@Test
func realExternalConnectorProcessRunnerExportsConnectorRoleEnvironment() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-external-connector-env-\(UUID().uuidString)")
    let executable = temporaryRoot.appendingPathComponent("record-env.sh")
    let environmentLog = temporaryRoot.appendingPathComponent("environment.txt")
    try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    try """
    #!/usr/bin/env bash
    printf '%s:%s\\n' "$OPEN_LOLA_EXTERNAL_CONNECTOR" "$OPEN_LOLA_EXTERNAL_CONNECTOR_ROLE" >"$1"
    exit 0
    """.write(to: executable, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

    let results = RealExternalConnectorProcessRunner().run(
        invocations: [
            ExternalConnectorProcessInvocation(
                executable: executable.path,
                arguments: [environmentLog.path],
                connector: .mvtpUltraGrid,
                role: .rx
            ),
        ],
        durationSeconds: 1
    )

    #expect(results.count == 1)
    #expect(results[0].launched)
    #expect(results[0].exitStatus == 0)
    #expect(
        try String(contentsOf: environmentLog, encoding: .utf8)
            == "\(ExternalConnectorKind.mvtpUltraGrid.rawValue):\(ExternalConnectorSessionRole.rx.rawValue)\n"
    )
}

@Test
func jackTripAudioVideoProcessRunUsesInjectedProcessRunnerForPrimaryAndAuxiliary() throws {
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

    let injectedRunner = MockExternalConnectorProcessRunner(results: [
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
    let injectedConfiguration = ExternalConnectorSessionConfiguration(
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

    let injectedReport = try ExternalConnectorSessionRunner.run(
        configuration: injectedConfiguration,
        processRunner: injectedRunner
    )

    try injectedReport.validate()
    #expect(injectedReport.verdict == .partial)
    #expect(injectedReport.runtimeError == nil)
    #expect(injectedReport.process?.processIdentifier == 42_001)
    #expect(injectedReport.auxiliaryProcesses.first?.processIdentifier == 42_002)
    #expect(injectedRunner.invocations.map(\.executable) == [
        "/definitely/not/jacktrip",
        "/definitely/not/uv",
    ])
}

@Test
func jackTripAudioVideoProcessRunReportsRealPrimaryAndAuxiliaryProcesses() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-jacktrip-av-process-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    let primaryExecutable = try writeBoundedExternalConnectorScript(
        named: "jacktrip-primary.sh",
        in: temporaryRoot
    )
    let auxiliaryExecutable = try writeBoundedExternalConnectorScript(
        named: "uv-auxiliary.sh",
        in: temporaryRoot
    )
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        executable: primaryExecutable.path,
        videoExecutable: auxiliaryExecutable.path,
        outputPath: temporaryRoot.appendingPathComponent("jacktrip-av-process.json").path,
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1,
        peerAudioPort: 4464
    ))

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.runtimeError == nil)
    #expect(report.process?.launched == true)
    #expect(report.process?.terminatedAfterDuration == true)
    #expect(report.process?.waitStatusKnown == true)
    #expect(report.process?.cleanupStatus == "completed")
    #expect(report.auxiliaryProcesses.count == 1)
    #expect(report.auxiliaryProcesses[0].launched)
    #expect(report.auxiliaryProcesses[0].terminatedAfterDuration)
    #expect(report.auxiliaryProcesses[0].waitStatusKnown == true)
    #expect(report.auxiliaryProcesses[0].cleanupStatus == "completed")
    #expect(
        try String(contentsOf: primaryExecutable.appendingPathExtension("log"), encoding: .utf8)
            .contains("\(ExternalConnectorKind.jackTrip.rawValue):\(ExternalConnectorSessionRole.tx.rawValue)")
    )
    #expect(
        try String(contentsOf: auxiliaryExecutable.appendingPathExtension("log"), encoding: .utf8)
            .contains("\(ExternalConnectorKind.jackTrip.rawValue):\(ExternalConnectorSessionRole.tx.rawValue)")
    )
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
    #expect(result.waitStatusKnown == true)
    #expect(result.cleanupStatus != nil)
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
    #expect(result.waitStatusKnown == true)
    #expect(result.cleanupStatus == "completed")
    #expect(result.standardOutputPrefix.hasPrefix("external-output-start"))
}

@Test
func externalConnectorSessionFailureReportsCoverMissingAuxiliaryAndEarlyExits() throws {
    let missingAuxiliaryRunner = MockExternalConnectorProcessRunner(results: [
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
    let missingAuxiliaryConfiguration = ExternalConnectorSessionConfiguration(
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
    var missingAuxiliaryReport = try ExternalConnectorSessionRunner.run(
        configuration: missingAuxiliaryConfiguration,
        processRunner: missingAuxiliaryRunner
    )
    missingAuxiliaryReport.auxiliaryProcesses = []

    #expect(throws: ExternalConnectorSessionError.processLaunchFailed("auxiliary process result count mismatch")) {
        try missingAuxiliaryReport.validate()
    }

    let nonZeroRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 44_001,
            exitStatus: 1,
            terminatedAfterDuration: false
        ),
    ])
    let nonZeroReport = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.20",
        executable: "/definitely/not/uv",
        outputPath: "/tmp/ultragrid-process-fail.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1
    ), processRunner: nonZeroRunner)

    try nonZeroReport.validate()
    #expect(nonZeroReport.verdict == .fail)
    #expect(nonZeroReport.runtimeError == "primary process exited with status 1")

    let earlyExitRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 45_001,
            exitStatus: 0,
            terminatedAfterDuration: false
        ),
    ])
    let earlyExitReport = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.20",
        executable: "/definitely/not/uv",
        outputPath: "/tmp/ultragrid-process-early-exit.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1
    ), processRunner: earlyExitRunner)

    try earlyExitReport.validate()
    #expect(earlyExitReport.verdict == .fail)
    #expect(earlyExitReport.runtimeError == "primary process exited before duration with status 0")

    let auxiliaryFailureRunner = MockExternalConnectorProcessRunner(results: [
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
    let auxiliaryFailureReport = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
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
    ), processRunner: auxiliaryFailureRunner)

    try auxiliaryFailureReport.validate()
    #expect(auxiliaryFailureReport.verdict == .fail)
    #expect(auxiliaryFailureReport.runtimeError == "auxiliary 0 process exited with status 1")

    let unknownWaitRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 47_001,
            terminatedAfterDuration: false,
            waitStatusKnown: false,
            cleanupStatus: "completed"
        ),
    ])
    let unknownWaitReport = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.20",
        executable: "/definitely/not/uv",
        outputPath: "/tmp/ultragrid-process-unknown-wait.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1
    ), processRunner: unknownWaitRunner)

    try unknownWaitReport.validate()
    #expect(unknownWaitReport.verdict == .fail)
    #expect(unknownWaitReport.runtimeError == "primary process exit status unknown")

    let cleanupFailureRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 48_001,
            terminatedAfterDuration: true,
            waitStatusKnown: true,
            cleanupStatus: "failed: SIGKILL process group 48001 errno 1"
        ),
    ])
    let cleanupFailureReport = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.20",
        executable: "/definitely/not/uv",
        outputPath: "/tmp/ultragrid-process-cleanup-failed.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1
    ), processRunner: cleanupFailureRunner)

    try cleanupFailureReport.validate()
    #expect(cleanupFailureReport.verdict == .fail)
    #expect(cleanupFailureReport.runtimeError == "primary process cleanup failed: SIGKILL process group 48001 errno 1")
}

@Test
func externalConnectorRealRunsWithoutExplicitExecutablesWriteHostReadinessReports() throws {
    let ultraGridRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: false,
            error: "mock host readiness: uv not executed"
        ),
    ])
    let ultraGridReport = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.20",
        outputPath: "/tmp/ultragrid-default-process.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1
    ), processRunner: ultraGridRunner)

    try ultraGridReport.validate()
    #expect(ultraGridReport.plan.executable == "uv")
    #expect(ultraGridReport.process != nil)
    #expect(!ultraGridReport.dryRun)
    #expect(ultraGridReport.process?.error == "mock host readiness: uv not executed")

    let jackTripRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: false,
            error: "mock host readiness: jacktrip not executed"
        ),
        ExternalConnectorProcessResult(
            launched: false,
            error: "mock host readiness: uv not executed"
        ),
    ])
    let jackTripReport = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-default-process.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1,
        peerAudioPort: 4464
    ), processRunner: jackTripRunner)

    try jackTripReport.validate()
    #expect(jackTripReport.plan.executable == "jacktrip")
    #expect(jackTripReport.plan.auxiliaryProcesses.first?.executable == "uv")
    #expect(jackTripReport.process != nil)
    #expect(jackTripReport.auxiliaryProcesses.count == 1)
    #expect(jackTripReport.process?.error == "mock host readiness: jacktrip not executed")
    #expect(jackTripReport.auxiliaryProcesses.first?.error == "mock host readiness: uv not executed")
}

private func writeBoundedExternalConnectorScript(named name: String, in directory: URL) throws -> URL {
    let executable = directory.appendingPathComponent(name)
    try """
    #!/usr/bin/env bash
    printf '%s:%s:%s\\n' "$OPEN_LOLA_EXTERNAL_CONNECTOR" "$OPEN_LOLA_EXTERNAL_CONNECTOR_ROLE" "$*" >"${BASH_SOURCE[0]}.log"
    exec /usr/bin/env python3 -c 'import signal, sys, time; signal.signal(signal.SIGTERM, lambda *_: sys.exit(0)); time.sleep(30)'
    """.write(to: executable, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    return executable
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
