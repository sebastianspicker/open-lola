// Classifies the exit of an SSH `test -f` readiness probe so permanent failures stop the wait instead of burning the timeout.
import Foundation

/// Result of one probe of a remote readiness marker over SSH.
package enum RemoteReadinessProbeOutcome: Equatable, Sendable {
    case ready
    case notReady
    case permanentFailure(String)

    private static let sshFailureExitCode: Int32 = 255
    private static let maxDetailCharacters = 300

    /// Maps the probe's exit status and standard error: 0 is ready, 1 means the marker is not there yet,
    /// 255 is an ssh-level failure (authentication, unreachable host), and 126/127 are a remote shell that
    /// cannot run `test`; any other status is treated as transient.
    package static func classify(exitCode: Int32, stderr: String) -> RemoteReadinessProbeOutcome {
        let detail = printable(String(stderr.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxDetailCharacters)))
        let suffix = detail.isEmpty ? "" : ": \(detail)"
        switch exitCode {
        case 0:
            return .ready
        case sshFailureExitCode:
            return .permanentFailure("ssh could not connect or authenticate (exit 255)\(suffix)")
        case 126, 127:
            return .permanentFailure("remote shell could not run the readiness check (exit \(exitCode))\(suffix)")
        default:
            return .notReady
        }
    }

    /// Replaces control characters (terminal escapes, inner newlines) in remote stderr with "?" before the text
    /// reaches the app's error message, as the Rust station's `printable` does.
    static func printable(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.map {
            $0.properties.generalCategory == .control ? "?" : $0
        }))
    }
}
