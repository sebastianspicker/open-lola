// Translates NetworkDirectP2PCommands command syntax into core API calls, keeping CLI parsing independent from domain services.
import Foundation
import OpenLolaCore

func handleNetworkDirectP2PCommand(_ arguments: [String]) throws -> Bool {
    if try handleNetworkDirectP2PLocalhostCommand(arguments) {
        return true
    }
    if try handleNetworkDirectP2PMeshCommand(arguments) {
        return true
    }
    if try handleNetworkDirectP2PTwoPeerCommand(arguments) {
        return true
    }
    if try handleNetworkDirectP2PSessionCommand(arguments) {
        return true
    }
    return false
}

private func handleNetworkDirectP2PLocalhostCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["direct-p2p-localhost-smoke"]:
        let result = try DirectP2PLocalhostSmoke.run()
        try result.report.validate()
        print(try result.report.prettyJSONString())
        printVerdict(result.report.verdict)
    case let args where args.count == 3 && args[0] == "direct-p2p-localhost-smoke" && args[1] == "--output":
        let result = try DirectP2PLocalhostSmoke.run()
        try result.report.validate()
        try writeJSONData(try result.report.prettyJSONData(), to: args[2])
        print("direct P2P localhost smoke report written: \(args[2])")
        print("packets-sent: \(result.report.metrics.packetsSent)")
        print("packets-received: \(result.report.metrics.packetsReceived)")
        printVerdict(result.report.verdict)
    default:
        return false
    }
    return true
}

private func handleNetworkDirectP2PMeshCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case let args where args.first == "direct-p2p-mesh-topology-synthetic-smoke":
        try runDirectP2PMeshTopologyCommand(args)
    case let args where args.first == "direct-p2p-mesh-runtime-localhost-smoke":
        try runDirectP2PMeshRuntimeCommand(args)
    default:
        return false
    }
    return true
}

private func handleNetworkDirectP2PTwoPeerCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case let args where args.first == "direct-p2p-two-peer-plan-run":
        try runDirectP2PTwoPeerPlanCommand(args)
    case ["direct-p2p-two-peer-report", "--help"],
         ["direct-p2p-two-peer-report", "-h"],
         ["direct-p2p-two-peer-report", "help"]:
        printDirectP2PTwoPeerPrototypeReportUsage(commandName: "direct-p2p-two-peer-report")
    case let args where args.first == "direct-p2p-two-peer-report":
        try runDirectP2PTwoPeerPrototypeReportCommand(
            Array(args.dropFirst()),
            outputLabel: "direct P2P two-peer report"
        )
    case ["direct-p2p-two-peer-prototype-report", "--help"],
         ["direct-p2p-two-peer-prototype-report", "-h"],
         ["direct-p2p-two-peer-prototype-report", "help"]:
        printDirectP2PTwoPeerPrototypeReportUsage()
    case let args where args.first == "direct-p2p-two-peer-prototype-report":
        try runDirectP2PTwoPeerPrototypeReportCommand(Array(args.dropFirst()))
    case let args where args.first == "direct-p2p-two-peer-local-run":
        try runDirectP2PTwoPeerLocalRunCommand(Array(args.dropFirst()))
    default:
        return false
    }
    return true
}

private func handleNetworkDirectP2PSessionCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["direct-p2p-session-run", "--help"],
         ["direct-p2p-session-run", "-h"],
         ["direct-p2p-session-run", "help"]:
        printDirectP2PSessionRunUsage()
    case let args where args.first == "direct-p2p-session-run":
        try runDirectP2PSessionCommand(args)
    default:
        return false
    }
    return true
}

private func runDirectP2PMeshTopologyCommand(_ args: [String]) throws {
    let values = try parseDirectP2PMeshTopologyArguments(Array(args.dropFirst()))
    let peerCount = try directP2PMeshTopologyPeerCount(values)
    let outputPath = try directP2PMeshTopologyOutputPath(values)
    let report = try DirectPeerMeshTopologySmoke.run(peerCount: peerCount)
    try report.validate()
    try writeJSONData(try report.prettyJSONData(), to: outputPath)
    print("direct P2P mesh topology report written: \(outputPath)")
    print("peers: \(report.metrics.peerCount)")
    print("directed-routes: \(report.metrics.configuredDirectedRouteCount)")
    printVerdict(report.verdict)
}

private func runDirectP2PMeshRuntimeCommand(_ args: [String]) throws {
    let values = try parseDirectP2PMeshRuntimeArguments(Array(args.dropFirst()))
    let peerCount = try directP2PMeshRuntimePeerCount(values)
    let packetCount = try directP2PMeshRuntimePacketCount(values)
    let outputPath = try directP2PMeshRuntimeOutputPath(values)
    let report = try DirectPeerMeshRuntimeSmoke.run(
        peerCount: peerCount,
        packetCount: packetCount
    )
    try report.validate()
    try writeJSONData(try report.prettyJSONData(), to: outputPath)
    print("direct P2P mesh runtime report written: \(outputPath)")
    print("peers: \(report.metrics.peerCount)")
    print("directed-routes: \(report.metrics.directedRouteCount)")
    print("audio-deadlines-received: \(report.metrics.audioDeadlinesReceived)")
    print("audio-fragments-received: \(report.metrics.audioFragmentsReceived)")
    printVerdict(report.verdict)
}

private func runDirectP2PTwoPeerPlanCommand(_ args: [String]) throws {
    let configuration = try DirectPeerTwoPeerRunPlanConfiguration.parse(Array(args.dropFirst()))
    let report = try DirectPeerTwoPeerRunPlanner.makeReport(configuration: configuration)
    try report.validate()
    try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
    print("direct P2P two-peer plan written: \(configuration.outputPath)")
    print("run-dir: \(report.runDirectory)")
    print("commands: \(report.commands.count)")
    printVerdict(report.verdict)
}

private func runDirectP2PSessionCommand(_ args: [String]) throws {
    let values = try parseDirectP2PSessionRunArguments(Array(args.dropFirst()))
    let mediaMode = try directP2PSessionMediaMode(values)
    try directP2PValidateAudioCompressionScope(values, mediaMode: mediaMode)
    let packetCount = try directP2PSessionRunPacketCount(values, mediaMode: mediaMode)
    let outputPath = try directP2PSessionRunOutputPath(values)
    var report = try runDirectP2PSession(values: values, mediaMode: mediaMode, packetCount: packetCount)
    report = try directP2PApplyMeasuredEvidence(report, values: values)
    report = directP2PAttachGeneratedReceiveEvidence(report, values: values)
    try report.validate()
    try directP2PWriteReceiveProofArtifacts(report, values: values)
    try directP2PWriteAutoEvidenceArtifact(report, values: values)
    try writeJSONData(try report.prettyJSONData(), to: outputPath)
    printDirectP2PSessionReportSummary(report, outputPath: outputPath)
}

private func runDirectP2PSession(
    values: [String: String],
    mediaMode: DirectPeerSessionMediaMode,
    packetCount: Int
) throws -> DirectPeerSessionReport {
    let onReady = directP2PReadyFileWriter(values)
    if mediaMode == .audioVideo {
        return try DirectPeerSessionSocketRunner.runManualAddressAudioVideo(
            configuration: try directP2PSessionAVConfiguration(values),
            onReady: onReady
        )
    }
    if values["--role"] == nil {
        return try DirectPeerSessionSocketRunner.runLoopback(packetCount: packetCount)
    }
    return try DirectPeerSessionSocketRunner.runManualAddress(
        configuration: try directP2PSessionManualConfiguration(
            values,
            packetCount: packetCount
        ),
        onReady: onReady
    )
}

private func printDirectP2PSessionReportSummary(_ report: DirectPeerSessionReport, outputPath: String) {
    print("direct P2P socket session report written: \(outputPath)")
    print("control-datagrams-sent: \(report.metrics.controlDatagramsSent ?? 0)")
    print("audio-metadata-messages-sent: \(report.metrics.audioMetadataMessagesSent)")
    print("audio-metadata-messages-received: \(report.metrics.audioMetadataMessagesReceived)")
    print("timing-probe-packets-sent: \(report.metrics.timingProbePacketsSent)")
    print("timing-probe-packets-received: \(report.metrics.timingProbePacketsReceived)")
    print("timing-probe-max-age-us: \(report.metrics.timingProbeMaxAgeMicroseconds)")
    print("packets-sent: \(report.metrics.packetsSent)")
    print("packets-received: \(report.metrics.packetsReceived)")
    if let avRuntime = report.avRuntime {
        print("quality-policy: \(avRuntime.qualityPolicy?.rawValue ?? "unknown")")
        print("useful-media-proof: \(avRuntime.usefulMediaProof.rawValue)")
    }
    printVerdict(report.verdict)
}
