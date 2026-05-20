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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow
    @State private var report = NativeAppShellReport.placeholder()
    @State private var operatorSurface: NativeAppShellOperatorPrototypeState
    @State private var executionController: AppExecutionController
    @State private var previewState: AppPreviewReceiverState
    @State private var inventoryController = AppLocalOperatorInventoryController()
    @State private var appSettings: AppSettings
    @State private var quitConfirmationPresented = false
    @State private var stopConfirmationPresented = false
    private let surfaceContract = NativeAppShellSurfaceContract.releaseReadiness
    private let appDelegate: OpenLolaApplicationDelegate?

    public init() {
        self.init(appDelegate: nil)
    }

    init(appDelegate: OpenLolaApplicationDelegate?) {
        self.appDelegate = appDelegate
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
            .onAppear(perform: installQuitGuard)
            .confirmationDialog(
                "Quit while supervisor is running?",
                isPresented: $quitConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Quit and Stop", role: .destructive, action: confirmQuitWhileRunning)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A supervisor process is active. Quitting will stop it.")
            }
            .confirmationDialog(
                "Stop active session?",
                isPresented: $stopConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Stop", role: .destructive, action: confirmMenuStop)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Stopping ends the current active audio/video session.")
            }
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
                previewState: previewState,
                executionPhase: executionController.phase
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
                menuButton(action, disabled: menuArmDisabled) { executionController.armedForExecution.toggle() }
            case "write-two-peer-plan":
                menuButton(action, disabled: executionController.isRunning || operatorSurface.sessionMode != .directMacPeer) {
                    _ = executionController.writePlanOrLogError(from: operatorSurface)
                }
            case "dry-run-supervisor":
                menuButton(action, disabled: !menuDryRunAvailable) {
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
                menuButton(action, disabled: !menuStartAvailable) {
                    if prepareExecution() {
                        if executionController.startArmed(operatorSurface: operatorSurface) {
                            operatorSurface.commandIntent = .runRequested
                        } else {
                            operatorSurface.commandIntent = .idle
                        }
                    }
                }
            case "stop-supervisor-run":
                menuButton(action, disabled: !executionController.isRunning) {
                    requestMenuStop()
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

    private var menuDryRunAvailable: Bool {
        AppMenuActionPolicy.dryRunAvailable(
            sessionMode: operatorSurface.sessionMode,
            planIsConfigured: operatorPlanIsConfigured,
            isRunning: executionController.isRunning
        )
    }

    private var menuStartAvailable: Bool {
        AppMenuActionPolicy.startAvailable(
            sessionMode: operatorSurface.sessionMode,
            planIsConfigured: operatorPlanIsConfigured,
            isRunning: executionController.isRunning,
            armedForExecution: executionController.armedForExecution,
            lastValidationResult: executionController.lastValidationResult,
            hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence
        )
    }

    private var menuArmDisabled: Bool {
        AppMenuActionPolicy.armDisabled(
            sessionMode: operatorSurface.sessionMode,
            isRunning: executionController.isRunning
        )
    }

    @MainActor
    private func installQuitGuard() {
        guard let appDelegate else {
            return
        }
        appDelegate.shouldRequestTerminationConfirmation = {
            AppQuitGuardPolicy.requiresConfirmation(
                isRunning: executionController.isRunning,
                allowNextTerminate: appDelegate.allowNextTerminate
            )
        }
        appDelegate.requestTerminationConfirmation = {
            quitConfirmationPresented = true
        }
    }

    @MainActor
    private func confirmQuitWhileRunning() {
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
    private func requestMenuStop() {
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
    private func confirmMenuStop() {
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

enum AppMenuActionPolicy {
    static func dryRunAvailable(
        sessionMode: NativeAppShellSessionMode,
        planIsConfigured: Bool,
        isRunning: Bool
    ) -> Bool {
        AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: sessionMode)
            && planIsConfigured
            && !isRunning
    }

    static func startAvailable(
        sessionMode: NativeAppShellSessionMode,
        planIsConfigured: Bool,
        isRunning: Bool,
        armedForExecution: Bool,
        lastValidationResult: AppValidationResult,
        hasValidatedRuntimeEvidence: Bool
    ) -> Bool {
        AppTransportStartPolicy.canStart(
            armedForExecution: armedForExecution,
            dryRunAvailable: dryRunAvailable(
                sessionMode: sessionMode,
                planIsConfigured: planIsConfigured,
                isRunning: isRunning
            ),
            lastValidationResult: lastValidationResult,
            hasValidatedRuntimeEvidence: hasValidatedRuntimeEvidence
        )
    }

    static func armDisabled(
        sessionMode: NativeAppShellSessionMode,
        isRunning: Bool
    ) -> Bool {
        AppRuntimeInputLock.mutatingInputsLocked(isRunning: isRunning)
            || !AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: sessionMode)
    }
}

enum AppQuitGuardPolicy {
    static func requiresConfirmation(isRunning: Bool, allowNextTerminate: Bool) -> Bool {
        isRunning && !allowNextTerminate
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
            // Native SwiftUI shell has no WKWebView and no NavigationStack reload owner, so Command-R remains refresh.
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
