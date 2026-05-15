import Darwin
import Dispatch
import Foundation

public enum MadiFullDuplexSocketRunner {
    private static let drainPollIntervalNanoseconds: UInt64 = 100_000

    public static func run(
        configuration: MadiFullDuplexSessionConfiguration,
        receiverDriftFramesPerPacket: Int = 0
    ) throws -> MadiFullDuplexReport {
        try configuration.validate()

        let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(socket) }
        try bindIPv4(
            socket,
            host: configuration.localEndpoint.host,
            port: configuration.localEndpoint.port.bigEndian
        )
        try setNonBlocking(socket)

        var session = try MadiFullDuplexSession(configuration: configuration)
        try session.start()
        var receiveBuffer = [UInt8](repeating: 0, count: configuration.maxTransmissionUnitBytes)

        let localMode = try configuration.audioPair.localSendMode(
            maxTransmissionUnitBytes: configuration.maxTransmissionUnitBytes,
            maxFragmentsPerDeadline: configuration.maxFragmentsPerDeadline,
            metadataRevision: configuration.metadataRevision
        )
        let remoteMode = try configuration.audioPair.remoteReceiveMode(
            maxTransmissionUnitBytes: configuration.maxTransmissionUnitBytes,
            maxFragmentsPerDeadline: configuration.maxFragmentsPerDeadline,
            metadataRevision: configuration.metadataRevision,
            rxBufferProfile: configuration.rxBufferProfile
        )

        waitForPeerBindWindow(timeoutSeconds: configuration.peerBindTimeoutSeconds)
        try runPacketLoop(
            socket: socket,
            session: &session,
            configuration: configuration,
            localMode: localMode,
            receiveBuffer: &receiveBuffer
        )
        try drainRemotePackets(
            socket: socket,
            session: &session,
            configuration: configuration,
            expectedCompletedBlocks: configuration.packetCount
        )

        let simulation = try MadiFullDuplexClockDriftSimulator.run(
            sampleCount: max(2, configuration.packetCount),
            senderFrameStep: remoteMode.framesPerPacket,
            receiverFrameStep: remoteMode.framesPerPacket + receiverDriftFramesPerPacket,
            correctionPolicy: configuration.correctionPolicy
        )
        session.applyDriftSimulation(simulation)

        let report = MadiFullDuplexReport(
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
        try report.validate()
        return report
    }

    private static func waitForPeerBindWindow(timeoutSeconds: Double) {
        guard timeoutSeconds > 0 else {
            return
        }
        let deadline = DispatchTime.now().uptimeNanoseconds
            + UInt64((timeoutSeconds * 1_000_000_000).rounded(.up))
        while DispatchTime.now().uptimeNanoseconds < deadline {
            let remaining = deadline - DispatchTime.now().uptimeNanoseconds
            let interval = min(drainPollIntervalNanoseconds, remaining)
            sleepUntilUptimeNanoseconds(DispatchTime.now().uptimeNanoseconds + interval)
        }
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
