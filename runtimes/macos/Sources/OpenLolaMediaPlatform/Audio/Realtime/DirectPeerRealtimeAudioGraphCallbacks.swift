// Defines Core Audio IOProc callbacks and host-time conversion helpers so the device callback surface remains allocation-free and auditable.
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

func nanosecondsFromHostTime(_ hostTime: UInt64, numerator: UInt64, denominator: UInt64) -> UInt64? {
    precondition(denominator > 0, "mach timebase denominator must be positive")
    let (scaled, overflow) = hostTime.multipliedReportingOverflow(by: numerator)
    return overflow ? nil : scaled / denominator
}

private struct ActiveDirectPeerRealtimeAudioGraphCallback {
    let graph: DirectPeerRealtimeAudioGraph
    let hostTimeNanoseconds: UInt64
}

@inline(__always)
private func startDirectPeerRealtimeAudioGraphCallback(
    clientData: UnsafeMutableRawPointer?,
    hostTime: UInt64
) -> ActiveDirectPeerRealtimeAudioGraphCallback? {
    guard let clientData else {
        return nil
    }
    let graph = Unmanaged<DirectPeerRealtimeAudioGraph>
        .fromOpaque(clientData)
        .takeUnretainedValue()
    guard graph.beginIOProcCallback() else {
        return nil
    }
    guard let hostTimeNanoseconds = graph.nanoseconds(fromHostTime: hostTime) else {
        // Host-time overflow is not recoverable for this block, but returning
        // noErr keeps Core Audio running instead of stopping the device.
        graph.recordHostTimeConversionFailure()
        graph.endIOProcCallback()
        return nil
    }
    return ActiveDirectPeerRealtimeAudioGraphCallback(
        graph: graph,
        hostTimeNanoseconds: hostTimeNanoseconds
    )
}

let directPeerRealtimeAudioIOProc: AudioDeviceIOProc = { _, inNow, inInputData, _, outOutputData, _, inClientData in
    guard let callback = startDirectPeerRealtimeAudioGraphCallback(
        clientData: inClientData,
        hostTime: inNow.pointee.mHostTime
    ) else {
        return inClientData == nil ? kAudioHardwareIllegalOperationError : noErr
    }
    defer { callback.graph.endIOProcCallback() }
    callback.graph.processIO(
        hostTimeNanoseconds: callback.hostTimeNanoseconds,
        input: inInputData,
        output: outOutputData
    )
    return noErr
}

let directPeerRealtimeAudioInputIOProc: AudioDeviceIOProc = { _, inNow, inInputData, _, _, _, inClientData in
    guard let callback = startDirectPeerRealtimeAudioGraphCallback(
        clientData: inClientData,
        hostTime: inNow.pointee.mHostTime
    ) else {
        return inClientData == nil ? kAudioHardwareIllegalOperationError : noErr
    }
    defer { callback.graph.endIOProcCallback() }
    callback.graph.processInputIO(
        hostTimeNanoseconds: callback.hostTimeNanoseconds,
        input: inInputData
    )
    return noErr
}

let directPeerRealtimeAudioOutputIOProc: AudioDeviceIOProc = { _, _, _, _, outOutputData, _, inClientData in
    guard let inClientData else {
        return kAudioHardwareIllegalOperationError
    }
    let graph = Unmanaged<DirectPeerRealtimeAudioGraph>
        .fromOpaque(inClientData)
        .takeUnretainedValue()
    guard graph.beginIOProcCallback() else {
        return noErr
    }
    defer { graph.endIOProcCallback() }
    graph.processOutputIO(output: outOutputData)
    return noErr
}
