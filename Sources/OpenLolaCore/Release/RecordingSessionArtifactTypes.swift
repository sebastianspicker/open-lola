// Collects release-readiness evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Identifies the measurement methodology recorded with recording-session artifact artifacts so consumers distinguish measured, synthetic, and sandbox-limited results.
public typealias RecordingSessionRunMode = MeasurementMethodology

/// Defines the finite acceptance policy values recorded by recording-session artifact artifacts for deterministic validation and report interpretation.
public enum RecordingDropPolicy: String, Codable, Equatable, Sendable {
    case dropAndMarkGap
    case blockProducer
    case growQueue
}

/// Defines the finite classification values recorded by recording-session artifact artifacts for deterministic validation and report interpretation.
public enum RecordingArtifactKind: String, Codable, Equatable, Hashable, Sendable {
    case manifest
    case audioPcm
    case videoFrames
    case videoFrameIndex
    case gapLog
    case metricsReport
}

/// Defines the finite structured result values recorded by recording-session artifact artifacts for deterministic validation and report interpretation.
public enum RecordingMediaSwitch: String, Codable, Equatable, Sendable {
// swiftlint:disable:next identifier_name
 case on
    case off
}

/// Defines the finite artifact metadata values recorded by recording-session artifact artifacts for deterministic validation and report interpretation.
public enum RecordingMediaArtifactState: String, Codable, Equatable, Sendable {
    case off
    case recorded
    case unavailable
}

/// Defines the finite structured result values recorded by recording-session artifact artifacts for deterministic validation and report interpretation.
public enum RecordingAudioSampleFormat: String, Codable, Equatable, Sendable {
    case int16LittleEndian = "int16-le"
    case float32LittleEndian = "float32-le"

    public var bytesPerSample: Int {
        switch self {
        case .int16LittleEndian:
            2
        case .float32LittleEndian:
            4
        }
    }
}

/// Captures media-capture state required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingAudioCaptureSelection: Codable, Equatable, Sendable {
    public var mode: RecordingMediaSwitch
    public var inputUID: String?
    public var sampleRateHertz: Int?
    public var framesPerBuffer: Int?
    public var channelCount: Int?
    public var inputChannels: [Int]
    public var sampleFormat: RecordingAudioSampleFormat

    public init(
        mode: RecordingMediaSwitch,
        inputUID: String? = nil,
        sampleRateHertz: Int? = nil,
        framesPerBuffer: Int? = nil,
        channelCount: Int? = nil,
        inputChannels: [Int] = [],
        sampleFormat: RecordingAudioSampleFormat = .int16LittleEndian
    ) {
        self.mode = mode
        self.inputUID = inputUID
        self.sampleRateHertz = sampleRateHertz
        self.framesPerBuffer = framesPerBuffer
        self.channelCount = channelCount
        self.inputChannels = inputChannels
        self.sampleFormat = sampleFormat
    }

    public static let off = RecordingAudioCaptureSelection(mode: .off)
}

/// Captures media-capture state required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingVideoCaptureSelection: Codable, Equatable, Sendable {
    public var mode: RecordingMediaSwitch
    public var deviceID: String?
    public var streamID: UInt32
    public var frameRate: Double
    public var queueDepth: Int

    public init(
        mode: RecordingMediaSwitch,
        deviceID: String? = nil,
        streamID: UInt32 = 100,
        frameRate: Double = 30,
        queueDepth: Int = 1
    ) {
        self.mode = mode
        self.deviceID = deviceID
        self.streamID = streamID
        self.frameRate = frameRate
        self.queueDepth = queueDepth
    }

    public static let off = RecordingVideoCaptureSelection(mode: .off)
}

/// Captures media-capture state required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingMediaCaptureSelection: Codable, Equatable, Sendable {
    public var audio: RecordingAudioCaptureSelection
    public var video: RecordingVideoCaptureSelection

    public init(
        audio: RecordingAudioCaptureSelection = .off,
        video: RecordingVideoCaptureSelection = .off
    ) {
        self.audio = audio
        self.video = video
    }

    public static let off = RecordingMediaCaptureSelection()
}

/// Captures measured metrics required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingAudioArtifactMetrics: Codable, Equatable, Sendable {
    public var state: RecordingMediaArtifactState
    public var relativePath: String?
    public var byteCount: Int
    public var checksum: String?
    public var blockers: [String]

    public init(
        state: RecordingMediaArtifactState,
        relativePath: String? = nil,
        byteCount: Int = 0,
        checksum: String? = nil,
        blockers: [String] = []
    ) {
        self.state = state
        self.relativePath = relativePath
        self.byteCount = byteCount
        self.checksum = checksum
        self.blockers = blockers
    }

    public static let off = RecordingAudioArtifactMetrics(state: .off)
}

/// Captures artifact metadata required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingVideoArtifactFiles: Equatable, Sendable {
    public var rawFramesRelativePath: String?
    public var frameIndexRelativePath: String?
    public var rawByteCount: Int
    public var frameIndexByteCount: Int
    public var rawChecksum: String?
    public var frameIndexChecksum: String?
    public var framesWritten: Int

    public init(
        rawFramesRelativePath: String? = nil,
        frameIndexRelativePath: String? = nil,
        rawByteCount: Int = 0,
        frameIndexByteCount: Int = 0,
        rawChecksum: String? = nil,
        frameIndexChecksum: String? = nil,
        framesWritten: Int = 0
    ) {
        self.rawFramesRelativePath = rawFramesRelativePath
        self.frameIndexRelativePath = frameIndexRelativePath
        self.rawByteCount = rawByteCount
        self.frameIndexByteCount = frameIndexByteCount
        self.rawChecksum = rawChecksum
        self.frameIndexChecksum = frameIndexChecksum
        self.framesWritten = framesWritten
    }

    public static let empty = RecordingVideoArtifactFiles()
}

/// Captures measured metrics required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingVideoArtifactMetrics: Codable, Equatable, Sendable {
    public var state: RecordingMediaArtifactState
    public var rawFramesRelativePath: String?
    public var frameIndexRelativePath: String?
    public var rawByteCount: Int
    public var frameIndexByteCount: Int
    public var rawChecksum: String?
    public var frameIndexChecksum: String?
    public var framesWritten: Int
    public var blockers: [String]

    public init(
        state: RecordingMediaArtifactState,
        files: RecordingVideoArtifactFiles = .empty,
        blockers: [String] = []
    ) {
        self.state = state
        self.rawFramesRelativePath = files.rawFramesRelativePath
        self.frameIndexRelativePath = files.frameIndexRelativePath
        self.rawByteCount = files.rawByteCount
        self.frameIndexByteCount = files.frameIndexByteCount
        self.rawChecksum = files.rawChecksum
        self.frameIndexChecksum = files.frameIndexChecksum
        self.framesWritten = files.framesWritten
        self.blockers = blockers
    }

    public static let off = RecordingVideoArtifactMetrics(state: .off)
}

/// Captures inventory entry required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingVideoFrameIndexEntry: Codable, Equatable, Sendable {
    public var sequenceNumber: UInt64
    public var timestampNanoseconds: UInt64
    public var byteOffset: Int
    public var byteCount: Int
    public var width: Int
    public var height: Int
    public var pixelFormat: String

    public init(
        sequenceNumber: UInt64,
        timestampNanoseconds: UInt64,
        byteOffset: Int,
        byteCount: Int,
        width: Int,
        height: Int,
        pixelFormat: String
    ) {
        self.sequenceNumber = sequenceNumber
        self.timestampNanoseconds = timestampNanoseconds
        self.byteOffset = byteOffset
        self.byteCount = byteCount
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
    }
}
