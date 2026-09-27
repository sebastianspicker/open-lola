import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Keeps the command-line AppKit preview responsive while connector transport work runs off the main thread.
import AppKit
import Foundation

/// Runs live connector video receive work off the main thread while pumping the AppKit preview run loop.
public enum ExternalConnectorAppKitSessionRunner {
    public static func run(
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> ExternalConnectorSessionReport {
        guard requiresAppKitSessionRunLoop(configuration), Thread.isMainThread else {
            return try ExternalConnectorSessionRunner.run(configuration: configuration)
        }
        MainActor.assumeIsolated {
            NSApplication.shared.setActivationPolicy(.accessory)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        return try runWhilePumpingMainRunLoop {
            try ExternalConnectorSessionRunner.run(configuration: configuration)
        }
    }
}

func runWhilePumpingMainRunLoop<Result: Sendable>(
    _ operation: @escaping @Sendable () throws -> Result
) throws -> Result {
    let state = ExternalConnectorSessionResultState<Result>()
    let group = DispatchGroup()
    group.enter()
    DispatchQueue.global(qos: .userInitiated).async {
        state.store(Swift.Result(catching: operation))
        group.leave()
    }
    while group.wait(timeout: .now()) != .success {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
    }
    return try state.take().get()
}

private func requiresAppKitSessionRunLoop(
    _ configuration: ExternalConnectorSessionConfiguration
) -> Bool {
    !configuration.dryRun
        && configuration.role.receives
        && configuration.mediaMode.hasVideo
        && configuration.videoDisplay == "appkit"
}

private final class ExternalConnectorSessionResultState<Value: Sendable>: @unchecked Sendable {
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
        return result ?? .failure(ExternalConnectorSessionError.socketFailed(
            "AppKit connector session completed without a result"
        ))
    }
}
