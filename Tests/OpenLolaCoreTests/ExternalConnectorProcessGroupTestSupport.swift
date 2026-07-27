// Shared External connector process group helpers keep multi-file test scenarios deterministic.
import Foundation
import Darwin
import Testing

@testable import OpenLolaCore

func writeBoundedExternalConnectorScript(named name: String, in directory: URL) throws -> URL {
    let executable = directory.appendingPathComponent(name)
    try """
    #!/usr/bin/env bash
    printf '%s:%s:%s\\n' \\
        "$OPEN_LOLA_EXTERNAL_CONNECTOR" \\
        "$OPEN_LOLA_EXTERNAL_CONNECTOR_ROLE" \\
        "$*" >"${BASH_SOURCE[0]}.log"
    exec /usr/bin/env python3 -c 'import signal, sys, time
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    time.sleep(30)'
    """.write(to: executable, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    return executable
}

func runJackTripAudioVideoNativeProcess(
    _ result: ExternalConnectorProcessResult,
    peer: String = "203.0.113.10",
    outputPath: String,
    videoExecutable: String? = "/definitely/not/uv",
    durationSeconds: Int = 1
) throws -> (report: ExternalConnectorSessionReport, processRunner: MockExternalConnectorProcessRunner) {
    let processRunner = MockExternalConnectorProcessRunner(results: [result])
    let report = try ExternalConnectorSessionRunner.run(
        configuration: jackTripAudioVideoNativeConfiguration(
            peer: peer,
            outputPath: outputPath,
            videoExecutable: videoExecutable,
            durationSeconds: durationSeconds
        ),
        processRunner: processRunner
    )
    return (report, processRunner)
}

func jackTripAudioVideoNativeConfiguration(
    peer: String,
    outputPath: String,
    videoExecutable: String?,
    durationSeconds: Int = 1
) -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: peer,
  outputPath: outputPath
) { input in
  input.executable = "/definitely/not/jacktrip"
  input.videoExecutable = videoExecutable
  input.dryRun = false
  input.mediaMode = .audioVideo
  input.durationSeconds = durationSeconds
  input.peerAudioPort = 4464
})
}

func expectJackTripAuxiliaryFailure(
    _ result: ExternalConnectorProcessResult,
    peer: String = "198.51.100.20",
    outputPath: String,
    videoExecutable: String? = nil,
    runtimeError: String
) throws {
    let report = try runJackTripAudioVideoNativeProcess(
        result,
        peer: peer,
        outputPath: outputPath,
        videoExecutable: videoExecutable
    ).report

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == runtimeError)
}

func childSpawningPython() -> String {
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
            "import signal, time; "
            "signal.signal(signal.SIGTERM, signal.SIG_IGN); "
            "signal.signal(signal.SIGHUP, signal.SIG_IGN); "
            "signal.signal(signal.SIGINT, signal.SIG_IGN); "
            "time.sleep(30)",
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

func readChildPID(marker: URL) throws -> pid_t {
    let text = try String(contentsOf: marker.appendingPathExtension("pid"), encoding: .utf8)
    guard let pid = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        throw CocoaError(.fileReadCorruptFile)
    }
    return pid
}

func processStops(pid: pid_t) -> Bool {
    if kill(pid, 0) != 0, errno == ESRCH {
        return true
    }

    let queue = kqueue()
    guard queue >= 0 else {
        return false
    }
    defer { close(queue) }

    var event = kevent()
    event.ident = UInt(pid)
    event.filter = Int16(EVFILT_PROC)
    event.flags = UInt16(EV_ADD | EV_ENABLE | EV_ONESHOT)
    event.fflags = UInt32(NOTE_EXIT)
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
