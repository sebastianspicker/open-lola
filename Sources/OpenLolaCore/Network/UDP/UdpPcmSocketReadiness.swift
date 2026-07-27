// Waits for UDP socket readability and writability with select or kqueue fallback.
import Darwin
import Foundation

@discardableResult
func waitForReadableSocket(socket: Int32, timeoutMicroseconds: UInt64) throws -> Bool {
    try waitForReadableSockets(
        sockets: [socket],
        timeoutMicroseconds: timeoutMicroseconds
    ).contains(socket)
}

func waitForReadableSockets(
    sockets: [Int32],
    timeoutMicroseconds: UInt64
) throws -> Set<Int32> {
    guard timeoutMicroseconds > 0, !sockets.isEmpty else {
        return []
    }
    if sockets.contains(where: { !openLolaFileDescriptorFitsFDSet($0) }) {
        return try waitForKqueueSockets(
            sockets: sockets,
            filter: Int16(EVFILT_READ),
            timeoutMicroseconds: timeoutMicroseconds
        )
    }
    var readSet = fd_set()
    openLolaFDZero(&readSet)
    for socket in sockets {
        try openLolaFDSet(socket, set: &readSet)
    }
    var timeout = readableSocketTimeout(timeoutMicroseconds: timeoutMicroseconds)
    let result = select((sockets.max() ?? 0) + 1, &readSet, nil, nil, &timeout)
    if result < 0 {
        let savedErrno = errno
        if savedErrno == EINTR {
            return []
        }
        throw UdpPcmRouteProbeError.receiveFailed(savedErrno)
    }
    guard result > 0 else {
        return []
    }
    var readable = Set<Int32>()
    for socket in sockets where try openLolaFDIsSet(socket, set: &readSet) {
        readable.insert(socket)
    }
    return readable
}

@discardableResult
func waitForWritableSocket(socket: Int32, timeoutMicroseconds: UInt64) throws -> Bool {
    guard timeoutMicroseconds > 0 else {
        return false
    }
    guard openLolaFileDescriptorFitsFDSet(socket) else {
        return try waitForKqueueSockets(
            sockets: [socket],
            filter: Int16(EVFILT_WRITE),
            timeoutMicroseconds: timeoutMicroseconds
        ).contains(socket)
    }
    var writeSet = fd_set()
    openLolaFDZero(&writeSet)
    try openLolaFDSet(socket, set: &writeSet)
    var timeout = readableSocketTimeout(timeoutMicroseconds: timeoutMicroseconds)
    let result = select(socket + 1, nil, &writeSet, nil, &timeout)
    if result < 0 {
        let savedErrno = errno
        if savedErrno == EINTR {
            return false
        }
        throw UdpPcmRouteProbeError.receiveFailed(savedErrno)
    }
    guard result > 0 else {
        return false
    }
    return try openLolaFDIsSet(socket, set: &writeSet)
}

private func waitForKqueueSockets(
    sockets: [Int32],
    filter: Int16,
    timeoutMicroseconds: UInt64
) throws -> Set<Int32> {
    let queue = kqueue()
    guard queue >= 0 else {
        throw UdpPcmRouteProbeError.receiveFailed(errno)
    }
    defer { close(queue) }
    var changes = sockets.map { descriptor in
        var event = kevent64_s()
        event.ident = UInt64(descriptor)
        event.filter = filter
        event.flags = UInt16(EV_ADD | EV_ONESHOT)
        return event
    }
    var events = Array(repeating: kevent64_s(), count: sockets.count)
    var timeout = socketEventTimeoutTimespec(timeoutMicroseconds: timeoutMicroseconds)
    let result = changes.withUnsafeMutableBufferPointer { changeBuffer in
        events.withUnsafeMutableBufferPointer { eventBuffer in
            kevent64(
                queue,
                changeBuffer.baseAddress,
                Int32(changeBuffer.count),
                eventBuffer.baseAddress,
                Int32(eventBuffer.count),
                0,
                &timeout
            )
        }
    }
    if result < 0 {
        let savedErrno = errno
        if savedErrno == EINTR {
            return []
        }
        throw UdpPcmRouteProbeError.receiveFailed(savedErrno)
    }
    guard result > 0 else {
        return []
    }
    let readyEvents = events.prefix(Int(result))
    if let errorEvent = readyEvents.first(where: { ($0.flags & UInt16(EV_ERROR)) != 0 }) {
        let eventError = errorEvent.data == 0 ? EIO : Int32(errorEvent.data)
        throw UdpPcmRouteProbeError.receiveFailed(eventError)
    }
    return Set(readyEvents.map { Int32($0.ident) })
}

func socketEventTimeoutTimespec(timeoutMicroseconds: UInt64) -> timespec {
    let seconds = min(timeoutMicroseconds / 1_000_000, UInt64(Int.max))
    let remainingMicroseconds = timeoutMicroseconds - seconds * 1_000_000
    return timespec(
        tv_sec: Int(seconds),
        tv_nsec: Int(remainingMicroseconds * 1_000)
    )
}

func readableSocketTimeout(timeoutMicroseconds: UInt64) -> timeval {
    let maximumMicroseconds = UInt64(Int32.max) * 1_000
    let bounded = min(timeoutMicroseconds, maximumMicroseconds)
    return timeval(
        tv_sec: Int(bounded / 1_000_000),
        tv_usec: Int32(bounded % 1_000_000)
    )
}
