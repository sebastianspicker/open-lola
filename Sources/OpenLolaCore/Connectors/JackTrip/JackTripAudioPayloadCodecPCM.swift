// Converts JackTrip PCM payloads between byte representation and normalized audio samples.
import Foundation

extension JackTripAudioPayloadCodec {
    public static func planarInt16Payload(
        interleavedLittleEndianPCM: Data,
        channels: Int,
        frames: Int
    ) throws -> Data {
        return try planarConvertedPayload(
            interleavedLittleEndianInt16PCM: interleavedLittleEndianPCM,
            channels: channels,
            frames: frames,
            bitResolution: .bit16
        )
    }

    public static func planarConvertedPayload(
        interleavedLittleEndianInt16PCM: Data,
        channels: Int,
        frames: Int,
        bitResolution: JackTripBitResolution
    ) throws -> Data {
        try validateInterleavedInt16ShapeForJackTrip(
            interleavedLittleEndianInt16PCM,
            channels: channels,
            frames: frames
        )
        let converted = convertInterleavedInt16(
            interleavedLittleEndianInt16PCM,
            to: bitResolution
        )
        return try planarPayload(
            interleavedLittleEndianPCM: converted,
            channels: channels,
            frames: frames,
            bitResolution: bitResolution
        )
    }

    public static func planarPayload(
        interleavedLittleEndianPCM: Data,
        channels: Int,
        frames: Int,
        bitResolution: JackTripBitResolution
    ) throws -> Data {
        try validatePCMShape(
            byteCount: interleavedLittleEndianPCM.count,
            channels: channels,
            frames: frames,
            bytesPerSample: bitResolution.bytesPerSample
        )
        let bytes = [UInt8](interleavedLittleEndianPCM)
        var planar = Data()
        planar.reserveCapacity(bytes.count)
        let sampleBytes = bitResolution.bytesPerSample
        for channel in 0..<channels {
            for frame in 0..<frames {
                let offset = ((frame * channels) + channel) * sampleBytes
                planar.append(contentsOf: bytes[offset..<offset + sampleBytes])
            }
        }
        return planar
    }

    public static func interleavedInt16Payload(
        planarLittleEndianPCM: Data,
        channels: Int,
        frames: Int
    ) throws -> Data {
        return try interleavedPayload(
            planarLittleEndianPCM: planarLittleEndianPCM,
            channels: channels,
            frames: frames,
            bitResolution: .bit16
        )
    }

    public static func interleavedPayload(
        planarLittleEndianPCM: Data,
        channels: Int,
        frames: Int,
        bitResolution: JackTripBitResolution
    ) throws -> Data {
        try validatePCMShape(
            byteCount: planarLittleEndianPCM.count,
            channels: channels,
            frames: frames,
            bytesPerSample: bitResolution.bytesPerSample
        )
        let bytes = [UInt8](planarLittleEndianPCM)
        var interleaved = Data(count: bytes.count)
        let sampleBytes = bitResolution.bytesPerSample
        for channel in 0..<channels {
            for frame in 0..<frames {
                let source = ((channel * frames) + frame) * sampleBytes
                let destination = ((frame * channels) + channel) * sampleBytes
                for byte in 0..<sampleBytes {
                    interleaved[destination + byte] = bytes[source + byte]
                }
            }
        }
        return interleaved
    }

    private static func validatePCMShape(
        byteCount: Int,
        channels: Int,
        frames: Int,
        bytesPerSample: Int
    ) throws {
        guard channels > 0 else {
            throw JackTripCompatibilityError.invalidField("channels", channels)
        }
        guard frames > 0 else {
            throw JackTripCompatibilityError.invalidField("frames", frames)
        }
        let expected = channels * frames * bytesPerSample
        guard byteCount == expected else {
            throw JackTripCompatibilityError.payloadLengthMismatch(expected: expected, actual: byteCount)
        }
    }

    public static func validateInterleavedInt16ShapeForJackTrip(
        _ interleavedLittleEndianInt16PCM: Data,
        channels: Int,
        frames: Int
    ) throws {
        try validatePCMShape(
            byteCount: interleavedLittleEndianInt16PCM.count,
            channels: channels,
            frames: frames,
            bytesPerSample: MemoryLayout<Int16>.size
        )
    }

    private static func convertInterleavedInt16(
        _ interleavedLittleEndianPCM: Data,
        to bitResolution: JackTripBitResolution
    ) -> Data {
        guard bitResolution != .bit16 else {
            return interleavedLittleEndianPCM
        }
        let bytes = [UInt8](interleavedLittleEndianPCM)
        var output = Data()
        output.reserveCapacity((bytes.count / 2) * bitResolution.bytesPerSample)
        var index = 0
        while index + 1 < bytes.count {
            let raw = UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
            let sample = Int32(Int16(bitPattern: raw))
            switch bitResolution {
            case .bit8:
                let converted = Int8(clamping: Int(sample >> 8))
                output.append(UInt8(bitPattern: converted))
            case .bit16:
                output.append(bytes[index])
                output.append(bytes[index + 1])
            case .bit24:
                let converted = sample << 8
                output.append(UInt8(truncatingIfNeeded: converted))
                output.append(UInt8(truncatingIfNeeded: converted >> 8))
                output.append(UInt8(truncatingIfNeeded: converted >> 16))
            case .bit32:
                let converted = sample << 16
                output.append(UInt8(truncatingIfNeeded: converted))
                output.append(UInt8(truncatingIfNeeded: converted >> 8))
                output.append(UInt8(truncatingIfNeeded: converted >> 16))
                output.append(UInt8(truncatingIfNeeded: converted >> 24))
            }
            index += 2
        }
        return output
    }
}
