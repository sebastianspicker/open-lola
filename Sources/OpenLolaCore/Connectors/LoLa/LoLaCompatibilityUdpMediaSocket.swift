// Implements LoLaCompatibilityUdpMediaSocket socket I/O and resource lifetime, isolating Darwin calls from protocol decisions.
import Darwin
import Foundation

struct LoLaAudioReceiveFreshnessSnapshot: Equatable, Sendable {
    var coalescedStaleAudioDatagrams: Int
    var rejectedAudioSourceDatagrams: Int
}

final class LoLaAudioReceiveFreshnessCounters: @unchecked Sendable {
    private let lock = NSLock()
    private var coalescedStaleAudioDatagrams = 0
    private var rejectedAudioSourceDatagrams = 0

    var snapshot: LoLaAudioReceiveFreshnessSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return LoLaAudioReceiveFreshnessSnapshot(
            coalescedStaleAudioDatagrams: coalescedStaleAudioDatagrams,
            rejectedAudioSourceDatagrams: rejectedAudioSourceDatagrams
        )
    }

    func addCoalescedStaleAudioDatagrams(_ count: Int) {
        lock.lock()
        coalescedStaleAudioDatagrams += count
        lock.unlock()
    }

    func addRejectedAudioSourceDatagrams(_ count: Int = 1) {
        lock.lock()
        rejectedAudioSourceDatagrams += count
        lock.unlock()
    }
}

struct LoLaAudioReceiveDrainAccumulator {
    private(set) var newestValidDatagram: LoLaUdpMediaDatagram?
    private(set) var coalescedStaleAudioDatagrams = 0
    private(set) var rejectedAudioSourceDatagrams = 0

    mutating func recordValid(_ datagram: LoLaUdpMediaDatagram) {
        guard let newestValidDatagram else {
            self.newestValidDatagram = datagram
            return
        }
        if loLaAudioDatagramIsNewer(datagram, than: newestValidDatagram) {
            coalescedStaleAudioDatagrams += 1
            self.newestValidDatagram = datagram
        } else {
            coalescedStaleAudioDatagrams += 1
        }
    }

    mutating func recordRejectedSource() {
        rejectedAudioSourceDatagrams += 1
    }

    mutating func deliverNewest(
        _ deliver: (LoLaUdpMediaDatagram) throws -> Void
    ) rethrows {
        guard let newestValidDatagram else {
            return
        }
        try deliver(newestValidDatagram)
    }
}

private struct LoLaUdpMediaReceiveContext {
    var datagrams: [LoLaUdpMediaDatagram] = []
    var audioBuffer = [UInt8](repeating: 0, count: 65_536)
    var videoBuffer = [UInt8](repeating: 0, count: 65_536)
    let coalesceReadableAudioToNewest: Bool
    let audioFreshnessCounters: LoLaAudioReceiveFreshnessCounters?
    let onDatagram: (LoLaUdpMediaDatagram) throws -> Void

    init(
        coalesceReadableAudioToNewest: Bool,
        audioFreshnessCounters: LoLaAudioReceiveFreshnessCounters?,
        onDatagram: @escaping (LoLaUdpMediaDatagram) throws -> Void
    ) {
        self.coalesceReadableAudioToNewest = coalesceReadableAudioToNewest
        self.audioFreshnessCounters = audioFreshnessCounters
        self.onDatagram = onDatagram
    }

    mutating func append(_ datagram: LoLaUdpMediaDatagram) throws {
        try onDatagram(datagram)
        datagrams.append(datagram)
    }
}

/// LoLa serializes a UInt32 media sequence. Keep the newest value across its
/// wrap while treating duplicates and reordered arrivals as stale. Unsequenced
/// evidence-only datagrams retain the historical arrival-order fallback.
private func loLaAudioDatagramIsNewer(
    _ candidate: LoLaUdpMediaDatagram,
    than current: LoLaUdpMediaDatagram
) -> Bool {
    let candidateSequence = loLaValidAudioSequence(candidate.sequenceNumber)
    let currentSequence = loLaValidAudioSequence(current.sequenceNumber)
    switch (candidateSequence, currentSequence) {
    case let (.some(candidateSequence), .some(currentSequence)):
        let distance = candidateSequence &- currentSequence
        return distance != 0 && distance < (UInt32.max / 2) + 1
    case (.some, .none):
        return true
    case (.none, .some):
        return false
    case (.none, .none):
        return true
    }
}

private func loLaValidAudioSequence(_ value: Int?) -> UInt32? {
    guard let value, value >= 0, value <= Int(UInt32.max) else {
        return nil
    }
    return UInt32(value)
}

/// Receives LoLa socket UDP media receiver from bound sockets until its request completes.
public struct LoLaSocketUdpMediaReceiver: LoLaUdpMediaReceiver {
    public var timeoutSeconds: Int

    public init(timeoutSeconds: Int = 1) {
        self.timeoutSeconds = timeoutSeconds
    }

    public func receive(
        maxDatagrams: Int,
        localHost: String,
        peer: String,
        audioPort: UInt16,
        videoPort: UInt16
    ) throws -> [LoLaUdpMediaDatagram] {
        try receive(
            request: LoLaUdpMediaReceiveRequest(
                maxDatagrams: maxDatagrams,
                localHost: localHost,
                peer: peer,
                ports: LoLaUdpMediaReceivePorts(audio: audioPort, video: videoPort)
            ),
            afterBind: { _ in }
        )
    }

    func receive(
        request: LoLaUdpMediaReceiveRequest,
        afterBind: (LoLaUdpMediaReceiveSockets) throws -> Void,
        coalesceReadableAudioToNewest: Bool = false,
        audioFreshnessCounters: LoLaAudioReceiveFreshnessCounters? = nil,
        onDatagram: @escaping (LoLaUdpMediaDatagram) throws -> Void = { _ in }
    ) throws -> [LoLaUdpMediaDatagram] {
        let sockets = try LoLaUdpMediaReceiveSockets(bindHost: request.localHost, ports: request.ports)
        try afterBind(sockets)

        var context = LoLaUdpMediaReceiveContext(
            coalesceReadableAudioToNewest: coalesceReadableAudioToNewest,
            audioFreshnessCounters: audioFreshnessCounters,
            onDatagram: onDatagram
        )
        let deadline = request.deadlineNanoseconds.map(MonotonicDeadline.init(uptimeNanoseconds:))
            ?? MonotonicDeadline(seconds: TimeInterval(max(1, timeoutSeconds)))
        while context.datagrams.count < request.maxDatagrams, deadline.hasTimeRemaining {
            let readableStreams = try sockets.readableStreams(timeoutSeconds: deadline.remainingSeconds)
            try appendReadableDatagrams(
                readableStreams,
                request: request,
                context: &context
            )
        }
        guard context.datagrams.count >= request.maxDatagrams else {
            throw ExternalConnectorSessionError.receiveTimedOut
        }
        return Array(context.datagrams.prefix(request.maxDatagrams))
    }

    private func appendReadableDatagrams(
        _ readableStreams: [LoLaUdpMediaSocketReadTarget],
        request: LoLaUdpMediaReceiveRequest,
        context: inout LoLaUdpMediaReceiveContext
    ) throws {
        for target in readableStreams where context.datagrams.count < request.maxDatagrams {
            if target.stream == .audio, context.coalesceReadableAudioToNewest {
                try drainReadableAudioDatagrams(
                    target: target,
                    request: request,
                    context: &context
                )
            } else {
                let attempt: LoLaUdpMediaReceiveAttempt
                if target.stream == .audio {
                    attempt = try receiveLoLaUdpMediaPayload(
                        socket: target.socket, stream: target.stream, port: target.port, peer: request.peer, buffer: &context.audioBuffer
                    )
                } else {
                    attempt = try receiveLoLaUdpMediaPayload(
                        socket: target.socket, stream: target.stream, port: target.port, peer: request.peer, buffer: &context.videoBuffer
                    )
                }
                if case let .accepted(datagram) = attempt {
                    try context.append(datagram)
                }
            }
        }
    }

    private func drainReadableAudioDatagrams(
        target: LoLaUdpMediaSocketReadTarget,
        request: LoLaUdpMediaReceiveRequest,
        context: inout LoLaUdpMediaReceiveContext
    ) throws {
        var accumulator = LoLaAudioReceiveDrainAccumulator()
        while true {
            switch try receiveLoLaUdpMediaPayload(
                socket: target.socket,
                stream: target.stream,
                port: target.port,
                peer: request.peer,
                buffer: &context.audioBuffer
            ) {
            case let .accepted(datagram):
                accumulator.recordValid(datagram)
            case .rejectedPeer:
                accumulator.recordRejectedSource()
            case .empty:
                context.audioFreshnessCounters?.addCoalescedStaleAudioDatagrams(accumulator.coalescedStaleAudioDatagrams)
                context.audioFreshnessCounters?.addRejectedAudioSourceDatagrams(accumulator.rejectedAudioSourceDatagrams)
                try accumulator.deliverNewest { datagram in
                    try context.append(datagram)
                }
                return
            }
        }
    }
}

struct LoLaUdpMediaReceivePorts: Sendable {
    var audio: UInt16
    var video: UInt16
}

struct LoLaUdpMediaReceiveRequest: Sendable {
    var maxDatagrams: Int
    var localHost: String
    var peer: String
    var ports: LoLaUdpMediaReceivePorts
    var deadlineNanoseconds: UInt64?

    init(
        maxDatagrams: Int,
        localHost: String,
        peer: String,
        ports: LoLaUdpMediaReceivePorts,
        deadlineNanoseconds: UInt64? = nil
    ) {
        self.maxDatagrams = maxDatagrams
        self.localHost = localHost
        self.peer = peer
        self.ports = ports
        self.deadlineNanoseconds = deadlineNanoseconds
    }

    init(configuration: LoLaUdpMediaReceiveRunConfiguration, deadlineNanoseconds: UInt64? = nil) {
        self.init(
            maxDatagrams: configuration.maxDatagrams,
            localHost: configuration.localHost,
            peer: configuration.peer,
            ports: LoLaUdpMediaReceivePorts(audio: configuration.audioPort, video: configuration.videoPort),
            deadlineNanoseconds: deadlineNanoseconds
        )
    }
}

struct LoLaUdpMediaSocketReadTarget {
    var socket: Int32
    var stream: LoLaCompatibilityMediaStream
    var port: UInt16
}

final class LoLaUdpMediaReceiveSockets: @unchecked Sendable {
    let audio: Int32
    let video: Int32
    let ports: LoLaUdpMediaReceivePorts

    init(bindHost: String, ports: LoLaUdpMediaReceivePorts) throws {
        self.audio = try makeLoLaUdpMediaSocket(bindHost: bindHost, port: ports.audio)
        do {
            self.video = try makeLoLaUdpMediaSocket(bindHost: bindHost, port: ports.video)
        } catch {
            Darwin.close(audio)
            throw error
        }
        self.ports = ports
    }

    deinit {
        Darwin.close(audio)
        Darwin.close(video)
    }

    func socket(for stream: LoLaCompatibilityMediaStream) -> Int32 {
        stream == .audio ? audio : video
    }

    func readableStreams(timeoutSeconds: TimeInterval) throws -> [LoLaUdpMediaSocketReadTarget] {
        let timeoutMicrosecondsDouble = max(1, (max(0, timeoutSeconds) * 1_000_000).rounded(.up))
        let timeoutMicroseconds = timeoutMicrosecondsDouble >= Double(UInt64.max)
            ? UInt64.max
            : UInt64(timeoutMicrosecondsDouble)
        let readable = try waitForReadableSockets(
            sockets: [audio, video],
            timeoutMicroseconds: timeoutMicroseconds
        )
        var targets: [LoLaUdpMediaSocketReadTarget] = []
        if readable.contains(audio) {
            targets.append(LoLaUdpMediaSocketReadTarget(socket: audio, stream: .audio, port: ports.audio))
        }
        if readable.contains(video) {
            targets.append(LoLaUdpMediaSocketReadTarget(socket: video, stream: .video, port: ports.video))
        }
        return targets
    }
}

func makeLoLaUdpMediaSocket(bindHost: String, port: UInt16) throws -> Int32 {
    let descriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw ExternalConnectorSessionError.socketFailed("udp media socket")
    }
    var shouldClose = true
    defer {
        if shouldClose {
            close(descriptor)
        }
    }
    var reuse: Int32 = 1
    guard setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("udp media setsockopt SO_REUSEADDR errno \(errno)")
    }
    do {
        try bindLoLaUdpMediaSocket(descriptor, host: bindHost, port: port)
    } catch {
        if bindHost != "0.0.0.0" {
            try bindLoLaUdpMediaSocket(descriptor, host: "0.0.0.0", port: port)
        } else {
            throw error
        }
    }
    try setNonBlocking(descriptor)
    shouldClose = false
    return descriptor
}

private func bindLoLaUdpMediaSocket(_ descriptor: Int32, host: String, port: UInt16) throws {
    var address = try loLaUdpMediaAddress(host: host, port: port)
    let result = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.bind(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard result == 0 else {
        throw ExternalConnectorSessionError.socketFailed("udp media bind \(host):\(port) errno \(errno)")
    }
}

private enum LoLaUdpMediaReceiveAttempt {
    case accepted(LoLaUdpMediaDatagram)
    case rejectedPeer
    case empty
}

private func receiveLoLaUdpMediaPayload(
    socket: Int32,
    stream: LoLaCompatibilityMediaStream,
    port: UInt16,
    peer: String,
    buffer: inout [UInt8]
) throws -> LoLaUdpMediaReceiveAttempt {
    var sender = sockaddr_in()
    var senderLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let received = buffer.withUnsafeMutableBytes { bytes in
        withUnsafeMutablePointer(to: &sender) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                recvfrom(socket, bytes.baseAddress, bytes.count, MSG_DONTWAIT, socketAddress, &senderLength)
            }
        }
    }
    guard received > 0 else {
        let receiveErrno = errno
        if received == 0 || receiveErrno == EAGAIN || receiveErrno == EWOULDBLOCK {
            return .empty
        }
        throw ExternalConnectorSessionError.socketFailed("udp media recvfrom errno \(receiveErrno)")
    }
    let sourceHost = try loLaUdpMediaHostString(sender.sin_addr)
    var datagram = LoLaUdpMediaDatagram(
        stream: stream,
        port: port,
        sourceHost: sourceHost,
        payload: Data(buffer.prefix(received))
    )
    if stream == .audio {
        datagram.sequenceNumber = loLaAudioSequenceNumber(datagram.payload)
    }
    return loLaUdpMediaDatagramMatchesPeer(datagram, peer: peer) ? .accepted(datagram) : .rejectedPeer
}

private func loLaAudioSequenceNumber(_ payload: Data) -> Int? {
    guard let fragment = try? LoLaCompatibilityMediaCodec.decode(payload).normalFragment,
          fragment.header.fragmentCount == 1,
          fragment.header.fragmentIndex == 0,
          fragment.header.originalOffset == 0,
          fragment.header.finalFlag,
          let sequence = fragment.body?.sequence else {
        return nil
    }
    return Int(sequence)
}

func loLaUdpMediaAddress(host: String, port: UInt16) throws -> sockaddr_in {
    try loLaIPv4SocketAddress(host: host, port: port, failurePrefix: "udp media")
}

func loLaIPv4SocketAddress(
    host: String,
    port: UInt16,
    failurePrefix: String
) throws -> sockaddr_in {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    guard host.withCString({ inet_pton(AF_INET, $0, &address.sin_addr) }) == 1 else {
        throw ExternalConnectorSessionError.socketFailed("\(failurePrefix) inet_pton \(host)")
    }
    return address
}

private func loLaUdpMediaHostString(_ address: in_addr) throws -> String {
    try lolaInetNtopString(address, failurePrefix: "udp media inet_ntop")
}
