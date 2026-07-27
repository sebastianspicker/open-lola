// Builds local and remote endpoint commands and shell renderings for an NMP connection plan.
import Foundation

// swiftlint:disable:next type_name
struct ExternalConnectorConnectionEndpointContext {
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

func endpointContext(
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

func connectionPlanEndpointOutputPath(
    _ configuration: ExternalConnectorConnectionPlanConfiguration,
    side: ExternalConnectorConnectionSide,
    direction: ExternalConnectorConnectionDirection,
    role: ExternalConnectorSessionRole
) -> String {
    let fileName = "\(configuration.connector.rawValue)-\(side.rawValue)-\(direction.rawValue)-\(role.rawValue).json"
    return "\(normalizedRunDirectory(configuration.runDirectory))/\(fileName)"
}

enum ExternalConnectorConnectionPlanPortKind {
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

func connectionPlanPort(
    _ configuredPort: UInt16?,
    connector: ExternalConnectorKind,
    side: ExternalConnectorConnectionSide,
    kind: ExternalConnectorConnectionPlanPortKind
) throws -> UInt16 {
    let basePort = configuredPort ?? defaultConnectionPlanPort(for: connector, kind: kind)
    return try sideScopedPort(basePort, side: side, label: kind.argumentLabel)
}

func defaultConnectionPlanPort(
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

func mediaArgumentPeerKnownFullDuplex(_ session: ExternalConnectorSessionConfiguration) -> Bool {
    (session.role == .txRx || session.fullDuplex)
        && !session.peer.isEmpty
        && (session.connector == .mvtpUltraGrid || session.connector == .jackTrip)
}

func shouldAppendUltraGridAudioCapture(
    _ session: ExternalConnectorSessionConfiguration,
    peerKnownFullDuplex: Bool
) -> Bool {
    (session.role.transmits || peerKnownFullDuplex)
        && session.connector == .mvtpUltraGrid
        && session.mediaMode.hasAudio
}

func shouldAppendUltraGridAudioPlayback(
    _ session: ExternalConnectorSessionConfiguration,
    peerKnownFullDuplex: Bool
) -> Bool {
    (session.role.receives || peerKnownFullDuplex)
        && session.connector == .mvtpUltraGrid
        && session.mediaMode.hasAudio
}

func shouldAppendVideoCapture(
    _ session: ExternalConnectorSessionConfiguration,
    peerKnownFullDuplex: Bool
) -> Bool {
    (session.role.transmits || peerKnownFullDuplex) && session.mediaMode.hasVideo
}

func shouldAppendVideoDisplay(
    _ session: ExternalConnectorSessionConfiguration,
    peerKnownFullDuplex: Bool
) -> Bool {
    (session.role.receives || peerKnownFullDuplex) && session.mediaMode.hasVideo
}

func connectionEndpointRoles(
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

func expectedConnectionEndpointSet(
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

func ultraGridTopologyRole(
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

func jackTripRunConfiguration(
    _ configuration: ExternalConnectorConnectionPlanConfiguration,
    side: ExternalConnectorConnectionSide
) -> JackTripRunConfiguration {
    guard configuration.connector == .jackTrip,
          configuration.jackTrip.topologyMode == .hubVirtualStudio else {
        return configuration.jackTrip
    }
    return JackTripRunConfiguration { input in
        input.queueDepth = configuration.jackTrip.queueDepth
        input.redundancy = configuration.jackTrip.redundancy
        input.bitResolutionBits = configuration.jackTrip.bitResolutionBits
        input.audioBackend = configuration.jackTrip.audioBackend
        input.topologyMode = .hubVirtualStudio
        input.topologyRole = side == .local ? .hubServer : .hubClient
        input.hubPatchMode = configuration.jackTrip.hubPatchMode
        input.hubTCPHandshakeMode = configuration.jackTrip.hubTCPHandshakeMode
        input.remoteClientName = configuration.jackTrip.remoteClientName
    }
}

func jackTripPeerAudioPort(
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

func connectionPlanNotes(_ connector: ExternalConnectorKind) -> String {
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

func preflightCommand(_ configuration: ExternalConnectorConnectionPlanConfiguration) -> [String]? {
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
