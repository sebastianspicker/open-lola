// Verifies that latency tuning pass candidate validates.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func latencyTuningPassCandidateValidates() throws {
    let report = try latencyTuningPassCandidate()

    try report.validate()

    #expect(report.verdict == .pass)
    #expect(report.selectedCandidateReportId == "direct-48k-32f")
}

@Test
func latencyTuningRejectsInvalidPassEvidence() throws {
    try expectLatencyTuningEvidenceIdentityErrors()
    try expectLatencyTuningSelectionErrors()
    try expectLatencyTuningProfileEvidenceErrors()
}

private func expectLatencyTuningEvidenceIdentityErrors() throws {
    try expectLatencyTuningError(.passWithoutMeasuredRun) {
        $0.runMode = .synthetic
    }
    try expectLatencyTuningError(.includedCandidateHardwareMismatch("direct-48k-32f")) {
        $0.candidates[0].hardware = HardwareIdentity(
            referenceMac: "reference-mac-b",
            audioInterface: "RME MADIface XT",
            osVersion: "macOS 15.4",
            driverVersion: "RME 4.17"
        )
    }
    try expectLatencyTuningError(.includedCandidateRouteMismatch("direct-48k-32f")) {
        $0.candidates[0].route = RouteIdentity(
            label: "campus-path",
            topology: "managed-campus-network"
        )
    }
    try expectLatencyTuningError(
        .nonPositiveField("candidates.durationSeconds"),
        fixture: LatencyTuningSyntheticSmoke.run()
    ) {
        $0.candidates[0].durationSeconds = 0
    }
}

private func expectLatencyTuningSelectionErrors() throws {
    try expectLatencyTuningError(.passSelectedCandidateIsNotFastest(
        selected: "direct-48k-64f",
        fastest: "direct-48k-32f"
    )) {
        $0.selectedCandidateReportId = "direct-48k-64f"
    }
    try expectLatencyTuningError(.passSelectedCandidateIsNotStable("direct-48k-32f")) {
        let index = try #require($0.candidates.firstIndex { $0.reportId == "direct-48k-32f" })
        $0.candidates[index].stable = false
    }
    try expectLatencyTuningError(.promotedChangeIncreasesOneWay(
        changeId: "buffer-64-to-32",
        before: 3_200,
        after: 3_600
    )) {
        $0.tuningChanges[0].afterOneWayMicroseconds = 3_600
    }
    try expectLatencyTuningError(.rollbackCandidateIneligible("direct-48k-64f")) {
        let index = try #require($0.candidates.firstIndex { $0.reportId == "direct-48k-64f" })
        $0.candidates[index].stable = false
    }
    try expectLatencyTuningError(.passWithoutSameHardwareBaselineComparison) {
        $0.comparedWithSameHardwareLolaBaseline = false
    }
}

private func expectLatencyTuningProfileEvidenceErrors() throws {
    try expectLatencyTuningError(.passSelectedCandidateMissingProfileEvidence(
        "direct-48k-16f",
        .ultraLowLatency16
    )) {
        let sixteen = latencyTuningCandidate(LatencyTuningCandidateFixture(
            reportId: "direct-48k-16f",
            hardware: $0.comparisonHardware,
            route: $0.comparisonRoute,
            framesPerBuffer: 16,
            oneWayMicroseconds: 2_100,
            p99JitterMicroseconds: 260,
            cpuP99Percent: 24,
            stable: true,
            accepted: true,
            includedInSelection: true,
            exclusionReason: nil
        ))
        $0.candidates.insert(sixteen, at: 0)
        $0.sourceReportIds.append("direct-48k-16f")
        $0.selectedCandidateReportId = "direct-48k-16f"
        $0.tuningChanges[0].afterCandidateReportId = "direct-48k-16f"
        $0.tuningChanges[0].afterOneWayMicroseconds = 2_100
    }
}

@Test
func latencyTuningTieBreaksFastestStableByCandidateOrderNotReportIdText() throws {
    var report = try latencyTuningPassCandidate()
    var first = report.candidates[0]
    first.reportId = "z-direct-48k-32f"
    var second = first
    second.reportId = "a-direct-48k-32f"
    report.candidates = [first, second, report.candidates[1], report.candidates[2]]
    report.sourceReportIds = [
        "z-direct-48k-32f",
        "a-direct-48k-32f",
        "direct-48k-64f",
        "campus-48k-32f"
    ]
    report.selectedCandidateReportId = "z-direct-48k-32f"
    report.tuningChanges[0].afterCandidateReportId = "z-direct-48k-32f"

    try report.validate()

    #expect(report.selectedCandidateReportId == "z-direct-48k-32f")
    #expect(report.candidates.first?.reportId == "z-direct-48k-32f")
}

@Test
func latencyTuningAcceptsSixteenFrameSelectedPassWithRollbackProfileEvidence() throws {
    var report = try latencyTuningPassCandidate()
    var sixteen = latencyTuningCandidate(LatencyTuningCandidateFixture(
            reportId: "direct-48k-16f",
            hardware: report.comparisonHardware,
            route: report.comparisonRoute,
            framesPerBuffer: 16,
            oneWayMicroseconds: 2_100,
            p99JitterMicroseconds: 260,
            cpuP99Percent: 24,
            stable: true,
            accepted: true,
            includedInSelection: true,
            exclusionReason: nil
        ))
    sixteen.latencyProfileEvidence = try tuningLowBufferEvidence(
        profile: .ultraLowLatency16,
        maxStableChannelCount: 64
    )
    report.candidates.insert(sixteen, at: 0)
    report.sourceReportIds.append("direct-48k-16f")
    report.selectedCandidateReportId = "direct-48k-16f"
    report.tuningChanges[0].afterCandidateReportId = "direct-48k-16f"
    report.tuningChanges[0].afterOneWayMicroseconds = 2_100

    try report.validate()

    #expect(report.selectedCandidateReportId == "direct-48k-16f")
}

private func expectLatencyTuningError(
    _ expected: LatencyTuningValidationError,
    fixture: LatencyTuningReport? = nil,
    mutate: (inout LatencyTuningReport) throws -> Void
) throws {
    var report = try fixture ?? latencyTuningPassCandidate()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func latencyTuningPassCandidate() throws -> LatencyTuningReport {
    let hardware = latencyTuningHardware()
    let route = latencyTuningDirectRoute()
    let report = LatencyTuningReport(
        id: "m07-latency-tuning-pass-candidate",
        title: "M07 latency tuning pass candidate",
        capturedAt: "2026-05-03T00:00:00Z",
        runMode: .measured,
        evidenceKind: .physicalReferenceRig,
        comparisonHardware: hardware,
        comparisonRoute: route,
        sourceReportIds: ["direct-48k-32f", "direct-48k-64f", "campus-48k-32f"],
        candidates: latencyTuningCandidates(hardware: hardware, route: route),
        selectedCandidateReportId: "direct-48k-32f",
        rollbackCandidateReportId: "direct-48k-64f",
        sameHardwareLolaBaselineReportId: "lola-direct-link-baseline",
        comparedWithSameHardwareLolaBaseline: true,
        thresholds: latencyTuningThresholds(),
        tuningChanges: latencyTuningChanges(),
        verdict: .pass,
        notes: "Measured pass candidate for validator behavior."
    )
    try report.validate()
    return report
}

private func latencyTuningHardware() -> HardwareIdentity {
    HardwareIdentity(
        referenceMac: "reference-mac-a",
        audioInterface: "RME MADIface XT",
        osVersion: "macOS 15.4",
        driverVersion: "RME 4.17"
    )
}

private func latencyTuningDirectRoute() -> RouteIdentity {
    RouteIdentity(label: "direct-link", topology: "two-mac-direct-ethernet")
}

private func latencyTuningCandidates(
    hardware: HardwareIdentity,
    route: RouteIdentity
) -> [LatencyTuningCandidate] {
    [
        latencyTuningCandidate(LatencyTuningCandidateFixture(
            reportId: "direct-48k-32f",
            hardware: hardware,
            route: route,
            framesPerBuffer: 32,
            oneWayMicroseconds: 2_550,
            p99JitterMicroseconds: 210,
            cpuP99Percent: 19,
            stable: true,
            accepted: true,
            includedInSelection: true,
            exclusionReason: nil
        )),
        latencyTuningCandidate(LatencyTuningCandidateFixture(
            reportId: "direct-48k-64f",
            hardware: hardware,
            route: route,
            framesPerBuffer: 64,
            oneWayMicroseconds: 3_200,
            p99JitterMicroseconds: 180,
            cpuP99Percent: 15,
            stable: true,
            accepted: true,
            includedInSelection: true,
            exclusionReason: nil
        )),
        latencyTuningCandidate(LatencyTuningCandidateFixture(
            reportId: "campus-48k-32f",
            hardware: hardware,
            route: RouteIdentity(label: "campus-path", topology: "managed-campus-network"),
            framesPerBuffer: 32,
            oneWayMicroseconds: 3_900,
            p99JitterMicroseconds: 700,
            cpuP99Percent: 20,
            stable: true,
            accepted: true,
            includedInSelection: false,
            exclusionReason: "Different route label; retained as separate-route evidence only."
        ))
    ]
}

private func latencyTuningThresholds() -> LatencyTuningThresholds {
    LatencyTuningThresholds(
        budgetDocument: "docs/latency-budget.md#audio-budget",
        minimumDurationSeconds: 3_600,
        oneWayTargetMicroseconds: 5_000,
        jitterP99MaxMicroseconds: 1_000,
        packetLossMaxPercent: 0.1,
        cpuP99MaxPercent: 75,
        underrunMaxCount: 0,
        callbackDeadlineWarningMaxCount: 0,
        allocationWarningMaxCount: 0,
        artifactWarningMaxCount: 0
    )
}

private func latencyTuningChanges() -> [LatencyTuningChangeRecord] {
    [
        LatencyTuningChangeRecord(
            id: "buffer-64-to-32",
            summary: "Promote the 32-frame direct route over the 64-frame fallback.",
            beforeCandidateReportId: "direct-48k-64f",
            afterCandidateReportId: "direct-48k-32f",
            beforeOneWayMicroseconds: 3_200,
            afterOneWayMicroseconds: 2_550,
            promoted: true,
            notes: "Measured on the same reference Mac, interface, route, and sample rate."
        )
    ]
}

private struct LatencyTuningCandidateFixture {
    var reportId: String
    var hardware: HardwareIdentity
    var route: RouteIdentity
    var framesPerBuffer: Int
    var oneWayMicroseconds: Double
    var p99JitterMicroseconds: Double
    var cpuP99Percent: Double
    var stable: Bool
    var accepted: Bool
    var includedInSelection: Bool
    var exclusionReason: String?
}

private func latencyTuningCandidate(_ fixture: LatencyTuningCandidateFixture) -> LatencyTuningCandidate {
    LatencyTuningCandidate(
        reportId: fixture.reportId,
        hardware: fixture.hardware,
        route: fixture.route,
        audioMode: latencyTuningAudioMode(framesPerBuffer: fixture.framesPerBuffer),
        durationSeconds: 3_600,
        timing: latencyTuningTiming(
            oneWayMicroseconds: fixture.oneWayMicroseconds,
            p99JitterMicroseconds: fixture.p99JitterMicroseconds
        ),
        loss: LatencyBenchmarkLossMetrics(lostPackets: 0, latePackets: 0, lossPercent: 0),
        faults: LatencyBenchmarkFaultMetrics(underruns: 0, overruns: 0, missedDeadlines: 0, droppedFrames: 0),
        resources: latencyTuningResources(cpuP99Percent: fixture.cpuP99Percent),
        callbackDeadlineWarnings: 0,
        artifactWarnings: [],
        latencyProfileEvidence: nil,
        stable: fixture.stable,
        accepted: fixture.accepted,
        includedInSelection: fixture.includedInSelection,
        exclusionReason: fixture.exclusionReason,
        notes: "Measured candidate row for validator behavior."
    )
}

private func latencyTuningAudioMode(framesPerBuffer: Int) -> AudioMode {
    AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: framesPerBuffer,
        channelCount: 2,
        sampleFormat: "float32LittleEndian"
    )
}

private func latencyTuningTiming(
    oneWayMicroseconds: Double,
    p99JitterMicroseconds: Double
) -> LatencyBenchmarkTimingMetrics {
    LatencyBenchmarkTimingMetrics(
        oneWayEstimateMicroseconds: oneWayMicroseconds,
        roundTripMicroseconds: oneWayMicroseconds * 2,
        jitter: LatencyJitterMetrics(
            p50Microseconds: 70,
            p95Microseconds: p99JitterMicroseconds * 0.75,
            p99Microseconds: p99JitterMicroseconds,
            maxMicroseconds: p99JitterMicroseconds + 60
        )
    )
}

private func latencyTuningResources(cpuP99Percent: Double) -> LatencyBenchmarkResourceMetrics {
    LatencyBenchmarkResourceMetrics(
        cpuP50Percent: 7,
        cpuP95Percent: max(cpuP99Percent - 3, 0),
        cpuP99Percent: cpuP99Percent,
        cpuMaxPercent: cpuP99Percent + 4,
        residentMemoryMegabytes: 96,
        allocationWarnings: [],
        threadWarnings: []
    )
}

private func tuningLowBufferEvidence(
    profile: LatencyProfile,
    maxStableChannelCount: Int?
) throws -> LatencyProfileEvidence {
    try lowBufferEvidence(
        profile: profile,
        maxStableChannelCount: maxStableChannelCount,
        sampleFormat: .float32LittleEndian
    )
}

private func loadLatencyTuningFixture(named name: String) throws -> LatencyTuningReport {
    let nestedURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "LatencyTuningReports/valid"
    )
    let url = try #require(nestedURL ?? Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    ))
    let report = try LatencyTuningReport.decode(from: Data(contentsOf: url))
    try report.validate()
    return report
}
