// Renders AppLocalOperatorSurfaceView in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import OpenLolaCore
import SwiftUI

struct AppLocalOperatorSurfaceView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let inventoryController: AppLocalOperatorInventoryController
    let appSettings: AppSettings
    let inputsLocked: Bool
    let onOpenDiagnostics: () -> Void

    var body: some View {
        Group {
            AppWorkflowModeSelectorView(
                operatorSurface: $operatorSurface,
                appSettings: appSettings,
                inputsLocked: inputsLocked
            )

            AppSetupReadinessView(operatorSurface: operatorSurface)

            DesignPanel(title: "Local media inventory", systemImage: "hifispeaker.2") {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    MetricsGrid {
                        LabeledContent("Captured", value: operatorSurface.inventory.capturedAt)
                        AppReadableMetric(label: "Host", value: operatorSurface.inventory.hostName)
                        LabeledContent("Audio devices", value: "\(operatorSurface.inventory.audioDevices.count)")
                        LabeledContent("Video devices", value: "\(operatorSurface.inventory.videoDevices.count)")
                    }

                    if !operatorSurface.inventory.inventoryErrors.isEmpty {
                        AppWarningBanner(
                            title: "Inventory Warnings",
                            messages: operatorSurface.inventory.inventoryErrors
                        )
                    }

                    Button(action: refreshInventory) {
                        HStack(spacing: AppSpacing.xs) {
                            if inventoryController.isRefreshingInventory {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Refresh Inventory")
                        }
                    }
                    .disabled(inventoryController.isRefreshingInventory || inputsLocked)
                    .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "Refresh local media inventory")

                    if let recovery = AppDeviceSetupRecoveryPolicy.summary(for: operatorSurface.inventory) {
                        AppDeviceSetupRecoveryPanel(
                            summary: recovery,
                            refreshDisabled: inventoryController.isRefreshingInventory || inputsLocked,
                            refreshHelp: inputsLocked
                                ? AppRuntimeInputLock.lockedHelp
                                : "Refresh local media inventory",
                            onRefreshInventory: refreshInventory,
                            onOpenDiagnostics: onOpenDiagnostics
                        )
                    }
                }
            }

            DesignPanel(title: "Local selection", systemImage: "checkmark.circle") {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    AppAudioDeviceSelectionSection(
                        title: "Audio Input",
                        emptyMessage: "No audio input devices found.",
                        devices: operatorSurface.inventory.audioDevices.filter(\.supportsInput),
                        selectedUID: operatorSurface.inventory.selection.audioInputUID,
                        supportsInput: true,
                        supportsOutput: false
                    ) { uid in
                        operatorSurface.inventory.selection.audioInputUID = uid
                    }
                    .disabled(inputsLocked)

                    Divider().padding(.vertical, AppSpacing.xxs)

                    AppAudioDeviceSelectionSection(
                        title: "Audio Output",
                        emptyMessage: "No audio output devices found.",
                        devices: operatorSurface.inventory.audioDevices.filter(\.supportsOutput),
                        selectedUID: operatorSurface.inventory.selection.audioOutputUID,
                        supportsInput: false,
                        supportsOutput: true
                    ) { uid in
                        operatorSurface.inventory.selection.audioOutputUID = uid
                    }
                    .disabled(inputsLocked)

                    DisclosureGroup("Optional video") {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            AppVideoDeviceSelectionSection(
                                devices: operatorSurface.inventory.videoDevices,
                                selectedID: operatorSurface.inventory.selection.videoDeviceID
                            ) { uniqueID in
                                operatorSurface.inventory.selection.videoDeviceID = uniqueID
                            }
                            .disabled(inputsLocked)
                        }
                        .padding(.top, AppSpacing.xs)
                    }
                }
                .frame(minWidth: 340, maxWidth: 560, alignment: .leading)
                .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "")
            }

            if operatorSurface.sessionMode == .directMacPeer {
                DisclosureGroup("Remote device inventory") {
                    DesignPanel(title: "Remote media inventory", systemImage: "network") {
                        VStack(alignment: .leading, spacing: AppSpacing.s) {
                        MetricsGrid {
                            TextField("Remote host label", text: $operatorSurface.remoteInventory.hostName)
                                .disabled(AppRemoteInventoryEditPolicy.fieldsDisabled(inputsLocked: inputsLocked))
                                .help(AppRemoteInventoryEditPolicy.help(inputsLocked: inputsLocked))
                            LabeledContent("Captured", value: operatorSurface.remoteInventory.capturedAt)
                            LabeledContent(
                                "Audio devices",
                                value: "\(operatorSurface.remoteInventory.audioDevices.count)"
                            )
                            LabeledContent(
                                "Video devices",
                                value: "\(operatorSurface.remoteInventory.videoDevices.count)"
                            )
                        }

                        if !operatorSurface.remoteInventory.inventoryErrors.isEmpty {
                            AppWarningBanner(
                                title: "Remote Inventory Warnings",
                                messages: operatorSurface.remoteInventory.inventoryErrors
                            )
                        }

                        Grid(
                            alignment: .leadingFirstTextBaseline,
                            horizontalSpacing: AppSpacing.s,
                            verticalSpacing: AppSpacing.xs
                        ) {
                            GridRow {
                                TextField("Remote input UID", text: remoteSelectionBinding(\.audioInputUID))
                                TextField("Remote output UID", text: remoteSelectionBinding(\.audioOutputUID))
                            }
                            GridRow {
                                TextField("Remote video device ID", text: remoteSelectionBinding(\.videoDeviceID))
                                    .gridCellColumns(2)
                            }
                        }
                        .disabled(AppRemoteInventoryEditPolicy.fieldsDisabled(inputsLocked: inputsLocked))
                        .help(AppRemoteInventoryEditPolicy.help(inputsLocked: inputsLocked))
                        }
                        .frame(minWidth: 340, maxWidth: 680, alignment: .leading)
                    }
                    .padding(.top, AppSpacing.xs)
                }
            }

            if operatorSurface.sessionMode == .directMacPeer {
                if operatorSurface.controlMode == .advanced {
                    AppOperatorArtifactsView(
                        operatorSurface: $operatorSurface,
                        appSettings: appSettings,
                        inputsLocked: inputsLocked
                    )
                    AppPeerNetworkFieldsView(operatorSurface: $operatorSurface, appSettings: appSettings)
                        .disabled(inputsLocked)
                        .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "")
                } else {
                    AppNormalMacToMacConnectionFieldsView(
                        operatorSurface: $operatorSurface,
                        appSettings: appSettings
                    )
                    .disabled(inputsLocked)
                    .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "")
                }
            } else if operatorSurface.sessionMode == .windowsLoLa {
                AppWindowsLoLaConnectionFieldsView(
                    operatorSurface: $operatorSurface,
                    appSettings: appSettings
                )
                .disabled(inputsLocked)
                .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "")
            } else if operatorSurface.sessionMode.externalConnectorKind != nil {
                AppExternalConnectorConnectionFieldsView(
                    operatorSurface: $operatorSurface,
                    appSettings: appSettings
                )
                .disabled(inputsLocked)
                .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "")
            } else {
                AppWorkflowUnavailableView(sessionMode: operatorSurface.sessionMode)
            }
            if operatorSurface.controlMode == .advanced {
                DisclosureGroup("Command metadata") {
                    AppCommandIntentView(operatorSurface: $operatorSurface, inputsLocked: inputsLocked)
                        .padding(.top, AppSpacing.xs)
                }
            }
        }
        .appConsoleGroupBoxStyle()
        .alert(
            "Inventory Refresh Warning",
            isPresented: Binding(
                get: { inventoryController.lastRefreshWarning != nil },
                set: { isPresented in
                    if !isPresented {
                        inventoryController.lastRefreshWarning = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(inventoryController.lastRefreshWarning ?? "")
        }
    }

    private func refreshInventory() {
        inventoryController.refresh(currentSurface: operatorSurface) { nextSurface in
            operatorSurface = AppLocalOperatorInventoryRefreshMergePolicy.merge(
                current: operatorSurface,
                refreshResult: nextSurface
            )
        }
    }

    private func remoteSelectionBinding(
        _ keyPath: WritableKeyPath<NativeAppShellLocalMediaSelection, String?>
    ) -> Binding<String> {
        Binding(
            get: { normalizedRemoteSelectionText(operatorSurface.remoteInventory.selection[keyPath: keyPath]) },
            set: {
                var nextSurface = operatorSurface
                nextSurface.importRemoteInventorySelection(keyPath: keyPath, value: $0)
                operatorSurface = nextSurface
            }
        )
    }

    private func normalizedRemoteSelectionText(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
