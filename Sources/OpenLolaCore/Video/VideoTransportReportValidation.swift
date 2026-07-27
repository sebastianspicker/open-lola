// Validates VideoTransportReportValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
extension VideoTransportReport {
    func validateIdentity() throws {
        try VideoTransportValidator.requireNonEmpty(id, "id")
        try VideoTransportValidator.requireNonEmpty(title, "title")
        try VideoTransportValidator.requireNonEmpty(capturedAt, "capturedAt")
        try VideoTransportValidator.requireNonEmpty(notes, "notes")
        try VideoTransportValidator.requirePositive(durationSeconds, "durationSeconds")
    }

    func validateSourceAndFormat() throws {
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

    func validateTransport() throws {
        try VideoTransportValidator.requireNonEmpty(transport.networkProtocol, "transport.networkProtocol")
        try VideoTransportValidator.requireNonEmpty(transport.payloadFormat, "transport.payloadFormat")
        try VideoTransportValidator.requirePositive(transport.maxPacketBytes, "transport.maxPacketBytes")
        try VideoTransportValidator.requirePositive(transport.encoderQueueDepth, "transport.encoderQueueDepth")
    }

    func validateRouteEvidence() throws {
        guard let routeEvidence else {
            return
        }
        try VideoTransportValidator.requireNonEmpty(routeEvidence.routeLabel, "routeEvidence.routeLabel")
try VideoTransportValidator.requireNonEmpty(
routeEvidence.packetCapturePoint,
"routeEvidence.packetCapturePoint"
)
        if let baselineReportId = routeEvidence.rawOrIntraFrameBaselineReportId {
            try VideoTransportValidator.requireNonEmpty(
                baselineReportId,
                "routeEvidence.rawOrIntraFrameBaselineReportId"
            )
        }
    }

    func validateFragmentation() throws {
        guard let fragmentation else {
            return
        }
        try VideoTransportValidator.requireNonNegative(
            fragmentation.framesFragmented,
            "fragmentation.framesFragmented"
        )
        try VideoTransportValidator.requireNonNegative(fragmentation.fragmentsSent, "fragmentation.fragmentsSent")
try VideoTransportValidator.requireNonNegative(
fragmentation.maxFragmentsPerFrame,
"fragmentation.maxFragmentsPerFrame"
)
        try VideoTransportValidator.requireNonNegative(
            fragmentation.maxPayloadBytesPerFragment,
            "fragmentation.maxPayloadBytesPerFragment"
        )
    }

    func validateReassembly() throws {
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

    func validateRenderOutput() throws {
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
try VideoTransportValidator.requireNonNegative(
renderOutput.observedQueueDepth,
"renderOutput.observedQueueDepth"
)
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

    func validateBlackmagicOutput() throws {
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

    func validateMetrics() throws {
        try VideoTransportValidator.requireNonNegative(transmitted.framesSent, "transmitted.framesSent")
        try VideoTransportValidator.requireNonNegative(
            transmitted.framesDroppedBeforeSend,
            "transmitted.framesDroppedBeforeSend"
        )
        try VideoTransportValidator.requireNonNegative(transmitted.packetsSent, "transmitted.packetsSent")
        try VideoTransportValidator.requireNonNegative(transmitted.packetsDropped, "transmitted.packetsDropped")

        try VideoTransportValidator.requireNonNegative(receiver.receivedFrames, "receiver.receivedFrames")
        if renderOutput?.backend != .metricsOnly {
            try VideoTransportValidator.requirePositive(receiver.displayedFrames, "receiver.displayedFrames")
        }
        try VideoTransportValidator.requireNonNegative(receiver.droppedFrames, "receiver.droppedFrames")
        try VideoTransportValidator.requireNonNegative(receiver.lateFrames, "receiver.lateFrames")
        try VideoTransportValidator.requireNonNegative(receiver.observedQueueDepth, "receiver.observedQueueDepth")

        let expectedReceived = transmitted.framesSent
        if receiver.receivedFrames != expectedReceived {
            throw VideoTransportValidationError.packetAccountingMismatch(
                expectedReceived: expectedReceived,
                actualReceived: receiver.receivedFrames
            )
        }
        let expectedDisplayed = renderOutput?.backend == .metricsOnly
            ? 0
            : max(0, receiver.receivedFrames - receiver.droppedFrames)
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

    func validatePerformanceCounters() throws {
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

    func validatePerformanceCounter(
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

    func validateAudioImpact() throws {
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
try VideoTransportValidator.requirePositive(
audioImpact.baselinePlayoutTargetFrames,
"audioImpact.baselinePlayoutTargetFrames"
)
try VideoTransportValidator.requirePositive(
audioImpact.videoPlayoutTargetFrames,
"audioImpact.videoPlayoutTargetFrames"
)
        try VideoTransportValidator.requireNonNegative(audioImpact.underruns, "audioImpact.underruns")
        guard audioImpact.baselineCallbackP99Microseconds <= audioImpact.baselineCallbackMaxMicroseconds else {
            throw VideoTransportValidationError.unorderedAudioCallbackMetrics("baseline")
        }
        guard audioImpact.videoCallbackP99Microseconds <= audioImpact.videoCallbackMaxMicroseconds else {
            throw VideoTransportValidationError.unorderedAudioCallbackMetrics("video")
        }
    }
}
