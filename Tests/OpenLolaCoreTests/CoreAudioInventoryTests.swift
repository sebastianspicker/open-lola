import Foundation
import Testing

@testable import OpenLolaCore

@Test
func coreAudioInventoryValidationRejectsEmptyMismatchedAndUnknownDevices() throws {
    let emptyReport = try loadInventoryFixture(named: "core-audio-inventory-empty")

    #expect(throws: CoreAudioInventoryValidationError.noDevices) {
        try emptyReport.validate()
    }

    let mismatchReport = CoreAudioInventoryReport(
        capturedAt: "2026-05-03T00:00:00Z",
        hostName: "test-host",
        devices: [
            CoreAudioDeviceInventory(
                id: 1,
                name: "Mismatch Device",
                uid: "mismatch-device",
                manufacturer: "Test",
                transportType: "USB",
                isAggregate: false,
                inputChannelCount: 2,
                outputChannelCount: 2,
                inputStreamCount: 1,
                outputStreamCount: 1,
                inputChannelLayout: AudioChannelLayoutSnapshot(
                    scope: .input,
                    streamChannelCounts: [1]
                ),
                outputChannelLayout: AudioChannelLayoutSnapshot(
                    scope: .output,
                    streamChannelCounts: [2]
                ),
                nominalSampleRateHertz: 48_000,
                availableSampleRateRanges: [
                    AudioValueRangeSnapshot(minimum: 48_000, maximum: 48_000)
                ],
                currentBufferFrameSize: 64,
                bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128),
                candidateBufferFrames: BufferFrameCandidates(
                    inReportedRange: [16, 32, 64, 128],
                    outsideReportedRange: [],
                    note: "test"
                ),
                inputLatencyFrames: 0,
                outputLatencyFrames: 0,
                inputSafetyOffsetFrames: 0,
                outputSafetyOffsetFrames: 0,
                clockDomain: 1,
                diagnosticNotes: ["test"]
            )
        ]
    )

    #expect(throws: CoreAudioInventoryValidationError.channelLayoutChannelCountMismatch(
        deviceID: 1,
        scope: .input,
        expected: 2,
        actual: 1
    )) {
        try mismatchReport.validate()
    }

    let unknownReport = CoreAudioInventoryReport(
        capturedAt: "2026-05-03T00:00:00Z",
        hostName: "test-host",
        devices: [
            makeCoreAudioInventoryDevice(id: 42, name: "Unknown Core Audio device 42", uid: "unknown-42")
        ]
    )

    #expect(throws: CoreAudioInventoryValidationError.missingDeviceIdentity(42)) {
        try unknownReport.validate()
    }
}

@Test
func coreAudioInventoryModelsClassifyBuffersAndStableChannels() throws {
    let candidates = BufferFrameCandidates(
        candidates: [8, 16, 32, 64, 128, 256],
        reportedRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128)
    )

    #expect(candidates.inReportedRange == [16, 32, 64, 128])
    #expect(candidates.outsideReportedRange == [8, 256])
    #expect(candidates.note == "reported-range-only")

    let layout = AudioChannelLayoutSnapshot(
        scope: .input,
        streamChannelCounts: [2, 6]
    )

    #expect(layout.totalChannelCount == 8)
    #expect(layout.channelLabels == [
        "input-1",
        "input-2",
        "input-3",
        "input-4",
        "input-5",
        "input-6",
        "input-7",
        "input-8",
    ])

    let device = CoreAudioDeviceInventory(
        id: 10,
        name: "RME MADI",
        uid: "rme-madi",
        manufacturer: "RME",
        transportType: "thun",
        isAggregate: false,
        inputChannelCount: 4,
        outputChannelCount: 2,
        inputStreamCount: 1,
        outputStreamCount: 1,
        inputChannelLayout: AudioChannelLayoutSnapshot(
            scope: .input,
            streamChannelCounts: [4],
            channelLabels: ["madi-1", "madi-2", "madi-3", "madi-4"]
        ),
        outputChannelLayout: AudioChannelLayoutSnapshot(
            scope: .output,
            streamChannelCounts: [2],
            channelLabels: ["phones-l", "phones-r"]
        ),
        nominalSampleRateHertz: 48_000,
        availableSampleRateRanges: [
            AudioValueRangeSnapshot(minimum: 48_000, maximum: 96_000)
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
        diagnosticNotes: ["test"]
    )

    #expect(device.channelSet(scope: .input).sortedByStableSourceIndex.map(\.label) == [
        "madi-1",
        "madi-2",
        "madi-3",
        "madi-4",
    ])
    let selected = try device.selectedChannelSet(scope: .input, stableSourceIndices: [3, 1])
    #expect(selected.sortedByStableSourceIndex.map(\.stableSourceIndex) == [1, 3])
    #expect(device.channelSet(scope: .output).sortedByStableSourceIndex.map(\.label) == [
        "phones-l",
        "phones-r",
    ])
}

@Test
func coreAudioInventoryJSONRoundTripPreservesDevices() throws {
    let report = try loadInventoryFixture(named: "core-audio-inventory-valid")
    let jsonData = try report.prettyJSONData()
    let decoded = try CoreAudioInventoryReport.decode(from: jsonData)

    #expect(decoded == report)
}

@Test
func coreAudioInventoryReaderFallbackPreservesDiagnostics() throws {
    let identity = coreAudioDeviceIdentity(deviceID: 42, name: nil, uid: nil)

    #expect(identity.name == "Unknown Core Audio device 42")
    #expect(identity.uid == "unknown-42")
    #expect(identity.diagnosticNotes.contains("device name fallback used"))
    #expect(identity.diagnosticNotes.contains("device uid fallback used"))
}

private func makeCoreAudioInventoryDevice(
    id: UInt32,
    name: String = "RME MADI",
    uid: String = "rme-madi"
) -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
        id: id,
        name: name,
        uid: uid,
        manufacturer: "RME",
        transportType: "thun",
        isAggregate: false,
        inputChannelCount: 2,
        outputChannelCount: 2,
        inputStreamCount: 1,
        outputStreamCount: 1,
        inputChannelLayout: AudioChannelLayoutSnapshot(
            scope: .input,
            streamChannelCounts: [2]
        ),
        outputChannelLayout: AudioChannelLayoutSnapshot(
            scope: .output,
            streamChannelCounts: [2]
        ),
        nominalSampleRateHertz: 48_000,
        availableSampleRateRanges: [
            AudioValueRangeSnapshot(minimum: 48_000, maximum: 48_000)
        ],
        currentBufferFrameSize: 64,
        bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128),
        candidateBufferFrames: BufferFrameCandidates(
            inReportedRange: [16, 32, 64, 128],
            outsideReportedRange: [],
            note: "test"
        ),
        inputLatencyFrames: 0,
        outputLatencyFrames: 0,
        inputSafetyOffsetFrames: 0,
        outputSafetyOffsetFrames: 0,
        clockDomain: 1,
        diagnosticNotes: ["test"]
    )
}

private func loadInventoryFixture(named name: String) throws -> CoreAudioInventoryReport {
    let url = try inventoryFixtureURL(named: name)
    return try CoreAudioInventoryReport.decode(from: Data(contentsOf: url))
}

private func inventoryFixtureURL(named name: String) throws -> URL {
    let nestedURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "CoreAudioInventory/valid"
    )

    return try #require(
        nestedURL ?? Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: nil
        )
    )
}
