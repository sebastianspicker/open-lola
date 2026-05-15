import Foundation

public enum VideoMediaPacketizer {
    public static func packets(
        for frame: CapturedVideoFrame,
        maxPacketBytes: Int = RawVideoFrameTransport.defaultMaxPacketBytes
    ) throws -> [UdpMediaPacket] {
        let fragmentPacketBytes = try videoMediaFragmentPacketByteLimit(maxPacketBytes: maxPacketBytes)
        let fragments = try RawVideoFrameTransport.fragments(
            for: frame,
            maxPacketBytes: fragmentPacketBytes
        )
        return try fragments.map { fragment in
            UdpMediaPacket(
                header: UdpMediaPacketHeader(
                    payloadType: .videoRawFrameFragment,
                    streamID: fragment.streamID,
                    sequenceNumber: fragment.frameSequenceNumber,
                    timestampNanoseconds: fragment.timestampNanoseconds
                ),
                payload: try fragment.encoded()
            )
        }
    }

    public static func packets(
        for rawFrame: RawCapturedVideoFrame,
        maxPacketBytes: Int = RawVideoFrameTransport.defaultMaxPacketBytes,
        payloadType: SessionPayloadType = .videoRawFrameFragment
    ) throws -> [UdpMediaPacket] {
        let fragmentPacketBytes = try videoMediaFragmentPacketByteLimit(maxPacketBytes: maxPacketBytes)
        let fragments = try RawVideoFrameTransport.fragments(
            for: rawFrame,
            maxPacketBytes: fragmentPacketBytes
        )
        return try fragments.map { fragment in
            UdpMediaPacket(
                header: UdpMediaPacketHeader(
                    payloadType: payloadType,
                    streamID: fragment.streamID,
                    sequenceNumber: fragment.frameSequenceNumber,
                    timestampNanoseconds: fragment.timestampNanoseconds
                ),
                payload: try fragment.encoded()
            )
        }
    }
}

private func videoMediaFragmentPacketByteLimit(maxPacketBytes: Int) throws -> Int {
    guard maxPacketBytes > UdpMediaPacketHeader.byteCount else {
        throw VideoTransportFragmentError.maxPacketTooSmall(
            maxPacketBytes: maxPacketBytes,
            overheadBytes: UdpMediaPacketHeader.byteCount
        )
    }
    return maxPacketBytes - UdpMediaPacketHeader.byteCount
}
