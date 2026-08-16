// Verifies that packaging field test rejects invalid pass fixtures.
import Foundation
import Darwin
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
    #expect(configuration.appBundlePath == "dist/OpenLoLa.app")
    #expect(configuration.outputDirectory == "reports/m15-package")
    #expect(configuration.reportPath == "reports/m15-packaging-field.json")

    let legacyConfiguration = try JSONDecoder().decode(
        PackagingFieldRunConfiguration.self,
        from: Data("""
        {"integratedReportPath":"integrated","appReportPath":"app","recordingReportPath":"recording","outputDirectory":"output","reportPath":"report"}
        """.utf8)
    )
    #expect(legacyConfiguration.appBundlePath == "dist/OpenLoLa.app")

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
    let appBundle = try writeStagedOpenLoLaAppFixture(in: outputDirectory)
    let runtimeReports = try packagingFieldPartialRuntimeReports(outputDirectory: outputDirectory)

    let report = try PackagingFieldRunner.run(
        configuration: packagingFieldRunConfiguration(outputDirectory: outputDirectory, appBundle: appBundle),
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

private func packagingFieldRunConfiguration(
    outputDirectory: URL,
    appBundle: URL
) -> PackagingFieldRunConfiguration {
    PackagingFieldRunConfiguration(
        integratedReportPath: "reports/m10-integrated-av.json",
        appReportPath: "reports/m13-native-app-runtime-smoke.json",
        recordingReportPath: "reports/m14-recording-session.json",
        appBundlePath: appBundle.path,
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
    #expect(report.signing.identityType == .adHoc)
    #expect(report.signing.signed)
    #expect(report.signing.signatureValid)
    #expect(!report.signing.hardenedRuntimeEnabled)
    #expect(!report.signing.secureTimestampPresent)
    #expect(!report.package.contents.documentationIncluded)
    #expect(!report.package.contents.reportTemplatesIncluded)
    #expect(report.package.productName == "Open LoLa")
    #expect(report.package.bundleIdentifier == "de.hfmt.open-lola.app")
    #expect(report.package.version == "0.1.0")
    #expect(report.package.minimumMacOSVersion == "14.0")
    #expect(report.notarization.tool == .none)
    let surface = try #require(report.permissionEntitlementSurface)
    #expect(surface.cameraUsageDescription.contains("explicit Mac-to-Mac video transport tests"))
    #expect(surface.localNetworkUsageDescription.contains("explicitly configured Mac peers"))
    #expect(surface.microphoneUsageDescription.contains("explicit low-latency Mac-to-Mac audio tests"))
    #expect(!report.entitlements.entitlementsReviewed)
    #expect(report.entitlements.networkClientEntitlementPresent)
    #expect(!report.entitlements.appSandboxDecisionRecorded)
    #expect(!report.fieldReport.endpointEvidenceIncluded)
    #expect(!report.fieldReport.networkEvidenceIncluded)
    #expect(!report.fieldReport.audioEvidenceIncluded)
    #expect(!report.fieldReport.videoEvidenceIncluded)
    #expect(!report.fieldReport.controlEvidenceIncluded)
    #expect(!report.fieldReport.recordingEvidenceIncluded)
    #expect(!report.fieldReport.packagingEvidenceIncluded)
    #expect(!report.fieldReport.fallbackRouteDecisionRecorded)
    #expect(!report.fieldReport.deferredArtisticIntegrationsRecorded)
    #expect(!report.fieldReport.verdictLineRecorded)
    #expect(report.cleanMac.cleanMacTested == false)
    #expect(!report.cleanMac.cliSmokeSucceeded)
    #expect(!report.cleanMac.networkAccessConfirmed)
    #expect(!report.cleanMac.reportWriteSucceeded)
    #expect(!report.notes.contains("PASS validation blocked"))

    #expect(report.package.artifacts.contains { artifact in
        artifact.relativePath == "OpenLoLa.app/Contents/MacOS/OpenLoLa"
            && artifact.sha256 != nil
    })
    #expect(report.package.artifacts.contains { artifact in
        artifact.relativePath == "OpenLoLa.app/Contents/MacOS/open-lola"
            && artifact.sha256 != nil
    })
}

@Test
func packagingFieldRunnerKeepsAdHocPackagePartialWithPassingRuntimeReports() throws {
    let outputDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-packaging-field-pass-guard-\(UUID().uuidString)", isDirectory: true)
    let appBundle = try writeStagedOpenLoLaAppFixture(in: outputDirectory)
    let configuration = PackagingFieldRunConfiguration(
        integratedReportPath: "reports/m10-integrated-av-pass.json",
        appReportPath: "reports/m13-native-app-runtime-smoke-pass.json",
        recordingReportPath: "reports/m14-recording-session-pass.json",
        appBundlePath: appBundle.path,
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
func packagingFieldRunnerRejectsMissingStagedBundleInsteadOfMaterializingPlaceholderArtifacts() throws {
    let outputDirectory = packagingFieldTemporaryOutputDirectory()
    let runtimeReports = try packagingFieldPartialRuntimeReports(outputDirectory: outputDirectory)
    let missingBundle = outputDirectory.appendingPathComponent("missing/OpenLoLa.app")
    let configuration = packagingFieldRunConfiguration(outputDirectory: outputDirectory, appBundle: missingBundle)

    #expect(throws: PackagingFieldArtifactInspectionError.missingStagedAppBundle(missingBundle.path)) {
        _ = try PackagingFieldRunner.run(
            configuration: configuration,
            integratedReport: runtimeReports.integratedReport,
            appShellReport: runtimeReports.appReport,
            recordingReport: runtimeReports.recordingReport,
            codeSigningInspection: fixtureAdHocCodeSigningInspection()
        )
    }
}

@Test
func packagingFieldRunnerRejectsMismatchedStagedBundleMetadata() throws {
    let outputDirectory = packagingFieldTemporaryOutputDirectory()
    let appBundle = try writeStagedOpenLoLaAppFixture(in: outputDirectory)
    let infoPlist = appBundle.appendingPathComponent("Contents/Info.plist")
    try Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <plist version="1.0"><dict>
      <key>CFBundleExecutable</key><string>WrongExecutable</string>
      <key>CFBundleIdentifier</key><string>de.hfmt.open-lola.app</string>
      <key>CFBundleName</key><string>Open LoLa</string>
      <key>CFBundleShortVersionString</key><string>0.1.0</string>
      <key>LSMinimumSystemVersion</key><string>14.0</string>
      <key>NSCameraUsageDescription</key><string>camera</string>
      <key>NSLocalNetworkUsageDescription</key><string>network</string>
      <key>NSMicrophoneUsageDescription</key><string>microphone</string>
    </dict></plist>
    """.utf8).write(to: infoPlist)
    let runtimeReports = try packagingFieldPartialRuntimeReports(outputDirectory: outputDirectory)

    #expect(throws: PackagingFieldArtifactInspectionError.unexpectedPlistValue(
        key: "CFBundleExecutable",
        expected: "OpenLoLa",
        actual: "WrongExecutable"
    )) {
        _ = try PackagingFieldRunner.run(
            configuration: packagingFieldRunConfiguration(outputDirectory: outputDirectory, appBundle: appBundle),
            integratedReport: runtimeReports.integratedReport,
            appShellReport: runtimeReports.appReport,
            recordingReport: runtimeReports.recordingReport,
            codeSigningInspection: fixtureAdHocCodeSigningInspection()
        )
    }
}

@Test
func packagingFieldRunnerRejectsMissingNetworkClientEntitlement() throws {
    let outputDirectory = packagingFieldTemporaryOutputDirectory()
    let appBundle = try writeStagedOpenLoLaAppFixture(in: outputDirectory)
    try Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <plist version="1.0"><dict>
      <key>com.apple.security.network.server</key><true/>
    </dict></plist>
    """.utf8).write(
        to: appBundle.appendingPathComponent("Contents/Resources/open-lola-app.entitlements")
    )
    let runtimeReports = try packagingFieldPartialRuntimeReports(outputDirectory: outputDirectory)

    #expect(throws: PackagingFieldArtifactInspectionError.missingEnabledEntitlement(
        "com.apple.security.network.client"
    )) {
        _ = try PackagingFieldRunner.run(
            configuration: packagingFieldRunConfiguration(outputDirectory: outputDirectory, appBundle: appBundle),
            integratedReport: runtimeReports.integratedReport,
            appShellReport: runtimeReports.appReport,
            recordingReport: runtimeReports.recordingReport,
            codeSigningInspection: fixtureAdHocCodeSigningInspection()
        )
    }
}

@Test
func packagingFieldRunnerRejectsBundleWhoseEmbeddedEntitlementsDoNotMatchItsResource() throws {
    let outputDirectory = packagingFieldTemporaryOutputDirectory()
    let appBundle = try writeStagedOpenLoLaAppFixture(
        in: outputDirectory,
        embedsNetworkClientEntitlement: false
    )
    let runtimeReports = try packagingFieldPartialRuntimeReports(outputDirectory: outputDirectory)

    #expect(throws: PackagingFieldArtifactInspectionError.missingEmbeddedEntitlement(
        "com.apple.security.network.client"
    )) {
        _ = try PackagingFieldRunner.run(
            configuration: packagingFieldRunConfiguration(outputDirectory: outputDirectory, appBundle: appBundle),
            integratedReport: runtimeReports.integratedReport,
            appShellReport: runtimeReports.appReport,
            recordingReport: runtimeReports.recordingReport
        )
    }
}

@Test(arguments: ["root-symlink", "intermediate-symlink", "final-symlink", "directory", "fifo", "oversized"])
func packagingFieldRunnerRejectsUnsafeStagedArtifactsBeforeCodeSigning(_ fixture: String) throws {
    let outputDirectory = packagingFieldTemporaryOutputDirectory()
    let appBundle = try writeStagedOpenLoLaAppFixture(in: outputDirectory)
    let outsideFile = outputDirectory.appendingPathComponent("outside")
    try Data("outside".utf8).write(to: outsideFile)

    switch fixture {
    case "root-symlink":
        let linkedBundle = outputDirectory.appendingPathComponent("Linked.app")
        try FileManager.default.createSymbolicLink(atPath: linkedBundle.path, withDestinationPath: appBundle.path)
        try assertPackagingFieldArtifactRejection(
            appBundle: linkedBundle,
            outputDirectory: outputDirectory,
            expected: .unsafeStagedAppBundle(linkedBundle.path)
        )
    case "intermediate-symlink":
        let contents = appBundle.appendingPathComponent("Contents")
        try FileManager.default.removeItem(at: contents)
        try FileManager.default.createSymbolicLink(atPath: contents.path, withDestinationPath: outputDirectory.path)
        try assertPackagingFieldArtifactRejection(
            appBundle: appBundle,
            outputDirectory: outputDirectory,
            expected: .unsafeStagedArtifact("OpenLoLa.app/Contents/Info.plist")
        )
    case "final-symlink":
        let infoPlist = appBundle.appendingPathComponent("Contents/Info.plist")
        try FileManager.default.removeItem(at: infoPlist)
        try FileManager.default.createSymbolicLink(atPath: infoPlist.path, withDestinationPath: outsideFile.path)
        try assertPackagingFieldArtifactRejection(
            appBundle: appBundle,
            outputDirectory: outputDirectory,
            expected: .unsafeStagedArtifact("OpenLoLa.app/Contents/Info.plist")
        )
    case "directory":
        let infoPlist = appBundle.appendingPathComponent("Contents/Info.plist")
        try FileManager.default.removeItem(at: infoPlist)
        try FileManager.default.createDirectory(at: infoPlist, withIntermediateDirectories: false)
        try assertPackagingFieldArtifactRejection(
            appBundle: appBundle,
            outputDirectory: outputDirectory,
            expected: .unsafeStagedArtifact("OpenLoLa.app/Contents/Info.plist")
        )
    case "fifo":
        let infoPlist = appBundle.appendingPathComponent("Contents/Info.plist")
        try FileManager.default.removeItem(at: infoPlist)
        try #require(mkfifo(infoPlist.path, 0o600) == 0)
        try assertPackagingFieldArtifactRejection(
            appBundle: appBundle,
            outputDirectory: outputDirectory,
            expected: .unsafeStagedArtifact("OpenLoLa.app/Contents/Info.plist")
        )
    case "oversized":
        let infoPlist = appBundle.appendingPathComponent("Contents/Info.plist")
        try Data(repeating: 0, count: 1_048_577).write(to: infoPlist)
        try assertPackagingFieldArtifactRejection(
            appBundle: appBundle,
            outputDirectory: outputDirectory,
            expected: .oversizedStagedArtifact("OpenLoLa.app/Contents/Info.plist")
        )
    default:
        Issue.record("unsupported staged-artifact fixture: \(fixture)")
    }
}

@Test
func packagingSubprocessCaptureStopsTrustedLargeOutputAtItsLimit() {
    #expect(throws: PackagingFieldSubprocessError.outputLimitExceeded) {
        _ = try boundedPackagingSubprocessOutput(
            executableURL: URL(fileURLWithPath: "/usr/bin/yes"),
            arguments: ["packaging-output"],
            timeoutSeconds: 2,
            maximumCaptureBytes: 4_096
        )
    }
}

@Test
func packagingSubprocessCaptureTerminatesTrustedHungCommandAtItsDeadline() {
    #expect(throws: PackagingFieldSubprocessError.timedOut) {
        _ = try boundedPackagingSubprocessOutput(
            executableURL: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["10"],
            timeoutSeconds: 0.05,
            maximumCaptureBytes: 4_096
        )
    }
}

private func assertPackagingFieldArtifactRejection(
    appBundle: URL,
    outputDirectory: URL,
    expected: PackagingFieldArtifactInspectionError
) throws {
    let runtimeReports = try packagingFieldPartialRuntimeReports(outputDirectory: outputDirectory)
    var codeSigningReached = false
    #expect(throws: expected) {
        _ = try PackagingFieldRunner.run(
            configuration: packagingFieldRunConfiguration(outputDirectory: outputDirectory, appBundle: appBundle),
            integratedReport: runtimeReports.integratedReport,
            appShellReport: runtimeReports.appReport,
            recordingReport: runtimeReports.recordingReport,
            codeSigningInspector: { _ in
                codeSigningReached = true
                return fixtureAdHocCodeSigningInspection()
            }
        )
    }
    #expect(!codeSigningReached)
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
