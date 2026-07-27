// Builds dry-run endpoint commands and report entries from a connection plan, centralizing per-side connector argument construction.
import Foundation

/// Parses a two-sided connector plan, validates both endpoints, and writes the plan report.
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
        let context = try endpointContext(configuration, side: side, direction: direction, role: role)
        let session = endpointSession(configuration, context: context)
        let plan = try ExternalConnectorLaunchPlan.build(configuration: session)
        let command = endpointCommand(session, plan: plan)
        return ExternalConnectorConnectionEndpoint(
            id: context.id,
            side: side,
            direction: direction,
            role: role,
            plan: plan,
            command: command,
            shellCommand: connectionPlanShellCommand(command)
        )
    }

    private static func endpointSession(
        _ configuration: ExternalConnectorConnectionPlanConfiguration,
        context: ExternalConnectorConnectionEndpointContext
    ) -> ExternalConnectorSessionConfiguration {
        ExternalConnectorSessionConfiguration(.init(
  connector: configuration.connector,
  role: context.role,
  peer: context.peer,
  outputPath: context.outputPath
) { input in
  input.localHost = context.localHost
  input.executable = configuration.executable
  input.videoExecutable = configuration.videoExecutable
  input.dryRun = true
  input.mediaMode = configuration.mediaMode
  input.controlTransport = configuration.controlTransport
  input.durationSeconds = configuration.durationSeconds
  input.controlPort = context.controlPort
  input.audioPort = context.audioPort
  input.peerAudioPort = context.peerAudioPort
  input.videoPort = context.videoPort
  input.channels = configuration.channels
  input.sampleRateHertz = configuration.sampleRateHertz
  input.framesPerPacket = configuration.framesPerPacket
  input.videoWidth = configuration.videoWidth
  input.videoHeight = configuration.videoHeight
  input.videoFrameRate = configuration.videoFrameRate
  input.videoBitsPerPixel = configuration.videoBitsPerPixel
  input.audioCapture = configuration.audioCapture
  input.audioPlayback = configuration.audioPlayback
  input.videoCapture = configuration.videoCapture
  input.videoDisplay = configuration.videoDisplay
  input.sessionID = configuration.sessionID
  input.rawLinkInterface = rawLinkInterface(configuration, side: context.side)
  input.sourceMAC = rawLinkSourceMAC(configuration, side: context.side, role: context.role)
  input.destinationMAC = rawLinkDestinationMAC(configuration, side: context.side, role: context.role)
  input.mediaPacketCount = configuration.mediaPacketCount
  input.fullDuplex = true
  input.ultraGridTopologyMode = configuration.ultraGridTopologyMode
  input.ultraGridTopologyRole = ultraGridTopologyRole(configuration, side: context.side)
  input.ultraGridFECMode = configuration.ultraGridFECMode
  input.jackTrip = jackTripRunConfiguration(configuration, side: context.side)
})
    }

    private static func endpointCommand(
        _ session: ExternalConnectorSessionConfiguration,
        plan: ExternalConnectorLaunchPlan
    ) -> [String] {
        var command = baseEndpointCommand(session)
        if !session.peer.isEmpty {
            command += ["--peer", session.peer]
        }
        if session.controlPort > 0 {
            command += ["--control-port", String(session.controlPort)]
        }
        if session.connector == .jackTrip, let peerAudioPort = session.peerAudioPort {
            command += ["--peer-audio-port", String(peerAudioPort)]
        }
        appendConnectorEndpointArguments(session, to: &command)
        appendExternalExecutables(session, plan: plan, to: &command)
        appendMediaDeviceArguments(session, to: &command)
        return command
    }

    private static func baseEndpointCommand(_ session: ExternalConnectorSessionConfiguration) -> [String] {
        [
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
            "--full-duplex", session.fullDuplex ? "true" : "false"
        ]
    }

    private static func appendConnectorEndpointArguments(
        _ session: ExternalConnectorSessionConfiguration,
        to command: inout [String]
    ) {
        if session.connector == .jackTrip {
            command += [
                "--jacktrip-queue-depth", String(session.jackTrip.queueDepth),
                "--jacktrip-redundancy", String(session.jackTrip.redundancy),
                "--jacktrip-bit-resolution", String(session.jackTrip.bitResolutionBits),
                "--jacktrip-audio-backend", session.jackTrip.audioBackend.rawValue,
                "--jacktrip-topology", session.jackTrip.topologyMode.rawValue,
                "--jacktrip-topology-role", session.jackTrip.topologyRole.rawValue
            ]
            if session.jackTrip.topologyMode == .hubVirtualStudio {
                command += ["--jacktrip-hub-patch", session.jackTrip.hubPatchMode.label]
            }
            if session.jackTrip.hubTCPHandshakeMode != .none {
                command += ["--jacktrip-hub-tcp-handshake", session.jackTrip.hubTCPHandshakeMode.rawValue]
            }
            if let remoteClientName = session.jackTrip.remoteClientName {
                command += ["--jacktrip-remote-client-name", remoteClientName]
            }
        }
        if session.connector == .mvtpUltraGrid {
            command += [
                "--ultragrid-topology", session.ultraGridTopologyMode.rawValue,
                "--ultragrid-topology-role", session.ultraGridTopologyRole.rawValue,
                "--ultragrid-audio-payload-type", String(session.ultraGridAudioPayloadType),
                "--ultragrid-video-payload-type", String(session.ultraGridVideoPayloadType),
                "--ultragrid-fec", session.ultraGridFECMode.rawValue
            ]
        }
        if session.connector == .lola {
            appendLoLaEndpointArguments(session, to: &command)
        }
    }

    private static func appendLoLaEndpointArguments(
        _ session: ExternalConnectorSessionConfiguration,
        to command: inout [String]
    ) {
        command += ["--media-packets", String(session.mediaPacketCount)]
        if let rawLinkInterface = session.rawLinkInterface {
            command += ["--raw-link-interface", rawLinkInterface]
            if session.role.transmits,
               let sourceMAC = session.sourceMAC,
               let destinationMAC = session.destinationMAC {
                command += [
                    "--source-mac", ethernetAddressCLIValue(sourceMAC),
                    "--destination-mac", ethernetAddressCLIValue(destinationMAC)
                ]
            }
        }
    }

    private static func appendExternalExecutables(
        _ session: ExternalConnectorSessionConfiguration,
        plan: ExternalConnectorLaunchPlan,
        to command: inout [String]
    ) {
        if let executable = plan.executable {
            command += ["--executable", executable]
        }
        if let videoExecutable = session.videoExecutable ?? plan.auxiliaryProcesses.first?.executable {
            command += ["--video-executable", videoExecutable]
        }
    }

    private static func appendMediaDeviceArguments(
        _ session: ExternalConnectorSessionConfiguration,
        to command: inout [String]
    ) {
        let peerKnownFullDuplex = mediaArgumentPeerKnownFullDuplex(session)
        appendAudioDeviceArguments(session, peerKnownFullDuplex: peerKnownFullDuplex, to: &command)
        appendVideoDeviceArguments(session, peerKnownFullDuplex: peerKnownFullDuplex, to: &command)
    }

    private static func appendAudioDeviceArguments(
        _ session: ExternalConnectorSessionConfiguration,
        peerKnownFullDuplex: Bool,
        to command: inout [String]
    ) {
        if shouldAppendUltraGridAudioCapture(session, peerKnownFullDuplex: peerKnownFullDuplex),
           let audioCapture = session.audioCapture {
            command += ["--audio-capture", audioCapture]
        }
        if shouldAppendUltraGridAudioPlayback(session, peerKnownFullDuplex: peerKnownFullDuplex),
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
    }

    private static func appendVideoDeviceArguments(
        _ session: ExternalConnectorSessionConfiguration,
        peerKnownFullDuplex: Bool,
        to command: inout [String]
    ) {
        if shouldAppendVideoCapture(session, peerKnownFullDuplex: peerKnownFullDuplex),
           let videoCapture = session.videoCapture {
            command += ["--video-capture", videoCapture]
        }
        if shouldAppendVideoDisplay(session, peerKnownFullDuplex: peerKnownFullDuplex),
           let videoDisplay = session.videoDisplay {
            command += ["--video-display", videoDisplay]
        }
    }

}
