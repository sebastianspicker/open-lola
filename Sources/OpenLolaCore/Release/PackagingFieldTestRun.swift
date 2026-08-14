// Coordinates release-readiness execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation

/// CLI and programmatic input contract for packaging field-test artifact generation.
public struct PackagingFieldRunConfiguration: Codable, Equatable, Sendable {
    public let integratedReportPath: String
    public let appReportPath: String
    public let recordingReportPath: String
    public let appBundlePath: String
    public let outputDirectory: String
    public let reportPath: String

    public init(
        integratedReportPath: String,
        appReportPath: String,
        recordingReportPath: String,
        appBundlePath: String = "dist/OpenLoLa.app",
        outputDirectory: String,
        reportPath: String
    ) {
        self.integratedReportPath = integratedReportPath
        self.appReportPath = appReportPath
        self.recordingReportPath = recordingReportPath
        self.appBundlePath = appBundlePath
        self.outputDirectory = outputDirectory
        self.reportPath = reportPath
    }

    private enum CodingKeys: String, CodingKey {
        case integratedReportPath
        case appReportPath
        case recordingReportPath
        case appBundlePath
        case outputDirectory
        case reportPath
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        integratedReportPath = try values.decode(String.self, forKey: .integratedReportPath)
        appReportPath = try values.decode(String.self, forKey: .appReportPath)
        recordingReportPath = try values.decode(String.self, forKey: .recordingReportPath)
        appBundlePath = try values.decodeIfPresent(String.self, forKey: .appBundlePath) ?? "dist/OpenLoLa.app"
        outputDirectory = try values.decode(String.self, forKey: .outputDirectory)
        reportPath = try values.decode(String.self, forKey: .reportPath)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(integratedReportPath, forKey: .integratedReportPath)
        try values.encode(appReportPath, forKey: .appReportPath)
        try values.encode(recordingReportPath, forKey: .recordingReportPath)
        try values.encode(appBundlePath, forKey: .appBundlePath)
        try values.encode(outputDirectory, forKey: .outputDirectory)
        try values.encode(reportPath, forKey: .reportPath)
    }

    public static func parse(_ arguments: [String]) throws -> PackagingFieldRunConfiguration {
        let allowed = [
            "--integrated-report",
            "--app-report",
            "--recording-report",
            "--app-bundle",
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
            appBundlePath: values["--app-bundle"] ?? "dist/OpenLoLa.app",
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
        let outputURL = URL(fileURLWithPath: configuration.outputDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        let appBundleURL = URL(fileURLWithPath: configuration.appBundlePath, isDirectory: true)
        guard FileManager.default.fileExists(atPath: appBundleURL.path) else {
            throw PackagingFieldArtifactInspectionError.missingStagedAppBundle(appBundleURL.path)
        }
        return try run(
            configuration: configuration,
            integratedReport: integratedReport,
            appShellReport: appShellReport,
            recordingReport: recordingReport,
            codeSigningInspection: nil
        )
    }

    static func run(
        configuration: PackagingFieldRunConfiguration,
        integratedReport: IntegratedAvReport,
        appShellReport: NativeAppShellReport,
        recordingReport: RecordingSessionArtifactReport,
        codeSigningInspection: StagedCodeSigningInspection? = nil,
        codeSigningInspector: ((URL) throws -> StagedCodeSigningInspection)? = nil
    ) throws -> PackagingFieldTestReport {
        let outputURL = URL(fileURLWithPath: configuration.outputDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        let appBundleURL = URL(fileURLWithPath: configuration.appBundlePath, isDirectory: true)
        let bundleMetadata = try inspectedStagedAppBundleMetadata(appBundleURL: appBundleURL)
        let artifacts = try inspectedStagedAppBundleArtifacts(
            surface: bundleMetadata.permissionEntitlementSurface,
            appBundleURL: appBundleURL
        )
        let codeSigningInspection = try codeSigningInspection
            ?? codeSigningInspector?(appBundleURL)
            ?? inspectedStagedAppBundleCodeSigning(appBundleURL: appBundleURL)
        try writePackagingFieldArtifacts(
            outputDirectory: configuration.outputDirectory,
            integratedReport: integratedReport,
            appReport: appShellReport,
            recordingReport: recordingReport
        )

        let report = measuredPackagingFieldReport(
            bundleMetadata: bundleMetadata,
            artifacts: artifacts,
            fieldReport: localPackagingFieldReportCoverage(),
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            codeSigningInspection: codeSigningInspection
        )
        return finalizedPackagingFieldReport(
            report,
            integratedReport: integratedReport,
            appShellReport: appShellReport,
            recordingReport: recordingReport
        )
    }
}

private func measuredPackagingFieldReport(
    bundleMetadata: StagedAppBundleMetadata,
    artifacts: [MacPackageArtifact],
    fieldReport: FieldReportCoverage,
    osVersion: String,
    codeSigningInspection: StagedCodeSigningInspection
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
            package: packagingPackageIdentity(bundleMetadata: bundleMetadata, artifacts: artifacts),
            signing: codeSigningInspection.signingReadiness,
            notarization: localPackagingNotarizationReadiness(),
            entitlements: packagingEntitlementReadiness(
                surface: bundleMetadata.permissionEntitlementSurface,
                codeSigningInspection: codeSigningInspection
            ),
            permissionEntitlementSurface: bundleMetadata.permissionEntitlementSurface
        ),
        fieldEvidence: PackagingFieldTestReport.FieldEvidence(
            cleanMac: localPackagingCleanMacProbe(osVersion: osVersion),
            fieldReport: fieldReport
        ),
        result: PackagingFieldTestReport.Result(
            verdict: .partial,
            notes: "Ad-hoc local package artifacts were inspected; embedded app sandbox is "
                + "\(codeSigningInspection.appSandboxEnabled ? "enabled" : "disabled"); "
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

private func packagingPackageIdentity(
    bundleMetadata: StagedAppBundleMetadata,
    artifacts: [MacPackageArtifact]
) -> MacPackageIdentity {
    MacPackageIdentity(
        productName: bundleMetadata.productName,
        bundleIdentifier: bundleMetadata.bundleIdentifier,
        version: bundleMetadata.version,
        minimumMacOSVersion: bundleMetadata.minimumMacOSVersion,
        contents: MacPackageContents(
            appBundleIncluded: artifacts.contains { $0.relativePath.hasSuffix("/Contents/Info.plist") },
            cliToolsIncluded: artifacts.compactMap { artifact in
                guard artifact.kind == .commandLineTool else { return nil }
                return URL(fileURLWithPath: artifact.relativePath).lastPathComponent
            },
            documentationIncluded: artifacts.contains { $0.kind == .documentation },
            reportTemplatesIncluded: artifacts.contains { $0.kind == .reportTemplate }
        ),
        artifacts: artifacts
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

private func packagingEntitlementReadiness(
    surface: MacPackagedPermissionEntitlementSurface,
    codeSigningInspection: StagedCodeSigningInspection
) -> MacEntitlementReadiness {
    MacEntitlementReadiness(
        entitlementsReviewed: false,
        microphoneUsageDescriptionPresent: !surface.microphoneUsageDescription.isEmpty,
        cameraUsageDescriptionPresent: !surface.cameraUsageDescription.isEmpty,
        localNetworkUsageDescriptionPresent: !surface.localNetworkUsageDescription.isEmpty,
        networkClientEntitlementPresent: codeSigningInspection.networkClientEntitlementEnabled,
        appSandboxDecisionRecorded: false
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
                package: syntheticPackagingPackageIdentity(),
                signing: syntheticPackagingSigningReadiness(),
                notarization: syntheticPackagingNotarizationReadiness(),
                entitlements: syntheticPackagingEntitlementReadiness(),
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

private func syntheticPackagingPackageIdentity() -> MacPackageIdentity {
    MacPackageIdentity(
        productName: "Open LoLa",
        bundleIdentifier: "de.hfmt.open-lola.app",
        version: "0.1.0",
        minimumMacOSVersion: "14.0",
        contents: MacPackageContents(
            appBundleIncluded: true,
            cliToolsIncluded: ["open-lola"],
            documentationIncluded: true,
            reportTemplatesIncluded: true
        ),
        artifacts: syntheticPackagingArtifacts()
    )
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

private func localPackagingFieldReportCoverage() -> FieldReportCoverage {
    FieldReportCoverage(
        evidenceSurfaces: FieldReportCoverage.EvidenceSurfaces(
            endpointEvidenceIncluded: false,
            networkEvidenceIncluded: false,
            audioEvidenceIncluded: false,
            videoEvidenceIncluded: false,
            controlEvidenceIncluded: false
        ),
        releaseEvidence: FieldReportCoverage.ReleaseEvidence(
            recordingEvidenceIncluded: false,
            packagingEvidenceIncluded: false,
            fallbackRouteDecisionRecorded: false,
            deferredArtisticIntegrationsRecorded: false,
            verdictLineRecorded: false
        )
    )
}

private func syntheticPackagingEntitlementReadiness() -> MacEntitlementReadiness {
    MacEntitlementReadiness(
        entitlementsReviewed: true,
        microphoneUsageDescriptionPresent: true,
        cameraUsageDescriptionPresent: true,
        localNetworkUsageDescriptionPresent: true,
        networkClientEntitlementPresent: true,
        appSandboxDecisionRecorded: true
    )
}
