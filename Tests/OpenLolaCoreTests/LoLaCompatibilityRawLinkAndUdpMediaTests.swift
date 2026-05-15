import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaRawLinkTransmitRunnerWritesFramesToMemorySink() throws {
    let sink = LoLaMemoryRawLinkTransmitter()
    let configuration = try LoLaRawLinkTransmitRunConfiguration.parse([
        "--interface", "en0",
        "--source-ip", "192.0.2.10",
        "--peer", "192.0.2.20",
        "--source-mac", "02:4c:6f:4c:61:00",
        "--destination-mac", "aa:bb:cc:dd:ee:ff",
        "--output", "/tmp/lola-raw-link.json",
        "--packets", "2",
        "--media", "audio-video",
        "--video-width", "16",
        "--video-height", "16",
        "--video-bpp", "8",
    ])

    let report = try LoLaRawLinkTransmitRunner.run(
        configuration: configuration,
        transmitter: sink
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(!report.realLinkTransmitted)
    #expect(report.audioFrameCount == 2)
    #expect(report.videoFrameCount == 4)
    #expect(sink.transmittedFrames.count == 6)
    #expect(try LoLaCompatibilityWireFrame.decode(sink.transmittedFrames[0]).destinationMAC.octets == [
        0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
    ])
    #expect(report.notes.contains("memory sink"))
}

@Test
func lolaRawLinkTransmitConfigurationRejectsMalformedMacAddress() {
    #expect(throws: ExternalConnectorSessionError.socketFailed("invalid MAC bad-mac")) {
        _ = try LoLaRawLinkTransmitRunConfiguration.parse([
            "--interface", "en0",
            "--source-ip", "192.0.2.10",
            "--peer", "192.0.2.20",
            "--source-mac", "bad-mac",
            "--destination-mac", "aa:bb:cc:dd:ee:ff",
            "--output", "/tmp/lola-raw-link.json",
        ])
    }
}

@Test
func lolaRawLinkReceiveRunnerDecodesFramesFromMemorySource() throws {
    let txConfiguration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.10",
        localHost: "192.0.2.20",
        outputPath: "/tmp/lola-raw-link-rx-source.json",
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8
    )
    let encodedFrames = try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: txConfiguration,
        frameCountPerStream: 1
    ).map(\.encodedFrame)
    let configuration = try LoLaRawLinkReceiveRunConfiguration.parse([
        "--interface", "en0",
        "--local-ip", "192.0.2.10",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-raw-link-rx.json",
        "--frames", "3",
        "--media", "audio-video",
        "--timeout-seconds", "3",
    ])

    let report = try LoLaRawLinkReceiveRunner.run(
        configuration: configuration,
        receiver: LoLaMemoryRawLinkReceiver(frames: encodedFrames)
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(!report.realLinkTransmitted)
    #expect(report.audioFrameCount == 1)
    #expect(report.videoFrameCount == 2)
    #expect(report.envelopeValidatedFrameCount == 3)
    #expect(report.notes.contains("memory source"))
    #expect(configuration.timeoutSeconds == 3)
    #expect(report.notes.contains("timeout 3s"))
}

@Test
func lolaBpfPacketExtractionSkipsMalformedRecordsInBatch() throws {
    let frame = try LoLaCompatibilityWireFrame(
        destinationMAC: LoLaEthernetAddress(octets: [0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]),
        sourceMAC: LoLaEthernetAddress(octets: [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]),
        sourceIP: LoLaIPv4Address(octets: [192, 0, 2, 10]),
        destinationIP: LoLaIPv4Address(octets: [192, 0, 2, 20]),
        sourcePort: 19788,
        destinationPort: 19788,
        payload: Data([0x55, 0x66, 0x77, 0x88])
    ).encoded()
    let batch = bpfTestRecord(capturedLength: 1, payload: Data([0xff]))
        + bpfTestRecord(capturedLength: frame.count, payload: frame)

    let packets = try extractBpfPackets(batch)

    #expect(packets == [frame])
}

@Test
func lolaBpfPacketExtractionUsesNamedHeaderOffsets() throws {
    let source = try readLoLaMediaSessionSource(
        "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityRawLink.swift"
    )

    #expect(source.contains("bpfHeaderCapturedLengthOffset"))
    #expect(source.contains("bpfHeaderLengthOffset"))
    #expect(source.contains("bpf_xhdr is not supported"))
    #expect(!source.contains("offset: offset + 16"))
    #expect(!source.contains("offset: offset + 24"))
}

@Test
func lolaRawLinkReceiveRunnerMarksConfiguredRealReceive() throws {
    let txConfiguration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.10",
        localHost: "192.0.2.20",
        outputPath: "/tmp/lola-raw-link-rx-real-source.json",
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8
    )
    let encodedFrames = try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: txConfiguration,
        frameCountPerStream: 1
    ).map(\.encodedFrame)
    let configuration = LoLaRawLinkReceiveRunConfiguration(
        interfaceName: "en0",
        localIP: "192.0.2.10",
        peerIP: "192.0.2.20",
        outputPath: "/tmp/lola-raw-link-rx-real.json",
        dryRun: false,
        maxFrames: 3,
        mediaMode: .audioVideo,
        timeoutSeconds: 3
    )

    let report = try LoLaRawLinkReceiveRunner.run(
        configuration: configuration,
        receiver: LoLaMemoryRawLinkReceiver(frames: encodedFrames)
    )

    try report.validate()
    #expect(report.realLinkTransmitted)
}

@Test
func lolaRawLinkReceiveRunnerReturnsStructuredTimeoutReport() throws {
    let configuration = LoLaRawLinkReceiveRunConfiguration(
        interfaceName: "en0",
        localIP: "192.0.2.10",
        peerIP: "192.0.2.20",
        outputPath: "/tmp/lola-raw-link-rx-timeout.json",
        dryRun: false,
        maxFrames: 2,
        mediaMode: .audioVideo,
        timeoutSeconds: 3
    )

    let report = try LoLaRawLinkReceiveRunner.run(
        configuration: configuration,
        receiver: LoLaTimeoutRawLinkReceiver()
    )

    try report.validate()
    #expect(report.id == "lola-raw-link-rx-timeout-en0")
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == "receiveTimedOut")
    #expect(report.realLinkTransmitted)
    #expect(report.localHost == "192.0.2.10")
    #expect(report.peer == "192.0.2.20")
    #expect(report.timeoutSeconds == 3)
    #expect(report.expectedDatagramCount == 2)
}

@Test
func lolaBpfRawLinkReceiverCarriesBoundedTimeoutConfiguration() {
    let receiver = LoLaBpfRawLinkReceiver(interfaceName: "en0", timeoutSeconds: 7)

    #expect(receiver.interfaceName == "en0")
    #expect(receiver.timeoutSeconds == 7)
}

@Test
func lolaUdpMediaTransmitRunnerSendsPayloadsThroughMemorySink() throws {
    let sink = LoLaMemoryUdpMediaTransmitter()
    let configuration = try LoLaUdpMediaTransmitRunConfiguration.parse([
        "--local-host", "192.0.2.10",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-udp-media-tx.json",
        "--dry-run", "false",
        "--packets", "2",
        "--media", "audio-video",
        "--audio-port", "19788",
        "--video-port", "19798",
        "--channels", "2",
        "--sample-rate", "44100",
        "--frames", "64",
        "--video-width", "16",
        "--video-height", "16",
        "--video-bpp", "8",
    ])

    let report = try LoLaUdpMediaTransmitRunner.run(
        configuration: configuration,
        transmitter: sink
    )

    try report.validate()
    #expect(report.realLinkTransmitted)
    #expect(report.audioFrameCount == 2)
    #expect(report.videoFrameCount == 4)
    #expect(sink.transmittedDatagrams.count == 6)
    #expect(sink.transmittedDatagrams.map(\.port).contains(19788))
    #expect(sink.transmittedDatagrams.map(\.port).contains(19798))
    #expect(report.notes.contains("UDP sockets"))
}

@Test
func lolaUdpMediaSleepRetriesWhenInterrupted() {
    let start = DispatchTime.now()
    let deadline = start + .seconds(1)
    var nowCalls = 0
    var sleepCalls: [useconds_t] = []

    loLaUdpMediaSleepUntil(
        deadline,
        now: {
            defer { nowCalls += 1 }
            return nowCalls < 2 ? start : deadline
        },
        sleep: { microseconds in
            sleepCalls.append(microseconds)
            errno = EINTR
            return -1
        }
    )

    #expect(sleepCalls.count == 2)
    #expect(sleepCalls.allSatisfy { $0 > 0 })
}

@Test
func lolaUdpMediaSleepStopsAfterBoundedInterrupts() {
    let start = DispatchTime.now()
    let deadline = start + .seconds(1)
    var sleepCalls = 0

    loLaUdpMediaSleepUntil(
        deadline,
        now: { start },
        sleep: { _ in
            sleepCalls += 1
            errno = EINTR
            return -1
        }
    )

    #expect(sleepCalls == 1_000)
}

@Test
func lolaUdpMediaSendRetryStopsOnStructuralErrors() {
    var attempts = 0
    let result = retryLoLaUdpMediaSend {
        attempts += 1
        errno = EMSGSIZE
        return -1
    }

    #expect(result == -1)
    #expect(attempts == 1)
    #expect(errno == EMSGSIZE)
}

@Test
func lolaUdpMediaSendRetryRepeatsTransientWouldBlockErrors() {
    var attempts = 0
    let result = retryLoLaUdpMediaSend {
        attempts += 1
        if attempts < 3 {
            errno = EAGAIN
            return -1
        }
        return 12
    }

    #expect(result == 12)
    #expect(attempts == 3)
}

@Test
func lolaUdpMediaTransmitRunnerAdvertisesOutboundSourceForWildcardHost() throws {
    let configuration = try LoLaUdpMediaTransmitRunConfiguration.parse([
        "--local-host", "0.0.0.0",
        "--peer", "127.0.0.1",
        "--output", "/tmp/lola-udp-media-tx-wildcard.json",
        "--dry-run", "false",
        "--packets", "1",
        "--media", "audio",
    ])

    let report = try LoLaUdpMediaTransmitRunner.run(
        configuration: configuration,
        transmitter: LoLaMemoryUdpMediaTransmitter()
    )
    let decoded = try LoLaCompatibilityWireFrame.decode(report.frames[0].encodedFrame)

    #expect(decoded.sourceIP.octets == [127, 0, 0, 1])
}

@Test
func lolaUdpMediaReceiveRunnerDecodesPayloadsFromMemorySource() throws {
    let configuration = try LoLaUdpMediaReceiveRunConfiguration.parse([
        "--local-host", "192.0.2.10",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-udp-media-rx.json",
        "--dry-run", "false",
        "--packets", "3",
        "--media", "audio-video",
        "--timeout-seconds", "3",
    ])
    let videoPackets = try LoLaCompatibilityMediaCodec.videoPackets(
        sequenceNumber: 1,
        payload: Data(repeating: 0x22, count: 64)
    )
    let source = LoLaMemoryUdpMediaReceiver(datagrams: [
        LoLaUdpMediaDatagram(
            stream: .audio,
            port: 19788,
            payload: try LoLaCompatibilityMediaCodec.audioFragments(sequenceNumber: 1, channels: 2)[0].payload
        ),
        LoLaUdpMediaDatagram(
            stream: .video,
            port: 19798,
            payload: videoPackets[0].payload
        ),
        LoLaUdpMediaDatagram(
            stream: .video,
            port: 19798,
            payload: videoPackets[1].payload
        ),
    ])

    let report = try LoLaUdpMediaReceiveRunner.run(
        configuration: configuration,
        receiver: source
    )

    try report.validate()
    #expect(report.realLinkTransmitted)
    #expect(report.audioFrameCount == 1)
    #expect(report.videoFrameCount == 2)
    #expect(report.notes.contains("timeout 3s"))
}

@Test
func lolaUdpMediaReceiveRunnerReturnsStructuredTimeoutReport() throws {
    let configuration = try LoLaUdpMediaReceiveRunConfiguration.parse([
        "--local-host", "10.230.61.175",
        "--peer", "10.230.61.175",
        "--output", "/tmp/lola-udp-media-rx-timeout.json",
        "--dry-run", "false",
        "--packets", "2",
        "--media", "audio-video",
        "--audio-port", "19788",
        "--video-port", "19798",
        "--timeout-seconds", "5",
    ])

    let report = try LoLaUdpMediaReceiveRunner.run(
        configuration: configuration,
        receiver: LoLaTimeoutUdpMediaReceiver()
    )

    try report.validate()
    #expect(report.id == "lola-udp-media-rx-timeout")
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == "receiveTimedOut")
    #expect(report.frames.isEmpty)
    #expect(report.realLinkTransmitted)
    #expect(report.localHost == "10.230.61.175")
    #expect(report.peer == "10.230.61.175")
    #expect(report.audioPort == 19788)
    #expect(report.videoPort == 19798)
    #expect(report.timeoutSeconds == 5)
    #expect(report.expectedDatagramCount == 2)
}

@Test
func lolaUdpMediaReceiveRunnerReturnsStructuredValidationFailureReport() throws {
    let configuration = try LoLaUdpMediaReceiveRunConfiguration.parse([
        "--local-host", "192.0.2.10",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-udp-media-rx-invalid.json",
        "--dry-run", "false",
        "--packets", "1",
        "--media", "video",
        "--timeout-seconds", "4",
    ])
    let videoFragmentWithoutPrelude = try LoLaCompatibilityMediaCodec.videoPackets(
        sequenceNumber: 1,
        payload: Data(repeating: 0x32, count: 64)
    )[1]
    let source = LoLaMemoryUdpMediaReceiver(datagrams: [
        LoLaUdpMediaDatagram(
            stream: .video,
            port: 19798,
            sourceHost: "192.0.2.20",
            payload: videoFragmentWithoutPrelude.payload
        ),
    ])

    let report = try LoLaUdpMediaReceiveRunner.run(
        configuration: configuration,
        receiver: source
    )

    try report.validate()
    #expect(report.id == "lola-udp-media-rx-failure")
    #expect(report.verdict == .fail)
    #expect(report.runtimeError?.contains("missingVideoPrelude") == true)
    #expect(report.frames.isEmpty)
    #expect(report.realLinkTransmitted)
    #expect(report.localHost == "192.0.2.10")
    #expect(report.peer == "192.0.2.20")
    #expect(report.audioPort == 19788)
    #expect(report.videoPort == 19798)
    #expect(report.timeoutSeconds == 4)
    #expect(report.expectedDatagramCount == 1)
}

@Test
func lolaUdpMediaReceiveRunnerFiltersDatagramsByConfiguredPeerSource() throws {
    let configuration = try LoLaUdpMediaReceiveRunConfiguration.parse([
        "--local-host", "192.0.2.10",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-udp-media-rx-filtered.json",
        "--dry-run", "false",
        "--packets", "1",
        "--media", "audio",
    ])
    let source = LoLaMemoryUdpMediaReceiver(datagrams: [
        LoLaUdpMediaDatagram(
            stream: .audio,
            port: 19788,
            sourceHost: "198.51.100.77",
            payload: try LoLaCompatibilityMediaCodec.audioFragments(sequenceNumber: 1, channels: 2)[0].payload
        ),
        LoLaUdpMediaDatagram(
            stream: .audio,
            port: 19788,
            sourceHost: "192.0.2.20",
            payload: try LoLaCompatibilityMediaCodec.audioFragments(sequenceNumber: 2, channels: 2)[0].payload
        ),
    ])

    let report = try LoLaUdpMediaReceiveRunner.run(
        configuration: configuration,
        receiver: source
    )

    try report.validate()
    #expect(report.audioFrameCount == 1)
    let decoded = try LoLaCompatibilityWireFrame.decode(try #require(report.frames.first).encodedFrame)
    let fragment = try #require(LoLaCompatibilityMediaCodec.decode(decoded.payload).normalFragment)
    #expect(try #require(fragment.body).sequence == 2)
}

@Test
func lolaUdpMediaBidirectionalRunnerSendsAndReceivesThroughUdpSockets() throws {
    let sink = LoLaMemoryUdpMediaTransmitter()
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .txRx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-udp-media-tx-rx.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 3,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8,
        mediaPacketCount: 1
    )
    let source = LoLaMemoryUdpMediaReceiver(datagrams: [
        LoLaUdpMediaDatagram(
            stream: .audio,
            port: 19788,
            sourceHost: "192.0.2.20",
            payload: try LoLaCompatibilityMediaCodec.audioFragments(sequenceNumber: 1, channels: 2)[0].payload
        ),
        LoLaUdpMediaDatagram(
            stream: .video,
            port: 19798,
            sourceHost: "192.0.2.20",
            payload: try LoLaCompatibilityMediaCodec.videoPackets(sequenceNumber: 1, payload: Data(repeating: 0x32, count: 64))[0].payload
        ),
        LoLaUdpMediaDatagram(
            stream: .video,
            port: 19798,
            sourceHost: "192.0.2.20",
            payload: try LoLaCompatibilityMediaCodec.videoPackets(sequenceNumber: 1, payload: Data(repeating: 0x32, count: 64))[1].payload
        ),
    ])

    let report = try LoLaUdpMediaBidirectionalRunner.run(
        configuration: configuration,
        transmitter: sink,
        receiver: source
    )

    try report.validate()
    #expect(report.id == "lola-udp-media-tx-rx")
    #expect(report.role == LoLaCompatibilityMediaSessionRole.txRx)
    #expect(report.realLinkTransmitted)
    #expect(report.audioFrameCount == 2)
    #expect(report.videoFrameCount == 4)
    #expect(sink.transmittedDatagrams.count == 3)
    #expect(report.notes.contains("TX-RX"))
}
