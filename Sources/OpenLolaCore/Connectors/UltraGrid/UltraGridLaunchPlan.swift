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
    let executable = try requiredExecutable(configuration, connector: .mvtpUltraGrid, defaultName: "uv")
    try validateTransmitPeer(configuration)
    try validateUltraGridVideoDefaults(configuration)
    let mediaProfile = try ExternalConnectorMediaProfile.build(configuration: configuration)
    try validateUltraGridPeer(configuration)
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
    var arguments: [String] = []
    let bidirectionalEndpoint = configuration.role == .txRx || (configuration.fullDuplex && !configuration.peer.isEmpty)
    if configuration.role.receives || bidirectionalEndpoint {
        arguments += ["-d", videoDisplay]
        if configuration.mediaMode.hasAudio {
            arguments += ["-r", audioPlayback]
        }
    }
    if configuration.role.transmits || bidirectionalEndpoint {
        arguments += ["-t", videoCapture]
        if configuration.mediaMode.hasAudio {
            arguments += ["-s", audioCapture]
        }
    }
    arguments += ["-P", portMap, peerArgument]

    return ExternalConnectorLaunchPlan(
        connector: .mvtpUltraGrid,
        role: configuration.role,
        launchKind: .externalProcess,
        executable: executable,
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
            "UltraGrid uses the uv command for capture/transmit and display/receive modes",
            "UltraGrid examples use -t for video transmit, -d for display receive, -s for audio capture, and -r for audio playback",
            "UltraGrid can use one uv instance for simultaneous send and receive when both -t and -d are present",
            "tx-rx mode always emits both transmit and receive arguments in one uv process",
            "open-lola exposes UltraGrid capture/playback/display modules so production devices can replace testcard/gl defaults",
            "UltraGrid public NAT documentation identifies UDP 5004 for video and 5006 for audio by default",
        ],
        sourceReferences: [
            "https://github.com/CESNET/UltraGrid",
            "https://raw.githubusercontent.com/CESNET/UltraGrid/master/README.md",
            "https://github.com/CESNET/UltraGrid/wiki/NAT-traversal",
        ],
        evidenceBoundary: "External UltraGrid process owns MVTP/RTP/UDP protocol behavior; open-lola supplies a reproducible launch plan and evidence report."
    )
}

private func validateUltraGridPeer(_ configuration: ExternalConnectorSessionConfiguration) throws {
    if configuration.peer.isEmpty {
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
