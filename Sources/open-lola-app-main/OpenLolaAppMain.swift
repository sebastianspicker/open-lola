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
