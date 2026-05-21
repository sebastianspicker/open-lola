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
        "--jacktrip-payload-encoding",
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
        "--ultragrid-control-command",
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
        "--jacktrip-payload-encoding",
    ])

    private static let loLaRawLinkOnlyArguments = Set([
        "--raw-link-interface",
        "--source-mac",
        "--destination-mac",
    ])

    private static let loLaControlOnlyArguments = Set([
        "--video-compression",
        "--video-bayer",
    ])

    private static let ignoredByJackTripVideoArguments = Set([
        "--lola-video-payload",
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
            ultraGridTopologyMode: try values["--ultragrid-topology"].map(parseUltraGridTopologyMode) ?? .directPeer,
            ultraGridTopologyRole: try values["--ultragrid-topology-role"].map(parseUltraGridTopologyRole) ?? .direct,
            ultraGridAudioPayloadType: try parseUltraGridRTPPayloadType(
                "--ultragrid-audio-payload-type",
                values
            ) ?? UltraGridCompatibility.audioPayloadType,
            ultraGridVideoPayloadType: try parseUltraGridRTPPayloadType(
                "--ultragrid-video-payload-type",
                values
            ) ?? UltraGridCompatibility.videoPayloadType,
            ultraGridFECMode: try values["--ultragrid-fec"].map(parseUltraGridFECMode) ?? .none,
            ultraGridEncryptionMode: try values["--ultragrid-encryption"].map(parseUltraGridEncryptionMode) ?? .none,
            ultraGridEncryptionPassphrase: values["--ultragrid-encryption-passphrase"],
            ultraGridControlMode: try values["--ultragrid-control"].map(parseUltraGridControlMode) ?? .disabled,
            ultraGridControlCommands: try parsed.repeatedValues(for: "--ultragrid-control-command")
                .map(UltraGridControlCommand.parse),
            jackTrip: JackTripRunConfiguration(
                queueDepth: try optionalExternalConnectorPositiveInteger("--jacktrip-queue-depth", values) ?? 4,
                redundancy: try optionalExternalConnectorPositiveInteger("--jacktrip-redundancy", values) ?? 1,
                bitResolutionBits: try optionalExternalConnectorPositiveInteger("--jacktrip-bit-resolution", values) ?? 16,
                audioBackend: try values["--jacktrip-audio-backend"].map(parseJackTripAudioBackend) ?? .coreAudio,
                topologyMode: try values["--jacktrip-topology"].map(parseJackTripTopologyMode) ?? .directPeer,
                topologyRole: try values["--jacktrip-topology-role"].map(parseJackTripTopologyRole) ?? .direct,
                hubPatchMode: try values["--jacktrip-hub-patch"].map(parseJackTripHubPatchMode) ?? .serverToClients,
                hubTCPHandshakeMode: try values["--jacktrip-hub-tcp-handshake"].map(parseJackTripHubTCPHandshakeMode)
                    ?? .none,
                remoteClientName: values["--jacktrip-remote-client-name"],
                packetHeaderMode: try values["--jacktrip-header"].map(parseJackTripPacketHeaderMode) ?? .default,
                transportMode: try values["--jacktrip-transport"].map(parseJackTripTransportMode) ?? .udp,
                pluginMode: try values["--jacktrip-plugin"].map(parseJackTripPluginMode) ?? .disabled,
                payloadEncoding: try values["--jacktrip-payload-encoding"].map(parseJackTripPayloadEncoding) ?? .pcm
            )
        )
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
