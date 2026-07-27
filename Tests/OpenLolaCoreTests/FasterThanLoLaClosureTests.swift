// Verifies that Faster-than-LoLa closure run configuration parses audio-only arguments.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func fasterThanLoLaClosureRunConfigurationParsesAudioOnlyArguments() throws {
    let configuration = try FasterThanLoLaClosureRunConfiguration.parse([
        "--claim-scope", "audioOnly",
        "--f01-report", "m01-rme-hardware",
        "--f02-report", "m02-realtime-engine",
        "--f03-report", "m05-direct-route",
        "--f04-report", "m06-drift-lola-baseline",
        "--output", "reports/f10-faster-than-lola.json"
    ])

    #expect(configuration.claimScope == .audioOnly)
    #expect(configuration.reportIds[.f01RmeMadiHardwareBaseline] == "m01-rme-hardware")
    #expect(configuration.reportIds[.f04DriftPlcLolaBaseline] == "m06-drift-lola-baseline")
    #expect(configuration.outputPath == "reports/f10-faster-than-lola.json")
}

@Test
func fasterThanLoLaClosureRunnerBuildsPartialAudioLedger() throws {
    let configuration = FasterThanLoLaClosureRunConfiguration(
        claimScope: .audioOnly,
        reportIds: [
            .f01RmeMadiHardwareBaseline: "m01-rme-hardware",
            .f02RealtimeDuplexAudioEngine: "m02-realtime-engine",
            .f03PeerToPeerRoute: "m05-direct-route",
            .f04DriftPlcLolaBaseline: "m06-drift-lola-baseline"
        ],
        outputPath: "reports/f10-faster-than-lola.json"
    )

    let report = FasterThanLoLaClosureRunner.run(configuration: configuration)

    try report.validate()

    #expect(report.id == "f10-faster-than-lola-closure-run")
    #expect(report.claimScope == .audioOnly)
    #expect(report.verdict == .partial)
    #expect(report.evidence.count == 4)
    #expect(report.evidence.allSatisfy { $0.verdict == .partial })
}

@Test
func fasterThanLoLaClosurePassCandidateValidates() throws {
    let report = try passCandidateReport()

    try report.validate()

    #expect(report.verdict == .pass)
}

@Test
func fasterThanLoLaClosureRejectsInvalidPassEvidence() throws {
    try expectFasterThanLoLaClosureError(.passWithoutMeasuredRun) {
        $0.runMode = .synthetic
    }
    try expectFasterThanLoLaClosureError(.passWithoutRequiredEvidence(.f03PeerToPeerRoute)) {
        $0.evidence.removeAll { $0.lane == .f03PeerToPeerRoute }
    }
    try expectFasterThanLoLaClosureError(.passWithoutPassEvidence(
        .f02RealtimeDuplexAudioEngine,
        .partial
    )) {
        let index = try #require($0.evidence.firstIndex { $0.lane == .f02RealtimeDuplexAudioEngine })
        $0.evidence[index].verdict = .partial
    }
    try expectFasterThanLoLaClosureError(.passWithoutMeasuredLolaBaseline) {
        $0.comparison.lolaBaselineMeasured = false
    }
    try expectFasterThanLoLaClosureError(.passWithoutOpenLolaFaster(.openLolaEquivalent)) {
        $0.comparison.result = .openLolaEquivalent
    }
    try expectFasterThanLoLaClosureError(.passWithoutLatencyWin("p99Milliseconds")) {
        $0.comparison.openLolaLatency.p99Milliseconds = $0.comparison.lolaLatency.p99Milliseconds
    }
    try expectFasterThanLoLaClosureError(.passWithRunShorterThanSixtyMinutes) {
        $0.comparison.durationSeconds = 3_599
    }
    try expectFasterThanLoLaClosureError(.passWithLossLateUnderrunOrArtifacts) {
        $0.comparison.artifactsDetected = true
    }
}

private func passCandidateReport() throws -> FasterThanLoLaClosureReport {
    let input = FasterThanLoLaClosureReport.Input(
        metadata: .init(
            id: "f10-faster-than-lola-pass-candidate",
            title: "F10 faster than LoLa pass candidate",
            capturedAt: "2026-05-03T00:00:00Z",
            runMode: .measured,
            claimScope: .audioOnly
        ),
        claimEvidence: .init(
            evidence: fasterThanLoLaPassEvidence(),
            comparison: fasterThanLoLaPassComparison()
        ),
        parity: .init(
            ledgerID: "g16-lola-parity-deferred-ledger-pass",
            featuresDeferred: true,
            windowsWireCompatibilityDeferred: true,
            fastestPathBlocked: false
        ),
        outcome: .init(
            verdict: .pass,
            notes: "Measured audio-only F10 closure candidate."
        )
    )
    return FasterThanLoLaClosureReport(input)
}

private func fasterThanLoLaPassEvidence() -> [FasterThanLoLaEvidenceReference] {
    FasterThanLoLaClaimScope.audioOnly.requiredEvidenceLanes.map { lane in
        FasterThanLoLaEvidenceReference(
            FasterThanLoLaEvidenceReference.Input(
                identity: .init(lane: lane, reportId: "measured-\(lane.rawValue)"),
                measurement: .init(verdict: .pass, measured: true),
                provenance: .init(
                    physicalOrCleanMacEvidence: true,
                    packetCaptureOrArtifactEvidence: true,
                    notes: "Measured PASS evidence for \(lane.rawValue)."
                )
            )
        )
    }
}

private func fasterThanLoLaPassComparison() -> FasterThanLoLaBenchmarkComparison {
    FasterThanLoLaBenchmarkComparison(fasterThanLoLaPassComparisonInput())
}

private func fasterThanLoLaPassComparisonInput() -> FasterThanLoLaBenchmarkComparison.Input {
    let baselineIdentity = FasterThanLoLaBenchmarkComparison.BaselineIdentity(
        lolaBaselineReportID: "measured-lola-baseline", openLolaReportID: "measured-open-lola",
        lolaVersion: "LoLa 2.0", lolaSettings: "RME MADI 48 kHz 32-frame direct route",
        routeLabel: "direct-rme-madi-p2p"
    )
    let packetRun = FasterThanLoLaBenchmarkComparison.PacketRun(
        packetMode: UdpPcmPacketMode(sampleRateHertz: 48_000, framesPerPacket: 32, channelCount: 2, sampleFormat: .float32LittleEndian),
        fixedPlayoutTargetFrames: 32, durationSeconds: 3_600
    )
    let measurements = FasterThanLoLaBenchmarkComparison.Measurements(
        lolaBaselineMeasured: true, sameHardwareAndRoute: true,
        openLolaLatency: LolaBaselineLatencyMetrics(p50Milliseconds: 2.1, p95Milliseconds: 2.4, p99Milliseconds: 2.7, maxMilliseconds: 3.1),
        lolaLatency: LolaBaselineLatencyMetrics(p50Milliseconds: 2.4, p95Milliseconds: 2.7, p99Milliseconds: 3.1, maxMilliseconds: 3.6)
    )
    let quality = FasterThanLoLaBenchmarkComparison.Quality(
        packetHealth: .init(lostPackets: 0, latePackets: 0, underruns: 0),
        assessment: .init(maxAbsoluteDriftPpm: 0.2, artifactsDetected: false, result: .openLolaFaster)
    )
    return FasterThanLoLaBenchmarkComparison.Input(
        baselineIdentity: baselineIdentity, packetRun: packetRun,
        measurements: measurements, quality: quality
    )
}

private func expectFasterThanLoLaClosureError(
    _ expected: FasterThanLoLaClosureValidationError,
    mutate: (inout FasterThanLoLaClosureReport) throws -> Void
) throws {
    var report = try passCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}
