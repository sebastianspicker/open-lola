import Darwin
import Foundation

public enum UdpPcmSampleFormat: UInt8, Codable, Equatable, Sendable {
    case int16LittleEndian = 1
    case float32LittleEndian = 2

    public var bytesPerSample: Int {
        switch self {
        case .int16LittleEndian:
            2
        case .float32LittleEndian:
            4
        }
    }
}

public struct UdpPcmPacketHeader: Codable, Equatable, Sendable {
    public static let magic = [UInt8]("OLPC".utf8)
    public static let currentVersion: UInt8 = 1
    public static let byteCount = 48
    public static let headerGuard: UInt32 = 0x3143_504C

    public var version: UInt8
    public var sequenceNumber: UInt64
    public var senderFrameIndex: UInt64
    public var senderHostTimeNanoseconds: UInt64
    public var sampleRateHertz: UInt32
    public var framesPerPacket: UInt32
    public var channelCount: UInt16
    public var sampleFormat: UdpPcmSampleFormat
    public var payloadByteCount: UInt32

    public init(
        version: UInt8 = Self.currentVersion,
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        senderHostTimeNanoseconds: UInt64,
        sampleRateHertz: UInt32,
        framesPerPacket: UInt32,
        channelCount: UInt16,
        sampleFormat: UdpPcmSampleFormat,
        payloadByteCount: UInt32 = 0
    ) {
        self.version = version
        self.sequenceNumber = sequenceNumber
        self.senderFrameIndex = senderFrameIndex
        self.senderHostTimeNanoseconds = senderHostTimeNanoseconds
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.channelCount = channelCount
        self.sampleFormat = sampleFormat
        self.payloadByteCount = payloadByteCount
    }
}

public enum UdpPcmPacketError: Error, Equatable, Sendable {
    case truncatedPacket(byteCount: Int)
    case oversizedPacket(expected: Int, actual: Int)
    case invalidMagic
    case unsupportedVersion(UInt8)
    case unsupportedSampleFormat(UInt8)
    case invalidChannelCount(UInt16)
    case invalidFrameCount(UInt32)
    case invalidSampleRate(UInt32)
    case invalidTimestamp(UInt64)
    case payloadLengthMismatch(expected: Int, actual: Int)
    case payloadTooLarge(Int)
    case invalidHeaderGuard
}

public struct UdpPcmPacket: PacketCodec {
    public static let maxPayloadByteCount = 1_048_576

    public var header: UdpPcmPacketHeader
    public var payload: Data

    public init(header: UdpPcmPacketHeader, payload: Data) {
        var header = header
        header.payloadByteCount = UInt32(payload.count)
        self.header = header
        self.payload = payload
    }

    public static func silence(
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        senderHostTimeNanoseconds: UInt64,
        mode: UdpPcmPacketMode
    ) -> UdpPcmPacket {
        UdpPcmPacket(
            header: UdpPcmPacketHeader(
                sequenceNumber: sequenceNumber,
                senderFrameIndex: senderFrameIndex,
                senderHostTimeNanoseconds: senderHostTimeNanoseconds,
                sampleRateHertz: UInt32(mode.sampleRateHertz),
                framesPerPacket: UInt32(mode.framesPerPacket),
                channelCount: UInt16(mode.channelCount),
                sampleFormat: mode.sampleFormat
            ),
            payload: Data(repeating: 0, count: mode.payloadByteCount)
        )
    }

    public func matches(_ mode: UdpPcmPacketMode) -> Bool {
        header.sampleRateHertz == UInt32(mode.sampleRateHertz)
            && header.framesPerPacket == UInt32(mode.framesPerPacket)
            && header.channelCount == UInt16(mode.channelCount)
            && header.sampleFormat == mode.sampleFormat
            && payload.count == mode.payloadByteCount
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> UdpPcmPacket {
        let bytes = [UInt8](data)
        guard bytes.count >= UdpPcmPacketHeader.byteCount else {
            throw UdpPcmPacketError.truncatedPacket(byteCount: bytes.count)
        }

        guard Array(bytes[0..<4]) == UdpPcmPacketHeader.magic else {
            throw UdpPcmPacketError.invalidMagic
        }

        let version = bytes[4]
        guard version == UdpPcmPacketHeader.currentVersion else {
            throw UdpPcmPacketError.unsupportedVersion(version)
        }

        let formatValue = bytes[5]
        guard let sampleFormat = UdpPcmSampleFormat(rawValue: formatValue) else {
            throw UdpPcmPacketError.unsupportedSampleFormat(formatValue)
        }

        let channelCount = try readCheckedUdpPcmPacketUInt16LE(bytes, offset: 6)
        guard channelCount > 0 else {
            throw UdpPcmPacketError.invalidChannelCount(channelCount)
        }

        let framesPerPacket = try readCheckedUdpPcmPacketUInt32LE(bytes, offset: 8)
        guard framesPerPacket > 0 else {
            throw UdpPcmPacketError.invalidFrameCount(framesPerPacket)
        }

        let sampleRateHertz = try readCheckedUdpPcmPacketUInt32LE(bytes, offset: 12)
        guard sampleRateHertz > 0 else {
            throw UdpPcmPacketError.invalidSampleRate(sampleRateHertz)
        }

        let sequenceNumber = try readCheckedUdpPcmPacketUInt64LE(bytes, offset: 16)
        let senderFrameIndex = try readCheckedUdpPcmPacketUInt64LE(bytes, offset: 24)
        let senderHostTimeNanoseconds = try readCheckedUdpPcmPacketUInt64LE(bytes, offset: 32)
        guard senderHostTimeNanoseconds > 0 else {
            throw UdpPcmPacketError.invalidTimestamp(senderHostTimeNanoseconds)
        }
        let payloadByteCount = try readCheckedUdpPcmPacketUInt32LE(bytes, offset: 40)
        let headerGuard = try readCheckedUdpPcmPacketUInt32LE(bytes, offset: 44)

        guard headerGuard == UdpPcmPacketHeader.headerGuard else {
            throw UdpPcmPacketError.invalidHeaderGuard
        }

        let actualPayloadByteCount = bytes.count - UdpPcmPacketHeader.byteCount
        let declaredPayloadByteCount = Int(payloadByteCount)
        let declaredPacketByteCount = UdpPcmPacketHeader.byteCount + declaredPayloadByteCount
        if actualPayloadByteCount > declaredPayloadByteCount {
            throw UdpPcmPacketError.oversizedPacket(
                expected: declaredPacketByteCount,
                actual: bytes.count
            )
        }
        if actualPayloadByteCount != declaredPayloadByteCount {
            throw UdpPcmPacketError.payloadLengthMismatch(
                expected: declaredPayloadByteCount,
                actual: actualPayloadByteCount
            )
        }
        guard declaredPayloadByteCount <= maxPayloadByteCount else {
            throw UdpPcmPacketError.payloadTooLarge(declaredPayloadByteCount)
        }

        let expectedPayloadByteCount = Int(framesPerPacket)
            * Int(channelCount)
            * sampleFormat.bytesPerSample
        guard expectedPayloadByteCount == declaredPayloadByteCount else {
            throw UdpPcmPacketError.payloadLengthMismatch(
                expected: expectedPayloadByteCount,
                actual: declaredPayloadByteCount
            )
        }

        let header = UdpPcmPacketHeader(
            version: version,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: senderFrameIndex,
            senderHostTimeNanoseconds: senderHostTimeNanoseconds,
            sampleRateHertz: sampleRateHertz,
            framesPerPacket: framesPerPacket,
            channelCount: channelCount,
            sampleFormat: sampleFormat,
            payloadByteCount: payloadByteCount
        )
        return UdpPcmPacket(
            header: header,
            payload: Data(bytes[UdpPcmPacketHeader.byteCount...])
        )
    }

    public func encoded() throws -> Data {
        try validatePayload()

        var data = Data()
        data.reserveCapacity(UdpPcmPacketHeader.byteCount + payload.count)
        data.append(contentsOf: UdpPcmPacketHeader.magic)
        data.append(header.version)
        data.append(header.sampleFormat.rawValue)
        appendUdpPcmUInt16LE(header.channelCount, to: &data)
        appendUdpPcmUInt32LE(header.framesPerPacket, to: &data)
        appendUdpPcmUInt32LE(header.sampleRateHertz, to: &data)
        appendUdpPcmUInt64LE(header.sequenceNumber, to: &data)
        appendUdpPcmUInt64LE(header.senderFrameIndex, to: &data)
        appendUdpPcmUInt64LE(header.senderHostTimeNanoseconds, to: &data)
        appendUdpPcmUInt32LE(UInt32(payload.count), to: &data)
        appendUdpPcmUInt32LE(UdpPcmPacketHeader.headerGuard, to: &data)
        data.append(payload)
        return data
    }

    private func validatePayload() throws {
        guard header.version == UdpPcmPacketHeader.currentVersion else {
            throw UdpPcmPacketError.unsupportedVersion(header.version)
        }
        guard header.channelCount > 0 else {
            throw UdpPcmPacketError.invalidChannelCount(header.channelCount)
        }
        guard header.framesPerPacket > 0 else {
            throw UdpPcmPacketError.invalidFrameCount(header.framesPerPacket)
        }
        guard header.sampleRateHertz > 0 else {
            throw UdpPcmPacketError.invalidSampleRate(header.sampleRateHertz)
        }
        guard header.senderHostTimeNanoseconds > 0 else {
            throw UdpPcmPacketError.invalidTimestamp(header.senderHostTimeNanoseconds)
        }
        guard payload.count <= Self.maxPayloadByteCount else {
            throw UdpPcmPacketError.payloadTooLarge(payload.count)
        }

        let expectedPayloadByteCount = Int(header.framesPerPacket)
            * Int(header.channelCount)
            * header.sampleFormat.bytesPerSample
        if payload.count != expectedPayloadByteCount {
            throw UdpPcmPacketError.payloadLengthMismatch(
                expected: expectedPayloadByteCount,
                actual: payload.count
            )
        }
    }
}

public enum UdpPcmSequenceError: Error, Equatable, Sendable {
    case unexpectedSequence(expected: UInt64, actual: UInt64)
    case unexpectedFrameIndex(expected: UInt64, actual: UInt64)
}

/// Requires strictly consecutive sequence numbers and sender frame indexes.
/// This tracker is valid only on lossless paths such as loopback or CI; real
/// network use needs a gap-tolerant wrapper that can classify packet loss.
public struct UdpPcmSequenceTracker: Sendable {
    private var nextSequenceNumber: UInt64?
    private var nextFrameIndex: UInt64?

    public init() {}

    public mutating func accept(_ packet: UdpPcmPacket) throws {
        if let nextSequenceNumber, packet.header.sequenceNumber != nextSequenceNumber {
            throw UdpPcmSequenceError.unexpectedSequence(
                expected: nextSequenceNumber,
                actual: packet.header.sequenceNumber
            )
        }
        if let nextFrameIndex, packet.header.senderFrameIndex != nextFrameIndex {
            throw UdpPcmSequenceError.unexpectedFrameIndex(
                expected: nextFrameIndex,
                actual: packet.header.senderFrameIndex
            )
        }

        nextSequenceNumber = packet.header.sequenceNumber &+ 1
        nextFrameIndex = packet.header.senderFrameIndex &+ UInt64(packet.header.framesPerPacket)
    }
}

public enum UdpPcmHexFixtureError: Error, Equatable, Sendable {
    case nonASCII
    case oddDigitCount
    case invalidByte(String)
}

public enum UdpPcmHexFixture {
    public static func decode(_ data: Data) throws -> Data {
        guard let text = String(data: data, encoding: .ascii) else {
            throw UdpPcmHexFixtureError.nonASCII
        }

        let compact = text.filter { !$0.isWhitespace }
        guard compact.count.isMultiple(of: 2) else {
            throw UdpPcmHexFixtureError.oddDigitCount
        }

        var bytes = Data()
        var index = compact.startIndex
        while index < compact.endIndex {
            let nextIndex = compact.index(index, offsetBy: 2)
            let byteText = String(compact[index..<nextIndex])
            guard let byte = UInt8(byteText, radix: 16) else {
                throw UdpPcmHexFixtureError.invalidByte(byteText)
            }
            bytes.append(byte)
            index = nextIndex
        }
        return bytes
    }
}

public enum UdpPcmLocalhostSmokeError: Error, Equatable, Sendable {
    case socketFailed
    case invalidLoopbackAddress
    case bindFailed(Int32)
    case getsocknameFailed(Int32)
    case sendFailed(Int32)
    case receiveFailed(Int32)
    case shortSend(expected: Int, actual: Int)
}

public enum UdpPcmLocalhostSmoke {
    public static func run() throws -> UdpPcmPacket {
        let packet = UdpPcmPacket(
            header: UdpPcmPacketHeader(
                sequenceNumber: 1,
                senderFrameIndex: 0,
                senderHostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds,
                sampleRateHertz: 48_000,
                framesPerPacket: 2,
                channelCount: 2,
                sampleFormat: .int16LittleEndian
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

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                bind(
                    socket,
                    socketAddress,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        if result != 0 {
            throw UdpPcmLocalhostSmokeError.bindFailed(errno)
        }
    }

    private static func boundPort(_ socket: Int32) throws -> in_port_t {
        var address = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let result = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                getsockname(socket, socketAddress, &length)
            }
        }
        if result != 0 {
            throw UdpPcmLocalhostSmokeError.getsocknameFailed(errno)
        }
        return address.sin_port
    }

    private static func send(_ data: Data, socket: Int32, port: in_port_t) throws {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port
        address.sin_addr = try loopbackAddress()

        let (sent, savedErrno) = data.withUnsafeBytes { bytes in
            withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                    let result = sendto(
                        socket,
                        bytes.baseAddress,
                        data.count,
                        0,
                        socketAddress,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                    return (result, errno)
                }
            }
        }
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
