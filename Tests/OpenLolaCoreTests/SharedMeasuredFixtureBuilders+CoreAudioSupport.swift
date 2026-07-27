// Builds measured and synthetic Core Audio device fixtures for full-duplex tests.
import Foundation

@testable import OpenLolaCore

/// Explicit measured device metadata shared by full-duplex Core Audio test fixtures.
struct MeasuredFullDuplexDeviceFixture {
    var id: UInt32 = 0
    var name = "Measured test device"
    var uid = "measured-test-device"
    var manufacturer: String?
    var transportType: String?
    var isAggregate = false
    var inputChannelCount = 0
    var outputChannelCount = 0
    var inputStreamCount = 0
    var outputStreamCount = 0
    var nominalSampleRateHertz = 48_000.0
    var availableSampleRateRanges: [AudioValueRangeSnapshot] = []
    var currentBufferFrameSize: UInt32 = 32
    var bufferFrameSizeRange = AudioValueRangeSnapshot(minimum: 32, maximum: 32)
    var candidateBufferFrames = BufferFrameCandidates(inReportedRange: [32], outsideReportedRange: [], note: "default measured fixture")
    var inputLatencyFrames: UInt32?
    var outputLatencyFrames: UInt32?
    var inputSafetyOffsetFrames: UInt32?
    var outputSafetyOffsetFrames: UInt32?
    var clockDomain: UInt32?
    var diagnosticNotes: [String] = []
}

func measuredFullDuplexDevice(
    _ fixture: MeasuredFullDuplexDeviceFixture
) -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
        identity: measuredFullDuplexIdentity(fixture),
        streams: measuredFullDuplexStreams(fixture),
        sampleRates: measuredFullDuplexSampleRates(fixture),
        buffering: measuredFullDuplexBuffering(fixture),
        timing: measuredFullDuplexTiming(fixture),
        diagnosticNotes: fixture.diagnosticNotes
    )
}

private func measuredFullDuplexIdentity(
    _ fixture: MeasuredFullDuplexDeviceFixture
) -> CoreAudioDeviceInventory.Identity {
    .init(
        id: fixture.id,
        name: fixture.name,
        uid: fixture.uid,
        manufacturer: fixture.manufacturer,
        transportType: fixture.transportType,
        isAggregate: fixture.isAggregate
    )
}

private func measuredFullDuplexStreams(
    _ fixture: MeasuredFullDuplexDeviceFixture
) -> CoreAudioDeviceInventory.Streams {
    .init(
        inputChannelCount: fixture.inputChannelCount,
        outputChannelCount: fixture.outputChannelCount,
        inputStreamCount: fixture.inputStreamCount,
        outputStreamCount: fixture.outputStreamCount,
        inputChannelLayout: nil,
        outputChannelLayout: nil
    )
}

private func measuredFullDuplexSampleRates(
    _ fixture: MeasuredFullDuplexDeviceFixture
) -> CoreAudioDeviceInventory.SampleRates {
    .init(
        nominalSampleRateHertz: fixture.nominalSampleRateHertz,
        availableSampleRateRanges: fixture.availableSampleRateRanges
    )
}

private func measuredFullDuplexBuffering(
    _ fixture: MeasuredFullDuplexDeviceFixture
) -> CoreAudioDeviceInventory.Buffering {
    .init(
        currentBufferFrameSize: fixture.currentBufferFrameSize,
        bufferFrameSizeRange: fixture.bufferFrameSizeRange,
        candidateBufferFrames: fixture.candidateBufferFrames
    )
}

private func measuredFullDuplexTiming(
    _ fixture: MeasuredFullDuplexDeviceFixture
) -> CoreAudioDeviceInventory.Timing {
    .init(
        inputLatencyFrames: fixture.inputLatencyFrames,
        outputLatencyFrames: fixture.outputLatencyFrames,
        inputSafetyOffsetFrames: fixture.inputSafetyOffsetFrames,
        outputSafetyOffsetFrames: fixture.outputSafetyOffsetFrames,
        clockDomain: fixture.clockDomain
    )
}

/// Explicit synthetic device metadata used by tests that exercise full-duplex Core Audio selection.
struct SyntheticFullDuplexDeviceFixture {
    var id: UInt32 = 0
    var name = "Synthetic full-duplex device"
    var uid = "synthetic-full-duplex"
    var manufacturer: String?
    var transportType: String?
    var inputChannelCount = 2
    var outputChannelCount = 2
    var inputStreamCount: Int?
    var outputStreamCount: Int?
    var availableSampleRateRanges = [AudioValueRangeSnapshot(minimum: 48_000, maximum: 48_000)]
    var currentBufferFrameSize: UInt32? = 32
    var bufferFrameSizeRange = AudioValueRangeSnapshot(minimum: 32, maximum: 128)
    var candidateBufferFrames = syntheticFullDuplexBufferCandidates()
    var inputLatencyFrames: UInt32?
    var outputLatencyFrames: UInt32?
    var inputSafetyOffsetFrames: UInt32?
    var outputSafetyOffsetFrames: UInt32?
    var clockDomain: UInt32?
    var diagnosticNotes: [String] = []
}

func syntheticFullDuplexDevice(
    _ fixture: SyntheticFullDuplexDeviceFixture
) -> CoreAudioDeviceInventory {
    var measured = MeasuredFullDuplexDeviceFixture()
    measured.id = fixture.id
    measured.name = fixture.name
    measured.uid = fixture.uid
    measured.manufacturer = fixture.manufacturer
    measured.transportType = fixture.transportType
    measured.inputChannelCount = fixture.inputChannelCount
    measured.outputChannelCount = fixture.outputChannelCount
    measured.inputStreamCount = fixture.inputStreamCount ?? (fixture.inputChannelCount > 0 ? 1 : 0)
    measured.outputStreamCount = fixture.outputStreamCount ?? (fixture.outputChannelCount > 0 ? 1 : 0)
    measured.availableSampleRateRanges = fixture.availableSampleRateRanges
    measured.currentBufferFrameSize = fixture.currentBufferFrameSize ?? 32
    measured.bufferFrameSizeRange = fixture.bufferFrameSizeRange
    measured.candidateBufferFrames = fixture.candidateBufferFrames
    measured.inputLatencyFrames = fixture.inputLatencyFrames
    measured.outputLatencyFrames = fixture.outputLatencyFrames
    measured.inputSafetyOffsetFrames = fixture.inputSafetyOffsetFrames
    measured.outputSafetyOffsetFrames = fixture.outputSafetyOffsetFrames
    measured.clockDomain = fixture.clockDomain
    measured.diagnosticNotes = fixture.diagnosticNotes
    return measuredFullDuplexDevice(measured)
}

func syntheticFullDuplexBufferCandidates() -> BufferFrameCandidates {
    BufferFrameCandidates(
        candidates: [32, 64, 128],
        reportedRange: AudioValueRangeSnapshot(minimum: 32, maximum: 128)
    )
}
