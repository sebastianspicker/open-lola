// Verifies JackTrip receive playout ownership and bounded receive accounting.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func jackTripLiveReceiveRequiresCoreAudioPlaybackBeforeTransportStarts() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .jackTrip,
        role: .rx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-live-receive-playback.json"
    ) { input in
        input.dryRun = false
    })

    #expect(throws: ExternalConnectorSessionError.missingRequiredArgument(
        "--audio-playback coreaudio:<device-uid>"
    )) {
        _ = try JackTripCompatibilityRunner.run(
            configuration: configuration,
            transmitter: JackTripMemoryMediaTransmitter(),
            receiver: JackTripStaticReceiveResultReceiver(
                result: JackTripCompatibilityReceiveResult(datagrams: [])
            )
        )
    }
}

@Test
func jackTripDryReceiveConvertsEightBitPCMToSharedPlayoutShapeWithoutHardware() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .jackTrip,
        role: .rx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-dry-receive-playback.json"
    ) { input in
        input.dryRun = true
        input.channels = 1
    })
    let header = try JackTripDefaultHeader(
        timestampMicroseconds: 1,
        sequenceNumber: 0,
        bufferSizeSamples: 2,
        sampleRate: .hz48000,
        bitResolution: .bit8,
        incomingChannelsFromNetwork: 1,
        outgoingChannelsToNetwork: JackTripCompatibility.matchingOutgoingChannelSentinel
    )
    let sink = try JackTripReceiveAudioSink(configuration: configuration)

    sink.consume(JackTripCompatibilityDatagram(
        sourceHost: "203.0.113.10",
        destinationPort: JackTripCompatibility.defaultAudioPort,
        packet: try JackTripAudioPacket(header: header, planarAudioPayload: Data([0, 0x80]))
    ))

    let report = sink.report()
    #expect(report.audioPacketCount == 1)
    #expect(report.audioPayloadByteCount == 2 * MemoryLayout<Float>.size)
    #expect(report.rejectedMediaCount == 0)
    #expect(report.notes.contains("no live CoreAudio playout was requested"))
}

@Test
func jackTripDryDuplexKeepsReceiveAccountingWithoutPlaybackConfiguration() throws {
    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .jackTrip,
            role: .txRx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-dry-duplex-playback.json"
        ) { input in
            input.dryRun = true
            input.mediaPacketCount = 1
        }),
        transmitter: JackTripMemoryMediaTransmitter(),
        receiver: JackTripStaticReceiveResultReceiver(
            result: JackTripCompatibilityReceiveResult(datagrams: [])
        )
    )

    #expect(report.transmittedDatagramCount == 1)
    #expect(report.receivedDatagramCount == 0)
    #expect(report.runtimeError == "received 0 of 1 expected JackTrip UDP audio datagrams")
}

@Test
func jackTripDuplexProviderUsesTransmitOnlyConfigurationWithoutPlayback() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .jackTrip,
        role: .txRx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-duplex-provider.json"
    ) { input in
        input.audioPlayback = "coreaudio:receive-output"
    })

    let providerConfiguration = JackTripCompatibilityRunner.transmitProviderConfiguration(for: configuration)

    #expect(providerConfiguration.role == .tx)
    #expect(providerConfiguration.audioPlayback == nil)
    #expect(configuration.role == .txRx)
    #expect(configuration.audioPlayback == "coreaudio:receive-output")
}

@Test
func jackTripReceiveReportRejectsPacketWhoseProducedPlayoutIsEntirelyDropped() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .jackTrip,
        role: .rx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-full-playout-ring.json"
    ) { input in
        input.dryRun = true
        input.channels = 1
    })
    let header = try JackTripDefaultHeader(
        timestampMicroseconds: 1,
        sequenceNumber: 0,
        bufferSizeSamples: 1,
        sampleRate: .hz48000,
        bitResolution: .bit16,
        incomingChannelsFromNetwork: 1,
        outgoingChannelsToNetwork: JackTripCompatibility.matchingOutgoingChannelSentinel
    )
    let sink = try JackTripReceiveAudioSink(
        configuration: configuration,
        audioPlayout: JackTripAlwaysDroppingAudioPlayout()
    )
    try sink.start()
    sink.consume(JackTripCompatibilityDatagram(
        sourceHost: "203.0.113.10",
        destinationPort: JackTripCompatibility.defaultAudioPort,
        packet: try JackTripAudioPacket(header: header, planarAudioPayload: Data([0, 0]))
    ))

    let report = sink.report()
    #expect(report.audioPacketCount == 0)
    #expect(report.audioPayloadByteCount == 0)
    #expect(report.rejectedMediaCount == 1)
}

@Test
func jackTripReceiveReportRecordsPartialPlayoutDropsWithoutRejectingPacket() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .jackTrip,
        role: .rx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-partial-playout-ring.json"
    ) { input in
        input.dryRun = true
        input.channels = 1
    })
    let header = try JackTripDefaultHeader(
        timestampMicroseconds: 1,
        sequenceNumber: 0,
        bufferSizeSamples: 1,
        sampleRate: .hz48000,
        bitResolution: .bit16,
        incomingChannelsFromNetwork: 1,
        outgoingChannelsToNetwork: JackTripCompatibility.matchingOutgoingChannelSentinel
    )
    let sink = try JackTripReceiveAudioSink(
        configuration: configuration,
        audioPlayout: JackTripPartiallyDroppingAudioPlayout()
    )
    try sink.start()
    sink.consume(JackTripCompatibilityDatagram(
        sourceHost: "203.0.113.10",
        destinationPort: JackTripCompatibility.defaultAudioPort,
        packet: try JackTripAudioPacket(header: header, planarAudioPayload: Data([0, 0]))
    ))

    let report = sink.report()
    #expect(report.audioPacketCount == 1)
    #expect(report.audioPayloadByteCount == 2)
    #expect(report.rejectedMediaCount == 1)
}

private final class JackTripAlwaysDroppingAudioPlayout: @unchecked Sendable, JackTripReceiveAudioPlayout {
    func start() throws {}

    func stop() {}

    func enqueue(
        _: DecodedInterleavedPCM,
        hostTimeNanoseconds _: UInt64
    ) throws -> DecodedAudioPlayoutEnqueueOutcome {
        .init(droppedBlocks: 1)
    }
}

private final class JackTripPartiallyDroppingAudioPlayout: @unchecked Sendable, JackTripReceiveAudioPlayout {
    func start() throws {}

    func stop() {}

    func enqueue(
        _: DecodedInterleavedPCM,
        hostTimeNanoseconds _: UInt64
    ) throws -> DecodedAudioPlayoutEnqueueOutcome {
        .init(queuedBlocks: 1, droppedBlocks: 1)
    }
}
