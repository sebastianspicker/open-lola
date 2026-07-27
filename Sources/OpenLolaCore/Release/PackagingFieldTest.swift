// Models package contents, signing, notarization, entitlements, and permissions so distribution readiness is evaluated as one bundle-level gate.
import Foundation

/// Identifies the measurement methodology recorded with packaging field test artifacts so consumers distinguish measured, synthetic, and sandbox-limited results.
public typealias PackagingFieldTestRunMode = MeasurementMethodology

/// Defines the finite structured result values recorded by packaging field test artifacts for deterministic validation and report interpretation.
public enum MacDistributionMethod: String, Codable, Equatable, Sendable {
    case developerID
    case appStore
    case adHocLocal
    case deferred
}

/// Defines the finite classification values recorded by packaging field test artifacts for deterministic validation and report interpretation.
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

/// Defines the finite hardware and endpoint identity values recorded by packaging field test artifacts for deterministic validation and report interpretation.
public enum CodeSigningIdentityType: String, Codable, Equatable, Sendable {
    case developerIDApplication
    case macDistribution
    case appleDevelopment
    case adHoc
    case none
}

/// Defines the finite structured result values recorded by packaging field test artifacts for deterministic validation and report interpretation.
public enum NotarizationSubmissionTool: String, Codable, Equatable, Sendable {
    case xcodeOrganizer
    case notarytool
    case notaryAPI
    case altool
    case none
}

/// Captures artifact metadata required to validate, interpret, and reproduce a packaging field test result.
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

/// Captures structured result required to validate, interpret, and reproduce a packaging field test result.
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

/// Captures hardware and endpoint identity required to validate, interpret, and reproduce a packaging field test result.
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

/// Captures structured result required to validate, interpret, and reproduce a packaging field test result.
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

/// Captures structured result required to validate, interpret, and reproduce a packaging field test result.
public struct MacNotarizationReadiness: Codable, Equatable, Sendable {
    public struct Submission: Codable, Equatable, Sendable {
        public var tool: NotarizationSubmissionTool
        public var readyForSubmission: Bool
        public var submitted: Bool
        public var accepted: Bool
        public var submissionIdentifier: String?

        public init(
            tool: NotarizationSubmissionTool,
            readyForSubmission: Bool,
            submitted: Bool,
            accepted: Bool,
            submissionIdentifier: String? = nil
        ) {
            self.tool = tool
            self.readyForSubmission = readyForSubmission
            self.submitted = submitted
            self.accepted = accepted
            self.submissionIdentifier = submissionIdentifier
        }
    }

    public struct Ticket: Codable, Equatable, Sendable {
        public var ticketStapled: Bool
        public var stapledTicketPath: String?

        public init(
            ticketStapled: Bool,
            stapledTicketPath: String? = nil
        ) {
            self.ticketStapled = ticketStapled
            self.stapledTicketPath = stapledTicketPath
        }
    }

    public struct Gatekeeper: Codable, Equatable, Sendable {
        public var gatekeeperAccepted: Bool
        public var gatekeeperAssessment: String?

        public init(
            gatekeeperAccepted: Bool,
            gatekeeperAssessment: String? = nil
        ) {
            self.gatekeeperAccepted = gatekeeperAccepted
            self.gatekeeperAssessment = gatekeeperAssessment
        }
    }

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
        submission: Submission,
        ticket: Ticket,
        gatekeeper: Gatekeeper
    ) {
        self.tool = submission.tool
        self.readyForSubmission = submission.readyForSubmission
        self.submitted = submission.submitted
        self.accepted = submission.accepted
        self.ticketStapled = ticket.ticketStapled
        self.gatekeeperAccepted = gatekeeper.gatekeeperAccepted
        self.submissionIdentifier = submission.submissionIdentifier
        self.stapledTicketPath = ticket.stapledTicketPath
        self.gatekeeperAssessment = gatekeeper.gatekeeperAssessment
    }
}

/// Captures structured result required to validate, interpret, and reproduce a packaging field test result.
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

/// Captures structured result required to validate, interpret, and reproduce a packaging field test result.
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

/// Captures report contents required to validate, interpret, and reproduce a packaging field test result.
public struct PackagingFieldTestReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public struct Metadata: Codable, Equatable, Sendable {
        public var id: String
        public var title: String
        public var capturedAt: String
        public var runMode: PackagingFieldTestRunMode
        public var distributionMethod: MacDistributionMethod

        public init(
            id: String,
            title: String,
            capturedAt: String,
            runMode: PackagingFieldTestRunMode,
            distributionMethod: MacDistributionMethod
        ) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.runMode = runMode
            self.distributionMethod = distributionMethod
        }
    }

    public struct PackageEvidence: Codable, Equatable, Sendable {
        public var package: MacPackageIdentity
        public var signing: MacSigningReadiness
        public var notarization: MacNotarizationReadiness
        public var entitlements: MacEntitlementReadiness
        public var permissionEntitlementSurface: MacPackagedPermissionEntitlementSurface?

        public init(
            package: MacPackageIdentity,
            signing: MacSigningReadiness,
            notarization: MacNotarizationReadiness,
            entitlements: MacEntitlementReadiness,
            permissionEntitlementSurface: MacPackagedPermissionEntitlementSurface? = nil
        ) {
            self.package = package
            self.signing = signing
            self.notarization = notarization
            self.entitlements = entitlements
            self.permissionEntitlementSurface = permissionEntitlementSurface
        }
    }

    public struct FieldEvidence: Codable, Equatable, Sendable {
        public var cleanMac: CleanMacFieldProbe
        public var fieldReport: FieldReportCoverage

        public init(
            cleanMac: CleanMacFieldProbe,
            fieldReport: FieldReportCoverage
        ) {
            self.cleanMac = cleanMac
            self.fieldReport = fieldReport
        }
    }

    public enum ResultDomain {}
    public typealias Result = MutableReportOutcome<ResultDomain>

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
        metadata: Metadata,
        packageEvidence: PackageEvidence,
        fieldEvidence: FieldEvidence,
        result: Result
    ) {
        self.id = metadata.id
        self.title = metadata.title
        self.capturedAt = metadata.capturedAt
        self.runMode = metadata.runMode
        self.distributionMethod = metadata.distributionMethod
        self.package = packageEvidence.package
        self.signing = packageEvidence.signing
        self.notarization = packageEvidence.notarization
        self.entitlements = packageEvidence.entitlements
        self.permissionEntitlementSurface = packageEvidence.permissionEntitlementSurface
        self.cleanMac = fieldEvidence.cleanMac
        self.fieldReport = fieldEvidence.fieldReport
        self.verdict = result.verdict
        self.notes = result.notes
    }

    public static func decode(from data: Data) throws -> PackagingFieldTestReport {
        try JSONDecoder().decode(PackagingFieldTestReport.self, from: data)
    }
}
