// Renders AppLocalOperatorSurfaceView in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import OpenLolaCore
import SwiftUI

struct AppLocalOperatorSurfaceView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let inventoryController: AppLocalOperatorInventoryController
    let appSettings: AppSettings
    let inputsLocked: Bool
    let onOpenDiagnostics: () -> Void

    @State private var setupPage = AppDeviceSetupPage.localMedia

    var body: some View {
        Group {
            AppWorkflowModeSelectorView(
                operatorSurface: $operatorSurface,
                appSettings: appSettings,
                inputsLocked: inputsLocked
            )

            AppSetupReadinessView(operatorSurface: operatorSurface)

            Picker("Setup section", selection: $setupPage) {
                ForEach(AppDeviceSetupPage.allCases) { page in
                    Text(page.rawValue).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.vertical, AppSpacing.xs)

            switch setupPage {
            case .localMedia:
                HStack {
                    Text("Select the devices this workflow will use.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: AppSpacing.s)
                    Button(action: refreshInventory) {
                        Label("Refresh devices", systemImage: "arrow.clockwise")
                    }
                    .disabled(inventoryController.isRefreshingInventory || inputsLocked)
                    .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "Scan for local media devices")
                    if inventoryController.isRefreshingInventory {
                        ProgressView().controlSize(.small)
                    }
                }
                if !operatorSurface.inventory.inventoryErrors.isEmpty {
                    AppWarningBanner(title: "Device discovery", messages: operatorSurface.inventory.inventoryErrors)
                }
                if let recovery = AppDeviceSetupRecoveryPolicy.summary(for: operatorSurface) {
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
                localMediaSelection
                localInventory
            case .connection:
                peerConnection
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

    private var localMediaSelection: some View {
        DesignPanel(title: "Choose your media devices", systemImage: "checkmark.circle") {
            let requirements = AppRequiredDevicePolicy.requirements(for: operatorSurface)
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                if requirements.audioInput {
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
                }

                if requirements.audioInput && requirements.audioOutput {
                    Divider().padding(.vertical, AppSpacing.xxs)
                }

                if requirements.audioOutput {
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
                }

                if requirements.videoInput {
                    DisclosureGroup("Video input") {
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

                if !requirements.audioInput && !requirements.audioOutput && !requirements.videoInput {
                    Text("This workflow uses generated media or remote receive output and needs no local capture device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "")
        }

    }

    private var localInventory: some View {
        DisclosureGroup("Inventory details") {
            DesignPanel(title: "Local media inventory", systemImage: "hifispeaker.2") {
                MetricsGrid {
                    LabeledContent("Captured", value: operatorSurface.inventory.capturedAt)
                    AppReadableMetric(label: "Host", value: operatorSurface.inventory.hostName)
                    LabeledContent("Audio devices", value: "\(operatorSurface.inventory.audioDevices.count)")
                    LabeledContent("Video devices", value: "\(operatorSurface.inventory.videoDevices.count)")
                }
            }
            .padding(.top, AppSpacing.s)
        }
    }

    @ViewBuilder
    private var peerConnection: some View {
        if operatorSurface.sessionMode == .directMacPeer {
            DisclosureGroup("Remote device inventory") {
                DesignPanel(title: "Remote media inventory", systemImage: "network") {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                    MetricsGrid {
                        TextField("Remote host label", text: $operatorSurface.remoteInventory.hostName)
                            .appConnectionFieldLabel("Remote host label")
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
                                .appConnectionFieldLabel("Remote input UID")
                            TextField("Remote output UID", text: remoteSelectionBinding(\.audioOutputUID))
                                .appConnectionFieldLabel("Remote output UID")
                        }
                        GridRow {
                            TextField("Remote video device ID", text: remoteSelectionBinding(\.videoDeviceID))
                                .appConnectionFieldLabel("Remote video device ID")
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

// Local view navigation does not change the configured session or stored preferences.
private enum AppDeviceSetupPage: String, CaseIterable, Identifiable {
    case localMedia = "Media devices"
    case connection = "Peer connection"

    var id: String { rawValue }
}
