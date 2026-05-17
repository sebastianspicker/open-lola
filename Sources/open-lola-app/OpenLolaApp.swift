import OpenLolaCore
import SwiftUI

public struct OpenLolaApp: App {
    public init() {}

    public var body: some Scene {
        OpenLolaAppScene()
    }
}

public struct OpenLolaAppScene: Scene {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow
    @State private var report = NativeAppShellReport.placeholder()
    @State private var operatorSurface: NativeAppShellOperatorPrototypeState
    @State private var executionController: AppExecutionController
    @State private var previewState: AppPreviewReceiverState
    @State private var inventoryController = AppLocalOperatorInventoryController()
    @State private var appSettings: AppSettings
    private let surfaceContract = NativeAppShellSurfaceContract.releaseReadiness

    public init() {
        let previewState = AppShellStoredDefaults.previewReceiverState()
        let executionController = AppExecutionController(settings: AppShellStoredDefaults.executionSettings())
        let appSettings = AppSettings()
        _operatorSurface = State(initialValue: AppShellStoredDefaults.placeholderOperatorSurface())
        _executionController = State(initialValue: executionController)
        _previewState = State(initialValue: previewState)
        _appSettings = State(initialValue: appSettings)
    }

    public var body: some Scene {
        Window("Open LoLa", id: "main") {
            AppShellRootView(
                report: report,
                operatorSurface: $operatorSurface,
                executionController: executionController,
                previewState: previewState,
                inventoryController: inventoryController,
                appSettings: appSettings,
                contract: surfaceContract,
                refreshReport: refreshSyntheticMetrics,
                refreshInventory: refreshInventory
            )
            .onChange(of: scenePhase) { _, phase in
                Task { @MainActor in
                    handleScenePhaseChange(phase)
                }
            }
            .task { await refreshSyntheticMetricsAsync() }
            .task { refreshInventory() }
        }
        .commands {
            CommandMenu("Open LoLa") {
                ForEach(surfaceContract.actions, id: \.id) { action in
                    appMenuActionButton(action)
                }
            }
        }

        Window("Local Preview", id: "receiver") {
            AppReceiverWindowView(
                operatorSurface: $operatorSurface,
                previewState: previewState
            )
        }
        .defaultSize(width: 920, height: 680)

        Settings {
            AppShellSettingsView(
                configuration: report.configuration,
                operatorSurface: $operatorSurface,
                executionController: executionController,
                previewState: previewState,
                appSettings: appSettings
            )
        }
    }

    @ViewBuilder
    private func appMenuActionButton(_ action: NativeAppShellSurfaceAction) -> some View {
        if AppMenuActionHandling.isHandled(action.id) {
            switch action.id {
            case "refresh-synthetic-metrics":
                menuButton(action) { refreshSyntheticMetrics() }
            case "refresh-local-media-inventory":
                menuButton(action) { refreshInventory() }
            case "arm-execution":
                menuButton(action) { executionController.armedForExecution.toggle() }
            case "write-two-peer-plan":
                menuButton(action, disabled: executionController.isRunning || operatorSurface.sessionMode != .directMacPeer) {
                    _ = executionController.writePlanOrLogError(from: operatorSurface)
                }
            case "dry-run-supervisor":
                menuButton(action, disabled: executionController.isRunning) {
                    if prepareExecution() {
                        operatorSurface.commandIntent = .handoffRequested
                        executionController.dryRun(operatorSurface: operatorSurface)
                    }
                }
            case "set-handoff-intent":
                menuButton(action, disabled: executionController.isRunning || !operatorPlanIsConfigured) {
                    operatorSurface.commandIntent = .handoffRequested
                }
            case "start-armed-supervisor":
                menuButton(action, disabled: !executionController.armedForExecution || executionController.isRunning) {
                    if prepareExecution() {
                        operatorSurface.commandIntent = .runRequested
                        executionController.startArmed(operatorSurface: operatorSurface)
                    }
                }
            case "stop-supervisor-run":
                menuButton(action, disabled: !executionController.isRunning) {
                    executionController.stop()
                    operatorSurface.commandIntent = .stopRequested
                }
            case "validate-supervisor-report":
                menuButton(action, disabled: !executionController.canValidateReport(operatorSurface: operatorSurface)) {
                    executionController.validateReport(operatorSurface: operatorSurface)
                }
            case "clear-command-intent":
                menuButton(action) { operatorSurface.commandIntent = .idle }
            case "open-local-preview-window":
                menuButton(action) {
                    previewState.receiverStatus = "Local preview window requested."
                    openWindow(id: "receiver")
                }
            default:
                unsupportedMenuAction(action)
            }
        } else {
            unsupportedMenuAction(action)
        }
    }

    private func unsupportedMenuAction(_ action: NativeAppShellSurfaceAction) -> some View {
        Button("Unsupported: \(action.title)") {}
            .disabled(true)
            .help("Unsupported menu action: \(action.id)")
    }

    private func menuButton(
        _ action: NativeAppShellSurfaceAction,
        disabled: Bool = false,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action.title, action: perform)
            .disabled(disabled)
            .modifier(AppMenuKeyboardShortcut(shortcut: action.keyboardShortcut))
    }

    private func refreshInventory() {
        inventoryController.refresh(currentSurface: operatorSurface) { nextSurface in
            operatorSurface = nextSurface
        }
    }

    @MainActor
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .background, executionController.isRunning {
            executionController.tearDown()
            operatorSurface.commandIntent = .stopRequested
        }
    }

    private func refreshSyntheticMetrics() {
        Task { await refreshSyntheticMetricsAsync() }
    }

    @MainActor
    private func refreshSyntheticMetricsAsync() async {
        report = await Task.detached {
            NativeAppShellSyntheticSmoke.run()
        }.value
    }

    private func prepareExecution() -> Bool {
        switch operatorSurface.sessionMode {
        case .directMacPeer:
            return executionController.writePlanOrLogError(from: operatorSurface)
        case .windowsLoLa:
            return true
        case .jackTrip, .ultraGrid:
            return false
        }
    }

    private var operatorPlanIsConfigured: Bool {
        AppOperatorPrototypePlan.make(operatorSurface: operatorSurface).isConfigured
    }
}

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

    static func isHandled(_ actionID: String) -> Bool {
        handledActionIDs.contains(actionID)
    }
}

private struct AppMenuKeyboardShortcut: ViewModifier {
    let shortcut: String?

    func body(content: Content) -> some View {
        guard let shortcut = AppMenuShortcut(shortcut) else {
            return AnyView(content)
        }
        return AnyView(content.keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers))
    }
}

private struct AppMenuShortcut {
    let key: KeyEquivalent
    let modifiers: EventModifiers

    init?(_ rawValue: String?) {
        switch rawValue {
        case "command-r":
            key = "r"
            modifiers = [.command]
        case "command-shift-e":
            key = "e"
            modifiers = [.command, .shift]
        case "command-shift-p":
            key = "p"
            modifiers = [.command, .shift]
        default:
            return nil
        }
    }
}
