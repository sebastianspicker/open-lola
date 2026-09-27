// Checks numerical order, clipping, and retained-buffer ownership in the prepared mixer.
import Foundation
@testable import OpenLolaMediaPlatform
import Testing

@Test func preparedInt16MixRetainsPerRouteSaturationAndHalfRounding() throws {
    var engine = try parityMixer(format: .int16LittleEndian, channels: 2, frames: 2, routes: [
        parityRoute(source: 0), parityRoute(source: 0), parityRoute(source: 1),
        parityRoute(source: 1, destination: 1, gain: 20 * log10(0.5))
    ])
    let input: [Int16] = [30_000, -30_000, 1, -1]
    let expected: [Int16] = [2_767, -15_000, 1, -1]
    let retained = try engine.applyReceiverMix(input.withUnsafeBytes { Data($0) })
    #expect(retained == expected.withUnsafeBytes { Data($0) })
    let silent = try engine.applyReceiverMix(Data(count: input.count * 2))
    #expect(silent == Data(count: expected.count * 2))
    let negative: [Int16] = [-30_000, 30_000, -1, 1]
    let negativeExpected: [Int16] = [-2_768, 15_000, -1, 1]
    #expect(try engine.applyReceiverMix(negative.withUnsafeBytes { Data($0) })
            == negativeExpected.withUnsafeBytes { Data($0) })
    #expect(retained == expected.withUnsafeBytes { Data($0) })
    #expect(engine.mixExecutionPlan.revision == engine.mixStore.revision)
}

@Test func preparedFloatMixPreservesRouteOrderAndPanTolerance() throws {
    var ordered = try parityMixer(format: .float32LittleEndian, channels: 3, frames: 1, routes: [
        parityRoute(source: 0), parityRoute(source: 2), parityRoute(source: 1)
    ])
    let input: [Float] = [16_777_216, -16_777_216, 1]
    #expect(try ordered.applyReceiverMix(input.withUnsafeBytes { Data($0) }) == Data(count: 8))

    for pan in [0.0, receiverMixPanTolerance, receiverMixPanTolerance.nextUp] {
        var engine = try parityMixer(format: .float32LittleEndian, channels: 2, frames: 1, routes: [
            parityRoute(source: 0, pan: pan), parityRoute(source: 1, destination: 1, muted: true)
        ])
        let samples: [Float] = [1, 0.75]
        let expected: [Float] = pan <= receiverMixPanTolerance
            ? [1, 0]
            : [Float(sqrt((1 - pan) / 2)), Float(sqrt((1 + pan) / 2))]
        #expect(try engine.applyReceiverMix(samples.withUnsafeBytes { Data($0) })
                == expected.withUnsafeBytes { Data($0) })
    }
}

@Test func preparedMixMetadataTracksReplacedSnapshotRevision() throws {
    let mode = try madiSyntheticUdpPcmV2AudioTransportMode(
        channelCount: 2, framesPerPacket: 1, sampleRateHertz: 48_000,
        sampleFormat: .int16LittleEndian, maxTransmissionUnitBytes: 1200
    )
    var store = try ReceiverMixSnapshotStore(
        initial: .init(routes: [parityRoute(source: 0)], requiresDestructiveDownmix: false),
        inputChannelCount: 2, outputChannelCount: 2
    )
    let original = MadiReceiverMixExecutionPlan(mode: mode, prepared: store.prepared, revision: store.revision, outputChannelCount: 2)
    try store.replace(
        with: .init(routes: [parityRoute(source: 1, destination: 1)], requiresDestructiveDownmix: false),
        inputChannelCount: 2, outputChannelCount: 2
    )
    let replacement = MadiReceiverMixExecutionPlan(mode: mode, prepared: store.prepared, revision: store.revision, outputChannelCount: 2)
    #expect(original.revision == 1)
    #expect(replacement.revision == 2)
    #expect(original.routes[0].sourceChannelOffsetBytes == 0)
    #expect(replacement.routes[0].sourceChannelOffsetBytes == 2)
}

private func parityRoute(source: Int, destination: Int = 0, gain: Double = 0, pan: Double = 0, muted: Bool = false) -> ReceiverMixRoute {
    .init(sourceChannelIndex: source, destinationChannelIndex: destination, gainDb: gain, muted: muted, pan: pan)
}

private func parityMixer(format: UdpPcmSampleFormat, channels: Int, frames: Int, routes: [ReceiverMixRoute]) throws -> MadiReceiveEngine {
    let mode = try madiSyntheticUdpPcmV2AudioTransportMode(
        channelCount: channels, framesPerPacket: frames, sampleRateHertz: 48_000,
        sampleFormat: format, maxTransmissionUnitBytes: 1200
    )
    return try MadiReceiveEngine(configuration: .init(
        mode: mode, receiverMix: .init(routes: routes, requiresDestructiveDownmix: false), outputChannelCount: 2
    ))
}
