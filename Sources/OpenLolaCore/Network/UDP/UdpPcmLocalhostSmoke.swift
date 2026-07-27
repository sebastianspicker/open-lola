// Sends and receives a bounded PCM packet sequence on localhost to verify socket and codec integration without external-route claims.
import Darwin
import Foundation

/// Enumerates failures that callers must handle when working with UDP media transport.
public enum UdpPcmLocalhostSmokeError: Error, Equatable, Sendable {
    case socketFailed
    case invalidLoopbackAddress
    case bindFailed(Int32)
    case getsocknameFailed(Int32)
    case sendFailed(Int32)
    case receiveFailed(Int32)
    case shortSend(expected: Int, actual: Int)
}

/// Provides deterministic UdpPcmLocalhostSmoke coverage without requiring external UDP media transport infrastructure.
public enum UdpPcmLocalhostSmoke {
    public static func run() throws -> UdpPcmPacket {
        let packet = UdpPcmPacket(
            header: UdpPcmPacketHeader(
                transport: .init(
                    sequenceNumber: 1,
                    senderFrameIndex: 0,
                    senderHostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
                ),
                format: .init(
                    sampleRateHertz: 48_000,
                    framesPerPacket: 2,
                    channelCount: 2,
                    sampleFormat: .int16LittleEndian
                )
            ),
            payload: Data([0, 0, 1, 0, 255, 255, 0, 128])
        )
        let encoded = try packet.encoded()
        let receiver = try makeSocket()
        defer { close(receiver) }
        let sender = try makeSocket()
        defer { close(sender) }

        try bindLoopback(receiver)
        let port = try boundPort(receiver)
        try send(encoded, socket: sender, port: port)
        let received = try receive(socket: receiver, byteCount: encoded.count)
        return try UdpPcmPacket.decode(received)
    }

    private static func makeSocket() throws -> Int32 {
        try makeUdpSocket(receiveTimeoutSeconds: 1)
    }

    private static func bindLoopback(_ socket: Int32) throws {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        address.sin_addr = try loopbackAddress()

        let (result, savedErrno) = bindUdpSocket(socket, address: address)
        if result != 0 {
            throw UdpPcmLocalhostSmokeError.bindFailed(savedErrno)
        }
    }

    private static func boundPort(_ socket: Int32) throws -> in_port_t {
        let (address, (result, savedErrno)) = boundUdpSocketAddress(socket)
        if result != 0 {
            throw UdpPcmLocalhostSmokeError.getsocknameFailed(savedErrno)
        }
        return address.sin_port
    }

    private static func send(_ data: Data, socket: Int32, port: in_port_t) throws {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port
        address.sin_addr = try loopbackAddress()

        let (sent, savedErrno) = sendUdpDatagram(data, socket: socket, destination: address)
        if sent < 0 {
            throw UdpPcmLocalhostSmokeError.sendFailed(savedErrno)
        }
        if sent != data.count {
            throw UdpPcmLocalhostSmokeError.shortSend(expected: data.count, actual: sent)
        }
    }

    private static func receive(socket: Int32, byteCount: Int) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: byteCount)
        let received = buffer.withUnsafeMutableBytes { bytes in
            recv(socket, bytes.baseAddress, byteCount, 0)
        }
        guard received >= 0 else {
            throw UdpPcmLocalhostSmokeError.receiveFailed(errno)
        }
        return Data(buffer.prefix(received))
    }

    private static func loopbackAddress() throws -> in_addr {
        var address = in_addr()
        let result = "127.0.0.1".withCString { pointer in
            inet_pton(AF_INET, pointer, &address)
        }
        guard result == 1 else {
            throw UdpPcmLocalhostSmokeError.invalidLoopbackAddress
        }
        return address
    }
}
