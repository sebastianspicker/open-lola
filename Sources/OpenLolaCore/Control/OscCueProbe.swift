// Probes OscCueProbe capability or availability, isolating environment inspection from policy decisions.
import Darwin
import Foundation

/// Identifies the OSC peer role represented by cue-probe evidence.
public enum OscCuePeerKind: String, Codable, Equatable, Sendable {
    case localLoopback
    case chataigne
    case openStageControl
    case qlcPlus
    case ola
}

/// Represents OscCueMessage values used by read-only control integration.
public struct OscCueMessage: Codable, Equatable, Sendable {
    public static let address = "/open-lola/cue"
    public static let typeTags = ",ss"

    public var cueId: String
    public var senderTimestampNanoseconds: UInt64

    public init(cueId: String, senderTimestampNanoseconds: UInt64) {
        self.cueId = cueId
        self.senderTimestampNanoseconds = senderTimestampNanoseconds
    }

    public func packetData() throws -> Data {
        var data = Data()
        data.append(oscString(Self.address))
        data.append(oscString(Self.typeTags))
        data.append(oscString(cueId))
        data.append(oscString(String(senderTimestampNanoseconds)))
        return data
    }

    public static func decodePacket(_ data: Data) throws -> OscCueMessage {
        var cursor = 0
        let address = try readOscString(data, cursor: &cursor)
        guard address == Self.address else {
            throw OscCuePacketError.invalidAddress(address)
        }
        let typeTags = try readOscString(data, cursor: &cursor)
        guard typeTags == Self.typeTags else {
            throw OscCuePacketError.invalidTypeTags(typeTags)
        }
        let cueId = try readOscString(data, cursor: &cursor)
        let timestamp = try readOscString(data, cursor: &cursor)
        guard let timestampNanoseconds = UInt64(timestamp) else {
            throw OscCuePacketError.invalidTimestamp(timestamp)
        }
        return OscCueMessage(cueId: cueId, senderTimestampNanoseconds: timestampNanoseconds)
    }
}

/// Enumerates failures that callers must handle when working with read-only control integration.
public enum OscCuePacketError: Error, Equatable, Sendable {
    case missingNullTerminator
    case invalidUTF8String
    case invalidAddress(String)
    case invalidTypeTags(String)
    case invalidTimestamp(String)
}

/// Enumerates failures that callers must handle when working with read-only control integration.
public enum OscCueError: Error, Equatable, Sendable {
    case receiveFailed(Int32)
}

/// Enumerates failures that callers must handle when working with read-only control integration.
public enum OscCueValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case emptyList(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case unorderedJitter
    case unorderedCueTiming(String)
    case cueJitterMismatch(cueId: String, expected: Double, actual: Double)
    case jitterSummaryMismatch(field: String, expected: Double, actual: Double)
    case cueCountMismatch(expected: Int, actual: Int)
    case invalidAddress(String)
    case invalidTypeTags(String)
    case unavailablePeerWithoutReason
    case unorderedAudioCallbackMetrics(String)
    case passWithoutAvailablePeer
    case passWithoutMeasuredLoopback
    case passWithoutLiveUdpLoopback
    case passWithoutFirstExternalPeer
    case passIncreasesAudioP99(baseline: Double, cueLoop: Double)
    case passIncreasesAudioMax(baseline: Double, cueLoop: Double)
    case passChangesAudioPlayoutTarget(baseline: Int, cueLoop: Int)
    case passWithUnderruns(Int)
    case passWithHiddenAudioImpact
    case passWithSyntheticAudioImpact
}

/// Keeps OSC capture identity distinct from other control-report identities.
public enum OscCueReportIdentityDomain {}
/// Names the report identity type used by OSC cue evidence.
public typealias OscCueReportIdentity = ReportCaptureIdentity<OscCueReportIdentityDomain>

/// Groups peer, transport, cue timing, jitter, and audio-impact evidence for one report.
public struct OscCueReportEvidence: Equatable, Sendable {
    public var peer: OscCuePeerReport
    public var transport: OscCueTransportEvidence?
    public var firstExternalPeer: OscCueExternalPeerEvidence?
    public var message: OscCueMessageProfile
    public var cues: [OscCueTimingSample]
    public var jitter: UdpPcmPacketAgeMetrics
    public var audioImpact: OscCueAudioImpactMetrics
    public var durationSeconds: Double
    public init(peer: OscCuePeerReport, transport: OscCueTransportEvidence? = nil, firstExternalPeer: OscCueExternalPeerEvidence? = nil, message: OscCueMessageProfile, cues: [OscCueTimingSample], jitter: UdpPcmPacketAgeMetrics, audioImpact: OscCueAudioImpactMetrics, durationSeconds: Double) { self.peer = peer; self.transport = transport; self.firstExternalPeer = firstExternalPeer; self.message = message; self.cues = cues; self.jitter = jitter; self.audioImpact = audioImpact; self.durationSeconds = durationSeconds }
}

/// Serializes OSC cue evidence and its verdict for validation and later review.
public struct OscCueReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var peer: OscCuePeerReport
    public var transport: OscCueTransportEvidence?
    public var firstExternalPeer: OscCueExternalPeerEvidence?
    public var message: OscCueMessageProfile
    public var cues: [OscCueTimingSample]
    public var jitter: UdpPcmPacketAgeMetrics
    public var audioImpact: OscCueAudioImpactMetrics
    public var durationSeconds: Double
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(identity: OscCueReportIdentity, evidence: OscCueReportEvidence, verdict: MeasurementVerdict, notes: String) {
        self.id = identity.id
        self.title = identity.title
        self.capturedAt = identity.capturedAt
        self.peer = evidence.peer
        self.transport = evidence.transport
        self.firstExternalPeer = evidence.firstExternalPeer
        self.message = evidence.message
        self.cues = evidence.cues
        self.jitter = evidence.jitter
        self.audioImpact = evidence.audioImpact
        self.durationSeconds = evidence.durationSeconds
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try validateIdentity()
        try validatePeer()
        try validateTransport()
        try validateFirstExternalPeer()
        try validateMessage()
        try validateCues()
        try validateJitter()
        try validateAudioImpact()
        try validatePassVerdict()
    }

    private func validateIdentity() throws {
        try requireOscNonEmpty(id, "id")
        try requireOscNonEmpty(title, "title")
        try requireOscNonEmpty(capturedAt, "capturedAt")
        try requireOscPositive(durationSeconds, "durationSeconds")
        try requireOscNonEmpty(notes, "notes")
    }

    private func validatePeer() throws {
        try requireOscNonEmpty(peer.label, "peer.label")
        if !peer.available {
            guard let reason = peer.unavailableReason, !reason.isEmpty else {
                throw OscCueValidationError.unavailablePeerWithoutReason
            }
        }
    }

    private func validateTransport() throws {
        guard let transport else {
            return
        }

        try requireOscNonEmpty(transport.protocolName, "transport.protocolName")
        try requireOscNonEmpty(transport.localBindHost, "transport.localBindHost")
        try requireOscNonEmpty(transport.peerHost, "transport.peerHost")
        try requireOscPositive(transport.peerPort, "transport.peerPort")
        try requireOscNonNegative(transport.sentPackets, "transport.sentPackets")
        try requireOscNonNegative(transport.receivedPackets, "transport.receivedPackets")
    }

    private func validateFirstExternalPeer() throws {
        guard let firstExternalPeer else {
            return
        }

        try requireOscNonEmpty(firstExternalPeer.host, "firstExternalPeer.host")
        try requireOscPositive(firstExternalPeer.port, "firstExternalPeer.port")
        if !firstExternalPeer.available {
            guard let reason = firstExternalPeer.unavailableReason, !reason.isEmpty else {
                throw OscCueValidationError.unavailablePeerWithoutReason
            }
        }
    }

    private func validateMessage() throws {
        try requireOscNonEmpty(message.address, "message.address")
        try requireOscNonEmpty(message.typeTags, "message.typeTags")
        try requireOscNonEmpty(message.timestampEncoding, "message.timestampEncoding")
        try requireOscPositive(message.cueCount, "message.cueCount")
        guard message.address == OscCueMessage.address else {
            throw OscCueValidationError.invalidAddress(message.address)
        }
        guard message.typeTags == OscCueMessage.typeTags else {
            throw OscCueValidationError.invalidTypeTags(message.typeTags)
        }
        guard message.cueCount == cues.count else {
            throw OscCueValidationError.cueCountMismatch(expected: cues.count, actual: message.cueCount)
        }
    }

    private func validateCues() throws {
        guard !cues.isEmpty else {
            throw OscCueValidationError.emptyList("cues")
        }
        for cue in cues {
            try requireOscNonEmpty(cue.cueId, "cues.cueId")
            try requireOscNonNegative(cue.jitterMicroseconds, "cues.jitterMicroseconds")
            guard cue.receiverTimestampNanoseconds >= cue.senderTimestampNanoseconds else {
                throw OscCueValidationError.unorderedCueTiming(cue.cueId)
            }
            let expected = Double(cue.receiverTimestampNanoseconds - cue.senderTimestampNanoseconds) / 1_000
            if abs(cue.jitterMicroseconds - expected) > 0.0001 {
                throw OscCueValidationError.cueJitterMismatch(
                    cueId: cue.cueId,
                    expected: expected,
                    actual: cue.jitterMicroseconds
                )
            }
        }
    }

    private func validateJitter() throws {
        try requireOscNonNegative(jitter.p50Microseconds, "jitter.p50Microseconds")
        try requireOscNonNegative(jitter.p95Microseconds, "jitter.p95Microseconds")
        try requireOscNonNegative(jitter.p99Microseconds, "jitter.p99Microseconds")
        try requireOscNonNegative(jitter.maxMicroseconds, "jitter.maxMicroseconds")
        guard jitter.p50Microseconds <= jitter.p95Microseconds,
              jitter.p95Microseconds <= jitter.p99Microseconds,
              jitter.p99Microseconds <= jitter.maxMicroseconds else {
            throw OscCueValidationError.unorderedJitter
        }

        let expected = packetAgeMetrics(for: cues.map(\.jitterMicroseconds))
        try requireOscJitterMatch("jitter.p50Microseconds", expected.p50Microseconds, jitter.p50Microseconds)
        try requireOscJitterMatch("jitter.p95Microseconds", expected.p95Microseconds, jitter.p95Microseconds)
        try requireOscJitterMatch("jitter.p99Microseconds", expected.p99Microseconds, jitter.p99Microseconds)
        try requireOscJitterMatch("jitter.maxMicroseconds", expected.maxMicroseconds, jitter.maxMicroseconds)
    }

    private func validateAudioImpact() throws {
        try requireOscNonNegative(
            audioImpact.baselineCallbackP99Microseconds,
            "audioImpact.baselineCallbackP99Microseconds"
        )
        try requireOscNonNegative(
            audioImpact.cueLoopCallbackP99Microseconds,
            "audioImpact.cueLoopCallbackP99Microseconds"
        )
        try requireOscNonNegative(
            audioImpact.baselineCallbackMaxMicroseconds,
            "audioImpact.baselineCallbackMaxMicroseconds"
        )
        try requireOscNonNegative(
            audioImpact.cueLoopCallbackMaxMicroseconds,
            "audioImpact.cueLoopCallbackMaxMicroseconds"
        )
        try requireOscPositive(audioImpact.baselinePlayoutTargetFrames, "audioImpact.baselinePlayoutTargetFrames")
        try requireOscPositive(audioImpact.cueLoopPlayoutTargetFrames, "audioImpact.cueLoopPlayoutTargetFrames")
        try requireOscNonNegative(audioImpact.underruns, "audioImpact.underruns")
        if let baselineReportId = audioImpact.baselineReportId {
            try requireOscNonEmpty(baselineReportId, "audioImpact.baselineReportId")
        }
        guard audioImpact.baselineCallbackP99Microseconds <= audioImpact.baselineCallbackMaxMicroseconds else {
            throw OscCueValidationError.unorderedAudioCallbackMetrics("audioImpact.baseline")
        }
        guard audioImpact.cueLoopCallbackP99Microseconds <= audioImpact.cueLoopCallbackMaxMicroseconds else {
            throw OscCueValidationError.unorderedAudioCallbackMetrics("audioImpact.cueLoop")
        }
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }

        try validatePassPeerEvidence()
        try validatePassTransportEvidence()
        try validatePassExternalPeerEvidence()
        try validatePassAudioImpact()
    }

    private func validatePassPeerEvidence() throws {
        guard peer.available else {
            throw OscCueValidationError.passWithoutAvailablePeer
        }
        guard peer.kind == .localLoopback else {
            throw OscCueValidationError.passWithoutMeasuredLoopback
        }
    }

    private func validatePassExternalPeerEvidence() throws {
        guard let firstExternalPeer, firstExternalPeer.available else {
            throw OscCueValidationError.passWithoutFirstExternalPeer
        }
    }

    private func validatePassTransportEvidence() throws {
        guard let transport,
              transport.protocolName == "udp",
              transport.liveUdpLoopback,
              transport.sentPackets == message.cueCount,
              transport.receivedPackets == message.cueCount else {
            throw OscCueValidationError.passWithoutLiveUdpLoopback
        }
    }

    private func validatePassAudioImpact() throws {
        if audioImpact.cueLoopCallbackP99Microseconds > audioImpact.baselineCallbackP99Microseconds {
            throw OscCueValidationError.passIncreasesAudioP99(
                baseline: audioImpact.baselineCallbackP99Microseconds,
                cueLoop: audioImpact.cueLoopCallbackP99Microseconds
            )
        }
        if audioImpact.cueLoopCallbackMaxMicroseconds > audioImpact.baselineCallbackMaxMicroseconds {
            throw OscCueValidationError.passIncreasesAudioMax(
                baseline: audioImpact.baselineCallbackMaxMicroseconds,
                cueLoop: audioImpact.cueLoopCallbackMaxMicroseconds
            )
        }
        if audioImpact.cueLoopPlayoutTargetFrames != audioImpact.baselinePlayoutTargetFrames {
            throw OscCueValidationError.passChangesAudioPlayoutTarget(
                baseline: audioImpact.baselinePlayoutTargetFrames,
                cueLoop: audioImpact.cueLoopPlayoutTargetFrames
            )
        }
        if audioImpact.underruns > 0 {
            throw OscCueValidationError.passWithUnderruns(audioImpact.underruns)
        }
        if audioImpact.hiddenAudioImpactDetected {
            throw OscCueValidationError.passWithHiddenAudioImpact
        }
        if audioImpact.synthetic == true {
            throw OscCueValidationError.passWithSyntheticAudioImpact
        }
    }
}
