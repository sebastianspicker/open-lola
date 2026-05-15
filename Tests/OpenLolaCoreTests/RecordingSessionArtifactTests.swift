import Foundation
import Dispatch
import Testing

@testable import OpenLolaCore

@Test
func recordingSessionArtifactFixtureDecodesAndValidates() throws {
    let report = try loadRecordingSessionArtifactFixture(named: "recording-session-partial")

    try report.validate()

    #expect(report.runMode == .synthetic)
    #expect(report.verdict == .partial)
    #expect(report.sideLane.dropPolicy == .dropAndMarkGap)
    #expect(report.writerPressure.droppedChunkCount > 0)
}

@Test
func recordingSessionSyntheticSmokeEmitsPartialReport() throws {
    let report = RecordingSessionSyntheticSmoke.run()

    try report.validate()

    #expect(report.runMode == .synthetic)
    #expect(report.verdict == .partial)
    #expect(report.sideLane.fileIOAllowedInRealtimeCallback == false)
    #expect(report.writerPressure.gapMarkerCount == report.writerPressure.droppedChunkCount)
}

@Test
func recordingSessionRunConfigurationParsesRequiredArguments() throws {
    let configuration = try RecordingSessionRunConfiguration.parse([
        "--integrated-baseline", "reports/m10-integrated-av.json",
        "--duration-seconds", "30",
        "--output-dir", "reports/m14-session",
        "--report", "reports/m14-recording-session.json",
    ])

    #expect(configuration.integratedBaselinePath == "reports/m10-integrated-av.json")
    #expect(configuration.durationSeconds == 30)
    #expect(configuration.outputDirectory == "reports/m14-session")
    #expect(configuration.reportPath == "reports/m14-recording-session.json")
    #expect(configuration.capture.audio.mode == .off)
    #expect(configuration.capture.video.mode == .off)
}

@Test
func recordingSessionRunConfigurationUsesSelectionHelpersForCaptureModes() throws {
    let source = try String(
        contentsOf: recordingSessionArtifactRepositoryRoot.appendingPathComponent(
            "Sources/OpenLolaCore/Release/RecordingSessionRun.swift"
        ),
        encoding: .utf8
    )

    #expect(source.contains("recordingAudioCaptureSelection(mode: audioMode, values: values)"))
    #expect(source.contains("recordingVideoCaptureSelection(mode: videoMode, values: values)"))
    #expect(source.contains("private func recordingAudioCaptureSelection"))
    #expect(source.contains("private func recordingVideoCaptureSelection"))
    #expect(!source.contains("audioMode == .on ?"))
    #expect(!source.contains("videoMode == .on ?"))
}

@Test
func recordingSessionRunArgumentsAreCentralized() throws {
    let runSource = try String(
        contentsOf: recordingSessionArtifactRepositoryRoot.appendingPathComponent(
            "Sources/OpenLolaCore/Release/RecordingSessionRun.swift"
        ),
        encoding: .utf8
    )
    let helperSource = try String(
        contentsOf: recordingSessionArtifactRepositoryRoot.appendingPathComponent(
            "Sources/OpenLolaCore/Release/RecordingSessionHelpers.swift"
        ),
        encoding: .utf8
    )

    #expect(helperSource.contains("enum RecordingSessionRunArgument"))
    #expect(helperSource.contains("static let audioCapture"))
    #expect(helperSource.contains("static let videoCapture"))
    #expect(helperSource.contains("static let all: Set<String>"))
    #expect(runSource.contains("allowed: RecordingSessionRunArgument.all"))
    #expect(runSource.contains("RecordingSessionRunArgument.integratedBaseline"))
    #expect(!runSource.contains("let allowed = ["))
}

@Test
func recordingSessionRunConfigurationParsesAudioOnlyRecordingArguments() throws {
    let configuration = try RecordingSessionRunConfiguration.parse([
        "--integrated-baseline", "reports/m10-integrated-av.json",
        "--duration-seconds", "30",
        "--output-dir", "reports/m14-session",
        "--report", "reports/m14-recording-session.json",
        "--record-audio", "on",
        "--audio-input-uid", "rme-input",
        "--sample-rate", "48000",
        "--frames", "32",
        "--channels", "2",
        "--input-channels", "8,9",
        "--sample-format", "float32-le",
    ])

    #expect(configuration.capture.audio.mode == .on)
    #expect(configuration.capture.audio.inputUID == "rme-input")
    #expect(configuration.capture.audio.sampleRateHertz == 48_000)
    #expect(configuration.capture.audio.framesPerBuffer == 32)
    #expect(configuration.capture.audio.channelCount == 2)
    #expect(configuration.capture.audio.inputChannels == [8, 9])
    #expect(configuration.capture.audio.sampleFormat == .float32LittleEndian)
    #expect(configuration.capture.video.mode == .off)
}

@Test
func recordingSessionRunConfigurationRequiresAudioArgumentsWhenEnabled() {
    #expect(throws: RecordingSessionRunConfigurationError.missingRequiredArgument("--audio-input-uid")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session",
            "--report", "reports/m14-recording-session.json",
            "--record-audio", "on",
            "--sample-rate", "48000",
            "--frames", "32",
            "--channels", "2",
        ])
    }
}

@Test
func recordingSessionRunConfigurationRequiresVideoDeviceWhenEnabled() {
    #expect(throws: RecordingSessionRunConfigurationError.missingRequiredArgument("--video-device-id")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session",
            "--report", "reports/m14-recording-session.json",
            "--record-video", "on",
        ])
    }
}

@Test
func recordingSessionRunConfigurationParsesVideoOnlyRecordingArguments() throws {
    let configuration = try RecordingSessionRunConfiguration.parse([
        "--integrated-baseline", "reports/m10-integrated-av.json",
        "--duration-seconds", "30",
        "--output-dir", "reports/m14-session",
        "--report", "reports/m14-recording-session.json",
        "--record-video", "on",
        "--video-device-id", "auto",
        "--stream-id", "200",
        "--frame-rate", "60",
        "--queue-depth", "3",
    ])

    #expect(configuration.capture.audio.mode == .off)
    #expect(configuration.capture.video.mode == .on)
    #expect(configuration.capture.video.deviceID == "auto")
    #expect(configuration.capture.video.streamID == 200)
    #expect(configuration.capture.video.frameRate == 60)
    #expect(configuration.capture.video.queueDepth == 3)
}

@Test
func recordingSessionRunConfigurationRequiresExplicitVideoTimingWhenEnabled() {
    #expect(throws: RecordingSessionRunConfigurationError.missingRequiredArgument("--frame-rate")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session",
            "--report", "reports/m14-recording-session.json",
            "--record-video", "on",
            "--video-device-id", "auto",
        ])
    }

    #expect(throws: RecordingSessionRunConfigurationError.missingRequiredArgument("--queue-depth")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session",
            "--report", "reports/m14-recording-session.json",
            "--record-video", "on",
            "--video-device-id", "auto",
            "--frame-rate", "30",
        ])
    }
}

@Test
func recordingSessionRunConfigurationRejectsAudioChannelMapWhenAudioIsOff() {
    #expect(throws: RecordingSessionRunConfigurationError.audioArgumentRequiresAudioMode("--input-channels")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session",
            "--report", "reports/m14-recording-session.json",
            "--input-channels", "0,1",
        ])
    }
}

@Test
func recordingSessionRunConfigurationRejectsVideoArgumentsWhenVideoIsOff() {
    #expect(throws: RecordingSessionRunConfigurationError.videoArgumentRequiresVideoMode("--frame-rate")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session",
            "--report", "reports/m14-recording-session.json",
            "--frame-rate", "30",
        ])
    }
}

@Test
func recordingSessionRunConfigurationParsesAudioVideoRecordingArguments() throws {
    let configuration = try RecordingSessionRunConfiguration.parse([
        "--integrated-baseline", "reports/m10-integrated-av.json",
        "--duration-seconds", "30",
        "--output-dir", "reports/m14-session",
        "--report", "reports/m14-recording-session.json",
        "--record-audio", "on",
        "--audio-input-uid", "rme-input",
        "--sample-rate", "48000",
        "--frames", "32",
        "--channels", "2",
        "--record-video", "on",
        "--video-device-id", "atem-uvc",
        "--frame-rate", "30",
        "--queue-depth", "1",
    ])

    #expect(configuration.capture.audio.mode == .on)
    #expect(configuration.capture.audio.inputChannels == [0, 1])
    #expect(configuration.capture.video.mode == .on)
    #expect(configuration.capture.video.deviceID == "atem-uvc")
}

@Test
func recordingSessionRunConfigurationRejectsMissingReport() {
    #expect(throws: RecordingSessionRunConfigurationError.missingRequiredArgument("--report")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session",
        ])
    }
}

@Test
func recordingSessionRunnerWritesPartialArtifactsFromIntegratedBaseline() throws {
    let outputDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-recording-session-\(UUID().uuidString)", isDirectory: true)
    let configuration = RecordingSessionRunConfiguration(
        integratedBaselinePath: "reports/m10-integrated-av.json",
        durationSeconds: 30,
        outputDirectory: outputDirectory.path,
        reportPath: outputDirectory.appendingPathComponent("recording-session-report.json").path
    )

    let report = try RecordingSessionRunner.run(
        configuration: configuration,
        integratedBaseline: IntegratedHeadlessAvSyntheticSmoke.run()
    )

    try report.validate()

    #expect(report.id == "m14-recording-session-run")
    #expect(report.runMode == .measured)
    #expect(report.verdict == .partial)
    #expect(report.durationSeconds == 30)
    #expect(report.sideLane.fileIOAllowedInRealtimeCallback == false)
    #expect(report.sideLane.queueFedByCopiedMedia)
    #expect(report.writerPressure.simulatedSlowWriter == false)
    #expect(report.writerPressure.producedChunkCount == report.manifest.entries.count)
    #expect(report.writerPressure.writtenChunkCount == report.manifest.entries.count)
    #expect(report.writerPressure.droppedChunkCount == 0)
    #expect(report.writerPressure.gapMarkerCount == 0)
    #expect(report.writerPressure.writerStallCount == 0)
    #expect(report.mediaImpact.recordingPlayoutTargetFrames == report.mediaImpact.baselinePlayoutTargetFrames)
    #expect(report.manifest.rootDirectory == outputDirectory.path)
    #expect(report.manifest.entries.count == 3)
    #expect(report.audioArtifact.state == .off)
    #expect(report.videoArtifact.state == .off)
    #expect(!report.manifest.entries.contains { $0.kind == .audioPcm })
    #expect(!report.manifest.entries.contains { $0.kind == .videoFrames })
    #expect(!report.manifest.entries.contains { $0.kind == .videoFrameIndex })

    for entry in report.manifest.entries {
        let artifactURL = outputDirectory.appendingPathComponent(entry.relativePath)
        #expect(FileManager.default.fileExists(atPath: artifactURL.path))
        #expect(entry.byteCount > 0)
        #expect(entry.checksum.isEmpty == false)
    }
}

@Test
func recordingSessionRunnerReportsBaselineReadPathOnFailure() {
    let path = "/tmp/open-lola-missing-baseline-\(UUID().uuidString).json"
    let configuration = RecordingSessionRunConfiguration(
        integratedBaselinePath: path,
        durationSeconds: 1,
        outputDirectory: "/tmp/open-lola-recording-\(UUID().uuidString)",
        reportPath: "/tmp/open-lola-recording-report-\(UUID().uuidString).json"
    )

    #expect(throws: RecordingSessionRunConfigurationError.integratedBaselineReadFailed(path)) {
        _ = try RecordingSessionRunner.run(configuration: configuration)
    }
}

@Test
func recordingSessionRunnerReportsBaselineDecodePathOnFailure() throws {
    let baseline = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-invalid-baseline-\(UUID().uuidString).json")
    try Data("not json".utf8).write(to: baseline)
    let configuration = RecordingSessionRunConfiguration(
        integratedBaselinePath: baseline.path,
        durationSeconds: 1,
        outputDirectory: "/tmp/open-lola-recording-\(UUID().uuidString)",
        reportPath: "/tmp/open-lola-recording-report-\(UUID().uuidString).json"
    )

    #expect(throws: RecordingSessionRunConfigurationError.integratedBaselineDecodeFailed(baseline.path)) {
        _ = try RecordingSessionRunner.run(configuration: configuration)
    }
}

@Test
func recordingSessionArtifactWriterRemovesStagingDirectoryOnFailure() throws {
    let outputDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-recording-rollback-\(UUID().uuidString)", isDirectory: true)
    let parent = outputDirectory.deletingLastPathComponent()
    let prefix = ".\(outputDirectory.lastPathComponent).staging-"

    #expect(throws: (any Error).self) {
        _ = try writeRecordingSessionArtifacts(
            outputDirectory: outputDirectory.path,
            artifacts: [
                RecordingSessionArtifactPayload(kind: .manifest, relativePath: "manifest.json", data: Data([1])),
                RecordingSessionArtifactPayload(kind: .gapLog, relativePath: "manifest.json/child", data: Data([2])),
            ]
        )
    }

    #expect(!FileManager.default.fileExists(atPath: outputDirectory.path))
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: parent.path)
        .filter { $0.hasPrefix(prefix) }
    #expect(leftovers.isEmpty)
}

@Test
func recordingSessionRunnerWritesInjectedAudioOnlyRawArtifact() throws {
    let outputDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-recording-audio-\(UUID().uuidString)", isDirectory: true)
    let configuration = RecordingSessionRunConfiguration(
        integratedBaselinePath: "reports/m10-integrated-av.json",
        durationSeconds: 1,
        outputDirectory: outputDirectory.path,
        reportPath: outputDirectory.appendingPathComponent("report.json").path,
        capture: RecordingMediaCaptureSelection(
            audio: RecordingAudioCaptureSelection(
                mode: .on,
                inputUID: "synthetic-input",
                sampleRateHertz: 48_000,
                framesPerBuffer: 32,
                channelCount: 2,
                inputChannels: [0, 1],
                sampleFormat: .int16LittleEndian
            )
        )
    )

    let report = try RecordingSessionRunner.run(
        configuration: configuration,
        integratedBaseline: IntegratedHeadlessAvSyntheticSmoke.run(),
        capturedMedia: RecordingCapturedMedia(audio: RecordingCapturedAudio(
            data: Data([1, 2, 3, 4]),
            callbackP99Microseconds: 70,
            callbackMaxMicroseconds: 95,
            underruns: 1
        ))
    )

    try report.validate()

    let audio = try #require(report.manifest.entries.first { $0.kind == .audioPcm })
    #expect(audio.relativePath == "audio/input.pcm")
    #expect(report.audioArtifact.state == .recorded)
    #expect(report.audioArtifact.byteCount == 4)
    #expect(report.audioArtifact.checksum == audio.checksum)
    #expect(audio.checksum.count == 64)
    #expect(!audio.checksum.hasPrefix("fnv1a64-"))
    #expect(report.mediaImpact.recordingAudioCallbackP99Microseconds == 70)
    #expect(report.mediaImpact.recordingAudioCallbackMaxMicroseconds == 95)
    #expect(report.mediaImpact.audioUnderruns == 1)
    #expect(report.videoArtifact.state == .off)
    #expect(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("audio/input.pcm").path))
}

@Test
func recordingSessionRunnerWritesInjectedVideoOnlyRawArtifacts() throws {
    let outputDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-recording-video-\(UUID().uuidString)", isDirectory: true)
    let configuration = RecordingSessionRunConfiguration(
        integratedBaselinePath: "reports/m10-integrated-av.json",
        durationSeconds: 1,
        outputDirectory: outputDirectory.path,
        reportPath: outputDirectory.appendingPathComponent("report.json").path,
        capture: RecordingMediaCaptureSelection(
            video: RecordingVideoCaptureSelection(mode: .on, deviceID: "synthetic-video")
        )
    )
    let frameIndex = RecordingVideoFrameIndexEntry(
        sequenceNumber: 7,
        timestampNanoseconds: 2_000,
        byteOffset: 0,
        byteCount: 4,
        width: 2,
        height: 1,
        pixelFormat: "rgb24"
    )

    let report = try RecordingSessionRunner.run(
        configuration: configuration,
        integratedBaseline: IntegratedHeadlessAvSyntheticSmoke.run(),
        capturedMedia: RecordingCapturedMedia(
            video: RecordingCapturedVideo(rawFrameData: Data([9, 8, 7, 6]), frameIndex: [frameIndex])
        )
    )

    try report.validate()

    let raw = try #require(report.manifest.entries.first { $0.kind == .videoFrames })
    let index = try #require(report.manifest.entries.first { $0.kind == .videoFrameIndex })
    #expect(report.audioArtifact.state == .off)
    #expect(report.videoArtifact.state == .recorded)
    #expect(report.videoArtifact.rawFramesRelativePath == "video/frames.raw")
    #expect(report.videoArtifact.frameIndexRelativePath == "video/frames.index.jsonl")
    #expect(report.videoArtifact.rawByteCount == raw.byteCount)
    #expect(report.videoArtifact.frameIndexByteCount == index.byteCount)
    #expect(report.videoArtifact.rawChecksum == raw.checksum)
    #expect(report.videoArtifact.frameIndexChecksum == index.checksum)
    #expect(report.videoArtifact.framesWritten == 1)
    #expect(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("video/frames.raw").path))
    #expect(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("video/frames.index.jsonl").path))
}

@Test
func recordingSessionRunnerWritesInjectedAudioVideoRawArtifacts() throws {
    let outputDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-recording-av-\(UUID().uuidString)", isDirectory: true)
    let configuration = RecordingSessionRunConfiguration(
        integratedBaselinePath: "reports/m10-integrated-av.json",
        durationSeconds: 1,
        outputDirectory: outputDirectory.path,
        reportPath: outputDirectory.appendingPathComponent("report.json").path,
        capture: RecordingMediaCaptureSelection(
            audio: RecordingAudioCaptureSelection(
                mode: .on,
                inputUID: "synthetic-input",
                sampleRateHertz: 48_000,
                framesPerBuffer: 32,
                channelCount: 1,
                inputChannels: [0]
            ),
            video: RecordingVideoCaptureSelection(mode: .on, deviceID: "synthetic-video")
        )
    )
    let frameIndex = RecordingVideoFrameIndexEntry(
        sequenceNumber: 0,
        timestampNanoseconds: 1_000,
        byteOffset: 0,
        byteCount: 3,
        width: 1,
        height: 1,
        pixelFormat: "rgb24"
    )

    let report = try RecordingSessionRunner.run(
        configuration: configuration,
        integratedBaseline: IntegratedHeadlessAvSyntheticSmoke.run(),
        capturedMedia: RecordingCapturedMedia(
            audio: RecordingCapturedAudio(data: Data([1, 2])),
            video: RecordingCapturedVideo(rawFrameData: Data([9, 8, 7]), frameIndex: [frameIndex])
        )
    )

    try report.validate()

    #expect(report.audioArtifact.state == .recorded)
    #expect(report.videoArtifact.state == .recorded)
    #expect(report.videoArtifact.framesWritten == 1)
    let raw = try #require(report.manifest.entries.first { $0.relativePath == "video/frames.raw" })
    let index = try #require(report.manifest.entries.first { $0.relativePath == "video/frames.index.jsonl" })
    #expect(report.videoArtifact.rawByteCount == raw.byteCount)
    #expect(report.videoArtifact.frameIndexByteCount == index.byteCount)
    #expect(report.videoArtifact.rawChecksum == raw.checksum)
    #expect(report.videoArtifact.frameIndexChecksum == index.checksum)
    #expect(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("video/frames.raw").path))
    #expect(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent("video/frames.index.jsonl").path))
}

@Test
func recordingSessionRunnerMarksEnabledUnavailableMediaWithoutFakeArtifacts() throws {
    let outputDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-recording-blocked-\(UUID().uuidString)", isDirectory: true)
    let configuration = RecordingSessionRunConfiguration(
        integratedBaselinePath: "reports/m10-integrated-av.json",
        durationSeconds: 1,
        outputDirectory: outputDirectory.path,
        reportPath: outputDirectory.appendingPathComponent("report.json").path,
        capture: RecordingMediaCaptureSelection(
            audio: RecordingAudioCaptureSelection(
                mode: .on,
                inputUID: "missing-input",
                sampleRateHertz: 48_000,
                framesPerBuffer: 32,
                channelCount: 1,
                inputChannels: [0]
            )
        )
    )

    let report = try RecordingSessionRunner.run(
        configuration: configuration,
        integratedBaseline: IntegratedHeadlessAvSyntheticSmoke.run(),
        capturedMedia: RecordingCapturedMedia(audioBlockers: ["input UID not found"])
    )

    try report.validate()

    #expect(report.audioArtifact.state == .unavailable)
    #expect(report.audioArtifact.blockers == ["input UID not found"])
    #expect(!report.manifest.entries.contains { $0.kind == .audioPcm })
}

@Test
func recordingSideLaneDropsAndMarksGapsWhenWriterStalls() {
    let pressure = RecordingSideLanePressureSimulator.run(
        producedChunkCount: 8,
        queueCapacityChunks: 2,
        writerPattern: [0]
    )

    #expect(pressure.producedChunkCount == 8)
    #expect(pressure.writtenChunkCount == 0)
    #expect(pressure.droppedChunkCount == 6)
    #expect(pressure.gapMarkerCount == 6)
    #expect(pressure.maxQueuedChunks == 2)
    #expect(pressure.writerStallCount == 8)
}

@Test
func recordingSessionLiveCaptureUsesCancellableWaitInsteadOfThreadSleep() throws {
    let source = try String(
        contentsOf: recordingSessionArtifactRepositoryRoot
            .appendingPathComponent("Sources/OpenLolaCore/Release/RecordingSessionLiveCapture.swift"),
        encoding: .utf8
    )

    #expect(!source.contains("Thread.sleep"))
    #expect(source.contains("DispatchSemaphore"))
    #expect(source.contains("RecordingLiveCaptureWait.wait"))

    let cancellation = DispatchSemaphore(value: 0)
    cancellation.signal()
    #expect(RecordingLiveCaptureWait.wait(durationSeconds: 60, cancellation: cancellation) == .success)
}

@Test
func recordingSessionLiveCaptureUsesCheckedBufferSizing() throws {
    let source = try String(
        contentsOf: recordingSessionArtifactRepositoryRoot
            .appendingPathComponent("Sources/OpenLolaCore/Release/RecordingSessionLiveCapture.swift"),
        encoding: .utf8
    )

    #expect(source.contains("checkedRecordingAudioByteCount"))
    #expect(source.contains("addingReportingOverflow"))
    #expect(source.contains("audioBufferSizingOverflow"))
}

@Test
func recordingSessionVideoCaptureStopsStartedSessionOnLaterThrows() throws {
    let source = try String(
        contentsOf: recordingSessionArtifactRepositoryRoot
            .appendingPathComponent("Sources/OpenLolaCore/Release/RecordingSessionLiveCapture.swift"),
        encoding: .utf8
    )

    #expect(source.contains("var didStartSession = false"))
    #expect(source.contains("defer {\n            if didStartSession {\n                captureSession.session.stopRunning()"))
    #expect(source.contains("captureSession.restoreDevice(logger: AVFoundationVideoCaptureRunner.logger)"))
    #expect(source.contains("didStartSession = true"))
    #expect(source.contains("didStartSession = false"))
}

private func passCandidateReport() throws -> RecordingSessionArtifactReport {
    var report = try loadRecordingSessionArtifactFixture(named: "recording-session-partial")
    report.verdict = .pass
    report.runMode = .measured
    report.writerPressure.simulatedSlowWriter = true
    return report
}

private func loadRecordingSessionArtifactFixture(named name: String) throws -> RecordingSessionArtifactReport {
    let url = try recordingSessionArtifactFixtureURL(named: name)
    return try RecordingSessionArtifactReport.decode(from: Data(contentsOf: url))
}

private func recordingSessionArtifactFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "RecordingSessionArtifacts/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "RecordingSessionArtifacts/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}

private var recordingSessionArtifactRepositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
