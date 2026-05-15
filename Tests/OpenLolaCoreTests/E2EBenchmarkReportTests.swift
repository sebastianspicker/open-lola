import Foundation
import Testing

@testable import OpenLolaCore

@Test
func e2eBenchmarkSyntheticSmokeEmitsPartialReport() throws {
    let report = try E2EBenchmarkSyntheticSmoke.run()

    try report.validate()

    #expect(report.id == "m13-e2e-integrated-benchmark-synthetic-smoke")
    #expect(report.runMode == .synthetic)
    #expect(report.evidenceKind == .synthetic)
    #expect(report.verdict == .partial)
    #expect(Set(report.profiles.map(\.profile)) == Set(E2EBenchmarkProfile.allCases))
    #expect(Set(report.impairments.map(\.profile)) == Set(E2EBenchmarkImpairmentProfile.allCases))
    #expect(report.recovery.reconnectEvents > 0)
    #expect(report.recovery.cleanShutdownObserved)
}

@Test
func e2eBenchmarkSyntheticSmokeUsesDirectZeroAudioDelta() throws {
    let source = try readE2ESource("Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkSyntheticSmoke.swift")

    #expect(source.contains("audio: audioMetrics(delta: 0)"))
    #expect(!source.contains("profile == .audioOnlyDirect ? 0 : 0"))
}

@Test
func e2eBenchmarkRunConfigurationParsesRequiredArguments() throws {
    let configuration = try E2EBenchmarkRunConfiguration.parse([
        "--audio-benchmark", "reports/audio.json",
        "--integrated-av", "reports/integrated-av.json",
        "--video-transport", "reports/video-transport.json",
        "--performance-audit", "reports/performance.json",
        "--duration-seconds", "1800",
        "--output", "reports/m13-e2e.json",
    ])

    #expect(configuration.audioBenchmarkPath == "reports/audio.json")
    #expect(configuration.integratedAvPath == "reports/integrated-av.json")
    #expect(configuration.videoTransportPath == "reports/video-transport.json")
    #expect(configuration.performanceAuditPath == "reports/performance.json")
    #expect(configuration.durationSeconds == 1800)
    #expect(configuration.outputPath == "reports/m13-e2e.json")
}

@Test
func e2eBenchmarkRunConfigurationUsesSharedKeyValueParser() throws {
    let source = try readE2ESource("Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkRunner.swift")

    #expect(source.contains("KeyValueArgumentParser.parseValues"))
    #expect(!source.contains("while index < arguments.count"))
}

@Test
func e2eBenchmarkCommandChecksInputExistenceWithComponentLabels() throws {
    let source = try readE2ESource("Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift")

    #expect(source.contains("private func e2eBenchmarkInputData(path: String, label: String) throws -> Data"))
    #expect(source.contains("FileManager.default.fileExists(atPath: path)"))
    #expect(source.contains("missing \\(label): \\(path)"))
    #expect(source.contains("label: \"audio benchmark\""))
    #expect(source.contains("label: \"integrated A/V report\""))
    #expect(source.contains("label: \"video transport report\""))
    #expect(source.contains("label: \"performance audit report\""))
}

@Test
func e2eBenchmarkRunnerAggregatesPartialInputs() throws {
    let configuration = E2EBenchmarkRunConfiguration(
        audioBenchmarkPath: "reports/audio.json",
        integratedAvPath: "reports/integrated-av.json",
        videoTransportPath: "reports/video-transport.json",
        performanceAuditPath: "reports/performance.json",
        durationSeconds: 60,
        outputPath: "reports/m13-e2e.json"
    )
    let report = try E2EBenchmarkRunner.run(
        configuration: configuration,
        audioBenchmark: try LatencyBenchmarkSyntheticSmoke.run(),
        integratedAv: IntegratedHeadlessAvSyntheticSmoke.run(),
        videoTransport: VideoTransportSyntheticSmoke.run(),
        performanceAudit: PerformanceAuditSyntheticSmoke.run()
    )

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.componentReports.audioBenchmarkReportId == "m02-latency-benchmark-synthetic-smoke")
    #expect(report.componentReports.integratedAvReportId == "m10-integrated-av-synthetic-smoke")
    #expect(report.componentReports.videoTransportReportId == "m09-video-transport-run")
    #expect(report.componentReports.performanceAuditReportId == "m12-apple-silicon-performance-synthetic-smoke")
    #expect(report.profiles.allSatisfy { $0.audio.configuredChannelCount == 2 })
}

@Test
func e2eBenchmarkRejectsPassWithoutMeasuredRun() throws {
    var report = passCandidateReport()
    report.runMode = .synthetic

    #expect(throws: E2EBenchmarkValidationError.passWithoutMeasuredRun) {
        try report.validate()
    }
}

@Test
func e2eBenchmarkRejectsPassWithoutPhysicalTwoPeerEvidence() throws {
    var report = passCandidateReport()
    report.evidenceKind = .synthetic

    #expect(throws: E2EBenchmarkValidationError.passWithoutPhysicalTwoPeerEvidence) {
        try report.validate()
    }
}

@Test
func e2eBenchmarkRejectsPassWithoutRequiredProfile() throws {
    var report = passCandidateReport()
    report.profiles.removeAll { $0.profile == .audioVideoDirect }

    #expect(throws: E2EBenchmarkValidationError.missingProfile(.audioVideoDirect)) {
        try report.validate()
    }
}

@Test
func e2eBenchmarkRejectsPassWithoutVideoMetricsWhenVideoEnabled() throws {
    var report = passCandidateReport()
    let index = try #require(report.profiles.firstIndex { $0.profile == .audioVideoDirect })
    report.profiles[index].video = nil

    #expect(throws: E2EBenchmarkValidationError.passWithoutVideoMetrics(.audioVideoDirect)) {
        try report.validate()
    }
}

@Test
func e2eBenchmarkRejectsPassWhenVideoChangesAudioTiming() throws {
    var report = passCandidateReport()
    let index = try #require(report.profiles.firstIndex { $0.profile == .audioVideoDirect })
    report.profiles[index].audio.audioP99DeltaFromBaselineMicroseconds =
        report.thresholds.audioP99DeltaFromBaselineToleranceMicroseconds + 1

    #expect(throws: E2EBenchmarkValidationError.passWithVideoAudioImpact(.audioVideoDirect)) {
        try report.validate()
    }
}

@Test
func e2eBenchmarkAllowsPassWithinVideoAudioTimingTolerance() throws {
    var report = passCandidateReport()
    let index = try #require(report.profiles.firstIndex { $0.profile == .audioVideoDirect })
    report.profiles[index].audio.audioP99DeltaFromBaselineMicroseconds =
        report.thresholds.audioP99DeltaFromBaselineToleranceMicroseconds

    try report.validate()
}

@Test
func e2eBenchmarkAllowsPassWhenVideoImprovesAudioTimingDelta() throws {
    var report = passCandidateReport()
    let index = try #require(report.profiles.firstIndex { $0.profile == .audioVideoDirect })
    report.profiles[index].audio.audioP99DeltaFromBaselineMicroseconds = -25

    try report.validate()

    #expect(report.profiles[index].audio.audioP99DeltaFromBaselineMicroseconds == -25)
}

@Test
func e2eBenchmarkRejectsPassThresholdViolations() throws {
    var underrunReport = passCandidateReport()
    let audioIndex = try #require(underrunReport.profiles.firstIndex { $0.profile == .audioOnlyDirect })
    underrunReport.profiles[audioIndex].audio.underruns = 1
    underrunReport.thresholds.audioUnderrunMaxCount = 0
    #expect(throws: E2EBenchmarkValidationError.passWithAudioUnderruns(.audioOnlyDirect, 1)) {
        try underrunReport.validate()
    }

    var droppedFrameReport = passCandidateReport()
    let videoIndex = try #require(droppedFrameReport.profiles.firstIndex { $0.profile == .audioVideoDirect })
    droppedFrameReport.profiles[videoIndex].video?.droppedFrames = 1
    droppedFrameReport.thresholds.droppedFrameMaxCount = 0
    #expect(throws: E2EBenchmarkValidationError.passExceedsDroppedFrames(
        profile: .audioVideoDirect,
        value: 1,
        threshold: 0
    )) {
        try droppedFrameReport.validate()
    }

    var packetLossReport = passCandidateReport()
    let lossIndex = try #require(packetLossReport.profiles.firstIndex { $0.profile == .wanStable })
    packetLossReport.profiles[lossIndex].network.packetLossPercent = 0.6
    packetLossReport.thresholds.packetLossMaxPercent = 0.5
    #expect(throws: E2EBenchmarkValidationError.passExceedsPacketLoss(
        profile: .wanStable,
        value: 0.6,
        threshold: 0.5
    )) {
        try packetLossReport.validate()
    }

    var cpuReport = passCandidateReport()
    let cpuIndex = try #require(cpuReport.profiles.firstIndex { $0.profile == .audioOnlyDirect })
    cpuReport.profiles[cpuIndex].resources.cpuP99Percent = 80.1
    cpuReport.thresholds.cpuP99MaxPercent = 80
    #expect(throws: E2EBenchmarkValidationError.passExceedsCpu(
        profile: .audioOnlyDirect,
        value: 80.1,
        threshold: 80
    )) {
        try cpuReport.validate()
    }
}

@Test
func e2eBenchmarkPassLimitsAreCentralizedInThresholds() throws {
    let modelSource = try readE2ESource("Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReport.swift")
    let validationSource = try readE2ESource(
        "Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReportValidation.swift"
    )

    #expect(modelSource.contains("public struct E2EBenchmarkThresholds"))
    #expect(validationSource.contains("thresholds.droppedFrameMaxCount"))
    #expect(validationSource.contains("thresholds.packetLossMaxPercent"))
    #expect(validationSource.contains("thresholds.cpuP99MaxPercent"))
    #expect(validationSource.contains("thresholds.audioUnderrunMaxCount"))
    #expect(validationSource.contains("thresholds.audioP99DeltaFromBaselineToleranceMicroseconds"))
}

@Test
func e2eBenchmarkPassCandidateValidates() throws {
    let report = passCandidateReport()

    try report.validate()

    #expect(report.verdict == .pass)
    #expect(report.recovery.leakedRealtimeCallbacksAfterShutdown == 0)
}

@Test
func e2eBenchmarkJSONRoundTripPreservesReport() throws {
    let report = try E2EBenchmarkSyntheticSmoke.run()
    let decoded = try E2EBenchmarkReport.decode(from: report.prettyJSONData())

    #expect(decoded == report)
}

private func passCandidateReport() -> E2EBenchmarkReport {
    var report = E2EBenchmarkSyntheticSmoke.passCandidate()
    report.verdict = .pass
    return report
}

private func readE2ESource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
