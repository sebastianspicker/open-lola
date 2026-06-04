import CryptoKit
import Foundation

enum RecordingSessionRunArgument {
    static let integratedBaseline = "--integrated-baseline"
    static let durationSeconds = "--duration-seconds"
    static let outputDirectory = "--output-dir"
    static let report = "--report"
    static let recordAudio = "--record-audio"
    static let audioInputUID = "--audio-input-uid"
    static let sampleRate = "--sample-rate"
    static let frames = "--frames"
    static let channels = "--channels"
    static let inputChannels = "--input-channels"
    static let sampleFormat = "--sample-format"
    static let recordVideo = "--record-video"
    static let videoDeviceID = "--video-device-id"
    static let streamID = "--stream-id"
    static let frameRate = "--frame-rate"
    static let queueDepth = "--queue-depth"

    static let audioCapture: [String] = [
        audioInputUID,
        sampleRate,
        frames,
        channels,
        inputChannels,
        sampleFormat,
    ]
    static let videoCapture: [String] = [
        videoDeviceID,
        streamID,
        frameRate,
        queueDepth,
    ]
    static let all: Set<String> = Set([
        integratedBaseline,
        durationSeconds,
        outputDirectory,
        report,
        recordAudio,
        recordVideo,
    ] + audioCapture + videoCapture)
}

func requiredRecordingRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw RecordingSessionRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

func requiredRecordingRunPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int {
    let value = try requiredRecordingRunString(argument, values)
    guard let integer = Int(value) else {
        throw RecordingSessionRunConfigurationError.invalidInteger(argument: argument, value: value)
    }
    guard integer > 0 else {
        throw RecordingSessionRunConfigurationError.nonPositiveArgument(argument)
    }
    return integer
}

func optionalRecordingRunPositiveInteger(
    _ argument: String,
    _ values: [String: String],
    defaultValue: Int
) throws -> Int {
    guard values[argument] != nil else {
        return defaultValue
    }
    return try requiredRecordingRunPositiveInteger(argument, values)
}

func optionalRecordingRunPositiveUInt32(
    _ argument: String,
    _ values: [String: String],
    defaultValue: UInt32
) throws -> UInt32 {
    let integer = try optionalRecordingRunPositiveInteger(
        argument,
        values,
        defaultValue: Int(defaultValue)
    )
    return UInt32(integer)
}

func optionalRecordingRunPositiveDouble(
    _ argument: String,
    _ values: [String: String],
    defaultValue: Double
) throws -> Double {
    guard let value = values[argument] else {
        return defaultValue
    }
    guard let double = Double(value) else {
        throw RecordingSessionRunConfigurationError.invalidDouble(argument: argument, value: value)
    }
    guard double > 0 else {
        throw RecordingSessionRunConfigurationError.nonPositiveArgument(argument)
    }
    return double
}

func requiredRecordingRunPositiveDouble(
    _ argument: String,
    _ values: [String: String]
) throws -> Double {
    let value = try requiredRecordingRunString(argument, values)
    guard let double = Double(value) else {
        throw RecordingSessionRunConfigurationError.invalidDouble(argument: argument, value: value)
    }
    guard double > 0 else {
        throw RecordingSessionRunConfigurationError.nonPositiveArgument(argument)
    }
    return double
}

func optionalRecordingRunSwitch(
    _ argument: String,
    _ values: [String: String],
    defaultValue: RecordingMediaSwitch
) throws -> RecordingMediaSwitch {
    guard let value = values[argument] else {
        return defaultValue
    }
    switch value.lowercased() {
    case "on":
        return .on
    case "off":
        return .off
    default:
        throw RecordingSessionRunConfigurationError.invalidSwitch(argument: argument, value: value)
    }
}

func optionalRecordingSampleFormat(
    _ value: String?
) throws -> RecordingAudioSampleFormat {
    guard let value else {
        return .int16LittleEndian
    }
    switch value.lowercased() {
    case "int16-le":
        return .int16LittleEndian
    case "float32-le":
        return .float32LittleEndian
    default:
        throw RecordingSessionRunConfigurationError.invalidSampleFormat(value)
    }
}

func validateRecordingAudioArguments(
    mode: RecordingMediaSwitch,
    values: [String: String]
) throws {
    guard mode == .off else {
        return
    }
    for argument in RecordingSessionRunArgument.audioCapture where values[argument] != nil {
        throw RecordingSessionRunConfigurationError.audioArgumentRequiresAudioMode(argument)
    }
}

func validateRecordingVideoArguments(
    mode: RecordingMediaSwitch,
    values: [String: String]
) throws {
    guard mode == .off else {
        return
    }
    for argument in RecordingSessionRunArgument.videoCapture where values[argument] != nil {
        throw RecordingSessionRunConfigurationError.videoArgumentRequiresVideoMode(argument)
    }
}

func optionalRecordingChannelMap(
    _ value: String?,
    expectedCount: Int
) throws -> [Int] {
    guard let value else {
        return Array(0..<expectedCount)
    }
    let channels = value.split(separator: ",").map(String.init)
    guard !channels.isEmpty else {
        throw RecordingSessionRunConfigurationError.invalidChannelMap(value)
    }
    let parsed = try channels.map { item in
        guard let integer = Int(item), integer >= 0 else {
            throw RecordingSessionRunConfigurationError.invalidChannelMap(value)
        }
        return integer
    }
    guard parsed.count == expectedCount else {
        throw RecordingSessionRunConfigurationError.channelMapCountMismatch(
            expected: expectedCount,
            actual: parsed.count
        )
    }
    return parsed
}

struct RecordingSessionArtifactPayload: Sendable {
    var kind: RecordingArtifactKind
    var relativePath: String
    var data: Data
}

struct RecordingSessionArtifactWriteResult: Sendable {
    var manifest: RecordingArtifactManifest
    var writerPressure: RecordingWriterPressureMetrics
}

func writeRecordingSessionArtifacts(
    outputDirectory: String,
    artifacts: [RecordingSessionArtifactPayload]
) throws -> RecordingSessionArtifactWriteResult {
    let outputURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
    let parentURL = outputURL.deletingLastPathComponent()
    let stagingURL = parentURL.appendingPathComponent(
        ".\(outputURL.lastPathComponent).staging-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)
    var committed = false
    defer {
        if !committed {
            try? FileManager.default.removeItem(at: stagingURL)
        }
    }

    var pressure = RecordingSideLaneWriterPressureCollector(queueCapacityChunks: 2)
    let entries = try artifacts.map { artifact in
        pressure.recordProducedChunk()
        let artifactURL = stagingURL.appendingPathComponent(artifact.relativePath)
        let parent = artifactURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try artifact.data.write(to: artifactURL)
        pressure.recordWrittenChunk()
        return RecordingArtifactEntry(
            kind: artifact.kind,
            relativePath: artifact.relativePath,
            byteCount: artifact.data.count,
            checksum: recordingSessionChecksum(artifact.data)
        )
    }
    if FileManager.default.fileExists(atPath: outputURL.path) {
        try FileManager.default.removeItem(at: outputURL)
    }
    try FileManager.default.moveItem(at: stagingURL, to: outputURL)
    committed = true

    return RecordingSessionArtifactWriteResult(
        manifest: RecordingArtifactManifest(
            rootDirectory: outputDirectory,
            includesConfigurationMetadata: true,
            includesVerdictMetadata: true,
            entries: entries
        ),
        writerPressure: pressure.metrics
    )
}

private struct RecordingSideLaneWriterPressureCollector {
    private let queueCapacityChunks: Int
    private var queuedChunks = 0
    private var producedChunkCount = 0
    private var writtenChunkCount = 0
    private var droppedChunkCount = 0
    private var maxQueuedChunks = 0
    private var writerStallCount = 0

    init(queueCapacityChunks: Int) {
        self.queueCapacityChunks = queueCapacityChunks
    }

    mutating func recordProducedChunk() {
        producedChunkCount += 1
        if queuedChunks < queueCapacityChunks {
            queuedChunks += 1
            maxQueuedChunks = max(maxQueuedChunks, queuedChunks)
        } else {
            droppedChunkCount += 1
        }
    }

    mutating func recordWrittenChunk() {
        guard queuedChunks > 0 else {
            writerStallCount += 1
            return
        }
        queuedChunks -= 1
        writtenChunkCount += 1
    }

    var metrics: RecordingWriterPressureMetrics {
        RecordingWriterPressureMetrics(
            simulatedSlowWriter: false,
            producedChunkCount: producedChunkCount,
            writtenChunkCount: writtenChunkCount,
            droppedChunkCount: droppedChunkCount,
            gapMarkerCount: droppedChunkCount,
            maxQueuedChunks: maxQueuedChunks,
            writerStallCount: writerStallCount
        )
    }
}

func recordingSessionChecksum(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
