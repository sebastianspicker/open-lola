import CoreAudio
import Darwin
import Foundation

struct AudioLoopbackIOProcResult {
    let callback: EndpointCallbackMetrics
    let handoff: RealtimeAudioHandoffMetrics
    let cleanup: AudioLoopbackRunCleanupResult
}

func makeRunReport(
    configuration: AudioLoopbackRunConfiguration,
    inventory: CoreAudioInventoryReport,
    preflight: AudioLoopbackPreflight,
    state: AudioLoopbackRunState,
    callback: EndpointCallbackMetrics?,
    handoff: RealtimeAudioHandoffMetrics? = nil,
    cleanup: AudioLoopbackRunCleanupResult? = nil,
    notes: String
) -> AudioLoopbackRunReport {
    AudioLoopbackRunReport(
        id: "audio-loopback-run-\(UUID().uuidString)",
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        hostName: inventory.hostName,
        runnerKind: .audioDeviceIOProc,
        state: state,
        configuration: configuration,
        preflight: preflight,
        callback: callback,
        handoff: handoff,
        cleanup: cleanup,
        verdict: .partial,
        notes: notes
    )
}

func audioLoopbackCompletionNotes(
    base: String,
    cleanup: AudioLoopbackRunCleanupResult
) -> String {
    guard !cleanup.failures.isEmpty else { return base }
    let failures = cleanup.failures
        .map { failure -> String in
            if let status = failure.status {
                return "\(failure.operation) status \(status)"
            }
            return "\(failure.operation) status unknown"
        }
        .joined(separator: "; ")
    return "\(base) Cleanup failures: \(failures)."
}

func audioLoopbackStatus(from error: Error) -> OSStatus? {
    if let error = error as? AudioLoopbackRunError,
       case .coreAudioStatus(let status, _) = error {
        return status
    }
    return nil
}

func requiredString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    try KeyValueArgumentParser.requiredString(
        argument,
        values,
        missing: AudioLoopbackRunConfigurationError.missingRequiredArgument
    )
}

func requiredPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int {
    try KeyValueArgumentParser.requiredPositiveInteger(
        argument,
        values,
        missing: AudioLoopbackRunConfigurationError.missingRequiredArgument,
        invalid: { AudioLoopbackRunConfigurationError.invalidInteger(argument: $0, value: $1) },
        nonPositive: AudioLoopbackRunConfigurationError.nonPositiveArgument
    )
}

func optionalPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int? {
    try KeyValueArgumentParser.optionalPositiveInteger(
        argument,
        values,
        invalid: { AudioLoopbackRunConfigurationError.invalidInteger(argument: $0, value: $1) },
        nonPositive: AudioLoopbackRunConfigurationError.nonPositiveArgument
    )
}

func optionalNonNegativeInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int? {
    try KeyValueArgumentParser.optionalNonNegativeInteger(
        argument,
        values,
        invalid: { AudioLoopbackRunConfigurationError.invalidInteger(argument: $0, value: $1) },
        negative: AudioLoopbackRunConfigurationError.negativeArgument
    )
}

func parseBool(_ value: String, argument: String) throws -> Bool {
    try KeyValueArgumentParser.boolean(
        value,
        argument: argument,
        trueValues: ["true", "yes", "1", "on"],
        falseValues: ["false", "no", "0", "off"],
        invalid: { AudioLoopbackRunConfigurationError.invalidBool(argument: $0, value: $1) }
    )
}

func parseAudioLoopbackSampleFormat(_ value: String?) throws -> UdpPcmSampleFormat {
    guard let value else {
        return .int16LittleEndian
    }
    switch value.lowercased() {
    case "int16", "int16-le", "int16littleendian":
        return .int16LittleEndian
    case "float32", "float32-le", "float32littleendian":
        return .float32LittleEndian
    default:
        throw AudioLoopbackRunConfigurationError.invalidSampleFormat(value)
    }
}

func parseAudioLoopbackChannelMap(
    _ value: String?,
    argument: String,
    expectedCount: Int
) throws -> [Int]? {
    guard let value else {
        return nil
    }
    let components = value.split(separator: ",", omittingEmptySubsequences: false)
    let channelMap = try components.map { component -> Int in
        guard let index = Int(String(component).trimmingCharacters(in: .whitespaces)) else {
            throw AudioLoopbackRunConfigurationError.invalidChannelMap(
                argument: argument,
                value: value
            )
        }
        guard index >= 0 else {
            throw AudioLoopbackRunConfigurationError.invalidChannelMap(
                argument: argument,
                value: value
            )
        }
        return index
    }
    guard channelMap.count == expectedCount else {
        throw AudioLoopbackRunConfigurationError.channelMapCountMismatch(
            argument: argument,
            expected: expectedCount,
            actual: channelMap.count
        )
    }
    return channelMap
}

func parseLatencyProfile(_ value: String?, framesPerBuffer: Int) throws -> LatencyProfile {
    if let value {
        guard let profile = LatencyProfile(rawValue: value) else {
            throw AudioLoopbackRunConfigurationError.invalidLatencyProfile(value)
        }
        return profile
    }
    return LatencyProfilePolicy.profile(forFramesPerBuffer: framesPerBuffer) ?? .safeLowLatency
}

func parseRxBufferProfile(_ value: String?) throws -> RxBufferProfile? {
    guard let value else {
        return nil
    }
    guard let profile = RxBufferProfile(rawValue: value) else {
        throw AudioLoopbackRunConfigurationError.invalidRxBufferProfile(value)
    }
    return profile
}

func supportsSampleRate(_ device: CoreAudioDeviceInventory, _ sampleRateHertz: Int) -> Bool {
    guard !device.availableSampleRateRanges.isEmpty else {
        return false
    }
    return device.availableSampleRateRanges.contains { range in
        Double(sampleRateHertz) >= range.minimum && Double(sampleRateHertz) <= range.maximum
    }
}

func supportsFrameSize(_ device: CoreAudioDeviceInventory, _ framesPerBuffer: Int) -> Bool {
    guard let range = device.bufferFrameSizeRange else {
        return false
    }
    return Double(framesPerBuffer) >= range.minimum
        && Double(framesPerBuffer) <= range.maximum
}

func channelMapFits(_ channelMap: [Int], available: Int) -> Bool {
    !channelMap.isEmpty && channelMap.allSatisfy { channel in
        channel >= 0 && channel < available
    }
}

func isAudioLoopbackRmeMadiDevice(_ device: CoreAudioDeviceInventory) -> Bool {
    let searchable = [
        device.name,
        device.uid,
        device.manufacturer ?? ""
    ].joined(separator: " ").lowercased()
    return searchable.contains("rme") && searchable.contains("madi")
}

func percentile(_ sortedValues: [Double], _ percentile: Double) -> Double {
    guard !sortedValues.isEmpty else {
        return 0
    }
    let clamped = min(max(percentile, 0), 1)
    let index = Int((Double(sortedValues.count - 1) * clamped).rounded())
    return sortedValues[index]
}

func doubleProperty(
    _ objectID: AudioObjectID,
    _ selector: AudioObjectPropertySelector,
    _ scope: AudioObjectPropertyScope
) -> Double? {
    var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )
    var value: Double = 0
    var dataSize = UInt32(MemoryLayout<Double>.size)
    guard AudioObjectGetPropertyData(
        objectID,
        &address,
        0,
        nil,
        &dataSize,
        &value
    ) == noErr else {
        return nil
    }
    return value
}

func uint32Property(
    _ objectID: AudioObjectID,
    _ selector: AudioObjectPropertySelector,
    _ scope: AudioObjectPropertyScope
) -> UInt32? {
    var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )
    var value: UInt32 = 0
    var dataSize = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(
        objectID,
        &address,
        0,
        nil,
        &dataSize,
        &value
    ) == noErr else {
        return nil
    }
    return value
}

func setDoubleProperty(
    _ objectID: AudioObjectID,
    _ selector: AudioObjectPropertySelector,
    _ scope: AudioObjectPropertyScope,
    _ value: Double
) throws {
    var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )
    var mutableValue = value
    let status = AudioObjectSetPropertyData(
        objectID,
        &address,
        0,
        nil,
        UInt32(MemoryLayout<Double>.size),
        &mutableValue
    )
    try throwLoopbackIfNeeded(status, "set Core Audio double property")
}

func setUInt32Property(
    _ objectID: AudioObjectID,
    _ selector: AudioObjectPropertySelector,
    _ scope: AudioObjectPropertyScope,
    _ value: UInt32
) throws {
    var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )
    var mutableValue = value
    let status = AudioObjectSetPropertyData(
        objectID,
        &address,
        0,
        nil,
        UInt32(MemoryLayout<UInt32>.size),
        &mutableValue
    )
    try throwLoopbackIfNeeded(status, "set Core Audio UInt32 property")
}

func throwLoopbackIfNeeded(_ status: OSStatus, _ operation: String) throws {
    if status != noErr {
        throw AudioLoopbackRunError.coreAudioStatus(status, operation)
    }
}
