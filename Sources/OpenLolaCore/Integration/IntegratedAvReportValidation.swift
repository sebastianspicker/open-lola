import Foundation

extension IntegratedAvReport: ReportValidationLifecycle {
    public func validate() throws {
        try validateLifecycle()
    }

    func validateIdentity() throws {
        try validateIntegratedFieldSet(
            nonEmpty: identityNonEmptyFields(),
            positiveDoubles: [IntegratedValidationField(name: "durationSeconds", value: durationSeconds)]
        )
    }

    func validateFields() throws {
        try validateRunWindow()
        try validateSync()
        try validateHeadless()
        try validateAudio()
        try validateVideo()
        try validateSystemLoad()
        try validateProof()
    }

    private func identityNonEmptyFields() -> [IntegratedValidationField<String>] {
        [
            IntegratedValidationField(name: "id", value: id),
            IntegratedValidationField(name: "title", value: title),
            IntegratedValidationField(name: "capturedAt", value: capturedAt),
            IntegratedValidationField(name: "notes", value: notes),
        ]
    }

    private func validateRunWindow() throws {
        guard let runWindow else {
            return
        }

        try validateIntegratedFieldSet(
            nonEmpty: runWindowNonEmptyFields(runWindow),
            positiveDoubles: [
                IntegratedValidationField(
                    name: "runWindow.audioVideoOverlapSeconds",
                    value: runWindow.audioVideoOverlapSeconds
                ),
            ]
        )
    }

    private func runWindowNonEmptyFields(
        _ runWindow: IntegratedAvRunWindowEvidence
    ) -> [IntegratedValidationField<String>] {
        [
            IntegratedValidationField(name: "runWindow.startedAt", value: runWindow.startedAt),
            IntegratedValidationField(name: "runWindow.endedAt", value: runWindow.endedAt),
        ]
    }

    private func validateSync() throws {
        // This is a structural integrated-AV policy check. Semantic audio clock stability
        // is proven by the subordinate audio benchmark/report referenced by this artifact.
        guard sync.masterClock == .audio else {
            throw IntegratedAvValidationError.audioMasterClockViolation(sync.masterClock)
        }
        if sync.audioMayBlockForVideo {
            throw IntegratedAvValidationError.audioMayBlockForVideo
        }
        if sync.videoMayChangeAudioPlayoutTarget {
            throw IntegratedAvValidationError.videoMayChangeAudioPlayoutTarget
        }
        guard sync.videoDegradesBeforeAudioImpact else {
            throw IntegratedAvValidationError.videoWithoutPreAudioImpactDegradation
        }
    }

    private func validateHeadless() throws {
        try validateIntegratedFieldSet(nonEmpty: headlessNonEmptyFields())
    }

    private func headlessNonEmptyFields() -> [IntegratedValidationField<String>] {
        [
            IntegratedValidationField(name: "headless.audioLaneOwner", value: headless.audioLaneOwner),
            IntegratedValidationField(name: "headless.videoLaneOwner", value: headless.videoLaneOwner),
        ]
    }

    private func validateAudio() throws {
        try validateIntegratedFieldSet(
            nonEmpty: [
                IntegratedValidationField(
                    name: "audio.baselineRouteReportId",
                    value: audio.baselineRouteReportId
                ),
            ],
            positiveInts: audioPositiveIntFields(),
            nonNegativeDoubles: audioNonNegativeDoubleFields()
        )
        try requireIntegratedPacketAge(audio.packetAge, "audio.packetAge")
        try validateIntegratedFieldSet(nonNegativeInts: audioNonNegativeIntFields())

        guard audio.baselineCallbackP99Microseconds <= audio.baselineCallbackMaxMicroseconds else {
            throw IntegratedAvValidationError.unorderedAudioCallbackMetrics("audio.baseline")
        }
        guard audio.integratedCallbackP99Microseconds <= audio.integratedCallbackMaxMicroseconds else {
            throw IntegratedAvValidationError.unorderedAudioCallbackMetrics("audio.integrated")
        }
    }

    private func audioNonNegativeDoubleFields() -> [IntegratedValidationField<Double>] {
        [
            IntegratedValidationField(
                name: "audio.baselineCallbackP99Microseconds",
                value: audio.baselineCallbackP99Microseconds
            ),
            IntegratedValidationField(
                name: "audio.integratedCallbackP99Microseconds",
                value: audio.integratedCallbackP99Microseconds
            ),
            IntegratedValidationField(
                name: "audio.baselineCallbackMaxMicroseconds",
                value: audio.baselineCallbackMaxMicroseconds
            ),
            IntegratedValidationField(
                name: "audio.integratedCallbackMaxMicroseconds",
                value: audio.integratedCallbackMaxMicroseconds
            ),
        ]
    }

    private func audioPositiveIntFields() -> [IntegratedValidationField<Int>] {
        [
            IntegratedValidationField(
                name: "audio.baselinePlayoutTargetFrames",
                value: audio.baselinePlayoutTargetFrames
            ),
            IntegratedValidationField(
                name: "audio.integratedPlayoutTargetFrames",
                value: audio.integratedPlayoutTargetFrames
            ),
        ]
    }

    private func audioNonNegativeIntFields() -> [IntegratedValidationField<Int>] {
        [
            IntegratedValidationField(name: "audio.lostPackets", value: audio.lostPackets),
            IntegratedValidationField(name: "audio.latePackets", value: audio.latePackets),
            IntegratedValidationField(name: "audio.underruns", value: audio.underruns),
        ]
    }

    private func validateVideo() throws {
        try validateIntegratedFieldSet(
            nonEmpty: videoNonEmptyFields(),
            positiveInts: videoPositiveIntFields(),
            positiveDoubles: [
                IntegratedValidationField(
                    name: "video.format.nominalFrameRate",
                    value: video.format.nominalFrameRate
                ),
            ]
        )
        if let deviceUniqueId = video.source.deviceUniqueId {
            try requireIntegratedNonEmpty(deviceUniqueId, "video.source.deviceUniqueId")
        }
        try requireIntegratedPacketAge(video.captureFrameAge, "video.captureFrameAge")
        try requireIntegratedPacketAge(video.transportFrameAge, "video.transportFrameAge")
        try validateIntegratedFieldSet(nonNegativeInts: videoReceiverNonNegativeIntFields())
        try validateVideoFrameTiming()
        try validateVideoRenderSync()
        guard !video.degradation.actions.isEmpty else {
            throw IntegratedAvValidationError.emptyList("video.degradation.actions")
        }
    }

    private func videoNonEmptyFields() -> [IntegratedValidationField<String>] {
        [
            IntegratedValidationField(name: "video.source.label", value: video.source.label),
            IntegratedValidationField(name: "video.source.permissionStatus", value: video.source.permissionStatus),
            IntegratedValidationField(name: "video.format.pixelFormat", value: video.format.pixelFormat),
        ]
    }

    private func videoPositiveIntFields() -> [IntegratedValidationField<Int>] {
        [
            IntegratedValidationField(name: "video.format.width", value: video.format.width),
            IntegratedValidationField(name: "video.format.height", value: video.format.height),
        ]
    }

    private func videoReceiverNonNegativeIntFields() -> [IntegratedValidationField<Int>] {
        [
            IntegratedValidationField(name: "video.captureDroppedFrames", value: video.captureDroppedFrames),
            IntegratedValidationField(name: "video.receiverDroppedFrames", value: video.receiverDroppedFrames),
            IntegratedValidationField(name: "video.receiverLateFrames", value: video.receiverLateFrames),
        ]
    }

    private func validateVideoFrameTiming() throws {
        try requireIntegratedNonNegative(video.frameTiming.firstFrameId, "video.frameTiming.firstFrameId")
        try requireIntegratedNonNegative(video.frameTiming.lastFrameId, "video.frameTiming.lastFrameId")
        try requireIntegratedNonNegative(
            video.frameTiming.firstFrameMonotonicNanoseconds,
            "video.frameTiming.firstFrameMonotonicNanoseconds"
        )
        try requireIntegratedNonNegative(
            video.frameTiming.lastFrameMonotonicNanoseconds,
            "video.frameTiming.lastFrameMonotonicNanoseconds"
        )
        try requireIntegratedNonNegative(
            video.frameTiming.nonMonotonicTimestampCount,
            "video.frameTiming.nonMonotonicTimestampCount"
        )
        try requireIntegratedNonNegative(
            video.frameTiming.duplicateFrameIdentityCount,
            "video.frameTiming.duplicateFrameIdentityCount"
        )
        guard video.frameTiming.firstFrameId <= video.frameTiming.lastFrameId else {
            throw IntegratedAvValidationError.invalidVideoFrameIdentityRange(
                firstFrameId: video.frameTiming.firstFrameId,
                lastFrameId: video.frameTiming.lastFrameId
            )
        }
        guard video.frameTiming.firstFrameMonotonicNanoseconds
            <= video.frameTiming.lastFrameMonotonicNanoseconds else {
            throw IntegratedAvValidationError.invalidVideoFrameTimestampRange(
                firstFrameMonotonicNanoseconds: video.frameTiming.firstFrameMonotonicNanoseconds,
                lastFrameMonotonicNanoseconds: video.frameTiming.lastFrameMonotonicNanoseconds
            )
        }
    }

    private func validateVideoRenderSync() throws {
        try requireIntegratedPositive(
            video.renderSync.staleFrameLimitMicroseconds,
            "video.renderSync.staleFrameLimitMicroseconds"
        )
        try requireIntegratedPacketAge(video.renderSync.renderedFrameAge, "video.renderSync.renderedFrameAge")
        try requireIntegratedNonNegative(video.renderSync.staleFramesDropped, "video.renderSync.staleFramesDropped")
        try requireIntegratedNonNegative(video.renderSync.staleFramesRendered, "video.renderSync.staleFramesRendered")
        try requireIntegratedNonNegative(video.renderSync.audioHoldEvents, "video.renderSync.audioHoldEvents")
    }

    private func validateSystemLoad() throws {
        try validateIntegratedFieldSet(
            nonNegativeDoubles: [
                IntegratedValidationField(
                    name: "systemLoad.networkMegabitsPerSecond",
                    value: systemLoad.networkMegabitsPerSecond
                ),
            ],
            percents: [
                IntegratedValidationField(name: "systemLoad.cpuP99Percent", value: systemLoad.cpuP99Percent),
                IntegratedValidationField(name: "systemLoad.gpuP99Percent", value: systemLoad.gpuP99Percent),
            ]
        )
    }

    private func validateProof() throws {
        guard let proof else {
            return
        }

        try validateIntegratedFieldSet(
            nonEmpty: proofNonEmptyFields(proof),
            optionalNonEmpty: proofOptionalNonEmptyFields(proof)
        )
        if proof.rmeAudioDeviceVisible {
            try requireIntegratedNonEmpty(proof.rmeAudioDeviceUid, "proof.rmeAudioDeviceUid")
        }
        if proof.oscPollingEnabled {
            try requireIntegratedNonEmpty(proof.oscControlReportId, "proof.oscControlReportId")
        }
        if proof.atemReadOnlyPollingEnabled {
            try requireIntegratedNonEmpty(proof.atemControlReportId, "proof.atemControlReportId")
        }
    }

    private func proofNonEmptyFields(
        _ proof: IntegratedProofEvidence
    ) -> [IntegratedValidationField<String>] {
        [
            IntegratedValidationField(
                name: "proof.audioOnlyBaselineReportId",
                value: proof.audioOnlyBaselineReportId
            ),
            IntegratedValidationField(name: "proof.integratedRunReportId", value: proof.integratedRunReportId),
        ]
    }

    private func proofOptionalNonEmptyFields(
        _ proof: IntegratedProofEvidence
    ) -> [IntegratedValidationField<String?>] {
        [
            IntegratedValidationField(
                name: "proof.audioRoutePacketCapturePoint",
                value: proof.audioRoutePacketCapturePoint
            ),
            IntegratedValidationField(name: "proof.videoCaptureReportId", value: proof.videoCaptureReportId),
            IntegratedValidationField(name: "proof.videoTransportReportId", value: proof.videoTransportReportId),
            IntegratedValidationField(
                name: "proof.videoTransportPacketCapturePoint",
                value: proof.videoTransportPacketCapturePoint
            ),
            IntegratedValidationField(name: "proof.videoPreviewReportId", value: proof.videoPreviewReportId),
        ]
    }

    func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
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
        try requireIntegratedPassProofText(
            proof.audioRoutePacketCapturePoint,
            field: "proof.audioRoutePacketCapturePoint",
            missing: .passWithoutAudioRoutePacketCapturePoint
        )
        guard proof.rmeAudioDeviceVisible && !proof.rmeAudioDeviceUid.isEmpty else {
            throw IntegratedAvValidationError.passWithoutRmeAudioDevice
        }
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
        guard audio.baselineVerdict == .pass else {
            throw IntegratedAvValidationError.passWithNonPassAudioBaseline(audio.baselineVerdict)
        }
        guard audio.integratedVerdict == .pass else {
            throw IntegratedAvValidationError.passWithNonPassIntegratedAudio(audio.integratedVerdict)
        }
        if headless.uiOwnsRealtimePaths {
            throw IntegratedAvValidationError.passWithUiRealtimeOwnership
        }
        guard video.degradation.triggeredBeforeAudioTargetChange else {
            throw IntegratedAvValidationError.passWithoutPreAudioDegradation
        }
        guard video.degradation.triggeredBeforeAudioOrRouteImpact == true else {
            throw IntegratedAvValidationError.videoWithoutPreAudioImpactDegradation
        }
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
