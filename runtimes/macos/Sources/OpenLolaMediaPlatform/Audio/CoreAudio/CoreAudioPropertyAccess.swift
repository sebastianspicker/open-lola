// Provides typed Core Audio HAL writes for reusable realtime media adapters.
import CoreAudio

enum CoreAudioPropertyAccessError: Error, Equatable, Sendable {
    case coreAudioStatus(OSStatus, String)
}

func doubleProperty(
    _ objectID: AudioObjectID,
    _ selector: AudioObjectPropertySelector,
    _ scope: AudioObjectPropertyScope
) -> Double? {
    var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    var value: Double = 0
    var dataSize = UInt32(MemoryLayout<Double>.size)
    guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value) == noErr else { return nil }
    return value
}

func uint32Property(
    _ objectID: AudioObjectID,
    _ selector: AudioObjectPropertySelector,
    _ scope: AudioObjectPropertyScope
) -> UInt32? {
    var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    var value: UInt32 = 0
    var dataSize = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value) == noErr else { return nil }
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
        objectID, &address, 0, nil, UInt32(MemoryLayout<Double>.size), &mutableValue
    )
    if status != noErr {
        throw CoreAudioPropertyAccessError.coreAudioStatus(status, "set Core Audio double property")
    }
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
        objectID, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &mutableValue
    )
    if status != noErr {
        throw CoreAudioPropertyAccessError.coreAudioStatus(status, "set Core Audio UInt32 property")
    }
}
