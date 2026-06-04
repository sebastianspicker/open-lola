import Foundation

public struct VideoTransportReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var durationSeconds: Double
    public var source: VideoSourceDescription
    public var format: VideoCaptureFormat
    public var transport: VideoTransportProfile
    public var routeEvidence: VideoTransportRouteEvidence?
    public var fragmentation: VideoFragmentationMetrics?
    public var reassembly: VideoReassemblyMetrics?
    public var renderOutput: VideoRenderOutputMetrics?
    public var blackmagicOutput: BlackmagicOutputBoundaryReport?
    public var multiVideo: MultiVideoTransportMetrics?
    public var avSync: AVSyncTimingMetrics?
    public var transmitted: VideoTransmittedMetrics
    public var receiver: VideoReceiverMetrics
    public var frameAge: UdpPcmPacketAgeMetrics
    public var performanceCounters: VideoTransportPerformanceCounters?
    public var degradation: VideoDegradationPolicy
    public var audioImpact: VideoAudioImpactMetrics
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        durationSeconds: Double,
        source: VideoSourceDescription,
        format: VideoCaptureFormat,
        transport: VideoTransportProfile,
        routeEvidence: VideoTransportRouteEvidence? = nil,
        fragmentation: VideoFragmentationMetrics? = nil,
        reassembly: VideoReassemblyMetrics? = nil,
        renderOutput: VideoRenderOutputMetrics? = nil,
        blackmagicOutput: BlackmagicOutputBoundaryReport? = nil,
        multiVideo: MultiVideoTransportMetrics? = nil,
        avSync: AVSyncTimingMetrics? = nil,
        transmitted: VideoTransmittedMetrics,
        receiver: VideoReceiverMetrics,
        frameAge: UdpPcmPacketAgeMetrics,
        performanceCounters: VideoTransportPerformanceCounters? = nil,
        degradation: VideoDegradationPolicy,
        audioImpact: VideoAudioImpactMetrics,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.durationSeconds = durationSeconds
        self.source = source
        self.format = format
        self.transport = transport
        self.routeEvidence = routeEvidence
        self.fragmentation = fragmentation
        self.reassembly = reassembly
        self.renderOutput = renderOutput
        self.blackmagicOutput = blackmagicOutput
        self.multiVideo = multiVideo
        self.avSync = avSync
        self.transmitted = transmitted
        self.receiver = receiver
        self.frameAge = frameAge
        self.performanceCounters = performanceCounters
        self.degradation = degradation
        self.audioImpact = audioImpact
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> VideoTransportReport {
        try JSONDecoder().decode(VideoTransportReport.self, from: data)
    }

    public func validate() throws {
        try validateIdentity()
        try validateSourceAndFormat()
        try validateTransport()
        try validateRouteEvidence()
        try validateFragmentation()
        try validateReassembly()
        try validateRenderOutput()
        try validateBlackmagicOutput()
        try multiVideo?.validate()
        try avSync?.validate()
        try validateMetrics()
        try validatePerformanceCounters()
        try validateAudioImpact()
        try validatePassVerdict()
    }

    private func validateIdentity() throws {
        try VideoTransportValidator.requireNonEmpty(id, "id")
        try VideoTransportValidator.requireNonEmpty(title, "title")
        try VideoTransportValidator.requireNonEmpty(capturedAt, "capturedAt")
        try VideoTransportValidator.requireNonEmpty(notes, "notes")
        try VideoTransportValidator.requirePositive(durationSeconds, "durationSeconds")
    }

    private func validateSourceAndFormat() throws {
        try VideoTransportValidator.requireNonEmpty(source.label, "source.label")
        try VideoTransportValidator.requireNonEmpty(source.permissionStatus, "source.permissionStatus")
        if let deviceUniqueId = source.deviceUniqueId {
            try VideoTransportValidator.requireNonEmpty(deviceUniqueId, "source.deviceUniqueId")
        }
        try VideoTransportValidator.requirePositive(format.width, "format.width")
        try VideoTransportValidator.requirePositive(format.height, "format.height")
        try VideoTransportValidator.requirePositive(format.nominalFrameRate, "format.nominalFrameRate")
        try VideoTransportValidator.requireNonEmpty(format.pixelFormat, "format.pixelFormat")
    }

    private func validateTransport() throws {
        try VideoTransportValidator.requireNonEmpty(transport.networkProtocol, "transport.networkProtocol")
        try VideoTransportValidator.requireNonEmpty(transport.payloadFormat, "transport.payloadFormat")
        try VideoTransportValidator.requirePositive(transport.maxPacketBytes, "transport.maxPacketBytes")
        try VideoTransportValidator.requirePositive(transport.encoderQueueDepth, "transport.encoderQueueDepth")
    }

    private func validateRouteEvidence() throws {
        guard let routeEvidence else {
            return
        }
        try VideoTransportValidator.requireNonEmpty(routeEvidence.routeLabel, "routeEvidence.routeLabel")
        try VideoTransportValidator.requireNonEmpty(routeEvidence.packetCapturePoint, "routeEvidence.packetCapturePoint")
        if let baselineReportId = routeEvidence.rawOrIntraFrameBaselineReportId {
            try VideoTransportValidator.requireNonEmpty(
                baselineReportId,
                "routeEvidence.rawOrIntraFrameBaselineReportId"
            )
        }
    }

    private func validateFragmentation() throws {
        guard let fragmentation else {
            return
        }
        try VideoTransportValidator.requirePositive(fragmentation.framesFragmented, "fragmentation.framesFragmented")
        try VideoTransportValidator.requirePositive(fragmentation.fragmentsSent, "fragmentation.fragmentsSent")
        try VideoTransportValidator.requirePositive(fragmentation.maxFragmentsPerFrame, "fragmentation.maxFragmentsPerFrame")
        try VideoTransportValidator.requirePositive(
            fragmentation.maxPayloadBytesPerFragment,
            "fragmentation.maxPayloadBytesPerFragment"
        )
    }

    private func validateReassembly() throws {
        guard let reassembly else {
            return
        }
        try VideoTransportValidator.requireNonNegative(reassembly.framesReassembled, "reassembly.framesReassembled")
        try VideoTransportValidator.requireNonNegative(
            reassembly.framesDroppedIncomplete,
            "reassembly.framesDroppedIncomplete"
        )
        try VideoTransportValidator.requireNonNegative(reassembly.missingFragments, "reassembly.missingFragments")
        try VideoTransportValidator.requireNonNegative(reassembly.lateFragments, "reassembly.lateFragments")
        try VideoTransportValidator.requireNonNegative(reassembly.duplicateFragments, "reassembly.duplicateFragments")
        try VideoTransportValidator.requireNonNegative(reassembly.activeFramesPeak, "reassembly.activeFramesPeak")
    }

    private func validateRenderOutput() throws {
        guard let renderOutput else {
            return
        }
        try VideoTransportValidator.requireNonNegative(renderOutput.framesSubmitted, "renderOutput.framesSubmitted")
        try VideoTransportValidator.requireNonNegative(renderOutput.framesRendered, "renderOutput.framesRendered")
        try VideoTransportValidator.requireNonNegative(renderOutput.framesOutput, "renderOutput.framesOutput")
        try VideoTransportValidator.requireNonNegative(renderOutput.framesDroppedLate, "renderOutput.framesDroppedLate")
        try VideoTransportValidator.requireNonNegative(
            renderOutput.framesDroppedBackpressure,
            "renderOutput.framesDroppedBackpressure"
        )
        try VideoTransportValidator.requireNonNegative(
            renderOutput.framesDroppedContinuity,
            "renderOutput.framesDroppedContinuity"
        )
        try VideoTransportValidator.requireNonNegative(renderOutput.observedQueueDepth, "renderOutput.observedQueueDepth")
        if renderOutput.framesOutput > renderOutput.framesRendered {
            throw VideoTransportValidationError.renderOutputAccountingMismatch(
                expectedMaximumOutput: renderOutput.framesRendered,
                actualOutput: renderOutput.framesOutput
            )
        }
        let accountedFrames = renderOutput.framesRendered
            + renderOutput.framesDroppedLate
            + renderOutput.framesDroppedBackpressure
            + renderOutput.framesDroppedContinuity
        if accountedFrames > renderOutput.framesSubmitted {
            throw VideoTransportValidationError.renderOutputDropAccountingMismatch(
                expectedMaximumSubmitted: renderOutput.framesSubmitted,
                actualAccounted: accountedFrames
            )
        }
        try validatePacketAge(renderOutput.receiveToReassembly, "renderOutput.receiveToReassembly")
        try validatePacketAge(renderOutput.reassemblyToRender, "renderOutput.reassemblyToRender")
        try validatePacketAge(renderOutput.renderToOutput, "renderOutput.renderToOutput")
    }

    private func validateBlackmagicOutput() throws {
        guard let blackmagicOutput else {
            return
        }
        try VideoTransportValidator.requireNonEmpty(blackmagicOutput.notes, "blackmagicOutput.notes")
        if !blackmagicOutput.hasPhysicalOutputEvidence {
            let limitationText = "\(blackmagicOutput.notes) \(blackmagicOutput.outputLimitationSummary)".lowercased()
            guard limitationText.contains("partial"),
                  limitationText.contains("decklink output"),
                  limitationText.contains("unavailable") || limitationText.contains("not implemented") else {
                throw VideoTransportValidationError.passWithoutBlackmagicOutputEvidence
            }
        }
    }

    private func validateMetrics() throws {
        try VideoTransportValidator.requirePositive(transmitted.framesSent, "transmitted.framesSent")
        try VideoTransportValidator.requireNonNegative(
            transmitted.framesDroppedBeforeSend,
            "transmitted.framesDroppedBeforeSend"
        )
        try VideoTransportValidator.requirePositive(transmitted.packetsSent, "transmitted.packetsSent")
        try VideoTransportValidator.requireNonNegative(transmitted.packetsDropped, "transmitted.packetsDropped")

        try VideoTransportValidator.requireNonNegative(receiver.receivedFrames, "receiver.receivedFrames")
        try VideoTransportValidator.requirePositive(receiver.displayedFrames, "receiver.displayedFrames")
        try VideoTransportValidator.requireNonNegative(receiver.droppedFrames, "receiver.droppedFrames")
        try VideoTransportValidator.requireNonNegative(receiver.lateFrames, "receiver.lateFrames")
        try VideoTransportValidator.requireNonNegative(receiver.observedQueueDepth, "receiver.observedQueueDepth")

        let expectedReceived = max(0, transmitted.framesSent - transmitted.framesDroppedBeforeSend)
        if receiver.receivedFrames != expectedReceived {
            throw VideoTransportValidationError.packetAccountingMismatch(
                expectedReceived: expectedReceived,
                actualReceived: receiver.receivedFrames
            )
        }
        let expectedDisplayed = max(0, receiver.receivedFrames - receiver.droppedFrames)
        if receiver.displayedFrames != expectedDisplayed {
            throw VideoTransportValidationError.receiverAccountingMismatch(
                expectedDisplayed: expectedDisplayed,
                actualDisplayed: receiver.displayedFrames
            )
        }

        try VideoTransportValidator.requireNonNegative(frameAge.p50Microseconds, "frameAge.p50Microseconds")
        try VideoTransportValidator.requireNonNegative(frameAge.p95Microseconds, "frameAge.p95Microseconds")
        try VideoTransportValidator.requireNonNegative(frameAge.p99Microseconds, "frameAge.p99Microseconds")
        try VideoTransportValidator.requireNonNegative(frameAge.maxMicroseconds, "frameAge.maxMicroseconds")
        guard frameAge.p50Microseconds <= frameAge.p95Microseconds,
              frameAge.p95Microseconds <= frameAge.p99Microseconds,
              frameAge.p99Microseconds <= frameAge.maxMicroseconds else {
            throw VideoTransportValidationError.unorderedFrameAge
        }
        guard !degradation.actions.isEmpty else {
            throw VideoTransportValidationError.emptyList("degradation.actions")
        }
    }

    private func validatePerformanceCounters() throws {
        guard let performanceCounters else {
            return
        }
        try validatePerformanceCounter(
            performanceCounters.packetizationDuration,
            "performanceCounters.packetizationDuration"
        )
        try validatePerformanceCounter(
            performanceCounters.reassemblyDuration,
            "performanceCounters.reassemblyDuration"
        )
        try validatePacketAge(performanceCounters.frameAge, "performanceCounters.frameAge")
        try VideoTransportValidator.requireNonNegative(
            performanceCounters.queueDepthFrames,
            "performanceCounters.queueDepthFrames"
        )
    }

    private func validatePerformanceCounter(
        _ counter: PerformanceCounterSummary,
        _ field: String
    ) throws {
        try VideoTransportValidator.requireNonNegative(counter.sampleCount, "\(field).sampleCount")
        try VideoTransportValidator.requireNonNegative(counter.p50Microseconds, "\(field).p50Microseconds")
        try VideoTransportValidator.requireNonNegative(counter.p95Microseconds, "\(field).p95Microseconds")
        try VideoTransportValidator.requireNonNegative(counter.p99Microseconds, "\(field).p99Microseconds")
        try VideoTransportValidator.requireNonNegative(counter.maxMicroseconds, "\(field).maxMicroseconds")
        guard counter.p50Microseconds <= counter.p95Microseconds,
              counter.p95Microseconds <= counter.p99Microseconds,
              counter.p99Microseconds <= counter.maxMicroseconds else {
            throw VideoTransportValidationError.unorderedFrameAge
        }
    }

    private func validateAudioImpact() throws {
        try VideoTransportValidator.requireNonNegative(
            audioImpact.baselineCallbackP99Microseconds,
            "audioImpact.baselineCallbackP99Microseconds"
        )
        try VideoTransportValidator.requireNonNegative(
            audioImpact.videoCallbackP99Microseconds,
            "audioImpact.videoCallbackP99Microseconds"
        )
        try VideoTransportValidator.requireNonNegative(
            audioImpact.baselineCallbackMaxMicroseconds,
            "audioImpact.baselineCallbackMaxMicroseconds"
        )
        try VideoTransportValidator.requireNonNegative(
            audioImpact.videoCallbackMaxMicroseconds,
            "audioImpact.videoCallbackMaxMicroseconds"
        )
        try VideoTransportValidator.requirePositive(audioImpact.baselinePlayoutTargetFrames, "audioImpact.baselinePlayoutTargetFrames")
        try VideoTransportValidator.requirePositive(audioImpact.videoPlayoutTargetFrames, "audioImpact.videoPlayoutTargetFrames")
        try VideoTransportValidator.requireNonNegative(audioImpact.underruns, "audioImpact.underruns")
        guard audioImpact.baselineCallbackP99Microseconds <= audioImpact.baselineCallbackMaxMicroseconds else {
            throw VideoTransportValidationError.unorderedAudioCallbackMetrics("baseline")
        }
        guard audioImpact.videoCallbackP99Microseconds <= audioImpact.videoCallbackMaxMicroseconds else {
            throw VideoTransportValidationError.unorderedAudioCallbackMetrics("video")
        }
    }

    private func validatePassVerdict() throws {
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
        try validatePassAVSync()
    }

    private func validatePassTransportAndDegradation() throws {
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

    private func passRouteEvidence() throws -> VideoTransportRouteEvidence {
        guard let routeEvidence, routeEvidence.isPhysicalRoute else {
            throw VideoTransportValidationError.passWithoutPhysicalRouteEvidence
        }
        return routeEvidence
    }

    private func validatePassCodecBaseline(_ routeEvidence: VideoTransportRouteEvidence) throws {
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

    private func validatePassFragmentation() throws {
        guard let fragmentation else {
            throw VideoTransportValidationError.passWithoutFragmentationMetrics
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

    private func validatePassReassembly() throws {
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

    private func validatePassRenderOutput() throws {
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

    private func validatePassBlackmagicOutput() throws {
        guard let blackmagicOutput, blackmagicOutput.hasPhysicalOutputEvidence else {
            throw VideoTransportValidationError.passWithoutBlackmagicOutputEvidence
        }
    }

    private func validatePassAudioRouteVerdicts(_ routeEvidence: VideoTransportRouteEvidence) throws {
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

    private func validatePassAudioImpact() throws {
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

    private func validatePassAVSync() throws {
        guard avSync != nil else {
            throw VideoTransportValidationError.passWithoutAVSyncTimingMetrics
        }
    }

    private func validatePacketAge(_ metrics: UdpPcmPacketAgeMetrics, _ field: String) throws {
        try VideoTransportValidator.requireNonNegative(metrics.p50Microseconds, "\(field).p50Microseconds")
        try VideoTransportValidator.requireNonNegative(metrics.p95Microseconds, "\(field).p95Microseconds")
        try VideoTransportValidator.requireNonNegative(metrics.p99Microseconds, "\(field).p99Microseconds")
        try VideoTransportValidator.requireNonNegative(metrics.maxMicroseconds, "\(field).maxMicroseconds")
        guard metrics.p50Microseconds <= metrics.p95Microseconds,
              metrics.p95Microseconds <= metrics.p99Microseconds,
              metrics.p99Microseconds <= metrics.maxMicroseconds else {
            throw VideoTransportValidationError.unorderedFrameAge
        }
    }
}
