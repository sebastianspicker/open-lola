import Darwin
import os

extension UdpMediaTransport {
    public func close() {
        guard markClosedForCleanup() else {
            return
        }
        interruptBlockingReceive()
        closeUdpSocket(descriptor)
    }

    func withOpenSocketLock<R>(_ operation: () throws -> R) throws -> R {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !isClosed else {
            throw UdpPcmRouteProbeError.receiveFailed(EBADF)
        }
        return try operation()
    }

    func openSocketDescriptor() throws -> Int32 {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !isClosed else {
            throw UdpPcmRouteProbeError.receiveFailed(EBADF)
        }
        return descriptor
    }

    func requireSocketOpenAfterBlockingOperation() throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !isClosed else {
            throw UdpPcmRouteProbeError.receiveFailed(EBADF)
        }
    }

    private func markClosedForCleanup() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !isClosed else {
            return false
        }
        isClosed = true
        return true
    }

    private func interruptBlockingReceive() {
        let result = shutdown(descriptor, SHUT_RDWR)
        guard result != 0 else {
            return
        }
        let savedErrno = errno
        if savedErrno == EBADF || savedErrno == EINVAL || savedErrno == ENOTCONN || savedErrno == ENOTSOCK {
            return
        }
        os_log(
            .error,
            "shutdown failed while interrupting UDP receive on socket %{public}d with errno %{public}d",
            descriptor,
            savedErrno
        )
    }
}
