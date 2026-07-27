// Validates EndpointLoopbackReportValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

public extension EndpointLoopbackReport {
    static func decode(from data: Data) throws -> EndpointLoopbackReport {
        try JSONDecoder().decode(EndpointLoopbackReport.self, from: data)
    }

    func validate() throws {
        try validateIdentity()
        try validateRequiredSampleRates()
        try validateSelectedMode()
        try validateStabilityRun()
    }

    private func validateIdentity() throws {
        try requireNonEmpty(id, "id")
        try requireNonEmpty(title, "title")
        try requireNonEmpty(capturedAt, "capturedAt")
        try requireNonEmpty(hardware.referenceMac, "hardware.referenceMac")
        try requireNonEmpty(hardware.audioInterface, "hardware.audioInterface")
        try requireNonEmpty(hardware.osVersion, "hardware.osVersion")
        try requireNonEmpty(hardware.driverVersion, "hardware.driverVersion")
        try requireNonEmpty(route.label, "route.label")
        try requireNonEmpty(route.topology, "route.topology")
        try requireNonEmpty(device.name, "device.name")
        try requireNonEmpty(device.uid, "device.uid")
        try requireNonEmpty(device.transportType, "device.transportType")
        try validateMode(selectedMode)
    }

    private func validateRequiredSampleRates() throws {
        var sampleRateMap: [Int: SampleRateLoopbackResult] = [:]
        for sampleRate in sampleRates {
            if sampleRateMap[sampleRate.sampleRateHertz] != nil {
                throw EndpointLoopbackValidationError.duplicateSampleRate(
                    sampleRate.sampleRateHertz
                )
            }
            sampleRateMap[sampleRate.sampleRateHertz] = sampleRate
        }

        for requiredSampleRate in Self.requiredSampleRates {
            guard let sampleRate = sampleRateMap[requiredSampleRate] else {
                throw EndpointLoopbackValidationError.missingRequiredSampleRate(requiredSampleRate)
            }
            try validateSampleRate(sampleRate)
        }
    }

    private func validateSampleRate(_ sampleRate: SampleRateLoopbackResult) throws {
        try requirePositive(sampleRate.sampleRateHertz, "sampleRateHertz")

        if !sampleRate.supported {
            try validateUnsupportedSampleRate(sampleRate)
            return
        }

        try validateSupportedSampleRateModes(sampleRate)
        let modeMap = try modeResultsByFrameSize(for: sampleRate)
        try validateRequiredFrameSizes(modeMap, sampleRateHertz: sampleRate.sampleRateHertz)

        for result in sampleRate.modeResults {
            try validateModeResult(result, sampleRateHertz: sampleRate.sampleRateHertz)
        }
    }

    private func validateUnsupportedSampleRate(_ sampleRate: SampleRateLoopbackResult) throws {
        if sampleRate.unsupportedReason == nil || sampleRate.unsupportedReason?.isEmpty == true {
            throw EndpointLoopbackValidationError.unsupportedSampleRateMissingReason(
                sampleRate.sampleRateHertz
            )
        }
    }

    private func validateSupportedSampleRateModes(_ sampleRate: SampleRateLoopbackResult) throws {
        if sampleRate.modeResults.isEmpty {
            throw EndpointLoopbackValidationError.supportedSampleRateMissingModes(
                sampleRate.sampleRateHertz
            )
        }
    }

    private func modeResultsByFrameSize(
        for sampleRate: SampleRateLoopbackResult
    ) throws -> [Int: EndpointModeResult] {
        var modeMap: [Int: EndpointModeResult] = [:]
        for modeResult in sampleRate.modeResults {
            let framesPerBuffer = modeResult.mode.framesPerBuffer
            if modeMap[framesPerBuffer] != nil {
                throw EndpointLoopbackValidationError.duplicateFrameSize(
                    sampleRateHertz: sampleRate.sampleRateHertz,
                    framesPerBuffer: framesPerBuffer
                )
            }
            modeMap[framesPerBuffer] = modeResult
        }
        return modeMap
    }

    private func validateRequiredFrameSizes(
        _ modeMap: [Int: EndpointModeResult],
        sampleRateHertz: Int
    ) throws {
        for requiredFrameSize in Self.requiredFrameSizes {
            guard modeMap[requiredFrameSize] != nil else {
                throw EndpointLoopbackValidationError.missingRequiredFrameSize(
                    sampleRateHertz: sampleRateHertz,
                    framesPerBuffer: requiredFrameSize
                )
            }
        }
    }

    private func validateModeResult(
        _ result: EndpointModeResult,
        sampleRateHertz: Int
    ) throws {
        try validateMode(result.mode)
        if result.mode.sampleRateHertz != sampleRateHertz {
            throw EndpointLoopbackValidationError.modeSampleRateMismatch(
                expected: sampleRateHertz,
                actual: result.mode.sampleRateHertz
            )
        }

        if result.accepted {
            guard let callback = result.callback else {
                throw EndpointLoopbackValidationError.acceptedModeMissingCallbackMetrics(
                    sampleRateHertz: sampleRateHertz,
                    framesPerBuffer: result.mode.framesPerBuffer
                )
            }
            guard let loopback = result.loopback else {
                throw EndpointLoopbackValidationError.acceptedModeMissingLoopbackMetrics(
                    sampleRateHertz: sampleRateHertz,
                    framesPerBuffer: result.mode.framesPerBuffer
                )
            }
            try validateCallback(callback)
            try validateLoopback(loopback)
        } else {
            if result.rejectionReason?.isEmpty != false {
                throw EndpointLoopbackValidationError.rejectedModeMissingReason(
                    sampleRateHertz: sampleRateHertz,
                    framesPerBuffer: result.mode.framesPerBuffer
                )
            }
            if result.stable {
                throw EndpointLoopbackValidationError.rejectedModeMarkedStable(
                    sampleRateHertz: sampleRateHertz,
                    framesPerBuffer: result.mode.framesPerBuffer
                )
            }
        }
    }

    private func validateSelectedMode() throws {
        let selectedResult = sampleRates
            .flatMap(\.modeResults)
            .first { $0.mode == selectedMode }

        guard let selectedResult, selectedResult.accepted else {
            throw EndpointLoopbackValidationError.selectedModeNotAccepted
        }
        if !selectedResult.stable {
            throw EndpointLoopbackValidationError.selectedModeNotStable
        }
    }

    private func validateStabilityRun() throws {
        if stabilityRun.mode != selectedMode {
            throw EndpointLoopbackValidationError.stabilityModeMismatch
        }
        if stabilityRun.durationSeconds < Self.minimumStabilityDurationSeconds {
            throw EndpointLoopbackValidationError.stabilityRunTooShort(
                seconds: stabilityRun.durationSeconds
            )
        }
        if selectedMode.framesPerBuffer == 8,
           stabilityRun.durationSeconds < Self.minimumExtremeLowLatencyDurationSeconds {
            throw EndpointLoopbackValidationError.eightFrameStabilityRunTooShort(
                seconds: stabilityRun.durationSeconds,
                minimumSeconds: Self.minimumExtremeLowLatencyDurationSeconds
            )
        }
        try validateCallback(stabilityRun.callback)
        try requireNonNegative(stabilityRun.dropoutEvents, "stabilityRun.dropoutEvents")
        if stabilityRun.dropoutEvents > 0 {
            throw EndpointLoopbackValidationError.dropoutEventsDetected(
                stabilityRun.dropoutEvents
            )
        }
        if stabilityRun.hiddenBufferGrowthDetected {
            throw EndpointLoopbackValidationError.hiddenBufferGrowthDetected
        }
    }
}

private func validateMode(_ mode: AudioMode) throws {
    try requirePositive(mode.sampleRateHertz, "mode.sampleRateHertz")
    try requirePositive(mode.framesPerBuffer, "mode.framesPerBuffer")
    try requirePositive(mode.channelCount, "mode.channelCount")
    try requireNonEmpty(mode.sampleFormat, "mode.sampleFormat")
}

private func validateCallback(_ callback: EndpointCallbackMetrics) throws {
    try requireNonNegative(callback.p50Microseconds, "callback.p50Microseconds")
    try requireNonNegative(callback.p95Microseconds, "callback.p95Microseconds")
    try requireNonNegative(callback.p99Microseconds, "callback.p99Microseconds")
    try requireNonNegative(callback.maxMicroseconds, "callback.maxMicroseconds")
    try requireNonNegative(callback.missedDeadlines, "callback.missedDeadlines")
    try requireNonNegative(callback.underruns, "callback.underruns")
    try requireNonNegative(callback.overruns, "callback.overruns")
    try requireNonNegative(callback.recordedIntervalSamples, "callback.recordedIntervalSamples")
    try requireNonNegative(callback.droppedIntervalSamples, "callback.droppedIntervalSamples")
    try requireNonNegative(callback.hostTimeConversionFailures, "callback.hostTimeConversionFailures")

    guard callback.p50Microseconds <= callback.p95Microseconds,
          callback.p95Microseconds <= callback.p99Microseconds,
          callback.p99Microseconds <= callback.maxMicroseconds else {
        throw EndpointLoopbackValidationError.unorderedCallbackMetrics
    }
}

private func validateLoopback(_ loopback: EndpointLoopbackMetrics) throws {
    try requireNonNegative(
        loopback.reportedInputLatencyFrames,
        "loopback.reportedInputLatencyFrames"
    )
    try requireNonNegative(
        loopback.reportedOutputLatencyFrames,
        "loopback.reportedOutputLatencyFrames"
    )
    try requireNonNegative(loopback.inputSafetyOffsetFrames, "loopback.inputSafetyOffsetFrames")
    try requireNonNegative(loopback.outputSafetyOffsetFrames, "loopback.outputSafetyOffsetFrames")
    try requireNonNegative(
        loopback.measuredAnalogRoundTripMilliseconds,
        "loopback.measuredAnalogRoundTripMilliseconds"
    )
    try requireNonNegative(
        loopback.correctedOneWayMilliseconds,
        "loopback.correctedOneWayMilliseconds"
    )
    if loopback.hiddenBufferGrowthDetected {
        throw EndpointLoopbackValidationError.hiddenBufferGrowthDetected
    }
}

private func requireNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw EndpointLoopbackValidationError.emptyField(field)
    }
}

private func requirePositive(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw EndpointLoopbackValidationError.nonPositiveField(field)
    }
}

private func requireNonNegative(_ value: Int, _ field: String) throws {
    if value < 0 {
        throw EndpointLoopbackValidationError.negativeField(field)
    }
}

private func requireNonNegative(_ value: Double, _ field: String) throws {
    if value < 0 {
        throw EndpointLoopbackValidationError.negativeField(field)
    }
}
