import Foundation

extension PeerSessionRunner {
    @discardableResult
    public mutating func sendAES67ST2110L24AudioPayload(
        _ payload: UnsafeRawBufferPointer,
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        ssrc: UInt32,
        streamID: Int = 1
    ) throws -> Int {
        guard state == .running else {
            throw PeerSessionRunnerError.missingAcceptedConfiguration
        }
        guard let audioTransport else {
            throw PeerSessionRunnerError.missingAudioTransport
        }
        guard let audioStream = acceptedConfiguration?.audioStreams.first(where: { $0.id == streamID }),
              audioStream.payloadType == .audioRtpL24 else {
            throw PeerSessionRunnerError.missingAudioStream
        }
        let rtpTimestamp = try directPeerAES67RTPTimestamp(
            senderFrameIndex: senderFrameIndex,
            sampleRateHertz: audioStream.sampleRateHertz
        )
        let packet = RTPPacket(
            header: RTPPacketHeader(
                sequenceNumber: directPeerRTPSequenceNumber(sequenceNumber),
                timestamp: rtpTimestamp,
                ssrc: ssrc
            ),
            payload: try L24PCMCodec.encodeFloat32InterleavedStereo(
                payload,
                framesPerPacket: audioStream.framesPerPacket
            )
        )
        try audioTransport.sendRawDatagram(try packet.encoded())
        metrics.mediaPacketsSent += 1
        return 1
    }

    public mutating func receiveAES67ST2110L24RTPPacketIfAvailable() throws -> RTPPacket? {
        guard let audioTransport else {
            throw PeerSessionRunnerError.missingAudioTransport
        }
        guard let data = try audioTransport.tryReceiveRawDatagram(
            maxByteCount: RTPPacketHeader.byteCount + AES67ST2110L24Profile.payloadByteCount
        ) else {
            return nil
        }
        let packet = try RTPPacket.decode(data)
        metrics.mediaPacketsReceived += 1
        metrics.audioPacketsRouted += 1
        return packet
    }
}

func directPeerRTPSequenceNumber(_ sequenceNumber: UInt64) -> UInt16 {
    UInt16(sequenceNumber & UInt64(UInt16.max))
}

func directPeerAES67RTPTimestamp(senderFrameIndex: UInt64, sampleRateHertz: Int) throws -> UInt32 {
    guard sampleRateHertz == AES67ST2110L24Profile.clockRateHertz else {
        throw PeerSessionRunnerError.unsupportedRTPAudioClock(sampleRateHertz: sampleRateHertz)
    }
    return UInt32(senderFrameIndex & UInt64(UInt32.max))
}
