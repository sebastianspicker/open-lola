// Implements DirectAudioMediaRouter audio-path behavior, isolating device and sample handling from higher-level routing.
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

    init(
        configuration: SessionConfiguration,
        localAudioCapabilities: AudioTransportCapabilities? = nil
    ) throws {
        for stream in configuration.audioStreams where stream.payloadType == .audioPcmV2 {
            let mode = try directAudioMediaRouterAudioMode(
                for: stream,
                mtuBytes: configuration.mtuBytes,
                latencyProfile: configuration.latencyProfile,
                rxBufferProfile: configuration.rxBufferProfile,
                localAudioCapabilities: localAudioCapabilities
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

enum DirectAudioMediaRouterError: Error, Equatable, Sendable {
    case unsupportedSampleRate(Int)
    case unsupportedFramesPerPacket(Int)
    case unsupportedSampleFormat(UdpPcmSampleFormat)
    case unsupportedChannelCount(requested: Int, available: Int)
    case unsupportedChannelIndex(index: Int, available: Int)
    case unsupportedPayloadType(SessionPayloadType)
}

func directAudioMediaRouterAudioMode(
    for stream: AudioStreamDescription,
    mtuBytes: Int,
    latencyProfile: SessionLatencyProfile,
    rxBufferProfile: RxBufferProfile,
    localAudioCapabilities: AudioTransportCapabilities? = nil
) throws -> AudioTransportMode {
    try validateDirectAudioMediaRouterStream(
        stream,
        localAudioCapabilities: localAudioCapabilities
    )
    let fragments = try UdpPcmV2FragmentPlanner.plan(stream: stream, mtuBytes: mtuBytes)
    return udpPcmV2AudioTransportMode(
        stream: stream,
        fragments: fragments,
        latencyProfile: audioTransportLatencyProfile(latencyProfile),
        rxBufferProfile: rxBufferProfile,
        maxTransmissionUnitBytes: mtuBytes
    )
}

private func validateDirectAudioMediaRouterStream(
    _ stream: AudioStreamDescription,
    localAudioCapabilities: AudioTransportCapabilities?
) throws {
    try stream.validate()
    guard stream.payloadType == .audioPcmV2 else {
        throw DirectAudioMediaRouterError.unsupportedPayloadType(stream.payloadType)
    }
    guard let localAudioCapabilities else {
        return
    }
    try validateDirectAudioMediaRouterLocalCapabilities(
        localAudioCapabilities,
        for: stream
    )
}

private func validateDirectAudioMediaRouterLocalCapabilities(
    _ localAudioCapabilities: AudioTransportCapabilities,
    for stream: AudioStreamDescription
) throws {
    try localAudioCapabilities.validateForSessionCapabilities()
    guard localAudioCapabilities.supportedPayloadTypes.contains(stream.payloadType) else {
        throw DirectAudioMediaRouterError.unsupportedPayloadType(stream.payloadType)
    }
    guard localAudioCapabilities.sampleRatesHertz.contains(stream.sampleRateHertz) else {
        throw DirectAudioMediaRouterError.unsupportedSampleRate(stream.sampleRateHertz)
    }
    guard localAudioCapabilities.framesPerPacketOptions.contains(stream.framesPerPacket) else {
        throw DirectAudioMediaRouterError.unsupportedFramesPerPacket(stream.framesPerPacket)
    }
    guard localAudioCapabilities.sampleFormats.contains(stream.sampleFormat) else {
        throw DirectAudioMediaRouterError.unsupportedSampleFormat(stream.sampleFormat)
    }

    let localChannels = localAudioCapabilities.channelSet.channels
    let availableChannelCount = localChannels.count
    guard availableChannelCount >= stream.channelCount else {
        throw DirectAudioMediaRouterError.unsupportedChannelCount(
            requested: stream.channelCount,
            available: availableChannelCount
        )
    }

    let localChannelIndices = Set(localChannels.map(\.stableSourceIndex))
    for channel in stream.channelOrder where !localChannelIndices.contains(channel.stableSourceIndex) {
        throw DirectAudioMediaRouterError.unsupportedChannelIndex(
            index: channel.stableSourceIndex,
            available: availableChannelCount
        )
    }
}

private func audioTransportLatencyProfile(_ profile: SessionLatencyProfile) -> LatencyProfile {
    switch profile {
    case .directAudioFirst:
        .ultraLowLatency16
    case .balancedAV, .multiVideoPerformance, .wanStable:
        .safeLowLatency
    }
}
