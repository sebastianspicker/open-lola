// Implements UdpMediaTransport media transport boundary, separating packet I/O from session policy.
import Darwin
import Dispatch
import Foundation

/// Provides the UdpMediaTransport boundary that isolates I/O lifetime from UDP media transport policy.
public final class UdpMediaTransport: @unchecked Sendable {
    public let localEndpoint: SessionNetworkEndpoint
    public let requestedDscp: Int?
    public let bufferProfile: UdpSocketBufferProfile
    public var metrics: UdpMediaMetrics {
        stateLock.lock()
        defer { stateLock.unlock() }
        return metricsState
    }

    let descriptor: Int32
    let stateLock = NSLock()
    private var metricsState = UdpMediaMetrics()
    private var nextSequenceByStream: [UdpMediaSequenceKey: UInt64] = [:]
    private var recentSequencesByStream: [UdpMediaSequenceKey: UdpMediaRecentSequences] = [:]
    private var jitterState = UdpMediaJitterState()
    var isClosed = false

    private init(
        descriptor: Int32,
        localEndpoint: SessionNetworkEndpoint,
        requestedDscp: Int?,
        bufferProfile: UdpSocketBufferProfile
    ) {
        self.descriptor = descriptor
        self.localEndpoint = localEndpoint
        self.requestedDscp = requestedDscp
        self.bufferProfile = bufferProfile
    }

    deinit {
        close()
    }

    public static func bindLoopback(
        receiveTimeoutSeconds: Int = 1,
        dscp: Int? = nil,
        bufferProfile: UdpSocketBufferProfile = .realtimeAudio
    ) throws -> UdpMediaTransport {
        try bind(
            host: "127.0.0.1",
            receiveTimeoutSeconds: receiveTimeoutSeconds,
            dscp: dscp,
            bufferProfile: bufferProfile
        ) { descriptor in
            try OpenLolaCore.bindLoopback(descriptor, port: 0)
        }
    }

    public static func bindIPv4(
        host: String,
        port: UInt16,
        receiveTimeoutSeconds: Int = 1,
        dscp: Int? = nil,
        bufferProfile: UdpSocketBufferProfile = .realtimeAudio
    ) throws -> UdpMediaTransport {
        try bind(
            host: host,
            receiveTimeoutSeconds: receiveTimeoutSeconds,
            dscp: dscp,
            bufferProfile: bufferProfile
        ) { descriptor in
            try OpenLolaCore.bindIPv4(descriptor, host: host, port: port.bigEndian)
        }
    }

    private static func bind(
        host: String,
        receiveTimeoutSeconds: Int,
        dscp: Int?,
        bufferProfile: UdpSocketBufferProfile,
        operation: (Int32) throws -> Void
    ) throws -> UdpMediaTransport {
        let descriptor = try makeUdpSocket(
            receiveTimeoutSeconds: receiveTimeoutSeconds,
            bufferProfile: bufferProfile
        )
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
        try operation(descriptor)
        let endpoint = SessionNetworkEndpoint(
            host: host,
            port: UInt16(bigEndian: try boundPort(descriptor))
        )
        succeeded = true
        return UdpMediaTransport(
            descriptor: descriptor,
            localEndpoint: endpoint,
            requestedDscp: dscp,
            bufferProfile: bufferProfile
        )
    }

    public func connect(to peer: SessionNetworkEndpoint) throws {
        try peer.validate(fieldPrefix: "peer")
        try withOpenSocketLock {
            try connectUdpSocket(descriptor, host: peer.host, port: peer.port.bigEndian)
        }
    }

    public func send(_ packet: UdpMediaPacket) throws {
        guard try trySend(packet) == .sent else {
            throw UdpPcmRouteProbeError.sendFailed(EWOULDBLOCK)
        }
    }

    func trySend(_ packet: UdpMediaPacket) throws -> UdpDatagramSendResult {
        let start = DispatchTime.now().uptimeNanoseconds
        let encoded = try packet.encoded()
        let packetizationDuration = mediaTransportElapsedMicroseconds(since: start)
        return try withOpenSocketLock {
            metricsState.packetizationDuration.record(packetizationDuration)
            let result = try trySendConnectedDatagram(
                encoded,
                socket: descriptor,
                nonBlocking: bufferProfile.usesNonBlockingSend
            )
            if result == .sent {
                metricsState.packetsSent += 1
            }
            return result
        }
    }

    public func sendRawDatagram(_ data: Data) throws {
        guard try trySendRawDatagram(data) == .sent else {
            throw UdpPcmRouteProbeError.sendFailed(EWOULDBLOCK)
        }
    }

    func trySendRawDatagram(_ data: Data) throws -> UdpDatagramSendResult {
        try withOpenSocketLock {
            let result = try trySendConnectedDatagram(
                data,
                socket: descriptor,
                nonBlocking: bufferProfile.usesNonBlockingSend
            )
            if result == .sent {
                metricsState.packetsSent += 1
            }
            return result
        }
    }

    public func receive(maxByteCount: Int) throws -> UdpMediaPacket {
        try receiveDecoded(maxByteCount: maxByteCount).packet
    }

    public func receiveDecoded(maxByteCount: Int) throws -> UdpMediaDecodedPacket {
        let socket = try openSocketDescriptor()
        let data = try receiveDatagram(socket: socket, byteCount: maxByteCount)
        try requireSocketOpenAfterBlockingOperation()
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

    @discardableResult
    func resetReceiveContinuity(maxByteCount: Int, drainLimit: Int) throws -> Int {
        try withOpenSocketLock {
            nextSequenceByStream.removeAll(keepingCapacity: true)
            recentSequencesByStream.removeAll(keepingCapacity: true)
            jitterState = UdpMediaJitterState()

            guard drainLimit > 0 else {
                return 0
            }
            var drained = 0
            while drained < drainLimit,
                  try datagramAvailable(socket: descriptor),
                  try receiveDatagramIfAvailable(socket: descriptor, byteCount: maxByteCount) != nil {
                drained += 1
            }
            return drained
        }
    }

    func waitForReadable(timeoutMicroseconds: UInt64) throws -> Bool {
        let socket = try openSocketDescriptor()
        let isReadable = try waitForReadableSocket(socket: socket, timeoutMicroseconds: timeoutMicroseconds)
        try requireSocketOpenAfterBlockingOperation()
        return isReadable
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
