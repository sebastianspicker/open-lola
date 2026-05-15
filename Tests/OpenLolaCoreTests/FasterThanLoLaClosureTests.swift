import Foundation
import Testing

@testable import OpenLolaCore

@Test
func fasterThanLoLaClosureSyntheticSmokeEmitsPartialReport() throws {
    let report = FasterThanLoLaClosureSyntheticSmoke.run()

    try report.validate()

    #expect(report.claimScope == .fieldReady)
    #expect(report.verdict == .partial)
    #expect(report.evidence.map(\.lane).contains(.f01RmeMadiHardwareBaseline))
    #expect(report.evidence.map(\.lane).contains(.f09FieldReadiness))
    #expect(report.comparison.result == .unavailable)
    #expect(report.fastestPathBlockedByParity == false)
}

@Test
func fasterThanLoLaClosureRunConfigurationParsesAudioOnlyArguments() throws {
    let configuration = try FasterThanLoLaClosureRunConfiguration.parse([
        "--claim-scope", "audioOnly",
        "--f01-report", "m01-rme-hardware",
        "--f02-report", "m02-realtime-engine",
        "--f03-report", "m05-direct-route",
        "--f04-report", "m06-drift-lola-baseline",
        "--output", "reports/f10-faster-than-lola.json",
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
            .f04DriftPlcLolaBaseline: "m06-drift-lola-baseline",
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
func fasterThanLoLaClosureRejectsPassWithoutMeasuredRun() throws {
    var report = try passCandidateReport()
    report.runMode = .synthetic

    #expect(throws: FasterThanLoLaClosureValidationError.passWithoutMeasuredRun) {
        try report.validate()
    }
}

@Test
func fasterThanLoLaClosureRejectsPassWithoutRequiredEvidence() throws {
    var report = try passCandidateReport()
    report.evidence.removeAll { $0.lane == .f03PeerToPeerRoute }

    #expect(throws: FasterThanLoLaClosureValidationError.passWithoutRequiredEvidence(.f03PeerToPeerRoute)) {
        try report.validate()
    }
}

@Test
func fasterThanLoLaClosureRejectsPassWithPartialEvidence() throws {
    var report = try passCandidateReport()
    let index = try #require(report.evidence.firstIndex { $0.lane == .f02RealtimeDuplexAudioEngine })
    report.evidence[index].verdict = .partial

    #expect(throws: FasterThanLoLaClosureValidationError.passWithoutPassEvidence(
        .f02RealtimeDuplexAudioEngine,
        .partial
    )) {
        try report.validate()
    }
}

@Test
func fasterThanLoLaClosureRejectsPassWithoutMeasuredLolaBaseline() throws {
    var report = try passCandidateReport()
    report.comparison.lolaBaselineMeasured = false

    #expect(throws: FasterThanLoLaClosureValidationError.passWithoutMeasuredLolaBaseline) {
        try report.validate()
    }
}

@Test
func fasterThanLoLaClosureRejectsPassWhenOpenLolaIsNotFaster() throws {
    var report = try passCandidateReport()
    report.comparison.result = .openLolaEquivalent

    #expect(throws: FasterThanLoLaClosureValidationError.passWithoutOpenLolaFaster(.openLolaEquivalent)) {
        try report.validate()
    }
}

@Test
func fasterThanLoLaClosureRejectsPassWithoutLatencyWin() throws {
    var report = try passCandidateReport()
    report.comparison.openLolaLatency.p99Milliseconds = report.comparison.lolaLatency.p99Milliseconds

    #expect(throws: FasterThanLoLaClosureValidationError.passWithoutLatencyWin("p99Milliseconds")) {
        try report.validate()
    }
}

@Test
func fasterThanLoLaClosureRejectsPassWithShortRun() throws {
    var report = try passCandidateReport()
    report.comparison.durationSeconds = 3_599

    #expect(throws: FasterThanLoLaClosureValidationError.passWithRunShorterThanSixtyMinutes) {
        try report.validate()
    }
}

@Test
func fasterThanLoLaClosureRejectsPassWithArtifacts() throws {
    var report = try passCandidateReport()
    report.comparison.artifactsDetected = true

    #expect(throws: FasterThanLoLaClosureValidationError.passWithLossLateUnderrunOrArtifacts) {
        try report.validate()
    }
}

private func passCandidateReport() throws -> FasterThanLoLaClosureReport {
    FasterThanLoLaClosureReport(
        id: "f10-faster-than-lola-pass-candidate",
        title: "F10 faster than LoLa pass candidate",
        capturedAt: "2026-05-03T00:00:00Z",
        runMode: .measured,
        claimScope: .audioOnly,
        evidence: FasterThanLoLaClaimScope.audioOnly.requiredEvidenceLanes.map { lane in
            FasterThanLoLaEvidenceReference(
                lane: lane,
                reportId: "measured-\(lane.rawValue)",
                verdict: .pass,
                measured: true,
                physicalOrCleanMacEvidence: true,
                packetCaptureOrArtifactEvidence: true,
                notes: "Measured PASS evidence for \(lane.rawValue)."
            )
        },
        comparison: FasterThanLoLaBenchmarkComparison(
            lolaBaselineReportId: "measured-lola-baseline",
            openLolaReportId: "measured-open-lola",
            lolaVersion: "LoLa 2.0",
            lolaSettings: "RME MADI 48 kHz 32-frame direct route",
            routeLabel: "direct-rme-madi-p2p",
            packetMode: UdpPcmPacketMode(
                sampleRateHertz: 48_000,
                framesPerPacket: 32,
                channelCount: 2,
                sampleFormat: .float32LittleEndian
            ),
            fixedPlayoutTargetFrames: 32,
            durationSeconds: 3_600,
            lolaBaselineMeasured: true,
            measuredOnSameHardwareAndRoute: true,
            openLolaLatency: LolaBaselineLatencyMetrics(
                p50Milliseconds: 2.1,
                p95Milliseconds: 2.4,
                p99Milliseconds: 2.7,
                maxMilliseconds: 3.1
            ),
            lolaLatency: LolaBaselineLatencyMetrics(
                p50Milliseconds: 2.4,
                p95Milliseconds: 2.7,
                p99Milliseconds: 3.1,
                maxMilliseconds: 3.6
            ),
            lostPackets: 0,
            latePackets: 0,
            underruns: 0,
            maxAbsoluteDriftPpm: 0.2,
            artifactsDetected: false,
            result: .openLolaFaster
        ),
        parityLedgerId: "g16-lola-parity-deferred-ledger-pass",
        parityFeaturesDeferred: true,
        windowsWireCompatibilityDeferred: true,
        fastestPathBlockedByParity: false,
        verdict: .pass,
        notes: "Measured audio-only F10 closure candidate."
    )
}
