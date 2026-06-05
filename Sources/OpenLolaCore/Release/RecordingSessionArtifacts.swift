import Foundation

public typealias RecordingSessionRunMode = MeasurementMethodology

public enum RecordingDropPolicy: String, Codable, Equatable, Sendable {
    case dropAndMarkGap
    case blockProducer
    case growQueue
}

public enum RecordingArtifactKind: String, Codable, Equatable, Hashable, Sendable {
    case manifest
    case audioPcm
    case videoFrames
    case videoFrameIndex
    case gapLog
    case metricsReport
}

public enum RecordingMediaSwitch: String, Codable, Equatable, Sendable {
    case on
    case off
}

public enum RecordingMediaArtifactState: String, Codable, Equatable, Sendable {
    case off
    case recorded
    case unavailable
}

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

public struct RecordingVideoDropImpact: Equatable, Sendable {
    public var beforeRecording: Int
    public var duringRecording: Int

    public init(beforeRecording: Int, duringRecording: Int) {
        self.beforeRecording = beforeRecording
        self.duringRecording = duringRecording
    }
}

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

public struct RecordingSessionArtifactReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: RecordingSessionRunMode
    public var durationSeconds: Double
    public var session: RecordingSessionMetadata
    public var sideLane: RecordingSideLanePolicy
    public var capture: RecordingMediaCaptureSelection
    public var writerPressure: RecordingWriterPressureMetrics
    public var mediaImpact: RecordingMediaImpactMetrics
    public var audioArtifact: RecordingAudioArtifactMetrics
    public var videoArtifact: RecordingVideoArtifactMetrics
    public var manifest: RecordingArtifactManifest
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        metadata: RecordingSessionArtifactReportMetadata,
        evidence: RecordingSessionArtifactReportEvidence,
        verdict: MeasurementVerdict
    ) {
        self.id = metadata.id
        self.title = metadata.title
        self.capturedAt = metadata.capturedAt
        self.runMode = metadata.runMode
        self.durationSeconds = metadata.durationSeconds
        self.session = evidence.session
        self.sideLane = evidence.sideLane
        self.capture = evidence.capture
        self.writerPressure = evidence.writerPressure
        self.mediaImpact = evidence.mediaImpact
        self.audioArtifact = evidence.audioArtifact
        self.videoArtifact = evidence.videoArtifact
        self.manifest = evidence.manifest
        self.verdict = verdict
        self.notes = metadata.notes
    }

    public static func decode(from data: Data) throws -> RecordingSessionArtifactReport {
        try JSONDecoder().decode(RecordingSessionArtifactReport.self, from: data)
    }

    public func validate() throws {
        try validateIdentity()
        try validateSession()
        try validateSideLane()
        try validateCapture()
        try validateWriterPressure()
        try validateMediaImpact()
        try validateManifest()
        try validateMediaArtifacts()
        try VerdictValidationPolicy.validatePass(verdict) {
            try validatePassVerdict()
        }
    }

    private func validateIdentity() throws {
        try RecordingSessionArtifactValidator.requireNonEmpty(id, "id")
        try RecordingSessionArtifactValidator.requireNonEmpty(title, "title")
        try RecordingSessionArtifactValidator.requireNonEmpty(capturedAt, "capturedAt")
        try RecordingSessionArtifactValidator.requirePositive(durationSeconds, "durationSeconds")
        try RecordingSessionArtifactValidator.requireNonEmpty(notes, "notes")
    }

    private func validateSession() throws {
        try RecordingSessionArtifactValidator.requireNonEmpty(session.sessionId, "session.sessionId")
        try RecordingSessionArtifactValidator.requireNonEmpty(session.profileName, "session.profileName")
        try RecordingSessionArtifactValidator.requireNonEmpty(session.configuredBy, "session.configuredBy")
        try RecordingSessionArtifactValidator.requireNonEmpty(session.startedAt, "session.startedAt")
        try RecordingSessionArtifactValidator.requireNonEmpty(session.endedAt, "session.endedAt")
    }

    private func validateSideLane() throws {
        try RecordingSessionArtifactValidator.requirePositive(sideLane.boundedQueueCapacityChunks, "sideLane.boundedQueueCapacityChunks")
    }

    private func validateCapture() throws {
        if capture.audio.mode == .on {
            let channelCount = capture.audio.channelCount ?? 0
            try RecordingSessionArtifactValidator.requireNonEmpty(capture.audio.inputUID ?? "", "capture.audio.inputUID")
            try RecordingSessionArtifactValidator.requirePositive(capture.audio.sampleRateHertz ?? 0, "capture.audio.sampleRateHertz")
            try RecordingSessionArtifactValidator.requirePositive(capture.audio.framesPerBuffer ?? 0, "capture.audio.framesPerBuffer")
            try RecordingSessionArtifactValidator.requirePositive(channelCount, "capture.audio.channelCount")
            guard capture.audio.inputChannels.count == channelCount else {
                throw RecordingSessionArtifactValidationError.emptyList("capture.audio.inputChannels")
            }
        }
        if capture.video.mode == .on {
            try RecordingSessionArtifactValidator.requireNonEmpty(capture.video.deviceID ?? "", "capture.video.deviceID")
            try RecordingSessionArtifactValidator.requirePositive(Int(capture.video.streamID), "capture.video.streamID")
            try RecordingSessionArtifactValidator.requirePositive(capture.video.frameRate, "capture.video.frameRate")
            try RecordingSessionArtifactValidator.requirePositive(capture.video.queueDepth, "capture.video.queueDepth")
        }
    }

    private func validateWriterPressure() throws {
        try RecordingSessionArtifactValidator.requirePositive(writerPressure.producedChunkCount, "writerPressure.producedChunkCount")
        try RecordingSessionArtifactValidator.requireNonNegative(writerPressure.writtenChunkCount, "writerPressure.writtenChunkCount")
        try RecordingSessionArtifactValidator.requireNonNegative(writerPressure.droppedChunkCount, "writerPressure.droppedChunkCount")
        try RecordingSessionArtifactValidator.requireNonNegative(writerPressure.gapMarkerCount, "writerPressure.gapMarkerCount")
        try RecordingSessionArtifactValidator.requireNonNegative(writerPressure.maxQueuedChunks, "writerPressure.maxQueuedChunks")
        try RecordingSessionArtifactValidator.requireNonNegative(writerPressure.writerStallCount, "writerPressure.writerStallCount")
    }

    private func validateMediaImpact() throws {
        try RecordingSessionArtifactValidator.requireNonNegative(
            mediaImpact.baselineAudioCallbackP99Microseconds,
            "mediaImpact.baselineAudioCallbackP99Microseconds"
        )
        try RecordingSessionArtifactValidator.requireNonNegative(
            mediaImpact.recordingAudioCallbackP99Microseconds,
            "mediaImpact.recordingAudioCallbackP99Microseconds"
        )
        try RecordingSessionArtifactValidator.requireNonNegative(
            mediaImpact.baselineAudioCallbackMaxMicroseconds,
            "mediaImpact.baselineAudioCallbackMaxMicroseconds"
        )
        try RecordingSessionArtifactValidator.requireNonNegative(
            mediaImpact.recordingAudioCallbackMaxMicroseconds,
            "mediaImpact.recordingAudioCallbackMaxMicroseconds"
        )
        try RecordingSessionArtifactValidator.requirePositive(mediaImpact.baselinePlayoutTargetFrames, "mediaImpact.baselinePlayoutTargetFrames")
        try RecordingSessionArtifactValidator.requirePositive(mediaImpact.recordingPlayoutTargetFrames, "mediaImpact.recordingPlayoutTargetFrames")
        try RecordingSessionArtifactValidator.requireNonNegative(mediaImpact.audioUnderruns, "mediaImpact.audioUnderruns")
        try RecordingSessionArtifactValidator.requireNonNegative(
            mediaImpact.videoDroppedFramesBeforeRecording,
            "mediaImpact.videoDroppedFramesBeforeRecording"
        )
        try RecordingSessionArtifactValidator.requireNonNegative(
            mediaImpact.videoDroppedFramesDuringRecording,
            "mediaImpact.videoDroppedFramesDuringRecording"
        )

        guard mediaImpact.baselineAudioCallbackP99Microseconds
            <= mediaImpact.baselineAudioCallbackMaxMicroseconds
        else {
            throw RecordingSessionArtifactValidationError.unorderedAudioCallbackMetrics("baseline")
        }
        guard mediaImpact.recordingAudioCallbackP99Microseconds
            <= mediaImpact.recordingAudioCallbackMaxMicroseconds
        else {
            throw RecordingSessionArtifactValidationError.unorderedAudioCallbackMetrics("recording")
        }
    }

    private func validateManifest() throws {
        try RecordingSessionArtifactValidator.requireNonEmpty(manifest.rootDirectory, "manifest.rootDirectory")
        guard !manifest.entries.isEmpty else {
            throw RecordingSessionArtifactValidationError.emptyList("manifest.entries")
        }
        for entry in manifest.entries {
            try RecordingSessionArtifactValidator.requireNonEmpty(entry.relativePath, "manifest.entries.relativePath")
            try RecordingSessionArtifactValidator.requirePositive(entry.byteCount, "manifest.entries.byteCount")
            try RecordingSessionArtifactValidator.requireNonEmpty(entry.checksum, "manifest.entries.checksum")
        }
    }

    private func validateMediaArtifacts() throws {
        try validateAudioArtifact()
        try validateVideoArtifact()
    }

    private func validateAudioArtifact() throws {
        switch audioArtifact.state {
        case .off:
            try validateAudioArtifactOff()
        case .unavailable:
            try validateAudioArtifactUnavailable()
        case .recorded:
            try validateAudioArtifactRecorded()
        }
    }

    private func validateAudioArtifactOff() throws {
        guard capture.audio.mode == .off else {
            throw RecordingSessionArtifactValidationError.mediaOptInWithoutRecordedOrUnavailable(.audioPcm)
        }
        guard !manifest.entries.contains(where: { $0.kind == .audioPcm }) else {
            throw RecordingSessionArtifactValidationError.mediaOffWithArtifact(.audioPcm)
        }
    }

    private func validateAudioArtifactUnavailable() throws {
        guard capture.audio.mode == .on else {
            throw RecordingSessionArtifactValidationError.recordedMediaWithoutOptIn(.audioPcm)
        }
        guard !audioArtifact.blockers.isEmpty else {
            throw RecordingSessionArtifactValidationError.unavailableMediaWithoutBlocker(.audioPcm)
        }
        guard !manifest.entries.contains(where: { $0.kind == .audioPcm }) else {
            throw RecordingSessionArtifactValidationError.mediaOffWithArtifact(.audioPcm)
        }
    }

    private func validateAudioArtifactRecorded() throws {
        guard capture.audio.mode == .on else {
            throw RecordingSessionArtifactValidationError.recordedMediaWithoutOptIn(.audioPcm)
        }
        let path = audioArtifact.relativePath ?? ""
        let entry = try manifestEntry(kind: .audioPcm, path: path)
        guard entry.byteCount == audioArtifact.byteCount else {
            throw RecordingSessionArtifactValidationError.recordedMediaByteCountMismatch(.audioPcm)
        }
        guard entry.checksum == audioArtifact.checksum else {
            throw RecordingSessionArtifactValidationError.recordedMediaChecksumMismatch(.audioPcm)
        }
    }

    private func validateVideoArtifact() throws {
        switch videoArtifact.state {
        case .off:
            try validateVideoArtifactOff()
        case .unavailable:
            try validateVideoArtifactUnavailable()
        case .recorded:
            try validateVideoArtifactRecorded()
        }
    }

    private func validateVideoArtifactOff() throws {
        guard capture.video.mode == .off else {
            throw RecordingSessionArtifactValidationError.mediaOptInWithoutRecordedOrUnavailable(.videoFrames)
        }
        guard !hasVideoManifestEntry else {
            throw RecordingSessionArtifactValidationError.mediaOffWithArtifact(.videoFrames)
        }
    }

    private func validateVideoArtifactUnavailable() throws {
        guard capture.video.mode == .on else {
            throw RecordingSessionArtifactValidationError.recordedMediaWithoutOptIn(.videoFrames)
        }
        guard !videoArtifact.blockers.isEmpty else {
            throw RecordingSessionArtifactValidationError.unavailableMediaWithoutBlocker(.videoFrames)
        }
        guard !hasVideoManifestEntry else {
            throw RecordingSessionArtifactValidationError.mediaOffWithArtifact(.videoFrames)
        }
    }

    private func validateVideoArtifactRecorded() throws {
        guard capture.video.mode == .on else {
            throw RecordingSessionArtifactValidationError.recordedMediaWithoutOptIn(.videoFrames)
        }
        let rawEntry = try manifestEntry(kind: .videoFrames, path: videoArtifact.rawFramesRelativePath ?? "")
        let indexEntry = try manifestEntry(kind: .videoFrameIndex, path: videoArtifact.frameIndexRelativePath ?? "")
        guard rawEntry.byteCount == videoArtifact.rawByteCount,
              indexEntry.byteCount == videoArtifact.frameIndexByteCount else {
            throw RecordingSessionArtifactValidationError.recordedMediaByteCountMismatch(.videoFrames)
        }
        guard rawEntry.checksum == videoArtifact.rawChecksum,
              indexEntry.checksum == videoArtifact.frameIndexChecksum else {
            throw RecordingSessionArtifactValidationError.recordedMediaChecksumMismatch(.videoFrames)
        }
        try RecordingSessionArtifactValidator.requirePositive(videoArtifact.framesWritten, "videoArtifact.framesWritten")
    }

    private var hasVideoManifestEntry: Bool {
        let mediaKinds: Set<RecordingArtifactKind> = [.videoFrames, .videoFrameIndex]
        return manifest.entries.contains(where: { mediaKinds.contains($0.kind) })
    }

    private func manifestEntry(kind: RecordingArtifactKind, path: String) throws -> RecordingArtifactEntry {
        guard let entry = manifest.entries.first(where: { $0.kind == kind && $0.relativePath == path }) else {
            throw RecordingSessionArtifactValidationError.recordedMediaMissingManifestEntry(kind, path)
        }
        return entry
    }

    private func validatePassVerdict() throws {
        try validatePassRunMode()
        try validatePassSideLane()
        try validatePassWriterPressure()
        try validatePassAudioImpact()
        try validatePassMetadata()
    }

    private func validatePassRunMode() throws {
        guard runMode == .measured else {
            throw RecordingSessionArtifactValidationError.passWithoutMeasuredRun
        }
    }

    private func validatePassSideLane() throws {
        guard !sideLane.fileIOAllowedInRealtimeCallback else {
            throw RecordingSessionArtifactValidationError.passAllowsRealtimeFileIO
        }
        guard sideLane.queueFedByCopiedMedia else {
            throw RecordingSessionArtifactValidationError.passWithoutCopiedMediaSideLane
        }
        guard sideLane.writesAsynchronously else {
            throw RecordingSessionArtifactValidationError.passWithoutAsyncWriter
        }
        guard sideLane.dropPolicy == .dropAndMarkGap else {
            throw RecordingSessionArtifactValidationError.passWithoutDropOnPressure
        }
    }

    private func validatePassWriterPressure() throws {
        guard writerPressure.simulatedSlowWriter else {
            throw RecordingSessionArtifactValidationError.passWithoutSlowWriterPressure
        }
        guard writerPressure.droppedChunkCount > 0, writerPressure.gapMarkerCount >= writerPressure.droppedChunkCount else {
            throw RecordingSessionArtifactValidationError.passWithoutRecordingDropOrGap
        }
    }

    private func validatePassAudioImpact() throws {
        guard mediaImpact.recordingAudioCallbackP99Microseconds
            <= mediaImpact.baselineAudioCallbackP99Microseconds
        else {
            throw RecordingSessionArtifactValidationError.passIncreasesAudioP99(
                baseline: mediaImpact.baselineAudioCallbackP99Microseconds,
                recording: mediaImpact.recordingAudioCallbackP99Microseconds
            )
        }
        guard mediaImpact.recordingAudioCallbackMaxMicroseconds
            <= mediaImpact.baselineAudioCallbackMaxMicroseconds
        else {
            throw RecordingSessionArtifactValidationError.passIncreasesAudioMax(
                baseline: mediaImpact.baselineAudioCallbackMaxMicroseconds,
                recording: mediaImpact.recordingAudioCallbackMaxMicroseconds
            )
        }
        guard mediaImpact.recordingPlayoutTargetFrames == mediaImpact.baselinePlayoutTargetFrames else {
            throw RecordingSessionArtifactValidationError.passChangesAudioPlayoutTarget(
                baseline: mediaImpact.baselinePlayoutTargetFrames,
                recording: mediaImpact.recordingPlayoutTargetFrames
            )
        }
        guard mediaImpact.audioUnderruns == 0 else {
            throw RecordingSessionArtifactValidationError.passWithAudioUnderruns(mediaImpact.audioUnderruns)
        }
        guard !mediaImpact.hiddenPlayoutGrowthDetected else {
            throw RecordingSessionArtifactValidationError.passWithHiddenPlayoutGrowth
        }
    }

    private func validatePassMetadata() throws {
        guard manifest.includesConfigurationMetadata else {
            throw RecordingSessionArtifactValidationError.passWithoutConfigurationMetadata
        }
        guard manifest.includesVerdictMetadata else {
            throw RecordingSessionArtifactValidationError.passWithoutVerdictMetadata
        }
    }
}
