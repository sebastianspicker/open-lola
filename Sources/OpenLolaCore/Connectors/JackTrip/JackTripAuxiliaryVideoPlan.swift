func jackTripAuxiliaryProcesses(
    _ configuration: ExternalConnectorSessionConfiguration
) throws -> [ExternalConnectorAuxiliaryProcessPlan] {
    guard configuration.mediaMode.hasVideo else {
        return []
    }
    let executable = try requiredVideoExecutable(configuration, defaultName: "uv")
    let portMap = try validateExternalConnectorProcessArgument(
        "\(configuration.videoPort):\(configuration.videoPort)",
        field: "jacktripAuxiliaryVideo.portMap",
        argumentClass: .ultraGridPortMap
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
    let videoDisplay = try validateExternalConnectorProcessArgument(
        configuration.videoDisplay ?? UltraGridDeviceDefaults.videoDisplay,
        field: "videoDisplay",
        argumentClass: .ultraGridModule
    )
    let peerArgument = try validateExternalConnectorProcessArgument(
        configuration.peer,
        field: "peer",
        argumentClass: .peerHost
    )
    let bidirectionalEndpoint = configuration.role == .txRx || (configuration.fullDuplex && !configuration.peer.isEmpty)
    var arguments: [String] = []
    if configuration.role.receives || bidirectionalEndpoint {
        arguments += ["-d", videoDisplay]
    }
    if configuration.role.transmits || bidirectionalEndpoint {
        arguments += ["-t", videoCapture]
    }
    arguments += ["-P", portMap, peerArgument]

    return [
        ExternalConnectorAuxiliaryProcessPlan(
            label: "jacktrip-auxiliary-ultragrid-video",
            executable: executable,
            arguments: arguments,
            mediaMode: .video,
            protocolFacts: [
                "JackTrip carries the audio leg only",
                "UltraGrid uv carries the video leg with -t on TX and -d on RX",
                "tx-rx mode always emits both auxiliary video transmit and receive arguments",
                "When a peer is known, one auxiliary UltraGrid uv process carries video send and receive together",
                "The auxiliary video leg accepts configured UltraGrid capture/display modules",
                "The auxiliary video leg uses the configured video UDP port",
            ],
            sourceReferences: [
                "https://github.com/CESNET/UltraGrid",
                "https://raw.githubusercontent.com/CESNET/UltraGrid/master/README.md",
            ]
        ),
    ]
}
