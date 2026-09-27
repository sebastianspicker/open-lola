import Foundation

/// Synchronizes one asynchronous UDP loop result without coupling its error policy.
final class UdpResultBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedResult: Result<Value, Error>?

    func store(_ result: Result<Value, Error>) {
        lock.lock()
        defer { lock.unlock() }
        storedResult = result
    }

    func result(or missingResultError: @autoclosure () -> Error) throws -> Result<Value, Error> {
        lock.lock()
        defer { lock.unlock() }
        guard let storedResult else {
            throw missingResultError()
        }
        return storedResult
    }
}
