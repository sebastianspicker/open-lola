// Implements LoLaCompatibilityUdpMedia interoperability behavior, isolating peer-specific compatibility rules from generic transport.
import Foundation

/// Defines the validated fields for LoLa UDP media datagram.
public struct LoLaUdpMediaDatagram: Equatable, Sendable {
    public var stream: LoLaCompatibilityMediaStream
    public var port: UInt16
    public var sourceHost: String?
    public var sequenceNumber: Int?
    public var videoFrameRate: Int?
    public var payload: Data

    public init(
        stream: LoLaCompatibilityMediaStream,
        port: UInt16,
        sourceHost: String? = nil,
        sequenceNumber: Int? = nil,
        videoFrameRate: Int? = nil,
        payload: Data
    ) {
        self.stream = stream
        self.port = port
        self.sourceHost = sourceHost
        self.sequenceNumber = sequenceNumber
        self.videoFrameRate = videoFrameRate
        self.payload = payload
    }
}

/// Requires conformers to transmit operations for LoLa UDP media transmitter.
public protocol LoLaUdpMediaTransmitter {
    var usesRealLink: Bool { get }
    func transmit(_ datagrams: [LoLaUdpMediaDatagram], localHost: String, peer: String) throws -> [Int]
    func transmitResult(
        _ datagrams: [LoLaUdpMediaDatagram], localHost: String, peer: String
    ) throws -> LoLaUdpMediaTransmitOutcome
}

public extension LoLaUdpMediaTransmitter {
    /// Injected/memory transmitters are evidence-only unless they explicitly
    /// identify themselves as a real socket-backed link.
    var usesRealLink: Bool { false }

    func transmitResult(
        _ datagrams: [LoLaUdpMediaDatagram], localHost: String, peer: String
    ) throws -> LoLaUdpMediaTransmitOutcome {
        LoLaUdpMediaTransmitOutcome(
            sentByteCounts: try transmit(datagrams, localHost: localHost, peer: peer)
        )
    }
}

/// Defines the validated fields for LoLa UDP media transmit outcome.
public struct LoLaUdpMediaTransmitOutcome: Equatable, Sendable {
    public var sentByteCounts: [Int]
    public var droppedAudioPackets: Int
    public var droppedVideoFrames: Int
    public var deadlineAbandonedAudioPackets: Int
    public var deadlineAbandonedVideoFrames: Int

    public init(
        sentByteCounts: [Int],
        droppedAudioPackets: Int = 0,
        droppedVideoFrames: Int = 0,
        deadlineAbandonedAudioPackets: Int = 0,
        deadlineAbandonedVideoFrames: Int = 0
    ) {
        self.sentByteCounts = sentByteCounts
        self.droppedAudioPackets = droppedAudioPackets
        self.droppedVideoFrames = droppedVideoFrames
        self.deadlineAbandonedAudioPackets = deadlineAbandonedAudioPackets
        self.deadlineAbandonedVideoFrames = deadlineAbandonedVideoFrames
    }
}

/// Requires conformers to receive, transmit operations for LoLa UDP media receiver.
public protocol LoLaUdpMediaReceiver {
    func receive(maxDatagrams: Int, localHost: String, peer: String, audioPort: UInt16, videoPort: UInt16) throws
        -> [LoLaUdpMediaDatagram]
}

/// Retains emitted datagrams in memory so callers can inspect LoLa memory UDP media transmitter.
public final class LoLaMemoryUdpMediaTransmitter: LoLaUdpMediaTransmitter {
    public private(set) var transmittedDatagrams: [LoLaUdpMediaDatagram] = []

    public init() {}

    public func transmit(_ datagrams: [LoLaUdpMediaDatagram], localHost: String, peer: String) throws -> [Int] {
        try transmitResult(datagrams, localHost: localHost, peer: peer).sentByteCounts
    }

    public func transmitResult(
        _ datagrams: [LoLaUdpMediaDatagram], localHost _: String, peer _: String
    ) throws -> LoLaUdpMediaTransmitOutcome {
        transmittedDatagrams.append(contentsOf: datagrams)
        return LoLaUdpMediaTransmitOutcome(sentByteCounts: datagrams.map { $0.payload.count })
    }
}

/// Returns preloaded datagrams that match the requested route for LoLa memory UDP media receiver.
public struct LoLaMemoryUdpMediaReceiver: LoLaUdpMediaReceiver {
    public var datagrams: [LoLaUdpMediaDatagram]

    public init(datagrams: [LoLaUdpMediaDatagram]) {
        self.datagrams = datagrams
    }

    public func receive(
        maxDatagrams: Int,
        localHost _: String,
        peer: String,
        audioPort: UInt16,
        videoPort: UInt16
    ) throws -> [LoLaUdpMediaDatagram] {
        Array(datagrams.filter {
            loLaUdpMediaDatagramMatchesPeer($0, peer: peer) && ($0.port == audioPort || $0.port == videoPort)
        }.prefix(maxDatagrams))
    }
}

/// Sends LoLa audio and video datagrams over UDP and records drop and byte-count evidence.
public enum LoLaUdpMediaTransmitRunner {
    public static func run(
        configuration: LoLaUdpMediaTransmitRunConfiguration
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let transmitter: LoLaUdpMediaTransmitter = configuration.dryRun
            ? LoLaMemoryUdpMediaTransmitter()
            : LoLaSocketUdpMediaTransmitter()
        return try run(configuration: configuration, transmitter: transmitter)
    }

    public static func run(
        configuration: LoLaUdpMediaTransmitRunConfiguration,
        transmitter: LoLaUdpMediaTransmitter
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let localHost = try lolaUdpMediaFrameSourceIP(configuration)
        var input = ExternalConnectorSessionConfigInput(
            connector: .lola,
            role: .tx,
            peer: configuration.peer,
            outputPath: configuration.outputPath
        )
        input.localHost = localHost
        input.dryRun = configuration.dryRun
        input.audioPort = configuration.audioPort
        input.videoPort = configuration.videoPort
        applyLoLaMediaFields(to: &input, from: configuration)
        let session = ExternalConnectorSessionConfiguration(input)
        return try transmitReport(
            context: LoLaUdpMediaTransmitReportContext(
                session: session,
                frameCountPerStream: configuration.packetCount,
                localHost: configuration.localHost,
                peer: configuration.peer,
                dryRun: configuration.dryRun
            ),
            transmitter: transmitter
        )
    }

    public static func run(
        sessionConfiguration configuration: ExternalConnectorSessionConfiguration,
        transmitter: LoLaUdpMediaTransmitter? = nil
    ) throws -> LoLaCompatibilityMediaSessionReport {
        if transmitter == nil, !configuration.dryRun, shouldUseLoLaLiveSocketTransmitter(configuration) {
            return try LoLaSocketUdpMediaLiveTransmitter().transmit(configuration: configuration)
        }
        let mediaTransmitter: LoLaUdpMediaTransmitter
        if let transmitter {
            mediaTransmitter = transmitter
        } else {
            mediaTransmitter = configuration.dryRun
                ? LoLaMemoryUdpMediaTransmitter()
                : LoLaSocketUdpMediaTransmitter()
        }
        var session = configuration
        if session.localHost == "0.0.0.0" {
            session.localHost = try lolaControlAdvertisedSourceIP(configuration)
        }
        return try transmitReport(
            context: LoLaUdpMediaTransmitReportContext(
                session: session,
                frameCountPerStream: configuration.mediaPacketCount,
                localHost: configuration.localHost,
                peer: configuration.peer,
                dryRun: configuration.dryRun,
                videoFrameRate: configuration.videoFrameRate
            ),
            transmitter: mediaTransmitter
        )
    }
}

/// Receives LoLa UDP media until the configured packet target or timeout and writes the report.
public enum LoLaUdpMediaReceiveRunner {
    public static func run(
        configuration: LoLaUdpMediaReceiveRunConfiguration
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let receiver: LoLaUdpMediaReceiver = configuration.dryRun
            ? LoLaMemoryUdpMediaReceiver(datagrams: try syntheticUdpMediaDatagrams(configuration))
            : LoLaSocketUdpMediaReceiver(timeoutSeconds: configuration.timeoutSeconds)
        return try run(configuration: configuration, receiver: receiver)
    }

    public static func run(
        configuration: LoLaUdpMediaReceiveRunConfiguration,
        receiver: LoLaUdpMediaReceiver
    ) throws -> LoLaCompatibilityMediaSessionReport {
        do {
            let datagrams = try receiver.receive(
                maxDatagrams: configuration.maxDatagrams,
                localHost: configuration.localHost,
                peer: configuration.peer,
                audioPort: configuration.audioPort,
                videoPort: configuration.videoPort
            )
            do {
                return try report(configuration: configuration, datagrams: datagrams)
            } catch {
                return failureReport(configuration: configuration, error: error, receivedDatagramCount: datagrams.count)
            }
        } catch ExternalConnectorSessionError.receiveTimedOut {
            return timeoutReport(configuration: configuration)
        } catch {
            return failureReport(configuration: configuration, error: error, receivedDatagramCount: nil)
        }
    }

}

/// Keeps LoLa UDP sockets bound while paired transmit and receive work completes.
public enum LoLaUdpMediaBidirectionalRunner {
    public static func run(
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> LoLaCompatibilityMediaSessionReport {
        if !configuration.dryRun {
            return try runSocketBidirectional(configuration: configuration)
        }
        let transmitter: LoLaUdpMediaTransmitter = configuration.dryRun
            ? LoLaMemoryUdpMediaTransmitter()
            : LoLaSocketUdpMediaTransmitter()
        let receiver: LoLaUdpMediaReceiver = configuration.dryRun
            ? LoLaMemoryUdpMediaReceiver(datagrams: try syntheticBidirectionalReceiveDatagrams(configuration))
            : LoLaSocketUdpMediaReceiver(timeoutSeconds: configuration.durationSeconds)
        return try run(configuration: configuration, transmitter: transmitter, receiver: receiver)
    }

    public static func run(
        configuration: ExternalConnectorSessionConfiguration,
        transmitter: LoLaUdpMediaTransmitter,
        receiver: LoLaUdpMediaReceiver
    ) throws -> LoLaCompatibilityMediaSessionReport {
        // swiftlint:disable:next identifier_name
        let tx = try LoLaUdpMediaTransmitRunner.run(
            sessionConfiguration: configuration,
            transmitter: transmitter
        )
        // swiftlint:disable:next identifier_name
        let receiveConfiguration = loLaSocketBidirectionalReceiveConfiguration(configuration)
        let rx = try LoLaUdpMediaReceiveRunner.run(
            configuration: receiveConfiguration,
            receiver: receiver
        )
        return makeLoLaMediaSessionReport(LoLaCompatibilityMediaSessionReportDraft(
            id: "lola-udp-media-tx-rx",
            role: .txRx,
            mediaMode: configuration.mediaMode,
            frames: tx.frames + rx.frames,
            realLinkTransmitted: tx.realLinkTransmitted || rx.realLinkTransmitted,
            verdict: rx.verdict == .fail ? .fail : .partial,
            runtimeError: rx.runtimeError,
            localHost: configuration.localHost,
            peer: configuration.peer,
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            timeoutSeconds: configuration.durationSeconds,
            expectedDatagramCount: lolaUdpMediaFrameReadCount(configuration),
            sentBytesTotal: tx.sentBytesTotal,
            notes: "LoLa UDP TX-RX sent \(tx.frames.count) media frame(s) and decoded \(rx.frames.count) "
                + "received media frame(s) through UDP sockets. PASS still requires matching Windows LoLa "
                + "payload grammar and measured bidirectional AV evidence."
        ))
    }

    private static func runSocketBidirectional(
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let exchange = try LoLaSocketBidirectionalExchange(configuration: configuration)
        let receiver = try receiveSocketBidirectional(configuration, exchange: exchange)
        guard exchange.txDone.wait(timeout: exchange.deadline) == .success else {
            throw ExternalConnectorSessionError.receiveTimedOut
        }
        let txReport = try requireLoLaBidirectionalTransmitReport(exchange.txResult.result)

        return makeLoLaSocketBidirectionalReport(
            configuration: configuration,
            txReport: txReport,
            receiver: receiver,
            audioBridge: exchange.audioBridge,
            audioFreshness: exchange.audioFreshnessCounters.snapshot
        )
    }

    private static func receiveSocketBidirectional(
        _ configuration: ExternalConnectorSessionConfiguration,
        exchange: LoLaSocketBidirectionalExchange
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let txResult = exchange.txResult
        let txDone = exchange.txDone
        let audioBridge = exchange.audioBridge
        let deadline = exchange.deadline
        do {
            let datagrams = try exchange.receiver.receive(
                request: LoLaUdpMediaReceiveRequest(
                    configuration: exchange.receiveConfiguration,
                    deadlineNanoseconds: exchange.deadline.uptimeNanoseconds
                ),
                afterBind: { sockets in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            txResult.set(.success(try transmitSocketBidirectional(
                                configuration: configuration,
                                audioBridge: audioBridge,
                                sockets: sockets,
                                deadline: deadline
                            )))
                        } catch {
                            txResult.set(.failure(error))
                        }
                        txDone.signal()
                    }
                },
                coalesceReadableAudioToNewest: true,
                audioFreshnessCounters: exchange.audioFreshnessCounters,
                onDatagram: { datagram in
                    try enqueueLoLaLiveAudioIfNeeded(datagram, audioBridge: audioBridge)
                }
            )
            return try LoLaUdpMediaReceiveRunner.report(
                configuration: exchange.receiveConfiguration,
                datagrams: datagrams
            )
        } catch ExternalConnectorSessionError.receiveTimedOut {
            return LoLaUdpMediaReceiveRunner.timeoutReport(configuration: exchange.receiveConfiguration)
        } catch {
            return LoLaUdpMediaReceiveRunner.failureReport(
                configuration: exchange.receiveConfiguration,
                error: error,
                receivedDatagramCount: nil
            )
        }
    }
}

private struct LoLaSocketBidirectionalExchange {
    let receiver: LoLaSocketUdpMediaReceiver
    let audioBridge: LoLaCoreAudioLiveBridge?
    let audioFreshnessCounters: LoLaAudioReceiveFreshnessCounters
    let txResult: LoLaBidirectionalTransmitResultBox
    let txDone: DispatchSemaphore
    let receiveConfiguration: LoLaUdpMediaReceiveRunConfiguration
    let deadline: DispatchTime

    init(configuration: ExternalConnectorSessionConfiguration) throws {
        receiver = LoLaSocketUdpMediaReceiver(timeoutSeconds: configuration.durationSeconds)
        audioBridge = try LoLaCoreAudioLiveBridge.makeIfRequested(configuration: configuration)
        audioFreshnessCounters = LoLaAudioReceiveFreshnessCounters()
        txResult = LoLaBidirectionalTransmitResultBox()
        txDone = DispatchSemaphore(value: 0)
        receiveConfiguration = loLaSocketBidirectionalReceiveConfiguration(configuration)
        deadline = DispatchTime.now() + .seconds(max(1, configuration.durationSeconds))
    }
}

private func transmitSocketBidirectional(
    configuration: ExternalConnectorSessionConfiguration,
    audioBridge: LoLaCoreAudioLiveBridge?,
    sockets: LoLaUdpMediaReceiveSockets,
    deadline: DispatchTime
) throws -> LoLaCompatibilityMediaSessionReport {
    if shouldUseLoLaLiveSocketTransmitter(configuration) {
        return try LoLaSocketUdpMediaLiveTransmitter().transmit(
            configuration: configuration,
            audioBridge: audioBridge,
            socketForPort: { port in sockets.socket(for: port == configuration.audioPort ? .audio : .video) },
            deadline: deadline
        )
    }
    if configuration.mediaMode.hasVideo, configuration.lolaVideoPayload != .generated {
        return try LoLaUdpMediaTransmitRunner.run(
            sessionConfiguration: configuration,
            transmitter: LoLaSocketUdpMediaTransmitter(
                boundSocketForDatagram: { sockets.socket(for: $0.stream) },
                deadline: deadline
            )
        )
    }
    return try LoLaSocketUdpMediaLiveTransmitter().transmit(
        configuration: configuration,
        audioBridge: audioBridge,
        socketForPort: { port in sockets.socket(for: port == configuration.audioPort ? .audio : .video) },
        deadline: deadline
    )
}

private func loLaSocketBidirectionalReceiveConfiguration(
    _ configuration: ExternalConnectorSessionConfiguration
) -> LoLaUdpMediaReceiveRunConfiguration {
    loLaUdpMediaReceiveRunConfiguration(
        configuration,
        dryRun: configuration.dryRun,
        maxDatagrams: max(1, lolaUdpMediaFrameReadCount(configuration))
    )
}

private func makeLoLaSocketBidirectionalReport(
    configuration: ExternalConnectorSessionConfiguration,
    txReport: LoLaCompatibilityMediaSessionReport,
    receiver: LoLaCompatibilityMediaSessionReport,
    audioBridge: LoLaCoreAudioLiveBridge?,
    audioFreshness: LoLaAudioReceiveFreshnessSnapshot?
) -> LoLaCompatibilityMediaSessionReport {
    let audioSnapshot = audioBridge?.snapshot
    return makeLoLaMediaSessionReport(LoLaCompatibilityMediaSessionReportDraft(
        id: "lola-udp-media-tx-rx",
        role: .txRx,
        mediaMode: configuration.mediaMode,
        frames: txReport.frames + receiver.frames,
        realLinkTransmitted: txReport.realLinkTransmitted || receiver.realLinkTransmitted,
        verdict: receiver.verdict == .fail ? .fail : .partial,
        runtimeError: receiver.runtimeError,
        localHost: configuration.localHost,
        peer: configuration.peer,
        audioPort: configuration.audioPort,
        videoPort: configuration.videoPort,
        timeoutSeconds: configuration.durationSeconds,
        expectedDatagramCount: lolaUdpMediaFrameReadCount(configuration),
        sentBytesTotal: txReport.sentBytesTotal,
            notes: "LoLa UDP TX-RX bound RX sockets before starting concurrent live TX. \(txReport.notes) "
            + "Decoded \(receiver.frames.count) received media frame(s). "
            + "\(loLaAudioReceiveFreshnessNote(audioFreshness))"
            + "\(loLaLiveAudioSnapshotNote(audioSnapshot))PASS still requires matching Windows LoLa "
            + "payload grammar and measured bidirectional AV evidence."
    ))
}
