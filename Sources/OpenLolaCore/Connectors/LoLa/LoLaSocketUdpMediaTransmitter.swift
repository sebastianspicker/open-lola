// Implements LoLaSocketUdpMediaTransmitter socket I/O and resource lifetime, isolating Darwin calls from protocol decisions.
import Darwin
import Dispatch
import Foundation

/// Sends LoLa socket UDP media transmitter through sockets bound for the requested peer.
public struct LoLaSocketUdpMediaTransmitter: LoLaUdpMediaTransmitter {
    public var usesRealLink: Bool { true }

    let send: (Data, Int32, String, UInt16) throws -> LoLaUdpMediaSendResult
    let boundSocketForDatagram: ((LoLaUdpMediaDatagram) -> Int32)?
    let deadline: DispatchTime?
    let now: () -> DispatchTime
    let sleepUntil: (DispatchTime) -> Void

    public init() {
        self.send = sendLoLaUdpMediaPayload
        boundSocketForDatagram = nil
        deadline = nil
        now = DispatchTime.now
        sleepUntil = { loLaUdpMediaSleepUntil($0) }
    }

    init(send: @escaping (Data, Int32, String, UInt16) throws -> LoLaUdpMediaSendResult) {
        self.send = send
        boundSocketForDatagram = nil
        deadline = nil
        now = DispatchTime.now
        sleepUntil = { loLaUdpMediaSleepUntil($0) }
    }

    init(
        boundSocketForDatagram: @escaping (LoLaUdpMediaDatagram) -> Int32,
        send: @escaping (Data, Int32, String, UInt16) throws -> LoLaUdpMediaSendResult = sendLoLaUdpMediaPayload,
        deadline: DispatchTime? = nil,
        now: @escaping () -> DispatchTime = DispatchTime.now,
        sleepUntil: @escaping (DispatchTime) -> Void = { loLaUdpMediaSleepUntil($0) }
    ) {
        self.boundSocketForDatagram = boundSocketForDatagram
        self.send = send
        self.deadline = deadline
        self.now = now
        self.sleepUntil = sleepUntil
    }

    public func transmit(_ datagrams: [LoLaUdpMediaDatagram], localHost: String, peer: String) throws -> [Int] {
        let outcome = try transmitResult(datagrams, localHost: localHost, peer: peer)
        return outcome.sentByteCounts
    }

    public func transmitResult(
        _ datagrams: [LoLaUdpMediaDatagram], localHost: String, peer: String
    ) throws -> LoLaUdpMediaTransmitOutcome {
        if let boundSocketForDatagram {
            return try transmit(datagrams, peer: peer, socketForDatagram: boundSocketForDatagram)
        }
        var sockets: [LoLaUdpMediaSocketCacheKey: Int32] = [:]
        defer {
            for descriptor in sockets.values {
                close(descriptor)
            }
        }
        return try transmit(datagrams, peer: peer) { datagram in
            try socket(for: datagram.port, localHost: localHost, sockets: &sockets)
        }
    }

    func transmit(
        _ datagrams: [LoLaUdpMediaDatagram],
        peer: String,
        socketForDatagram: (LoLaUdpMediaDatagram) throws -> Int32
    ) throws -> LoLaUdpMediaTransmitOutcome {
        var state = LoLaUdpMediaTransmitState()
        let orderedDatagrams = loLaUdpMediaLatencyPriorityOrder(datagrams)
        for (index, datagram) in orderedDatagrams.enumerated() {
            if transmissionDeadlineExpired {
                state.recordAbandoned(orderedDatagrams[index...])
                break
            }
            if state.shouldSkipAfterBackpressure(datagram) {
                continue
            }
            state.paceVideoIfNeeded(
                datagram,
                exchangeDeadline: deadline,
                now: now,
                sleepUntil: sleepUntil
            )
            // Pacing may have slept exactly to the shared exchange deadline.
            // Never perform the socket lookup or send once that deadline has
            // elapsed; account for the complete unsent suffix instead.
            if transmissionDeadlineExpired {
                state.recordAbandoned(orderedDatagrams[index...])
                break
            }
            let descriptor = try socketForDatagram(datagram)
            let result = try send(datagram.payload, descriptor, peer, datagram.port)
            state.record(result, for: datagram)
        }
        return state.outcome
    }

    private var transmissionDeadlineExpired: Bool {
        guard let deadline else {
            return false
        }
        return now() >= deadline
    }

    private func socket(
        for port: UInt16,
        localHost: String,
        sockets: inout [LoLaUdpMediaSocketCacheKey: Int32]
    ) throws -> Int32 {
        let key = LoLaUdpMediaSocketCacheKey(port: port, host: localHost)
        if let descriptor = sockets[key] {
            return descriptor
        }
        let descriptor = try makeLoLaUdpMediaSocket(bindHost: localHost, port: port)
        sockets[key] = descriptor
        return descriptor
    }
}

func loLaUdpMediaLatencyPriorityOrder(
    _ datagrams: [LoLaUdpMediaDatagram]
) -> [LoLaUdpMediaDatagram] {
    var ordered: [LoLaUdpMediaDatagram] = []
    ordered.reserveCapacity(datagrams.count)
    var index = 0
    while index < datagrams.count {
        guard let sequence = datagrams[index].sequenceNumber else {
            ordered.append(datagrams[index])
            index += 1
            continue
        }
        var end = index + 1
        while end < datagrams.count, datagrams[end].sequenceNumber == sequence {
            end += 1
        }
        let group = datagrams[index..<end]
        ordered.append(contentsOf: group.filter { $0.stream == .audio })
        ordered.append(contentsOf: group.filter { $0.stream != .audio })
        index = end
    }
    return ordered
}

func loLaUdpMediaDeadlineAbandonment(
    _ datagrams: [LoLaUdpMediaDatagram]
) -> (audioPackets: Int, videoFrames: Int) {
    let audioPackets = datagrams.count { $0.stream == .audio }
    var videoSequences = Set<Int>()
    var unsequencedVideoDatagrams = 0
    for datagram in datagrams where datagram.stream == .video {
        if let sequence = datagram.sequenceNumber {
            videoSequences.insert(sequence)
        } else {
            unsequencedVideoDatagrams += 1
        }
    }
    return (audioPackets, videoSequences.count + unsequencedVideoDatagrams)
}

private struct LoLaUdpMediaSocketCacheKey: Hashable {
    var port: UInt16
    var host: String
}

private struct LoLaUdpMediaTransmitState {
    private var sentByteCounts: [Int] = []
    private var lastVideoSequence: Int?
    private var droppedAudioSequence: Int?
    private var droppedVideoSequence: Int?
    private var droppedAudioPackets = 0
    private var droppedVideoFrames = 0
    private var deadlineAbandonedAudioPackets = 0
    private var deadlineAbandonedVideoFrames = 0
    private var nextVideoFrameDeadline: DispatchTime?

    var outcome: LoLaUdpMediaTransmitOutcome {
        LoLaUdpMediaTransmitOutcome(
            sentByteCounts: sentByteCounts,
            droppedAudioPackets: droppedAudioPackets,
            droppedVideoFrames: droppedVideoFrames,
            deadlineAbandonedAudioPackets: deadlineAbandonedAudioPackets,
            deadlineAbandonedVideoFrames: deadlineAbandonedVideoFrames
        )
    }

    mutating func recordAbandoned(_ datagrams: ArraySlice<LoLaUdpMediaDatagram>) {
        let abandoned = loLaUdpMediaDeadlineAbandonment(Array(datagrams))
        deadlineAbandonedAudioPackets += abandoned.audioPackets
        deadlineAbandonedVideoFrames += abandoned.videoFrames
    }

    mutating func shouldSkipAfterBackpressure(_ datagram: LoLaUdpMediaDatagram) -> Bool {
        if let droppedAudioSequence,
           datagram.stream == .audio,
           datagram.sequenceNumber == droppedAudioSequence {
            droppedAudioPackets += 1
            return true
        }
        guard let droppedVideoSequence else {
            return false
        }
        return datagram.stream == .video && datagram.sequenceNumber == droppedVideoSequence
    }

    mutating func paceVideoIfNeeded(
        _ datagram: LoLaUdpMediaDatagram,
        exchangeDeadline: DispatchTime?,
        now: () -> DispatchTime,
        sleepUntil: (DispatchTime) -> Void
    ) {
        guard datagram.stream == .video,
              let sequence = datagram.sequenceNumber,
              let fps = datagram.videoFrameRate,
              lastVideoSequence != sequence else {
            return
        }
        if let nextVideoFrameDeadline {
            sleepUntil(DispatchTime(
                uptimeNanoseconds: min(
                    nextVideoFrameDeadline.uptimeNanoseconds,
                    exchangeDeadline?.uptimeNanoseconds ?? UInt64.max
                )
            ))
        }
        let frameDurationNanoseconds = Int(1_000_000_000 / Double(max(1, fps)))
        nextVideoFrameDeadline = now() + .nanoseconds(frameDurationNanoseconds)
        lastVideoSequence = sequence
    }

    mutating func record(_ result: LoLaUdpMediaSendResult, for datagram: LoLaUdpMediaDatagram) {
        switch result {
        case let .sent(byteCount):
            sentByteCounts.append(byteCount)
        case .wouldBlock where datagram.stream == .video:
            droppedVideoFrames += 1
            droppedVideoSequence = datagram.sequenceNumber
        case .wouldBlock:
            droppedAudioPackets += 1
            droppedAudioSequence = datagram.sequenceNumber
        }
    }
}

enum LoLaUdpMediaSendResult: Equatable {
    case sent(Int)
    case wouldBlock
}

func sendLoLaUdpMediaPayload(_ payload: Data, socket: Int32, peer: String, port: UInt16) throws -> LoLaUdpMediaSendResult {
    var destination = try loLaUdpMediaAddress(host: peer, port: port)
    return try payload.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else {
            throw ExternalConnectorSessionError.socketFailed("empty udp media payload")
        }
        let sent = withUnsafePointer(to: &destination) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                retryLoLaUdpMediaSend {
                    sendto(
                        socket,
                        baseAddress,
                        rawBuffer.count,
                        MSG_DONTWAIT,
                        socketAddress,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
            }
        }
        if sent < 0, errno == EAGAIN || errno == EWOULDBLOCK {
            return .wouldBlock
        }
        guard sent == rawBuffer.count else {
            throw ExternalConnectorSessionError.socketFailed("udp media sendto \(peer):\(port) errno \(errno)")
        }
        return .sent(sent)
    }
}

func loLaUdpMediaSleepUntil(
    _ deadline: DispatchTime,
    now: () -> DispatchTime = DispatchTime.now,
    sleep: (useconds_t) -> Int32 = usleep
) {
    let maxInterruptedSleeps = 1_000
    var interruptedSleeps = 0
    while true {
        let current = now()
        guard deadline.uptimeNanoseconds > current.uptimeNanoseconds else {
            return
        }
        let remainingNanoseconds = deadline.uptimeNanoseconds - current.uptimeNanoseconds
        let remainingMicroseconds = Double(remainingNanoseconds) / 1_000
        let clampedMicroseconds = min(remainingMicroseconds, Double(UInt32.max))
        let microseconds = useconds_t(clampedMicroseconds)
        let result = sleep(microseconds)
        if result == 0 {
            return
        }
        guard errno == EINTR else {
            return
        }
        interruptedSleeps += 1
        guard interruptedSleeps < maxInterruptedSleeps else {
            return
        }
    }
}

func retryLoLaUdpMediaSend(_ send: () -> Int) -> Int {
    var lastErrno: Int32 = 0
    for attempt in 0..<6 {
        let result = send()
        if result >= 0 {
            return result
        }
        lastErrno = errno
        guard lastErrno == EINTR, attempt < 5 else {
            errno = lastErrno
            return result
        }
    }
    errno = lastErrno
    return -1
}
