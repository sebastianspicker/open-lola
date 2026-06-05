import Foundation

public enum ExternalConnectorConnectionSide: String, Codable, Equatable, Sendable {
    case local
    case remote
    case both
}

public enum ExternalConnectorConnectionDirection: String, Codable, Equatable, Sendable {
    case localToRemote
    case remoteToLocal
    case bidirectional
}

public struct ExternalConnectorConnectionEndpoint: Codable, Equatable, Sendable {
    public var id: String
    public var side: ExternalConnectorConnectionSide
    public var direction: ExternalConnectorConnectionDirection
    public var role: ExternalConnectorSessionRole
    public var plan: ExternalConnectorLaunchPlan
    public var command: [String]
    public var shellCommand: String
}

public struct ExternalConnectorConnectionPlanConfiguration: Equatable, Sendable {
    public var connector: ExternalConnectorKind
    public var localHost: String
    public var remoteHost: String
    public var outputPath: String
    public var runDirectory: String
    public var executable: String?
    public var videoExecutable: String?
    public var mediaMode: ExternalConnectorMediaMode
    public var controlTransport: ExternalConnectorControlTransport
    public var durationSeconds: Int
    public var controlPort: UInt16?
    public var audioPort: UInt16?
    public var videoPort: UInt16?
    public var channels: Int
    public var sampleRateHertz: Int?
    public var framesPerPacket: Int?
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoFrameRate: Int
    public var videoBitsPerPixel: Int
    public var audioCapture: String?
    public var audioPlayback: String?
    public var videoCapture: String?
    public var videoDisplay: String?
    public var sessionID: String
    public var localRawLinkInterface: String?
    public var remoteRawLinkInterface: String?
    public var localMAC: LoLaEthernetAddress?
    public var remoteMAC: LoLaEthernetAddress?
    public var mediaPacketCount: Int
    public var ultraGridTopologyMode: UltraGridTopologyMode
    public var ultraGridFECMode: UltraGridFECMode
    public var jackTrip: JackTripRunConfiguration

    public static func parse(_ arguments: [String]) throws -> ExternalConnectorConnectionPlanConfiguration {
        let values = try parseExternalConnectorConnectionPlanValues(arguments)
        return try makeExternalConnectorConnectionPlanConfiguration(values)
    }
}

private let externalConnectorConnectionPlanArguments = Set([
    "--connector", "--local-host", "--remote-host", "--output", "--run-dir", "--media",
    "--control-transport", "--duration-seconds", "--channels", "--sample-rate",
    "--frames", "--control-port", "--audio-port", "--video-port",
    "--video-width", "--video-height", "--video-fps", "--video-bpp",
    "--executable", "--video-executable", "--audio-capture",
    "--audio-playback", "--video-capture", "--video-display", "--session-id",
    "--local-raw-link-interface", "--remote-raw-link-interface", "--local-mac",
    "--remote-mac", "--media-packets", "--jacktrip-audio-backend",
    "--jacktrip-topology", "--jacktrip-topology-role", "--jacktrip-hub-patch",
    "--jacktrip-hub-tcp-handshake", "--jacktrip-remote-client-name",
    "--ultragrid-topology", "--ultragrid-fec"
])

private func parseExternalConnectorConnectionPlanValues(_ arguments: [String]) throws -> [String: String] {
    try parseExternalConnectorKeyValueArguments(arguments, allowed: externalConnectorConnectionPlanArguments)
}

private func makeExternalConnectorConnectionPlanConfiguration(
    _ values: [String: String]
) throws -> ExternalConnectorConnectionPlanConfiguration {
    let connector = try parseExternalConnectorKind(try requiredExternalConnectorValue("--connector", values))
    let outputPath = try requiredExternalConnectorValue("--output", values)
    return ExternalConnectorConnectionPlanConfiguration(
        connector: connector,
        localHost: try requiredExternalConnectorValue("--local-host", values),
        remoteHost: try requiredExternalConnectorValue("--remote-host", values),
        outputPath: outputPath,
        runDirectory: values["--run-dir"] ?? defaultRunDirectory(forOutputPath: outputPath),
        executable: values["--executable"],
        videoExecutable: values["--video-executable"],
        mediaMode: try values["--media"].map(parseExternalConnectorMediaMode) ?? .audioVideo,
        controlTransport: try parsedConnectionPlanControlTransport(values, connector: connector),
        durationSeconds: try optionalExternalConnectorPositiveInteger("--duration-seconds", values) ?? 1,
        controlPort: try optionalExternalConnectorPort("--control-port", values),
        audioPort: try optionalExternalConnectorPort("--audio-port", values),
        videoPort: try optionalExternalConnectorPort("--video-port", values),
        channels: try optionalExternalConnectorPositiveInteger("--channels", values) ?? 2,
        sampleRateHertz: try optionalExternalConnectorPositiveInteger("--sample-rate", values),
        framesPerPacket: try optionalExternalConnectorPositiveInteger("--frames", values),
        videoWidth: try optionalExternalConnectorPositiveInteger("--video-width", values) ?? 1920,
        videoHeight: try optionalExternalConnectorPositiveInteger("--video-height", values) ?? 1080,
        videoFrameRate: try optionalExternalConnectorPositiveInteger("--video-fps", values) ?? 30,
        videoBitsPerPixel: try optionalExternalConnectorPositiveInteger("--video-bpp", values) ?? 24,
        audioCapture: values["--audio-capture"],
        audioPlayback: values["--audio-playback"],
        videoCapture: values["--video-capture"],
        videoDisplay: values["--video-display"],
        sessionID: values["--session-id"] ?? "1",
        localRawLinkInterface: values["--local-raw-link-interface"],
        remoteRawLinkInterface: values["--remote-raw-link-interface"],
        localMAC: try values["--local-mac"].map(parseLoLaEthernetAddress),
        remoteMAC: try values["--remote-mac"].map(parseLoLaEthernetAddress),
        mediaPacketCount: try optionalExternalConnectorPositiveInteger("--media-packets", values) ?? 1,
        ultraGridTopologyMode: try values["--ultragrid-topology"].map(parseUltraGridTopologyMode) ?? .directPeer,
        ultraGridFECMode: try values["--ultragrid-fec"].map(parseUltraGridFECMode) ?? .none,
        jackTrip: try parsedConnectionPlanJackTripConfiguration(values)
    )
}

private func parsedConnectionPlanControlTransport(
    _ values: [String: String],
    connector: ExternalConnectorKind
) throws -> ExternalConnectorControlTransport {
    try values["--control-transport"].map(parseExternalConnectorControlTransport)
        ?? defaultControlTransport(for: connector)
}

private func parsedConnectionPlanJackTripConfiguration(
    _ values: [String: String]
) throws -> JackTripRunConfiguration {
    JackTripRunConfiguration(
        audioBackend: try values["--jacktrip-audio-backend"].map(parseJackTripAudioBackend) ?? .coreAudio,
        topologyMode: try values["--jacktrip-topology"].map(parseJackTripTopologyMode) ?? .directPeer,
        topologyRole: try values["--jacktrip-topology-role"].map(parseJackTripTopologyRole) ?? .direct,
        hubPatchMode: try values["--jacktrip-hub-patch"].map(parseJackTripHubPatchMode) ?? .serverToClients,
        hubTCPHandshakeMode: try values["--jacktrip-hub-tcp-handshake"].map(parseJackTripHubTCPHandshakeMode)
            ?? .none,
        remoteClientName: values["--jacktrip-remote-client-name"]
    )
}

public struct ExternalConnectorConnectionPlanReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var connector: ExternalConnectorKind
    public var mediaMode: ExternalConnectorMediaMode
    public var localHost: String
    public var remoteHost: String
    public var runDirectory: String
    public var preflightCommand: [String]?
    public var preflightShellCommand: String?
    public var endpoints: [ExternalConnectorConnectionEndpoint]
    public var verdict: MeasurementVerdict
    public var notes: String

    public func validate() throws {
        try validateConnectionPlanIdentity()
        try validateConnectionPlanPreflightCommand()
        try validateConnectionPlanEndpoints()
    }

    private func validateConnectionPlanIdentity() throws {
        try requireExternalConnectorSessionNonEmpty(id, "id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "capturedAt")
        try requireExternalConnectorSessionNonEmpty(localHost, "localHost")
        try requireExternalConnectorSessionNonEmpty(remoteHost, "remoteHost")
        try requireExternalConnectorSessionNonEmpty(runDirectory, "runDirectory")
        try requireExternalConnectorSessionNonEmpty(notes, "notes")
        try validateMediaMode(mediaMode, connector: connector)
        guard verdict != .pass else {
            throw ExternalConnectorValidationError.realWorldPassNotAllowed
        }
        guard endpoints.count == 2 else {
            throw ExternalConnectorSessionError.emptyList("endpoints")
        }
    }

    private func validateConnectionPlanPreflightCommand() throws {
        if let preflightCommand {
            try requireExternalConnectorSessionNonEmptyList(preflightCommand, "preflightCommand")
            try rejectConnectionPlanPlaceholders(preflightCommand, field: "preflightCommand")
            guard preflightCommand.first == "external-connector-executable-preflight-run" else {
                throw ExternalConnectorSessionError.emptyField("preflightCommand")
            }
            _ = try ExternalConnectorExecutablePreflightConfiguration.parse(Array(preflightCommand.dropFirst()))
            if let preflightShellCommand, preflightShellCommand != connectionPlanShellCommand(preflightCommand) {
                throw ExternalConnectorSessionError.inconsistentShellCommand("preflightShellCommand")
            }
        }
    }

    private func validateConnectionPlanEndpoints() throws {
        let expected = expectedConnectionEndpointSet(connector: connector, endpoints: endpoints)
        let actual = Set(endpoints.map { "\($0.side.rawValue)-\($0.direction.rawValue)-\($0.role.rawValue)" })
        guard actual == expected else {
            throw ExternalConnectorSessionError.emptyField("endpoints")
        }
        for endpoint in endpoints {
            try validateConnectionPlanEndpoint(endpoint)
        }
    }

    private func validateConnectionPlanEndpoint(_ endpoint: ExternalConnectorConnectionEndpoint) throws {
        try requireExternalConnectorSessionNonEmpty(endpoint.id, "endpoints.id")
        try requireExternalConnectorSessionNonEmptyList(endpoint.command, "endpoints.command")
        try requireExternalConnectorSessionNonEmpty(endpoint.shellCommand, "endpoints.shellCommand")
        try rejectConnectionPlanPlaceholders(endpoint.command, field: "endpoints.command")
        try rejectConnectionPlanPlaceholders([endpoint.shellCommand], field: "endpoints.shellCommand")
        guard endpoint.shellCommand == connectionPlanShellCommand(endpoint.command) else {
            throw ExternalConnectorSessionError.inconsistentShellCommand("endpoints.shellCommand")
        }
        guard endpoint.command.first == "external-connector-session-run" else {
            throw ExternalConnectorSessionError.emptyField("endpoints.command")
        }
        _ = try ExternalConnectorSessionConfiguration.parse(Array(endpoint.command.dropFirst()))
        guard endpoint.plan.connector == connector else {
            throw ExternalConnectorSessionError.invalidConnector(endpoint.plan.connector.rawValue)
        }
        guard endpoint.plan.mediaProfile.mode == mediaMode else {
            throw ExternalConnectorSessionError.invalidMediaMode(endpoint.plan.mediaProfile.mode.rawValue)
        }
    }
}

public enum ExternalConnectorConnectionPlanRunner {
    public static func run(
        configuration: ExternalConnectorConnectionPlanConfiguration
    ) throws -> ExternalConnectorConnectionPlanReport {
        try validateRawLinkConfiguration(configuration)
        let endpoints = try connectionEndpointRoles(configuration).map {
            try endpoint(configuration, side: $0.side, direction: .bidirectional, role: $0.role)
        }
        return ExternalConnectorConnectionPlanReport(
            id: "external-connector-\(configuration.connector.rawValue)-av-connection-plan",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            connector: configuration.connector,
            mediaMode: configuration.mediaMode,
            localHost: configuration.localHost,
            remoteHost: configuration.remoteHost,
            runDirectory: configuration.runDirectory,
            preflightCommand: preflightCommand(configuration),
            preflightShellCommand: preflightCommand(configuration).map(connectionPlanShellCommand),
            endpoints: endpoints,
            verdict: .partial,
            notes: connectionPlanNotes(configuration.connector)
        )
    }

    private static func endpoint(
        _ configuration: ExternalConnectorConnectionPlanConfiguration,
        side: ExternalConnectorConnectionSide,
        direction: ExternalConnectorConnectionDirection,
        role: ExternalConnectorSessionRole
    ) throws -> ExternalConnectorConnectionEndpoint {
        let context = try endpointContext(configuration, side: side, direction: direction, role: role)
        let session = endpointSession(configuration, context: context)
        let plan = try ExternalConnectorLaunchPlan.build(configuration: session)
        let command = endpointCommand(session, plan: plan)
        return ExternalConnectorConnectionEndpoint(
            id: context.id,
            side: side,
            direction: direction,
            role: role,
            plan: plan,
            command: command,
            shellCommand: connectionPlanShellCommand(command)
        )
    }

    private static func endpointSession(
        _ configuration: ExternalConnectorConnectionPlanConfiguration,
        context: ExternalConnectorConnectionEndpointContext
    ) -> ExternalConnectorSessionConfiguration {
        ExternalConnectorSessionConfiguration(
            connector: configuration.connector,
            role: context.role,
            peer: context.peer,
            localHost: context.localHost,
            executable: configuration.executable,
            videoExecutable: configuration.videoExecutable,
            outputPath: context.outputPath,
            dryRun: true,
            mediaMode: configuration.mediaMode,
            controlTransport: configuration.controlTransport,
            durationSeconds: configuration.durationSeconds,
            controlPort: context.controlPort,
            audioPort: context.audioPort,
            peerAudioPort: context.peerAudioPort,
            videoPort: context.videoPort,
            channels: configuration.channels,
            sampleRateHertz: configuration.sampleRateHertz,
            framesPerPacket: configuration.framesPerPacket,
            videoWidth: configuration.videoWidth,
            videoHeight: configuration.videoHeight,
            videoFrameRate: configuration.videoFrameRate,
            videoBitsPerPixel: configuration.videoBitsPerPixel,
            audioCapture: configuration.audioCapture,
            audioPlayback: configuration.audioPlayback,
            videoCapture: configuration.videoCapture,
            videoDisplay: configuration.videoDisplay,
            sessionID: configuration.sessionID,
            rawLinkInterface: rawLinkInterface(configuration, side: context.side),
            sourceMAC: rawLinkSourceMAC(configuration, side: context.side, role: context.role),
            destinationMAC: rawLinkDestinationMAC(configuration, side: context.side, role: context.role),
            mediaPacketCount: configuration.mediaPacketCount,
            fullDuplex: true,
            ultraGridTopologyMode: configuration.ultraGridTopologyMode,
            ultraGridTopologyRole: ultraGridTopologyRole(configuration, side: context.side),
            ultraGridFECMode: configuration.ultraGridFECMode,
            jackTrip: jackTripRunConfiguration(configuration, side: context.side)
        )
    }

    private static func endpointCommand(
        _ session: ExternalConnectorSessionConfiguration,
        plan: ExternalConnectorLaunchPlan
    ) -> [String] {
        var command = baseEndpointCommand(session)
        if !session.peer.isEmpty {
            command += ["--peer", session.peer]
        }
        if session.controlPort > 0 {
            command += ["--control-port", String(session.controlPort)]
        }
        if session.connector == .jackTrip, let peerAudioPort = session.peerAudioPort {
            command += ["--peer-audio-port", String(peerAudioPort)]
        }
        appendConnectorEndpointArguments(session, to: &command)
        appendExternalExecutables(session, plan: plan, to: &command)
        appendMediaDeviceArguments(session, to: &command)
        return command
    }

    private static func baseEndpointCommand(_ session: ExternalConnectorSessionConfiguration) -> [String] {
        [
            "external-connector-session-run", "--connector", connectorCLIValue(session.connector),
            "--role", session.role.rawValue, "--local-host", session.localHost,
            "--output", session.outputPath, "--dry-run", "false", "--media", mediaModeCLIValue(session.mediaMode),
            "--control-transport", session.controlTransport.rawValue,
            "--duration-seconds", String(session.durationSeconds),
            "--audio-port", String(session.audioPort),
            "--video-port", String(session.videoPort),
            "--channels", String(session.channels),
            "--sample-rate", String(session.sampleRateHertz),
            "--frames", String(session.framesPerPacket),
            "--video-width", String(session.videoWidth),
            "--video-height", String(session.videoHeight),
            "--video-fps", String(session.videoFrameRate),
            "--video-bpp", String(session.videoBitsPerPixel),
            "--session-id", session.sessionID,
            "--full-duplex", session.fullDuplex ? "true" : "false"
        ]
    }

    private static func appendConnectorEndpointArguments(
        _ session: ExternalConnectorSessionConfiguration,
        to command: inout [String]
    ) {
        if session.connector == .jackTrip {
            command += [
                "--jacktrip-queue-depth", String(session.jackTrip.queueDepth),
                "--jacktrip-redundancy", String(session.jackTrip.redundancy),
                "--jacktrip-bit-resolution", String(session.jackTrip.bitResolutionBits),
                "--jacktrip-audio-backend", session.jackTrip.audioBackend.rawValue,
                "--jacktrip-topology", session.jackTrip.topologyMode.rawValue,
                "--jacktrip-topology-role", session.jackTrip.topologyRole.rawValue
            ]
            if session.jackTrip.topologyMode == .hubVirtualStudio {
                command += ["--jacktrip-hub-patch", session.jackTrip.hubPatchMode.label]
            }
            if session.jackTrip.hubTCPHandshakeMode != .none {
                command += ["--jacktrip-hub-tcp-handshake", session.jackTrip.hubTCPHandshakeMode.rawValue]
            }
            if let remoteClientName = session.jackTrip.remoteClientName {
                command += ["--jacktrip-remote-client-name", remoteClientName]
            }
        }
        if session.connector == .mvtpUltraGrid {
            command += [
                "--ultragrid-topology", session.ultraGridTopologyMode.rawValue,
                "--ultragrid-topology-role", session.ultraGridTopologyRole.rawValue,
                "--ultragrid-audio-payload-type", String(session.ultraGridAudioPayloadType),
                "--ultragrid-video-payload-type", String(session.ultraGridVideoPayloadType),
                "--ultragrid-fec", session.ultraGridFECMode.rawValue
            ]
        }
        if session.connector == .lola {
            appendLoLaEndpointArguments(session, to: &command)
        }
    }

    private static func appendLoLaEndpointArguments(
        _ session: ExternalConnectorSessionConfiguration,
        to command: inout [String]
    ) {
        command += ["--media-packets", String(session.mediaPacketCount)]
        if let rawLinkInterface = session.rawLinkInterface {
            command += ["--raw-link-interface", rawLinkInterface]
            if session.role.transmits,
               let sourceMAC = session.sourceMAC,
               let destinationMAC = session.destinationMAC {
                command += [
                    "--source-mac", ethernetAddressCLIValue(sourceMAC),
                    "--destination-mac", ethernetAddressCLIValue(destinationMAC)
                ]
            }
        }
    }

    private static func appendExternalExecutables(
        _ session: ExternalConnectorSessionConfiguration,
        plan: ExternalConnectorLaunchPlan,
        to command: inout [String]
    ) {
        if let executable = plan.executable {
            command += ["--executable", executable]
        }
        if let videoExecutable = session.videoExecutable ?? plan.auxiliaryProcesses.first?.executable {
            command += ["--video-executable", videoExecutable]
        }
    }

    private static func appendMediaDeviceArguments(
        _ session: ExternalConnectorSessionConfiguration,
        to command: inout [String]
    ) {
        let peerKnownFullDuplex = mediaArgumentPeerKnownFullDuplex(session)
        appendAudioDeviceArguments(session, peerKnownFullDuplex: peerKnownFullDuplex, to: &command)
        appendVideoDeviceArguments(session, peerKnownFullDuplex: peerKnownFullDuplex, to: &command)
    }

    private static func appendAudioDeviceArguments(
        _ session: ExternalConnectorSessionConfiguration,
        peerKnownFullDuplex: Bool,
        to command: inout [String]
    ) {
        if shouldAppendUltraGridAudioCapture(session, peerKnownFullDuplex: peerKnownFullDuplex),
           let audioCapture = session.audioCapture {
            command += ["--audio-capture", audioCapture]
        }
        if shouldAppendUltraGridAudioPlayback(session, peerKnownFullDuplex: peerKnownFullDuplex),
           let audioPlayback = session.audioPlayback {
            command += ["--audio-playback", audioPlayback]
        }
        if session.connector == .jackTrip, session.mediaMode.hasAudio {
            if let audioCapture = session.audioCapture {
                command += ["--audio-capture", audioCapture]
            }
            if let audioPlayback = session.audioPlayback {
                command += ["--audio-playback", audioPlayback]
            }
        }
    }

    private static func appendVideoDeviceArguments(
        _ session: ExternalConnectorSessionConfiguration,
        peerKnownFullDuplex: Bool,
        to command: inout [String]
    ) {
        if shouldAppendVideoCapture(session, peerKnownFullDuplex: peerKnownFullDuplex),
           let videoCapture = session.videoCapture {
            command += ["--video-capture", videoCapture]
        }
        if shouldAppendVideoDisplay(session, peerKnownFullDuplex: peerKnownFullDuplex),
           let videoDisplay = session.videoDisplay {
            command += ["--video-display", videoDisplay]
        }
    }

}

private struct ExternalConnectorConnectionEndpointContext {
    let connector: ExternalConnectorKind
    let side: ExternalConnectorConnectionSide
    let direction: ExternalConnectorConnectionDirection
    let role: ExternalConnectorSessionRole
    let localHost: String
    let peer: String
    let outputPath: String
    let controlPort: UInt16
    let audioPort: UInt16
    let peerAudioPort: UInt16?
    let videoPort: UInt16

    var id: String {
        "\(connector.rawValue)-\(side.rawValue)-\(direction.rawValue)-\(role.rawValue)"
    }
}

private func endpointContext(
    _ configuration: ExternalConnectorConnectionPlanConfiguration,
    side: ExternalConnectorConnectionSide,
    direction: ExternalConnectorConnectionDirection,
    role: ExternalConnectorSessionRole
) throws -> ExternalConnectorConnectionEndpointContext {
    let remote = side == .local ? configuration.remoteHost : configuration.localHost
    return ExternalConnectorConnectionEndpointContext(
        connector: configuration.connector,
        side: side,
        direction: direction,
        role: role,
        localHost: side == .local ? configuration.localHost : configuration.remoteHost,
        peer: endpointPeer(configuration, role: role, remote: remote),
        outputPath: connectionPlanEndpointOutputPath(configuration, side: side, direction: direction, role: role),
        controlPort: try connectionPlanPort(
            configuration.controlPort,
            connector: configuration.connector,
            side: side,
            kind: .control
        ),
        audioPort: try connectionPlanPort(
            configuration.audioPort,
            connector: configuration.connector,
            side: side,
            kind: .audio
        ),
        peerAudioPort: try jackTripPeerAudioPort(configuration, side: side, role: role),
        videoPort: try connectionPlanPort(
            configuration.videoPort,
            connector: configuration.connector,
            side: side,
            kind: .video
        )
    )
}

private func connectionPlanEndpointOutputPath(
    _ configuration: ExternalConnectorConnectionPlanConfiguration,
    side: ExternalConnectorConnectionSide,
    direction: ExternalConnectorConnectionDirection,
    role: ExternalConnectorSessionRole
) -> String {
    let fileName = "\(configuration.connector.rawValue)-\(side.rawValue)-\(direction.rawValue)-\(role.rawValue).json"
    return "\(normalizedRunDirectory(configuration.runDirectory))/\(fileName)"
}

private enum ExternalConnectorConnectionPlanPortKind {
    case control
    case audio
    case video

    var argumentLabel: String {
        switch self {
        case .control:
            return "--control-port"
        case .audio:
            return "--audio-port"
        case .video:
            return "--video-port"
        }
    }
}

private func connectionPlanPort(
    _ configuredPort: UInt16?,
    connector: ExternalConnectorKind,
    side: ExternalConnectorConnectionSide,
    kind: ExternalConnectorConnectionPlanPortKind
) throws -> UInt16 {
    let basePort = configuredPort ?? defaultConnectionPlanPort(for: connector, kind: kind)
    return try sideScopedPort(basePort, side: side, label: kind.argumentLabel)
}

private func defaultConnectionPlanPort(
    for connector: ExternalConnectorKind,
    kind: ExternalConnectorConnectionPlanPortKind
) -> UInt16 {
    switch kind {
    case .control:
        return defaultControlPort(for: connector)
    case .audio:
        return defaultAudioPort(for: connector)
    case .video:
        return defaultVideoPort(for: connector)
    }
}

private func mediaArgumentPeerKnownFullDuplex(_ session: ExternalConnectorSessionConfiguration) -> Bool {
    (session.role == .txRx || session.fullDuplex)
        && !session.peer.isEmpty
        && (session.connector == .mvtpUltraGrid || session.connector == .jackTrip)
}

private func shouldAppendUltraGridAudioCapture(
    _ session: ExternalConnectorSessionConfiguration,
    peerKnownFullDuplex: Bool
) -> Bool {
    (session.role.transmits || peerKnownFullDuplex)
        && session.connector == .mvtpUltraGrid
        && session.mediaMode.hasAudio
}

private func shouldAppendUltraGridAudioPlayback(
    _ session: ExternalConnectorSessionConfiguration,
    peerKnownFullDuplex: Bool
) -> Bool {
    (session.role.receives || peerKnownFullDuplex)
        && session.connector == .mvtpUltraGrid
        && session.mediaMode.hasAudio
}

private func shouldAppendVideoCapture(
    _ session: ExternalConnectorSessionConfiguration,
    peerKnownFullDuplex: Bool
) -> Bool {
    (session.role.transmits || peerKnownFullDuplex) && session.mediaMode.hasVideo
}

private func shouldAppendVideoDisplay(
    _ session: ExternalConnectorSessionConfiguration,
    peerKnownFullDuplex: Bool
) -> Bool {
    (session.role.receives || peerKnownFullDuplex) && session.mediaMode.hasVideo
}

private func connectionEndpointRoles(
    _ configuration: ExternalConnectorConnectionPlanConfiguration
) -> [(side: ExternalConnectorConnectionSide, role: ExternalConnectorSessionRole)] {
    if configuration.connector == .jackTrip {
        return [(.local, .rx), (.remote, .tx)]
    }
    if configuration.connector == .mvtpUltraGrid, configuration.ultraGridTopologyMode == .serverClient {
        return [(.local, .rx), (.remote, .tx)]
    }
    return [(.local, .txRx), (.remote, .txRx)]
}

private func expectedConnectionEndpointSet(
    connector: ExternalConnectorKind,
    endpoints: [ExternalConnectorConnectionEndpoint]
) -> Set<String> {
    if connector == .jackTrip {
        return Set(["local-bidirectional-rx", "remote-bidirectional-tx"])
    }
    if connector == .mvtpUltraGrid,
       endpoints.contains(where: {
           $0.plan.arguments.contains("--topology-role") && $0.plan.arguments.contains("server")
       }) {
        return Set(["local-bidirectional-rx", "remote-bidirectional-tx"])
    }
    return Set(["local-bidirectional-tx-rx", "remote-bidirectional-tx-rx"])
}

private func ultraGridTopologyRole(
    _ configuration: ExternalConnectorConnectionPlanConfiguration,
    side: ExternalConnectorConnectionSide
) -> UltraGridTopologyRole {
    guard configuration.connector == .mvtpUltraGrid else {
        return .direct
    }
    guard configuration.ultraGridTopologyMode == .serverClient else {
        return .direct
    }
    return side == .local ? .server : .client
}

private func jackTripRunConfiguration(
    _ configuration: ExternalConnectorConnectionPlanConfiguration,
    side: ExternalConnectorConnectionSide
) -> JackTripRunConfiguration {
    guard configuration.connector == .jackTrip,
          configuration.jackTrip.topologyMode == .hubVirtualStudio else {
        return configuration.jackTrip
    }
    return JackTripRunConfiguration(
        queueDepth: configuration.jackTrip.queueDepth,
        redundancy: configuration.jackTrip.redundancy,
        bitResolutionBits: configuration.jackTrip.bitResolutionBits,
        audioBackend: configuration.jackTrip.audioBackend,
        topologyMode: .hubVirtualStudio,
        topologyRole: side == .local ? .hubServer : .hubClient,
        hubPatchMode: configuration.jackTrip.hubPatchMode,
        hubTCPHandshakeMode: configuration.jackTrip.hubTCPHandshakeMode,
        remoteClientName: configuration.jackTrip.remoteClientName
    )
}

private func jackTripPeerAudioPort(
    _ configuration: ExternalConnectorConnectionPlanConfiguration,
    side: ExternalConnectorConnectionSide,
    role: ExternalConnectorSessionRole
) throws -> UInt16? {
    guard configuration.connector == .jackTrip, role.transmits else {
        return nil
    }
    let basePort = configuration.audioPort ?? defaultAudioPort(for: .jackTrip)
    if side == .local {
        return try sideScopedPort(basePort, side: .remote, label: "--audio-port")
    }
    return basePort
}

private func connectionPlanNotes(_ connector: ExternalConnectorKind) -> String {
    if connector == .jackTrip {
        return [
            "Bidirectional JackTrip A/V connection plan.",
            "It emits a P2P server endpoint and a P2P client endpoint so the audio leg follows",
            "JackTrip-to-JackTrip launch semantics; PASS still requires both peers to run",
            "and measured route/media evidence to be attached."
        ].joined(separator: " ")
    }
    return [
        "Bidirectional A/V connection plan.",
        "It emits explicit tx-rx endpoint commands for both peers, but does not claim real",
        "interoperability until both peers run and measured route/media evidence is attached."
    ].joined(separator: " ")
}

private func preflightCommand(_ configuration: ExternalConnectorConnectionPlanConfiguration) -> [String]? {
    guard configuration.connector != .lola, configuration.connector != .mvtpUltraGrid else {
        return nil
    }
    var command = [
        "external-connector-executable-preflight-run", "--output",
        connectionPlanPreflightOutputPath(configuration),
        "--connector", connectorCLIValue(configuration.connector)
    ]
    if configuration.connector == .jackTrip {
        command += ["--jacktrip-executable", configuration.executable ?? "jacktrip"]
    }
    let ultraGridExecutable = configuration.connector == .mvtpUltraGrid
        ? configuration.executable ?? "uv"
        : configuration.videoExecutable ?? "uv"
    command += ["--ultragrid-executable", ultraGridExecutable]
    return command
}

private func connectionPlanPreflightOutputPath(
    _ configuration: ExternalConnectorConnectionPlanConfiguration
) -> String {
    let fileName = "\(configuration.connector.rawValue)-executable-preflight.json"
    return "\(normalizedRunDirectory(configuration.runDirectory))/\(fileName)"
}

private func connectionPlanShellCommand(_ command: [String]) -> String {
    (["open-lola"] + command).map(shellQuote).joined(separator: " ")
}

private func shellQuote(_ value: String) -> String {
    guard !value.isEmpty, value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
          !value.contains("'"), value.range(of: #"[^A-Za-z0-9_./:=@+-]"#, options: .regularExpression) == nil else {
        return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
    return value
}

private func endpointPeer(
    _ configuration: ExternalConnectorConnectionPlanConfiguration,
    role: ExternalConnectorSessionRole,
    remote: String
) -> String {
    if role.transmits {
        return remote
    }
    if configuration.connector == .lola {
        return remote
    }
    if configuration.connector == .mvtpUltraGrid {
        if configuration.ultraGridTopologyMode == .serverClient, role == .rx {
            return ""
        }
        return remote
    }
    if configuration.connector == .jackTrip, configuration.mediaMode.hasVideo {
        return remote
    }
    return ""
}

private func sideScopedPort(
    _ basePort: UInt16,
    side: ExternalConnectorConnectionSide,
    label: String
) throws -> UInt16 {
    guard basePort > 0 else {
        return 0
    }
    guard side == .remote else {
        return basePort
    }
    guard basePort < UInt16.max else {
        throw ExternalConnectorSessionError.invalidPort(label, String(basePort))
    }
    return basePort + 1
}

private func normalizedRunDirectory(_ runDirectory: String) -> String {
    guard runDirectory.count > 1, runDirectory.hasSuffix("/") else {
        return runDirectory
    }
    return String(runDirectory.dropLast())
}

private func defaultRunDirectory(forOutputPath outputPath: String) -> String {
    guard let slash = outputPath.lastIndex(of: "/") else {
        return "."
    }
    if slash == outputPath.startIndex {
        return "/"
    }
    return String(outputPath[..<slash])
}

private func rejectConnectionPlanPlaceholders(_ values: [String], field: String) throws {
    if values.contains(where: { $0.contains("<run-dir>") }) {
        throw ExternalConnectorSessionError.placeholderValue(field)
    }
}

private func validateRawLinkConfiguration(_ configuration: ExternalConnectorConnectionPlanConfiguration) throws {
    guard hasRawLinkInput(configuration) else {
        return
    }
    guard configuration.connector == .lola else {
        throw ExternalConnectorSessionError.connectorDoesNotSupportRawLink(configuration.connector)
    }
    try requireRawLinkEndpointInputs(configuration)
}

private func hasRawLinkInput(_ configuration: ExternalConnectorConnectionPlanConfiguration) -> Bool {
    configuration.localRawLinkInterface != nil
        || configuration.remoteRawLinkInterface != nil
        || configuration.localMAC != nil
        || configuration.remoteMAC != nil
}

private func requireRawLinkEndpointInputs(_ configuration: ExternalConnectorConnectionPlanConfiguration) throws {
    guard configuration.localRawLinkInterface != nil else {
        throw ExternalConnectorSessionError.missingRequiredArgument("--local-raw-link-interface")
    }
    guard configuration.remoteRawLinkInterface != nil else {
        throw ExternalConnectorSessionError.missingRequiredArgument("--remote-raw-link-interface")
    }
    guard configuration.localMAC != nil else {
        throw ExternalConnectorSessionError.missingRequiredArgument("--local-mac")
    }
    guard configuration.remoteMAC != nil else {
        throw ExternalConnectorSessionError.missingRequiredArgument("--remote-mac")
    }
}

private func rawLinkInterface(
    _ configuration: ExternalConnectorConnectionPlanConfiguration,
    side: ExternalConnectorConnectionSide
) -> String? {
    guard configuration.connector == .lola else {
        return nil
    }
    return side == .local ? configuration.localRawLinkInterface : configuration.remoteRawLinkInterface
}

private func rawLinkSourceMAC(
    _ configuration: ExternalConnectorConnectionPlanConfiguration,
    side: ExternalConnectorConnectionSide,
    role: ExternalConnectorSessionRole
) -> LoLaEthernetAddress? {
    guard configuration.connector == .lola, role.transmits else {
        return nil
    }
    return side == .local ? configuration.localMAC : configuration.remoteMAC
}

private func rawLinkDestinationMAC(
    _ configuration: ExternalConnectorConnectionPlanConfiguration,
    side: ExternalConnectorConnectionSide,
    role: ExternalConnectorSessionRole
) -> LoLaEthernetAddress? {
    guard configuration.connector == .lola, role.transmits else {
        return nil
    }
    return side == .local ? configuration.remoteMAC : configuration.localMAC
}

private func connectorCLIValue(_ connector: ExternalConnectorKind) -> String {
    switch connector {
    case .lola:
        return "lola"
    case .mvtpUltraGrid:
        return "mvtp-ultragrid"
    case .jackTrip:
        return "jacktrip"
    }
}

private func mediaModeCLIValue(_ mediaMode: ExternalConnectorMediaMode) -> String {
    switch mediaMode {
    case .audio:
        return "audio"
    case .video:
        return "video"
    case .audioVideo:
        return "audio-video"
    }
}

private func ethernetAddressCLIValue(_ address: LoLaEthernetAddress) -> String {
    address.octets.map { String(format: "%02x", $0) }.joined(separator: ":")
}
