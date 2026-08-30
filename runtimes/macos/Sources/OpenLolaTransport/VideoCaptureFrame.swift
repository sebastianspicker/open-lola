import OpenLolaSessionDomain
import Foundation

/// Metadata that identifies the stream and timestamp clock for captured video.
public struct VideoCaptureStreamMetadata: Codable, Equatable, Sendable {
    public var streamID: UInt32
    public var sourceRole: VideoStreamRole
    public var timestampBasis: VideoTimestampBasis

    public init(streamID: UInt32, sourceRole: VideoStreamRole, timestampBasis: VideoTimestampBasis) {
        self.streamID = streamID
        self.sourceRole = sourceRole
        self.timestampBasis = timestampBasis
    }

    public static let syntheticTestPattern = VideoCaptureStreamMetadata(
        streamID: 100,
        sourceRole: .testPattern,
        timestampBasis: .syntheticMonotonicNanoseconds
    )
}

/// A capture-independent video frame description carried by transport.
public struct CapturedVideoFrame: Codable, Equatable, Sendable {
    public var streamID: UInt32
    public var sequenceNumber: UInt64
    public var timestampNanoseconds: UInt64
    public var timestampBasis: VideoTimestampBasis
    public var sourceRole: VideoStreamRole
    public var width: Int
    public var height: Int
    public var pixelFormat: String
    public var frameRate: VideoFrameRate
    public var fingerprint: String

    package init(
        streamID: UInt32,
        sequenceNumber: UInt64,
        timestampNanoseconds: UInt64,
        timestampBasis: VideoTimestampBasis,
        sourceRole: VideoStreamRole,
        width: Int,
        height: Int,
        pixelFormat: String,
        frameRate: VideoFrameRate,
        fingerprint: String
    ) {
        self.streamID = streamID
        self.sequenceNumber = sequenceNumber
        self.timestampNanoseconds = timestampNanoseconds
        self.timestampBasis = timestampBasis
        self.sourceRole = sourceRole
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.frameRate = frameRate
        self.fingerprint = fingerprint
    }
}

/// A capture-independent video frame payload carried by transport.
public struct RawCapturedVideoFrame: Equatable, Sendable {
    public var metadata: CapturedVideoFrame
    public var payload: Data

    public init(metadata: CapturedVideoFrame, payload: Data) {
        self.metadata = metadata
        self.payload = payload
    }
}
