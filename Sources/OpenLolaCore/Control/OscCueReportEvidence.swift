// Collects measurement evidence evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
/// Captures OscCuePeerReport evidence in a stable form for validation and serialized reporting.
public struct OscCuePeerReport: Codable, Equatable, Sendable {
    public var kind: OscCuePeerKind
    public var label: String
    public var available: Bool
    public var unavailableReason: String?

    public init(kind: OscCuePeerKind, label: String, available: Bool, unavailableReason: String?) {
        self.kind = kind
        self.label = label
        self.available = available
        self.unavailableReason = unavailableReason
    }
}

/// Captures OscCueTransportEvidence evidence in a stable form for validation and serialized reporting.
public struct OscCueTransportEvidence: Codable, Equatable, Sendable {
    public var protocolName: String
    public var localBindHost: String
    public var peerHost: String
    public var peerPort: Int
    public var liveUdpLoopback: Bool
    public var sentPackets: Int
    public var receivedPackets: Int

    public init(
        protocolName: String,
        localBindHost: String,
        peerHost: String,
        peerPort: Int,
        liveUdpLoopback: Bool,
        sentPackets: Int,
        receivedPackets: Int
    ) {
        self.protocolName = protocolName
        self.localBindHost = localBindHost
        self.peerHost = peerHost
        self.peerPort = peerPort
        self.liveUdpLoopback = liveUdpLoopback
        self.sentPackets = sentPackets
        self.receivedPackets = receivedPackets
    }
}

/// Captures OscCueExternalPeerEvidence evidence in a stable form for validation and serialized reporting.
public struct OscCueExternalPeerEvidence: Codable, Equatable, Sendable {
    public var kind: OscCuePeerKind
    public var host: String
    public var port: Int
    public var available: Bool
    public var unavailableReason: String?

    public init(
        kind: OscCuePeerKind,
        host: String,
        port: Int,
        available: Bool,
        unavailableReason: String?
    ) {
        self.kind = kind
        self.host = host
        self.port = port
        self.available = available
        self.unavailableReason = unavailableReason
    }
}

/// Represents OscCueMessageProfile values used by read-only control integration.
public struct OscCueMessageProfile: Codable, Equatable, Sendable {
    public var address: String
    public var typeTags: String
    public var timestampEncoding: String
    public var cueCount: Int

    public init(address: String, typeTags: String, timestampEncoding: String, cueCount: Int) {
        self.address = address
        self.typeTags = typeTags
        self.timestampEncoding = timestampEncoding
        self.cueCount = cueCount
    }
}

/// Represents OscCueTimingSample values used by read-only control integration.
public struct OscCueTimingSample: Codable, Equatable, Sendable {
    public var cueId: String
    public var senderTimestampNanoseconds: UInt64
    public var receiverTimestampNanoseconds: UInt64
    public var jitterMicroseconds: Double

    public init(
        cueId: String,
        senderTimestampNanoseconds: UInt64,
        receiverTimestampNanoseconds: UInt64,
        jitterMicroseconds: Double
    ) {
        self.cueId = cueId
        self.senderTimestampNanoseconds = senderTimestampNanoseconds
        self.receiverTimestampNanoseconds = receiverTimestampNanoseconds
        self.jitterMicroseconds = jitterMicroseconds
    }
}

/// Compares audio callback and playout metrics before and during OSC cue processing.
public struct OscCueAudioImpactMetrics: Codable, Equatable, Sendable {
    public var baselineCallbackP99Microseconds: Double
    public var cueLoopCallbackP99Microseconds: Double
    public var baselineCallbackMaxMicroseconds: Double
    public var cueLoopCallbackMaxMicroseconds: Double
    public var baselinePlayoutTargetFrames: Int
    public var cueLoopPlayoutTargetFrames: Int
    public var underruns: Int
    public var hiddenAudioImpactDetected: Bool
    public var baselineReportId: String?
    public var synthetic: Bool?

    public init(baseline: OscCueAudioCallbackMetrics, cueLoop: OscCueAudioCallbackMetrics, underruns: Int, hiddenAudioImpactDetected: Bool, baselineReportId: String? = nil, synthetic: Bool? = nil) {
        self.baselineCallbackP99Microseconds = baseline.p99Microseconds
        self.cueLoopCallbackP99Microseconds = cueLoop.p99Microseconds
        self.baselineCallbackMaxMicroseconds = baseline.maxMicroseconds
        self.cueLoopCallbackMaxMicroseconds = cueLoop.maxMicroseconds
        self.baselinePlayoutTargetFrames = baseline.playoutTargetFrames
        self.cueLoopPlayoutTargetFrames = cueLoop.playoutTargetFrames
        self.underruns = underruns
        self.hiddenAudioImpactDetected = hiddenAudioImpactDetected
        self.baselineReportId = baselineReportId
        self.synthetic = synthetic
    }
}
