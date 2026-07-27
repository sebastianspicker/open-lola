// Implements LoLaCompatibilityUdpMediaLive interoperability behavior, isolating peer-specific compatibility rules from generic transport.
import Foundation

func shouldUseLoLaLiveSocketTransmitter(_ configuration: ExternalConnectorSessionConfiguration) -> Bool {
    if configuration.audioCapture != nil || configuration.audioPlayback != nil {
        return true
    }
    guard configuration.mediaMode.hasVideo else {
        return configuration.lolaVideoPayload == .generated
    }
    return true
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
    func transmit(
        configuration: ExternalConnectorSessionConfiguration,
        audioBridge providedAudioBridge: LoLaCoreAudioLiveBridge? = nil,
        socketForPort: ((UInt16) -> Int32)? = nil,
        deadline providedDeadline: DispatchTime? = nil
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let profile = try ExternalConnectorMediaProfile.build(configuration: configuration)
        let deadline = Self.liveTransmitDeadline(
            configuration: configuration,
            providedDeadline: providedDeadline
        )
        let counters = LoLaLiveTransmitCounters()
        let errors = LoLaLiveTransmitErrors()
        let group = DispatchGroup()
        let ownedAudioBridge = providedAudioBridge == nil
            ? try LoLaCoreAudioLiveBridge.makeIfRequested(configuration: configuration)
            : nil
        let audioBridge = providedAudioBridge ?? ownedAudioBridge
        let audioSocket = socketForPort?(configuration.audioPort)
        let videoSocket = socketForPort?(configuration.videoPort)
        try audioBridge?.start()
        defer {
            ownedAudioBridge?.stop()
        }

        if profile.audioEnabled {
            runTransmitLoop(group: group, errors: errors) {
                try transmitAudioLoop(
                    configuration: configuration,
                    deadline: deadline,
                    counters: counters,
                    audioBridge: audioBridge,
                    socket: audioSocket
                )
            }
        }

        if profile.videoEnabled {
            runTransmitLoop(group: group, errors: errors) {
                try transmitVideoLoop(
                    configuration: configuration,
                    deadline: deadline,
                    counters: counters,
                    socket: videoSocket
                )
            }
        }

        Self.waitForTransmitLoops(group, until: deadline)
        try errors.throwIfPresent()
        return makeTransmitReport(configuration: configuration, counters: counters, audioBridge: audioBridge)
    }

    private static func liveTransmitDeadline(
        configuration: ExternalConnectorSessionConfiguration,
        providedDeadline: DispatchTime?
    ) -> DispatchTime {
        if let providedDeadline {
            return providedDeadline
        }
        let durationNanoseconds = UInt64(max(1, configuration.durationSeconds)) * 1_000_000_000
        return DispatchTime.now() + .nanoseconds(Int(min(durationNanoseconds, UInt64(Int.max))))
    }

    private static func waitForTransmitLoops(_ group: DispatchGroup, until deadline: DispatchTime) {
        guard group.wait(timeout: deadline) != .success else {
            return
        }
        // Capture waits and media loops share this same deadline. Join the
        // cooperatively exiting workers before stopping their live source.
        group.wait()
    }

    private func makeTransmitReport(
        configuration: ExternalConnectorSessionConfiguration,
        counters: LoLaLiveTransmitCounters,
        audioBridge: LoLaCoreAudioLiveBridge?
    ) -> LoLaCompatibilityMediaSessionReport {
        let snapshot = counters.snapshot
        let audioSnapshot = audioBridge?.snapshot
        let attemptedRealLink = !configuration.dryRun
        let realLinkTransmitted = attemptedRealLink && snapshot.sentBytes > 0
        let zeroBytesError = loLaTransmitZeroBytesError(
            realLinkTransmitted: attemptedRealLink,
            sentBytesTotal: snapshot.sentBytes
        )

        return makeLoLaMediaSessionReport(LoLaCompatibilityMediaSessionReportDraft(
            id: "lola-udp-media-live-tx",
            role: .tx,
            mediaMode: configuration.mediaMode,
            frames: [],
            realLinkTransmitted: realLinkTransmitted,
            verdict: zeroBytesError == nil ? .partial : .fail,
            runtimeError: zeroBytesError,
            localHost: configuration.localHost,
            peer: configuration.peer,
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            timeoutSeconds: configuration.durationSeconds,
            sentBytesTotal: snapshot.sentBytes,
            notes: "Live TX sent \(snapshot.audioDatagramCount) audio datagram(s) from captured audio "
                + "readiness events or an exact \(configuration.framesPerPacket)/\(configuration.sampleRateHertz)s "
                + "synthetic sample clock, \(snapshot.videoFrameCount) video frame(s) on a separate "
                + "paced loop, and \(snapshot.videoDatagramCount) video datagram(s) through UDP sockets. "
                + "Dropped \(snapshot.droppedAudioPackets) audio packet(s) and "
                + "\(snapshot.droppedVideoFrames) video frame(s) on UDP backpressure; abandoned "
                + "\(snapshot.deadlineAbandonedAudioPackets) audio packet(s) and "
                + "\(snapshot.deadlineAbandonedVideoFrames) video frame(s) at the shared deadline. "
                + "\(loLaLiveAudioSnapshotNote(audioSnapshot))"
        ))
    }

    private func runTransmitLoop(
        group: DispatchGroup,
        errors: LoLaLiveTransmitErrors,
        _ transmit: @escaping @Sendable () throws -> Void
    ) {
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try transmit()
            } catch {
                errors.append(error)
            }
            group.leave()
        }
    }

    private func transmitAudioLoop(
        configuration: ExternalConnectorSessionConfiguration,
        deadline: DispatchTime,
        counters: LoLaLiveTransmitCounters,
        audioBridge: LoLaCoreAudioLiveBridge?,
        socket providedSocket: Int32?
    ) throws {
        let socket = try providedSocket ?? makeLoLaUdpMediaSocket(bindHost: configuration.localHost, port: configuration.audioPort)
        defer { if providedSocket == nil { close(socket) } }
        let interval = Self.liveAudioIntervalNanoseconds(configuration: configuration)
        var nextSyntheticSend = DispatchTime.now()
        var sequence: UInt32 = 0

        while DispatchTime.now().uptimeNanoseconds < deadline.uptimeNanoseconds {
            guard let packets = try liveAudioPackets(
                configuration: configuration,
                audioBridge: audioBridge,
                sequence: sequence,
                deadline: deadline
            ) else {
                break
            }
            let outcome = try sendLoLaLivePackets(
                packets,
                request: LoLaLivePacketSendRequest(
                    socket: socket,
                    peer: configuration.peer,
                    port: configuration.audioPort,
                    deadline: deadline
                )
            )
            counters.addAudio(
                datagrams: outcome.sentDatagrams,
                bytes: outcome.sentBytes,
                droppedPackets: outcome.droppedForBackpressure ? 1 : 0,
                deadlineAbandonedPackets: outcome.abandonedAtDeadline ? 1 : 0
            )
            if outcome.abandonedAtDeadline {
                break
            }
            sequence = sequence &+ 1
            paceSyntheticAudioIfNeeded(
                audioBridge: audioBridge,
                nextSend: &nextSyntheticSend,
                intervalNanoseconds: interval,
                deadline: deadline
            )
        }
    }

    private func liveAudioPackets(
        configuration: ExternalConnectorSessionConfiguration,
        audioBridge: LoLaCoreAudioLiveBridge?,
        sequence: UInt32,
        deadline: DispatchTime
    ) throws -> [LoLaCompatibilityMediaPacket]? {
        guard let audioBridge else {
            return try LoLaCompatibilityMediaCodec.audioFragments(
                sequenceNumber: sequence,
                channels: configuration.channels
            )
        }
        guard let payload = try audioBridge.nextLoLaAudioPayload(until: deadline) else {
            return nil
        }
        return try LoLaCompatibilityMediaCodec.audioFragments(
            sequenceNumber: sequence,
            channels: configuration.channels,
            payload: payload
        )
    }

    private func paceSyntheticAudioIfNeeded(
        audioBridge: LoLaCoreAudioLiveBridge?,
        nextSend: inout DispatchTime,
        intervalNanoseconds: UInt64,
        deadline: DispatchTime
    ) {
        guard audioBridge == nil else {
            return
        }
        nextSend = Self.nextLiveDeadline(
            after: nextSend,
            intervalNanoseconds: intervalNanoseconds,
            now: DispatchTime.now()
        )
        loLaUdpMediaSleepUntil(DispatchTime(
            uptimeNanoseconds: min(nextSend.uptimeNanoseconds, deadline.uptimeNanoseconds)
        ))
    }

    private func transmitVideoLoop(
        configuration: ExternalConnectorSessionConfiguration,
        deadline: DispatchTime,
        counters: LoLaLiveTransmitCounters,
        socket providedSocket: Int32?
    ) throws {
        let socket = try providedSocket ?? makeLoLaUdpMediaSocket(bindHost: configuration.localHost, port: configuration.videoPort)
        defer { if providedSocket == nil { close(socket) } }
        let interval = liveVideoIntervalNanoseconds(configuration: configuration)
        var nextSend = DispatchTime.now()
        var sequence: UInt32 = 0
        var source: LoLaLiveRaw8VideoSource?
        defer { source?.stop() }
        let context = LoLaLiveVideoTransmitContext(
            configuration: configuration,
            deadline: deadline,
            counters: counters,
            socket: socket
        )

        while DispatchTime.now().uptimeNanoseconds < deadline.uptimeNanoseconds {
            guard try transmitVideoFrame(
                context: context,
                sequence: sequence,
                source: &source
            ) else {
                break
            }
            sequence = sequence &+ 1
            paceLiveVideoIfNeeded(
                configuration: configuration,
                nextSend: &nextSend,
                intervalNanoseconds: interval,
                deadline: deadline
            )
        }
    }

    private func transmitVideoFrame(
        context: LoLaLiveVideoTransmitContext,
        sequence: UInt32,
        source: inout LoLaLiveRaw8VideoSource?
    ) throws -> Bool {
        let payload = try liveVideoPayload(
            configuration: context.configuration,
            source: &source,
            sequence: sequence,
            deadline: context.deadline
        )
        guard DispatchTime.now().uptimeNanoseconds < context.deadline.uptimeNanoseconds else {
            context.counters.addVideo(
                frameCount: 0,
                datagrams: 0,
                bytes: 0,
                droppedFrames: 0,
                deadlineAbandonedFrames: 1
            )
            return false
        }
        let packets = try LoLaCompatibilityMediaCodec.videoPackets(
            sequenceNumber: sequence,
            payload: payload
        )
        let outcome = try sendLoLaLivePackets(
            packets,
            request: LoLaLivePacketSendRequest(
                socket: context.socket,
                peer: context.configuration.peer,
                port: context.configuration.videoPort,
                deadline: context.deadline
            )
        )
        context.counters.addVideo(
            frameCount: outcome.sentDatagrams == packets.count ? 1 : 0,
            datagrams: outcome.sentDatagrams,
            bytes: outcome.sentBytes,
            droppedFrames: outcome.droppedForBackpressure ? 1 : 0,
            deadlineAbandonedFrames: outcome.abandonedAtDeadline ? 1 : 0
        )
        return !outcome.abandonedAtDeadline
    }

    private func paceLiveVideoIfNeeded(
        configuration: ExternalConnectorSessionConfiguration,
        nextSend: inout DispatchTime,
        intervalNanoseconds: UInt64,
        deadline: DispatchTime
    ) {
        guard Self.shouldPaceLiveVideo(configuration.lolaVideoPayload) else {
            return
        }
        nextSend = Self.nextLiveDeadline(
            after: nextSend,
            intervalNanoseconds: intervalNanoseconds,
            now: DispatchTime.now()
        )
        let sleepDeadline = DispatchTime(
            uptimeNanoseconds: min(nextSend.uptimeNanoseconds, deadline.uptimeNanoseconds)
        )
        loLaUdpMediaSleepUntil(sleepDeadline)
    }

    private func liveVideoPayload(
        configuration: ExternalConnectorSessionConfiguration,
        source: inout LoLaLiveRaw8VideoSource?,
        sequence: UInt32,
        deadline: DispatchTime
    ) throws -> Data {
        switch configuration.lolaVideoPayload {
        case .generated:
            return try LoLaVideoPayloadProvider.generatedRawVideoPayload(
                configuration: configuration,
                sequenceNumber: Int(sequence)
            )
        case .avFoundationRaw8, .avFoundationMjpeg, .avFoundationJpegXS:
            if source == nil {
                let liveSource = LoLaAVFoundationLiveRaw8Source(configuration: configuration)
                try liveSource.start()
                source = liveSource
            }
            let nowNanoseconds = DispatchTime.now().uptimeNanoseconds
            let remainingSeconds = deadline.uptimeNanoseconds > nowNanoseconds
                ? min(1, Double(deadline.uptimeNanoseconds - nowNanoseconds) / 1_000_000_000)
                : 0
            if let payload = try source?.nextPayload(until: Date().addingTimeInterval(remainingSeconds)) {
                return payload
            }
            throw LoLaVideoPayloadError.captureUnavailable
        }
    }

    static func liveAudioIntervalNanoseconds(configuration: ExternalConnectorSessionConfiguration) -> UInt64 {
        let frames = max(1, configuration.framesPerPacket)
        let sampleRate = max(1, configuration.sampleRateHertz)
        let seconds = Double(frames) / Double(sampleRate)
        return max(1, UInt64(seconds * 1_000_000_000))
    }

    static func shouldPaceLiveVideo(_ payloadKind: LoLaVideoPayloadKind) -> Bool {
        payloadKind == .generated
    }

    private func liveVideoIntervalNanoseconds(configuration: ExternalConnectorSessionConfiguration) -> UInt64 {
        let fps = max(1, configuration.videoFrameRate)
        return max(1, UInt64((1.0 / Double(fps)) * 1_000_000_000))
    }

    static func nextLiveDeadline(
        after previous: DispatchTime,
        intervalNanoseconds: UInt64,
        now: DispatchTime
    ) -> DispatchTime {
        let next = saturatedNanosecondSum(previous.uptimeNanoseconds, intervalNanoseconds)
        if next < now.uptimeNanoseconds {
            return DispatchTime(uptimeNanoseconds: saturatedNanosecondSum(
                now.uptimeNanoseconds,
                intervalNanoseconds
            ))
        }
        return DispatchTime(uptimeNanoseconds: next)
    }

    private static func saturatedNanosecondSum(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        lhs > UInt64.max - rhs ? UInt64.max : lhs + rhs
    }
}

private struct LoLaLiveVideoTransmitContext {
    var configuration: ExternalConnectorSessionConfiguration
    var deadline: DispatchTime
    var counters: LoLaLiveTransmitCounters
    var socket: Int32
}

private struct LoLaLiveTransmitSnapshot {
    var audioDatagramCount: Int
    var videoFrameCount: Int
    var videoDatagramCount: Int
    var sentBytes: Int
    var droppedAudioPackets: Int
    var droppedVideoFrames: Int
    var deadlineAbandonedAudioPackets: Int
    var deadlineAbandonedVideoFrames: Int
}

private final class LoLaLiveTransmitCounters: @unchecked Sendable {
    private let lock = NSLock()
    private var audioDatagramCount = 0
    private var videoFrameCount = 0
    private var videoDatagramCount = 0
    private var sentBytes = 0
    private var droppedAudioPackets = 0
    private var droppedVideoFrames = 0
    private var deadlineAbandonedAudioPackets = 0
    private var deadlineAbandonedVideoFrames = 0

    var snapshot: LoLaLiveTransmitSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return LoLaLiveTransmitSnapshot(
            audioDatagramCount: audioDatagramCount,
            videoFrameCount: videoFrameCount,
            videoDatagramCount: videoDatagramCount,
            sentBytes: sentBytes,
            droppedAudioPackets: droppedAudioPackets,
            droppedVideoFrames: droppedVideoFrames,
            deadlineAbandonedAudioPackets: deadlineAbandonedAudioPackets,
            deadlineAbandonedVideoFrames: deadlineAbandonedVideoFrames
        )
    }

    func addAudio(
        datagrams: Int,
        bytes: Int,
        droppedPackets: Int,
        deadlineAbandonedPackets: Int = 0
    ) {
        lock.lock()
        audioDatagramCount += datagrams
        sentBytes += bytes
        droppedAudioPackets += droppedPackets
        deadlineAbandonedAudioPackets += deadlineAbandonedPackets
        lock.unlock()
    }

    func addVideo(
        frameCount: Int,
        datagrams: Int,
        bytes: Int,
        droppedFrames: Int,
        deadlineAbandonedFrames: Int = 0
    ) {
        lock.lock()
        videoFrameCount += frameCount
        videoDatagramCount += datagrams
        sentBytes += bytes
        droppedVideoFrames += droppedFrames
        deadlineAbandonedVideoFrames += deadlineAbandonedFrames
        lock.unlock()
    }
}

private final class LoLaLiveTransmitErrors: @unchecked Sendable {
    private let lock = NSLock()
    private var errors: [Error] = []

    private var snapshot: [Error] {
        lock.lock()
        defer { lock.unlock() }
        return errors
    }

    func append(_ error: Error) {
        lock.lock()
        errors.append(error)
        lock.unlock()
    }

    func throwIfPresent() throws {
        let errors = snapshot
        switch errors.count {
        case 0:
            return
        case 1:
            throw errors[0]
        default:
            throw LoLaLiveTransmitAggregateError(errors: errors)
        }
    }
}
