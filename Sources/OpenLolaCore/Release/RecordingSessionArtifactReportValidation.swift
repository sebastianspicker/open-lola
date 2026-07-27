// Validates RecordingSessionArtifactReportValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension RecordingSessionArtifactReport {
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
        try RecordingSessionArtifactValidator.requirePositive(
            sideLane.boundedQueueCapacityChunks,
            "sideLane.boundedQueueCapacityChunks"
        )
    }

    private func validateCapture() throws {
        if capture.audio.mode == .on {
            let channelCount = capture.audio.channelCount ?? 0
            try RecordingSessionArtifactValidator.requireNonEmpty(
                capture.audio.inputUID ?? "",
                "capture.audio.inputUID"
            )
            try RecordingSessionArtifactValidator.requirePositive(
                capture.audio.sampleRateHertz ?? 0,
                "capture.audio.sampleRateHertz"
            )
            try RecordingSessionArtifactValidator.requirePositive(
                capture.audio.framesPerBuffer ?? 0,
                "capture.audio.framesPerBuffer"
            )
            try RecordingSessionArtifactValidator.requirePositive(channelCount, "capture.audio.channelCount")
            guard capture.audio.inputChannels.count == channelCount else {
                throw RecordingSessionArtifactValidationError.emptyList("capture.audio.inputChannels")
            }
        }
        if capture.video.mode == .on {
            try RecordingSessionArtifactValidator.requireNonEmpty(
                capture.video.deviceID ?? "",
                "capture.video.deviceID"
            )
            try RecordingSessionArtifactValidator.requirePositive(Int(capture.video.streamID), "capture.video.streamID")
            try RecordingSessionArtifactValidator.requirePositive(capture.video.frameRate, "capture.video.frameRate")
            try RecordingSessionArtifactValidator.requirePositive(capture.video.queueDepth, "capture.video.queueDepth")
        }
    }

    private func validateWriterPressure() throws {
        try RecordingSessionArtifactValidator.requirePositive(
            writerPressure.producedChunkCount,
            "writerPressure.producedChunkCount"
        )
        try RecordingSessionArtifactValidator.requireNonNegative(
            writerPressure.writtenChunkCount,
            "writerPressure.writtenChunkCount"
        )
        try RecordingSessionArtifactValidator.requireNonNegative(
            writerPressure.droppedChunkCount,
            "writerPressure.droppedChunkCount"
        )
        try RecordingSessionArtifactValidator.requireNonNegative(
            writerPressure.gapMarkerCount,
            "writerPressure.gapMarkerCount"
        )
        try RecordingSessionArtifactValidator.requireNonNegative(
            writerPressure.maxQueuedChunks,
            "writerPressure.maxQueuedChunks"
        )
        try RecordingSessionArtifactValidator.requireNonNegative(
            writerPressure.writerStallCount,
            "writerPressure.writerStallCount"
        )
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
        try RecordingSessionArtifactValidator.requirePositive(
            mediaImpact.baselinePlayoutTargetFrames,
            "mediaImpact.baselinePlayoutTargetFrames"
        )
        try RecordingSessionArtifactValidator.requirePositive(
            mediaImpact.recordingPlayoutTargetFrames,
            "mediaImpact.recordingPlayoutTargetFrames"
        )
        try RecordingSessionArtifactValidator.requireNonNegative(
            mediaImpact.audioUnderruns,
            "mediaImpact.audioUnderruns"
        )
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
        try RecordingSessionArtifactValidator.requirePositive(
            videoArtifact.framesWritten,
            "videoArtifact.framesWritten"
        )
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
        guard writerPressure.droppedChunkCount > 0,
              writerPressure.gapMarkerCount >= writerPressure.droppedChunkCount else {
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
