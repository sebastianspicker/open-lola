import CoreAudio
import Foundation

// Core Audio HAL property access decision, checked 2026-05-22:
// this package targets macOS 14, while AudioHardwareObject property helpers are
// macOS 15+. Keep the public AudioObjectGetPropertyData* C HAL calls behind
// typed local helpers until the deployment target can move to macOS 15+.
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
        let bufferRange = audioValueRange(
            deviceID,
            kAudioDevicePropertyBufferFrameSizeRange,
            kAudioObjectPropertyScopeGlobal
        )
        let candidates = BufferFrameCandidates(
            candidates: [8, 16, 32, 64, 128, 256],
            reportedRange: bufferRange
        )
        let classID = uint32Property(
            deviceID,
            kAudioObjectPropertyClass,
            kAudioObjectPropertyScopeGlobal
        )
        let inputChannelLayout = channelLayout(
            deviceID,
            kAudioObjectPropertyScopeInput,
            .input
        )
        let outputChannelLayout = channelLayout(
            deviceID,
            kAudioObjectPropertyScopeOutput,
            .output
        )

        let identity = coreAudioDeviceIdentity(
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

        return CoreAudioDeviceInventory(
            id: deviceID,
            name: identity.name,
            uid: identity.uid,
            manufacturer: retainedStringProperty(
                deviceID,
                kAudioObjectPropertyManufacturer,
                kAudioObjectPropertyScopeGlobal
            ),
            transportType: uint32Property(
                deviceID,
                kAudioDevicePropertyTransportType,
                kAudioObjectPropertyScopeGlobal
            ).map(fourCharacterCode),
            isAggregate: classID == kAudioAggregateDeviceClassID,
            inputChannelCount: inputChannelLayout.totalChannelCount,
            outputChannelCount: outputChannelLayout.totalChannelCount,
            inputStreamCount: streamCount(deviceID, kAudioObjectPropertyScopeInput),
            outputStreamCount: streamCount(deviceID, kAudioObjectPropertyScopeOutput),
            inputChannelLayout: inputChannelLayout,
            outputChannelLayout: outputChannelLayout,
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
            bufferFrameSizeRange: bufferRange,
            candidateBufferFrames: candidates,
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
            ),
            diagnosticNotes: [
                "read-only inventory",
                "api latency is diagnostic only",
                "candidate buffer frames use reported range only",
                "channel layout is derived from Core Audio stream configuration"
            ] + identity.diagnosticNotes
        )
    }

    private func retainedStringProperty(
        _ objectID: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope
    ) -> String? {
        guard coreAudioPropertyReturnsRetainedCFObject(selector) else {
            return nil
        }
        var address = coreAudioPropertyAddress(selector, scope)
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(
                objectID,
                &address,
                0,
                nil,
                &dataSize,
                pointer
            )
        }
        guard status == noErr, let value else {
            return nil
        }
        return value.takeRetainedValue() as String
    }

    func coreAudioPropertyReturnsRetainedCFObject(
        _ selector: AudioObjectPropertySelector
    ) -> Bool {
        // AudioHardwareBase.h documents these CFString selectors as caller-owned.
        switch selector {
        case kAudioObjectPropertyName,
             kAudioObjectPropertyManufacturer,
             kAudioDevicePropertyDeviceUID:
            return true
        default:
            return false
        }
    }

    private func uint32Property(
        _ objectID: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope
    ) -> UInt32? {
        var address = coreAudioPropertyAddress(selector, scope)
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

    private func doubleProperty(
        _ objectID: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope
    ) -> Double? {
        var address = coreAudioPropertyAddress(selector, scope)
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

    private func audioValueRange(
        _ objectID: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope
    ) -> AudioValueRangeSnapshot? {
        var address = coreAudioPropertyAddress(selector, scope)
        var value = AudioValueRange(mMinimum: 0, mMaximum: 0)
        var dataSize = UInt32(MemoryLayout<AudioValueRange>.size)
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
        return AudioValueRangeSnapshot(minimum: value.mMinimum, maximum: value.mMaximum)
    }

    private func audioValueRanges(
        _ objectID: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope
    ) -> [AudioValueRangeSnapshot] {
        var address = coreAudioPropertyAddress(selector, scope)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            objectID,
            &address,
            0,
            nil,
            &dataSize
        ) == noErr else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioValueRange>.size
        var values = [AudioValueRange](
            repeating: AudioValueRange(mMinimum: 0, mMaximum: 0),
            count: count
        )
        guard AudioObjectGetPropertyData(
            objectID,
            &address,
            0,
            nil,
            &dataSize,
            &values
        ) == noErr else {
            return []
        }

        return values.map { range in
            AudioValueRangeSnapshot(minimum: range.mMinimum, maximum: range.mMaximum)
        }
    }

    private func streamCount(
        _ objectID: AudioObjectID,
        _ scope: AudioObjectPropertyScope
    ) -> Int {
        var address = coreAudioPropertyAddress(kAudioDevicePropertyStreams, scope)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            objectID,
            &address,
            0,
            nil,
            &dataSize
        ) == noErr else {
            return 0
        }
        return Int(dataSize) / MemoryLayout<AudioObjectID>.size
    }

    private func channelLayout(
        _ objectID: AudioObjectID,
        _ scope: AudioObjectPropertyScope,
        _ layoutScope: AudioChannelLayoutScope
    ) -> AudioChannelLayoutSnapshot {
        var address = coreAudioPropertyAddress(kAudioDevicePropertyStreamConfiguration, scope)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            objectID,
            &address,
            0,
            nil,
            &dataSize
        ) == noErr else {
            return AudioChannelLayoutSnapshot(scope: layoutScope, streamChannelCounts: [])
        }

        let dataSizeInt = Int(dataSize)
        guard let bufferOffset = MemoryLayout<AudioBufferList>.offset(of: \.mBuffers),
              dataSizeInt >= bufferOffset else {
            return AudioChannelLayoutSnapshot(scope: layoutScope, streamChannelCounts: [])
        }
        let maximumBuffers = max(
            1,
            (dataSizeInt - bufferOffset) / MemoryLayout<AudioBuffer>.stride
        )
        let bufferList = AudioBufferList.allocate(maximumBuffers: maximumBuffers)
        defer { bufferList.unsafeMutablePointer.deallocate() }

        guard AudioObjectGetPropertyData(
            objectID,
            &address,
            0,
            nil,
            &dataSize,
            bufferList.unsafeMutablePointer
        ) == noErr else {
            return AudioChannelLayoutSnapshot(scope: layoutScope, streamChannelCounts: [])
        }

        let streamChannelCounts = bufferList.map { buffer in
            Int(buffer.mNumberChannels)
        }
        return AudioChannelLayoutSnapshot(
            scope: layoutScope,
            streamChannelCounts: streamChannelCounts
        )
    }

    private func throwIfNeeded(_ status: OSStatus, _ operation: String) throws {
        if status != noErr {
            throw CoreAudioInventoryError.coreAudioStatus(status, operation)
        }
    }
}

private func coreAudioPropertyAddress(
    _ selector: AudioObjectPropertySelector,
    _ scope: AudioObjectPropertyScope
) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )
}

struct CoreAudioDeviceIdentity: Equatable, Sendable {
    let name: String
    let uid: String
    let diagnosticNotes: [String]
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
