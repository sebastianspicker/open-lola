// Implements LoLaTcpControlExchangeTcpSocket socket I/O and resource lifetime, isolating Darwin calls from protocol decisions.
import Darwin

func makeExternalConnectorTcpSocket() throws -> Int32 {
    let descriptor = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
    guard descriptor >= 0 else {
        throw ExternalConnectorSessionError.socketFailed("tcp socket")
    }
    return descriptor
}

func connectExternalConnectorTcp(
    socket: Int32,
    host: String,
    port: UInt16,
    timeoutSeconds: Int
) throws {
    var address = try externalConnectorTcpAddress(host: host, port: port)
    let flags = fcntl(socket, F_GETFL, 0)
    guard flags >= 0, fcntl(socket, F_SETFL, flags | O_NONBLOCK) >= 0 else {
        throw ExternalConnectorSessionError.socketFailed("fcntl")
    }
    defer { _ = fcntl(socket, F_SETFL, flags) }

    let result = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            connect(socket, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    if result == 0 { return }
    guard errno == EINPROGRESS else {
        throw ExternalConnectorSessionError.socketFailed("tcp connect errno \(errno)")
    }

    var writeSet = fd_set()
    openLolaFDZero(&writeSet)
    try openLolaRequireFileDescriptorFitsFDSet(socket, context: "tcp connect")
    try openLolaFDSet(socket, set: &writeSet)
    var timeout = timeval(tv_sec: max(1, timeoutSeconds), tv_usec: 0)
    let ready = select(socket + 1, nil, &writeSet, nil, &timeout)
    guard ready > 0 else {
        throw ready == 0
            ? ExternalConnectorSessionError.receiveTimedOut
            : ExternalConnectorSessionError.socketFailed("tcp connect select errno \(errno)")
    }
    var socketError: Int32 = 0
    var socketErrorLength = socklen_t(MemoryLayout<Int32>.size)
    guard getsockopt(socket, SOL_SOCKET, SO_ERROR, &socketError, &socketErrorLength) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("tcp connect getsockopt errno \(errno)")
    }
    guard socketError == 0 else {
        throw ExternalConnectorSessionError.socketFailed("tcp connect errno \(socketError)")
    }
}

func bindExternalConnectorTcp(socket: Int32, host: String, port: UInt16) throws {
    var reuse: Int32 = 1
    guard setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("tcp setsockopt SO_REUSEADDR errno \(errno)")
    }
    var address = try externalConnectorTcpAddress(host: host, port: port)
    let result = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.bind(socket, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard result == 0 else {
        throw ExternalConnectorSessionError.socketFailed("tcp bind \(host):\(port) errno \(errno)")
    }
}

func waitForExternalConnectorTcpConnection(
    socket: Int32,
    timeoutSeconds: Int
) throws -> Bool {
    var readSet = fd_set()
    openLolaFDZero(&readSet)
    try openLolaRequireFileDescriptorFitsFDSet(socket, context: "tcp accept")
    try openLolaFDSet(socket, set: &readSet)
    var timeout = timeval(tv_sec: max(1, timeoutSeconds), tv_usec: 0)
    let ready = select(socket + 1, &readSet, nil, nil, &timeout)
    if ready > 0 {
        return true
    }
    if ready == 0 {
        return false
    }
    throw ExternalConnectorSessionError.socketFailed("tcp accept select errno \(errno)")
}

typealias ExternalConnectorTcpSendFunction = (
    _ socket: Int32,
    _ buffer: UnsafeRawPointer,
    _ byteCount: Int,
    _ flags: Int32
) -> Int

func externalConnectorTcpDarwinSend(
    socket: Int32,
    buffer: UnsafeRawPointer,
    byteCount: Int,
    flags: Int32
) -> Int {
    Darwin.send(socket, buffer, byteCount, flags)
}

func sendExternalConnectorTcpBytes(
    _ bytes: [UInt8],
    socket: Int32,
    send: ExternalConnectorTcpSendFunction = externalConnectorTcpDarwinSend
) throws -> Int {
    return try bytes.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else {
            throw ExternalConnectorSessionError.socketFailed("empty tcp send buffer")
        }
        var sentByteCount = 0
        while sentByteCount < rawBuffer.count {
            let remainingByteCount = rawBuffer.count - sentByteCount
            let sent = send(socket, baseAddress.advanced(by: sentByteCount), remainingByteCount, 0)
            if sent > 0, sent <= remainingByteCount {
                sentByteCount += sent
                continue
            }
            if sent < 0 {
                let savedErrno = errno
                if savedErrno == EINTR {
                    continue
                }
                throw ExternalConnectorSessionError.socketFailed("tcp send errno \(savedErrno)")
            }
            throw ExternalConnectorSessionError.socketFailed("tcp send")
        }
        return sentByteCount
    }
}

func sendExternalConnectorTcp(_ message: String, socket: Int32) throws -> Int {
    try sendExternalConnectorTcpBytes(lolaControlDatagramBytes(message), socket: socket)
}

func receiveExternalConnectorTcp(
    socket: Int32,
    bufferSize: Int
) throws -> (message: String, bytesTransferred: Int) {
    let targetByteCount = max(1, min(bufferSize, lolaControlDatagramByteCount))
    var messageBytes: [UInt8] = []
    messageBytes.reserveCapacity(targetByteCount)
    var buffer = [UInt8](repeating: 0, count: targetByteCount)
    while messageBytes.count < targetByteCount {
        let remainingByteCount = targetByteCount - messageBytes.count
        let received = recv(socket, &buffer, remainingByteCount, 0)
        let savedErrno = errno
        if received == 0 {
            _ = Darwin.shutdown(socket, SHUT_RDWR)
            throw ExternalConnectorSessionError.socketFailed("tcp peer closed connection")
        }
        guard received > 0 else {
            throw savedErrno == EAGAIN || savedErrno == EWOULDBLOCK
                ? ExternalConnectorSessionError.receiveTimedOut
                : ExternalConnectorSessionError.socketFailed("tcp recv errno \(savedErrno)")
        }
        messageBytes.append(contentsOf: buffer[0..<received])
        let message = try decodeExternalConnectorTcpMessage(messageBytes)
        if !message.contains("\0"),
           (try? LoLaCompatibilityControlMessage.parse(message)) != nil {
            return (message, messageBytes.count)
        }
    }
    return (try decodeExternalConnectorTcpMessage(messageBytes), messageBytes.count)
}

private func decodeExternalConnectorTcpMessage(_ messageBytes: [UInt8]) throws -> String {
    guard let message = String(bytes: messageBytes, encoding: .utf8) else {
        throw ExternalConnectorSessionError.malformedLoLaControlMessage("invalid UTF-8 TCP control datagram")
    }
    return message
}

func setExternalConnectorTcpTimeout(socket: Int32, seconds: Int) throws {
    var timeout = timeval(tv_sec: max(1, seconds), tv_usec: 0)
    guard setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size)) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("tcp setsockopt receive")
    }
    guard setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size)) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("tcp setsockopt send")
    }
}

private func externalConnectorTcpAddress(host: String, port: UInt16) throws -> sockaddr_in {
    try loLaIPv4SocketAddress(host: host, port: port, failurePrefix: "tcp")
}

func externalConnectorTcpHostString(_ address: in_addr) throws -> String {
    try lolaInetNtopString(address, failurePrefix: "tcp inet_ntop")
}
