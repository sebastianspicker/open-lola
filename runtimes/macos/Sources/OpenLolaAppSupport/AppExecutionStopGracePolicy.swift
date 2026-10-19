// Derives how long the app lets a stopping supervisor run before SIGKILL, so it never kills it mid-way through stopping ssh peers.
import Foundation
import OpenLolaCore

enum AppExecutionStopGracePolicy {
    /// Seconds the app waits after SIGTERM for a local supervisor, which stops its peers with SIGTERM and SIGKILL only.
    static let localGraceSeconds: TimeInterval = 5

    /// Slack on top of the supervisor's own worst case, for process start-up of the stop path and report writing.
    static let sshMarginSeconds: TimeInterval = 2

    /// Seconds between the app's SIGTERM and its SIGKILL of the supervisor for `mode`.
    ///
    /// An ssh supervisor first closes the peers' stdin and waits `defaultStandardInputCloseGraceSeconds`, then sends
    /// SIGTERM and waits `defaultGraceSeconds`, then sends SIGKILL and waits `defaultGraceSeconds` again; the app
    /// must outlast that worst case plus `sshMarginSeconds`, or it orphans the remote peers.
    static func gracePeriod(for mode: DirectPeerTwoPeerRunExecutionMode) -> TimeInterval {
        switch mode {
        case .local:
            localGraceSeconds
        case .ssh:
            ManagedProcessRunner.defaultStandardInputCloseGraceSeconds
                + 2 * ManagedProcessStopMonitor.defaultGraceSeconds
                + sshMarginSeconds
        }
    }
}
