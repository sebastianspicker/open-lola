// Defines external connector session settings, launch plans, process outcomes, and control exchange records.
import Darwin
import Foundation

/// Defines failures reported when external connector session error cannot continue.
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

/// Defines the validated fields for external connector session config input.
public struct ExternalConnectorSessionConfigInput: Equatable, Sendable {
    public var connector: ExternalConnectorKind
    public var role: ExternalConnectorSessionRole
    public var peer: String
    public var localHost: String = "0.0.0.0"
    public var executable: String?
    public var videoExecutable: String?
    public var outputPath: String
    public var dryRun: Bool = true
    public var mediaMode: ExternalConnectorMediaMode?
    public var controlTransport: ExternalConnectorControlTransport?
    public var durationSeconds: Int = 1
    public var controlPort: UInt16?
    public var audioPort: UInt16?
    public var peerAudioPort: UInt16?
    public var videoPort: UInt16?
    public var channels: Int = 2
    public var sampleRateHertz: Int?
    public var framesPerPacket: Int?
    public var videoWidth: Int = 1920
    public var videoHeight: Int = 1080
    public var videoFrameRate: Int = 30
    public var videoBitsPerPixel: Int = 24
    public var lolaVideoPayload: LoLaVideoPayloadKind = .generated
    public var videoCompression: Int = 0
    public var videoBayer: Int = 0
    public var audioCapture: String?
    public var audioPlayback: String?
    public var videoCapture: String?
    public var videoDisplay: String?
    public var sessionID: String = "1"
    public var rawLinkInterface: String?
    public var sourceMAC: LoLaEthernetAddress?
    public var destinationMAC: LoLaEthernetAddress?
    public var mediaPacketCount: Int = 1
    public var fullDuplex: Bool = true
    public var ultraGridTopologyMode: UltraGridTopologyMode = .directPeer
    public var ultraGridTopologyRole: UltraGridTopologyRole = .direct
    public var ultraGridAudioPayloadType: UInt8 = UltraGridCompatibility.audioPayloadType
    public var ultraGridVideoPayloadType: UInt8 = UltraGridCompatibility.videoPayloadType
    public var ultraGridFECMode: UltraGridFECMode = .none
    public var ultraGridEncryptionMode: UltraGridEncryptionMode = .none
    public var ultraGridEncryptionPassphrase: String?
    public var ultraGridControlMode: UltraGridControlMode = .disabled
    public var ultraGridControlCommands: [UltraGridControlCommand] = []
    public var jackTrip: JackTripRunConfiguration = JackTripRunConfiguration()

    public init(
        connector: ExternalConnectorKind,
        role: ExternalConnectorSessionRole,
        peer: String,
        outputPath: String,
        configure: (inout ExternalConnectorSessionConfigInput) -> Void = { _ in }
    ) {
        self.connector = connector
        self.role = role
        self.peer = peer
        self.outputPath = outputPath
        configure(&self)
    }
}

/// Defines the validated fields for external connector session configuration.
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

  public init(_ input: ExternalConnectorSessionConfigInput) {
    self.connector = input.connector
    self.role = input.role
    self.peer = input.peer
    self.localHost = input.localHost
    self.executable = input.executable
    self.videoExecutable = input.videoExecutable
    self.outputPath = input.outputPath
    self.dryRun = input.dryRun
    self.mediaMode = input.mediaMode ?? defaultMediaMode(for: input.connector)
    self.controlTransport = input.controlTransport ?? defaultControlTransport(for: input.connector)
    self.durationSeconds = input.durationSeconds
    self.controlPort = input.controlPort ?? defaultControlPort(for: input.connector)
    self.audioPort = input.audioPort ?? defaultAudioPort(for: input.connector)
    self.peerAudioPort = input.peerAudioPort
    self.videoPort = input.videoPort ?? defaultVideoPort(for: input.connector)
    self.channels = input.channels
    self.sampleRateHertz = input.sampleRateHertz ?? defaultSampleRate(for: input.connector)
    self.framesPerPacket = input.framesPerPacket ?? defaultFramesPerPacket(for: input.connector)
    self.videoWidth = input.videoWidth
    self.videoHeight = input.videoHeight
    self.videoFrameRate = input.videoFrameRate
    self.videoBitsPerPixel = input.videoBitsPerPixel
    self.lolaVideoPayload = input.lolaVideoPayload
    self.videoCompression = input.videoCompression
    self.videoBayer = input.videoBayer
    self.audioCapture = input.audioCapture
    self.audioPlayback = input.audioPlayback
    self.videoCapture = input.videoCapture
    self.videoDisplay = input.videoDisplay
    self.sessionID = input.sessionID
    self.rawLinkInterface = input.rawLinkInterface
    self.sourceMAC = input.sourceMAC
    self.destinationMAC = input.destinationMAC
    self.mediaPacketCount = input.mediaPacketCount
    self.fullDuplex = input.fullDuplex
    self.ultraGridTopologyMode = input.ultraGridTopologyMode
    self.ultraGridTopologyRole = input.ultraGridTopologyRole
    self.ultraGridAudioPayloadType = input.ultraGridAudioPayloadType
    self.ultraGridVideoPayloadType = input.ultraGridVideoPayloadType
    self.ultraGridFECMode = input.ultraGridFECMode
    self.ultraGridEncryptionMode = input.ultraGridEncryptionMode
    self.ultraGridEncryptionPassphrase = input.ultraGridEncryptionPassphrase
    self.ultraGridControlMode = input.ultraGridControlMode
    self.ultraGridControlCommands = input.ultraGridControlCommands
    self.jackTrip = input.jackTrip
  }

}

/// Defines the validated fields for external connector media profile.
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

/// Defines the validated fields for external connector launch plan.
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

/// Defines the validated fields for external connector auxiliary process plan.
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

/// Records launch, process, exit, output, cleanup, and error state for one external process.
public struct ExternalConnectorProcessResult: Codable, Equatable, Sendable {
  public var launched: Bool = false
  public var processIdentifier: Int32?
  public var exitStatus: Int32?
  public var terminatedAfterDuration: Bool = false
  public var standardOutputPrefix: String = ""
  public var standardErrorPrefix: String = ""
  public var waitStatusKnown: Bool?
  public var cleanupStatus: String?
  public var error: String?
}

/// Defines the validated fields for LoLa control exchange.
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
