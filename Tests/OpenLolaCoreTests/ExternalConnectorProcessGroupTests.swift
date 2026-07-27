// Verifies that real external connector process runner exports connector role environment.
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
            )
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
func jackTripAudioVideoNativeRunUsesInjectedProcessRunnerForAuxiliaryVideo() throws {
    let nativeRun = try runJackTripAudioVideoNativeProcess(
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 41_002,
            terminatedAfterDuration: true
        ),
        outputPath: "/tmp/jacktrip-av-concurrent-process.json"
    )

    let report = nativeRun.report
    try assertCommonAuxiliaryVideoResult(report, invocationCount: nativeRun.processRunner.invocations.count)
    #expect(report.notes.contains("Swift-native JackTrip UDP audio"))

    let injectedRun = try runJackTripAudioVideoNativeProcess(
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 42_002,
            terminatedAfterDuration: true,
            standardOutputPrefix: "mock-auxiliary"
        ),
        outputPath: "/tmp/jacktrip-av-mock-process.json"
    )

    let injectedReport = injectedRun.report
    try injectedReport.validate()
    #expect(injectedReport.verdict == .partial)
    #expect(injectedReport.runtimeError == nil)
    #expect(injectedReport.process == nil)
    #expect(injectedReport.auxiliaryProcesses.first?.processIdentifier == 42_002)
    #expect(injectedRun.processRunner.invocations.map(\.executable) == [
        "/definitely/not/uv"
    ])
}

@Test
func jackTripAudioVideoNativeRunReportsAuxiliaryVideoProcess() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-jacktrip-av-process-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    let auxiliaryExecutable = try writeBoundedExternalConnectorScript(
        named: "uv-auxiliary.sh",
        in: temporaryRoot
    )
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: temporaryRoot.appendingPathComponent("jacktrip-av-process.json").path
) { input in
  input.videoExecutable = auxiliaryExecutable.path
  input.dryRun = false
  input.mediaMode = .audioVideo
  input.durationSeconds = 1
  input.peerAudioPort = 4464
}))

    try assertCommonAuxiliaryVideoResult(report, invocationCount: 1)
    #expect(report.verdict == .partial)
    #expect(report.runtimeError == nil)
    #expect(report.auxiliaryProcesses[0].waitStatusKnown == true)
    #expect(report.auxiliaryProcesses[0].cleanupStatus == "completed")
    #expect(
        try String(contentsOf: auxiliaryExecutable.appendingPathExtension("log"), encoding: .utf8)
            .contains("\(ExternalConnectorKind.jackTrip.rawValue):\(ExternalConnectorSessionRole.tx.rawValue)")
    )
}

private func assertCommonAuxiliaryVideoResult(
    _ report: ExternalConnectorSessionReport,
    invocationCount: Int
) throws {
    try report.validate()
    #expect(report.process == nil)
    #expect(report.jackTripMedia?.transmittedDatagramCount == 1)
    #expect(report.auxiliaryProcesses.count == 1)
    #expect(report.auxiliaryProcesses[0].launched)
    #expect(report.auxiliaryProcesses[0].terminatedAfterDuration)
    #expect(invocationCount == 1)
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
            """
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
    var missingAuxiliaryReport = try runJackTripAudioVideoNativeProcess(
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 43_002,
            terminatedAfterDuration: true
        ),
        outputPath: "/tmp/jacktrip-av-process.json"
    ).report
    missingAuxiliaryReport.auxiliaryProcesses = []

    try missingAuxiliaryReport.validate()
    #expect(missingAuxiliaryReport.process == nil)
    #expect(missingAuxiliaryReport.jackTripMedia != nil)

    try expectJackTripAuxiliaryFailure(
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 46_002,
            exitStatus: 1,
            terminatedAfterDuration: false
        ),
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-auxiliary-process-fail.json",
        videoExecutable: "/definitely/not/uv",
        runtimeError: "auxiliary 0 process exited with status 1"
    )
    try expectJackTripAuxiliaryFailure(
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 47_001,
            terminatedAfterDuration: false,
            waitStatusKnown: false,
            cleanupStatus: "completed"
        ),
        outputPath: "/tmp/ultragrid-process-unknown-wait.json",
        runtimeError: "auxiliary 0 process exit status unknown"
    )
    try expectJackTripAuxiliaryFailure(
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 48_001,
            terminatedAfterDuration: true,
            waitStatusKnown: true,
            cleanupStatus: "failed: SIGKILL process group 48001 errno 1"
        ),
        outputPath: "/tmp/ultragrid-process-cleanup-failed.json",
        runtimeError: "auxiliary 0 process cleanup failed: SIGKILL process group 48001 errno 1"
    )
}

@Test
func externalConnectorRealRunsWithoutExplicitExecutablesWriteHostReadinessReports() throws {
    let ultraGridRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: false,
            error: "mock host readiness: uv not executed"
        )
    ])
    let ultraGridConfiguration = ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "127.0.0.1",
        outputPath: "/tmp/ultragrid-default-process.json"
    ) { input in
  input.localHost = "127.0.0.1"
  input.dryRun = false
  input.mediaMode = .audioVideo
  input.durationSeconds = 1
        input.videoWidth = 16
        input.videoHeight = 16
        input.videoBitsPerPixel = 8
    })
    let ultraGridReport = try ExternalConnectorSessionRunner.run(
        configuration: ultraGridConfiguration,
        processRunner: ultraGridRunner
    )

    try ultraGridReport.validate()
    #expect(ultraGridReport.plan.launchKind == .internalUltraGridMvtp)
    #expect(ultraGridReport.plan.executable == nil)
    #expect(ultraGridReport.process == nil)
    #expect(ultraGridReport.ultraGridMedia != nil)
    #expect(!ultraGridReport.dryRun)
}

@Test
func externalConnectorJackTripRealRunWithoutExplicitExecutableWritesHostReadinessReport() throws {
    let jackTripRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: false,
            error: "mock host readiness: uv not executed"
        )
    ])
    let jackTripConfiguration = ExternalConnectorSessionConfiguration(.init(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-default-process.json"
    ) { input in
  input.dryRun = false
        input.mediaMode = .audioVideo
        input.durationSeconds = 1
        input.peerAudioPort = 4464
    })
    let jackTripReport = try ExternalConnectorSessionRunner.run(
        configuration: jackTripConfiguration,
        processRunner: jackTripRunner
    )

    try jackTripReport.validate()
    #expect(jackTripReport.plan.executable == nil)
    #expect(jackTripReport.plan.auxiliaryProcesses.first?.executable == "uv")
    #expect(jackTripReport.process == nil)
    #expect(jackTripReport.jackTripMedia != nil)
    #expect(jackTripReport.auxiliaryProcesses.count == 1)
    #expect(jackTripReport.auxiliaryProcesses.first?.error ==
        "mock host readiness: uv not executed")
}
