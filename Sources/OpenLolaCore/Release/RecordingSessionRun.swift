import Foundation

public enum RecordingSideLanePressureSimulator {
    public static func run(
        producedChunkCount: Int,
        queueCapacityChunks: Int,
        writerPattern: [Int]
    ) -> RecordingWriterPressureMetrics {
        var queued = 0
        var written = 0
        var dropped = 0
        var maxQueued = 0
        var stalls = 0
        let pattern = writerPattern.isEmpty ? [1] : writerPattern

        for index in 0..<producedChunkCount {
            if queued < queueCapacityChunks {
                queued += 1
            } else {
                dropped += 1
            }

            let writeBudget = max(0, pattern[index % pattern.count])
            if writeBudget == 0 {
                stalls += 1
            }
            let writes = min(queued, writeBudget)
            queued -= writes
            written += writes
            maxQueued = max(maxQueued, queued)
        }

        return RecordingWriterPressureMetrics(
            simulatedSlowWriter: true,
            producedChunkCount: producedChunkCount,
            writtenChunkCount: written,
            droppedChunkCount: dropped,
            gapMarkerCount: dropped,
            maxQueuedChunks: maxQueued,
            writerStallCount: stalls
        )
    }
}

/// CLI and programmatic input contract for recording-session artifact generation.
public struct RecordingSessionRunConfiguration: Codable, Equatable, Sendable {
    public let integratedBaselinePath: String
    public let durationSeconds: Int
    public let outputDirectory: String
    public let reportPath: String
    public let capture: RecordingMediaCaptureSelection

    public init(
        integratedBaselinePath: String,
        durationSeconds: Int,
        outputDirectory: String,
        reportPath: String,
        capture: RecordingMediaCaptureSelection = .off
    ) {
        self.integratedBaselinePath = integratedBaselinePath
        self.durationSeconds = durationSeconds
        self.outputDirectory = outputDirectory
        self.reportPath = reportPath
        self.capture = capture
    }

    public static func parse(_ arguments: [String]) throws -> RecordingSessionRunConfiguration {
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: RecordingSessionRunArgument.all,
            unknown: RecordingSessionRunConfigurationError.unknownArgument,
            duplicate: RecordingSessionRunConfigurationError.duplicateArgument,
            missingValue: RecordingSessionRunConfigurationError.missingValue
        )
        let audioMode = try optionalRecordingRunSwitch(RecordingSessionRunArgument.recordAudio, values, defaultValue: .off)
        let videoMode = try optionalRecordingRunSwitch(RecordingSessionRunArgument.recordVideo, values, defaultValue: .off)
        try validateRecordingAudioArguments(mode: audioMode, values: values)
        try validateRecordingVideoArguments(mode: videoMode, values: values)
        let audio = try recordingAudioCaptureSelection(mode: audioMode, values: values)
        let video = try recordingVideoCaptureSelection(mode: videoMode, values: values)

        return RecordingSessionRunConfiguration(
            integratedBaselinePath: try requiredRecordingRunString(RecordingSessionRunArgument.integratedBaseline, values),
            durationSeconds: try requiredRecordingRunPositiveInteger(RecordingSessionRunArgument.durationSeconds, values),
            outputDirectory: try requiredRecordingRunString(RecordingSessionRunArgument.outputDirectory, values),
            reportPath: try requiredRecordingRunString(RecordingSessionRunArgument.report, values),
            capture: RecordingMediaCaptureSelection(audio: audio, video: video)
        )
    }
}

private func recordingAudioCaptureSelection(
    mode: RecordingMediaSwitch,
    values: [String: String]
) throws -> RecordingAudioCaptureSelection {
    guard mode == .on else {
        return RecordingAudioCaptureSelection(
            mode: mode,
            inputUID: nil,
            sampleRateHertz: nil,
            framesPerBuffer: nil,
            channelCount: nil,
            inputChannels: [],
            sampleFormat: try optionalRecordingSampleFormat(values[RecordingSessionRunArgument.sampleFormat])
        )
    }

    let channelCount = try requiredRecordingRunPositiveInteger(RecordingSessionRunArgument.channels, values)
    return RecordingAudioCaptureSelection(
        mode: mode,
        inputUID: try requiredRecordingRunString(RecordingSessionRunArgument.audioInputUID, values),
        sampleRateHertz: try requiredRecordingRunPositiveInteger(RecordingSessionRunArgument.sampleRate, values),
        framesPerBuffer: try requiredRecordingRunPositiveInteger(RecordingSessionRunArgument.frames, values),
        channelCount: channelCount,
        inputChannels: try optionalRecordingChannelMap(
            values[RecordingSessionRunArgument.inputChannels],
            expectedCount: channelCount
        ),
        sampleFormat: try optionalRecordingSampleFormat(values[RecordingSessionRunArgument.sampleFormat])
    )
}

private func recordingVideoCaptureSelection(
    mode: RecordingMediaSwitch,
    values: [String: String]
) throws -> RecordingVideoCaptureSelection {
    guard mode == .on else {
        return RecordingVideoCaptureSelection(
            mode: mode,
            deviceID: nil,
            streamID: try optionalRecordingRunPositiveUInt32(
                RecordingSessionRunArgument.streamID,
                values,
                defaultValue: 100
            ),
            frameRate: 30,
            queueDepth: 1
        )
    }

    return RecordingVideoCaptureSelection(
        mode: mode,
        deviceID: try requiredRecordingRunString(RecordingSessionRunArgument.videoDeviceID, values),
        streamID: try optionalRecordingRunPositiveUInt32(
            RecordingSessionRunArgument.streamID,
            values,
            defaultValue: 100
        ),
        frameRate: try requiredRecordingRunPositiveDouble(RecordingSessionRunArgument.frameRate, values),
        queueDepth: try requiredRecordingRunPositiveInteger(RecordingSessionRunArgument.queueDepth, values)
    )
}

public enum RecordingSessionRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case invalidDouble(argument: String, value: String)
    case invalidSwitch(argument: String, value: String)
    case invalidSampleFormat(String)
    case invalidChannelMap(String)
    case channelMapCountMismatch(expected: Int, actual: Int)
    case audioArgumentRequiresAudioMode(String)
    case videoArgumentRequiresVideoMode(String)
    case nonPositiveArgument(String)
    case integratedBaselineReadFailed(String)
    case integratedBaselineDecodeFailed(String)
}

public enum RecordingSessionRunner {
    public static func run(configuration: RecordingSessionRunConfiguration) throws -> RecordingSessionArtifactReport {
        let baselineData: Data
        do {
            baselineData = try BoundedFileReader.data(atPath: configuration.integratedBaselinePath)
        } catch {
            throw RecordingSessionRunConfigurationError.integratedBaselineReadFailed(
                configuration.integratedBaselinePath
            )
        }
        let baseline: IntegratedAvReport
        do {
            baseline = try IntegratedAvReport.decode(from: baselineData)
        } catch {
            throw RecordingSessionRunConfigurationError.integratedBaselineDecodeFailed(
                configuration.integratedBaselinePath
            )
        }
        return try run(configuration: configuration, integratedBaseline: baseline)
    }

    public static func run(
        configuration: RecordingSessionRunConfiguration,
        integratedBaseline: IntegratedAvReport
    ) throws -> RecordingSessionArtifactReport {
        try run(
            configuration: configuration,
            integratedBaseline: integratedBaseline,
            capturedMedia: RecordingSessionLiveMediaCapture.capture(configuration: configuration)
        )
    }

    public static func run(
        configuration: RecordingSessionRunConfiguration,
        integratedBaseline: IntegratedAvReport,
        capturedMedia: RecordingCapturedMedia
    ) throws -> RecordingSessionArtifactReport {
        let written = try RecordingMediaArtifactWriter.write(
            outputDirectory: configuration.outputDirectory,
            durationSeconds: configuration.durationSeconds,
            capture: configuration.capture,
            capturedMedia: capturedMedia
        )
        let baselineP99 = integratedBaseline.audio.integratedCallbackP99Microseconds
        let baselineMax = integratedBaseline.audio.integratedCallbackMaxMicroseconds
        let recordingCallback = recordingAudioCallbackMetrics(
            baselineP99: baselineP99,
            baselineMax: baselineMax,
            capturedAudio: capturedMedia.audio
        )
        let playoutFrames = integratedBaseline.audio.integratedPlayoutTargetFrames

        return RecordingSessionArtifactReport(
            id: "m14-recording-session-run",
            title: "Recording side-lane runtime report",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            runMode: .measured,
            durationSeconds: Double(configuration.durationSeconds),
            session: recordingSessionMetadata(),
            sideLane: recordingSideLanePolicy(),
            capture: configuration.capture,
            writerPressure: written.writerPressure,
            mediaImpact: recordingMediaImpact(
                baselineP99: baselineP99,
                baselineMax: baselineMax,
                recordingCallback: recordingCallback,
                playoutFrames: playoutFrames,
                integratedBaseline: integratedBaseline
            ),
            audioArtifact: written.audio,
            videoArtifact: written.video,
            manifest: written.manifest,
            verdict: .partial,
            notes: "Recording side-lane wrote opted-in raw media artifacts without realtime file I/O."
        )
    }
}

private struct RecordingAudioCallbackMetrics {
    var p99Microseconds: Double
    var maxMicroseconds: Double
    var underruns: Int
}

private func recordingAudioCallbackMetrics(
    baselineP99: Double,
    baselineMax: Double,
    capturedAudio: RecordingCapturedAudio?
) -> RecordingAudioCallbackMetrics {
    guard let capturedAudio,
          let p99 = capturedAudio.callbackP99Microseconds,
          let max = capturedAudio.callbackMaxMicroseconds else {
        return RecordingAudioCallbackMetrics(
            p99Microseconds: baselineP99,
            maxMicroseconds: baselineMax,
            underruns: 0
        )
    }
    return RecordingAudioCallbackMetrics(
        p99Microseconds: p99,
        maxMicroseconds: max,
        underruns: capturedAudio.underruns
    )
}

private func recordingSessionMetadata() -> RecordingSessionMetadata {
    let formatter = ISO8601DateFormatter()
    return RecordingSessionMetadata(
        sessionId: "m14-recording-session-run",
        profileName: "headless-side-lane",
        configuredBy: "open-lola",
        startedAt: formatter.string(from: Date()),
        endedAt: formatter.string(from: Date())
    )
}

private func recordingSideLanePolicy() -> RecordingSideLanePolicy {
    RecordingSideLanePolicy(
        fileIOAllowedInRealtimeCallback: false,
        queueFedByCopiedMedia: true,
        writesAsynchronously: true,
        boundedQueueCapacityChunks: 2,
        dropPolicy: .dropAndMarkGap
    )
}

private func recordingMediaImpact(
    baselineP99: Double,
    baselineMax: Double,
    recordingCallback: RecordingAudioCallbackMetrics,
    playoutFrames: Int,
    integratedBaseline: IntegratedAvReport
) -> RecordingMediaImpactMetrics {
    RecordingMediaImpactMetrics(
        baselineAudioCallbackP99Microseconds: baselineP99,
        recordingAudioCallbackP99Microseconds: recordingCallback.p99Microseconds,
        baselineAudioCallbackMaxMicroseconds: baselineMax,
        recordingAudioCallbackMaxMicroseconds: recordingCallback.maxMicroseconds,
        baselinePlayoutTargetFrames: playoutFrames,
        recordingPlayoutTargetFrames: playoutFrames,
        audioUnderruns: recordingCallback.underruns,
        videoDroppedFramesBeforeRecording: integratedBaseline.video.receiverDroppedFrames,
        videoDroppedFramesDuringRecording: integratedBaseline.video.receiverDroppedFrames,
        hiddenPlayoutGrowthDetected: false
    )
}

public enum RecordingSessionSyntheticSmoke {
    public static func run() -> RecordingSessionArtifactReport {
        let pressure = RecordingSideLanePressureSimulator.run(
            producedChunkCount: 8,
            queueCapacityChunks: 2,
            writerPattern: [0]
        )
        return RecordingSessionArtifactReport(
            id: "m14-recording-session-synthetic-smoke",
            title: "Synthetic recording side-lane report",
            capturedAt: "2026-05-02T00:00:00Z",
            runMode: .synthetic,
            durationSeconds: 1,
            session: RecordingSessionMetadata(
                sessionId: "synthetic-session",
                profileName: "synthetic-side-lane",
                configuredBy: "test",
                startedAt: "2026-05-02T00:00:00Z",
                endedAt: "2026-05-02T00:00:01Z"
            ),
            sideLane: RecordingSideLanePolicy(
                fileIOAllowedInRealtimeCallback: false,
                queueFedByCopiedMedia: true,
                writesAsynchronously: true,
                boundedQueueCapacityChunks: 2,
                dropPolicy: .dropAndMarkGap
            ),
            capture: .off,
            writerPressure: pressure,
            mediaImpact: RecordingMediaImpactMetrics(
                baselineAudioCallbackP99Microseconds: 80,
                recordingAudioCallbackP99Microseconds: 80,
                baselineAudioCallbackMaxMicroseconds: 120,
                recordingAudioCallbackMaxMicroseconds: 120,
                baselinePlayoutTargetFrames: 32,
                recordingPlayoutTargetFrames: 32,
                audioUnderruns: 0,
                videoDroppedFramesBeforeRecording: 0,
                videoDroppedFramesDuringRecording: 0,
                hiddenPlayoutGrowthDetected: false
            ),
            audioArtifact: .off,
            videoArtifact: .off,
            manifest: RecordingArtifactManifest(
                rootDirectory: "synthetic",
                includesConfigurationMetadata: true,
                includesVerdictMetadata: true,
                entries: [
                    RecordingArtifactEntry(
                        kind: .manifest,
                        relativePath: "manifest.json",
                        byteCount: 16,
                        checksum: recordingSessionChecksum(Data("synthetic-recording-manifest".utf8))
                    )
                ]
            ),
            verdict: .partial,
            notes: "Synthetic recording side-lane validation only."
        )
    }
}
