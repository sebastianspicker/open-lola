import Foundation

final class BoundedPipeCapture: @unchecked Sendable {
    enum LimitMode {
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

    init(pipe: Pipe, limit: Int = 65_536, mode: LimitMode = .bytes) {
        self.readHandle = pipe.fileHandleForReading
        self.writeHandle = pipe.fileHandleForWriting
        self.limit = limit
        self.mode = mode
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
        let text = String(data: data, encoding: .utf8) ?? "<non-UTF8 output: \(data.count) bytes>"
        switch mode {
        case .bytes:
            return text
        case .characters:
            return String(text.prefix(limit))
        }
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
