import AppKit
import OpenLolaCore
import SwiftUI

public struct OpenLolaApp: App {
    @NSApplicationDelegateAdaptor(OpenLolaApplicationDelegate.self) private var appDelegate

    public init() {}

    public var body: some Scene {
        OpenLolaAppScene(appDelegate: appDelegate)
    }
}

public struct OpenLolaAppScene: Scene {
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.openWindow) private var openWindow
    @State var report = NativeAppShellReport.placeholder()
    @State var operatorSurface: NativeAppShellOperatorPrototypeState
    @State var executionController: AppExecutionController
    @State var previewState: AppPreviewReceiverState
    @State var inventoryController = AppLocalOperatorInventoryController()
    @State var appSettings: AppSettings
    @State var syntheticMetricsRefreshState = AppSyntheticMetricsRefreshState.idle
    @State var quitConfirmationPresented = false
    @State var stopConfirmationPresented = false
    let surfaceContract = NativeAppShellSurfaceContract.releaseReadiness
    let appDelegate: OpenLolaApplicationDelegate?

    public init() {
        self.init(appDelegate: nil)
    }

    init(appDelegate: OpenLolaApplicationDelegate?) {
        self.appDelegate = appDelegate
        AppMenuActionHandling.logOmittedActions(from: NativeAppShellSurfaceContract.releaseReadiness.actions)
        let previewState = AppShellStoredDefaults.previewReceiverState()
        let executionController = AppExecutionController(settings: AppShellStoredDefaults.executionSettings())
        let appSettings = AppSettings()
        _operatorSurface = State(initialValue: AppShellStoredDefaults.placeholderOperatorSurface())
        _executionController = State(initialValue: executionController)
        _previewState = State(initialValue: previewState)
        _appSettings = State(initialValue: appSettings)
    }

}

extension OpenLolaAppScene {
    @ViewBuilder
    func appMenuActionButton(_ action: NativeAppShellSurfaceAction) -> some View {
        switch AppMenuActionGroup(actionID: action.id) {
        case .refresh:
            refreshMenuActionButton(action)
        case .preparation:
            preparationMenuActionButton(action)
        case .transport:
            transportMenuActionButton(action)
        case .validation:
            validationMenuActionButton(action)
        case .preview:
            previewMenuActionButton(action)
        case .unsupported:
            EmptyView()
        }
    }

    @ViewBuilder
    func refreshMenuActionButton(_ action: NativeAppShellSurfaceAction) -> some View {
        switch action.id {
        case "refresh-synthetic-metrics":
            menuButton(action) { refreshSyntheticMetrics() }
        case "refresh-local-media-inventory":
            menuButton(action) { refreshInventory() }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    func preparationMenuActionButton(_ action: NativeAppShellSurfaceAction) -> some View {
        switch action.id {
        case "arm-execution":
            let reason = AppMenuActionPolicy.armDisabledReason(
                sessionMode: operatorSurface.sessionMode,
                isRunning: executionController.isRunning
            )
            menuButton(action, disabled: reason != nil, help: reason) {
                executionController.armedForExecution.toggle()
            }
        case "write-two-peer-plan":
            let reason = AppMenuActionPolicy.writePlanDisabledReason(
                sessionMode: operatorSurface.sessionMode,
                isRunning: executionController.isRunning
            )
            menuButton(action, disabled: reason != nil, help: reason) {
                _ = executionController.writePlanOrLogError(from: operatorSurface)
            }
        case "dry-run-supervisor":
            let reason = AppMenuActionPolicy.dryRunDisabledReason(
                sessionMode: operatorSurface.sessionMode,
                planIsConfigured: operatorPlanIsConfigured,
                isRunning: executionController.isRunning
            )
            menuButton(action, disabled: reason != nil, help: reason) {
                if executionController.prepareExecution(from: operatorSurface) {
                    operatorSurface.commandIntent = .handoffRequested
                    executionController.dryRun(operatorSurface: operatorSurface)
                }
            }
        case "set-handoff-intent":
            let reason = AppMenuActionPolicy.handoffIntentDisabledReason(
                planIsConfigured: operatorPlanIsConfigured,
                isRunning: executionController.isRunning
            )
            menuButton(action, disabled: reason != nil, help: reason) {
                operatorSurface.commandIntent = .handoffRequested
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    func transportMenuActionButton(_ action: NativeAppShellSurfaceAction) -> some View {
        switch action.id {
        case "start-armed-supervisor":
            let readiness = AppStartReadiness(
                sessionMode: operatorSurface.sessionMode,
                planIsConfigured: operatorPlanIsConfigured,
                isRunning: executionController.isRunning,
                armedForExecution: executionController.armedForExecution,
                lastValidationResult: executionController.lastValidationResult,
                hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence
            )
            let reason = AppMenuActionPolicy.startDisabledReason(readiness)
            menuButton(action, disabled: reason != nil, help: reason) {
                if executionController.prepareExecution(from: operatorSurface) {
                    if executionController.startArmed(operatorSurface: operatorSurface) {
                        operatorSurface.commandIntent = .runRequested
                    } else {
                        operatorSurface.commandIntent = .idle
                    }
                }
            }
        case "stop-supervisor-run":
            let reason = AppMenuActionPolicy.stopDisabledReason(isRunning: executionController.isRunning)
            menuButton(action, disabled: reason != nil, help: reason) {
                requestMenuStop()
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    func validationMenuActionButton(_ action: NativeAppShellSurfaceAction) -> some View {
        switch action.id {
        case "validate-supervisor-report":
            let validationReadiness = executionController.validationReadiness(operatorSurface: operatorSurface)
            let reason = AppMenuActionPolicy.validateDisabledReason(
                validationUnavailableMessage: validationReadiness.unavailableMessage
            )
            menuButton(action, disabled: reason != nil, help: reason) {
                executionController.validateReport(operatorSurface: operatorSurface)
            }
        case "clear-command-intent":
            menuButton(action) { operatorSurface.commandIntent = .idle }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    func previewMenuActionButton(_ action: NativeAppShellSurfaceAction) -> some View {
        switch action.id {
        case "open-local-preview-window":
            menuButton(action, help: AppPreviewWindowRequestFeedback.menuHelp) {
                previewState.requestPreviewWindow()
                openWindow(id: "receiver")
            }
        default:
            EmptyView()
        }
    }

    func menuButton(
        _ action: NativeAppShellSurfaceAction,
        disabled: Bool = false,
        help: String? = nil,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action.title, action: perform)
            .disabled(disabled)
            .help(help ?? action.title)
            .modifier(AppMenuKeyboardShortcut(shortcut: action.keyboardShortcut))
    }

    func refreshInventory() {
        inventoryController.refresh(currentSurface: operatorSurface) { nextSurface in
            operatorSurface = AppLocalOperatorInventoryRefreshMergePolicy.merge(
                current: operatorSurface,
                refreshResult: nextSurface
            )
        }
    }

    @MainActor
    func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .background, executionController.isRunning {
            executionController.tearDown()
            operatorSurface.commandIntent = .stopRequested
        }
    }

    func refreshSyntheticMetrics() {
        Task { await refreshSyntheticMetricsAsync() }
    }

    @MainActor
    func refreshSyntheticMetricsAsync() async {
        guard !syntheticMetricsRefreshState.isRefreshing else {
            return
        }
        syntheticMetricsRefreshState = .refreshing
        report = await Task.detached {
            NativeAppShellSyntheticSmoke.run()
        }.value
        syntheticMetricsRefreshState = .refreshed
    }

    var operatorPlanIsConfigured: Bool {
        AppOperatorPrototypePlan.make(operatorSurface: operatorSurface).isConfigured
    }

    @MainActor
    func installQuitGuard() {
        guard let appDelegate else {
            return
        }
        appDelegate.shouldRequestTerminationConfirmation = {
            executionController.isRunning && !appDelegate.allowNextTerminate
        }
        appDelegate.requestTerminationConfirmation = {
            quitConfirmationPresented = true
        }
    }

    @MainActor
    func confirmQuitWhileRunning() {
        guard let appDelegate else {
            return
        }
        appDelegate.allowNextTerminate = true
        if executionController.isRunning {
            executionController.stop()
            operatorSurface.commandIntent = .stopRequested
        }
        NSApplication.shared.terminate(nil)
    }

    @MainActor
    func requestMenuStop() {
        guard executionController.isRunning else {
            return
        }
        if AppTransportStopConfirmationPolicy.requiresConfirmation(
            isRunning: executionController.isRunning,
            lastRunWasDryRun: executionController.lastRunWasDryRun
        ) {
            stopConfirmationPresented = true
            return
        }
        confirmMenuStop()
    }

    @MainActor
    func confirmMenuStop() {
        executionController.stop()
        operatorSurface.commandIntent = .stopRequested
    }
}

@MainActor
final class OpenLolaApplicationDelegate: NSObject, NSApplicationDelegate {
    var allowNextTerminate = false
    var shouldRequestTerminationConfirmation: () -> Bool = { false }
    var requestTerminationConfirmation: () -> Void = {}

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard shouldRequestTerminationConfirmation() else {
            return .terminateNow
        }
        requestTerminationConfirmation()
        return .terminateCancel
    }
}

struct AppStartReadiness {
    var sessionMode: NativeAppShellSessionMode
    var planIsConfigured: Bool
    var isRunning: Bool
    var armedForExecution: Bool
    var lastValidationResult: AppValidationResult
    var hasValidatedRuntimeEvidence: Bool
}
