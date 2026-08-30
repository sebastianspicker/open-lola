// Verifies UDP packet encoding and fake-kernel send, drop, and receive policy behavior.
import Darwin
import Foundation
import OpenLolaContracts
import OpenLolaSessionDomain
@testable import OpenLolaTransport
import Testing

@Test func udpMediaPacketRoundTripsExactHeaderAndRejectsTruncation() throws {
    let packet = UdpMediaPacket(
        header: .init(
            payloadType: .keepalive,
            streamID: 7,
            sequenceNumber: 42,
            timestampNanoseconds: 1_000
        ),
        payload: Data([0, 1, 2, 3])
    )
    let encoded = try packet.encoded()
    #expect(encoded.count == UdpMediaPacketHeader.byteCount + 4)
    #expect(try UdpMediaPacket.decode(encoded) == packet)
    #expect(throws: UdpMediaPacketError.self) {
        try UdpMediaPacket.decode(encoded.prefix(UdpMediaPacketHeader.byteCount - 1))
    }
}

@Test func udpPacketCodecUsesFakeKernelOutcomesForSendDropAndReceivePolicy() throws {
    let packet = UdpMediaPacket(
        header: .init(
            payloadType: .keepalive,
            streamID: 9,
            sequenceNumber: 3,
            timestampNanoseconds: 2_000
        ),
        payload: Data()
    )
    let transmittedDatagram = try packet.encoded()

    #expect(
        try udpDatagramSendResult(
            sentByteCount: transmittedDatagram.count,
            expectedByteCount: transmittedDatagram.count,
            savedErrno: 0,
            nonBlocking: true
        ) == .sent
    )
    #expect(
        try udpDatagramSendResult(
            sentByteCount: -1,
            expectedByteCount: transmittedDatagram.count,
            savedErrno: EAGAIN,
            nonBlocking: true
        ) == .wouldBlock
    )
    #expect(throws: UdpPcmRouteProbeError.self) {
        try udpDatagramSendResult(
            sentByteCount: transmittedDatagram.count - 1,
            expectedByteCount: transmittedDatagram.count,
            savedErrno: 0,
            nonBlocking: true
        )
    }
    #expect(try UdpMediaPacket.decode(transmittedDatagram) == packet)
}
