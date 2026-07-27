// Builds the LoLa UDP transmit report from sent bytes, drops, and deadline abandonment.
import Foundation

struct LoLaUdpMediaTransmitReportContext {
    var session: ExternalConnectorSessionConfiguration
    var frameCountPerStream: Int
    var localHost: String
    var peer: String
    var dryRun: Bool
    var videoFrameRate: Int?
}

func transmitReport(
    context: LoLaUdpMediaTransmitReportContext,
    transmitter: LoLaUdpMediaTransmitter
) throws -> LoLaCompatibilityMediaSessionReport {
    let frames = try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: context.session,
        frameCountPerStream: context.frameCountPerStream
    )
    let datagrams = try frames.map { try udpDatagram($0, videoFrameRate: context.videoFrameRate) }
    let outcome = try transmitter.transmitResult(datagrams, localHost: context.localHost, peer: context.peer)
    let sentBytesTotal = outcome.sentByteCounts.reduce(0, +)
    let attemptedRealLink = !context.dryRun
    let realLinkTransmitted = attemptedRealLink && transmitter.usesRealLink && sentBytesTotal > 0
    let zeroBytesError = loLaTransmitZeroBytesError(
        realLinkTransmitted: attemptedRealLink,
        sentBytesTotal: sentBytesTotal
    )
    return makeLoLaMediaSessionReport(LoLaCompatibilityMediaSessionReportDraft(
        id: "lola-udp-media-tx",
        role: .tx,
        mediaMode: context.session.mediaMode,
        frames: frames,
        realLinkTransmitted: realLinkTransmitted,
        verdict: zeroBytesError == nil ? .partial : .fail,
        runtimeError: zeroBytesError,
        sentBytesTotal: sentBytesTotal,
        notes: "LoLa UDP media TX used \(transmitter.usesRealLink ? "UDP sockets" : "memory sink"), sent "
            + "\(outcome.sentByteCounts.count) datagram(s), and dropped \(outcome.droppedAudioPackets) audio packet(s) "
            + "and \(outcome.droppedVideoFrames) video frame(s) due to UDP backpressure. The shared session "
            + "deadline abandoned \(outcome.deadlineAbandonedAudioPackets) audio packet(s) and "
            + "\(outcome.deadlineAbandonedVideoFrames) video frame(s). PASS still "
            + "requires a responding LoLa peer and captured payload grammar."
    ))
}

func loLaTransmitZeroBytesError(realLinkTransmitted: Bool, sentBytesTotal: Int) -> String? {
    guard realLinkTransmitted, sentBytesTotal == 0 else {
        return nil
    }
    return "LoLa UDP media TX sent zero payload bytes"
}

func lolaUdpMediaFrameSourceIP(_ configuration: LoLaUdpMediaTransmitRunConfiguration) throws -> String {
    guard configuration.localHost == "0.0.0.0" else {
        return configuration.localHost
    }
    return try lolaControlAdvertisedSourceIP(ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: configuration.peer,
  outputPath: configuration.outputPath
) { input in
  input.localHost = configuration.localHost
  input.controlPort = configuration.audioPort
}))
}
