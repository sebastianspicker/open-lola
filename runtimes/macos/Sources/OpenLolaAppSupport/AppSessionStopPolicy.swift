// Decides which lifecycle events may stop a running session, so hiding or minimizing the window never ends a live run.
import SwiftUI

enum AppSessionStopTrigger: Equatable {
    case scenePhase(ScenePhase)
    case explicitStop
    case applicationTermination
}

enum AppSessionStopPolicy {
    /// Only an explicit Stop or application termination stops a run; scene phases (hide, minimize, inactive) never do.
    static func stopsRunningSession(for trigger: AppSessionStopTrigger) -> Bool {
        switch trigger {
        case .scenePhase:
            false
        case .explicitStop, .applicationTermination:
            true
        }
    }
}
