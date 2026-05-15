import Foundation

public struct LatencyBenchmarkReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var category: LatencyBenchmarkCategory
    public var runMode: LatencyBenchmarkRunMode
    public var evidenceKind: LatencyBenchmarkEvidenceKind
    public var hardware: HardwareIdentity
    public var route: RouteIdentity
    public var mediaMode: LatencyBenchmarkMediaMode
    public var timing: LatencyBenchmarkTimingMetrics
    public var loss: LatencyBenchmarkLossMetrics
    public var faults: LatencyBenchmarkFaultMetrics
    public var resources: LatencyBenchmarkResourceMetrics
    public var thresholds: LatencyBenchmarkThresholds
    public var components: [LatencyBudgetComponentMeasurement]
    public var rxBufferImpact: RxBufferBenchmarkImpact?
    public var latencyProfileEvidence: LatencyProfileEvidence?
    public var sessionProfileMetrics: SessionLatencyProfileBenchmarkMetrics?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        category: LatencyBenchmarkCategory,
        runMode: LatencyBenchmarkRunMode,
        evidenceKind: LatencyBenchmarkEvidenceKind,
        hardware: HardwareIdentity,
        route: RouteIdentity,
        mediaMode: LatencyBenchmarkMediaMode,
        timing: LatencyBenchmarkTimingMetrics,
        loss: LatencyBenchmarkLossMetrics,
        faults: LatencyBenchmarkFaultMetrics,
        resources: LatencyBenchmarkResourceMetrics,
        thresholds: LatencyBenchmarkThresholds,
        components: [LatencyBudgetComponentMeasurement],
        rxBufferImpact: RxBufferBenchmarkImpact? = nil,
        latencyProfileEvidence: LatencyProfileEvidence? = nil,
        sessionProfileMetrics: SessionLatencyProfileBenchmarkMetrics? = nil,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.category = category
        self.runMode = runMode
        self.evidenceKind = evidenceKind
        self.hardware = hardware
        self.route = route
        self.mediaMode = mediaMode
        self.timing = timing
        self.loss = loss
        self.faults = faults
        self.resources = resources
        self.thresholds = thresholds
        self.components = components
        self.rxBufferImpact = rxBufferImpact
        self.latencyProfileEvidence = latencyProfileEvidence
        self.sessionProfileMetrics = sessionProfileMetrics
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        // Keep report validation fail-fast so the first structural error is the reported context.
        // Cross-field pass-verdict checks only run after the base report shape is valid.
        try validateIdentity()
        try validateMediaMode()
        try validateTiming()
        try validateLoss()
        try validateFaults()
        try validateResources()
        try validateThresholds()
        try validateComponents()
        try validateRxBufferImpact()
        try validateLatencyProfileEvidence()
        try validateSessionProfileMetrics()
        try validatePassVerdict()
    }

    private func validateIdentity() throws {
        try requireLatencyNonEmpty(id, "id")
        try requireLatencyNonEmpty(title, "title")
        try requireLatencyNonEmpty(capturedAt, "capturedAt")
        try requireLatencyNonEmpty(hardware.referenceMac, "hardware.referenceMac")
        try requireLatencyNonEmpty(hardware.audioInterface, "hardware.audioInterface")
        try requireLatencyNonEmpty(hardware.osVersion, "hardware.osVersion")
        try requireLatencyNonEmpty(hardware.driverVersion, "hardware.driverVersion")
        try requireLatencyNonEmpty(route.label, "route.label")
        try requireLatencyNonEmpty(route.topology, "route.topology")
        try requireLatencyNonEmpty(notes, "notes")
    }

    private func validateMediaMode() throws {
        guard mediaMode.audio != nil || mediaMode.video != nil || mediaMode.lighting != nil else {
            throw LatencyBenchmarkValidationError.emptyField("mediaMode")
        }
        if let audio = mediaMode.audio {
            try requireLatencyPositive(audio.sampleRateHertz, "mediaMode.audio.sampleRateHertz")
            try requireLatencyPositive(audio.framesPerBuffer, "mediaMode.audio.framesPerBuffer")
            try requireLatencyPositive(audio.channelCount, "mediaMode.audio.channelCount")
            try requireLatencyNonEmpty(audio.sampleFormat, "mediaMode.audio.sampleFormat")
        }
        if let video = mediaMode.video {
            try requireLatencyPositive(video.width, "mediaMode.video.width")
            try requireLatencyPositive(video.height, "mediaMode.video.height")
            try requireLatencyPositive(video.nominalFrameRate, "mediaMode.video.nominalFrameRate")
            try requireLatencyNonEmpty(video.pixelFormat, "mediaMode.video.pixelFormat")
            try requireLatencyNonEmpty(video.transport, "mediaMode.video.transport")
        }
        if let lighting = mediaMode.lighting {
            try requireLatencyNonEmpty(lighting.protocolName, "mediaMode.lighting.protocolName")
            try requireLatencyNonEmpty(lighting.fixtureOrBridge, "mediaMode.lighting.fixtureOrBridge")
            try requireLatencyPositive(lighting.cueRateHertz, "mediaMode.lighting.cueRateHertz")
        }
    }

    private func validateTiming() throws {
        try requireLatencyNonNegative(
            timing.oneWayEstimateMicroseconds,
            "timing.oneWayEstimateMicroseconds"
        )
        try requireLatencyNonNegative(timing.roundTripMicroseconds, "timing.roundTripMicroseconds")
        // Jitter percentiles must be finite so ordering and pass-threshold comparisons are meaningful.
        try requireLatencyNonNegative(timing.jitter.p50Microseconds, "timing.jitter.p50Microseconds")
        try requireLatencyNonNegative(timing.jitter.p95Microseconds, "timing.jitter.p95Microseconds")
        try requireLatencyNonNegative(timing.jitter.p99Microseconds, "timing.jitter.p99Microseconds")
        try requireLatencyNonNegative(timing.jitter.maxMicroseconds, "timing.jitter.maxMicroseconds")

        guard timing.oneWayEstimateMicroseconds <= timing.roundTripMicroseconds else {
            throw LatencyBenchmarkValidationError.oneWayExceedsRoundTrip(
                oneWayMicroseconds: timing.oneWayEstimateMicroseconds,
                roundTripMicroseconds: timing.roundTripMicroseconds
            )
        }
        guard timingPercentilesAreOrdered(
            p50: timing.jitter.p50Microseconds,
            p95: timing.jitter.p95Microseconds,
            p99: timing.jitter.p99Microseconds,
            max: timing.jitter.maxMicroseconds
        ) else {
            throw LatencyBenchmarkValidationError.unorderedJitter
        }
    }

    private func validateLoss() throws {
        try requireLatencyNonNegative(loss.lostPackets, "loss.lostPackets")
        try requireLatencyNonNegative(loss.latePackets, "loss.latePackets")
        try requireLatencyPercent(loss.lossPercent, "loss.lossPercent")
    }

    private func validateFaults() throws {
        try requireLatencyNonNegative(faults.underruns, "faults.underruns")
        try requireLatencyNonNegative(faults.overruns, "faults.overruns")
        try requireLatencyNonNegative(faults.missedDeadlines, "faults.missedDeadlines")
        try requireLatencyNonNegative(faults.droppedFrames, "faults.droppedFrames")
    }

    private func validateResources() throws {
        try requireLatencyPercent(resources.cpuP50Percent, "resources.cpuP50Percent")
        try requireLatencyPercent(resources.cpuP95Percent, "resources.cpuP95Percent")
        try requireLatencyPercent(resources.cpuP99Percent, "resources.cpuP99Percent")
        try requireLatencyPercent(resources.cpuMaxPercent, "resources.cpuMaxPercent")
        try requireLatencyNonNegative(
            resources.residentMemoryMegabytes,
            "resources.residentMemoryMegabytes"
        )
        guard timingPercentilesAreOrdered(
            p50: resources.cpuP50Percent,
            p95: resources.cpuP95Percent,
            p99: resources.cpuP99Percent,
            max: resources.cpuMaxPercent
        ) else {
            throw LatencyBenchmarkValidationError.unorderedCpuMetrics
        }
        try validateWarnings(resources.allocationWarnings, "resources.allocationWarnings")
        try validateWarnings(resources.threadWarnings, "resources.threadWarnings")
    }

    private func validateWarnings(_ warnings: [LatencyBenchmarkWarning], _ field: String) throws {
        for (index, warning) in warnings.enumerated() {
            try requireLatencyNonEmpty(warning.field, "\(field)[\(index)].field")
            try requireLatencyNonEmpty(warning.message, "\(field)[\(index)].message")
        }
    }

    private func validateThresholds() throws {
        try requireLatencyNonEmpty(thresholds.budgetDocument, "thresholds.budgetDocument")
        try requireLatencyPositive(
            thresholds.oneWayTargetMicroseconds,
            "thresholds.oneWayTargetMicroseconds"
        )
        try requireLatencyPositive(
            thresholds.roundTripTargetMicroseconds,
            "thresholds.roundTripTargetMicroseconds"
        )
        try requireLatencyNonNegative(
            thresholds.jitterP99MaxMicroseconds,
            "thresholds.jitterP99MaxMicroseconds"
        )
        try requireLatencyPercent(thresholds.packetLossMaxPercent, "thresholds.packetLossMaxPercent")
        try requireLatencyPercent(thresholds.cpuP99MaxPercent, "thresholds.cpuP99MaxPercent")
        try requireLatencyNonNegative(thresholds.underrunMaxCount, "thresholds.underrunMaxCount")
        try requireLatencyNonNegative(
            thresholds.droppedFrameMaxCount,
            "thresholds.droppedFrameMaxCount"
        )
        try requireLatencyNonNegative(
            thresholds.allocationWarningMaxCount,
            "thresholds.allocationWarningMaxCount"
        )
        try requireLatencyNonNegative(
            thresholds.threadWarningMaxCount,
            "thresholds.threadWarningMaxCount"
        )
    }

    private func validateComponents() throws {
        guard !components.isEmpty else {
            throw LatencyBenchmarkValidationError.emptyList("components")
        }
        for (index, component) in components.enumerated() {
            try requireLatencyNonEmpty(component.id, "components[\(index)].id")
            try requireLatencyNonEmpty(component.label, "components[\(index)].label")
            try requireLatencyNonEmpty(component.source, "components[\(index)].source")
            if let budgetTargetMicroseconds = component.budgetTargetMicroseconds {
                try requireLatencyNonNegative(
                    budgetTargetMicroseconds,
                    "components[\(index)].budgetTargetMicroseconds"
                )
            }
            if let measuredMicroseconds = component.measuredMicroseconds {
                try requireLatencyNonNegative(
                    measuredMicroseconds,
                    "components[\(index)].measuredMicroseconds"
                )
            }
        }
    }

    private func validateRxBufferImpact() throws {
        try rxBufferImpact?.validate()
    }

    private func validateLatencyProfileEvidence() throws {
        guard let audioMode = mediaMode.audio,
              let profile = latencyProfile(for: audioMode),
              profile != .safeLowLatency else {
            return
        }
        guard let latencyProfileEvidence else {
            if verdict == .pass {
                throw LatencyBenchmarkValidationError.passWithoutLowBufferProfileEvidence(profile)
            }
            return
        }
        try latencyProfileEvidence.validate(for: audioMode, verdict: verdict)
    }

    private func validateSessionProfileMetrics() throws {
        try sessionProfileMetrics?.validate()
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        guard runMode == .measured else {
            throw LatencyBenchmarkValidationError.passWithoutMeasuredRun
        }
        guard evidenceKind == .physicalReferenceRig else {
            throw LatencyBenchmarkValidationError.passWithoutPhysicalReferenceRig
        }
        guard thresholds.budgetDocument.contains("latency-budget.md") else {
            throw LatencyBenchmarkValidationError.passWithoutLatencyBudgetReference(
                thresholds.budgetDocument
            )
        }
        let criticalComponents = components.filter { $0.criticality == .criticalPath }
        guard !criticalComponents.isEmpty else {
            throw LatencyBenchmarkValidationError.passWithoutCriticalPathComponent
        }
        for component in criticalComponents where component.measuredMicroseconds == nil {
            throw LatencyBenchmarkValidationError.passWithoutMeasuredCriticalPathComponent(component.id)
        }
        if timing.oneWayEstimateMicroseconds > thresholds.oneWayTargetMicroseconds {
            throw LatencyBenchmarkValidationError.passExceedsOneWayThreshold(
                value: timing.oneWayEstimateMicroseconds,
                threshold: thresholds.oneWayTargetMicroseconds
            )
        }
        if timing.roundTripMicroseconds > thresholds.roundTripTargetMicroseconds {
            throw LatencyBenchmarkValidationError.passExceedsRoundTripThreshold(
                value: timing.roundTripMicroseconds,
                threshold: thresholds.roundTripTargetMicroseconds
            )
        }
        if timing.jitter.p99Microseconds > thresholds.jitterP99MaxMicroseconds {
            throw LatencyBenchmarkValidationError.passExceedsJitterThreshold(
                value: timing.jitter.p99Microseconds,
                threshold: thresholds.jitterP99MaxMicroseconds
            )
        }
        if loss.lossPercent > thresholds.packetLossMaxPercent {
            throw LatencyBenchmarkValidationError.passExceedsLossThreshold(
                value: loss.lossPercent,
                threshold: thresholds.packetLossMaxPercent
            )
        }
        if resources.cpuP99Percent > thresholds.cpuP99MaxPercent {
            throw LatencyBenchmarkValidationError.passExceedsCpuThreshold(
                value: resources.cpuP99Percent,
                threshold: thresholds.cpuP99MaxPercent
            )
        }
        if faults.underruns > thresholds.underrunMaxCount {
            throw LatencyBenchmarkValidationError.passExceedsUnderrunThreshold(
                value: faults.underruns,
                threshold: thresholds.underrunMaxCount
            )
        }
        if faults.droppedFrames > thresholds.droppedFrameMaxCount {
            throw LatencyBenchmarkValidationError.passExceedsDroppedFrameThreshold(
                value: faults.droppedFrames,
                threshold: thresholds.droppedFrameMaxCount
            )
        }
        if resources.allocationWarnings.count > thresholds.allocationWarningMaxCount {
            throw LatencyBenchmarkValidationError.passExceedsAllocationWarningThreshold(
                value: resources.allocationWarnings.count,
                threshold: thresholds.allocationWarningMaxCount
            )
        }
        if resources.threadWarnings.count > thresholds.threadWarningMaxCount {
            throw LatencyBenchmarkValidationError.passExceedsThreadWarningThreshold(
                value: resources.threadWarnings.count,
                threshold: thresholds.threadWarningMaxCount
            )
        }
        if let sessionProfileMetrics,
           sessionProfileMetrics.fastestPassClaimed,
           !SessionLatencyProfilePolicy.policy(
                for: sessionProfileMetrics.sessionProfile
           ).fastestAudioPassEligible {
            throw LatencyBenchmarkValidationError.passWithFastestIneligibleSessionProfile(
                profile: sessionProfileMetrics.sessionProfile,
                rxBufferProfile: sessionProfileMetrics.rxBufferProfile
            )
        }
        if let rxBufferImpact {
            guard rxBufferImpact.profile.fastestAudioPassEligible else {
                throw LatencyBenchmarkValidationError.passWithFastestIneligibleRxBuffer(
                    rxBufferImpact.profile.profile
                )
            }
            let hiddenGrowth = rxBufferImpact.targetFramesOverTime.contains {
                $0 > rxBufferImpact.profile.maximumTargetFrames
            }
            if hiddenGrowth {
                throw LatencyBenchmarkValidationError.passWithHiddenRxBufferGrowth
            }
        }
    }
}


private func requireLatencyNonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(value, field: field, error: LatencyBenchmarkValidationError.self)
}

private func requireLatencyPositive(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, error: LatencyBenchmarkValidationError.self)
}

private func requireLatencyPositive(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, error: LatencyBenchmarkValidationError.self)
}

private func requireLatencyNonNegative(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(value, field: field, error: LatencyBenchmarkValidationError.self)
}

private func requireLatencyNonNegative(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(value, field: field, error: LatencyBenchmarkValidationError.self)
}

private func requireLatencyPercent(_ value: Double, _ field: String) throws {
    guard value.isFinite else {
        throw LatencyBenchmarkValidationError.nonFiniteField(field)
    }
    guard value >= 0, value <= 100 else {
        throw LatencyBenchmarkValidationError.percentOutOfRange(field: field, value: value)
    }
}
