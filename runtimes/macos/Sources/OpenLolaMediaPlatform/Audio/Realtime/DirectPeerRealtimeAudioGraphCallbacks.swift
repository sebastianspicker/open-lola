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
    let product = hostTime.multipliedFullWidth(by: numerator)
    if product.high == 0 { return product.low / denominator }
    // The quotient can fit even when the intermediate multiplication does not,
    // as on Apple Silicon's fractional mach timebase after a long uptime.
    guard product.high < denominator else { return nil }
    return denominator.dividingFullWidth(product).quotient
}

private struct ActiveDirectPeerRealtimeAudioCallback {
    let state: DirectPeerRealtimeAudioCallbackState
    let hostTimeNanoseconds: UInt64
}

@inline(__always)
private func startDirectPeerRealtimeAudioCallback(
    clientData: UnsafeMutableRawPointer?,
    hostTime: UInt64
) -> ActiveDirectPeerRealtimeAudioCallback? {
    guard let clientData else {
        return nil
    }
    let state = Unmanaged<DirectPeerRealtimeAudioCallbackState>
        .fromOpaque(clientData)
        .takeUnretainedValue()
    guard state.beginIOProcCallback() else {
        return nil
    }
    guard let hostTimeNanoseconds = state.nanoseconds(fromHostTime: hostTime) else {
        // Host-time overflow is not recoverable for this block, but returning
        // noErr keeps Core Audio running instead of stopping the device.
        state.recordHostTimeConversionFailure()
        state.endIOProcCallback()
        return nil
    }
    return ActiveDirectPeerRealtimeAudioCallback(
        state: state,
        hostTimeNanoseconds: hostTimeNanoseconds
    )
}

/// Capture is stamped with the time the input was sampled, not the IOProc's "now".
@inline(__always)
private func directPeerCaptureHostTime(
    inNow: UnsafePointer<AudioTimeStamp>,
    inInputTime: UnsafePointer<AudioTimeStamp>
) -> UInt64 {
    let inputTime = inInputTime.pointee
    return inputTime.mFlags.contains(.hostTimeValid) ? inputTime.mHostTime : inNow.pointee.mHostTime
}

private func silenceDirectPeerOutput(_ output: UnsafeMutablePointer<AudioBufferList>) {
    for buffer in UnsafeMutableAudioBufferListPointer(output) {
        if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
    }
}

let directPeerRealtimeAudioIOProc: AudioDeviceIOProc = { _, inNow, inInputData, inInputTime, outOutputData, _, inClientData in
    guard let callback = startDirectPeerRealtimeAudioCallback(
        clientData: inClientData,
        hostTime: directPeerCaptureHostTime(inNow: inNow, inInputTime: inInputTime)
    ) else {
        silenceDirectPeerOutput(outOutputData)
        return inClientData == nil ? kAudioHardwareIllegalOperationError : noErr
    }
    defer { callback.state.endIOProcCallback() }
    callback.state.processIO(
        hostTimeNanoseconds: callback.hostTimeNanoseconds,
        input: inInputData,
        output: outOutputData
    )
    return noErr
}

let directPeerRealtimeAudioInputIOProc: AudioDeviceIOProc = { _, inNow, inInputData, inInputTime, _, _, inClientData in
    guard let callback = startDirectPeerRealtimeAudioCallback(
        clientData: inClientData,
        hostTime: directPeerCaptureHostTime(inNow: inNow, inInputTime: inInputTime)
    ) else {
        return inClientData == nil ? kAudioHardwareIllegalOperationError : noErr
    }
    defer { callback.state.endIOProcCallback() }
    callback.state.processInputIO(
        hostTimeNanoseconds: callback.hostTimeNanoseconds,
        input: inInputData
    )
    return noErr
}

let directPeerRealtimeAudioOutputIOProc: AudioDeviceIOProc = { _, _, _, _, outOutputData, _, inClientData in
    guard let inClientData else {
        silenceDirectPeerOutput(outOutputData)
        return kAudioHardwareIllegalOperationError
    }
    let state = Unmanaged<DirectPeerRealtimeAudioCallbackState>
        .fromOpaque(inClientData)
        .takeUnretainedValue()
    guard state.beginIOProcCallback() else {
        silenceDirectPeerOutput(outOutputData)
        return noErr
    }
    defer { state.endIOProcCallback() }
    state.processOutputIO(output: outOutputData)
    return noErr
}
