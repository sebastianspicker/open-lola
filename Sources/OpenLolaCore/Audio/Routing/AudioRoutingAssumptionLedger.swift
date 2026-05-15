import Foundation

public enum AudioRoutingAssumptionClassification: String, Codable, Equatable, Sendable {
    case legacyV1Compatibility
    case syntheticFixture
    case defaultProfile
    case runtimeMultichannelPath
    case validationBoundary
    case advisoryMetadata
    case unclassified
}

public enum AudioRoutingAssumptionStatus: String, Codable, Equatable, Sendable {
    case accepted
    case replacedByV2Path
    case sourceImplemented
    case physicalEvidenceRequired
}

public struct AudioRoutingAssumption: Codable, Equatable, Sendable {
    public var id: String
    public var location: String
    public var assumption: String
    public var classification: AudioRoutingAssumptionClassification
    public var status: AudioRoutingAssumptionStatus
    public var action: String

    public init(
        id: String,
        location: String,
        assumption: String,
        classification: AudioRoutingAssumptionClassification,
        status: AudioRoutingAssumptionStatus,
        action: String
    ) {
        self.id = id
        self.location = location
        self.assumption = assumption
        self.classification = classification
        self.status = status
        self.action = action
    }
}

public enum AudioRoutingAssumptionLedger {
    public static let entries: [AudioRoutingAssumption] = [
        AudioRoutingAssumption(
            id: "udp-pcm-v1-stereo-fixtures",
            location: "Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets",
            assumption: "valid v1 packet fixtures are stereo packets",
            classification: .legacyV1Compatibility,
            status: .accepted,
            action: "keep as v1 compatibility evidence and add v2 source-level round trips"
        ),
        AudioRoutingAssumption(
            id: "udp-pcm-localhost-smokes",
            location: "UdpPcmLocalhostSmoke, UdpPcmRouteLocalhostSmoke, UdpPcmContinuousRouteLocalhostSmoke",
            assumption: "localhost smoke helpers default to channelCount: 2",
            classification: .syntheticFixture,
            status: .accepted,
            action: "keep cheap v1 smoke behavior and cover multichannel in v2 packetizer tests"
        ),
        AudioRoutingAssumption(
            id: "udp-pcm-default-probe-packet",
            location: "UdpPcmRouteHelpers.makeProbePacket(sequenceNumber:senderFrameIndex:)",
            assumption: "no-mode helper emits 48 kHz, 32-frame, stereo int16 packets",
            classification: .defaultProfile,
            status: .accepted,
            action: "retain for legacy callers; use explicit mode or v2 packetizer for multichannel"
        ),
        AudioRoutingAssumption(
            id: "realtime-synthetic-stereo-map",
            location: "RealtimeAudioEngineTests.realtimeHandoffConfiguration",
            assumption: "synthetic realtime fixture uses channelCount: 2 and maps [0, 1]",
            classification: .syntheticFixture,
            status: .accepted,
            action: "keep fixture, add 64-channel v2 handoff coverage"
        ),
        AudioRoutingAssumption(
            id: "audio-loopback-synthetic-stereo-map",
            location: "AudioLoopbackRun synthetic report helpers",
            assumption: "loopback synthetic reports use channelCount: 2 and maps [0, 1]",
            classification: .syntheticFixture,
            status: .physicalEvidenceRequired,
            action: "do not claim multichannel PASS until measured RME loopback evidence exists"
        ),
        AudioRoutingAssumption(
            id: "route-certification-stereo-fixtures",
            location: "Mac-to-Mac and drift/PLC route certification fixtures",
            assumption: "route certification fixtures use stereo packet modes",
            classification: .syntheticFixture,
            status: .accepted,
            action: "keep existing certification lane and add v2 packet accounting as source evidence"
        ),
        AudioRoutingAssumption(
            id: "latency-tuning-stereo-candidates",
            location: "Latency tuning report candidates",
            assumption: "candidate modes are stereo until hardware matrix data exists",
            classification: .validationBoundary,
            status: .physicalEvidenceRequired,
            action: "treat max-stable-channel-count as a measured hardware follow-up, not a source claim"
        ),
        AudioRoutingAssumption(
            id: "rme-fastest-path-channel-fit",
            location: "RmeFastestAudioPathReport.validatePassVerdict",
            assumption: "selected mode channel count must fit input and output inventory counts",
            classification: .validationBoundary,
            status: .accepted,
            action: "preserve as PASS guard for future 64-channel physical evidence"
        ),
        AudioRoutingAssumption(
            id: "udp-pcm-v2-send-all-channel-fragments",
            location: "UdpPcmV2Packetizer and UdpPcmV2FragmentReassembler",
            assumption: "v2 sends all selected channels as MTU-safe channel-range fragments",
            classification: .runtimeMultichannelPath,
            status: .sourceImplemented,
            action: "use stable source order and keep metadata advisory by revision"
        ),
        AudioRoutingAssumption(
            id: "receiver-local-identity-mix",
            location: "ReceiverMixSnapshot.identity",
            assumption: "receiver defaults to identity routing when enough output channels exist",
            classification: .runtimeMultichannelPath,
            status: .sourceImplemented,
            action: "reject hidden destructive downmix unless explicitly allowed by receiver control"
        ),
        AudioRoutingAssumption(
            id: "rme-matrix-metadata-advisory",
            location: "RmeMatrixMetadataSnapshot",
            assumption: "RME matrix metadata is optional and never required for media playback",
            classification: .advisoryMetadata,
            status: .sourceImplemented,
            action: "accept Core Audio, documented TotalMix, user-provided, or unavailable providers only"
        ),
    ]

    public static var unclassifiedEntries: [AudioRoutingAssumption] {
        entries.filter { $0.classification == .unclassified }
    }
}
