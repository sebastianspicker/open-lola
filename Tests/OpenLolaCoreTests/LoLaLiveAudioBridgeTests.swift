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
func lolaCoreAudioBridgeSelectsCommonDeviceRateForBuiltInSplitDevices() throws {
    let inventory = CoreAudioInventoryReport(
        capturedAt: "test",
        hostName: "test-host",
        devices: [
            lolaLiveAudioDevice(uid: "mic", inputChannels: 1, outputChannels: 0, sampleRates: [48_000]),
            lolaLiveAudioDevice(uid: "speaker", inputChannels: 0, outputChannels: 2, sampleRates: [44_100, 48_000]),
        ]
    )

    let bridge = try LoLaCoreAudioLiveBridge(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .txRx,
            peer: "192.0.2.2",
            outputPath: "/tmp/lola-live-audio.json",
            dryRun: false,
            sampleRateHertz: 44_100,
            framesPerPacket: 64,
            audioCapture: "coreaudio:mic",
            audioPlayback: "coreaudio:speaker"
        ),
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
        id: UInt32(abs(uid.hashValue % 10_000) + 1),
        name: uid,
        uid: uid,
        manufacturer: nil,
        transportType: nil,
        isAggregate: false,
        inputChannelCount: inputChannels,
        outputChannelCount: outputChannels,
        inputStreamCount: inputChannels > 0 ? 1 : 0,
        outputStreamCount: outputChannels > 0 ? 1 : 0,
        nominalSampleRateHertz: sampleRates.first.map(Double.init),
        availableSampleRateRanges: sampleRates.map {
            AudioValueRangeSnapshot(minimum: Double($0), maximum: Double($0))
        },
        currentBufferFrameSize: 64,
        bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 64, maximum: 512),
        candidateBufferFrames: BufferFrameCandidates(
            inReportedRange: [64, 128],
            outsideReportedRange: [],
            note: "test"
        ),
        inputLatencyFrames: nil,
        outputLatencyFrames: nil,
        inputSafetyOffsetFrames: nil,
        outputSafetyOffsetFrames: nil,
        clockDomain: nil,
        diagnosticNotes: []
    )
}
