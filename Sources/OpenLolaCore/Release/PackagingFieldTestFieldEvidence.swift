/// Collects release-readiness evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
public struct CleanMacFieldProbe: Codable, Equatable, Sendable {
    public struct Installation: Codable, Equatable, Sendable {
        public var cleanMacTested: Bool
        public var installTargetLabel: String?
        public var installedBundlePath: String?
        public var installedArtifactSHA256: String?
        public var packageHashVerified: Bool?

        public init(
            cleanMacTested: Bool,
            installTargetLabel: String? = nil,
            installedBundlePath: String? = nil,
            installedArtifactSHA256: String? = nil,
            packageHashVerified: Bool? = nil
        ) {
            self.cleanMacTested = cleanMacTested
            self.installTargetLabel = installTargetLabel
            self.installedBundlePath = installedBundlePath
            self.installedArtifactSHA256 = installedArtifactSHA256
            self.packageHashVerified = packageHashVerified
        }
    }

    public struct Host: Codable, Equatable, Sendable {
        public var hardwareIdentifier: String
        public var osVersion: String
        public var architecture: String

        public init(
            hardwareIdentifier: String,
            osVersion: String,
            architecture: String
        ) {
            self.hardwareIdentifier = hardwareIdentifier
            self.osVersion = osVersion
            self.architecture = architecture
        }
    }

    public struct Smoke: Codable, Equatable, Sendable {
        public var appLaunchSucceeded: Bool
        public var cliSmokeSucceeded: Bool
        public var reportWriteSucceeded: Bool

        public init(
            appLaunchSucceeded: Bool,
            cliSmokeSucceeded: Bool,
            reportWriteSucceeded: Bool
        ) {
            self.appLaunchSucceeded = appLaunchSucceeded
            self.cliSmokeSucceeded = cliSmokeSucceeded
            self.reportWriteSucceeded = reportWriteSucceeded
        }
    }

    public struct Access: Codable, Equatable, Sendable {
        public var permissionsPrompted: Bool
        public var audioDeviceAccessConfirmed: Bool
        public var cameraAccessConfirmed: Bool
        public var networkAccessConfirmed: Bool

        public init(
            permissionsPrompted: Bool,
            audioDeviceAccessConfirmed: Bool,
            cameraAccessConfirmed: Bool,
            networkAccessConfirmed: Bool
        ) {
            self.permissionsPrompted = permissionsPrompted
            self.audioDeviceAccessConfirmed = audioDeviceAccessConfirmed
            self.cameraAccessConfirmed = cameraAccessConfirmed
            self.networkAccessConfirmed = networkAccessConfirmed
        }
    }

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
        installation: Installation,
        host: Host,
        smoke: Smoke,
        access: Access
    ) {
        self.cleanMacTested = installation.cleanMacTested
        self.installTargetLabel = installation.installTargetLabel
        self.installedBundlePath = installation.installedBundlePath
        self.installedArtifactSHA256 = installation.installedArtifactSHA256
        self.packageHashVerified = installation.packageHashVerified
        self.hardwareIdentifier = host.hardwareIdentifier
        self.osVersion = host.osVersion
        self.architecture = host.architecture
        self.appLaunchSucceeded = smoke.appLaunchSucceeded
        self.cliSmokeSucceeded = smoke.cliSmokeSucceeded
        self.permissionsPrompted = access.permissionsPrompted
        self.audioDeviceAccessConfirmed = access.audioDeviceAccessConfirmed
        self.cameraAccessConfirmed = access.cameraAccessConfirmed
        self.networkAccessConfirmed = access.networkAccessConfirmed
        self.reportWriteSucceeded = smoke.reportWriteSucceeded
    }
}

/// Captures report contents required to validate, interpret, and reproduce a packaging field test result.
public struct FieldReportCoverage: Codable, Equatable, Sendable {
    public struct EvidenceSurfaces: Codable, Equatable, Sendable {
        public var endpointEvidenceIncluded: Bool
        public var networkEvidenceIncluded: Bool
        public var audioEvidenceIncluded: Bool
        public var videoEvidenceIncluded: Bool
        public var controlEvidenceIncluded: Bool

        public init(
            endpointEvidenceIncluded: Bool,
            networkEvidenceIncluded: Bool,
            audioEvidenceIncluded: Bool,
            videoEvidenceIncluded: Bool,
            controlEvidenceIncluded: Bool
        ) {
            self.endpointEvidenceIncluded = endpointEvidenceIncluded
            self.networkEvidenceIncluded = networkEvidenceIncluded
            self.audioEvidenceIncluded = audioEvidenceIncluded
            self.videoEvidenceIncluded = videoEvidenceIncluded
            self.controlEvidenceIncluded = controlEvidenceIncluded
        }
    }

    public struct ReleaseEvidence: Codable, Equatable, Sendable {
        public var recordingEvidenceIncluded: Bool
        public var packagingEvidenceIncluded: Bool
        public var fallbackRouteDecisionRecorded: Bool
        public var deferredArtisticIntegrationsRecorded: Bool
        public var verdictLineRecorded: Bool

        public init(
            recordingEvidenceIncluded: Bool,
            packagingEvidenceIncluded: Bool,
            fallbackRouteDecisionRecorded: Bool,
            deferredArtisticIntegrationsRecorded: Bool,
            verdictLineRecorded: Bool
        ) {
            self.recordingEvidenceIncluded = recordingEvidenceIncluded
            self.packagingEvidenceIncluded = packagingEvidenceIncluded
            self.fallbackRouteDecisionRecorded = fallbackRouteDecisionRecorded
            self.deferredArtisticIntegrationsRecorded = deferredArtisticIntegrationsRecorded
            self.verdictLineRecorded = verdictLineRecorded
        }
    }

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
        evidenceSurfaces: EvidenceSurfaces,
        releaseEvidence: ReleaseEvidence
    ) {
        self.endpointEvidenceIncluded = evidenceSurfaces.endpointEvidenceIncluded
        self.networkEvidenceIncluded = evidenceSurfaces.networkEvidenceIncluded
        self.audioEvidenceIncluded = evidenceSurfaces.audioEvidenceIncluded
        self.videoEvidenceIncluded = evidenceSurfaces.videoEvidenceIncluded
        self.controlEvidenceIncluded = evidenceSurfaces.controlEvidenceIncluded
        self.recordingEvidenceIncluded = releaseEvidence.recordingEvidenceIncluded
        self.packagingEvidenceIncluded = releaseEvidence.packagingEvidenceIncluded
        self.fallbackRouteDecisionRecorded = releaseEvidence.fallbackRouteDecisionRecorded
        self.deferredArtisticIntegrationsRecorded =
            releaseEvidence.deferredArtisticIntegrationsRecorded
        self.verdictLineRecorded = releaseEvidence.verdictLineRecorded
    }
}
