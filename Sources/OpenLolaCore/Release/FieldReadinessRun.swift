// Coordinates release-readiness execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation

/// CLI and programmatic input contract for the aggregate field-readiness runner.
public struct FieldReadinessRunConfiguration: Codable, Equatable, Sendable {
    public let integratedReportPath: String
    public let durationSeconds: Int
    public let outputDirectory: String

    public var appReportPath: String {
        fieldReadinessPath(outputDirectory: outputDirectory, component: "m13-native-app-runtime-smoke.json")
    }

    public var recordingOutputDirectory: String {
        fieldReadinessPath(outputDirectory: outputDirectory, component: "m14-session")
    }

    public var recordingReportPath: String {
        fieldReadinessPath(outputDirectory: outputDirectory, component: "m14-recording-session.json")
    }

    public var packagingOutputDirectory: String {
        fieldReadinessPath(outputDirectory: outputDirectory, component: "m15-package")
    }

    public var packagingReportPath: String {
        fieldReadinessPath(outputDirectory: outputDirectory, component: "m15-packaging-field.json")
    }

    public var proofReportPath: String {
        fieldReadinessPath(outputDirectory: outputDirectory, component: "p05-field-runtime-proof.json")
    }

    public init(
        integratedReportPath: String,
        durationSeconds: Int,
        outputDirectory: String
    ) {
        self.integratedReportPath = integratedReportPath
        self.durationSeconds = durationSeconds
        self.outputDirectory = outputDirectory
    }

    public static func parse(_ arguments: [String]) throws -> FieldReadinessRunConfiguration {
        let allowed = [
            "--integrated-report",
            "--duration-seconds",
            "--output-dir"
        ]
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: Set(allowed),
            unknown: FieldReadinessRunConfigurationError.unknownArgument,
            duplicate: FieldReadinessRunConfigurationError.duplicateArgument,
            missingValue: FieldReadinessRunConfigurationError.missingValue
        )

        return FieldReadinessRunConfiguration(
            integratedReportPath: try requiredFieldReadinessRunString("--integrated-report", values),
            durationSeconds: try requiredFieldReadinessRunPositiveInteger("--duration-seconds", values),
            outputDirectory: try requiredFieldReadinessRunString("--output-dir", values)
        )
    }
}

/// Describes failures that prevent field-readiness inputs or evidence from satisfying the required validation invariants.
public enum FieldReadinessRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
}

/// Captures operation result required to validate, interpret, and reproduce a field-readiness result.
public struct FieldReadinessRunResult: Codable, Equatable, Sendable {
    public struct ReportIDs: Sendable {
        public let integrated: String
        public let app: String
        public let recording: String
        public let packaging: String
        public let proof: String

        public init(integrated: String, app: String, recording: String, packaging: String, proof: String) {
            self.integrated = integrated
            self.app = app
            self.recording = recording
            self.packaging = packaging
            self.proof = proof
        }
    }

    public struct ReportPaths: Sendable {
        public let app: String
        public let recording: String
        public let packaging: String
        public let proof: String

        public init(app: String, recording: String, packaging: String, proof: String) {
            self.app = app
            self.recording = recording
            self.packaging = packaging
            self.proof = proof
        }
    }

    public struct OutputDirectories: Sendable {
        public let recording: String
        public let packaging: String

        public init(recording: String, packaging: String) {
            self.recording = recording
            self.packaging = packaging
        }
    }

    public let integratedReportId: String
    public let appReportId: String
    public let recordingReportId: String
    public let packagingReportId: String
    public let proofReportId: String
    public let appReportPath: String
    public let recordingReportPath: String
    public let packagingReportPath: String
    public let proofReportPath: String
    public let recordingOutputDirectory: String
    public let packagingOutputDirectory: String
    public let verdict: MeasurementVerdict

    public init(
        reportIDs: ReportIDs,
        reportPaths: ReportPaths,
        outputDirectories: OutputDirectories,
        verdict: MeasurementVerdict
    ) {
        self.integratedReportId = reportIDs.integrated
        self.appReportId = reportIDs.app
        self.recordingReportId = reportIDs.recording
        self.packagingReportId = reportIDs.packaging
        self.proofReportId = reportIDs.proof
        self.appReportPath = reportPaths.app
        self.recordingReportPath = reportPaths.recording
        self.packagingReportPath = reportPaths.packaging
        self.proofReportPath = reportPaths.proof
        self.recordingOutputDirectory = outputDirectories.recording
        self.packagingOutputDirectory = outputDirectories.packaging
        self.verdict = verdict
    }
}

/// Runs the field-readiness evaluation from supplied artifacts while retaining their measurement provenance in the resulting report.
public enum FieldReadinessRunner {
    public static func run(
        configuration: FieldReadinessRunConfiguration,
        integratedReport: IntegratedAvReport
    ) throws -> FieldReadinessRunResult {
        try integratedReport.validate()

        let reports = try runFieldReadinessReports(
            configuration: configuration,
            integratedReport: integratedReport
        )

        return FieldReadinessRunResult(
            reportIDs: FieldReadinessRunResult.ReportIDs(
                integrated: integratedReport.id,
                app: reports.app.id,
                recording: reports.recording.id,
                packaging: reports.packaging.id,
                proof: reports.proof.id
            ),
            reportPaths: FieldReadinessRunResult.ReportPaths(
                app: configuration.appReportPath,
                recording: configuration.recordingReportPath,
                packaging: configuration.packagingReportPath,
                proof: configuration.proofReportPath
            ),
            outputDirectories: FieldReadinessRunResult.OutputDirectories(
                recording: configuration.recordingOutputDirectory,
                packaging: configuration.packagingOutputDirectory
            ),
            verdict: reports.proof.verdict
        )
    }

    private static func runFieldReadinessReports(
        configuration: FieldReadinessRunConfiguration,
        integratedReport: IntegratedAvReport
    ) throws -> FieldReadinessReports {
        let appReport = try runAppReport(configuration: configuration, integratedReport: integratedReport)
        let recordingReport = try runRecordingReport(configuration: configuration, integratedReport: integratedReport)
        let packagingReport = try runPackagingReport(
            configuration: configuration,
            integratedReport: integratedReport,
            appReport: appReport,
            recordingReport: recordingReport
        )
        let proofReport = try runProofReport(
            configuration: configuration,
            integratedReport: integratedReport,
            appReport: appReport,
            recordingReport: recordingReport,
            packagingReport: packagingReport
        )

        return FieldReadinessReports(
            app: appReport,
            recording: recordingReport,
            packaging: packagingReport,
            proof: proofReport
        )
    }

    private static func runAppReport(
        configuration: FieldReadinessRunConfiguration,
        integratedReport: IntegratedAvReport
    ) throws -> NativeAppShellReport {
        let appReport = NativeAppRuntimeSmoke.run(
            configuration: NativeAppRuntimeSmokeConfiguration(
                headlessReportPath: configuration.integratedReportPath,
                outputPath: configuration.appReportPath
            ),
            headlessReport: integratedReport
        )
        try appReport.validate()
        try writeFieldReadinessJSONData(try appReport.prettyJSONData(), to: configuration.appReportPath)
        return appReport
    }

    private static func runRecordingReport(
        configuration: FieldReadinessRunConfiguration,
        integratedReport: IntegratedAvReport
    ) throws -> RecordingSessionArtifactReport {
        let recordingReport = try RecordingSessionRunner.run(
            configuration: RecordingSessionRunConfiguration(
                integratedBaselinePath: configuration.integratedReportPath,
                durationSeconds: configuration.durationSeconds,
                outputDirectory: configuration.recordingOutputDirectory,
                reportPath: configuration.recordingReportPath
            ),
            integratedBaseline: integratedReport
        )
        try recordingReport.validate()
        try writeFieldReadinessJSONData(try recordingReport.prettyJSONData(), to: configuration.recordingReportPath)
        return recordingReport
    }

    private static func runPackagingReport(
        configuration: FieldReadinessRunConfiguration,
        integratedReport: IntegratedAvReport,
        appReport: NativeAppShellReport,
        recordingReport: RecordingSessionArtifactReport
    ) throws -> PackagingFieldTestReport {
        let packagingReport = try PackagingFieldRunner.run(
            configuration: PackagingFieldRunConfiguration(
                integratedReportPath: configuration.integratedReportPath,
                appReportPath: configuration.appReportPath,
                recordingReportPath: configuration.recordingReportPath,
                outputDirectory: configuration.packagingOutputDirectory,
                reportPath: configuration.packagingReportPath
            ),
            integratedReport: integratedReport,
            appShellReport: appReport,
            recordingReport: recordingReport
        )
        try packagingReport.validate()
        try writeFieldReadinessJSONData(try packagingReport.prettyJSONData(), to: configuration.packagingReportPath)
        return packagingReport
    }

    private static func runProofReport(
        configuration: FieldReadinessRunConfiguration,
        integratedReport: IntegratedAvReport,
        appReport: NativeAppShellReport,
        recordingReport: RecordingSessionArtifactReport,
        packagingReport: PackagingFieldTestReport
    ) throws -> FieldReadyRuntimeProofReport {
        let proofReport = FieldReadyRuntimeProofRunner.run(
            configuration: FieldReadyRuntimeProofRunConfiguration(
                integratedReportPath: configuration.integratedReportPath,
                appReportPath: configuration.appReportPath,
                recordingReportPath: configuration.recordingReportPath,
                packagingReportPath: configuration.packagingReportPath,
                outputPath: configuration.proofReportPath
            ),
            integratedReport: integratedReport,
            appShellReport: appReport,
            recordingReport: recordingReport,
            packagingReport: packagingReport
        )
        try proofReport.validate()
        try writeFieldReadinessJSONData(try proofReport.prettyJSONData(), to: configuration.proofReportPath)
        return proofReport
    }
}

private struct FieldReadinessReports {
    let app: NativeAppShellReport
    let recording: RecordingSessionArtifactReport
    let packaging: PackagingFieldTestReport
    let proof: FieldReadyRuntimeProofReport
}

private func fieldReadinessPath(outputDirectory: String, component: String) -> String {
    let separator = outputDirectory.hasSuffix("/") ? "" : "/"
    return "\(outputDirectory)\(separator)\(component)"
}

private func requiredFieldReadinessRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw FieldReadinessRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

private func requiredFieldReadinessRunPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int {
    let value = try requiredFieldReadinessRunString(argument, values)
    guard let integerValue = Int(value) else {
        throw FieldReadinessRunConfigurationError.invalidInteger(argument: argument, value: value)
    }
    guard integerValue > 0 else {
        throw FieldReadinessRunConfigurationError.nonPositiveArgument(argument)
    }
    return integerValue
}

private func writeFieldReadinessJSONData(_ data: Data, to path: String) throws {
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url)
}
