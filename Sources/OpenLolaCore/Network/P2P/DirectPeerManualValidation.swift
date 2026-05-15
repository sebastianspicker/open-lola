import Darwin
import Foundation

public struct DirectPeerManualNetworkShape: Equatable, Sendable {
    public var localHost: String
    public var remoteHost: String
    public var ports: DirectPeerPortSet

    public init(localHost: String, remoteHost: String, ports: DirectPeerPortSet) {
        self.localHost = localHost
        self.remoteHost = remoteHost
        self.ports = ports
    }

    public func validate() throws {
        try DirectPeerManualEndpointValidator.requireAdvertisableHost(localHost, field: "localHost")
        try DirectPeerManualEndpointValidator.requireAdvertisableHost(remoteHost, field: "remoteHost")
        try ports.validate(localHost: localHost, remoteHost: remoteHost)
    }
}

public struct DirectPeerPortSet: Equatable, Sendable {
    public var controlPort: UInt16
    public var remoteControlPort: UInt16
    public var audioPort: UInt16
    public var videoPort: UInt16
    public var metricsPort: UInt16

    public init(
        controlPort: UInt16,
        remoteControlPort: UInt16,
        audioPort: UInt16,
        videoPort: UInt16,
        metricsPort: UInt16
    ) {
        self.controlPort = controlPort
        self.remoteControlPort = remoteControlPort
        self.audioPort = audioPort
        self.videoPort = videoPort
        self.metricsPort = metricsPort
    }

    public func validate(localHost: String, remoteHost: String) throws {
        var entries: [(field: String, port: UInt16)] = [
            ("controlPort", controlPort),
            ("audioPort", audioPort),
            ("videoPort", videoPort),
            ("metricsPort", metricsPort),
        ]
        if localHost == remoteHost {
            entries.append(("remoteControlPort", remoteControlPort))
        } else {
            try requireValidPort(remoteControlPort, field: "remoteControlPort")
        }
        var seen: Set<UInt16> = []
        for entry in entries {
            try requireValidPort(entry.port, field: entry.field)
            guard seen.insert(entry.port).inserted else {
                throw DirectPeerSessionSocketRunnerError.duplicateManualPort(entry.field, entry.port)
            }
        }
    }

    private func requireValidPort(_ port: UInt16, field: String) throws {
        guard port > 0 else {
            throw DirectPeerSessionSocketRunnerError.invalidManualPort(field, port)
        }
    }
}

public enum DirectPeerManualEndpointValidator {
    public static func requireAdvertisableHost(_ host: String, field: String) throws {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed == host else {
            throw DirectPeerSessionSocketRunnerError.invalidManualHost(field, host)
        }
        guard trimmed != "0.0.0.0", trimmed != "::", trimmed != "*" else {
            throw DirectPeerSessionSocketRunnerError.invalidManualHost(field, host)
        }
        var address = in_addr()
        let inetPtonStatus = trimmed.withCString { pointer in
            inet_pton(AF_INET, pointer, &address)
        }
        guard inetPtonStatus == 1 else {
            throw DirectPeerSessionSocketRunnerError.invalidManualHostParse(field, host, inetPtonStatus)
        }
    }

    public static func isSupportedAdvertisedIPv4Host(_ host: String) -> Bool {
        do {
            try requireAdvertisableHost(host, field: "host")
            return true
        } catch {
            return false
        }
    }
}

public enum DirectPeerSessionAVMediaShapeError: Error, Equatable, Sendable {
    case invalidSampleFormat(String)
    case invalidVideoPixelFormat(String)
    case invalidAudioTransportShape(DirectPeerSessionAudioTransport)
}

public struct DirectPeerSessionAVMediaShape: Equatable, Sendable {
    public var audioTransport: DirectPeerSessionAudioTransport
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var sampleFormatText: String
    public var channelCount: Int
    public var videoPixelFormatText: String

    public init(
        audioTransport: DirectPeerSessionAudioTransport,
        sampleRateHertz: Int,
        framesPerPacket: Int,
        sampleFormatText: String,
        channelCount: Int,
        videoPixelFormatText: String
    ) {
        self.audioTransport = audioTransport
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.sampleFormatText = sampleFormatText
        self.channelCount = channelCount
        self.videoPixelFormatText = videoPixelFormatText
    }

    public var sampleFormat: UdpPcmSampleFormat {
        get throws {
            try Self.sampleFormat(from: sampleFormatText)
        }
    }

    public var normalizedVideoPixelFormat: String {
        get throws {
            try Self.normalizedVideoPixelFormat(from: videoPixelFormatText)
        }
    }

    public func validate() throws {
        let parsedSampleFormat = try sampleFormat
        _ = try normalizedVideoPixelFormat
        try Self.validateAudioTransportShape(
            audioTransport,
            sampleRateHertz: sampleRateHertz,
            framesPerPacket: framesPerPacket,
            sampleFormat: parsedSampleFormat,
            channelCount: channelCount
        )
    }

    public static func sampleFormat(from value: String) throws -> UdpPcmSampleFormat {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "float32":
            return .float32LittleEndian
        case "int16":
            return .int16LittleEndian
        default:
            throw DirectPeerSessionAVMediaShapeError.invalidSampleFormat(value)
        }
    }

    public static func normalizedVideoPixelFormat(from value: String) throws -> String {
        let normalized = directPeerNormalizedVideoPixelFormat(value)
        guard ["bgra8", "rgb24", "yuv422"].contains(normalized) else {
            throw DirectPeerSessionAVMediaShapeError.invalidVideoPixelFormat(value)
        }
        return normalized
    }

    public static func validateAudioTransportShape(
        _ transport: DirectPeerSessionAudioTransport,
        sampleRateHertz: Int,
        framesPerPacket: Int,
        sampleFormat: UdpPcmSampleFormat,
        channelCount: Int
    ) throws {
        switch transport {
        case .openLolaRaw:
            return
        case .openLolaOpusCeltLowDelay:
            do {
                try OpusCELTLowDelayCodecValidation.validate(
                    sampleRateHertz: sampleRateHertz,
                    frameCount: framesPerPacket,
                    sampleFormat: sampleFormat,
                    channelCount: channelCount
                )
            } catch {
                throw DirectPeerSessionAVMediaShapeError.invalidAudioTransportShape(transport)
            }
        case .aes67ST2110L24:
            guard sampleRateHertz == AES67ST2110L24Profile.clockRateHertz,
                  framesPerPacket == AES67ST2110L24Profile.framesPerPacket,
                  sampleFormat == .float32LittleEndian,
                  channelCount == AES67ST2110L24Profile.channelCount else {
                throw DirectPeerSessionAVMediaShapeError.invalidAudioTransportShape(transport)
            }
        }
    }
}
