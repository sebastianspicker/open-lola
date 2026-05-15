import Foundation
import Testing

@testable import OpenLolaCore

@Test
func latencyBenchmarkPartialFixtureDecodesAndValidates() throws {
    let report = try loadLatencyBenchmarkFixture(named: "latency-benchmark-partial")

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.runMode == .synthetic)
    #expect(report.evidenceKind == .synthetic)
    #expect(report.timing.oneWayEstimateMicroseconds <= report.timing.roundTripMicroseconds)
    #expect(report.thresholds.budgetDocument.contains("latency-budget.md"))
    #expect(Set(report.components.map(\.criticality)).contains(.criticalPath))
}

@Test
func latencyBenchmarkSyntheticSmokeEmitsPartialReport() throws {
    let report = try LatencyBenchmarkSyntheticSmoke.run()

    try report.validate()

    #expect(report.id == "m02-latency-benchmark-synthetic-smoke")
    #expect(report.verdict == .partial)
    #expect(report.resources.allocationWarnings.count == 1)
    #expect(report.resources.threadWarnings.count == 1)
}

@Test
func latencyBenchmarkRepeatedMeasurementUsesWarmupAndSamples() throws {
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

@Test
func latencyBenchmarkSamplingConfigurationRejectsInvalidCounts() throws {
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

@Test
func latencyBenchmarkSummarySeparatesWarmupFromSteadyStatePercentiles() {
    let summary = LatencyBenchmark.summarize(
        samplesMicroseconds: [1, 2, 3],
        warmupSamplesMicroseconds: [1_000],
        warmupIterations: 3
    )

    #expect(summary.sampleCount == 3)
    #expect(summary.coldStartMaxMicroseconds == 1_000)
    #expect(summary.p99Microseconds == 2)
    #expect(summary.maxMicroseconds == 3)
}

@Test
func latencyBenchmarkSummaryReportsMedianAndP99() {
    let summary = LatencyBenchmark.summarize(
        samplesMicroseconds: [1, 100, 2, 3],
        warmupIterations: 3
    )

    #expect(summary.sampleCount == 4)
    #expect(summary.medianMicroseconds == 2)
    #expect(summary.p99Microseconds == 3)
    #expect(summary.maxMicroseconds == 100)
}

@Test
func latencyBenchmarkSummaryFiltersNonFiniteSamples() {
    let summary = LatencyBenchmark.summarize(
        samplesMicroseconds: [1, .infinity, 2, .nan, 3],
        warmupIterations: 3
    )

    #expect(summary.sampleCount == 3)
    #expect(summary.medianMicroseconds.isFinite)
    #expect(summary.p99Microseconds.isFinite)
    #expect(summary.maxMicroseconds == 3)
}

@Test
func latencyBenchmarkUsesExplicitMonotonicClockWithoutClamping() throws {
    let source = try readOpenLolaCoreSource("Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmark.swift")

    #expect(source.contains("private static func monotonicNanoseconds() -> UInt64"))
    #expect(source.contains("clock_gettime_nsec_np(CLOCK_MONOTONIC)"))
    #expect(source.contains("clock_gettime(CLOCK_MONOTONIC, &timestamp)"))
    #expect(source.contains("precondition(end >= start, \"LatencyBenchmark monotonic clock went backwards\")"))
    #expect(source.contains("private static let medianPercentile = 0.50"))
    #expect(source.contains("private static let p99Percentile = 0.99"))
    #expect(source.contains("medianMicroseconds: percentile(sanitized, medianPercentile)"))
    #expect(source.contains("p99Microseconds: percentile(sanitized, p99Percentile)"))
    #expect(source.contains("logger.warning(\"Filtered \\(filteredCount, privacy: .public) non-finite latency benchmark sample(s)\""))
    #expect(!source.contains("samplesMicroseconds.map { $0.isFinite ? max(0, $0) : 0 }"))
    #expect(!source.contains("DispatchTime.now().uptimeNanoseconds"))
    #expect(!source.contains("max(0, durationMicroseconds)"))
    #expect(!source.contains("assert("))
}

@Test
func latencyBenchmarkTimingMetricsDocumentOneWayEstimateMethodology() throws {
    let source = try readOpenLolaCoreSource("Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkTypes.swift")
    let reportSource = try readOpenLolaCoreSource("Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift")

    #expect(source.contains("Estimated one-way latency in microseconds"))
    #expect(source.contains("not an independently clock-synchronized one-way measurement"))
    #expect(source.contains("Round-trip latency in microseconds from the same benchmark methodology"))
    #expect(reportSource.contains("timing.oneWayEstimateMicroseconds <= timing.roundTripMicroseconds"))
}

@Test
func latencyBenchmarkReportDocumentsFailFastValidationSemantics() throws {
    let source = try readOpenLolaCoreSource("Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift")

    #expect(source.contains("Keep report validation fail-fast"))
    #expect(source.contains("Cross-field pass-verdict checks only run after the base report shape is valid."))
    #expect(source.contains("try validateIdentity()"))
    #expect(source.contains("try validatePassVerdict()"))
}

@Test
func m07LatencyProfileSyntheticSmokeCarriesSessionProfileTelemetry() throws {
    let report = try LatencyProfileBenchmarkSyntheticSmoke.run()

    try report.validate()

    let metrics = try #require(report.sessionProfileMetrics)
    #expect(report.id == "m07-latency-profile-synthetic-smoke")
    #expect(metrics.sessionProfile == .directAudioFirst)
    #expect(metrics.rxBufferProfile == .direct)
    #expect(metrics.callbackDurationP99Microseconds == 180)
    #expect(metrics.routeAge.p99Microseconds == 310)
    #expect(metrics.packetAge.p99Microseconds == 240)
    #expect(metrics.underruns == report.faults.underruns)
    #expect(metrics.overruns == report.faults.overruns)
    #expect(metrics.addedBufferCostFrames == report.rxBufferImpact?.addedLatencyFrames)
    #expect(metrics.addedBufferCostPackets == report.rxBufferImpact?.profile.latencyCostPackets)
}

@Test
func latencyBenchmarkRejectsInvalidFixtures() {
    for fixtureName in [
        "latency-missing-hardware",
        "latency-missing-route",
        "latency-missing-timing",
        "latency-missing-thresholds",
        "latency-missing-verdict",
    ] {
        #expect(throws: Error.self) {
            _ = try loadInvalidLatencyBenchmarkFixture(named: fixtureName)
        }
    }
}

@Test
func latencyBenchmarkRejectsSyntheticEvidencePassClaim() throws {
    var report = try latencyBenchmarkPassCandidate()
    report.evidenceKind = .synthetic

    #expect(throws: LatencyBenchmarkValidationError.passWithoutPhysicalReferenceRig) {
        try report.validate()
    }
}

@Test
func latencyBenchmarkRejectsPassWithoutLatencyBudgetReference() throws {
    var report = try latencyBenchmarkPassCandidate()
    report.thresholds.budgetDocument = "docs/mac-port/reports/ad-hoc-thresholds.md"

    #expect(throws: LatencyBenchmarkValidationError.passWithoutLatencyBudgetReference(
        "docs/mac-port/reports/ad-hoc-thresholds.md"
    )) {
        try report.validate()
    }
}

@Test
func latencyBenchmarkRejectsPassWithoutMeasuredCriticalPathComponent() throws {
    var report = try latencyBenchmarkPassCandidate()
    report.components[0].measuredMicroseconds = nil

    #expect(throws: LatencyBenchmarkValidationError.passWithoutMeasuredCriticalPathComponent(
        "audio-interface-buffer"
    )) {
        try report.validate()
    }
}

@Test
func latencyBenchmarkRejectsPassOverOneWayThreshold() throws {
    var report = try latencyBenchmarkPassCandidate()
    report.timing.oneWayEstimateMicroseconds = 5_001

    #expect(throws: LatencyBenchmarkValidationError.passExceedsOneWayThreshold(
        value: 5_001,
        threshold: 5_000
    )) {
        try report.validate()
    }
}

@Test
func latencyBenchmarkRejectsPassThresholdViolations() throws {
    var roundTripReport = try latencyBenchmarkPassCandidate()
    roundTripReport.timing.roundTripMicroseconds = 10_001
    roundTripReport.thresholds.roundTripTargetMicroseconds = 10_000
    #expect(throws: LatencyBenchmarkValidationError.passExceedsRoundTripThreshold(
        value: 10_001,
        threshold: 10_000
    )) {
        try roundTripReport.validate()
    }

    var jitterReport = try latencyBenchmarkPassCandidate()
    jitterReport.timing.jitter.p99Microseconds = 251
    jitterReport.timing.jitter.maxMicroseconds = 300
    jitterReport.thresholds.jitterP99MaxMicroseconds = 250
    #expect(throws: LatencyBenchmarkValidationError.passExceedsJitterThreshold(
        value: 251,
        threshold: 250
    )) {
        try jitterReport.validate()
    }

    var lossReport = try latencyBenchmarkPassCandidate()
    lossReport.loss.lossPercent = 0.11
    lossReport.thresholds.packetLossMaxPercent = 0.1
    #expect(throws: LatencyBenchmarkValidationError.passExceedsLossThreshold(
        value: 0.11,
        threshold: 0.1
    )) {
        try lossReport.validate()
    }

    var cpuReport = try latencyBenchmarkPassCandidate()
    cpuReport.resources.cpuP99Percent = 50.1
    cpuReport.resources.cpuMaxPercent = 60
    cpuReport.thresholds.cpuP99MaxPercent = 50
    #expect(throws: LatencyBenchmarkValidationError.passExceedsCpuThreshold(
        value: 50.1,
        threshold: 50
    )) {
        try cpuReport.validate()
    }

    var underrunReport = try latencyBenchmarkPassCandidate()
    underrunReport.faults.underruns = 1
    underrunReport.thresholds.underrunMaxCount = 0
    #expect(throws: LatencyBenchmarkValidationError.passExceedsUnderrunThreshold(
        value: 1,
        threshold: 0
    )) {
        try underrunReport.validate()
    }

    var droppedFrameReport = try latencyBenchmarkPassCandidate()
    droppedFrameReport.faults.droppedFrames = 1
    droppedFrameReport.thresholds.droppedFrameMaxCount = 0
    #expect(throws: LatencyBenchmarkValidationError.passExceedsDroppedFrameThreshold(
        value: 1,
        threshold: 0
    )) {
        try droppedFrameReport.validate()
    }

    var allocationWarningReport = try latencyBenchmarkPassCandidate()
    allocationWarningReport.resources.allocationWarnings = [
        LatencyBenchmarkWarning(field: "audio.callback", message: "allocation")
    ]
    allocationWarningReport.thresholds.allocationWarningMaxCount = 0
    #expect(throws: LatencyBenchmarkValidationError.passExceedsAllocationWarningThreshold(
        value: 1,
        threshold: 0
    )) {
        try allocationWarningReport.validate()
    }

    var threadWarningReport = try latencyBenchmarkPassCandidate()
    threadWarningReport.resources.threadWarnings = [
        LatencyBenchmarkWarning(field: "audio.callback", message: "thread warning")
    ]
    threadWarningReport.thresholds.threadWarningMaxCount = 0
    #expect(throws: LatencyBenchmarkValidationError.passExceedsThreadWarningThreshold(
        value: 1,
        threshold: 0
    )) {
        try threadWarningReport.validate()
    }
}

@Test
func latencyBenchmarkRejectsNegativeJitterPercentilesBeforeOrdering() throws {
    var report = try latencyBenchmarkPassCandidate()
    report.timing.jitter.p50Microseconds = -1

    #expect(throws: LatencyBenchmarkValidationError.negativeField("timing.jitter.p50Microseconds")) {
        try report.validate()
    }
}

@Test
func latencyBenchmarkRejectsNonFiniteJitterPercentilesBeforeOrdering() throws {
    var report = try latencyBenchmarkPassCandidate()
    report.timing.jitter.maxMicroseconds = .nan

    #expect(throws: LatencyBenchmarkValidationError.nonFiniteField("timing.jitter.maxMicroseconds")) {
        try report.validate()
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
func latencyBenchmarkRejectsFastestPassWithBufferedSessionProfile() throws {
    var report = try latencyBenchmarkPassCandidate()
    report.sessionProfileMetrics = sessionProfileMetrics(
        profile: .balancedAV,
        rxBufferProfile: .small,
        fastestPassClaimed: true
    )

    #expect(throws: LatencyBenchmarkValidationError.passWithFastestIneligibleSessionProfile(
        profile: .balancedAV,
        rxBufferProfile: .small
    )) {
        try report.validate()
    }
}

@Test
func latencyBenchmarkRejectsSixteenFramePassWithoutProfileEvidence() throws {
    var report = try latencyBenchmarkPassCandidate()
    report.mediaMode.audio = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 16,
        channelCount: 2,
        sampleFormat: "int16"
    )
    report.latencyProfileEvidence = nil

    #expect(throws: LatencyBenchmarkValidationError.passWithoutLowBufferProfileEvidence(
        .ultraLowLatency16
    )) {
        try report.validate()
    }
}

@Test
func latencyBenchmarkSixteenFramePhysicalPassRequiresRmeDirectEvidence() throws {
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
}

@Test
func latencyBenchmarkEightFramePartialCarriesWarningEvidence() throws {
    var report = try LatencyBenchmarkSyntheticSmoke.run()
    report.mediaMode.audio = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 8,
        channelCount: 2,
        sampleFormat: "int16"
    )
    report.latencyProfileEvidence = try lowBufferEvidence(
        profile: .extremeLowLatency8,
        maxStableChannelCount: nil,
        longRunDurationSeconds: 1_800
    )

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.latencyProfileEvidence?.warnings.contains(.physicalLongRunEvidenceMissing) == true)
}

@Test
func latencyBenchmarkJSONRoundTripPreservesReport() throws {
    let report = try loadLatencyBenchmarkFixture(named: "latency-benchmark-partial")
    let jsonData = try report.prettyJSONData()
    let decoded = try LatencyBenchmarkReport.decode(from: jsonData)

    #expect(decoded == report)
}

private func latencyBenchmarkPassCandidate() throws -> LatencyBenchmarkReport {
    var report = try LatencyBenchmarkSyntheticSmoke.run()
    report.id = "m02-latency-benchmark-physical-pass-candidate"
    report.title = "M02 latency benchmark physical pass candidate"
    report.runMode = .measured
    report.evidenceKind = .physicalReferenceRig
    report.hardware = HardwareIdentity(
        referenceMac: "reference-mac-a",
        audioInterface: "RME MADIface USB",
        osVersion: "macOS 15.4",
        driverVersion: "RME 4.17"
    )
    report.route = RouteIdentity(label: "direct-wired-p2p", topology: "two-mac-direct-ethernet")
    report.timing = LatencyBenchmarkTimingMetrics(
        oneWayEstimateMicroseconds: 4_900,
        roundTripMicroseconds: 9_800,
        jitter: LatencyJitterMetrics(
            p50Microseconds: 60,
            p95Microseconds: 120,
            p99Microseconds: 180,
            maxMicroseconds: 240
        )
    )
    report.loss = LatencyBenchmarkLossMetrics(lostPackets: 0, latePackets: 0, lossPercent: 0)
    report.faults = LatencyBenchmarkFaultMetrics(
        underruns: 0,
        overruns: 0,
        missedDeadlines: 0,
        droppedFrames: 0
    )
    report.resources.allocationWarnings = []
    report.resources.threadWarnings = []
    report.notes = "Physical reference-rig candidate used only for validator behavior."
    report.verdict = .pass
    try report.validate()
    return report
}

private func sessionProfileMetrics(
    profile: SessionLatencyProfile,
    rxBufferProfile: RxBufferProfile,
    fastestPassClaimed: Bool
) -> SessionLatencyProfileBenchmarkMetrics {
    SessionLatencyProfileBenchmarkMetrics(
        sessionProfile: profile,
        rxBufferProfile: rxBufferProfile,
        callbackDurationP99Microseconds: 120,
        routeAge: UdpPcmPacketAgeMetrics(
            p50Microseconds: 100,
            p95Microseconds: 150,
            p99Microseconds: 180,
            maxMicroseconds: 220
        ),
        packetAge: UdpPcmPacketAgeMetrics(
            p50Microseconds: 90,
            p95Microseconds: 140,
            p99Microseconds: 170,
            maxMicroseconds: 210
        ),
        jitter: LatencyJitterMetrics(
            p50Microseconds: 30,
            p95Microseconds: 70,
            p99Microseconds: 90,
            maxMicroseconds: 120
        ),
        underruns: 0,
        overruns: 0,
        addedBufferCostFrames: rxBufferProfile == .direct ? 32 : 64,
        addedBufferCostPackets: rxBufferProfile == .direct ? 1 : 2,
        addedBufferCostMicroseconds: rxBufferProfile == .direct
            ? 666.6666666666666
            : 1_333.3333333333333,
        fastestPassClaimed: fastestPassClaimed
    )
}

private func lowBufferEvidence(
    profile: LatencyProfile,
    maxStableChannelCount: Int?,
    rmeDirectPhysicalEvidence: Bool = true,
    routeBenchmarkPassed: Bool = true,
    longRunDurationSeconds: Int? = 7_200
) throws -> LatencyProfileEvidence {
    try LatencyProfileEvidence(
        profile: profile,
        explicitOptIn: true,
        experimentalOptIn: profile == .extremeLowLatency8,
        warningAcknowledged: profile == .extremeLowLatency8 || profile == .ultraLowLatency16,
        rmeDirectPhysicalEvidence: rmeDirectPhysicalEvidence,
        routeBenchmarkPassed: routeBenchmarkPassed,
        maxStableChannelCount: maxStableChannelCount,
        longRunDurationSeconds: longRunDurationSeconds,
        rollbackProfile: profile == .extremeLowLatency8 ? .ultraLowLatency16 : .safeLowLatency,
        budget: .calculate(
            profile: profile,
            sampleRateHertz: 48_000,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        )
    )
}

private func loadLatencyBenchmarkFixture(named name: String) throws -> LatencyBenchmarkReport {
    let url = try latencyBenchmarkFixtureURL(named: name, directory: "valid")
    let report = try LatencyBenchmarkReport.decode(from: Data(contentsOf: url))
    try report.validate()
    return report
}

private func loadInvalidLatencyBenchmarkFixture(named name: String) throws -> LatencyBenchmarkReport {
    let url = try latencyBenchmarkFixtureURL(named: name, directory: "invalid")
    let report = try LatencyBenchmarkReport.decode(from: Data(contentsOf: url))
    try report.validate()
    return report
}

private func latencyBenchmarkFixtureURL(named name: String, directory: String) throws -> URL {
    let nestedURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "LatencyBenchmarkReports/\(directory)"
    )
    return try #require(nestedURL ?? Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    ))
}

private func readOpenLolaCoreSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
