// Shared Audio loopback run helpers keep multi-file test scenarios deterministic.
import CoreAudio
import Foundation
import Testing

@testable import OpenLolaCore

func audioLoopbackPreflight(
    configuration: AudioLoopbackRunConfiguration = audioLoopbackRmeMadiConfiguration(),
    devices: [CoreAudioDeviceInventory] = [rmeMadiDevice(uid: "rme-madi-uid")]
) -> AudioLoopbackPreflight {
    AudioLoopbackPreflight.evaluate(
        configuration: configuration,
        inventory: CoreAudioInventoryReport(
            capturedAt: "2026-05-02T00:00:00Z",
            hostName: "reference-mac",
            devices: devices
        )
    )
}

func audioLoopbackBuiltInOnlyPreflight() -> AudioLoopbackPreflight {
    audioLoopbackPreflight(
        configuration: audioLoopbackBuiltInConfiguration(),
        devices: [builtInDevice(uid: "built-in-uid")]
    )
}

func audioLoopbackNonRmeSelectionPreflight() -> AudioLoopbackPreflight {
    audioLoopbackPreflight(
        configuration: audioLoopbackBuiltInConfiguration(),
        devices: [
            builtInDevice(uid: "built-in-uid"),
            rmeMadiDevice(uid: "rme-madi-uid")
        ]
    )
}

func audioLoopbackUnsupportedFrameSizePreflight() -> AudioLoopbackPreflight {
    audioLoopbackPreflight(configuration: AudioLoopbackRunConfiguration(
        devices: .init(inputUID: "rme-madi-uid", outputUID: "rme-madi-uid"),
        audio: .init(sampleRateHertz: 48_000, framesPerBuffer: 512),
        run: .init(durationSeconds: 1_800, outputPath: "reports/rme-loopback.json")
    ))
}

func audioLoopbackChannelMapBeyondDevicePreflight() -> AudioLoopbackPreflight {
    audioLoopbackPreflight(configuration: AudioLoopbackRunConfiguration(
        devices: .init(inputUID: "rme-madi-uid", outputUID: "rme-madi-uid"),
        audio: .init(
            sampleRateHertz: 48_000,
            framesPerBuffer: 32,
            channelCount: 2,
            inputChannelMap: [0, 64],
            outputChannelMap: [0, 1]
        ),
        run: .init(durationSeconds: 1_800, outputPath: "reports/rme-loopback.json")
    ))
}

func audioLoopbackRunReport(
    state: AudioLoopbackRunState = .blockedPreflight,
    callback: EndpointCallbackMetrics? = nil,
    handoff: RealtimeAudioHandoffMetrics? = nil,
    cleanup: AudioLoopbackRunCleanupResult? = nil,
    notes: String = "test report"
) -> AudioLoopbackRunReport {
    let configuration = audioLoopbackRmeMadiConfiguration()
    return AudioLoopbackRunReport(
        identity: .init(
            id: "audio-loopback-run-test",
            capturedAt: "2026-05-02T00:00:00Z",
            hostName: "reference-mac",
            runnerKind: .audioDeviceIOProc
        ),
        execution: .init(
            state: state,
            configuration: configuration,
            preflight: audioLoopbackPreflight(configuration: configuration)
        ),
        runtime: .init(callback: callback, handoff: handoff, cleanup: cleanup),
        outcome: .init(verdict: .partial, notes: notes)
    )
}

func audioLoopbackRmeMadiConfiguration() -> AudioLoopbackRunConfiguration {
    AudioLoopbackRunConfiguration(
        devices: .init(inputUID: "rme-madi-uid", outputUID: "rme-madi-uid"),
        audio: .init(sampleRateHertz: 48_000, framesPerBuffer: 32),
        run: .init(durationSeconds: 1_800, outputPath: "reports/rme-loopback.json")
    )
}

func audioLoopbackBuiltInConfiguration() -> AudioLoopbackRunConfiguration {
    AudioLoopbackRunConfiguration(
        devices: .init(inputUID: "built-in-uid", outputUID: "built-in-uid"),
        audio: .init(sampleRateHertz: 48_000, framesPerBuffer: 32),
        run: .init(durationSeconds: 1_800, outputPath: "reports/built-in-loopback.json")
    )
}

func audioLoopbackTestCallbackMetrics() -> EndpointCallbackMetrics {
    EndpointCallbackMetrics(latency: .init(p50Microseconds: 10, p95Microseconds: 20, p99Microseconds: 30, maxMicroseconds: 40), events: .init(missedDeadlines: 0, underruns: 0, overruns: 0))
}

func audioLoopbackTestCleanupFailure() -> AudioLoopbackRunCleanupResult {
    AudioLoopbackRunCleanupResult(failures: [
        .init(operation: "restore sample rate", status: OSStatus(-22))
    ])
}

// swiftlint:disable:next function_parameter_count
func audioLoopbackTestIOProc(
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

func audioLoopbackTestHandoffMetrics() -> RealtimeAudioHandoffMetrics {
    RealtimeAudioHandoffMetrics(
            counters: .init(inputBlocks: 1, outputBlocks: 1, networkSendBlocks: 0, networkReceiveBlocks: 0, droppedInputBlocks: 0, droppedNetworkBlocks: 0, outputUnderrunBlocks: 0, callbackOverrunBlocks: 0),
            buffering: .init(latePackets: 0, maximumBufferedBlocks: 0, ringCapacityBlocks: 1, fullCaptureRingBlocks: 0, invalidInputBlocks: 0, directInputBlocks: 1, remappedInputBlocks: 0, packetFragmentCount: 0),
            observability: .init(allocationWarnings: 0, maximumCaptureRingOccupancyBlocks: 1, maximumPlayoutQueueDepthBlocks: 1, packetizationDuration: .empty, depacketizationDuration: .empty),
            completion: .init(hiddenPlayoutGrowthDetected: false, shutdownCompleted: true, rxBuffer: nil)
        )
}

func rmeMadiDevice(uid: String) -> CoreAudioDeviceInventory {
    let maximumSupportedSampleRate = 96_000
    return measuredFullDuplexDevice(.init(
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
        availableSampleRateRanges: [AudioValueRangeSnapshot(minimum: 48_000, maximum: Double(maximumSupportedSampleRate))],
        currentBufferFrameSize: 32,
        bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128),
        candidateBufferFrames: BufferFrameCandidates(inReportedRange: [16, 32, 64, 128], outsideReportedRange: [], note: "test"),
        inputLatencyFrames: 12,
        outputLatencyFrames: 12,
        inputSafetyOffsetFrames: 0,
        outputSafetyOffsetFrames: 0,
        clockDomain: 1,
        diagnosticNotes: []
    ))
}

func builtInDevice(
    uid: String,
    name: String = "MacBook Air Speakers",
    diagnosticNotes: [String] = []
) -> CoreAudioDeviceInventory {
    let builtInRateRange = AudioValueRangeSnapshot(minimum: 48_000, maximum: 48_000)
    let standardCandidateFrames = BufferFrameCandidates(
        inReportedRange: [16, 32, 64, 128],
        outsideReportedRange: [],
        note: "test"
    )
    return measuredFullDuplexDevice(.init(
        id: 101,
        name: name,
        uid: uid,
        manufacturer: "Apple Inc.",
        transportType: "bltn",
        isAggregate: false,
        inputChannelCount: 2,
        outputChannelCount: 2,
        inputStreamCount: 1,
        outputStreamCount: 1,
        nominalSampleRateHertz: 48_000,
        availableSampleRateRanges: [builtInRateRange],
        currentBufferFrameSize: 32,
        bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128),
        candidateBufferFrames: standardCandidateFrames,
        inputLatencyFrames: 12,
        outputLatencyFrames: 12,
        inputSafetyOffsetFrames: 0,
        outputSafetyOffsetFrames: 0,
        clockDomain: 1,
        diagnosticNotes: diagnosticNotes
    ))
}
