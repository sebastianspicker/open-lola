import SwiftUI

extension OpenLolaAppScene {
    @SceneBuilder
    public var body: some Scene {
        mainWindowScene
        receiverWindowScene
        settingsScene
    }

    private var mainWindowScene: some Scene {
        Window("Open LoLa", id: "main") {
            mainWindowContent
        }
        .commands {
            CommandMenu("Open LoLa") {
                ForEach(AppMenuActionHandling.renderedActions(from: surfaceContract.actions), id: \.id) { action in
                    appMenuActionButton(action)
                }
            }
        }
    }

    private var receiverWindowScene: some Scene {
        Window("Local Preview", id: "receiver") {
            AppReceiverWindowView(
                operatorSurface: $operatorSurface,
                previewState: previewState,
                executionPhase: executionController.phase
            )
        }
        .defaultSize(width: 920, height: 680)
    }

    private var settingsScene: some Scene {
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

    private var mainWindowContent: some View {
        AppShellRootView(
            report: report,
            operatorSurface: $operatorSurface,
            dependencies: AppShellRootDependencies(
                executionController: executionController,
                previewState: previewState,
                inventoryController: inventoryController,
                appSettings: appSettings,
                contract: surfaceContract,
                syntheticMetricsRefreshState: syntheticMetricsRefreshState,
                refreshReport: refreshSyntheticMetrics,
                refreshInventory: refreshInventory
            )
        )
        .onChange(of: scenePhase) { _, phase in
            Task { @MainActor in
                handleScenePhaseChange(phase)
            }
        }
        .task { await refreshSyntheticMetricsAsync() }
        .task { refreshInventory() }
        .onAppear(perform: installQuitGuard)
        .modifier(
            AppQuitConfirmationDialog(
                isPresented: $quitConfirmationPresented,
                confirmQuit: confirmQuitWhileRunning
            )
        )
        .modifier(
            AppMenuStopConfirmationDialog(
                isPresented: $stopConfirmationPresented,
                confirmStop: confirmMenuStop
            )
        )
    }
}

private struct AppQuitConfirmationDialog: ViewModifier {
    @Binding var isPresented: Bool
    let confirmQuit: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            AppTransportStopConfirmationPolicy.quitConfirmationTitle,
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            Button(
                AppTransportStopConfirmationPolicy.quitConfirmationButtonTitle,
                role: .destructive,
                action: confirmQuit
            )
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(AppTransportStopConfirmationPolicy.quitConfirmationMessage)
        }
    }
}

private struct AppMenuStopConfirmationDialog: ViewModifier {
    @Binding var isPresented: Bool
    let confirmStop: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            AppTransportStopConfirmationPolicy.stopConfirmationTitle,
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            Button(
                AppTransportStopConfirmationPolicy.stopConfirmationButtonTitle,
                role: .destructive,
                action: confirmStop
            )
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(AppTransportStopConfirmationPolicy.stopConfirmationMessage)
        }
    }
}
