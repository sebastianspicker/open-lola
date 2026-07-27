// Builds a validated LoLa executable launch plan for control, media, and device settings.
func buildLoLaPlan(
    _ configuration: ExternalConnectorSessionConfiguration
) throws -> ExternalConnectorLaunchPlan {
    try validateTransmitPeer(configuration)
    _ = try lolaControlSessionID(configuration.sessionID)
    let mediaProfile = try ExternalConnectorMediaProfile.build(configuration: configuration)
    let audioWireFrameBytes = try LoLaCompatibilityMediaModel.audioWireFrameByteCount(
        channels: configuration.channels
    )
    let mediaBpfFilter = lolaMediaBpfFilter(configuration)
    return makeExternalConnectorLaunchPlan(
        configuration: configuration,
        details: ExternalConnectorLaunchPlanDetails(
        execution: .init(
            launchKind: .internalLoLaControl,
            arguments: lolaConnectorArguments(configuration)
        ),
        mediaProfile: mediaProfile,
        protocolFacts: lolaProtocolFacts(
            configuration: configuration,
            audioWireFrameBytes: audioWireFrameBytes,
            mediaBpfFilter: mediaBpfFilter
        ),
        sourceReferences: [
            "docs/reverse-engineering-boundary.md",
            "docs/compatibility-scope.md",
            "https://lola.conts.it/downloads/Lola_Manual_2.0.0_rev_001.pdf",
            "https://lola.conts.it/downloads/Lola_Manual_1.5.0_rev_001.pdf"
        ],
        evidenceBoundary: "Internal LoLa reverse-engineering evidence supports control fields, " +
            "ports, timing assumptions, and static media-envelope facts. " +
            LoLaCompatibilityMediaModel.evidenceBoundary
        )
    )
}

private func lolaMediaBpfFilter(
    _ configuration: ExternalConnectorSessionConfiguration
) -> String {
    let mediaFilterSource = configuration.role.transmits
        ? configuration.localHost
        : (configuration.peer.isEmpty ? "<peer>" : configuration.peer)
    let mediaFilterDestination = configuration.role.transmits
        ? configuration.peer
        : configuration.localHost
    return LoLaCompatibilityMediaModel.mediaBpfFilter(
        sourceHost: mediaFilterSource,
        destinationHost: mediaFilterDestination,
        audioPort: configuration.audioPort,
        videoPort: configuration.videoPort
    )
}

private func lolaConnectorArguments(
    _ configuration: ExternalConnectorSessionConfiguration
) -> [String] {
    let transportCommand = "internal-lola-control-\(configuration.controlTransport.rawValue)"
    var arguments = [
        transportCommand,
        "--role", configuration.role.rawValue,
        "--control-transport", configuration.controlTransport.rawValue,
        "--control-port", String(configuration.controlPort),
        "--audio-port", String(configuration.audioPort),
        "--video-port", String(configuration.videoPort),
        "--sample-rate", String(configuration.sampleRateHertz),
        "--frames", String(configuration.framesPerPacket),
        "--channels", String(configuration.channels),
        "--lola-video-payload", configuration.lolaVideoPayload.rawValue,
        "--video-compression", String(configuration.videoCompression),
        "--video-bayer", String(configuration.videoBayer)
    ]
    if let interfaceName = configuration.rawLinkInterface {
        arguments += [
            "--raw-link-interface", interfaceName,
            "--media-packets", String(configuration.mediaPacketCount)
        ]
    }
    return arguments
}

private func lolaProtocolFacts(
    configuration: ExternalConnectorSessionConfiguration,
    audioWireFrameBytes: Int,
    mediaBpfFilter: String
) -> [String] {
    [
        "control messages use visible /MESG_* names SRCIP, DSTIP, SID fields",
        "LoLa SID is numeric in recovered format strings",
        "recovered defaults use control/service port 7000, audio port 19788, video port 19798",
        "LoLa 2.0 public manual labels service/media ports UDP, while LoLa 1.5 " +
        "public manual labels service communication TCP 7000; plan uses " +
        "\(configuration.controlTransport.rawValue) control transport",
        "audio static evidence favors 64-frame int16 blocks 44.1 kHz behavior",
        "audio video media remain separate control/session lane",
        "media packets use 42-byte Ethernet/IPv4/UDP envelope before LoLa payload",
        "outer media wire-frame codec uses recovered EtherType IPv4, IPv4 header 0x45, " +
        "UDP protocol 0x11, encoder seed IPv4 ID 0x1337, variable decoded IPv4 IDs, " +
        "and IPv4/UDP checksum validation",
        "Linux seed audio wire sizing 42 + 1066 padded UDP payload bytes; " +
        "this plan expects \(audioWireFrameBytes) bytes \(configuration.channels) audio channels",
        "fragment helper evidence exposes 0x21 payload offset, 0xeeeeeeee marker, " +
        "1066-byte padded audio payloads, 30-slot video ring/sendqueue",
        "media capture filter shape: \(mediaBpfFilter)",
        "status-check uses /MESG_CHECKLOLASTATUS /MESG_CHECKLOLASTATUS_ACK before quick-connect",
        "quick-connect carries audio fields SR/BPS/CHNLS video fields FPS/BPP/X/Y/COMP/BAYER",
        "reject, disconnect, chat, bounce-back, generated-audio-signal control message " +
        "templates visible in v2.0 binary",
        "tx-rx mode is explicit simultaneous bidirectional source contract; it initiates " +
        "control like TX while attaching combined media TX generation and " +
        "RX envelope-validation evidence",
        "when raw-link options are supplied, LoLa media TX/RX uses macOS BPF raw-link " +
        "runner shared lola-raw-link-* commands RX bounded by session duration"
    ]
}
