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
        try requireTransportNonEmpty(id, "id")
        try requireTransportNonEmpty(title, "title")
        try requireTransportNonEmpty(capturedAt, "capturedAt")
        try requireTransportNonEmpty(notes, "notes")
        try requireTransportPositive(durationSeconds, "durationSeconds")
    }

    private func validateSourceAndFormat() throws {
        try requireTransportNonEmpty(source.label, "source.label")
        try requireTransportNonEmpty(source.permissionStatus, "source.permissionStatus")
        if let deviceUniqueId = source.deviceUniqueId {
            try requireTransportNonEmpty(deviceUniqueId, "source.deviceUniqueId")
        }
        try requireTransportPositive(format.width, "format.width")
        try requireTransportPositive(format.height, "format.height")
        try requireTransportPositive(format.nominalFrameRate, "format.nominalFrameRate")
        try requireTransportNonEmpty(format.pixelFormat, "format.pixelFormat")
    }

    private func validateTransport() throws {
        try requireTransportNonEmpty(transport.networkProtocol, "transport.networkProtocol")
        try requireTransportNonEmpty(transport.payloadFormat, "transport.payloadFormat")
        try requireTransportPositive(transport.maxPacketBytes, "transport.maxPacketBytes")
        try requireTransportPositive(transport.encoderQueueDepth, "transport.encoderQueueDepth")
    }

    private func validateRouteEvidence() throws {
        guard let routeEvidence else {
            return
        }
        try requireTransportNonEmpty(routeEvidence.routeLabel, "routeEvidence.routeLabel")
        try requireTransportNonEmpty(routeEvidence.packetCapturePoint, "routeEvidence.packetCapturePoint")
        if let baselineReportId = routeEvidence.rawOrIntraFrameBaselineReportId {
            try requireTransportNonEmpty(
                baselineReportId,
                "routeEvidence.rawOrIntraFrameBaselineReportId"
            )
        }
    }

    private func validateFragmentation() throws {
        guard let fragmentation else {
            return
        }
        try requireTransportPositive(fragmentation.framesFragmented, "fragmentation.framesFragmented")
        try requireTransportPositive(fragmentation.fragmentsSent, "fragmentation.fragmentsSent")
        try requireTransportPositive(fragmentation.maxFragmentsPerFrame, "fragmentation.maxFragmentsPerFrame")
        try requireTransportPositive(
            fragmentation.maxPayloadBytesPerFragment,
            "fragmentation.maxPayloadBytesPerFragment"
        )
    }

    private func validateReassembly() throws {
        guard let reassembly else {
            return
        }
        try requireTransportNonNegative(reassembly.framesReassembled, "reassembly.framesReassembled")
        try requireTransportNonNegative(
            reassembly.framesDroppedIncomplete,
            "reassembly.framesDroppedIncomplete"
        )
        try requireTransportNonNegative(reassembly.missingFragments, "reassembly.missingFragments")
        try requireTransportNonNegative(reassembly.lateFragments, "reassembly.lateFragments")
        try requireTransportNonNegative(reassembly.duplicateFragments, "reassembly.duplicateFragments")
        try requireTransportNonNegative(reassembly.activeFramesPeak, "reassembly.activeFramesPeak")
    }

    private func validateRenderOutput() throws {
        guard let renderOutput else {
            return
        }
        try requireTransportNonNegative(renderOutput.framesSubmitted, "renderOutput.framesSubmitted")
        try requireTransportNonNegative(renderOutput.framesRendered, "renderOutput.framesRendered")
        try requireTransportNonNegative(renderOutput.framesOutput, "renderOutput.framesOutput")
        try requireTransportNonNegative(renderOutput.framesDroppedLate, "renderOutput.framesDroppedLate")
        try requireTransportNonNegative(
            renderOutput.framesDroppedBackpressure,
            "renderOutput.framesDroppedBackpressure"
        )
        try requireTransportNonNegative(
            renderOutput.framesDroppedContinuity,
            "renderOutput.framesDroppedContinuity"
        )
        try requireTransportNonNegative(renderOutput.observedQueueDepth, "renderOutput.observedQueueDepth")
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
        try requireTransportNonEmpty(blackmagicOutput.notes, "blackmagicOutput.notes")
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
        try requireTransportPositive(transmitted.framesSent, "transmitted.framesSent")
        try requireTransportNonNegative(
            transmitted.framesDroppedBeforeSend,
            "transmitted.framesDroppedBeforeSend"
        )
        try requireTransportPositive(transmitted.packetsSent, "transmitted.packetsSent")
        try requireTransportNonNegative(transmitted.packetsDropped, "transmitted.packetsDropped")

        try requireTransportNonNegative(receiver.receivedFrames, "receiver.receivedFrames")
        try requireTransportPositive(receiver.displayedFrames, "receiver.displayedFrames")
        try requireTransportNonNegative(receiver.droppedFrames, "receiver.droppedFrames")
        try requireTransportNonNegative(receiver.lateFrames, "receiver.lateFrames")
        try requireTransportNonNegative(receiver.observedQueueDepth, "receiver.observedQueueDepth")

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

        try requireTransportNonNegative(frameAge.p50Microseconds, "frameAge.p50Microseconds")
        try requireTransportNonNegative(frameAge.p95Microseconds, "frameAge.p95Microseconds")
        try requireTransportNonNegative(frameAge.p99Microseconds, "frameAge.p99Microseconds")
        try requireTransportNonNegative(frameAge.maxMicroseconds, "frameAge.maxMicroseconds")
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
        try requireTransportNonNegative(
            performanceCounters.queueDepthFrames,
            "performanceCounters.queueDepthFrames"
        )
    }

    private func validatePerformanceCounter(
        _ counter: PerformanceCounterSummary,
        _ field: String
    ) throws {
        try requireTransportNonNegative(counter.sampleCount, "\(field).sampleCount")
        try requireTransportNonNegative(counter.p50Microseconds, "\(field).p50Microseconds")
        try requireTransportNonNegative(counter.p95Microseconds, "\(field).p95Microseconds")
        try requireTransportNonNegative(counter.p99Microseconds, "\(field).p99Microseconds")
        try requireTransportNonNegative(counter.maxMicroseconds, "\(field).maxMicroseconds")
        guard counter.p50Microseconds <= counter.p95Microseconds,
              counter.p95Microseconds <= counter.p99Microseconds,
              counter.p99Microseconds <= counter.maxMicroseconds else {
            throw VideoTransportValidationError.unorderedFrameAge
        }
    }

    private func validateAudioImpact() throws {
        try requireTransportNonNegative(
            audioImpact.baselineCallbackP99Microseconds,
            "audioImpact.baselineCallbackP99Microseconds"
        )
        try requireTransportNonNegative(
            audioImpact.videoCallbackP99Microseconds,
            "audioImpact.videoCallbackP99Microseconds"
        )
        try requireTransportNonNegative(
            audioImpact.baselineCallbackMaxMicroseconds,
            "audioImpact.baselineCallbackMaxMicroseconds"
        )
        try requireTransportNonNegative(
            audioImpact.videoCallbackMaxMicroseconds,
            "audioImpact.videoCallbackMaxMicroseconds"
        )
        try requireTransportPositive(audioImpact.baselinePlayoutTargetFrames, "audioImpact.baselinePlayoutTargetFrames")
        try requireTransportPositive(audioImpact.videoPlayoutTargetFrames, "audioImpact.videoPlayoutTargetFrames")
        try requireTransportNonNegative(audioImpact.underruns, "audioImpact.underruns")
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
        if transport.reliableRetransmission {
            throw VideoTransportValidationError.passUsesReliableRetransmission
        }
        guard degradation.triggeredBeforeAudioTargetChange else {
            throw VideoTransportValidationError.passWithoutPreAudioDegradation
        }
        guard degradation.triggeredBeforeAudioOrRouteImpact == true else {
            throw VideoTransportValidationError.passWithoutPreAudioOrRouteDegradation
        }
        guard let routeEvidence, routeEvidence.isPhysicalRoute else {
            throw VideoTransportValidationError.passWithoutPhysicalRouteEvidence
        }
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
        guard let fragmentation else {
            throw VideoTransportValidationError.passWithoutFragmentationMetrics
        }
        guard let reassembly else {
            throw VideoTransportValidationError.passWithoutReassemblyMetrics
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
        if reassembly.framesReassembled != receiver.receivedFrames {
            throw VideoTransportValidationError.passWithReassembledFrameMismatch(
                expected: receiver.receivedFrames,
                actual: reassembly.framesReassembled
            )
        }
        if reassembly.framesDroppedIncomplete > 0 || reassembly.missingFragments > 0 {
            throw VideoTransportValidationError.passWithIncompleteReassembly
        }
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
        guard let blackmagicOutput, blackmagicOutput.hasPhysicalOutputEvidence else {
            throw VideoTransportValidationError.passWithoutBlackmagicOutputEvidence
        }
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
        guard avSync != nil else {
            throw VideoTransportValidationError.passWithoutAVSyncTimingMetrics
        }
    }

    private func validatePacketAge(_ metrics: UdpPcmPacketAgeMetrics, _ field: String) throws {
        try requireTransportNonNegative(metrics.p50Microseconds, "\(field).p50Microseconds")
        try requireTransportNonNegative(metrics.p95Microseconds, "\(field).p95Microseconds")
        try requireTransportNonNegative(metrics.p99Microseconds, "\(field).p99Microseconds")
        try requireTransportNonNegative(metrics.maxMicroseconds, "\(field).maxMicroseconds")
        guard metrics.p50Microseconds <= metrics.p95Microseconds,
              metrics.p95Microseconds <= metrics.p99Microseconds,
              metrics.p99Microseconds <= metrics.maxMicroseconds else {
            throw VideoTransportValidationError.unorderedFrameAge
        }
    }
}
