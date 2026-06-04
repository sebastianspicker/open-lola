import Darwin
import Dispatch
import Foundation

let directPeerMaximumTimeoutSeconds = 86_400

public enum DirectPeerSessionSocketRunnerError: Error, Equatable, Sendable {
    case timedOutWaitingForControlMessage(String)
    case unexpectedControlSource(expected: SessionNetworkEndpoint, actualHost: String, actualPort: UInt16)
    case invalidPacketCount(Int)
    case invalidTimeoutSeconds(Int)
    case invalidAudioChannelCount(Int)
    case invalidManualHost(String, String)
    case invalidManualHostParse(String, String, Int32)
    case invalidManualPort(String, UInt16)
    case duplicateManualPort(String, UInt16)
    case missingExpectedControlMessage(String)
    case missingRemoteCapabilities
}

public enum DirectPeerSessionManualRole: String, Codable, Equatable, Sendable {
    case initiator
    case responder
}

func directPeerValidatedPacketCount(_ packetCount: Int) throws -> Int {
    guard packetCount > 0 else {
        throw DirectPeerSessionSocketRunnerError.invalidPacketCount(packetCount)
    }
    return packetCount
}

public struct DirectPeerSessionManualRunConfiguration: Codable, Equatable, Sendable {
    public var role: DirectPeerSessionManualRole
    public var localPeerID: String
    public var remotePeerID: String
    public var localHost: String
    public var remoteHost: String
    public var controlPort: UInt16
    public var remoteControlPort: UInt16
    public var audioPort: UInt16
    public var videoPort: UInt16
    public var metricsPort: UInt16
    public var packetCount: Int
    public var audioChannelCount: Int
    public var timeoutSeconds: Int
    public var dscp: Int?

    public init(
        role: DirectPeerSessionManualRole,
        localPeerID: String,
        remotePeerID: String,
        localHost: String,
        remoteHost: String,
        controlPort: UInt16,
        remoteControlPort: UInt16,
        audioPort: UInt16,
        videoPort: UInt16,
        metricsPort: UInt16,
        packetCount: Int = 3,
        audioChannelCount: Int = 2,
        timeoutSeconds: Int = 5,
        dscp: Int? = nil
    ) {
        self.role = role
        self.localPeerID = localPeerID
        self.remotePeerID = remotePeerID
        self.localHost = localHost
        self.remoteHost = remoteHost
        self.controlPort = controlPort
        self.remoteControlPort = remoteControlPort
        self.audioPort = audioPort
        self.videoPort = videoPort
        self.metricsPort = metricsPort
        self.packetCount = packetCount
        self.audioChannelCount = audioChannelCount
        self.timeoutSeconds = timeoutSeconds
        self.dscp = dscp
    }

    public func validateManualNetworkShape() throws {
        try DirectPeerManualNetworkShape(
            localHost: localHost,
            remoteHost: remoteHost,
            ports: DirectPeerPortSet(
                controlPort: controlPort,
                remoteControlPort: remoteControlPort,
                audioPort: audioPort,
                videoPort: videoPort,
                metricsPort: metricsPort
            )
        ).validate()
    }
}

public enum DirectPeerSessionSocketRunner {
    public static func runLoopback(packetCount: Int = 3) throws -> DirectPeerSessionReport {
        let validatedPacketCount = try directPeerValidatedPacketCount(packetCount)

        let firstControl = try DirectPeerSessionControlSocket.bindLoopback()
        let secondControl = try DirectPeerSessionControlSocket.bindLoopback()
        defer {
            firstControl.close()
            secondControl.close()
        }

        var first = try PeerSessionRunner.localhost(
            peerID: "peer-a",
            remotePeerID: "peer-b",
            controlEndpoint: firstControl.endpoint
        )
        var second = try PeerSessionRunner.localhost(
            peerID: "peer-b",
            remotePeerID: "peer-a",
            controlEndpoint: secondControl.endpoint
        )
        defer {
            first.shutdown(reason: "socket run complete")
            second.shutdown(reason: "socket run complete")
        }

        try send(try first.beginHandshake(), from: firstControl, to: secondControl.endpoint)
        try second.receiveControlMessages(try secondControl.receiveMessages(
            count: 2,
            label: "first handshake",
            expectedSource: firstControl.endpoint
        ))

        try send(try second.beginHandshake(), from: secondControl, to: firstControl.endpoint)
        try first.receiveControlMessages(try firstControl.receiveMessages(
            count: 2,
            label: "second handshake",
            expectedSource: secondControl.endpoint
        ))

        let proposal = try first.makeSessionProposal()
        try firstControl.send(proposal, to: secondControl.endpoint)
        let receivedProposal = try secondControl.receiveMessage(
            label: "proposal",
            expectedSource: firstControl.endpoint
        )
        let accept = try second.acceptProposal(
            receivedProposal,
            proposerCapabilities: first.localCapabilities
        )
        try secondControl.send(accept, to: firstControl.endpoint)
        try first.receiveControlMessages([try firstControl.receiveMessage(
            label: "accept",
            expectedSource: secondControl.endpoint
        )])

        try publishAndExchangeAudioMetadata(
            first: &first,
            firstControl: firstControl,
            second: &second,
            secondControl: secondControl
        )

        try first.startMedia()
        try second.startMedia()
        try firstControl.send(try latestControlMessage(from: first, label: "first media start"), to: secondControl.endpoint)
        try secondControl.send(try latestControlMessage(from: second, label: "second media start"), to: firstControl.endpoint)
        try second.receiveControlMessages([try secondControl.receiveMessage(
            label: "first media start",
            expectedSource: firstControl.endpoint
        )])
        try first.receiveControlMessages([try firstControl.receiveMessage(
            label: "second media start",
            expectedSource: secondControl.endpoint
        )])

        try exchangeTimingProbes(first: &first, second: &second)

        for sequence in 1...validatedPacketCount {
            try first.sendAudioPacket(sequenceNumber: UInt64(sequence))
            try second.receiveMediaPacket()
        }

        let configuration = try requireDirectPeerSessionConfiguration(first.acceptedConfiguration)
        let controlDatagramsSent = firstControl.sentDatagrams + secondControl.sentDatagrams
        let controlDatagramsReceived = firstControl.receivedDatagrams + secondControl.receivedDatagrams
        let report = DirectPeerSessionReport(
            id: "m06-direct-p2p-socket-\(Int(Date().timeIntervalSince1970))",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            configuration: configuration,
            metrics: DirectPeerSessionReportMetrics(
                controlMessagesSent: first.metrics.controlMessagesSent + second.metrics.controlMessagesSent,
                packetsSent: first.metrics.mediaPacketsSent,
                packetsReceived: second.metrics.mediaPacketsReceived,
                packetsLost: second.transportMetrics().packetsLost,
                jitterMicroseconds: second.transportMetrics().jitterMicroseconds,
                audioPacketsRouted: second.metrics.audioPacketsRouted,
                videoPacketsRouted: second.metrics.videoPacketsRouted,
                recoveryEvents: first.metrics.recoveryEvents + second.metrics.recoveryEvents,
                audioPayloadsSentOnControlChannel: first.metrics.audioPayloadsSentOnControlChannel
                    + second.metrics.audioPayloadsSentOnControlChannel,
                controlDatagramsSent: controlDatagramsSent,
                controlDatagramsReceived: controlDatagramsReceived,
                audioMetadataMessagesSent: first.metrics.audioMetadataMessagesSent
                    + second.metrics.audioMetadataMessagesSent,
                audioMetadataMessagesReceived: first.metrics.audioMetadataMessagesReceived
                    + second.metrics.audioMetadataMessagesReceived,
                timingProbePacketsSent: first.metrics.timingProbePacketsSent
                    + second.metrics.timingProbePacketsSent,
                timingProbePacketsReceived: first.metrics.timingProbePacketsReceived
                    + second.metrics.timingProbePacketsReceived,
                timingProbeMaxAgeMicroseconds: max(
                    first.metrics.timingProbeMaxAgeMicroseconds,
                    second.metrics.timingProbeMaxAgeMicroseconds
                )
            ),
            verdict: .partial,
            notes: "Socket-backed direct P2P run exchanged control JSON over UDP and routed UDP media. PASS still requires direct-LAN two-machine packet capture, DSCP, and physical audio evidence."
        )
        try report.validate()
        return report
    }

    public static func runManualAddress(
        configuration: DirectPeerSessionManualRunConfiguration
    ) throws -> DirectPeerSessionReport {
        try runManualAddress(configuration: configuration, onReady: nil)
    }

    public static func runManualAddress(
        configuration: DirectPeerSessionManualRunConfiguration,
        onReady: (() -> Void)?
    ) throws -> DirectPeerSessionReport {
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

        let control = try DirectPeerSessionControlSocket.bindIPv4(
            host: configuration.localHost,
            port: configuration.controlPort,
            receiveTimeoutSeconds: configuration.timeoutSeconds
        )
        defer { control.close() }

        var runner = try PeerSessionRunner.boundIPv4(
            peerID: configuration.localPeerID,
            remotePeerID: configuration.remotePeerID,
            localHost: configuration.localHost,
            controlEndpoint: control.endpoint,
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            metricsPort: configuration.metricsPort,
            audioChannelCount: configuration.audioChannelCount,
            dscp: configuration.dscp
        )
        defer { runner.shutdown(reason: "manual-address socket run complete") }
        onReady?()

        let remoteControl = SessionNetworkEndpoint(
            host: configuration.remoteHost,
            port: configuration.remoteControlPort
        )
        switch configuration.role {
        case .initiator:
            try runManualInitiator(
                runner: &runner,
                control: control,
                remoteControl: remoteControl,
                packetCount: validatedPacketCount
            )
        case .responder:
            try runManualResponder(
                runner: &runner,
                control: control,
                remoteControl: remoteControl,
                packetCount: validatedPacketCount
            )
        }

        let report = DirectPeerSessionReport(
            id: "m06-direct-p2p-\(configuration.role.rawValue)-\(Int(Date().timeIntervalSince1970))",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            configuration: try requireDirectPeerSessionConfiguration(runner.acceptedConfiguration),
            metrics: DirectPeerSessionReportMetrics(
                controlMessagesSent: runner.metrics.controlMessagesSent,
                packetsSent: runner.metrics.mediaPacketsSent,
                packetsReceived: runner.metrics.mediaPacketsReceived,
                packetsLost: runner.transportMetrics().packetsLost,
                jitterMicroseconds: runner.transportMetrics().jitterMicroseconds,
                audioPacketsRouted: runner.metrics.audioPacketsRouted,
                videoPacketsRouted: runner.metrics.videoPacketsRouted,
                recoveryEvents: runner.metrics.recoveryEvents,
                audioPayloadsSentOnControlChannel: runner.metrics.audioPayloadsSentOnControlChannel,
                controlDatagramsSent: control.sentDatagrams,
                controlDatagramsReceived: control.receivedDatagrams,
                audioMetadataMessagesSent: runner.metrics.audioMetadataMessagesSent,
                audioMetadataMessagesReceived: runner.metrics.audioMetadataMessagesReceived,
                timingProbePacketsSent: runner.metrics.timingProbePacketsSent,
                timingProbePacketsReceived: runner.metrics.timingProbePacketsReceived,
                timingProbeMaxAgeMicroseconds: runner.metrics.timingProbeMaxAgeMicroseconds
            ),
            verdict: .partial,
            notes: "Manual-address direct P2P run exchanged control JSON over UDP and routed UDP media between configured endpoints. PASS still requires direct-LAN two-machine packet capture, DSCP, and physical audio evidence."
        )
        try report.validate()
        return report
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

    static func startAndExchangeMediaStart(
        runner: inout PeerSessionRunner,
        control: DirectPeerSessionControlSocket,
        remoteControl: SessionNetworkEndpoint
    ) throws {
        try runner.startMedia()
        try control.send(try latestControlMessage(from: runner, label: "media start"), to: remoteControl)
        try runner.receiveControlMessages([try control.receiveMessage(
            label: "peer media start",
            expectedSource: remoteControl
        )])
    }

    private static func exchangeAudioPackets(
        runner: inout PeerSessionRunner,
        packetCount: Int
    ) throws {
        let validatedPacketCount = try directPeerValidatedPacketCount(packetCount)
        for sequence in 1...validatedPacketCount {
            try runner.sendAudioPacket(sequenceNumber: UInt64(sequence))
        }
        for _ in 1...validatedPacketCount {
            try runner.receiveMediaPacket()
        }
    }

    private static func exchangeTimingProbes(
        first: inout PeerSessionRunner,
        second: inout PeerSessionRunner
    ) throws {
        try first.sendAudioTimingProbe(sequenceNumber: 1)
        try second.receiveMediaPacket()
        try second.sendAudioTimingProbe(sequenceNumber: 1)
        try first.receiveMediaPacket()
    }

    private static func exchangeTimingProbe(
        runner: inout PeerSessionRunner
    ) throws {
        try runner.sendAudioTimingProbe(sequenceNumber: 1)
        try runner.receiveMediaPacket()
    }

    static func publishAndExchangeAudioMetadata(
        first: inout PeerSessionRunner,
        firstControl: DirectPeerSessionControlSocket,
        second: inout PeerSessionRunner,
        secondControl: DirectPeerSessionControlSocket
    ) throws {
        if let firstMessage = try first.publishAudioMetadata(metadataSnapshot(for: first)) {
            try firstControl.send(firstMessage, to: secondControl.endpoint)
            try receiveControlMessage(
                ofType: .audioMetadata,
                into: &second,
                control: secondControl,
                expectedSource: firstControl.endpoint,
                label: "first audio metadata"
            )
        }
        if let secondMessage = try second.publishAudioMetadata(metadataSnapshot(for: second)) {
            try secondControl.send(secondMessage, to: firstControl.endpoint)
            try receiveControlMessage(
                ofType: .audioMetadata,
                into: &first,
                control: firstControl,
                expectedSource: secondControl.endpoint,
                label: "second audio metadata"
            )
        }
    }

    static func publishAndExchangeAudioMetadata(
        runner: inout PeerSessionRunner,
        control: DirectPeerSessionControlSocket,
        remoteControl: SessionNetworkEndpoint
    ) throws {
        if let message = try runner.publishAudioMetadata(metadataSnapshot(for: runner)) {
            try control.send(message, to: remoteControl)
        }
        try receiveControlMessage(
            ofType: .audioMetadata,
            into: &runner,
            control: control,
            expectedSource: remoteControl,
            label: "peer audio metadata"
        )
    }

    static func receiveControlMessage(
        ofType expectedType: SessionControlMessageType,
        into runner: inout PeerSessionRunner,
        control: DirectPeerSessionControlSocket,
        expectedSource: SessionNetworkEndpoint,
        label: String,
        maxSkippedMessages: Int = 8
    ) throws {
        for attempt in 0...maxSkippedMessages {
            let message = try control.receiveMessage(
                label: attempt == 0 ? label : "\(label) skipped-\(attempt)",
                expectedSource: expectedSource
            )
            try runner.receiveControlMessages([message])
            if message.type == expectedType {
                return
            }
        }
        throw DirectPeerSessionSocketRunnerError.missingExpectedControlMessage(label)
    }

    static func send(
        _ messages: [SessionControlMessage],
        from socket: DirectPeerSessionControlSocket,
        to endpoint: SessionNetworkEndpoint
    ) throws {
        for message in messages {
            try socket.send(message, to: endpoint)
        }
    }

    private static func latestControlMessage(
        from runner: PeerSessionRunner,
        label: String
    ) throws -> SessionControlMessage {
        guard let message = runner.controlTranscript.last else {
            throw DirectPeerSessionSocketRunnerError.missingExpectedControlMessage(label)
        }
        return message
    }

    private static func metadataSnapshot(for runner: PeerSessionRunner) -> RmeMatrixMetadataSnapshot {
        // Control-plane RME metadata is advisory stereo V1 metadata; full channel capability stays in CapabilitySet.
        let channels = Array(runner.localCapabilities.audio.channelSet.sortedByStableSourceIndex.prefix(2))
        if channels.isEmpty {
            return RmeMatrixMetadataSnapshot.unavailable(
                revision: 1,
                capturedAt: ISO8601DateFormatter().string(from: Date()),
                notes: "No Core Audio channel descriptors were available for advisory metadata."
            )
        }
        return RmeMatrixMetadataSnapshot(
            snapshotID: "\(runner.localCapabilities.peer.peerID)-control-metadata-1",
            provider: .coreAudioOnly,
            revision: 1,
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            legalBasis: "Core Audio channel order and open-lola capability document",
            confidence: .highForChannelOrder,
            channels: channels,
            routes: [],
            notes: "Advisory control-plane metadata only; audio playback does not depend on it."
        )
    }
}
