// Translates E2EBenchmarkCommands command syntax into core API calls, keeping CLI parsing independent from domain services.
import Foundation
import OpenLolaCore

func handleE2EBenchmarkCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case let args where args.count == 2 && args[0] == "validate-e2e-benchmark-report":
        try validateReport(at: args[1], as: E2EBenchmarkReport.self, label: "E2E benchmark report")
    case ["e2e-benchmark-synthetic-smoke"]:
        let report = try E2EBenchmarkSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case let args where args.first == "e2e-benchmark-run":
        try runE2EBenchmarkCommand(Array(args.dropFirst()))
    default:
        return false
    }
    return true
}

private func runE2EBenchmarkCommand(_ arguments: [String]) throws {
    let configuration = try E2EBenchmarkRunConfiguration.parse(arguments)
    let audioBenchmark = try LatencyBenchmarkReport.decode(
        from: try e2eBenchmarkInputData(
            path: configuration.audioBenchmarkPath,
            label: "audio benchmark"
        )
    )
    let integratedAv = try IntegratedAvReport.decode(
        from: try e2eBenchmarkInputData(
            path: configuration.integratedAvPath,
            label: "integrated A/V report"
        )
    )
    let videoTransport = try VideoTransportReport.decode(
        from: try e2eBenchmarkInputData(
            path: configuration.videoTransportPath,
            label: "video transport report"
        )
    )
    let performanceAudit = try PerformanceAuditReport.decode(
        from: try e2eBenchmarkInputData(
            path: configuration.performanceAuditPath,
            label: "performance audit report"
        )
    )

    try audioBenchmark.validate()
    try integratedAv.validate()
    try videoTransport.validate()
    try performanceAudit.validate()

    let report = try E2EBenchmarkRunner.run(
        configuration: configuration,
        audioBenchmark: audioBenchmark,
        integratedAv: integratedAv,
        videoTransport: videoTransport,
        performanceAudit: performanceAudit
    )
    try report.validate()
    try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
    print("E2E benchmark report written: \(configuration.outputPath)")
    print("profiles: \(report.profiles.count)")
    print("impairments: \(report.impairments.count)")
    printVerdict(report.verdict)
}

private func e2eBenchmarkInputData(path: String, label: String) throws -> Data {
    guard FileManager.default.fileExists(atPath: path) else {
        throw CommandError.invalidArgument("missing \(label): \(path)")
    }
    return try BoundedFileReader.data(atPath: path)
}
