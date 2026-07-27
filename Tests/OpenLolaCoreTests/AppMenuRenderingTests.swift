// Verifies that app menu source does not render unsupported debug labels.
import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@Test
func appMenuSourceDoesNotRenderUnsupportedDebugLabels() throws {
    let source = try readAppShellSource("Sources/open-lola-app/OpenLolaApp.swift")

    #expect(!source.contains("Unsupported:"))
    #expect(!source.contains("unsupportedMenuAction"))
}

@Test
func appMenuRenderingFiltersFutureUnmappedActions() {
    let futureAction = NativeAppShellSurfaceAction(
        identity: .init(id: "future-unmapped-action", title: "Future Unmapped Action", keyboardShortcut: nil),
        effects: .init(refreshesReportOnly: false, startsRealtimeAudio: false, startsRealtimeVideo: false, armsControlOutput: false)
    )
    let contractActions = NativeAppShellSurfaceContract.releaseReadiness.actions
    let actions = contractActions + [futureAction]

    #expect(AppMenuActionHandling.renderedActions(from: actions).map(\.id) == contractActions.map(\.id))
    #expect(AppMenuActionHandling.omittedActionIDs(from: actions) == ["future-unmapped-action"])
}

@Test
func appOperatorMenuActionsDeclareSupportedShortcuts() throws {
    let expectedShortcuts = [
        "refresh-synthetic-metrics": "command-r",
        "arm-execution": "command-shift-e",
        "write-two-peer-plan": "command-option-w",
        "dry-run-supervisor": "command-option-d",
        "validate-supervisor-report": "command-shift-v",
        "open-local-preview-window": "command-shift-p"
    ]
    let actualShortcuts = Dictionary(
        uniqueKeysWithValues: NativeAppShellActionInventory.menuActions.compactMap { action in
            action.keyboardShortcut.map { (action.id, $0) }
        }
    )

    for (actionID, shortcut) in expectedShortcuts {
        #expect(actualShortcuts[actionID] == shortcut)
        #expect(AppMenuShortcut(shortcut) != nil)
    }
}

private func readAppShellSource(_ relativePath: String) throws -> String {
    let testFile = URL(fileURLWithPath: #filePath)
    let repositoryRoot = testFile
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: repositoryRoot.appendingPathComponent(relativePath), encoding: .utf8)
}
