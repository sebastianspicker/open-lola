// Verifies that Core Audio inventory validation rejects empty, mismatched, and unknown devices.
import CoreAudio
import Foundation
import Testing

@testable import OpenLolaCore

@Test
// swiftlint:disable function_body_length
func coreAudioInventoryValidationRejectsEmptyMismatchedAndUnknownDevices() throws {
    let emptyReport = try loadInventoryFixture(named: "core-audio-inventory-empty")

    #expect(throws: CoreAudioInventoryValidationError.noDevices) {
        try emptyReport.validate()
    }

    let mismatchReport = CoreAudioInventoryReport(
        capturedAt: "2026-05-03T00:00:00Z",
        hostName: "test-host",
        devices: [
            makeCoreAudioInventoryDevice(
                id: 1,
                name: "Mismatch Device",
                uid: "mismatch-device",
                inputStreamChannelCounts: [1]
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
// swiftlint:enable function_body_length

@Test
func coreAudioInventoryModelsClassifyBuffersAndStableChannels() throws {
    coreAudioInventoryBufferCandidatesClassifyReportedRange()
    coreAudioInventoryChannelLayoutBuildsStableLabels()
    try coreAudioInventoryDeviceBuildsStableChannelSets()
}

private func coreAudioInventoryBufferCandidatesClassifyReportedRange() {
    let candidates = BufferFrameCandidates(
        candidates: [8, 16, 32, 64, 128, 256],
        reportedRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128)
    )

    #expect(candidates.inReportedRange == [16, 32, 64, 128])
    #expect(candidates.outsideReportedRange == [8, 256])
    #expect(candidates.note == "reported-range-only")
}

private func coreAudioInventoryChannelLayoutBuildsStableLabels() {
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
        "input-8"
    ])
}

private func coreAudioInventoryDeviceBuildsStableChannelSets() throws {
    let device = coreAudioInventoryStableChannelDevice()

    #expect(device.channelSet(scope: .input).sortedByStableSourceIndex.map(\.label) == [
        "madi-1",
        "madi-2",
        "madi-3",
        "madi-4"
    ])
    let selected = try device.selectedChannelSet(scope: .input, stableSourceIndices: [3, 1])
    #expect(selected.sortedByStableSourceIndex.map(\.stableSourceIndex) == [1, 3])
    #expect(device.channelSet(scope: .output).sortedByStableSourceIndex.map(\.label) == [
        "phones-l",
        "phones-r"
    ])
}

private func coreAudioInventoryStableChannelDevice() -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
            identity: .init(id: 10, name: "RME MADI", uid: "rme-madi", manufacturer: "RME", transportType: "thun", isAggregate: false),
            streams: .init(inputChannelCount: 4, outputChannelCount: 2, inputStreamCount: 1, outputStreamCount: 1, inputChannelLayout: AudioChannelLayoutSnapshot(
            scope: .input,
            streamChannelCounts: [4],
            channelLabels: ["madi-1", "madi-2", "madi-3", "madi-4"]
        ), outputChannelLayout: AudioChannelLayoutSnapshot(
            scope: .output,
            streamChannelCounts: [2],
            channelLabels: ["phones-l", "phones-r"]
        )),
            sampleRates: .init(nominalSampleRateHertz: 48_000, availableSampleRateRanges: [
            AudioValueRangeSnapshot(minimum: 48_000, maximum: 96_000)
        ]),
            buffering: .init(currentBufferFrameSize: 32, bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128), candidateBufferFrames: BufferFrameCandidates(
            inReportedRange: [16, 32, 64, 128],
            outsideReportedRange: [],
            note: "test"
        )),
            timing: .init(inputLatencyFrames: 12, outputLatencyFrames: 12, inputSafetyOffsetFrames: 0, outputSafetyOffsetFrames: 0, clockDomain: 1),
            diagnosticNotes: ["test"]
        )
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

@Test
func coreAudioInventoryReaderRestrictsRetainedStringPropertiesToDocumentedSelectors() {
    let reader = CoreAudioInventoryReader()

    #expect(reader.coreAudioPropertyReturnsRetainedCFObject(kAudioObjectPropertyName))
    #expect(reader.coreAudioPropertyReturnsRetainedCFObject(kAudioObjectPropertyManufacturer))
    #expect(reader.coreAudioPropertyReturnsRetainedCFObject(kAudioDevicePropertyDeviceUID))
    #expect(!reader.coreAudioPropertyReturnsRetainedCFObject(kAudioDevicePropertyTransportType))
}

@Test
func coreAudioHALPropertyAccessDecisionDocumentsMacOS14CompatibilityBoundary() throws {
    let packageSource = try repositoryFile("Package.swift")
    let madiDoc = try repositoryFile("docs/audio-rme-madi.md")
    let inventorySource = try repositoryFile(
        "Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift"
    )
    let loopbackSource = try repositoryFile(
        "Sources/OpenLolaCore/Audio/Routing/AudioLoopbackHelpers.swift"
    )

    #expect(packageSource.contains(".macOS(.v14)"))
    #expect(madiDoc.contains("Core Audio HAL Property API Compatibility"))
    #expect(madiDoc.contains("AudioHardwareObject.propertyData(address:qualifier:)"))
    #expect(madiDoc.contains("macOS 15+"))
    #expect(inventorySource.contains("Core Audio HAL property access decision"))
    #expect(loopbackSource.contains("Core Audio HAL property access decision"))
}

private func makeCoreAudioInventoryDevice(
    id: UInt32,
    name: String = "RME MADI",
    uid: String = "rme-madi",
    inputStreamChannelCounts: [Int] = [2]
) -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
            identity: .init(id: id, name: name, uid: uid, manufacturer: "RME", transportType: "thun", isAggregate: false),
            streams: .init(inputChannelCount: 2, outputChannelCount: 2, inputStreamCount: 1, outputStreamCount: 1, inputChannelLayout: AudioChannelLayoutSnapshot(
            scope: .input,
            streamChannelCounts: inputStreamChannelCounts
        ), outputChannelLayout: AudioChannelLayoutSnapshot(
            scope: .output,
            streamChannelCounts: [2]
        )),
            sampleRates: .init(nominalSampleRateHertz: 48_000, availableSampleRateRanges: [
            AudioValueRangeSnapshot(minimum: 48_000, maximum: 48_000)
        ]),
            buffering: .init(currentBufferFrameSize: 64, bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128), candidateBufferFrames: BufferFrameCandidates(
            inReportedRange: [16, 32, 64, 128],
            outsideReportedRange: [],
            note: "test"
        )),
            timing: .init(inputLatencyFrames: 0, outputLatencyFrames: 0, inputSafetyOffsetFrames: 0, outputSafetyOffsetFrames: 0, clockDomain: 1),
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

private func repositoryFile(_ relativePath: String) throws -> String {
    try String(contentsOf: repositoryRoot.appendingPathComponent(relativePath), encoding: .utf8)
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
