// Encodes session control messages, payload variants, and legal runtime transitions so peers validate the same signaling state machine.
import Foundation

/// Identifies the payload variant carried by a session control message.
public enum SessionControlMessageType: String, Codable, Equatable, Sendable {
    case hello
    case capabilities
    case sessionPropose
    case sessionAccept
    case sessionReject
    case audioMetadata
    case mediaStart
    case mediaPause
    case metrics
    case error
    case shutdown
}

/// Describes why a session proposal was rejected and whether the peer may retry.
public struct SessionRejection: Codable, Equatable, Sendable {
    public var reason: String
    public var recoverable: Bool

    public init(reason: String, recoverable: Bool) {
        self.reason = reason
        self.recoverable = recoverable
    }
}

/// Targets a negotiated session and supplies the host time for a media start or pause.
public struct SessionMediaCommand: Codable, Equatable, Sendable {
    public var sessionID: String
    public var hostTimeNanoseconds: UInt64

    public init(sessionID: String, hostTimeNanoseconds: UInt64) {
        self.sessionID = sessionID
        self.hostTimeNanoseconds = hostTimeNanoseconds
    }
}

/// Reports loss, jitter, callback, queue, resource, underrun, overrun, and video-drop telemetry for a session.
public struct SessionMetricsMessage: Codable, Equatable, Sendable {
    public var sessionID: String
    public var packetsLost: Int
    public var jitterMicroseconds: Double
    public var latePackets: Int
    public var callbackDurationP99Microseconds: Double
    public var queueDepthPackets: Int
    public var cpuPercent: Double
    public var memoryResidentBytes: UInt64
    public var underruns: Int
    public var overruns: Int
    public var videoFramesDropped: Int

    public struct Delivery: Equatable, Sendable {
        public let packetsLost: Int
        public let jitterMicroseconds: Double
        public let latePackets: Int
        public let callbackDurationP99Microseconds: Double
        public let queueDepthPackets: Int

        public init(packetsLost: Int, jitterMicroseconds: Double, latePackets: Int = 0,
                    callbackDurationP99Microseconds: Double = 0, queueDepthPackets: Int = 0) {
            self.packetsLost = packetsLost
            self.jitterMicroseconds = jitterMicroseconds
            self.latePackets = latePackets
            self.callbackDurationP99Microseconds = callbackDurationP99Microseconds
            self.queueDepthPackets = queueDepthPackets
        }
    }

    public struct Runtime: Equatable, Sendable {
        public let cpuPercent: Double
        public let memoryResidentBytes: UInt64
        public let underruns: Int
        public let overruns: Int
        public let videoFramesDropped: Int

        public init(cpuPercent: Double = 0, memoryResidentBytes: UInt64 = 0,
                    underruns: Int, overruns: Int, videoFramesDropped: Int) {
            self.cpuPercent = cpuPercent
            self.memoryResidentBytes = memoryResidentBytes
            self.underruns = underruns
            self.overruns = overruns
            self.videoFramesDropped = videoFramesDropped
        }
    }

    public init(sessionID: String, delivery: Delivery, runtime: Runtime) {
        self.sessionID = sessionID
        packetsLost = delivery.packetsLost
        jitterMicroseconds = delivery.jitterMicroseconds
        latePackets = delivery.latePackets
        callbackDurationP99Microseconds = delivery.callbackDurationP99Microseconds
        queueDepthPackets = delivery.queueDepthPackets
        cpuPercent = runtime.cpuPercent
        memoryResidentBytes = runtime.memoryResidentBytes
        underruns = runtime.underruns
        overruns = runtime.overruns
        videoFramesDropped = runtime.videoFramesDropped
    }
}

/// Reports a coded session failure with optional session identity, fatality, and human-readable detail.
public struct SessionErrorMessage: Codable, Equatable, Sendable {
    public var sessionID: String?
    public var code: String
    public var message: String
    public var fatal: Bool

    public init(sessionID: String? = nil, code: String, message: String, fatal: Bool) {
        self.sessionID = sessionID
        self.code = code
        self.message = message
        self.fatal = fatal
    }
}

/// Requests session termination with an optional session identifier and human-readable reason.
public struct SessionShutdown: Codable, Equatable, Sendable {
    public var sessionID: String?
    public var reason: String

    public init(reason: String, sessionID: String? = nil) {
        self.sessionID = sessionID
        self.reason = reason
    }
}

/// Carries the payload selected by `type`, with constructors for every legal control-message variant.
public struct SessionControlMessage: PrettyJSONCodable, Equatable, Sendable {
    public var type: SessionControlMessageType
    public var peer: PeerIdentity?
    public var supportedControlVersions: [Int]?
    public var capabilities: CapabilitySet?
    public var proposal: SessionProposal?
    public var configuration: SessionConfiguration?
    public var rejection: SessionRejection?
    public var audioMetadata: RmeMatrixMetadataSnapshot?
    public var mediaCommand: SessionMediaCommand?
    public var metrics: SessionMetricsMessage?
    public var error: SessionErrorMessage?
    public var shutdown: SessionShutdown?

    public struct Handshake: Equatable, Sendable {
        public let peer: PeerIdentity?
        public let supportedControlVersions: [Int]?
        public let capabilities: CapabilitySet?
        public let proposal: SessionProposal?
        public let configuration: SessionConfiguration?
        public let rejection: SessionRejection?

        public init(peer: PeerIdentity? = nil, supportedControlVersions: [Int]? = nil,
                    capabilities: CapabilitySet? = nil, proposal: SessionProposal? = nil,
                    configuration: SessionConfiguration? = nil, rejection: SessionRejection? = nil) {
            self.peer = peer
            self.supportedControlVersions = supportedControlVersions
            self.capabilities = capabilities
            self.proposal = proposal
            self.configuration = configuration
            self.rejection = rejection
        }
    }

    public struct Media: Equatable, Sendable {
        public let audioMetadata: RmeMatrixMetadataSnapshot?
        public let mediaCommand: SessionMediaCommand?
        public let metrics: SessionMetricsMessage?
        public let error: SessionErrorMessage?
        public let shutdown: SessionShutdown?

        public init(audioMetadata: RmeMatrixMetadataSnapshot? = nil, mediaCommand: SessionMediaCommand? = nil,
                    metrics: SessionMetricsMessage? = nil, error: SessionErrorMessage? = nil,
                    shutdown: SessionShutdown? = nil) {
            self.audioMetadata = audioMetadata
            self.mediaCommand = mediaCommand
            self.metrics = metrics
            self.error = error
            self.shutdown = shutdown
        }
    }

    public init(type: SessionControlMessageType, handshake: Handshake = .init(), media: Media = .init()) {
        self.type = type
        peer = handshake.peer
        supportedControlVersions = handshake.supportedControlVersions
        capabilities = handshake.capabilities
        proposal = handshake.proposal
        configuration = handshake.configuration
        rejection = handshake.rejection
        audioMetadata = media.audioMetadata
        mediaCommand = media.mediaCommand
        metrics = media.metrics
        error = media.error
        shutdown = media.shutdown
    }

    public static func hello(
        peer: PeerIdentity,
        supportedControlVersions: [Int]
    ) -> SessionControlMessage {
        SessionControlMessage(
            type: .hello,
            handshake: .init(peer: peer, supportedControlVersions: supportedControlVersions)
        )
    }

    public static func capabilities(_ capabilities: CapabilitySet) -> SessionControlMessage {
        SessionControlMessage(type: .capabilities, handshake: .init(capabilities: capabilities))
    }

    public static func sessionPropose(_ proposal: SessionProposal) -> SessionControlMessage {
        SessionControlMessage(type: .sessionPropose, handshake: .init(proposal: proposal))
    }

    public static func sessionAccept(_ configuration: SessionConfiguration) -> SessionControlMessage {
        SessionControlMessage(type: .sessionAccept, handshake: .init(configuration: configuration))
    }

    public static func sessionReject(_ rejection: SessionRejection) -> SessionControlMessage {
        SessionControlMessage(type: .sessionReject, handshake: .init(rejection: rejection))
    }

    public static func audioMetadata(_ snapshot: RmeMatrixMetadataSnapshot) -> SessionControlMessage {
        SessionControlMessage(type: .audioMetadata, media: .init(audioMetadata: snapshot))
    }

    public static func mediaStart(_ command: SessionMediaCommand) -> SessionControlMessage {
        SessionControlMessage(type: .mediaStart, media: .init(mediaCommand: command))
    }

    public static func mediaPause(_ command: SessionMediaCommand) -> SessionControlMessage {
        SessionControlMessage(type: .mediaPause, media: .init(mediaCommand: command))
    }

    public static func metrics(_ metrics: SessionMetricsMessage) -> SessionControlMessage {
        SessionControlMessage(type: .metrics, media: .init(metrics: metrics))
    }

    public static func error(_ error: SessionErrorMessage) -> SessionControlMessage {
        SessionControlMessage(type: .error, media: .init(error: error))
    }

    public static func shutdown(_ shutdown: SessionShutdown) -> SessionControlMessage {
        SessionControlMessage(type: .shutdown, media: .init(shutdown: shutdown))
    }
}

/// Encodes and decodes session control messages as deterministic JSON.
public enum SessionControlCodec {
    public static func encode(_ message: SessionControlMessage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(message)
    }

    public static func decode(_ data: Data) throws -> SessionControlMessage {
        try JSONDecoder().decode(SessionControlMessage.self, from: data)
    }
}

/// Tracks the legal lifecycle phases of the session control state machine.
public enum SessionRuntimeState: String, Codable, Equatable, Sendable {
    case idle
    case helloReceived
    case capabilitiesReceived
    case proposed
    case accepted
    case running
    case paused
    case failed
    case stopped
}

/// Reports a control message rejected because it is illegal in the current runtime state.
public enum SessionStateMachineError: Error, Equatable, Sendable {
    case invalidTransition(from: SessionRuntimeState, message: SessionControlMessageType)
}

/// Tracks runtime state and enforces legal transitions for incoming control-message types.
public struct SessionStateMachine: Equatable, Sendable {
    public private(set) var state: SessionRuntimeState

    public init(state: SessionRuntimeState = .idle) {
        self.state = state
    }

    public mutating func apply(_ message: SessionControlMessage) throws {
        let transition = Self.transition(for: message.type)
        try requireTransition(message, allowedFrom: transition.allowedStates)
        if let nextState = transition.nextState {
            state = nextState
        }
    }

    private func requireTransition(
        _ message: SessionControlMessage,
        allowedFrom allowedStates: Set<SessionRuntimeState>
    ) throws {
        guard allowedStates.contains(state) else {
            throw SessionStateMachineError.invalidTransition(from: state, message: message.type)
        }
    }

    private static func transition(for type: SessionControlMessageType) -> SessionStateTransition {
        guard let transition = transitions[type] else {
            preconditionFailure("Missing session state transition for \(type)")
        }
        return transition
    }

    private static let transitions: [SessionControlMessageType: SessionStateTransition] = [
        .hello: SessionStateTransition(allowedStates: [.idle], nextState: .helloReceived),
        .capabilities: SessionStateTransition(allowedStates: [.helloReceived], nextState: .capabilitiesReceived),
        .sessionPropose: SessionStateTransition(allowedStates: [.capabilitiesReceived], nextState: .proposed),
        .sessionAccept: SessionStateTransition(allowedStates: [.proposed], nextState: .accepted),
        .audioMetadata: SessionStateTransition(allowedStates: [.accepted, .running, .paused]),
        .sessionReject: SessionStateTransition(
            allowedStates: [.helloReceived, .capabilitiesReceived, .proposed],
            nextState: .failed
        ),
        .error: SessionStateTransition(allowedStates: [.accepted, .running, .paused], nextState: .failed),
        .mediaStart: SessionStateTransition(allowedStates: [.accepted, .running, .paused], nextState: .running),
        .mediaPause: SessionStateTransition(allowedStates: [.running], nextState: .paused),
        .metrics: SessionStateTransition(allowedStates: [.accepted, .running, .paused]),
        .shutdown: SessionStateTransition(allowedStates: [.accepted, .running, .paused, .stopped], nextState: .stopped)
    ]
}

private struct SessionStateTransition: Sendable {
    var allowedStates: Set<SessionRuntimeState>
    var nextState: SessionRuntimeState?
}
