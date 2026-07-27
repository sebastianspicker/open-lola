// Opens BPF interfaces to transmit and receive LoLa Ethernet frames with bounded timing.
import Darwin
import Foundation

/// Defines the validated fields for LoLa BPF raw link transmitter.
public struct LoLaBpfRawLinkTransmitter: LoLaRawLinkTransmitter {
    public var interfaceName: String
    public var sequenceIntervalNanoseconds: UInt64?

    public init(interfaceName: String, sequenceIntervalNanoseconds: UInt64? = nil) {
        self.interfaceName = interfaceName
        self.sequenceIntervalNanoseconds = sequenceIntervalNanoseconds
    }

    public func transmit(_ frames: [LoLaCompatibilityMediaFrame]) throws -> [Int] {
        try transmitGenerated { emit in
            for frame in frames {
                try emit(frame)
            }
        }
    }

    public func transmitGenerated(
        _ generate: (_ emit: (LoLaCompatibilityMediaFrame) throws -> Void) throws -> Void
    ) throws -> [Int] {
        let outcome = try transmitGeneratedOutcome(generate)
        return outcome.writtenByteCountEvidence
    }

    public func transmitGeneratedOutcome(
        _ generate: (_ emit: (LoLaCompatibilityMediaFrame) throws -> Void) throws -> Void
    ) throws -> LoLaRawLinkTransmitOutcome {
        let descriptor = try openBpfDescriptor()
        defer { close(descriptor) }
        try configureBpfDescriptor(descriptor, interfaceName: interfaceName)
        try configureNonBlockingRawLinkDescriptor(descriptor)
        let state = LoLaBpfRawLinkTransmitState(
            descriptor: descriptor,
            interfaceName: interfaceName,
            sequenceIntervalNanoseconds: sequenceIntervalNanoseconds
        )
        try generate { frame in
            try state.emit(frame)
        }
        return state.outcome
    }
}

private final class LoLaBpfRawLinkTransmitState {
    private let descriptor: Int32
    private let interfaceName: String
    private let sequenceIntervalNanoseconds: UInt64?
    private var writtenFrameCount = 0
    private var writtenBytesTotal = 0
    private var droppedFrames = 0
    private var writtenByteCounts: [Int] = []
    private var lastSequence: Int?
    private var nextSequenceDeadline = DispatchTime.now()

    init(descriptor: Int32, interfaceName: String, sequenceIntervalNanoseconds: UInt64?) {
        self.descriptor = descriptor
        self.interfaceName = interfaceName
        self.sequenceIntervalNanoseconds = sequenceIntervalNanoseconds
    }

    var outcome: LoLaRawLinkTransmitOutcome {
        LoLaRawLinkTransmitOutcome(
            writtenFrameCount: writtenFrameCount,
            writtenBytesTotal: writtenBytesTotal,
            backpressureDroppedFrames: droppedFrames,
            writtenByteCountEvidence: writtenByteCounts
        )
    }

    func emit(_ frame: LoLaCompatibilityMediaFrame) throws {
        paceIfNeeded(frame)
        let written = try writeFrame(frame)
        guard written > 0 else {
            droppedFrames += 1
            return
        }
        writtenFrameCount += 1
        writtenBytesTotal += written
        if writtenByteCounts.count < loLaRawLinkMaximumRetainedEvidenceFrames {
            writtenByteCounts.append(written)
        }
    }

    private func paceIfNeeded(_ frame: LoLaCompatibilityMediaFrame) {
        defer { lastSequence = frame.sequenceNumber }
        guard let interval = sequenceIntervalNanoseconds,
              lastSequence != nil,
              lastSequence != frame.sequenceNumber else {
            return
        }
        nextSequenceDeadline = loLaRawLinkNextDeadline(
            previous: nextSequenceDeadline,
            intervalNanoseconds: interval,
            now: DispatchTime.now()
        )
        loLaUdpMediaSleepUntil(nextSequenceDeadline)
    }

    private func writeFrame(_ frame: LoLaCompatibilityMediaFrame) throws -> Int {
        try frame.encodedFrame.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                throw ExternalConnectorSessionError.socketFailed("empty raw-link frame")
            }
            let written = write(descriptor, baseAddress, rawBuffer.count)
            if written < 0, errno == EAGAIN || errno == EWOULDBLOCK {
                return 0
            }
            guard written == rawBuffer.count else {
                throw ExternalConnectorSessionError.socketFailed("bpf write \(interfaceName)")
            }
            return written
        }
    }
}

private func loLaRawLinkNextDeadline(
    previous: DispatchTime,
    intervalNanoseconds: UInt64,
    now: DispatchTime
) -> DispatchTime {
    let interval = max(1, intervalNanoseconds)
    let scheduled = previous.uptimeNanoseconds.addingReportingOverflow(interval)
    let scheduledValue = scheduled.overflow ? UInt64.max : scheduled.partialValue
    if scheduledValue > now.uptimeNanoseconds {
        return DispatchTime(uptimeNanoseconds: scheduledValue)
    }
    let reanchored = now.uptimeNanoseconds.addingReportingOverflow(interval)
    return DispatchTime(uptimeNanoseconds: reanchored.overflow ? UInt64.max : reanchored.partialValue)
}

/// Defines the validated fields for LoLa BPF raw link receiver.
public struct LoLaBpfRawLinkReceiver: LoLaRawLinkReceiver {
    public var interfaceName: String
    public var timeoutSeconds: Int

    public init(interfaceName: String, timeoutSeconds: Int = 1) {
        self.interfaceName = interfaceName
        self.timeoutSeconds = timeoutSeconds
    }

    public func receive(maxFrames: Int) throws -> [Data] {
        let descriptor = try openBpfDescriptor()
        defer { close(descriptor) }
        try configureBpfDescriptor(descriptor, interfaceName: interfaceName)
        try configureNonBlockingRawLinkDescriptor(descriptor)
        var received: [Data] = []
        var buffer = [UInt8](repeating: 0, count: try bpfBufferLength(descriptor))
        let deadline = MonotonicDeadline(seconds: TimeInterval(max(1, timeoutSeconds)))
        while received.count < maxFrames, deadline.hasTimeRemaining {
            let byteCount = read(descriptor, &buffer, buffer.count)
            if byteCount < 0 {
                if errno == EWOULDBLOCK || errno == EAGAIN {
                    _ = try waitForReadableSocket(
                        socket: descriptor,
                        timeoutMicroseconds: 50_000
                    )
                    continue
                }
                throw ExternalConnectorSessionError.socketFailed("bpf read errno \(errno)")
            }
            guard byteCount > 0 else {
                _ = try waitForReadableSocket(
                    socket: descriptor,
                    timeoutMicroseconds: 50_000
                )
                continue
            }
            received.append(contentsOf: try extractBpfPackets(Array(buffer.prefix(byteCount))))
        }
        guard received.count >= maxFrames else {
            throw ExternalConnectorSessionError.receiveTimedOut
        }
        return Array(received.prefix(maxFrames))
    }
}

private let bpfIoctlSetInterface: UInt = 0x8020_426c
private let bpfIoctlGetBufferLength: UInt = 0x4004_4266
private let bpfIoctlSetHeaderComplete: UInt = 0x8004_4275
private let bpfIoctlImmediate: UInt = 0x8004_4270
private let bpfHeaderMinimumByteCount = 26
private let bpfHeaderCapturedLengthOffset = 16
private let bpfHeaderLengthOffset = 24

private func openBpfDescriptor() throws -> Int32 {
    for index in 0..<256 {
        let descriptor = open("/dev/bpf\(index)", O_RDWR)
        if descriptor >= 0 {
            return descriptor
        }
        if errno != EBUSY {
            break
        }
    }
    throw ExternalConnectorSessionError.socketFailed("open /dev/bpf*")
}

private func bpfBufferLength(_ descriptor: Int32) throws -> Int {
    var bufferLength: UInt32 = 0
    guard ioctl(descriptor, bpfIoctlGetBufferLength, &bufferLength) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("BIOCGBLEN errno \(errno)")
    }
    guard bufferLength > 0 else {
        throw ExternalConnectorSessionError.socketFailed("BIOCGBLEN returned empty buffer")
    }
    return Int(bufferLength)
}

private func configureBpfDescriptor(_ descriptor: Int32, interfaceName: String) throws {
    var request = ifreq()
    try copyInterfaceName(interfaceName, into: &request)
    guard ioctl(descriptor, bpfIoctlSetInterface, &request) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("BIOCSETIF \(interfaceName) errno \(errno)")
    }
    var enabled: UInt32 = 1
    guard ioctl(descriptor, bpfIoctlSetHeaderComplete, &enabled) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("BIOCSHDRCMPLT errno \(errno)")
    }
    guard ioctl(descriptor, bpfIoctlImmediate, &enabled) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("BIOCIMMEDIATE errno \(errno)")
    }
}

private func configureNonBlockingRawLinkDescriptor(_ descriptor: Int32) throws {
    let flags = fcntl(descriptor, F_GETFL, 0)
    guard flags >= 0 else {
        throw ExternalConnectorSessionError.socketFailed("bpf fcntl get errno \(errno)")
    }
    guard fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("bpf fcntl nonblock errno \(errno)")
    }
}

func extractBpfPackets(_ bytes: [UInt8]) throws -> [Data] {
    var packets: [Data] = []
    var offset = 0
    // Uses the classic net/bpf.h bpf_hdr layout; bpf_xhdr is not supported here.
    while offset + bpfHeaderMinimumByteCount <= bytes.count {
        let capturedLength = Int(readLoLaRawLinkUInt32Native(
            bytes,
            offset: offset + bpfHeaderCapturedLengthOffset
        ))
        let headerLength = Int(readLoLaRawLinkUInt16Native(
            bytes,
            offset: offset + bpfHeaderLengthOffset
        ))
        let recordStride = bpfWordAlign(max(1, headerLength + capturedLength))
        guard headerLength > 0, capturedLength >= LoLaCompatibilityMediaModel.wirePayloadOffset else {
            offset += recordStride
            continue
        }
        let packetOffset = offset + headerLength
        guard packetOffset + capturedLength <= bytes.count else {
            offset += recordStride
            continue
        }
        packets.append(Data(bytes[packetOffset..<packetOffset + capturedLength]))
        offset += recordStride
    }
    return packets
}

private func bpfWordAlign(_ value: Int) -> Int {
    let alignment = MemoryLayout<Int32>.size
    return (value + alignment - 1) & ~(alignment - 1)
}

private func readLoLaRawLinkUInt16Native(_ bytes: [UInt8], offset: Int) -> UInt16 {
    readPrevalidatedUInt16LE(bytes, offset: offset)
}

private func readLoLaRawLinkUInt32Native(_ bytes: [UInt8], offset: Int) -> UInt32 {
    readPrevalidatedUInt32LE(bytes, offset: offset)
}

private func copyInterfaceName(_ value: String, into request: inout ifreq) throws {
    let bytes = Array(value.utf8)
    guard bytes.count < Int(IFNAMSIZ) else {
        throw ExternalConnectorSessionError.socketFailed("interface name too long \(value)")
    }
    withUnsafeMutableBytes(of: &request.ifr_name) { name in
        for index in name.indices {
            name[index] = 0
        }
        for index in bytes.indices {
            name[index] = bytes[index]
        }
    }
}

func parseLoLaRawLinkArguments(_ arguments: [String]) throws -> [String: String] {
    let allowed = Set([
        "--interface", "--source-ip", "--local-ip", "--peer", "--source-mac", "--destination-mac",
        "--output", "--dry-run", "--packets", "--media", "--channels", "--sample-rate", "--frames",
        "--video-width", "--video-height", "--video-bpp",
        "--timeout-seconds"
    ])
    return try parseExternalConnectorKeyValueArguments(arguments, allowed: allowed)
}
