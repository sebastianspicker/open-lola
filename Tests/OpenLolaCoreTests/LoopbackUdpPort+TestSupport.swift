// Shared Loopback UDP port helpers keep multi-file test scenarios deterministic.
import Darwin
import Foundation

@testable import OpenLolaCore

enum LoLaTestSocketTransport {
    case udp
    case tcp

    var socketType: Int32 {
        switch self {
        case .udp:
            SOCK_DGRAM
        case .tcp:
            SOCK_STREAM
        }
    }

    var protocolNumber: Int32 {
        switch self {
        case .udp:
            IPPROTO_UDP
        case .tcp:
            IPPROTO_TCP
        }
    }
}

struct LoLaTestUdpDatagram {
    let bytes: [UInt8]
    let senderHost: String
    let senderPort: UInt16
}

func withLoLaTestSocket<Result>(
    _ transport: LoLaTestSocketTransport,
    operation: (Int32) throws -> Result
) throws -> Result {
    let descriptor = try openLoLaTestSocket(transport)
    defer { Darwin.close(descriptor) }
    return try operation(descriptor)
}

func openLoLaTestSocket(_ transport: LoLaTestSocketTransport) throws -> Int32 {
    let descriptor = Darwin.socket(AF_INET, transport.socketType, transport.protocolNumber)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    return descriptor
}

func withLoLaTestTcpSocketPair<Result>(
    operation: (Int32, Int32) async throws -> Result
) async throws -> Result {
    var sockets: [Int32] = [0, 0]
    guard Darwin.socketpair(AF_UNIX, SOCK_STREAM, 0, &sockets) == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer {
        Darwin.close(sockets[0])
        Darwin.close(sockets[1])
    }
    return try await operation(sockets[0], sockets[1])
}

func bindLoLaTestSocket(
    _ socket: Int32,
    host: String,
    port: UInt16,
    reuseAddress: Bool = false
) throws {
    if reuseAddress {
        var reuse: Int32 = 1
        _ = setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
    }
    var address = try loLaTestIPv4Address(host: host, port: port)
    let result = withLoLaTestSocketAddress(&address) { socketAddress in
        Darwin.bind(socket, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
    guard result == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
}

private func withLoLaTestSocketAddress<Result>(
    _ address: inout sockaddr_in,
    operation: (UnsafePointer<sockaddr>) -> Result
) -> Result {
    withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1, operation)
    }
}

func loLaTestIPv4Address(host: String, port: UInt16) throws -> sockaddr_in {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout.size(ofValue: address))
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    return address
}

func freeLoLaTestPort(_ transport: LoLaTestSocketTransport, host: String = "127.0.0.1") throws -> UInt16 {
    try withLoLaTestSocket(transport) { descriptor in
        try bindLoLaTestSocket(descriptor, host: host, port: 0)
        return try boundLoLaTestSocketAddress(socket: descriptor).port
    }
}

func boundLoLaTestSocketAddress(socket: Int32) throws -> (host: String, port: UInt16) {
    var bound = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let result = withUnsafeMutablePointer(to: &bound) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.getsockname(socket, socketAddress, &length)
        }
    }
    guard result == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    return (
        host: try loLaTestHostString(bound.sin_addr),
        port: UInt16(bigEndian: bound.sin_port)
    )
}

func receiveLoLaTestUdpDatagram(socket: Int32) throws -> LoLaTestUdpDatagram {
    var buffer = [UInt8](repeating: 0, count: 4096)
    var sender = sockaddr_in()
    var senderLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let received = withUnsafeMutablePointer(to: &sender) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.recvfrom(socket, &buffer, buffer.count, 0, socketAddress, &senderLength)
        }
    }
    guard received > 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    return LoLaTestUdpDatagram(
        bytes: Array(buffer[0..<received]),
        senderHost: try loLaTestHostString(sender.sin_addr),
        senderPort: UInt16(bigEndian: sender.sin_port)
    )
}

func sendLoLaTestUdpBytes(
    _ bytes: [UInt8],
    socket: Int32,
    host: String,
    port: UInt16,
    retry: (_ send: () -> Int) -> Int = { send in send() }
) throws {
    var destination = try loLaTestIPv4Address(host: host, port: port)
    let sent = try bytes.withUnsafeBytes { rawBuffer in
        try withUnsafePointer(to: &destination) { pointer in
            try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                let result = retry {
                    Darwin.sendto(
                        socket,
                        rawBuffer.baseAddress,
                        rawBuffer.count,
                        0,
                        socketAddress,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
                guard result == rawBuffer.count else {
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
                }
                return result
            }
        }
    }
    _ = sent
}

func setLoLaTestSocketReceiveTimeout(
    _ socket: Int32,
    seconds: Int,
    microseconds: Int32 = 0
) throws {
    var timeout = timeval(tv_sec: seconds, tv_usec: microseconds)
    let status = setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    guard status == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
}

func loLaTestHostString(_ address: in_addr) throws -> String {
    var address = address
    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
    guard inet_ntop(AF_INET, &address, &buffer, socklen_t(buffer.count)) != nil else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    let endIndex = buffer.firstIndex(of: 0) ?? buffer.endIndex
    return String(bytes: buffer[..<endIndex].map(UInt8.init), encoding: .utf8) ?? ""
}

func loLaTestLossyUTF8String(_ bytes: [UInt8]) -> String {
    String(bytes: bytes, encoding: .utf8)
        ?? String(repeating: "\u{FFFD}", count: bytes.count)
}

func freeLoopbackUdpPort() throws -> UInt16 {
    try freeLoLaTestPort(.udp)
}

actor ExternalConnectorReadinessGate {
    private var isReady = false
    private var waiters: [UUID: CheckedContinuation<Bool, Never>] = [:]

    func signal() {
        isReady = true
        let continuations = waiters.values
        waiters.removeAll()
        for continuation in continuations {
            continuation.resume(returning: true)
        }
    }

    func wait(timeout: Duration) async -> Bool {
        if isReady {
            return true
        }
        let id = UUID()
        return await withCheckedContinuation { continuation in
            waiters[id] = continuation
            Task.detached {
                try? await ContinuousClock().sleep(for: timeout)
                await self.timeout(id)
            }
        }
    }

    private func timeout(_ id: UUID) {
        guard let continuation = waiters.removeValue(forKey: id) else {
            return
        }
        continuation.resume(returning: isReady)
    }
}

func runExternalConnectorSessionInBackground(
    _ configuration: ExternalConnectorSessionConfiguration,
    onLoLaControlReady: (@Sendable () -> Void)? = nil
) -> @Sendable () throws -> ExternalConnectorSessionReport {
    let semaphore = DispatchSemaphore(value: 0)
    let box = ExternalConnectorSessionResultBox()
    DispatchQueue.global(qos: .userInitiated).async {
        box.store(Result {
            try ExternalConnectorSessionRunner.run(
                configuration: configuration,
                processRunner: RealExternalConnectorProcessRunner(),
                loLaControlReady: onLoLaControlReady
            )
        })
        semaphore.signal()
    }
    return {
        semaphore.wait()
        return try box.load()
    }
}

private final class ExternalConnectorSessionResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<ExternalConnectorSessionReport, Error>?

    func store(_ result: Result<ExternalConnectorSessionReport, Error>) {
        lock.lock()
        self.result = result
        lock.unlock()
    }

    func load() throws -> ExternalConnectorSessionReport {
        lock.lock()
        let result = self.result
        lock.unlock()
        switch result {
        case let .success(report):
            return report
        case let .failure(error):
            throw error
        case nil:
            throw ExternalConnectorSessionError.emptyField("backgroundSessionResult")
        }
    }
}
