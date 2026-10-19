// Quotes command arguments for POSIX shells so copied commands run unchanged.
import Foundation

/// Formats argument vectors as POSIX shell command lines.
public enum NativeAppShellCommandLine {
    private static let safeScalars = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_@%+=:,./-"
    )

    /// Returns the argument unchanged when it is shell-safe, otherwise single-quoted with embedded quotes escaped.
    public static func escapedArgument(_ argument: String) -> String {
        guard !argument.isEmpty else {
            return "''"
        }
        // zsh expands a leading `=word` to a command path, so such arguments are quoted too.
        if !argument.hasPrefix("="), argument.unicodeScalars.allSatisfy({ safeScalars.contains($0) }) {
            return argument
        }
        return "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Joins the arguments into one shell line, quoting each as needed.
    public static func shellLine(_ arguments: [String]) -> String {
        arguments.map(escapedArgument).joined(separator: " ")
    }
}
