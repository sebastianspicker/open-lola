// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Darwin
import Foundation

let peerSessionDefaultMediaReceiveByteBudget = 1_200
let peerSessionMaximumMediaReceiveByteBudget = 65_507

struct PeerSessionVideoSendAttempt: Equatable, Sendable {
    var packetsSent: Int
    var wouldBlock: Bool
}

func peerSessionMediaReceiveByteBudget(acceptedConfiguration: SessionConfiguration?) -> Int {
    guard let mtuBytes = acceptedConfiguration?.mtuBytes else {
        return peerSessionDefaultMediaReceiveByteBudget
    }
    return min(
        max(peerSessionDefaultMediaReceiveByteBudget, mtuBytes),
        peerSessionMaximumMediaReceiveByteBudget
    )
}

extension PeerSessionRunner {
    @discardableResult
    public mutating func sendAudioPacket(sequenceNumber: UInt64, streamID: Int = 1) throws -> Int {
        guard state == .running else {
            throw PeerSessionRunnerError.missingAcceptedConfiguration
        }
        guard let audioTransport else {
            throw PeerSessionRunnerError.missingAudioTransport
        }
        let packets = try makeAudioPackets(streamID: streamID, sequenceNumber: sequenceNumber)
        for packet in packets {
            let media = UdpMediaPacket(
                header: UdpMediaPacketHeader(
                    payloadType: .audioPcmV2,
                    streamID: UInt32(streamID),
                    sequenceNumber: sequenceNumber,
                    timestampNanoseconds: packet.header.senderHostTimeNanoseconds
                ),
                payload: try packet.encoded()
            )
            try audioTransport.send(media)
            metrics.mediaPacketsSent += 1
        }
        return packets.count
    }

    @discardableResult
    public mutating func sendAudioPayload(
        _ payload: Data,
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        hostTimeNanoseconds: UInt64,
        streamID: Int = 1
    ) throws -> Int {
        try payload.withUnsafeBytes { payloadBytes in
            try sendAudioPayload(
                payloadBytes,
                sequenceNumber: sequenceNumber,
                senderFrameIndex: senderFrameIndex,
                hostTimeNanoseconds: hostTimeNanoseconds,
                streamID: streamID
            )
        }
    }

    @discardableResult
    public mutating func sendAudioPayload(
        _ payload: UnsafeRawBufferPointer,
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        hostTimeNanoseconds: UInt64,
        streamID: Int = 1
    ) throws -> Int {
        guard try trySendAudioPayload(
            payload,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: senderFrameIndex,
            hostTimeNanoseconds: hostTimeNanoseconds,
            streamID: streamID
        ) else {
            throw UdpPcmRouteProbeError.sendFailed(EWOULDBLOCK)
        }
        guard let audioStream = acceptedConfiguration?.audioStreams.first(where: { $0.id == streamID }) else {
            throw PeerSessionRunnerError.missingAudioStream
        }
        return try audioMode(for: audioStream).fragments.count
    }

    mutating func trySendAudioPayload(
        _ payload: UnsafeRawBufferPointer,
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        hostTimeNanoseconds: UInt64,
        streamID: Int = 1
    ) throws -> Bool {
        let context = try runningAudioContext(streamID: streamID)
        let mode = try audioMode(for: context.stream)
        let packets = try UdpPcmV2Packetizer.packetize(
            payload,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: senderFrameIndex,
            senderHostTimeNanoseconds: hostTimeNanoseconds,
            mode: mode
        )
        for packet in packets {
            let result = try context.transport.trySend(UdpMediaPacket(
                header: UdpMediaPacketHeader(
                    payloadType: .audioPcmV2,
                    streamID: UInt32(streamID),
                    sequenceNumber: sequenceNumber,
                    timestampNanoseconds: packet.header.senderHostTimeNanoseconds
                ),
                payload: try packet.encoded()
            ))
            guard result == .sent else {
                return false
            }
            metrics.mediaPacketsSent += 1
        }
        return true
    }

    @discardableResult
    public mutating func sendOpusAudioPayload(
        _ payload: Data,
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        hostTimeNanoseconds: UInt64,
        streamID: Int = 1,
        channelCount: Int
    ) throws -> Int {
        guard try trySendOpusAudioPayload(
            payload,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: senderFrameIndex,
            hostTimeNanoseconds: hostTimeNanoseconds,
            streamID: streamID,
            channelCount: channelCount
        ) else {
            throw UdpPcmRouteProbeError.sendFailed(EWOULDBLOCK)
        }
        return 1
    }

    mutating func trySendOpusAudioPayload(
        _ payload: Data,
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        hostTimeNanoseconds: UInt64,
        streamID: Int = 1,
        channelCount: Int
    ) throws -> Bool {
        let context = try runningAudioContext(
            streamID: streamID,
            requiredPayloadType: .audioOpusCeltLowDelayFrame
        )
        let packet = AudioOpusCeltLowDelayPacket(
            header: AudioOpusCeltLowDelayPacketHeader(
                stream: .init(streamID: UInt32(streamID)),
                timing: .init(
                    sequenceNumber: sequenceNumber,
                    senderFrameIndex: senderFrameIndex,
                    senderHostTimeNanoseconds: hostTimeNanoseconds
                ),
                format: .init(channelCount: UInt16(channelCount))
            ),
            payload: payload
        )
        let result = try context.transport.trySend(UdpMediaPacket(
            header: UdpMediaPacketHeader(
                payloadType: .audioOpusCeltLowDelayFrame,
                streamID: UInt32(streamID),
                sequenceNumber: sequenceNumber,
                timestampNanoseconds: hostTimeNanoseconds
            ),
            payload: try packet.encoded()
        ))
        guard result == .sent else {
            return false
        }
        metrics.mediaPacketsSent += 1
        return true
    }

    @discardableResult
    public mutating func sendRawVideoFrame(
        _ frame: RawCapturedVideoFrame,
        payloadType: SessionPayloadType = .videoRawFrameFragment
    ) throws -> Int {
        try sendVideoPackets(rawVideoPackets(frame, payloadType: payloadType))
    }

    func rawVideoPackets(
        _ frame: RawCapturedVideoFrame,
        payloadType: SessionPayloadType = .videoRawFrameFragment
    ) throws -> [UdpMediaPacket] {
        guard state == .running else {
            throw PeerSessionRunnerError.missingAcceptedConfiguration
        }
        guard videoTransport != nil else {
            throw PeerSessionRunnerError.missingVideoTransport
        }
        return try VideoMediaPacketizer.packets(
            for: frame,
            maxPacketBytes: try videoPacketByteLimit(),
            payloadType: payloadType
        )
    }

    func videoPacketByteLimit() throws -> Int {
        guard state == .running, let acceptedConfiguration else {
            throw PeerSessionRunnerError.missingAcceptedConfiguration
        }
        guard videoTransport != nil else {
            throw PeerSessionRunnerError.missingVideoTransport
        }
        return acceptedConfiguration.mtuBytes
    }

    @discardableResult
    mutating func sendVideoPackets<Packets: Collection>(_ packets: Packets) throws -> Int
    where Packets.Element == UdpMediaPacket {
        let attempt = try trySendVideoPackets(packets)
        guard !attempt.wouldBlock else {
            throw UdpPcmRouteProbeError.sendFailed(EWOULDBLOCK)
        }
        return attempt.packetsSent
    }

    mutating func trySendVideoPackets<Packets: Collection>(
        _ packets: Packets
    ) throws -> PeerSessionVideoSendAttempt where Packets.Element == UdpMediaPacket {
        guard state == .running else {
            throw PeerSessionRunnerError.missingAcceptedConfiguration
        }
        guard let videoTransport else {
            throw PeerSessionRunnerError.missingVideoTransport
        }
        var sent = 0
        for packet in packets {
            guard try videoTransport.trySend(packet) == .sent else {
                return PeerSessionVideoSendAttempt(packetsSent: sent, wouldBlock: true)
            }
            metrics.mediaPacketsSent += 1
            sent += 1
        }
        return PeerSessionVideoSendAttempt(packetsSent: sent, wouldBlock: false)
    }

    public mutating func sendAudioTimingProbe(
        sequenceNumber: UInt64,
        streamID: Int = 1
    ) throws {
        let context = try runningAudioContext(streamID: streamID)
        let now = DispatchTime.now().uptimeNanoseconds
        let timing = MediaTimingPacket(
            streamID: UInt32(streamID),
            sequenceNumber: sequenceNumber,
            observedPayloadType: .audioPcmV2,
            senderFrameIndex: sequenceNumber * UInt64(context.stream.framesPerPacket),
            remoteSenderTimeNanoseconds: now,
            localObservationTimeNanoseconds: now,
            timestampOrigin: .syntheticMonotonicNanoseconds
        )
        try context.transport.send(UdpMediaPacket(
            header: UdpMediaPacketHeader(
                payloadType: .audioTiming,
                streamID: UInt32(streamID),
                sequenceNumber: sequenceNumber,
                timestampNanoseconds: now
            ),
            payload: try JSONEncoder().encode(timing)
        ))
        metrics.timingProbePacketsSent += 1
    }

    @discardableResult
    public mutating func receiveMediaPacket() throws -> UdpMediaPacket {
        try receiveAudioMediaPacket()
    }

    @discardableResult
    public mutating func receiveAudioMediaPacket() throws -> UdpMediaPacket {
        guard let audioTransport else {
            throw PeerSessionRunnerError.missingAudioTransport
        }
        let decoded = try audioTransport.receiveDecoded(maxByteCount: mediaReceiveByteBudget)
        _ = try recordReceivedAudioOrTiming(decoded)
        return decoded.packet
    }

    @discardableResult
    public mutating func receiveAudioMediaPacketIfAvailable() throws -> UdpMediaPacket? {
        try receiveDecodedAudioMediaPacketIfAvailable()?.packet
    }

    mutating func receiveDecodedAudioMediaPacketIfAvailable() throws -> PeerSessionReceivedAudioMediaPacket? {
        guard let audioTransport else {
            throw PeerSessionRunnerError.missingAudioTransport
        }
        guard let decoded = try audioTransport.tryReceiveDecoded(maxByteCount: mediaReceiveByteBudget) else {
            return nil
        }
        return try recordReceivedAudioOrTiming(decoded)
    }

    @discardableResult
    public mutating func receiveVideoMediaPacket() throws -> UdpMediaPacket {
        guard let videoTransport else {
            throw PeerSessionRunnerError.missingVideoTransport
        }
        let decoded = try videoTransport.receiveDecoded(maxByteCount: mediaReceiveByteBudget)
        _ = try recordReceivedVideo(decoded)
        return decoded.packet
    }

    @discardableResult
    public mutating func receiveVideoMediaPacketIfAvailable() throws -> UdpMediaPacket? {
        try receiveDecodedVideoMediaPacketIfAvailable()?.packet
    }

    mutating func receiveDecodedVideoMediaPacketIfAvailable() throws -> PeerSessionReceivedVideoMediaPacket? {
        guard let videoTransport else {
            throw PeerSessionRunnerError.missingVideoTransport
        }
        guard let decoded = try videoTransport.tryReceiveDecoded(maxByteCount: mediaReceiveByteBudget) else {
            return nil
        }
        return try recordReceivedVideo(decoded)
    }

    private var mediaReceiveByteBudget: Int {
        peerSessionMediaReceiveByteBudget(acceptedConfiguration: acceptedConfiguration)
    }

    func waitForIncomingMedia(
        timeoutMicroseconds: UInt64,
        additionalReadDescriptor: Int32? = nil
    ) throws -> Bool {
        try waitForIncomingMedia(
            timeoutMicroseconds: timeoutMicroseconds,
            additionalReadDescriptors: additionalReadDescriptor.map { [$0] } ?? []
        )
    }

    func waitForIncomingMedia(
        timeoutMicroseconds: UInt64,
        additionalReadDescriptors: [Int32]
    ) throws -> Bool {
        let transports = [audioTransport, videoTransport, metricsTransport].compactMap { $0 }
        guard !transports.isEmpty || !additionalReadDescriptors.isEmpty else {
            return false
        }
        var descriptors = try transports.map { try $0.openSocketDescriptor() }
        descriptors.append(contentsOf: additionalReadDescriptors)
        let readable = try waitForReadableSockets(
            sockets: descriptors,
            timeoutMicroseconds: timeoutMicroseconds
        )
        for transport in transports {
            try transport.requireSocketOpenAfterBlockingOperation()
        }
        return !readable.isEmpty
    }

    private mutating func recordReceivedVideo(
        _ decoded: UdpMediaDecodedPacket
    ) throws -> PeerSessionReceivedVideoMediaPacket {
        var received = PeerSessionReceivedVideoMediaPacket(packet: decoded.packet)
        switch decoded.packet.header.payloadType {
        case .videoRawFrameFragment, .videoVideoToolboxFragment, .videoJpegXSFrameFragment:
            metrics.mediaPacketsReceived += 1
            guard case .videoFragment(let fragment) = decoded.decodedPayload else {
                throw PeerSessionRunnerError.unsupportedControlMessage(.error)
            }
            received.decodedFragment = fragment
            metrics.videoPacketsRouted += 1
        default:
            break
        }
        return received
    }

    private mutating func recordReceivedAudioOrTiming(
        _ decoded: UdpMediaDecodedPacket
    ) throws -> PeerSessionReceivedAudioMediaPacket {
        var received = PeerSessionReceivedAudioMediaPacket(packet: decoded.packet)
        switch decoded.packet.header.payloadType {
        case .audioPcmV2:
            try recordReceivedPcmV2(decoded, received: &received)
        case .audioOpusCeltLowDelayFrame:
            try recordReceivedOpusCeltLowDelay(decoded, received: &received)
        case .audioTiming:
            try recordReceivedAudioTiming(decoded)
        default:
            break
        }
        return received
    }

    private mutating func recordReceivedPcmV2(
        _ decoded: UdpMediaDecodedPacket,
        received: inout PeerSessionReceivedAudioMediaPacket
    ) throws {
        metrics.mediaPacketsReceived += 1
        guard case .audioPcmV2(let decodedPcm) = decoded.decodedPayload else {
            throw PeerSessionRunnerError.unsupportedControlMessage(.error)
        }
        guard let audioRouter else {
            throw PeerSessionRunnerError.missingAudioRouter
        }
        _ = try audioRouter.route(decodedPcm)
        self.audioRouter = audioRouter
        metrics.audioPacketsRouted += 1
        received.decodedPcmV2 = decodedPcm
    }

    private mutating func recordReceivedOpusCeltLowDelay(
        _ decoded: UdpMediaDecodedPacket,
        received: inout PeerSessionReceivedAudioMediaPacket
    ) throws {
        metrics.mediaPacketsReceived += 1
        guard case .audioOpusCeltLowDelayFrame(let opus) = decoded.decodedPayload else {
            throw PeerSessionRunnerError.unsupportedControlMessage(.error)
        }
        received.decodedOpusCeltLowDelay = opus
        metrics.audioPacketsRouted += 1
    }

    private mutating func recordReceivedAudioTiming(_ decoded: UdpMediaDecodedPacket) throws {
        guard case .audioTiming(let timing) = decoded.decodedPayload else {
            throw PeerSessionRunnerError.unsupportedControlMessage(.error)
        }
        metrics.timingProbePacketsReceived += 1
        metrics.timingProbeMaxAgeMicroseconds = max(
            metrics.timingProbeMaxAgeMicroseconds,
            timing.observedAgeMicroseconds
        )
    }
}
