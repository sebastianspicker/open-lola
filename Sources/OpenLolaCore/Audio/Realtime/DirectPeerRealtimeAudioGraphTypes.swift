// Defines graph preflight, configuration, cleanup failures, captured payloads, and counters shared by lifecycle and callback extensions.
import CoreAudio
import Foundation

/// Reports device and format failures that prevent a direct-peer graph from meeting its callback contract.
public enum DirectPeerAudioGraphError: Error, Equatable, Sendable {
    case missingDeviceUID(String)
    case separateDevicesUnsupported(input: String, output: String)
    case deviceNotFullDuplex(String)
    case unsupportedSampleRate(uid: String, sampleRateHertz: Int)
    case unsupportedFrameSize(uid: String, framesPerBuffer: Int)
    case channelMapOutOfRange(scope: AudioChannelLayoutScope, index: Int, available: Int)
    case coreAudioStatus(OSStatus, String)
    case graphNotStarted
    case graphAlreadyStarted
}

// swiftlint:disable:next type_name
/// Records `operation` and `status` when a cleanup step cannot complete safely.
public struct DirectPeerRealtimeAudioGraphCleanupFailure: Equatable, Sendable {
    public var operation: String
    public var status: OSStatus?

    public init(operation: String, status: OSStatus?) {
        self.operation = operation
        self.status = status
    }
}

// swiftlint:disable:next type_name
/// Combines `failures` and `succeeded` into the outcome returned by a bounded the real-time audio path operation.
public struct DirectPeerRealtimeAudioGraphCleanupResult: Equatable, Sendable {
    public var failures: [DirectPeerRealtimeAudioGraphCleanupFailure]

    public init(failures: [DirectPeerRealtimeAudioGraphCleanupFailure] = []) {
        self.failures = failures
    }

    public var succeeded: Bool { failures.isEmpty }
}

func directPeerRealtimeAudioCleanupFailureSummary(
    _ result: DirectPeerRealtimeAudioGraphCleanupResult
) -> String {
    result.failures.map { failure in
        let status = failure.status.map(String.init) ?? "unknown"
        return "\(failure.operation) status \(status)"
    }.joined(separator: "; ")
}

/// Records `device`, `outputDevice`, `sampleRateSupported`, and `frameSizeSupported` before the real-time audio path claims it can start safely.
public struct DirectPeerRealtimeAudioGraphPreflight: Codable, Equatable, Sendable {
    public var device: CoreAudioDeviceInventory?
    public var outputDevice: CoreAudioDeviceInventory?
    public var sampleRateSupported: Bool
    public var frameSizeSupported: Bool
    public var fullDuplexSupported: Bool
    public var blockers: [String]

    public var canStart: Bool { blockers.isEmpty }

    public static func evaluate(
        configuration: DirectPeerRealtimeAudioGraphConfiguration,
        inventory: CoreAudioInventoryReport
    ) -> DirectPeerRealtimeAudioGraphPreflight {
        let context = DirectPeerRealtimeAudioGraphPreflightContext(
            configuration: configuration,
            inventory: inventory
        )

        return DirectPeerRealtimeAudioGraphPreflight(
            device: context.device,
            outputDevice: context.outputDevice,
            sampleRateSupported: context.sampleRateSupported,
            frameSizeSupported: context.frameSizeSupported,
            fullDuplexSupported: context.fullDuplexSupported,
            blockers: context.blockers
        )
    }
}

// swiftlint:disable:next type_name
private struct DirectPeerRealtimeAudioGraphPreflightContext {
    let configuration: DirectPeerRealtimeAudioGraphConfiguration
    let device: CoreAudioDeviceInventory?
    let outputDevice: CoreAudioDeviceInventory?
    let sampleRateSupported: Bool
    let frameSizeSupported: Bool
    let fullDuplexSupported: Bool

    init(
        configuration: DirectPeerRealtimeAudioGraphConfiguration,
        inventory: CoreAudioInventoryReport
    ) {
        self.configuration = configuration
        self.device = inventory.devices.first { $0.uid == configuration.inputDeviceUID }
        self.outputDevice = inventory.devices.first { $0.uid == configuration.outputDeviceUID }
        self.sampleRateSupported = directPeerRealtimeAudioGraphSampleRateSupported(
            device: device,
            outputDevice: outputDevice,
            sampleRateHertz: configuration.sampleRateHertz
        )
        self.frameSizeSupported = directPeerRealtimeAudioGraphFrameSizeSupported(
            device: device,
            outputDevice: outputDevice,
            framesPerBuffer: configuration.framesPerBuffer
        )
        self.fullDuplexSupported = directPeerRealtimeAudioGraphFullDuplexSupported(
            configuration: configuration,
            device: device,
            outputDevice: outputDevice
        )
    }

    var blockers: [String] {
        var result: [String] = []
        appendDeviceBlockers(to: &result)
        appendFormatBlockers(to: &result)
        appendChannelMapShapeBlockers(to: &result)
        appendChannelMapBoundsBlockers(to: &result)
        return result
    }

    private func appendDeviceBlockers(to blockers: inout [String]) {
        if device == nil {
            blockers.append("input audio device UID not found")
        }
        if outputDevice == nil {
            blockers.append("output audio device UID not found")
        }
        if !fullDuplexSupported {
            blockers.append(configuration.inputDeviceUID == configuration.outputDeviceUID
                ? "audio device is not full duplex"
                : "input/output audio devices do not expose required directions")
        }
    }

    private func appendFormatBlockers(to blockers: inout [String]) {
        if device != nil, !sampleRateSupported {
            blockers.append("requested sample rate is outside reported device range")
        }
        if device != nil, !frameSizeSupported {
            blockers.append("requested frame size is outside reported device range")
        }
    }

    private func appendChannelMapShapeBlockers(to blockers: inout [String]) {
        if configuration.inputChannelMap.count != configuration.channelCount {
            blockers.append("requested input channel map must match channel count")
        }
        if configuration.outputChannelMap.count != configuration.channelCount {
            blockers.append("requested output channel map must match channel count")
        }
        if configuration.inputChannelMap.contains(where: { $0 < 0 }) {
            blockers.append("requested input channel map contains a negative channel index")
        }
        if configuration.outputChannelMap.contains(where: { $0 < 0 }) {
            blockers.append("requested output channel map contains a negative channel index")
        }
    }

    private func appendChannelMapBoundsBlockers(to blockers: inout [String]) {
        appendChannelMapBoundsBlocker(
            configuration.inputChannelMap,
            availableChannels: device?.inputChannelCount,
            message: "requested input channel map exceeds input device channels",
            to: &blockers
        )
        appendChannelMapBoundsBlocker(
            configuration.outputChannelMap,
            availableChannels: outputDevice?.outputChannelCount,
            message: "requested output channel map exceeds output device channels",
            to: &blockers
        )
    }
}

private func directPeerRealtimeAudioGraphSampleRateSupported(
    device: CoreAudioDeviceInventory?,
    outputDevice: CoreAudioDeviceInventory?,
    sampleRateHertz: Int
) -> Bool {
    [device, outputDevice].allSatisfy {
        $0.map { supportsSampleRate($0, sampleRateHertz) } == true
    }
}

private func directPeerRealtimeAudioGraphFrameSizeSupported(
    device: CoreAudioDeviceInventory?,
    outputDevice: CoreAudioDeviceInventory?,
    framesPerBuffer: Int
) -> Bool {
    [device, outputDevice].allSatisfy {
        $0.map { supportsFrameSize($0, framesPerBuffer) } == true
    }
}

private func directPeerRealtimeAudioGraphFullDuplexSupported(
    configuration: DirectPeerRealtimeAudioGraphConfiguration,
    device: CoreAudioDeviceInventory?,
    outputDevice: CoreAudioDeviceInventory?
) -> Bool {
    if configuration.inputDeviceUID == configuration.outputDeviceUID {
        return (device?.inputChannelCount ?? 0) > 0 && (device?.outputChannelCount ?? 0) > 0
    }
    return (device?.inputChannelCount ?? 0) > 0 && (outputDevice?.outputChannelCount ?? 0) > 0
}

private func appendChannelMapBoundsBlocker(
    _ channelMap: [Int],
    availableChannels: Int?,
    message: String,
    to blockers: inout [String]
) {
    guard let availableChannels else {
        return
    }
    if channelMap.contains(where: { $0 >= availableChannels }) {
        blockers.append(message)
    }
}

// swiftlint:disable:next type_name
/// Binds `inputDeviceUID`, `outputDeviceUID`, `sampleRateHertz`, and `framesPerBuffer` before the callback-driven audio path starts, preventing implicit runtime defaults.
public struct DirectPeerRealtimeAudioGraphConfiguration: Codable, Equatable, Sendable {
    public struct Devices: Equatable, Sendable {
        public var audioDeviceUID: String
        public var inputDeviceUID: String?
        public var outputDeviceUID: String?

        public init(
            audioDeviceUID: String,
            inputDeviceUID: String? = nil,
            outputDeviceUID: String? = nil
        ) {
            self.audioDeviceUID = audioDeviceUID
            self.inputDeviceUID = inputDeviceUID
            self.outputDeviceUID = outputDeviceUID
        }
    }

    public struct Format: Equatable, Sendable {
        public var sampleRateHertz: Int
        public var framesPerBuffer: Int
        public var channelCount: Int
        public var sampleFormat: UdpPcmSampleFormat

        public init(
            sampleRateHertz: Int,
            framesPerBuffer: Int,
            channelCount: Int,
            sampleFormat: UdpPcmSampleFormat
        ) {
            self.sampleRateHertz = sampleRateHertz
            self.framesPerBuffer = framesPerBuffer
            self.channelCount = channelCount
            self.sampleFormat = sampleFormat
        }
    }

    public typealias ChannelMaps = RealtimeAudioChannelMaps

    public struct Buffering: Equatable, Sendable {
        public var ringCapacityBlocks: Int
        public var rxBufferPolicy: RxBufferPolicy?

        public init(ringCapacityBlocks: Int = 8, rxBufferPolicy: RxBufferPolicy? = nil) {
            self.ringCapacityBlocks = ringCapacityBlocks
            self.rxBufferPolicy = rxBufferPolicy
        }
    }

    public var inputDeviceUID: String
    public var outputDeviceUID: String
    public var sampleRateHertz: Int
    public var framesPerBuffer: Int
    public var channelCount: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var inputChannelMap: [Int]
    public var outputChannelMap: [Int]
    public var ringCapacityBlocks: Int
    public var rxBufferPolicy: RxBufferPolicy?

    /// Legacy single-device UID retained as a compatibility accessor only.
    /// New configs should set `inputDeviceUID` and `outputDeviceUID` explicitly.
 @available(*, deprecated, message: "Use input/output device UIDs; audioDeviceUID is compatibility-only.")
    public var audioDeviceUID: String { inputDeviceUID }

    public init(devices: Devices, format: Format, channelMaps: ChannelMaps, buffering: Buffering = .init()) {
        self.inputDeviceUID = devices.inputDeviceUID ?? devices.audioDeviceUID
        self.outputDeviceUID = devices.outputDeviceUID ?? devices.audioDeviceUID
        self.sampleRateHertz = format.sampleRateHertz
        self.framesPerBuffer = format.framesPerBuffer
        self.channelCount = format.channelCount
        self.sampleFormat = format.sampleFormat
        self.inputChannelMap = channelMaps.input
        self.outputChannelMap = channelMaps.output
        self.ringCapacityBlocks = buffering.ringCapacityBlocks
        self.rxBufferPolicy = buffering.rxBufferPolicy
    }

    public var payloadByteCount: Int { framesPerBuffer * channelCount * sampleFormat.bytesPerSample }

    public var playoutTargetFrames: Int { rxBufferPolicy?.targetFrames ?? 0 }

    public func validateRealtimeBufferInputs() throws {
        let format = RealtimeAudioBufferValidationInput.Format(
            sampleRateHertz: sampleRateHertz,
            framesPerBuffer: framesPerBuffer,
            channelCount: channelCount,
            bytesPerSample: sampleFormat.bytesPerSample
        )
        let channelMaps = RealtimeAudioBufferValidationInput.ChannelMaps(
            input: inputChannelMap,
            output: outputChannelMap
        )
        let buffering = RealtimeAudioBufferValidationInput.Buffering(
            capacityRequirement: .ringCapacityBlocks(ringCapacityBlocks),
            playoutTargetFrames: nil,
            rxBufferPolicy: rxBufferPolicy
        )
        try validateRealtimeAudioBufferInput(
            RealtimeAudioBufferValidationInput(
                format: format,
                channelMaps: channelMaps,
                buffering: buffering
            )
        )
    }

    enum CodingKeys: String, CodingKey {
        case inputDeviceUID
        case outputDeviceUID
        case sampleRateHertz
        case framesPerBuffer
        case channelCount
        case sampleFormat
        case inputChannelMap
        case outputChannelMap
        case ringCapacityBlocks
        case rxBufferPolicy
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.inputDeviceUID = try container.decode(String.self, forKey: .inputDeviceUID)
        self.outputDeviceUID = try container.decode(String.self, forKey: .outputDeviceUID)
        self.sampleRateHertz = try container.decode(Int.self, forKey: .sampleRateHertz)
        self.framesPerBuffer = try container.decode(Int.self, forKey: .framesPerBuffer)
        self.channelCount = try container.decode(Int.self, forKey: .channelCount)
        self.sampleFormat = try container.decode(UdpPcmSampleFormat.self, forKey: .sampleFormat)
        self.inputChannelMap = try container.decode([Int].self, forKey: .inputChannelMap)
        self.outputChannelMap = try container.decode([Int].self, forKey: .outputChannelMap)
        self.ringCapacityBlocks = try container.decodeIfPresent(Int.self, forKey: .ringCapacityBlocks) ?? 8
        self.rxBufferPolicy = try container.decodeIfPresent(RxBufferPolicy.self, forKey: .rxBufferPolicy)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(inputDeviceUID, forKey: .inputDeviceUID)
        try container.encode(outputDeviceUID, forKey: .outputDeviceUID)
        try container.encode(sampleRateHertz, forKey: .sampleRateHertz)
        try container.encode(framesPerBuffer, forKey: .framesPerBuffer)
        try container.encode(channelCount, forKey: .channelCount)
        try container.encode(sampleFormat, forKey: .sampleFormat)
        try container.encode(inputChannelMap, forKey: .inputChannelMap)
        try container.encode(outputChannelMap, forKey: .outputChannelMap)
        try container.encode(ringCapacityBlocks, forKey: .ringCapacityBlocks)
        try container.encodeIfPresent(rxBufferPolicy, forKey: .rxBufferPolicy)
    }
}

/// Pairs `block` and `payload` so captured audio bytes retain their block timing.
public struct DirectPeerCapturedAudioPayload: Equatable, Sendable {
    public var block: RealtimeAudioFrameBlock
    public var payload: Data
}

// swiftlint:disable:next type_name
/// Counts `capturedInputBlocks`, `droppedInputBlocks`, `inputOverrunBlocks`, and `outputBlocks` to expose real-time graph activity and loss.
public struct DirectPeerRealtimeAudioGraphRuntimeCounters: Codable, Equatable, Sendable {
    public var capturedInputBlocks: Int = 0
    public var droppedInputBlocks: Int = 0
    public var inputOverrunBlocks: Int = 0
    public var outputBlocks: Int = 0
    public var droppedOutputBlocks: Int = 0
    public var outputUnderrunBlocks: Int = 0
    public var callbackInvocationBlocks: Int = 0
    public var callbackMaxMicroseconds: Int = 0
    public var callbackDeadlineMisses: Int = 0
    public var callbackOverrunBlocks: Int = 0
    public var hostTimeConversionFailures: Int = 0
}
