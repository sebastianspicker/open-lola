// Verifies that audio loopback run configuration parses default and multichannel profiles.
import CoreAudio
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func audioLoopbackRunConfigurationParsesDefaultAndMultichannelProfiles() throws {
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
}

@Test
func audioLoopbackRunConfigurationRequiresLatencyProfileOptIns() throws {
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
}

@Test
func audioLoopbackRunConfigurationRejectsInvalidArgumentShapes() throws {
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
    let configuration = stableWanAudioLoopbackConfiguration()

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

private func stableWanAudioLoopbackConfiguration() -> AudioLoopbackRunConfiguration {
    AudioLoopbackRunConfiguration(
        devices: .init(inputUID: "rme-madi-uid", outputUID: "rme-madi-uid"),
        audio: .init(sampleRateHertz: 48_000, framesPerBuffer: 32, channelCount: 2),
        transport: .init(preallocatedBlockCount: 16),
        latency: .init(rxBufferProfile: .stableWan),
        run: .init(durationSeconds: 1_800, outputPath: "reports/rme-loopback-stable-wan.json")
    )
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
        savedSettings: AudioLoopbackSavedDeviceSettings(
            sampleRate: 44_100,
            frames: nil
        )
    )

    #expect(cleanup == AudioLoopbackRunCleanupResult(failures: [
        .init(operation: "destroy AudioDeviceIOProcID", status: OSStatus(-11)),
        .init(operation: "restore sample rate", status: OSStatus(-22)),
        .init(operation: "restore buffer frame size", status: nil)
    ]))
    #expect(!cleanup.succeeded)
}

@Test
func audioLoopbackPreflightAcceptsRmeMadiAndBlocksUnsafePassPathSelections() throws {
    let preflight = audioLoopbackPreflight()

    #expect(preflight.rmeMadiVisible)
    #expect(preflight.canStartIOProc)
    #expect(preflight.blockers.isEmpty)

    let builtInOnly = audioLoopbackBuiltInOnlyPreflight()
    #expect(!builtInOnly.rmeMadiVisible)
    #expect(!builtInOnly.canStartIOProc)
    #expect(builtInOnly.blockers.contains("RME MADI device is not visible"))

    let nonRmeSelection = audioLoopbackNonRmeSelectionPreflight()
    #expect(nonRmeSelection.rmeMadiVisible)
    #expect(!nonRmeSelection.canStartIOProc)
    #expect(nonRmeSelection.blockers.contains("input device is not RME MADI"))
    #expect(nonRmeSelection.blockers.contains("output device is not RME MADI"))

    let unsupportedFrameSize = audioLoopbackUnsupportedFrameSizePreflight()
    #expect(!unsupportedFrameSize.canStartIOProc)
    #expect(unsupportedFrameSize.blockers.contains("requested frame size is outside reported input range"))

    let channelMapBeyondDevice = audioLoopbackChannelMapBeyondDevicePreflight()
    #expect(!channelMapBeyondDevice.canStartIOProc)
    #expect(channelMapBeyondDevice.blockers.contains("requested input channel map exceeds input device channels"))
}

@Test
func audioLoopbackRunReportRoundTripsAndRequiresHandoffMetricsForCompletedRuns() throws {
    let report = audioLoopbackRunReport()

    try report.validate()
    let decoded = try AudioLoopbackRunReport.decode(from: try report.prettyJSONData())

    #expect(decoded == report)
    #expect(!decoded.safety.noAllocationInCallback)
    #expect(!decoded.safety.countersOnlyInCallback)

    let completedReport = audioLoopbackRunReport(
        state: .completed,
        callback: audioLoopbackTestCallbackMetrics()
    )

    #expect(throws: AudioLoopbackRunValidationError.completedRunMissingHandoff) {
        try completedReport.validate()
    }

    let plainCompletedReport = audioLoopbackRunReport(
        state: .completed,
        callback: audioLoopbackTestCallbackMetrics(),
        handoff: audioLoopbackTestHandoffMetrics(),
        cleanup: nil
    )
    #expect(throws: AudioLoopbackRunValidationError.completedRunMissingCleanup) {
        try plainCompletedReport.validate()
    }

    let cleanupFailureReport = audioLoopbackRunReport(
        state: .completed,
        callback: audioLoopbackTestCallbackMetrics(),
        handoff: audioLoopbackTestHandoffMetrics(),
        cleanup: audioLoopbackTestCleanupFailure()
    )
    #expect(throws: AudioLoopbackRunValidationError.completedRunCleanupFailureMissingNote("restore sample rate")) {
        try cleanupFailureReport.validate()
    }

    let annotatedCleanupFailureReport = audioLoopbackRunReport(
        state: .completed,
        callback: audioLoopbackTestCallbackMetrics(),
        handoff: audioLoopbackTestHandoffMetrics(),
        cleanup: audioLoopbackTestCleanupFailure(),
        notes: "Cleanup failures: restore sample rate status -22."
    )
    try annotatedCleanupFailureReport.validate()
}
