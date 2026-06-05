import Foundation

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

public protocol LoLaUdpMediaTransmitter {
    func transmit(_ datagrams: [LoLaUdpMediaDatagram], localHost: String, peer: String) throws -> [Int]
}

public protocol LoLaUdpMediaReceiver {
    func receive(maxDatagrams: Int, localHost: String, peer: String, audioPort: UInt16, videoPort: UInt16) throws
        -> [LoLaUdpMediaDatagram]
}

public final class LoLaMemoryUdpMediaTransmitter: LoLaUdpMediaTransmitter {
    public private(set) var transmittedDatagrams: [LoLaUdpMediaDatagram] = []

    public init() {}

    public func transmit(_ datagrams: [LoLaUdpMediaDatagram], localHost _: String, peer _: String) throws -> [Int] {
        transmittedDatagrams.append(contentsOf: datagrams)
        return datagrams.map { $0.payload.count }
    }
}

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

public struct LoLaUdpMediaTransmitRunConfiguration: Equatable, Sendable {
    public var localHost: String, peer: String, outputPath: String
    public var dryRun: Bool, packetCount: Int
    public var mediaMode: ExternalConnectorMediaMode
    public var audioPort: UInt16, videoPort: UInt16
    public var channels: Int, sampleRateHertz: Int, framesPerPacket: Int
    public var videoWidth: Int, videoHeight: Int, videoBitsPerPixel: Int

    public init(
        localHost: String,
        peer: String,
        outputPath: String,
        dryRun: Bool = true,
        packetCount: Int = 1,
        mediaMode: ExternalConnectorMediaMode = .audioVideo,
        audioPort: UInt16 = 19788,
        videoPort: UInt16 = 19798,
        channels: Int = 2,
        sampleRateHertz: Int = 44_100,
        framesPerPacket: Int = 64,
        videoWidth: Int = 1920,
        videoHeight: Int = 1080,
        videoBitsPerPixel: Int = 24
    ) {
        self.localHost = localHost
        self.peer = peer
        self.outputPath = outputPath
        self.dryRun = dryRun
        self.packetCount = packetCount
        self.mediaMode = mediaMode
        self.audioPort = audioPort
        self.videoPort = videoPort
        self.channels = channels
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.videoBitsPerPixel = videoBitsPerPixel
    }

    public static func parse(_ arguments: [String]) throws -> LoLaUdpMediaTransmitRunConfiguration {
        let values = try parseLoLaUdpMediaArguments(arguments)
        return try LoLaUdpMediaTransmitRunConfiguration(
            localHost: requiredExternalConnectorValue("--local-host", values),
            peer: requiredExternalConnectorValue("--peer", values),
            outputPath: requiredExternalConnectorValue("--output", values),
            dryRun: optionalExternalConnectorBoolean("--dry-run", values) ?? true,
            packetCount: optionalExternalConnectorPositiveInteger("--packets", values) ?? 1,
            mediaMode: values["--media"].map(parseExternalConnectorMediaMode) ?? .audioVideo,
            audioPort: optionalExternalConnectorPort("--audio-port", values) ?? 19788,
            videoPort: optionalExternalConnectorPort("--video-port", values) ?? 19798,
            channels: optionalExternalConnectorPositiveInteger("--channels", values) ?? 2,
            sampleRateHertz: optionalExternalConnectorPositiveInteger("--sample-rate", values) ?? 44_100,
            framesPerPacket: optionalExternalConnectorPositiveInteger("--frames", values) ?? 64,
            videoWidth: optionalExternalConnectorPositiveInteger("--video-width", values) ?? 1920,
            videoHeight: optionalExternalConnectorPositiveInteger("--video-height", values) ?? 1080,
            videoBitsPerPixel: optionalExternalConnectorPositiveInteger("--video-bpp", values) ?? 24
        )
    }
}

public struct LoLaUdpMediaReceiveRunConfiguration: Equatable, Sendable {
    public var localHost: String, peer: String, outputPath: String
    public var dryRun: Bool, maxDatagrams: Int
    public var mediaMode: ExternalConnectorMediaMode
    public var audioPort: UInt16, videoPort: UInt16
    public var videoWidth: Int, videoHeight: Int, videoBitsPerPixel: Int
    public var timeoutSeconds: Int

    public init(
        localHost: String,
        peer: String,
        outputPath: String,
        dryRun: Bool = true,
        maxDatagrams: Int = 3,
        mediaMode: ExternalConnectorMediaMode = .audioVideo,
        audioPort: UInt16 = 19788,
        videoPort: UInt16 = 19798,
        videoWidth: Int = 1920,
        videoHeight: Int = 1080,
        videoBitsPerPixel: Int = 24,
        timeoutSeconds: Int = 1
    ) {
        self.localHost = localHost
        self.peer = peer
        self.outputPath = outputPath
        self.dryRun = dryRun
        self.maxDatagrams = maxDatagrams
        self.mediaMode = mediaMode
        self.audioPort = audioPort
        self.videoPort = videoPort
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.videoBitsPerPixel = videoBitsPerPixel
        self.timeoutSeconds = timeoutSeconds
    }

    public static func parse(_ arguments: [String]) throws -> LoLaUdpMediaReceiveRunConfiguration {
        let values = try parseLoLaUdpMediaArguments(arguments)
        return try LoLaUdpMediaReceiveRunConfiguration(
            localHost: requiredExternalConnectorValue("--local-host", values),
            peer: values["--peer"] ?? "0.0.0.0",
            outputPath: requiredExternalConnectorValue("--output", values),
            dryRun: optionalExternalConnectorBoolean("--dry-run", values) ?? true,
            maxDatagrams: optionalExternalConnectorPositiveInteger("--packets", values) ?? 3,
            mediaMode: values["--media"].map(parseExternalConnectorMediaMode) ?? .audioVideo,
            audioPort: optionalExternalConnectorPort("--audio-port", values) ?? 19788,
            videoPort: optionalExternalConnectorPort("--video-port", values) ?? 19798,
            videoWidth: optionalExternalConnectorPositiveInteger("--video-width", values) ?? 1920,
            videoHeight: optionalExternalConnectorPositiveInteger("--video-height", values) ?? 1080,
            videoBitsPerPixel: optionalExternalConnectorPositiveInteger("--video-bpp", values) ?? 24,
            timeoutSeconds: optionalExternalConnectorPositiveInteger("--timeout-seconds", values) ?? 1
        )
    }
}

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
        let session = ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .tx,
            peer: configuration.peer,
            localHost: try lolaUdpMediaFrameSourceIP(configuration),
            outputPath: configuration.outputPath,
            dryRun: configuration.dryRun,
            mediaMode: configuration.mediaMode,
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            channels: configuration.channels,
            sampleRateHertz: configuration.sampleRateHertz,
            framesPerPacket: configuration.framesPerPacket,
            videoWidth: configuration.videoWidth,
            videoHeight: configuration.videoHeight,
            videoBitsPerPixel: configuration.videoBitsPerPixel
        )
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

private struct LoLaUdpMediaTransmitReportContext {
    var session: ExternalConnectorSessionConfiguration
    var frameCountPerStream: Int
    var localHost: String
    var peer: String
    var dryRun: Bool
    var videoFrameRate: Int?
}

private func transmitReport(
    context: LoLaUdpMediaTransmitReportContext,
    transmitter: LoLaUdpMediaTransmitter
) throws -> LoLaCompatibilityMediaSessionReport {
    let frames = try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: context.session,
        frameCountPerStream: context.frameCountPerStream
    )
    let datagrams = try frames.map { try udpDatagram($0, videoFrameRate: context.videoFrameRate) }
    let sentByteCounts = try transmitter.transmit(datagrams, localHost: context.localHost, peer: context.peer)
    let sentBytesTotal = sentByteCounts.reduce(0, +)
    let zeroBytesError = loLaTransmitZeroBytesError(
        realLinkTransmitted: !context.dryRun,
        sentBytesTotal: sentBytesTotal
    )
    return makeLoLaMediaSessionReport(LoLaCompatibilityMediaSessionReportDraft(
        id: "lola-udp-media-tx",
        role: .tx,
        mediaMode: context.session.mediaMode,
        frames: frames,
        realLinkTransmitted: !context.dryRun,
        verdict: zeroBytesError == nil ? .partial : .fail,
        runtimeError: zeroBytesError,
        sentBytesTotal: sentBytesTotal,
        notes: "LoLa UDP media TX used \(context.dryRun ? "memory sink" : "UDP sockets"). PASS still requires a responding LoLa peer and captured payload grammar."
    ))
}

func loLaTransmitZeroBytesError(realLinkTransmitted: Bool, sentBytesTotal: Int) -> String? {
    guard realLinkTransmitted, sentBytesTotal == 0 else {
        return nil
    }
    return "LoLa UDP media TX sent zero payload bytes"
}

private func lolaUdpMediaFrameSourceIP(_ configuration: LoLaUdpMediaTransmitRunConfiguration) throws -> String {
    guard configuration.localHost == "0.0.0.0" else {
        return configuration.localHost
    }
    return try lolaControlAdvertisedSourceIP(ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: configuration.peer,
        localHost: configuration.localHost,
        outputPath: configuration.outputPath,
        controlPort: configuration.audioPort
    ))
}

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

    static func report(
        configuration: LoLaUdpMediaReceiveRunConfiguration,
        datagrams: [LoLaUdpMediaDatagram]
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let encodedFrames = try datagrams.map {
            try udpDatagramWireFrame($0, configuration: configuration).encoded()
        }
        var report = try LoLaCompatibilityMediaSession.receiveReport(
            configuration: ExternalConnectorSessionConfiguration(
                connector: .lola,
                role: .rx,
                peer: configuration.peer,
                localHost: configuration.localHost,
                outputPath: configuration.outputPath,
                dryRun: configuration.dryRun,
                mediaMode: configuration.mediaMode,
                audioPort: configuration.audioPort,
                videoPort: configuration.videoPort
            ),
            encodedFrames: encodedFrames
        )
        report.id = "lola-udp-media-rx"
        report.realLinkTransmitted = !configuration.dryRun
        report.notes = "LoLa UDP media RX decoded \(datagrams.count) payload datagrams from \(configuration.dryRun ? "memory source" : "UDP sockets") with timeout \(configuration.timeoutSeconds)s. PASS still requires a responding LoLa peer and captured payload grammar."
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
            realLinkTransmitted: !configuration.dryRun,
            verdict: .fail,
            runtimeError: String(describing: ExternalConnectorSessionError.receiveTimedOut),
            localHost: configuration.localHost,
            peer: configuration.peer,
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            timeoutSeconds: configuration.timeoutSeconds,
            expectedDatagramCount: configuration.maxDatagrams,
            notes: "LoLa UDP media RX received no media datagrams before timeout \(configuration.timeoutSeconds)s. Expected \(configuration.maxDatagrams) datagram(s) on audio port \(configuration.audioPort) and video port \(configuration.videoPort) from peer \(configuration.peer)."
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
            realLinkTransmitted: !configuration.dryRun,
            verdict: .fail,
            runtimeError: String(describing: error),
            localHost: configuration.localHost,
            peer: configuration.peer,
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            timeoutSeconds: configuration.timeoutSeconds,
            expectedDatagramCount: configuration.maxDatagrams,
            notes: "LoLa UDP media RX failed while receiving or validating media datagrams after \(receivedDescription) datagram(s). Expected \(configuration.maxDatagrams) datagram(s) on audio port \(configuration.audioPort) and video port \(configuration.videoPort) from peer \(configuration.peer)."
        ))
    }
}

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
        let tx = try LoLaUdpMediaTransmitRunner.run(
            sessionConfiguration: configuration,
            transmitter: transmitter
        )
        let rx = try LoLaUdpMediaReceiveRunner.run(
            configuration: LoLaUdpMediaReceiveRunConfiguration(
                localHost: configuration.localHost,
                peer: configuration.peer.isEmpty ? "0.0.0.0" : configuration.peer,
                outputPath: configuration.outputPath,
                dryRun: configuration.dryRun,
                maxDatagrams: max(1, lolaUdpMediaFrameReadCount(configuration)),
                mediaMode: configuration.mediaMode,
                audioPort: configuration.audioPort,
                videoPort: configuration.videoPort,
                videoWidth: configuration.videoWidth,
                videoHeight: configuration.videoHeight,
                videoBitsPerPixel: configuration.videoBitsPerPixel,
                timeoutSeconds: configuration.durationSeconds
            ),
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
            notes: "LoLa UDP TX-RX sent \(tx.frames.count) media frame(s) and decoded \(rx.frames.count) received media frame(s) through UDP sockets. PASS still requires matching Windows LoLa payload grammar and measured bidirectional AV evidence."
        ))
    }

    private static func runSocketBidirectional(
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let receiver = LoLaSocketUdpMediaReceiver(timeoutSeconds: configuration.durationSeconds)
        let audioBridge = try LoLaCoreAudioLiveBridge.makeIfRequested(configuration: configuration)
        let txResult = LoLaBidirectionalTransmitResultBox()
        let txDone = DispatchSemaphore(value: 0)
        let receiveConfiguration = LoLaUdpMediaReceiveRunConfiguration(
            localHost: configuration.localHost,
            peer: configuration.peer.isEmpty ? "0.0.0.0" : configuration.peer,
            outputPath: configuration.outputPath,
            dryRun: configuration.dryRun,
            maxDatagrams: max(1, lolaUdpMediaFrameReadCount(configuration)),
            mediaMode: configuration.mediaMode,
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            videoWidth: configuration.videoWidth,
            videoHeight: configuration.videoHeight,
            videoBitsPerPixel: configuration.videoBitsPerPixel,
            timeoutSeconds: configuration.durationSeconds
        )

        let rx: LoLaCompatibilityMediaSessionReport
        do {
            let datagrams = try receiver.receive(
                request: LoLaUdpMediaReceiveRequest(configuration: receiveConfiguration)
            ) {
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        if shouldUseLoLaLiveSocketTransmitter(configuration) {
                            txResult.set(.success(try LoLaSocketUdpMediaLiveTransmitter().transmit(
                                configuration: configuration,
                                audioBridge: audioBridge
                            )))
                        } else if configuration.mediaMode.hasVideo, configuration.lolaVideoPayload != .generated {
                            txResult.set(.success(try LoLaUdpMediaTransmitRunner.run(
                                sessionConfiguration: configuration,
                                transmitter: LoLaSocketUdpMediaTransmitter()
                            )))
                        } else {
                            txResult.set(.success(try LoLaSocketUdpMediaLiveTransmitter().transmit(
                                configuration: configuration,
                                audioBridge: audioBridge
                            )))
                        }
                    } catch {
                        txResult.set(.failure(error))
                    }
                    txDone.signal()
                }
            } onDatagram: { datagram in
                try enqueueLoLaLiveAudioIfNeeded(datagram, audioBridge: audioBridge)
            }
            rx = try LoLaUdpMediaReceiveRunner.report(configuration: receiveConfiguration, datagrams: datagrams)
        } catch ExternalConnectorSessionError.receiveTimedOut {
            rx = LoLaUdpMediaReceiveRunner.timeoutReport(configuration: receiveConfiguration)
        } catch {
            rx = LoLaUdpMediaReceiveRunner.failureReport(
                configuration: receiveConfiguration,
                error: error,
                receivedDatagramCount: nil
            )
        }
        txDone.wait()
        let txReport = try requireLoLaBidirectionalTransmitReport(txResult.result)
        let audioSnapshot = audioBridge?.snapshot

        return makeLoLaMediaSessionReport(LoLaCompatibilityMediaSessionReportDraft(
            id: "lola-udp-media-tx-rx",
            role: .txRx,
            mediaMode: configuration.mediaMode,
            frames: txReport.frames + rx.frames,
            realLinkTransmitted: txReport.realLinkTransmitted || rx.realLinkTransmitted,
            verdict: rx.verdict == .fail ? .fail : .partial,
            runtimeError: rx.runtimeError,
            localHost: configuration.localHost,
            peer: configuration.peer,
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            timeoutSeconds: configuration.durationSeconds,
            expectedDatagramCount: lolaUdpMediaFrameReadCount(configuration),
            sentBytesTotal: txReport.sentBytesTotal,
            notes: "LoLa UDP TX-RX bound RX sockets before starting concurrent live TX. \(txReport.notes) Decoded \(rx.frames.count) received media frame(s). \(loLaLiveAudioSnapshotNote(audioSnapshot))PASS still requires matching Windows LoLa payload grammar and measured bidirectional AV evidence."
        ))
    }
}
