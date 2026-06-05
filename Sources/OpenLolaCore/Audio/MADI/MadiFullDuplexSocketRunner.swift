import Darwin
import Dispatch
import Foundation

public enum MadiFullDuplexSocketRunner {
    private static let drainPollIntervalNanoseconds: UInt64 = 100_000
    fileprivate static let readinessPollIntervalNanoseconds: UInt64 = 5_000_000
    private static let readinessPrefix = Data("open-lola-madi-ready-v1\n".utf8)

    public static func run(
        configuration: MadiFullDuplexSessionConfiguration,
        receiverDriftFramesPerPacket: Int = 0
    ) throws -> MadiFullDuplexReport {
        try configuration.validate()

        let socket = try configuredSocket(for: configuration)
        defer { close(socket) }
        var session = try startedSession(configuration: configuration)
        var receiveBuffer = [UInt8](repeating: 0, count: configuration.maxTransmissionUnitBytes)

        let modes = try MadiFullDuplexSocketModes(configuration: configuration)

        try waitForPeerReadiness(
            socket: socket,
            configuration: configuration,
            receiveBuffer: &receiveBuffer
        )
        try runPacketLoop(
            socket: socket,
            session: &session,
            configuration: configuration,
            localMode: modes.local,
            receiveBuffer: &receiveBuffer
        )
        try drainRemotePackets(
            socket: socket,
            session: &session,
            configuration: configuration,
            expectedCompletedBlocks: configuration.packetCount
        )

        try applyDriftSimulation(
            to: &session,
            configuration: configuration,
            remoteMode: modes.remote,
            receiverDriftFramesPerPacket: receiverDriftFramesPerPacket
        )
        let report = makeNetworkRuntimeReport(configuration: configuration, session: session)
        try report.validate()
        return report
    }

    private static func configuredSocket(for configuration: MadiFullDuplexSessionConfiguration) throws -> Int32 {
        let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        try bindIPv4(
            socket,
            host: configuration.localEndpoint.host,
            port: configuration.localEndpoint.port.bigEndian
        )
        try setNonBlocking(socket)
        return socket
    }

    private static func startedSession(configuration: MadiFullDuplexSessionConfiguration) throws -> MadiFullDuplexSession {
        var session = try MadiFullDuplexSession(configuration: configuration)
        try session.start()
        return session
    }

    private static func applyDriftSimulation(
        to session: inout MadiFullDuplexSession,
        configuration: MadiFullDuplexSessionConfiguration,
        remoteMode: AudioTransportMode,
        receiverDriftFramesPerPacket: Int
    ) throws {
        let simulation = try MadiFullDuplexClockDriftSimulator.run(
            sampleCount: max(2, configuration.packetCount),
            senderFrameStep: remoteMode.framesPerPacket,
            receiverFrameStep: remoteMode.framesPerPacket + receiverDriftFramesPerPacket,
            correctionPolicy: configuration.correctionPolicy
        )
        session.applyDriftSimulation(simulation)
    }

    private static func makeNetworkRuntimeReport(
        configuration: MadiFullDuplexSessionConfiguration,
        session: MadiFullDuplexSession
    ) -> MadiFullDuplexReport {
        MadiFullDuplexReport(
            id: "m05-madi-full-duplex-network-run",
            title: "M05 MADI full-duplex UDP runtime run",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            runMode: .networkRuntime,
            localPeerID: configuration.localPeerID,
            remotePeerID: configuration.remotePeerID,
            localEndpoint: configuration.localEndpoint,
            remoteEndpoint: configuration.remoteEndpoint,
            audioPair: configuration.audioPair,
            metrics: session.metrics,
            receiverMix: receiverMixEvidence(
                configuration: configuration,
                metrics: session.metrics,
                lastAppliedRevision: session.lastReceiverMixRevision,
                outputChannelCount: session.lastReceiverOutputChannelCount
            ),
            verdict: .partial,
            notes: "Socket-backed UDP PCM v2 full-duplex run. PASS still requires physical two-peer RME MADI Core Audio evidence and packet capture."
        )
    }

    private static func waitForPeerReadiness(
        socket: Int32,
        configuration: MadiFullDuplexSessionConfiguration,
        receiveBuffer: inout [UInt8]
    ) throws {
        let exchange = try MadiFullDuplexReadinessExchange(configuration: configuration)
        while DispatchTime.now().uptimeNanoseconds < exchange.deadlineNanoseconds {
            try announceReadiness(socket: socket, configuration: configuration, exchange: exchange)
            try waitForReadableSocket(socket, deadlineNanoseconds: exchange.nextPollDeadline())
            if try receivedExpectedReadiness(
                socket: socket,
                exchange: exchange,
                receiveBuffer: &receiveBuffer
            ) {
                return
            }
        }
        throw MadiFullDuplexError.peerReadinessTimeout(
            peerID: configuration.remotePeerID,
            timeoutSeconds: configuration.peerBindTimeoutSeconds
        )
    }

    private static func announceReadiness(
        socket: Int32,
        configuration: MadiFullDuplexSessionConfiguration,
        exchange: MadiFullDuplexReadinessExchange
    ) throws {
        try sendDatagram(
            exchange.localReady,
            socket: socket,
            host: configuration.remoteEndpoint.host,
            port: configuration.remoteEndpoint.port.bigEndian
        )
    }

    private static func receivedExpectedReadiness(
        socket: Int32,
        exchange: MadiFullDuplexReadinessExchange,
        receiveBuffer: inout [UInt8]
    ) throws -> Bool {
        while let data = try receiveDatagramIfAvailable(
            socket: socket,
            byteCount: exchange.receiveByteCount,
            buffer: &receiveBuffer
        ) {
            if data == exchange.expectedPeerReady {
                return true
            }
        }
        return false
    }

    fileprivate static func readinessDatagram(sessionID: String, peerID: String) -> Data {
        Data("open-lola-madi-ready-v1\nsession:\(sessionID)\npeer:\(peerID)".utf8)
    }

    private static func isReadinessDatagram(_ data: Data) -> Bool {
        data.starts(with: readinessPrefix)
    }

    private static func runPacketLoop(
        socket: Int32,
        session: inout MadiFullDuplexSession,
        configuration: MadiFullDuplexSessionConfiguration,
        localMode: AudioTransportMode,
        receiveBuffer: inout [UInt8]
    ) throws {
        let intervalNanoseconds = packetIntervalNanoseconds(
            UdpPcmPacketMode(
                sampleRateHertz: localMode.sampleRateHertz,
                framesPerPacket: localMode.framesPerPacket,
                channelCount: localMode.channelCount,
                sampleFormat: localMode.sampleFormat
            )
        )
        let start = DispatchTime.now().uptimeNanoseconds

        for index in 0..<configuration.packetCount {
            let senderFrameIndex = UInt64(index * localMode.framesPerPacket)
            _ = try session.captureLocalPayload(
                startFrame: senderFrameIndex,
                hostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds,
                payload: SyntheticAudioPayload.make(
                    seed: index,
                    byteCount: localMode.payloadByteCount
                )
            )
            let packets = try session.sendNextLocalPackets()
            for packet in packets {
                try sendDatagram(
                    try packet.encoded(),
                    socket: socket,
                    host: configuration.remoteEndpoint.host,
                    port: configuration.remoteEndpoint.port.bigEndian
                )
            }

            let nextDeadline = start + (UInt64(index + 1) * intervalNanoseconds)
            try drainUntil(
                socket: socket,
                session: &session,
                deadlineNanoseconds: nextDeadline,
                byteCount: configuration.maxTransmissionUnitBytes,
                receiveBuffer: &receiveBuffer
            )
            _ = try session.renderRemoteAudioCallback()
            sleepUntilUptimeNanoseconds(nextDeadline)
        }
    }

    private static func drainRemotePackets(
        socket: Int32,
        session: inout MadiFullDuplexSession,
        configuration: MadiFullDuplexSessionConfiguration,
        expectedCompletedBlocks: Int
    ) throws {
        var receiveBuffer = [UInt8](repeating: 0, count: configuration.maxTransmissionUnitBytes)
        let deadline = DispatchTime.now().uptimeNanoseconds + 1_000_000_000
        while DispatchTime.now().uptimeNanoseconds < deadline
            && session.metrics.renderedReceiveBlocks < expectedCompletedBlocks {
            try drainUntil(
                socket: socket,
                session: &session,
                deadlineNanoseconds: DispatchTime.now().uptimeNanoseconds + 1_000_000,
                byteCount: configuration.maxTransmissionUnitBytes,
                receiveBuffer: &receiveBuffer
            )
            _ = try session.renderRemoteAudioCallback()
        }
    }

    private static func drainUntil(
        socket: Int32,
        session: inout MadiFullDuplexSession,
        deadlineNanoseconds: UInt64,
        byteCount: Int,
        receiveBuffer: inout [UInt8]
    ) throws {
        while DispatchTime.now().uptimeNanoseconds < deadlineNanoseconds {
            try waitForReadableSocket(socket, deadlineNanoseconds: deadlineNanoseconds)
            guard let data = try receiveDatagramIfAvailable(
                socket: socket,
                byteCount: byteCount,
                buffer: &receiveBuffer
            ) else {
                continue
            }
            if isReadinessDatagram(data) {
                continue
            }
            let packet = try UdpPcmV2Packet.decode(data)
            _ = try session.receiveRemotePackets(
                [packet],
                receivedAtHostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
            )
        }
    }

    private static func waitForReadableSocket(_ socket: Int32, deadlineNanoseconds: UInt64) throws {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now < deadlineNanoseconds else {
            return
        }
        let waitNanoseconds = min(deadlineNanoseconds - now, Self.drainPollIntervalNanoseconds)
        var descriptor = pollfd(fd: socket, events: Int16(POLLIN), revents: 0)
        let timeoutMilliseconds = Int32(max(1, waitNanoseconds / 1_000_000))
        let result = poll(&descriptor, 1, timeoutMilliseconds)
        let savedErrno = errno
        guard result >= 0 else {
            throw UdpPcmRouteProbeError.receiveFailed(savedErrno)
        }
    }

}

private struct MadiFullDuplexSocketModes {
    var local: AudioTransportMode
    var remote: AudioTransportMode

    init(configuration: MadiFullDuplexSessionConfiguration) throws {
        local = try configuration.audioPair.localSendMode(
            maxTransmissionUnitBytes: configuration.maxTransmissionUnitBytes,
            maxFragmentsPerDeadline: configuration.maxFragmentsPerDeadline,
            metadataRevision: configuration.metadataRevision
        )
        remote = try configuration.audioPair.remoteReceiveMode(
            maxTransmissionUnitBytes: configuration.maxTransmissionUnitBytes,
            maxFragmentsPerDeadline: configuration.maxFragmentsPerDeadline,
            metadataRevision: configuration.metadataRevision,
            rxBufferProfile: configuration.rxBufferProfile
        )
    }
}

private struct MadiFullDuplexReadinessExchange {
    var localReady: Data
    var expectedPeerReady: Data
    var receiveByteCount: Int
    var deadlineNanoseconds: UInt64

    init(configuration: MadiFullDuplexSessionConfiguration) throws {
        guard configuration.peerBindTimeoutSeconds > 0 else {
            throw MadiFullDuplexError.peerReadinessTimeout(
                peerID: configuration.remotePeerID,
                timeoutSeconds: configuration.peerBindTimeoutSeconds
            )
        }
        localReady = MadiFullDuplexSocketRunner.readinessDatagram(
            sessionID: configuration.sessionID,
            peerID: configuration.localPeerID
        )
        expectedPeerReady = MadiFullDuplexSocketRunner.readinessDatagram(
            sessionID: configuration.sessionID,
            peerID: configuration.remotePeerID
        )
        receiveByteCount = max(
            configuration.maxTransmissionUnitBytes,
            localReady.count,
            expectedPeerReady.count
        )
        deadlineNanoseconds = DispatchTime.now().uptimeNanoseconds
            + UInt64((configuration.peerBindTimeoutSeconds * 1_000_000_000).rounded(.up))
    }

    func nextPollDeadline() -> UInt64 {
        min(
            deadlineNanoseconds,
            DispatchTime.now().uptimeNanoseconds + MadiFullDuplexSocketRunner.readinessPollIntervalNanoseconds
        )
    }
}
