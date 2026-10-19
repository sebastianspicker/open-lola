import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
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

    /// LoLa video defaults shared with the Rust station: its `VideoSettings`
    /// default of 1280x720 at 60 fps, 8 bpp, uncompressed, sent as Mono8
    /// (`BAYER:0`). The Rust responder checks FPS, BPP and BAYER exactly, so a
    /// default session no longer fails with `video frame rate mismatch`.
    public static let lolaDefaultValues = ExternalConnectorMediaOptionValues(
        durationSeconds: 1,
        channels: 2,
        sampleRateHertz: nil,
        framesPerPacket: nil,
        videoWidth: 1_280,
        videoHeight: 720,
        videoFrameRate: 60,
        videoBitsPerPixel: 8
    )

    /// Largest accepted `--video-width` or `--video-height`.
    public static let maximumVideoDimension = 16_384

    /// Largest accepted width x height: a quarter of 16384 x 16384, so frame byte counts stay far from overflow.
    public static let maximumVideoPixelCount = 16_384 * 16_384 / 4

    /// Returns the option defaults a connector starts from before flags apply.
    public static func defaults(for connector: ExternalConnectorKind) -> ExternalConnectorMediaOptionValues {
        connector == .lola ? lolaDefaultValues : defaultValues
    }
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
    _ values: [String: String],
    defaults: ExternalConnectorMediaOptionValues = .defaultValues
) throws -> ExternalConnectorMediaOptionValues {
    var mediaOptions = defaults
    mediaOptions.durationSeconds = try optionalExternalConnectorPositiveInteger("--duration-seconds", values) ?? mediaOptions.durationSeconds
    mediaOptions.channels = try optionalExternalConnectorPositiveInteger("--channels", values) ?? mediaOptions.channels
    mediaOptions.sampleRateHertz = try optionalExternalConnectorPositiveInteger("--sample-rate", values)
    mediaOptions.framesPerPacket = try optionalExternalConnectorPositiveInteger("--frames", values)
    mediaOptions.videoWidth = try optionalExternalConnectorVideoDimension("--video-width", values) ?? mediaOptions.videoWidth
    mediaOptions.videoHeight = try optionalExternalConnectorVideoDimension("--video-height", values) ?? mediaOptions.videoHeight
    mediaOptions.videoFrameRate = try optionalExternalConnectorPositiveInteger("--video-fps", values) ?? mediaOptions.videoFrameRate
    mediaOptions.videoBitsPerPixel = try optionalExternalConnectorPositiveInteger("--video-bpp", values) ?? mediaOptions.videoBitsPerPixel
    let pixelCount = mediaOptions.videoWidth * mediaOptions.videoHeight
    guard pixelCount <= ExternalConnectorMediaOptionValues.maximumVideoPixelCount else {
        throw ExternalConnectorSessionError.invalidVideoGeometry(
            "\(mediaOptions.videoWidth)x\(mediaOptions.videoHeight) is \(pixelCount) pixels; the maximum is "
                + "\(ExternalConnectorMediaOptionValues.maximumVideoPixelCount)"
        )
    }
    return mediaOptions
}

/// Parses a positive video dimension no larger than `maximumVideoDimension`, so `width * height * 4` cannot overflow.
private func optionalExternalConnectorVideoDimension(_ key: String, _ values: [String: String]) throws -> Int? {
    guard let dimension = try optionalExternalConnectorPositiveInteger(key, values) else {
        return nil
    }
    guard dimension <= ExternalConnectorMediaOptionValues.maximumVideoDimension else {
        throw ExternalConnectorSessionError.invalidVideoGeometry(
            "\(key) \(dimension) exceeds the maximum of \(ExternalConnectorMediaOptionValues.maximumVideoDimension)"
        )
    }
    return dimension
}
