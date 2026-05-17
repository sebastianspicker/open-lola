import Darwin
import Dispatch
import Foundation

public struct UdpMediaPacketHeader: Codable, Equatable, Sendable {
    public static let magic = [UInt8]("OLMP".utf8)
    public static let currentVersion: UInt8 = 1
    public static let byteCount = 36
    public static let headerGuard: UInt32 = 0x3150_4D4F

    public var version: UInt8
    public var payloadType: SessionPayloadType
    public var streamID: UInt32
    public var sequenceNumber: UInt64
    public var timestampNanoseconds: UInt64
    public var payloadByteCount: UInt32

    public init(
        version: UInt8 = Self.currentVersion,
        payloadType: SessionPayloadType,
        streamID: UInt32,
        sequenceNumber: UInt64,
        timestampNanoseconds: UInt64,
        payloadByteCount: UInt32 = 0
    ) {
        self.version = version
        self.payloadType = payloadType
        self.streamID = streamID
        self.sequenceNumber = sequenceNumber
        self.timestampNanoseconds = timestampNanoseconds
        self.payloadByteCount = payloadByteCount
    }
}

public enum UdpMediaPacketError: Error, Equatable, Sendable {
    case truncatedPacket(byteCount: Int)
    case invalidMagic
    case unsupportedVersion(UInt8)
    case unsupportedPayloadType(UInt8)
    case invalidStreamID(UInt32)
    case invalidTimestamp(UInt64)
    case payloadLengthMismatch(expected: Int, actual: Int)
    case payloadTooLarge(Int)
    case invalidHeaderGuard
    case audioStreamMismatch(expected: UInt32, actual: UInt32)
    case audioSequenceMismatch(expected: UInt64, actual: UInt64)
    case audioTimestampMismatch(expected: UInt64, actual: UInt64)
    case videoStreamMismatch(expected: UInt32, actual: UInt32)
    case videoSequenceMismatch(expected: UInt64, actual: UInt64)
    case videoTimestampMismatch(expected: UInt64, actual: UInt64)
}

public struct UdpMediaMalformedDatagramError: Error, Equatable, Sendable {
    public var reason: String

    public init(reason: String) {
        self.reason = reason
    }
}

public struct UdpMediaPacket: PacketCodec {
    public static let maxPayloadByteCount = UdpPcmPacket.maxPayloadByteCount

    public var header: UdpMediaPacketHeader
    public var payload: Data

    public init(header: UdpMediaPacketHeader, payload: Data) {
        var header = header
        header.payloadByteCount = UInt32(payload.count)
        self.header = header
        self.payload = payload
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> UdpMediaPacket {
        try decodeWithNestedPayload(data).packet
    }

    public static func decodeWithNestedPayload<Bytes: DataProtocol>(_ data: Bytes) throws -> UdpMediaDecodedPacket {
        let bytes = [UInt8](data)
        guard bytes.count >= UdpMediaPacketHeader.byteCount else {
            throw UdpMediaPacketError.truncatedPacket(byteCount: bytes.count)
        }
        guard Array(bytes[0..<4]) == UdpMediaPacketHeader.magic else {
            throw UdpMediaPacketError.invalidMagic
        }
        let version = bytes[4]
        guard version == UdpMediaPacketHeader.currentVersion else {
            throw UdpMediaPacketError.unsupportedVersion(version)
        }
        let payloadTypeValue = bytes[5]
        guard let payloadType = SessionPayloadType(rawValue: Int(payloadTypeValue)) else {
            throw UdpMediaPacketError.unsupportedPayloadType(payloadTypeValue)
        }
        let streamID = try readUdpMediaUInt32LE(bytes, offset: 8)
        guard streamID > 0 else {
            throw UdpMediaPacketError.invalidStreamID(streamID)
        }
        let sequenceNumber = try readUdpMediaUInt64LE(bytes, offset: 12)
        let timestampNanoseconds = try readUdpMediaUInt64LE(bytes, offset: 20)
        guard timestampNanoseconds > 0 else {
            throw UdpMediaPacketError.invalidTimestamp(timestampNanoseconds)
        }
        let payloadByteCount = try readUdpMediaUInt32LE(bytes, offset: 28)
        let headerGuard = try readUdpMediaUInt32LE(bytes, offset: 32)
        guard headerGuard == UdpMediaPacketHeader.headerGuard else {
            throw UdpMediaPacketError.invalidHeaderGuard
        }

        let actualPayloadByteCount = bytes.count - UdpMediaPacketHeader.byteCount
        let declaredPayloadByteCount = Int(payloadByteCount)
        guard actualPayloadByteCount == declaredPayloadByteCount else {
            throw UdpMediaPacketError.payloadLengthMismatch(
                expected: declaredPayloadByteCount,
                actual: actualPayloadByteCount
            )
        }
        guard declaredPayloadByteCount <= maxPayloadByteCount else {
            throw UdpMediaPacketError.payloadTooLarge(declaredPayloadByteCount)
        }

        let packet = UdpMediaPacket(
            header: UdpMediaPacketHeader(
                version: version,
                payloadType: payloadType,
                streamID: streamID,
                sequenceNumber: sequenceNumber,
                timestampNanoseconds: timestampNanoseconds,
                payloadByteCount: payloadByteCount
            ),
            payload: Data(bytes[UdpMediaPacketHeader.byteCount..<bytes.count])
        )
        let decodedPayload = try packet.decodedNestedPayload()
        return UdpMediaDecodedPacket(packet: packet, decodedPayload: decodedPayload)
    }

    public func encoded() throws -> Data {
        try validate()

        var data = Data()
        data.reserveCapacity(UdpMediaPacketHeader.byteCount + payload.count)
        data.append(contentsOf: UdpMediaPacketHeader.magic)
        data.append(header.version)
        data.append(UInt8(header.payloadType.rawValue))
        appendUdpMediaUInt16LE(0, to: &data)
        appendUdpMediaUInt32LE(header.streamID, to: &data)
        appendUdpMediaUInt64LE(header.sequenceNumber, to: &data)
        appendUdpMediaUInt64LE(header.timestampNanoseconds, to: &data)
        appendUdpMediaUInt32LE(UInt32(payload.count), to: &data)
        appendUdpMediaUInt32LE(UdpMediaPacketHeader.headerGuard, to: &data)
        data.append(payload)
        return data
    }

    private func validate() throws {
        guard header.version == UdpMediaPacketHeader.currentVersion else {
            throw UdpMediaPacketError.unsupportedVersion(header.version)
        }
        guard header.streamID > 0 else {
            throw UdpMediaPacketError.invalidStreamID(header.streamID)
        }
        guard header.timestampNanoseconds > 0 else {
            throw UdpMediaPacketError.invalidTimestamp(header.timestampNanoseconds)
        }
        guard payload.count <= Self.maxPayloadByteCount else {
            throw UdpMediaPacketError.payloadTooLarge(payload.count)
        }
        _ = try decodedNestedPayload()
    }

    private func decodedNestedPayload() throws -> UdpMediaDecodedPayload {
        switch header.payloadType {
        case .audioRtpL24:
            let rtp = try RTPPacket.decode(payload)
            try validateNestedPayloadByteCount(try rtp.encoded().count)
            return .audioRtpL24(rtp)
        case .audioPcmV2, .audioOpusCeltLowDelayFrame:
            let nestedStreamID: UInt32
            let nestedSequenceNumber: UInt64
            let nestedTimestampNanoseconds: UInt64
            let decodedPayload: UdpMediaDecodedPayload
            if header.payloadType == .audioPcmV2 {
                let audio = try UdpPcmV2Packet.decode(payload)
                try validateNestedPayloadByteCount(try audio.encoded().count)
                nestedStreamID = audio.header.streamID
                nestedSequenceNumber = audio.header.sequenceNumber
                nestedTimestampNanoseconds = audio.header.senderHostTimeNanoseconds
                decodedPayload = .audioPcmV2(audio)
            } else {
                let opus = try AudioOpusCeltLowDelayPacket.decode(payload)
                try validateNestedPayloadByteCount(try opus.encoded().count)
                nestedStreamID = opus.header.streamID
                nestedSequenceNumber = opus.header.sequenceNumber
                nestedTimestampNanoseconds = opus.header.senderHostTimeNanoseconds
                decodedPayload = .audioOpusCeltLowDelayFrame(opus)
            }
            guard nestedStreamID == header.streamID else {
                throw UdpMediaPacketError.audioStreamMismatch(
                    expected: header.streamID,
                    actual: nestedStreamID
                )
            }
            guard nestedSequenceNumber == header.sequenceNumber else {
                throw UdpMediaPacketError.audioSequenceMismatch(
                    expected: header.sequenceNumber,
                    actual: nestedSequenceNumber
                )
            }
            guard nestedTimestampNanoseconds == header.timestampNanoseconds else {
                throw UdpMediaPacketError.audioTimestampMismatch(
                    expected: header.timestampNanoseconds,
                    actual: nestedTimestampNanoseconds
                )
            }
            return decodedPayload
        case .videoRawFrameFragment, .videoVideoToolboxFragment, .videoJpegXSFrameFragment:
            let video = try VideoTransportFragment.decode(payload)
            try validateNestedPayloadByteCount(try video.encoded().count)
            guard video.streamID == header.streamID else {
                throw UdpMediaPacketError.videoStreamMismatch(
                    expected: header.streamID,
                    actual: video.streamID
                )
            }
            guard video.frameSequenceNumber == header.sequenceNumber else {
                throw UdpMediaPacketError.videoSequenceMismatch(
                    expected: header.sequenceNumber,
                    actual: video.frameSequenceNumber
                )
            }
            guard video.timestampNanoseconds == header.timestampNanoseconds else {
                throw UdpMediaPacketError.videoTimestampMismatch(
                    expected: header.timestampNanoseconds,
                    actual: video.timestampNanoseconds
                )
            }
            return .videoFragment(video)
        case .metrics:
            return .metrics(try JSONDecoder().decode(SessionMetricsMessage.self, from: payload))
        case .audioTiming:
            let timing = try JSONDecoder().decode(MediaTimingPacket.self, from: payload)
            try timing.validate()
            return .audioTiming(timing)
        case .keepalive:
            return .keepalive
        }
    }

    private func validateNestedPayloadByteCount(_ nestedByteCount: Int) throws {
        guard nestedByteCount == payload.count else {
            throw UdpMediaPacketError.payloadLengthMismatch(
                expected: nestedByteCount,
                actual: payload.count
            )
        }
    }
}

public enum UdpMediaDecodedPayload: Equatable, Sendable {
    case audioRtpL24(RTPPacket)
    case audioPcmV2(UdpPcmV2Packet)
    case audioOpusCeltLowDelayFrame(AudioOpusCeltLowDelayPacket)
    case videoFragment(VideoTransportFragment)
    case metrics(SessionMetricsMessage)
    case audioTiming(MediaTimingPacket)
    case keepalive
}

public struct UdpMediaDecodedPacket: Equatable, Sendable {
    public var packet: UdpMediaPacket
    public var decodedPayload: UdpMediaDecodedPayload

    public init(packet: UdpMediaPacket, decodedPayload: UdpMediaDecodedPayload) {
        self.packet = packet
        self.decodedPayload = decodedPayload
    }
}

public struct UdpMediaMetrics: Codable, Equatable, Sendable {
    public var packetsSent: Int = 0
    public var packetsReceived: Int = 0
    public var packetsLost: Int = 0
    public var latePackets: Int = 0
    public var reorderedPackets: Int = 0
    public var duplicatePackets: Int = 0
    public var malformedPackets: Int = 0
    public var jitterMicroseconds: Double = 0
    public var clockSkewEventCount: Int = 0
    public var callbackDurationP99Microseconds: Double = 0
    public var queueDepthPackets: Int = 0
    public var cpuPercent: Double = 0
    public var memoryResidentBytes: UInt64 = 0
    public var packetizationDuration: PerformanceCounterSummary = .empty
    public var depacketizationDuration: PerformanceCounterSummary = .empty

    public init() {}

    public func controlMessage(sessionID: String) -> SessionControlMessage {
        SessionControlMessage.metrics(SessionMetricsMessage(
            sessionID: sessionID,
            packetsLost: packetsLost,
            jitterMicroseconds: jitterMicroseconds,
            latePackets: latePackets,
            callbackDurationP99Microseconds: callbackDurationP99Microseconds,
            queueDepthPackets: queueDepthPackets,
            cpuPercent: cpuPercent,
            memoryResidentBytes: memoryResidentBytes,
            underruns: 0,
            overruns: 0,
            videoFramesDropped: 0
        ))
    }
}

public final class UdpMediaTransport: @unchecked Sendable {
    public let localEndpoint: SessionNetworkEndpoint
    public let requestedDscp: Int?
    public var metrics: UdpMediaMetrics {
        stateLock.lock()
        defer { stateLock.unlock() }
        return metricsState
    }

    private let descriptor: Int32
    private let stateLock = NSLock()
    private var metricsState = UdpMediaMetrics()
    private var nextSequenceByStream: [UdpMediaSequenceKey: UInt64] = [:]
    private var recentSequencesByStream: [UdpMediaSequenceKey: UdpMediaRecentSequences] = [:]
    private var jitterState = UdpMediaJitterState()
    private var isClosed = false

    private init(descriptor: Int32, localEndpoint: SessionNetworkEndpoint, requestedDscp: Int?) {
        self.descriptor = descriptor
        self.localEndpoint = localEndpoint
        self.requestedDscp = requestedDscp
    }

    deinit {
        close()
    }

    public static func bindLoopback(
        receiveTimeoutSeconds: Int = 1,
        dscp: Int? = nil
    ) throws -> UdpMediaTransport {
        let descriptor = try makeUdpSocket(receiveTimeoutSeconds: receiveTimeoutSeconds)
        var succeeded = false
        defer {
            if !succeeded {
                closeUdpSocket(descriptor)
            }
        }
        if let dscp {
            try requireDscpRange(dscp)
            try setDscp(dscp, socket: descriptor)
        }
        try OpenLolaCore.bindLoopback(descriptor, port: 0)
        let endpoint = SessionNetworkEndpoint(
            host: "127.0.0.1",
            port: UInt16(bigEndian: try boundPort(descriptor))
        )
        succeeded = true
        return UdpMediaTransport(descriptor: descriptor, localEndpoint: endpoint, requestedDscp: dscp)
    }

    public static func bindIPv4(
        host: String,
        port: UInt16,
        receiveTimeoutSeconds: Int = 1,
        dscp: Int? = nil
    ) throws -> UdpMediaTransport {
        let descriptor = try makeUdpSocket(receiveTimeoutSeconds: receiveTimeoutSeconds)
        var succeeded = false
        defer {
            if !succeeded {
                closeUdpSocket(descriptor)
            }
        }
        if let dscp {
            try requireDscpRange(dscp)
            try setDscp(dscp, socket: descriptor)
        }
        try OpenLolaCore.bindIPv4(descriptor, host: host, port: port.bigEndian)
        let endpoint = SessionNetworkEndpoint(
            host: host,
            port: UInt16(bigEndian: try boundPort(descriptor))
        )
        succeeded = true
        return UdpMediaTransport(descriptor: descriptor, localEndpoint: endpoint, requestedDscp: dscp)
    }

    public func connect(to peer: SessionNetworkEndpoint) throws {
        try peer.validate(fieldPrefix: "peer")
        try withOpenSocketLock {
            try connectUdpSocket(descriptor, host: peer.host, port: peer.port.bigEndian)
        }
    }

    public func send(_ packet: UdpMediaPacket) throws {
        let start = DispatchTime.now().uptimeNanoseconds
        let encoded = try packet.encoded()
        let packetizationDuration = mediaTransportElapsedMicroseconds(since: start)
        try withOpenSocketLock {
            metricsState.packetizationDuration.record(packetizationDuration)
            try sendConnectedDatagram(encoded, socket: descriptor)
            metricsState.packetsSent += 1
        }
    }

    public func sendRawDatagram(_ data: Data) throws {
        try withOpenSocketLock {
            try sendConnectedDatagram(data, socket: descriptor)
            metricsState.packetsSent += 1
        }
    }

    public func receive(maxByteCount: Int) throws -> UdpMediaPacket {
        try receiveDecoded(maxByteCount: maxByteCount).packet
    }

    public func receiveDecoded(maxByteCount: Int) throws -> UdpMediaDecodedPacket {
        let data = try withOpenSocketLock {
            try receiveDatagram(socket: descriptor, byteCount: maxByteCount)
        }
        let receivedAt = DispatchTime.now().uptimeNanoseconds
        return try decodeReceived(data, receivedAt: receivedAt)
    }

    public func tryReceive(maxByteCount: Int) throws -> UdpMediaPacket? {
        try tryReceiveDecoded(maxByteCount: maxByteCount)?.packet
    }

    public func tryReceiveDecoded(maxByteCount: Int) throws -> UdpMediaDecodedPacket? {
        let data = try withOpenSocketLock {
            guard try datagramAvailable(socket: descriptor) else {
                return Data?.none
            }
            return try receiveDatagramIfAvailable(socket: descriptor, byteCount: maxByteCount)
        }
        guard let data else {
            return nil
        }
        let receivedAt = DispatchTime.now().uptimeNanoseconds
        return try decodeReceived(data, receivedAt: receivedAt)
    }

    public func tryReceiveRawDatagram(maxByteCount: Int) throws -> Data? {
        try withOpenSocketLock {
            guard try datagramAvailable(socket: descriptor) else {
                return nil
            }
            let data = try receiveDatagramIfAvailable(socket: descriptor, byteCount: maxByteCount)
            if data != nil {
                metricsState.packetsReceived += 1
            }
            return data
        }
    }

    public func drain(maxByteCount: Int, limit: Int) throws -> [UdpMediaPacket] {
        guard limit > 0 else {
            return []
        }
        var packets: [UdpMediaPacket] = []
        packets.reserveCapacity(limit)
        while packets.count < limit {
            guard let packet = try tryReceive(maxByteCount: maxByteCount) else {
                break
            }
            packets.append(packet)
        }
        return packets
    }

    func waitForReadable(timeoutMicroseconds: UInt64) throws -> Bool {
        try withOpenSocketLock {
            try waitForReadableSocket(socket: descriptor, timeoutMicroseconds: timeoutMicroseconds)
        }
    }

    private func decodeReceived(_ data: Data, receivedAt: UInt64) throws -> UdpMediaDecodedPacket {
        let decodeStart = DispatchTime.now().uptimeNanoseconds
        let decoded: UdpMediaDecodedPacket
        do {
            decoded = try UdpMediaPacket.decodeWithNestedPayload(data)
        } catch {
            recordMalformedReceived()
            throw UdpMediaMalformedDatagramError(reason: String(describing: error))
        }
        recordReceived(
            decoded.packet,
            receivedAt: receivedAt,
            depacketizationDurationMicroseconds: mediaTransportElapsedMicroseconds(since: decodeStart)
        )
        return decoded
    }

    public func close() {
        stateLock.lock()
        guard !isClosed else {
            stateLock.unlock()
            return
        }
        isClosed = true
        closeUdpSocket(descriptor)
        stateLock.unlock()
    }

    private func withOpenSocketLock<R>(_ operation: () throws -> R) throws -> R {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !isClosed else {
            throw UdpPcmRouteProbeError.receiveFailed(EBADF)
        }
        return try operation()
    }

    private func recordReceived(
        _ packet: UdpMediaPacket,
        receivedAt: UInt64,
        depacketizationDurationMicroseconds: Double
    ) {
        stateLock.lock()
        defer { stateLock.unlock() }
        metricsState.depacketizationDuration.record(depacketizationDurationMicroseconds)
        metricsState.packetsReceived += 1
        let key = UdpMediaSequenceKey(
            payloadType: packet.header.payloadType,
            streamID: packet.header.streamID
        )
        let sequenceNumber = packet.header.sequenceNumber
        var recentSequences = recentSequencesByStream[key] ?? UdpMediaRecentSequences()
        let isDuplicate = !recentSequences.insert(sequenceNumber)
        recentSequencesByStream[key] = recentSequences
        if isDuplicate {
            metricsState.duplicatePackets += 1
        }
        if let expected = nextSequenceByStream[key] {
            if sequenceNumber == expected {
                nextSequenceByStream[key] = sequenceNumber &+ 1
            } else if udpMediaSequenceIsForward(actual: sequenceNumber, expected: expected) {
                let lostPackets = udpMediaForwardSequenceGap(
                    expected: expected,
                    actual: sequenceNumber
                )
                metricsState.packetsLost += lostPackets
                nextSequenceByStream[key] = sequenceNumber &+ 1
            } else {
                metricsState.latePackets += 1
                if !isDuplicate {
                    metricsState.reorderedPackets += 1
                }
            }
        } else {
            nextSequenceByStream[key] = sequenceNumber &+ 1
        }

        guard receivedAt >= packet.header.timestampNanoseconds else {
            metricsState.clockSkewEventCount += 1
            return
        }
        let transit = Double(receivedAt - packet.header.timestampNanoseconds) / 1_000
        metricsState.jitterMicroseconds = jitterState.record(
            payloadType: packet.header.payloadType,
            streamID: packet.header.streamID,
            transitMicroseconds: transit
        )
    }

    private func recordMalformedReceived() {
        stateLock.lock()
        metricsState.malformedPackets += 1
        stateLock.unlock()
    }
}

private func mediaTransportElapsedMicroseconds(since startNanoseconds: UInt64) -> Double {
    let end = DispatchTime.now().uptimeNanoseconds
    return Double(end >= startNanoseconds ? end - startNanoseconds : 0) / 1_000
}

private struct UdpMediaSequenceKey: Hashable {
    var payloadType: SessionPayloadType
    var streamID: UInt32
}

struct UdpMediaJitterState {
    private var previousTransitByStream: [UdpMediaSequenceKey: Double] = [:]
    private var transitSampleCountByStream: [UdpMediaSequenceKey: Int] = [:]
    private var jitterByStream: [UdpMediaSequenceKey: Double] = [:]

    mutating func record(
        payloadType: SessionPayloadType,
        streamID: UInt32,
        transitMicroseconds: Double
    ) -> Double {
        let key = UdpMediaSequenceKey(payloadType: payloadType, streamID: streamID)
        let sampleCount = (transitSampleCountByStream[key] ?? 0) + 1
        transitSampleCountByStream[key] = sampleCount

        if let previousTransit = previousTransitByStream[key] {
            let delta = abs(transitMicroseconds - previousTransit)
            if sampleCount >= minimumUdpMediaJitterSampleCount {
                let previousJitter = jitterByStream[key] ?? 0
                jitterByStream[key] = previousJitter + (delta - previousJitter) / 16
            }
        }
        previousTransitByStream[key] = transitMicroseconds
        return jitterByStream.values.max() ?? 0
    }
}

private let minimumUdpMediaJitterSampleCount = 16
private let udpMediaSequenceHalfWindowThreshold = UInt64.max / 2

private struct UdpMediaRecentSequences {
    private var order: [UInt64] = []
    private var set = Set<UInt64>()
    private let capacity = 256

    mutating func insert(_ sequenceNumber: UInt64) -> Bool {
        guard set.insert(sequenceNumber).inserted else {
            return false
        }
        order.append(sequenceNumber)
        if order.count > capacity {
            let evicted = Array(order.prefix(order.count - capacity))
            order.removeFirst(order.count - capacity)
            for sequence in evicted {
                set.remove(sequence)
            }
        }
        return true
    }
}

private func udpMediaSequenceIsForward(actual: UInt64, expected: UInt64) -> Bool {
    let forwardDistance = actual &- expected
    return forwardDistance > 0 && forwardDistance <= udpMediaSequenceHalfWindowThreshold
}

private func udpMediaForwardSequenceGap(expected: UInt64, actual: UInt64) -> Int {
    guard actual != expected else {
        return 0
    }
    let forwardDistance = actual &- expected
    guard forwardDistance <= UInt64(Int.max) else {
        return 0
    }
    return Int(forwardDistance)
}

private func datagramAvailable(socket: Int32) throws -> Bool {
    var pollDescriptor = pollfd(fd: socket, events: Int16(POLLIN), revents: 0)
    let result = poll(&pollDescriptor, 1, 0)
    if result < 0 {
        throw UdpPcmRouteProbeError.receiveFailed(errno)
    }
    return result > 0 && (pollDescriptor.revents & Int16(POLLIN)) != 0
}

private func readUdpMediaUInt16LE(_ bytes: [UInt8], offset: Int) throws -> UInt16 {
    guard udpPcmHasBytes(bytes, offset: offset, count: 2) else {
        throw UdpMediaPacketError.truncatedPacket(byteCount: bytes.count)
    }
    return NetworkByteReader.readUInt16LE(bytes, offset: offset)
}

private func readUdpMediaUInt32LE(_ bytes: [UInt8], offset: Int) throws -> UInt32 {
    guard udpPcmHasBytes(bytes, offset: offset, count: 4) else {
        throw UdpMediaPacketError.truncatedPacket(byteCount: bytes.count)
    }
    return NetworkByteReader.readUInt32LE(bytes, offset: offset)
}

private func readUdpMediaUInt64LE(_ bytes: [UInt8], offset: Int) throws -> UInt64 {
    guard udpPcmHasBytes(bytes, offset: offset, count: 8) else {
        throw UdpMediaPacketError.truncatedPacket(byteCount: bytes.count)
    }
    return NetworkByteReader.readUInt64LE(bytes, offset: offset)
}

private func appendUdpMediaUInt16LE(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(value & 0xFF))
    data.append(UInt8((value >> 8) & 0xFF))
}

private func appendUdpMediaUInt32LE(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(value & 0xFF))
    data.append(UInt8((value >> 8) & 0xFF))
    data.append(UInt8((value >> 16) & 0xFF))
    data.append(UInt8((value >> 24) & 0xFF))
}

private func appendUdpMediaUInt64LE(_ value: UInt64, to data: inout Data) {
    appendUdpMediaUInt32LE(UInt32(value & 0xFFFF_FFFF), to: &data)
    appendUdpMediaUInt32LE(UInt32((value >> 32) & 0xFFFF_FFFF), to: &data)
}
