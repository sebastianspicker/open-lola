// Builds the operator-facing message shown when a run exits non-zero, from the exit status and the tail of its stderr log.
import Foundation

enum AppRunFailureMessage {
    static let maximumTailBytes = 4_096
    static let maximumTailLines = 3
    static let maximumLineCharacters = 400

    /// Prefers a localized description (for example from `LocalizedError`) over the raw case dump.
    static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    /// Names the exit status, the last few stderr lines (when any) and the full stderr log path.
    static func make(exitCode: Int32, stderrTail: String, stderrPath: String) -> String {
        let lines = lastLines(of: stderrTail)
        var message = "Run failed (exit status \(exitCode))."
        if lines.isEmpty {
            message += " Nothing was written to stderr."
        } else {
            message += " Last stderr lines:\n" + lines.joined(separator: "\n")
        }
        return message + "\nFull log: \(stderrPath)"
    }

    /// Keeps the last few non-empty lines, each cut to a readable length.
    static func lastLines(of stderrTail: String) -> [String] {
        stderrTail
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .suffix(maximumTailLines)
            .map { String($0.prefix(maximumLineCharacters)) }
    }

    /// Reads at most `maximumTailBytes` from the end of the file; returns an empty string when it cannot be read.
    static func stderrTail(atPath path: String) -> String {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            return ""
        }
        defer { try? handle.close() }
        do {
            let size = try handle.seekToEnd()
            let offset = size > UInt64(maximumTailBytes) ? size - UInt64(maximumTailBytes) : 0
            try handle.seek(toOffset: offset)
            let data = try handle.readToEnd() ?? Data()
            var text = String(decoding: data, as: UTF8.self)
            if offset > 0, let firstNewline = text.firstIndex(of: "\n") {
                // The window starts mid-line; drop the partial first line.
                text = String(text[text.index(after: firstNewline)...])
            }
            return text
        } catch {
            return ""
        }
    }
}
