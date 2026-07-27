// Maps DirectP2PTwoPeerLocalRunCommandSupport CLI input into core calls, keeping argument normalization outside domain services.
import Dispatch
import Foundation
import OpenLolaCore

private let directP2PTwoPeerRunTimeoutSlackSeconds = 10

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
    var reportRequest = DirectPeerTwoPeerLocalRunReportRequest(plan: plan, executed: options.execute)
    reportRequest.processResults = processResults
    reportRequest.aggregateReportPath = aggregateReportPath
    reportRequest.aggregateExecuted = aggregateReportPath != nil
    reportRequest.aggregateFailureReason = aggregateFailureReason
    reportRequest.executionMode = options.executionMode
    reportRequest.remoteTargets = options.remoteTargets(for: plan)
    let report = try DirectPeerTwoPeerLocalRunReportBuilder.makeReport(request: reportRequest)
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
    try validateDirectP2PTwoPeerPreflight(plan: plan, options: options)
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
        )
    ]
}

private func validateDirectP2PTwoPeerPreflight(
    plan: DirectPeerTwoPeerRunPlanReport,
    options: DirectP2PTwoPeerLocalRunOptions
) throws {
    guard options.requirePreflight else { return }
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

private func directP2PTwoPeerRunTimeoutSeconds(plan: DirectPeerTwoPeerRunPlanReport) throws -> Int {
    let requestedSeconds = plan.commands
        .flatMap { command in
            [
                directP2PArgumentPositiveInt("--duration-seconds", in: command.arguments),
                directP2PArgumentPositiveInt("--timeout-seconds", in: command.arguments)
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

func collectArtifactsIfNeeded(
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
