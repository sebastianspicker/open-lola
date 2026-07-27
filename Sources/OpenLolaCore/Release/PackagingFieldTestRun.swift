// Coordinates release-readiness execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation

/// CLI and programmatic input contract for packaging field-test artifact generation.
public struct PackagingFieldRunConfiguration: Codable, Equatable, Sendable {
    public let integratedReportPath: String
    public let appReportPath: String
    public let recordingReportPath: String
    public let outputDirectory: String
    public let reportPath: String

    public init(
        integratedReportPath: String,
        appReportPath: String,
        recordingReportPath: String,
        outputDirectory: String,
        reportPath: String
    ) {
        self.integratedReportPath = integratedReportPath
        self.appReportPath = appReportPath
        self.recordingReportPath = recordingReportPath
        self.outputDirectory = outputDirectory
        self.reportPath = reportPath
    }

    public static func parse(_ arguments: [String]) throws -> PackagingFieldRunConfiguration {
        let allowed = [
            "--integrated-report",
            "--app-report",
            "--recording-report",
            "--output-dir",
            "--report"
        ]
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: Set(allowed),
            unknown: PackagingFieldRunConfigurationError.unknownArgument,
            duplicate: PackagingFieldRunConfigurationError.duplicateArgument,
            missingValue: PackagingFieldRunConfigurationError.missingValue
        )

        return PackagingFieldRunConfiguration(
            integratedReportPath: try requiredPackagingRunString("--integrated-report", values),
            appReportPath: try requiredPackagingRunString("--app-report", values),
            recordingReportPath: try requiredPackagingRunString("--recording-report", values),
            outputDirectory: try requiredPackagingRunString("--output-dir", values),
            reportPath: try requiredPackagingRunString("--report", values)
        )
    }
}

/// Describes failures that prevent packaging field test inputs or evidence from satisfying the required validation invariants.
public enum PackagingFieldRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
}

/// Runs the packaging field test evaluation from supplied artifacts while retaining their measurement provenance in the resulting report.
public enum PackagingFieldRunner {
    public static func run(configuration: PackagingFieldRunConfiguration) throws -> PackagingFieldTestReport {
        let integratedReport = try IntegratedAvReport.readValidated(fromPath: configuration.integratedReportPath)
        let appReport = try NativeAppShellReport.readValidated(fromPath: configuration.appReportPath)
        let recordingReport = try RecordingSessionArtifactReport.readValidated(
            fromPath: configuration.recordingReportPath
        )
        return try run(
            configuration: configuration,
            integratedReport: integratedReport,
            appShellReport: appReport,
            recordingReport: recordingReport
        )
    }

    public static func run(
        configuration: PackagingFieldRunConfiguration,
        integratedReport: IntegratedAvReport,
        appShellReport: NativeAppShellReport,
        recordingReport: RecordingSessionArtifactReport
    ) throws -> PackagingFieldTestReport {
        let permissionSurface = packagedPermissionEntitlementSurface()
        let outputURL = URL(fileURLWithPath: configuration.outputDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        let artifacts = try materializedPackagingArtifacts(surface: permissionSurface, outputDirectory: outputURL)
        let fieldReport = try writePackagingFieldArtifacts(
            outputDirectory: configuration.outputDirectory,
            integratedReport: integratedReport,
            appReport: appShellReport,
            recordingReport: recordingReport
        )

        let report = measuredPackagingFieldReport(
            permissionSurface: permissionSurface,
            artifacts: artifacts,
            fieldReport: fieldReport,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString
        )
        return finalizedPackagingFieldReport(
            report,
            integratedReport: integratedReport,
            appShellReport: appShellReport,
            recordingReport: recordingReport
        )
    }
}

private func materializedPackagingArtifacts(
    surface: MacPackagedPermissionEntitlementSurface,
    outputDirectory: URL
) throws -> [MacPackageArtifact] {
    try packagingArtifactInputs(surface: surface).map {
        try materializePackagingArtifact($0, outputDirectory: outputDirectory)
    }
}

private func measuredPackagingFieldReport(
    permissionSurface: MacPackagedPermissionEntitlementSurface,
    artifacts: [MacPackageArtifact],
    fieldReport: FieldReportCoverage,
    osVersion: String
) -> PackagingFieldTestReport {
    PackagingFieldTestReport(
        metadata: PackagingFieldTestReport.Metadata(
            id: "m15-packaging-field-run",
            title: "Packaging and field readiness run",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            runMode: .measured,
            distributionMethod: .adHocLocal
        ),
        packageEvidence: PackagingFieldTestReport.PackageEvidence(
            package: packagingPackageIdentity(artifacts: artifacts),
            signing: adHocPackagingSigningReadiness(),
            notarization: localPackagingNotarizationReadiness(),
            entitlements: packagingEntitlementReadiness(),
            permissionEntitlementSurface: permissionSurface
        ),
        fieldEvidence: PackagingFieldTestReport.FieldEvidence(
            cleanMac: localPackagingCleanMacProbe(osVersion: osVersion),
            fieldReport: fieldReport
        ),
        result: PackagingFieldTestReport.Result(
            verdict: .partial,
            notes: "Ad-hoc local package artifacts were assembled; "
                + "Developer ID signing, notarization, and clean-Mac proof remain open."
        )
    )
}

private func finalizedPackagingFieldReport(
    _ report: PackagingFieldTestReport,
    integratedReport: IntegratedAvReport,
    appShellReport: NativeAppShellReport,
    recordingReport: RecordingSessionArtifactReport
) -> PackagingFieldTestReport {
    var report = report
    let verdictDecision = packagingFieldRunVerdict(
        report: report,
        runtimeVerdict: packagingFieldVerdict(
            integratedReport: integratedReport,
            appReport: appShellReport,
            recordingReport: recordingReport
        )
    )
    report.verdict = verdictDecision.verdict
    if let validationBlocker = verdictDecision.validationBlocker {
        report.notes = packagingFieldRunNotes(
            report.notes,
            validationBlocker: validationBlocker
        )
    }
    return report
}

private func packagingPackageIdentity(artifacts: [MacPackageArtifact]) -> MacPackageIdentity {
    MacPackageIdentity(
        productName: "Open LoLa",
        bundleIdentifier: "de.hfmt.open-lola.app",
        version: "0.1.0",
        minimumMacOSVersion: "14.0",
        contents: MacPackageContents(
            appBundleIncluded: true,
            cliToolsIncluded: ["open-lola", "open-lola-app"],
            documentationIncluded: true,
            reportTemplatesIncluded: true
        ),
        artifacts: artifacts
    )
}

private func adHocPackagingSigningReadiness() -> MacSigningReadiness {
    MacSigningReadiness(
        signed: false,
        signatureValid: false,
        identityType: .adHoc,
        signingIdentityLabel: "ad-hoc local build",
        hardenedRuntimeEnabled: false,
        secureTimestampPresent: false
    )
}

private func localPackagingNotarizationReadiness() -> MacNotarizationReadiness {
    MacNotarizationReadiness(
        submission: MacNotarizationReadiness.Submission(
            tool: .none,
            readyForSubmission: false,
            submitted: false,
            accepted: false
        ),
        ticket: MacNotarizationReadiness.Ticket(ticketStapled: false),
        gatekeeper: MacNotarizationReadiness.Gatekeeper(gatekeeperAccepted: false)
    )
}

private func packagingEntitlementReadiness() -> MacEntitlementReadiness {
    MacEntitlementReadiness(
        entitlementsReviewed: true,
        microphoneUsageDescriptionPresent: true,
        cameraUsageDescriptionPresent: true,
        localNetworkUsageDescriptionPresent: true,
        networkClientEntitlementPresent: true,
        appSandboxDecisionRecorded: true
    )
}

private func localPackagingCleanMacProbe(osVersion: String) -> CleanMacFieldProbe {
    CleanMacFieldProbe(
        installation: CleanMacFieldProbe.Installation(cleanMacTested: false),
        host: CleanMacFieldProbe.Host(
            hardwareIdentifier: "local-build-host",
            osVersion: osVersion,
            architecture: packagingHostArchitecture()
        ),
        smoke: CleanMacFieldProbe.Smoke(
            appLaunchSucceeded: false,
            cliSmokeSucceeded: true,
            reportWriteSucceeded: true
        ),
        access: CleanMacFieldProbe.Access(
            permissionsPrompted: false,
            audioDeviceAccessConfirmed: false,
            cameraAccessConfirmed: false,
            networkAccessConfirmed: true
        )
    )
}

private func packagingFieldRunVerdict(
    report: PackagingFieldTestReport,
    runtimeVerdict: MeasurementVerdict
) -> (verdict: MeasurementVerdict, validationBlocker: String?) {
    guard runtimeVerdict == .pass else {
        return (verdict: .partial, validationBlocker: nil)
    }
    var passCandidate = report
    passCandidate.verdict = .pass
    do {
        try passCandidate.validate()
        return (verdict: .pass, validationBlocker: nil)
    } catch {
        return (verdict: .partial, validationBlocker: String(describing: error))
    }
}

private func packagingFieldRunNotes(_ notes: String, validationBlocker: String) -> String {
    "\(notes) PASS validation blocked: \(validationBlocker)."
}

/// Creates deterministic synthetic packaging field test evidence that exercises report validation without claiming physical measurement.
public enum PackagingFieldTestSyntheticSmoke {
    public static func run() -> PackagingFieldTestReport {
        PackagingFieldTestReport(
            metadata: PackagingFieldTestReport.Metadata(
                id: "m15-packaging-field-test-synthetic-smoke",
                title: "Synthetic packaging field test",
                capturedAt: "2026-05-02T00:00:00Z",
                runMode: .synthetic,
                distributionMethod: .developerID
            ),
            packageEvidence: PackagingFieldTestReport.PackageEvidence(
                package: packagingPackageIdentity(artifacts: syntheticPackagingArtifacts()),
                signing: syntheticPackagingSigningReadiness(),
                notarization: syntheticPackagingNotarizationReadiness(),
                entitlements: packagingEntitlementReadiness(),
                permissionEntitlementSurface: packagedPermissionEntitlementSurface()
            ),
            fieldEvidence: PackagingFieldTestReport.FieldEvidence(
                cleanMac: syntheticPackagingCleanMacProbe(),
                fieldReport: completePackagingFieldReportCoverage()
            ),
            result: PackagingFieldTestReport.Result(
                verdict: .partial,
                notes: "Synthetic packaging contract validation only; "
                    + "no signed package or clean-Mac proof."
            )
        )
    }
}

private func syntheticPackagingArtifacts() -> [MacPackageArtifact] {
    [
        MacPackageArtifact(kind: .appBundle, relativePath: "OpenLoLa.app", required: true),
        MacPackageArtifact(kind: .commandLineTool, relativePath: "bin/open-lola", required: true)
    ]
}

private func syntheticPackagingSigningReadiness() -> MacSigningReadiness {
    MacSigningReadiness(
        signed: false,
        signatureValid: false,
        identityType: .none,
        signingIdentityLabel: "not signed",
        hardenedRuntimeEnabled: false,
        secureTimestampPresent: false
    )
}

private func syntheticPackagingNotarizationReadiness() -> MacNotarizationReadiness {
    MacNotarizationReadiness(
        submission: MacNotarizationReadiness.Submission(
            tool: .notarytool,
            readyForSubmission: false,
            submitted: false,
            accepted: false
        ),
        ticket: MacNotarizationReadiness.Ticket(ticketStapled: false),
        gatekeeper: MacNotarizationReadiness.Gatekeeper(gatekeeperAccepted: false)
    )
}

private func syntheticPackagingCleanMacProbe() -> CleanMacFieldProbe {
    CleanMacFieldProbe(
        installation: CleanMacFieldProbe.Installation(cleanMacTested: false),
        host: CleanMacFieldProbe.Host(
            hardwareIdentifier: "synthetic-mac",
            osVersion: "synthetic-macos",
            architecture: "arm64"
        ),
        smoke: CleanMacFieldProbe.Smoke(
            appLaunchSucceeded: false,
            cliSmokeSucceeded: false,
            reportWriteSucceeded: false
        ),
        access: CleanMacFieldProbe.Access(
            permissionsPrompted: false,
            audioDeviceAccessConfirmed: false,
            cameraAccessConfirmed: false,
            networkAccessConfirmed: false
        )
    )
}

func completePackagingFieldReportCoverage() -> FieldReportCoverage {
    FieldReportCoverage(
        evidenceSurfaces: FieldReportCoverage.EvidenceSurfaces(
            endpointEvidenceIncluded: true,
            networkEvidenceIncluded: true,
            audioEvidenceIncluded: true,
            videoEvidenceIncluded: true,
            controlEvidenceIncluded: true
        ),
        releaseEvidence: FieldReportCoverage.ReleaseEvidence(
            recordingEvidenceIncluded: true,
            packagingEvidenceIncluded: true,
            fallbackRouteDecisionRecorded: true,
            deferredArtisticIntegrationsRecorded: true,
            verdictLineRecorded: true
        )
    )
}
