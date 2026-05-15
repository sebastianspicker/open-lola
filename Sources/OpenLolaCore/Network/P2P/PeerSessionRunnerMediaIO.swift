import Foundation

let peerSessionDefaultMediaReceiveByteBudget = 1_200
let peerSessionMaximumMediaReceiveByteBudget = 65_507

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
        guard state == .running else {
            throw PeerSessionRunnerError.missingAcceptedConfiguration
        }
        guard let audioTransport else {
            throw PeerSessionRunnerError.missingAudioTransport
        }
        guard let audioStream = acceptedConfiguration?.audioStreams.first(where: { $0.id == streamID }) else {
            throw PeerSessionRunnerError.missingAudioStream
        }
        let mode = try audioMode(for: audioStream)
        let packets = try UdpPcmV2Packetizer.packetize(
            payload,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: senderFrameIndex,
            senderHostTimeNanoseconds: hostTimeNanoseconds,
            mode: mode
        )
        for packet in packets {
            try audioTransport.send(UdpMediaPacket(
                header: UdpMediaPacketHeader(
                    payloadType: .audioPcmV2,
                    streamID: UInt32(streamID),
                    sequenceNumber: sequenceNumber,
                    timestampNanoseconds: packet.header.senderHostTimeNanoseconds
                ),
                payload: try packet.encoded()
            ))
            metrics.mediaPacketsSent += 1
        }
        return packets.count
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
        guard state == .running else {
            throw PeerSessionRunnerError.missingAcceptedConfiguration
        }
        guard let audioTransport else {
            throw PeerSessionRunnerError.missingAudioTransport
        }
        guard let audioStream = acceptedConfiguration?.audioStreams.first(where: { $0.id == streamID }),
              audioStream.payloadType == .audioOpusCeltLowDelayFrame else {
            throw PeerSessionRunnerError.missingAudioStream
        }
        let packet = AudioOpusCeltLowDelayPacket(
            header: AudioOpusCeltLowDelayPacketHeader(
                streamID: UInt32(streamID),
                sequenceNumber: sequenceNumber,
                senderFrameIndex: senderFrameIndex,
                senderHostTimeNanoseconds: hostTimeNanoseconds,
                channelCount: UInt16(channelCount)
            ),
            payload: payload
        )
        try audioTransport.send(UdpMediaPacket(
            header: UdpMediaPacketHeader(
                payloadType: .audioOpusCeltLowDelayFrame,
                streamID: UInt32(streamID),
                sequenceNumber: sequenceNumber,
                timestampNanoseconds: hostTimeNanoseconds
            ),
            payload: try packet.encoded()
        ))
        metrics.mediaPacketsSent += 1
        return 1
    }

    @discardableResult
    public mutating func sendRawVideoFrame(
        _ frame: RawCapturedVideoFrame,
        payloadType: SessionPayloadType = .videoRawFrameFragment
    ) throws -> Int {
        guard state == .running else {
            throw PeerSessionRunnerError.missingAcceptedConfiguration
        }
        guard let videoTransport else {
            throw PeerSessionRunnerError.missingVideoTransport
        }
        let packets = try VideoMediaPacketizer.packets(
            for: frame,
            maxPacketBytes: acceptedConfiguration?.mtuBytes ?? 1_200,
            payloadType: payloadType
        )
        for packet in packets {
            try videoTransport.send(packet)
            metrics.mediaPacketsSent += 1
        }
        return packets.count
    }

    public mutating func sendAudioTimingProbe(
        sequenceNumber: UInt64,
        streamID: Int = 1
    ) throws {
        guard state == .running else {
            throw PeerSessionRunnerError.missingAcceptedConfiguration
        }
        guard let audioTransport else {
            throw PeerSessionRunnerError.missingAudioTransport
        }
        guard let audioStream = acceptedConfiguration?.audioStreams.first(where: { $0.id == streamID }) else {
            throw PeerSessionRunnerError.missingAudioStream
        }
        let now = DispatchTime.now().uptimeNanoseconds
        let timing = MediaTimingPacket(
            streamID: UInt32(streamID),
            sequenceNumber: sequenceNumber,
            observedPayloadType: .audioPcmV2,
            senderFrameIndex: sequenceNumber * UInt64(audioStream.framesPerPacket),
            remoteSenderTimeNanoseconds: now,
            localObservationTimeNanoseconds: now,
            timestampOrigin: .syntheticMonotonicNanoseconds
        )
        try audioTransport.send(UdpMediaPacket(
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

    func waitForIncomingMedia(timeoutMicroseconds: UInt64) throws -> Bool {
        let transports = [audioTransport, videoTransport, metricsTransport].compactMap { $0 }
        guard !transports.isEmpty else {
            return false
        }
        let perTransportTimeout = max(1, timeoutMicroseconds / UInt64(transports.count))
        for transport in transports {
            if try transport.waitForReadable(timeoutMicroseconds: perTransportTimeout) {
                return true
            }
        }
        return false
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
        case .audioOpusCeltLowDelayFrame:
            metrics.mediaPacketsReceived += 1
            guard case .audioOpusCeltLowDelayFrame(let opus) = decoded.decodedPayload else {
                throw PeerSessionRunnerError.unsupportedControlMessage(.error)
            }
            received.decodedOpusCeltLowDelay = opus
            metrics.audioPacketsRouted += 1
        case .audioTiming:
            guard case .audioTiming(let timing) = decoded.decodedPayload else {
                throw PeerSessionRunnerError.unsupportedControlMessage(.error)
            }
            metrics.timingProbePacketsReceived += 1
            metrics.timingProbeMaxAgeMicroseconds = max(
                metrics.timingProbeMaxAgeMicroseconds,
                timing.observedAgeMicroseconds
            )
        default:
            break
        }
        return received
    }
}
