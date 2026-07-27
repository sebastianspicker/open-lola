// Defines and validates the two-sided connector plan consumed by NMP orchestration.
import Foundation

/// Identifies whether a connection endpoint belongs to the local, remote, or both sides.
public enum ExternalConnectorConnectionSide: String, Codable, Equatable, Sendable {
    case local
    case remote
    case both
}

/// Defines the supported choices for external connector connection direction.
public enum ExternalConnectorConnectionDirection: String, Codable, Equatable, Sendable {
    case localToRemote
    case remoteToLocal
    case bidirectional
}

/// Defines the validated fields for external connector connection endpoint.
public struct ExternalConnectorConnectionEndpoint: Codable, Equatable, Sendable {
    public var id: String
    public var side: ExternalConnectorConnectionSide
    public var direction: ExternalConnectorConnectionDirection
    public var role: ExternalConnectorSessionRole
    public var plan: ExternalConnectorLaunchPlan
    public var command: [String]
    public var shellCommand: String
}

// swiftlint:disable:next type_name
/// Defines the validated fields for external connector connection plan configuration.
public struct ExternalConnectorConnectionPlanConfiguration: Equatable, Sendable, ExternalConnectorMediaOptionConfiguring {
    public var connector: ExternalConnectorKind
    public var localHost: String
    public var remoteHost: String
    public var outputPath: String
    public var runDirectory: String
    public var executable: String?
    public var videoExecutable: String?
    public var mediaMode: ExternalConnectorMediaMode
    public var controlTransport: ExternalConnectorControlTransport
    public var mediaOptions: ExternalConnectorMediaOptionValues
    public var controlPort: UInt16?
    public var audioPort: UInt16?
    public var videoPort: UInt16?
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
    let media = try parseExternalConnectorMediaOptionValues(values)
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
        mediaOptions: media,
        controlPort: try optionalExternalConnectorPort("--control-port", values),
        audioPort: try optionalExternalConnectorPort("--audio-port", values),
        videoPort: try optionalExternalConnectorPort("--video-port", values),
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
    try JackTripRunConfiguration { input in
    input.audioBackend = try values["--jacktrip-audio-backend"].map(parseJackTripAudioBackend) ?? .coreAudio
    input.topologyMode = try values["--jacktrip-topology"].map(parseJackTripTopologyMode) ?? .directPeer
    input.topologyRole = try values["--jacktrip-topology-role"].map(parseJackTripTopologyRole) ?? .direct
    input.hubPatchMode = try values["--jacktrip-hub-patch"].map(parseJackTripHubPatchMode) ?? .serverToClients
    input.hubTCPHandshakeMode = try values["--jacktrip-hub-tcp-handshake"].map(parseJackTripHubTCPHandshakeMode)
    ?? .none
    input.remoteClientName = values["--jacktrip-remote-client-name"]
    }
}

/// Records the evidence and outcome for external connector connection plan report.
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
