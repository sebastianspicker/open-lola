// Validates the buffer constraints shared by the engine and direct-peer graph configurations.
import Foundation

enum RealtimeAudioBufferCapacityRequirement: Sendable {
    case preallocatedBlockCount(Int)
    case ringCapacityBlocks(Int)

    func validate() throws {
        switch self {
        case let .preallocatedBlockCount(value):
            try validatePositive(value, "preallocatedBlockCount")
        case let .ringCapacityBlocks(value):
            try validatePositive(value, "ringCapacityBlocks")
        }
    }
}

/// Identifies which callback surface owns the real-time audio processing cycle.
public enum RealtimeAudioCallbackOwner: String, Codable, Equatable, Sendable {
    case audioDeviceIOProc
    case auhalRenderCallback
    case synthetic
}

struct RealtimeAudioBufferValidationInput: Sendable {
    struct Format: Sendable {
        let sampleRateHertz: Int
        let framesPerBuffer: Int
        let channelCount: Int
        let bytesPerSample: Int
    }

    struct ChannelMaps: Sendable {
        let input: [Int]
        let output: [Int]
    }

    struct Buffering: Sendable {
        let capacityRequirement: RealtimeAudioBufferCapacityRequirement
        let playoutTargetFrames: Int?
        let rxBufferPolicy: RxBufferPolicy?
    }

    let format: Format
    let channelMaps: ChannelMaps
    let buffering: Buffering
}

func validateRealtimeAudioBufferInput(_ input: RealtimeAudioBufferValidationInput) throws {
    try validatePositive(input.format.sampleRateHertz, "sampleRateHertz")
    try validatePositive(input.format.framesPerBuffer, "framesPerBuffer")
    try validatePositive(input.format.channelCount, "channelCount")
    if let playoutTargetFrames = input.buffering.playoutTargetFrames {
        try validateNonNegative(playoutTargetFrames, "playoutTargetFrames")
    }
    try input.buffering.capacityRequirement.validate()
    try validateChannelMap(
        input.channelMaps.input,
        channelCount: input.format.channelCount,
        field: "inputChannelMap"
    )
    try validateChannelMap(
        input.channelMaps.output,
        channelCount: input.format.channelCount,
        field: "outputChannelMap"
    )
    _ = try validatedRealtimeAudioPayloadByteCount(
        frameCount: input.format.framesPerBuffer,
        channelCount: input.format.channelCount,
        bytesPerSample: input.format.bytesPerSample
    )
    if let rxBufferPolicy = input.buffering.rxBufferPolicy {
        try rxBufferPolicy.validate()
        guard rxBufferPolicy.framesPerPacket == input.format.framesPerBuffer else {
            throw RealtimeAudioBufferConfigurationError.mismatchedField(
                field: "rxBufferPolicy.framesPerPacket",
                expected: input.format.framesPerBuffer,
                actual: rxBufferPolicy.framesPerPacket
            )
        }
        guard rxBufferPolicy.sampleRateHertz == input.format.sampleRateHertz else {
            throw RealtimeAudioBufferConfigurationError.mismatchedField(
                field: "rxBufferPolicy.sampleRateHertz",
                expected: input.format.sampleRateHertz,
                actual: rxBufferPolicy.sampleRateHertz
            )
        }
    }
}

func normalizedRealtimeAudioChannelMap(_ channelMap: [Int]?, channelCount: Int) -> [Int] {
    let resolved: [Int]
    if let channelMap, !channelMap.isEmpty {
        resolved = channelMap
    } else {
        resolved = Array(0..<channelCount)
    }
    precondition(resolved.count == channelCount, "channel map must match channel count")
    precondition(resolved.allSatisfy { $0 >= 0 }, "channel map indices must be non-negative")
    return resolved
}

/// Reports invalid buffer sizes and channel maps before callback-owned audio resources are configured.
public enum RealtimeAudioBufferConfigurationError: Error, Equatable, Sendable {
    case nonPositiveField(String)
    case negativeField(String)
    case invalidChannelMap(field: String, expected: Int, actual: Int)
    case negativeChannelMapIndex(String)
    case payloadByteCountOverflow
    case mismatchedField(field: String, expected: Int, actual: Int)
}

func validatePositive(_ value: Int, _ field: String) throws {
    guard value > 0 else {
        throw RealtimeAudioBufferConfigurationError.nonPositiveField(field)
    }
}

func validateNonNegative(_ value: Int, _ field: String) throws {
    guard value >= 0 else {
        throw RealtimeAudioBufferConfigurationError.negativeField(field)
    }
}

func validateChannelMap(_ channelMap: [Int], channelCount: Int, field: String) throws {
    guard !channelMap.isEmpty else { return }
    guard channelMap.count == channelCount else {
        throw RealtimeAudioBufferConfigurationError.invalidChannelMap(
            field: field,
            expected: channelCount,
            actual: channelMap.count
        )
    }
    guard channelMap.allSatisfy({ $0 >= 0 }) else {
        throw RealtimeAudioBufferConfigurationError.negativeChannelMapIndex(field)
    }
}

extension UdpPcmSampleFormat {
    var audioModeSampleFormat: String {
        switch self {
        case .int16LittleEndian:
            "int16-le"
        case .float32LittleEndian:
            "float32-le"
        }
    }
}

/// Self-attestation checklist. Fields are set by the developer writing the report,
/// not by runtime instrumentation. This is a documentation aid, not a measured check.
/// A violation is only detectable if the developer explicitly sets a field to false.
public struct RealtimeAudioCallbackSafetyChecklist: Codable, Equatable, Sendable {
    public var noAllocationInCallback: Bool
    public var noLoggingInCallback: Bool
    public var noFileIOInCallback: Bool
    public var noLocksOrUnboundedWaitsInCallback: Bool
    public var noNetworkSetupInCallback: Bool
    public var noReportWritingInCallback: Bool
    public var countersOnlyInCallback: Bool

    public init(
        noAllocationInCallback: Bool,
        noLoggingInCallback: Bool,
        noFileIOInCallback: Bool,
        noLocksOrUnboundedWaitsInCallback: Bool,
        noNetworkSetupInCallback: Bool,
        noReportWritingInCallback: Bool,
        countersOnlyInCallback: Bool
    ) {
        self.noAllocationInCallback = noAllocationInCallback
        self.noLoggingInCallback = noLoggingInCallback
        self.noFileIOInCallback = noFileIOInCallback
        self.noLocksOrUnboundedWaitsInCallback = noLocksOrUnboundedWaitsInCallback
        self.noNetworkSetupInCallback = noNetworkSetupInCallback
        self.noReportWritingInCallback = noReportWritingInCallback
        self.countersOnlyInCallback = countersOnlyInCallback
    }

    public var firstViolation: String? {
        if !noAllocationInCallback { return "noAllocationInCallback" }
        if !noLoggingInCallback { return "noLoggingInCallback" }
        if !noFileIOInCallback { return "noFileIOInCallback" }
        if !noLocksOrUnboundedWaitsInCallback { return "noLocksOrUnboundedWaitsInCallback" }
        if !noNetworkSetupInCallback { return "noNetworkSetupInCallback" }
        if !noReportWritingInCallback { return "noReportWritingInCallback" }
        if !countersOnlyInCallback { return "countersOnlyInCallback" }
        return nil
    }
}
