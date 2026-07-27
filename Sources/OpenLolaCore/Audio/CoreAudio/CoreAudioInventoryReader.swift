// Captures the current Core Audio device inventory, formats, ranges, and channel layouts.
import CoreAudio
import Foundation

// Core Audio HAL property access decision, checked 2026-05-22:
// this package targets macOS 14, while AudioHardwareObject property helpers are
// macOS 15+. Keep the public AudioObjectGetPropertyData* C HAL calls behind
// typed local helpers until the deployment target can move to macOS 15+.
/// Reads CoreAudio devices and translates their identifiers, formats, and channel layouts into inventory data.
public struct CoreAudioInventoryReader: Sendable {
    public init() {}

    public func capture() throws -> CoreAudioInventoryReport {
        let devices = try deviceIDs().map(deviceInventory(for:))
        guard !devices.isEmpty else {
            throw CoreAudioInventoryError.noDevices
        }

        return CoreAudioInventoryReport(
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            hostName: Host.current().localizedName ?? "unknown-host",
            devices: devices
        )
    }

    private func deviceIDs() throws -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        )
        try throwIfNeeded(status, "read Core Audio device list size")

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var devices = [AudioObjectID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &devices
        )
        try throwIfNeeded(status, "read Core Audio device list")
        return devices
    }

    private func deviceInventory(for deviceID: AudioObjectID) -> CoreAudioDeviceInventory {
        let bufferRange = bufferFrameSizeRange(for: deviceID)
        let identity = identity(for: deviceID)
        let channels = channelLayouts(for: deviceID)
        let properties = deviceProperties(for: deviceID)

        return deviceInventory(
            id: deviceID,
            identity: identity,
            channels: channels,
            properties: properties,
            bufferRange: bufferRange
        )
    }

    private func deviceInventory(
        id: AudioObjectID,
        identity: CoreAudioDeviceIdentity,
        channels: CoreAudioDeviceChannelLayouts,
        properties: CoreAudioDeviceProperties,
        bufferRange: AudioValueRangeSnapshot?
    ) -> CoreAudioDeviceInventory {
        CoreAudioDeviceInventory(
            identity: CoreAudioDeviceInventory.Identity(
                id: id,
                name: identity.name,
                uid: identity.uid,
                manufacturer: properties.manufacturer,
                transportType: properties.transportType,
                isAggregate: properties.isAggregate
            ),
            streams: CoreAudioDeviceInventory.Streams(
                inputChannelCount: channels.input.totalChannelCount,
                outputChannelCount: channels.output.totalChannelCount,
                inputStreamCount: properties.inputStreamCount,
                outputStreamCount: properties.outputStreamCount,
                inputChannelLayout: channels.input,
                outputChannelLayout: channels.output
            ),
            sampleRates: CoreAudioDeviceInventory.SampleRates(
                nominalSampleRateHertz: properties.nominalSampleRateHertz,
                availableSampleRateRanges: properties.availableSampleRateRanges
            ),
            buffering: CoreAudioDeviceInventory.Buffering(
                currentBufferFrameSize: properties.currentBufferFrameSize,
                bufferFrameSizeRange: bufferRange,
                candidateBufferFrames: bufferFrameCandidates(reportedRange: bufferRange)
            ),
            timing: CoreAudioDeviceInventory.Timing(
                inputLatencyFrames: properties.inputLatencyFrames,
                outputLatencyFrames: properties.outputLatencyFrames,
                inputSafetyOffsetFrames: properties.inputSafetyOffsetFrames,
                outputSafetyOffsetFrames: properties.outputSafetyOffsetFrames,
                clockDomain: properties.clockDomain
            ),
            diagnosticNotes: [
                "read-only inventory",
                "api latency is diagnostic only",
                "candidate buffer frames use reported range only",
                "channel layout is derived from Core Audio stream configuration"
            ] + identity.diagnosticNotes
        )
    }

    private func deviceProperties(for deviceID: AudioObjectID) -> CoreAudioDeviceProperties {
        CoreAudioDeviceProperties(
            manufacturer: manufacturer(for: deviceID),
            transportType: transportType(for: deviceID),
            isAggregate: isAggregateDevice(deviceID),
            inputStreamCount: streamCount(deviceID, kAudioObjectPropertyScopeInput),
            outputStreamCount: streamCount(deviceID, kAudioObjectPropertyScopeOutput),
            nominalSampleRateHertz: doubleProperty(
                deviceID,
                kAudioDevicePropertyNominalSampleRate,
                kAudioObjectPropertyScopeGlobal
            ),
            availableSampleRateRanges: audioValueRanges(
                deviceID,
                kAudioDevicePropertyAvailableNominalSampleRates,
                kAudioObjectPropertyScopeGlobal
            ),
            currentBufferFrameSize: uint32Property(
                deviceID,
                kAudioDevicePropertyBufferFrameSize,
                kAudioObjectPropertyScopeGlobal
            ),
            inputLatencyFrames: uint32Property(
                deviceID,
                kAudioDevicePropertyLatency,
                kAudioObjectPropertyScopeInput
            ),
            outputLatencyFrames: uint32Property(
                deviceID,
                kAudioDevicePropertyLatency,
                kAudioObjectPropertyScopeOutput
            ),
            inputSafetyOffsetFrames: uint32Property(
                deviceID,
                kAudioDevicePropertySafetyOffset,
                kAudioObjectPropertyScopeInput
            ),
            outputSafetyOffsetFrames: uint32Property(
                deviceID,
                kAudioDevicePropertySafetyOffset,
                kAudioObjectPropertyScopeOutput
            ),
            clockDomain: uint32Property(
                deviceID,
                kAudioDevicePropertyClockDomain,
                kAudioObjectPropertyScopeGlobal
            )
        )
    }

    private func identity(for deviceID: AudioObjectID) -> CoreAudioDeviceIdentity {
        coreAudioDeviceIdentity(
            deviceID: deviceID,
            name: retainedStringProperty(
                deviceID,
                kAudioObjectPropertyName,
                kAudioObjectPropertyScopeGlobal
            ),
            uid: retainedStringProperty(
                deviceID,
                kAudioDevicePropertyDeviceUID,
                kAudioObjectPropertyScopeGlobal
            )
        )
    }

    private func manufacturer(for deviceID: AudioObjectID) -> String? {
        retainedStringProperty(
            deviceID,
            kAudioObjectPropertyManufacturer,
            kAudioObjectPropertyScopeGlobal
        )
    }

    private func transportType(for deviceID: AudioObjectID) -> String? {
        uint32Property(
            deviceID,
            kAudioDevicePropertyTransportType,
            kAudioObjectPropertyScopeGlobal
        ).map(fourCharacterCode)
    }

    private func isAggregateDevice(_ deviceID: AudioObjectID) -> Bool {
        uint32Property(
            deviceID,
            kAudioObjectPropertyClass,
            kAudioObjectPropertyScopeGlobal
        ) == kAudioAggregateDeviceClassID
    }

    private func channelLayouts(for deviceID: AudioObjectID) -> CoreAudioDeviceChannelLayouts {
        CoreAudioDeviceChannelLayouts(
            input: channelLayout(deviceID, kAudioObjectPropertyScopeInput, .input),
            output: channelLayout(deviceID, kAudioObjectPropertyScopeOutput, .output)
        )
    }

    private func bufferFrameSizeRange(for deviceID: AudioObjectID) -> AudioValueRangeSnapshot? {
        audioValueRange(
            deviceID,
            kAudioDevicePropertyBufferFrameSizeRange,
            kAudioObjectPropertyScopeGlobal
        )
    }

    private func bufferFrameCandidates(
        reportedRange: AudioValueRangeSnapshot?
    ) -> BufferFrameCandidates {
        BufferFrameCandidates(
            candidates: [8, 16, 32, 64, 128, 256],
            reportedRange: reportedRange
    )
}

}

struct CoreAudioDeviceIdentity: Equatable, Sendable {
    let name: String
    let uid: String
    let diagnosticNotes: [String]
}

private struct CoreAudioDeviceChannelLayouts {
    let input: AudioChannelLayoutSnapshot
    let output: AudioChannelLayoutSnapshot
}

private struct CoreAudioDeviceProperties {
    let manufacturer: String?
    let transportType: String?
    let isAggregate: Bool
    let inputStreamCount: Int
    let outputStreamCount: Int
    let nominalSampleRateHertz: Double?
    let availableSampleRateRanges: [AudioValueRangeSnapshot]
    let currentBufferFrameSize: UInt32?
    let inputLatencyFrames: UInt32?
    let outputLatencyFrames: UInt32?
    let inputSafetyOffsetFrames: UInt32?
    let outputSafetyOffsetFrames: UInt32?
    let clockDomain: UInt32?
}

func coreAudioDeviceIdentity(
    deviceID: AudioObjectID,
    name: String?,
    uid: String?
) -> CoreAudioDeviceIdentity {
    var diagnosticNotes: [String] = []
    let resolvedName: String
    if let name {
        resolvedName = name
    } else {
        resolvedName = "Unknown Core Audio device " + String(deviceID)
        diagnosticNotes.append("device name fallback used")
    }

    let resolvedUID: String
    if let uid {
        resolvedUID = uid
    } else {
        resolvedUID = "unknown-" + String(deviceID)
        diagnosticNotes.append("device uid fallback used")
    }

    return CoreAudioDeviceIdentity(
        name: resolvedName,
        uid: resolvedUID,
        diagnosticNotes: diagnosticNotes
    )
}

private func fourCharacterCode(_ code: UInt32) -> String {
    let printableASCIILowerBound: UInt32 = 32
    let printableASCIIUpperBound: UInt32 = 126
    let scalars = [
        UnicodeScalar((code >> 24) & 0xFF),
        UnicodeScalar((code >> 16) & 0xFF),
        UnicodeScalar((code >> 8) & 0xFF),
        UnicodeScalar(code & 0xFF)
    ]

    // Core Audio transport constants are four-character codes stored as four printable ASCII
    // bytes. They are not Unicode text; non-printable bytes fall back to the numeric value.
    let characters = scalars.compactMap { scalar -> Character? in
        guard let scalar,
              scalar.isASCII,
              scalar.value >= printableASCIILowerBound,
              scalar.value <= printableASCIIUpperBound else {
            return nil
        }
        return Character(scalar)
    }

    guard characters.count == 4 else {
        return String(code)
    }

    return String(characters)
}
