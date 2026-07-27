// Validates LatencyTuningReportValidationSupport acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

func validateLatencyTuningHardware(_ hardware: HardwareIdentity, prefix: String) throws {
    try LatencyTuningValidator.requireNonEmpty(hardware.referenceMac, "\(prefix).referenceMac")
    try LatencyTuningValidator.requireNonEmpty(hardware.audioInterface, "\(prefix).audioInterface")
    try LatencyTuningValidator.requireNonEmpty(hardware.osVersion, "\(prefix).osVersion")
    try LatencyTuningValidator.requireNonEmpty(hardware.driverVersion, "\(prefix).driverVersion")
}

func validateLatencyTuningRoute(_ route: RouteIdentity, prefix: String) throws {
    try LatencyTuningValidator.requireNonEmpty(route.label, "\(prefix).label")
    try LatencyTuningValidator.requireNonEmpty(route.topology, "\(prefix).topology")
}

func validateLatencyTuningTiming(
    _ timing: LatencyBenchmarkTimingMetrics,
    candidateId: String
) throws {
    try LatencyTuningValidator.requireNonNegative(
timing.oneWayEstimateMicroseconds,
"timing.oneWayEstimateMicroseconds"
)
    try LatencyTuningValidator.requireNonNegative(timing.roundTripMicroseconds, "timing.roundTripMicroseconds")
    try LatencyTuningValidator.requireNonNegative(timing.jitter.p50Microseconds, "timing.jitter.p50Microseconds")
    try LatencyTuningValidator.requireNonNegative(timing.jitter.p95Microseconds, "timing.jitter.p95Microseconds")
    try LatencyTuningValidator.requireNonNegative(timing.jitter.p99Microseconds, "timing.jitter.p99Microseconds")
    try LatencyTuningValidator.requireNonNegative(timing.jitter.maxMicroseconds, "timing.jitter.maxMicroseconds")
    guard timing.oneWayEstimateMicroseconds <= timing.roundTripMicroseconds else {
        throw LatencyTuningValidationError.oneWayExceedsRoundTrip(
            candidate: candidateId,
            oneWay: timing.oneWayEstimateMicroseconds,
            roundTrip: timing.roundTripMicroseconds
        )
    }
    guard timingPercentilesAreOrdered(
        p50: timing.jitter.p50Microseconds,
        p95: timing.jitter.p95Microseconds,
        p99: timing.jitter.p99Microseconds,
        max: timing.jitter.maxMicroseconds
    ) else {
        throw LatencyTuningValidationError.unorderedJitter(candidateId)
    }
}

func validateLatencyTuningLoss(_ loss: LatencyBenchmarkLossMetrics) throws {
    try LatencyTuningValidator.requireNonNegative(loss.lostPackets, "loss.lostPackets")
    try LatencyTuningValidator.requireNonNegative(loss.latePackets, "loss.latePackets")
    try requireLatencyTuningPercent(loss.lossPercent, "loss.lossPercent")
}

func validateLatencyTuningFaults(_ faults: LatencyBenchmarkFaultMetrics) throws {
    try LatencyTuningValidator.requireNonNegative(faults.underruns, "faults.underruns")
    try LatencyTuningValidator.requireNonNegative(faults.overruns, "faults.overruns")
    try LatencyTuningValidator.requireNonNegative(faults.missedDeadlines, "faults.missedDeadlines")
    try LatencyTuningValidator.requireNonNegative(faults.droppedFrames, "faults.droppedFrames")
}

func validateLatencyTuningResources(
    _ resources: LatencyBenchmarkResourceMetrics,
    candidateId: String
) throws {
    try requireLatencyTuningPercent(resources.cpuP50Percent, "resources.cpuP50Percent")
    try requireLatencyTuningPercent(resources.cpuP95Percent, "resources.cpuP95Percent")
    try requireLatencyTuningPercent(resources.cpuP99Percent, "resources.cpuP99Percent")
    try requireLatencyTuningPercent(resources.cpuMaxPercent, "resources.cpuMaxPercent")
    try LatencyTuningValidator.requireNonNegative(
resources.residentMemoryMegabytes,
"resources.residentMemoryMegabytes"
)
    guard timingPercentilesAreOrdered(
        p50: resources.cpuP50Percent,
        p95: resources.cpuP95Percent,
        p99: resources.cpuP99Percent,
        max: resources.cpuMaxPercent
    ) else {
        throw LatencyTuningValidationError.unorderedCpu(candidateId)
    }
    for warning in resources.allocationWarnings + resources.threadWarnings {
        try LatencyTuningValidator.requireNonEmpty(warning.field, "resources.warning.field")
        try LatencyTuningValidator.requireNonEmpty(warning.message, "resources.warning.message")
    }
}

func latencyTuningCandidateIsFaster(
    lhs: LatencyTuningCandidate,
    rhs: LatencyTuningCandidate
) -> Bool {
    if lhs.timing.oneWayEstimateMicroseconds != rhs.timing.oneWayEstimateMicroseconds {
        return lhs.timing.oneWayEstimateMicroseconds < rhs.timing.oneWayEstimateMicroseconds
    }
    if lhs.timing.jitter.p99Microseconds != rhs.timing.jitter.p99Microseconds {
        return lhs.timing.jitter.p99Microseconds < rhs.timing.jitter.p99Microseconds
    }
    if lhs.audioMode.framesPerBuffer != rhs.audioMode.framesPerBuffer {
        return lhs.audioMode.framesPerBuffer < rhs.audioMode.framesPerBuffer
    }
    return false
}

func requireLatencyTuningPercent(_ value: Double, _ field: String) throws {
    guard value.isFinite else {
        throw LatencyTuningValidationError.nonFiniteField(field)
    }
    guard value >= 0, value <= 100 else {
        throw LatencyTuningValidationError.percentOutOfRange(field: field, value: value)
    }
}
