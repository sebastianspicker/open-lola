// Covers deterministic provider, in-memory transport, report, and parser branches without live I/O.
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func wave15SyntheticProviderReportIsSynthetic() {
    let report = UltraGridSyntheticMediaProvider().providerReport
    #expect(report.audioSource == "synthetic")
    #expect(report.videoSource == "synthetic")
    #expect(report.observedEvidenceClasses == [.synthetic])
}

@Test
func wave15SyntheticProviderSizesAudioPayload() throws {
    let payload = try UltraGridSyntheticMediaProvider().audioPCM(
        sequenceNumber: 9, channels: 2, framesPerPacket: 4
    )
    #expect(payload == Data(repeating: 0, count: 16))
}

@Test
func wave15SyntheticProviderClampsZeroAudioPayload() throws {
    let payload = try UltraGridSyntheticMediaProvider().audioPCM(
        sequenceNumber: 1, channels: 0, framesPerPacket: 0
    )
    #expect(payload.count == 1)
}

@Test
func wave15SyntheticProviderBuildsRepeatedVideoPattern() throws {
    let payload = try UltraGridSyntheticMediaProvider().videoFrame(
        frameID: 7, width: 3, height: 2, bitsPerPixel: 8
    )
    #expect(payload == Data([0, 1, 2, 3, 4, 5]))
}

@Test
func wave15SyntheticProviderClampsZeroVideoPayload() throws {
    let payload = try UltraGridSyntheticMediaProvider().videoFrame(
        frameID: 7, width: 0, height: 0, bitsPerPixel: 0
    )
    #expect(payload == Data([0]))
}

@Test
func wave15SyntheticProviderAcceptsNilAndFutureDeadlines() throws {
    let provider = UltraGridSyntheticMediaProvider()
    #expect(try provider.audioPCM(sequenceNumber: 1, channels: 1, framesPerPacket: 1,
        deadlineNanoseconds: nil).count == 2)
    #expect(try provider.videoFrame(frameID: 1, width: 1, height: 1, bitsPerPixel: 8,
        deadlineNanoseconds: DispatchTime.now().uptimeNanoseconds + 1_000_000_000) == Data([0]))
}

@Test
func wave15SyntheticProviderRejectsExpiredDeadline() {
    let past = DispatchTime.now().uptimeNanoseconds - 1
    #expect(throws: UltraGridCompatibilityError.receiveTimeout(expected: 0, actual: 0)) {
        _ = try UltraGridSyntheticMediaProvider().audioPCM(
            sequenceNumber: 1, channels: 1, framesPerPacket: 1, deadlineNanoseconds: past
        )
    }
}

@Test
func wave15SessionProviderSelectsSyntheticWithoutStart() throws {
    let provider = try UltraGridSessionMediaProvider(configuration: wave15UltraGridConfiguration())
    #expect(try provider.audioPCM(sequenceNumber: 1, channels: 1, framesPerPacket: 2) == Data(repeating: 0, count: 4))
    #expect(provider.providerReport.audioSource == "synthetic")
    #expect(provider.providerReport.videoSource == "synthetic")
}

@Test
func wave15SessionProviderRepeatsAudioFixtureWithoutStart() throws {
    let provider = try UltraGridSessionMediaProvider(configuration: wave15UltraGridConfiguration { input in
        input.audioCapture = "fixture:0102"
    })
    #expect(try provider.audioPCM(sequenceNumber: 1, channels: 1, framesPerPacket: 3) == Data([1, 2, 1, 2, 1, 2]))
    #expect(provider.providerReport.audioSource == "fixture")
}

@Test
func wave15SessionProviderReturnsVideoFixtureWithoutStart() throws {
    let provider = try UltraGridSessionMediaProvider(configuration: wave15UltraGridConfiguration { input in
        input.videoCapture = "fixture:010203"
    })
    #expect(try provider.videoFrame(frameID: 2, width: 99, height: 99, bitsPerPixel: 32) == Data([1, 2, 3]))
    #expect(provider.providerReport.videoSource == "fixture")
}

@Test
func wave15SessionProviderRejectsExpiredDeadlineBeforeFixture() throws {
    let provider = try UltraGridSessionMediaProvider(configuration: wave15UltraGridConfiguration { input in
        input.audioCapture = "fixture:01"
    })
    #expect(throws: UltraGridCompatibilityError.receiveTimeout(expected: 0, actual: 0)) {
        _ = try provider.audioPCM(sequenceNumber: 1, channels: 1, framesPerPacket: 1,
            deadlineNanoseconds: DispatchTime.now().uptimeNanoseconds - 1)
    }
}

@Test
func wave15TransmitterExtensionCollectsGeneratedDatagrams() throws {
    let transmitter = Wave15Transmitter()
    let count = try transmitter.transmitGenerated(localHost: "local", peer: "peer") { emit in
        try emit(wave15Datagram(sequence: 1, port: 5_000))
        try emit(wave15Datagram(sequence: 2, port: 5_001))
    }
    #expect(count == 2)
    #expect(transmitter.datagrams.map(\.rtp.header.sequenceNumber) == [1, 2])
}

@Test
func wave15ReceiverExtensionBuildsResultFromReceive() throws {
    let receiver = Wave15Receiver(datagrams: [wave15Datagram(sequence: 3, port: 5_000)])
    let result = try receiver.receiveResult(wave15ReceiveRequest())
    #expect(result.receivedDatagramCount == 1)
    #expect(result.datagrams.map(\.rtp.header.sequenceNumber) == [3])
}

@Test
func wave15ReceiverExtensionRunsTransmitWhileBound() throws {
    let receiver = Wave15Receiver(datagrams: [wave15Datagram(sequence: 4, port: 5_000)])
    let outcome = try receiver.receiveWhileBound(wave15ReceiveRequest()) {
        .init(successfulDatagramCount: 2, attemptedDatagramCount: 3)
    }
    #expect(outcome.transmitted == 2)
    #expect(outcome.received.receivedDatagramCount == 1)
}

@Test
func wave15MemoryReceiverFiltersPeerAndPorts() throws {
    let receiver = UltraGridMemoryMediaReceiver(datagrams: [
        wave15Datagram(sequence: 1, source: "peer", port: 5_000),
        wave15Datagram(sequence: 2, source: "other", port: 5_000),
        wave15Datagram(sequence: 3, source: "peer", port: 5_002),
        wave15Datagram(sequence: 4, source: nil, port: 5_001)
    ])
    let received = try receiver.receive(wave15ReceiveRequest(expected: 9))
    #expect(received.map(\.rtp.header.sequenceNumber) == [1, 4])
}

@Test
func wave15MemoryReceiverHonorsZeroExpectedAndWildcardPeer() throws {
    let receiver = UltraGridMemoryMediaReceiver(datagrams: [
        wave15Datagram(sequence: 1, source: "first", port: 5_000),
        wave15Datagram(sequence: 2, source: "second", port: 5_001)
    ])
    let request = wave15ReceiveRequest(expected: 0, peer: "0.0.0.0")
    #expect(try receiver.receive(request).map(\.rtp.header.sequenceNumber) == [1, 2])
}

@Test
func wave15MemoryReceiverCapsExpectedDatagrams() throws {
    let receiver = UltraGridMemoryMediaReceiver(datagrams: [
        wave15Datagram(sequence: 1, port: 5_000), wave15Datagram(sequence: 2, port: 5_001)
    ])
    #expect(try receiver.receive(wave15ReceiveRequest(expected: 1)).count == 1)
}

@Test
func wave15DropStateDropsBlockedVideoFrameAndOptionalFEC() {
    var state = UltraGridSocketTransmitDropState()
    let first = wave15Datagram(sequence: 1, port: 5_001, stream: .video, marker: false, payloadType: 20)
    let last = wave15Datagram(sequence: 2, port: 5_001, stream: .video, marker: true, payloadType: 20)
    let fec = wave15Datagram(sequence: 3, port: 5_001, stream: .video, marker: false,
        payloadType: UltraGridCompatibility.fecPayloadType)
    state.recordWouldBlock(first)
    let dropsFirst = state.shouldAttempt(first)
    let dropsLast = state.shouldAttempt(last)
    let dropsFEC = state.shouldAttempt(fec)
    let keepsAudio = state.shouldAttempt(
        wave15Datagram(sequence: 4, port: 5_000, stream: .audio, marker: false, payloadType: 21)
    )
    #expect(!dropsFirst)
    #expect(!dropsLast)
    #expect(!dropsFEC)
    #expect(keepsAudio)
}

@Test
func wave15ReceiveLedgerRetainsEvidenceCapAndCount() {
    var ledger = UltraGridSocketReceiveEvidenceLedger(evidenceLimit: 1)
    ledger.record(wave15Datagram(sequence: 1, port: 5_000))
    ledger.record(wave15Datagram(sequence: 2, port: 5_000))
    #expect(ledger.receivedDatagramCount == 2)
    #expect(ledger.evidence.map(\.rtp.header.sequenceNumber) == [1])
}

@Test
func wave15DrainBudgetStopsAtLimit() {
    var budget = UltraGridSocketReceiveDrainBudget(limit: 1)
    #expect(budget.hasCapacity)
    budget.recordProcessedDatagram()
    budget.recordProcessedDatagram()
    #expect(!budget.hasCapacity)
    #expect(budget.processed == 1)
}

@Test
func wave15FullDuplexCompletionRequiresTransmissionAndExpectedCount() {
    #expect(!ultraGridFullDuplexReceiveIsComplete(
        transmissionFinished: false, expectedDatagrams: 1, receivedDatagramCount: 1
    ))
    #expect(!ultraGridFullDuplexReceiveIsComplete(
        transmissionFinished: true, expectedDatagrams: nil, receivedDatagramCount: 9
    ))
    #expect(ultraGridFullDuplexReceiveIsComplete(
        transmissionFinished: true, expectedDatagrams: 1, receivedDatagramCount: 1
    ))
}

@Test
func wave15RuntimeDeadlineUsesProvidedClockAndExpires() {
    let deadline = UltraGridRuntimeDeadline(timeoutSeconds: 0, nowNanoseconds: 1)
    #expect(deadline.deadlineNanoseconds == 1_000_000_001)
    #expect(deadline.hasExpired)
}

@Test
func wave15MadiSyntheticSmokeProducesPartialValidatedReport() throws {
    let report = try MadiTransmitSyntheticSmoke.run()
    try report.validate()
    #expect(report.verdict == .partial)
    #expect(Set(report.measurements.map(\.channelCount)) == Set(madiSyntheticRequiredChannelCounts))
}

@Test
func wave15MadiReportRejectsPassWithoutPhysicalEvidence() throws {
    var report = try MadiTransmitSyntheticSmoke.run()
    report.verdict = .pass
    #expect(throws: MadiTransmitValidationError.passRequiresPhysicalRmeEvidence) {
        try report.validate()
    }
}

@Test
func wave15MadiReportRejectsNegativeMeasurementValue() throws {
    var report = try MadiTransmitSyntheticSmoke.run()
    report.measurements[0].allocationWarnings = -1
    #expect(throws: MadiTransmitValidationError.negativeField("measurement.allocationWarnings")) {
        try report.validate()
    }
}

@Test
func wave15LatencyVideoModePreservesInitializerValues() {
    let mode = LatencyVideoMode(width: 1_920, height: 1_080, nominalFrameRate: 59.94,
        pixelFormat: "raw8", transport: "udp")
    #expect(mode.width == 1_920)
    #expect(mode.nominalFrameRate == 59.94)
    #expect(mode.transport == "udp")
}

@Test
func wave15LatencyLightingModePreservesInitializerValues() {
    let mode = LatencyLightingMode(protocolName: "sacn", fixtureOrBridge: "fixture", cueRateHertz: 44)
    #expect(mode.protocolName == "sacn")
    #expect(mode.fixtureOrBridge == "fixture")
    #expect(mode.cueRateHertz == 44)
}

@Test
func wave15LatencyMediaModePreservesOptionalDomains() {
    let video = LatencyVideoMode(width: 1, height: 1, nominalFrameRate: 30, pixelFormat: "raw8", transport: "udp")
    let mode = LatencyBenchmarkMediaMode(domain: .video, audio: nil, video: video, lighting: nil)
    #expect(mode.domain == .video)
    #expect(mode.audio == nil)
    #expect(mode.video == video)
}

@Test
func wave15GraphCleanupSummaryHandlesMultipleFailures() {
    let summary = directPeerRealtimeAudioCleanupFailureSummary(.init(failures: [
        .init(operation: "stop", status: nil), .init(operation: "dispose", status: -1)
    ]))
    #expect(summary == "stop status unknown; dispose status -1")
}

@Test
func wave15GraphConfigurationHonorsExplicitDirectionalDevices() {
    let configuration = wave15GraphConfiguration(input: "input", output: "output")
    #expect(configuration.inputDeviceUID == "input")
    #expect(configuration.outputDeviceUID == "output")
    #expect(configuration.payloadByteCount == 256)
}

@Test
func wave15GraphPreflightReportsMissingDevicesWithoutCoreAudio() {
    let preflight = DirectPeerRealtimeAudioGraphPreflight.evaluate(
        configuration: wave15GraphConfiguration(),
        inventory: .init(capturedAt: "wave15", hostName: "fixture", devices: [])
    )
    #expect(!preflight.canStart)
    #expect(preflight.blockers.contains("input audio device UID not found"))
    #expect(preflight.blockers.contains("audio device is not full duplex"))
}

@Test
func wave15GraphPreflightReportsInvalidChannelMapWithoutCoreAudio() {
    var configuration = wave15GraphConfiguration()
    configuration.inputChannelMap = [-1]
    let preflight = DirectPeerRealtimeAudioGraphPreflight.evaluate(
        configuration: configuration,
        inventory: .init(capturedAt: "wave15", hostName: "fixture", devices: [])
    )
    #expect(preflight.blockers.contains("requested input channel map must match channel count"))
    #expect(preflight.blockers.contains("requested input channel map contains a negative channel index"))
}

@Test
func wave15CaptureDecoderRecognizesNulTerminatedControlMessage() throws {
    let report = try LoLaCompatibilityCaptureDecoder.decode(
        data: wave15ClassicPcap(packet: try lolaCompatibilityTestWireFrame(
            payload: Data("/MESG_QUICKCONN\0ignored".utf8), sourcePort: 7_000, destinationPort: 7_000
        )), inputPath: "wave15-control.pcap", capturedAt: "2026-08-05T00:00:00Z"
    )
    #expect(report.packets[0].stream == .control)
    #expect(report.packets[0].controlMessageName == "/MESG_QUICKCONN")
}

@Test
func wave15CaptureDecoderNotesInvalidControlText() throws {
    let report = try LoLaCompatibilityCaptureDecoder.decode(
        data: wave15ClassicPcap(packet: try lolaCompatibilityTestWireFrame(
            payload: Data("not-a-message".utf8), sourcePort: 7_000, destinationPort: 7_000
        )), inputPath: "wave15-invalid-control.pcap", capturedAt: "2026-08-05T00:00:00Z"
    )
    #expect(report.packets[0].notes.contains("Control payload is not a recovered /MESG_* text message."))
}

@Test
func wave15CaptureDecoderClassifiesEmbeddedJPEGVideoPayload() throws {
    let payload = Data([0, 0xff, 0xd8, 0xff, 0xe0, 1, 0xff, 0xd9, 0])
    let report = try LoLaCompatibilityCaptureDecoder.decode(
        data: wave15ClassicPcap(packet: try lolaCompatibilityTestWireFrame(
            payload: payload, sourcePort: 19_798, destinationPort: 19_798
        )), inputPath: "wave15-jpeg.pcap", capturedAt: "2026-08-05T00:00:00Z"
    )
    #expect(report.packets[0].stream == .video)
    #expect(report.packets[0].mediaPayloadCandidate == .mjpeg)
}

private final class Wave15Transmitter: UltraGridCompatibilityMediaTransmitting {
    var datagrams: [UltraGridCompatibilityDatagram] = []

    func transmit(_ datagrams: [UltraGridCompatibilityDatagram], localHost _: String, peer _: String) throws -> Int {
        self.datagrams.append(contentsOf: datagrams)
        return datagrams.count
    }
}

private struct Wave15Receiver: UltraGridCompatibilityMediaReceiving {
    let datagrams: [UltraGridCompatibilityDatagram]

    func receive(_ request: UltraGridMediaReceiveRequest) throws -> [UltraGridCompatibilityDatagram] {
        datagrams
    }
}

private func wave15UltraGridConfiguration(
    _ update: (inout ExternalConnectorSessionConfigInput) -> Void = { _ in }
) -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid, role: .tx, peer: "203.0.113.15", outputPath: "/tmp/wave15.json"
    ) { input in
        input.mediaMode = .audioVideo
        input.framesPerPacket = 2
        input.videoWidth = 2
        input.videoHeight = 1
        input.videoBitsPerPixel = 8
        update(&input)
    })
}

private func wave15ReceiveRequest(expected: Int = 2, peer: String = "peer") -> UltraGridMediaReceiveRequest {
    UltraGridMediaReceiveRequest(
        expectedDatagrams: expected, localHost: "127.0.0.1", peer: peer,
        audioPort: 5_000, videoPort: 5_001, payloadRegistry: .default,
        encryptionConfiguration: nil, timeoutSeconds: 1
    )
}

private func wave15Datagram(
    sequence: UInt16,
    source: String? = "peer",
    port: UInt16 = 5_000,
    stream: LoLaCompatibilityMediaStream = .audio,
    marker: Bool = false,
    payloadType: UInt8 = 21
) -> UltraGridCompatibilityDatagram {
    UltraGridCompatibilityDatagram(
        stream: stream, sourceHost: source, destinationPort: port,
        rtp: RTPPacket(
            header: .init(payloadType: payloadType, marker: marker, sequenceNumber: sequence,
                timestamp: UInt32(sequence), ssrc: 1),
            payload: Data()
        )
    )
}

private func wave15GraphConfiguration(
    input: String = "device", output: String = "device"
) -> DirectPeerRealtimeAudioGraphConfiguration {
    DirectPeerRealtimeAudioGraphConfiguration(
        devices: .init(audioDeviceUID: "legacy", inputDeviceUID: input, outputDeviceUID: output),
        format: .init(sampleRateHertz: 48_000, framesPerBuffer: 32, channelCount: 2,
            sampleFormat: .float32LittleEndian),
        channelMaps: .init(input: [0, 1], output: [0, 1]), buffering: .init(ringCapacityBlocks: 2)
    )
}

private func wave15ClassicPcap(packet: Data) -> Data {
    var data = Data([0xd4, 0xc3, 0xb2, 0xa1])
    wave15AppendLE16(2, to: &data)
    wave15AppendLE16(4, to: &data)
    [UInt32(0), 0, 65_535, 1, 0, 0, UInt32(packet.count), UInt32(packet.count)].forEach {
        wave15AppendLE32($0, to: &data)
    }
    data.append(packet)
    return data
}

private func wave15AppendLE16(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(value & 0xff))
    data.append(UInt8(value >> 8))
}

private func wave15AppendLE32(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(value & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8((value >> 16) & 0xff))
    data.append(UInt8((value >> 24) & 0xff))
}
