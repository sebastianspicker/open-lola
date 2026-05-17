import Foundation
#if canImport(Darwin)
import Darwin
#endif

#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
#endif

public enum VideoSourceKind: String, Codable, Equatable, Sendable {
    case testPattern
    case avFoundation
    case filePattern
}

public enum VideoQueuePolicy: String, Codable, Equatable, Sendable {
    case latestFrame
}

public protocol CameraSource: Sendable {
    func nextFrame() -> CapturedVideoFrame?
}

public enum VideoTimestampBasis: String, Codable, Equatable, Sendable {
    case syntheticMonotonicNanoseconds
    case hostUptimeNanoseconds
    case avFoundationPresentationTimeNanoseconds
}

public struct VideoCaptureStreamMetadata: Codable, Equatable, Sendable {
    public var streamID: UInt32
    public var sourceRole: VideoStreamRole
    public var timestampBasis: VideoTimestampBasis

    public init(
        streamID: UInt32,
        sourceRole: VideoStreamRole,
        timestampBasis: VideoTimestampBasis
    ) {
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

    public init(
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

    public init(
        sequenceNumber: UInt64,
        timestampNanoseconds: UInt64,
        width: Int,
        height: Int,
        pixelFormat: String,
        fingerprint: String
    ) {
        self.init(
            streamID: VideoCaptureStreamMetadata.syntheticTestPattern.streamID,
            sequenceNumber: sequenceNumber,
            timestampNanoseconds: timestampNanoseconds,
            timestampBasis: .syntheticMonotonicNanoseconds,
            sourceRole: .testPattern,
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            frameRate: VideoFrameRate(numerator: 30, denominator: 1),
            fingerprint: fingerprint
        )
    }
}

public struct RawCapturedVideoFrame: Equatable, Sendable {
    public var metadata: CapturedVideoFrame
    public var payload: Data

    public init(metadata: CapturedVideoFrame, payload: Data) {
        self.metadata = metadata
        self.payload = payload
    }
}

public enum RawVideoCaptureMode: String, Codable, Equatable, Sendable {
    case disabled
    case requested
}

public struct RawVideoCaptureMetrics: Codable, Equatable, Sendable {
    public var mode: RawVideoCaptureMode
    public var extractionAttempts: Int
    public var extractionFailures: Int
    public var payloadsCaptured: Int
    public var artifactFramesRetained: Int
    public var lastExtractionError: String?

    public init(
        mode: RawVideoCaptureMode,
        extractionAttempts: Int,
        extractionFailures: Int,
        payloadsCaptured: Int,
        artifactFramesRetained: Int,
        lastExtractionError: String? = nil
    ) {
        self.mode = mode
        self.extractionAttempts = extractionAttempts
        self.extractionFailures = extractionFailures
        self.payloadsCaptured = payloadsCaptured
        self.artifactFramesRetained = artifactFramesRetained
        self.lastExtractionError = lastExtractionError
    }

    public static let disabled = RawVideoCaptureMetrics(
        mode: .disabled,
        extractionAttempts: 0,
        extractionFailures: 0,
        payloadsCaptured: 0,
        artifactFramesRetained: 0
    )
}

public final class TestPatternCameraSource: CameraSource, @unchecked Sendable {
    public var width: Int
    public var height: Int
    public var frameIntervalNanoseconds: UInt64
    public var streamID: UInt32
    public var sourceRole: VideoStreamRole
    public var frameRate: VideoFrameRate
    public var pixelFormat: String
    public private(set) var nextSequenceNumber: UInt64

    public init(
        width: Int,
        height: Int,
        frameIntervalNanoseconds: UInt64,
        streamID: UInt32 = VideoCaptureStreamMetadata.syntheticTestPattern.streamID,
        sourceRole: VideoStreamRole = .testPattern,
        frameRate: VideoFrameRate = VideoFrameRate(numerator: 30, denominator: 1),
        pixelFormat: String = "synthetic-rgb"
    ) {
        self.width = width
        self.height = height
        self.frameIntervalNanoseconds = frameIntervalNanoseconds
        self.streamID = streamID
        self.sourceRole = sourceRole
        self.frameRate = frameRate
        self.pixelFormat = pixelFormat
        nextSequenceNumber = 0
    }

    public func nextFrame() -> CapturedVideoFrame? {
        guard width > 0, height > 0, frameIntervalNanoseconds > 0 else {
            return nil
        }

        let sequenceNumber = nextSequenceNumber
        nextSequenceNumber += 1

        return CapturedVideoFrame(
            streamID: streamID,
            sequenceNumber: sequenceNumber,
            timestampNanoseconds: sequenceNumber * frameIntervalNanoseconds,
            timestampBasis: .syntheticMonotonicNanoseconds,
            sourceRole: sourceRole,
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            frameRate: frameRate,
            fingerprint: "test-pattern-\(sequenceNumber)-\(width)x\(height)"
        )
    }
}

public struct LatestFrameQueue: Equatable, Sendable {
    public var maxDepth: Int
    public private(set) var frames: [CapturedVideoFrame]
    public private(set) var droppedFrames: Int
    public private(set) var observedMaxDepth: Int
    public private(set) var preallocatedFrameSlots: Int

    public init(maxDepth: Int) {
        self.maxDepth = maxDepth
        frames = []
        frames.reserveCapacity(max(0, maxDepth))
        droppedFrames = 0
        observedMaxDepth = 0
        preallocatedFrameSlots = max(0, maxDepth)
    }

    public mutating func enqueue(_ frame: CapturedVideoFrame) {
        guard maxDepth > 0 else {
            droppedFrames += 1
            frames.removeAll()
            observedMaxDepth = 0
            return
        }

        frames.append(frame)
        if frames.count > maxDepth {
            let dropCount = frames.count - maxDepth
            frames.removeFirst(dropCount)
            droppedFrames += dropCount
        }
        observedMaxDepth = max(observedMaxDepth, frames.count)
    }
}

public struct VideoSourceDescription: Codable, Equatable, Sendable {
    public var kind: VideoSourceKind
    public var label: String
    public var deviceUniqueId: String?
    public var permissionStatus: String

    public init(
        kind: VideoSourceKind,
        label: String,
        deviceUniqueId: String?,
        permissionStatus: String
    ) {
        self.kind = kind
        self.label = label
        self.deviceUniqueId = deviceUniqueId
        self.permissionStatus = permissionStatus
    }
}

public struct VideoCaptureFormat: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var nominalFrameRate: Double
    public var pixelFormat: String

    public init(width: Int, height: Int, nominalFrameRate: Double, pixelFormat: String) {
        self.width = width
        self.height = height
        self.nominalFrameRate = nominalFrameRate
        self.pixelFormat = pixelFormat
    }
}

public struct VideoQueueMetrics: Codable, Equatable, Sendable {
    public var policy: VideoQueuePolicy
    public var maxDepth: Int
    public var observedMaxDepth: Int
    public var droppedFrames: Int

    public init(policy: VideoQueuePolicy, maxDepth: Int, observedMaxDepth: Int, droppedFrames: Int) {
        self.policy = policy
        self.maxDepth = maxDepth
        self.observedMaxDepth = observedMaxDepth
        self.droppedFrames = droppedFrames
    }
}

public struct VideoAudioImpactMetrics: Codable, Equatable, Sendable {
    public var baselineCallbackP99Microseconds: Double
    public var videoCallbackP99Microseconds: Double
    public var baselineCallbackMaxMicroseconds: Double
    public var videoCallbackMaxMicroseconds: Double
    public var baselinePlayoutTargetFrames: Int
    public var videoPlayoutTargetFrames: Int
    public var underruns: Int
    public var hiddenAudioImpactDetected: Bool

    public init(
        baselineCallbackP99Microseconds: Double,
        videoCallbackP99Microseconds: Double,
        baselineCallbackMaxMicroseconds: Double,
        videoCallbackMaxMicroseconds: Double,
        baselinePlayoutTargetFrames: Int,
        videoPlayoutTargetFrames: Int,
        underruns: Int,
        hiddenAudioImpactDetected: Bool
    ) {
        self.baselineCallbackP99Microseconds = baselineCallbackP99Microseconds
        self.videoCallbackP99Microseconds = videoCallbackP99Microseconds
        self.baselineCallbackMaxMicroseconds = baselineCallbackMaxMicroseconds
        self.videoCallbackMaxMicroseconds = videoCallbackMaxMicroseconds
        self.baselinePlayoutTargetFrames = baselinePlayoutTargetFrames
        self.videoPlayoutTargetFrames = videoPlayoutTargetFrames
        self.underruns = underruns
        self.hiddenAudioImpactDetected = hiddenAudioImpactDetected
    }
}

public struct VideoProcessCpuMetrics: Codable, Equatable, Sendable {
    public var userSeconds: Double
    public var systemSeconds: Double

    public init(userSeconds: Double, systemSeconds: Double) {
        self.userSeconds = userSeconds
        self.systemSeconds = systemSeconds
    }
}

public struct VideoProcessMemoryMetrics: Codable, Equatable, Sendable {
    public var residentPeakBytes: UInt64

    public init(residentPeakBytes: UInt64) {
        self.residentPeakBytes = residentPeakBytes
    }
}
