import Foundation
import Testing

@testable import OpenLolaCore

@Test
func e2eBenchmarkSyntheticSmokeAndRunnerKeepVideoProfilesNeutralAgainstAudioBaseline() throws {
    let report = try E2EBenchmarkSyntheticSmoke.run()
    let audioOnly = try #require(report.profiles.first { $0.profile == .audioOnlyDirect })
    let audioVideo = try #require(report.profiles.first { $0.profile == .audioVideoDirect })
    let multiVideo = try #require(report.profiles.first { $0.profile == .audioMultiVideoDirect })
    let wanStable = try #require(report.profiles.first { $0.profile == .wanStable })

    #expect(audioOnly.video == nil)
    #expect(audioVideo.video?.streamCount == 1)
    #expect(multiVideo.video?.streamCount == 2)
    #expect(wanStable.video?.streamCount == 1)
    #expect(audioOnly.audio.audioP99DeltaFromBaselineMicroseconds == 0)
    #expect(audioVideo.audio.audioP99DeltaFromBaselineMicroseconds == 0)
    #expect(multiVideo.audio.audioP99DeltaFromBaselineMicroseconds == 0)
    #expect(wanStable.audio.audioP99DeltaFromBaselineMicroseconds == 0)

    let runnerConfiguration = E2EBenchmarkRunConfiguration(
        audioBenchmarkPath: "reports/audio.json",
        integratedAvPath: "reports/integrated-av.json",
        videoTransportPath: "reports/video-transport.json",
        performanceAuditPath: "reports/performance.json",
        durationSeconds: 60,
        outputPath: "reports/m13-e2e.json"
    )
    let runnerReport = try E2EBenchmarkRunner.run(
        configuration: runnerConfiguration,
        audioBenchmark: try LatencyBenchmarkSyntheticSmoke.run(),
        integratedAv: IntegratedHeadlessAvSyntheticSmoke.run(),
        videoTransport: VideoTransportSyntheticSmoke.run(),
        performanceAudit: PerformanceAuditSyntheticSmoke.run()
    )

    try runnerReport.validate()

    #expect(runnerReport.verdict == .partial)
    #expect(runnerReport.componentReports.audioBenchmarkReportId == "m02-latency-benchmark-synthetic-smoke")
    #expect(runnerReport.componentReports.integratedAvReportId == "m10-integrated-av-synthetic-smoke")
    #expect(runnerReport.componentReports.videoTransportReportId == "m09-video-transport-run")
    #expect(runnerReport.componentReports.performanceAuditReportId == "m12-apple-silicon-performance-synthetic-smoke")
    #expect(runnerReport.profiles.allSatisfy { $0.audio.configuredChannelCount == 2 })
}

@Test
func e2eBenchmarkRunConfigurationParsesRequiredArgumentsAndRejectsKeyValueErrors() throws {
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

    #expect(throws: E2EBenchmarkRunConfigurationError.duplicateArgument("--output")) {
        try E2EBenchmarkRunConfiguration.parse(e2eBenchmarkArguments() + ["--output", "reports/other.json"])
    }

    #expect(throws: E2EBenchmarkRunConfigurationError.missingValue("--output")) {
        try E2EBenchmarkRunConfiguration.parse(Array(e2eBenchmarkArguments().dropLast()))
    }

    #expect(throws: E2EBenchmarkRunConfigurationError.unknownArgument("--unexpected")) {
        try E2EBenchmarkRunConfiguration.parse(e2eBenchmarkArguments() + ["--unexpected", "value"])
    }

    #expect(throws: E2EBenchmarkRunConfigurationError.invalidNumber(
        argument: "--duration-seconds",
        value: "not-a-number"
    )) {
        try E2EBenchmarkRunConfiguration.parse(e2eBenchmarkArguments(
            replacing: ["--duration-seconds": "not-a-number"]
        ))
    }

    #expect(throws: E2EBenchmarkRunConfigurationError.nonPositiveArgument("--duration-seconds")) {
        try E2EBenchmarkRunConfiguration.parse(e2eBenchmarkArguments(replacing: ["--duration-seconds": "0"]))
    }
}

@Test
func e2eBenchmarkCLIReportsMissingInputsWithComponentLabels() throws {
    let cliURL = try e2eBenchmarkOpenLolaCLIURL()
    let directory = try e2eBenchmarkTemporaryDirectory(prefix: "e2e-benchmark-missing-inputs")
    let paths = E2EBenchmarkFixturePaths(directory: directory)

    for (label, missingPath, availablePaths) in [
        ("audio benchmark", paths.audio, []),
        ("integrated A/V report", paths.integratedAv, [paths.audio]),
        ("video transport report", paths.videoTransport, [paths.audio, paths.integratedAv]),
        ("performance audit report", paths.performanceAudit, [
            paths.audio,
            paths.integratedAv,
            paths.videoTransport,
        ]),
    ] {
        for path in [paths.audio, paths.integratedAv, paths.videoTransport, paths.performanceAudit] {
            try? FileManager.default.removeItem(at: path)
        }
        try writeE2EBenchmarkFixtureInputs(paths, only: availablePaths)

        let result = try runE2EBenchmarkOpenLolaCLI(
            cliURL,
            arguments: ["e2e-benchmark-run"] + e2eBenchmarkArguments(
                audioBenchmark: paths.audio.path,
                integratedAv: paths.integratedAv.path,
                videoTransport: paths.videoTransport.path,
                performanceAudit: paths.performanceAudit.path,
                output: paths.output.path
            )
        )

        #expect(result.exitCode != 0)
        #expect(result.output.contains("missing \(label): \(missingPath.path)"))
    }
}

@Test
func e2eBenchmarkRejectsInvalidPassEvidenceAndThresholdViolations() throws {
    try expectE2EBenchmarkError(.passWithoutMeasuredRun) {
        $0.runMode = .synthetic
    }
    try expectE2EBenchmarkError(.passWithoutPhysicalTwoPeerEvidence) {
        $0.evidenceKind = .synthetic
    }
    try expectE2EBenchmarkError(.missingProfile(.audioVideoDirect)) {
        $0.profiles.removeAll { $0.profile == .audioVideoDirect }
    }
    try expectE2EBenchmarkError(.passWithoutVideoMetrics(.audioVideoDirect)) {
        let index = try #require($0.profiles.firstIndex { $0.profile == .audioVideoDirect })
        $0.profiles[index].video = nil
    }
    try expectE2EBenchmarkError(.passWithVideoAudioImpact(.audioVideoDirect)) {
        let index = try #require($0.profiles.firstIndex { $0.profile == .audioVideoDirect })
        $0.profiles[index].audio.audioP99DeltaFromBaselineMicroseconds =
            $0.thresholds.audioP99DeltaFromBaselineToleranceMicroseconds + 1
    }

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
func e2eBenchmarkPassCandidateAllowsTimingToleranceAndImprovement() throws {
    let report = passCandidateReport()

    try report.validate()

    #expect(report.verdict == .pass)
    #expect(report.recovery.leakedRealtimeCallbacksAfterShutdown == 0)

    var toleranceReport = passCandidateReport()
    let toleranceIndex = try #require(toleranceReport.profiles.firstIndex { $0.profile == .audioVideoDirect })
    toleranceReport.profiles[toleranceIndex].audio.audioP99DeltaFromBaselineMicroseconds =
        toleranceReport.thresholds.audioP99DeltaFromBaselineToleranceMicroseconds

    try toleranceReport.validate()

    var improvedReport = passCandidateReport()
    let improvedIndex = try #require(improvedReport.profiles.firstIndex { $0.profile == .audioVideoDirect })
    improvedReport.profiles[improvedIndex].audio.audioP99DeltaFromBaselineMicroseconds = -25

    try improvedReport.validate()

    #expect(improvedReport.profiles[improvedIndex].audio.audioP99DeltaFromBaselineMicroseconds == -25)
}

private func passCandidateReport() -> E2EBenchmarkReport {
    var report = E2EBenchmarkSyntheticSmoke.passCandidate()
    report.verdict = .pass
    return report
}

private func expectE2EBenchmarkError(
    _ expected: E2EBenchmarkValidationError,
    mutate: (inout E2EBenchmarkReport) throws -> Void
) throws {
    var report = passCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func e2eBenchmarkArguments(replacing replacements: [String: String] = [:]) -> [String] {
    e2eBenchmarkArguments(
        audioBenchmark: replacements["--audio-benchmark"] ?? "reports/audio.json",
        integratedAv: replacements["--integrated-av"] ?? "reports/integrated-av.json",
        videoTransport: replacements["--video-transport"] ?? "reports/video-transport.json",
        performanceAudit: replacements["--performance-audit"] ?? "reports/performance.json",
        durationSeconds: replacements["--duration-seconds"] ?? "1800",
        output: replacements["--output"] ?? "reports/m13-e2e.json"
    )
}

private func e2eBenchmarkArguments(
    audioBenchmark: String,
    integratedAv: String,
    videoTransport: String,
    performanceAudit: String,
    durationSeconds: String = "1800",
    output: String
) -> [String] {
    [
        "--audio-benchmark", audioBenchmark,
        "--integrated-av", integratedAv,
        "--video-transport", videoTransport,
        "--performance-audit", performanceAudit,
        "--duration-seconds", durationSeconds,
        "--output", output,
    ]
}

private struct E2EBenchmarkFixturePaths {
    let audio: URL
    let integratedAv: URL
    let videoTransport: URL
    let performanceAudit: URL
    let output: URL

    init(directory: URL) {
        audio = directory.appendingPathComponent("audio.json")
        integratedAv = directory.appendingPathComponent("integrated-av.json")
        videoTransport = directory.appendingPathComponent("video-transport.json")
        performanceAudit = directory.appendingPathComponent("performance.json")
        output = directory.appendingPathComponent("m13-e2e.json")
    }
}

private func writeE2EBenchmarkFixtureInputs(
    _ paths: E2EBenchmarkFixturePaths,
    only selectedPaths: [URL]? = nil
) throws {
    let selected = selectedPaths.map(Set.init)
    try writeE2EBenchmarkFixture(
        try LatencyBenchmarkSyntheticSmoke.run().prettyJSONData(),
        to: paths.audio,
        selected: selected
    )
    try writeE2EBenchmarkFixture(
        try IntegratedHeadlessAvSyntheticSmoke.run().prettyJSONData(),
        to: paths.integratedAv,
        selected: selected
    )
    try writeE2EBenchmarkFixture(
        try VideoTransportSyntheticSmoke.run().prettyJSONData(),
        to: paths.videoTransport,
        selected: selected
    )
    try writeE2EBenchmarkFixture(
        try PerformanceAuditSyntheticSmoke.run().prettyJSONData(),
        to: paths.performanceAudit,
        selected: selected
    )
}

private func writeE2EBenchmarkFixture(_ data: Data, to url: URL, selected: Set<URL>?) throws {
    guard selected?.contains(url) ?? true else {
        return
    }
    try data.write(to: url, options: [.atomic])
}

private func e2eBenchmarkTemporaryDirectory(prefix: String) throws -> URL {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func e2eBenchmarkOpenLolaCLIURL() throws -> URL {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try requiredFreshOpenLolaCLIURL(
        repositoryRoot: root,
        context: "E2E benchmark CLI behavior tests"
    )
}

private func runE2EBenchmarkOpenLolaCLI(
    _ executableURL: URL,
    arguments: [String]
) throws -> (exitCode: Int32, output: String) {
    let process = Process()
    let outputPipe = Pipe()
    process.executableURL = executableURL
    process.arguments = arguments
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    try process.run()
    process.waitUntilExit()

    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
}
