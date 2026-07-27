// Verifies that packaging field test rejects invalid pass fixtures.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func packagingFieldTestRejectsInvalidPassFixtures() throws {
    let report = try loadPackagingFieldTestFixture(named: "packaging-field-test-synthetic-pass")

    #expect(throws: PackagingFieldTestValidationError.passWithoutMeasuredRun) {
        try report.validate()
    }

    try expectPackagingFieldFixtureError(
        .passWithoutSignedPackage,
        fixture: "packaging-field-test-missing-signing"
    )
    try expectPackagingFieldFixtureError(
        .passWithoutAcceptedNotarization,
        fixture: "packaging-field-test-missing-notarization"
    )
    try expectPackagingFieldFixtureError(
        .passWithoutGatekeeperAcceptance,
        fixture: "packaging-field-test-missing-gatekeeper"
    )
    try expectPackagingFieldFixtureError(
        .passWithoutCleanMacTest,
        fixture: "packaging-field-test-missing-clean-mac"
    ) {
        $0.permissionEntitlementSurface = validPackagedPermissionSurface()
    }
}

@Test
func packagingFieldRunConfigurationParsesRequiredArgumentsAndRejectsMissingReport() throws {
    let configuration = try PackagingFieldRunConfiguration.parse([
        "--integrated-report", "reports/m10-integrated-av.json",
        "--app-report", "reports/m13-native-app-runtime-smoke.json",
        "--recording-report", "reports/m14-recording-session.json",
        "--output-dir", "reports/m15-package",
        "--report", "reports/m15-packaging-field.json"
    ])

    #expect(configuration.integratedReportPath == "reports/m10-integrated-av.json")
    #expect(configuration.appReportPath == "reports/m13-native-app-runtime-smoke.json")
    #expect(configuration.recordingReportPath == "reports/m14-recording-session.json")
    #expect(configuration.outputDirectory == "reports/m15-package")
    #expect(configuration.reportPath == "reports/m15-packaging-field.json")

    #expect(throws: PackagingFieldRunConfigurationError.missingRequiredArgument("--report")) {
        _ = try PackagingFieldRunConfiguration.parse([
            "--integrated-report", "reports/m10-integrated-av.json",
            "--app-report", "reports/m13-native-app-runtime-smoke.json",
            "--recording-report", "reports/m14-recording-session.json",
            "--output-dir", "reports/m15-package"
        ])
    }
}

@Test
func packagingFieldRunnerWritesPartialAdHocPackageFromRuntimeReports() throws {
    let outputDirectory = packagingFieldTemporaryOutputDirectory()
    let runtimeReports = try packagingFieldPartialRuntimeReports(outputDirectory: outputDirectory)

    let report = try PackagingFieldRunner.run(
        configuration: packagingFieldRunConfiguration(outputDirectory: outputDirectory),
        integratedReport: runtimeReports.integratedReport,
        appShellReport: runtimeReports.appReport,
        recordingReport: runtimeReports.recordingReport
    )

    try report.validate()
    try expectPartialAdHocPackagingFieldReport(report, outputDirectory: outputDirectory)
}

private struct PackagingFieldRuntimeReports {
    var integratedReport: IntegratedAvReport
    var appReport: NativeAppShellReport
    var recordingReport: RecordingSessionArtifactReport
}

private func packagingFieldTemporaryOutputDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-packaging-field-\(UUID().uuidString)", isDirectory: true)
}

private func packagingFieldPartialRuntimeReports(
    outputDirectory: URL
) throws -> PackagingFieldRuntimeReports {
    let integratedReport = makeFieldReadyIntegratedAvReport(outputDirectory: outputDirectory)
    let appReport = NativeAppRuntimeSmoke.run(
        configuration: NativeAppRuntimeSmokeConfiguration(
            headlessReportPath: "reports/m10-integrated-av.json",
            outputPath: "reports/m13-native-app-runtime-smoke.json"
        ),
        headlessReport: integratedReport
    )
    let recordingReport = try RecordingSessionRunner.run(
        configuration: RecordingSessionRunConfiguration(
            integratedBaselinePath: "reports/m10-integrated-av.json",
            durationSeconds: 30,
            outputDirectory: outputDirectory.appendingPathComponent("m14-session", isDirectory: true).path,
            reportPath: outputDirectory.appendingPathComponent("m14-recording-session.json").path
        ),
        integratedBaseline: integratedReport
    )
    return PackagingFieldRuntimeReports(
        integratedReport: integratedReport,
        appReport: appReport,
        recordingReport: recordingReport
    )
}

private func packagingFieldRunConfiguration(outputDirectory: URL) -> PackagingFieldRunConfiguration {
    PackagingFieldRunConfiguration(
        integratedReportPath: "reports/m10-integrated-av.json",
        appReportPath: "reports/m13-native-app-runtime-smoke.json",
        recordingReportPath: "reports/m14-recording-session.json",
        outputDirectory: outputDirectory.path,
        reportPath: outputDirectory.appendingPathComponent("m15-packaging-field.json").path
    )
}

private func expectPartialAdHocPackagingFieldReport(
    _ report: PackagingFieldTestReport,
    outputDirectory: URL
) throws {
    #expect(report.id == "m15-packaging-field-run")
    #expect(report.runMode == .measured)
    #expect(report.distributionMethod == .adHocLocal)
    #expect(report.verdict == .partial)
    #expect(report.package.contents.appBundleIncluded)
    #expect(report.package.contents.cliToolsIncluded.contains("open-lola"))
    #expect(report.package.contents.cliToolsIncluded.contains("open-lola-app"))
    #expect(report.signing.identityType == .adHoc)
    #expect(report.signing.signed == false)
    #expect(report.notarization.tool == .none)
    let surface = try #require(report.permissionEntitlementSurface)
    let infoPlist = try String(
        contentsOf: outputDirectory.appendingPathComponent(surface.infoPlistRelativePath),
        encoding: .utf8
    )
    let entitlements = try String(
        contentsOf: outputDirectory.appendingPathComponent(surface.entitlementsRelativePath),
        encoding: .utf8
    )
    #expect(infoPlist.contains("NSCameraUsageDescription"))
    #expect(infoPlist.contains("NSLocalNetworkUsageDescription"))
    #expect(infoPlist.contains("CFBundleIdentifier"))
    #expect(infoPlist.contains("de.hfmt.open-lola.app"))
    #expect(entitlements.contains("com.apple.security.network.client"))
    #expect(report.fieldReport.audioEvidenceIncluded)
    #expect(report.fieldReport.videoEvidenceIncluded)
    #expect(report.fieldReport.controlEvidenceIncluded)
    #expect(report.fieldReport.recordingEvidenceIncluded)
    #expect(report.cleanMac.cleanMacTested == false)
    #expect(!report.notes.contains("PASS validation blocked"))

    for artifact in report.package.artifacts where artifact.required {
        let artifactURL = outputDirectory.appendingPathComponent(artifact.relativePath)
        #expect(FileManager.default.fileExists(atPath: artifactURL.path))
        #expect(artifact.sha256?.count == 64)
    }
    #expect(report.package.artifacts.contains { artifact in
        artifact.relativePath == "OpenLoLa.app/Contents/MacOS/open-lola-app"
            && artifact.sha256 != nil
    })
    #expect(report.package.artifacts.contains { artifact in
        artifact.relativePath == "Entitlements/open-lola.entitlements"
            && artifact.sha256 != nil
    })
}

@Test
func packagingFieldRunnerKeepsAdHocPackagePartialWithPassingRuntimeReports() throws {
    let outputDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-packaging-field-pass-guard-\(UUID().uuidString)", isDirectory: true)
    let configuration = PackagingFieldRunConfiguration(
        integratedReportPath: "reports/m10-integrated-av-pass.json",
        appReportPath: "reports/m13-native-app-runtime-smoke-pass.json",
        recordingReportPath: "reports/m14-recording-session-pass.json",
        outputDirectory: outputDirectory.path,
        reportPath: outputDirectory.appendingPathComponent("m15-packaging-field.json").path
    )
    var integratedReport = IntegratedAvRunner.run(
        configuration: IntegratedAvRunConfiguration(
            artifacts: IntegratedAvRunConfiguration.ArtifactPaths(
                audioBaselineReportId: "m05-route-baseline-pass",
                outputPath: outputDirectory.appendingPathComponent("m10-integrated-av-pass.json").path
            ),
            media: IntegratedAvRunConfiguration.MediaOptions(
                videoCaptureEnabled: true,
                videoTransportEnabled: true
            ),
            control: IntegratedAvRunConfiguration.ControlOptions(
                oscControlEnabled: true,
                atemReadOnlyHost: nil
            ),
            durationSeconds: 30,
        )
    )
    var appReport = NativeAppShellSyntheticSmoke.run()
    var recordingReport = RecordingSessionSyntheticSmoke.run()
    integratedReport.verdict = .pass
    appReport.verdict = .pass
    recordingReport.verdict = .pass

    let report = try PackagingFieldRunner.run(
        configuration: configuration,
        integratedReport: integratedReport,
        appShellReport: appReport,
        recordingReport: recordingReport
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.distributionMethod == .adHocLocal)
    #expect(report.signing.identityType == .adHoc)
    #expect(!report.cleanMac.cleanMacTested)
    #expect(report.notes.contains("PASS validation blocked"))
    #expect(report.notes.contains("passWithoutReleaseDistribution"))
    #expect(report.notes.contains("adHocLocal"))
}

@Test
func packagingFieldTestRejectsInvalidPassEvidenceAndPlaceholderSigningIdentity() throws {
    try expectPackagingFieldRejectsDistributionAndArtifactPassGaps()
    try expectPackagingFieldRejectsSigningPassGaps()
    try expectPackagingFieldRejectsNotarizationPassGaps()
    try expectPackagingFieldRejectsPermissionSurfacePassGaps()
    try expectPackagingFieldRejectsCleanMacPassGaps()
    try expectPackagingFieldRejectsFieldReportPassGaps()
}

private func expectPackagingFieldRejectsDistributionAndArtifactPassGaps() throws {
    try expectPackagingFieldError(.passWithoutReleaseDistribution(.adHocLocal)) {
        $0.distributionMethod = .adHocLocal
    }
    try expectPackagingFieldError(.passWithoutDistributionArtifact) {
        $0.package.artifacts.removeAll { $0.kind == .diskImage || $0.kind == .zipArchive }
    }
    try expectPackagingFieldError(.passWithoutArtifactHash("Open LoLa.app")) {
        $0.package.artifacts[0].sha256 = nil
    }
    try expectPackagingFieldError(.passWithoutAppBundle) {
        $0.package.contents.appBundleIncluded = false
    }
}

private func expectPackagingFieldRejectsSigningPassGaps() throws {
    try expectPackagingFieldError(.passWithoutDeveloperIDSignature(.adHoc)) {
        $0.signing.identityType = .adHoc
    }
    try expectPackagingFieldError(.passWithPlaceholderSigningIdentity) {
        $0.signing.signingIdentityLabel = "Q010 signing identity not supplied"
    }
    try expectPackagingFieldError(.passWithoutHardenedRuntime) {
        $0.signing.hardenedRuntimeEnabled = false
    }
}

private func expectPackagingFieldRejectsNotarizationPassGaps() throws {
    try expectPackagingFieldError(.passUsesDeprecatedAltool) {
        $0.notarization.tool = .altool
    }
    try expectPackagingFieldError(.passWithoutNotarizationReadiness) {
        $0.notarization.readyForSubmission = false
    }
    try expectPackagingFieldError(.passWithoutNotarizationSubmissionId) {
        $0.notarization.submissionIdentifier = nil
    }
    try expectPackagingFieldError(.passWithoutStapledTicketEvidence) {
        $0.notarization.stapledTicketPath = nil
    }
    try expectPackagingFieldError(.passWithoutGatekeeperAssessmentEvidence) {
        $0.notarization.gatekeeperAssessment = nil
    }
}

private func expectPackagingFieldRejectsPermissionSurfacePassGaps() throws {
    try expectPackagingFieldError(.passWithoutRequiredPurposeStrings) {
        $0.entitlements.cameraUsageDescriptionPresent = false
    }
    try expectPackagingFieldError(.passWithoutPackagedPermissionEntitlementSurface) {
        $0.permissionEntitlementSurface = nil
    }
    try expectPackagingFieldError(.passWithPlaceholderPackagedPermissionEntitlementField(
        "permissionEntitlementSurface.localNetworkUsageDescription"
    )) {
        $0.permissionEntitlementSurface?.localNetworkUsageDescription = "TODO(human): required"
    }
}

private func expectPackagingFieldRejectsCleanMacPassGaps() throws {
    try expectPackagingFieldError(.passWithoutCleanMacTest) {
        $0.cleanMac.cleanMacTested = false
    }
    try expectPackagingFieldError(.passWithoutCleanMacInstallTarget) {
        $0.cleanMac.installTargetLabel = nil
    }
    try expectPackagingFieldError(.passWithPlaceholderCleanMacEvidence("cleanMac.installTargetLabel")) {
        $0.cleanMac.installTargetLabel = "Q010 clean Mac target not supplied"
    }
    try expectPackagingFieldError(.passWithoutCleanMacHashVerification) {
        $0.cleanMac.packageHashVerified = false
    }
    try expectPackagingFieldError(.passWithoutCleanMacLaunch) {
        $0.cleanMac.appLaunchSucceeded = false
    }
}

private func expectPackagingFieldRejectsFieldReportPassGaps() throws {
    try expectPackagingFieldError(.passWithoutFieldVerdictLine) {
        $0.fieldReport.verdictLineRecorded = false
    }
}
