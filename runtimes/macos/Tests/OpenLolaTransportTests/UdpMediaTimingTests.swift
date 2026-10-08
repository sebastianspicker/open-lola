// Verifies cross-host transport jitter and UDP drain recovery after empty datagrams.
import XCTest
import Dispatch
@testable import OpenLolaTransport
import OpenLolaSessionDomain

// Verifies clock-offset-independent transport timing and zero-byte datagram draining.
final class UdpMediaTimingTests: XCTestCase {
    func testJitterIsIndependentOfPeerUptimeOffset() {
        var peerAhead = UdpMediaJitterState()
        var peerBehind = UdpMediaJitterState()
        for index in 0..<20 {
            let sender = UInt64(10_000_000 + index * 1_000_000)
            let arrival = UInt64(100_000_000 + index * 1_000_000 + (index % 2) * 200_000)
            let ahead = peerAhead.record(
                payloadType: .audioPcmV2, streamID: 1,
                senderNanoseconds: sender + 1_000_000_000, arrivalNanoseconds: arrival
            )
            let behind = peerBehind.record(
                payloadType: .audioPcmV2, streamID: 1,
                senderNanoseconds: sender, arrivalNanoseconds: arrival + 1_000_000_000
            )
            XCTAssertEqual(ahead, behind, accuracy: 0.000_001)
        }
    }

    func testJitterRespondsBeforeSixteenPacketWarmup() {
        var jitter = UdpMediaJitterState()
        XCTAssertEqual(jitter.record(
            payloadType: .audioPcmV2, streamID: 1,
            senderNanoseconds: 1_000_000_000, arrivalNanoseconds: 1_000_000
        ), 0)
        XCTAssertEqual(jitter.record(
            payloadType: .audioPcmV2, streamID: 1,
            senderNanoseconds: 1_001_000_000, arrivalNanoseconds: 4_000_000
        ), 125, accuracy: 0.000_001)
    }

    func testConstantOffsetAndSeparateStreamsProduceNoJitter() {
        var jitter = UdpMediaJitterState()
        for index in 0..<30 {
            let time = UInt64(index * 1_000_000)
            XCTAssertEqual(jitter.record(
                payloadType: .audioPcmV2, streamID: 1,
                senderNanoseconds: time + 9_000_000_000, arrivalNanoseconds: time
            ), 0)
            XCTAssertEqual(jitter.record(
                payloadType: .audioPcmV2, streamID: 2,
                senderNanoseconds: time, arrivalNanoseconds: time + 80_000_000_000
            ), 0)
        }
    }

    func testTransportReportsJitterWhenPeerUptimeIsAhead() throws {
        let sender = try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 0)
        let receiver = try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 0)
        defer { sender.close(); receiver.close() }
        try sender.connect(to: receiver.localEndpoint)
        let peerTime = DispatchTime.now().uptimeNanoseconds + 10_000_000_000
        for sequence: UInt64 in 1...2 {
            try sender.send(UdpMediaPacket(
                header: UdpMediaPacketHeader(
                    payloadType: .keepalive, streamID: 1, sequenceNumber: sequence,
                    timestampNanoseconds: peerTime + sequence * 1_000_000_000
                ), payload: Data()
            ))
        }
        for _ in 0..<2 {
            try waitForReadableSocket(socket: receiver.openSocketDescriptor(), timeoutMicroseconds: 1_000_000)
            XCTAssertNotNil(try receiver.tryReceive(maxByteCount: 1_500))
        }
        XCTAssertGreaterThan(receiver.metrics.jitterMicroseconds, 0)
        XCTAssertEqual(receiver.metrics.clockSkewEventCount, 0)
    }

    func testDefaultSocketHelpersIgnoreEmptyDatagramsAndPreserveFollowingPayload() throws {
        let receiver = try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 0)
        let sender = try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 0)
        defer { receiver.close(); sender.close() }
        let socket = try receiver.openSocketDescriptor()
        let expectedPayload = Data([17, 23, 41])
        try sender.connect(to: receiver.localEndpoint)
        for sourceAware in [false, true] {
            try sender.sendRawDatagram(Data())
            try sender.sendRawDatagram(expectedPayload)
            try waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000_000)
            if sourceAware {
                XCTAssertNil(try receiveDatagramWithSourceIfAvailable(socket: socket, byteCount: 1_500))
                try waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000_000)
                let following = try XCTUnwrap(receiveDatagramWithSourceIfAvailable(socket: socket, byteCount: 1_500))
                XCTAssertEqual(following.data, expectedPayload)
                XCTAssertEqual(following.port, sender.localEndpoint.port)
            } else {
                var scratch: [UInt8] = []
                XCTAssertNil(try receiveDatagramIfAvailable(socket: socket, byteCount: 1_500, buffer: &scratch))
                try waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000_000)
                XCTAssertEqual(try receiveDatagramIfAvailable(socket: socket, byteCount: 1_500), expectedPayload)
            }
        }
    }

    func testZeroByteDatagramIsConsumedBeforeFollowingPacket() throws {
        let sender = try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 0)
        let receiver = try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 0)
        defer { sender.close(); receiver.close() }
        try sender.connect(to: receiver.localEndpoint)
        try sender.sendRawDatagram(Data())
        let packet = UdpMediaPacket(
            header: UdpMediaPacketHeader(
                payloadType: .keepalive, streamID: 1,
                sequenceNumber: 1, timestampNanoseconds: 1
            ), payload: Data()
        )
        try sender.send(packet)
        try waitForReadableSocket(socket: receiver.openSocketDescriptor(), timeoutMicroseconds: 1_000_000)
        XCTAssertThrowsError(try receiver.tryReceive(maxByteCount: 1_500)) { error in
            XCTAssertTrue(error is UdpMediaMalformedDatagramError)
        }
        try waitForReadableSocket(socket: receiver.openSocketDescriptor(), timeoutMicroseconds: 1_000_000)
        XCTAssertEqual(try receiver.tryReceive(maxByteCount: 1_500), packet)
        XCTAssertNil(try receiver.tryReceive(maxByteCount: 1_500))
    }
}
