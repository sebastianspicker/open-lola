import Foundation
import Testing

@testable import OpenLolaCore

@Test
func recordingSessionRejectsPassWithRealtimeFileIO() throws {
    var report = try passCandidateReport()
    report.sideLane.fileIOAllowedInRealtimeCallback = true

    #expect(throws: RecordingSessionArtifactValidationError.passAllowsRealtimeFileIO) {
        try report.validate()
    }
}

@Test
func recordingSessionRejectsPassWithoutDropOnPressurePolicy() throws {
    var report = try passCandidateReport()
    report.sideLane.dropPolicy = .blockProducer

    #expect(throws: RecordingSessionArtifactValidationError.passWithoutDropOnPressure) {
        try report.validate()
    }
}

@Test
func recordingSessionRejectsPassWithoutGapMarkersForDrops() throws {
    var report = try passCandidateReport()
    report.writerPressure.gapMarkerCount = 0

    #expect(throws: RecordingSessionArtifactValidationError.passWithoutRecordingDropOrGap) {
        try report.validate()
    }
}

@Test
func recordingSessionRejectsPassWithAudioP99Increase() throws {
    var report = try passCandidateReport()
    report.mediaImpact.recordingAudioCallbackP99Microseconds = 81

    #expect(throws: RecordingSessionArtifactValidationError.passIncreasesAudioP99(
        baseline: 80,
        recording: 81
    )) {
        try report.validate()
    }
}

@Test
func recordingSessionRejectsPassWithPlayoutTargetChange() throws {
    var report = try passCandidateReport()
    report.mediaImpact.recordingPlayoutTargetFrames = 48

    #expect(throws: RecordingSessionArtifactValidationError.passChangesAudioPlayoutTarget(
        baseline: 32,
        recording: 48
    )) {
        try report.validate()
    }
}

@Test
func recordingSessionRejectsPassWithHiddenPlayoutGrowth() throws {
    var report = try passCandidateReport()
    report.mediaImpact.hiddenPlayoutGrowthDetected = true

    #expect(throws: RecordingSessionArtifactValidationError.passWithHiddenPlayoutGrowth) {
        try report.validate()
    }
}

@Test
func recordingSessionRejectsPassWithoutConfigurationMetadata() throws {
    var report = try passCandidateReport()
    report.manifest.includesConfigurationMetadata = false

    #expect(throws: RecordingSessionArtifactValidationError.passWithoutConfigurationMetadata) {
        try report.validate()
    }
}

@Test
func recordingSessionRejectsRecordedAudioWithoutManifestEntry() throws {
    var report = try passCandidateReport()
    report.verdict = .partial
    report.capture.audio = RecordingAudioCaptureSelection(
        mode: .on,
        inputUID: "synthetic-input",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 1,
        inputChannels: [0]
    )
    report.audioArtifact = RecordingAudioArtifactMetrics(
        state: .recorded,
        relativePath: "audio/input.pcm",
        byteCount: 4,
        checksum: "missing"
    )

    #expect(throws: RecordingSessionArtifactValidationError.recordedMediaMissingManifestEntry(
        .audioPcm,
        "audio/input.pcm"
    )) {
        try report.validate()
    }
}

@Test
func recordingSessionRejectsRecordedVideoWithoutManifestEntry() throws {
    var report = try passCandidateReport()
    report.verdict = .partial
    report.capture.video = RecordingVideoCaptureSelection(mode: .on, deviceID: "synthetic-video")
    report.videoArtifact = RecordingVideoArtifactMetrics(
        state: .recorded,
        rawFramesRelativePath: "video/frames.raw",
        frameIndexRelativePath: "video/frames.index.jsonl",
        rawByteCount: 4,
        frameIndexByteCount: 128,
        rawChecksum: "missing-raw",
        frameIndexChecksum: "missing-index",
        framesWritten: 1
    )

    #expect(throws: RecordingSessionArtifactValidationError.recordedMediaMissingManifestEntry(
        .videoFrames,
        "video/frames.raw"
    )) {
        try report.validate()
    }
}

@Test
func recordingSessionJSONRoundTripPreservesReport() throws {
    let report = try loadRecordingSessionArtifactFixture(named: "recording-session-partial")
    let jsonData = try report.prettyJSONData()
    let decoded = try RecordingSessionArtifactReport.decode(from: jsonData)

    #expect(decoded == report)
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
