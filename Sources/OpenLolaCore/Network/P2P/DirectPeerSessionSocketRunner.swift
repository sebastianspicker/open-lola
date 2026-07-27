// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Darwin
import Dispatch
import Foundation

/// Runs DirectPeerSessionSocketRunner while keeping its stateful execution separate from report validation.
public enum DirectPeerSessionSocketRunner {
    public static func runManualAddress(
        configuration: DirectPeerSessionManualRunConfiguration
    ) throws -> DirectPeerSessionReport {
        try runManualAddress(configuration: configuration, onReady: nil)
    }

    public static func runManualAddress(
        configuration: DirectPeerSessionManualRunConfiguration,
        onReady: (() -> Void)?
    ) throws -> DirectPeerSessionReport {
        var context = try makeManualSocketRunContext(configuration)
        defer {
            context.runner.shutdown(reason: "manual-address socket run complete")
            context.control.close()
        }
        onReady?()

        try runManualRole(configuration.role, context: &context)
        let report = try manualAddressReport(configuration: configuration, context: context)
        try report.validate()
        return report
    }

    private static func makeManualSocketRunContext(
        _ configuration: DirectPeerSessionManualRunConfiguration
    ) throws -> DirectPeerManualSocketRunContext {
        let validatedPacketCount = try validateManualRunConfiguration(configuration)
        let control = try DirectPeerSessionControlSocket.bindIPv4(
            host: configuration.localHost,
            port: configuration.controlPort,
            receiveTimeoutSeconds: configuration.timeoutSeconds
        )
        do {
            let runner = try PeerSessionRunner.boundIPv4(PeerSessionIPv4BindingRequest(
                peerID: configuration.localPeerID,
                remotePeerID: configuration.remotePeerID,
                localHost: configuration.localHost,
                controlEndpoint: control.endpoint,
                audioPort: configuration.audioPort,
                videoPort: configuration.videoPort,
                metricsPort: configuration.metricsPort,
                audioChannelCount: configuration.audioChannelCount,
                dscp: configuration.dscp
            ))
            return DirectPeerManualSocketRunContext(
                packetCount: validatedPacketCount,
                control: control,
                runner: runner,
                remoteControl: SessionNetworkEndpoint(
                    host: configuration.remoteHost,
                    port: configuration.remoteControlPort
                )
            )
        } catch {
            control.close()
            throw error
        }
    }

    private static func validateManualRunConfiguration(
        _ configuration: DirectPeerSessionManualRunConfiguration
    ) throws -> Int {
        let validatedPacketCount = try directPeerValidatedPacketCount(configuration.packetCount)
        guard configuration.audioChannelCount > 0 else {
            throw DirectPeerSessionSocketRunnerError.invalidAudioChannelCount(
                configuration.audioChannelCount
            )
        }
        guard configuration.timeoutSeconds > 0 else {
            throw DirectPeerSessionSocketRunnerError.invalidTimeoutSeconds(
                configuration.timeoutSeconds
            )
        }
        guard configuration.timeoutSeconds <= directPeerMaximumTimeoutSeconds else {
            throw DirectPeerSessionSocketRunnerError.invalidTimeoutSeconds(
                configuration.timeoutSeconds
            )
        }
        try configuration.validateManualNetworkShape()
        return validatedPacketCount
    }

    private static func runManualRole(
        _ role: DirectPeerSessionManualRole,
        context: inout DirectPeerManualSocketRunContext
    ) throws {
        switch role {
        case .initiator:
            try runManualInitiator(
                runner: &context.runner,
                control: context.control,
                remoteControl: context.remoteControl,
                packetCount: context.packetCount
            )
        case .responder:
            try runManualResponder(
                runner: &context.runner,
                control: context.control,
                remoteControl: context.remoteControl,
                packetCount: context.packetCount
            )
        }
    }

    private static func manualAddressReport(
        configuration: DirectPeerSessionManualRunConfiguration,
        context: DirectPeerManualSocketRunContext
    ) throws -> DirectPeerSessionReport {
        DirectPeerSessionReport(
            id: "m06-direct-p2p-\(configuration.role.rawValue)-\(Int(Date().timeIntervalSince1970))",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            configuration: try requireDirectPeerSessionConfiguration(context.runner.acceptedConfiguration),
            metrics: manualAddressMetrics(context),
            verdict: .partial,
            notes: "Manual-address direct P2P run exchanged control JSON over UDP and routed UDP media "
                + "between configured endpoints. PASS still requires direct-LAN two-machine packet capture, "
                + "DSCP, and physical audio evidence."
        )
    }

    private static func manualAddressMetrics(
        _ context: DirectPeerManualSocketRunContext
    ) -> DirectPeerSessionReportMetrics {
        DirectPeerSessionReportMetrics(
            traffic: manualAddressTrafficMetrics(context),
            control: manualAddressControlMetrics(context),
            remote: .init(),
            remoteResources: .init()
        )
    }

    private static func manualAddressTrafficMetrics(
        _ context: DirectPeerManualSocketRunContext
    ) -> DirectPeerSessionReportMetrics.Traffic {
        let transportMetrics = context.runner.transportMetrics()
        return .init(
            controlMessagesSent: context.runner.metrics.controlMessagesSent,
            packetsSent: context.runner.metrics.mediaPacketsSent,
            packetsReceived: context.runner.metrics.mediaPacketsReceived,
            packetsLost: transportMetrics.packetsLost,
            jitterMicroseconds: transportMetrics.jitterMicroseconds,
            audioPacketsRouted: context.runner.metrics.audioPacketsRouted,
            videoPacketsRouted: context.runner.metrics.videoPacketsRouted,
            recoveryEvents: context.runner.metrics.recoveryEvents
        )
    }

    private static func manualAddressControlMetrics(
        _ context: DirectPeerManualSocketRunContext
    ) -> DirectPeerSessionReportMetrics.Control {
        .init(
            audioPayloadsSentOnControlChannel: context.runner.metrics.audioPayloadsSentOnControlChannel,
            controlDatagramsSent: context.control.sentDatagrams,
            controlDatagramsReceived: context.control.receivedDatagrams,
            audioMetadataMessagesSent: context.runner.metrics.audioMetadataMessagesSent,
            audioMetadataMessagesReceived: context.runner.metrics.audioMetadataMessagesReceived,
            timingProbePacketsSent: context.runner.metrics.timingProbePacketsSent,
            timingProbePacketsReceived: context.runner.metrics.timingProbePacketsReceived,
            timingProbeMaxAgeMicroseconds: context.runner.metrics.timingProbeMaxAgeMicroseconds
        )
    }

    static func completeResponderControlHandshake(
        runner: inout PeerSessionRunner,
        control: DirectPeerSessionControlSocket,
        remoteControl: SessionNetworkEndpoint
    ) throws {
        try send(try runner.beginHandshake(), from: control, to: remoteControl)
        let proposal = try control.receiveMessage(
            label: "session proposal",
            expectedSource: remoteControl
        )
        guard let proposerCapabilities = runner.remoteCapabilities else {
            throw DirectPeerSessionSocketRunnerError.missingRemoteCapabilities
        }
        try control.send(
            try runner.acceptProposal(proposal, proposerCapabilities: proposerCapabilities),
            to: remoteControl
        )
    }

    private static func runManualInitiator(
        runner: inout PeerSessionRunner,
        control: DirectPeerSessionControlSocket,
        remoteControl: SessionNetworkEndpoint,
        packetCount: Int
    ) throws {
        try send(try runner.beginHandshake(), from: control, to: remoteControl)
        try runner.receiveControlMessages(try control.receiveMessages(
            count: 2,
            label: "responder handshake",
            expectedSource: remoteControl
        ))
        try control.send(try runner.makeSessionProposal(), to: remoteControl)
        try runner.receiveControlMessages([try control.receiveMessage(
            label: "session accept",
            expectedSource: remoteControl
        )])
        try finishManualSocketSession(
            runner: &runner,
            control: control,
            remoteControl: remoteControl,
            packetCount: packetCount
        )
    }

    private static func runManualResponder(
        runner: inout PeerSessionRunner,
        control: DirectPeerSessionControlSocket,
        remoteControl: SessionNetworkEndpoint,
        packetCount: Int
    ) throws {
        try runner.receiveControlMessages(try control.receiveMessages(
            count: 2,
            label: "initiator handshake",
            expectedSource: remoteControl
        ))
        try completeResponderControlHandshake(
            runner: &runner,
            control: control,
            remoteControl: remoteControl
        )
        try finishManualSocketSession(
            runner: &runner,
            control: control,
            remoteControl: remoteControl,
            packetCount: packetCount
        )
    }

    private static func finishManualSocketSession(
        runner: inout PeerSessionRunner,
        control: DirectPeerSessionControlSocket,
        remoteControl: SessionNetworkEndpoint,
        packetCount: Int
    ) throws {
        try publishAndExchangeAudioMetadata(
            runner: &runner,
            control: control,
            remoteControl: remoteControl
        )
        try startAndExchangeMediaStart(
            runner: &runner,
            control: control,
            remoteControl: remoteControl
        )
        try exchangeTimingProbe(runner: &runner)
        try exchangeAudioPackets(runner: &runner, packetCount: packetCount)
    }

}
