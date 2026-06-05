import OpenLolaCore

enum AppMenuActionHandling {
    static let handledActionIDs: Set<String> = [
        "refresh-synthetic-metrics",
        "refresh-local-media-inventory",
        "arm-execution",
        "write-two-peer-plan",
        "dry-run-supervisor",
        "set-handoff-intent",
        "start-armed-supervisor",
        "stop-supervisor-run",
        "validate-supervisor-report",
        "clear-command-intent",
        "open-local-preview-window",
    ]

    static func renderedActions(from actions: [NativeAppShellSurfaceAction]) -> [NativeAppShellSurfaceAction] {
        actions.filter { handledActionIDs.contains($0.id) }
    }

    static func omittedActionIDs(from actions: [NativeAppShellSurfaceAction]) -> [String] {
        actions.map(\.id).filter { !handledActionIDs.contains($0) }
    }

    static func logOmittedActions(from actions: [NativeAppShellSurfaceAction]) {
        #if DEBUG
        let ids = omittedActionIDs(from: actions)
        if !ids.isEmpty {
            debugPrint("Open LoLa omitted unsupported menu action ids: \(ids.joined(separator: ", "))")
        }
        #endif
    }
}

enum AppMenuActionGroup {
    case refresh
    case preparation
    case transport
    case validation
    case preview
    case unsupported

    private static let refreshActionIDs: Set<String> = [
        "refresh-synthetic-metrics",
        "refresh-local-media-inventory",
    ]

    private static let preparationActionIDs: Set<String> = [
        "arm-execution",
        "write-two-peer-plan",
        "dry-run-supervisor",
        "set-handoff-intent",
    ]

    private static let transportActionIDs: Set<String> = [
        "start-armed-supervisor",
        "stop-supervisor-run",
    ]

    private static let validationActionIDs: Set<String> = [
        "validate-supervisor-report",
        "clear-command-intent",
    ]

    init(actionID: String) {
        if Self.refreshActionIDs.contains(actionID) {
            self = .refresh
        } else if Self.preparationActionIDs.contains(actionID) {
            self = .preparation
        } else if Self.transportActionIDs.contains(actionID) {
            self = .transport
        } else if Self.validationActionIDs.contains(actionID) {
            self = .validation
        } else if actionID == "open-local-preview-window" {
            self = .preview
        } else {
            self = .unsupported
        }
    }
}
