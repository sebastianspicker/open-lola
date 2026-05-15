import Foundation

private final class DirectAudioMediaRouterReceiver {
    private let lock = NSLock()
    var receiver: MadiReceiveEngine

    init(receiver: MadiReceiveEngine) {
        self.receiver = receiver
    }

    func route(_ packet: UdpPcmV2Packet, receivedAtHostTimeNanoseconds: UInt64) throws -> MadiReceivePacketResult {
        lock.lock()
        defer { lock.unlock() }
        return try receiver.receive(
            packet,
            receivedAtHostTimeNanoseconds: receivedAtHostTimeNanoseconds
        )
    }
}

final class DirectAudioMediaRouter: @unchecked Sendable {
    private var receivers: [UInt32: DirectAudioMediaRouterReceiver] = [:]
    private let lock = NSLock()

    init(configuration: SessionConfiguration) throws {
        for stream in configuration.audioStreams {
            let mode = try directAudioMediaRouterAudioMode(
                for: stream,
                mtuBytes: configuration.mtuBytes,
                latencyProfile: configuration.latencyProfile,
                rxBufferProfile: configuration.rxBufferProfile
            )
            receivers[UInt32(stream.id)] = DirectAudioMediaRouterReceiver(
                receiver: try MadiReceiveEngine(
                    configuration: MadiReceiveConfiguration(mode: mode)
                )
            )
        }
    }

    func route(_ packet: UdpPcmV2Packet) throws -> MadiReceivePacketResult {
        lock.lock()
        let receiverState = receivers[packet.header.streamID]
        lock.unlock()
        guard let receiverState else {
            throw PeerSessionRunnerError.missingAudioStream
        }
        let result = try receiverState.route(
            packet,
            receivedAtHostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
        )
        return result
    }
}

func directAudioMediaRouterAudioMode(
    for stream: AudioStreamDescription,
    mtuBytes: Int,
    latencyProfile: SessionLatencyProfile,
    rxBufferProfile: RxBufferProfile
) throws -> AudioTransportMode {
    let fragments = try UdpPcmV2FragmentPlanner.plan(
        UdpPcmV2FragmentPlanRequest(
            streamID: stream.id,
            totalChannelCount: stream.channelCount,
            framesPerPacket: stream.framesPerPacket,
            sampleRateHertz: stream.sampleRateHertz,
            sampleFormat: stream.sampleFormat,
            maxTransmissionUnitBytes: mtuBytes,
            maxFragmentsPerDeadline: 16,
            metadataRevision: 0,
            packingMode: .interleavedChannelRange
        )
    )
    return AudioTransportMode(
        protocolVersion: .udpPcmV2,
        sampleRateHertz: stream.sampleRateHertz,
        framesPerPacket: stream.framesPerPacket,
        channelCount: stream.channelCount,
        sampleFormat: stream.sampleFormat,
        latencyProfile: audioTransportLatencyProfile(latencyProfile),
        rxBufferProfile: rxBufferProfile,
        maxTransmissionUnitBytes: mtuBytes,
        channelOrder: stream.channelOrder,
        fragments: fragments
    )
}

private func audioTransportLatencyProfile(_ profile: SessionLatencyProfile) -> LatencyProfile {
    switch profile {
    case .directAudioFirst:
        .ultraLowLatency16
    case .balancedAV, .multiVideoPerformance, .wanStable:
        .safeLowLatency
    }
}
