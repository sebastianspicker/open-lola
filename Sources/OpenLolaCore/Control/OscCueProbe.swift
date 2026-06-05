import Darwin
import Foundation

public enum OscCuePeerKind: String, Codable, Equatable, Sendable {
    case localLoopback
    case chataigne
    case openStageControl
    case qlcPlus
    case ola
}

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

public enum OscCuePacketError: Error, Equatable, Sendable {
    case missingNullTerminator
    case invalidUTF8String
    case invalidAddress(String)
    case invalidTypeTags(String)
    case invalidTimestamp(String)
}

public enum OscCueError: Error, Equatable, Sendable {
    case receiveFailed(Int32)
}

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

    public init(
        baselineCallbackP99Microseconds: Double,
        cueLoopCallbackP99Microseconds: Double,
        baselineCallbackMaxMicroseconds: Double,
        cueLoopCallbackMaxMicroseconds: Double,
        baselinePlayoutTargetFrames: Int,
        cueLoopPlayoutTargetFrames: Int,
        underruns: Int,
        hiddenAudioImpactDetected: Bool,
        baselineReportId: String? = nil,
        synthetic: Bool? = nil
    ) {
        self.baselineCallbackP99Microseconds = baselineCallbackP99Microseconds
        self.cueLoopCallbackP99Microseconds = cueLoopCallbackP99Microseconds
        self.baselineCallbackMaxMicroseconds = baselineCallbackMaxMicroseconds
        self.cueLoopCallbackMaxMicroseconds = cueLoopCallbackMaxMicroseconds
        self.baselinePlayoutTargetFrames = baselinePlayoutTargetFrames
        self.cueLoopPlayoutTargetFrames = cueLoopPlayoutTargetFrames
        self.underruns = underruns
        self.hiddenAudioImpactDetected = hiddenAudioImpactDetected
        self.baselineReportId = baselineReportId
        self.synthetic = synthetic
    }
}

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

    public init(
        id: String,
        title: String,
        capturedAt: String,
        peer: OscCuePeerReport,
        transport: OscCueTransportEvidence? = nil,
        firstExternalPeer: OscCueExternalPeerEvidence? = nil,
        message: OscCueMessageProfile,
        cues: [OscCueTimingSample],
        jitter: UdpPcmPacketAgeMetrics,
        audioImpact: OscCueAudioImpactMetrics,
        durationSeconds: Double,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.peer = peer
        self.transport = transport
        self.firstExternalPeer = firstExternalPeer
        self.message = message
        self.cues = cues
        self.jitter = jitter
        self.audioImpact = audioImpact
        self.durationSeconds = durationSeconds
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

public struct OscCueExternalRunConfiguration: Codable, Equatable, Sendable {
    public let audioBaselineReportId: String
    public let port: UInt16
    public let count: Int
    public let firstExternalPeerKind: OscCuePeerKind
    public let externalHost: String
    public let externalPort: UInt16
    public let externalAvailable: Bool
    public let externalUnavailableReason: String?
    public let outputPath: String

    public init(
        audioBaselineReportId: String,
        port: UInt16,
        count: Int,
        firstExternalPeerKind: OscCuePeerKind,
        externalHost: String,
        externalPort: UInt16,
        externalAvailable: Bool,
        externalUnavailableReason: String?,
        outputPath: String
    ) {
        self.audioBaselineReportId = audioBaselineReportId
        self.port = port
        self.count = count
        self.firstExternalPeerKind = firstExternalPeerKind
        self.externalHost = externalHost
        self.externalPort = externalPort
        self.externalAvailable = externalAvailable
        self.externalUnavailableReason = externalUnavailableReason
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> OscCueExternalRunConfiguration {
        let allowed = [
            "--audio-baseline",
            "--port",
            "--count",
            "--first-external-peer",
            "--external-host",
            "--external-port",
            "--external-available",
            "--external-unavailable-reason",
            "--output",
        ]
        var values: [String: String] = [:]
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            guard allowed.contains(argument) else {
                throw OscCueExternalRunConfigurationError.unknownArgument(argument)
            }
            guard values[argument] == nil else {
                throw OscCueExternalRunConfigurationError.duplicateArgument(argument)
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
                throw OscCueExternalRunConfigurationError.missingValue(argument)
            }
            values[argument] = arguments[valueIndex]
            index += 2
        }

        let externalAvailable = try requiredOscExternalRunBoolean("--external-available", values)
        let unavailableReason = values["--external-unavailable-reason"]
        if !externalAvailable && (unavailableReason?.isEmpty ?? true) {
            throw OscCueExternalRunConfigurationError.missingRequiredArgument("--external-unavailable-reason")
        }

        return OscCueExternalRunConfiguration(
            audioBaselineReportId: try requiredOscExternalRunString("--audio-baseline", values),
            port: try requiredOscExternalRunPort("--port", values, allowZero: true),
            count: try requiredOscExternalRunPositiveInteger("--count", values),
            firstExternalPeerKind: try requiredOscExternalRunPeerKind("--first-external-peer", values),
            externalHost: try requiredOscExternalRunString("--external-host", values),
            externalPort: try requiredOscExternalRunPort("--external-port", values, allowZero: false),
            externalAvailable: externalAvailable,
            externalUnavailableReason: unavailableReason,
            outputPath: try requiredOscExternalRunString("--output", values)
        )
    }
}

public enum OscCueExternalRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
    case invalidPort(String)
    case invalidBoolean(argument: String, value: String)
    case invalidExternalPeerKind(String)
}
