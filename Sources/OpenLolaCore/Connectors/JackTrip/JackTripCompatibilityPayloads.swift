import Foundation

func jackTripPayload(
    configuration: ExternalConnectorSessionConfiguration,
    audioProvider: any JackTripAudioFrameProviding,
    packetIndex: Int,
    bitResolution: JackTripBitResolution
) throws -> Data {
    let interleaved = try audioProvider.interleavedInt16PCM(
        sequenceNumber: packetIndex,
        channels: configuration.channels,
        frames: configuration.framesPerPacket
    )
    switch configuration.jackTrip.payloadEncoding {
    case .pcm:
        return try JackTripAudioPayloadCodec.planarConvertedPayload(
            interleavedLittleEndianInt16PCM: interleaved,
            channels: configuration.channels,
            frames: configuration.framesPerPacket,
            bitResolution: bitResolution
        )
    case .opusCELTLowDelay:
        let floatPCM = try jackTripFloat32PCM(
            interleavedLittleEndianInt16PCM: interleaved,
            channels: configuration.channels,
            frames: configuration.framesPerPacket
        )
        let encoded = try OpusCELTLowDelayEncoder(channelCount: configuration.channels).encode(floatPCM)
        return try JackTripAdvancedModeCodec.encodeOpusExtensionPacket(
            encodedOpusPayload: encoded,
            sequenceNumber: UInt16(packetIndex & 0xffff),
            timestampMicroseconds: UInt64(1_700_000_000_000_000 + packetIndex * configuration.framesPerPacket),
            channels: try uint8(configuration.channels, "channels")
        ).planarAudioPayload
    }
}

func jackTripFloat32PCM(
    interleavedLittleEndianInt16PCM: Data,
    channels: Int,
    frames: Int
) throws -> Data {
    try JackTripAudioPayloadCodec.validateInterleavedInt16ShapeForJackTrip(
        interleavedLittleEndianInt16PCM,
        channels: channels,
        frames: frames
    )
    var output = Data()
    output.reserveCapacity(channels * frames * MemoryLayout<Float>.size)
    let bytes = [UInt8](interleavedLittleEndianInt16PCM)
    for offset in stride(from: 0, to: bytes.count, by: 2) {
        let sample = Int16(bitPattern: UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8))
        var float = Float(sample) / Float(Int16.max)
        withUnsafeBytes(of: &float) { output.append(contentsOf: $0) }
    }
    return output
}

func uint8(_ value: Int, _ field: String) throws -> UInt8 {
    guard value > 0, value <= Int(UInt8.max) else {
        throw JackTripCompatibilityError.invalidField(field, value)
    }
    return UInt8(value)
}
