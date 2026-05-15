import Foundation

func buildJackTripPlan(
    _ configuration: ExternalConnectorSessionConfiguration
) throws -> ExternalConnectorLaunchPlan {
    let executable = try requiredExecutable(configuration, connector: .jackTrip, defaultName: "jacktrip")
    try validateTransmitPeer(configuration)
    let mediaProfile = try ExternalConnectorMediaProfile.build(configuration: configuration)
    try validateJackTripVideoPeer(configuration)
    let auxiliaryProcesses = try jackTripAuxiliaryProcesses(configuration)
    let peerAudioPort = try jackTripRequiredPeerAudioPort(configuration)
    let peer = try validateExternalConnectorProcessArgument(
        configuration.peer,
        field: "peer",
        argumentClass: .peerHost
    )
    var arguments = configuration.role.transmits ? ["-c", peer] : ["-s"]
    arguments += [
        "-R",
        "-n", String(configuration.channels),
        "-q", String(configuration.jackTrip.queueDepth),
        "-r", String(configuration.jackTrip.redundancy),
        "-B", String(configuration.audioPort),
        "-T", String(configuration.sampleRateHertz),
        "-F", String(configuration.framesPerPacket),
    ]
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
        launchKind: .externalProcess,
        executable: executable,
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
            "JackTrip public CLI exposes P2P server (-s) and client (-c host) modes",
            "JackTrip public CLI exposes channel count, queue, redundancy, bind/peer port, sample-rate, and buffer-size options",
            "JackTrip P2P server mode binds the local audio port; client mode targets the peer audio port explicitly",
            "JackTrip RtAudio mode (-R) uses the system audio backend instead of requiring a JACK graph",
            "JackTrip RtAudio mode exposes input and output device-name options for production endpoint routing",
            "JackTrip default peer UDP port is 4464; open-lola makes that port explicit in the launch plan",
            "tx-rx mode uses the peer-known JackTrip client endpoint because JackTrip audio is bidirectional after connection establishment",
            "JackTrip is an audio protocol; audio-video mode pairs JackTrip audio with an auxiliary UltraGrid video process",
        ],
        sourceReferences: [
            "https://github.com/jacktrip/jacktrip",
            "https://raw.githubusercontent.com/jacktrip/jacktrip/main/README.md",
            "https://raw.githubusercontent.com/jacktrip/jacktrip/main/src/Settings.cpp",
            "https://jacktrip.github.io/jacktrip/",
            "https://github.com/CESNET/UltraGrid",
            "https://raw.githubusercontent.com/CESNET/UltraGrid/master/README.md",
        ],
        evidenceBoundary: "External JackTrip owns audio behavior. Audio-video mode uses UltraGrid as a separate video carrier because JackTrip itself is audio-only."
    )
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
