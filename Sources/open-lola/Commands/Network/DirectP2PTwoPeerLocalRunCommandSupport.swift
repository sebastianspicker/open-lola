import Dispatch
import Foundation
import OpenLolaCore

private let directP2PTwoPeerRunTimeoutSlackSeconds = 10
private let directP2PTwoPeerTerminationGraceSeconds = 2

func runDirectP2PTwoPeerLocalRunCommand(_ arguments: [String]) throws {
    let options = try DirectP2PTwoPeerLocalRunOptions.parse(arguments)
    let plan = try DirectPeerTwoPeerRunPlanReport.readValidated(fromPath: options.planPath)
    try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: plan.runDirectory),
        withIntermediateDirectories: true
    )
    let processResults = options.execute
        ? try runDirectP2PTwoPeerLocalProcesses(plan: plan, options: options)
        : nil
    var aggregateFailureReason: String?
    let aggregateReportPath = processResults.flatMap {
        do {
            return try writeAggregatePrototypeReport(plan: plan, processResults: $0)
        } catch {
            aggregateFailureReason = String(describing: error)
            return nil
        }
    }
    let report = try DirectPeerTwoPeerLocalRunReportBuilder.makeReport(
        plan: plan,
        executed: options.execute,
        processResults: processResults,
        aggregateReportPath: aggregateReportPath,
        aggregateExecuted: aggregateReportPath != nil,
        aggregateFailureReason: aggregateFailureReason,
        executionMode: options.executionMode,
        remoteTargets: options.remoteTargets(for: plan)
    )
    try writeJSONData(try report.prettyJSONData(), to: options.outputPath)
    print("direct P2P two-peer supervisor report written: \(options.outputPath)")
    print("executed: \(report.executed)")
    print("executionMode: \(report.executionMode.rawValue)")
    print("processes: \(report.processResults.count)")
    if let aggregateReportPath = report.aggregateReportPath {
        print("aggregateReport: \(aggregateReportPath)")
    }
    if let aggregateFailureReason {
        print("aggregateFailure: \(aggregateFailureReason)")
    }
    printVerdict(report.verdict)
}

private func runDirectP2PTwoPeerLocalProcesses(
    plan: DirectPeerTwoPeerRunPlanReport,
    options: DirectP2PTwoPeerLocalRunOptions
) throws -> [DirectPeerTwoPeerLocalRunProcessResult] {
    if options.requirePreflight {
        try validateConnectionPreflight(options.connectionPreflightReportPath)
        let checks = DirectPeerTwoPeerRunPreflight.makeChecks(
            plan: plan,
            executionMode: options.executionMode,
            remoteTargets: options.remoteTargets(for: plan)
        )
        let failures = checks.filter { !$0.passed && $0.severity == .fail }
        if !failures.isEmpty {
            throw CommandError.invalidArgument("preflight failed: \(failures.map(\.id).joined(separator: ","))")
        }
    }
    let responderCommands = plan.commands.filter { $0.role == .responder }
    let initiatorCommands = plan.commands.filter { $0.role == .initiator }
    guard responderCommands.count == 1, initiatorCommands.count == 1 else {
        throw CommandError.invalidArgument("plan must contain one responder and one initiator")
    }
    let responder = try startDirectP2PProcess(
        command: responderCommands[0],
        runDirectory: plan.runDirectory,
        options: options,
        readyFilePath: directP2PReadyFilePath(runDirectory: plan.runDirectory, peerID: responderCommands[0].peerID)
    )
    let initiator: RunningDirectP2PProcess
    do {
        try waitForDirectP2PReadyFile(responder, timeoutMilliseconds: options.readinessDelayMilliseconds)
        initiator = try startDirectP2PProcess(
            command: initiatorCommands[0],
            runDirectory: plan.runDirectory,
            options: options,
            readyFilePath: nil
        )
    } catch {
        if responder.process.isRunning {
            terminateExpiredDirectP2PProcesses([responder])
        }
        throw error
    }
    let runTimeoutSeconds = try directP2PTwoPeerRunTimeoutSeconds(plan: plan)
    let deadline = DispatchTime.now() + .seconds(runTimeoutSeconds)
    if !waitForDirectP2PProcessesToExit([initiator, responder], deadline: deadline) {
        terminateExpiredDirectP2PProcesses([initiator, responder])
    }
    return [
        try responder.result(
            exitCode: directP2PExitCode(for: responder.process),
            options: options,
            runDirectory: plan.runDirectory
        ),
        try initiator.result(
            exitCode: directP2PExitCode(for: initiator.process),
            options: options,
            runDirectory: plan.runDirectory
        ),
    ]
}

private func directP2PTwoPeerRunTimeoutSeconds(plan: DirectPeerTwoPeerRunPlanReport) throws -> Int {
    let requestedSeconds = plan.commands
        .flatMap { command in
            [
                directP2PArgumentPositiveInt("--duration-seconds", in: command.arguments),
                directP2PArgumentPositiveInt("--timeout-seconds", in: command.arguments),
            ].compactMap { $0 }
        }
        .max() ?? 1
    let (timeoutSeconds, overflow) = requestedSeconds.addingReportingOverflow(
        directP2PTwoPeerRunTimeoutSlackSeconds
    )
    guard !overflow, timeoutSeconds > 0 else {
        throw CommandError.invalidArgument("direct P2P child run timeout overflow")
    }
    return timeoutSeconds
}

private func waitForDirectP2PProcessesToExit(
    _ processes: [RunningDirectP2PProcess],
    deadline: DispatchTime
) -> Bool {
    ManagedProcessRunner.waitUntilExit(processes.map(\.process), deadline: deadline)
}

private func terminateExpiredDirectP2PProcesses(_ processes: [RunningDirectP2PProcess]) {
    ManagedProcessRunner.terminate(
        processes.map(\.process),
        graceSeconds: TimeInterval(directP2PTwoPeerTerminationGraceSeconds)
    )
}

private func directP2PExitCode(for process: ManagedProcess) -> Int {
    process.isRunning ? -1 : Int(process.terminationStatus)
}

private struct RunningDirectP2PProcess {
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
            peerID: command.peerID,
            role: command.role,
            reportPath: command.outputReportPath,
            command: launchedArguments,
            stdoutPath: stdoutPath,
            stderrPath: stderrPath,
            exitCode: exitCode,
            executionMode: executionMode,
            remoteTarget: remoteTarget,
            collectedReportPath: collected.reportPath,
            collectedReceiveProofPath: collected.receiveProofPath,
            startedAt: startedAt,
            finishedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}

private func startDirectP2PProcess(
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
    let launchedArguments: [String]
    if options.executionMode == .ssh {
        guard let remoteTarget else {
            throw CommandError.invalidArgument("missing SSH target for \(command.peerID)")
        }
        launchedArguments = [options.sshExecutable, remoteTarget] + remoteShellArguments(
            childArguments,
            workingDirectory: options.remoteWorkingDirectory(for: command)
        )
    } else {
        launchedArguments = childArguments
    }
    let stdoutPath = "\(runDirectory)/\(command.peerID)-stdout.log"
    let stderrPath = "\(runDirectory)/\(command.peerID)-stderr.log"
    let process = try ManagedProcessRunner.start(
        executable: launchedArguments[0],
        arguments: Array(launchedArguments.dropFirst()),
        standardOutputPath: stdoutPath,
        standardErrorPath: stderrPath
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

private func directP2PChildArguments(
    _ arguments: [String],
    executablePath: String?,
    readyFilePath: String?
) -> [String] {
    var arguments = arguments
    if let executablePath {
        arguments[0] = executablePath
    }
    if let readyFilePath {
        arguments += ["--ready-file", readyFilePath]
    }
    return arguments
}

private func directP2PReadyFilePath(runDirectory: String, peerID: String) -> String {
    "\(runDirectory)/.\(peerID)-ready-\(UUID().uuidString)"
}

private func waitForDirectP2PReadyFile(
    _ process: RunningDirectP2PProcess,
    timeoutMilliseconds: Int
) throws {
    let deadline = DispatchTime.now() + .milliseconds(timeoutMilliseconds)
    while DispatchTime.now() < deadline {
        if directP2PReadyFileExists(process) {
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

private func directP2PReadyFileExists(_ process: RunningDirectP2PProcess) -> Bool {
    guard let readyFilePath = directP2PReadyFilePath(from: process.launchedArguments) else {
        return true
    }
    guard process.executionMode == .ssh, let remoteTarget = process.remoteTarget else {
        return FileManager.default.fileExists(atPath: readyFilePath)
    }
    do {
        let exitCode = try ManagedProcessRunner.runToExit(
            executable: process.launchedArguments[0],
            arguments: ["-o", "BatchMode=yes", remoteTarget, "test -f \(shellQuoted(readyFilePath))"]
        )
        return exitCode == 0
    } catch {
        return false
    }
}

private func directP2PReadyFilePath(from arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: "--ready-file"),
          index + 1 < arguments.count else {
        return nil
    }
    return arguments[index + 1]
}

private func remoteShellArguments(_ arguments: [String], workingDirectory: String?) -> [String] {
    let command = arguments.map(shellQuoted).joined(separator: " ")
    guard let workingDirectory, !workingDirectory.isEmpty else {
        return [command]
    }
    return ["cd \(shellQuoted(workingDirectory)) && \(command)"]
}

private func shellQuoted(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
}

private struct DirectP2PTwoPeerLocalRunOptions {
    var planPath: String
    var outputPath: String
    var execute: Bool
    var executablePath: String?
    var executionMode: DirectPeerTwoPeerRunExecutionMode
    var macASSH: String?
    var macBSSH: String?
    var macAExecutable: String?
    var macBExecutable: String?
    var macAWorkingDirectory: String?
    var macBWorkingDirectory: String?
    var sshExecutable: String
    var scpExecutable: String
    var sshFallbackExplicit: Bool
    var sshFallbackReason: String?
    var readinessDelayMilliseconds: Int
    var requirePreflight: Bool
    var connectionPreflightReportPath: String?

    static func parse(_ arguments: [String]) throws -> DirectP2PTwoPeerLocalRunOptions {
        let values = try directP2PTwoPeerLocalRunValues(arguments)
        let options = DirectP2PTwoPeerLocalRunOptions(
            planPath: try directP2PTwoPeerLocalRunRequired("--plan", values),
            outputPath: try directP2PTwoPeerLocalRunRequired("--output", values),
            execute: try directP2PTwoPeerLocalRunBool(values["--execute"]),
            executablePath: values["--executable"],
            executionMode: try directP2PTwoPeerExecutionMode(values["--execution-mode"]),
            macASSH: values["--mac-a-ssh"],
            macBSSH: values["--mac-b-ssh"],
            macAExecutable: values["--mac-a-executable"],
            macBExecutable: values["--mac-b-executable"],
            macAWorkingDirectory: values["--mac-a-workdir"],
            macBWorkingDirectory: values["--mac-b-workdir"],
            sshExecutable: values["--ssh-executable"] ?? "/usr/bin/ssh",
            scpExecutable: values["--scp-executable"] ?? "/usr/bin/scp",
            sshFallbackExplicit: try directP2PTwoPeerLocalRunBool(values["--ssh-fallback-explicit"]),
            sshFallbackReason: values["--ssh-fallback-reason"],
            readinessDelayMilliseconds: try directP2PTwoPeerLocalRunPositiveInt(
                values["--readiness-delay-ms"],
                defaultValue: 300,
                label: "--readiness-delay-ms"
            ),
            requirePreflight: try directP2PTwoPeerLocalRunBool(values["--require-preflight"]),
            connectionPreflightReportPath: values["--connection-preflight-report"]
        )
        try options.validate()
        return options
    }

    func validate() throws {
        if requirePreflight {
            guard connectionPreflightReportPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw CommandError.invalidArgument("missing --connection-preflight-report")
            }
        }
        guard executionMode == .ssh else {
            return
        }
        guard sshFallbackExplicit else {
            throw CommandError.invalidArgument("ssh execution requires --ssh-fallback-explicit true")
        }
        guard sshFallbackReason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw CommandError.invalidArgument("ssh execution requires --ssh-fallback-reason")
        }
        guard macASSH?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw CommandError.invalidArgument("ssh execution requires --mac-a-ssh")
        }
        guard macBSSH?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw CommandError.invalidArgument("ssh execution requires --mac-b-ssh")
        }
    }

    func sshTarget(for command: DirectPeerTwoPeerRunCommand) -> String? {
        switch command.role {
        case .initiator:
            return macASSH
        case .responder:
            return macBSSH
        }
    }

    func remoteTargets(for plan: DirectPeerTwoPeerRunPlanReport) -> [String: String] {
        Dictionary(uniqueKeysWithValues: plan.commands.compactMap { command in
            sshTarget(for: command).map { (command.peerID, $0) }
        })
    }

    func executablePath(for command: DirectPeerTwoPeerRunCommand) -> String? {
        switch command.role {
        case .initiator:
            return macAExecutable ?? executablePath
        case .responder:
            return macBExecutable ?? executablePath
        }
    }

    func remoteWorkingDirectory(for command: DirectPeerTwoPeerRunCommand) -> String? {
        switch command.role {
        case .initiator:
            return macAWorkingDirectory
        case .responder:
            return macBWorkingDirectory
        }
    }
}

private func writeAggregatePrototypeReport(
    plan: DirectPeerTwoPeerRunPlanReport,
    processResults: [DirectPeerTwoPeerLocalRunProcessResult]
) throws -> String? {
    guard processResults.allSatisfy({ $0.exitCode == 0 }) else {
        return nil
    }
    let peerA = try aggregatePeerInput(role: .initiator, processResults: processResults)
    let peerB = try aggregatePeerInput(role: .responder, processResults: processResults)
    let peerAReport = try loadJSON(DirectPeerSessionReport.self, from: peerA.reportPath)
    let peerBReport = try loadJSON(DirectPeerSessionReport.self, from: peerB.reportPath)
    let peerAProof = try loadJSON(DirectPeerSessionReceiveProofArtifact.self, from: peerA.receiveProofPath)
    let peerBProof = try loadJSON(DirectPeerSessionReceiveProofArtifact.self, from: peerB.receiveProofPath)
    let report = try DirectPeerTwoPeerPrototypeReportBuilder.makeReport(
        peerAReportPath: peerA.reportPath,
        peerAReport: peerAReport,
        peerARXProofPath: peerA.receiveProofPath,
        peerARXProof: peerAProof,
        peerBReportPath: peerB.reportPath,
        peerBReport: peerBReport,
        peerBRXProofPath: peerB.receiveProofPath,
        peerBRXProof: peerBProof
    )
    let outputPath = "\(plan.runDirectory)/m06-direct-p2p-two-peer-prototype.json"
    try writeJSONData(try report.prettyJSONData(), to: outputPath)
    return outputPath
}

private func validateConnectionPreflight(_ path: String?) throws {
    guard let path, !path.isEmpty else {
        throw CommandError.invalidArgument("missing --connection-preflight-report")
    }
    let report = try MacToMacConnectionEstablishmentReport.readValidated(fromPath: path)
    guard report.verdict == .pass else {
        throw CommandError.invalidArgument("connection preflight did not pass: \(report.verdict.rawValue)")
    }
}

private func aggregatePeerInput(
    role: DirectPeerSessionManualRole,
    processResults: [DirectPeerTwoPeerLocalRunProcessResult]
) throws -> (reportPath: String, receiveProofPath: String) {
    guard let result = processResults.first(where: { $0.role == role }) else {
        throw CommandError.invalidArgument("missing aggregate peer result for \(role.rawValue)")
    }
    let reportPath = result.collectedReportPath ?? result.reportPath
    let receiveProofPath = result.collectedReceiveProofPath ?? rxProofPath(for: result.reportPath)
    return (reportPath, receiveProofPath)
}

private func collectArtifactsIfNeeded(
    command: DirectPeerTwoPeerRunCommand,
    exitCode: Int,
    options: DirectP2PTwoPeerLocalRunOptions,
    runDirectory: String,
    remoteTarget: String?
) throws -> (reportPath: String?, receiveProofPath: String?) {
    guard options.executionMode == .ssh, exitCode == 0, let remoteTarget else {
        return (nil, nil)
    }
    let collectionDirectory = "\(runDirectory)/collected"
    try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: collectionDirectory),
        withIntermediateDirectories: true
    )
    let localReportPath = "\(collectionDirectory)/\(command.peerID)-report.json"
    let localRXProofPath = "\(collectionDirectory)/\(command.peerID)-rx-proof.json"
    let remoteRXProofPath = directP2PArgumentValue("--rx-proof-output", in: command.arguments)
    try runSCP(
        executable: options.scpExecutable,
        remoteTarget: remoteTarget,
        remotePath: command.outputReportPath,
        localPath: localReportPath
    )
    guard let remoteRXProofPath else {
        return (localReportPath, nil)
    }
    do {
        try runSCP(
            executable: options.scpExecutable,
            remoteTarget: remoteTarget,
            remotePath: remoteRXProofPath,
            localPath: localRXProofPath
        )
        return (localReportPath, localRXProofPath)
    } catch {
        print("warning: rx-proof collection skipped for \(command.peerID): \(error)")
        return (localReportPath, nil)
    }
}

private func runSCP(
    executable: String,
    remoteTarget: String,
    remotePath: String,
    localPath: String
) throws {
    let exitCode = try ManagedProcessRunner.runToExit(
        executable: executable,
        arguments: ["\(remoteTarget):\(remotePath)", localPath]
    )
    guard exitCode == 0 else {
        throw CommandError.invalidArgument("scp failed for \(remoteTarget):\(remotePath)")
    }
}

private func rxProofPath(for reportPath: String) -> String {
    if reportPath.hasSuffix(".json") {
        return String(reportPath.dropLast(5)) + "-rx-proof.json"
    }
    return reportPath + "-rx-proof.json"
}

private func directP2PArgumentValue(_ name: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        return nil
    }
    let value = arguments[index + 1]
    return value.hasPrefix("--") ? nil : value
}

private func directP2PArgumentPositiveInt(_ name: String, in arguments: [String]) -> Int? {
    guard let value = directP2PArgumentValue(name, in: arguments),
          let number = Int(value),
          number > 0 else {
        return nil
    }
    return number
}

private func directP2PTwoPeerLocalRunValues(_ arguments: [String]) throws -> [String: String] {
    let allowed = Set([
        "--plan",
        "--output",
        "--execute",
        "--executable",
        "--execution-mode",
        "--mac-a-ssh",
        "--mac-b-ssh",
        "--mac-a-executable",
        "--mac-b-executable",
        "--mac-a-workdir",
        "--mac-b-workdir",
        "--ssh-executable",
        "--scp-executable",
        "--ssh-fallback-explicit",
        "--ssh-fallback-reason",
        "--readiness-delay-ms",
        "--require-preflight",
        "--connection-preflight-report",
    ])
    return try KeyValueArgumentParser.parseValues(
        arguments,
        allowed: allowed,
        allowsDashPrefixedValues: false,
        unknown: { CommandError.invalidArgument("unknown \($0)") },
        duplicate: { CommandError.invalidArgument("duplicate \($0)") },
        missingValue: { CommandError.invalidArgument("missing value for \($0)") }
    )
}

private func directP2PTwoPeerLocalRunRequired(
    _ key: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[key], !value.isEmpty else {
        throw CommandError.invalidArgument("missing \(key)")
    }
    return value
}

private func directP2PTwoPeerLocalRunBool(_ value: String?) throws -> Bool {
    guard let value else {
        return false
    }
    switch value {
    case "true":
        return true
    case "false":
        return false
    default:
        throw CommandError.invalidArgument("invalid --execute")
    }
}

private func directP2PTwoPeerExecutionMode(_ value: String?) throws -> DirectPeerTwoPeerRunExecutionMode {
    guard let value else {
        return .local
    }
    guard let mode = DirectPeerTwoPeerRunExecutionMode(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --execution-mode")
    }
    return mode
}

private func directP2PTwoPeerLocalRunPositiveInt(
    _ value: String?,
    defaultValue: Int,
    label: String
) throws -> Int {
    guard let value else {
        return defaultValue
    }
    guard let parsed = Int(value), parsed > 0 else {
        throw CommandError.invalidArgument("invalid \(label)")
    }
    return parsed
}
