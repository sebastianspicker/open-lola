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

    public static func parse(_ arguments: [String]) throws -> ExternalConnectorConnectionPlanConfiguration {
        let allowed = [
            "--connector", "--local-host", "--remote-host", "--output", "--run-dir", "--media",
            "--control-transport", "--duration-seconds", "--channels", "--sample-rate",
            "--frames", "--control-port", "--audio-port", "--video-port",
            "--video-width", "--video-height", "--video-fps", "--video-bpp",
            "--executable", "--video-executable", "--audio-capture",
            "--audio-playback", "--video-capture", "--video-display", "--session-id",
            "--local-raw-link-interface", "--remote-raw-link-interface", "--local-mac",
            "--remote-mac", "--media-packets",
        ]
        var values: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            guard allowed.contains(argument) else {
                throw ExternalConnectorSessionError.unknownArgument(argument)
            }
            guard values[argument] == nil else {
                throw ExternalConnectorSessionError.duplicateArgument(argument)
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
                throw ExternalConnectorSessionError.missingValue(argument)
            }
            values[argument] = arguments[valueIndex]
            index += 2
        }
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
            controlTransport: try values["--control-transport"].map(parseExternalConnectorControlTransport)
                ?? defaultControlTransport(for: connector),
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
            mediaPacketCount: try optionalExternalConnectorPositiveInteger("--media-packets", values) ?? 1
        )
    }
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
        let expected: Set<String> = connector == .jackTrip
            ? Set(["local-bidirectional-rx", "remote-bidirectional-tx"])
            : Set(["local-bidirectional-tx-rx", "remote-bidirectional-tx-rx"])
        let actual = Set(endpoints.map { "\($0.side.rawValue)-\($0.direction.rawValue)-\($0.role.rawValue)" })
        guard actual == expected else {
            throw ExternalConnectorSessionError.emptyField("endpoints")
        }
        for endpoint in endpoints {
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
        let local = side == .local ? configuration.localHost : configuration.remoteHost
        let remote = side == .local ? configuration.remoteHost : configuration.localHost
        let peer = endpointPeer(configuration, role: role, remote: remote)
        let controlPort = try sideScopedPort(
            configuration.controlPort ?? defaultControlPort(for: configuration.connector),
            side: side,
            label: "--control-port"
        )
        let audioPort = try sideScopedPort(
            configuration.audioPort ?? defaultAudioPort(for: configuration.connector),
            side: side,
            label: "--audio-port"
        )
        let peerAudioPort = try jackTripPeerAudioPort(
            configuration,
            side: side,
            role: role
        )
        let videoPort = try sideScopedPort(
            configuration.videoPort ?? defaultVideoPort(for: configuration.connector),
            side: side,
            label: "--video-port"
        )
        let session = ExternalConnectorSessionConfiguration(
            connector: configuration.connector,
            role: role,
            peer: peer,
            localHost: local,
            executable: configuration.executable,
            videoExecutable: configuration.videoExecutable,
            outputPath: endpointOutputPath(configuration, side: side, direction: direction, role: role),
            dryRun: true,
            mediaMode: configuration.mediaMode,
            controlTransport: configuration.controlTransport,
            durationSeconds: configuration.durationSeconds,
            controlPort: controlPort,
            audioPort: audioPort,
            peerAudioPort: peerAudioPort,
            videoPort: videoPort,
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
            rawLinkInterface: rawLinkInterface(configuration, side: side),
            sourceMAC: rawLinkSourceMAC(configuration, side: side, role: role),
            destinationMAC: rawLinkDestinationMAC(configuration, side: side, role: role),
            mediaPacketCount: configuration.mediaPacketCount,
            fullDuplex: true
        )
        let plan = try ExternalConnectorLaunchPlan.build(configuration: session)
        let command = endpointCommand(session, plan: plan)
        return ExternalConnectorConnectionEndpoint(
            id: "\(configuration.connector.rawValue)-\(side.rawValue)-\(direction.rawValue)-\(role.rawValue)",
            side: side,
            direction: direction,
            role: role,
            plan: plan,
            command: command,
            shellCommand: connectionPlanShellCommand(command)
        )
    }

    private static func endpointOutputPath(
        _ configuration: ExternalConnectorConnectionPlanConfiguration,
        side: ExternalConnectorConnectionSide,
        direction: ExternalConnectorConnectionDirection,
        role: ExternalConnectorSessionRole
    ) -> String {
        "\(normalizedRunDirectory(configuration.runDirectory))/\(configuration.connector.rawValue)-\(side.rawValue)-\(direction.rawValue)-\(role.rawValue).json"
    }

    private static func endpointCommand(
        _ session: ExternalConnectorSessionConfiguration,
        plan: ExternalConnectorLaunchPlan
    ) -> [String] {
        var command = [
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
            "--full-duplex", session.fullDuplex ? "true" : "false",
        ]
        if !session.peer.isEmpty {
            command += ["--peer", session.peer]
        }
        if session.controlPort > 0 {
            command += ["--control-port", String(session.controlPort)]
        }
        if session.connector == .jackTrip, let peerAudioPort = session.peerAudioPort {
            command += ["--peer-audio-port", String(peerAudioPort)]
        }
        if session.connector == .jackTrip {
            command += [
                "--jacktrip-queue-depth", String(session.jackTrip.queueDepth),
                "--jacktrip-redundancy", String(session.jackTrip.redundancy),
            ]
        }
        if session.connector == .lola {
            command += ["--media-packets", String(session.mediaPacketCount)]
            if let rawLinkInterface = session.rawLinkInterface {
                command += ["--raw-link-interface", rawLinkInterface]
                if session.role.transmits, let sourceMAC = session.sourceMAC, let destinationMAC = session.destinationMAC {
                    command += [
                        "--source-mac", ethernetAddressCLIValue(sourceMAC),
                        "--destination-mac", ethernetAddressCLIValue(destinationMAC),
                    ]
                }
            }
        }
        if let executable = plan.executable {
            command += ["--executable", executable]
        }
        if let videoExecutable = session.videoExecutable ?? plan.auxiliaryProcesses.first?.executable {
            command += ["--video-executable", videoExecutable]
        }
        let peerKnownFullDuplex = (session.role == .txRx || session.fullDuplex) && !session.peer.isEmpty
            && (session.connector == .mvtpUltraGrid || session.connector == .jackTrip)
        if (session.role.transmits || peerKnownFullDuplex),
           session.connector == .mvtpUltraGrid,
           session.mediaMode.hasAudio,
           let audioCapture = session.audioCapture {
            command += ["--audio-capture", audioCapture]
        }
        if (session.role.receives || peerKnownFullDuplex),
           session.connector == .mvtpUltraGrid,
           session.mediaMode.hasAudio,
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
        if (session.role.transmits || peerKnownFullDuplex), session.mediaMode.hasVideo, let videoCapture = session.videoCapture {
            command += ["--video-capture", videoCapture]
        }
        if (session.role.receives || peerKnownFullDuplex), session.mediaMode.hasVideo, let videoDisplay = session.videoDisplay {
            command += ["--video-display", videoDisplay]
        }
        return command
    }

}

private func connectionEndpointRoles(
    _ configuration: ExternalConnectorConnectionPlanConfiguration
) -> [(side: ExternalConnectorConnectionSide, role: ExternalConnectorSessionRole)] {
    if configuration.connector == .jackTrip {
        return [(.local, .rx), (.remote, .tx)]
    }
    return [(.local, .txRx), (.remote, .txRx)]
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
    return side == .local ? try sideScopedPort(basePort, side: .remote, label: "--audio-port") : basePort
}

private func connectionPlanNotes(_ connector: ExternalConnectorKind) -> String {
    if connector == .jackTrip {
        return "Bidirectional JackTrip A/V connection plan. It emits a P2P server endpoint and a P2P client endpoint so the audio leg follows JackTrip-to-JackTrip launch semantics; PASS still requires both peers to run and measured route/media evidence to be attached."
    }
    return "Bidirectional A/V connection plan. It emits explicit tx-rx endpoint commands for both peers, but does not claim real interoperability until both peers run and measured route/media evidence is attached."
}

private func preflightCommand(_ configuration: ExternalConnectorConnectionPlanConfiguration) -> [String]? {
    guard configuration.connector != .lola else {
        return nil
    }
    var command = [
        "external-connector-executable-preflight-run", "--output",
        "\(normalizedRunDirectory(configuration.runDirectory))/\(configuration.connector.rawValue)-executable-preflight.json",
        "--connector", connectorCLIValue(configuration.connector),
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
    let hasRawLinkInput = configuration.localRawLinkInterface != nil
        || configuration.remoteRawLinkInterface != nil
        || configuration.localMAC != nil
        || configuration.remoteMAC != nil
    guard hasRawLinkInput else {
        return
    }
    guard configuration.connector == .lola else {
        throw ExternalConnectorSessionError.connectorDoesNotSupportRawLink(configuration.connector)
    }
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
