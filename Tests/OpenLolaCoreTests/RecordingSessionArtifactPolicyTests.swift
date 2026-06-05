import Foundation
import Testing

@testable import OpenLolaCore

@Test
func recordingSessionRejectsInvalidPassEvidence() throws {
    try expectRecordingSessionArtifactError(.passAllowsRealtimeFileIO) {
        $0.sideLane.fileIOAllowedInRealtimeCallback = true
    }
    try expectRecordingSessionArtifactError(.passWithoutDropOnPressure) {
        $0.sideLane.dropPolicy = .blockProducer
    }
    try expectRecordingSessionArtifactError(.passWithoutRecordingDropOrGap) {
        $0.writerPressure.gapMarkerCount = 0
    }
    try expectRecordingSessionArtifactError(.passIncreasesAudioP99(baseline: 80, recording: 81)) {
        $0.mediaImpact.recordingAudioCallbackP99Microseconds = 81
    }
    try expectRecordingSessionArtifactError(.passChangesAudioPlayoutTarget(baseline: 32, recording: 48)) {
        $0.mediaImpact.recordingPlayoutTargetFrames = 48
    }
    try expectRecordingSessionArtifactError(.passWithHiddenPlayoutGrowth) {
        $0.mediaImpact.hiddenPlayoutGrowthDetected = true
    }
    try expectRecordingSessionArtifactError(.passWithoutConfigurationMetadata) {
        $0.manifest.includesConfigurationMetadata = false
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
        files: RecordingVideoArtifactFiles(
            rawFramesRelativePath: "video/frames.raw",
            frameIndexRelativePath: "video/frames.index.jsonl",
            rawByteCount: 4,
            frameIndexByteCount: 128,
            rawChecksum: "missing-raw",
            frameIndexChecksum: "missing-index",
            framesWritten: 1
        )
    )

    #expect(throws: RecordingSessionArtifactValidationError.recordedMediaMissingManifestEntry(
        .videoFrames,
        "video/frames.raw"
    )) {
        try report.validate()
    }
}

private func passCandidateReport() throws -> RecordingSessionArtifactReport {
    var report = try loadRecordingSessionArtifactFixture(named: "recording-session-partial")
    report.verdict = .pass
    report.runMode = .measured
    report.writerPressure.simulatedSlowWriter = true
    return report
}

private func expectRecordingSessionArtifactError(
    _ expected: RecordingSessionArtifactValidationError,
    mutate: (inout RecordingSessionArtifactReport) throws -> Void
) throws {
    var report = try passCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
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
