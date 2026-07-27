// Shared packaging field test tests helpers keep related tests deterministic and focused on their contract.
import Foundation
import Testing

@testable import OpenLolaCore

func expectPackagingFieldError(
    _ expected: PackagingFieldTestValidationError,
    mutate: (inout PackagingFieldTestReport) throws -> Void
) throws {
    var report = try packagingFieldTestPassCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

func expectPackagingFieldFixtureError(
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

func packagingFieldTestPassCandidateReport() throws -> PackagingFieldTestReport {
    var report = try loadPackagingFieldTestFixture(named: "packaging-field-test-partial")
    report.verdict = .pass
    report.runMode = .measured
    applyPassingPackageArtifacts(to: &report)
    applyPassingSigningEvidence(to: &report)
    applyPassingNotarizationEvidence(to: &report)
    applyPassingPermissionSurface(to: &report)
    applyPassingCleanMacEvidence(to: &report)
    applyPassingFieldReportEvidence(to: &report)
    return report
}

func applyPassingPackageArtifacts(to report: inout PackagingFieldTestReport) {
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
}

func applyPassingSigningEvidence(to report: inout PackagingFieldTestReport) {
    report.signing.signed = true
    report.signing.signatureValid = true
    report.signing.identityType = .developerIDApplication
    report.signing.signingIdentityLabel = "Developer ID Application: Open LoLa Test Team (TEAMID1234)"
    report.signing.hardenedRuntimeEnabled = true
    report.signing.secureTimestampPresent = true
}

func applyPassingNotarizationEvidence(to report: inout PackagingFieldTestReport) {
    report.notarization.readyForSubmission = true
    report.notarization.submitted = true
    report.notarization.accepted = true
    report.notarization.ticketStapled = true
    report.notarization.gatekeeperAccepted = true
    report.notarization.submissionIdentifier = "notary-submission-2026-05-04"
    report.notarization.stapledTicketPath = "OpenLoLa-0.1.0.dmg/.stapled-ticket"
    report.notarization.gatekeeperAssessment = "spctl accepted OpenLoLa-0.1.0.dmg"
}

func applyPassingPermissionSurface(to report: inout PackagingFieldTestReport) {
    let permissionSurface = validPackagedPermissionSurface()
    report.permissionEntitlementSurface = MacPackagedPermissionEntitlementSurface(
        infoPlistRelativePath: permissionSurface.infoPlistRelativePath,
        entitlementsRelativePath: permissionSurface.entitlementsRelativePath,
        microphoneUsageDescription: permissionSurface.microphoneUsageDescription,
        cameraUsageDescription: permissionSurface.cameraUsageDescription,
        localNetworkUsageDescription: permissionSurface.localNetworkUsageDescription,
        networkClientEntitlementKey: permissionSurface.networkClientEntitlementKey,
        appSandboxDecision: permissionSurface.appSandboxDecision
    )
}

func applyPassingCleanMacEvidence(to report: inout PackagingFieldTestReport) {
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
}

func applyPassingFieldReportEvidence(to report: inout PackagingFieldTestReport) {
    report.fieldReport.endpointEvidenceIncluded = true
    report.fieldReport.networkEvidenceIncluded = true
    report.fieldReport.audioEvidenceIncluded = true
    report.fieldReport.videoEvidenceIncluded = true
    report.fieldReport.controlEvidenceIncluded = true
    report.fieldReport.recordingEvidenceIncluded = true
}

func validPackagedPermissionSurface() -> MacPackagedPermissionEntitlementSurface {
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

let fixtureSHA256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

func loadPackagingFieldTestFixture(named name: String) throws -> PackagingFieldTestReport {
    let url = try packagingFieldTestFixtureURL(named: name)
    return try PackagingFieldTestReport.decode(from: Data(contentsOf: url))
}

func packagingFieldTestFixtureURL(named name: String) throws -> URL {
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

var packagingFieldTestRepositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
