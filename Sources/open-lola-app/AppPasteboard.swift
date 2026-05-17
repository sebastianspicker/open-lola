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
}

enum AppPasteboardCopyStatus {
    static func message(copied: Bool, success: String, failure: String) -> String {
        copied ? success : failure
    }
}
