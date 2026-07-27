// Collects release-readiness evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Captures media-capture state required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingCapturedAudio: Equatable, Sendable {
    public var data: Data
    public var callbackP99Microseconds: Double?
    public var callbackMaxMicroseconds: Double?
    public var underruns: Int

    public init(
        data: Data,
        callbackP99Microseconds: Double? = nil,
        callbackMaxMicroseconds: Double? = nil,
        underruns: Int = 0
    ) {
        self.data = data
        self.callbackP99Microseconds = callbackP99Microseconds
        self.callbackMaxMicroseconds = callbackMaxMicroseconds
        self.underruns = underruns
    }
}

/// Captures media-capture state required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingCapturedVideo: Equatable, Sendable {
    public var rawFrameData: Data
    public var frameIndex: [RecordingVideoFrameIndexEntry]

    public init(rawFrameData: Data, frameIndex: [RecordingVideoFrameIndexEntry]) {
        self.rawFrameData = rawFrameData
        self.frameIndex = frameIndex
    }
}

/// Captures media-capture state required to validate, interpret, and reproduce a recording-session artifact result.
public struct RecordingCapturedMedia: Equatable, Sendable {
    public var audio: RecordingCapturedAudio?
    public var audioBlockers: [String]
    public var video: RecordingCapturedVideo?
    public var videoBlockers: [String]

    public init(
        audio: RecordingCapturedAudio? = nil,
        audioBlockers: [String] = [],
        video: RecordingCapturedVideo? = nil,
        videoBlockers: [String] = []
    ) {
        self.audio = audio
        self.audioBlockers = audioBlockers
        self.video = video
        self.videoBlockers = videoBlockers
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
        guard capturedMedia.audio != nil else {
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
        return RecordingAudioArtifactMetrics(
            state: .recorded,
            relativePath: entry.relativePath,
            byteCount: entry.byteCount,
            checksum: entry.checksum
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
        return RecordingVideoArtifactMetrics(
            state: .recorded,
            files: RecordingVideoArtifactFiles(
                rawFramesRelativePath: raw.relativePath,
                frameIndexRelativePath: index.relativePath,
                rawByteCount: raw.byteCount,
                frameIndexByteCount: index.byteCount,
                rawChecksum: raw.checksum,
                frameIndexChecksum: index.checksum,
                framesWritten: video.frameIndex.count
            )
        )
    }
}
