import Darwin
import Dispatch
import Foundation

public struct LoLaSocketUdpMediaTransmitter: LoLaUdpMediaTransmitter {
    public init() {}

    public func transmit(_ datagrams: [LoLaUdpMediaDatagram], localHost: String, peer: String) throws -> [Int] {
        var sent: [Int] = []
        var sockets: [LoLaUdpMediaSocketCacheKey: Int32] = [:]
        defer {
            for descriptor in sockets.values {
                close(descriptor)
            }
        }
        var lastVideoSequence: Int?
        var nextVideoFrameDeadline: DispatchTime?
        for datagram in datagrams {
            if datagram.stream == .video,
               let sequence = datagram.sequenceNumber,
               let fps = datagram.videoFrameRate,
                lastVideoSequence != sequence {
                if let deadline = nextVideoFrameDeadline {
                    loLaUdpMediaSleepUntil(deadline)
                }
                let frameDurationNanoseconds = Int(1_000_000_000 / Double(max(1, fps)))
                nextVideoFrameDeadline = DispatchTime.now() + .nanoseconds(frameDurationNanoseconds)
                lastVideoSequence = sequence
            }
            let descriptor = try socket(for: datagram.port, localHost: localHost, sockets: &sockets)
            sent.append(try sendLoLaUdpMediaPayload(
                datagram.payload,
                socket: descriptor,
                peer: peer,
                port: datagram.port
            ))
        }
        return sent
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

private struct LoLaUdpMediaSocketCacheKey: Hashable {
    var port: UInt16
    var host: String
}

func sendLoLaUdpMediaPayload(_ payload: Data, socket: Int32, peer: String, port: UInt16) throws -> Int {
    var destination = try loLaUdpMediaAddress(host: peer, port: port)
    return try payload.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else {
            throw ExternalConnectorSessionError.socketFailed("empty udp media payload")
        }
        let sent = withUnsafePointer(to: &destination) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                retryLoLaUdpMediaSend {
                    sendto(socket, baseAddress, rawBuffer.count, 0, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == rawBuffer.count else {
            throw ExternalConnectorSessionError.socketFailed("udp media sendto \(peer):\(port) errno \(errno)")
        }
        return sent
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
        guard lastErrno == EAGAIN || lastErrno == EWOULDBLOCK, attempt < 5 else {
            errno = lastErrno
            return result
        }
        usleep(5_000)
    }
    errno = lastErrno
    return -1
}
