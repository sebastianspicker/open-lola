// Verifies that latency benchmark sampling warms up, rejects invalid counts, and summarizes results.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func latencyBenchmarkSamplingRunsWarmupRejectsInvalidCountsAndSummarizes() throws {
    try expectRepeatedLatencySamplingRunsWarmup()
    try expectLatencySamplingConfigurationRejectsInvalidCounts()
    expectLatencyBenchmarkSummaryUsesWarmupColdStart()
    expectLatencyBenchmarkSummaryUsesNearestRankPercentiles()
    expectLatencyBenchmarkSummaryIgnoresNonFiniteSamples()
}
private func expectRepeatedLatencySamplingRunsWarmup() throws {
    var calls = 0
    let summary = LatencyBenchmark.measureRepeatedMicroseconds(
        configuration: try LatencyBenchmarkSamplingConfiguration(warmupIterations: 3, sampleCount: 10)
    ) {
        calls += 1
    }

    #expect(calls == 13)
    #expect(summary.warmupIterations == 3)
    #expect(summary.sampleCount == 10)
    #expect(summary.coldStartMaxMicroseconds != nil)
    #expect(summary.medianMicroseconds <= summary.p99Microseconds)
    #expect(summary.p99Microseconds <= summary.maxMicroseconds)
}

private func expectLatencySamplingConfigurationRejectsInvalidCounts() throws {
    #expect(throws: LatencyBenchmarkSamplingConfigurationError.warmupIterationsTooLow(
        actual: 2,
        minimum: 3
    )) {
        try LatencyBenchmarkSamplingConfiguration(warmupIterations: 2, sampleCount: 10)
    }
    #expect(throws: LatencyBenchmarkSamplingConfigurationError.sampleCountTooLow(
        actual: 9,
        minimum: 10
    )) {
        try LatencyBenchmarkSamplingConfiguration(warmupIterations: 3, sampleCount: 9)
    }
}

private func expectLatencyBenchmarkSummaryUsesWarmupColdStart() {
    let warmupSummary = LatencyBenchmark.summarize(
        samplesMicroseconds: [1, 2, 3],
        warmupSamplesMicroseconds: [1_000],
        warmupIterations: 3
    )

    #expect(warmupSummary.sampleCount == 3)
    #expect(warmupSummary.coldStartMaxMicroseconds == 1_000)
    #expect(warmupSummary.p99Microseconds == 2)
    #expect(warmupSummary.maxMicroseconds == 3)
}

private func expectLatencyBenchmarkSummaryUsesNearestRankPercentiles() {
    let percentileSummary = LatencyBenchmark.summarize(
        samplesMicroseconds: [1, 100, 2, 3],
        warmupIterations: 3
    )

    #expect(percentileSummary.sampleCount == 4)
    #expect(percentileSummary.medianMicroseconds == 2)
    #expect(percentileSummary.p99Microseconds == 3)
    #expect(percentileSummary.maxMicroseconds == 100)
}

private func expectLatencyBenchmarkSummaryIgnoresNonFiniteSamples() {
    let finiteSummary = LatencyBenchmark.summarize(
        samplesMicroseconds: [1, .infinity, 2, .nan, 3],
        warmupIterations: 3
    )

    #expect(finiteSummary.sampleCount == 3)
    #expect(finiteSummary.medianMicroseconds.isFinite)
    #expect(finiteSummary.p99Microseconds.isFinite)
    #expect(finiteSummary.maxMicroseconds == 3)
}

@Test
func m07LatencyProfileSyntheticSmokeCarriesSessionProfileTelemetry() throws {
    let report = try LatencyProfileBenchmarkSyntheticSmoke.run()

    try report.validate()

    let metrics = try #require(report.sessionProfileMetrics)
    #expect(report.id == "m07-latency-profile-synthetic-smoke")
    #expect(metrics.sessionProfile == .directAudioFirst)
    #expect(metrics.rxBufferProfile == .direct)
    #expect(metrics.callbackDurationP99Microseconds > 0)
    #expect(metrics.routeAge.p99Microseconds > 0)
    #expect(metrics.packetAge.p99Microseconds > 0)
    #expect(metrics.underruns == report.faults.underruns)
    #expect(metrics.overruns == report.faults.overruns)
    #expect(metrics.addedBufferCostFrames == report.rxBufferImpact?.addedLatencyFrames)
    #expect(metrics.addedBufferCostPackets == report.rxBufferImpact?.profile.latencyCostPackets)
}

@Test
func latencyBenchmarkRejectsInvalidReportAndPassEvidence() throws {
    try expectLatencyBenchmarkRejectsInvalidIdentity()
    try expectInvalidLatencyBenchmarkFixturesFailValidation()
    try expectLatencyBenchmarkRejectsInvalidPassEvidence()
    try expectLatencyBenchmarkRejectsInvalidJitterMetrics()
}

private func expectLatencyBenchmarkRejectsInvalidIdentity() throws {
    var invalidIdentity = try latencyBenchmarkPassCandidate()
    invalidIdentity.id = ""
    invalidIdentity.evidenceKind = .synthetic

    #expect(throws: LatencyBenchmarkValidationError.emptyField("id")) {
        try invalidIdentity.validate()
    }
}

private func expectInvalidLatencyBenchmarkFixturesFailValidation() throws {
    for fixtureName in [
        "latency-missing-hardware",
        "latency-missing-route",
        "latency-missing-timing",
        "latency-missing-thresholds",
        "latency-missing-verdict"
    ] {
        #expect(throws: Error.self) {
            _ = try loadInvalidLatencyBenchmarkFixture(named: fixtureName)
        }
    }
}

private func expectLatencyBenchmarkRejectsInvalidPassEvidence() throws {
    try expectLatencyBenchmarkError(.passWithoutPhysicalReferenceRig) {
        $0.evidenceKind = .synthetic
    }
    try expectLatencyBenchmarkError(.passWithoutLatencyBudgetReference(
        "private/reports/ad-hoc-thresholds.md"
    )) {
        $0.thresholds.budgetDocument = "private/reports/ad-hoc-thresholds.md"
    }
    try expectLatencyBenchmarkError(.passWithoutMeasuredCriticalPathComponent(
        "audio-interface-buffer"
    )) {
        $0.components[0].measuredMicroseconds = nil
    }
    try expectLatencyBenchmarkError(.passExceedsOneWayThreshold(
        value: 5_001,
        threshold: 5_000
    )) {
        $0.timing.oneWayEstimateMicroseconds = 5_001
    }
    try expectLatencyBenchmarkError(.passWithFastestIneligibleSessionProfile(
        profile: .balancedAV,
        rxBufferProfile: .small
    )) {
        $0.sessionProfileMetrics = sessionProfileMetrics(
            profile: .balancedAV,
            rxBufferProfile: .small,
            fastestPassClaimed: true
        )
    }
    try expectLatencyBenchmarkError(.passWithoutLowBufferProfileEvidence(
        .ultraLowLatency16
    )) {
        $0.mediaMode.audio = AudioMode(
            sampleRateHertz: 48_000,
            framesPerBuffer: 16,
            channelCount: 2,
            sampleFormat: "int16"
        )
        $0.latencyProfileEvidence = nil
    }
}

private func expectLatencyBenchmarkRejectsInvalidJitterMetrics() throws {
    var negativeJitter = try latencyBenchmarkPassCandidate()
    negativeJitter.timing.jitter.p50Microseconds = -1

    #expect(throws: LatencyBenchmarkValidationError.negativeField("timing.jitter.p50Microseconds")) {
        try negativeJitter.validate()
    }

    var nonFiniteJitter = try latencyBenchmarkPassCandidate()
    nonFiniteJitter.timing.jitter.maxMicroseconds = .nan

    #expect(throws: LatencyBenchmarkValidationError.nonFiniteField("timing.jitter.maxMicroseconds")) {
        try nonFiniteJitter.validate()
    }
}

@Test
func latencyBenchmarkRejectsPassThresholdViolations() throws {
    try expectLatencyBenchmarkRejectsTimingAndNetworkThresholdViolations()
    try expectLatencyBenchmarkRejectsResourceAndFaultThresholdViolations()
}

private func expectLatencyBenchmarkRejectsTimingAndNetworkThresholdViolations() throws {
    try expectLatencyBenchmarkError(.passExceedsRoundTripThreshold(
        value: 10_001,
        threshold: 10_000
    )) {
        $0.timing.roundTripMicroseconds = 10_001
        $0.thresholds.roundTripTargetMicroseconds = 10_000
    }

    try expectLatencyBenchmarkError(.passExceedsJitterThreshold(
        value: 251,
        threshold: 250
    )) {
        $0.timing.jitter.p99Microseconds = 251
        $0.timing.jitter.maxMicroseconds = 300
        $0.thresholds.jitterP99MaxMicroseconds = 250
    }

    try expectLatencyBenchmarkError(.passExceedsLossThreshold(
        value: 0.11,
        threshold: 0.1
    )) {
        $0.loss.lossPercent = 0.11
        $0.thresholds.packetLossMaxPercent = 0.1
    }
}

private func expectLatencyBenchmarkRejectsResourceAndFaultThresholdViolations() throws {
    try expectLatencyBenchmarkError(.passExceedsCpuThreshold(
        value: 50.1,
        threshold: 50
    )) {
        $0.resources.cpuP99Percent = 50.1
        $0.resources.cpuMaxPercent = 60
        $0.thresholds.cpuP99MaxPercent = 50
    }

    try expectLatencyBenchmarkError(.passExceedsUnderrunThreshold(
        value: 1,
        threshold: 0
    )) {
        $0.faults.underruns = 1
        $0.thresholds.underrunMaxCount = 0
    }

    try expectLatencyBenchmarkError(.passExceedsDroppedFrameThreshold(
        value: 1,
        threshold: 0
    )) {
        $0.faults.droppedFrames = 1
        $0.thresholds.droppedFrameMaxCount = 0
    }

    try expectLatencyBenchmarkError(.passExceedsAllocationWarningThreshold(
        value: 1,
        threshold: 0
    )) {
        $0.resources.allocationWarnings = [
            LatencyBenchmarkWarning(field: "audio.callback", message: "allocation")
        ]
        $0.thresholds.allocationWarningMaxCount = 0
    }

    try expectLatencyBenchmarkError(.passExceedsThreadWarningThreshold(
        value: 1,
        threshold: 0
    )) {
        $0.resources.threadWarnings = [
            LatencyBenchmarkWarning(field: "audio.callback", message: "thread warning")
        ]
        $0.thresholds.threadWarningMaxCount = 0
    }
}

@Test
func latencyBenchmarkPhysicalPassCandidateValidates() throws {
    let report = try latencyBenchmarkPassCandidate()

    try report.validate()

    #expect(report.verdict == .pass)
    #expect(report.runMode == .measured)
    #expect(report.evidenceKind == .physicalReferenceRig)
}

@Test
func latencyBenchmarkLowBufferEvidenceValidatesPhysicalAndWarningPaths() throws {
    var report = try latencyBenchmarkPassCandidate()
    report.mediaMode.audio = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 16,
        channelCount: 2,
        sampleFormat: "int16"
    )
    report.latencyProfileEvidence = try lowBufferEvidence(
        profile: .ultraLowLatency16,
        maxStableChannelCount: 64,
        rmeDirectPhysicalEvidence: false
    )

    #expect(throws: LatencyProfileValidationError.physicalRmeDirectEvidenceRequired(
        .ultraLowLatency16
    )) {
        try report.validate()
    }

    report.latencyProfileEvidence = try lowBufferEvidence(
        profile: .ultraLowLatency16,
        maxStableChannelCount: 64
    )
    try report.validate()

    var partialReport = try LatencyBenchmarkSyntheticSmoke.run()
    partialReport.mediaMode.audio = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 8,
        channelCount: 2,
        sampleFormat: "int16"
    )
    partialReport.latencyProfileEvidence = try lowBufferEvidence(
        profile: .extremeLowLatency8,
        maxStableChannelCount: nil,
        longRunDurationSeconds: 1_800
    )

    try partialReport.validate()

    #expect(partialReport.verdict == .partial)
    #expect(partialReport.latencyProfileEvidence?.warnings.contains(.physicalLongRunEvidenceMissing) == true)
}
