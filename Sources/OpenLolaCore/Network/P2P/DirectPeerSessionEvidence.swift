// Collects direct-peer session evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
/// Identifies the measured-evidence source attached to a direct-peer session report.
public enum DirectPeerSessionMeasuredEvidenceKind: String, Codable, Equatable, Sendable {
    case synthetic
    case localhostLoopback
    case physicalTwoPeerMacs
}

/// Classifies observed DSCP marking against the session's requested traffic priority.
public enum DirectPeerSessionDSCPClassification: String, Codable, Equatable, Sendable {
    case honored
    case rewritten
    case ignored
    case harmful
}

/// Captures DirectPeerSessionEvidenceArtifact evidence in a stable form for validation and serialized reporting.
public struct DirectPeerSessionEvidenceArtifact: Codable, Equatable, Sendable {
    public var path: String
    public var captured: Bool
    public var sha256: String?

    public init(path: String, captured: Bool, sha256: String? = nil) {
        self.path = path
        self.captured = captured
        self.sha256 = sha256
    }
}

/// Captures DirectPeerSessionDSCPEvidence evidence in a stable form for validation and serialized reporting.
public struct DirectPeerSessionDSCPEvidence: Codable, Equatable, Sendable {
    public var requested: Int?
    public var observed: Int?
    public var classification: DirectPeerSessionDSCPClassification
    public var capturePoint: String
    public var artifact: DirectPeerSessionEvidenceArtifact

    public init(
        requested: Int?,
        observed: Int?,
        classification: DirectPeerSessionDSCPClassification,
        capturePoint: String,
        artifact: DirectPeerSessionEvidenceArtifact
    ) {
        self.requested = requested
        self.observed = observed
        self.classification = classification
        self.capturePoint = capturePoint
        self.artifact = artifact
    }
}

/// Captures DirectPeerSessionClockEvidence evidence in a stable form for validation and serialized reporting.
public struct DirectPeerSessionClockEvidence: Codable, Equatable, Sendable {
    public var clockSource: String
    public var method: String
    public var maxOffsetMicroseconds: Double
    public var artifact: DirectPeerSessionEvidenceArtifact

    public init(
        clockSource: String,
        method: String,
        maxOffsetMicroseconds: Double,
        artifact: DirectPeerSessionEvidenceArtifact
    ) {
        self.clockSource = clockSource
        self.method = method
        self.maxOffsetMicroseconds = maxOffsetMicroseconds
        self.artifact = artifact
    }
}

/// Captures DirectPeerSessionMeasuredEvidence evidence in a stable form for validation and serialized reporting.
public struct DirectPeerSessionMeasuredEvidence: Codable, Equatable, Sendable {
    public struct Identity: Equatable, Sendable {
        public var kind: DirectPeerSessionMeasuredEvidenceKind
        public var sourcePeerLabel: String
        public var receiverPeerLabel: String
        public var routeLabel: String

        public init(kind: DirectPeerSessionMeasuredEvidenceKind, sourcePeerLabel: String, receiverPeerLabel: String, routeLabel: String) {
            self.kind = kind
            self.sourcePeerLabel = sourcePeerLabel
            self.receiverPeerLabel = receiverPeerLabel
            self.routeLabel = routeLabel
        }
    }

    public struct PacketCapture: Equatable, Sendable {
        public var path: String
        public var artifact: DirectPeerSessionEvidenceArtifact?

        public init(path: String, artifact: DirectPeerSessionEvidenceArtifact? = nil) {
            self.path = path
            self.artifact = artifact
        }
    }

    public struct DSCP: Equatable, Sendable {
        public var observation: String
        public var evidence: DirectPeerSessionDSCPEvidence?

        public init(observation: String, evidence: DirectPeerSessionDSCPEvidence? = nil) {
            self.observation = observation
            self.evidence = evidence
        }
    }

    public struct Clock: Equatable, Sendable {
        public var summary: String
        public var evidence: DirectPeerSessionClockEvidence?

        public init(summary: String, evidence: DirectPeerSessionClockEvidence? = nil) {
            self.summary = summary
            self.evidence = evidence
        }
    }

    public struct Media: Equatable, Sendable {
        public var rawVideoReceiveEvidence: String?
        public var durationSeconds: Double

        public init(rawVideoReceiveEvidence: String? = nil, durationSeconds: Double) {
            self.rawVideoReceiveEvidence = rawVideoReceiveEvidence
            self.durationSeconds = durationSeconds
        }
    }
    public var kind: DirectPeerSessionMeasuredEvidenceKind
    public var sourcePeerLabel: String
    public var receiverPeerLabel: String
    public var routeLabel: String
    public var packetCapturePath: String
    public var packetCapture: DirectPeerSessionEvidenceArtifact?
    public var dscpObservation: String
    public var dscp: DirectPeerSessionDSCPEvidence?
    public var clockSyncSummary: String
    public var clock: DirectPeerSessionClockEvidence?
    public var rawVideoReceiveEvidence: String?
    public var durationSeconds: Double

    public init(identity: Identity, packetCapture: PacketCapture, dscp: DSCP, clock: Clock, media: Media) {
        self.kind = identity.kind
        self.sourcePeerLabel = identity.sourcePeerLabel
        self.receiverPeerLabel = identity.receiverPeerLabel
        self.routeLabel = identity.routeLabel
        self.packetCapturePath = packetCapture.path
        self.packetCapture = packetCapture.artifact
        self.dscpObservation = dscp.observation
        self.dscp = dscp.evidence
        self.clockSyncSummary = clock.summary
        self.clock = clock.evidence
        self.rawVideoReceiveEvidence = media.rawVideoReceiveEvidence
        self.durationSeconds = media.durationSeconds
    }
}

// swiftlint:disable:next type_name
/// Represents DirectPeerSessionFastestAVBaselineComparison values used by direct peer sessions.
public struct DirectPeerSessionFastestAVBaselineComparison: Codable, Equatable, Sendable {
    public var audioOnlyBaselineReportID: String
    public var audioOnlyBaselineReportPath: String
    public var comparisonArtifactPath: String
    public var audioOnlyLatencyP99Microseconds: Double
    public var fastestAVAudioLatencyP99Microseconds: Double
    public var audioLatencyEqualToBaseline: Bool
    public var rxBufferEqualToBaseline: Bool
    public var lossJitterEqualToBaseline: Bool

    public init(
        audioOnlyBaselineReportID: String,
        audioOnlyBaselineReportPath: String,
        comparisonArtifactPath: String,
        audioOnlyLatencyP99Microseconds: Double,
        fastestAVAudioLatencyP99Microseconds: Double,
        audioLatencyEqualToBaseline: Bool,
        rxBufferEqualToBaseline: Bool,
        lossJitterEqualToBaseline: Bool
    ) {
        self.audioOnlyBaselineReportID = audioOnlyBaselineReportID
        self.audioOnlyBaselineReportPath = audioOnlyBaselineReportPath
        self.comparisonArtifactPath = comparisonArtifactPath
        self.audioOnlyLatencyP99Microseconds = audioOnlyLatencyP99Microseconds
        self.fastestAVAudioLatencyP99Microseconds = fastestAVAudioLatencyP99Microseconds
        self.audioLatencyEqualToBaseline = audioLatencyEqualToBaseline
        self.rxBufferEqualToBaseline = rxBufferEqualToBaseline
        self.lossJitterEqualToBaseline = lossJitterEqualToBaseline
    }
}
