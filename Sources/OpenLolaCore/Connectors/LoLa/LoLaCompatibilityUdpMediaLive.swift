import Foundation

func shouldUseLoLaLiveSocketTransmitter(_ configuration: ExternalConnectorSessionConfiguration) -> Bool {
    if configuration.audioCapture != nil || configuration.audioPlayback != nil {
        return true
    }
    guard configuration.mediaMode.hasVideo else {
        return configuration.lolaVideoPayload == .generated
    }
    return configuration.lolaVideoPayload == .generated || configuration.lolaVideoPayload == .avFoundationRaw8
}

func enqueueLoLaLiveAudioIfNeeded(
    _ datagram: LoLaUdpMediaDatagram,
    audioBridge: LoLaCoreAudioLiveBridge?
) throws {
    guard datagram.stream == .audio, let audioBridge else {
        return
    }
    let decoded = try LoLaCompatibilityMediaCodec.decode(datagram.payload)
    guard let body = decoded.normalFragment?.body else {
        return
    }
    try audioBridge.enqueueLoLaPlaybackPayload(
        body.payload,
        hostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
    )
}

func loLaLiveAudioSnapshotNote(_ snapshot: LoLaCoreAudioLiveSnapshot?) -> String {
    guard let snapshot else {
        return ""
    }
    return "Live Core Audio graph ran at \(snapshot.graphSampleRateHertz) Hz; captured \(snapshot.capturedBlocks) block(s), transmitted \(snapshot.transmittedAudioPackets) LoLa audio packet(s), received \(snapshot.receivedAudioPackets) LoLa audio packet(s), queued \(snapshot.queuedPlayoutBlocks) playout block(s), and dropped \(snapshot.droppedPlayoutBlocks) playout block(s). "
}

func requireLoLaBidirectionalTransmitReport(
    _ result: Result<LoLaCompatibilityMediaSessionReport, Error>?
) throws -> LoLaCompatibilityMediaSessionReport {
    guard let result else {
        throw ExternalConnectorSessionError.socketFailed("udp media tx-rx did not run transmitter after binding receivers")
    }
    return try result.get()
}

final class LoLaBidirectionalTransmitResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedResult: Result<LoLaCompatibilityMediaSessionReport, Error>?

    var result: Result<LoLaCompatibilityMediaSessionReport, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return storedResult
    }

    func set(_ result: Result<LoLaCompatibilityMediaSessionReport, Error>) {
        lock.lock()
        storedResult = result
        lock.unlock()
    }
}

struct LoLaSocketUdpMediaLiveTransmitter {
    private static let audioIntervalScale = 0.92

    func transmit(
        configuration: ExternalConnectorSessionConfiguration,
        audioBridge providedAudioBridge: LoLaCoreAudioLiveBridge? = nil
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let profile = try ExternalConnectorMediaProfile.build(configuration: configuration)
        let durationNanoseconds = UInt64(max(1, configuration.durationSeconds)) * 1_000_000_000
        let deadline = DispatchTime.now() + .nanoseconds(Int(min(durationNanoseconds, UInt64(Int.max))))
        let counters = LoLaLiveTransmitCounters()
        let errors = LoLaLiveTransmitErrors()
        let group = DispatchGroup()
        let ownedAudioBridge = providedAudioBridge == nil
            ? try LoLaCoreAudioLiveBridge.makeIfRequested(configuration: configuration)
            : nil
        let audioBridge = providedAudioBridge ?? ownedAudioBridge
        if let audioBridge {
            try audioBridge.start()
        }
        defer {
            ownedAudioBridge?.stop()
        }

        if profile.audioEnabled {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try transmitAudioLoop(
                        configuration: configuration,
                        deadline: deadline,
                        counters: counters,
                        audioBridge: audioBridge
                    )
                } catch {
                    errors.append(error)
                }
                group.leave()
            }
        }

        if profile.videoEnabled {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try transmitVideoLoop(configuration: configuration, deadline: deadline, counters: counters)
                } catch {
                    errors.append(error)
                }
                group.leave()
            }
        }

        group.wait()
        if let error = errors.first {
            throw error
        }
        let snapshot = counters.snapshot
        let audioSnapshot = audioBridge?.snapshot

        return makeLoLaMediaSessionReport(
            id: "lola-udp-media-live-tx",
            role: .tx,
            mediaMode: configuration.mediaMode,
            frames: [],
            realLinkTransmitted: true,
            localHost: configuration.localHost,
            peer: configuration.peer,
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            timeoutSeconds: configuration.durationSeconds,
            notes: "Live TX sent \(snapshot.audioDatagramCount) audio datagram(s) on a dedicated paced loop at \(configuration.framesPerPacket)/\(configuration.sampleRateHertz)s * \(Self.audioIntervalScale), \(snapshot.videoFrameCount) video frame(s) on a separate paced loop, \(snapshot.videoDatagramCount) video datagram(s), and \(snapshot.sentBytes) payload byte(s) through UDP sockets. \(loLaLiveAudioSnapshotNote(audioSnapshot))"
        )
    }

    private func transmitAudioLoop(
        configuration: ExternalConnectorSessionConfiguration,
        deadline: DispatchTime,
        counters: LoLaLiveTransmitCounters,
        audioBridge: LoLaCoreAudioLiveBridge?
    ) throws {
        let socket = try makeLoLaUdpMediaSocket(bindHost: configuration.localHost, port: configuration.audioPort)
        defer { close(socket) }
        let interval = liveAudioIntervalNanoseconds(configuration: configuration)
        var nextSend = DispatchTime.now()
        var sequence: UInt32 = 0

        while DispatchTime.now().uptimeNanoseconds < deadline.uptimeNanoseconds {
            let payload = try audioBridge?.nextLoLaAudioPayload()
            let packets: [LoLaCompatibilityMediaPacket]
            if let payload {
                packets = try LoLaCompatibilityMediaCodec.audioFragments(
                    sequenceNumber: sequence,
                    channels: configuration.channels,
                    payload: payload
                )
            } else if audioBridge == nil {
                packets = try LoLaCompatibilityMediaCodec.audioFragments(
                    sequenceNumber: sequence,
                    channels: configuration.channels
                )
            } else {
                nextSend = nextLiveDeadline(after: nextSend, intervalNanoseconds: interval, now: DispatchTime.now())
                loLaUdpMediaSleepUntil(DispatchTime(uptimeNanoseconds: min(nextSend.uptimeNanoseconds, deadline.uptimeNanoseconds)))
                continue
            }
            var sentBytes = 0
            for packet in packets {
                sentBytes += try sendLoLaUdpMediaPayload(
                    packet.payload,
                    socket: socket,
                    peer: configuration.peer,
                    port: configuration.audioPort
                )
            }
            counters.addAudio(datagrams: packets.count, bytes: sentBytes)
            sequence = sequence &+ 1
            nextSend = nextLiveDeadline(after: nextSend, intervalNanoseconds: interval, now: DispatchTime.now())
            loLaUdpMediaSleepUntil(DispatchTime(uptimeNanoseconds: min(nextSend.uptimeNanoseconds, deadline.uptimeNanoseconds)))
        }
    }

    private func transmitVideoLoop(
        configuration: ExternalConnectorSessionConfiguration,
        deadline: DispatchTime,
        counters: LoLaLiveTransmitCounters
    ) throws {
        let socket = try makeLoLaUdpMediaSocket(bindHost: configuration.localHost, port: configuration.videoPort)
        defer { close(socket) }
        let interval = liveVideoIntervalNanoseconds(configuration: configuration)
        var nextSend = DispatchTime.now()
        var sequence: UInt32 = 0
        var source: LoLaLiveRaw8VideoSource?
        defer { source?.stop() }

        while DispatchTime.now().uptimeNanoseconds < deadline.uptimeNanoseconds {
            let payload = try liveVideoPayload(configuration: configuration, source: &source, sequence: sequence)
            let packets = try LoLaCompatibilityMediaCodec.videoPackets(
                sequenceNumber: sequence,
                payload: payload
            )
            var sentBytes = 0
            for packet in packets {
                sentBytes += try sendLoLaUdpMediaPayload(
                    packet.payload,
                    socket: socket,
                    peer: configuration.peer,
                    port: configuration.videoPort
                )
            }
            counters.addVideo(frameCount: 1, datagrams: packets.count, bytes: sentBytes)
            sequence = sequence &+ 1
            nextSend = nextLiveDeadline(after: nextSend, intervalNanoseconds: interval, now: DispatchTime.now())
            loLaUdpMediaSleepUntil(DispatchTime(uptimeNanoseconds: min(nextSend.uptimeNanoseconds, deadline.uptimeNanoseconds)))
        }
    }

    private func liveVideoPayload(
        configuration: ExternalConnectorSessionConfiguration,
        source: inout LoLaLiveRaw8VideoSource?,
        sequence: UInt32
    ) throws -> Data {
        switch configuration.lolaVideoPayload {
        case .generated:
            return try LoLaVideoPayloadProvider.generatedRawVideoPayload(
                configuration: configuration,
                sequenceNumber: Int(sequence)
            )
        case .avFoundationRaw8:
            if source == nil {
                let liveSource = LoLaAVFoundationLiveRaw8Source(configuration: configuration)
                try liveSource.start()
                source = liveSource
            }
            let deadline = Date().addingTimeInterval(1)
            while Date() < deadline {
                if let payload = try source?.nextPayload() {
                    return payload
                }
                Thread.sleep(forTimeInterval: 0.001)
            }
            throw LoLaVideoPayloadError.captureUnavailable
        case .avFoundationMjpeg, .avFoundationJpegXS:
            throw LoLaVideoPayloadError.captureUnavailable
        }
    }

    private func liveAudioIntervalNanoseconds(configuration: ExternalConnectorSessionConfiguration) -> UInt64 {
        let frames = max(1, configuration.framesPerPacket)
        let sampleRate = max(1, configuration.sampleRateHertz)
        let seconds = (Double(frames) / Double(sampleRate)) * Self.audioIntervalScale
        return max(1, UInt64(seconds * 1_000_000_000))
    }

    private func liveVideoIntervalNanoseconds(configuration: ExternalConnectorSessionConfiguration) -> UInt64 {
        let fps = max(1, configuration.videoFrameRate)
        return max(1, UInt64((1.0 / Double(fps)) * 1_000_000_000))
    }

    private func nextLiveDeadline(
        after previous: DispatchTime,
        intervalNanoseconds: UInt64,
        now: DispatchTime
    ) -> DispatchTime {
        let clamped = Int(min(intervalNanoseconds, UInt64(Int.max)))
        let next = previous + .nanoseconds(clamped)
        if next.uptimeNanoseconds < now.uptimeNanoseconds {
            return now + .nanoseconds(clamped)
        }
        return next
    }
}

private struct LoLaLiveTransmitSnapshot {
    var audioDatagramCount: Int
    var videoFrameCount: Int
    var videoDatagramCount: Int
    var sentBytes: Int
}

private final class LoLaLiveTransmitCounters: @unchecked Sendable {
    private let lock = NSLock()
    private var audioDatagramCount = 0
    private var videoFrameCount = 0
    private var videoDatagramCount = 0
    private var sentBytes = 0

    var snapshot: LoLaLiveTransmitSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return LoLaLiveTransmitSnapshot(
            audioDatagramCount: audioDatagramCount,
            videoFrameCount: videoFrameCount,
            videoDatagramCount: videoDatagramCount,
            sentBytes: sentBytes
        )
    }

    func addAudio(datagrams: Int, bytes: Int) {
        lock.lock()
        audioDatagramCount += datagrams
        sentBytes += bytes
        lock.unlock()
    }

    func addVideo(frameCount: Int, datagrams: Int, bytes: Int) {
        lock.lock()
        videoFrameCount += frameCount
        videoDatagramCount += datagrams
        sentBytes += bytes
        lock.unlock()
    }
}

private final class LoLaLiveTransmitErrors: @unchecked Sendable {
    private let lock = NSLock()
    private var errors: [Error] = []

    var first: Error? {
        lock.lock()
        defer { lock.unlock() }
        return errors.first
    }

    func append(_ error: Error) {
        lock.lock()
        errors.append(error)
        lock.unlock()
    }
}
