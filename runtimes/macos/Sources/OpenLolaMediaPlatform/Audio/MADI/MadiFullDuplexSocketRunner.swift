// Exchanges readiness, sends timed audio blocks, and drains socket input under fixed deadlines for the MADI full-duplex transport.
import Darwin
import Dispatch
import Foundation

/// Executes a bounded madi full duplex socket run and returns accountable MADI full-duplex transport evidence.
public enum MadiFullDuplexSocketRunner {
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
        let socket = try makeUdpSocket(
            receiveTimeoutSeconds: 1,
            bufferProfile: .realtimeAudio
        )
        try bindIPv4(
            socket,
            host: configuration.localEndpoint.host,
            port: configuration.localEndpoint.port.bigEndian
        )
        try setNonBlocking(socket)
        return socket
    }

    private static func startedSession(
configuration: MadiFullDuplexSessionConfiguration
) throws -> MadiFullDuplexSession {
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
            notes: "Socket-backed UDP PCM v2 model run using synthetic capture payloads and a model render "
                + "callback. It did not exercise ADC/interface input, Core Audio capture/output, DAC/interface "
                + "output, or physical MADI end-to-end latency. Packetized model fragments and kernel-accepted "
                + "socket fragments are reported separately. PASS still requires physical two-peer RME MADI "
                + "Core Audio evidence and packet capture."
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
        _ = try trySendDatagram(
            exchange.localReady,
            socket: socket,
            host: configuration.remoteEndpoint.host,
            port: configuration.remoteEndpoint.port.bigEndian,
            nonBlocking: true
        )
    }

    private static func receivedExpectedReadiness(
        socket: Int32,
        exchange: MadiFullDuplexReadinessExchange,
        receiveBuffer: inout [UInt8]
    ) throws -> Bool {
        var drained = 0
        while drained < 64,
              DispatchTime.now().uptimeNanoseconds < exchange.deadlineNanoseconds,
              let data = try receiveDatagramIfAvailable(
            socket: socket,
            byteCount: exchange.receiveByteCount,
            buffer: &receiveBuffer
        ) {
            drained += 1
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
        let context = MadiFullDuplexPacketLoopContext(
            socket: socket,
            configuration: configuration,
            localMode: localMode
        )
        var slotStartNanoseconds = DispatchTime.now().uptimeNanoseconds

        for index in 0..<configuration.packetCount {
            let timing = madiRealtimeSlotTiming(
                nowNanoseconds: DispatchTime.now().uptimeNanoseconds,
                scheduledStartNanoseconds: slotStartNanoseconds,
                intervalNanoseconds: intervalNanoseconds
            )
            slotStartNanoseconds = timing.nextSlotStartNanoseconds
            guard timing.shouldTransmit else {
                session.recordSocketDeadlineDrop()
                continue
            }
            try runPacketLoopIteration(
                index: index,
                timing: timing,
                context: context,
                session: &session,
                receiveBuffer: &receiveBuffer
            )
        }
    }

    private static func runPacketLoopIteration(
        index: Int,
        timing: MadiRealtimeSlotTiming,
        context: MadiFullDuplexPacketLoopContext,
        session: inout MadiFullDuplexSession,
        receiveBuffer: inout [UInt8]
    ) throws {
        sleepUntilUptimeNanoseconds(timing.sendNotBeforeNanoseconds)
        let senderFrameIndex = UInt64(index * context.localMode.framesPerPacket)
        _ = try session.captureLocalPayload(
            startFrame: senderFrameIndex,
            hostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds,
            payload: SyntheticAudioPayload.make(
                seed: index,
                byteCount: context.localMode.payloadByteCount
            )
        )
        let packets = try session.sendNextLocalPackets()
        let sendResult = try sendMadiAudioBlock(packets) { encoded in
            try trySendDatagram(
                encoded,
                socket: context.socket,
                host: context.configuration.remoteEndpoint.host,
                port: context.configuration.remoteEndpoint.port.bigEndian,
                nonBlocking: true
            )
        }
        session.recordSocketTransmit(
            sentFragments: sendResult.sentFragments,
            droppedForBackpressure: sendResult.droppedForBackpressure
        )
        let renderAttempted = try drainUntil(
            socket: context.socket,
            session: &session,
            deadlineNanoseconds: timing.nextSlotStartNanoseconds,
            byteCount: context.configuration.maxTransmissionUnitBytes,
            receiveBuffer: &receiveBuffer
        )
        if !renderAttempted {
            _ = try session.renderRemoteAudioCallback()
        }
        sleepUntilUptimeNanoseconds(timing.nextSlotStartNanoseconds)
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
            let renderAttempted = try drainUntil(
                socket: socket,
                session: &session,
                deadlineNanoseconds: DispatchTime.now().uptimeNanoseconds + 1_000_000,
                byteCount: configuration.maxTransmissionUnitBytes,
                receiveBuffer: &receiveBuffer
            )
            if !renderAttempted {
                _ = try session.renderRemoteAudioCallback()
            }
        }
    }

    private static func drainUntil(
        socket: Int32,
        session: inout MadiFullDuplexSession,
        deadlineNanoseconds: UInt64,
        byteCount: Int,
        receiveBuffer: inout [UInt8]
    ) throws -> Bool {
        var renderAttempted = false
        while DispatchTime.now().uptimeNanoseconds < deadlineNanoseconds {
            try waitForReadableSocket(socket, deadlineNanoseconds: deadlineNanoseconds)
            var drained = 0
            while drained < 64,
                  DispatchTime.now().uptimeNanoseconds < deadlineNanoseconds,
                  let data = try receiveDatagramIfAvailable(
                socket: socket,
                byteCount: byteCount,
                buffer: &receiveBuffer
            ) {
                drained += 1
                if isReadinessDatagram(data) {
                    continue
                }
                let packet = try UdpPcmV2Packet.decode(data)
                let results = try session.receiveRemotePackets(
                    [packet],
                    receivedAtHostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
                )
                if results.contains(.queued) {
                    _ = try session.renderRemoteAudioCallback()
                    renderAttempted = true
                }
            }
        }
        return renderAttempted
    }

    private static func waitForReadableSocket(_ socket: Int32, deadlineNanoseconds: UInt64) throws {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now < deadlineNanoseconds else {
            return
        }
        let waitNanoseconds = deadlineNanoseconds - now
        let timeoutMicroseconds = max(1, (waitNanoseconds + 999) / 1_000)
        _ = try waitForReadableSockets(
            sockets: [socket],
            timeoutMicroseconds: timeoutMicroseconds
        )
    }

}

private struct MadiFullDuplexPacketLoopContext {
    var socket: Int32
    var configuration: MadiFullDuplexSessionConfiguration
    var localMode: AudioTransportMode
}

struct MadiRealtimeSlotTiming: Equatable, Sendable {
    var shouldTransmit: Bool
    var sendNotBeforeNanoseconds: UInt64
    var nextSlotStartNanoseconds: UInt64
}

func madiRealtimeSlotTiming(
    nowNanoseconds: UInt64,
    scheduledStartNanoseconds: UInt64,
    intervalNanoseconds: UInt64
) -> MadiRealtimeSlotTiming {
    let interval = max(1, intervalNanoseconds)
    let scheduledEnd = saturatedMadiNanosecondSum(scheduledStartNanoseconds, interval)
    guard nowNanoseconds < scheduledEnd else {
        return MadiRealtimeSlotTiming(
            shouldTransmit: false,
            sendNotBeforeNanoseconds: nowNanoseconds,
            // Preserve the original absolute schedule. The caller advances one
            // logical slot per iteration, dropping every expired quantum
            // instead of stretching the session or bursting stale audio.
            nextSlotStartNanoseconds: scheduledEnd
        )
    }
    return MadiRealtimeSlotTiming(
        shouldTransmit: true,
        sendNotBeforeNanoseconds: scheduledStartNanoseconds,
        nextSlotStartNanoseconds: scheduledEnd
    )
}

private func saturatedMadiNanosecondSum(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
    lhs > UInt64.max - rhs ? UInt64.max : lhs + rhs
}

struct MadiSocketAudioBlockSendResult: Equatable, Sendable {
    var sentFragments: Int
    var droppedForBackpressure: Bool
}

func sendMadiAudioBlock(
    _ packets: [UdpPcmV2Packet],
    send: (Data) throws -> UdpDatagramSendResult
) throws -> MadiSocketAudioBlockSendResult {
    var sentFragments = 0
    for packet in packets {
        guard try send(packet.encoded()) == .sent else {
            return MadiSocketAudioBlockSendResult(
                sentFragments: sentFragments,
                droppedForBackpressure: true
            )
        }
        sentFragments += 1
    }
    return MadiSocketAudioBlockSendResult(
        sentFragments: sentFragments,
        droppedForBackpressure: false
    )
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
