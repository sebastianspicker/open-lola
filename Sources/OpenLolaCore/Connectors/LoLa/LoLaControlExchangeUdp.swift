// Handles LoLaControlExchangeUdp control exchange, keeping control-plane details distinct from media data flow.
import Darwin
import Foundation

func lolaControlAdvertisedSourceIP(_ configuration: ExternalConnectorSessionConfiguration) throws -> String {
    guard configuration.localHost == "0.0.0.0", !configuration.peer.isEmpty else {
        return configuration.localHost
    }
    let descriptor = try makeExternalConnectorUdpSocket()
    defer { close(descriptor) }
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = configuration.controlPort.bigEndian
    guard inet_pton(AF_INET, configuration.peer, &address.sin_addr) == 1 else {
        throw ExternalConnectorSessionError.socketFailed("inet_pton \(configuration.peer)")
    }
    let connectStatus = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            connect(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard connectStatus == 0 else {
        throw ExternalConnectorSessionError.socketFailed(
            "connect \(configuration.peer):\(configuration.controlPort) errno \(errno)"
        )
    }
    var localAddress = sockaddr_in()
    var localAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameStatus = withUnsafeMutablePointer(to: &localAddress) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            getsockname(descriptor, socketAddress, &localAddressLength)
        }
    }
    guard nameStatus == 0 else {
        throw ExternalConnectorSessionError.socketFailed("getsockname errno \(errno)")
    }
    return try externalConnectorHostString(localAddress.sin_addr)
}

func makeExternalConnectorUdpSocket() throws -> Int32 {
    let descriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw ExternalConnectorSessionError.socketFailed("socket")
    }
    var reuse: Int32 = 1
    guard setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("udp setsockopt SO_REUSEADDR errno \(errno)")
    }
    #if os(macOS)
    guard setsockopt(descriptor, SOL_SOCKET, SO_REUSEPORT, &reuse, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("udp setsockopt SO_REUSEPORT errno \(errno)")
    }
    #endif
    return descriptor
}

func sendExternalConnectorUdp(
    _ message: String,
    socket: Int32,
    host: String,
    port: UInt16
) throws -> Int {
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
        throw ExternalConnectorSessionError.socketFailed("inet_pton \(host)")
    }
    let bytes = lolaControlDatagramBytes(message)
    let sent = try withUnsafePointer(to: &address) { pointer in
        try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            try bytes.withUnsafeBytes { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else {
                    throw ExternalConnectorSessionError.socketFailed("empty send buffer")
                }
                let result = try retryLoLaControlUdpSend(socket: socket) {
                    sendto(
                        socket,
                        baseAddress,
                        rawBuffer.count,
                        0,
                        socketAddress,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
                guard result >= 0 else {
                    throw ExternalConnectorSessionError.socketFailed("sendto errno \(errno)")
                }
                return result
            }
        }
    }
    return sent
}

func lolaControlDatagramBytes(_ message: String) -> [UInt8] {
    let bytes = [UInt8](message.utf8)
    if bytes.count > lolaControlDatagramByteCount {
        return Array(bytes.prefix(lolaControlDatagramByteCount))
    }
    return bytes + [UInt8](repeating: 0, count: lolaControlDatagramByteCount - bytes.count)
}

private func retryLoLaControlUdpSend(socket: Int32, _ send: () -> Int) throws -> Int {
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
        _ = try waitForWritableSocket(socket: socket, timeoutMicroseconds: 5_000)
    }
    errno = lastErrno
    return -1
}

struct ExternalConnectorUdpReceiveResult {
    var message: String
    var senderHost: String
    var senderPort: UInt16
    var bytesTransferred: Int
    var payload: [UInt8]
}

func receiveExternalConnectorUdp(
    socket: Int32,
    bufferSize: Int
) throws -> ExternalConnectorUdpReceiveResult {
    var buffer = [UInt8](repeating: 0, count: bufferSize)
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
        throw ExternalConnectorSessionError.socketFailed("recvfrom errno \(receiveErrno)")
    }
    let host = try externalConnectorHostString(sender.sin_addr)
    let messageBytes = buffer[0..<received]
    let messageEnd = messageBytes.firstIndex(of: 0) ?? messageBytes.endIndex
    let payload = Array(messageBytes)
    return ExternalConnectorUdpReceiveResult(
        message: String(bytes: messageBytes[..<messageEnd], encoding: .utf8) ?? "",
        senderHost: host,
        senderPort: UInt16(bigEndian: sender.sin_port),
        bytesTransferred: received,
        payload: payload
    )
}

private func externalConnectorHostString(_ address: in_addr) throws -> String {
    try lolaInetNtopString(address, failurePrefix: "inet_ntop")
}

func lolaInetNtopString(_ address: in_addr, failurePrefix: String) throws -> String {
    var mutableAddress = address
    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
    guard inet_ntop(AF_INET, &mutableAddress, &buffer, socklen_t(buffer.count)) != nil else {
        throw ExternalConnectorSessionError.socketFailed(failurePrefix)
    }
    buffer[buffer.count - 1] = 0
    guard let endIndex = buffer.firstIndex(of: 0) else {
        throw ExternalConnectorSessionError.socketFailed("\(failurePrefix) missing null terminator")
    }
    return String(bytes: buffer[..<endIndex].map(UInt8.init), encoding: .utf8) ?? ""
}

func bindExternalConnectorUdp(socket: Int32, host: String, port: UInt16) throws {
    let bindErrno = try externalConnectorUdpBindErrno(socket: socket, host: host, port: port)
    guard bindErrno == 0 else {
        throw ExternalConnectorSessionError.socketFailed("bind \(host):\(port) errno \(bindErrno)")
    }
}

func setExternalConnectorReceiveTimeout(socket: Int32, seconds: Int) throws {
    var timeout = timeval(tv_sec: max(1, seconds), tv_usec: 0)
    let status = setsockopt(
        socket,
        SOL_SOCKET,
        SO_RCVTIMEO,
        &timeout,
        socklen_t(MemoryLayout<timeval>.size)
    )
    guard status == 0 else {
        throw ExternalConnectorSessionError.socketFailed("setsockopt")
    }
}
