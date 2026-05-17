import Foundation

public typealias PackagingFieldTestRunMode = MeasurementMethodology

public enum MacDistributionMethod: String, Codable, Equatable, Sendable {
    case developerID
    case appStore
    case adHocLocal
    case deferred
}

public enum MacPackageArtifactKind: String, Codable, Equatable, Sendable {
    case appBundle
    case commandLineTool
    case documentation
    case entitlements
    case manifest
    case reportTemplate
    case diskImage
    case zipArchive
}

public enum CodeSigningIdentityType: String, Codable, Equatable, Sendable {
    case developerIDApplication
    case macDistribution
    case appleDevelopment
    case adHoc
    case none
}

public enum NotarizationSubmissionTool: String, Codable, Equatable, Sendable {
    case xcodeOrganizer
    case notarytool
    case notaryAPI
    case altool
    case none
}

public struct MacPackageArtifact: Codable, Equatable, Sendable {
    public var kind: MacPackageArtifactKind
    public var relativePath: String
    public var required: Bool
    public var sha256: String?

    public init(
        kind: MacPackageArtifactKind,
        relativePath: String,
        required: Bool,
        sha256: String? = nil
    ) {
        self.kind = kind
        self.relativePath = relativePath
        self.required = required
        self.sha256 = sha256
    }
}

public struct MacPackageContents: Codable, Equatable, Sendable {
    public var appBundleIncluded: Bool
    public var cliToolsIncluded: [String]
    public var documentationIncluded: Bool
    public var reportTemplatesIncluded: Bool

    public init(
        appBundleIncluded: Bool,
        cliToolsIncluded: [String],
        documentationIncluded: Bool,
        reportTemplatesIncluded: Bool
    ) {
        self.appBundleIncluded = appBundleIncluded
        self.cliToolsIncluded = cliToolsIncluded
        self.documentationIncluded = documentationIncluded
        self.reportTemplatesIncluded = reportTemplatesIncluded
    }
}

public struct MacPackageIdentity: Codable, Equatable, Sendable {
    public var productName: String
    public var bundleIdentifier: String
    public var version: String
    public var minimumMacOSVersion: String
    public var contents: MacPackageContents
    public var artifacts: [MacPackageArtifact]

    public init(
        productName: String,
        bundleIdentifier: String,
        version: String,
        minimumMacOSVersion: String,
        contents: MacPackageContents,
        artifacts: [MacPackageArtifact]
    ) {
        self.productName = productName
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.minimumMacOSVersion = minimumMacOSVersion
        self.contents = contents
        self.artifacts = artifacts
    }
}

public struct MacSigningReadiness: Codable, Equatable, Sendable {
    public var signed: Bool
    public var signatureValid: Bool
    public var identityType: CodeSigningIdentityType
    public var signingIdentityLabel: String
    public var hardenedRuntimeEnabled: Bool
    public var secureTimestampPresent: Bool

    public init(
        signed: Bool,
        signatureValid: Bool,
        identityType: CodeSigningIdentityType,
        signingIdentityLabel: String,
        hardenedRuntimeEnabled: Bool,
        secureTimestampPresent: Bool
    ) {
        self.signed = signed
        self.signatureValid = signatureValid
        self.identityType = identityType
        self.signingIdentityLabel = signingIdentityLabel
        self.hardenedRuntimeEnabled = hardenedRuntimeEnabled
        self.secureTimestampPresent = secureTimestampPresent
    }
}

public struct MacNotarizationReadiness: Codable, Equatable, Sendable {
    public var tool: NotarizationSubmissionTool
    public var readyForSubmission: Bool
    public var submitted: Bool
    public var accepted: Bool
    public var ticketStapled: Bool
    public var gatekeeperAccepted: Bool
    public var submissionIdentifier: String?
    public var stapledTicketPath: String?
    public var gatekeeperAssessment: String?

    public init(
        tool: NotarizationSubmissionTool,
        readyForSubmission: Bool,
        submitted: Bool,
        accepted: Bool,
        ticketStapled: Bool,
        gatekeeperAccepted: Bool,
        submissionIdentifier: String? = nil,
        stapledTicketPath: String? = nil,
        gatekeeperAssessment: String? = nil
    ) {
        self.tool = tool
        self.readyForSubmission = readyForSubmission
        self.submitted = submitted
        self.accepted = accepted
        self.ticketStapled = ticketStapled
        self.gatekeeperAccepted = gatekeeperAccepted
        self.submissionIdentifier = submissionIdentifier
        self.stapledTicketPath = stapledTicketPath
        self.gatekeeperAssessment = gatekeeperAssessment
    }
}

public struct MacEntitlementReadiness: Codable, Equatable, Sendable {
    public var entitlementsReviewed: Bool
    public var microphoneUsageDescriptionPresent: Bool
    public var cameraUsageDescriptionPresent: Bool
    public var localNetworkUsageDescriptionPresent: Bool
    public var networkClientEntitlementPresent: Bool
    public var appSandboxDecisionRecorded: Bool

    public init(
        entitlementsReviewed: Bool,
        microphoneUsageDescriptionPresent: Bool,
        cameraUsageDescriptionPresent: Bool,
        localNetworkUsageDescriptionPresent: Bool,
        networkClientEntitlementPresent: Bool,
        appSandboxDecisionRecorded: Bool
    ) {
        self.entitlementsReviewed = entitlementsReviewed
        self.microphoneUsageDescriptionPresent = microphoneUsageDescriptionPresent
        self.cameraUsageDescriptionPresent = cameraUsageDescriptionPresent
        self.localNetworkUsageDescriptionPresent = localNetworkUsageDescriptionPresent
        self.networkClientEntitlementPresent = networkClientEntitlementPresent
        self.appSandboxDecisionRecorded = appSandboxDecisionRecorded
    }
}

public struct MacPackagedPermissionEntitlementSurface: Codable, Equatable, Sendable {
    public var infoPlistRelativePath: String
    public var entitlementsRelativePath: String
    public var microphoneUsageDescription: String
    public var cameraUsageDescription: String
    public var localNetworkUsageDescription: String
    public var networkClientEntitlementKey: String
    public var appSandboxDecision: String

    public init(
        infoPlistRelativePath: String,
        entitlementsRelativePath: String,
        microphoneUsageDescription: String,
        cameraUsageDescription: String,
        localNetworkUsageDescription: String,
        networkClientEntitlementKey: String,
        appSandboxDecision: String
    ) {
        self.infoPlistRelativePath = infoPlistRelativePath
        self.entitlementsRelativePath = entitlementsRelativePath
        self.microphoneUsageDescription = microphoneUsageDescription
        self.cameraUsageDescription = cameraUsageDescription
        self.localNetworkUsageDescription = localNetworkUsageDescription
        self.networkClientEntitlementKey = networkClientEntitlementKey
        self.appSandboxDecision = appSandboxDecision
    }
}

public struct CleanMacFieldProbe: Codable, Equatable, Sendable {
    public var cleanMacTested: Bool
    public var installTargetLabel: String?
    public var installedBundlePath: String?
    public var installedArtifactSHA256: String?
    public var packageHashVerified: Bool?
    public var hardwareIdentifier: String
    public var osVersion: String
    public var architecture: String
    public var appLaunchSucceeded: Bool
    public var cliSmokeSucceeded: Bool
    public var permissionsPrompted: Bool
    public var audioDeviceAccessConfirmed: Bool
    public var cameraAccessConfirmed: Bool
    public var networkAccessConfirmed: Bool
    public var reportWriteSucceeded: Bool

    public init(
        cleanMacTested: Bool,
        installTargetLabel: String? = nil,
        installedBundlePath: String? = nil,
        installedArtifactSHA256: String? = nil,
        packageHashVerified: Bool? = nil,
        hardwareIdentifier: String,
        osVersion: String,
        architecture: String,
        appLaunchSucceeded: Bool,
        cliSmokeSucceeded: Bool,
        permissionsPrompted: Bool,
        audioDeviceAccessConfirmed: Bool,
        cameraAccessConfirmed: Bool,
        networkAccessConfirmed: Bool,
        reportWriteSucceeded: Bool
    ) {
        self.cleanMacTested = cleanMacTested
        self.installTargetLabel = installTargetLabel
        self.installedBundlePath = installedBundlePath
        self.installedArtifactSHA256 = installedArtifactSHA256
        self.packageHashVerified = packageHashVerified
        self.hardwareIdentifier = hardwareIdentifier
        self.osVersion = osVersion
        self.architecture = architecture
        self.appLaunchSucceeded = appLaunchSucceeded
        self.cliSmokeSucceeded = cliSmokeSucceeded
        self.permissionsPrompted = permissionsPrompted
        self.audioDeviceAccessConfirmed = audioDeviceAccessConfirmed
        self.cameraAccessConfirmed = cameraAccessConfirmed
        self.networkAccessConfirmed = networkAccessConfirmed
        self.reportWriteSucceeded = reportWriteSucceeded
    }
}

public struct FieldReportCoverage: Codable, Equatable, Sendable {
    public var endpointEvidenceIncluded: Bool
    public var networkEvidenceIncluded: Bool
    public var audioEvidenceIncluded: Bool
    public var videoEvidenceIncluded: Bool
    public var controlEvidenceIncluded: Bool
    public var recordingEvidenceIncluded: Bool
    public var packagingEvidenceIncluded: Bool
    public var fallbackRouteDecisionRecorded: Bool
    public var deferredArtisticIntegrationsRecorded: Bool
    public var verdictLineRecorded: Bool

    public init(
        endpointEvidenceIncluded: Bool,
        networkEvidenceIncluded: Bool,
        audioEvidenceIncluded: Bool,
        videoEvidenceIncluded: Bool,
        controlEvidenceIncluded: Bool,
        recordingEvidenceIncluded: Bool,
        packagingEvidenceIncluded: Bool,
        fallbackRouteDecisionRecorded: Bool,
        deferredArtisticIntegrationsRecorded: Bool,
        verdictLineRecorded: Bool
    ) {
        self.endpointEvidenceIncluded = endpointEvidenceIncluded
        self.networkEvidenceIncluded = networkEvidenceIncluded
        self.audioEvidenceIncluded = audioEvidenceIncluded
        self.videoEvidenceIncluded = videoEvidenceIncluded
        self.controlEvidenceIncluded = controlEvidenceIncluded
        self.recordingEvidenceIncluded = recordingEvidenceIncluded
        self.packagingEvidenceIncluded = packagingEvidenceIncluded
        self.fallbackRouteDecisionRecorded = fallbackRouteDecisionRecorded
        self.deferredArtisticIntegrationsRecorded = deferredArtisticIntegrationsRecorded
        self.verdictLineRecorded = verdictLineRecorded
    }
}

public enum PackagingFieldTestValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError,
    ValidationMalformedFieldError {
    case emptyField(String)
    case emptyList(String)
    case malformedField(String)
    case passWithoutMeasuredRun
    case passWithoutReleaseDistribution(MacDistributionMethod)
    case passWithoutAppBundle
    case passWithoutRequiredCLI(String)
    case passWithoutDocumentation
    case passWithoutReportTemplates
    case passWithoutDistributionArtifact
    case passWithoutArtifactHash(String)
    case passWithoutSignedPackage
    case passWithoutValidSignature
    case passWithoutDeveloperIDSignature(CodeSigningIdentityType)
    case passWithPlaceholderSigningIdentity
    case passWithoutHardenedRuntime
    case passWithoutSecureTimestamp
    case passUsesDeprecatedAltool
    case passWithoutNotarizationReadiness
    case passWithoutAcceptedNotarization
    case passWithoutNotarizationSubmissionId
    case passWithoutStapledTicket
    case passWithoutStapledTicketEvidence
    case passWithoutGatekeeperAcceptance
    case passWithoutGatekeeperAssessmentEvidence
    case passWithoutEntitlementReview
    case passWithoutRequiredPurposeStrings
    case passWithoutPackagedPermissionEntitlementSurface
    case passWithPlaceholderPackagedPermissionEntitlementField(String)
    case passWithoutCleanMacTest
    case passWithoutCleanMacInstallTarget
    case passWithPlaceholderCleanMacEvidence(String)
    case passWithoutCleanMacHashVerification
    case passWithoutCleanMacLaunch
    case passWithoutCLISmoke
    case passWithoutPermissionPromptRecord
    case passWithoutMediaPermissions
    case passWithoutNetworkAccess
    case passWithoutReportWrite
    case passWithoutFieldEvidence(String)
    case passWithoutFieldVerdictLine
}

public struct PackagingFieldTestReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: PackagingFieldTestRunMode
    public var distributionMethod: MacDistributionMethod
    public var package: MacPackageIdentity
    public var signing: MacSigningReadiness
    public var notarization: MacNotarizationReadiness
    public var entitlements: MacEntitlementReadiness
    public var permissionEntitlementSurface: MacPackagedPermissionEntitlementSurface?
    public var cleanMac: CleanMacFieldProbe
    public var fieldReport: FieldReportCoverage
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: PackagingFieldTestRunMode,
        distributionMethod: MacDistributionMethod,
        package: MacPackageIdentity,
        signing: MacSigningReadiness,
        notarization: MacNotarizationReadiness,
        entitlements: MacEntitlementReadiness,
        permissionEntitlementSurface: MacPackagedPermissionEntitlementSurface? = nil,
        cleanMac: CleanMacFieldProbe,
        fieldReport: FieldReportCoverage,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.distributionMethod = distributionMethod
        self.package = package
        self.signing = signing
        self.notarization = notarization
        self.entitlements = entitlements
        self.permissionEntitlementSurface = permissionEntitlementSurface
        self.cleanMac = cleanMac
        self.fieldReport = fieldReport
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> PackagingFieldTestReport {
        try JSONDecoder().decode(PackagingFieldTestReport.self, from: data)
    }
}
