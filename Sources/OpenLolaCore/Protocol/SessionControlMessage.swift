import Foundation

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

public struct SessionRejection: Codable, Equatable, Sendable {
    public var reason: String
    public var recoverable: Bool

    public init(reason: String, recoverable: Bool) {
        self.reason = reason
        self.recoverable = recoverable
    }
}

public struct SessionMediaCommand: Codable, Equatable, Sendable {
    public var sessionID: String
    public var hostTimeNanoseconds: UInt64

    public init(sessionID: String, hostTimeNanoseconds: UInt64) {
        self.sessionID = sessionID
        self.hostTimeNanoseconds = hostTimeNanoseconds
    }
}

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

    public init(
        sessionID: String,
        packetsLost: Int,
        jitterMicroseconds: Double,
        latePackets: Int = 0,
        callbackDurationP99Microseconds: Double = 0,
        queueDepthPackets: Int = 0,
        cpuPercent: Double = 0,
        memoryResidentBytes: UInt64 = 0,
        underruns: Int,
        overruns: Int,
        videoFramesDropped: Int
    ) {
        self.sessionID = sessionID
        self.packetsLost = packetsLost
        self.jitterMicroseconds = jitterMicroseconds
        self.latePackets = latePackets
        self.callbackDurationP99Microseconds = callbackDurationP99Microseconds
        self.queueDepthPackets = queueDepthPackets
        self.cpuPercent = cpuPercent
        self.memoryResidentBytes = memoryResidentBytes
        self.underruns = underruns
        self.overruns = overruns
        self.videoFramesDropped = videoFramesDropped
    }
}

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

public struct SessionShutdown: Codable, Equatable, Sendable {
    public var sessionID: String?
    public var reason: String

    public init(reason: String, sessionID: String? = nil) {
        self.sessionID = sessionID
        self.reason = reason
    }
}

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

    public init(
        type: SessionControlMessageType,
        peer: PeerIdentity? = nil,
        supportedControlVersions: [Int]? = nil,
        capabilities: CapabilitySet? = nil,
        proposal: SessionProposal? = nil,
        configuration: SessionConfiguration? = nil,
        rejection: SessionRejection? = nil,
        audioMetadata: RmeMatrixMetadataSnapshot? = nil,
        mediaCommand: SessionMediaCommand? = nil,
        metrics: SessionMetricsMessage? = nil,
        error: SessionErrorMessage? = nil,
        shutdown: SessionShutdown? = nil
    ) {
        self.type = type
        self.peer = peer
        self.supportedControlVersions = supportedControlVersions
        self.capabilities = capabilities
        self.proposal = proposal
        self.configuration = configuration
        self.rejection = rejection
        self.audioMetadata = audioMetadata
        self.mediaCommand = mediaCommand
        self.metrics = metrics
        self.error = error
        self.shutdown = shutdown
    }

    public static func hello(
        peer: PeerIdentity,
        supportedControlVersions: [Int]
    ) -> SessionControlMessage {
        SessionControlMessage(
            type: .hello,
            peer: peer,
            supportedControlVersions: supportedControlVersions
        )
    }

    public static func capabilities(_ capabilities: CapabilitySet) -> SessionControlMessage {
        SessionControlMessage(type: .capabilities, capabilities: capabilities)
    }

    public static func sessionPropose(_ proposal: SessionProposal) -> SessionControlMessage {
        SessionControlMessage(type: .sessionPropose, proposal: proposal)
    }

    public static func sessionAccept(_ configuration: SessionConfiguration) -> SessionControlMessage {
        SessionControlMessage(type: .sessionAccept, configuration: configuration)
    }

    public static func sessionReject(_ rejection: SessionRejection) -> SessionControlMessage {
        SessionControlMessage(type: .sessionReject, rejection: rejection)
    }

    public static func audioMetadata(_ snapshot: RmeMatrixMetadataSnapshot) -> SessionControlMessage {
        SessionControlMessage(type: .audioMetadata, audioMetadata: snapshot)
    }

    public static func mediaStart(_ command: SessionMediaCommand) -> SessionControlMessage {
        SessionControlMessage(type: .mediaStart, mediaCommand: command)
    }

    public static func mediaPause(_ command: SessionMediaCommand) -> SessionControlMessage {
        SessionControlMessage(type: .mediaPause, mediaCommand: command)
    }

    public static func metrics(_ metrics: SessionMetricsMessage) -> SessionControlMessage {
        SessionControlMessage(type: .metrics, metrics: metrics)
    }

    public static func error(_ error: SessionErrorMessage) -> SessionControlMessage {
        SessionControlMessage(type: .error, error: error)
    }

    public static func shutdown(_ shutdown: SessionShutdown) -> SessionControlMessage {
        SessionControlMessage(type: .shutdown, shutdown: shutdown)
    }
}

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

public enum SessionStateMachineError: Error, Equatable, Sendable {
    case invalidTransition(from: SessionRuntimeState, message: SessionControlMessageType)
}

public struct SessionStateMachine: Equatable, Sendable {
    public private(set) var state: SessionRuntimeState

    public init(state: SessionRuntimeState = .idle) {
        self.state = state
    }

    public mutating func apply(_ message: SessionControlMessage) throws {
        switch message.type {
        case .hello:
            try requireTransition(message, allowedFrom: [.idle])
            state = .helloReceived
        case .capabilities:
            try requireTransition(message, allowedFrom: [.helloReceived])
            state = .capabilitiesReceived
        case .sessionPropose:
            try requireTransition(message, allowedFrom: [.capabilitiesReceived])
            state = .proposed
        case .sessionAccept:
            try requireTransition(message, allowedFrom: [.proposed])
            state = .accepted
        case .audioMetadata:
            try requireTransition(message, allowedFrom: [.accepted, .running, .paused])
            return
        case .sessionReject, .error:
            try requireTransition(
                message,
                allowedFrom: [.helloReceived, .capabilitiesReceived, .proposed, .accepted, .running, .paused]
            )
            state = .failed
        case .mediaStart:
            try requireTransition(message, allowedFrom: [.accepted, .running, .paused])
            state = .running
        case .mediaPause:
            try requireTransition(message, allowedFrom: [.running])
            state = .paused
        case .metrics:
            try requireTransition(message, allowedFrom: [.accepted, .running, .paused])
            return
        case .shutdown:
            state = .stopped
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
}
