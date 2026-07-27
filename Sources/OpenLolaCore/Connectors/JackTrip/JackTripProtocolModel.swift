// Defines JackTrip packet headers, sample formats, protocol constants, and clean-room evidence boundaries.
import Foundation

/// Defines failures reported when JackTrip compatibility error cannot continue.
public enum JackTripCompatibilityError: Error, Equatable, Sendable {
    case truncatedPacket(byteCount: Int)
    case invalidField(String, Int)
    case unsupportedMode(String)
    case payloadLengthMismatch(expected: Int, actual: Int)
    case receiveTimeout(expected: Int, actual: Int)
}

/// Defines the supported choices for JackTrip sample rate.
public enum JackTripSampleRate: UInt8, Codable, Equatable, Sendable {
    case hz22050 = 0
    case hz32000 = 1
    case hz44100 = 2
    case hz48000 = 3
    case hz88200 = 4
    case hz96000 = 5
    case hz192000 = 6

    public init(hertz: Int) throws {
        switch hertz {
        case 22_050: self = .hz22050
        case 32_000: self = .hz32000
        case 44_100: self = .hz44100
        case 48_000: self = .hz48000
        case 88_200: self = .hz88200
        case 96_000: self = .hz96000
        case 192_000: self = .hz192000
        default: throw JackTripCompatibilityError.unsupportedMode("sample-rate-\(hertz)")
        }
    }

    public var hertz: Int {
        switch self {
        case .hz22050: return 22_050
        case .hz32000: return 32_000
        case .hz44100: return 44_100
        case .hz48000: return 48_000
        case .hz88200: return 88_200
        case .hz96000: return 96_000
        case .hz192000: return 192_000
        }
    }
}

/// Defines the supported choices for JackTrip bit resolution.
public enum JackTripBitResolution: UInt8, Codable, Equatable, Sendable {
    case bit8 = 1
    case bit16 = 2
    case bit24 = 3
    case bit32 = 4

    public init(bits: Int) throws {
        switch bits {
        case 8: self = .bit8
        case 16: self = .bit16
        case 24: self = .bit24
        case 32: self = .bit32
        default: throw JackTripCompatibilityError.unsupportedMode("bit-resolution-\(bits)")
        }
    }

    public var bits: Int { Int(rawValue) * 8 }
    public var bytesPerSample: Int { bits / 8 }
}

/// Defines the validated fields for JackTrip default header.
public struct JackTripDefaultHeader: Codable, Equatable, Sendable {
    public static let byteCount = 16

    public var timestampMicroseconds: UInt64
    public var sequenceNumber: UInt16
    public var bufferSizeSamples: UInt16
    public var sampleRate: JackTripSampleRate
    public var bitResolution: JackTripBitResolution
    public var incomingChannelsFromNetwork: UInt8
    public var outgoingChannelsToNetwork: UInt8

    public init(
        timestampMicroseconds: UInt64,
        sequenceNumber: UInt16,
        bufferSizeSamples: UInt16,
        sampleRate: JackTripSampleRate,
        bitResolution: JackTripBitResolution = .bit16,
        incomingChannelsFromNetwork: UInt8,
        outgoingChannelsToNetwork: UInt8
    ) throws {
        self.timestampMicroseconds = timestampMicroseconds
        self.sequenceNumber = sequenceNumber
        self.bufferSizeSamples = bufferSizeSamples
        self.sampleRate = sampleRate
        self.bitResolution = bitResolution
        self.incomingChannelsFromNetwork = incomingChannelsFromNetwork
        self.outgoingChannelsToNetwork = outgoingChannelsToNetwork
        try validate()
    }

    public func validate() throws {
        guard timestampMicroseconds > 0 else {
            throw JackTripCompatibilityError.invalidField("timestampMicroseconds", 0)
        }
        guard bufferSizeSamples > 0 else {
            throw JackTripCompatibilityError.invalidField("bufferSizeSamples", Int(bufferSizeSamples))
        }
        guard incomingChannelsFromNetwork > 0 else {
            throw JackTripCompatibilityError.invalidField(
                "incomingChannelsFromNetwork",
                Int(incomingChannelsFromNetwork)
            )
        }
    }

    public var payloadChannelCount: Int {
        switch outgoingChannelsToNetwork {
        case JackTripCompatibility.matchingOutgoingChannelSentinel:
            return Int(incomingChannelsFromNetwork)
        case JackTripCompatibility.noInputChannelsSentinel:
            return 0
        default:
            return Int(outgoingChannelsToNetwork)
        }
    }
}

/// Defines the validated fields for JackTrip audio packet.
public struct JackTripAudioPacket: PacketCodec, Codable, Equatable, Sendable {
    public var header: JackTripDefaultHeader
    public var planarAudioPayload: Data

    public init(header: JackTripDefaultHeader, planarAudioPayload: Data) throws {
        self.header = header
        self.planarAudioPayload = planarAudioPayload
        try validate()
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> JackTripAudioPacket {
        try JackTripAudioPayloadCodec.decodeDefaultPacket(data)
    }

    public func encoded() throws -> Data {
        try JackTripAudioPayloadCodec.encodeDefaultPacket(self)
    }

    public func validate() throws {
        try header.validate()
        let expected = Int(header.bufferSizeSamples)
            * header.payloadChannelCount
            * header.bitResolution.bytesPerSample
        guard planarAudioPayload.count == expected else {
            throw JackTripCompatibilityError.payloadLengthMismatch(
                expected: expected,
                actual: planarAudioPayload.count
            )
        }
    }
}

/// Defines the validated fields for JackTrip jam link header.
public struct JackTripJamLinkHeader: Codable, Equatable, Sendable {
    public static let byteCount = 8
    private static let stereoFlag: UInt16 = 1 << 13
    private static let non16BitFlag: UInt16 = 1 << 12
    private static let rateMask: UInt16 = 0x7 << 9
    private static let samplesMask: UInt16 = 0x01ff

    public var common: UInt16
    public var sequenceNumber: UInt16
    public var timestamp: UInt32

    public init(common: UInt16, sequenceNumber: UInt16, timestamp: UInt32) throws {
        self.common = common
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        try validate()
    }

    public init(packet: JackTripAudioPacket) throws {
        let channels = packet.header.payloadChannelCount
        guard channels == 1 || channels == 2 else {
            throw JackTripCompatibilityError.unsupportedMode("jamlink-channels-\(channels)")
        }
        guard packet.header.bitResolution == .bit16 else {
            throw JackTripCompatibilityError.unsupportedMode(
                "jamlink-bit-resolution-\(packet.header.bitResolution.bits)"
            )
        }
        let samples = packet.header.bufferSizeSamples
        guard samples > 0, samples <= Self.samplesMask else {
            throw JackTripCompatibilityError.invalidField("jamlinkSamplesPerPacket", Int(samples))
        }
        var common = try Self.sampleRateBits(packet.header.sampleRate)
        common |= channels == 2 ? Self.stereoFlag : 0
        common |= samples
        try self.init(
            common: common,
            sequenceNumber: packet.header.sequenceNumber,
            timestamp: UInt32(packet.header.timestampMicroseconds & 0xffff_ffff)
        )
    }

    public func defaultHeader() throws -> JackTripDefaultHeader {
        try JackTripDefaultHeader(
            timestampMicroseconds: UInt64(max(timestamp, 1)),
            sequenceNumber: sequenceNumber,
            bufferSizeSamples: bufferSizeSamples,
            sampleRate: sampleRate,
            bitResolution: .bit16,
            incomingChannelsFromNetwork: channelCount,
            outgoingChannelsToNetwork: JackTripCompatibility.matchingOutgoingChannelSentinel
        )
    }

    public func validate() throws {
        if common & Self.non16BitFlag != 0 {
            throw JackTripCompatibilityError.unsupportedMode("jamlink-non-16-bit")
        }
        guard bufferSizeSamples > 0 else {
            throw JackTripCompatibilityError.invalidField("jamlinkSamplesPerPacket", Int(bufferSizeSamples))
        }
        _ = try Self.sampleRate(fromCommon: common)
    }

    public var bufferSizeSamples: UInt16 { common & Self.samplesMask }
    public var channelCount: UInt8 { common & Self.stereoFlag == 0 ? 1 : 2 }
    public var sampleRate: JackTripSampleRate { get throws { try Self.sampleRate(fromCommon: common) } }

    private static func sampleRateBits(_ sampleRate: JackTripSampleRate) throws -> UInt16 {
        switch sampleRate {
        case .hz48000: return 0 << 9
        case .hz44100: return 1 << 9
        case .hz32000: return 2 << 9
        case .hz22050: return 4 << 9
        default:
            throw JackTripCompatibilityError.unsupportedMode("jamlink-sample-rate-\(sampleRate.hertz)")
        }
    }

    private static func sampleRate(fromCommon common: UInt16) throws -> JackTripSampleRate {
        switch common & rateMask {
        case 0 << 9: return .hz48000
        case 1 << 9: return .hz44100
        case 2 << 9: return .hz32000
        case 4 << 9: return .hz22050
        default:
            throw JackTripCompatibilityError.unsupportedMode(
                "jamlink-sample-rate-code-\((common & rateMask) >> 9)"
            )
        }
    }
}

/// Defines JackTrip wire defaults, sentinel values, evidence boundaries, and unsupported-mode inventory.
public enum JackTripCompatibility {
    public static let defaultAudioPort: UInt16 = 4464
    public static let defaultBitResolution = JackTripBitResolution.bit16
    public static let matchingOutgoingChannelSentinel: UInt8 = 0
    public static let noInputChannelsSentinel: UInt8 = 0xff
    public static let stopControlDatagramByteCount = 63
    public static let evidenceBoundary = "Swift-native clean-room JackTrip DEFAULT, JAMLINK, EMPTY, " +
        "WebRTC data-channel, WebTransport datagram, JACK graph, plugin bridge, and Opus extension " +
        "packet models from public JackTrip NetworkProtocol.md and PacketHeader.h references. " +
        "Real JackTrip interoperability remains PARTIAL until measured peer capture evidence exists."
    public static let networkServiceClassStatus = "not-applied: JackTrip DSCP/service-class marking " +
        "is not configured by this bounded socket runner; route capture is required before any QoS claim."
    public static let unsupportedModes: [String] = []
}

/// Enumerates the supported operating modes for JackTrip packet header.
public enum JackTripPacketHeaderMode: String, Codable, Equatable, Sendable {
    case `default`
    case jamLink = "jamlink"
    case empty
}

/// Selects Core Audio or JACK graph as the JackTrip audio backend.
public enum JackTripAudioBackend: String, Codable, Equatable, Sendable {
    case coreAudio = "coreaudio"
    case jackGraph = "jack-graph"
}

/// Enumerates the supported operating modes for JackTrip transport.
public enum JackTripTransportMode: String, Codable, Equatable, Sendable {
    case udp
    case webRTC = "webrtc"
    case webTransport = "webtransport"
}

/// Enumerates the supported operating modes for JackTrip plugin.
public enum JackTripPluginMode: String, Codable, Equatable, Sendable {
    case disabled
    case audioBridge = "audio-bridge"
}

/// Defines the supported choices for JackTrip payload encoding.
public enum JackTripPayloadEncoding: String, Codable, Equatable, Sendable {
    case pcm
    case opusCELTLowDelay = "opus-celt-low-delay"
}

func appendJackTripUInt16LE(_ value: UInt16, to data: inout Data) {
    appendUdpPcmUInt16LE(value, to: &data)
}

func appendJackTripUInt64LE(_ value: UInt64, to data: inout Data) {
    appendUdpPcmUInt64LE(value, to: &data)
}

func appendJackTripUInt32LE(_ value: UInt32, to data: inout Data) {
    appendUdpPcmUInt32LE(value, to: &data)
}

func readJackTripUInt16LE(_ bytes: [UInt8], offset: Int) -> UInt16 {
    NetworkByteReader.readUInt16LE(bytes, offset: offset)
}

func readJackTripUInt64LE(_ bytes: [UInt8], offset: Int) -> UInt64 {
    NetworkByteReader.readUInt64LE(bytes, offset: offset)
}

func readJackTripUInt32LE(_ bytes: [UInt8], offset: Int) -> UInt32 {
    readPrevalidatedUInt32LE(bytes, offset: offset)
}
