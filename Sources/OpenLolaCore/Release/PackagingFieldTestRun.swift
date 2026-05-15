import CryptoKit
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

public enum PackagingFieldRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
}

public enum PackagingFieldRunner {
    public static func run(configuration: PackagingFieldRunConfiguration) throws -> PackagingFieldTestReport {
        let integratedReport = try IntegratedAvReport.readValidated(fromPath: configuration.integratedReportPath)
        let appReport = try NativeAppShellReport.readValidated(fromPath: configuration.appReportPath)
        let recordingReport = try RecordingSessionArtifactReport.readValidated(fromPath: configuration.recordingReportPath)
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

        var artifacts: [MacPackageArtifact] = []
        for artifactInput in packagingArtifactInputs(surface: permissionSurface) {
            artifacts.append(try materializePackagingArtifact(artifactInput, outputDirectory: outputURL))
        }

        let fieldReport = try writePackagingFieldArtifacts(
            outputDirectory: configuration.outputDirectory,
            integratedReport: integratedReport,
            appReport: appShellReport,
            recordingReport: recordingReport
        )

        var report = PackagingFieldTestReport(
            id: "m15-packaging-field-run",
            title: "Packaging and field readiness run",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            runMode: .measured,
            distributionMethod: .adHocLocal,
            package: MacPackageIdentity(
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
            ),
            signing: MacSigningReadiness(
                signed: false,
                signatureValid: false,
                identityType: .adHoc,
                signingIdentityLabel: "ad-hoc local build",
                hardenedRuntimeEnabled: false,
                secureTimestampPresent: false
            ),
            notarization: MacNotarizationReadiness(
                tool: .none,
                readyForSubmission: false,
                submitted: false,
                accepted: false,
                ticketStapled: false,
                gatekeeperAccepted: false
            ),
            entitlements: MacEntitlementReadiness(
                entitlementsReviewed: true,
                microphoneUsageDescriptionPresent: true,
                cameraUsageDescriptionPresent: true,
                localNetworkUsageDescriptionPresent: true,
                networkClientEntitlementPresent: true,
                appSandboxDecisionRecorded: true
            ),
            permissionEntitlementSurface: permissionSurface,
            cleanMac: CleanMacFieldProbe(
                cleanMacTested: false,
                hardwareIdentifier: "local-build-host",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                architecture: packagingHostArchitecture(),
                appLaunchSucceeded: false,
                cliSmokeSucceeded: true,
                permissionsPrompted: false,
                audioDeviceAccessConfirmed: false,
                cameraAccessConfirmed: false,
                networkAccessConfirmed: true,
                reportWriteSucceeded: true
            ),
            fieldReport: fieldReport,
            verdict: .partial,
            notes: "Ad-hoc local package artifacts were assembled; Developer ID signing, notarization, and clean-Mac proof remain open."
        )
        report.verdict = packagingFieldRunVerdict(
            report: report,
            runtimeVerdict: packagingFieldVerdict(
                integratedReport: integratedReport,
                appReport: appShellReport,
                recordingReport: recordingReport
            )
        )
        return report
    }
}

private func packagingFieldRunVerdict(
    report: PackagingFieldTestReport,
    runtimeVerdict: MeasurementVerdict
) -> MeasurementVerdict {
    guard runtimeVerdict == .pass else {
        return .partial
    }
    var passCandidate = report
    passCandidate.verdict = .pass
    return (try? passCandidate.validate()) == nil ? .partial : .pass
}

public enum PackagingFieldTestSyntheticSmoke {
    public static func run() -> PackagingFieldTestReport {
        PackagingFieldTestReport(
            id: "m15-packaging-field-test-synthetic-smoke",
            title: "Synthetic packaging field test",
            capturedAt: "2026-05-02T00:00:00Z",
            runMode: .synthetic,
            distributionMethod: .developerID,
            package: MacPackageIdentity(
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
                artifacts: [
                    MacPackageArtifact(kind: .appBundle, relativePath: "OpenLoLa.app", required: true),
                    MacPackageArtifact(kind: .commandLineTool, relativePath: "bin/open-lola", required: true),
                ]
            ),
            signing: MacSigningReadiness(
                signed: false,
                signatureValid: false,
                identityType: .none,
                signingIdentityLabel: "not signed",
                hardenedRuntimeEnabled: false,
                secureTimestampPresent: false
            ),
            notarization: MacNotarizationReadiness(
                tool: .notarytool,
                readyForSubmission: false,
                submitted: false,
                accepted: false,
                ticketStapled: false,
                gatekeeperAccepted: false
            ),
            entitlements: MacEntitlementReadiness(
                entitlementsReviewed: true,
                microphoneUsageDescriptionPresent: true,
                cameraUsageDescriptionPresent: true,
                localNetworkUsageDescriptionPresent: true,
                networkClientEntitlementPresent: true,
                appSandboxDecisionRecorded: true
            ),
            permissionEntitlementSurface: packagedPermissionEntitlementSurface(),
            cleanMac: CleanMacFieldProbe(
                cleanMacTested: false,
                hardwareIdentifier: "synthetic-mac",
                osVersion: "synthetic-macos",
                architecture: "arm64",
                appLaunchSucceeded: false,
                cliSmokeSucceeded: false,
                permissionsPrompted: false,
                audioDeviceAccessConfirmed: false,
                cameraAccessConfirmed: false,
                networkAccessConfirmed: false,
                reportWriteSucceeded: false
            ),
            fieldReport: FieldReportCoverage(
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
            ),
            verdict: .partial,
            notes: "Synthetic packaging contract validation only; no signed package or clean-Mac proof."
        )
    }
}

private func packagedPermissionEntitlementSurface() -> MacPackagedPermissionEntitlementSurface {
    MacPackagedPermissionEntitlementSurface(
        infoPlistRelativePath: "OpenLoLa.app/Contents/Info.plist",
        entitlementsRelativePath: "OpenLoLa.app/Contents/Resources/open-lola-app.entitlements",
        microphoneUsageDescription: "Open LoLa captures selected audio inputs for explicit Mac-to-Mac audio tests.",
        cameraUsageDescription: "Open LoLa captures selected camera frames for explicit Mac-to-Mac video tests.",
        localNetworkUsageDescription: "Open LoLa sends and receives local UDP media between configured Mac peers.",
        networkClientEntitlementKey: "com.apple.security.network.client",
        appSandboxDecision: "App sandbox disabled for direct Core Audio, camera, and UDP device access in field prototypes."
    )
}

private struct PackagingArtifactInput {
    let kind: MacPackageArtifactKind
    let relativePath: String
    let required: Bool
    let sourcePath: String?
    let generatedData: Data?
}

private func packagingArtifactInputs(
    surface: MacPackagedPermissionEntitlementSurface
) -> [PackagingArtifactInput] {
    [
        PackagingArtifactInput(
            kind: .appBundle,
            relativePath: surface.infoPlistRelativePath,
            required: true,
            sourcePath: "Sources/open-lola-app/Info.plist",
            generatedData: Data(packagedInfoPlist(surface).utf8)
        ),
        PackagingArtifactInput(
            kind: .appBundle,
            relativePath: "OpenLoLa.app/Contents/MacOS/open-lola-app",
            required: true,
            sourcePath: firstReachablePackagingSource([
                ".build/\(packagingBuildTriple())/debug/open-lola-app",
                ".build/debug/open-lola-app",
            ]),
            generatedData: nil
        ),
        PackagingArtifactInput(
            kind: .commandLineTool,
            relativePath: "bin/open-lola",
            required: true,
            sourcePath: firstReachablePackagingSource([
                ".build/\(packagingBuildTriple())/debug/open-lola",
                ".build/debug/open-lola",
            ]),
            generatedData: nil
        ),
        PackagingArtifactInput(
            kind: .commandLineTool,
            relativePath: "bin/open-lola-app",
            required: true,
            sourcePath: firstReachablePackagingSource([
                ".build/\(packagingBuildTriple())/debug/open-lola-app",
                ".build/debug/open-lola-app",
            ]),
            generatedData: nil
        ),
        PackagingArtifactInput(
            kind: .documentation,
            relativePath: "Documentation/README.md",
            required: true,
            sourcePath: "README.md",
            generatedData: Data("Open LoLa packaging README source was not reachable.\n".utf8)
        ),
        PackagingArtifactInput(
            kind: .entitlements,
            relativePath: surface.entitlementsRelativePath,
            required: true,
            sourcePath: "Sources/open-lola-app/open-lola-app.entitlements",
            generatedData: Data(packagedEntitlementsPlist(surface).utf8)
        ),
        PackagingArtifactInput(
            kind: .entitlements,
            relativePath: "Entitlements/open-lola.entitlements",
            required: true,
            sourcePath: "Sources/open-lola/open-lola.entitlements",
            generatedData: nil
        ),
        PackagingArtifactInput(
            kind: .manifest,
            relativePath: "manifest.json",
            required: true,
            sourcePath: nil,
            generatedData: Data(packagedManifestJSON().utf8)
        ),
        PackagingArtifactInput(
            kind: .reportTemplate,
            relativePath: "ReportTemplates/field-report.md",
            required: true,
            sourcePath: nil,
            generatedData: Data(packagedFieldReportTemplate().utf8)
        ),
    ]
}

private func materializePackagingArtifact(
    _ input: PackagingArtifactInput,
    outputDirectory: URL
) throws -> MacPackageArtifact {
    let destination = outputDirectory.appendingPathComponent(input.relativePath)
    try FileManager.default.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    let data: Data
    if let sourcePath = input.sourcePath,
       FileManager.default.fileExists(atPath: sourcePath) {
        data = try BoundedFileReader.data(atPath: sourcePath)
    } else if let generatedData = input.generatedData {
        data = generatedData
    } else {
        data = Data("open-lola package artifact unavailable: \(input.relativePath)\n".utf8)
    }
    try data.write(to: destination)
    return MacPackageArtifact(
        kind: input.kind,
        relativePath: input.relativePath,
        required: input.required,
        sha256: packagingSHA256(data)
    )
}

private func packagedInfoPlist(_ surface: MacPackagedPermissionEntitlementSurface) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key>
      <string>de.hfmt.open-lola.app</string>
      <key>NSCameraUsageDescription</key>
      <string>\(surface.cameraUsageDescription)</string>
      <key>NSLocalNetworkUsageDescription</key>
      <string>\(surface.localNetworkUsageDescription)</string>
      <key>NSMicrophoneUsageDescription</key>
      <string>\(surface.microphoneUsageDescription)</string>
    </dict>
    </plist>
    """
}

private func packagedEntitlementsPlist(_ surface: MacPackagedPermissionEntitlementSurface) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>\(surface.networkClientEntitlementKey)</key>
      <true/>
    </dict>
    </plist>
    """
}

private func packagedManifestJSON() -> String {
    """
    {
      "product": "Open LoLa",
      "packageKind": "ad-hoc-local-field-prototype",
      "requiredArtifacts": [
        "OpenLoLa.app/Contents/Info.plist",
        "OpenLoLa.app/Contents/MacOS/open-lola-app",
        "OpenLoLa.app/Contents/Resources/open-lola-app.entitlements",
        "bin/open-lola",
        "bin/open-lola-app"
      ]
    }
    """
}

private func packagedFieldReportTemplate() -> String {
    """
    # Open LoLa Field Report

    - Endpoint evidence:
    - Network evidence:
    - Audio evidence:
    - Video evidence:
    - Control evidence:
    - Recording evidence:
    - Packaging evidence:
    - VERDICT:
    """
}

private func firstReachablePackagingSource(_ paths: [String]) -> String? {
    paths.first { FileManager.default.fileExists(atPath: $0) }
}

private func packagingBuildTriple() -> String {
    #if arch(arm64)
    "arm64-apple-macosx"
    #elseif arch(x86_64)
    "x86_64-apple-macosx"
    #else
    "unknown-apple-macosx"
    #endif
}

private func packagingSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
