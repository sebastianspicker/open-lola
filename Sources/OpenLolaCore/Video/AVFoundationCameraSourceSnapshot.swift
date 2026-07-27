// Snapshots the selected AVFoundation camera, stream metadata, format, and queue policy.
/// Captures one AVFoundation source, stream format, queue metrics, and retained-frame timing evidence.
public struct AVFoundationCameraSourceDescription: Codable, Equatable, Sendable {
    public var source: VideoSourceDescription
    public var stream: VideoCaptureStreamMetadata
    public var format: VideoCaptureFormat
    public var queue: VideoQueueMetrics
    public init(source: VideoSourceDescription, stream: VideoCaptureStreamMetadata = VideoCaptureStreamMetadata(streamID: 100, sourceRole: .avFoundationDevice, timestampBasis: .hostUptimeNanoseconds), format: VideoCaptureFormat, queue: VideoQueueMetrics) { self.source = source; self.stream = stream; self.format = format; self.queue = queue }
}

/// Records frame counts, timestamps, and raw capture metrics from an AVFoundation source.
public struct AVFoundationCameraCaptureEvidence: Codable, Equatable, Sendable {
    public var framesCaptured: Int
    public var framesRetained: Int
    public var capturedFrameTimestampsNanoseconds: [UInt64]
    public var callbackArrivalTimestampsNanoseconds: [UInt64]
    public var retainedFrameTimestampsNanoseconds: [UInt64]
    public var rawCapture: RawVideoCaptureMetrics
    public init(framesCaptured: Int, framesRetained: Int, capturedFrameTimestampsNanoseconds: [UInt64] = [], callbackArrivalTimestampsNanoseconds: [UInt64] = [], retainedFrameTimestampsNanoseconds: [UInt64], rawCapture: RawVideoCaptureMetrics = .disabled) { self.framesCaptured = framesCaptured; self.framesRetained = framesRetained; self.capturedFrameTimestampsNanoseconds = capturedFrameTimestampsNanoseconds; self.callbackArrivalTimestampsNanoseconds = callbackArrivalTimestampsNanoseconds; self.retainedFrameTimestampsNanoseconds = retainedFrameTimestampsNanoseconds; self.rawCapture = rawCapture }
}

/// Combines AVFoundation source metadata with capture evidence for persistence and review.
public struct AVFoundationCameraSourceSnapshot: Codable, Equatable, Sendable {
    public var source: VideoSourceDescription
    public var stream: VideoCaptureStreamMetadata
    public var format: VideoCaptureFormat
    public var queue: VideoQueueMetrics
    public var framesCaptured: Int
    public var framesRetained: Int
    public var capturedFrameTimestampsNanoseconds: [UInt64]
    public var callbackArrivalTimestampsNanoseconds: [UInt64]
    public var retainedFrameTimestampsNanoseconds: [UInt64]
    public var rawCapture: RawVideoCaptureMetrics

    public init(sourceDescription: AVFoundationCameraSourceDescription, captureEvidence: AVFoundationCameraCaptureEvidence) {
        self.source = sourceDescription.source
        self.stream = sourceDescription.stream
        self.format = sourceDescription.format
        self.queue = sourceDescription.queue
        self.framesCaptured = captureEvidence.framesCaptured
        self.framesRetained = captureEvidence.framesRetained
        self.capturedFrameTimestampsNanoseconds = captureEvidence.capturedFrameTimestampsNanoseconds
        self.callbackArrivalTimestampsNanoseconds = captureEvidence.callbackArrivalTimestampsNanoseconds
        self.retainedFrameTimestampsNanoseconds = captureEvidence.retainedFrameTimestampsNanoseconds
        self.rawCapture = captureEvidence.rawCapture
    }

    enum CodingKeys: String, CodingKey {
        case source
        case stream
        case format
        case queue
        case framesCaptured
        case framesRetained
        case capturedFrameTimestampsNanoseconds
        case callbackArrivalTimestampsNanoseconds
        case retainedFrameTimestampsNanoseconds
        case rawCapture
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(VideoSourceDescription.self, forKey: .source)
        stream = try container.decode(VideoCaptureStreamMetadata.self, forKey: .stream)
        format = try container.decode(VideoCaptureFormat.self, forKey: .format)
        queue = try container.decode(VideoQueueMetrics.self, forKey: .queue)
        framesCaptured = try container.decode(Int.self, forKey: .framesCaptured)
        framesRetained = try container.decode(Int.self, forKey: .framesRetained)
        capturedFrameTimestampsNanoseconds = try container.decodeIfPresent(
            [UInt64].self,
            forKey: .capturedFrameTimestampsNanoseconds
        ) ?? []
        callbackArrivalTimestampsNanoseconds = try container.decodeIfPresent(
            [UInt64].self,
            forKey: .callbackArrivalTimestampsNanoseconds
        ) ?? []
        retainedFrameTimestampsNanoseconds = try container.decode(
            [UInt64].self,
            forKey: .retainedFrameTimestampsNanoseconds
        )
        rawCapture = try container.decodeIfPresent(
            RawVideoCaptureMetrics.self,
            forKey: .rawCapture
        ) ?? .disabled
    }
}
