// Verifies that UltraGrid compatibility runner builds native TX RX reports.
import Foundation
import Testing

@testable import OpenLolaCore

final class UltraGridStreamingOrderProbe {
    var emittedDatagramCount = 0
    var capturedAheadOfTransmit = false
    var requiresReceiverBound = false
    var receiverBound = false
    var transmitStartedBeforeReceiverBound = false
}

final class UltraGridLiveSchedulingProbeProvider:
    UltraGridMediaProviding {
    var captureOrder: [String] = []

    func audioPCM(sequenceNumber _: Int, channels: Int, framesPerPacket: Int) throws -> Data {
        captureOrder.append("audio")
        return Data(repeating: 0, count: channels * framesPerPacket * MemoryLayout<Int16>.size)
    }

    func videoFrame(frameID _: Int, width: Int, height: Int, bitsPerPixel: Int) throws -> Data {
        captureOrder.append("video")
        return Data(repeating: 0, count: max(1, width * height * max(1, bitsPerPixel / 8)))
    }
}

struct UltraGridStreamingOrderProvider: UltraGridMediaProviding {
    let probe: UltraGridStreamingOrderProbe

    func audioPCM(sequenceNumber: Int, channels: Int, framesPerPacket: Int) throws -> Data {
        if probe.emittedDatagramCount < sequenceNumber {
            probe.capturedAheadOfTransmit = true
        }
        return Data(repeating: 0, count: channels * framesPerPacket * MemoryLayout<Int16>.size)
    }

    func audioPCM(
        sequenceNumber: Int,
        channels: Int,
        framesPerPacket: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        if let deadlineNanoseconds,
           DispatchTime.now().uptimeNanoseconds >= deadlineNanoseconds {
            throw UltraGridCompatibilityError.receiveTimeout(expected: 0, actual: 0)
        }
        return try audioPCM(
            sequenceNumber: sequenceNumber,
            channels: channels,
            framesPerPacket: framesPerPacket
        )
    }

    func videoFrame(frameID _: Int, width: Int, height: Int, bitsPerPixel: Int) throws -> Data {
        Data(repeating: 0, count: max(1, width * height * max(1, bitsPerPixel / 8)))
    }

    func videoFrame(
        frameID: Int,
        width: Int,
        height: Int,
        bitsPerPixel: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        if let deadlineNanoseconds,
           DispatchTime.now().uptimeNanoseconds >= deadlineNanoseconds {
            throw UltraGridCompatibilityError.receiveTimeout(expected: 0, actual: 0)
        }
        return try videoFrame(
            frameID: frameID,
            width: width,
            height: height,
            bitsPerPixel: bitsPerPixel
        )
    }
}

struct UltraGridStreamingOrderTransmitter: UltraGridCompatibilityMediaTransmitting {
    let probe: UltraGridStreamingOrderProbe

    func transmit(
        _ datagrams: [UltraGridCompatibilityDatagram],
        localHost _: String,
        peer _: String
    ) throws -> Int {
        probe.emittedDatagramCount += datagrams.count
        return datagrams.count
    }

    func transmitGenerated(
        localHost _: String,
        peer _: String,
        generate: (_ emit: (UltraGridCompatibilityDatagram) throws -> Void) throws -> Void
    ) throws -> Int {
        if probe.requiresReceiverBound, !probe.receiverBound {
            probe.transmitStartedBeforeReceiverBound = true
        }
        try generate { _ in probe.emittedDatagramCount += 1 }
        return probe.emittedDatagramCount
    }
}

struct UltraGridZeroSendTransmitter: UltraGridCompatibilityMediaTransmitting {
    func transmit(
        _ datagrams: [UltraGridCompatibilityDatagram],
        localHost _: String,
        peer _: String
    ) throws -> Int {
        0
    }

    func transmitGenerated(
        localHost _: String,
        peer _: String,
        generate: (_ emit: (UltraGridCompatibilityDatagram) throws -> Void) throws -> Void
    ) throws -> Int {
        try generate { _ in }
        return 0
    }
}

struct UltraGridCountedEvidenceReceiver: UltraGridCompatibilityMediaReceiving {
    let result: UltraGridCompatibilityReceiveResult

    func receive(_: UltraGridMediaReceiveRequest) throws -> [UltraGridCompatibilityDatagram] {
        result.datagrams
    }

    func receiveResult(_: UltraGridMediaReceiveRequest) throws -> UltraGridCompatibilityReceiveResult {
        result
    }
}

struct UltraGridFailingMediaProvider: UltraGridMediaProviding {
    func audioPCM(sequenceNumber _: Int, channels _: Int, framesPerPacket _: Int) throws -> Data {
        throw TestFailure()
    }

    func videoFrame(frameID _: Int, width _: Int, height _: Int, bitsPerPixel _: Int) throws -> Data {
        throw TestFailure()
    }

    private struct TestFailure: Error {}
}

final class UltraGridLegacyBlockingMediaProvider: UltraGridMediaProviding {
    private let lock = NSLock()
    private(set) var legacyAudioCallCount = 0

    func audioPCM(sequenceNumber _: Int, channels _: Int, framesPerPacket _: Int) throws -> Data {
        lock.lock()
        legacyAudioCallCount += 1
        lock.unlock()
        _ = DispatchSemaphore(value: 0).wait(timeout: .now() + .seconds(1))
        return Data()
    }

    func videoFrame(frameID _: Int, width _: Int, height _: Int, bitsPerPixel _: Int) throws -> Data {
        Data()
    }
}

final class UltraGridTestMonotonicClock: UltraGridMonotonicClock {
    private let clockState: TestMonotonicClockState

    init(now: UInt64 = 0) { clockState = TestMonotonicClockState(now: now) }

    var now: UInt64 { clockState.now }

    func nowNanoseconds() -> UInt64 { clockState.now }

    func sleep(untilNanoseconds: UInt64) throws { clockState.advance(toAtLeast: untilNanoseconds) }

    func advance(by nanoseconds: UInt64) { clockState.advance(by: nanoseconds) }
}

final class UltraGridFirstAudioCaptureOverrunProvider: UltraGridMediaProviding {
    let clock: UltraGridTestMonotonicClock

    init(clock: UltraGridTestMonotonicClock) { self.clock = clock }

    func audioPCM(sequenceNumber: Int, channels: Int, framesPerPacket: Int) throws -> Data {
        if sequenceNumber == 0 { clock.advance(by: 35_000_000) }
        return Data(repeating: 0, count: channels * framesPerPacket * MemoryLayout<Int16>.size)
    }

    func videoFrame(frameID _: Int, width _: Int, height _: Int, bitsPerPixel _: Int) throws -> Data {
        Data([0])
    }
}

struct UltraGridBoundOrderReceiver: UltraGridCompatibilityMediaReceiving {
    let probe: UltraGridStreamingOrderProbe

    func receive(_: UltraGridMediaReceiveRequest) throws -> [UltraGridCompatibilityDatagram] {
        []
    }

    func receiveWhileBound(
        _ request: UltraGridMediaReceiveRequest,
        transmit: @escaping () throws -> UltraGridCompatibilityTransmitResult
    ) throws -> (transmitted: Int, received: UltraGridCompatibilityReceiveResult) {
        probe.receiverBound = true
        return (
            try transmit().successfulDatagramCount,
            UltraGridCompatibilityReceiveResult(datagrams: [])
        )
    }
}

@Test
func ultraGridCompatibilityRunnerBuildsNativeTxRxReports() throws {
    let fixture = try ultraGridNativeTxRxFixture()

    let report = try UltraGridCompatibilityRunner.run(
        configuration: fixture.configuration,
        transmitter: fixture.transmitter,
        receiver: fixture.receiver
    )

    try report.validate()
    #expect(report.transmittedDatagramCount == fixture.datagrams.count)
    #expect(report.receivedDatagramCount == fixture.datagrams.count)
    #expect(report.audioDatagramCount == 1)
    #expect(report.videoDatagramCount >= 1)
    #expect(!report.unsupportedModes.contains("fec"))
}

@Test
func ultraGridFullDuplexDeadlineRejectsLegacyProviderWithoutCallingIt() throws {
    let provider = UltraGridLegacyBlockingMediaProvider()
    let started = Date()

    #expect(throws: ExternalConnectorSessionError.unsupportedRuntimeMode(
        "ultragrid-full-duplex-provider-without-deadline"
    )) {
        _ = try UltraGridCompatibilityRunner.run(
            configuration: ExternalConnectorSessionConfiguration(.init(
                connector: .mvtpUltraGrid,
                role: .txRx,
                peer: "203.0.113.20",
                outputPath: "/tmp/ultragrid-legacy-provider-deadline.json"
            ) { input in
                input.dryRun = true
                input.mediaMode = .audio
                input.mediaPacketCount = 1
            }),
            transmitter: UltraGridMemoryMediaTransmitter(),
            receiver: UltraGridMemoryMediaReceiver(datagrams: []),
            mediaProvider: provider
        )
    }

    #expect(provider.legacyAudioCallCount == 0)
    #expect(Date().timeIntervalSince(started) < 0.5)
}

@Test
func ultraGridNeverReturningTransmitterDoesNotBlockDeadlineAndRetainsClosure() throws {
    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    var retained: UltraGridStreamingOrderProbe? = UltraGridStreamingOrderProbe()
    weak let weakRetained = retained
    let state = UltraGridConcurrentReceiveState(timeoutSeconds: 1)
    let task = UltraGridConcurrentTransmitTask(transmit: { [retained] in
        _ = retained
        started.signal()
        release.wait()
        return UltraGridCompatibilityTransmitResult(
            successfulDatagramCount: 0,
            attemptedDatagramCount: 0
        )
    }, state: state)
    retained = nil
    task.start()
    #expect(started.wait(timeout: .now() + .seconds(1)) == .success)

    #expect(task.wait(
        untilNanoseconds: DispatchTime.now().uptimeNanoseconds + 1_000_000
    ) == .timedOut)
    #expect(weakRetained != nil)

    // Cleanup only: the simulated transmitter has no production completion path.
    release.signal()
    #expect(task.wait(
        untilNanoseconds: DispatchTime.now().uptimeNanoseconds + 1_000_000_000
    ) == .success)
}

@Test
func ultraGridPacingKeepsIndependentAudioVideoSlotsAndDropsOverrunCatchUp() throws {
    let clock = UltraGridTestMonotonicClock()
    var audioSendTimes: [UInt64] = []
    var videoSendTimes: [UInt64] = []
    try UltraGridCompatibilityDatagramBuilder.forEachDatagram(
        configuration: ultraGridPacingConfiguration(mode: .audioVideo, packetCount: 4),
        mediaProvider: UltraGridSyntheticMediaProvider(),
        clock: clock
    ) { datagram in
        if datagram.stream == .audio {
            audioSendTimes.append(clock.nowNanoseconds())
        } else if datagram.rtp.header.marker {
            videoSendTimes.append(clock.nowNanoseconds())
        }
    }

    #expect(audioSendTimes == [0, 10_000_000, 20_000_000, 30_000_000])
    #expect(videoSendTimes == [0, 40_000_000, 80_000_000, 120_000_000])

    let overrunClock = UltraGridTestMonotonicClock()
    var overrunSendTimes: [UInt64] = []
    var sequences: [UInt16] = []
    try UltraGridCompatibilityDatagramBuilder.forEachDatagram(
        configuration: ultraGridPacingConfiguration(mode: .audio, packetCount: 7),
        mediaProvider: UltraGridFirstAudioCaptureOverrunProvider(clock: overrunClock),
        clock: overrunClock
    ) { datagram in
        overrunSendTimes.append(overrunClock.nowNanoseconds())
        sequences.append(datagram.rtp.header.sequenceNumber)
    }

    #expect(sequences == [3, 5, 6])
    #expect(zip(overrunSendTimes, overrunSendTimes.dropFirst()).allSatisfy { later, earlier in
        earlier - later >= 10_000_000
    })
}

private func ultraGridPacingConfiguration(
    mode: ExternalConnectorMediaMode,
    packetCount: Int
) -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "203.0.113.20",
        outputPath: "/tmp/ultragrid-pacing.json"
    ) { input in
        input.dryRun = false
        input.mediaMode = mode
        input.sampleRateHertz = 1_000
        input.framesPerPacket = 10
        input.videoFrameRate = 25
        input.videoWidth = 1
        input.videoHeight = 1
        input.videoBitsPerPixel = 8
        input.mediaPacketCount = packetCount
    })
}

@Test
func ultraGridCompatibilityRunnerReportsSyntheticEvidenceAndSinkCounts() throws {
    let fixture = try ultraGridNativeTxRxFixture()

    let report = try UltraGridCompatibilityRunner.run(
        configuration: fixture.configuration,
        transmitter: fixture.transmitter,
        receiver: fixture.receiver
    )

    #expect(report.provider.audioSource == "synthetic")
    #expect(report.provider.videoSource == "synthetic")
    #expect(report.observedEvidenceClasses == [.synthetic])
    #expect(report.missingEvidenceClassesForPass == ExternalConnectorEvidenceClass.runtimePassRequiredEvidence)
    #expect(report.sink.audioPacketCount == 1)
    #expect(report.sink.audioPayloadByteCount == fixture.configuration.channels * fixture.configuration.framesPerPacket * 2)
    #expect(report.sink.videoFrameCount == 1)
    #expect(report.sink.videoPayloadByteCount == fixture.configuration.videoWidth * fixture.configuration.videoHeight)
    #expect(report.sink.rejectedMediaCount == 0)
    #expect(report.realLinkTransmitted)
    #expect(fixture.transmitter.transmittedDatagrams.count == fixture.datagrams.count)
}

private struct UltraGridNativeTxRxFixture {
    var configuration: ExternalConnectorSessionConfiguration
    var datagrams: [UltraGridCompatibilityDatagram]
    var transmitter: UltraGridMemoryMediaTransmitter
    var receiver: UltraGridMemoryMediaReceiver
}

private func ultraGridNativeTxRxFixture() throws -> UltraGridNativeTxRxFixture {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .txRx,
        peer: "127.0.0.1",
        outputPath: "/tmp/ug-native.json"
    ) { input in
        input.localHost = "127.0.0.1"
        input.dryRun = false
        input.mediaMode = .audioVideo
        input.audioPort = 50_006
        input.videoPort = 50_004
        input.videoWidth = 16
        input.videoHeight = 16
        input.videoFrameRate = 30
        input.videoBitsPerPixel = 8
        input.mediaPacketCount = 1
    })
    let datagrams = try UltraGridCompatibilityRunner.buildDatagrams(configuration: configuration)
    let transmitter = UltraGridMemoryMediaTransmitter()
    let receiver = UltraGridMemoryMediaReceiver(datagrams: datagrams.map {
        UltraGridCompatibilityDatagram(
            stream: $0.stream,
            sourceHost: "127.0.0.1",
            sourcePort: 40_000,
            destinationPort: $0.destinationPort,
            rtp: $0.rtp
        )
    })
    return UltraGridNativeTxRxFixture(
        configuration: configuration,
        datagrams: datagrams,
        transmitter: transmitter,
        receiver: receiver
    )
}

@Test
func ultraGridServerClientTopologyListensWithoutPeerAndReportsPartialEvidence() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .rx,
        peer: "",
        outputPath: "/tmp/ug-server.json"
    ) { input in
        input.localHost = "0.0.0.0"
        input.dryRun = false
        input.mediaMode = .audio
        input.audioPort = 50_006
        input.mediaPacketCount = 1
        input.ultraGridTopologyMode = .serverClient
        input.ultraGridTopologyRole = .server
    })
    let received = [
        try ultraGridAudioDatagram(sequence: 0, timestamp: 0, ssrc: 1)
    ]
    let report = try UltraGridCompatibilityRunner.run(
        configuration: configuration,
        transmitter: UltraGridMemoryMediaTransmitter(),
        receiver: UltraGridMemoryMediaReceiver(datagrams: received)
    )

    try report.validate()
    #expect(report.topology.mode == .serverClient)
    #expect(report.topology.role == .server)
    #expect(report.topology.state == .serverListening)
    #expect(!report.topology.peerRequired)
    #expect(!report.topology.peerConfigured)
    #expect(report.receivedDatagramCount == 1)
    #expect(report.verdict == .partial)
    #expect(report.missingEvidenceClassesForPass.contains(.fieldRoute))
}

@Test
func ultraGridPhysicalServerTransmitRequiresExplicitPeer() {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "",
        outputPath: "/tmp/ug-server-tx.json"
    ) { input in
        input.dryRun = false
        input.mediaMode = .audio
        input.ultraGridTopologyMode = .serverClient
        input.ultraGridTopologyRole = .server
    })

    #expect(throws: ExternalConnectorSessionError.connectorRequiresPeerForTx(.mvtpUltraGrid)) {
        _ = try UltraGridCompatibilityRunner.run(
            configuration: configuration,
            transmitter: UltraGridMemoryMediaTransmitter(),
            receiver: UltraGridMemoryMediaReceiver(datagrams: [])
        )
    }
}

@Test
func ultraGridServerClientClientRequiresPeer() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "",
        outputPath: "/tmp/ug-client.json"
    ) { input in
        input.mediaMode = .audio
        input.ultraGridTopologyMode = .serverClient
        input.ultraGridTopologyRole = .client
    })

    #expect(throws: ExternalConnectorSessionError.connectorRequiresPeerForTx(.mvtpUltraGrid)) {
        _ = try UltraGridCompatibilityRunner.run(
            configuration: configuration,
            transmitter: UltraGridMemoryMediaTransmitter(),
            receiver: UltraGridMemoryMediaReceiver(datagrams: [])
        )
    }
}
