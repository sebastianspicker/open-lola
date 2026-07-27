// Shared RME fastest audio path test fixtures builders keep multi-file test scenarios deterministic.
import Foundation

@testable import OpenLolaCore

func rmeMadiDevice(
    uid: String,
    overrides: RmeMadiDeviceOverrides = .init()
) -> CoreAudioDeviceInventory {
    var fixture = MeasuredFullDuplexDeviceFixture(id: 100, name: overrides.name, uid: uid)
    fixture.manufacturer = "RME"
    fixture.transportType = overrides.transportType
    fixture.isAggregate = overrides.isAggregate
    fixture.inputChannelCount = overrides.inputChannelCount
    fixture.outputChannelCount = overrides.outputChannelCount
    fixture.inputStreamCount = 1
    fixture.outputStreamCount = 1
    fixture.nominalSampleRateHertz = 48_000
    fixture.availableSampleRateRanges = overrides.availableSampleRateRanges
    fixture.currentBufferFrameSize = 32
    fixture.bufferFrameSizeRange = AudioValueRangeSnapshot(minimum: 8, maximum: 128)
    fixture.candidateBufferFrames = overrides.candidateBufferFrames
    fixture.inputLatencyFrames = 12
    fixture.outputLatencyFrames = 12
    fixture.inputSafetyOffsetFrames = 0
    fixture.outputSafetyOffsetFrames = 0
    fixture.clockDomain = overrides.clockDomain
    fixture.diagnosticNotes = ["test fixture"]
    return measuredFullDuplexDevice(fixture)
}

struct RmeMadiDeviceOverrides {
    var name = "RME Fireface UFX+ MADI Thunderbolt"
    var transportType = "thun"
    var isAggregate = false
    var inputChannelCount = 64
    var outputChannelCount = 64
    var availableSampleRateRanges = [
        AudioValueRangeSnapshot(minimum: 48_000, maximum: 96_000)
    ]
    var candidateBufferFrames = BufferFrameCandidates(
        inReportedRange: [8, 16, 32, 64, 128],
        outsideReportedRange: [256],
        note: "reported-range-only"
    )
    var clockDomain: UInt32? = 1
}

func builtInFullDuplexDevice(uid: String) -> CoreAudioDeviceInventory {
    builtInDevice(
        uid: uid,
        name: "Built-in Output",
        diagnosticNotes: ["test fixture"]
    )
}
