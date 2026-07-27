// Implements UdpPcmSocketOperations socket I/O and resource lifetime, isolating Darwin calls from protocol decisions.
import Darwin
import Foundation
import os

/// Selects requested kernel send and receive buffer sizing for UDP sockets.
public enum UdpSocketBufferProfile: Equatable, Sendable {
    /// Direct P2P audio: one complete worst-case 16-fragment deadline plus four
    /// datagrams of scheduler slack. Keeping this separate prevents a stalled
    /// receive loop from silently accumulating the wider shared audio backlog.
    case minimumLatencyAudio
    case realtimeAudio
    case realtimeVideo
    case diagnostic

    var byteCount: Int32 {
        switch self {
        case .minimumLatencyAudio:
            24 * 1_024
        case .realtimeAudio:
            // One full 16-fragment, 1,200-byte audio deadline plus short scheduling slack.
            32 * 1_024
        case .realtimeVideo:
            // Video is latest-frame paced but arrives in larger fragment bursts.
            256 * 1_024
        case .diagnostic:
            4 * 1_024 * 1_024
        }
    }

    var usesNonBlockingSend: Bool { self != .diagnostic }
}

private let maxUdpDatagramPayloadByteCount = 65_535

enum UdpDatagramSendResult: Equatable, Sendable {
    case sent
    case wouldBlock
}

func makeUdpSocket(
    receiveTimeoutSeconds: Int,
    bufferProfile: UdpSocketBufferProfile = .diagnostic
) throws -> Int32 {
    let descriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw UdpPcmRouteProbeError.socketFailed
    }

    do {
        try setUdpSocketBuffer(byteCount: bufferProfile.byteCount, option: SO_RCVBUF, socket: descriptor)
        try setUdpSocketBuffer(byteCount: bufferProfile.byteCount, option: SO_SNDBUF, socket: descriptor)
    } catch {
        closeUdpSocket(descriptor)
        throw error
    }

    var timeout = timeval(tv_sec: receiveTimeoutSeconds, tv_usec: 0)
    let timeoutResult = setsockopt(
        descriptor,
        SOL_SOCKET,
        SO_RCVTIMEO,
        &timeout,
        socklen_t(MemoryLayout<timeval>.size)
    )
    if timeoutResult != 0 {
        let savedErrno = errno
        closeUdpSocket(descriptor)
        throw UdpPcmRouteProbeError.setSocketOptionFailed(savedErrno)
    }
    return descriptor
}

private func setUdpSocketBuffer(byteCount: Int32, option: Int32, socket: Int32) throws {
    var byteCount = byteCount
    let result = setsockopt(
        socket,
        SOL_SOCKET,
        option,
        &byteCount,
        socklen_t(MemoryLayout<Int32>.size)
    )
    if result != 0 {
        let savedErrno = errno
        throw UdpPcmRouteProbeError.setSocketOptionFailed(savedErrno)
    }
    var actualByteCount: Int32 = 0
    var actualByteCountSize = socklen_t(MemoryLayout<Int32>.size)
    let readbackResult = getsockopt(
        socket,
        SOL_SOCKET,
        option,
        &actualByteCount,
        &actualByteCountSize
    )
    if readbackResult != 0 {
        let savedErrno = errno
        throw UdpPcmRouteProbeError.setSocketOptionFailed(savedErrno)
    }
    if actualByteCount < byteCount {
        os_log(
            .error,
            "UDP socket buffer option %{public}d capped below requested bytes: requested=%{public}d actual=%{public}d",
            option,
            byteCount,
            actualByteCount
        )
    }
}

func closeUdpSocket(_ descriptor: Int32) {
    let result = Darwin.close(descriptor)
    if result != 0 {
        os_log(.fault, "close failed for UDP socket %{public}d with errno %{public}d", descriptor, errno)
    }
}

func setNonBlocking(_ socket: Int32) throws {
    let flags = fcntl(socket, F_GETFL, 0)
    let getFlagsErrno = errno
    if flags == -1 {
        throw UdpPcmRouteProbeError.fcntlFailed(getFlagsErrno)
    }
    let setFlagsResult = fcntl(socket, F_SETFL, flags | O_NONBLOCK)
    let setFlagsErrno = errno
    if setFlagsResult == -1 {
        throw UdpPcmRouteProbeError.fcntlFailed(setFlagsErrno)
    }
}

func setDscp(_ dscp: Int, socket: Int32) throws {
    var tos = Int32(dscp << 2)
    let result = setsockopt(
        socket,
        IPPROTO_IP,
        IP_TOS,
        &tos,
        socklen_t(MemoryLayout<Int32>.size)
    )
    if result != 0 {
        throw UdpPcmRouteProbeError.setSocketOptionFailed(errno)
    }
}

func bindLoopback(_ socket: Int32, port: in_port_t) throws {
    try bindSocket(socket, address: try ipv4Address("127.0.0.1"), port: port)
}

func bindAnyIPv4(_ socket: Int32, port: in_port_t) throws {
    try bindIPv4(socket, host: "0.0.0.0", port: port)
}

func bindIPv4(_ socket: Int32, host: String, port: in_port_t) throws {
    let address = host == "0.0.0.0"
        ? in_addr(s_addr: INADDR_ANY)
        : try ipv4Address(host)
    try bindSocket(socket, address: address, port: port)
}

private func bindSocket(_ socket: Int32, address socketAddress: in_addr, port: in_port_t) throws {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port
    address.sin_addr = socketAddress

    let (result, savedErrno) = bindUdpSocket(socket, address: address)
    if result != 0 {
        throw UdpPcmRouteProbeError.bindFailed(savedErrno)
    }
}

func boundPort(_ socket: Int32) throws -> in_port_t {
    let (address, (result, savedErrno)) = boundUdpSocketAddress(socket)
    if result != 0 {
        throw UdpPcmRouteProbeError.getsocknameFailed(savedErrno)
    }
    return address.sin_port
}

func boundHostPort(_ socket: Int32) throws -> UInt16 {
    UInt16(bigEndian: try boundPort(socket))
}

func connectUdpSocket(_ socket: Int32, host: String, port: in_port_t) throws {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port

    let result = host.withCString { pointer in
        inet_pton(AF_INET, pointer, &address.sin_addr)
    }
    guard result == 1 else {
        throw UdpPcmRouteProbeError.invalidHost(host)
    }

    let connected = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            connect(
                socket,
                socketAddress,
                socklen_t(MemoryLayout<sockaddr_in>.size)
            )
        }
    }
    if connected != 0 {
        throw UdpPcmRouteProbeError.connectFailed(errno)
    }
}

func trySendConnectedDatagram(
    _ data: Data,
    socket: Int32,
    nonBlocking: Bool = false
) throws -> UdpDatagramSendResult {
    let (sent, savedErrno) = data.withUnsafeBytes { bytes in
        let result = send(socket, bytes.baseAddress, data.count, nonBlocking ? MSG_DONTWAIT : 0)
        return (result, errno)
    }
    return try udpDatagramSendResult(
        sentByteCount: sent,
        expectedByteCount: data.count,
        savedErrno: savedErrno,
        nonBlocking: nonBlocking
    )
}

func sendConnectedDatagram(_ data: Data, socket: Int32, nonBlocking: Bool = false) throws {
    guard try trySendConnectedDatagram(data, socket: socket, nonBlocking: nonBlocking) == .sent else {
        throw UdpPcmRouteProbeError.sendFailed(EWOULDBLOCK)
    }
}

func trySendDatagram(
    _ data: Data,
    socket: Int32,
    host: String,
    port: in_port_t,
    nonBlocking: Bool = false
) throws -> UdpDatagramSendResult {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port

    address.sin_addr = try ipv4Address(host)

    let (sent, savedErrno) = sendUdpDatagram(
        data,
        socket: socket,
        destination: address,
        flags: nonBlocking ? MSG_DONTWAIT : 0
    )
    return try udpDatagramSendResult(
        sentByteCount: sent,
        expectedByteCount: data.count,
        savedErrno: savedErrno,
        nonBlocking: nonBlocking
    )
}

func sendDatagram(
    _ data: Data,
    socket: Int32,
    host: String,
    port: in_port_t,
    nonBlocking: Bool = false
) throws {
    guard try trySendDatagram(
        data,
        socket: socket,
        host: host,
        port: port,
        nonBlocking: nonBlocking
    ) == .sent else {
        throw UdpPcmRouteProbeError.sendFailed(EWOULDBLOCK)
    }
}

func udpDatagramSendResult(
    sentByteCount: Int,
    expectedByteCount: Int,
    savedErrno: Int32,
    nonBlocking: Bool
) throws -> UdpDatagramSendResult {
    if sentByteCount < 0 {
        if nonBlocking, savedErrno == EAGAIN || savedErrno == EWOULDBLOCK {
            return .wouldBlock
        }
        throw UdpPcmRouteProbeError.sendFailed(savedErrno)
    }
    guard sentByteCount == expectedByteCount else {
        throw UdpPcmRouteProbeError.shortSend(expected: expectedByteCount, actual: sentByteCount)
    }
    return .sent
}

func receiveDatagram(socket: Int32, byteCount: Int) throws -> Data {
    try validateUdpReceiveByteCount(byteCount)
    var buffer = [UInt8](repeating: 0, count: byteCount)
    let received = buffer.withUnsafeMutableBytes { bytes in
        recv(socket, bytes.baseAddress, byteCount, 0)
    }
    let savedErrno = errno
    guard received >= 0 else {
        throw UdpPcmRouteProbeError.receiveFailed(savedErrno)
    }
    guard received > 0 else {
        throw UdpPcmRouteProbeError.receiveFailed(EINVAL)
    }
    return Data(buffer.prefix(received))
}

private func ipv4Address(_ host: String) throws -> in_addr {
    var address = in_addr()
    let result = host.withCString { pointer in
        inet_pton(AF_INET, pointer, &address)
    }
    guard result == 1 else {
        throw UdpPcmRouteProbeError.invalidHost(host)
    }
    return address
}

func receiveDatagramIfAvailable(socket: Int32, byteCount: Int) throws -> Data? {
    var buffer = [UInt8]()
    return try receiveDatagramIfAvailable(socket: socket, byteCount: byteCount, buffer: &buffer)
}

func receiveDatagramIfAvailable(socket: Int32, byteCount: Int, buffer: inout [UInt8]) throws -> Data? {
    try validateUdpReceiveByteCount(byteCount)
    if buffer.count < byteCount {
        buffer = [UInt8](repeating: 0, count: byteCount)
    }
    let received = buffer.withUnsafeMutableBytes { bytes in
        recv(socket, bytes.baseAddress, byteCount, MSG_DONTWAIT)
    }
    let savedErrno = errno
    if received < 0 {
        if savedErrno == EAGAIN || savedErrno == EWOULDBLOCK {
            return nil
        }
        throw UdpPcmRouteProbeError.receiveFailed(savedErrno)
    }
    guard received > 0 else {
        throw UdpPcmRouteProbeError.receiveFailed(EINVAL)
    }
    return Data(buffer.prefix(received))
}

struct UdpDatagramWithSource: Sendable {
    var data: Data
    var host: String
    var port: UInt16
}

func receiveDatagramWithSourceIfAvailable(socket: Int32, byteCount: Int) throws -> UdpDatagramWithSource? {
    var buffer = [UInt8]()
    return try receiveDatagramWithSourceIfAvailable(socket: socket, byteCount: byteCount, buffer: &buffer)
}

func receiveDatagramWithSourceIfAvailable(
    socket: Int32,
    byteCount: Int,
    buffer: inout [UInt8]
) throws -> UdpDatagramWithSource? {
    try validateUdpReceiveByteCount(byteCount)
    if buffer.count < byteCount {
        buffer = [UInt8](repeating: 0, count: byteCount)
    }
    var address = sockaddr_in()
    var addressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let (received, savedErrno) = receiveUdpDatagramFrom(
        UdpDatagramReceiveRequest(socket: socket, byteCount: byteCount, flags: MSG_DONTWAIT),
        buffer: &buffer,
        address: &address,
        addressLength: &addressLength
    )
    if received < 0 {
        if savedErrno == EAGAIN || savedErrno == EWOULDBLOCK {
            return nil
        }
        throw UdpPcmRouteProbeError.receiveFailed(savedErrno)
    }
    guard received > 0,
          addressLength == socklen_t(MemoryLayout<sockaddr_in>.size) else {
        throw UdpPcmRouteProbeError.receiveFailed(EINVAL)
    }
    return UdpDatagramWithSource(
        data: Data(buffer.prefix(received)),
        host: try ipv4Host(address.sin_addr),
        port: UInt16(bigEndian: address.sin_port)
    )
}

private func validateUdpReceiveByteCount(_ byteCount: Int) throws {
    guard (1...maxUdpDatagramPayloadByteCount).contains(byteCount) else {
        throw UdpPcmRouteProbeError.receiveFailed(EINVAL)
    }
}

private func ipv4Host(_ address: in_addr) throws -> String {
    var address = address
    var storage = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
    guard inet_ntop(AF_INET, &address, &storage, socklen_t(INET_ADDRSTRLEN)) != nil else {
        throw UdpPcmRouteProbeError.receiveFailed(errno)
    }
    let length = storage.firstIndex(of: 0) ?? storage.count
    let hostBytes = storage[..<length].map { UInt8(bitPattern: $0) }
    guard let host = String(bytes: hostBytes, encoding: .utf8) else {
        throw UdpPcmRouteProbeError.receiveFailed(EINVAL)
    }
    return host
}

func bindUdpSocket(_ socket: Int32, address: sockaddr_in) -> (result: Int32, savedErrno: Int32) {
    var address = address
    let (result, savedErrno) = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            let result = bind(socket, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
            return (result, errno)
        }
    }
    return (result, savedErrno)
}

func boundUdpSocketAddress(
    _ socket: Int32
) -> (address: sockaddr_in, status: (result: Int32, savedErrno: Int32)) {
    var address = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let (result, savedErrno) = withUnsafeMutablePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            let result = getsockname(socket, socketAddress, &length)
            return (result, errno)
        }
    }
    return (address, (result, savedErrno))
}

func sendUdpDatagram(
    _ data: Data,
    socket: Int32,
    destination: sockaddr_in,
    flags: Int32 = 0
) -> (sent: Int, savedErrno: Int32) {
    var destination = destination
    let (result, savedErrno) = data.withUnsafeBytes { bytes in
        withUnsafePointer(to: &destination) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                let result = sendto(
                    socket,
                    bytes.baseAddress,
                    data.count,
                    flags,
                    socketAddress,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
                return (result, errno)
            }
        }
    }
    return (result, savedErrno)
}

struct UdpDatagramReceiveRequest {
    let socket: Int32
    let byteCount: Int
    let flags: Int32
}

func receiveUdpDatagramFrom(
    _ request: UdpDatagramReceiveRequest,
    buffer: inout [UInt8],
    address: inout sockaddr_in,
    addressLength: inout socklen_t
) -> (received: Int, savedErrno: Int32) {
    let (result, savedErrno) = buffer.withUnsafeMutableBytes { bytes in
        withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                let result = recvfrom(
                    request.socket,
                    bytes.baseAddress,
                    request.byteCount,
                    request.flags,
                    socketAddress,
                    &addressLength
                )
                return (result, errno)
            }
        }
    }
    return (result, savedErrno)
}
