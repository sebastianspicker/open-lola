import Darwin
import Foundation

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
    case runtimePassMissingEvidence(String)
    case runtimePassWithRuntimeError(String)
    case processLaunchFailed(String)
    case invalidProcessArgument(String, String)
    case socketFailed(String)
    case receiveTimedOut
    case malformedLoLaControlMessage(String)
    case unsupportedRuntimeMode(String)
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
    public var ultraGridTopologyMode: UltraGridTopologyMode
    public var ultraGridTopologyRole: UltraGridTopologyRole
    public var ultraGridAudioPayloadType: UInt8
    public var ultraGridVideoPayloadType: UInt8
    public var ultraGridFECMode: UltraGridFECMode
    public var ultraGridEncryptionMode: UltraGridEncryptionMode
    public var ultraGridEncryptionPassphrase: String?
    public var ultraGridControlMode: UltraGridControlMode
    public var ultraGridControlCommands: [UltraGridControlCommand]
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
        ultraGridTopologyMode: UltraGridTopologyMode = .directPeer,
        ultraGridTopologyRole: UltraGridTopologyRole = .direct,
        ultraGridAudioPayloadType: UInt8 = UltraGridCompatibility.audioPayloadType,
        ultraGridVideoPayloadType: UInt8 = UltraGridCompatibility.videoPayloadType,
        ultraGridFECMode: UltraGridFECMode = .none,
        ultraGridEncryptionMode: UltraGridEncryptionMode = .none,
        ultraGridEncryptionPassphrase: String? = nil,
        ultraGridControlMode: UltraGridControlMode = .disabled,
        ultraGridControlCommands: [UltraGridControlCommand] = [],
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
        self.ultraGridTopologyMode = ultraGridTopologyMode
        self.ultraGridTopologyRole = ultraGridTopologyRole
        self.ultraGridAudioPayloadType = ultraGridAudioPayloadType
        self.ultraGridVideoPayloadType = ultraGridVideoPayloadType
        self.ultraGridFECMode = ultraGridFECMode
        self.ultraGridEncryptionMode = ultraGridEncryptionMode
        self.ultraGridEncryptionPassphrase = ultraGridEncryptionPassphrase
        self.ultraGridControlMode = ultraGridControlMode
        self.ultraGridControlCommands = ultraGridControlCommands
        self.jackTrip = jackTrip
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
        try validateRawLinkSupport(configuration)
        switch configuration.connector {
        case .lola:
            return try buildLoLaPlan(configuration)
        case .mvtpUltraGrid:
            return try buildUltraGridPlan(configuration)
        case .jackTrip:
            return try buildJackTripPlan(configuration)
        }
    }

    private static func validateRawLinkSupport(_ configuration: ExternalConnectorSessionConfiguration) throws {
        guard configuration.connector != .lola, configuration.rawLinkInterface != nil
                || configuration.sourceMAC != nil
                || configuration.destinationMAC != nil else {
            return
        }
        throw ExternalConnectorSessionError.connectorDoesNotSupportRawLink(configuration.connector)
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
    public var waitStatusKnown: Bool?
    public var cleanupStatus: String?
    public var error: String?

    public init(
        launched: Bool,
        processIdentifier: Int32? = nil,
        exitStatus: Int32? = nil,
        terminatedAfterDuration: Bool = false,
        standardOutputPrefix: String = "",
        standardErrorPrefix: String = "",
        waitStatusKnown: Bool? = nil,
        cleanupStatus: String? = nil,
        error: String? = nil
    ) {
        self.launched = launched
        self.processIdentifier = processIdentifier
        self.exitStatus = exitStatus
        self.terminatedAfterDuration = terminatedAfterDuration
        self.standardOutputPrefix = standardOutputPrefix
        self.standardErrorPrefix = standardErrorPrefix
        self.waitStatusKnown = waitStatusKnown
        self.cleanupStatus = cleanupStatus
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
    public var ultraGridMedia: UltraGridCompatibilityMediaReport?
    public var jackTripMedia: JackTripCompatibilityMediaReport?
    public var runtimeError: String?
    public var runtimeErrorFree: Bool?
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
        ultraGridMedia: UltraGridCompatibilityMediaReport? = nil,
        jackTripMedia: JackTripCompatibilityMediaReport? = nil,
        runtimeError: String? = nil,
        runtimeErrorFree: Bool? = nil,
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
        self.ultraGridMedia = ultraGridMedia
        self.jackTripMedia = jackTripMedia
        self.runtimeError = runtimeError
        self.runtimeErrorFree = runtimeErrorFree ?? (runtimeError == nil)
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
        try validateProcessResultShape()
        if verdict == .fail {
            try requireExternalConnectorSessionNonEmpty(runtimeError ?? "", "runtimeError")
        }
        try lolaMedia?.validate()
        try ultraGridMedia?.validate()
        try jackTripMedia?.validate()
        try lolaControlRetryResponder?.validate()
        try validateAuxiliaryProcesses()
        try validateMediaMode(plan.mediaProfile.mode, connector: connector)
        if verdict == .pass {
            try validatePassEvidence()
        }
        try validateTransmitPeer()
        try validateMediaProfileFlags()
        try requireExternalConnectorSessionNonEmptyList(plan.protocolFacts, "plan.protocolFacts")
        try requireExternalConnectorSessionNonEmptyList(plan.sourceReferences, "plan.sourceReferences")
        try validateSourceReferences()
    }

    private func validateTransmitPeer() throws {
        guard role.transmits, plan.peer.isEmpty else {
            return
        }
        if connector == .lola {
            throw ExternalConnectorSessionError.lolaRequiresPeerForTx
        }
        throw ExternalConnectorSessionError.connectorRequiresPeerForTx(connector)
    }

    private func validateMediaProfileFlags() throws {
        guard plan.mediaProfile.audioEnabled == plan.mediaProfile.mode.hasAudio,
              plan.mediaProfile.videoEnabled == plan.mediaProfile.mode.hasVideo else {
            throw ExternalConnectorSessionError.invalidMediaMode(plan.mediaProfile.mode.rawValue)
        }
    }

    private func validateProcessResultShape() throws {
        guard !dryRun, plan.launchKind == .externalProcess else {
            return
        }
        guard process != nil else {
            throw ExternalConnectorSessionError.processLaunchFailed("missing primary process result")
        }
        guard auxiliaryProcesses.count == plan.auxiliaryProcesses.count else {
            throw ExternalConnectorSessionError.processLaunchFailed("auxiliary process result count mismatch")
        }
    }

    private func validatePassEvidence() throws {
        guard runtimeError == nil else {
            throw ExternalConnectorSessionError.runtimePassWithRuntimeError("runtimeError")
        }
        guard runtimeErrorFree == true else {
            throw ExternalConnectorSessionError.runtimePassWithRuntimeError("runtimeErrorFree")
        }
        try validateProcessPassEvidence()
        switch connector {
        case .lola:
            try validateLoLaPassEvidence()
        case .mvtpUltraGrid:
            try validateUltraGridPassEvidence()
        case .jackTrip:
            try validateJackTripPassEvidence()
        }
    }

    private func validateLoLaPassEvidence() throws {
        guard lolaControl != nil else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence("lolaControl")
        }
        guard let lolaMedia else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence("lolaMedia")
        }
        guard lolaMedia.runtimeError == nil else {
            throw ExternalConnectorSessionError.runtimePassWithRuntimeError("lolaMedia.runtimeError")
        }
        guard lolaMedia.verdict == .pass else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence("lolaMedia.verdict")
        }
    }

    private func validateUltraGridPassEvidence() throws {
        guard let ultraGridMedia else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence("ultraGridMedia")
        }
        try validatePassMediaEvidence(
            runtimeError: ultraGridMedia.runtimeError,
            runtimeErrorFree: ultraGridMedia.runtimeErrorFree,
            verdict: ultraGridMedia.verdict,
            prefix: "ultraGridMedia"
        )
    }

    private func validateJackTripPassEvidence() throws {
        guard let jackTripMedia else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence("jackTripMedia")
        }
        try validatePassMediaEvidence(
            runtimeError: jackTripMedia.runtimeError,
            runtimeErrorFree: jackTripMedia.runtimeErrorFree,
            verdict: jackTripMedia.verdict,
            prefix: "jackTripMedia"
        )
    }

    private func validatePassMediaEvidence(
        runtimeError: String?,
        runtimeErrorFree: Bool?,
        verdict: MeasurementVerdict,
        prefix: String
    ) throws {
        guard runtimeError == nil else {
            throw ExternalConnectorSessionError.runtimePassWithRuntimeError("\(prefix).runtimeError")
        }
        guard runtimeErrorFree == true else {
            throw ExternalConnectorSessionError.runtimePassWithRuntimeError("\(prefix).runtimeErrorFree")
        }
        guard verdict == .pass else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence("\(prefix).verdict")
        }
    }

    private func validateProcessPassEvidence() throws {
        if plan.launchKind == .externalProcess {
            guard let process else {
                throw ExternalConnectorSessionError.processLaunchFailed("missing primary process result")
            }
            try validatePassProcessResult(process, label: "primary")
        }
        for (index, auxiliary) in auxiliaryProcesses.enumerated() {
            try validatePassProcessResult(auxiliary, label: "auxiliary \(index)")
        }
    }

    private func validatePassProcessResult(
        _ result: ExternalConnectorProcessResult,
        label: String
    ) throws {
        guard result.launched else {
            throw ExternalConnectorSessionError.processLaunchFailed(
                "\(label) process launch failed: \(result.error ?? "unknown error")"
            )
        }
        if result.waitStatusKnown == false {
            throw ExternalConnectorSessionError.processLaunchFailed("\(label) process exit status unknown")
        }
        if let cleanupStatus = result.cleanupStatus, cleanupStatus.hasPrefix("failed:") {
            throw ExternalConnectorSessionError.processLaunchFailed("\(label) process cleanup \(cleanupStatus)")
        }
        if !result.terminatedAfterDuration, let exitStatus = result.exitStatus {
            throw ExternalConnectorSessionError.processLaunchFailed(
                exitStatus == 0
                    ? "\(label) process exited before duration with status 0"
                    : "\(label) process exited with status \(exitStatus)"
            )
        }
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
            guard plan.sourceReferences.contains("docs/reverse-engineering-boundary.md") else {
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
