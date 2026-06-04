import Foundation

func requiredPackagingRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw PackagingFieldRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

func writePackagingFieldArtifacts(
    outputDirectory: String,
    integratedReport: IntegratedAvReport,
    appReport: NativeAppShellReport,
    recordingReport: RecordingSessionArtifactReport
) throws -> FieldReportCoverage {
    let outputURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
    try integratedReport.prettyJSONData().write(
        to: outputURL.appendingPathComponent("integrated-av-report.json")
    )
    try appReport.prettyJSONData().write(
        to: outputURL.appendingPathComponent("native-app-shell-report.json")
    )
    try recordingReport.prettyJSONData().write(
        to: outputURL.appendingPathComponent("recording-session-report.json")
    )

    return FieldReportCoverage(
        endpointEvidenceIncluded: true,
        networkEvidenceIncluded: true,
        audioEvidenceIncluded: true,
        videoEvidenceIncluded: true,
        controlEvidenceIncluded: true,
        recordingEvidenceIncluded: true,
        packagingEvidenceIncluded: true,
        fallbackRouteDecisionRecorded: true,
        deferredArtisticIntegrationsRecorded: true,
        verdictLineRecorded: true
    )
}

func packagingFieldVerdict(
    integratedReport: IntegratedAvReport,
    appReport: NativeAppShellReport,
    recordingReport: RecordingSessionArtifactReport
) -> MeasurementVerdict {
    integratedReport.verdict == .pass
        && appReport.verdict == .pass
        && recordingReport.verdict == .pass ? .pass : .partial
}

func packagingHostArchitecture() -> String {
    #if arch(arm64)
    "arm64"
    #elseif arch(x86_64)
    "x86_64"
    #else
    "unknown"
    #endif
}
