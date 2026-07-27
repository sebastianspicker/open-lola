// Verifies that external connector launch plans cover UltraGrid JackTrip and AV transport ports.
import Foundation
import Darwin
import Testing

@testable import OpenLolaCore

@Test
func externalConnectorLaunchPlansCoverUltraGridJackTripAndAvTransportPorts() throws {
    let txPlan = try ultraGridLaunchPlan(
        role: .tx,
        peer: "198.51.100.10",
        outputPath: "/tmp/ug-tx.json"
    )
    let rxPlan = try ultraGridLaunchPlan(
        role: .rx,
        peer: "198.51.100.20",
        outputPath: "/tmp/ug-rx.json"
    )

    #expect(txPlan.launchKind == .internalUltraGridMvtp)
    #expect(txPlan.executable == nil)
    #expect(txPlan.arguments.contains("--video-capture"))
    #expect(txPlan.arguments.contains("--audio-capture"))
    #expect(txPlan.arguments.contains("5004:5004:5006:5006"))
    #expect(rxPlan.arguments.contains("--video-display"))
    #expect(rxPlan.arguments.contains("--audio-playback"))
    #expect(rxPlan.videoPort == 5004)
    #expect(rxPlan.audioPort == 5006)
    #expect(txPlan.mediaProfile.mode == .audioVideo)
    #expect(txPlan.mediaProfile.audioEnabled)
    #expect(txPlan.mediaProfile.videoEnabled)
    #expect(txPlan.sourceReferences.contains("https://github.com/CESNET/UltraGrid"))
    #expect(txPlan.sourceReferences.contains(
        "https://raw.githubusercontent.com/CESNET/UltraGrid/master/README.md"
    ))
    #expect(txPlan.sourceReferences.contains(
        "https://github.com/CESNET/UltraGrid/wiki/NAT-traversal"
    ))
    #expect(txPlan.sourceReferences.contains(
        "https://raw.githubusercontent.com/wiki/CESNET/UltraGrid/UltraGrid-packet-types.md"
    ))
}

private func ultraGridLaunchPlan(
    role: ExternalConnectorSessionRole,
    peer: String,
    outputPath: String
) throws -> ExternalConnectorLaunchPlan {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: role,
        peer: peer,
        outputPath: outputPath
    ))
    return try ExternalConnectorLaunchPlan.build(configuration: configuration)
}

@Test
func externalConnectorLaunchPlansCoverJackTripAudioPorts() throws {
    let jackTripTx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-tx.json"
) { input in
  input.audioPort = 4465
  input.peerAudioPort = 4464
  input.channels = 8
  input.jackTrip = JackTripRunConfiguration { $0.queueDepth = 6; $0.redundancy = 2 }
}))
    #expect(jackTripTx.launchKind == .internalJackTripAudio)
    #expect(jackTripTx.executable == nil)
    #expect(jackTripTx.arguments.starts(with: ["-c", "203.0.113.10"]))
    #expect(jackTripTx.arguments.contains("-R"))
    #expect(jackTripTx.arguments.contains("-n"))
    #expect(jackTripTx.arguments.contains("8"))
    #expect(commandValue(jackTripTx.arguments, "-q") == "6")
    #expect(commandValue(jackTripTx.arguments, "-r") == "2")
    #expect(commandValue(jackTripTx.arguments, "-B") == "4465")
    #expect(commandValue(jackTripTx.arguments, "-P") == "4464")
    #expect(jackTripTx.protocolFacts.contains { $0.contains("direct UDP endpoint") })
    #expect(jackTripTx.mediaProfile.mode == .audio)
    #expect(jackTripTx.mediaProfile.audioEnabled)
    #expect(!jackTripTx.mediaProfile.videoEnabled)
    #expect(jackTripTx.auxiliaryProcesses.isEmpty)
    #expect(jackTripTx.sourceReferences.contains("https://github.com/jacktrip/jacktrip"))
    #expect(jackTripTx.sourceReferences.contains(
        "https://raw.githubusercontent.com/jacktrip/jacktrip/main/src/Settings.cpp"
    ))
    #expect(jackTripTx.sourceReferences.contains(
        "https://raw.githubusercontent.com/jacktrip/jacktrip/main/docs/Documentation/NetworkProtocol.md"
    ))
    #expect(jackTripTx.sourceReferences.contains(
        "https://raw.githubusercontent.com/jacktrip/jacktrip/main/src/PacketHeader.h"
    ))
    #expect(jackTripTx.sourceReferences.contains("https://jacktrip.github.io/jacktrip/"))
}
@Test
func externalConnectorLaunchPlansCoverJackTripRxAudioPorts() throws {
    let jackTripRx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .rx,
  peer: "",
  outputPath: "/tmp/jacktrip-rx.json"
) { input in
  input.channels = 8
}))

    #expect(jackTripRx.arguments.first == "-s")
    #expect(jackTripRx.arguments.contains("-R"))
    #expect(commandValue(jackTripRx.arguments, "-B") == "4464")
    #expect(commandValue(jackTripRx.arguments, "-P") == nil)
    #expect(jackTripRx.audioPort == 4464)
    #expect(jackTripRx.videoPort == 5004)
}
@Test
func externalConnectorLaunchPlansCoverJackTripAvTransportPorts() throws {
    let jackTripAvTx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-av-tx.json"
) { input in
  input.mediaMode = .audioVideo
  input.peerAudioPort = 4464
}))
    let jackTripAvRx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .rx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-av-rx.json"
) { input in
  input.mediaMode = .audioVideo
}))

    #expect(jackTripAvTx.arguments.starts(with: ["-c", "203.0.113.10"]))
    #expect(jackTripAvTx.mediaProfile.mode == .audioVideo)
    #expect(jackTripAvTx.mediaProfile.audioEnabled)
    #expect(jackTripAvTx.mediaProfile.videoEnabled)
    #expect(jackTripAvTx.auxiliaryProcesses.count == 1)
    #expect(jackTripAvTx.auxiliaryProcesses[0].executable == "uv")
    #expect(jackTripAvTx.auxiliaryProcesses[0].arguments.contains("-t"))
    #expect(jackTripAvTx.auxiliaryProcesses[0].arguments.contains("5004:5004"))
    #expect(jackTripAvRx.arguments.first == "-s")
    #expect(jackTripAvRx.auxiliaryProcesses.count == 1)
    #expect(jackTripAvRx.auxiliaryProcesses[0].arguments.contains("-d"))
    #expect(jackTripAvRx.auxiliaryProcesses[0].arguments.contains("5004:5004"))
    #expect(jackTripAvRx.auxiliaryProcesses[0].arguments.last == "203.0.113.10")
    #expect(jackTripAvTx.protocolFacts.contains { $0.contains("audio-video mode pairs native JackTrip audio") })
    #expect(jackTripAvTx.sourceReferences.contains("https://github.com/CESNET/UltraGrid"))
}
@Test
func externalConnectorConfigurationAndLaunchPlanParsesValidInputs() throws {
    let parsed = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "mvtp-ultragrid",
        "--role", "rx",
        "--peer", "198.51.100.20",
        "--output", "/tmp/ug.json",
        "--dry-run", "true",
        "--video-executable", "uv",
        "--media", "audio-video",
        "--channels", "4",
        "--video-width", "1280",
        "--video-height", "720",
        "--video-fps", "60",
        "--ultragrid-audio-payload-type", "96",
        "--ultragrid-video-payload-type", "97",
        "--ultragrid-fec", "single-parity",
        "--ultragrid-control", "local-tcp",
        "--ultragrid-control-command", "stats on"
    ])

    #expect(parsed.connector == .mvtpUltraGrid)
    #expect(parsed.role == .rx)
    #expect(parsed.mediaMode == .audioVideo)
    #expect(parsed.videoExecutable == "uv")
    #expect(parsed.channels == 4)
    #expect(parsed.audioPort == 5006)
    #expect(parsed.videoWidth == 1280)
    #expect(parsed.videoHeight == 720)
    #expect(parsed.videoFrameRate == 60)
    #expect(parsed.ultraGridAudioPayloadType == 96)
    #expect(parsed.ultraGridVideoPayloadType == 97)
    #expect(parsed.ultraGridFECMode == .singleParity)
    #expect(parsed.ultraGridControlMode == .localTCP)
    #expect(try parsed.ultraGridControlCommands.map { try $0.encodedLine() } == ["stats on\r\n"])

    let ultraGridServerConfiguration = ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .rx,
        peer: "",
        outputPath: "/tmp/ug-server.json"
    ) { input in
        input.ultraGridTopologyMode = .serverClient
        input.ultraGridTopologyRole = .server
    })
    let ultraGridServer = try ExternalConnectorLaunchPlan.build(
        configuration: ultraGridServerConfiguration
    )
    #expect(ultraGridServer.peer.isEmpty)
    #expect(!ultraGridServer.arguments.contains("--peer"))
    #expect(commandValue(ultraGridServer.arguments, "--topology") == "server-client")
    #expect(commandValue(ultraGridServer.arguments, "--topology-role") == "server")
}
@Test
func externalConnectorConfigurationAndLaunchPlanRejectInvalidInputs() throws {
    #expect(throws: ExternalConnectorSessionError.invalidConnector("mtvp-ultragrid")) {
        try ExternalConnectorSessionConfiguration.parse([
            "--connector", "mtvp-ultragrid",
            "--role", "rx",
            "--peer", "198.51.100.20",
            "--output", "/tmp/ug.json"
        ])
    }

    let missingPeerPortConfiguration = ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-missing-peer-port.json"
))

    #expect(throws: ExternalConnectorSessionError.missingRequiredArgument("--peer-audio-port")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: missingPeerPortConfiguration)
    }

    #expect(throws: ExternalConnectorSessionError.connectorDoesNotSupportMediaMode(.jackTrip, .video)) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .rx,
  peer: "",
  outputPath: "/tmp/jacktrip-video.json"
) { input in
  input.mediaMode = .video
}))
    }

    let audioOnlyConfiguration = ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .rx,
        peer: "198.51.100.20",
        outputPath: "/tmp/ug-audio.json"
    ) { input in
        input.mediaMode = .audio
    })
    let audioOnlyUltraGrid = try ExternalConnectorLaunchPlan.build(
        configuration: audioOnlyConfiguration
    )
    #expect(audioOnlyUltraGrid.mediaProfile.mode == .audio)
    #expect(audioOnlyUltraGrid.protocolFacts.contains { $0.contains("payload type 21") })
}
@Test
func externalConnectorLaunchPlanRejectsUnsafeAndOutOfRangeInputs() throws {
    #expect(throws: ExternalConnectorSessionError.invalidPort("videoPort", "0")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .txRx,
  peer: "198.51.100.10",
  outputPath: "/tmp/ug-zero-video-port.json"
) { input in
  input.videoPort = 0
}))
    }

    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("videoCapture", "--help")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .tx,
  peer: "198.51.100.10",
  outputPath: "/tmp/ug-option-video-capture.json"
) { input in
  input.videoCapture = "--help"
}))
    }

    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("videoCapture", "--help")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-av-option-video-capture.json"
) { input in
  input.mediaMode = .audioVideo
  input.peerAudioPort = 4464
  input.videoCapture = "--help"
}))
    }

    #expect(throws: ExternalConnectorSessionError.connectorRequiresPeerForTx(.jackTrip)) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "",
  outputPath: "/tmp/jacktrip-tx.json"
)))
    }
}
@Test
func externalConnectorLaunchPlanRejectsInvalidLoLaAndDurationInputs() throws {
    #expect(throws: ExternalConnectorSessionError.invalidLoLaSessionID("sid-1")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-invalid-session.json"
) { input in
  input.sessionID = "sid-1"
}))
    }

    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger("durationSeconds", "-1")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-negative-duration.json"
) { input in
  input.durationSeconds = -1
}))
    }

    #expect(throws: ExternalConnectorSessionError.invalidPort("controlPort", "0")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/lola-zero-control-port.json"
) { input in
  input.controlPort = 0
}))
    }
}
@Test
func externalConnectorPlansPreserveWhitespaceDeviceNamesAsSingleArguments() throws {
    let ultraGrid = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .txRx,
  peer: "198.51.100.10",
  outputPath: "/tmp/ug-whitespace-devices.json"
) { input in
  input.audioCapture = "Studio Input 1"
  input.audioPlayback = "Studio Output 1"
  input.videoCapture = "decklink:device=Studio Camera 1"
  input.videoDisplay = "DeckLink Studio Display"
}))

    #expect(commandValue(ultraGrid.arguments, "--audio-capture") == "Studio Input 1")
    #expect(commandValue(ultraGrid.arguments, "--audio-playback") == "Studio Output 1")
    #expect(commandValue(ultraGrid.arguments, "--video-capture") == "decklink:device=Studio Camera 1")
    #expect(commandValue(ultraGrid.arguments, "--video-display") == "DeckLink Studio Display")

    let jackTrip = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-whitespace-devices.json"
) { input in
  input.peerAudioPort = 4464
  input.audioCapture = "RME MADI Input 1"
  input.audioPlayback = "RME MADI Output 1"
}))

    #expect(commandValue(jackTrip.arguments, "--audioinputdevice") == "RME MADI Input 1")
    #expect(commandValue(jackTrip.arguments, "--audiooutputdevice") == "RME MADI Output 1")
}
