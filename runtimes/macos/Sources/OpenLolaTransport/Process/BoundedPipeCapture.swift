// Captures process-pipe bytes under a hard limit and records truncation so child output cannot grow memory without bound.
import Foundation

package final class BoundedPipeCapture: @unchecked Sendable {
    package enum LimitMode {
        case bytes
        case characters
    }

    private let readHandle: FileHandle
    private let writeHandle: FileHandle
    private let limit: Int
    private let mode: LimitMode
    private let lock = NSLock()
    private var prefixData = Data()
    private var didFinish = false
    private var failure: String?
    private static let maxConsecutiveRetries = 1_000

    package init(pipe: Pipe, limit: Int = 65_536, mode: LimitMode = .bytes) {
        self.readHandle = pipe.fileHandleForReading
        self.writeHandle = pipe.fileHandleForWriting
        self.limit = limit
        self.mode = mode
        readHandle.readabilityHandler = { [weak self] handle in
            self?.capture(handle.availableData)
        }
    }

    package func closeWriteHandle() {
        try? writeHandle.close()
    }

    /// Why draining stopped before end of stream, or nil when the whole stream was read; `prefix()` also notes it.
    package var readError: String? {
        lock.lock()
        defer { lock.unlock() }
        return failure
    }

    package func prefix(drainToEnd: Bool = true) -> String {
        if drainToEnd {
            finish()
        } else {
            readHandle.readabilityHandler = nil
            try? readHandle.close()
        }
        lock.lock()
        let data = prefixData
        let readFailure = failure
        lock.unlock()
        let text = String(data: data, encoding: .utf8) ?? "<non-UTF8 output: \(data.count) bytes>"
        let bounded = mode == .characters ? String(text.prefix(limit)) : text
        guard let readFailure else {
            return bounded
        }
        return bounded + "\n[output capture stopped early: \(readFailure)]"
    }

    private func finish() {
        let shouldDrain: Bool
        lock.lock()
        if didFinish {
            shouldDrain = false
        } else {
            didFinish = true
            shouldDrain = true
        }
        lock.unlock()

        guard shouldDrain else {
            return
        }
        readHandle.readabilityHandler = nil
        drain { try readHandle.read(upToCount: 64 * 1024) ?? Data() }
        try? readHandle.close()
    }

    /// Reads until an empty chunk, retrying EINTR and EAGAIN; any other error is recorded in `readError`.
    func drain(retryDelay: TimeInterval = 0.002, read: () throws -> Data) {
        var consecutiveRetries = 0
        while true {
            do {
                let data = try read()
                if data.isEmpty {
                    return
                }
                consecutiveRetries = 0
                capture(data)
            } catch {
                let code = Self.posixErrorCode(error)
                consecutiveRetries += 1
                guard code == EINTR || code == EAGAIN, consecutiveRetries <= Self.maxConsecutiveRetries else {
                    recordFailure("\(error.localizedDescription) (\(code.map { "errno \($0)" } ?? "unknown errno"))")
                    return
                }
                if code == EAGAIN {
                    Thread.sleep(forTimeInterval: retryDelay)
                }
            }
        }
    }

    private func recordFailure(_ message: String) {
        lock.lock()
        failure = message
        lock.unlock()
    }

    private static func posixErrorCode(_ error: Error) -> Int32? {
        let nsError = error as NSError
        if nsError.domain == NSPOSIXErrorDomain {
            return Int32(nsError.code)
        }
        guard let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
              underlying.domain == NSPOSIXErrorDomain else {
            return nil
        }
        return Int32(underlying.code)
    }

    private func capture(_ data: Data) {
        guard !data.isEmpty else {
            return
        }
        lock.lock()
        let remaining = limit - prefixData.count
        if remaining > 0 {
            prefixData.append(contentsOf: data.prefix(remaining))
        }
        lock.unlock()
    }
}
