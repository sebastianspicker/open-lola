import Foundation
import Testing

@testable import OpenLolaCore

@Test
func packagingFieldTestFixtureDecodesAndValidates() throws {
    let report = try loadPackagingFieldTestFixture(named: "packaging-field-test-partial")

    try report.validate()

    #expect(report.runMode == .synthetic)
    #expect(report.verdict == .partial)
    #expect(report.package.contents.appBundleIncluded)
    #expect(report.signing.hardenedRuntimeEnabled == false)
}

@Test
func packagingFieldTestSyntheticSmokeEmitsPartialReport() throws {
    let report = PackagingFieldTestSyntheticSmoke.run()

    try report.validate()

    #expect(report.distributionMethod == .developerID)
    #expect(report.verdict == .partial)
    #expect(report.cleanMac.cleanMacTested == false)
    #expect(report.permissionEntitlementSurface?.networkClientEntitlementKey == "com.apple.security.network.client")
}

@Test
func packagingFieldTestRejectsSyntheticPassFixture() throws {
    let report = try loadPackagingFieldTestFixture(named: "packaging-field-test-synthetic-pass")

    #expect(throws: PackagingFieldTestValidationError.passWithoutMeasuredRun) {
        try report.validate()
    }
}

@Test
func packagingFieldRunConfigurationParsesRequiredArguments() throws {
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
}

@Test
func packagingFieldRunConfigurationRejectsMissingReport() {
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
}

@Test
func packagingFieldQ010PlaceholderFragmentHasInlineContext() throws {
    let source = try String(
        contentsOf: packagingFieldTestRepositoryRoot
            .appendingPathComponent("Sources/OpenLolaCore/Release/PackagingFieldTestValidation.swift"),
        encoding: .utf8
    )

    #expect(source.contains("q010 is the sprint-backlog ticket prefix used in human-operator template fields"))
}

@Test
func packagingFieldTestRejectsPassWithAdHocDistribution() throws {
    var report = try passCandidateReport()
    report.distributionMethod = .adHocLocal

    #expect(throws: PackagingFieldTestValidationError.passWithoutReleaseDistribution(.adHocLocal)) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutDistributionArtifact() throws {
    var report = try passCandidateReport()
    report.package.artifacts.removeAll { $0.kind == .diskImage || $0.kind == .zipArchive }

    #expect(throws: PackagingFieldTestValidationError.passWithoutDistributionArtifact) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutArtifactHash() throws {
    var report = try passCandidateReport()
    report.package.artifacts[0].sha256 = nil

    #expect(throws: PackagingFieldTestValidationError.passWithoutArtifactHash("Open LoLa.app")) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutAppBundle() throws {
    var report = try passCandidateReport()
    report.package.contents.appBundleIncluded = false

    #expect(throws: PackagingFieldTestValidationError.passWithoutAppBundle) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutDeveloperIDSignature() throws {
    var report = try passCandidateReport()
    report.signing.identityType = .adHoc

    #expect(throws: PackagingFieldTestValidationError.passWithoutDeveloperIDSignature(.adHoc)) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithPlaceholderSigningIdentity() throws {
    var report = try passCandidateReport()
    report.signing.signingIdentityLabel = "Q010 signing identity not supplied"

    #expect(throws: PackagingFieldTestValidationError.passWithPlaceholderSigningIdentity) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutHardenedRuntime() throws {
    var report = try passCandidateReport()
    report.signing.hardenedRuntimeEnabled = false

    #expect(throws: PackagingFieldTestValidationError.passWithoutHardenedRuntime) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassUsingAltool() throws {
    var report = try passCandidateReport()
    report.notarization.tool = .altool

    #expect(throws: PackagingFieldTestValidationError.passUsesDeprecatedAltool) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutNotarizationReadiness() throws {
    var report = try passCandidateReport()
    report.notarization.readyForSubmission = false

    #expect(throws: PackagingFieldTestValidationError.passWithoutNotarizationReadiness) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutNotarizationSubmissionId() throws {
    var report = try passCandidateReport()
    report.notarization.submissionIdentifier = nil

    #expect(throws: PackagingFieldTestValidationError.passWithoutNotarizationSubmissionId) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutStapledTicketEvidence() throws {
    var report = try passCandidateReport()
    report.notarization.stapledTicketPath = nil

    #expect(throws: PackagingFieldTestValidationError.passWithoutStapledTicketEvidence) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutGatekeeperAssessmentEvidence() throws {
    var report = try passCandidateReport()
    report.notarization.gatekeeperAssessment = nil

    #expect(throws: PackagingFieldTestValidationError.passWithoutGatekeeperAssessmentEvidence) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutPurposeStrings() throws {
    var report = try passCandidateReport()
    report.entitlements.cameraUsageDescriptionPresent = false

    #expect(throws: PackagingFieldTestValidationError.passWithoutRequiredPurposeStrings) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutPackagedPermissionEntitlementSurface() throws {
    var report = try passCandidateReport()
    report.permissionEntitlementSurface = nil

    #expect(throws: PackagingFieldTestValidationError.passWithoutPackagedPermissionEntitlementSurface) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithPlaceholderPermissionEntitlementSurface() throws {
    var report = try passCandidateReport()
    report.permissionEntitlementSurface?.localNetworkUsageDescription = "TODO(human): required"

    #expect(throws: PackagingFieldTestValidationError.passWithPlaceholderPackagedPermissionEntitlementField(
        "permissionEntitlementSurface.localNetworkUsageDescription"
    )) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutCleanMacTest() throws {
    var report = try passCandidateReport()
    report.cleanMac.cleanMacTested = false

    #expect(throws: PackagingFieldTestValidationError.passWithoutCleanMacTest) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutCleanMacInstallTarget() throws {
    var report = try passCandidateReport()
    report.cleanMac.installTargetLabel = nil

    #expect(throws: PackagingFieldTestValidationError.passWithoutCleanMacInstallTarget) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithPlaceholderCleanMacEvidence() throws {
    var report = try passCandidateReport()
    report.cleanMac.installTargetLabel = "Q010 clean Mac target not supplied"

    #expect(throws: PackagingFieldTestValidationError.passWithPlaceholderCleanMacEvidence(
        "cleanMac.installTargetLabel"
    )) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutCleanMacHashVerification() throws {
    var report = try passCandidateReport()
    report.cleanMac.packageHashVerified = false

    #expect(throws: PackagingFieldTestValidationError.passWithoutCleanMacHashVerification) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutLaunch() throws {
    var report = try passCandidateReport()
    report.cleanMac.appLaunchSucceeded = false

    #expect(throws: PackagingFieldTestValidationError.passWithoutCleanMacLaunch) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsPassWithoutVerdictLine() throws {
    var report = try passCandidateReport()
    report.fieldReport.verdictLineRecorded = false

    #expect(throws: PackagingFieldTestValidationError.passWithoutFieldVerdictLine) {
        try report.validate()
    }
}

@Test
func packagingFieldTestJSONRoundTripPreservesReport() throws {
    let report = try loadPackagingFieldTestFixture(named: "packaging-field-test-partial")
    let jsonData = try report.prettyJSONData()
    let decoded = try PackagingFieldTestReport.decode(from: jsonData)

    #expect(decoded == report)
}

@Test
func packagingFieldTestRejectsMissingSigningFixture() throws {
    let report = try loadPackagingFieldTestFixture(named: "packaging-field-test-missing-signing")

    #expect(throws: PackagingFieldTestValidationError.passWithoutSignedPackage) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsMissingNotarizationFixture() throws {
    let report = try loadPackagingFieldTestFixture(named: "packaging-field-test-missing-notarization")

    #expect(throws: PackagingFieldTestValidationError.passWithoutAcceptedNotarization) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsMissingGatekeeperFixture() throws {
    let report = try loadPackagingFieldTestFixture(named: "packaging-field-test-missing-gatekeeper")

    #expect(throws: PackagingFieldTestValidationError.passWithoutGatekeeperAcceptance) {
        try report.validate()
    }
}

@Test
func packagingFieldTestRejectsMissingCleanMacFixture() throws {
    var report = try loadPackagingFieldTestFixture(named: "packaging-field-test-missing-clean-mac")
    report.permissionEntitlementSurface = validPackagedPermissionSurface()

    #expect(throws: PackagingFieldTestValidationError.passWithoutCleanMacTest) {
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
