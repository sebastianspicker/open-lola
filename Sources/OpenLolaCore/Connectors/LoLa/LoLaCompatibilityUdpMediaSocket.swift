import Darwin
import Foundation

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
            afterBind: {}
        )
    }

    func receive(
        request: LoLaUdpMediaReceiveRequest,
        afterBind: () throws -> Void,
        onDatagram: (LoLaUdpMediaDatagram) throws -> Void = { _ in }
    ) throws -> [LoLaUdpMediaDatagram] {
        let sockets = try LoLaUdpMediaReceiveSockets(bindHost: request.localHost, ports: request.ports)
        defer { sockets.close() }
        try afterBind()

        var datagrams: [LoLaUdpMediaDatagram] = []
        let deadline = MonotonicDeadline(seconds: TimeInterval(max(1, timeoutSeconds)))
        while datagrams.count < request.maxDatagrams, deadline.hasTimeRemaining {
            let readableStreams = try sockets.readableStreams()
            try appendReadableDatagrams(
                readableStreams,
                request: request,
                datagrams: &datagrams,
                onDatagram: onDatagram
            )
        }
        guard datagrams.count >= request.maxDatagrams else {
            throw ExternalConnectorSessionError.receiveTimedOut
        }
        return Array(datagrams.prefix(request.maxDatagrams))
    }

    private func appendReadableDatagrams(
        _ readableStreams: [LoLaUdpMediaSocketReadTarget],
        request: LoLaUdpMediaReceiveRequest,
        datagrams: inout [LoLaUdpMediaDatagram],
        onDatagram: (LoLaUdpMediaDatagram) throws -> Void
    ) throws {
        for target in readableStreams where datagrams.count < request.maxDatagrams {
            if let datagram = try receiveLoLaUdpMediaPayload(
                socket: target.socket,
                stream: target.stream,
                port: target.port,
                peer: request.peer
            ) {
                try onDatagram(datagram)
                datagrams.append(datagram)
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

    init(maxDatagrams: Int, localHost: String, peer: String, ports: LoLaUdpMediaReceivePorts) {
        self.maxDatagrams = maxDatagrams
        self.localHost = localHost
        self.peer = peer
        self.ports = ports
    }

    init(configuration: LoLaUdpMediaReceiveRunConfiguration) {
        self.init(
            maxDatagrams: configuration.maxDatagrams,
            localHost: configuration.localHost,
            peer: configuration.peer,
            ports: LoLaUdpMediaReceivePorts(audio: configuration.audioPort, video: configuration.videoPort)
        )
    }
}

private struct LoLaUdpMediaSocketReadTarget {
    var socket: Int32
    var stream: LoLaCompatibilityMediaStream
    var port: UInt16
}

private struct LoLaUdpMediaReceiveSockets {
    var audio: Int32
    var video: Int32
    var ports: LoLaUdpMediaReceivePorts

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

    func close() {
        Darwin.close(audio)
        Darwin.close(video)
    }

    func readableStreams() throws -> [LoLaUdpMediaSocketReadTarget] {
        var readSet = fd_set()
        openLolaFDZero(&readSet)
        try openLolaRequireFileDescriptorFitsFDSet(audio, context: "udp media audio")
        try openLolaRequireFileDescriptorFitsFDSet(video, context: "udp media video")
        try openLolaFDSet(audio, set: &readSet)
        try openLolaFDSet(video, set: &readSet)
        var timeout = timeval(tv_sec: 0, tv_usec: 50_000)
        let ready = select(max(audio, video) + 1, &readSet, nil, nil, &timeout)
        guard ready >= 0 else {
            throw ExternalConnectorSessionError.socketFailed("udp media select errno \(errno)")
        }
        guard ready > 0 else {
            return []
        }
        return try readableTargets(in: &readSet)
    }

    private func readableTargets(in readSet: inout fd_set) throws -> [LoLaUdpMediaSocketReadTarget] {
        var targets: [LoLaUdpMediaSocketReadTarget] = []
        if try openLolaFDIsSet(audio, set: &readSet) {
            targets.append(LoLaUdpMediaSocketReadTarget(socket: audio, stream: .audio, port: ports.audio))
        }
        if try openLolaFDIsSet(video, set: &readSet) {
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

private func receiveLoLaUdpMediaPayload(
    socket: Int32,
    stream: LoLaCompatibilityMediaStream,
    port: UInt16,
    peer: String
) throws -> LoLaUdpMediaDatagram?
{
    var buffer = [UInt8](repeating: 0, count: 65_536)
    var sender = sockaddr_in()
    var senderLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let received = withUnsafeMutablePointer(to: &sender) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            recvfrom(socket, &buffer, buffer.count, 0, socketAddress, &senderLength)
        }
    }
    guard received > 0 else {
        let receiveErrno = errno
        if received == 0 || receiveErrno == EAGAIN || receiveErrno == EWOULDBLOCK {
            throw ExternalConnectorSessionError.receiveTimedOut
        }
        throw ExternalConnectorSessionError.socketFailed("udp media recvfrom errno \(receiveErrno)")
    }
    let sourceHost = try loLaUdpMediaHostString(sender.sin_addr)
    let datagram = LoLaUdpMediaDatagram(
        stream: stream,
        port: port,
        sourceHost: sourceHost,
        payload: Data(buffer.prefix(received))
    )
    return loLaUdpMediaDatagramMatchesPeer(datagram, peer: peer) ? datagram : nil
}

func loLaUdpMediaAddress(host: String, port: UInt16) throws -> sockaddr_in {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
        throw ExternalConnectorSessionError.socketFailed("udp media inet_pton \(host)")
    }
    return address
}

private func loLaUdpMediaHostString(_ address: in_addr) throws -> String {
    try lolaInetNtopString(address, failurePrefix: "udp media inet_ntop")
}
