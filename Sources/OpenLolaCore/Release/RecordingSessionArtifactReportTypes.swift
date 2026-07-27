// Collects release-readiness evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Captures structured result required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingSessionMetadata: Codable, Equatable, Sendable {
    public var sessionId: String
    public var profileName: String
    public var configuredBy: String
    public var startedAt: String
    public var endedAt: String

    public init(
        sessionId: String,
        profileName: String,
        configuredBy: String,
        startedAt: String,
        endedAt: String
    ) {
        self.sessionId = sessionId
        self.profileName = profileName
        self.configuredBy = configuredBy
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

/// Captures acceptance policy required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingSideLanePolicy: Codable, Equatable, Sendable {
    public var fileIOAllowedInRealtimeCallback: Bool
    public var queueFedByCopiedMedia: Bool
    public var writesAsynchronously: Bool
    public var boundedQueueCapacityChunks: Int
    public var dropPolicy: RecordingDropPolicy

    public init(
        fileIOAllowedInRealtimeCallback: Bool,
        queueFedByCopiedMedia: Bool,
        writesAsynchronously: Bool,
        boundedQueueCapacityChunks: Int,
        dropPolicy: RecordingDropPolicy
    ) {
        self.fileIOAllowedInRealtimeCallback = fileIOAllowedInRealtimeCallback
        self.queueFedByCopiedMedia = queueFedByCopiedMedia
        self.writesAsynchronously = writesAsynchronously
        self.boundedQueueCapacityChunks = boundedQueueCapacityChunks
        self.dropPolicy = dropPolicy
    }
}

/// Captures measured metrics required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingWriterPressureMetrics: Codable, Equatable, Sendable {
    public var simulatedSlowWriter: Bool
    public var producedChunkCount: Int
    public var writtenChunkCount: Int
    public var droppedChunkCount: Int
    public var gapMarkerCount: Int
    public var maxQueuedChunks: Int
    public var writerStallCount: Int

    public init(
        simulatedSlowWriter: Bool,
        producedChunkCount: Int,
        writtenChunkCount: Int,
        droppedChunkCount: Int,
        gapMarkerCount: Int,
        maxQueuedChunks: Int,
        writerStallCount: Int
    ) {
        self.simulatedSlowWriter = simulatedSlowWriter
        self.producedChunkCount = producedChunkCount
        self.writtenChunkCount = writtenChunkCount
        self.droppedChunkCount = droppedChunkCount
        self.gapMarkerCount = gapMarkerCount
        self.maxQueuedChunks = maxQueuedChunks
        self.writerStallCount = writerStallCount
    }
}

/// Captures runtime-impact measurement required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingAudioCallbackImpact: Equatable, Sendable {
    public var baselineP99Microseconds: Double
    public var recordingP99Microseconds: Double
    public var baselineMaxMicroseconds: Double
    public var recordingMaxMicroseconds: Double
    public var underruns: Int

    public init(
        baselineP99Microseconds: Double,
        recordingP99Microseconds: Double,
        baselineMaxMicroseconds: Double,
        recordingMaxMicroseconds: Double,
        underruns: Int
    ) {
        self.baselineP99Microseconds = baselineP99Microseconds
        self.recordingP99Microseconds = recordingP99Microseconds
        self.baselineMaxMicroseconds = baselineMaxMicroseconds
        self.recordingMaxMicroseconds = recordingMaxMicroseconds
        self.underruns = underruns
    }
}

/// Captures runtime-impact measurement required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingPlayoutImpact: Equatable, Sendable {
    public var baselineTargetFrames: Int
    public var recordingTargetFrames: Int
    public var hiddenGrowthDetected: Bool

    public init(
        baselineTargetFrames: Int,
        recordingTargetFrames: Int,
        hiddenGrowthDetected: Bool
    ) {
        self.baselineTargetFrames = baselineTargetFrames
        self.recordingTargetFrames = recordingTargetFrames
        self.hiddenGrowthDetected = hiddenGrowthDetected
    }
}

/// Captures runtime-impact measurement required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingVideoDropImpact: Equatable, Sendable {
    public var beforeRecording: Int
    public var duringRecording: Int

    public init(beforeRecording: Int, duringRecording: Int) {
        self.beforeRecording = beforeRecording
        self.duringRecording = duringRecording
    }
}

/// Captures measured metrics required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingMediaImpactMetrics: Codable, Equatable, Sendable {
    public var baselineAudioCallbackP99Microseconds: Double
    public var recordingAudioCallbackP99Microseconds: Double
    public var baselineAudioCallbackMaxMicroseconds: Double
    public var recordingAudioCallbackMaxMicroseconds: Double
    public var baselinePlayoutTargetFrames: Int
    public var recordingPlayoutTargetFrames: Int
    public var audioUnderruns: Int
    public var videoDroppedFramesBeforeRecording: Int
    public var videoDroppedFramesDuringRecording: Int
    public var hiddenPlayoutGrowthDetected: Bool

    public init(
        audio: RecordingAudioCallbackImpact,
        playout: RecordingPlayoutImpact,
        videoDrops: RecordingVideoDropImpact
    ) {
        self.baselineAudioCallbackP99Microseconds = audio.baselineP99Microseconds
        self.recordingAudioCallbackP99Microseconds = audio.recordingP99Microseconds
        self.baselineAudioCallbackMaxMicroseconds = audio.baselineMaxMicroseconds
        self.recordingAudioCallbackMaxMicroseconds = audio.recordingMaxMicroseconds
        self.baselinePlayoutTargetFrames = playout.baselineTargetFrames
        self.recordingPlayoutTargetFrames = playout.recordingTargetFrames
        self.audioUnderruns = audio.underruns
        self.videoDroppedFramesBeforeRecording = videoDrops.beforeRecording
        self.videoDroppedFramesDuringRecording = videoDrops.duringRecording
        self.hiddenPlayoutGrowthDetected = playout.hiddenGrowthDetected
    }
}

/// Captures artifact metadata required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingArtifactEntry: Codable, Equatable, Sendable {
    public var kind: RecordingArtifactKind
    public var relativePath: String
    public var byteCount: Int
    public var checksum: String

    public init(kind: RecordingArtifactKind, relativePath: String, byteCount: Int, checksum: String) {
        self.kind = kind
        self.relativePath = relativePath
        self.byteCount = byteCount
        self.checksum = checksum
    }
}

/// Captures artifact metadata required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingArtifactManifest: Codable, Equatable, Sendable {
    public var rootDirectory: String
    public var includesConfigurationMetadata: Bool
    public var includesVerdictMetadata: Bool
    public var entries: [RecordingArtifactEntry]

    public init(
        rootDirectory: String,
        includesConfigurationMetadata: Bool,
        includesVerdictMetadata: Bool,
        entries: [RecordingArtifactEntry]
    ) {
        self.rootDirectory = rootDirectory
        self.includesConfigurationMetadata = includesConfigurationMetadata
        self.includesVerdictMetadata = includesVerdictMetadata
        self.entries = entries
    }
}

/// Captures report contents required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingSessionArtifactReportMetadata: Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: RecordingSessionRunMode
    public var durationSeconds: Double
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: RecordingSessionRunMode,
        durationSeconds: Double,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.durationSeconds = durationSeconds
        self.notes = notes
    }
}

/// Captures evidence provenance required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingSessionArtifactReportEvidence: Equatable, Sendable {
    public var session: RecordingSessionMetadata
    public var sideLane: RecordingSideLanePolicy
    public var capture: RecordingMediaCaptureSelection
    public var writerPressure: RecordingWriterPressureMetrics
    public var mediaImpact: RecordingMediaImpactMetrics
    public var audioArtifact: RecordingAudioArtifactMetrics
    public var videoArtifact: RecordingVideoArtifactMetrics
    public var manifest: RecordingArtifactManifest

    public init(
        session: RecordingSessionMetadata,
        sideLane: RecordingSideLanePolicy,
        capture: RecordingMediaCaptureSelection = .off,
        writerPressure: RecordingWriterPressureMetrics,
        mediaImpact: RecordingMediaImpactMetrics,
        audioArtifact: RecordingAudioArtifactMetrics = .off,
        videoArtifact: RecordingVideoArtifactMetrics = .off,
        manifest: RecordingArtifactManifest
    ) {
        self.session = session
        self.sideLane = sideLane
        self.capture = capture
        self.writerPressure = writerPressure
        self.mediaImpact = mediaImpact
        self.audioArtifact = audioArtifact
        self.videoArtifact = videoArtifact
        self.manifest = manifest
    }
}
