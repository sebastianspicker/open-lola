// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Darwin
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
        guard try trySendAES67ST2110L24AudioPayload(
            payload,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: senderFrameIndex,
            ssrc: ssrc,
            streamID: streamID
        ) else {
            throw UdpPcmRouteProbeError.sendFailed(EWOULDBLOCK)
        }
        return 1
    }

    mutating func trySendAES67ST2110L24AudioPayload(
        _ payload: UnsafeRawBufferPointer,
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        ssrc: UInt32,
        streamID: Int = 1
    ) throws -> Bool {
        let context = try runningAudioContext(streamID: streamID, requiredPayloadType: .audioRtpL24)
        let rtpTimestamp = try directPeerAES67RTPTimestamp(
            senderFrameIndex: senderFrameIndex,
            sampleRateHertz: context.stream.sampleRateHertz
        )
        let packet = RTPPacket(
            header: RTPPacketHeader(
                sequenceNumber: directPeerRTPSequenceNumber(sequenceNumber),
                timestamp: rtpTimestamp,
                ssrc: ssrc
            ),
            payload: try L24PCMCodec.encodeFloat32InterleavedStereo(
                payload,
                framesPerPacket: context.stream.framesPerPacket
            )
        )
        guard try context.transport.trySendRawDatagram(try packet.encoded()) == .sent else {
            return false
        }
        metrics.mediaPacketsSent += 1
        return true
    }

    public mutating func receiveAES67ST2110L24RTPPacketIfAvailable() throws -> RTPPacket? {
        guard let audioTransport else {
            throw PeerSessionRunnerError.missingAudioTransport
        }
        guard let audioStream = acceptedConfiguration?.audioStreams.first(where: { $0.id == 1 }),
              audioStream.payloadType == .audioRtpL24,
              let packetTime = AES67ST2110L24Profile.packetTime(
                  forFramesPerPacket: audioStream.framesPerPacket
              ),
              let data = try audioTransport.tryReceiveRawDatagram(
                  maxByteCount: RTPPacketHeader.byteCount + AES67ST2110L24Profile.payloadByteCount(for: packetTime)
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
