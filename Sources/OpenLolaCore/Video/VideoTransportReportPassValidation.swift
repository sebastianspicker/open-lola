// Validates VideoTransportReportPassValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
extension VideoTransportReport {
    func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        try validatePassTransportAndDegradation()
        let routeEvidence = try passRouteEvidence()
        try validatePassCodecBaseline(routeEvidence)
        try validatePassFragmentation()
        try validatePassReassembly()
        try validatePassRenderOutput()
        try validatePassBlackmagicOutput()
        try validatePassAudioRouteVerdicts(routeEvidence)
        try validatePassAudioImpact()
        try validatePassAudioPriorityProtection()
        try validatePassAVSync()
    }

    func validatePassTransportAndDegradation() throws {
        if transport.reliableRetransmission {
            throw VideoTransportValidationError.passUsesReliableRetransmission
        }
        guard degradation.triggeredBeforeAudioTargetChange else {
            throw VideoTransportValidationError.passWithoutPreAudioDegradation
        }
        guard degradation.triggeredBeforeAudioOrRouteImpact == true else {
            throw VideoTransportValidationError.passWithoutPreAudioOrRouteDegradation
        }
    }

    func passRouteEvidence() throws -> VideoTransportRouteEvidence {
        guard let routeEvidence, routeEvidence.isPhysicalRoute else {
            throw VideoTransportValidationError.passWithoutPhysicalRouteEvidence
        }
        return routeEvidence
    }

    func validatePassCodecBaseline(_ routeEvidence: VideoTransportRouteEvidence) throws {
        if !isRawOrIntraFrameTransportMode(transport.mode) {
            guard let baselineMode = routeEvidence.rawOrIntraFrameBaselineMode,
                  isRawOrIntraFrameTransportMode(baselineMode),
                  routeEvidence.rawOrIntraFrameBaselineReportId?.isEmpty == false else {
                throw VideoTransportValidationError.passWithoutRawOrIntraFrameRouteBaseline
            }
            guard transport.videoToolboxAvailable else {
                throw VideoTransportValidationError.passWithoutVideoToolboxAvailability
            }
            guard transport.videoToolboxRealtimeMode else {
                throw VideoTransportValidationError.passWithoutVideoToolboxRealtimeMode
            }
            guard !transport.frameReorderingAllowed else {
                throw VideoTransportValidationError.passAllowsVideoToolboxFrameReordering
            }
            guard transport.encoderQueueDepth <= 1 else {
                throw VideoTransportValidationError.passWithEncoderQueueDepth(transport.encoderQueueDepth)
            }
        }
    }

    func validatePassFragmentation() throws {
        guard let fragmentation else {
            throw VideoTransportValidationError.passWithoutFragmentationMetrics
        }
        guard transmitted.framesSent > 0, transmitted.packetsSent > 0 else {
            throw VideoTransportValidationError.passWithoutTransmittedFrames
        }
        guard transmitted.framesDroppedBeforeSend == 0, transmitted.packetsDropped == 0 else {
            throw VideoTransportValidationError.passWithTransportDrops(
                frames: transmitted.framesDroppedBeforeSend,
                packets: transmitted.packetsDropped
            )
        }
        if fragmentation.maxPayloadBytesPerFragment > transport.maxPacketBytes {
            throw VideoTransportValidationError.passWithOversizedFragmentPayload(
                payloadBytes: fragmentation.maxPayloadBytesPerFragment,
                maxPacketBytes: transport.maxPacketBytes
            )
        }
        if fragmentation.framesFragmented != transmitted.framesSent {
            throw VideoTransportValidationError.passWithFragmentedFrameMismatch(
                expected: transmitted.framesSent,
                actual: fragmentation.framesFragmented
            )
        }
    }

    func validatePassReassembly() throws {
        guard let reassembly else {
            throw VideoTransportValidationError.passWithoutReassemblyMetrics
        }
        if reassembly.framesReassembled != receiver.receivedFrames {
            throw VideoTransportValidationError.passWithReassembledFrameMismatch(
                expected: receiver.receivedFrames,
                actual: reassembly.framesReassembled
            )
        }
        if reassembly.framesDroppedIncomplete > 0 || reassembly.missingFragments > 0 {
            throw VideoTransportValidationError.passWithIncompleteReassembly
        }
    }

    func validatePassRenderOutput() throws {
        guard let renderOutput else {
            throw VideoTransportValidationError.passWithoutRenderOutputMetrics
        }
        guard renderOutput.framesOutput > 0 else {
            throw VideoTransportValidationError.passWithoutRenderedOutputFrames
        }
        if renderOutput.framesDroppedLate > 0
            || renderOutput.framesDroppedBackpressure > 0
            || renderOutput.framesDroppedContinuity > 0 {
            throw VideoTransportValidationError.passWithRenderOutputDrops
        }
    }

    func validatePassBlackmagicOutput() throws {
        guard let blackmagicOutput, blackmagicOutput.hasPhysicalOutputEvidence else {
            throw VideoTransportValidationError.passWithoutBlackmagicOutputEvidence
        }
    }

    func validatePassAudioRouteVerdicts(_ routeEvidence: VideoTransportRouteEvidence) throws {
        guard routeEvidence.baselineAudioRouteVerdict == .pass else {
            throw VideoTransportValidationError.passWithNonPassBaselineRouteVerdict(
                routeEvidence.baselineAudioRouteVerdict
            )
        }
        guard routeEvidence.baselineAudioRouteVerdict == routeEvidence.videoActiveAudioRouteVerdict else {
            throw VideoTransportValidationError.passChangesAudioRouteVerdict(
                baseline: routeEvidence.baselineAudioRouteVerdict,
                videoActive: routeEvidence.videoActiveAudioRouteVerdict
            )
        }
    }

    func validatePassAudioImpact() throws {
        if audioImpact.videoCallbackP99Microseconds > audioImpact.baselineCallbackP99Microseconds {
            throw VideoTransportValidationError.passIncreasesAudioP99(
                baseline: audioImpact.baselineCallbackP99Microseconds,
                video: audioImpact.videoCallbackP99Microseconds
            )
        }
        if audioImpact.videoCallbackMaxMicroseconds > audioImpact.baselineCallbackMaxMicroseconds {
            throw VideoTransportValidationError.passIncreasesAudioMax(
                baseline: audioImpact.baselineCallbackMaxMicroseconds,
                video: audioImpact.videoCallbackMaxMicroseconds
            )
        }
        if audioImpact.videoPlayoutTargetFrames != audioImpact.baselinePlayoutTargetFrames {
            throw VideoTransportValidationError.passChangesAudioPlayoutTarget(
                baseline: audioImpact.baselinePlayoutTargetFrames,
                video: audioImpact.videoPlayoutTargetFrames
            )
        }
        if audioImpact.underruns > 0 {
            throw VideoTransportValidationError.passWithUnderruns(audioImpact.underruns)
        }
        if audioImpact.hiddenAudioImpactDetected {
            throw VideoTransportValidationError.passWithHiddenAudioImpact
        }
    }

    func validatePassAudioPriorityProtection() throws {
        guard let multiVideo,
              multiVideo.audioPriorityEvidence == .measured,
              let audioPriorityProtected = multiVideo.audioPriorityProtected else {
            throw VideoTransportValidationError.passWithoutMeasuredAudioPriorityProtection
        }
        guard audioPriorityProtected else {
            throw VideoTransportValidationError.passWithUnprotectedAudioPriority
        }
    }

    func validatePassAVSync() throws {
        guard avSync != nil else {
            throw VideoTransportValidationError.passWithoutAVSyncTimingMetrics
        }
    }

    func validatePacketAge(_ metrics: UdpPcmPacketAgeMetrics, _ field: String) throws {
        try validateVideoPacketAge(metrics, field: field)
    }
}
