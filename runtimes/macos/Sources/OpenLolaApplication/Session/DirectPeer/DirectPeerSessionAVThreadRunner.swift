import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Runs the direct-peer A/V session on a dedicated real-time thread so the main run loop stays free for AppKit preview delivery.
import AppKit
import Dispatch
import Foundation

/// Name of the dedicated thread that owns sockets, the peer runner and the media loops of one A/V session.
let directPeerAVSessionThreadName = "open-lola.direct-peer.av"

/// Runs `operation` on a dedicated user-interactive thread and blocks the caller until it finishes.
///
/// When the caller is the main thread and preview is requested, the main thread switches the process
/// to an accessory AppKit app and pumps the main run loop so `@MainActor` preview deliveries execute.
func runDirectPeerAVSessionOnDedicatedThread<Value: Sendable>(
    previewMode: DirectPeerSessionPreviewMode,
    _ operation: @escaping @Sendable () throws -> Value
) throws -> Value {
    let pumpsMainRunLoop = Thread.isMainThread && previewMode == .on
    if pumpsMainRunLoop {
        MainActor.assumeIsolated {
            _ = NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
    let state = DirectPeerAVSessionThreadResultState<Value>()
    let group = DispatchGroup()
    group.enter()
    let thread = Thread {
        state.store(Swift.Result(catching: operation))
        group.leave()
    }
    thread.qualityOfService = .userInteractive
    thread.name = directPeerAVSessionThreadName
    // Foundation threads default to a small stack; the session body used to run on the main thread.
    thread.stackSize = 8 << 20
    thread.start()
    if pumpsMainRunLoop {
        while group.wait(timeout: .now()) != .success {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
        }
    } else {
        group.wait()
    }
    return try state.take().get()
}

/// Carries a caller-supplied non-Sendable callback onto the session thread; it is invoked exactly once there.
final class DirectPeerAVSessionCallbackBox: @unchecked Sendable {
    private let callback: (() -> Void)?

    init(_ callback: (() -> Void)?) {
        self.callback = callback
    }

    func invoke() {
        callback?()
    }
}

enum DirectPeerAVSessionThreadError: Error, Equatable {
    case completedWithoutResult
}

private final class DirectPeerAVSessionThreadResultState<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Swift.Result<Value, any Error>?

    func store(_ result: Swift.Result<Value, any Error>) {
        lock.lock()
        self.result = result
        lock.unlock()
    }

    func take() -> Swift.Result<Value, any Error> {
        lock.lock()
        defer { lock.unlock() }
        return result ?? .failure(DirectPeerAVSessionThreadError.completedWithoutResult)
    }
}
