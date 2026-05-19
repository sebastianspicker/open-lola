import Foundation

func buildJackTripPlan(
    _ configuration: ExternalConnectorSessionConfiguration
) throws -> ExternalConnectorLaunchPlan {
    let mediaProfile = try ExternalConnectorMediaProfile.build(configuration: configuration)
    try validateJackTripTopology(configuration)
    try validateJackTripVideoPeer(configuration)
    let auxiliaryProcesses = try jackTripAuxiliaryProcesses(configuration)
    let peerAudioPort = try jackTripRequiredPeerAudioPort(configuration)
    let peer = try validateExternalConnectorProcessArgument(
        configuration.peer,
        field: "peer",
        argumentClass: .peerHost
    )
    var arguments = try jackTripTopologyArguments(configuration, peer: peer)
    arguments += [
        "-R",
        "-n", String(configuration.channels),
        "-q", String(configuration.jackTrip.queueDepth),
        "-r", String(configuration.jackTrip.redundancy),
        "-B", String(configuration.audioPort),
        "-T", String(configuration.sampleRateHertz),
        "-F", String(configuration.framesPerPacket),
        "--bit-resolution", String(configuration.jackTrip.bitResolutionBits),
        "--packet-header", configuration.jackTrip.packetHeaderMode.rawValue,
        "--transport", configuration.jackTrip.transportMode.rawValue,
        "--plugin", configuration.jackTrip.pluginMode.rawValue,
        "--payload-encoding", configuration.jackTrip.payloadEncoding.rawValue,
        "--topology", configuration.jackTrip.topologyMode.rawValue,
        "--topology-role", configuration.jackTrip.topologyRole.rawValue,
    ]
    if configuration.jackTrip.topologyMode == .hubVirtualStudio {
        arguments += ["--hub-patch", configuration.jackTrip.hubPatchMode.label]
    }
    if configuration.jackTrip.hubTCPHandshakeMode != .none {
        arguments += ["--hub-tcp-handshake", configuration.jackTrip.hubTCPHandshakeMode.rawValue]
    }
    if let remoteClientName = configuration.jackTrip.remoteClientName {
        arguments += ["--remote-client-name", try validateExternalConnectorProcessArgument(
            remoteClientName,
            field: "jackTrip.remoteClientName",
            argumentClass: .jackTripRemoteClientName
        )]
    }
    if let peerAudioPort {
        arguments += ["-P", String(peerAudioPort)]
    }
    if let audioCapture = configuration.audioCapture {
        arguments += ["--audioinputdevice", try validateExternalConnectorProcessArgument(
            audioCapture,
            field: "audioCapture",
            argumentClass: .jackTripAudioDevice
        )]
    }
    if let audioPlayback = configuration.audioPlayback {
        arguments += ["--audiooutputdevice", try validateExternalConnectorProcessArgument(
            audioPlayback,
            field: "audioPlayback",
            argumentClass: .jackTripAudioDevice
        )]
    }

    return ExternalConnectorLaunchPlan(
        connector: .jackTrip,
        role: configuration.role,
        launchKind: .internalJackTripAudio,
        executable: nil,
        arguments: arguments,
        auxiliaryProcesses: auxiliaryProcesses,
        peer: configuration.peer,
        localHost: configuration.localHost,
        controlPort: configuration.controlPort,
        audioPort: configuration.audioPort,
        videoPort: configuration.videoPort,
        mediaProfile: mediaProfile,
        channels: configuration.channels,
        sampleRateHertz: configuration.sampleRateHertz,
        framesPerPacket: configuration.framesPerPacket,
        protocolFacts: [
            "JackTrip UDP audio datagrams carry a DEFAULT header, compact JAMLINK header, or the public EMPTY header mode with raw planar PCM only",
            "JackTrip DEFAULT header is the public DefaultHeaderStruct layout copied as host-order bytes by the reference implementation",
            "JackTrip JAMLINK header support is bounded to representable 16-bit mono/stereo PCM with encoded sample-rate, sequence, timestamp, and samples-per-packet fields",
            "Open LoLa supports little-endian desktop DEFAULT packets with 8/16/24/32-bit PCM, explicit channels, sample-rate enum, sequence number, timestamp, and buffer size",
            "Open LoLa supports JackTrip EMPTY header mode only with explicit local sample-rate, bit-depth, channel, and frame-size configuration because the wire payload carries no header metadata",
            "JackTrip redundancy concatenates full packets in one datagram; this native slice models redundancy as bounded packet copies across UDP-equivalent transports",
            "JackTrip default peer UDP port is 4464; open-lola makes that port explicit in the launch plan",
            "JackTrip WebRTC data-channel mode carries the same packet bytes as the UDP stream over an unordered unreliable data channel after WSS signaling",
            "JackTrip WebTransport mode carries the same packet bytes as UDP after a QUIC varint quarter-stream prefix in each HTTP/3 datagram",
            "tx-rx mode uses the peer-known direct UDP endpoint because JackTrip P2P audio is bidirectional after the first datagram establishes the peer endpoint",
            "JackTrip hub virtual-studio topology is modeled explicitly: hub servers listen for clients, hub clients require a configured hub peer, and patch mode is recorded without claiming managed Virtual Studio cloud evidence",
            "JackTrip unauthenticated hub TCP handshake exchanges a little-endian client UDP port, optional fixed-width client name, and little-endian server UDP port before UDP audio flows",
            "JackTrip audio backend selection is explicit: coreaudio uses the native provider path, while jack-graph requires measured JACK graph capture evidence for non-dry runs",
            "JackTrip plugin bridge mode is modeled as an audio-source boundary; plugin-host loading remains external to this packet runtime",
            "JackTrip non-PCM audio is modeled as an Open LoLa Opus CELT low-delay extension envelope and is not promoted to reference JackTrip interoperability without measured peer evidence",
            "JackTrip is an audio protocol; audio-video mode pairs native JackTrip audio with an auxiliary UltraGrid-compatible video process",
        ],
        sourceReferences: [
            "https://github.com/jacktrip/jacktrip",
            "https://raw.githubusercontent.com/jacktrip/jacktrip/main/README.md",
            "https://raw.githubusercontent.com/jacktrip/jacktrip/main/src/Settings.cpp",
            "https://raw.githubusercontent.com/jacktrip/jacktrip/main/docs/Documentation/NetworkProtocol.md",
            "https://raw.githubusercontent.com/jacktrip/jacktrip/main/src/PacketHeader.h",
            "https://raw.githubusercontent.com/jacktrip/jacktrip/main/src/Settings.cpp",
            "https://jacktrip.github.io/jacktrip/",
            "https://github.com/CESNET/UltraGrid",
            "https://raw.githubusercontent.com/CESNET/UltraGrid/master/README.md",
        ],
        evidenceBoundary: "Swift-native JackTrip owns the audio packetization path for DEFAULT, JAMLINK, EMPTY, WebRTC data-channel, WebTransport datagram, and Opus-extension payloads, and models the unauthenticated hub TCP port exchange. Audio-video mode uses UltraGrid as a separate video carrier because JackTrip itself is audio-only. Hub TCP, plugin, WebRTC, WebTransport, and Opus-extension readiness is not managed Virtual Studio cloud or reference-peer evidence. Real JackTrip peer interoperability remains PARTIAL until measured peer capture evidence exists."
    )
}

private func jackTripTopologyArguments(
    _ configuration: ExternalConnectorSessionConfiguration,
    peer: String
) throws -> [String] {
    switch (configuration.jackTrip.topologyMode, configuration.jackTrip.topologyRole) {
    case (.directPeer, .direct):
        return configuration.role.transmits ? ["-c", peer] : ["-s"]
    case (.hubVirtualStudio, .hubServer):
        return ["-S", "-p", String(configuration.jackTrip.hubPatchMode.rawValue)]
    case (.hubVirtualStudio, .hubClient):
        return ["-C", peer]
    default:
        throw ExternalConnectorSessionError.unsupportedRuntimeMode(
            "jacktrip-topology-\(configuration.jackTrip.topologyMode.rawValue)-\(configuration.jackTrip.topologyRole.rawValue)"
        )
    }
}

private func validateJackTripTopology(_ configuration: ExternalConnectorSessionConfiguration) throws {
    switch (configuration.jackTrip.topologyMode, configuration.jackTrip.topologyRole) {
    case (.directPeer, .direct), (.hubVirtualStudio, .hubServer), (.hubVirtualStudio, .hubClient):
        break
    default:
        throw ExternalConnectorSessionError.unsupportedRuntimeMode(
            "jacktrip-topology-\(configuration.jackTrip.topologyMode.rawValue)-\(configuration.jackTrip.topologyRole.rawValue)"
        )
    }
    if jackTripLaunchPlanPeerRequired(configuration), configuration.peer.isEmpty {
        if configuration.jackTrip.topologyMode == .directPeer {
            throw ExternalConnectorSessionError.connectorRequiresPeerForTx(.jackTrip)
        }
        throw ExternalConnectorSessionError.missingRequiredArgument("--peer")
    }
}

private func jackTripLaunchPlanPeerRequired(_ configuration: ExternalConnectorSessionConfiguration) -> Bool {
    if configuration.jackTrip.topologyMode == .hubVirtualStudio,
       configuration.jackTrip.topologyRole == .hubServer {
        return false
    }
    if configuration.jackTrip.topologyMode == .hubVirtualStudio,
       configuration.jackTrip.topologyRole == .hubClient {
        return true
    }
    return configuration.role.transmits || configuration.role == .txRx
}

private func validateJackTripVideoPeer(_ configuration: ExternalConnectorSessionConfiguration) throws {
    if configuration.mediaMode.hasVideo, configuration.peer.isEmpty {
        throw ExternalConnectorSessionError.missingRequiredArgument("--peer")
    }
}

private func jackTripRequiredPeerAudioPort(
    _ configuration: ExternalConnectorSessionConfiguration
) throws -> UInt16? {
    guard configuration.role.transmits else {
        return nil
    }
    guard let peerAudioPort = configuration.peerAudioPort else {
        throw ExternalConnectorSessionError.missingRequiredArgument("--peer-audio-port")
    }
    return peerAudioPort
}
