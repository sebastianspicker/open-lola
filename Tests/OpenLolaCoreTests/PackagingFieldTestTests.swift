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
        "--report", "reports/m15-packaging-field.json",
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
            "--output-dir", "reports/m15-package",
        ])
    }
}

@Test
func packagingFieldRunnerWritesPartialAdHocPackageFromRuntimeReports() throws {
    let outputDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-packaging-field-\(UUID().uuidString)", isDirectory: true)
    let recordingDirectory = outputDirectory.appendingPathComponent("m14-session", isDirectory: true)
    let integratedReport = IntegratedAvRunner.run(
        configuration: IntegratedAvRunConfiguration(
            audioBaselineReportId: "m05-route-baseline-required",
            videoCaptureEnabled: true,
            videoTransportEnabled: true,
            oscControlEnabled: true,
            atemReadOnlyHost: nil,
            durationSeconds: 30,
            outputPath: outputDirectory.appendingPathComponent("m10-integrated-av.json").path
        )
    )
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
            outputDirectory: recordingDirectory.path,
            reportPath: outputDirectory.appendingPathComponent("m14-recording-session.json").path
        ),
        integratedBaseline: integratedReport
    )
    let configuration = PackagingFieldRunConfiguration(
        integratedReportPath: "reports/m10-integrated-av.json",
        appReportPath: "reports/m13-native-app-runtime-smoke.json",
        recordingReportPath: "reports/m14-recording-session.json",
        outputDirectory: outputDirectory.path,
        reportPath: outputDirectory.appendingPathComponent("m15-packaging-field.json").path
    )

    let report = try PackagingFieldRunner.run(
        configuration: configuration,
        integratedReport: integratedReport,
        appShellReport: appReport,
        recordingReport: recordingReport
    )

    try report.validate()

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
            audioBaselineReportId: "m05-route-baseline-pass",
            videoCaptureEnabled: true,
            videoTransportEnabled: true,
            oscControlEnabled: true,
            atemReadOnlyHost: nil,
            durationSeconds: 30,
            outputPath: outputDirectory.appendingPathComponent("m10-integrated-av-pass.json").path
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
    try expectPackagingFieldError(.passWithoutDeveloperIDSignature(.adHoc)) {
        $0.signing.identityType = .adHoc
    }
    try expectPackagingFieldError(.passWithPlaceholderSigningIdentity) {
        $0.signing.signingIdentityLabel = "Q010 signing identity not supplied"
    }
    try expectPackagingFieldError(.passWithoutHardenedRuntime) {
        $0.signing.hardenedRuntimeEnabled = false
    }
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
    try expectPackagingFieldError(.passWithoutFieldVerdictLine) {
        $0.fieldReport.verdictLineRecorded = false
    }
}

private func expectPackagingFieldError(
    _ expected: PackagingFieldTestValidationError,
    mutate: (inout PackagingFieldTestReport) throws -> Void
) throws {
    var report = try passCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func expectPackagingFieldFixtureError(
    _ expected: PackagingFieldTestValidationError,
    fixture: String,
    mutate: (inout PackagingFieldTestReport) throws -> Void = { _ in }
) throws {
    var report = try loadPackagingFieldTestFixture(named: fixture)
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func passCandidateReport() throws -> PackagingFieldTestReport {
    var report = try loadPackagingFieldTestFixture(named: "packaging-field-test-partial")
    report.verdict = .pass
    report.runMode = .measured
    report.package.artifacts = report.package.artifacts.map { artifact in
        MacPackageArtifact(
            kind: artifact.kind,
            relativePath: artifact.relativePath,
            required: artifact.required,
            sha256: fixtureSHA256
        )
    }
    report.package.artifacts.append(
        MacPackageArtifact(
            kind: .diskImage,
            relativePath: "OpenLoLa-0.1.0.dmg",
            required: true,
            sha256: fixtureSHA256
        )
    )
    report.signing.signed = true
    report.signing.signatureValid = true
    report.signing.identityType = .developerIDApplication
    report.signing.signingIdentityLabel = "Developer ID Application: Open LoLa Test Team (TEAMID1234)"
    report.signing.hardenedRuntimeEnabled = true
    report.signing.secureTimestampPresent = true
    report.notarization.readyForSubmission = true
    report.notarization.submitted = true
    report.notarization.accepted = true
    report.notarization.ticketStapled = true
    report.notarization.gatekeeperAccepted = true
    report.notarization.submissionIdentifier = "notary-submission-2026-05-04"
    report.notarization.stapledTicketPath = "OpenLoLa-0.1.0.dmg/.stapled-ticket"
    report.notarization.gatekeeperAssessment = "spctl accepted OpenLoLa-0.1.0.dmg"
    report.permissionEntitlementSurface = MacPackagedPermissionEntitlementSurface(
        infoPlistRelativePath: validPackagedPermissionSurface().infoPlistRelativePath,
        entitlementsRelativePath: validPackagedPermissionSurface().entitlementsRelativePath,
        microphoneUsageDescription: validPackagedPermissionSurface().microphoneUsageDescription,
        cameraUsageDescription: validPackagedPermissionSurface().cameraUsageDescription,
        localNetworkUsageDescription: validPackagedPermissionSurface().localNetworkUsageDescription,
        networkClientEntitlementKey: validPackagedPermissionSurface().networkClientEntitlementKey,
        appSandboxDecision: validPackagedPermissionSurface().appSandboxDecision
    )
    report.cleanMac.cleanMacTested = true
    report.cleanMac.installTargetLabel = "clean-mac-release-target-1"
    report.cleanMac.installedBundlePath = "/Applications/Open LoLa.app"
    report.cleanMac.installedArtifactSHA256 = fixtureSHA256
    report.cleanMac.packageHashVerified = true
    report.cleanMac.appLaunchSucceeded = true
    report.cleanMac.cliSmokeSucceeded = true
    report.cleanMac.permissionsPrompted = true
    report.cleanMac.audioDeviceAccessConfirmed = true
    report.cleanMac.cameraAccessConfirmed = true
    report.cleanMac.networkAccessConfirmed = true
    report.cleanMac.reportWriteSucceeded = true
    report.fieldReport.endpointEvidenceIncluded = true
    report.fieldReport.networkEvidenceIncluded = true
    report.fieldReport.audioEvidenceIncluded = true
    report.fieldReport.videoEvidenceIncluded = true
    report.fieldReport.controlEvidenceIncluded = true
    report.fieldReport.recordingEvidenceIncluded = true
    return report
}

private func validPackagedPermissionSurface() -> MacPackagedPermissionEntitlementSurface {
    MacPackagedPermissionEntitlementSurface(
        infoPlistRelativePath: "Open LoLa.app/Contents/Info.plist",
        entitlementsRelativePath: "Open LoLa.app/Contents/open-lola.entitlements",
        microphoneUsageDescription: "Open LoLa captures selected audio inputs for field validation.",
        cameraUsageDescription: "Open LoLa captures selected camera frames for field validation.",
        localNetworkUsageDescription: "Open LoLa exchanges local UDP media with the configured peer Mac.",
        networkClientEntitlementKey: "com.apple.security.network.client",
        appSandboxDecision: "Sandbox disabled for hardware validation and documented in release notes."
    )
}

private let fixtureSHA256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

private func loadPackagingFieldTestFixture(named name: String) throws -> PackagingFieldTestReport {
    let url = try packagingFieldTestFixtureURL(named: name)
    return try PackagingFieldTestReport.decode(from: Data(contentsOf: url))
}

private func packagingFieldTestFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "PackagingFieldTests/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "PackagingFieldTests/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}

private var packagingFieldTestRepositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
