// Defines and validates LoLa media-session evidence for sent and received audio and video frames.
import Foundation

/// Records the evidence and outcome for LoLa compatibility media session report.
public struct LoLaCompatibilityMediaSessionReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Identity: Equatable, Sendable {
        public var id: String
        public var capturedAt: String
        public var role: LoLaCompatibilityMediaSessionRole
        public var mediaMode: ExternalConnectorMediaMode

        public init(
            id: String,
            capturedAt: String,
            role: LoLaCompatibilityMediaSessionRole,
            mediaMode: ExternalConnectorMediaMode
        ) {
            self.id = id
            self.capturedAt = capturedAt
            self.role = role
            self.mediaMode = mediaMode
        }
    }

    public struct Execution: Equatable, Sendable {
        public var frames: [LoLaCompatibilityMediaFrame]
        public var realLinkTransmitted: Bool
        public var verdict: MeasurementVerdict
        public var runtimeError: String?

        public init(
            frames: [LoLaCompatibilityMediaFrame],
            realLinkTransmitted: Bool,
            verdict: MeasurementVerdict,
            runtimeError: String? = nil
        ) {
            self.frames = frames
            self.realLinkTransmitted = realLinkTransmitted
            self.verdict = verdict
            self.runtimeError = runtimeError
        }
    }

    public struct Endpoint: Equatable, Sendable {
        public var localHost: String?
        public var peer: String?
        public var audioPort: UInt16?
        public var videoPort: UInt16?
        public var timeoutSeconds: Int?
        public var expectedDatagramCount: Int?
        public var sentBytesTotal: Int?

        public init(
            localHost: String? = nil,
            peer: String? = nil,
            audioPort: UInt16? = nil,
            videoPort: UInt16? = nil,
            timeoutSeconds: Int? = nil,
            expectedDatagramCount: Int? = nil,
            sentBytesTotal: Int? = nil
        ) {
            self.localHost = localHost
            self.peer = peer
            self.audioPort = audioPort
            self.videoPort = videoPort
            self.timeoutSeconds = timeoutSeconds
            self.expectedDatagramCount = expectedDatagramCount
            self.sentBytesTotal = sentBytesTotal
        }
    }

    public struct Input: Equatable, Sendable {
        public var identity: Identity
        public var execution: Execution
        public var endpoint: Endpoint
        public var evidenceBoundary: String
        public var notes: String

        public init(
            identity: Identity,
            execution: Execution,
            endpoint: Endpoint,
            evidenceBoundary: String,
            notes: String
        ) {
            self.identity = identity
            self.execution = execution
            self.endpoint = endpoint
            self.evidenceBoundary = evidenceBoundary
            self.notes = notes
        }
    }

    public var id: String
    public var capturedAt: String
    public var role: LoLaCompatibilityMediaSessionRole
    public var mediaMode: ExternalConnectorMediaMode
    public var frames: [LoLaCompatibilityMediaFrame]
    public var audioFrameCount: Int
    public var videoFrameCount: Int
    public var totalWireBytes: Int
    public var envelopeValidatedFrameCount: Int
    public var realLinkTransmitted: Bool
    public var verdict: MeasurementVerdict
    public var runtimeError: String?
    public var localHost: String?
    public var peer: String?
    public var audioPort: UInt16?
    public var videoPort: UInt16?
    public var timeoutSeconds: Int?
    public var expectedDatagramCount: Int?
    public var sentBytesTotal: Int?
    public var evidenceBoundary: String
    public var notes: String

    public init(input: Input) {
        id = input.identity.id
        capturedAt = input.identity.capturedAt
        role = input.identity.role
        mediaMode = input.identity.mediaMode
        frames = input.execution.frames
        audioFrameCount = frames.filter { $0.stream == .audio }.count
        videoFrameCount = frames.filter { $0.stream == .video }.count
        totalWireBytes = frames.map(\.wireByteCount).reduce(0, +)
        envelopeValidatedFrameCount = frames.filter(\.envelopeValidated).count
        realLinkTransmitted = input.execution.realLinkTransmitted
        verdict = input.execution.verdict
        runtimeError = input.execution.runtimeError
        localHost = input.endpoint.localHost
        peer = input.endpoint.peer
        audioPort = input.endpoint.audioPort
        videoPort = input.endpoint.videoPort
        timeoutSeconds = input.endpoint.timeoutSeconds
        expectedDatagramCount = input.endpoint.expectedDatagramCount
        sentBytesTotal = input.endpoint.sentBytesTotal
        evidenceBoundary = input.evidenceBoundary
        notes = input.notes
    }

    public var malformedFrameCount: Int {
        frames.filter { $0.packetKind == .malformedFragment }.count
    }

    public func validate() throws {
        try requireExternalConnectorSessionNonEmpty(id, "id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "capturedAt")
        try requireExternalConnectorSessionNonEmpty(evidenceBoundary, "evidenceBoundary")
        try requireExternalConnectorSessionNonEmpty(notes, "notes")
        try validateLoLaMediaSessionVerdict()
        try validateLoLaMediaSessionSentBytes()
        try validateLoLaMediaSessionFrameCounts()
    }

    private func validateLoLaMediaSessionVerdict() throws {
        guard verdict != .pass else { throw ExternalConnectorSessionError.dryRunCannotPass }
        if verdict == .fail {
            try requireExternalConnectorSessionNonEmpty(runtimeError ?? "", "runtimeError")
        }
    }

    private func validateLoLaMediaSessionSentBytes() throws {
        guard let sentBytesTotal else { return }
        guard sentBytesTotal >= 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("sentBytesTotal", String(sentBytesTotal))
        }
        if realLinkTransmitted, role != .rx, sentBytesTotal == 0, verdict != .fail {
            throw ExternalConnectorSessionError.socketFailed(
                "measured LoLa TX reported zero sent bytes without fail verdict"
            )
        }
    }

    private func validateLoLaMediaSessionFrameCounts() throws {
        try requireLoLaMediaSessionCount(
            audioFrameCount,
            expected: frames.filter { $0.stream == .audio }.count,
            field: "audioFrameCount"
        )
        try requireLoLaMediaSessionCount(
            videoFrameCount,
            expected: frames.filter { $0.stream == .video }.count,
            field: "videoFrameCount"
        )
        try requireLoLaMediaSessionCount(
            totalWireBytes,
            expected: frames.map(\.wireByteCount).reduce(0, +),
            field: "totalWireBytes"
        )
        try requireLoLaMediaSessionCount(
            envelopeValidatedFrameCount,
            expected: frames.filter(\.envelopeValidated).count,
            field: "envelopeValidatedFrameCount"
        )
    }
}

private func requireLoLaMediaSessionCount(_ actual: Int, expected: Int, field: String) throws {
    guard actual == expected else {
        throw ExternalConnectorSessionError.invalidPositiveInteger(field, String(actual))
    }
}
