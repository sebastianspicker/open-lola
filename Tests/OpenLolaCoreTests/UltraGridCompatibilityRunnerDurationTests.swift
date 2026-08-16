// Verifies that UltraGrid duration-bounded sessions share deadlines and ignore packet-count completion.
import Foundation
import Testing

@testable import OpenLolaCore

final class UltraGridDeadlineCapturingReceiver: UltraGridCompatibilityMediaReceiving {
    private(set) var deadlineNanoseconds: UInt64?

    func receive(_: UltraGridMediaReceiveRequest) throws -> [UltraGridCompatibilityDatagram] { [] }

    func receiveWhileBound(
        _ request: UltraGridMediaReceiveRequest,
        transmit: @escaping () throws -> UltraGridCompatibilityTransmitResult
    ) throws -> (transmitted: Int, received: UltraGridCompatibilityReceiveResult) {
        deadlineNanoseconds = request.deadlineNanoseconds
        let transmitResult = try transmit()
        return (transmitResult.successfulDatagramCount, UltraGridCompatibilityReceiveResult(datagrams: []))
    }
}

@Test
func ultraGridDurationModeOutlivesTheDefaultSinglePacketBound() throws {
    let deadline: UInt64 = 25_000_000
    let clock = UltraGridTestMonotonicClock()
    let runtimeDeadline = UltraGridRuntimeDeadline(
        deadlineNanoseconds: deadline,
        nowNanoseconds: { clock.nowNanoseconds() }
    )
    var durationModeSequences: [UInt16] = []
    var durationConfiguration = ultraGridPacingConfiguration(mode: .audio, packetCount: 1)
    durationConfiguration.durationBoundedRuntime = true
    try UltraGridCompatibilityDatagramBuilder.forEachDatagram(
        configuration: durationConfiguration,
        mediaProvider: UltraGridDeadlineAwareTestProvider(),
        deadline: runtimeDeadline,
        clock: clock
    ) { durationModeSequences.append($0.rtp.header.sequenceNumber) }

    #expect(durationModeSequences == [0, 1, 2])

    var packetModeSequences: [UInt16] = []
    try UltraGridCompatibilityDatagramBuilder.forEachDatagram(
        configuration: ultraGridPacingConfiguration(mode: .audio, packetCount: 1),
        mediaProvider: UltraGridSyntheticMediaProvider(),
        clock: UltraGridTestMonotonicClock()
    ) { packetModeSequences.append($0.rtp.header.sequenceNumber) }
    #expect(packetModeSequences == [0])
}

@Test
func ultraGridFullDuplexDurationModeSharesTheInjectedAbsoluteDeadline() throws {
    let deadlineNanoseconds: UInt64 = 25_000_000
    let clock = UltraGridTestMonotonicClock()
    let deadline = UltraGridRuntimeDeadline(
        deadlineNanoseconds: deadlineNanoseconds,
        nowNanoseconds: { clock.nowNanoseconds() }
    )
    var configuration = ultraGridPacingConfiguration(mode: .audio, packetCount: 1)
    configuration.role = .txRx
    configuration.durationBoundedRuntime = true
    let receiver = UltraGridDeadlineCapturingReceiver()
    let payloadRegistry = try UltraGridCompatibilityRuntimeConfiguration.payloadRegistry(configuration)

    let exchange = try UltraGridCompatibilityRunner.runMediaExchange(.init(
        configuration: configuration,
        transmitter: UltraGridMemoryMediaTransmitter(),
        receiver: receiver,
        mediaProvider: UltraGridDeadlineAwareTestProvider(),
        payloadRegistry: payloadRegistry,
        fullDuplexLifecycleLease: nil,
        previewAdapter: nil,
        audioPlayout: nil,
        durationDeadline: deadline,
        clock: clock
    ))

    #expect(receiver.deadlineNanoseconds == deadlineNanoseconds)
    #expect(exchange.transmittedDatagramCount == 3)
}

@Test
func ultraGridDurationModeReceiveDoesNotStopAtTheFirstPacket() throws {
    var configuration = ultraGridPacingConfiguration(mode: .audio, packetCount: 2)
    configuration.durationBoundedRuntime = true
    let datagrams = try UltraGridCompatibilityRunner.buildDatagrams(configuration: configuration)
    let receiver = UltraGridMemoryMediaReceiver(datagrams: datagrams)
    let registry = try UltraGridCompatibilityRuntimeConfiguration.payloadRegistry(configuration)
    let durationResult = try receiver.receiveResult(UltraGridMediaReceiveRequest(
        expectedDatagrams: 1,
        localHost: configuration.localHost,
        peer: configuration.peer,
        audioPort: configuration.audioPort,
        videoPort: configuration.videoPort,
        payloadRegistry: registry,
        encryptionConfiguration: nil,
        timeoutSeconds: configuration.durationSeconds,
        runUntilDeadline: true
    ))
    #expect(durationResult.receivedDatagramCount == 2)

    let packetResult = try receiver.receiveResult(UltraGridMediaReceiveRequest(
        expectedDatagrams: 1,
        localHost: configuration.localHost,
        peer: configuration.peer,
        audioPort: configuration.audioPort,
        videoPort: configuration.videoPort,
        payloadRegistry: registry,
        encryptionConfiguration: nil,
        timeoutSeconds: configuration.durationSeconds
    ))
    #expect(packetResult.receivedDatagramCount == 1)
}

private struct UltraGridDeadlineAwareTestProvider: UltraGridMediaProviding {
    func audioPCM(sequenceNumber _: Int, channels: Int, framesPerPacket: Int) throws -> Data {
        Data(repeating: 0, count: channels * framesPerPacket * MemoryLayout<Int16>.size)
    }

    func audioPCM(
        sequenceNumber: Int,
        channels: Int,
        framesPerPacket: Int,
        deadlineNanoseconds _: UInt64?
    ) throws -> Data {
        try audioPCM(sequenceNumber: sequenceNumber, channels: channels, framesPerPacket: framesPerPacket)
    }

    func videoFrame(frameID _: Int, width _: Int, height _: Int, bitsPerPixel _: Int) throws -> Data { Data() }

    func videoFrame(
        frameID: Int,
        width: Int,
        height: Int,
        bitsPerPixel: Int,
        deadlineNanoseconds _: UInt64?
    ) throws -> Data {
        try videoFrame(frameID: frameID, width: width, height: height, bitsPerPixel: bitsPerPixel)
    }
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
