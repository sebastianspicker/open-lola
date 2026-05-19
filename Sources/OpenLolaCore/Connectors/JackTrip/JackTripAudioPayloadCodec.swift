import Foundation

public enum JackTripAudioPayloadCodec {
    public static func encodeDatagram(_ packets: [JackTripAudioPacket], headerMode: JackTripPacketHeaderMode) throws -> Data {
        switch headerMode {
        case .default:
            return try encodeDefaultDatagram(packets)
        case .jamLink:
            return try encodeJamLinkDatagram(packets)
        case .empty:
            return try encodeEmptyDatagram(packets)
        }
    }

    public static func decodeDatagram<Bytes: DataProtocol>(
        _ data: Bytes,
        headerMode: JackTripPacketHeaderMode,
        emptyHeaderTemplate: JackTripDefaultHeader? = nil
    ) throws -> [JackTripAudioPacket] {
        switch headerMode {
        case .default:
            return try decodeDefaultDatagram(data)
        case .jamLink:
            return try decodeJamLinkDatagram(data)
        case .empty:
            guard let emptyHeaderTemplate else {
                throw JackTripCompatibilityError.unsupportedMode("empty-header-missing-template")
            }
            return [try decodeEmptyPacket(data, template: emptyHeaderTemplate)]
        }
    }

    public static func encodeDefaultDatagram(_ packets: [JackTripAudioPacket]) throws -> Data {
        guard !packets.isEmpty else {
            throw JackTripCompatibilityError.invalidField("packets", 0)
        }
        var data = Data()
        for packet in packets {
            data.append(try encodeDefaultPacket(packet))
        }
        return data
    }

    public static func encodeEmptyDatagram(_ packets: [JackTripAudioPacket]) throws -> Data {
        guard packets.count == 1, let packet = packets.first else {
            throw JackTripCompatibilityError.unsupportedMode("empty-header-redundancy")
        }
        try packet.validate()
        return packet.planarAudioPayload
    }

    public static func encodeJamLinkDatagram(_ packets: [JackTripAudioPacket]) throws -> Data {
        guard !packets.isEmpty else {
            throw JackTripCompatibilityError.invalidField("packets", 0)
        }
        var data = Data()
        for packet in packets {
            data.append(try encodeJamLinkPacket(packet))
        }
        return data
    }

    public static func encodeJamLinkPacket(_ packet: JackTripAudioPacket) throws -> Data {
        try packet.validate()
        let header = try JackTripJamLinkHeader(packet: packet)
        var data = Data()
        data.reserveCapacity(JackTripJamLinkHeader.byteCount + packet.planarAudioPayload.count)
        appendJackTripUInt16LE(header.common, to: &data)
        appendJackTripUInt16LE(header.sequenceNumber, to: &data)
        appendJackTripUInt32LE(header.timestamp, to: &data)
        data.append(packet.planarAudioPayload)
        return data
    }

    public static func decodeJamLinkDatagram<Bytes: DataProtocol>(_ data: Bytes) throws -> [JackTripAudioPacket] {
        let bytes = [UInt8](data)
        guard !bytes.isEmpty else {
            throw JackTripCompatibilityError.truncatedPacket(byteCount: 0)
        }
        var packets: [JackTripAudioPacket] = []
        var offset = 0
        while offset < bytes.count {
            guard bytes.count - offset >= JackTripJamLinkHeader.byteCount else {
                throw JackTripCompatibilityError.truncatedPacket(byteCount: bytes.count - offset)
            }
            let header = try JackTripJamLinkHeader(
                common: readJackTripUInt16LE(bytes, offset: offset),
                sequenceNumber: readJackTripUInt16LE(bytes, offset: offset + 2),
                timestamp: readJackTripUInt32LE(bytes, offset: offset + 4)
            )
            let packetByteCount = JackTripJamLinkHeader.byteCount
                + Int(header.bufferSizeSamples)
                * Int(header.channelCount)
                * JackTripBitResolution.bit16.bytesPerSample
            guard bytes.count - offset >= packetByteCount else {
                throw JackTripCompatibilityError.payloadLengthMismatch(
                    expected: packetByteCount - JackTripJamLinkHeader.byteCount,
                    actual: max(0, bytes.count - offset - JackTripJamLinkHeader.byteCount)
                )
            }
            packets.append(try decodeJamLinkPacket(bytes[offset..<offset + packetByteCount]))
            offset += packetByteCount
        }
        return packets
    }

    public static func decodeJamLinkPacket<Bytes: DataProtocol>(_ data: Bytes) throws -> JackTripAudioPacket {
        let bytes = [UInt8](data)
        guard bytes.count >= JackTripJamLinkHeader.byteCount else {
            throw JackTripCompatibilityError.truncatedPacket(byteCount: bytes.count)
        }
        let header = try JackTripJamLinkHeader(
            common: readJackTripUInt16LE(bytes, offset: 0),
            sequenceNumber: readJackTripUInt16LE(bytes, offset: 2),
            timestamp: readJackTripUInt32LE(bytes, offset: 4)
        )
        return try JackTripAudioPacket(
            header: header.defaultHeader(),
            planarAudioPayload: Data(bytes[JackTripJamLinkHeader.byteCount..<bytes.count])
        )
    }

    public static func decodeEmptyPacket<Bytes: DataProtocol>(
        _ data: Bytes,
        template: JackTripDefaultHeader
    ) throws -> JackTripAudioPacket {
        let payload = Data(data)
        return try JackTripAudioPacket(header: template, planarAudioPayload: payload)
    }

    public static func decodeDefaultDatagram<Bytes: DataProtocol>(_ data: Bytes) throws -> [JackTripAudioPacket] {
        let bytes = [UInt8](data)
        guard !bytes.isEmpty else {
            throw JackTripCompatibilityError.truncatedPacket(byteCount: 0)
        }
        var packets: [JackTripAudioPacket] = []
        var offset = 0
        while offset < bytes.count {
            guard bytes.count - offset >= JackTripDefaultHeader.byteCount else {
                throw JackTripCompatibilityError.truncatedPacket(byteCount: bytes.count - offset)
            }
            guard let sampleRate = JackTripSampleRate(rawValue: bytes[offset + 12]) else {
                throw JackTripCompatibilityError.unsupportedMode("sample-rate-enum-\(bytes[offset + 12])")
            }
            guard let bitResolution = JackTripBitResolution(rawValue: bytes[offset + 13]) else {
                throw JackTripCompatibilityError.unsupportedMode("bit-resolution-enum-\(bytes[offset + 13])")
            }
            let header = try JackTripDefaultHeader(
                timestampMicroseconds: readJackTripUInt64LE(bytes, offset: offset),
                sequenceNumber: readJackTripUInt16LE(bytes, offset: offset + 8),
                bufferSizeSamples: readJackTripUInt16LE(bytes, offset: offset + 10),
                sampleRate: sampleRate,
                bitResolution: bitResolution,
                incomingChannelsFromNetwork: bytes[offset + 14],
                outgoingChannelsToNetwork: bytes[offset + 15]
            )
            let packetByteCount = JackTripDefaultHeader.byteCount
                + Int(header.bufferSizeSamples)
                * header.payloadChannelCount
                * header.bitResolution.bytesPerSample
            guard bytes.count - offset >= packetByteCount else {
                throw JackTripCompatibilityError.payloadLengthMismatch(
                    expected: packetByteCount - JackTripDefaultHeader.byteCount,
                    actual: max(0, bytes.count - offset - JackTripDefaultHeader.byteCount)
                )
            }
            packets.append(try decodeDefaultPacket(bytes[offset..<offset + packetByteCount]))
            offset += packetByteCount
        }
        return packets
    }

    public static func encodeDefaultPacket(_ packet: JackTripAudioPacket) throws -> Data {
        try packet.header.validate()
        try packet.validate()
        var data = Data()
        data.reserveCapacity(JackTripDefaultHeader.byteCount + packet.planarAudioPayload.count)
        appendJackTripUInt64LE(packet.header.timestampMicroseconds, to: &data)
        appendJackTripUInt16LE(packet.header.sequenceNumber, to: &data)
        appendJackTripUInt16LE(packet.header.bufferSizeSamples, to: &data)
        data.append(packet.header.sampleRate.rawValue)
        data.append(packet.header.bitResolution.rawValue)
        data.append(packet.header.incomingChannelsFromNetwork)
        data.append(packet.header.outgoingChannelsToNetwork)
        data.append(packet.planarAudioPayload)
        return data
    }

    public static func decodeDefaultPacket<Bytes: DataProtocol>(_ data: Bytes) throws -> JackTripAudioPacket {
        let bytes = [UInt8](data)
        guard bytes.count >= JackTripDefaultHeader.byteCount else {
            throw JackTripCompatibilityError.truncatedPacket(byteCount: bytes.count)
        }
        guard let sampleRate = JackTripSampleRate(rawValue: bytes[12]) else {
            throw JackTripCompatibilityError.unsupportedMode("sample-rate-enum-\(bytes[12])")
        }
        guard let bitResolution = JackTripBitResolution(rawValue: bytes[13]) else {
            throw JackTripCompatibilityError.unsupportedMode("bit-resolution-enum-\(bytes[13])")
        }
        let header = try JackTripDefaultHeader(
            timestampMicroseconds: readJackTripUInt64LE(bytes, offset: 0),
            sequenceNumber: readJackTripUInt16LE(bytes, offset: 8),
            bufferSizeSamples: readJackTripUInt16LE(bytes, offset: 10),
            sampleRate: sampleRate,
            bitResolution: bitResolution,
            incomingChannelsFromNetwork: bytes[14],
            outgoingChannelsToNetwork: bytes[15]
        )
        let payload = Data(bytes[JackTripDefaultHeader.byteCount..<bytes.count])
        return try JackTripAudioPacket(header: header, planarAudioPayload: payload)
    }

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
