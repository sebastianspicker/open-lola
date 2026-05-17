import CoreAudio
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func audioLoopbackRunConfigurationParsesProfilesAndRejectsInvalidArgumentShapes() throws {
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

    let multichannel = try AudioLoopbackRunConfiguration.parse([
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

    #expect(multichannel.channelCount == 4)
    #expect(multichannel.sampleFormat == .float32LittleEndian)
    #expect(multichannel.inputChannelMap == [2, 0, 3, 1])
    #expect(multichannel.outputChannelMap == [0, 1, 2, 3])
    #expect(multichannel.preallocatedBlockCount == 8)
    #expect(multichannel.maxTransmissionUnitBytes == 1_200)
    #expect(multichannel.maxFragmentsPerDeadline == 16)
    #expect(multichannel.metadataRevision == 9)

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

    #expect(throws: AudioLoopbackRunConfigurationError.missingRequiredArgument("--output")) {
        _ = try AudioLoopbackRunConfiguration.parse([
            "--input-uid", "rme-madi-uid",
            "--output-uid", "rme-madi-uid",
            "--sample-rate", "48000",
            "--frames", "32",
            "--duration-seconds", "1800"
        ])
    }

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
func audioLoopbackRuntimeMetricsAndSourceGuardsProtectCallbacksAndRXBuffering() throws {
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
    var handoff = try RealtimeAudioPacketHandoff(configuration: realtimeConfiguration)
    handoff.markShutdownCompleted()
    let rxBuffer = try #require(handoff.metrics.rxBuffer)

    #expect(realtimeConfiguration.rxBufferPolicy?.profile == .stableWan)
    #expect(realtimeConfiguration.rxBufferPolicy?.targetFrames == 256)
    #expect(rxBuffer.policy.profile == .stableWan)
    #expect(rxBuffer.currentTargetFrames == 256)
    #expect(handoff.metrics.ringCapacityBlocks == 16)

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
func audioLoopbackCleanupReportsDestroyRestoreAndUnknownFailures() {
    let runner = CoreAudioLoopbackRunner(
        destroyIOProc: { _, _ in OSStatus(-11) },
        restoreDoubleProperty: { _, _, _, _ in
            throw AudioLoopbackRunError.coreAudioStatus(OSStatus(-22), "test sample-rate restore")
        },
        restoreUInt32Property: { _, _, _, _ in
            throw AudioLoopbackRunError.coreAudioStatus(OSStatus(-33), "test buffer restore")
        }
    )

    let cleanup = runner.cleanupIOProc(
        deviceID: 100,
        ioProcID: audioLoopbackTestIOProc,
        originalSampleRate: 44_100,
        originalFrames: nil
    )

    #expect(cleanup == AudioLoopbackRunCleanupResult(failures: [
        .init(operation: "destroy AudioDeviceIOProcID", status: OSStatus(-11)),
        .init(operation: "restore sample rate", status: OSStatus(-22)),
        .init(operation: "restore buffer frame size", status: nil),
    ]))
    #expect(!cleanup.succeeded)
}

@Test
func audioLoopbackPreflightAcceptsRmeMadiAndBlocksUnsafePassPathSelections() throws {
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

    let builtInOnly = AudioLoopbackPreflight.evaluate(
        configuration: AudioLoopbackRunConfiguration(
            inputUID: "built-in-uid",
            outputUID: "built-in-uid",
            sampleRateHertz: 48_000,
            framesPerBuffer: 32,
            durationSeconds: 1_800,
            outputPath: "reports/built-in-loopback.json"
        ),
        inventory: CoreAudioInventoryReport(
            capturedAt: "2026-05-02T00:00:00Z",
            hostName: "reference-mac",
            devices: [builtInDevice(uid: "built-in-uid")]
        )
    )
    #expect(!builtInOnly.rmeMadiVisible)
    #expect(!builtInOnly.canStartIOProc)
    #expect(builtInOnly.blockers.contains("RME MADI device is not visible"))

    let nonRmeSelection = AudioLoopbackPreflight.evaluate(
        configuration: AudioLoopbackRunConfiguration(
            inputUID: "built-in-uid",
            outputUID: "built-in-uid",
            sampleRateHertz: 48_000,
            framesPerBuffer: 32,
            durationSeconds: 1_800,
            outputPath: "reports/built-in-loopback.json"
        ),
        inventory: CoreAudioInventoryReport(
            capturedAt: "2026-05-02T00:00:00Z",
            hostName: "reference-mac",
            devices: [
                builtInDevice(uid: "built-in-uid"),
                rmeMadiDevice(uid: "rme-madi-uid"),
            ]
        )
    )
    #expect(nonRmeSelection.rmeMadiVisible)
    #expect(!nonRmeSelection.canStartIOProc)
    #expect(nonRmeSelection.blockers.contains("input device is not RME MADI"))
    #expect(nonRmeSelection.blockers.contains("output device is not RME MADI"))

    let unsupportedFrameSize = AudioLoopbackPreflight.evaluate(
        configuration: AudioLoopbackRunConfiguration(
            inputUID: "rme-madi-uid",
            outputUID: "rme-madi-uid",
            sampleRateHertz: 48_000,
            framesPerBuffer: 512,
            durationSeconds: 1_800,
            outputPath: "reports/rme-loopback.json"
        ),
        inventory: CoreAudioInventoryReport(
            capturedAt: "2026-05-02T00:00:00Z",
            hostName: "reference-mac",
            devices: [rmeMadiDevice(uid: "rme-madi-uid")]
        )
    )
    #expect(!unsupportedFrameSize.canStartIOProc)
    #expect(unsupportedFrameSize.blockers.contains("requested frame size is outside reported input range"))

    let channelMapBeyondDevice = AudioLoopbackPreflight.evaluate(
        configuration: AudioLoopbackRunConfiguration(
            inputUID: "rme-madi-uid",
            outputUID: "rme-madi-uid",
            sampleRateHertz: 48_000,
            framesPerBuffer: 32,
            channelCount: 2,
            inputChannelMap: [0, 64],
            outputChannelMap: [0, 1],
            durationSeconds: 1_800,
            outputPath: "reports/rme-loopback.json"
        ),
        inventory: CoreAudioInventoryReport(
            capturedAt: "2026-05-02T00:00:00Z",
            hostName: "reference-mac",
            devices: [rmeMadiDevice(uid: "rme-madi-uid")]
        )
    )
    #expect(!channelMapBeyondDevice.canStartIOProc)
    #expect(channelMapBeyondDevice.blockers.contains("requested input channel map exceeds input device channels"))
}

@Test
func audioLoopbackRunReportRoundTripsAndRequiresHandoffMetricsForCompletedRuns() throws {
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

    let completedReport = AudioLoopbackRunReport(
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
        try completedReport.validate()
    }

    let plainCompletedReport = AudioLoopbackRunReport(
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
        handoff: audioLoopbackTestHandoffMetrics(),
        verdict: .partial,
        notes: "test report"
    )
    #expect(throws: AudioLoopbackRunValidationError.completedRunMissingCleanup) {
        try plainCompletedReport.validate()
    }

    let cleanupFailureReport = AudioLoopbackRunReport(
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
        handoff: audioLoopbackTestHandoffMetrics(),
        cleanup: AudioLoopbackRunCleanupResult(failures: [
            .init(operation: "restore sample rate", status: OSStatus(-22)),
        ]),
        verdict: .partial,
        notes: "test report"
    )
    #expect(throws: AudioLoopbackRunValidationError.completedRunCleanupFailureMissingNote("restore sample rate")) {
        try cleanupFailureReport.validate()
    }

    let annotatedCleanupFailureReport = AudioLoopbackRunReport(
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
        handoff: audioLoopbackTestHandoffMetrics(),
        cleanup: AudioLoopbackRunCleanupResult(failures: [
            .init(operation: "restore sample rate", status: OSStatus(-22)),
        ]),
        verdict: .partial,
        notes: "Cleanup failures: restore sample rate status -22."
    )
    try annotatedCleanupFailureReport.validate()
}

private func audioLoopbackTestIOProc(
    _: AudioObjectID,
    _: UnsafePointer<AudioTimeStamp>,
    _: UnsafePointer<AudioBufferList>,
    _: UnsafePointer<AudioTimeStamp>,
    _: UnsafeMutablePointer<AudioBufferList>,
    _: UnsafePointer<AudioTimeStamp>,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    noErr
}

private func audioLoopbackTestHandoffMetrics() -> RealtimeAudioHandoffMetrics {
    RealtimeAudioHandoffMetrics(
        inputBlocks: 1,
        outputBlocks: 1,
        networkSendBlocks: 0,
        networkReceiveBlocks: 0,
        droppedInputBlocks: 0,
        droppedNetworkBlocks: 0,
        outputUnderrunBlocks: 0,
        callbackOverrunBlocks: 0,
        latePackets: 0,
        maximumBufferedBlocks: 0,
        ringCapacityBlocks: 1,
        fullCaptureRingBlocks: 0,
        invalidInputBlocks: 0,
        directInputBlocks: 1,
        remappedInputBlocks: 0,
        packetFragmentCount: 0,
        allocationWarnings: 0,
        maximumCaptureRingOccupancyBlocks: 1,
        maximumPlayoutQueueDepthBlocks: 1,
        packetizationDuration: .empty,
        depacketizationDuration: .empty,
        hiddenPlayoutGrowthDetected: false,
        shutdownCompleted: true,
        rxBuffer: nil
    )
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
