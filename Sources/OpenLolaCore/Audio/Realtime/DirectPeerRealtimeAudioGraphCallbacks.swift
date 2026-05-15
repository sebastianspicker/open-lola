import CoreAudio
import Foundation

func validateChannelMap(
    _ channelMap: [Int],
    scope: AudioChannelLayoutScope,
    available: Int,
    expectedCount: Int
) throws {
    guard channelMap.count == expectedCount else {
        throw DirectPeerAudioGraphError.channelMapOutOfRange(
            scope: scope,
            index: channelMap.count,
            available: available
        )
    }
    for index in channelMap where index < 0 || index >= available {
        throw DirectPeerAudioGraphError.channelMapOutOfRange(
            scope: scope,
            index: index,
            available: available
        )
    }
}

struct ReadOnlyAudioBufferListPointer {
    private let pointer: UnsafePointer<AudioBufferList>

    init(_ pointer: UnsafePointer<AudioBufferList>) {
        self.pointer = pointer
    }

    var count: Int {
        Int(pointer.pointee.mNumberBuffers)
    }

    var isEmpty: Bool {
        count == 0
    }

    subscript(index: Int) -> AudioBuffer? {
        guard index >= 0 && index < count else {
            return nil
        }
        guard let buffersOffset = MemoryLayout<AudioBufferList>.offset(of: \.mBuffers) else {
            return nil
        }
        return UnsafeRawPointer(pointer)
            .advanced(by: buffersOffset + index * MemoryLayout<AudioBuffer>.stride)
            .assumingMemoryBound(to: AudioBuffer.self)
            .pointee
    }
}

func audioByteOffset(
    frame: Int,
    channel: Int,
    channelCount: Int,
    bytesPerSample: Int
) -> Int? {
    let (frameBase, frameOverflow) = frame.multipliedReportingOverflow(by: channelCount)
    guard !frameOverflow else { return nil }
    let (sampleIndex, sampleOverflow) = frameBase.addingReportingOverflow(channel)
    guard !sampleOverflow else { return nil }
    let (byteOffset, byteOverflow) = sampleIndex.multipliedReportingOverflow(by: bytesPerSample)
    guard !byteOverflow else { return nil }
    return byteOffset
}

func throwDirectPeerAudioStatusIfNeeded(_ status: OSStatus, _ operation: String) throws {
    guard status == noErr else {
        throw DirectPeerAudioGraphError.coreAudioStatus(status, operation)
    }
}

func directPeerRealtimeAudioIOProc(
    _: AudioObjectID,
    _ inNow: UnsafePointer<AudioTimeStamp>,
    _ inInputData: UnsafePointer<AudioBufferList>,
    _: UnsafePointer<AudioTimeStamp>,
    _ outOutputData: UnsafeMutablePointer<AudioBufferList>,
    _: UnsafePointer<AudioTimeStamp>,
    _ inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let inClientData else {
        return kAudioHardwareIllegalOperationError
    }
    let graph = Unmanaged<DirectPeerRealtimeAudioGraph>
        .fromOpaque(inClientData)
        .takeUnretainedValue()
    guard let hostTimeNanoseconds = graph.nanoseconds(fromHostTime: inNow.pointee.mHostTime) else {
        return kAudioHardwareIllegalOperationError
    }
    graph.processIO(
        hostTimeNanoseconds: hostTimeNanoseconds,
        input: inInputData,
        output: outOutputData
    )
    return noErr
}

func directPeerRealtimeAudioInputIOProc(
    _: AudioObjectID,
    _ inNow: UnsafePointer<AudioTimeStamp>,
    _ inInputData: UnsafePointer<AudioBufferList>,
    _: UnsafePointer<AudioTimeStamp>,
    _: UnsafeMutablePointer<AudioBufferList>,
    _: UnsafePointer<AudioTimeStamp>,
    _ inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let inClientData else {
        return kAudioHardwareIllegalOperationError
    }
    let graph = Unmanaged<DirectPeerRealtimeAudioGraph>
        .fromOpaque(inClientData)
        .takeUnretainedValue()
    guard let hostTimeNanoseconds = graph.nanoseconds(fromHostTime: inNow.pointee.mHostTime) else {
        return kAudioHardwareIllegalOperationError
    }
    graph.processInputIO(
        hostTimeNanoseconds: hostTimeNanoseconds,
        input: inInputData
    )
    return noErr
}

func directPeerRealtimeAudioOutputIOProc(
    _: AudioObjectID,
    _: UnsafePointer<AudioTimeStamp>,
    _: UnsafePointer<AudioBufferList>,
    _: UnsafePointer<AudioTimeStamp>,
    _ outOutputData: UnsafeMutablePointer<AudioBufferList>,
    _: UnsafePointer<AudioTimeStamp>,
    _ inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let inClientData else {
        return kAudioHardwareIllegalOperationError
    }
    let graph = Unmanaged<DirectPeerRealtimeAudioGraph>
        .fromOpaque(inClientData)
        .takeUnretainedValue()
    graph.processOutputIO(output: outOutputData)
    return noErr
}
