// Reads typed Core Audio properties with fixed scopes and expected value sizes.
import CoreAudio
import Foundation

extension CoreAudioInventoryReader {
    func retainedStringProperty(
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

    func audioValueRange(
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

    func audioValueRanges(
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

    func streamCount(
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

    func channelLayout(
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

    func throwIfNeeded(_ status: OSStatus, _ operation: String) throws {
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
