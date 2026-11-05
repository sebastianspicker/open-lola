import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Collects release-readiness evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Captures media-capture state required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingCapturedAudio: Equatable, Sendable {
    public var data: Data
    public var callbackP99Microseconds: Double?
    public var callbackMaxMicroseconds: Double?
    public var underruns: Int
    /// Callbacks whose buffer held a different frame count than requested.
    public var frameCountMismatches: Int

    public init(
        data: Data,
        callbackP99Microseconds: Double? = nil,
        callbackMaxMicroseconds: Double? = nil,
        underruns: Int = 0,
        frameCountMismatches: Int = 0
    ) {
        self.data = data
        self.callbackP99Microseconds = callbackP99Microseconds
        self.callbackMaxMicroseconds = callbackMaxMicroseconds
        self.underruns = underruns
        self.frameCountMismatches = frameCountMismatches
    }
}

/// Captures media-capture state required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingCapturedVideo: Equatable, Sendable {
    public var rawFrameData: Data
    public var frameIndex: [RecordingVideoFrameIndexEntry]
    /// Frames captured before older ones were dropped; nil when unknown.
    public var framesCaptured: Int?

    public init(rawFrameData: Data, frameIndex: [RecordingVideoFrameIndexEntry], framesCaptured: Int? = nil) {
        self.rawFrameData = rawFrameData
        self.frameIndex = frameIndex
        self.framesCaptured = framesCaptured
    }
}

extension RecordingCapturedVideo {
    /// A plain note when older frames were dropped, so the take is not reported as complete.
    var truncationNote: String? {
        guard let framesCaptured, framesCaptured > frameIndex.count else {
            return nil
        }
        return "partial video: kept only the last \(frameIndex.count) of \(framesCaptured) video frames"
    }
}

/// Captures media-capture state required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingCapturedMedia: Equatable, Sendable {
    public var audio: RecordingCapturedAudio?
    public var audioBlockers: [String]
    public var video: RecordingCapturedVideo?
    public var videoBlockers: [String]
    public var startedAt: Date?
    public var endedAt: Date?
    /// The signal that ended capture before the requested duration; nil when it ran to the end.
    public var stopSignalName: String?

    public init(
        audio: RecordingCapturedAudio? = nil,
        audioBlockers: [String] = [],
        video: RecordingCapturedVideo? = nil,
        videoBlockers: [String] = [],
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        stopSignalName: String? = nil
    ) {
        self.audio = audio
        self.audioBlockers = audioBlockers
        self.video = video
        self.videoBlockers = videoBlockers
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.stopSignalName = stopSignalName
    }

    var stoppedEarlyNote: String? {
        stopSignalName.map { "capture stopped early by \($0); the take is incomplete" }
    }
}

struct RecordingWrittenMediaArtifacts: Equatable, Sendable {
    var manifest: RecordingArtifactManifest
    var audio: RecordingAudioArtifactMetrics
    var video: RecordingVideoArtifactMetrics
    var writerPressure: RecordingWriterPressureMetrics
}

enum RecordingMediaArtifactWriter {
    static func write(
        outputDirectory: String,
        durationSeconds: Int,
        capture: RecordingMediaCaptureSelection,
        capturedMedia: RecordingCapturedMedia
    ) throws -> RecordingWrittenMediaArtifacts {
        var artifacts = baselineArtifacts(
            durationSeconds: durationSeconds,
            capture: capture,
            capturedMedia: capturedMedia
        )
        if capture.audio.mode == .on, let audio = capturedMedia.audio {
            artifacts.append(RecordingSessionArtifactPayload(
                kind: .audioPcm,
                relativePath: "audio/input.pcm",
                data: audio.data
            ))
        }
        if capture.video.mode == .on, let video = capturedMedia.video {
            artifacts.append(RecordingSessionArtifactPayload(
                kind: .videoFrames,
                relativePath: "video/frames.raw",
                data: video.rawFrameData
            ))
            artifacts.append(RecordingSessionArtifactPayload(
                kind: .videoFrameIndex,
                relativePath: "video/frames.index.jsonl",
                data: try frameIndexJSONL(video.frameIndex)
            ))
        }

        let writeResult = try writeRecordingSessionArtifacts(
            outputDirectory: outputDirectory,
            artifacts: artifacts
        )
        let manifest = writeResult.manifest
        return RecordingWrittenMediaArtifacts(
            manifest: manifest,
            audio: audioMetrics(capture: capture.audio, capturedMedia: capturedMedia, manifest: manifest),
            video: videoMetrics(capture: capture.video, capturedMedia: capturedMedia, manifest: manifest),
            writerPressure: writeResult.writerPressure
        )
    }

    private static func baselineArtifacts(
        durationSeconds: Int,
        capture: RecordingMediaCaptureSelection,
        capturedMedia: RecordingCapturedMedia
    ) -> [RecordingSessionArtifactPayload] {
        [
            RecordingSessionArtifactPayload(
                kind: .manifest,
                relativePath: "manifest.json",
data: Data((
"{\"schema\":\"open-lola-recording-session-artifacts\","
+ "\"audio\":\"\(capture.audio.mode.rawValue)\","
+ "\"video\":\"\(capture.video.mode.rawValue)\"}"
).utf8)
            ),
            RecordingSessionArtifactPayload(
                kind: .gapLog,
                relativePath: "logs/gaps.jsonl",
                data: Data("{\"source\":\"writerPressure\",\"recordedInReport\":true}\n".utf8)
            ),
            RecordingSessionArtifactPayload(
                kind: .metricsReport,
                relativePath: "reports/metrics.json",
data: Data((
"{\"durationSeconds\":\(durationSeconds),"
+ "\"audioBlockers\":\(capturedMedia.audioBlockers.count),"
+ "\"videoBlockers\":\(capturedMedia.videoBlockers.count)}"
).utf8)
            )
        ]
    }

    private static func frameIndexJSONL(_ frames: [RecordingVideoFrameIndexEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let lines = try frames.map { frame in
            try frameIndexJSONLine(frame, encoder: encoder)
        }
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    private static func frameIndexJSONLine(
        _ frame: RecordingVideoFrameIndexEntry,
        encoder: JSONEncoder
    ) throws -> String {
        let data = try encoder.encode(frame)
        guard let line = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                frame,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Encoded video frame index was not valid UTF-8"
                )
            )
        }
        return line
    }

    private static func audioMetrics(
        capture: RecordingAudioCaptureSelection,
        capturedMedia: RecordingCapturedMedia,
        manifest: RecordingArtifactManifest
    ) -> RecordingAudioArtifactMetrics {
        guard capture.mode == .on else {
            return .off
        }
        guard let audio = capturedMedia.audio else {
            return RecordingAudioArtifactMetrics(
                state: .unavailable,
                blockers: capturedMedia.audioBlockers.isEmpty
                    ? ["audio capture returned no raw input data"]
                    : capturedMedia.audioBlockers
            )
        }
        guard let entry = manifest.entries.first(where: { $0.kind == .audioPcm }) else {
            return RecordingAudioArtifactMetrics(state: .unavailable, blockers: ["audio artifact write failed"])
        }
        let incomplete = [
            audio.underruns > 0 ? "\(audio.underruns) audio callbacks were dropped because the take buffer was full" : nil,
            capturedMedia.stoppedEarlyNote
        ].compactMap { $0 }
        let mismatch = audio.frameCountMismatches > 0
            ? ["\(audio.frameCountMismatches) audio callbacks delivered a different number of frames than requested"]
            : []
        return RecordingAudioArtifactMetrics(
            state: incomplete.isEmpty ? .recorded : .partial,
            relativePath: entry.relativePath,
            byteCount: entry.byteCount,
            checksum: entry.checksum,
            blockers: mismatch + incomplete
        )
    }

    private static func videoMetrics(
        capture: RecordingVideoCaptureSelection,
        capturedMedia: RecordingCapturedMedia,
        manifest: RecordingArtifactManifest
    ) -> RecordingVideoArtifactMetrics {
        guard capture.mode == .on else {
            return .off
        }
        guard let video = capturedMedia.video else {
            return RecordingVideoArtifactMetrics(
                state: .unavailable,
                blockers: capturedMedia.videoBlockers.isEmpty
                    ? ["video capture returned no raw frame data"]
                    : capturedMedia.videoBlockers
            )
        }
        guard let raw = manifest.entries.first(where: { $0.kind == .videoFrames }),
              let index = manifest.entries.first(where: { $0.kind == .videoFrameIndex }) else {
            return RecordingVideoArtifactMetrics(state: .unavailable, blockers: ["video artifact write failed"])
        }
        let incomplete = [video.truncationNote, capturedMedia.stoppedEarlyNote].compactMap { $0 }
        return RecordingVideoArtifactMetrics(
            state: incomplete.isEmpty ? .recorded : .partial,
            files: RecordingVideoArtifactFiles(
                rawFramesRelativePath: raw.relativePath,
                frameIndexRelativePath: index.relativePath,
                rawByteCount: raw.byteCount,
                frameIndexByteCount: index.byteCount,
                rawChecksum: raw.checksum,
                frameIndexChecksum: index.checksum,
                framesWritten: video.frameIndex.count
            ),
            blockers: incomplete
        )
    }
}
