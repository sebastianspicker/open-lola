import CoreGraphics
import Foundation
import Testing

@testable import OpenLolaCore


@Test
func directPeerRealtimeAudioPreflightBlocksMissingAndSeparateDeviceShapes() throws {
    let inventory = splitDeviceCoreAudioInventory()
    let missing = directPeerRealtimeAudioGraphConfiguration(audioDeviceUID: "missing")
    let outputOnly = directPeerRealtimeAudioGraphConfiguration(audioDeviceUID: "output-only")
    let splitDevices = directPeerSplitRealtimeAudioGraphConfiguration()

    #expect(throws: DirectPeerAudioGraphError.missingDeviceUID("missing")) {
        _ = try DirectPeerRealtimeAudioGraph.preflight(configuration: missing, inventory: inventory)
    }
    #expect(throws: DirectPeerAudioGraphError.deviceNotFullDuplex("output-only")) {
        _ = try DirectPeerRealtimeAudioGraph.preflight(configuration: outputOnly, inventory: inventory)
    }
    let splitPreflight = try DirectPeerRealtimeAudioGraph.preflight(configuration: splitDevices, inventory: inventory)
    #expect(splitPreflight.device?.uid == "input-only")
    #expect(splitPreflight.outputDevice?.uid == "output-only")
    #expect(splitPreflight.canStart)
}

private func splitDeviceCoreAudioInventory() -> CoreAudioInventoryReport {
    CoreAudioInventoryReport(
        capturedAt: "2026-05-08T00:00:00Z",
        hostName: "test-host",
        devices: [
            coreAudioDeviceInventory(
                id: 2,
                name: "Input Only",
                uid: "input-only",
                inputChannelCount: 2,
                outputChannelCount: 0,
                inputStreamCount: 1,
                outputStreamCount: 0
            ),
            coreAudioDeviceInventory(
                id: 1,
                name: "Output Only",
                uid: "output-only",
                inputChannelCount: 0,
                outputChannelCount: 2,
                inputStreamCount: 0,
                outputStreamCount: 1
            )
        ]
    )
}

private func coreAudioDeviceInventory(
    id: UInt32,
    name: String,
    uid: String,
    inputChannelCount: Int,
    outputChannelCount: Int,
    inputStreamCount: Int,
    outputStreamCount: Int
) -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
        id: id,
        name: name,
        uid: uid,
        manufacturer: nil,
        transportType: nil,
        isAggregate: false,
        inputChannelCount: inputChannelCount,
        outputChannelCount: outputChannelCount,
        inputStreamCount: inputStreamCount,
        outputStreamCount: outputStreamCount,
        nominalSampleRateHertz: 48_000,
        availableSampleRateRanges: [AudioValueRangeSnapshot(minimum: 48_000, maximum: 48_000)],
        currentBufferFrameSize: 32,
        bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128),
        candidateBufferFrames: BufferFrameCandidates(
            candidates: [16, 32],
            reportedRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128)
        ),
        inputLatencyFrames: nil,
        outputLatencyFrames: nil,
        inputSafetyOffsetFrames: nil,
        outputSafetyOffsetFrames: nil,
        clockDomain: nil,
        diagnosticNotes: []
    )
}

private func directPeerRealtimeAudioGraphConfiguration(
    audioDeviceUID: String
) -> DirectPeerRealtimeAudioGraphConfiguration {
    DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: audioDeviceUID,
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0, 1],
        outputChannelMap: [0, 1]
    )
}

private func directPeerSplitRealtimeAudioGraphConfiguration() -> DirectPeerRealtimeAudioGraphConfiguration {
    DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "input-only",
        inputDeviceUID: "input-only",
        outputDeviceUID: "output-only",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0, 1],
        outputChannelMap: [0, 1]
    )
}

@Test
func directPeerAVFastestSyncPolicyUsesMediaSourceToleranceWithoutAudioDelay() throws {
    try expectFastestProductionAVSyncPolicyUsesOneFrameTolerance()
    try expectFastestSyntheticAVSyncPolicyUsesTwoFrameTolerance()
}

private func expectFastestProductionAVSyncPolicyUsesOneFrameTolerance() throws {
    let bufferPolicy = try DirectPeerSessionAVBufferPolicy.resolve(
        avProfile: .fastest,
        rxBufferProfile: .direct
    )
    let frameIntervalNanoseconds: UInt64 = 33_333_333
    let policy = directPeerAVSyncPolicy(
        configuration: directPeerAVSupportConfiguration(mediaSourceMode: .production),
        bufferPolicy: bufferPolicy,
        videoFrameIntervalNanoseconds: frameIntervalNanoseconds
    )

    #expect(policy.profile == .directAudioFirst)
    #expect(policy.audioMayDelayForVideo == false)
    #expect(policy.videoAlignmentToleranceMicroseconds == Double(frameIntervalNanoseconds) / 1_000)
    #expect(AVTimestampAligner.decision(
        videoTimestampNanoseconds: 133_333_333,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: policy
    ).action == .renderNow)
    #expect(AVTimestampAligner.decision(
        videoTimestampNanoseconds: 66_666_667,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: policy
    ).action == .renderNow)
}

private func expectFastestSyntheticAVSyncPolicyUsesTwoFrameTolerance() throws {
    let syntheticBufferPolicy = try DirectPeerSessionAVBufferPolicy.resolve(
        avProfile: .fastest,
        rxBufferProfile: .direct
    )
    let frameIntervalNanoseconds: UInt64 = 33_333_333
    let syntheticPolicy = directPeerAVSyncPolicy(
        configuration: directPeerAVSupportConfiguration(mediaSourceMode: .syntheticFixture),
        bufferPolicy: syntheticBufferPolicy,
        videoFrameIntervalNanoseconds: frameIntervalNanoseconds
    )

    #expect(syntheticPolicy.profile == .directAudioFirst)
    #expect(syntheticPolicy.audioMayDelayForVideo == false)
    #expect(syntheticPolicy.videoAlignmentToleranceMicroseconds == Double(frameIntervalNanoseconds * 2) / 1_000)
    #expect(AVTimestampAligner.decision(
        videoTimestampNanoseconds: 166_666_666,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: syntheticPolicy
    ).action == .renderNow)
    #expect(AVTimestampAligner.decision(
        videoTimestampNanoseconds: 166_666_668,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: syntheticPolicy
    ).action == .deferVideo)
}

@Test
func directPeerAVFoundationFrameHelpersRetimestampDeferAndGateDelivery() {
    let presentationFrame = rawCapturedVideoFrame(sequenceNumber: 10)
    let hostTimed = directPeerHostTimedVideoFrame(
        presentationFrame,
        hostTimeNanoseconds: 123_456_789
    )

    #expect(hostTimed.metadata.sequenceNumber == presentationFrame.metadata.sequenceNumber)
    #expect(hostTimed.metadata.timestampNanoseconds == 123_456_789)
    #expect(hostTimed.metadata.timestampBasis == .hostUptimeNanoseconds)
    #expect(hostTimed.payload == presentationFrame.payload)

    var result = DirectPeerVideoRXDrainResult()
    var deferredFrame: RawCapturedVideoFrame?

    deferVideoFrameForSync(
        rawCapturedVideoFrame(sequenceNumber: 1),
        deferredFrame: &deferredFrame,
        result: &result
    )
    deferVideoFrameForSync(
        rawCapturedVideoFrame(sequenceNumber: 2),
        deferredFrame: &deferredFrame,
        result: &result
    )

    #expect(deferredFrame?.metadata.sequenceNumber == 2)
    #expect(result.framesReplacedDuringSyncDefer == 1)
    #expect(result.framesDroppedForSync == 1)

    var metrics = DirectPeerSessionAVRuntimeMetrics()
    dropDeferredVideoFrameAtShutdown(&deferredFrame, metrics: &metrics)
    #expect(deferredFrame == nil)
    #expect(metrics.videoFramesDroppedForSync == 1)

    var gate = DirectPeerAVFoundationFrameDeliveryGate()
    let first = rawCapturedVideoFrame(sequenceNumber: 7)
    let second = rawCapturedVideoFrame(sequenceNumber: 8)
    let firstDelivery = gate.shouldDeliver(first)
    let duplicateFirstDelivery = gate.shouldDeliver(first)
    let secondDelivery = gate.shouldDeliver(second)

    #expect(firstDelivery)
    #expect(!duplicateFirstDelivery)
    #expect(secondDelivery)

    gate.reset()
    let firstDeliveryAfterReset = gate.shouldDeliver(first)
    #expect(firstDeliveryAfterReset)
}

@Test
func directPeerVideoReassemblerUsesNegotiatedFragmentBudgetAndTracksOversizeDrops() throws {
    var configuration = directPeerAVSupportConfiguration(mediaSourceMode: .syntheticFixture)
    configuration.avProfile = .fastest
    configuration.rxBufferProfile = .direct
    configuration.videoWidth = 2
    configuration.videoHeight = 2
    let reassembler = try directPeerVideoReassembler(for: configuration)
    var fragment = try #require(RawVideoFrameTransport.fragments(
        for: rawCapturedVideoFrame(sequenceNumber: 1),
        maxPacketBytes: 512
    ).first)
    fragment.fragmentCount = 129

    #expect(throws: VideoTransportFragmentError.invalidFragmentCount(129)) {
        _ = try reassembler.receiveRaw(fragment)
    }

}

private func rawCapturedVideoFrame(sequenceNumber: UInt64) -> RawCapturedVideoFrame {
    RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: 1,
            sequenceNumber: sequenceNumber,
            timestampNanoseconds: sequenceNumber,
            timestampBasis: .hostUptimeNanoseconds,
            sourceRole: .avFoundationDevice,
            width: 2,
            height: 2,
            pixelFormat: "bgra8",
            frameRate: VideoFrameRate(numerator: 30, denominator: 1),
            fingerprint: "test-frame-\(sequenceNumber)"
        ),
        payload: Data(repeating: UInt8(sequenceNumber & 0xff), count: 16)
    )
}
