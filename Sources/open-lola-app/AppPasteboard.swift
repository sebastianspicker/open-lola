// Bridges AppPasteboard clipboard access, isolating AppKit interaction from view and state logic.
import AppKit

@MainActor
enum AppPasteboard {
    static var writeString: (String) -> Bool = { value in
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(value, forType: .string)
    }

    @discardableResult
    static func copyString(_ value: String) -> Bool {
        writeString(value)
    }

    static func copyFeedback(_ value: String, target: String) -> AppPasteboardCopyFeedback {
        AppPasteboardCopyFeedback(target: target, copied: copyString(value))
    }
}

enum AppPasteboardCopyStatus {
    static func message(copied: Bool, success: String, failure: String) -> String {
        copied ? success : failure
    }
}

struct AppPasteboardCopyFeedback: Equatable {
    let target: String
    let copied: Bool

    var message: String {
        copied ? "Copied \(target)." : "Copy failed for \(target)."
    }

    var systemImage: String {
        copied ? "checkmark.circle" : "exclamationmark.triangle"
    }
}
