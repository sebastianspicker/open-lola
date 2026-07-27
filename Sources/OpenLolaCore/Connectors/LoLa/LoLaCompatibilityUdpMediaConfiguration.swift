// Parses and validates LoLa UDP transmit and receive settings, routes, ports, and deadlines.
import Foundation

/// Identifies the local host, peer, and output destination for LoLa UDP media.
public struct LoLaUdpMediaEndpoint: Equatable, Sendable {
    public var localHost: String
    public var peer: String
    public var outputPath: String

    public init(localHost: String, peer: String, outputPath: String) {
        self.localHost = localHost
        self.peer = peer
        self.outputPath = outputPath
    }
}

/// Groups the UDP ports assigned to LoLa audio and video media streams.
public struct LoLaUdpMediaPorts: Equatable, Sendable {
    public var audio: UInt16
    public var video: UInt16

    public init(audio: UInt16 = 19788, video: UInt16 = 19798) {
        self.audio = audio
        self.video = video
    }
}

/// Defines the channel count, sample rate, and packet duration for LoLa audio.
public struct LoLaMediaAudioFormat: Equatable, Sendable {
    public var channels: Int
    public var sampleRateHertz: Int
    public var framesPerPacket: Int

    public init(channels: Int = 2, sampleRateHertz: Int = 44_100, framesPerPacket: Int = 64) {
        self.channels = channels
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
    }
}

/// Defines the frame dimensions and pixel depth for LoLa video media.
public struct LoLaMediaVideoFormat: Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var bitsPerPixel: Int

    public init(width: Int = 1920, height: Int = 1080, bitsPerPixel: Int = 24) {
        self.width = width
        self.height = height
        self.bitsPerPixel = bitsPerPixel
    }
}

/// Combines LoLa media mode with its audio and video format requirements.
public struct LoLaMediaFormat: Equatable, Sendable {
    public var mode: ExternalConnectorMediaMode
    public var audio: LoLaMediaAudioFormat
    public var video: LoLaMediaVideoFormat

    public init(
        mode: ExternalConnectorMediaMode = .audioVideo,
        audio: LoLaMediaAudioFormat = .init(),
        video: LoLaMediaVideoFormat = .init()
    ) {
        self.mode = mode
        self.audio = audio
        self.video = video
    }
}

struct LoLaMediaConfigurationValues {
    let mode: ExternalConnectorMediaMode
    let channels: Int
    let sampleRateHertz: Int
    let framesPerPacket: Int
    let videoWidth: Int
    let videoHeight: Int
    let videoBitsPerPixel: Int

    init(_ media: LoLaMediaFormat) {
        mode = media.mode
        channels = media.audio.channels
        sampleRateHertz = media.audio.sampleRateHertz
        framesPerPacket = media.audio.framesPerPacket
        videoWidth = media.video.width
        videoHeight = media.video.height
        videoBitsPerPixel = media.video.bitsPerPixel
    }
}

protocol LoLaMediaFieldSource {
    var mediaMode: ExternalConnectorMediaMode { get }
    var channels: Int { get }
    var sampleRateHertz: Int { get }
    var framesPerPacket: Int { get }
    var videoWidth: Int { get }
    var videoHeight: Int { get }
    var videoBitsPerPixel: Int { get }
}

extension ExternalConnectorSessionConfiguration: LoLaMediaFieldSource {}

func applyLoLaMediaFields(
    to input: inout ExternalConnectorSessionConfigInput,
    from source: some LoLaMediaFieldSource
) {
    input.mediaMode = source.mediaMode
    input.channels = source.channels
    input.sampleRateHertz = source.sampleRateHertz
    input.framesPerPacket = source.framesPerPacket
    input.videoWidth = source.videoWidth
    input.videoHeight = source.videoHeight
    input.videoBitsPerPixel = source.videoBitsPerPixel
}

/// Defines the validated fields for LoLa UDP media transmit run configuration.
public struct LoLaUdpMediaTransmitRunConfiguration: Equatable, Sendable {
    public var localHost: String, peer: String, outputPath: String
    public var dryRun: Bool, packetCount: Int
    public var mediaMode: ExternalConnectorMediaMode
    public var audioPort: UInt16, videoPort: UInt16
    public var channels: Int, sampleRateHertz: Int, framesPerPacket: Int
    public var videoWidth: Int, videoHeight: Int, videoBitsPerPixel: Int

    public struct Execution: Equatable, Sendable {
        public var dryRun: Bool
        public var packetCount: Int

        public init(dryRun: Bool = true, packetCount: Int = 1) {
            self.dryRun = dryRun
            self.packetCount = packetCount
        }
    }

    public init(
        endpoint: LoLaUdpMediaEndpoint,
        execution: Execution = .init(),
        ports: LoLaUdpMediaPorts = .init(),
        media: LoLaMediaFormat = .init()
    ) {
        localHost = endpoint.localHost
        peer = endpoint.peer
        outputPath = endpoint.outputPath
        dryRun = execution.dryRun
        packetCount = execution.packetCount
        mediaMode = media.mode
        audioPort = ports.audio
        videoPort = ports.video
        channels = media.audio.channels
        sampleRateHertz = media.audio.sampleRateHertz
        framesPerPacket = media.audio.framesPerPacket
        videoWidth = media.video.width
        videoHeight = media.video.height
        videoBitsPerPixel = media.video.bitsPerPixel
    }

    public static func parse(_ arguments: [String]) throws -> LoLaUdpMediaTransmitRunConfiguration {
        let values = try parseLoLaUdpMediaArguments(arguments)
        return try LoLaUdpMediaTransmitRunConfiguration(
            endpoint: .init(
                localHost: requiredExternalConnectorValue("--local-host", values),
                peer: requiredExternalConnectorValue("--peer", values),
                outputPath: requiredExternalConnectorValue("--output", values)
            ),
            execution: .init(
                dryRun: optionalExternalConnectorBoolean("--dry-run", values) ?? true,
                packetCount: optionalExternalConnectorPositiveInteger("--packets", values) ?? 1
            ),
            ports: .init(
                audio: optionalExternalConnectorPort("--audio-port", values) ?? 19788,
                video: optionalExternalConnectorPort("--video-port", values) ?? 19798
            ),
            media: try loLaMediaFormat(from: values)
        )
    }
}

extension LoLaUdpMediaTransmitRunConfiguration: LoLaMediaFieldSource {}

func loLaMediaFormat(from values: [String: String]) throws -> LoLaMediaFormat {
    try LoLaMediaFormat(
        mode: values["--media"].map(parseExternalConnectorMediaMode) ?? .audioVideo,
        audio: .init(
            channels: optionalExternalConnectorPositiveInteger("--channels", values) ?? 2,
            sampleRateHertz: optionalExternalConnectorPositiveInteger("--sample-rate", values) ?? 44_100,
            framesPerPacket: optionalExternalConnectorPositiveInteger("--frames", values) ?? 64
        ),
        video: .init(
            width: optionalExternalConnectorPositiveInteger("--video-width", values) ?? 1920,
            height: optionalExternalConnectorPositiveInteger("--video-height", values) ?? 1080,
            bitsPerPixel: optionalExternalConnectorPositiveInteger("--video-bpp", values) ?? 24
        )
    )
}

/// Defines the validated fields for LoLa UDP media receive run configuration.
public struct LoLaUdpMediaReceiveRunConfiguration: Equatable, Sendable {
    public var localHost: String, peer: String, outputPath: String
    public var dryRun: Bool, maxDatagrams: Int
    public var mediaMode: ExternalConnectorMediaMode
    public var audioPort: UInt16, videoPort: UInt16
    public var videoWidth: Int, videoHeight: Int, videoBitsPerPixel: Int
    public var timeoutSeconds: Int

    public struct Execution: Equatable, Sendable {
        public var dryRun: Bool
        public var maxDatagrams: Int
        public var timeoutSeconds: Int

        public init(dryRun: Bool = true, maxDatagrams: Int = 3, timeoutSeconds: Int = 1) {
            self.dryRun = dryRun
            self.maxDatagrams = maxDatagrams
            self.timeoutSeconds = timeoutSeconds
        }
    }

    public init(
        endpoint: LoLaUdpMediaEndpoint,
        execution: Execution = .init(),
        ports: LoLaUdpMediaPorts = .init(),
        mediaMode: ExternalConnectorMediaMode = .audioVideo,
        video: LoLaMediaVideoFormat = .init()
    ) {
        localHost = endpoint.localHost
        peer = endpoint.peer
        outputPath = endpoint.outputPath
        dryRun = execution.dryRun
        maxDatagrams = execution.maxDatagrams
        self.mediaMode = mediaMode
        audioPort = ports.audio
        videoPort = ports.video
        videoWidth = video.width
        videoHeight = video.height
        videoBitsPerPixel = video.bitsPerPixel
        timeoutSeconds = execution.timeoutSeconds
    }

    public static func parse(_ arguments: [String]) throws -> LoLaUdpMediaReceiveRunConfiguration {
        let values = try parseLoLaUdpMediaArguments(arguments)
        return try LoLaUdpMediaReceiveRunConfiguration(
            endpoint: .init(
                localHost: requiredExternalConnectorValue("--local-host", values),
                peer: values["--peer"] ?? "0.0.0.0",
                outputPath: requiredExternalConnectorValue("--output", values)
            ),
            execution: .init(
                dryRun: optionalExternalConnectorBoolean("--dry-run", values) ?? true,
                maxDatagrams: optionalExternalConnectorPositiveInteger("--packets", values) ?? 3,
                timeoutSeconds: optionalExternalConnectorPositiveInteger("--timeout-seconds", values) ?? 1
            ),
            ports: .init(
                audio: optionalExternalConnectorPort("--audio-port", values) ?? 19788,
                video: optionalExternalConnectorPort("--video-port", values) ?? 19798
            ),
            mediaMode: values["--media"].map(parseExternalConnectorMediaMode) ?? .audioVideo,
            video: .init(
                width: optionalExternalConnectorPositiveInteger("--video-width", values) ?? 1920,
                height: optionalExternalConnectorPositiveInteger("--video-height", values) ?? 1080,
                bitsPerPixel: optionalExternalConnectorPositiveInteger("--video-bpp", values) ?? 24
            )
        )
    }
}
