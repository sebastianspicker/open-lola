// Shared LoLa qUIck connect fallback UDP helpers keep multi-file test scenarios deterministic.
import Darwin
import Foundation
import Testing

@testable import OpenLolaCore

func freeLoLaFallbackUdpPort() throws -> UInt16 {
    try freeLoLaTestPort(.udp)
}

func secondaryLoopbackAliasAvailable() -> Bool {
    (try? freeLoLaTestPort(.udp, host: "127.0.0.2")) != nil
}

// swiftlint:disable:next type_name
enum LoLaFallbackLoopbackAliasRequirementError: Error, Equatable {
    case unavailable(String)
}

func requireSecondaryLoopbackAliasAvailable(
    _ isAvailable: () -> Bool = secondaryLoopbackAliasAvailable,
    host: String = "127.0.0.2"
) throws {
    guard isAvailable() else {
        throw LoLaFallbackLoopbackAliasRequirementError.unavailable(host)
    }
}

func bindLoLaFallbackUdpSocket(_ socket: Int32, host: String, port: UInt16) throws {
    try bindLoLaTestSocket(socket, host: host, port: port)
}

func makeLoLaFallbackUdpSocket(
    host: String,
    port: UInt16,
    timeoutSeconds: Int,
    timeoutMicroseconds: Int32 = 0
) throws -> Int32 {
    let descriptor = try openLoLaTestSocket(.udp)
    do {
        try bindLoLaFallbackUdpSocket(descriptor, host: host, port: port)
        try setLoLaFallbackUdpTimeout(
            descriptor,
            seconds: timeoutSeconds,
            microseconds: timeoutMicroseconds
        )
        return descriptor
    } catch {
        Darwin.close(descriptor)
        throw error
    }
}

func withLoLaFallbackUdpSocket<Result>(
    host: String,
    port: UInt16,
    timeoutSeconds: Int,
    timeoutMicroseconds: Int32 = 0,
    operation: (Int32) throws -> Result
) throws -> Result {
    let descriptor = try makeLoLaFallbackUdpSocket(
        host: host,
        port: port,
        timeoutSeconds: timeoutSeconds,
        timeoutMicroseconds: timeoutMicroseconds
    )
    defer { Darwin.close(descriptor) }
    return try operation(descriptor)
}

struct LoLaFallbackUdpMessage {
    var message: String
    var senderHost: String
    var senderPort: UInt16
    var byteCount: Int
}

func receiveLoLaFallbackUdpMessage(socket: Int32) throws -> LoLaFallbackUdpMessage {
    let datagram = try receiveLoLaTestUdpDatagram(socket: socket)
    return LoLaFallbackUdpMessage(
        message: String(data: Data(datagram.bytes), encoding: .utf8) ?? "",
        senderHost: datagram.senderHost,
        senderPort: datagram.senderPort,
        byteCount: datagram.bytes.count
    )
}

func sendLoLaFallbackUdpMessage(_ message: String, socket: Int32, host: String, port: UInt16) throws {
    try sendLoLaFallbackUdpBytes([UInt8](message.utf8), socket: socket, host: host, port: port)
}

func sendLoLaFallbackUdpMessageUntilReply(
    _ message: String,
    socket: Int32,
    host: String,
    port: UInt16,
    deadline: DispatchTime = .now() + .seconds(3)
) throws -> LoLaFallbackUdpMessage {
    var lastTransientError: Error?
    while DispatchTime.now() < deadline {
        try sendLoLaFallbackUdpMessage(message, socket: socket, host: host, port: port)
        do {
            return try receiveLoLaFallbackUdpMessage(socket: socket)
        } catch {
            guard isTransientLoLaFallbackUdpReceiveError(error) else {
                throw error
            }
            lastTransientError = error
        }
    }
    if let lastTransientError {
        throw lastTransientError
    }
    throw NSError(domain: NSPOSIXErrorDomain, code: Int(ETIMEDOUT))
}

func sendLoLaFallbackUdpBytes(_ bytes: [UInt8], socket: Int32, host: String, port: UInt16) throws {
    try sendLoLaTestUdpBytes(
        bytes,
        socket: socket,
        host: host,
        port: port,
        retry: retryLoLaFallbackUdpSend
    )
}

func retryLoLaFallbackUdpSend(_ send: () -> Int) -> Int {
    var lastErrno: Int32 = 0
    var attempt = 0
    repeat {
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
        attempt += 1
    } while attempt < 6
    errno = lastErrno
    return -1
}
func setLoLaFallbackUdpTimeout(_ socket: Int32, seconds: Int, microseconds: Int32 = 0) throws {
    try setLoLaTestSocketReceiveTimeout(socket, seconds: seconds, microseconds: microseconds)
}

func isTransientLoLaFallbackUdpReceiveError(_ error: Error) -> Bool {
    let nsError = error as NSError
    guard nsError.domain == NSPOSIXErrorDomain else {
        return false
    }
    return nsError.code == Int(EAGAIN)
        || nsError.code == Int(EWOULDBLOCK)
        || nsError.code == Int(ETIMEDOUT)
}

func waitForLoLaFallbackUdpPeerReady(_ ready: DispatchSemaphore) throws {
    guard ready.wait(timeout: .now() + 3) == .success else {
        Issue.record("LoLa fallback UDP peer did not bind before the control attempt started")
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(ETIMEDOUT))
    }
}

func loLaFallbackHostString(_ address: in_addr) throws -> String {
    try loLaTestHostString(address)
}
