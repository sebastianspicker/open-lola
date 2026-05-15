import Foundation

final class BoundedPipeCapture: @unchecked Sendable {
    private let readHandle: FileHandle
    private let writeHandle: FileHandle
    private let limit: Int
    private let lock = NSLock()
    private var prefixData = Data()
    private var didFinish = false

    init(pipe: Pipe, limit: Int = 65_536) {
        self.readHandle = pipe.fileHandleForReading
        self.writeHandle = pipe.fileHandleForWriting
        self.limit = limit
        readHandle.readabilityHandler = { [weak self] handle in
            self?.capture(handle.availableData)
        }
    }

    func closeWriteHandle() {
        try? writeHandle.close()
    }

    func prefix(drainToEnd: Bool = true) -> String {
        if drainToEnd {
            finish()
        } else {
            readHandle.readabilityHandler = nil
            try? readHandle.close()
        }
        lock.lock()
        let data = prefixData
        lock.unlock()
        return String(decoding: data, as: UTF8.self)
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
        capture(readHandle.readDataToEndOfFile())
        try? readHandle.close()
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
