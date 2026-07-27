// Validates RealtimeAudioEngineReportValidationSupport acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension RealtimeAudioEngineReport {
    public func validate() throws {
        try validateIdentity()
        try validateConfiguration()
        try validateRuntime()
        try sourceRmeFastestAudioReport?.validate()
        try sourceRouteCertificationReport?.validate()
        try validatePassVerdict()
    }

    private func validateIdentity() throws {
        try RealtimeAudioEngineValidator.requireNonEmpty(id, "id")
        try RealtimeAudioEngineValidator.requireNonEmpty(title, "title")
        try RealtimeAudioEngineValidator.requireNonEmpty(capturedAt, "capturedAt")
        try RealtimeAudioEngineValidator.requireNonEmpty(hardware.referenceMac, "hardware.referenceMac")
        try RealtimeAudioEngineValidator.requireNonEmpty(hardware.audioInterface, "hardware.audioInterface")
        try RealtimeAudioEngineValidator.requireNonEmpty(hardware.osVersion, "hardware.osVersion")
        try RealtimeAudioEngineValidator.requireNonEmpty(hardware.driverVersion, "hardware.driverVersion")
        try RealtimeAudioEngineValidator.requireNonEmpty(notes, "notes")
    }

    private func validateConfiguration() throws {
        try RealtimeAudioEngineValidator.requireNonEmpty(configuration.inputDeviceUID, "configuration.inputDeviceUID")
        try RealtimeAudioEngineValidator.requireNonEmpty(configuration.outputDeviceUID, "configuration.outputDeviceUID")
        try RealtimeAudioEngineValidator.requirePositive(configuration.sampleRateHertz, "configuration.sampleRateHertz")
        try RealtimeAudioEngineValidator.requirePositive(configuration.framesPerBuffer, "configuration.framesPerBuffer")
        try RealtimeAudioEngineValidator.requirePositive(configuration.channelCount, "configuration.channelCount")
        try RealtimeAudioEngineValidator.requireNonNegative(
            configuration.playoutTargetFrames,
            "configuration.playoutTargetFrames"
        )
        try RealtimeAudioEngineValidator.requirePositive(
            configuration.preallocatedBlockCount,
            "configuration.preallocatedBlockCount"
        )
        if let rxBufferPolicy = configuration.rxBufferPolicy {
            try rxBufferPolicy.validate()
            guard rxBufferPolicy.targetFrames == configuration.playoutTargetFrames else {
                throw RealtimeAudioEngineValidationError.rxBufferPlayoutTargetMismatch(
                    policyFrames: rxBufferPolicy.targetFrames,
                    configurationFrames: configuration.playoutTargetFrames
                )
            }
        }
        try validateChannelMap(configuration.inputChannelMap, "configuration.inputChannelMap")
        try validateChannelMap(configuration.outputChannelMap, "configuration.outputChannelMap")
    }

    private func validateChannelMap(_ channelMap: [Int], _ field: String) throws {
        guard !channelMap.isEmpty else {
            throw RealtimeAudioEngineValidationError.emptyChannelMap(field)
        }
        guard channelMap.count == configuration.channelCount else {
            throw RealtimeAudioEngineValidationError.channelMapCountMismatch(
                field: field,
                expected: configuration.channelCount,
                actual: channelMap.count
            )
        }
        for index in channelMap {
            try RealtimeAudioEngineValidator.requireNonNegative(index, field)
        }
    }

    private func validateRuntime() throws {
        try validateCallback(runtime.callback)
        try validateHandoff(runtime.handoff)
        try RealtimeAudioEngineValidator.requirePositive(
            runtime.measuredDurationSeconds,
            "runtime.measuredDurationSeconds"
        )
    }

    private func validateCallback(_ callback: EndpointCallbackMetrics) throws {
        try RealtimeAudioEngineValidator.requireNonNegative(
            callback.p50Microseconds,
            "runtime.callback.p50Microseconds"
        )
        try RealtimeAudioEngineValidator.requireNonNegative(
            callback.p95Microseconds,
            "runtime.callback.p95Microseconds"
        )
        try RealtimeAudioEngineValidator.requireNonNegative(
            callback.p99Microseconds,
            "runtime.callback.p99Microseconds"
        )
        try RealtimeAudioEngineValidator.requireNonNegative(
            callback.maxMicroseconds,
            "runtime.callback.maxMicroseconds"
        )
        try RealtimeAudioEngineValidator.requireNonNegative(
            callback.missedDeadlines,
            "runtime.callback.missedDeadlines"
        )
        try RealtimeAudioEngineValidator.requireNonNegative(callback.underruns, "runtime.callback.underruns")
        try RealtimeAudioEngineValidator.requireNonNegative(callback.overruns, "runtime.callback.overruns")
        try RealtimeAudioEngineValidator.requireNonNegative(
            callback.recordedIntervalSamples,
            "runtime.callback.recordedIntervalSamples"
        )
        try RealtimeAudioEngineValidator.requireNonNegative(
            callback.droppedIntervalSamples,
            "runtime.callback.droppedIntervalSamples"
        )
        try RealtimeAudioEngineValidator.requireNonNegative(
            callback.hostTimeConversionFailures,
            "runtime.callback.hostTimeConversionFailures"
        )
        guard callback.p50Microseconds <= callback.p95Microseconds,
              callback.p95Microseconds <= callback.p99Microseconds,
              callback.p99Microseconds <= callback.maxMicroseconds else {
            throw RealtimeAudioEngineValidationError.unorderedCallbackMetrics
        }
    }

    private func validateHandoff(_ handoff: RealtimeAudioHandoffMetrics) throws {
        try validateNonNegativeHandoffCounts(handoff)
        try RealtimeAudioEngineValidator.requirePositive(
            handoff.ringCapacityBlocks,
            "runtime.handoff.ringCapacityBlocks"
        )
        try validateNonNegativeHandoffCapacityCounts(handoff)
        try validatePerformanceCounter(
            handoff.packetizationDuration,
            "runtime.handoff.packetizationDuration"
        )
        try validatePerformanceCounter(
            handoff.depacketizationDuration,
            "runtime.handoff.depacketizationDuration"
        )
        try handoff.rxBuffer?.validate()
    }

    private func validateNonNegativeHandoffCounts(_ handoff: RealtimeAudioHandoffMetrics) throws {
        for (value, field) in [
            (handoff.inputBlocks, "runtime.handoff.inputBlocks"),
            (handoff.outputBlocks, "runtime.handoff.outputBlocks"),
            (handoff.networkSendBlocks, "runtime.handoff.networkSendBlocks"),
            (handoff.networkReceiveBlocks, "runtime.handoff.networkReceiveBlocks"),
            (handoff.droppedInputBlocks, "runtime.handoff.droppedInputBlocks"),
            (handoff.droppedNetworkBlocks, "runtime.handoff.droppedNetworkBlocks"),
            (handoff.outputUnderrunBlocks, "runtime.handoff.outputUnderrunBlocks"),
            (handoff.callbackOverrunBlocks, "runtime.handoff.callbackOverrunBlocks"),
            (handoff.latePackets, "runtime.handoff.latePackets"),
            (handoff.maximumBufferedBlocks, "runtime.handoff.maximumBufferedBlocks")
        ] {
            try RealtimeAudioEngineValidator.requireNonNegative(value, field)
        }
    }

    private func validateNonNegativeHandoffCapacityCounts(_ handoff: RealtimeAudioHandoffMetrics) throws {
        for (value, field) in [
            (handoff.fullCaptureRingBlocks, "runtime.handoff.fullCaptureRingBlocks"),
            (handoff.invalidInputBlocks, "runtime.handoff.invalidInputBlocks"),
            (handoff.directInputBlocks, "runtime.handoff.directInputBlocks"),
            (handoff.remappedInputBlocks, "runtime.handoff.remappedInputBlocks"),
            (handoff.packetFragmentCount, "runtime.handoff.packetFragmentCount"),
            (handoff.allocationWarnings, "runtime.handoff.allocationWarnings"),
            (handoff.maximumCaptureRingOccupancyBlocks, "runtime.handoff.maximumCaptureRingOccupancyBlocks"),
            (handoff.maximumPlayoutQueueDepthBlocks, "runtime.handoff.maximumPlayoutQueueDepthBlocks")
        ] {
            try RealtimeAudioEngineValidator.requireNonNegative(value, field)
        }
    }

    private func validatePerformanceCounter(
        _ counter: PerformanceCounterSummary,
        _ field: String
    ) throws {
        try RealtimeAudioEngineValidator.requireNonNegative(counter.sampleCount, "\(field).sampleCount")
        try RealtimeAudioEngineValidator.requireNonNegative(counter.p50Microseconds, "\(field).p50Microseconds")
        try RealtimeAudioEngineValidator.requireNonNegative(counter.p95Microseconds, "\(field).p95Microseconds")
        try RealtimeAudioEngineValidator.requireNonNegative(counter.p99Microseconds, "\(field).p99Microseconds")
        try RealtimeAudioEngineValidator.requireNonNegative(counter.maxMicroseconds, "\(field).maxMicroseconds")
        guard counter.p50Microseconds <= counter.p95Microseconds,
              counter.p95Microseconds <= counter.p99Microseconds,
              counter.p99Microseconds <= counter.maxMicroseconds else {
            throw RealtimeAudioEngineValidationError.unorderedPerformanceCounter(field)
        }
    }

}
