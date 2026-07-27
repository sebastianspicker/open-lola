// Verifies JackTrip receive evidence, learned peers, and packet-order accounting.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func jackTripNativeRunnerReportsLearnedPeerAndRedundancyRecovery() throws {
    let receivedDatagrams = [
        JackTripCompatibilityDatagram(
            sourceHost: "203.0.113.10",
            sourcePort: 54_321,
            destinationPort: JackTripCompatibility.defaultAudioPort,
            packet: try jackTripTestPacket(sequenceNumber: 0, payloadByte: 0x01)
        ),
        JackTripCompatibilityDatagram(
            sourceHost: "203.0.113.10",
            sourcePort: 54_321,
            destinationPort: JackTripCompatibility.defaultAudioPort,
            packets: [
                try jackTripTestPacket(sequenceNumber: 2, payloadByte: 0x03),
                try jackTripTestPacket(sequenceNumber: 1, payloadByte: 0x02)
            ]
        )
    ]
    let receiver = JackTripStaticReceiveResultReceiver(
        result: JackTripCompatibilityReceiveResult(datagrams: receivedDatagrams)
    )

    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .jackTrip,
            role: .rx,
            peer: "0.0.0.0",
            outputPath: "/tmp/jacktrip-native-rx.json"
        ) { input in
            input.mediaPacketCount = 2
        }),
        transmitter: JackTripMemoryMediaTransmitter(),
        receiver: receiver
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.learnedPeerHost == "203.0.113.10")
    #expect(report.learnedPeerPort == 54_321)
    #expect(report.redundancyRecoveredPacketCount == 1)
    #expect(report.packetLossCount == 0)
    #expect(report.duplicatePacketCount == 0)
    #expect(report.outOfOrderPacketCount == 0)
    #expect(report.sink.audioPacketCount == 3)
    #expect(report.sink.audioPayloadByteCount == 24)
    #expect(report.sink.rejectedMediaCount == 0)
    #expect(report.networkServiceClassStatus.contains("not-applied"))
}

@Test
func jackTripSocketReceiverLearnsPeerFromInboundUdpSource() throws {
    let audioPort = try freeLoopbackUdpPort()
    let resultBox = JackTripReceiveResultBox()

    DispatchQueue.global(qos: .userInitiated).async {
        resultBox.store(Result {
            try JackTripSocketMediaReceiver().receive(JackTripMediaReceiveRequest(
                expectedDatagrams: 1,
                localHost: "127.0.0.1",
                peer: "0.0.0.0",
                audioPort: audioPort,
                headerMode: .default,
                emptyHeaderTemplate: nil,
                timeoutSeconds: 2
            ))
        })
    }

    usleep(50_000)
    let sender = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { closeUdpSocket(sender) }
    let packet = try jackTripTestPacket(sequenceNumber: 4, payloadByte: 0x04)
    try sendDatagram(
        try JackTripAudioPayloadCodec.encodeDefaultDatagram([packet]),
        socket: sender,
        host: "127.0.0.1",
        port: audioPort.bigEndian
    )

    let result = try resultBox.load()
    #expect(result.datagrams.count == 1)
    #expect(result.datagrams[0].sourceHost == "127.0.0.1")
    #expect(result.datagrams[0].sourcePort != nil)
    #expect(result.datagrams[0].packets.map(\.header.sequenceNumber) == [4])
}

@Test
func jackTripNativeRunnerReportsUnrecoveredGapsDuplicatesAndReordering() throws {
    let receivedDatagrams = [
        JackTripCompatibilityDatagram(
            destinationPort: JackTripCompatibility.defaultAudioPort,
            packet: try jackTripTestPacket(sequenceNumber: 2, payloadByte: 0x02)
        ),
        JackTripCompatibilityDatagram(
            destinationPort: JackTripCompatibility.defaultAudioPort,
            packets: [
                try jackTripTestPacket(sequenceNumber: 0, payloadByte: 0x00),
                try jackTripTestPacket(sequenceNumber: 2, payloadByte: 0x02)
            ]
        )
    ]
    let receiver = JackTripStaticReceiveResultReceiver(
        result: JackTripCompatibilityReceiveResult(datagrams: receivedDatagrams)
    )

    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .jackTrip,
            role: .rx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-native-rx.json"
        ) { input in
            input.mediaPacketCount = 2
        }),
        transmitter: JackTripMemoryMediaTransmitter(),
        receiver: receiver
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.packetLossCount == 1)
    #expect(report.duplicatePacketCount == 1)
    #expect(report.outOfOrderPacketCount == 1)
    #expect(report.redundancyRecoveredPacketCount == 0)
    #expect(report.sink.audioPacketCount == 3)
    #expect(report.sink.audioPayloadByteCount == 24)
}
