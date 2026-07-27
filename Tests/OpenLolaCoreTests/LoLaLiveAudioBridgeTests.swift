// Verifies that LoLa Float-to-Int16 conversion preserves the expected stereo payload shape.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaFloatToInt16ConversionDuplicatesStereoPayloadShape() throws {
    let samples: [Float] = [-1.0, -1.0, 0.0, 0.0, 1.0, 1.0]

    let data = int16LittleEndianData(fromInterleavedFloat: samples)
    let roundTrip = interleavedFloatData(fromInt16LittleEndian: data)

    #expect(data.count == samples.count * 2)
    #expect(roundTrip.count == samples.count)
    #expect(roundTrip[0] < -0.99)
    #expect(abs(roundTrip[2]) < 0.001)
    #expect(roundTrip[4] > 0.99)
}

@Test
func lolaLinearResamplerConvertsDeviceRateToLoLaRate() throws {
    let resampler = LoLaLinearPCMResampler(inputRate: 48_000, outputRate: 44_100, channels: 2)
    let input = (0..<960).flatMap { frame -> [Float] in
        let sample = Float(frame) / 960.0
        return [sample, sample]
    }

    let output = resampler.appendAndProduce(input)

    #expect(output.count > 1_700)
    #expect(output.count < 1_800)
    #expect(output.count.isMultiple(of: 2))
}

@Test
func lolaLinearResamplerEmitsEqualRateBlockWithoutLookahead() throws {
    let resampler = LoLaLinearPCMResampler(inputRate: 48_000, outputRate: 48_000, channels: 2)
    let first = (0..<64).flatMap { frame in [Float(frame), -Float(frame)] }
    let second = (64..<128).flatMap { frame in [Float(frame), -Float(frame)] }

    #expect(resampler.appendAndProduce(first) == first)
    #expect(resampler.appendAndProduce(second) == second)
}

@Test
func lolaSyntheticAudioClockUsesExactSampleIntervalAndSkipsStaleDeadline() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.2",
        outputPath: "/tmp/lola-live-audio.json"
    ) { input in
        input.framesPerPacket = 64
        input.sampleRateHertz = 48_000
    })
    let interval = LoLaSocketUdpMediaLiveTransmitter.liveAudioIntervalNanoseconds(
        configuration: configuration
    )
    let previous = DispatchTime(uptimeNanoseconds: 1_000)
    let staleNow = DispatchTime(uptimeNanoseconds: 2_000_000)

    #expect(interval == 1_333_333)
    #expect(
        LoLaSocketUdpMediaLiveTransmitter.nextLiveDeadline(
            after: previous,
            intervalNanoseconds: interval,
            now: staleNow
        ).uptimeNanoseconds == staleNow.uptimeNanoseconds + interval
    )
}

@Test
func lolaPlayoutAnchorSchedulesOneFullBlockAheadAndReanchorsAfterCallbackAdvance() {
    var anchor = LoLaLocalPlayoutFrameAnchor()

    #expect(anchor.takeNextFrame(localOutputFrame: 4_096, frameCount: 64) == 4_160)
    #expect(anchor.takeNextFrame(localOutputFrame: 4_128, frameCount: 64) == 4_224)
    #expect(anchor.takeNextFrame(localOutputFrame: 8_192, frameCount: 64) == 8_256)
}

@Test
func lolaPlayoutAnchorResetsForBridgeLifecycleAndSaturatesAtUInt64Maximum() {
    var anchor = LoLaLocalPlayoutFrameAnchor()

    #expect(anchor.takeNextFrame(localOutputFrame: 4_096, frameCount: 64) == 4_160)
    anchor.reset()
    #expect(anchor.takeNextFrame(localOutputFrame: 8_192, frameCount: 64) == 8_256)
    #expect(anchor.takeNextFrame(localOutputFrame: UInt64.max - 1, frameCount: 64) == UInt64.max)
    #expect(anchor.takeNextFrame(localOutputFrame: UInt64.max, frameCount: 64) == UInt64.max)
}

@Test
func lolaCoreAudioBridgeSelectsCommonDeviceRateForBuiltInSplitDevices() throws {
    let inventory = CoreAudioInventoryReport(
        capturedAt: "test",
        hostName: "test-host",
        devices: [
            lolaLiveAudioDevice(uid: "mic", inputChannels: 1, outputChannels: 0, sampleRates: [48_000]),
            lolaLiveAudioDevice(uid: "speaker", inputChannels: 0, outputChannels: 2, sampleRates: [44_100, 48_000])
        ]
    )

    let bridge = try LoLaCoreAudioLiveBridge(
        configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .txRx,
  peer: "192.0.2.2",
  outputPath: "/tmp/lola-live-audio.json"
) { input in
  input.dryRun = false
  input.sampleRateHertz = 44_100
  input.framesPerPacket = 64
  input.audioCapture = "coreaudio:mic"
  input.audioPlayback = "coreaudio:speaker"
}),
        inputDeviceUID: "mic",
        outputDeviceUID: "speaker",
        inventory: inventory
    )

    #expect(bridge.snapshot.graphSampleRateHertz == 48_000)
}

private func lolaLiveAudioDevice(
    uid: String,
    inputChannels: Int,
    outputChannels: Int,
    sampleRates: [Int]
) -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
            identity: .init(id: UInt32(abs(uid.hashValue % 10_000) + 1), name: uid, uid: uid, manufacturer: nil, transportType: nil, isAggregate: false),
            streams: .init(inputChannelCount: inputChannels, outputChannelCount: outputChannels, inputStreamCount: inputChannels > 0 ? 1 : 0, outputStreamCount: outputChannels > 0 ? 1 : 0, inputChannelLayout: nil, outputChannelLayout: nil),
            sampleRates: .init(nominalSampleRateHertz: sampleRates.first.map(Double.init), availableSampleRateRanges: sampleRates.map {
            AudioValueRangeSnapshot(minimum: Double($0), maximum: Double($0))
        }),
            buffering: .init(currentBufferFrameSize: 64, bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 64, maximum: 512), candidateBufferFrames: BufferFrameCandidates(
            inReportedRange: [64, 128],
            outsideReportedRange: [],
            note: "test"
        )),
            timing: .init(inputLatencyFrames: nil, outputLatencyFrames: nil, inputSafetyOffsetFrames: nil, outputSafetyOffsetFrames: nil, clockDomain: nil),
            diagnosticNotes: []
        )
}
