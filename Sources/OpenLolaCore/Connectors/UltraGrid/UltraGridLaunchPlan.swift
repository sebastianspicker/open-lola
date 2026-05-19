enum UltraGridDeviceDefaults {
    static let audioCapture = "coreaudio"
    static let audioPlayback = "coreaudio"
    static let videoDisplay = "gl"

    static func videoCapture(width: Int, height: Int, frameRate: Int) -> String {
        "testcard:\(width):\(height):\(frameRate):RGB"
    }
}

func buildUltraGridPlan(
    _ configuration: ExternalConnectorSessionConfiguration
) throws -> ExternalConnectorLaunchPlan {
    try validateUltraGridTopology(configuration)
    try validateUltraGridVideoDefaults(configuration)
    let mediaProfile = try ExternalConnectorMediaProfile.build(configuration: configuration)
    let portMap = try ultraGridPortMap(
        videoTxPort: configuration.videoPort,
        videoRxPort: configuration.videoPort,
        audioTxPort: configuration.audioPort,
        audioRxPort: configuration.audioPort
    )
    let videoCapture = try validateExternalConnectorProcessArgument(
        configuration.videoCapture
            ?? UltraGridDeviceDefaults.videoCapture(
                width: configuration.videoWidth,
                height: configuration.videoHeight,
                frameRate: configuration.videoFrameRate
            ),
        field: "videoCapture",
        argumentClass: .ultraGridModule
    )
    let audioCapture = try validateExternalConnectorProcessArgument(
        configuration.audioCapture ?? UltraGridDeviceDefaults.audioCapture,
        field: "audioCapture",
        argumentClass: .ultraGridModule
    )
    let videoDisplay = try validateExternalConnectorProcessArgument(
        configuration.videoDisplay ?? UltraGridDeviceDefaults.videoDisplay,
        field: "videoDisplay",
        argumentClass: .ultraGridModule
    )
    let audioPlayback = try validateExternalConnectorProcessArgument(
        configuration.audioPlayback ?? UltraGridDeviceDefaults.audioPlayback,
        field: "audioPlayback",
        argumentClass: .ultraGridModule
    )
    let peerArgument = try validateExternalConnectorProcessArgument(
        configuration.peer,
        field: "peer",
        argumentClass: .peerHost
    )
    var arguments: [String] = [
        "native-mvtp",
        "--pt-video", String(UltraGridCompatibility.videoPayloadType),
        "--pt-audio", String(UltraGridCompatibility.audioPayloadType),
        "--ports", portMap,
    ]
    let bidirectionalEndpoint = configuration.role == .txRx || (configuration.fullDuplex && !configuration.peer.isEmpty)
    if configuration.role.receives || bidirectionalEndpoint {
        arguments += ["--video-display", videoDisplay]
        if configuration.mediaMode.hasAudio {
            arguments += ["--audio-playback", audioPlayback]
        }
    }
    if configuration.role.transmits || bidirectionalEndpoint {
        arguments += ["--video-capture", videoCapture]
        if configuration.mediaMode.hasAudio {
            arguments += ["--audio-capture", audioCapture]
        }
    }
    arguments += [
        "--topology", configuration.ultraGridTopologyMode.rawValue,
        "--topology-role", configuration.ultraGridTopologyRole.rawValue,
        "--pt-audio-negotiated", String(configuration.ultraGridAudioPayloadType),
        "--pt-video-negotiated", String(configuration.ultraGridVideoPayloadType),
        "--fec", configuration.ultraGridFECMode.rawValue,
        "--encryption", configuration.ultraGridEncryptionMode.rawValue,
        "--control", configuration.ultraGridControlMode.rawValue,
    ]
    if configuration.ultraGridControlMode != .disabled {
        let controlPort = configuration.controlPort == 0
            ? UltraGridControlReportBuilder.defaultControlPort
            : configuration.controlPort
        arguments += ["--control-port", String(controlPort)]
    }
    for command in configuration.ultraGridControlCommands {
        arguments += ["--control-command", try command.encodedLine().trimmingCharacters(in: .whitespacesAndNewlines)]
    }
    if configuration.ultraGridEncryptionMode != .none {
        arguments += ["--encryption-passphrase", "<redacted>"]
    }
    if !peerArgument.isEmpty {
        arguments += ["--peer", peerArgument]
    }

    return ExternalConnectorLaunchPlan(
        connector: .mvtpUltraGrid,
        role: configuration.role,
        launchKind: .internalUltraGridMvtp,
        executable: nil,
        arguments: arguments,
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
            "Open LoLa uses a Swift-native RTP/MVTP runtime for mvtp-ultragrid sessions instead of launching uv as the primary runtime",
            "UltraGrid-compatible RTP payload type 20 carries the first-slice raw video fragment payloads",
            "UltraGrid-compatible RTP payload type 21 carries the first-slice PCM audio payloads",
            "Dynamic RTP payload negotiation can map configured payload types to implemented PCM audio, raw-video, RTP/JPEG, and RTP/H.264 codecs",
            "UltraGrid-compatible RTP payload type 22 carries a bounded single-parity FEC envelope for local loss recovery; reference LDGM parity still requires measured peer evidence",
            "UltraGrid-compatible RTP payload types 24 and 25 carry AES-128-GCM encrypted raw-video and PCM-audio packet payloads with redacted key material in reports",
            "UltraGrid control socket commands are modeled as CRLF-delimited TCP command frames without claiming reference peer control-plane success",
            "open-lola keeps UltraGrid capture/playback/display module names as reference metadata for parity and hardware wiring checks",
            "UltraGrid public NAT documentation identifies UDP 5004 for video and 5006 for audio by default",
            "UltraGrid server-client topology is modeled explicitly without converting local listener readiness into field-route evidence",
        ],
        sourceReferences: [
            "https://github.com/CESNET/UltraGrid",
            "https://raw.githubusercontent.com/CESNET/UltraGrid/master/README.md",
            "https://github.com/CESNET/UltraGrid/wiki/NAT-traversal",
            "https://github.com/CESNET/UltraGrid/wiki/Development#packet-formats",
            "https://raw.githubusercontent.com/wiki/CESNET/UltraGrid/Encryption.md",
            "https://raw.githubusercontent.com/CESNET/UltraGrid/master/src/rtp/rtp_types.h",
            "https://raw.githubusercontent.com/CESNET/UltraGrid/master/src/crypto/openssl_encrypt.c",
            "https://raw.githubusercontent.com/CESNET/UltraGrid/master/src/crypto/openssl_decrypt.c",
            "https://raw.githubusercontent.com/wiki/CESNET/UltraGrid/UltraGrid-packet-types.md",
            "https://www.rfc-editor.org/rfc/rfc2435",
            "https://www.rfc-editor.org/rfc/rfc6184",
            "https://raw.githubusercontent.com/CESNET/UltraGrid/master/src/control_socket.cpp",
        ],
        evidenceBoundary: UltraGridCompatibility.evidenceBoundary
    )
}

func ultraGridPeerRequired(_ configuration: ExternalConnectorSessionConfiguration) -> Bool {
    if configuration.ultraGridTopologyMode == .serverClient,
       configuration.ultraGridTopologyRole == .server {
        return false
    }
    return configuration.role.transmits || configuration.role == .txRx || configuration.ultraGridTopologyMode == .directPeer
}

private func validateUltraGridTopology(_ configuration: ExternalConnectorSessionConfiguration) throws {
    switch (configuration.ultraGridTopologyMode, configuration.ultraGridTopologyRole) {
    case (.directPeer, .direct), (.serverClient, .server), (.serverClient, .client):
        break
    default:
        throw ExternalConnectorSessionError.unsupportedRuntimeMode(
            "ultragrid-topology-\(configuration.ultraGridTopologyMode.rawValue)-\(configuration.ultraGridTopologyRole.rawValue)"
        )
    }
    if ultraGridPeerRequired(configuration), configuration.peer.isEmpty {
        throw ExternalConnectorSessionError.missingRequiredArgument("--peer")
    }
}

private func validateUltraGridVideoDefaults(_ configuration: ExternalConnectorSessionConfiguration) throws {
    guard configuration.mediaMode.hasVideo, configuration.videoCapture == nil else {
        return
    }
    try validateUltraGridPositiveInteger(configuration.videoWidth, "videoWidth")
    try validateUltraGridPositiveInteger(configuration.videoHeight, "videoHeight")
    try validateUltraGridPositiveInteger(configuration.videoFrameRate, "videoFrameRate")
}

private func validateUltraGridPositiveInteger(_ value: Int, _ field: String) throws {
    guard value > 0 else {
        throw ExternalConnectorSessionError.invalidPositiveInteger(field, String(value))
    }
}

private func ultraGridPortMap(
    videoTxPort: UInt16,
    videoRxPort: UInt16,
    audioTxPort: UInt16,
    audioRxPort: UInt16
) throws -> String {
    try validateUltraGridPort(videoTxPort, "ultragrid.videoTxPort")
    try validateUltraGridPort(videoRxPort, "ultragrid.videoRxPort")
    try validateUltraGridPort(audioTxPort, "ultragrid.audioTxPort")
    try validateUltraGridPort(audioRxPort, "ultragrid.audioRxPort")
    return try validateExternalConnectorProcessArgument(
        "\(videoTxPort):\(videoRxPort):\(audioTxPort):\(audioRxPort)",
        field: "ultragrid.portMap",
        argumentClass: .ultraGridPortMap
    )
}

private func validateUltraGridPort(_ port: UInt16, _ field: String) throws {
    guard port > 0 else {
        throw ExternalConnectorSessionError.invalidPort(field, String(port))
    }
}
