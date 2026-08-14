// Verifies the CLI pumps MainActor work while live connector transport executes off the main thread.
import Foundation
import Testing

@testable import OpenLolaCore

@Test @MainActor
func externalConnectorAppKitSessionRunPumpsMainActorUntilWorkerCompletes() throws {
    let mainRunLoopWorkCompleted = DispatchSemaphore(value: 0)
    let value = try runWhilePumpingMainRunLoop {
        RunLoop.main.perform { mainRunLoopWorkCompleted.signal() }
        guard mainRunLoopWorkCompleted.wait(timeout: .now() + 1) == .success else {
            throw AppKitSessionRunTestError.mainRunLoopDidNotRun
        }
        return 41
    }

    #expect(value == 41)
}

private enum AppKitSessionRunTestError: Error {
    case mainRunLoopDidNotRun
}
