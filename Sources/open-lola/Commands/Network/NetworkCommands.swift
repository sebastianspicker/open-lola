import Darwin
import Foundation
import OpenLolaCore

private typealias NetworkReportValidator = @Sendable (String) throws -> Void

private let simpleNetworkReportValidators: [String: NetworkReportValidator] = [
    "validate-reference-rig-report": {
        try validateReport(at: $0, as: ReferenceRigReport.self, label: "reference rig report")
    },
    "validate-loopback-report": {
        try validateReport(at: $0, as: EndpointLoopbackReport.self, label: "endpoint-loopback report")
    },
    "validate-rme-fastest-audio-report": {
        try validateReport(at: $0, as: RmeFastestAudioPathReport.self, label: "RME fastest audio report")
    },
    "validate-realtime-audio-engine-report": {
        try validateReport(at: $0, as: RealtimeAudioEngineReport.self, label: "realtime audio engine report")
    },
    "validate-audio-loopback-run-report": {
        try validateReport(
            at: $0,
            as: AudioLoopbackRunReport.self,
            label: "audio loopback run report",
            extraLines: {
                [
                    "state: \($0.state.rawValue)",
                    "can-start-ioproc: \($0.preflight.canStartIOProc)",
                    "blockers: \($0.preflight.blockers.count)",
                ]
            }
        )
    },
    "validate-route-report": {
        try validateReport(at: $0, as: UdpPcmRouteReport.self, label: "udp-pcm route report")
    },
    "validate-route-certification-report": {
        try validateReport(
            at: $0,
            as: MacToMacRouteCertificationReport.self,
            label: "Mac-to-Mac route certification report"
        )
    },
    "validate-udp-pcm-loopback-report": {
        try validateReport(at: $0, as: UdpPcmLoopbackReport.self, label: "udp-pcm loopback report")
    },
    "validate-network-diagnostics-report": {
        try validateReport(at: $0, as: NetworkDiagnosticsReport.self, label: "network diagnostics report")
    },
    "validate-nat-friendly-route-report": {
        try validateReport(at: $0, as: NatFriendlyRouteReport.self, label: "NAT-friendly route report")
    },
    "validate-mac-to-mac-connection-establishment-report": {
        try validateReport(
            at: $0,
            as: MacToMacConnectionEstablishmentReport.self,
            label: "Mac-to-Mac connection establishment report"
        )
    },
    "validate-direct-p2p-session-report": {
        try validateReport(at: $0, as: DirectPeerSessionReport.self, label: "direct P2P session report")
    },
    "validate-direct-p2p-mesh-topology-report": {
        try validateReport(
            at: $0,
            as: DirectPeerMeshTopologyReport.self,
            label: "direct P2P mesh topology report"
        )
    },
    "validate-direct-p2p-mesh-runtime-report": {
        try validateReport(
            at: $0,
            as: DirectPeerMeshRuntimeReport.self,
            label: "direct P2P mesh runtime report"
        )
    },
    "validate-direct-p2p-two-peer-plan-report": {
        try validateReport(
            at: $0,
            as: DirectPeerTwoPeerRunPlanReport.self,
            label: "direct P2P two-peer plan report"
        )
    },
    "validate-direct-p2p-two-peer-report": {
        try validateReport(
            at: $0,
            as: DirectPeerTwoPeerPrototypeReport.self,
            label: "direct P2P two-peer report"
        )
    },
    "validate-direct-p2p-two-peer-prototype-report": {
        try validateReport(
            at: $0,
            as: DirectPeerTwoPeerPrototypeReport.self,
            label: "direct P2P two-peer prototype report"
        )
    },
]

func handleNetworkCommand(_ arguments: [String]) throws -> Bool {
    if arguments.count == 2, let validate = simpleNetworkReportValidators[arguments[0]] {
        try validate(arguments[1])
        return true
    }
    if try handleNetworkCoreCommand(arguments) {
        return true
    }
    if try handleNetworkNatCommand(arguments) {
        return true
    }
    if try handleNetworkDirectP2PCommand(arguments) {
        return true
    }
    return false
}

private func handleNetworkCoreCommand(_ arguments: [String]) throws -> Bool {
    if try handleNetworkUdpCommand(arguments) {
        return true
    }
    if try handleNetworkConnectionEvidenceCommand(arguments) {
        return true
    }
    return false
}

private func handleNetworkUdpCommand(_ arguments: [String]) throws -> Bool {
    if try handleNetworkUdpSimpleCommand(arguments) {
        return true
    }
    if try handleNetworkUdpRunCommand(arguments) {
        return true
    }
    return false
}

private func handleNetworkUdpSimpleCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["device-inventory"]:
        let report = try CoreAudioInventoryReader().capture()
        try report.validate()
        print(try report.prettyJSONString())
    case let args where args.count == 2 && args[0] == "validate-udp-pcm-packet":
        try validateUdpPcmPacketCommand(args[1])
    case ["udp-pcm-route-run", "--help"], ["udp-pcm-route-run", "-h"]:
        printUdpPcmRouteRunUsage()
    case let args where args.count == 3 && args[0] == "validate-udp-pcm-loopback-session":
        try validateUdpPcmLoopbackSessionCommand(firstPath: args[1], secondPath: args[2])
    case ["udp-pcm-loopback-localhost-smoke"]:
        let report = try UdpPcmLoopbackLocalhostSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    default:
        return false
    }
    return true
}

private func handleNetworkUdpRunCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case let args where args.first == "audio-loopback-run":
        try runAudioLoopbackCommand(args)
    case let args where args.first == "udp-pcm-route-run":
        try runUdpPcmRouteCommand(args)
    case let args where args.first == "udp-pcm-loopback-run":
        try runUdpPcmLoopbackCommand(args)
    default:
        return false
    }
    return true
}

private func handleNetworkConnectionEvidenceCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case let args where args.first == "network-diagnostics-run":
        try runNetworkDiagnosticsCommand(args)
    case let args where args.first == "mac-to-mac-connection-preflight-run":
        try runMacToMacConnectionPreflightCommand(args)
    case ["verify-direct-p2p-session-evidence-bundle", "--help"],
        ["verify-direct-p2p-session-evidence-bundle", "-h"]:
        print("Usage: open-lola verify-direct-p2p-session-evidence-bundle <report.json> <bundle-root>")
    case let args where args.count == 3 && args[0] == "verify-direct-p2p-session-evidence-bundle":
        try verifyDirectP2PSessionEvidenceBundleCommand(reportPath: args[1], bundleRootPath: args[2])
    case let args where args.count == 2 && args[0] == "validate-direct-p2p-two-peer-local-run-report":
        try validateDirectP2PTwoPeerLocalRunReportCommand(args[1])
    default:
        return false
    }
    return true
}

private func runAudioLoopbackCommand(_ args: [String]) throws {
    let configuration = try AudioLoopbackRunConfiguration.parse(Array(args.dropFirst()))
    let report = try CoreAudioLoopbackRunner().run(configuration: configuration)
    try report.validate()
    let outputURL = URL(fileURLWithPath: configuration.outputPath)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
    print("audio-loopback run report written: \(configuration.outputPath)")
    print("state: \(report.state.rawValue)")
    printVerdict(report.verdict)
}

private func validateUdpPcmPacketCommand(_ packetPath: String) throws {
    let packetURL = URL(fileURLWithPath: packetPath)
    let packetData = try readPacketData(from: packetURL)
    let packet = try UdpPcmPacket.decode(packetData)
    print(
        "udp-pcm packet valid: seq=\(packet.header.sequenceNumber) "
            + "frames=\(packet.header.framesPerPacket) "
            + "channels=\(packet.header.channelCount) "
            + "format=\(packet.header.sampleFormat)"
    )
    printVerdict(.pass)
}

private func validateUdpPcmLoopbackSessionCommand(firstPath: String, secondPath: String) throws {
    let first = try UdpPcmLoopbackReport.readValidated(fromPath: firstPath)
    let second = try UdpPcmLoopbackReport.readValidated(fromPath: secondPath)
    try first.validateSessionPair(with: second)
    print("udp-pcm loopback session valid: \(first.session.sessionID)")
    print("reports: \(first.id), \(second.id)")
    printVerdict(.partial)
}

private func runUdpPcmRouteCommand(_ args: [String]) throws {
    let configuration = try UdpPcmRouteRunConfiguration.parse(Array(args.dropFirst()))
    switch configuration.role {
    case .sender:
        let summary = try UdpPcmContinuousRouteRunner.runSender(configuration: configuration)
        try writeJSONData(try summary.prettyJSONData(), to: configuration.outputPath)
        print("udp-pcm continuous sender summary written: \(configuration.outputPath)")
        print("packets-sent: \(summary.packetsSent)")
        printVerdict(summary.verdict)
    case .receiver:
        let report = try UdpPcmContinuousRouteRunner.runReceiver(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("udp-pcm continuous receiver report written: \(configuration.outputPath)")
        print("packets-received: \(report.metrics.packetsReceived)")
        printVerdict(report.verdict)
    }
}

private func runUdpPcmLoopbackCommand(_ args: [String]) throws {
    let configuration = try UdpPcmLoopbackRunConfiguration.parse(Array(args.dropFirst()))
    let result: (report: UdpPcmLoopbackReport, debugTrace: DebugTrace?)
    do {
        result = try UdpPcmLoopbackRunner.run(configuration: configuration)
    } catch let failure as DebugTracedRunFailure {
        if let debugOutputPath = configuration.debugOutputPath {
            try failure.debugTrace.write(to: debugOutputPath)
        }
        throw CommandError.loopbackRunFailed(failure.failureDescription)
    }
    try result.report.validate()
    try writeJSONData(try result.report.prettyJSONData(), to: configuration.outputPath)
    if let debugTrace = result.debugTrace,
       let debugOutputPath = configuration.debugOutputPath {
        try debugTrace.write(to: debugOutputPath)
    }
    print("udp-pcm loopback report written: \(configuration.outputPath)")
    print("role: \(configuration.role.rawValue)")
    print("packets-echoed: \(result.report.metrics.packetsEchoed)")
    print("byte-exact-echo: \(result.report.metrics.byteExactEcho)")
    print("reciprocal-command: \(configuration.reciprocalCommand())")
    printVerdict(result.report.verdict)
}

private func runNetworkDiagnosticsCommand(_ args: [String]) throws {
    let configuration = try NetworkDiagnosticsRunConfiguration.parse(Array(args.dropFirst()))
    let report = NetworkDiagnosticsRunner.run(configuration: configuration)
    try report.validate()
    try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
    print("network diagnostics report written: \(configuration.outputPath)")
    print("peer: \(configuration.peer)")
    print("traceroute-blocked: \(report.traceroute.blocked)")
    printVerdict(report.verdict)
}

private func runMacToMacConnectionPreflightCommand(_ args: [String]) throws {
    let configuration = try MacToMacConnectionEstablishmentRunConfiguration.parse(Array(args.dropFirst()))
    let report = try MacToMacConnectionEstablishmentRunner.run(configuration: configuration)
    try report.validate()
    try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
    print("Mac-to-Mac connection preflight report written: \(configuration.outputPath)")
    print("setup-mode: \(report.setupMode.rawValue)")
    print("selected-route: \(report.selectedRoute.rawValue)")
    print("blockers: \(report.blockers.count)")
    printVerdict(report.verdict)
}

private func verifyDirectP2PSessionEvidenceBundleCommand(reportPath: String, bundleRootPath: String) throws {
    let report = try DirectPeerSessionReport.decode(from: BoundedFileReader.data(atPath: reportPath))
    let verification = try DirectPeerSessionEvidenceBundleVerifier.verify(
        report: report,
        bundleRoot: URL(fileURLWithPath: bundleRootPath, isDirectory: true)
    )
    print("direct P2P session evidence bundle valid: \(verification.reportID)")
    print("bundle-root: \(verification.bundleRootPath)")
    print("artifacts-verified: \(verification.verifiedArtifacts.count)")
    printVerdict(.pass)
}

private func validateDirectP2PTwoPeerLocalRunReportCommand(_ reportPath: String) throws {
    let report = try DirectPeerTwoPeerLocalRunReport.readValidated(fromPath: reportPath)
    try report.validateReferencedArtifacts()
    let outputText = [
        "direct P2P two-peer local supervisor report valid: \(report.id)",
        "VERDICT: \(report.verdict.rawValue.uppercased())",
    ].joined(separator: "\n") + "\n"
    try FileHandle.standardOutput.write(
        contentsOf: Data(outputText.utf8)
    )
}

private func printUdpPcmRouteRunUsage() {
    print("Usage: open-lola udp-pcm-route-run --role <sender|receiver> --peer <ip> --port <port> --sample-rate <hz> --frames <frames> --channels <channels> --duration-seconds <seconds> --output <path> [options]")
    print("")
    print("Options:")
    for flag in [
        "--bind-host",
        "--dscp",
        "--route-kind",
        "--route-label",
        "--route-topology",
        "--sender-label",
        "--sender-host",
        "--sender-interface",
        "--sender-ip",
        "--receiver-label",
        "--receiver-host",
        "--receiver-interface",
        "--receiver-ip",
        "--link-rate-mbps",
        "--vlan",
        "--multicast-policy",
        "--dscp-observed",
        "--dscp-classification",
        "--dscp-not-tested-reason",
        "--capture-point",
        "--capture-correlated",
        "--capture-notes",
        "--report-id",
        "--title",
        "--notes",
        "--verdict",
    ] {
        print("  \(flag)")
    }
}
