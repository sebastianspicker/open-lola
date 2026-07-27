// Parses connector-specific CLI options into a validated session configuration, rejecting arguments that do not apply to the selected connector.
extension ExternalConnectorSessionConfiguration {
    private static let allowedArguments = Set([
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
        "--ultragrid-topology",
        "--ultragrid-topology-role",
        "--ultragrid-audio-payload-type",
        "--ultragrid-video-payload-type",
        "--ultragrid-fec",
        "--ultragrid-encryption",
        "--ultragrid-encryption-passphrase",
        "--ultragrid-control",
        "--ultragrid-control-command",
        "--jacktrip-queue-depth",
        "--jacktrip-redundancy",
        "--jacktrip-bit-resolution",
        "--jacktrip-audio-backend",
        "--jacktrip-topology",
        "--jacktrip-topology-role",
        "--jacktrip-hub-patch",
        "--jacktrip-hub-tcp-handshake",
        "--jacktrip-remote-client-name",
        "--jacktrip-header",
        "--jacktrip-transport",
        "--jacktrip-plugin",
        "--jacktrip-payload-encoding"
    ])

    private static let ultraGridOnlyArguments = Set([
        "--ultragrid-topology",
        "--ultragrid-topology-role",
        "--ultragrid-audio-payload-type",
        "--ultragrid-video-payload-type",
        "--ultragrid-fec",
        "--ultragrid-encryption",
        "--ultragrid-encryption-passphrase",
        "--ultragrid-control",
        "--ultragrid-control-command"
    ])

    private static let jackTripOnlyArguments = Set([
        "--jacktrip-queue-depth",
        "--jacktrip-redundancy",
        "--jacktrip-bit-resolution",
        "--jacktrip-audio-backend",
        "--jacktrip-topology",
        "--jacktrip-topology-role",
        "--jacktrip-hub-patch",
        "--jacktrip-hub-tcp-handshake",
        "--jacktrip-remote-client-name",
        "--jacktrip-header",
        "--jacktrip-transport",
        "--jacktrip-plugin",
        "--jacktrip-payload-encoding"
    ])

    private static let loLaRawLinkOnlyArguments = Set([
        "--raw-link-interface",
        "--source-mac",
        "--destination-mac"
    ])

    private static let loLaControlOnlyArguments = Set([
        "--video-compression",
        "--video-bayer"
    ])

    private static let ignoredByJackTripVideoArguments = Set([
        "--lola-video-payload"
    ])

    public static func parse(_ arguments: [String]) throws -> ExternalConnectorSessionConfiguration {
        let parsed = try parseExternalConnectorKeyValueArguments(
            arguments,
            allowed: allowedArguments,
            repeatableKeys: ["--ultragrid-control-command"]
        )
        let values = parsed.values
        let connector = try parseExternalConnectorKind(try requiredExternalConnectorValue("--connector", values))
        try rejectMismatchedConnectorArguments(
            connector: connector,
            values: values,
            repeatedValues: parsed.repeatedValues
        )
        return try makeConfiguration(
            connector: connector,
            values: values,
            ultraGridControlCommands: parsed.repeatedValues(for: "--ultragrid-control-command")
        )
    }

    private static func makeConfiguration(
        connector: ExternalConnectorKind,
        values: [String: String],
        ultraGridControlCommands: [String]
    ) throws -> ExternalConnectorSessionConfiguration {
        let input = try parseExternalConnectorSessionInput(
            connector: connector,
            values: values,
            ultraGridControlCommands: ultraGridControlCommands
        )
        return try makeExternalConnectorSessionConfiguration(input)
    }

    private static func parseExternalConnectorSessionInput(
        connector: ExternalConnectorKind,
        values: [String: String],
        ultraGridControlCommands: [String]
    ) throws -> ExternalConnectorSessionInput {
        let role = try parseExternalConnectorSessionRole(try requiredExternalConnectorValue("--role", values))
        let mediaMode = try values["--media"].map(parseExternalConnectorMediaMode)
        let controlTransport = try values["--control-transport"].map(parseExternalConnectorControlTransport)
        let lolaVideoPayload = try values["--lola-video-payload"].map(parseLoLaVideoPayloadKind)
        let ultraGrid = try parseUltraGridConnectorOptions(
            values: values,
            controlCommands: ultraGridControlCommands
        )
        let jackTrip = try parseJackTripRunConfiguration(values)

        return ExternalConnectorSessionInput(
            connector: connector,
            role: role,
            values: values,
            mediaMode: mediaMode,
            controlTransport: controlTransport,
            lolaVideoPayload: lolaVideoPayload,
            ultraGrid: ultraGrid,
            jackTrip: jackTrip
        )
    }

private struct ExternalConnectorSessionInput {
    var connector: ExternalConnectorKind
    var role: ExternalConnectorSessionRole
    var values: [String: String]
    var mediaMode: ExternalConnectorMediaMode?
    var controlTransport: ExternalConnectorControlTransport?
    var lolaVideoPayload: LoLaVideoPayloadKind?
    var ultraGrid: UltraGridConnectorOptions
    var jackTrip: JackTripRunConfiguration
}

private struct ExternalConnectorSessionParsedOptions {
    var outputPath: String
    var dryRun: Bool
    var durationSeconds: Int
    var controlPort: UInt16?
    var audioPort: UInt16?
    var peerAudioPort: UInt16?
    var videoPort: UInt16?
    var channels: Int
    var sampleRateHertz: Int?
    var framesPerPacket: Int?
    var videoWidth: Int
    var videoHeight: Int
    var videoFrameRate: Int
    var videoBitsPerPixel: Int
    var videoCompression: Int
    var videoBayer: Int
    var sourceMAC: LoLaEthernetAddress?
    var destinationMAC: LoLaEthernetAddress?
    var mediaPacketCount: Int
    var fullDuplex: Bool
}

private static func makeExternalConnectorSessionConfiguration(
_ input: ExternalConnectorSessionInput
) throws -> ExternalConnectorSessionConfiguration {
let values = input.values
let options = try parseExternalConnectorSessionParsedOptions(values)
return ExternalConnectorSessionConfiguration(.init(
connector: input.connector,
role: input.role,
peer: values["--peer"] ?? "",
outputPath: options.outputPath
) { config in
config.localHost = values["--local-host"] ?? "0.0.0.0"
config.executable = values["--executable"]
config.videoExecutable = values["--video-executable"]
config.dryRun = options.dryRun
config.mediaMode = input.mediaMode
config.controlTransport = input.controlTransport
config.durationSeconds = options.durationSeconds
config.controlPort = options.controlPort
config.audioPort = options.audioPort
config.peerAudioPort = options.peerAudioPort
config.videoPort = options.videoPort
config.channels = options.channels
config.sampleRateHertz = options.sampleRateHertz
config.framesPerPacket = options.framesPerPacket
config.videoWidth = options.videoWidth
config.videoHeight = options.videoHeight
config.videoFrameRate = options.videoFrameRate
config.videoBitsPerPixel = options.videoBitsPerPixel
config.lolaVideoPayload = input.lolaVideoPayload ?? .generated
config.videoCompression = options.videoCompression
config.videoBayer = options.videoBayer
config.audioCapture = values["--audio-capture"]
config.audioPlayback = values["--audio-playback"]
config.videoCapture = values["--video-capture"]
config.videoDisplay = values["--video-display"]
config.sessionID = values["--session-id"] ?? "1"
config.rawLinkInterface = values["--raw-link-interface"]
config.sourceMAC = options.sourceMAC
config.destinationMAC = options.destinationMAC
config.mediaPacketCount = options.mediaPacketCount
config.fullDuplex = options.fullDuplex
config.ultraGridTopologyMode = input.ultraGrid.topologyMode
config.ultraGridTopologyRole = input.ultraGrid.topologyRole
config.ultraGridAudioPayloadType = input.ultraGrid.audioPayloadType
config.ultraGridVideoPayloadType = input.ultraGrid.videoPayloadType
config.ultraGridFECMode = input.ultraGrid.fecMode
config.ultraGridEncryptionMode = input.ultraGrid.encryptionMode
config.ultraGridEncryptionPassphrase = input.ultraGrid.encryptionPassphrase
config.ultraGridControlMode = input.ultraGrid.controlMode
config.ultraGridControlCommands = input.ultraGrid.controlCommands
config.jackTrip = input.jackTrip
})
}

private static func parseExternalConnectorSessionParsedOptions(
_ values: [String: String]
) throws -> ExternalConnectorSessionParsedOptions {
let media = try parseExternalConnectorMediaOptionValues(values)
return ExternalConnectorSessionParsedOptions(
outputPath: try requiredExternalConnectorValue("--output", values),
dryRun: try optionalExternalConnectorBoolean("--dry-run", values) ?? true,
durationSeconds: media.durationSeconds,
controlPort: try optionalExternalConnectorPort("--control-port", values),
audioPort: try optionalExternalConnectorPort("--audio-port", values),
peerAudioPort: try optionalExternalConnectorPort("--peer-audio-port", values),
videoPort: try optionalExternalConnectorPort("--video-port", values),
channels: media.channels,
sampleRateHertz: media.sampleRateHertz,
framesPerPacket: media.framesPerPacket,
videoWidth: media.videoWidth,
videoHeight: media.videoHeight,
videoFrameRate: media.videoFrameRate,
videoBitsPerPixel: media.videoBitsPerPixel,
videoCompression: try optionalExternalConnectorNonNegativeInteger(
"--video-compression",
values
) ?? 0,
videoBayer: try optionalExternalConnectorNonNegativeInteger("--video-bayer", values) ?? 0,
sourceMAC: try values["--source-mac"].map(parseLoLaEthernetAddress),
destinationMAC: try values["--destination-mac"].map(parseLoLaEthernetAddress),
mediaPacketCount: try optionalExternalConnectorPositiveInteger("--media-packets", values) ?? 1,
fullDuplex: try optionalExternalConnectorBoolean("--full-duplex", values) ?? true
)
}
private struct UltraGridConnectorOptions {
        var topologyMode: UltraGridTopologyMode
        var topologyRole: UltraGridTopologyRole
        var audioPayloadType: UInt8
        var videoPayloadType: UInt8
        var fecMode: UltraGridFECMode
        var encryptionMode: UltraGridEncryptionMode
        var encryptionPassphrase: String?
        var controlMode: UltraGridControlMode
        var controlCommands: [UltraGridControlCommand]
    }

    private static func parseUltraGridConnectorOptions(
        values: [String: String],
        controlCommands: [String]
    ) throws -> UltraGridConnectorOptions {
        UltraGridConnectorOptions(
            topologyMode: try values["--ultragrid-topology"].map(parseUltraGridTopologyMode) ?? .directPeer,
            topologyRole: try values["--ultragrid-topology-role"].map(parseUltraGridTopologyRole) ?? .direct,
            audioPayloadType: try parseUltraGridRTPPayloadType(
                "--ultragrid-audio-payload-type",
                values
            ) ?? UltraGridCompatibility.audioPayloadType,
            videoPayloadType: try parseUltraGridRTPPayloadType(
                "--ultragrid-video-payload-type",
                values
            ) ?? UltraGridCompatibility.videoPayloadType,
            fecMode: try values["--ultragrid-fec"].map(parseUltraGridFECMode) ?? .none,
            encryptionMode: try values["--ultragrid-encryption"].map(parseUltraGridEncryptionMode) ?? .none,
            encryptionPassphrase: values["--ultragrid-encryption-passphrase"],
            controlMode: try values["--ultragrid-control"].map(parseUltraGridControlMode) ?? .disabled,
            controlCommands: try controlCommands.map(UltraGridControlCommand.parse)
        )
    }

    private static func parseJackTripRunConfiguration(
 _ values: [String: String]
 ) throws -> JackTripRunConfiguration {
 var configuration = JackTripRunConfiguration()
 configuration.queueDepth = try optionalExternalConnectorPositiveInteger(
 "--jacktrip-queue-depth",
 values
 ) ?? configuration.queueDepth
 configuration.redundancy = try optionalExternalConnectorPositiveInteger("--jacktrip-redundancy", values) ?? 1
 configuration.bitResolutionBits = try optionalExternalConnectorPositiveInteger(
 "--jacktrip-bit-resolution",
 values
 ) ?? 16
 configuration.audioBackend = try values["--jacktrip-audio-backend"].map(parseJackTripAudioBackend) ?? .coreAudio
 configuration.topologyMode = try values["--jacktrip-topology"].map(parseJackTripTopologyMode) ?? .directPeer
 configuration.topologyRole = try values["--jacktrip-topology-role"].map(parseJackTripTopologyRole) ?? .direct
 configuration.hubPatchMode = try values["--jacktrip-hub-patch"].map(parseJackTripHubPatchMode) ?? .serverToClients
 configuration.hubTCPHandshakeMode = try values["--jacktrip-hub-tcp-handshake"].map(parseJackTripHubTCPHandshakeMode)
 ?? .none
 configuration.remoteClientName = values["--jacktrip-remote-client-name"]
 configuration.packetHeaderMode = try values["--jacktrip-header"].map(parseJackTripPacketHeaderMode) ?? .default
 configuration.transportMode = try values["--jacktrip-transport"].map(parseJackTripTransportMode) ?? .udp
 configuration.pluginMode = try values["--jacktrip-plugin"].map(parseJackTripPluginMode) ?? .disabled
 configuration.payloadEncoding = try values["--jacktrip-payload-encoding"].map(parseJackTripPayloadEncoding) ?? .pcm
 return configuration
 }

 private static func rejectMismatchedConnectorArguments(
        connector: ExternalConnectorKind,
        values: [String: String],
        repeatedValues: [String: [String]]
    ) throws {
        let presentArguments = Set(values.keys).union(repeatedValues.keys)
        let disallowedArguments: Set<String>
        switch connector {
        case .lola:
            disallowedArguments = ultraGridOnlyArguments.union(jackTripOnlyArguments)
        case .mvtpUltraGrid:
            disallowedArguments = jackTripOnlyArguments
                .union(loLaRawLinkOnlyArguments)
                .union(loLaControlOnlyArguments)
        case .jackTrip:
            disallowedArguments = ultraGridOnlyArguments
                .union(loLaRawLinkOnlyArguments)
                .union(loLaControlOnlyArguments)
                .union(ignoredByJackTripVideoArguments)
        }

        if let argument = presentArguments.intersection(disallowedArguments).sorted().first {
            throw ExternalConnectorSessionError.unknownArgument(argument)
        }
    }
}
