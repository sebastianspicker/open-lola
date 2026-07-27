// Validates IntegratedAvPassReportValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension IntegratedAvReport {
    func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        let proof = try validatePassRunEvidence()
        try validatePassProofIdentity(proof)
        try validatePassProofAudio(proof)
        try validatePassProofVideo(proof)
        try validatePassProofControl(proof)
        try validatePassRouteVerdicts(proof)
        try validatePassAudioVerdicts()
        try validatePassHeadlessAndDegradation()
        try validatePassVideoTiming()
        try validatePassAudioPerformance()
    }

    private func validatePassRunEvidence() throws -> IntegratedProofEvidence {
        guard runMode == .measured else {
            throw IntegratedAvValidationError.passWithoutMeasuredRun
        }
        if durationSeconds < Self.minimumPassDurationSeconds {
            throw IntegratedAvValidationError.passRunTooShort(
                seconds: durationSeconds,
                minimumSeconds: Self.minimumPassDurationSeconds
            )
        }
        guard let runWindow else {
            throw IntegratedAvValidationError.passWithoutRunWindow
        }
        if runWindow.audioVideoOverlapSeconds < Self.minimumPassDurationSeconds {
            throw IntegratedAvValidationError.passWithInsufficientAudioVideoOverlap(
                seconds: runWindow.audioVideoOverlapSeconds,
                minimumSeconds: Self.minimumPassDurationSeconds
            )
        }
        guard let proof else {
            throw IntegratedAvValidationError.passWithoutP04Proof
        }
        return proof
    }

    private func validatePassProofIdentity(_ proof: IntegratedProofEvidence) throws {
        guard proof.audioOnlyBaselineFirst else {
            throw IntegratedAvValidationError.passWithoutAudioOnlyBaselineFirst
        }
        guard proof.audioOnlyBaselineReportId == audio.baselineRouteReportId else {
            throw IntegratedAvValidationError.passWithAudioBaselineReportMismatch(
                expected: audio.baselineRouteReportId,
                actual: proof.audioOnlyBaselineReportId
            )
        }
        guard proof.integratedRunReportId == id else {
            throw IntegratedAvValidationError.passWithIntegratedRunReportMismatch(
                expected: id,
                actual: proof.integratedRunReportId
            )
        }
        try requireIntegratedPassProofText(
            proof.audioOnlyBaselineReportId,
            field: "proof.audioOnlyBaselineReportId",
            missing: .emptyField("proof.audioOnlyBaselineReportId")
        )
        try requireIntegratedPassProofText(
            proof.integratedRunReportId,
            field: "proof.integratedRunReportId",
            missing: .emptyField("proof.integratedRunReportId")
        )
    }

    private func validatePassProofAudio(_ proof: IntegratedProofEvidence) throws {
        try requireIntegratedPassProofText(
            proof.audioRoutePacketCapturePoint,
            field: "proof.audioRoutePacketCapturePoint",
            missing: .passWithoutAudioRoutePacketCapturePoint
        )
        guard proof.rmeAudioDeviceVisible && !proof.rmeAudioDeviceUid.isEmpty else {
            throw IntegratedAvValidationError.passWithoutRmeAudioDevice
        }
    }

    private func validatePassProofVideo(_ proof: IntegratedProofEvidence) throws {
        guard proof.videoCaptureEnabled else {
            throw IntegratedAvValidationError.passWithoutVideoCapture
        }
        try requireIntegratedPassProofText(
            proof.videoCaptureReportId,
            field: "proof.videoCaptureReportId",
            missing: .passWithoutVideoCaptureReportId
        )
        guard proof.videoTransportEnabled || proof.videoPreviewEnabled else {
            throw IntegratedAvValidationError.passWithoutVideoTransportOrPreview
        }
        if proof.videoTransportEnabled {
            try requireIntegratedPassProofText(
                proof.videoTransportReportId,
                field: "proof.videoTransportReportId",
                missing: .passWithoutVideoTransportReportId
            )
            try requireIntegratedPassProofText(
                proof.videoTransportPacketCapturePoint,
                field: "proof.videoTransportPacketCapturePoint",
                missing: .passWithoutVideoTransportPacketCapturePoint
            )
        }
        if proof.videoPreviewEnabled {
            try requireIntegratedPassProofText(
                proof.videoPreviewReportId,
                field: "proof.videoPreviewReportId",
                missing: .passWithoutVideoPreviewReportId
            )
        }
    }

    private func validatePassProofControl(_ proof: IntegratedProofEvidence) throws {
        guard proof.oscPollingEnabled else {
            throw IntegratedAvValidationError.passWithoutOscPolling
        }
        try requireIntegratedPassProofText(
            proof.oscControlReportId,
            field: "proof.oscControlReportId",
            missing: .emptyField("proof.oscControlReportId")
        )
        guard proof.atemReadOnlyPollingEnabled else {
            throw IntegratedAvValidationError.passWithoutAtemReadOnlyPolling
        }
        try requireIntegratedPassProofText(
            proof.atemControlReportId,
            field: "proof.atemControlReportId",
            missing: .emptyField("proof.atemControlReportId")
        )
        if proof.atemArmedCommandsAllowed {
            throw IntegratedAvValidationError.passWithAtemCommandsArmed
        }
    }

    private func validatePassRouteVerdicts(_ proof: IntegratedProofEvidence) throws {
        guard proof.baselineRouteVerdict == proof.integratedRouteVerdict else {
            throw IntegratedAvValidationError.passChangesAudioRouteVerdict(
                baseline: proof.baselineRouteVerdict,
                integrated: proof.integratedRouteVerdict
            )
        }
        guard proof.baselineRouteVerdict == .pass && proof.integratedRouteVerdict == .pass else {
            throw IntegratedAvValidationError.passWithNonPassAudioRouteVerdict(
                baseline: proof.baselineRouteVerdict,
                integrated: proof.integratedRouteVerdict
            )
        }
    }

    private func validatePassAudioVerdicts() throws {
        guard audio.baselineVerdict == .pass else {
            throw IntegratedAvValidationError.passWithNonPassAudioBaseline(audio.baselineVerdict)
        }
        guard audio.integratedVerdict == .pass else {
            throw IntegratedAvValidationError.passWithNonPassIntegratedAudio(audio.integratedVerdict)
        }
    }

    private func validatePassHeadlessAndDegradation() throws {
        if headless.uiOwnsRealtimePaths {
            throw IntegratedAvValidationError.passWithUiRealtimeOwnership
        }
        guard video.degradation.triggeredBeforeAudioTargetChange else {
            throw IntegratedAvValidationError.passWithoutPreAudioDegradation
        }
        guard video.degradation.triggeredBeforeAudioOrRouteImpact == true else {
            throw IntegratedAvValidationError.videoWithoutPreAudioImpactDegradation
        }
    }

    private func validatePassVideoTiming() throws {
        if video.frameTiming.nonMonotonicTimestampCount > 0 {
            throw IntegratedAvValidationError.passWithNonMonotonicVideoFrameTiming(
                video.frameTiming.nonMonotonicTimestampCount
            )
        }
        if video.frameTiming.duplicateFrameIdentityCount > 0 {
            throw IntegratedAvValidationError.passWithDuplicateVideoFrameIdentities(
                video.frameTiming.duplicateFrameIdentityCount
            )
        }
        if video.renderSync.renderedFrameAge.maxMicroseconds > video.renderSync.staleFrameLimitMicroseconds {
            throw IntegratedAvValidationError.passWithStaleVideoRendered(
                maxAgeMicroseconds: video.renderSync.renderedFrameAge.maxMicroseconds,
                limitMicroseconds: video.renderSync.staleFrameLimitMicroseconds
            )
        }
        if video.renderSync.staleFramesRendered > 0 {
            throw IntegratedAvValidationError.passWithRenderedStaleVideoFrames(
                video.renderSync.staleFramesRendered
            )
        }
        if video.renderSync.audioHoldEvents > 0 {
            throw IntegratedAvValidationError.passWithAudioHoldForVideoEvents(
                video.renderSync.audioHoldEvents
            )
        }
    }

    private func validatePassAudioPerformance() throws {
        if audio.integratedCallbackP99Microseconds > audio.baselineCallbackP99Microseconds {
            throw IntegratedAvValidationError.passIncreasesAudioP99(
                baseline: audio.baselineCallbackP99Microseconds,
                integrated: audio.integratedCallbackP99Microseconds
            )
        }
        if audio.integratedCallbackMaxMicroseconds > audio.baselineCallbackMaxMicroseconds {
            throw IntegratedAvValidationError.passIncreasesAudioMax(
                baseline: audio.baselineCallbackMaxMicroseconds,
                integrated: audio.integratedCallbackMaxMicroseconds
            )
        }
        if audio.integratedPlayoutTargetFrames != audio.baselinePlayoutTargetFrames {
            throw IntegratedAvValidationError.passChangesAudioPlayoutTarget(
                baseline: audio.baselinePlayoutTargetFrames,
                integrated: audio.integratedPlayoutTargetFrames
            )
        }
        if audio.lostPackets > 0 || audio.latePackets > 0 {
            throw IntegratedAvValidationError.passWithAudioLossOrLatePackets
        }
        if audio.underruns > 0 {
            throw IntegratedAvValidationError.passWithUnderruns(audio.underruns)
        }
        if audio.hiddenPlayoutGrowthDetected {
            throw IntegratedAvValidationError.passWithHiddenPlayoutGrowth
        }
    }
}
