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
            "--output-dir",
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

public enum FieldReadinessRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
}

public struct FieldReadinessRunResult: Codable, Equatable, Sendable {
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
        integratedReportId: String,
        appReportId: String,
        recordingReportId: String,
        packagingReportId: String,
        proofReportId: String,
        appReportPath: String,
        recordingReportPath: String,
        packagingReportPath: String,
        proofReportPath: String,
        recordingOutputDirectory: String,
        packagingOutputDirectory: String,
        verdict: MeasurementVerdict
    ) {
        self.integratedReportId = integratedReportId
        self.appReportId = appReportId
        self.recordingReportId = recordingReportId
        self.packagingReportId = packagingReportId
        self.proofReportId = proofReportId
        self.appReportPath = appReportPath
        self.recordingReportPath = recordingReportPath
        self.packagingReportPath = packagingReportPath
        self.proofReportPath = proofReportPath
        self.recordingOutputDirectory = recordingOutputDirectory
        self.packagingOutputDirectory = packagingOutputDirectory
        self.verdict = verdict
    }
}

public enum FieldReadinessRunner {
    public static func run(
        configuration: FieldReadinessRunConfiguration,
        integratedReport: IntegratedAvReport
    ) throws -> FieldReadinessRunResult {
        try integratedReport.validate()

        let appReport = NativeAppRuntimeSmoke.run(
            configuration: NativeAppRuntimeSmokeConfiguration(
                headlessReportPath: configuration.integratedReportPath,
                outputPath: configuration.appReportPath
            ),
            headlessReport: integratedReport
        )
        try appReport.validate()
        try writeFieldReadinessJSONData(try appReport.prettyJSONData(), to: configuration.appReportPath)

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

        return FieldReadinessRunResult(
            integratedReportId: integratedReport.id,
            appReportId: appReport.id,
            recordingReportId: recordingReport.id,
            packagingReportId: packagingReport.id,
            proofReportId: proofReport.id,
            appReportPath: configuration.appReportPath,
            recordingReportPath: configuration.recordingReportPath,
            packagingReportPath: configuration.packagingReportPath,
            proofReportPath: configuration.proofReportPath,
            recordingOutputDirectory: configuration.recordingOutputDirectory,
            packagingOutputDirectory: configuration.packagingOutputDirectory,
            verdict: proofReport.verdict
        )
    }
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
