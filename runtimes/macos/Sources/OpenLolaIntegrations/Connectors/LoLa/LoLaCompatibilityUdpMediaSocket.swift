import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Implements LoLaCompatibilityUdpMediaSocket socket I/O and resource lifetime, isolating Darwin calls from protocol decisions.
import Darwin
import Foundation
import OpenLolaSessionDomain

struct LoLaAudioReceiveFreshnessSnapshot: Equatable, Sendable {
    var rejectedSourceDatagrams = 0
    var receivedDatagrams = 0
    var retainedEvidenceDatagrams = 0
    var playoutRejectedDatagrams = 0
}

final class LoLaAudioReceiveFreshnessCounters: @unchecked Sendable {
    private let lock = NSLock()
    private var rejectedSourceDatagrams = 0
    private var receivedDatagrams = 0
    private var retainedEvidenceDatagrams = 0
    private var playoutRejectedDatagrams = 0

    var snapshot: LoLaAudioReceiveFreshnessSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return LoLaAudioReceiveFreshnessSnapshot(
            rejectedSourceDatagrams: rejectedSourceDatagrams,
            receivedDatagrams: receivedDatagrams,
            retainedEvidenceDatagrams: retainedEvidenceDatagrams,
            playoutRejectedDatagrams: playoutRejectedDatagrams
        )
    }

    func noteReceived(retainedAsEvidence: Bool) {
        lock.lock()
        receivedDatagrams += 1
        if retainedAsEvidence {
            retainedEvidenceDatagrams += 1
        }
        lock.unlock()
    }

    func noteRejectedSource() {
        lock.lock()
        rejectedSourceDatagrams += 1
        lock.unlock()
    }

    func notePlayoutRejected() {
        lock.lock()
        playoutRejectedDatagrams += 1
        lock.unlock()
    }
}

private struct LoLaUdpMediaReceiveContext {
    var datagrams: [LoLaUdpMediaDatagram] = []
    var audioBuffer = [UInt8](repeating: 0, count: 65_536)
    var videoBuffer = [UInt8](repeating: 0, count: 65_536)
    let audioFreshnessCounters: LoLaAudioReceiveFreshnessCounters?
    let onDatagram: (LoLaUdpMediaDatagram) throws -> Void

    init(
        audioFreshnessCounters: LoLaAudioReceiveFreshnessCounters?,
        onDatagram: @escaping (LoLaUdpMediaDatagram) throws -> Void
    ) {
        self.audioFreshnessCounters = audioFreshnessCounters
        self.onDatagram = onDatagram
    }

    /// Hands every datagram to the live consumer and retains the first
    /// `evidenceLimit` of them for the report. A consumer failure for one
    /// datagram (for example an unexpected block size) is counted, not fatal.
    mutating func admit(_ datagram: LoLaUdpMediaDatagram, evidenceLimit: Int) {
        do {
            try onDatagram(datagram)
        } catch {
            audioFreshnessCounters?.notePlayoutRejected()
        }
        let retain = datagrams.count < evidenceLimit
        if retain {
            datagrams.append(datagram)
        }
        audioFreshnessCounters?.noteReceived(retainedAsEvidence: retain)
    }
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
        audioFreshnessCounters: LoLaAudioReceiveFreshnessCounters? = nil,
        cancellation: LoLaSessionCancellation? = nil,
        onDatagram: @escaping (LoLaUdpMediaDatagram) throws -> Void = { _ in }
    ) throws -> [LoLaUdpMediaDatagram] {
        let sockets = try LoLaUdpMediaReceiveSockets(bindHost: request.localHost, ports: request.ports)
        try afterBind(sockets)

        var context = LoLaUdpMediaReceiveContext(
            audioFreshnessCounters: audioFreshnessCounters,
            onDatagram: onDatagram
        )
        let deadline = request.deadlineNanoseconds.map(MonotonicDeadline.init(uptimeNanoseconds:))
            ?? MonotonicDeadline(seconds: TimeInterval(max(1, timeoutSeconds)))
        // A live session keeps receiving until its deadline so playout never
        // stops at an evidence count; a bounded diagnostic run stops once the
        // requested datagram count has been retained.
        // A peer-initiated end (/MESG_DISCONNECT) stops the loop at its next
        // wake-up, so the socket wait is bounded while a cancellation exists.
        while deadline.hasTimeRemaining, !(cancellation?.isCancelled ?? false),
              request.runUntilDeadline || context.datagrams.count < request.maxDatagrams {
            let waitSeconds = cancellation == nil
                ? deadline.remainingSeconds
                : min(deadline.remainingSeconds, lolaSessionCancellationPollSeconds)
            let readableStreams = try sockets.readableStreams(timeoutSeconds: waitSeconds)
            try appendReadableDatagrams(
                readableStreams,
                request: request,
                context: &context
            )
        }
        if cancellation?.isCancelled == true {
            return Array(context.datagrams.prefix(request.maxDatagrams))
        }
        let required = request.runUntilDeadline ? 1 : request.maxDatagrams
        guard context.datagrams.count >= required else {
            throw ExternalConnectorSessionError.receiveTimedOut
        }
        return Array(context.datagrams.prefix(request.maxDatagrams))
    }

    private func appendReadableDatagrams(
        _ readableStreams: [LoLaUdpMediaSocketReadTarget],
        request: LoLaUdpMediaReceiveRequest,
        context: inout LoLaUdpMediaReceiveContext
    ) throws {
        for target in readableStreams
        where request.runUntilDeadline || context.datagrams.count < request.maxDatagrams {
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
            switch attempt {
            case let .accepted(datagram):
                context.admit(datagram, evidenceLimit: request.maxDatagrams)
            case .rejectedPeer:
                context.audioFreshnessCounters?.noteRejectedSource()
            case .empty:
                break
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
    /// Live sessions receive until the deadline and retain `maxDatagrams`
    /// datagrams as evidence; bounded runs stop at `maxDatagrams`.
    var runUntilDeadline: Bool

    init(
        maxDatagrams: Int,
        localHost: String,
        peer: String,
        ports: LoLaUdpMediaReceivePorts,
        deadlineNanoseconds: UInt64? = nil,
        runUntilDeadline: Bool = false
    ) {
        self.maxDatagrams = maxDatagrams
        self.localHost = localHost
        self.peer = peer
        self.ports = ports
        self.deadlineNanoseconds = deadlineNanoseconds
        self.runUntilDeadline = runUntilDeadline
    }

    init(
        configuration: LoLaUdpMediaReceiveRunConfiguration,
        deadlineNanoseconds: UInt64? = nil,
        runUntilDeadline: Bool = false
    ) {
        self.init(
            maxDatagrams: configuration.maxDatagrams,
            localHost: configuration.localHost,
            peer: configuration.peer,
            ports: LoLaUdpMediaReceivePorts(audio: configuration.audioPort, video: configuration.videoPort),
            deadlineNanoseconds: deadlineNanoseconds,
            runUntilDeadline: runUntilDeadline
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
    try bindLoLaUdpMediaSocket(descriptor, host: bindHost, port: port)
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
    (try? LoLaCompatibilityMediaCodec.decodeAudioDatagram(payload)).map { Int($0.sequence) }
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
