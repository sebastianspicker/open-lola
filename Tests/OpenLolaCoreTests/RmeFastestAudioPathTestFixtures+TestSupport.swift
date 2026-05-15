import Foundation

@testable import OpenLolaCore

func rmeMadiDevice(
    uid: String,
    name: String = "RME Fireface UFX+ MADI Thunderbolt",
    transportType: String = "thun",
    isAggregate: Bool = false,
    inputChannelCount: Int = 64,
    outputChannelCount: Int = 64,
    availableSampleRateRanges: [AudioValueRangeSnapshot] = [
        AudioValueRangeSnapshot(minimum: 48_000, maximum: 96_000)
    ],
    candidateBufferFrames: BufferFrameCandidates = BufferFrameCandidates(
        inReportedRange: [8, 16, 32, 64, 128],
        outsideReportedRange: [256],
        note: "reported-range-only"
    ),
    clockDomain: UInt32? = 1
) -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
        id: 100,
        name: name,
        uid: uid,
        manufacturer: "RME",
        transportType: transportType,
        isAggregate: isAggregate,
        inputChannelCount: inputChannelCount,
        outputChannelCount: outputChannelCount,
        inputStreamCount: 1,
        outputStreamCount: 1,
        nominalSampleRateHertz: 48_000,
        availableSampleRateRanges: availableSampleRateRanges,
        currentBufferFrameSize: 32,
        bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 8, maximum: 128),
        candidateBufferFrames: candidateBufferFrames,
        inputLatencyFrames: 12,
        outputLatencyFrames: 12,
        inputSafetyOffsetFrames: 0,
        outputSafetyOffsetFrames: 0,
        clockDomain: clockDomain,
        diagnosticNotes: ["test fixture"]
    )
}

func builtInFullDuplexDevice(uid: String) -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
        id: 101,
        name: "Built-in Output",
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
        diagnosticNotes: ["test fixture"]
    )
}
