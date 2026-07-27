// Builds the LoLa UDP receive report from accepted datagrams, packet counts, and timeout state.
import Foundation

extension LoLaUdpMediaReceiveRunner {
    static func report(
        configuration: LoLaUdpMediaReceiveRunConfiguration,
        datagrams: [LoLaUdpMediaDatagram]
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let encodedFrames = try datagrams.map {
            try udpDatagramWireFrame($0, configuration: configuration).encoded()
        }
        var report = try LoLaCompatibilityMediaSession.receiveReport(
            configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .rx,
  peer: configuration.peer,
  outputPath: configuration.outputPath
) { input in
  input.localHost = configuration.localHost
  input.dryRun = configuration.dryRun
  input.mediaMode = configuration.mediaMode
  input.audioPort = configuration.audioPort
  input.videoPort = configuration.videoPort
}),
            encodedFrames: encodedFrames
        )
        report.id = "lola-udp-media-rx"
        report.realLinkTransmitted = !configuration.dryRun && !datagrams.isEmpty
        report.notes = "LoLa UDP media RX decoded \(datagrams.count) payload datagrams from "
            + "\(configuration.dryRun ? "memory source" : "UDP sockets") with timeout "
            + "\(configuration.timeoutSeconds)s. PASS still requires a responding LoLa peer and "
            + "captured payload grammar."
        return report
    }

    static func timeoutReport(
        configuration: LoLaUdpMediaReceiveRunConfiguration
    ) -> LoLaCompatibilityMediaSessionReport {
        makeLoLaMediaSessionReport(LoLaCompatibilityMediaSessionReportDraft(
            id: "lola-udp-media-rx-timeout",
            role: .rx,
            mediaMode: configuration.mediaMode,
            frames: [],
            realLinkTransmitted: false,
            verdict: .fail,
            runtimeError: String(describing: ExternalConnectorSessionError.receiveTimedOut),
            localHost: configuration.localHost,
            peer: configuration.peer,
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            timeoutSeconds: configuration.timeoutSeconds,
            expectedDatagramCount: configuration.maxDatagrams,
            notes: "LoLa UDP media RX received no media datagrams before timeout "
                + "\(configuration.timeoutSeconds)s. Expected \(configuration.maxDatagrams) datagram(s) on "
                + "audio port \(configuration.audioPort) and video port \(configuration.videoPort) from "
                + "peer \(configuration.peer)."
        ))
    }

    static func failureReport(
        configuration: LoLaUdpMediaReceiveRunConfiguration,
        error: Error,
        receivedDatagramCount: Int?
    ) -> LoLaCompatibilityMediaSessionReport {
        let receivedDescription = receivedDatagramCount.map { "\($0)" } ?? "unknown"
        return makeLoLaMediaSessionReport(LoLaCompatibilityMediaSessionReportDraft(
            id: "lola-udp-media-rx-failure",
            role: .rx,
            mediaMode: configuration.mediaMode,
            frames: [],
            realLinkTransmitted: !configuration.dryRun && (receivedDatagramCount ?? 0) > 0,
            verdict: .fail,
            runtimeError: String(describing: error),
            localHost: configuration.localHost,
            peer: configuration.peer,
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            timeoutSeconds: configuration.timeoutSeconds,
            expectedDatagramCount: configuration.maxDatagrams,
            notes: "LoLa UDP media RX failed while receiving or validating media datagrams after "
                + "\(receivedDescription) datagram(s). Expected \(configuration.maxDatagrams) datagram(s) "
                + "on audio port \(configuration.audioPort) and video port \(configuration.videoPort) from "
                + "peer \(configuration.peer)."
        ))
    }
}
