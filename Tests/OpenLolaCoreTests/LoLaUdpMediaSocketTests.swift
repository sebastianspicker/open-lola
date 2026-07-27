// Verifies that LoLa UDP media socket receiver binds before transmit window.
import Darwin
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaUdpMediaSocketReceiverBindsBeforeTransmitWindow() throws {
    let ports = try freeLocalUdpPorts(count: 2)
    let receiver = LoLaSocketUdpMediaReceiver(timeoutSeconds: 1)
    var transmittedAfterBind = false

    let datagrams = try receiver.receive(
        request: LoLaUdpMediaReceiveRequest(
            maxDatagrams: 1,
            localHost: "127.0.0.1",
            peer: "127.0.0.1",
            ports: LoLaUdpMediaReceivePorts(audio: ports[0], video: ports[1])
        )
    ) { _ in
        transmittedAfterBind = true
        try sendLoLaUdpMediaTestPayload(port: ports[0], payload: Data([0x01, 0x02, 0x03]))
    }

    #expect(transmittedAfterBind)
    #expect(datagrams == [
        LoLaUdpMediaDatagram(
            stream: .audio,
            port: ports[0],
            sourceHost: "127.0.0.1",
            payload: Data([0x01, 0x02, 0x03])
        )
    ])
}

@Test
func lolaAudioReceiveDrainDeliversOnlyNewestValidDatagramToPlayout() throws {
    let port: UInt16 = 19_788
    let first = LoLaUdpMediaDatagram(
        stream: .audio,
        port: port,
        sourceHost: "192.0.2.2",
        payload: Data([0x01])
    )
    let newest = LoLaUdpMediaDatagram(
        stream: .audio,
        port: port,
        sourceHost: "192.0.2.2",
        payload: Data([0x03])
    )
    var accumulator = LoLaAudioReceiveDrainAccumulator()
    var delivered: [LoLaUdpMediaDatagram] = []

    accumulator.recordValid(first)
    accumulator.recordRejectedSource()
    accumulator.recordValid(newest)
    accumulator.recordRejectedSource()
    accumulator.deliverNewest { delivered.append($0) }

    #expect(delivered == [newest])
    #expect(accumulator.coalescedStaleAudioDatagrams == 1)
    #expect(accumulator.rejectedAudioSourceDatagrams == 2)
}

@Test
func lolaAudioReceiveDrainUsesModuloSequenceOrderingForDescendingDuplicatesAndWrap() throws {
    let port: UInt16 = 19_788
    func datagram(_ sequence: UInt32) -> LoLaUdpMediaDatagram {
        LoLaUdpMediaDatagram(
            stream: .audio,
            port: port,
            sourceHost: "192.0.2.2",
            sequenceNumber: Int(sequence),
            payload: Data([UInt8(truncatingIfNeeded: sequence)])
        )
    }
    var accumulator = LoLaAudioReceiveDrainAccumulator()
    var delivered: [LoLaUdpMediaDatagram] = []
    accumulator.recordValid(datagram(UInt32.max - 1))
    accumulator.recordValid(datagram(UInt32.max - 2))
    accumulator.recordValid(datagram(UInt32.max - 1))
    accumulator.recordValid(datagram(0))
    accumulator.recordValid(LoLaUdpMediaDatagram(
        stream: .audio,
        port: port,
        sourceHost: "192.0.2.2",
        payload: Data([0xff])
    ))
    accumulator.deliverNewest { delivered.append($0) }

    #expect(delivered.map(\.sequenceNumber) == [0])
    #expect(accumulator.coalescedStaleAudioDatagrams == 4)
}

@Test
func fileDescriptorSetGuardRejectsOutOfRangeDescriptors() throws {
    #expect(openLolaFileDescriptorFitsFDSet(Int32(FD_SETSIZE - 1)))
    #expect(!openLolaFileDescriptorFitsFDSet(Int32(FD_SETSIZE)))
    #expect(throws: ExternalConnectorSessionError.self) {
        try openLolaRequireFileDescriptorFitsFDSet(Int32(FD_SETSIZE), context: "test")
    }
    try assertFDSetRejectsOutOfRange()
}

@Test
func lolaUdpMediaSocketFallsBackToWildcardBindWhenSpecificHostFails() throws {
    let ports = try freeLocalUdpPorts(count: 1)
    let descriptor = try makeLoLaUdpMediaSocket(bindHost: "203.0.113.1", port: ports[0])
    defer { Darwin.close(descriptor) }

    var boundAddress = sockaddr_in()
    var boundAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    try withUnsafeMutablePointer(to: &boundAddress) { pointer in
        let result = pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            Darwin.getsockname(descriptor, socketAddress, &boundAddressLength)
        }
        guard result == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }

    #expect(UInt16(bigEndian: boundAddress.sin_port) == ports[0])
    #expect(boundAddress.sin_addr.s_addr == inet_addr("0.0.0.0"))
}

@Test
func lolaUdpMediaTransmitterDropsBackpressuredVideoFrameWithoutCountingIt() throws {
    let ports: [UInt16] = [19_788, 19_798]
    var attempts: [Data] = []
    let transmitter = LoLaSocketUdpMediaTransmitter(
        boundSocketForDatagram: { _ in -1 },
        send: { payload, _, _, _ in
            attempts.append(payload)
            return attempts.count == 2 ? .wouldBlock : .sent(payload.count)
        }
    )
    let outcome = try transmitter.transmitResult([
        LoLaUdpMediaDatagram(stream: .audio, port: ports[0], sequenceNumber: 1, payload: Data([0x01])),
        LoLaUdpMediaDatagram(stream: .video, port: ports[1], sequenceNumber: 7, payload: Data([0x02])),
        LoLaUdpMediaDatagram(stream: .video, port: ports[1], sequenceNumber: 7, payload: Data([0x03])),
        LoLaUdpMediaDatagram(stream: .video, port: ports[1], sequenceNumber: 8, payload: Data([0x04]))
    ], localHost: "127.0.0.1", peer: "127.0.0.1")

    #expect(attempts == [Data([0x01]), Data([0x02]), Data([0x04])])
    #expect(outcome.sentByteCounts == [1, 1])
    #expect(outcome.droppedAudioPackets == 0)
    #expect(outcome.droppedVideoFrames == 1)
}

@Test
func lolaUdpMediaTransmitterUsesReceiverOwnedStreamSocket() throws {
    let ports: [UInt16] = [19_788, 19_798]
    let audioSocket: Int32 = 11
    let videoSocket: Int32 = 12
    var descriptors: [Int32] = []
    let transmitter = LoLaSocketUdpMediaTransmitter(
        boundSocketForDatagram: { $0.stream == .audio ? audioSocket : videoSocket },
        send: { _, descriptor, _, _ in
            descriptors.append(descriptor)
            return .sent(1)
        }
    )
    _ = try transmitter.transmit([
        LoLaUdpMediaDatagram(stream: .audio, port: ports[0], payload: Data([0x01])),
        LoLaUdpMediaDatagram(stream: .video, port: ports[1], payload: Data([0x02]))
    ], localHost: "127.0.0.1", peer: "127.0.0.1")

    #expect(descriptors == [audioSocket, videoSocket])
}

@Test
func lolaUdpMediaTransmitterDropsRemainderOfBackpressuredAudioSequence() throws {
    var attempts: [Data] = []
    let transmitter = LoLaSocketUdpMediaTransmitter(
        boundSocketForDatagram: { _ in -1 },
        send: { payload, _, _, _ in
            attempts.append(payload)
            return attempts.count == 1 ? .wouldBlock : .sent(payload.count)
        }
    )

    let outcome = try transmitter.transmitResult([
        LoLaUdpMediaDatagram(stream: .audio, port: 19_788, sequenceNumber: 7, payload: Data([0x01])),
        LoLaUdpMediaDatagram(stream: .audio, port: 19_788, sequenceNumber: 7, payload: Data([0x02])),
        LoLaUdpMediaDatagram(stream: .audio, port: 19_788, sequenceNumber: 8, payload: Data([0x03]))
    ], localHost: "127.0.0.1", peer: "127.0.0.1")

    #expect(attempts == [Data([0x01]), Data([0x03])])
    #expect(outcome.sentByteCounts == [1])
    #expect(outcome.droppedAudioPackets == 2)
}

@Test
func lolaUdpMediaTransmitterReportsWorkAbandonedAtSharedDeadline() throws {
    let transmitter = LoLaSocketUdpMediaTransmitter(
        boundSocketForDatagram: { _ in -1 },
        send: { _, _, _, _ in
            Issue.record("expired transmission must not call send")
            return .sent(1)
        },
        deadline: .now()
    )

    let outcome = try transmitter.transmitResult([
        LoLaUdpMediaDatagram(stream: .audio, port: 19_788, sequenceNumber: 1, payload: Data([0x01])),
        LoLaUdpMediaDatagram(stream: .video, port: 19_798, sequenceNumber: 1, payload: Data([0x02])),
        LoLaUdpMediaDatagram(stream: .video, port: 19_798, sequenceNumber: 1, payload: Data([0x03])),
        LoLaUdpMediaDatagram(stream: .video, port: 19_798, sequenceNumber: 2, payload: Data([0x04]))
    ], localHost: "127.0.0.1", peer: "127.0.0.1")

    #expect(outcome.sentByteCounts.isEmpty)
    #expect(outcome.deadlineAbandonedAudioPackets == 1)
    #expect(outcome.deadlineAbandonedVideoFrames == 2)
}

@Test
func lolaUdpMediaTransmitterRechecksDeadlineAfterVideoPacing() throws {
    var clock: UInt64 = 1_000
    var sentPayloads: [Data] = []
    let deadline = DispatchTime(uptimeNanoseconds: 2_000)
    let transmitter = LoLaSocketUdpMediaTransmitter(
        boundSocketForDatagram: { _ in -1 },
        send: { payload, _, _, _ in
            sentPayloads.append(payload)
            return .sent(payload.count)
        },
        deadline: deadline,
        now: { DispatchTime(uptimeNanoseconds: clock) },
        sleepUntil: { target in clock = target.uptimeNanoseconds }
    )

    let outcome = try transmitter.transmitResult([
        LoLaUdpMediaDatagram(
            stream: .video,
            port: 19_798,
            sequenceNumber: 1,
            videoFrameRate: 30,
            payload: Data([0x01])
        ),
        LoLaUdpMediaDatagram(
            stream: .video,
            port: 19_798,
            sequenceNumber: 2,
            videoFrameRate: 30,
            payload: Data([0x02])
        )
    ], localHost: "127.0.0.1", peer: "127.0.0.1")

    #expect(sentPayloads == [Data([0x01])])
    #expect(outcome.deadlineAbandonedVideoFrames == 1)
}

private func sendLoLaUdpMediaTestPayload(port: UInt16, payload: Data) throws {
    let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { Darwin.close(descriptor) }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    try payload.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(EINVAL))
        }
        let sent = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                Darwin.sendto(
                    descriptor,
                    baseAddress,
                    rawBuffer.count,
                    0,
                    socketAddress,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        guard sent == rawBuffer.count else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }
}
