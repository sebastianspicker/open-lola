import Foundation
import OpenLolaCore

@MainActor
extension AppExecutionController {
    @discardableResult
    func writePlanOrLogError(from operatorSurface: NativeAppShellOperatorPrototypeState) -> Bool {
        do {
            _ = try operatorSurface.writeTwoPeerRunPlanArtifact(
                to: URL(fileURLWithPath: settings.planPath),
                runDirectory: URL(fileURLWithPath: settings.planPath)
                    .deletingLastPathComponent()
                    .path
            )
            status = "Plan written."
            phase = .planWritten
            lastError = nil
            return true
        } catch {
            lastError = String(describing: error)
            status = "Plan write failed."
            phase = .runFailed
            return false
        }
    }

    func prepareExecution(from operatorSurface: NativeAppShellOperatorPrototypeState) -> Bool {
        switch operatorSurface.sessionMode.appExecutionRoute {
        case .directMacPeer:
            return writePlanOrLogError(from: operatorSurface)
        case .windowsLoLa, .externalConnector:
            return true
        case .unsupportedExternalConnector:
            return false
        }
    }
}
