import Foundation

extension PackagingFieldTestReport {
    public func validate() throws {
        try validateIdentity()
        try validatePackage()
        try validateSigning()
        try validatePermissionEntitlementSurface()
        try validateCleanMac()
        try VerdictValidationPolicy.validatePass(verdict) {
            try validatePassVerdict()
        }
    }

    private func validateIdentity() throws {
        try PackagingFieldValidator.requireNonEmpty(id, "id")
        try PackagingFieldValidator.requireNonEmpty(title, "title")
        try PackagingFieldValidator.requireNonEmpty(capturedAt, "capturedAt")
        try PackagingFieldValidator.requireISO8601Date(capturedAt, "capturedAt")
        try PackagingFieldValidator.requireNonEmpty(notes, "notes")
    }

    private func validatePackage() throws {
        try PackagingFieldValidator.requireNonEmpty(package.productName, "package.productName")
        try PackagingFieldValidator.requireNonEmpty(package.bundleIdentifier, "package.bundleIdentifier")
        try PackagingFieldValidator.requireNonEmpty(package.version, "package.version")
        try PackagingFieldValidator.requireNonEmpty(package.minimumMacOSVersion, "package.minimumMacOSVersion")
        guard !package.contents.cliToolsIncluded.isEmpty else {
            throw PackagingFieldTestValidationError.emptyList("package.contents.cliToolsIncluded")
        }
        guard !package.artifacts.isEmpty else {
            throw PackagingFieldTestValidationError.emptyList("package.artifacts")
        }
        for cliTool in package.contents.cliToolsIncluded {
            try PackagingFieldValidator.requireNonEmpty(cliTool, "package.contents.cliToolsIncluded")
        }
        for artifact in package.artifacts {
            try PackagingFieldValidator.requireNonEmpty(artifact.relativePath, "package.artifacts.relativePath")
            if let sha256 = artifact.sha256 {
                try PackagingFieldValidator.requireNonEmpty(sha256, "package.artifacts.sha256")
            }
        }
    }

    private func validateSigning() throws {
        try PackagingFieldValidator.requireNonEmpty(signing.signingIdentityLabel, "signing.signingIdentityLabel")
    }

    private func validatePermissionEntitlementSurface() throws {
        guard let surface = permissionEntitlementSurface else {
            return
        }
        try PackagingFieldValidator.requireNonEmpty(surface.infoPlistRelativePath, "permissionEntitlementSurface.infoPlistRelativePath")
        try PackagingFieldValidator.requireNonEmpty(surface.entitlementsRelativePath, "permissionEntitlementSurface.entitlementsRelativePath")
        try PackagingFieldValidator.requireNonEmpty(
            surface.microphoneUsageDescription,
            "permissionEntitlementSurface.microphoneUsageDescription"
        )
        try PackagingFieldValidator.requireNonEmpty(
            surface.cameraUsageDescription,
            "permissionEntitlementSurface.cameraUsageDescription"
        )
        try PackagingFieldValidator.requireNonEmpty(
            surface.localNetworkUsageDescription,
            "permissionEntitlementSurface.localNetworkUsageDescription"
        )
        try PackagingFieldValidator.requireNonEmpty(
            surface.networkClientEntitlementKey,
            "permissionEntitlementSurface.networkClientEntitlementKey"
        )
        try PackagingFieldValidator.requireNonEmpty(surface.appSandboxDecision, "permissionEntitlementSurface.appSandboxDecision")
    }

    private func validateCleanMac() throws {
        try PackagingFieldValidator.requireNonEmpty(cleanMac.hardwareIdentifier, "cleanMac.hardwareIdentifier")
        try PackagingFieldValidator.requireNonEmpty(cleanMac.osVersion, "cleanMac.osVersion")
        try PackagingFieldValidator.requireNonEmpty(cleanMac.architecture, "cleanMac.architecture")
    }

    private func validatePassVerdict() throws {
        guard runMode == .measured else {
            throw PackagingFieldTestValidationError.passWithoutMeasuredRun
        }
        guard distributionMethod == .developerID || distributionMethod == .appStore else {
            throw PackagingFieldTestValidationError.passWithoutReleaseDistribution(distributionMethod)
        }
        try validatePassPackage()
        try validatePassSigningAndNotarization()
        try validatePassCleanMac()
        try validatePassEntitlements()
        try validatePassFieldReport()
    }

    private func validatePassPackage() throws {
        try validatePassPackageContents()
        let distributionArtifacts = try passDistributionArtifacts()
        try validatePassPackageArtifactHashes(distributionArtifacts)
    }

    private func validatePassPackageContents() throws {
        guard package.contents.appBundleIncluded else {
            throw PackagingFieldTestValidationError.passWithoutAppBundle
        }
        guard package.contents.cliToolsIncluded.contains("open-lola") else {
            throw PackagingFieldTestValidationError.passWithoutRequiredCLI("open-lola")
        }
        guard package.contents.documentationIncluded else {
            throw PackagingFieldTestValidationError.passWithoutDocumentation
        }
        guard package.contents.reportTemplatesIncluded else {
            throw PackagingFieldTestValidationError.passWithoutReportTemplates
        }
    }

    private func passDistributionArtifacts() throws -> [MacPackageArtifact] {
        let distributionArtifacts = package.artifacts.filter { artifact in
            artifact.kind == .diskImage || artifact.kind == .zipArchive
        }
        guard !distributionArtifacts.isEmpty else {
            throw PackagingFieldTestValidationError.passWithoutDistributionArtifact
        }
        return distributionArtifacts
    }

    private func validatePassPackageArtifactHashes(_ distributionArtifacts: [MacPackageArtifact]) throws {
        for artifact in package.artifacts where artifact.required || distributionArtifacts.contains(artifact) {
            guard packagingHashIsValidSHA256(artifact.sha256) else {
                throw PackagingFieldTestValidationError.passWithoutArtifactHash(artifact.relativePath)
            }
        }
    }

    private func validatePassSigningAndNotarization() throws {
        try validatePassSigningIdentity()
        try validatePassSigningRuntime()
        try validatePassNotarizationSubmission()
        try validatePassStapledTicket()
        try validatePassGatekeeperAssessment()
    }

    private func validatePassSigningIdentity() throws {
        guard signing.signed else {
            throw PackagingFieldTestValidationError.passWithoutSignedPackage
        }
        guard signing.signatureValid else {
            throw PackagingFieldTestValidationError.passWithoutValidSignature
        }
        if distributionMethod == .developerID {
            guard signing.identityType == .developerIDApplication else {
                throw PackagingFieldTestValidationError.passWithoutDeveloperIDSignature(signing.identityType)
            }
        }
        guard !packagingValueIsPlaceholder(signing.signingIdentityLabel) else {
            throw PackagingFieldTestValidationError.passWithPlaceholderSigningIdentity
        }
    }

    private func validatePassSigningRuntime() throws {
        guard signing.hardenedRuntimeEnabled else {
            throw PackagingFieldTestValidationError.passWithoutHardenedRuntime
        }
        guard signing.secureTimestampPresent else {
            throw PackagingFieldTestValidationError.passWithoutSecureTimestamp
        }
    }

    private func validatePassNotarizationSubmission() throws {
        guard notarization.tool != .altool else {
            throw PackagingFieldTestValidationError.passUsesDeprecatedAltool
        }
        guard notarization.readyForSubmission else {
            throw PackagingFieldTestValidationError.passWithoutNotarizationReadiness
        }
        guard notarization.submitted, notarization.accepted else {
            throw PackagingFieldTestValidationError.passWithoutAcceptedNotarization
        }
        guard !packagingValueIsPlaceholder(notarization.submissionIdentifier) else {
            throw PackagingFieldTestValidationError.passWithoutNotarizationSubmissionId
        }
    }

    private func validatePassStapledTicket() throws {
        guard notarization.ticketStapled else {
            throw PackagingFieldTestValidationError.passWithoutStapledTicket
        }
        guard !packagingValueIsPlaceholder(notarization.stapledTicketPath) else {
            throw PackagingFieldTestValidationError.passWithoutStapledTicketEvidence
        }
    }

    private func validatePassGatekeeperAssessment() throws {
        guard notarization.gatekeeperAccepted else {
            throw PackagingFieldTestValidationError.passWithoutGatekeeperAcceptance
        }
        guard !packagingValueIsPlaceholder(notarization.gatekeeperAssessment) else {
            throw PackagingFieldTestValidationError.passWithoutGatekeeperAssessmentEvidence
        }
    }

    private func validatePassEntitlements() throws {
        guard entitlements.entitlementsReviewed, entitlements.appSandboxDecisionRecorded else {
            throw PackagingFieldTestValidationError.passWithoutEntitlementReview
        }
        guard entitlements.microphoneUsageDescriptionPresent,
              entitlements.cameraUsageDescriptionPresent,
              entitlements.localNetworkUsageDescriptionPresent
        else {
            throw PackagingFieldTestValidationError.passWithoutRequiredPurposeStrings
        }
        guard entitlements.networkClientEntitlementPresent else {
            throw PackagingFieldTestValidationError.passWithoutNetworkAccess
        }
        guard let surface = permissionEntitlementSurface else {
            throw PackagingFieldTestValidationError.passWithoutPackagedPermissionEntitlementSurface
        }
        for field in packagedPermissionEntitlementFields(surface) where packagingValueIsPlaceholder(field.value) {
            throw PackagingFieldTestValidationError.passWithPlaceholderPackagedPermissionEntitlementField(field.name)
        }
    }

    private func validatePassCleanMac() throws {
        guard cleanMac.cleanMacTested else {
            throw PackagingFieldTestValidationError.passWithoutCleanMacTest
        }
        try validatePassCleanMacInstallEvidence()
        guard cleanMac.appLaunchSucceeded else {
            throw PackagingFieldTestValidationError.passWithoutCleanMacLaunch
        }
        guard cleanMac.cliSmokeSucceeded else {
            throw PackagingFieldTestValidationError.passWithoutCLISmoke
        }
        guard cleanMac.permissionsPrompted else {
            throw PackagingFieldTestValidationError.passWithoutPermissionPromptRecord
        }
        guard cleanMac.audioDeviceAccessConfirmed, cleanMac.cameraAccessConfirmed else {
            throw PackagingFieldTestValidationError.passWithoutMediaPermissions
        }
        guard cleanMac.networkAccessConfirmed else {
            throw PackagingFieldTestValidationError.passWithoutNetworkAccess
        }
        guard cleanMac.reportWriteSucceeded else {
            throw PackagingFieldTestValidationError.passWithoutReportWrite
        }
    }

    private func validatePassCleanMacInstallEvidence() throws {
        guard let installTargetLabel = cleanMac.installTargetLabel,
              let installedBundlePath = cleanMac.installedBundlePath,
              !installTargetLabel.isEmpty,
              !installedBundlePath.isEmpty else {
            throw PackagingFieldTestValidationError.passWithoutCleanMacInstallTarget
        }
        let installFields = [
            ("cleanMac.installTargetLabel", installTargetLabel),
            ("cleanMac.installedBundlePath", installedBundlePath),
        ]
        for field in installFields where packagingValueIsPlaceholder(field.1) {
            throw PackagingFieldTestValidationError.passWithPlaceholderCleanMacEvidence(field.0)
        }
        guard packagingHashIsValidSHA256(cleanMac.installedArtifactSHA256),
              cleanMac.packageHashVerified == true else {
            throw PackagingFieldTestValidationError.passWithoutCleanMacHashVerification
        }
    }

    private func validatePassFieldReport() throws {
        try validatePassFieldReportEvidenceSections()
        try validatePassFieldReportDeferrals()
        try validatePassFieldReportVerdictLine()
    }

    private func validatePassFieldReportEvidenceSections() throws {
        let requiredEvidence = [
            ("endpoint", fieldReport.endpointEvidenceIncluded),
            ("network", fieldReport.networkEvidenceIncluded),
            ("audio", fieldReport.audioEvidenceIncluded),
            ("video", fieldReport.videoEvidenceIncluded),
            ("control", fieldReport.controlEvidenceIncluded),
            ("recording", fieldReport.recordingEvidenceIncluded),
            ("packaging", fieldReport.packagingEvidenceIncluded),
        ]
        for evidence in requiredEvidence where !evidence.1 {
            throw PackagingFieldTestValidationError.passWithoutFieldEvidence(evidence.0)
        }
    }

    private func validatePassFieldReportDeferrals() throws {
        guard fieldReport.fallbackRouteDecisionRecorded,
              fieldReport.deferredArtisticIntegrationsRecorded
        else {
            throw PackagingFieldTestValidationError.passWithoutFieldEvidence("SOTA deferral")
        }
    }

    private func validatePassFieldReportVerdictLine() throws {
        guard fieldReport.verdictLineRecorded else {
            throw PackagingFieldTestValidationError.passWithoutFieldVerdictLine
        }
    }
}

private func packagedPermissionEntitlementFields(
    _ surface: MacPackagedPermissionEntitlementSurface
) -> [(name: String, value: String)] {
    [
        ("permissionEntitlementSurface.infoPlistRelativePath", surface.infoPlistRelativePath),
        ("permissionEntitlementSurface.entitlementsRelativePath", surface.entitlementsRelativePath),
        ("permissionEntitlementSurface.microphoneUsageDescription", surface.microphoneUsageDescription),
        ("permissionEntitlementSurface.cameraUsageDescription", surface.cameraUsageDescription),
        ("permissionEntitlementSurface.localNetworkUsageDescription", surface.localNetworkUsageDescription),
        ("permissionEntitlementSurface.networkClientEntitlementKey", surface.networkClientEntitlementKey),
        ("permissionEntitlementSurface.appSandboxDecision", surface.appSandboxDecision),
    ]
}

private func packagingHashIsValidSHA256(_ value: String?) -> Bool {
    guard let value, value.count == 64 else {
        return false
    }
    return value.allSatisfy { packagingSHA256Characters.contains($0) }
}

private let packagingSHA256Characters = Set("0123456789abcdefABCDEF")

private func packagingValueIsPlaceholder(_ value: String?) -> Bool {
    PlaceholderDetection.matchesOptional(
        value,
        containing: [
            // q010 is the sprint-backlog ticket prefix used in human-operator template fields.
            "q010",
            "not supplied",
            "synthetic",
            "placeholder",
            "required",
        ]
    )
}
