// Verifies that recording session run configuration rejects invalid arguments.
import Foundation
import Dispatch
import Testing

@testable import OpenLolaCore

@Test
// swiftlint:disable:next function_body_length
func recordingSessionRunConfigurationRejectsInvalidArguments() {
    #expect(throws: RecordingSessionRunConfigurationError.unknownArgument("--unexpected")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session",
            "--report", "reports/m14-recording-session.json",
            "--unexpected", "value"
        ])
    }

    #expect(throws: RecordingSessionRunConfigurationError.duplicateArgument("--report")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session",
            "--report", "reports/m14-recording-session.json",
            "--report", "reports/duplicate.json"
        ])
    }

    #expect(throws: RecordingSessionRunConfigurationError.missingRequiredArgument("--audio-input-uid")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session",
            "--report", "reports/m14-recording-session.json",
            "--record-audio", "on",
            "--sample-rate", "48000",
            "--frames", "32",
            "--channels", "2"
        ])
    }

    #expect(throws: RecordingSessionRunConfigurationError.missingRequiredArgument("--video-device-id")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session",
            "--report", "reports/m14-recording-session.json",
            "--record-video", "on"
        ])
    }

    #expect(throws: RecordingSessionRunConfigurationError.missingRequiredArgument("--frame-rate")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session",
            "--report", "reports/m14-recording-session.json",
            "--record-video", "on",
            "--video-device-id", "auto"
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
            "--frame-rate", "30"
        ])
    }

    #expect(throws: RecordingSessionRunConfigurationError.audioArgumentRequiresAudioMode("--input-channels")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session",
            "--report", "reports/m14-recording-session.json",
            "--input-channels", "0,1"
        ])
    }

    #expect(throws: RecordingSessionRunConfigurationError.videoArgumentRequiresVideoMode("--frame-rate")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session",
            "--report", "reports/m14-recording-session.json",
            "--frame-rate", "30"
        ])
    }

    #expect(throws: RecordingSessionRunConfigurationError.missingRequiredArgument("--report")) {
        _ = try RecordingSessionRunConfiguration.parse([
            "--integrated-baseline", "reports/m10-integrated-av.json",
            "--duration-seconds", "30",
            "--output-dir", "reports/m14-session"
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
                RecordingSessionArtifactPayload(kind: .gapLog, relativePath: "manifest.json/child", data: Data([2]))
            ]
        )
    }

    #expect(!FileManager.default.fileExists(atPath: outputDirectory.path))
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: parent.path)
        .filter { $0.hasPrefix(prefix) }
    #expect(leftovers.isEmpty)
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

func recordingSessionPassCandidateReport() throws -> RecordingSessionArtifactReport {
    var report = try loadJSONFixture(
        named: "recording-session-partial",
        fixtureDirectory: "RecordingSessionArtifacts",
        decode: RecordingSessionArtifactReport.decode(from:)
    )
    report.verdict = .pass
    report.runMode = .measured
    report.writerPressure.simulatedSlowWriter = true
    return report
}

private var recordingSessionArtifactRepositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
