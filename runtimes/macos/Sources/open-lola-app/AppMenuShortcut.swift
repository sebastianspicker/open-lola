// Defines AppMenuShortcut menu behavior, keeping command routing and shortcut policy outside view layout.
import SwiftUI

struct AppMenuKeyboardShortcut: ViewModifier {
    let shortcut: String?

    func body(content: Content) -> some View {
        guard let shortcut = AppMenuShortcut(shortcut) else {
            return AnyView(content)
        }
        return AnyView(content.keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers))
    }
}

struct AppMenuShortcut {
    let key: KeyEquivalent
    let modifiers: EventModifiers

    init?(_ rawValue: String?) {
        switch rawValue {
        case "command-r":
            // Native SwiftUI shell has no WKWebView and no NavigationStack reload owner, so Command-R remains refresh.
            key = "r"
            modifiers = [.command]
        case "command-shift-e":
            key = "e"
            modifiers = [.command, .shift]
        case "command-shift-p":
            key = "p"
            modifiers = [.command, .shift]
        case "command-shift-v":
            key = "v"
            modifiers = [.command, .shift]
        case "command-option-d":
            key = "d"
            modifiers = [.command, .option]
        case "command-option-w":
            key = "w"
            modifiers = [.command, .option]
        default:
            return nil
        }
    }
}
