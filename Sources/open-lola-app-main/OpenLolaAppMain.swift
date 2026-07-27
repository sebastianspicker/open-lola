// Starts the native macOS application, keeping app-process setup separate from reusable SwiftUI support.
import AppKit
import OpenLolaAppSupport
import SwiftUI

@main
struct OpenLolaAppMain: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        OpenLolaAppScene()
    }
}
