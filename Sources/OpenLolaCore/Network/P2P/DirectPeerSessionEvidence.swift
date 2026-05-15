public enum DirectPeerSessionMeasuredEvidenceKind: String, Codable, Equatable, Sendable {
    case synthetic
    case localhostLoopback
    case physicalTwoPeerMacs
}

public enum DirectPeerSessionDSCPClassification: String, Codable, Equatable, Sendable {
    case honored
    case rewritten
    case ignored
    case harmful
}

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

public struct DirectPeerSessionMeasuredEvidence: Codable, Equatable, Sendable {
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

    public init(
        kind: DirectPeerSessionMeasuredEvidenceKind,
        sourcePeerLabel: String,
        receiverPeerLabel: String,
        routeLabel: String,
        packetCapturePath: String,
        packetCapture: DirectPeerSessionEvidenceArtifact? = nil,
        dscpObservation: String,
        dscp: DirectPeerSessionDSCPEvidence? = nil,
        clockSyncSummary: String,
        clock: DirectPeerSessionClockEvidence? = nil,
        rawVideoReceiveEvidence: String? = nil,
        durationSeconds: Double
    ) {
        self.kind = kind
        self.sourcePeerLabel = sourcePeerLabel
        self.receiverPeerLabel = receiverPeerLabel
        self.routeLabel = routeLabel
        self.packetCapturePath = packetCapturePath
        self.packetCapture = packetCapture
        self.dscpObservation = dscpObservation
        self.dscp = dscp
        self.clockSyncSummary = clockSyncSummary
        self.clock = clock
        self.rawVideoReceiveEvidence = rawVideoReceiveEvidence
        self.durationSeconds = durationSeconds
    }
}

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
