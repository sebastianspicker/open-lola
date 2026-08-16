// Covers deterministic model and report seams left outside live media and socket paths.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func wave13CleanupResultDefaultsToSuccess() {
    #expect(DirectPeerRealtimeAudioGraphCleanupResult().succeeded)
}

@Test
func wave13CleanupFailureSummaryIncludesKnownStatus() {
    let result = DirectPeerRealtimeAudioGraphCleanupResult(
        failures: [.init(operation: "dispose", status: -50)]
    )
    #expect(!result.succeeded)
    #expect(directPeerRealtimeAudioCleanupFailureSummary(result) == "dispose status -50")
}

@Test
func wave13CleanupFailureSummaryUsesUnknownForNilStatus() {
    let result = DirectPeerRealtimeAudioGraphCleanupResult(
        failures: [.init(operation: "stop", status: nil)]
    )
    #expect(directPeerRealtimeAudioCleanupFailureSummary(result) == "stop status unknown")
}

@Test
func wave13GraphConfigurationUsesLegacyDeviceForBothDirections() {
    let configuration = wave13GraphConfiguration()
    #expect(configuration.inputDeviceUID == "synthetic-device")
    #expect(configuration.outputDeviceUID == "synthetic-device")
    #expect(configuration.payloadByteCount == 256)
    #expect(configuration.playoutTargetFrames == 0)
}

@Test
func wave13GraphConfigurationRejectsNonPositiveSampleRate() {
    var configuration = wave13GraphConfiguration()
    configuration.sampleRateHertz = 0
    #expect(throws: RealtimeAudioBufferConfigurationError.nonPositiveField("sampleRateHertz")) {
        try configuration.validateRealtimeBufferInputs()
    }
}

@Test
func wave13GraphConfigurationRejectsMismatchedInputMap() {
    var configuration = wave13GraphConfiguration()
    configuration.inputChannelMap = [0]
    #expect(throws: RealtimeAudioBufferConfigurationError.invalidChannelMap(
        field: "inputChannelMap", expected: 2, actual: 1
    )) {
        try configuration.validateRealtimeBufferInputs()
    }
}

@Test
func wave13GraphConfigurationRejectsNegativeOutputMapIndex() {
    var configuration = wave13GraphConfiguration()
    configuration.outputChannelMap = [0, -1]
    #expect(throws: RealtimeAudioBufferConfigurationError.negativeChannelMapIndex("outputChannelMap")) {
        try configuration.validateRealtimeBufferInputs()
    }
}

@Test
func wave13GraphConfigurationCodableRoundTripPreservesFields() throws {
    let configuration = wave13GraphConfiguration()
    let decoded = try JSONDecoder().decode(
        DirectPeerRealtimeAudioGraphConfiguration.self,
        from: JSONEncoder().encode(configuration)
    )
    #expect(decoded == configuration)
}

@Test
func wave13ControlResponderAcceptsStartedRecord() throws {
    let report = LoLaControlRetryResponderReport(
        started: true, localHost: "127.0.0.1", controlPort: 7_000, timeoutSeconds: 1
    )
    try report.validate()
}

@Test
func wave13ControlResponderRejectsBlankHost() {
    let report = LoLaControlRetryResponderReport(
        started: true, localHost: "", controlPort: 7_000, timeoutSeconds: 1
    )
    #expect(throws: ExternalConnectorSessionError.emptyField(
        "lolaControlRetryResponder.localHost"
    )) {
        try report.validate()
    }
}

@Test
func wave13ControlResponderRejectsNonPositiveTimeout() {
    let report = LoLaControlRetryResponderReport(
        started: true, localHost: "127.0.0.1", controlPort: 7_000, timeoutSeconds: 0
    )
    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger(
        "lolaControlRetryResponder.timeoutSeconds", "0"
    )) {
        try report.validate()
    }
}

@Test
func wave13ControlResponderRequiresErrorWhenNotStarted() {
    let report = LoLaControlRetryResponderReport(
        started: false, localHost: "127.0.0.1", controlPort: 7_000, timeoutSeconds: 1
    )
    #expect(throws: ExternalConnectorSessionError.emptyField(
        "lolaControlRetryResponder.runtimeError"
    )) {
        try report.validate()
    }
}

@Test
func wave13ControlResponderAcceptsStoppedRecordWithError() throws {
    let report = LoLaControlRetryResponderReport(
        started: false, localHost: "127.0.0.1", controlPort: 7_000,
        timeoutSeconds: 1, runtimeError: "bind failed"
    )
    try report.validate()
}

@Test
func wave13ControlExchangeDecodesLegacyOptionalFields() throws {
    let data = Data(#"{"bytesTransferred":12}"#.utf8)
    let exchange = try JSONDecoder().decode(LoLaControlExchange.self, from: data)
    #expect(exchange.bytesTransferred == 12)
    #expect(exchange.sentMessages.isEmpty)
    #expect(exchange.receivedMessages.isEmpty)
    #expect(exchange.opaqueControlDatagrams.isEmpty)
    #expect(exchange.fields.isEmpty)
}

@Test
func wave13ExternalLoLaConfigurationSuppliesLoLaDefaults() {
    let configuration = wave13ExternalConfiguration(connector: .lola)
    #expect(configuration.mediaMode == .audioVideo)
    #expect(configuration.controlPort == 7_000)
    #expect(configuration.sampleRateHertz == 44_100)
}

@Test
func wave13ExternalJackTripConfigurationSuppliesJackTripDefaults() {
    let configuration = wave13ExternalConfiguration(connector: .jackTrip)
    #expect(configuration.mediaMode == .audio)
    #expect(configuration.framesPerPacket > 0)
    #expect(configuration.controlPort == 0)
}

@Test
func wave13ExternalConfigurationPreservesExplicitOverrides() {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola, role: .txRx, peer: "198.51.100.10", outputPath: "/tmp/wave13.json"
    ) { input in
        input.localHost = "192.0.2.10"
        input.controlPort = 9_000
        input.audioPort = 9_001
        input.framesPerPacket = 64
        input.mediaMode = .video
    })
    #expect(configuration.localHost == "192.0.2.10")
    #expect(configuration.controlPort == 9_000)
    #expect(configuration.audioPort == 9_001)
    #expect(configuration.framesPerPacket == 64)
    #expect(configuration.mediaMode == .video)
}

@Test
func wave13ExternalProcessResultUsesSafeDefaults() {
    let result = ExternalConnectorProcessResult()
    #expect(!result.launched)
    #expect(result.exitStatus == nil)
    #expect(!result.terminatedAfterDuration)
    #expect(result.standardOutputPrefix.isEmpty)
}

@Test
func wave13ParseLoLaEthernetAddressAcceptsCanonicalOctets() throws {
    let address = try parseLoLaEthernetAddress("02:4c:6f:4c:61:00")
    #expect(address.octets == [0x02, 0x4c, 0x6f, 0x4c, 0x61, 0x00])
}

@Test
func wave13ParseLoLaEthernetAddressRejectsWrongOctetCount() {
    #expect(throws: ExternalConnectorSessionError.socketFailed("invalid MAC 02:4c")) {
        _ = try parseLoLaEthernetAddress("02:4c")
    }
}

@Test
func wave13ParseLoLaEthernetAddressRejectsNonHexOctet() {
    #expect(throws: ExternalConnectorSessionError.socketFailed("invalid MAC 02:4c:6f:4c:61:zz")) {
        _ = try parseLoLaEthernetAddress("02:4c:6f:4c:61:zz")
    }
}

@Test
func wave13RawLinkReceiveConfigurationUsesDefaults() throws {
    let configuration = try LoLaRawLinkReceiveRunConfiguration.parse([
        "--interface", "en0", "--local-ip", "192.0.2.10", "--output", "/tmp/wave13-rx.json"
    ])
    #expect(configuration.peerIP == "0.0.0.0")
    #expect(configuration.dryRun)
    #expect(configuration.maxFrames == 3)
    #expect(configuration.timeoutSeconds == 1)
}

@Test
func wave13MemoryRawLinkReceiverHonorsMaximumFrames() throws {
    let receiver = LoLaMemoryRawLinkReceiver(frames: [Data([1]), Data([2]), Data([3])])
    #expect(try receiver.receive(maxFrames: 2) == [Data([1]), Data([2])])
}

@Test
func wave13MemoryRawLinkGeneratedOutcomeRetainsBoundedEvidence() throws {
    let transmitter = LoLaMemoryRawLinkTransmitter()
    let frames = try wave13LoLaFrames()
    let outcome = try transmitter.transmitGeneratedOutcome { emit in
        for _ in 0..<130 {
            for frame in frames {
                try emit(frame)
            }
        }
    }
    #expect(outcome.writtenFrameCount == frames.count * 130)
    #expect(outcome.writtenBytesTotal > 0)
    #expect(outcome.writtenByteCountEvidence.count == 256)
    #expect(transmitter.transmittedFrames.count == 256)
}

@Test
func wave13CaptureDecoderRejectsOversizedInputBeforeParsing() {
    let oversized = Data(repeating: 0, count: LoLaCompatibilityCaptureDecoder.maxInputByteCount + 1)
    #expect(throws: LoLaCompatibilityCaptureDecodeError.inputTooLarge(oversized.count)) {
        _ = try LoLaCompatibilityCaptureDecoder.decode(
            data: oversized, inputPath: "wave13.pcap", capturedAt: "2026-08-05T00:00:00Z"
        )
    }
}

@Test
func wave13CaptureDecoderRejectsUnsupportedEmptyCaptureFormat() {
    #expect(throws: LoLaCompatibilityCaptureDecodeError.unsupportedCaptureFormat) {
        _ = try LoLaCompatibilityCaptureDecoder.decode(
            data: Data(), inputPath: "wave13-empty.pcap", capturedAt: "2026-08-05T00:00:00Z"
        )
    }
}

@Test
func wave13LatencyThresholdsPreserveNestedTargetsAndLimits() {
    let thresholds = LatencyBenchmarkThresholds(
        targets: .init(
            budgetDocument: "wave13-budget", oneWayMicroseconds: 1_000,
            roundTripMicroseconds: 2_000, jitterP99MaxMicroseconds: 50, packetLossMaxPercent: 0.1
        ),
        limits: .init(
            cpuP99MaxPercent: 60, underrunMaxCount: 0, droppedFrameMaxCount: 1,
            allocationWarningMaxCount: 2, threadWarningMaxCount: 3
        )
    )
    #expect(thresholds.budgetDocument == "wave13-budget")
    #expect(thresholds.oneWayTargetMicroseconds == 1_000)
    #expect(thresholds.threadWarningMaxCount == 3)
}

@Test
func wave13LatencyComponentMeasurementPreservesOptionalEvidence() {
    let component = LatencyBudgetComponentMeasurement(
        id: "capture", label: "Capture", criticality: .criticalPath,
        budgetTargetMicroseconds: 500, measuredMicroseconds: nil, source: "wave13"
    )
    #expect(component.criticality == .criticalPath)
    #expect(component.measuredMicroseconds == nil)
}

@Test
func wave13VideoDefaultAudioImpactIsSyntheticAndBalanced() {
    let impact = defaultVideoCaptureAudioImpact()
    #expect(impact.synthetic == true)
    #expect(impact.baselineCallbackP99Microseconds == impact.videoCallbackP99Microseconds)
    #expect(impact.baselinePlayoutTargetFrames == impact.videoPlayoutTargetFrames)
}

private func wave13GraphConfiguration() -> DirectPeerRealtimeAudioGraphConfiguration {
    DirectPeerRealtimeAudioGraphConfiguration(
        devices: .init(audioDeviceUID: "synthetic-device"),
        format: .init(
            sampleRateHertz: 48_000, framesPerBuffer: 32, channelCount: 2,
            sampleFormat: .float32LittleEndian
        ),
        channelMaps: .init(input: [0, 1], output: [0, 1]),
        buffering: .init(ringCapacityBlocks: 2)
    )
}

private func wave13ExternalConfiguration(
    connector: ExternalConnectorKind
) -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
        connector: connector, role: .tx, peer: "198.51.100.10", outputPath: "/tmp/wave13.json"
    ))
}

private func wave13LoLaFrames() throws -> [LoLaCompatibilityMediaFrame] {
    let configuration = wave13ExternalConfiguration(connector: .lola)
    return try LoLaCompatibilityMediaSession.buildTransmitFrames(
        configuration: configuration, frameCountPerStream: 1
    )
}
