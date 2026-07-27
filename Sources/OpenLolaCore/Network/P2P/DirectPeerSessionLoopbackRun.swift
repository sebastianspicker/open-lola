// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation

private struct DirectPeerLoopbackRunContext {
    var packetCount: Int
    var firstControl: DirectPeerSessionControlSocket
    var secondControl: DirectPeerSessionControlSocket
    var first: PeerSessionRunner
    var second: PeerSessionRunner
}

public extension DirectPeerSessionSocketRunner {
    static func runLoopback(packetCount: Int = 3) throws -> DirectPeerSessionReport {
        var context = try makeLoopbackRunContext(packetCount: packetCount)
        defer {
            context.first.shutdown(reason: "socket run complete")
            context.second.shutdown(reason: "socket run complete")
            context.firstControl.close()
            context.secondControl.close()
        }

        try runLoopbackControlExchange(context: &context)
        try routeLoopbackAudio(context: &context)
        let report = try loopbackReport(context)
        try report.validate()
        return report
    }
}

private extension DirectPeerSessionSocketRunner {
    static func makeLoopbackRunContext(packetCount: Int) throws -> DirectPeerLoopbackRunContext {
        let firstControl = try DirectPeerSessionControlSocket.bindLoopback()
        do {
            let secondControl = try DirectPeerSessionControlSocket.bindLoopback()
            do {
                return DirectPeerLoopbackRunContext(
                    packetCount: try directPeerValidatedPacketCount(packetCount),
                    firstControl: firstControl,
                    secondControl: secondControl,
                    first: try PeerSessionRunner.localhost(
                        peerID: "peer-a",
                        remotePeerID: "peer-b",
                        controlEndpoint: firstControl.endpoint
                    ),
                    second: try PeerSessionRunner.localhost(
                        peerID: "peer-b",
                        remotePeerID: "peer-a",
                        controlEndpoint: secondControl.endpoint
                    )
                )
            } catch {
                secondControl.close()
                throw error
            }
        } catch {
            firstControl.close()
            throw error
        }
    }

    static func runLoopbackControlExchange(context: inout DirectPeerLoopbackRunContext) throws {
        try exchangeLoopbackHandshake(context: &context)
        try exchangeLoopbackProposal(context: &context)
        try publishAndExchangeAudioMetadata(
            first: &context.first,
            firstControl: context.firstControl,
            second: &context.second,
            secondControl: context.secondControl
        )
        try exchangeLoopbackMediaStart(context: &context)
        try exchangeLoopbackTimingProbes(context: &context)
    }

    static func exchangeLoopbackHandshake(context: inout DirectPeerLoopbackRunContext) throws {
        try send(try context.first.beginHandshake(), from: context.firstControl, to: context.secondControl.endpoint)
        try context.second.receiveControlMessages(try context.secondControl.receiveMessages(
            count: 2,
            label: "first handshake",
            expectedSource: context.firstControl.endpoint
        ))
        try send(try context.second.beginHandshake(), from: context.secondControl, to: context.firstControl.endpoint)
        try context.first.receiveControlMessages(try context.firstControl.receiveMessages(
            count: 2,
            label: "second handshake",
            expectedSource: context.secondControl.endpoint
        ))
    }

    static func exchangeLoopbackProposal(context: inout DirectPeerLoopbackRunContext) throws {
        let proposal = try context.first.makeSessionProposal()
        try context.firstControl.send(proposal, to: context.secondControl.endpoint)
        let receivedProposal = try context.secondControl.receiveMessage(
            label: "proposal",
            expectedSource: context.firstControl.endpoint
        )
        try context.secondControl.send(try context.second.acceptProposal(
            receivedProposal,
            proposerCapabilities: context.first.localCapabilities
        ), to: context.firstControl.endpoint)
        try context.first.receiveControlMessages([try context.firstControl.receiveMessage(
            label: "accept",
            expectedSource: context.secondControl.endpoint
        )])
    }

    static func exchangeLoopbackMediaStart(context: inout DirectPeerLoopbackRunContext) throws {
        try context.first.startMedia()
        try context.second.startMedia()
        try context.firstControl.send(
            try latestLoopbackControlMessage(from: context.first, label: "first media start"),
            to: context.secondControl.endpoint
        )
        try context.secondControl.send(
            try latestLoopbackControlMessage(from: context.second, label: "second media start"),
            to: context.firstControl.endpoint
        )
        try context.second.receiveControlMessages([try context.secondControl.receiveMessage(
            label: "first media start",
            expectedSource: context.firstControl.endpoint
        )])
        try context.first.receiveControlMessages([try context.firstControl.receiveMessage(
            label: "second media start",
            expectedSource: context.secondControl.endpoint
        )])
    }

    static func exchangeLoopbackTimingProbes(context: inout DirectPeerLoopbackRunContext) throws {
        try context.first.sendAudioTimingProbe(sequenceNumber: 1)
        try context.second.receiveMediaPacket()
        try context.second.sendAudioTimingProbe(sequenceNumber: 1)
        try context.first.receiveMediaPacket()
    }

    static func routeLoopbackAudio(context: inout DirectPeerLoopbackRunContext) throws {
        for sequence in 1...context.packetCount {
            try context.first.sendAudioPacket(sequenceNumber: UInt64(sequence))
            try context.second.receiveMediaPacket()
        }
    }

    static func loopbackReport(_ context: DirectPeerLoopbackRunContext) throws -> DirectPeerSessionReport {
        DirectPeerSessionReport(
            id: "m06-direct-p2p-socket-\(Int(Date().timeIntervalSince1970))",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            configuration: try requireDirectPeerSessionConfiguration(context.first.acceptedConfiguration),
            metrics: loopbackReportMetrics(context),
            verdict: .partial,
            notes: "Socket-backed direct P2P run exchanged control JSON over UDP and routed UDP media. "
                + "PASS still requires direct-LAN two-machine packet capture, DSCP, and physical audio evidence."
        )
    }

    static func loopbackReportMetrics(_ context: DirectPeerLoopbackRunContext) -> DirectPeerSessionReportMetrics {
        DirectPeerSessionReportMetrics(
            traffic: .init(
                controlMessagesSent: context.first.metrics.controlMessagesSent
                    + context.second.metrics.controlMessagesSent,
                packetsSent: context.first.metrics.mediaPacketsSent,
                packetsReceived: context.second.metrics.mediaPacketsReceived,
                packetsLost: context.second.transportMetrics().packetsLost,
                jitterMicroseconds: context.second.transportMetrics().jitterMicroseconds,
                audioPacketsRouted: context.second.metrics.audioPacketsRouted,
                videoPacketsRouted: context.second.metrics.videoPacketsRouted,
                recoveryEvents: context.first.metrics.recoveryEvents + context.second.metrics.recoveryEvents
            ),
            control: .init(
                audioPayloadsSentOnControlChannel: context.first.metrics.audioPayloadsSentOnControlChannel
                    + context.second.metrics.audioPayloadsSentOnControlChannel,
                controlDatagramsSent: context.firstControl.sentDatagrams + context.secondControl.sentDatagrams,
                controlDatagramsReceived: context.firstControl.receivedDatagrams
                    + context.secondControl.receivedDatagrams,
                audioMetadataMessagesSent: context.first.metrics.audioMetadataMessagesSent
                    + context.second.metrics.audioMetadataMessagesSent,
                audioMetadataMessagesReceived: context.first.metrics.audioMetadataMessagesReceived
                    + context.second.metrics.audioMetadataMessagesReceived,
                timingProbePacketsSent: context.first.metrics.timingProbePacketsSent
                    + context.second.metrics.timingProbePacketsSent,
                timingProbePacketsReceived: context.first.metrics.timingProbePacketsReceived
                    + context.second.metrics.timingProbePacketsReceived,
                timingProbeMaxAgeMicroseconds: max(
                    context.first.metrics.timingProbeMaxAgeMicroseconds,
                    context.second.metrics.timingProbeMaxAgeMicroseconds
                )
            ),
            remote: .init(),
            remoteResources: .init()
        )
    }

    static func latestLoopbackControlMessage(
        from runner: PeerSessionRunner,
        label: String
    ) throws -> SessionControlMessage {
        guard let message = runner.controlTranscript.last else {
            throw DirectPeerSessionSocketRunnerError.missingExpectedControlMessage(label)
        }
        return message
    }
}
