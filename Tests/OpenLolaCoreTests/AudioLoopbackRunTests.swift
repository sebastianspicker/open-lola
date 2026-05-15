import Foundation
import Testing

@testable import OpenLolaCore

@Test
func audioLoopbackRunConfigurationParsesRequiredArguments() throws {
    let configuration = try AudioLoopbackRunConfiguration.parse([
        "--input-uid", "rme-madi-uid",
        "--output-uid", "rme-madi-uid",
        "--sample-rate", "48000",
        "--frames", "32",
        "--duration-seconds", "1800",
        "--output", "reports/rme-loopback.json"
    ])

    #expect(configuration.inputUID == "rme-madi-uid")
    #expect(configuration.outputUID == "rme-madi-uid")
    #expect(configuration.sampleRateHertz == 48_000)
    #expect(configuration.framesPerBuffer == 32)
    #expect(configuration.channelCount == 2)
    #expect(configuration.sampleFormat == .int16LittleEndian)
    #expect(configuration.inputChannelMap == [0, 1])
    #expect(configuration.outputChannelMap == [0, 1])
    #expect(configuration.latencyProfile == .safeLowLatency)
    #expect(configuration.rxBufferProfile == .direct)
    #expect(configuration.durationSeconds == 1_800)
    #expect(configuration.outputPath == "reports/rme-loopback.json")
}

@Test
func audioLoopbackRunConfigurationParsesMultichannelTransmitArguments() throws {
    let configuration = try AudioLoopbackRunConfiguration.parse([
        "--input-uid", "rme-madi-uid",
        "--output-uid", "rme-madi-uid",
        "--sample-rate", "48000",
        "--frames", "32",
        "--channels", "4",
        "--sample-format", "float32-le",
        "--input-channels", "2,0,3,1",
        "--output-channels", "0,1,2,3",
        "--preallocated-blocks", "8",
        "--mtu", "1200",
        "--max-fragments", "16",
        "--metadata-revision", "9",
        "--duration-seconds", "1800",
        "--output", "reports/rme-madi-tx.json"
    ])

    #expect(configuration.channelCount == 4)
    #expect(configuration.sampleFormat == .float32LittleEndian)
    #expect(configuration.inputChannelMap == [2, 0, 3, 1])
    #expect(configuration.outputChannelMap == [0, 1, 2, 3])
    #expect(configuration.preallocatedBlockCount == 8)
    #expect(configuration.maxTransmissionUnitBytes == 1_200)
    #expect(configuration.maxFragmentsPerDeadline == 16)
    #expect(configuration.metadataRevision == 9)
}

@Test
func audioLoopbackRunConfigurationRequiresLowBufferProfileOptIn() {
    #expect(throws: LatencyProfileValidationError.missingExplicitOptIn(.ultraLowLatency16)) {
        _ = try AudioLoopbackRunConfiguration.parse([
            "--input-uid", "rme-madi-uid",
            "--output-uid", "rme-madi-uid",
            "--sample-rate", "48000",
            "--frames", "16",
            "--duration-seconds", "1800",
            "--output", "reports/rme-loopback.json"
        ])
    }
}

@Test
func audioLoopbackRunConfigurationParsesExplicitLowBufferProfiles() throws {
    let ultra = try AudioLoopbackRunConfiguration.parse([
        "--input-uid", "rme-madi-uid",
        "--output-uid", "rme-madi-uid",
        "--sample-rate", "48000",
        "--frames", "16",
        "--latency-profile", "ultraLowLatency16",
        "--acknowledge-latency-warning", "true",
        "--duration-seconds", "1800",
        "--output", "reports/rme-loopback.json"
    ])
    let extreme = try AudioLoopbackRunConfiguration.parse([
        "--input-uid", "rme-madi-uid",
        "--output-uid", "rme-madi-uid",
        "--sample-rate", "48000",
        "--frames", "8",
        "--latency-profile", "extremeLowLatency8",
        "--experimental-8-frame", "true",
        "--acknowledge-latency-warning", "true",
        "--duration-seconds", "7200",
        "--output", "reports/rme-loopback-8.json"
    ])

    #expect(ultra.latencyProfile == .ultraLowLatency16)
    #expect(ultra.rxBufferProfile == .direct)
    #expect(!ultra.experimentalEightFrameOptIn)
    #expect(ultra.warningAcknowledged)
    #expect(extreme.latencyProfile == .extremeLowLatency8)
    #expect(extreme.experimentalEightFrameOptIn)
    #expect(extreme.warningAcknowledged)
}

@Test
func audioLoopbackRunConfigurationRejectsUnknownDuplicateAndMissingValueArguments() {
    #expect(throws: AudioLoopbackRunConfigurationError.unknownArgument("--unexpected")) {
        _ = try AudioLoopbackRunConfiguration.parse(["--unexpected", "true"])
    }
    #expect(throws: AudioLoopbackRunConfigurationError.duplicateArgument("--input-uid")) {
        _ = try AudioLoopbackRunConfiguration.parse([
            "--input-uid", "rme-madi-uid",
            "--input-uid", "other-rme-madi-uid"
        ])
    }
    #expect(throws: AudioLoopbackRunConfigurationError.missingValue("--input-uid")) {
        _ = try AudioLoopbackRunConfiguration.parse(["--input-uid"])
    }
}

@Test
func audioLoopbackRunConfigurationReportsInvalidBoolArgumentName() {
    #expect(throws: AudioLoopbackRunConfigurationError.invalidBool(
        argument: "--acknowledge-latency-warning",
        value: "maybe"
    )) {
        _ = try AudioLoopbackRunConfiguration.parse([
            "--input-uid", "rme-madi-uid",
            "--output-uid", "rme-madi-uid",
            "--sample-rate", "48000",
            "--frames", "32",
            "--acknowledge-latency-warning", "maybe",
            "--duration-seconds", "1800",
            "--output", "reports/rme-loopback.json"
        ])
    }
}

@Test
func audioLoopbackRealtimeConfigurationAppliesExplicitRXBufferProfileToHandoff() throws {
    let configuration = AudioLoopbackRunConfiguration(
        inputUID: "rme-madi-uid",
        outputUID: "rme-madi-uid",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        preallocatedBlockCount: 16,
        rxBufferProfile: .stableWan,
        durationSeconds: 1_800,
        outputPath: "reports/rme-loopback-stable-wan.json"
    )

    let realtimeConfiguration = try audioLoopbackRealtimeConfiguration(for: configuration)
    var handoff = RealtimeAudioPacketHandoff(configuration: realtimeConfiguration)
    handoff.markShutdownCompleted()
    let rxBuffer = try #require(handoff.metrics.rxBuffer)

    #expect(realtimeConfiguration.rxBufferPolicy?.profile == .stableWan)
    #expect(realtimeConfiguration.rxBufferPolicy?.targetFrames == 256)
    #expect(rxBuffer.policy.profile == .stableWan)
    #expect(rxBuffer.currentTargetFrames == 256)
    #expect(handoff.metrics.ringCapacityBlocks == 16)
}

@Test
func audioLoopbackHostTimeConversionRejectsOverflow() {
    #expect(audioLoopbackHostTimeNanoseconds(
        hostTime: UInt64.max,
        timebaseNumerator: 2,
        timebaseDenominator: 1
    ) == nil)
    #expect(audioLoopbackHostTimeNanoseconds(
        hostTime: 10,
        timebaseNumerator: 3,
        timebaseDenominator: 2
    ) == 15)
}

@Test
func endpointCallbackMetricsDefaultsMissingHostTimeConversionFailures() throws {
    let data = Data("""
    {
      "p50Microseconds": 10,
      "p95Microseconds": 20,
      "p99Microseconds": 30,
      "maxMicroseconds": 40,
      "missedDeadlines": 0,
      "underruns": 0,
      "overruns": 0
    }
    """.utf8)
    let metrics = try JSONDecoder().decode(EndpointCallbackMetrics.self, from: data)

    #expect(metrics.recordedIntervalSamples == 0)
    #expect(metrics.droppedIntervalSamples == 0)
    #expect(metrics.hostTimeConversionFailures == 0)
}

@Test
func audioLoopbackIOProcSeparatesHostTimeConversionFailuresFromOverruns() throws {
    let source = try readAudioLoopbackSource("Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift")

    #expect(source.contains("hostTimeConversionFailures += 1"))
    #expect(source.contains("hostTimeConversionFailures: hostTimeConversionFailures"))
}

@Test
func audioLoopbackIOProcReportsRecordedAndDroppedIntervalSamples() throws {
    let source = try readAudioLoopbackSource("Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift")

    #expect(source.contains("maximumRecordedCallbackIntervals = 100_000"))
    #expect(source.contains("durationSeconds.multipliedReportingOverflow"))
    #expect(source.contains("recordedCallbackCapacity = min("))
    #expect(source.contains("callbackIntervalBufferAllocationFailed"))
    #expect(source.contains("guard let rawIntervals = calloc("))
    #expect(source.contains("free(UnsafeMutableRawPointer(intervalStorage))"))
    #expect(source.contains("private var droppedIntervalSamples = 0"))
    #expect(source.contains("droppedIntervalSamples += 1"))
    #expect(source.contains("recordedIntervalSamples: intervalCount"))
    #expect(source.contains("droppedIntervalSamples: droppedIntervalSamples"))
}

@Test
func audioLoopbackIOProcDoesNotCountLateCallbackAsUnderrun() throws {
    let source = try readAudioLoopbackSource("Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift")

    #expect(source.contains("deltaMicroseconds > expectedIntervalMicroseconds * 1.5"))
    #expect(source.contains("missedDeadlines += 1"))
    #expect(!source.contains("missedDeadlines += 1\n            underruns += 1"))
}

@Test
func audioLoopbackIOProcMapsHandoffResultsToCallbackUnderrunAndOverrunMetrics() throws {
    let source = try readAudioLoopbackSource("Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift")

    #expect(source.contains("let captureResult = handoff.captureAudioBufferListCallback"))
    #expect(source.contains("if captureResult == .droppedFull"))
    #expect(source.contains("overruns += 1"))
    #expect(source.contains("let renderResult = handoff.renderCallback()"))
    #expect(source.contains("if case .silence = renderResult"))
    #expect(source.contains("underruns += 1"))
}

@Test
func audioLoopbackIOProcNamesMicrosecondsPerSecondConversion() throws {
    let source = try readAudioLoopbackSource("Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift")

    #expect(source.contains("private static let microsecondsPerSecond = 1_000_000.0"))
    #expect(source.contains("* Self.microsecondsPerSecond"))
    #expect(!source.contains(") * 1_000_000"))
}

@Test
func audioLoopbackCopyInputToOutputRejectsSizeMismatchInsteadOfTruncating() throws {
    let source = try readAudioLoopbackSource("Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift")

    #expect(source.contains("inputBuffers.count == outputBuffers.count"))
    #expect(source.contains("kAudioHardwareBadPropertySizeError"))
    #expect(source.contains("inputBuffers[index].mDataByteSize == outputBuffers[index].mDataByteSize"))
    #expect(source.contains("private func zeroOutputBuffers("))
    #expect(!source.contains("min(Int(inputBuffers[index].mDataByteSize), Int(outputBuffers[index].mDataByteSize))"))
}

@Test
func audioLoopbackIOProcSourceGuardsNonMonotonicHostTime() throws {
    let source = try readAudioLoopbackSource("Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift")

    #expect(source.contains("multipliedReportingOverflow"))
    #expect(source.contains("""
guard hostTimeNanoseconds > lastHostTimeNanoseconds else {
            droppedIntervalSamples += 1
            return
        }
"""))
    #expect(!source.contains("let hostTimeNanoseconds = (hostTime * timebaseNumerator) / timebaseDenominator"))
    #expect(!source.contains("let deltaNanoseconds = hostTimeNanoseconds - lastHostTimeNanoseconds\n        let deltaMicroseconds"))
    #expect(!source.contains("""
guard hostTimeNanoseconds > lastHostTimeNanoseconds else {
            lastHostTimeNanoseconds = hostTimeNanoseconds
            return
        }
"""))
}

@Test
func audioLoopbackIOProcMetricsAreSnapshottedAfterStop() throws {
    let source = try readAudioLoopbackSource("Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift")

    #expect(source.contains("AudioDeviceStop(deviceID, ioProcID)"))
    #expect(source.contains("state.markStopped()"))
    #expect(source.contains("precondition(stopped"))
}

@Test
func audioLoopbackRunWaitsWithoutThreadSleep() throws {
    let source = try readAudioLoopbackSource("Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift")

    #expect(source.contains("DispatchSemaphore(value: 0).wait"))
    #expect(!source.contains("Thread.sleep(forTimeInterval:"))
}

@Test
func audioLoopbackRunConfigurationRejectsMissingRequiredArgument() {
    #expect(throws: AudioLoopbackRunConfigurationError.missingRequiredArgument("--output")) {
        _ = try AudioLoopbackRunConfiguration.parse([
            "--input-uid", "rme-madi-uid",
            "--output-uid", "rme-madi-uid",
            "--sample-rate", "48000",
            "--frames", "32",
            "--duration-seconds", "1800"
        ])
    }
}

@Test
func audioLoopbackRunConfigurationRejectsNonPositiveFrames() {
    #expect(throws: AudioLoopbackRunConfigurationError.nonPositiveArgument("--frames")) {
        _ = try AudioLoopbackRunConfiguration.parse([
            "--input-uid", "rme-madi-uid",
            "--output-uid", "rme-madi-uid",
            "--sample-rate", "48000",
            "--frames", "0",
            "--duration-seconds", "1800",
            "--output", "reports/rme-loopback.json"
        ])
    }
}

@Test
func audioLoopbackPreflightAcceptsVisibleRmeMadiFullDuplexDevice() throws {
    let configuration = AudioLoopbackRunConfiguration(
        inputUID: "rme-madi-uid",
        outputUID: "rme-madi-uid",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        durationSeconds: 1_800,
        outputPath: "reports/rme-loopback.json"
    )
    let inventory = CoreAudioInventoryReport(
        capturedAt: "2026-05-02T00:00:00Z",
        hostName: "reference-mac",
        devices: [
            rmeMadiDevice(uid: "rme-madi-uid")
        ]
    )

    let preflight = AudioLoopbackPreflight.evaluate(
        configuration: configuration,
        inventory: inventory
    )

    #expect(preflight.rmeMadiVisible)
    #expect(preflight.canStartIOProc)
    #expect(preflight.blockers.isEmpty)
}

@Test
func audioLoopbackPreflightBlocksBuiltInAudioForPassPath() throws {
    let configuration = AudioLoopbackRunConfiguration(
        inputUID: "built-in-uid",
        outputUID: "built-in-uid",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        durationSeconds: 1_800,
        outputPath: "reports/built-in-loopback.json"
    )
    let inventory = CoreAudioInventoryReport(
        capturedAt: "2026-05-02T00:00:00Z",
        hostName: "reference-mac",
        devices: [
            builtInDevice(uid: "built-in-uid")
        ]
    )

    let preflight = AudioLoopbackPreflight.evaluate(
        configuration: configuration,
        inventory: inventory
    )

    #expect(!preflight.rmeMadiVisible)
    #expect(!preflight.canStartIOProc)
    #expect(preflight.blockers.contains("RME MADI device is not visible"))
}

@Test
func audioLoopbackPreflightBlocksNonRmeSelectionWhenRmeIsVisible() throws {
    let configuration = AudioLoopbackRunConfiguration(
        inputUID: "built-in-uid",
        outputUID: "built-in-uid",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        durationSeconds: 1_800,
        outputPath: "reports/built-in-loopback.json"
    )
    let inventory = CoreAudioInventoryReport(
        capturedAt: "2026-05-02T00:00:00Z",
        hostName: "reference-mac",
        devices: [
            builtInDevice(uid: "built-in-uid"),
            rmeMadiDevice(uid: "rme-madi-uid")
        ]
    )

    let preflight = AudioLoopbackPreflight.evaluate(
        configuration: configuration,
        inventory: inventory
    )

    #expect(preflight.rmeMadiVisible)
    #expect(!preflight.canStartIOProc)
    #expect(preflight.blockers.contains("input device is not RME MADI"))
    #expect(preflight.blockers.contains("output device is not RME MADI"))
}

@Test
func audioLoopbackPreflightBlocksUnsupportedFrameSize() throws {
    let configuration = AudioLoopbackRunConfiguration(
        inputUID: "rme-madi-uid",
        outputUID: "rme-madi-uid",
        sampleRateHertz: 48_000,
        framesPerBuffer: 512,
        durationSeconds: 1_800,
        outputPath: "reports/rme-loopback.json"
    )
    let inventory = CoreAudioInventoryReport(
        capturedAt: "2026-05-02T00:00:00Z",
        hostName: "reference-mac",
        devices: [
            rmeMadiDevice(uid: "rme-madi-uid")
        ]
    )

    let preflight = AudioLoopbackPreflight.evaluate(
        configuration: configuration,
        inventory: inventory
    )

    #expect(!preflight.canStartIOProc)
    #expect(preflight.blockers.contains("requested frame size is outside reported input range"))
}

@Test
func audioLoopbackPreflightBlocksChannelMapBeyondDeviceChannels() throws {
    let configuration = AudioLoopbackRunConfiguration(
        inputUID: "rme-madi-uid",
        outputUID: "rme-madi-uid",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        inputChannelMap: [0, 64],
        outputChannelMap: [0, 1],
        durationSeconds: 1_800,
        outputPath: "reports/rme-loopback.json"
    )
    let inventory = CoreAudioInventoryReport(
        capturedAt: "2026-05-02T00:00:00Z",
        hostName: "reference-mac",
        devices: [
            rmeMadiDevice(uid: "rme-madi-uid")
        ]
    )

    let preflight = AudioLoopbackPreflight.evaluate(
        configuration: configuration,
        inventory: inventory
    )

    #expect(!preflight.canStartIOProc)
    #expect(preflight.blockers.contains("requested input channel map exceeds input device channels"))
}

@Test
func audioLoopbackRunReportRoundTrips() throws {
    let configuration = AudioLoopbackRunConfiguration(
        inputUID: "rme-madi-uid",
        outputUID: "rme-madi-uid",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        durationSeconds: 1_800,
        outputPath: "reports/rme-loopback.json"
    )
    let inventory = CoreAudioInventoryReport(
        capturedAt: "2026-05-02T00:00:00Z",
        hostName: "reference-mac",
        devices: [
            rmeMadiDevice(uid: "rme-madi-uid")
        ]
    )
    let report = AudioLoopbackRunReport(
        id: "audio-loopback-run-test",
        capturedAt: "2026-05-02T00:00:00Z",
        hostName: "reference-mac",
        runnerKind: .audioDeviceIOProc,
        state: .blockedPreflight,
        configuration: configuration,
        preflight: AudioLoopbackPreflight.evaluate(
            configuration: configuration,
            inventory: inventory
        ),
        callback: nil,
        verdict: .partial,
        notes: "test report"
    )

    try report.validate()
    let decoded = try AudioLoopbackRunReport.decode(from: try report.prettyJSONData())

    #expect(decoded == report)
    #expect(!decoded.safety.noAllocationInCallback)
    #expect(!decoded.safety.countersOnlyInCallback)
}

@Test
func audioLoopbackCompletedRunRequiresHandoffMetrics() {
    let configuration = AudioLoopbackRunConfiguration(
        inputUID: "rme-madi-uid",
        outputUID: "rme-madi-uid",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        durationSeconds: 1_800,
        outputPath: "reports/rme-loopback.json"
    )
    let inventory = CoreAudioInventoryReport(
        capturedAt: "2026-05-02T00:00:00Z",
        hostName: "reference-mac",
        devices: [
            rmeMadiDevice(uid: "rme-madi-uid")
        ]
    )
    let report = AudioLoopbackRunReport(
        id: "audio-loopback-run-test",
        capturedAt: "2026-05-02T00:00:00Z",
        hostName: "reference-mac",
        runnerKind: .audioDeviceIOProc,
        state: .completed,
        configuration: configuration,
        preflight: AudioLoopbackPreflight.evaluate(
            configuration: configuration,
            inventory: inventory
        ),
        callback: EndpointCallbackMetrics(
            p50Microseconds: 10,
            p95Microseconds: 20,
            p99Microseconds: 30,
            maxMicroseconds: 40,
            missedDeadlines: 0,
            underruns: 0,
            overruns: 0
        ),
        verdict: .partial,
        notes: "test report"
    )

    #expect(throws: AudioLoopbackRunValidationError.completedRunMissingHandoff) {
        try report.validate()
    }
}

private func rmeMadiDevice(uid: String) -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
        id: 100,
        name: "RME MADIface USB",
        uid: uid,
        manufacturer: "RME",
        transportType: "USB",
        isAggregate: false,
        inputChannelCount: 64,
        outputChannelCount: 64,
        inputStreamCount: 1,
        outputStreamCount: 1,
        nominalSampleRateHertz: 48_000,
        availableSampleRateRanges: [
            AudioValueRangeSnapshot(minimum: 48_000, maximum: 96_000)
        ],
        currentBufferFrameSize: 32,
        bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128),
        candidateBufferFrames: BufferFrameCandidates(
            inReportedRange: [16, 32, 64, 128],
            outsideReportedRange: [],
            note: "test"
        ),
        inputLatencyFrames: 12,
        outputLatencyFrames: 12,
        inputSafetyOffsetFrames: 0,
        outputSafetyOffsetFrames: 0,
        clockDomain: 1,
        diagnosticNotes: []
    )
}

private func readAudioLoopbackSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

private func builtInDevice(uid: String) -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
        id: 101,
        name: "MacBook Air Speakers",
        uid: uid,
        manufacturer: "Apple Inc.",
        transportType: "bltn",
        isAggregate: false,
        inputChannelCount: 2,
        outputChannelCount: 2,
        inputStreamCount: 1,
        outputStreamCount: 1,
        nominalSampleRateHertz: 48_000,
        availableSampleRateRanges: [
            AudioValueRangeSnapshot(minimum: 48_000, maximum: 48_000)
        ],
        currentBufferFrameSize: 32,
        bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128),
        candidateBufferFrames: BufferFrameCandidates(
            inReportedRange: [16, 32, 64, 128],
            outsideReportedRange: [],
            note: "test"
        ),
        inputLatencyFrames: 12,
        outputLatencyFrames: 12,
        inputSafetyOffsetFrames: 0,
        outputSafetyOffsetFrames: 0,
        clockDomain: 1,
        diagnosticNotes: []
    )
}
