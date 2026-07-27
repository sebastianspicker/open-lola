// Translates MilestoneFieldReleaseCommands command syntax into core API calls, keeping CLI parsing independent from domain services.
import Foundation
import OpenLolaCore

func handleMilestoneFieldReleaseCommand(_ arguments: [String]) throws -> Bool {
    if try handleMilestoneRecordingPackagingCommand(arguments) { return true }
    if try handleMilestoneFieldRuntimeCommand(arguments) { return true }
    if try handleMilestoneReleaseReadinessCommand(arguments) { return true }
    return false
}

private func handleMilestoneRecordingPackagingCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["recording-session-synthetic-smoke"]:
        let report = RecordingSessionSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case let args where args.first == "recording-session-run":
        try runRecordingSessionCommand(args)
    case let args where args.first == "packaging-field-run":
        try runPackagingFieldCommand(args)
    case ["packaging-field-synthetic-smoke"]:
        let report = PackagingFieldTestSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    default:
        return false
    }
    return true
}

private func handleMilestoneFieldRuntimeCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case let args where args.first == "field-runtime-proof-run":
        try runFieldRuntimeProofCommand(args)
    case let args where args.first == "field-readiness-run":
        try runFieldReadinessCommand(args)
    case ["field-runtime-synthetic-smoke"]:
        let report = FieldReadyRuntimeSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case ["faster-than-lola-closure-synthetic-smoke"]:
        let report = FasterThanLoLaClosureSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case let args where args.first == "faster-than-lola-closure-run":
        try runFasterThanLoLaClosureCommand(args)
    default:
        return false
    }
    return true
}

private func handleMilestoneReleaseReadinessCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["release-hardening-synthetic-smoke"]:
        let report = ReleaseHardeningSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case let args where args.first == "release-hardening-run":
        try runReleaseHardeningCommand(args)
    case let args where args.first == "open-source-release-readiness-run":
        try runOpenSourceReleaseReadinessCommand(args)
    default:
        return false
    }
    return true
}

private func runRecordingSessionCommand(_ args: [String]) throws {
    let configuration = try RecordingSessionRunConfiguration.parse(Array(args.dropFirst()))
    let baselineURL = URL(fileURLWithPath: configuration.integratedBaselinePath)
    let baseline = try IntegratedAvReport.readValidated(from: baselineURL)
    let report = try RecordingSessionRunner.run(
        configuration: configuration,
        integratedBaseline: baseline
    )
    try writeValidatedReport(report, to: configuration.reportPath)
    print("recording session report written: \(configuration.reportPath)")
    print("artifact-root: \(report.manifest.rootDirectory)")
    print("artifacts: \(report.manifest.entries.count)")
    print("dropped-chunks: \(report.writerPressure.droppedChunkCount)")
    print("gap-markers: \(report.writerPressure.gapMarkerCount)")
    printVerdict(report.verdict)
}

private func runPackagingFieldCommand(_ args: [String]) throws {
    let configuration = try PackagingFieldRunConfiguration.parse(Array(args.dropFirst()))
    let inputs = try packagingFieldInputs(
        integratedReportPath: configuration.integratedReportPath,
        appReportPath: configuration.appReportPath,
        recordingReportPath: configuration.recordingReportPath
    )
    let report = try PackagingFieldRunner.run(
        configuration: configuration,
        integratedReport: inputs.integratedReport,
        appShellReport: inputs.appReport,
        recordingReport: inputs.recordingReport
    )
    try writeValidatedReport(report, to: configuration.reportPath)
    print("packaging field-test report written: \(configuration.reportPath)")
    print("package-root: \(configuration.outputDirectory)")
    print("artifacts: \(report.package.artifacts.count)")
    print("distribution: \(report.distributionMethod.rawValue)")
    printVerdict(report.verdict)
}

private func runFieldRuntimeProofCommand(_ args: [String]) throws {
    let configuration = try FieldReadyRuntimeProofRunConfiguration.parse(Array(args.dropFirst()))
    let inputs = try packagingFieldInputs(
        integratedReportPath: configuration.integratedReportPath,
        appReportPath: configuration.appReportPath,
        recordingReportPath: configuration.recordingReportPath
    )
    let packagingReport = try PackagingFieldTestReport.readValidated(fromPath: configuration.packagingReportPath)
    let report = FieldReadyRuntimeProofRunner.run(
        configuration: configuration,
        integratedReport: inputs.integratedReport,
        appShellReport: inputs.appReport,
        recordingReport: inputs.recordingReport,
        packagingReport: packagingReport
    )
    try writeValidatedReport(report, to: configuration.outputPath)
    print("field-ready runtime proof written: \(configuration.outputPath)")
    print("integrated-report: \(inputs.integratedReport.id)")
    print("packaging-report: \(packagingReport.id)")
    printVerdict(report.verdict)
}

private struct PackagingFieldInputs {
    let integratedReport: IntegratedAvReport
    let appReport: NativeAppShellReport
    let recordingReport: RecordingSessionArtifactReport
}

private func packagingFieldInputs(
    integratedReportPath: String,
    appReportPath: String,
    recordingReportPath: String
) throws -> PackagingFieldInputs {
    let integratedReport = try IntegratedAvReport.readValidated(fromPath: integratedReportPath)
    let appReport = try NativeAppShellReport.readValidated(fromPath: appReportPath)
    let recordingReport = try RecordingSessionArtifactReport.readValidated(fromPath: recordingReportPath)
    return PackagingFieldInputs(
        integratedReport: integratedReport,
        appReport: appReport,
        recordingReport: recordingReport
    )
}

private func runFieldReadinessCommand(_ args: [String]) throws {
    let configuration = try FieldReadinessRunConfiguration.parse(Array(args.dropFirst()))
    let integratedURL = URL(fileURLWithPath: configuration.integratedReportPath)
    let integratedReport = try IntegratedAvReport.readValidated(from: integratedURL)
    let result = try FieldReadinessRunner.run(
        configuration: configuration,
        integratedReport: integratedReport
    )
    print("field readiness reports written: \(configuration.outputDirectory)")
    print("integrated-report: \(result.integratedReportId)")
    print("app-report: \(result.appReportPath)")
    print("recording-report: \(result.recordingReportPath)")
    print("packaging-report: \(result.packagingReportPath)")
    print("field-runtime-proof: \(result.proofReportPath)")
    printVerdict(result.verdict)
}

private func runFasterThanLoLaClosureCommand(_ args: [String]) throws {
    let configuration = try FasterThanLoLaClosureRunConfiguration.parse(Array(args.dropFirst()))
    let report = FasterThanLoLaClosureRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("faster-than-LoLa closure report written: \(configuration.outputPath)")
    print("claim-scope: \(report.claimScope.rawValue)")
    print("evidence-count: \(report.evidence.count)")
    print("comparison-result: \(report.comparison.result.rawValue)")
    printVerdict(report.verdict)
}

private func runReleaseHardeningCommand(_ args: [String]) throws {
    let configuration = try ReleaseHardeningRunConfiguration.parse(Array(args.dropFirst()))
    let report = ReleaseHardeningRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("release hardening report written: \(configuration.outputPath)")
    print("claims: \(report.claims.count)")
    print("remaining-partial-gates: \(report.remainingPartialGates.count)")
    printVerdict(report.verdict)
}

private func runOpenSourceReleaseReadinessCommand(_ args: [String]) throws {
    let configuration = try OpenSourceReleaseReadinessRunConfiguration.parse(Array(args.dropFirst()))
    let report = OpenSourceReleaseReadinessRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("open-source release readiness report written: \(configuration.outputPath)")
    print("requirements: \(report.requirements.count)")
    print("blockers: \(report.blockers.count)")
    printVerdict(report.verdict)
}
