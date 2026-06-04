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
    switch arguments {
    case ["device-inventory"]:
        let report = try CoreAudioInventoryReader().capture()
        try report.validate()
        print(try report.prettyJSONString())
    case let args where args.first == "audio-loopback-run":
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
    case let args where args.count == 2 && args[0] == "validate-udp-pcm-packet":
        let packetURL = URL(fileURLWithPath: args[1])
        let packetData = try readPacketData(from: packetURL)
        let packet = try UdpPcmPacket.decode(packetData)
        print(
            "udp-pcm packet valid: seq=\(packet.header.sequenceNumber) "
                + "frames=\(packet.header.framesPerPacket) "
                + "channels=\(packet.header.channelCount) "
                + "format=\(packet.header.sampleFormat)"
        )
        printVerdict(.pass)
    case ["udp-pcm-route-run", "--help"], ["udp-pcm-route-run", "-h"]:
        printUdpPcmRouteRunUsage()
    case let args where args.count == 3 && args[0] == "validate-udp-pcm-loopback-session":
        let first = try UdpPcmLoopbackReport.readValidated(fromPath: args[1])
        let second = try UdpPcmLoopbackReport.readValidated(fromPath: args[2])
        try first.validateSessionPair(with: second)
        print("udp-pcm loopback session valid: \(first.session.sessionID)")
        print("reports: \(first.id), \(second.id)")
        printVerdict(.partial)
    case let args where args.first == "udp-pcm-route-run":
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
    case let args where args.first == "udp-pcm-loopback-run":
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
    case ["udp-pcm-loopback-localhost-smoke"]:
        let report = try UdpPcmLoopbackLocalhostSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case let args where args.first == "network-diagnostics-run":
        let configuration = try NetworkDiagnosticsRunConfiguration.parse(Array(args.dropFirst()))
        let report = NetworkDiagnosticsRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("network diagnostics report written: \(configuration.outputPath)")
        print("peer: \(configuration.peer)")
        print("traceroute-blocked: \(report.traceroute.blocked)")
        printVerdict(report.verdict)
    case let args where args.first == "mac-to-mac-connection-preflight-run":
        let configuration = try MacToMacConnectionEstablishmentRunConfiguration.parse(Array(args.dropFirst()))
        let report = try MacToMacConnectionEstablishmentRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("Mac-to-Mac connection preflight report written: \(configuration.outputPath)")
        print("setup-mode: \(report.setupMode.rawValue)")
        print("selected-route: \(report.selectedRoute.rawValue)")
        print("blockers: \(report.blockers.count)")
        printVerdict(report.verdict)
    case ["verify-direct-p2p-session-evidence-bundle", "--help"],
        ["verify-direct-p2p-session-evidence-bundle", "-h"]:
        print("Usage: open-lola verify-direct-p2p-session-evidence-bundle <report.json> <bundle-root>")
    case let args where args.count == 3 && args[0] == "verify-direct-p2p-session-evidence-bundle":
        let report = try DirectPeerSessionReport.decode(from: BoundedFileReader.data(atPath: args[1]))
        let verification = try DirectPeerSessionEvidenceBundleVerifier.verify(
            report: report,
            bundleRoot: URL(fileURLWithPath: args[2], isDirectory: true)
        )
        print("direct P2P session evidence bundle valid: \(verification.reportID)")
        print("bundle-root: \(verification.bundleRootPath)")
        print("artifacts-verified: \(verification.verifiedArtifacts.count)")
        printVerdict(.pass)
    case let args where args.count == 2 && args[0] == "validate-direct-p2p-two-peer-local-run-report":
        let report = try DirectPeerTwoPeerLocalRunReport.readValidated(fromPath: args[1])
        try report.validateReferencedArtifacts()
        let outputText = [
            "direct P2P two-peer local supervisor report valid: \(report.id)",
            "VERDICT: \(report.verdict.rawValue.uppercased())",
        ].joined(separator: "\n") + "\n"
        try FileHandle.standardOutput.write(
            contentsOf: Data(outputText.utf8)
        )
    case let args where args.first == "nat-rendezvous-run":
        let configuration = try NatRendezvousRunConfiguration.parse(Array(args.dropFirst()))
        let report = try NatRendezvousRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("NAT rendezvous report written: \(configuration.outputPath)")
        print("session-id: \(configuration.sessionID)")
        print("registrations: \(report.registrations.count)")
        print("mode: \(configuration.mode.rawValue)")
        printVerdict(report.verdict)
    case let args where args.first == "nat-relay-run":
        let configuration = try NatRelayRunConfiguration.parse(Array(args.dropFirst()))
        let report = try NatRelayRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("NAT relay report written: \(configuration.outputPath)")
        print("session-id: \(configuration.sessionID)")
        print("registrations: \(report.registrations.count)")
        print("forwarded-datagrams: \(report.forwardedDatagrams)")
        printVerdict(report.verdict)
    case let args where args.first == "nat-rendezvous-forwarder-run":
        let configuration = try NatRendezvousForwarderLauncherConfiguration.parse(Array(args.dropFirst()))
        let report = try NatRendezvousForwarderLauncherRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print(report.performanceWarning)
        print("NAT rendezvous/UDP forwarder launcher report written: \(configuration.outputPath)")
        print("session-id: \(configuration.sessionID)")
        print("rendezvous-port: \(configuration.rendezvousPort)")
        print("forwarder-port: \(configuration.forwarderPort)")
        printVerdict(report.verdict)
    case let args where args.first == "nat-friendly-route-run":
        let configuration = try NatFriendlyRouteRunConfiguration.parse(Array(args.dropFirst()))
        let result = try NatFriendlyRouteRunner.run(configuration: configuration)
        try result.report.validate()
        try writeJSONData(try result.report.prettyJSONData(), to: configuration.outputPath)
        if let debugTrace = result.debugTrace,
           let debugOutputPath = configuration.debugOutputPath {
            try debugTrace.write(to: debugOutputPath)
        }
        print("NAT-friendly route report written: \(configuration.outputPath)")
        print("session-id: \(configuration.sessionID)")
        print("compatibility-mode: \(result.report.compatibilityMode.rawValue)")
        print("raw-p2p-preferred: \(result.report.rawP2PPreferred)")
        printVerdict(result.report.verdict)
    case ["nat-friendly-localhost-smoke"]:
        let report = try NatFriendlyRouteLocalhostSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["nat-rendezvous-localhost-smoke"]:
        let result = try NatRendezvousLocalhostSmoke.run()
        try result.serverReport.validate()
        for report in result.routeReports {
            try report.validate()
        }
        print(try result.prettyJSONString())
        printVerdict(.partial)
    case ["nat-rendezvous-forwarder-localhost-smoke"]:
        let report = try NatRendezvousForwarderLauncherLocalhostSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(.partial)
    case ["nat-relay-fallback-localhost-smoke"]:
        let result = try NatRelayFallbackLocalhostSmoke.run()
        try result.rendezvousReport.validate()
        try result.relayReport.validate()
        for report in result.routeReports {
            try report.validate()
        }
        print(try result.prettyJSONString())
        printVerdict(.partial)
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
    case let args where args.first == "direct-p2p-mesh-topology-synthetic-smoke":
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
    case let args where args.first == "direct-p2p-mesh-runtime-localhost-smoke":
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
    case let args where args.first == "direct-p2p-two-peer-plan-run":
        let configuration = try DirectPeerTwoPeerRunPlanConfiguration.parse(Array(args.dropFirst()))
        let report = try DirectPeerTwoPeerRunPlanner.makeReport(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("direct P2P two-peer plan written: \(configuration.outputPath)")
        print("run-dir: \(report.runDirectory)")
        print("commands: \(report.commands.count)")
        printVerdict(report.verdict)
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
    case ["direct-p2p-session-run", "--help"], ["direct-p2p-session-run", "-h"], ["direct-p2p-session-run", "help"]:
        printDirectP2PSessionRunUsage()
    case let args where args.first == "direct-p2p-session-run":
        let values = try parseDirectP2PSessionRunArguments(Array(args.dropFirst()))
        let mediaMode = try directP2PSessionMediaMode(values)
        try directP2PValidateAudioCompressionScope(values, mediaMode: mediaMode)
        let packetCount = try directP2PSessionRunPacketCount(values, mediaMode: mediaMode)
        let outputPath = try directP2PSessionRunOutputPath(values)
        var report: DirectPeerSessionReport
        let onReady = directP2PReadyFileWriter(values)
        if mediaMode == .audioVideo {
            report = try DirectPeerSessionSocketRunner.runManualAddressAudioVideo(
                configuration: try directP2PSessionAVConfiguration(values),
                onReady: onReady
            )
        } else if values["--role"] == nil {
            report = try DirectPeerSessionSocketRunner.runLoopback(packetCount: packetCount)
        } else {
            report = try DirectPeerSessionSocketRunner.runManualAddress(
                configuration: try directP2PSessionManualConfiguration(
                    values,
                    packetCount: packetCount
                ),
                onReady: onReady
            )
        }
        report = try directP2PApplyMeasuredEvidence(report, values: values)
        report = directP2PAttachGeneratedReceiveEvidence(report, values: values)
        try report.validate()
        try directP2PWriteReceiveProofArtifacts(report, values: values)
        try directP2PWriteAutoEvidenceArtifact(report, values: values)
        try writeJSONData(try report.prettyJSONData(), to: outputPath)
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
    default:
        return false
    }
    return true
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
