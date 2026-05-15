final class SocketHeavyTestGate: @unchecked Sendable {
    static let shared = SocketHeavyTestGate()

    private let semaphore = AsyncSocketHeavyTestSemaphore()

    private init() {}

    func run<T>(_ body: () async throws -> T) async throws -> T {
        await semaphore.acquire()
        do {
            let result = try await body()
            await semaphore.release()
            return result
        } catch {
            await semaphore.release()
            throw error
        }
    }
}

private actor AsyncSocketHeavyTestSemaphore {
    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isHeld {
            isHeld = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isHeld = false
            return
        }

        waiters.removeFirst().resume()
    }
}
