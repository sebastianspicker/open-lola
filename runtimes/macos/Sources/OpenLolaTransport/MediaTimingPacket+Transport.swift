import OpenLolaSessionDomain

public extension MediaTimingPacket {
    init(
        audioPacket: UdpPcmPacket,
        streamID: UInt32,
        localObservationTimeNanoseconds: UInt64
    ) throws {
        self.init(
            streamID: streamID,
            sequenceNumber: audioPacket.header.sequenceNumber,
            observedPayloadType: .audioPcmV2,
            senderFrameIndex: audioPacket.header.senderFrameIndex,
            remoteSenderTimeNanoseconds: audioPacket.header.senderHostTimeNanoseconds,
            localObservationTimeNanoseconds: localObservationTimeNanoseconds,
            timestampOrigin: .audioPacketSenderHostTimeNanoseconds
        )
        try validate()
    }

    init(audioV2Packet: UdpPcmV2Packet, localObservationTimeNanoseconds: UInt64) throws {
        self.init(
            streamID: audioV2Packet.header.streamID,
            sequenceNumber: audioV2Packet.header.sequenceNumber,
            observedPayloadType: .audioPcmV2,
            senderFrameIndex: audioV2Packet.header.senderFrameIndex,
            remoteSenderTimeNanoseconds: audioV2Packet.header.senderHostTimeNanoseconds,
            localObservationTimeNanoseconds: localObservationTimeNanoseconds,
            timestampOrigin: .audioPacketSenderHostTimeNanoseconds
        )
        try validate()
    }

    init(videoPacket: VideoTransportPacket, localObservationTimeNanoseconds: UInt64) throws {
        self.init(
            streamID: videoPacket.streamID,
            sequenceNumber: videoPacket.sequenceNumber,
            observedPayloadType: .videoRawFrameFragment,
            senderFrameIndex: nil,
            remoteSenderTimeNanoseconds: videoPacket.timestampNanoseconds,
            localObservationTimeNanoseconds: localObservationTimeNanoseconds,
            timestampOrigin: .videoPacketTimestampNanoseconds
        )
        try validate()
    }
}
