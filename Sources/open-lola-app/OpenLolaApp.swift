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
    @State private var syntheticMetricsRefreshState = AppSyntheticMetricsRefreshState.idle
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
                syntheticMetricsRefreshState: syntheticMetricsRefreshState,
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
                AppTransportStopConfirmationPolicy.quitConfirmationTitle,
                isPresented: $quitConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(
                    AppTransportStopConfirmationPolicy.quitConfirmationButtonTitle,
                    role: .destructive,
                    action: confirmQuitWhileRunning
                )
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(AppTransportStopConfirmationPolicy.quitConfirmationMessage)
            }
            .confirmationDialog(
                AppTransportStopConfirmationPolicy.stopConfirmationTitle,
                isPresented: $stopConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(
                    AppTransportStopConfirmationPolicy.stopConfirmationButtonTitle,
                    role: .destructive,
                    action: confirmMenuStop
                )
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(AppTransportStopConfirmationPolicy.stopConfirmationMessage)
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
        if AppMenuActionHandling.handledActionIDs.contains(action.id) {
            switch action.id {
            case "refresh-synthetic-metrics":
                menuButton(action) { refreshSyntheticMetrics() }
            case "refresh-local-media-inventory":
                menuButton(action) { refreshInventory() }
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
            case "start-armed-supervisor":
                let reason = AppMenuActionPolicy.startDisabledReason(
                    sessionMode: operatorSurface.sessionMode,
                    planIsConfigured: operatorPlanIsConfigured,
                    isRunning: executionController.isRunning,
                    armedForExecution: executionController.armedForExecution,
                    lastValidationResult: executionController.lastValidationResult,
                    hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence
                )
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
            case "open-local-preview-window":
                menuButton(action, help: AppPreviewWindowRequestFeedback.menuHelp) {
                    previewState.receiverStatus = AppPreviewWindowRequestFeedback.statusMessage
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
        help: String? = nil,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action.title, action: perform)
            .disabled(disabled)
            .help(help ?? action.title)
            .modifier(AppMenuKeyboardShortcut(shortcut: action.keyboardShortcut))
    }

    private func refreshInventory() {
        inventoryController.refresh(currentSurface: operatorSurface) { nextSurface in
            operatorSurface = AppLocalOperatorInventoryRefreshMergePolicy.merge(
                current: operatorSurface,
                refreshResult: nextSurface
            )
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
        guard !syntheticMetricsRefreshState.isRefreshing else {
            return
        }
        syntheticMetricsRefreshState = .refreshing
        report = await Task.detached {
            NativeAppShellSyntheticSmoke.run()
        }.value
        syntheticMetricsRefreshState = .refreshed
    }

    private var operatorPlanIsConfigured: Bool {
        AppOperatorPrototypePlan.make(operatorSurface: operatorSurface).isConfigured
    }

    @MainActor
    private func installQuitGuard() {
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
    static func writePlanDisabledReason(
        sessionMode: NativeAppShellSessionMode,
        isRunning: Bool
    ) -> String? {
        if isRunning {
            return AppRuntimeInputLock.lockedHelp
        }
        if sessionMode != .directMacPeer {
            return "Switch to Direct Mac Peer mode to write a two-peer plan."
        }
        return nil
    }

    static func dryRunAvailable(
        sessionMode: NativeAppShellSessionMode,
        planIsConfigured: Bool,
        isRunning: Bool
    ) -> Bool {
        AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: sessionMode)
            && planIsConfigured
            && !isRunning
    }

    static func dryRunDisabledReason(
        sessionMode: NativeAppShellSessionMode,
        planIsConfigured: Bool,
        isRunning: Bool
    ) -> String? {
        if isRunning {
            return "Stop or let the current run complete before dry running again."
        }
        if !AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: sessionMode) {
            return "Switch to a supported workflow in Settings to dry run."
        }
        if !planIsConfigured {
            return "Configure local and remote session fields before dry run."
        }
        return nil
    }

    static func handoffIntentDisabledReason(
        planIsConfigured: Bool,
        isRunning: Bool
    ) -> String? {
        if isRunning {
            return AppRuntimeInputLock.lockedHelp
        }
        if !planIsConfigured {
            return "Configure local and remote session fields before setting handoff intent."
        }
        return nil
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

    static func startDisabledReason(
        sessionMode: NativeAppShellSessionMode,
        planIsConfigured: Bool,
        isRunning: Bool,
        armedForExecution: Bool,
        lastValidationResult: AppValidationResult,
        hasValidatedRuntimeEvidence: Bool
    ) -> String? {
        if isRunning {
            return "Stop or let the current run complete before starting another run."
        }
        if !AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: sessionMode) {
            return "Switch to a supported workflow in Settings before starting."
        }
        if !planIsConfigured {
            return "Configure local and remote session fields before starting."
        }
        if !armedForExecution {
            return "Arm execution before starting."
        }
        if lastValidationResult != .passed || !hasValidatedRuntimeEvidence {
            return "Run a passing validation with current runtime evidence before starting."
        }
        return nil
    }

    static func stopDisabledReason(isRunning: Bool) -> String? {
        isRunning ? nil : "No supervisor run is active."
    }

    static func validateDisabledReason(validationUnavailableMessage: String?) -> String? {
        validationUnavailableMessage
    }

    static func armDisabled(
        sessionMode: NativeAppShellSessionMode,
        isRunning: Bool
    ) -> Bool {
        AppRuntimeInputLock.mutatingInputsLocked(isRunning: isRunning)
            || !AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: sessionMode)
    }

    static func armDisabledReason(
        sessionMode: NativeAppShellSessionMode,
        isRunning: Bool
    ) -> String? {
        if AppRuntimeInputLock.mutatingInputsLocked(isRunning: isRunning) {
            return AppRuntimeInputLock.lockedHelp
        }
        if !AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: sessionMode) {
            return "Switch to a supported workflow in Settings to arm execution."
        }
        return nil
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
