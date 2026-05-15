import Darwin
import Foundation
public enum ExternalConnectorSessionRole: String, Codable, Equatable, Sendable {
    case tx, rx
    case txRx = "tx-rx"

    public var transmits: Bool {
        self == .tx || self == .txRx
    }

    public var receives: Bool {
        self == .rx || self == .txRx
    }
}

public enum ExternalConnectorLaunchKind: String, Codable, Equatable, Sendable {
    case internalLoLaControl
    case internalLoLaControlUdp
    case externalProcess
}

public enum ExternalConnectorMediaMode: String, Codable, Equatable, Sendable {
    case audio
    case video
    case audioVideo

    public var hasAudio: Bool {
        self == .audio || self == .audioVideo
    }

    public var hasVideo: Bool {
        self == .video || self == .audioVideo
    }
}

public enum ExternalConnectorControlTransport: String, Codable, Equatable, Sendable {
    case udp
    case tcp
}

public enum LoLaVideoPayloadKind: String, Codable, Equatable, Sendable {
    case generated
    case avFoundationMjpeg = "avfoundation-mjpeg"
    case avFoundationRaw8 = "avfoundation-raw8"
    case avFoundationJpegXS = "avfoundation-jpeg-xs"
}

public struct JackTripRunConfiguration: Codable, Equatable, Sendable {
    public var queueDepth: Int
    public var redundancy: Int

    public init(queueDepth: Int = 4, redundancy: Int = 1) {
        self.queueDepth = queueDepth
        self.redundancy = redundancy
    }
}

public enum ExternalConnectorSessionError: Error, Equatable, Sendable {
    case unknownArgument(String)
    case duplicateArgument(String)
    case missingValue(String)
    case missingRequiredArgument(String)
    case invalidConnector(String)
    case invalidRole(String)
    case invalidConnectionSide(String)
    case invalidMediaMode(String)
    case invalidControlTransport(String)
    case invalidBoolean(String)
    case invalidPositiveInteger(String, String)
    case invalidPort(String, String)
    case emptyField(String)
    case emptyList(String)
    case missingSourceReference(ExternalConnectorKind)
    case connectorDoesNotSupportMediaMode(ExternalConnectorKind, ExternalConnectorMediaMode)
    case connectorDoesNotSupportRawLink(ExternalConnectorKind)
    case rawLinkRequiresLoLaConnector
    case lolaRequiresPeerForTx
    case connectorRequiresPeerForTx(ExternalConnectorKind)
    case externalConnectorRequiresExecutable(ExternalConnectorKind)
    case invalidLoLaSessionID(String)
    case dryRunCannotPass
    case processLaunchFailed(String)
    case invalidProcessArgument(String, String)
    case socketFailed(String)
    case receiveTimedOut
    case malformedLoLaControlMessage(String)
    case placeholderValue(String), inconsistentShellCommand(String)
}

public struct ExternalConnectorSessionConfiguration: Codable, Equatable, Sendable {
    public var connector: ExternalConnectorKind
    public var role: ExternalConnectorSessionRole
    public var peer: String
    public var localHost: String
    public var executable: String?
    public var videoExecutable: String?
    public var outputPath: String
    public var dryRun: Bool
    public var mediaMode: ExternalConnectorMediaMode
    public var controlTransport: ExternalConnectorControlTransport
    public var durationSeconds: Int
    public var controlPort: UInt16
    public var audioPort: UInt16
    public var peerAudioPort: UInt16?
    public var videoPort: UInt16
    public var channels: Int
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoFrameRate: Int
    public var videoBitsPerPixel: Int
    public var lolaVideoPayload: LoLaVideoPayloadKind
    public var videoCompression: Int
    public var videoBayer: Int
    public var audioCapture: String?
    public var audioPlayback: String?
    public var videoCapture: String?
    public var videoDisplay: String?
    public var sessionID: String
    public var rawLinkInterface: String?
    public var sourceMAC: LoLaEthernetAddress?
    public var destinationMAC: LoLaEthernetAddress?
    public var mediaPacketCount: Int
    public var fullDuplex: Bool
    public var jackTrip: JackTripRunConfiguration

    public init(
        connector: ExternalConnectorKind,
        role: ExternalConnectorSessionRole,
        peer: String,
        localHost: String = "0.0.0.0",
        executable: String? = nil,
        videoExecutable: String? = nil,
        outputPath: String,
        dryRun: Bool = true,
        mediaMode: ExternalConnectorMediaMode? = nil,
        controlTransport: ExternalConnectorControlTransport? = nil,
        durationSeconds: Int = 1,
        controlPort: UInt16? = nil,
        audioPort: UInt16? = nil,
        peerAudioPort: UInt16? = nil,
        videoPort: UInt16? = nil,
        channels: Int = 2,
        sampleRateHertz: Int? = nil,
        framesPerPacket: Int? = nil,
        videoWidth: Int = 1920,
        videoHeight: Int = 1080,
        videoFrameRate: Int = 30,
        videoBitsPerPixel: Int = 24,
        lolaVideoPayload: LoLaVideoPayloadKind = .generated,
        videoCompression: Int = 0,
        videoBayer: Int = 0,
        audioCapture: String? = nil,
        audioPlayback: String? = nil,
        videoCapture: String? = nil,
        videoDisplay: String? = nil,
        sessionID: String = "1",
        rawLinkInterface: String? = nil,
        sourceMAC: LoLaEthernetAddress? = nil,
        destinationMAC: LoLaEthernetAddress? = nil,
        mediaPacketCount: Int = 1,
        fullDuplex: Bool = true,
        jackTrip: JackTripRunConfiguration = JackTripRunConfiguration()
    ) {
        self.connector = connector
        self.role = role
        self.peer = peer
        self.localHost = localHost
        self.executable = executable
        self.videoExecutable = videoExecutable
        self.outputPath = outputPath
        self.dryRun = dryRun
        self.mediaMode = mediaMode ?? defaultMediaMode(for: connector)
        self.controlTransport = controlTransport ?? defaultControlTransport(for: connector)
        self.durationSeconds = durationSeconds
        self.controlPort = controlPort ?? defaultControlPort(for: connector)
        self.audioPort = audioPort ?? defaultAudioPort(for: connector)
        self.peerAudioPort = peerAudioPort
        self.videoPort = videoPort ?? defaultVideoPort(for: connector)
        self.channels = channels
        self.sampleRateHertz = sampleRateHertz ?? defaultSampleRate(for: connector)
        self.framesPerPacket = framesPerPacket ?? defaultFramesPerPacket(for: connector)
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.videoFrameRate = videoFrameRate
        self.videoBitsPerPixel = videoBitsPerPixel
        self.lolaVideoPayload = lolaVideoPayload
        self.videoCompression = videoCompression
        self.videoBayer = videoBayer
        self.audioCapture = audioCapture
        self.audioPlayback = audioPlayback
        self.videoCapture = videoCapture
        self.videoDisplay = videoDisplay
        self.sessionID = sessionID
        self.rawLinkInterface = rawLinkInterface
        self.sourceMAC = sourceMAC
        self.destinationMAC = destinationMAC
        self.mediaPacketCount = mediaPacketCount
        self.fullDuplex = fullDuplex
        self.jackTrip = jackTrip
    }

    public static func parse(_ arguments: [String]) throws -> ExternalConnectorSessionConfiguration {
        let allowed = Set([
            "--connector",
            "--role",
            "--peer",
            "--local-host",
            "--executable",
            "--video-executable",
            "--output",
            "--dry-run",
            "--media",
            "--control-transport",
            "--duration-seconds",
            "--control-port",
            "--audio-port",
            "--peer-audio-port",
            "--video-port",
            "--channels",
            "--sample-rate",
            "--frames",
            "--video-width",
            "--video-height",
            "--video-fps",
            "--video-bpp",
            "--lola-video-payload",
            "--video-compression",
            "--video-bayer",
            "--audio-capture",
            "--audio-playback",
            "--video-capture",
            "--video-display",
            "--session-id",
            "--raw-link-interface",
            "--source-mac",
            "--destination-mac",
            "--media-packets",
            "--full-duplex",
            "--jacktrip-queue-depth",
            "--jacktrip-redundancy",
        ])
        let values = try parseExternalConnectorKeyValueArguments(arguments, allowed: allowed)

        let connector = try parseExternalConnectorKind(try requiredExternalConnectorValue("--connector", values))
        let role = try parseExternalConnectorSessionRole(try requiredExternalConnectorValue("--role", values))
        let mediaMode = try values["--media"].map(parseExternalConnectorMediaMode)
        let controlTransport = try values["--control-transport"].map(parseExternalConnectorControlTransport)
        let lolaVideoPayload = try values["--lola-video-payload"].map(parseLoLaVideoPayloadKind)

        return ExternalConnectorSessionConfiguration(
            connector: connector,
            role: role,
            peer: values["--peer"] ?? "",
            localHost: values["--local-host"] ?? "0.0.0.0",
            executable: values["--executable"],
            videoExecutable: values["--video-executable"],
            outputPath: try requiredExternalConnectorValue("--output", values),
            dryRun: try optionalExternalConnectorBoolean("--dry-run", values) ?? true,
            mediaMode: mediaMode,
            controlTransport: controlTransport,
            durationSeconds: try optionalExternalConnectorPositiveInteger("--duration-seconds", values) ?? 1,
            controlPort: try optionalExternalConnectorPort("--control-port", values),
            audioPort: try optionalExternalConnectorPort("--audio-port", values),
            peerAudioPort: try optionalExternalConnectorPort("--peer-audio-port", values),
            videoPort: try optionalExternalConnectorPort("--video-port", values),
            channels: try optionalExternalConnectorPositiveInteger("--channels", values) ?? 2,
            sampleRateHertz: try optionalExternalConnectorPositiveInteger("--sample-rate", values),
            framesPerPacket: try optionalExternalConnectorPositiveInteger("--frames", values),
            videoWidth: try optionalExternalConnectorPositiveInteger("--video-width", values) ?? 1920,
            videoHeight: try optionalExternalConnectorPositiveInteger("--video-height", values) ?? 1080,
            videoFrameRate: try optionalExternalConnectorPositiveInteger("--video-fps", values) ?? 30,
            videoBitsPerPixel: try optionalExternalConnectorPositiveInteger("--video-bpp", values) ?? 24,
            lolaVideoPayload: lolaVideoPayload ?? .generated,
            videoCompression: try optionalExternalConnectorNonNegativeInteger("--video-compression", values) ?? 0,
            videoBayer: try optionalExternalConnectorNonNegativeInteger("--video-bayer", values) ?? 0,
            audioCapture: values["--audio-capture"],
            audioPlayback: values["--audio-playback"],
            videoCapture: values["--video-capture"],
            videoDisplay: values["--video-display"],
            sessionID: values["--session-id"] ?? "1",
            rawLinkInterface: values["--raw-link-interface"],
            sourceMAC: try values["--source-mac"].map(parseLoLaEthernetAddress),
            destinationMAC: try values["--destination-mac"].map(parseLoLaEthernetAddress),
            mediaPacketCount: try optionalExternalConnectorPositiveInteger("--media-packets", values) ?? 1,
            fullDuplex: try optionalExternalConnectorBoolean("--full-duplex", values) ?? true,
            jackTrip: JackTripRunConfiguration(
                queueDepth: try optionalExternalConnectorPositiveInteger("--jacktrip-queue-depth", values) ?? 4,
                redundancy: try optionalExternalConnectorPositiveInteger("--jacktrip-redundancy", values) ?? 1
            )
        )
    }
}

public struct ExternalConnectorMediaProfile: Codable, Equatable, Sendable {
    public var mode: ExternalConnectorMediaMode
    public var audioEnabled: Bool
    public var videoEnabled: Bool
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var channels: Int
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoFrameRate: Int
    public var videoBitsPerPixel: Int

    public static func build(
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> ExternalConnectorMediaProfile {
        try validateMediaMode(configuration.mediaMode, connector: configuration.connector)
        return ExternalConnectorMediaProfile(
            mode: configuration.mediaMode,
            audioEnabled: configuration.mediaMode.hasAudio,
            videoEnabled: configuration.mediaMode.hasVideo,
            sampleRateHertz: configuration.sampleRateHertz,
            framesPerPacket: configuration.framesPerPacket,
            channels: configuration.channels,
            videoWidth: configuration.mediaMode.hasVideo ? configuration.videoWidth : 0,
            videoHeight: configuration.mediaMode.hasVideo ? configuration.videoHeight : 0,
            videoFrameRate: configuration.mediaMode.hasVideo ? configuration.videoFrameRate : 0,
            videoBitsPerPixel: configuration.mediaMode.hasVideo ? configuration.videoBitsPerPixel : 0
        )
    }
}

public struct ExternalConnectorLaunchPlan: Codable, Equatable, Sendable {
    public var connector: ExternalConnectorKind
    public var role: ExternalConnectorSessionRole
    public var launchKind: ExternalConnectorLaunchKind
    public var executable: String?
    public var arguments: [String]
    public var auxiliaryProcesses: [ExternalConnectorAuxiliaryProcessPlan] = []
    public var peer: String
    public var localHost: String
    public var controlPort: UInt16
    public var audioPort: UInt16
    public var videoPort: UInt16
    public var mediaProfile: ExternalConnectorMediaProfile
    public var channels: Int
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var protocolFacts: [String]
    public var sourceReferences: [String]
    public var evidenceBoundary: String

    public static func build(
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> ExternalConnectorLaunchPlan {
        try validateExternalConnectorRuntimeInputs(configuration)
        if configuration.connector != .lola, configuration.rawLinkInterface != nil || configuration.sourceMAC != nil || configuration.destinationMAC != nil {
            throw ExternalConnectorSessionError.connectorDoesNotSupportRawLink(configuration.connector)
        }
        switch configuration.connector {
        case .lola:
            return try buildLoLaPlan(configuration)
        case .mvtpUltraGrid:
            return try buildUltraGridPlan(configuration)
        case .jackTrip:
            return try buildJackTripPlan(configuration)
        }
    }
}

private func validateExternalConnectorRuntimeInputs(
    _ configuration: ExternalConnectorSessionConfiguration
) throws {
    guard configuration.durationSeconds >= 0 else {
        throw ExternalConnectorSessionError.invalidPositiveInteger(
            "durationSeconds",
            String(configuration.durationSeconds)
        )
    }
    if configuration.connector == .lola {
        try validateExternalConnectorPort(configuration.controlPort, "controlPort")
    }
    try validateExternalConnectorPort(configuration.audioPort, "audioPort")
    try validateExternalConnectorPort(configuration.videoPort, "videoPort")
    if configuration.connector == .jackTrip {
        guard configuration.jackTrip.queueDepth > 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "jackTrip.queueDepth",
                String(configuration.jackTrip.queueDepth)
            )
        }
        guard configuration.jackTrip.redundancy > 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "jackTrip.redundancy",
                String(configuration.jackTrip.redundancy)
            )
        }
    }
}

private func validateExternalConnectorPort(_ port: UInt16, _ field: String) throws {
    guard port > 0 else {
        throw ExternalConnectorSessionError.invalidPort(field, String(port))
    }
}

public struct ExternalConnectorAuxiliaryProcessPlan: Codable, Equatable, Sendable {
    public var label: String
    public var executable: String
    public var arguments: [String]
    public var mediaMode: ExternalConnectorMediaMode
    public var protocolFacts: [String]
    public var sourceReferences: [String]

    public init(
        label: String,
        executable: String,
        arguments: [String],
        mediaMode: ExternalConnectorMediaMode,
        protocolFacts: [String],
        sourceReferences: [String]
    ) {
        self.label = label
        self.executable = executable
        self.arguments = arguments
        self.mediaMode = mediaMode
        self.protocolFacts = protocolFacts
        self.sourceReferences = sourceReferences
    }
}

public struct ExternalConnectorProcessResult: Codable, Equatable, Sendable {
    public var launched: Bool
    public var processIdentifier: Int32?
    public var exitStatus: Int32?
    public var terminatedAfterDuration: Bool
    public var standardOutputPrefix: String
    public var standardErrorPrefix: String
    public var error: String?

    public init(
        launched: Bool,
        processIdentifier: Int32? = nil,
        exitStatus: Int32? = nil,
        terminatedAfterDuration: Bool = false,
        standardOutputPrefix: String = "",
        standardErrorPrefix: String = "",
        error: String? = nil
    ) {
        self.launched = launched
        self.processIdentifier = processIdentifier
        self.exitStatus = exitStatus
        self.terminatedAfterDuration = terminatedAfterDuration
        self.standardOutputPrefix = standardOutputPrefix
        self.standardErrorPrefix = standardErrorPrefix
        self.error = error
    }
}

public struct LoLaControlExchange: Codable, Equatable, Sendable {
    public var sentMessage: String?
    public var receivedMessage: String?
    public var sentMessages: [String]
    public var receivedMessages: [String]
    public var opaqueControlDatagrams: [LoLaOpaqueControlDatagram]
    public var parsedMessageName: String?
    public var fields: [String: String]
    public var bytesTransferred: Int

    public init(
        sentMessage: String? = nil,
        receivedMessage: String? = nil,
        sentMessages: [String] = [],
        receivedMessages: [String] = [],
        opaqueControlDatagrams: [LoLaOpaqueControlDatagram] = [],
        parsedMessageName: String? = nil,
        fields: [String: String] = [:],
        bytesTransferred: Int = 0
    ) {
        self.sentMessage = sentMessage
        self.receivedMessage = receivedMessage
        self.sentMessages = sentMessages
        self.receivedMessages = receivedMessages
        self.opaqueControlDatagrams = opaqueControlDatagrams
        self.parsedMessageName = parsedMessageName
        self.fields = fields
        self.bytesTransferred = bytesTransferred
    }

    private enum CodingKeys: String, CodingKey {
        case sentMessage
        case receivedMessage
        case sentMessages
        case receivedMessages
        case opaqueControlDatagrams
        case parsedMessageName
        case fields
        case bytesTransferred
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sentMessage = try container.decodeIfPresent(String.self, forKey: .sentMessage)
        receivedMessage = try container.decodeIfPresent(String.self, forKey: .receivedMessage)
        sentMessages = try container.decodeIfPresent([String].self, forKey: .sentMessages) ?? []
        receivedMessages = try container.decodeIfPresent([String].self, forKey: .receivedMessages) ?? []
        opaqueControlDatagrams = try container.decodeIfPresent(
            [LoLaOpaqueControlDatagram].self,
            forKey: .opaqueControlDatagrams
        ) ?? []
        parsedMessageName = try container.decodeIfPresent(String.self, forKey: .parsedMessageName)
        fields = try container.decodeIfPresent([String: String].self, forKey: .fields) ?? [:]
        bytesTransferred = try container.decode(Int.self, forKey: .bytesTransferred)
    }
}

public struct LoLaOpaqueControlDatagram: Codable, Equatable, Sendable {
    public var classification: String
    public var sourceHost: String
    public var sourcePort: UInt16
    public var destinationPort: UInt16
    public var payloadLength: Int
    public var firstByte: UInt8?
    public var hexPrefix: String

    public init(
        classification: String = "opaque-control-datagram",
        sourceHost: String,
        sourcePort: UInt16,
        destinationPort: UInt16,
        payloadLength: Int,
        firstByte: UInt8?,
        hexPrefix: String
    ) {
        self.classification = classification
        self.sourceHost = sourceHost
        self.sourcePort = sourcePort
        self.destinationPort = destinationPort
        self.payloadLength = payloadLength
        self.firstByte = firstByte
        self.hexPrefix = hexPrefix
    }

    public static func classify(
        payload: [UInt8],
        sourceHost: String,
        sourcePort: UInt16,
        destinationPort: UInt16,
        prefixByteCount: Int = 16
    ) -> LoLaOpaqueControlDatagram {
        LoLaOpaqueControlDatagram(
            sourceHost: sourceHost,
            sourcePort: sourcePort,
            destinationPort: destinationPort,
            payloadLength: payload.count,
            firstByte: payload.first,
            hexPrefix: payload.prefix(max(0, prefixByteCount)).map {
                String(format: "%02x", $0)
            }.joined()
        )
    }
}

public struct ExternalConnectorSessionReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var connector: ExternalConnectorKind
    public var role: ExternalConnectorSessionRole
    public var dryRun: Bool
    public var plan: ExternalConnectorLaunchPlan
    public var process: ExternalConnectorProcessResult?
    public var auxiliaryProcesses: [ExternalConnectorProcessResult]
    public var lolaControl: LoLaControlExchange?
    public var lolaControlRetryResponder: LoLaControlRetryResponderReport?
    public var lolaMedia: LoLaCompatibilityMediaSessionReport?
    public var runtimeError: String?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        connector: ExternalConnectorKind,
        role: ExternalConnectorSessionRole,
        dryRun: Bool,
        plan: ExternalConnectorLaunchPlan,
        process: ExternalConnectorProcessResult?,
        auxiliaryProcesses: [ExternalConnectorProcessResult] = [],
        lolaControl: LoLaControlExchange?,
        lolaControlRetryResponder: LoLaControlRetryResponderReport? = nil,
        lolaMedia: LoLaCompatibilityMediaSessionReport? = nil,
        runtimeError: String? = nil,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.connector = connector
        self.role = role
        self.dryRun = dryRun
        self.plan = plan
        self.process = process
        self.auxiliaryProcesses = auxiliaryProcesses
        self.lolaControl = lolaControl
        self.lolaControlRetryResponder = lolaControlRetryResponder
        self.lolaMedia = lolaMedia
        self.runtimeError = runtimeError
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try requireExternalConnectorSessionNonEmpty(id, "id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "capturedAt")
        try requireExternalConnectorSessionNonEmpty(notes, "notes")
        if verdict == .pass, dryRun {
            throw ExternalConnectorSessionError.dryRunCannotPass
        }
        if plan.connector != connector {
            throw ExternalConnectorSessionError.invalidConnector(plan.connector.rawValue)
        }
        if plan.role != role {
            throw ExternalConnectorSessionError.invalidRole(plan.role.rawValue)
        }
        if plan.launchKind == .externalProcess, plan.executable == nil {
            throw ExternalConnectorSessionError.externalConnectorRequiresExecutable(connector)
        }
        if !dryRun, plan.launchKind == .externalProcess {
            if process == nil { throw ExternalConnectorSessionError.processLaunchFailed("missing primary process result") }
            if auxiliaryProcesses.count != plan.auxiliaryProcesses.count { throw ExternalConnectorSessionError.processLaunchFailed("auxiliary process result count mismatch") }
        }
        if verdict == .fail {
            try requireExternalConnectorSessionNonEmpty(runtimeError ?? "", "runtimeError")
        }
        try lolaMedia?.validate()
        try lolaControlRetryResponder?.validate()
        try validateAuxiliaryProcesses()
        try validateMediaMode(plan.mediaProfile.mode, connector: connector)
        if connector == .lola, role.transmits, plan.peer.isEmpty {
            throw ExternalConnectorSessionError.lolaRequiresPeerForTx
        }
        if role.transmits, plan.peer.isEmpty {
            throw ExternalConnectorSessionError.connectorRequiresPeerForTx(connector)
        }
        if plan.mediaProfile.audioEnabled != plan.mediaProfile.mode.hasAudio {
            throw ExternalConnectorSessionError.invalidMediaMode(plan.mediaProfile.mode.rawValue)
        }
        if plan.mediaProfile.videoEnabled != plan.mediaProfile.mode.hasVideo {
            throw ExternalConnectorSessionError.invalidMediaMode(plan.mediaProfile.mode.rawValue)
        }
        try requireExternalConnectorSessionNonEmptyList(plan.protocolFacts, "plan.protocolFacts")
        try requireExternalConnectorSessionNonEmptyList(plan.sourceReferences, "plan.sourceReferences")
        try validateSourceReferences()
    }

    private func validateAuxiliaryProcesses() throws {
        for auxiliary in plan.auxiliaryProcesses {
            try requireExternalConnectorSessionNonEmpty(auxiliary.label, "plan.auxiliaryProcesses.label")
            try requireExternalConnectorSessionNonEmpty(auxiliary.executable, "plan.auxiliaryProcesses.executable")
            try requireExternalConnectorSessionNonEmptyList(
                auxiliary.arguments,
                "plan.auxiliaryProcesses.arguments"
            )
            try requireExternalConnectorSessionNonEmptyList(
                auxiliary.protocolFacts,
                "plan.auxiliaryProcesses.protocolFacts"
            )
            try requireExternalConnectorSessionNonEmptyList(
                auxiliary.sourceReferences,
                "plan.auxiliaryProcesses.sourceReferences"
            )
        }
    }

    private func validateSourceReferences() throws {
        switch connector {
        case .lola:
            guard plan.sourceReferences.contains("docs/reverse-engineering/README.md") else {
                throw ExternalConnectorSessionError.missingSourceReference(connector)
            }
        case .mvtpUltraGrid:
            guard plan.sourceReferences.contains("https://github.com/CESNET/UltraGrid") else {
                throw ExternalConnectorSessionError.missingSourceReference(connector)
            }
        case .jackTrip:
            guard plan.sourceReferences.contains("https://github.com/jacktrip/jacktrip") else {
                throw ExternalConnectorSessionError.missingSourceReference(connector)
            }
        }
    }
}
