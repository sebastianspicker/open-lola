import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerRealtimeAudioGraphAdaptivePolicyChangesTargetOutsideCallback() throws {
    let graph = try DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "synthetic",
        sampleRateHertz: 48_000,
        framesPerBuffer: 1,
        channelCount: 1,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0],
        outputChannelMap: [0],
        ringCapacityBlocks: 1,
        rxBufferPolicy: try .adaptive(
            framesPerPacket: 1,
            sampleRateHertz: 48_000,
            minimumPackets: 1,
            initialPackets: 1,
            maximumPackets: 2
        )
    ))
    let oldHostTime = DispatchTime.now().uptimeNanoseconds - 5_000_000

    #expect(graph.queuePlayoutPayload(float32Data([1]), startFrame: 0, hostTimeNanoseconds: oldHostTime) == .stored)
    #expect(graph.queuePlayoutPayload(float32Data([2]), startFrame: 1, hostTimeNanoseconds: oldHostTime) == .full)

    let snapshot = try #require(graph.rxBufferRuntimeSnapshot())
    #expect(snapshot.currentTargetFrames == 2)
    #expect(snapshot.maximumObservedTargetFrames == 2)
    #expect(snapshot.targetChangeEvents.count == 1)
    #expect(snapshot.targetChangeEvents.allSatisfy { !$0.changedInsideAudioCallback })
}

@Test
func directPeerRealtimeAudioGraphRejectsInvalidAdaptivePolicy() throws {
    let invalidPolicy = RxBufferPolicy(
        profile: .adaptive,
        framesPerPacket: 1,
        sampleRateHertz: 48_000,
        minimumTargetFrames: 1,
        targetFrames: 1,
        maximumTargetFrames: 2,
        fastestAudioPassEligible: false,
        adaptationChangesOutsideCallback: false,
        notes: "Invalid adaptive policy for graph setup failure coverage."
    )

    #expect(throws: RxBufferPolicyValidationError.adaptiveRequiresOutsideCallbackChanges) {
        _ = try DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
            audioDeviceUID: "synthetic",
            sampleRateHertz: 48_000,
            framesPerBuffer: 1,
            channelCount: 1,
            sampleFormat: .float32LittleEndian,
            inputChannelMap: [0],
            outputChannelMap: [0],
            ringCapacityBlocks: 1,
            rxBufferPolicy: invalidPolicy
        ))
    }
}

private func float32Data(_ values: [Float]) -> Data {
    values.withUnsafeBufferPointer { buffer in
        Data(buffer: buffer)
    }
}
