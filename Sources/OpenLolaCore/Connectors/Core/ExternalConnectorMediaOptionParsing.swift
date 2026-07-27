// Parses the media option block shared by connector session and connection-plan commands.

/// Defines the shared validated media option values for external connector plans.
public struct ExternalConnectorMediaOptionValues: Equatable, Sendable {
    public var durationSeconds: Int
    public var channels: Int
    public var sampleRateHertz: Int?
    public var framesPerPacket: Int?
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoFrameRate: Int
    public var videoBitsPerPixel: Int

    static let defaultValues = ExternalConnectorMediaOptionValues(
        durationSeconds: 1,
        channels: 2,
        sampleRateHertz: nil,
        framesPerPacket: nil,
        videoWidth: 1_920,
        videoHeight: 1_080,
        videoFrameRate: 30,
        videoBitsPerPixel: 24
    )
}

/// Provides direct access to shared external connector media option values.
public protocol ExternalConnectorMediaOptionConfiguring {
    var mediaOptions: ExternalConnectorMediaOptionValues { get set }
}

public extension ExternalConnectorMediaOptionConfiguring {
    var durationSeconds: Int {
        get { mediaOptions.durationSeconds }
        set { mediaOptions.durationSeconds = newValue }
    }

    var channels: Int {
        get { mediaOptions.channels }
        set { mediaOptions.channels = newValue }
    }

    var sampleRateHertz: Int? {
        get { mediaOptions.sampleRateHertz }
        set { mediaOptions.sampleRateHertz = newValue }
    }

    var framesPerPacket: Int? {
        get { mediaOptions.framesPerPacket }
        set { mediaOptions.framesPerPacket = newValue }
    }

    var videoWidth: Int {
        get { mediaOptions.videoWidth }
        set { mediaOptions.videoWidth = newValue }
    }

    var videoHeight: Int {
        get { mediaOptions.videoHeight }
        set { mediaOptions.videoHeight = newValue }
    }

    var videoFrameRate: Int {
        get { mediaOptions.videoFrameRate }
        set { mediaOptions.videoFrameRate = newValue }
    }

    var videoBitsPerPixel: Int {
        get { mediaOptions.videoBitsPerPixel }
        set { mediaOptions.videoBitsPerPixel = newValue }
    }
}

func parseExternalConnectorMediaOptionValues(
    _ values: [String: String]
) throws -> ExternalConnectorMediaOptionValues {
    var mediaOptions: ExternalConnectorMediaOptionValues = .defaultValues
    mediaOptions.durationSeconds = try optionalExternalConnectorPositiveInteger("--duration-seconds", values) ?? mediaOptions.durationSeconds
    mediaOptions.channels = try optionalExternalConnectorPositiveInteger("--channels", values) ?? mediaOptions.channels
    mediaOptions.sampleRateHertz = try optionalExternalConnectorPositiveInteger("--sample-rate", values)
    mediaOptions.framesPerPacket = try optionalExternalConnectorPositiveInteger("--frames", values)
    mediaOptions.videoWidth = try optionalExternalConnectorPositiveInteger("--video-width", values) ?? mediaOptions.videoWidth
    mediaOptions.videoHeight = try optionalExternalConnectorPositiveInteger("--video-height", values) ?? mediaOptions.videoHeight
    mediaOptions.videoFrameRate = try optionalExternalConnectorPositiveInteger("--video-fps", values) ?? mediaOptions.videoFrameRate
    mediaOptions.videoBitsPerPixel = try optionalExternalConnectorPositiveInteger("--video-bpp", values) ?? mediaOptions.videoBitsPerPixel
    return mediaOptions
}
