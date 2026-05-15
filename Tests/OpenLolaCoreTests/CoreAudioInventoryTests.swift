import Foundation
import Testing

@testable import OpenLolaCore

@Test
func coreAudioInventoryFixtureDecodesAndValidates() throws {
    let report = try loadInventoryFixture(named: "core-audio-inventory-valid")

    try report.validate()

    #expect(report.hostName == "placeholder-host")
    #expect(report.devices.count == 1)
    #expect(report.devices[0].name == "Placeholder Audio Device")
    #expect(report.devices[0].uid == "placeholder-device-uid")
    #expect(report.devices[0].nominalSampleRateHertz == 48000)
    #expect(report.devices[0].inputChannelLayout.streamChannelCounts == [2])
    #expect(report.devices[0].inputChannelLayout.channelLabels == ["input-1", "input-2"])
    #expect(report.devices[0].outputChannelLayout.streamChannelCounts == [2])
    #expect(report.devices[0].outputChannelLayout.channelLabels == ["output-1", "output-2"])
    #expect(report.devices[0].candidateBufferFrames.inReportedRange == [16, 32, 64, 128])
    #expect(report.devices[0].candidateBufferFrames.outsideReportedRange == [8, 256])
}

@Test
func coreAudioInventoryFixtureRequiresDevices() throws {
    let report = try loadInventoryFixture(named: "core-audio-inventory-empty")

    #expect(throws: CoreAudioInventoryValidationError.noDevices) {
        try report.validate()
    }
}

@Test
func bufferFrameCandidateClassificationUsesReportedRangeOnly() {
    let candidates = BufferFrameCandidates(
        candidates: [8, 16, 32, 64, 128, 256],
        reportedRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128)
    )

    #expect(candidates.inReportedRange == [16, 32, 64, 128])
    #expect(candidates.outsideReportedRange == [8, 256])
    #expect(candidates.note == "reported-range-only")
}

@Test
func audioChannelLayoutSnapshotSynthesizesStableLabels() {
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
}

@Test
func coreAudioDeviceInventoryBuildsStableChannelSetsFromLayouts() throws {
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
func coreAudioInventoryRejectsMismatchedChannelLayout() {
    let report = CoreAudioInventoryReport(
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
        try report.validate()
    }
}

@Test
func coreAudioInventoryRejectsUnknownPrefixedDeviceUID() {
    let report = CoreAudioInventoryReport(
        capturedAt: "2026-05-03T00:00:00Z",
        hostName: "test-host",
        devices: [
            makeCoreAudioInventoryDevice(id: 42, name: "Unknown Core Audio device 42", uid: "unknown-42")
        ]
    )

    #expect(throws: CoreAudioInventoryValidationError.missingDeviceIdentity(42)) {
        try report.validate()
    }
}

@Test
func coreAudioInventoryReaderAnnotatesFallbackDeviceIdentity() {
    let identity = coreAudioDeviceIdentity(deviceID: 42, name: nil, uid: nil)

    #expect(identity.name == "Unknown Core Audio device 42")
    #expect(identity.uid == "unknown-42")
    #expect(identity.diagnosticNotes.contains("device name fallback used"))
    #expect(identity.diagnosticNotes.contains("device uid fallback used"))
}

@Test
func coreAudioInventoryReaderCachesFallbackDeviceIdentityStrings() throws {
    let source = try readCoreAudioSource("Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift")

    #expect(source.contains("private let coreAudioFallbackIdentityCache = CoreAudioFallbackIdentityCache()"))
    #expect(source.contains("private final class CoreAudioFallbackIdentityCache"))
    #expect(source.contains("coreAudioFallbackIdentityCache.uid(for: deviceID)"))
    #expect(!source.contains("\"unknown-\\(deviceID)\""))
}

@Test
func coreAudioInventoryJSONRoundTripPreservesDevices() throws {
    let report = try loadInventoryFixture(named: "core-audio-inventory-valid")
    let jsonData = try report.prettyJSONData()
    let decoded = try CoreAudioInventoryReport.decode(from: jsonData)

    #expect(decoded == report)
}

@Test
func coreAudioInventoryReaderConsumesRetainedCoreFoundationStrings() throws {
    let source = try readCoreAudioSource("Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift")

    #expect(source.contains("takeRetainedValue() as String"))
    #expect(!source.contains("takeUnretainedValue() as String"))
}

@Test
func coreAudioInventoryReaderUsesAlignedAudioBufferListAllocation() throws {
    let source = try readCoreAudioSource("Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift")

    #expect(source.contains("AudioBufferList.allocate(maximumBuffers: maximumBuffers)"))
    #expect(source.contains("MemoryLayout<AudioBufferList>.offset(of: \\.mBuffers)"))
    #expect(!source.contains("UnsafeMutableRawPointer.allocate(\n            byteCount: Int(dataSize)"))
}

@Test
func coreAudioInventoryReaderUsesSharedPropertyAddressFactory() throws {
    let source = try readCoreAudioSource("Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift")

    #expect(source.contains("private func coreAudioPropertyAddress("))
    #expect(source.contains("mElement: kAudioObjectPropertyElementMain"))
    #expect(source.contains("var address = coreAudioPropertyAddress(selector, scope)"))
    #expect(source.contains("var address = coreAudioPropertyAddress(kAudioDevicePropertyStreams, scope)"))
    #expect(source.contains("var address = coreAudioPropertyAddress(kAudioDevicePropertyStreamConfiguration, scope)"))
}

@Test
func coreAudioInventoryReaderDocumentsFourCharacterCodeAsciiConstraint() throws {
    let source = try readCoreAudioSource("Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift")

    #expect(source.contains("let printableASCIILowerBound: UInt32 = 32"))
    #expect(source.contains("let printableASCIIUpperBound: UInt32 = 126"))
    #expect(source.contains("Core Audio transport constants are four-character codes"))
    #expect(source.contains("They are not Unicode text"))
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

private func readCoreAudioSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
