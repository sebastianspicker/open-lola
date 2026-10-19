// Wraps a remote shell command so it receives SIGTERM when the local ssh client goes away, without needing a pty.

/// Builds the shell text that runs a remote command and stops it when its standard input reaches EOF.
///
/// ssh without `-t` gives the remote command no hangup signal when the client dies, but the remote side does see
/// EOF on standard input once the client exits or the local writer closes the pipe. The wrapper watches for that
/// EOF and sends SIGTERM to the command, and it exits with the command's own status so callers can still read it.
public enum RemoteProcessHangupWrapper {
    /// Returns `exec /bin/sh -c '<script>'` that runs `command` (already shell-quoted) under the EOF watcher.
    ///
    /// The script runs in /bin/sh rather than the remote login shell, because zsh lowers the priority of
    /// background jobs by default. fd 3 keeps the original standard input, since a background job's own standard
    /// input is /dev/null. The command gets neither fd 3 nor the watcher's output, and the watcher is stopped once
    /// the command exits so that no process keeps the ssh channel open.
    public static func command(_ command: String) -> String {
        let watcher = "( trap 'kill \"$c\" 2>/dev/null; exit 0' TERM; "
            + "cat <&3 >/dev/null 2>&1 & c=$!; wait \"$c\"; kill -TERM \"$p\" 2>/dev/null ) >/dev/null 2>&1"
        let script = "exec 3<&0; \(command) 3<&- & p=$!; \(watcher) & w=$!; exec 3<&-; "
            + "wait \"$p\"; s=$?; kill \"$w\" 2>/dev/null; exit \"$s\""
        return "exec /bin/sh -c \(singleQuoted(script))"
    }

    private static func singleQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
