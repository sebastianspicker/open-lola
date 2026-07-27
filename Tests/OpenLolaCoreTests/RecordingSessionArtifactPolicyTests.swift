// Verifies that recording session rejects invalid pass evidence.
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
    var report = try recordingSessionPassCandidateReport()
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
    var report = try recordingSessionPassCandidateReport()
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

private func expectRecordingSessionArtifactError(
    _ expected: RecordingSessionArtifactValidationError,
    mutate: (inout RecordingSessionArtifactReport) throws -> Void
) throws {
    var report = try recordingSessionPassCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private var recordingSessionArtifactRepositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
