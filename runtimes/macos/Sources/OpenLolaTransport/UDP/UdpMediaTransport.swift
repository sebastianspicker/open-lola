import OpenLolaEvidenceModels
import OpenLolaSessionDomain
import OpenLolaContracts
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
    private var receiveStreamOrder: [UdpMediaSequenceKey] = []
    private var receiveScratch: [UInt8] = []
    private var sendScratch = Data()
    private var jitterState = UdpMediaJitterState()
    var isClosed = false

    static let maximumTrackedReceiveStreams = 256

    var trackedReceiveStreamCount: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return nextSequenceByStream.count
    }

    package var receiveScratchStorageForTesting: UdpMediaReceiveScratchStorage {
        stateLock.lock()
        defer { stateLock.unlock() }
        return receiveScratch.withUnsafeBufferPointer {
            UdpMediaReceiveScratchStorage(
                byteCount: receiveScratch.count,
                capacity: receiveScratch.capacity,
                address: $0.baseAddress.map { UInt(bitPattern: $0) }
            )
        }
    }

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
            try OpenLolaTransport.bindLoopback(descriptor, port: 0)
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
            try OpenLolaTransport.bindIPv4(descriptor, host: host, port: port.bigEndian)
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
            try validateDscp(dscp)
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

    package func trySend(_ packet: UdpMediaPacket) throws -> UdpDatagramSendResult {
        let validationStart = DispatchTime.now().uptimeNanoseconds
        try packet.validateForEncoding()
        let validationDuration = mediaTransportElapsedMicroseconds(since: validationStart)
        return try withOpenSocketLock {
            let encodingStart = DispatchTime.now().uptimeNanoseconds
            packet.encodePrevalidated(into: &sendScratch)
            let encodingDuration = mediaTransportElapsedMicroseconds(since: encodingStart)
            metricsState.packetizationDuration.record(validationDuration + encodingDuration)
            let result = try trySendConnectedDatagram(
                sendScratch,
                socket: descriptor,
                nonBlocking: bufferProfile.usesNonBlockingSend
            )
            if result == .sent {
                metricsState.packetsSent = saturatingOpenLolaCounterSum(metricsState.packetsSent, 1)
            }
            return result
        }
    }

    package func trySendPreparedPcmV2Datagram(
        _ payload: UnsafeRawBufferPointer,
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        senderHostTimeNanoseconds: UInt64,
        fragment: UdpPcmV2ChannelFragmentPlan,
        mode: AudioTransportMode
    ) throws -> UdpDatagramSendResult {
        guard senderHostTimeNanoseconds > 0 else {
            throw UdpPcmV2PacketError.invalidTimestamp(senderHostTimeNanoseconds)
        }
        return try withOpenSocketLock {
            let start = DispatchTime.now().uptimeNanoseconds
            try UdpPcmV2Packetizer.encodePreparedMediaDatagram(
                payload,
                sequenceNumber: sequenceNumber,
                senderFrameIndex: senderFrameIndex,
                senderHostTimeNanoseconds: senderHostTimeNanoseconds,
                fragment: fragment,
                mode: mode,
                into: &sendScratch
            )
            metricsState.packetizationDuration.record(
                mediaTransportElapsedMicroseconds(since: start)
            )
            let result = try trySendConnectedDatagram(
                sendScratch,
                socket: descriptor,
                nonBlocking: bufferProfile.usesNonBlockingSend
            )
            if result == .sent {
                metricsState.packetsSent = saturatingOpenLolaCounterSum(metricsState.packetsSent, 1)
            }
            return result
        }
    }

    package func trySendNextPreparedVideoDatagram(
        _ cursor: inout UdpMediaPreparedVideoCursor
    ) throws -> UdpDatagramSendResult? {
        return try withOpenSocketLock {
            let start = DispatchTime.now().uptimeNanoseconds
            guard cursor.encodeNext(into: &sendScratch) else {
                return nil
            }
            metricsState.packetizationDuration.record(
                mediaTransportElapsedMicroseconds(since: start)
            )
            let result = try trySendConnectedDatagram(
                sendScratch,
                socket: descriptor,
                nonBlocking: bufferProfile.usesNonBlockingSend
            )
            if result == .sent {
                metricsState.packetsSent = saturatingOpenLolaCounterSum(metricsState.packetsSent, 1)
            } else {
                // The caller keeps and retries the frame; the refused fragment must not be skipped.
                cursor.rewindOne()
            }
            return result
        }
    }

    public func sendRawDatagram(_ data: Data) throws {
        guard try trySendRawDatagram(data) == .sent else {
            throw UdpPcmRouteProbeError.sendFailed(EWOULDBLOCK)
        }
    }

    package func trySendRawDatagram(_ data: Data) throws -> UdpDatagramSendResult {
        try withOpenSocketLock {
            let result = try trySendConnectedDatagram(
                data,
                socket: descriptor,
                nonBlocking: bufferProfile.usesNonBlockingSend
            )
            if result == .sent {
                metricsState.packetsSent = saturatingOpenLolaCounterSum(metricsState.packetsSent, 1)
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
            try receiveDatagramIfAvailable(
                socket: descriptor,
                byteCount: maxByteCount,
                buffer: &receiveScratch,
                includingEmptyDatagrams: true
            )
        }
        guard let data else {
            return nil
        }
        let receivedAt = DispatchTime.now().uptimeNanoseconds
        return try decodeReceived(data, receivedAt: receivedAt)
    }

    public func tryReceiveRawDatagram(maxByteCount: Int) throws -> Data? {
        try withOpenSocketLock {
            let data = try receiveDatagramIfAvailable(
                socket: descriptor,
                byteCount: maxByteCount,
                buffer: &receiveScratch
            )
            if data != nil {
                metricsState.packetsReceived = saturatingOpenLolaCounterSum(metricsState.packetsReceived, 1)
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
    package func resetReceiveContinuity(maxByteCount: Int, drainLimit: Int) throws -> Int {
        try withOpenSocketLock {
            nextSequenceByStream.removeAll(keepingCapacity: true)
            recentSequencesByStream.removeAll(keepingCapacity: true)
            receiveStreamOrder.removeAll(keepingCapacity: true)
            jitterState = UdpMediaJitterState()

            guard drainLimit > 0 else {
                return 0
            }
            var drained = 0
            while drained < drainLimit,
                  try receiveDatagramIfAvailable(
                      socket: descriptor,
                      byteCount: maxByteCount,
                      buffer: &receiveScratch,
                      includingEmptyDatagrams: true
                  ) != nil {
                drained += 1
            }
            return drained
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

    private func recordReceived(
        _ packet: UdpMediaPacket,
        receivedAt: UInt64,
        depacketizationDurationMicroseconds: Double
    ) {
        stateLock.lock()
        defer { stateLock.unlock() }
        metricsState.depacketizationDuration.record(depacketizationDurationMicroseconds)
        metricsState.packetsReceived = saturatingOpenLolaCounterSum(metricsState.packetsReceived, 1)
        let key = UdpMediaSequenceKey(
            payloadType: packet.header.payloadType,
            streamID: packet.header.streamID
        )
        trackReceiveStream(key)
        let sequenceNumber = packet.header.sequenceNumber
        let isDuplicate = !recentSequencesByStream[key, default: UdpMediaRecentSequences()]
            .insert(sequenceNumber)
        if isDuplicate {
            metricsState.duplicatePackets = saturatingOpenLolaCounterSum(metricsState.duplicatePackets, 1)
        }
        if let expected = nextSequenceByStream[key] {
            if sequenceNumber == expected {
                nextSequenceByStream[key] = sequenceNumber &+ 1
            } else if udpMediaSequenceIsForward(actual: sequenceNumber, expected: expected) {
                let lostPackets = udpMediaForwardSequenceGap(
                    expected: expected,
                    actual: sequenceNumber
                )
                metricsState.packetsLost = saturatingOpenLolaCounterSum(metricsState.packetsLost, lostPackets)
                nextSequenceByStream[key] = sequenceNumber &+ 1
            } else {
                metricsState.latePackets = saturatingOpenLolaCounterSum(metricsState.latePackets, 1)
                if !isDuplicate {
                    metricsState.reorderedPackets = saturatingOpenLolaCounterSum(metricsState.reorderedPackets, 1)
                }
            }
        } else {
            nextSequenceByStream[key] = sequenceNumber &+ 1
        }

        metricsState.jitterMicroseconds = jitterState.record(
            payloadType: packet.header.payloadType,
            streamID: packet.header.streamID,
            senderNanoseconds: packet.header.timestampNanoseconds,
            arrivalNanoseconds: receivedAt
        )
    }

    private func recordMalformedReceived() {
        stateLock.lock()
        metricsState.malformedPackets = saturatingOpenLolaCounterSum(metricsState.malformedPackets, 1)
        stateLock.unlock()
    }

    private func trackReceiveStream(_ key: UdpMediaSequenceKey) {
        guard nextSequenceByStream[key] == nil else {
            return
        }
        while nextSequenceByStream.count >= Self.maximumTrackedReceiveStreams,
              let evicted = receiveStreamOrder.first {
            receiveStreamOrder.removeFirst()
            nextSequenceByStream.removeValue(forKey: evicted)
            recentSequencesByStream.removeValue(forKey: evicted)
            jitterState.remove(evicted)
        }
        receiveStreamOrder.append(key)
    }
}

private func validateDscp(_ value: Int) throws {
    guard (0...63).contains(value) else {
        throw UdpPcmRouteProbeError.invalidDscp(value)
    }
}

package func saturatingOpenLolaCounterSum(_ lhs: Int, _ rhs: Int) -> Int {
    let result = lhs.addingReportingOverflow(rhs)
    guard result.overflow else {
        return result.partialValue
    }
    return rhs >= 0 ? Int.max : Int.min
}

private func mediaTransportElapsedMicroseconds(since startNanoseconds: UInt64) -> Double {
    let end = DispatchTime.now().uptimeNanoseconds
    return Double(end >= startNanoseconds ? end - startNanoseconds : 0) / 1_000
}

struct UdpMediaSequenceKey: Hashable {
    var payloadType: SessionPayloadType
    var streamID: UInt32
}

private let udpMediaSequenceHalfWindowThreshold = UInt64.max / 2

package struct UdpMediaRecentSequences {
    static let capacity = 256
    private var slots = Array<UInt64?>(repeating: nil, count: capacity)
    private var nextSlot = 0
    private var count = 0
    private var set = Set<UInt64>()

    mutating func insert(_ sequenceNumber: UInt64) -> Bool {
        guard set.insert(sequenceNumber).inserted else {
            return false
        }
        if count == Self.capacity, let evicted = slots[nextSlot] {
            set.remove(evicted)
        } else {
            count += 1
        }
        slots[nextSlot] = sequenceNumber
        nextSlot = (nextSlot + 1) % Self.capacity
        return true
    }
}

package struct UdpMediaReceiveScratchStorage: Equatable {
    package var byteCount: Int
    package var capacity: Int
    package var address: UInt?
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
