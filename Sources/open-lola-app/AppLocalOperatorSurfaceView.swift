import OpenLolaCore
import SwiftUI

struct AppLocalOperatorSurfaceView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let inventoryController: AppLocalOperatorInventoryController
    let appSettings: AppSettings

    var body: some View {
        Group {
            GroupBox("Local Media Inventory") {
                VStack(alignment: .leading, spacing: 12) {
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
                        HStack(spacing: 8) {
                            if inventoryController.isRefreshingInventory {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Refresh Inventory")
                        }
                    }
                    .disabled(inventoryController.isRefreshingInventory)
                }
            }

            GroupBox("Local Selection") {
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

                    Divider().padding(.vertical, AppSpacing.xxs)

                    AppVideoDeviceSelectionSection(
                        devices: operatorSurface.inventory.videoDevices,
                        selectedID: operatorSurface.inventory.selection.videoDeviceID
                    ) { uniqueID in
                        operatorSurface.inventory.selection.videoDeviceID = uniqueID
                    }
                }
                .frame(minWidth: 340, maxWidth: 560, alignment: .leading)
            }

            if operatorSurface.sessionMode == .directMacPeer {
                GroupBox("Remote Media Inventory") {
                    VStack(alignment: .leading, spacing: 12) {
                        MetricsGrid {
                            TextField("Remote host label", text: $operatorSurface.remoteInventory.hostName)
                            LabeledContent("Captured", value: operatorSurface.remoteInventory.capturedAt)
                            LabeledContent("Audio devices", value: "\(operatorSurface.remoteInventory.audioDevices.count)")
                            LabeledContent("Video devices", value: "\(operatorSurface.remoteInventory.videoDevices.count)")
                        }

                        if !operatorSurface.remoteInventory.inventoryErrors.isEmpty {
                            AppWarningBanner(
                                title: "Remote Inventory Warnings",
                                messages: operatorSurface.remoteInventory.inventoryErrors
                            )
                        }

                        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                            GridRow {
                                TextField("Remote input UID", text: remoteSelectionBinding(\.audioInputUID))
                                TextField("Remote output UID", text: remoteSelectionBinding(\.audioOutputUID))
                            }
                            GridRow {
                                TextField("Remote video device ID", text: remoteSelectionBinding(\.videoDeviceID))
                                    .gridCellColumns(2)
                            }
                        }
                    }
                    .frame(minWidth: 340, maxWidth: 680, alignment: .leading)
                }
            }

            if operatorSurface.sessionMode == .directMacPeer {
                AppOperatorArtifactsView(
                    operatorSurface: $operatorSurface,
                    appSettings: appSettings
                )
                AppPeerNetworkFieldsView(operatorSurface: $operatorSurface, appSettings: appSettings)
            }
            AppCommandIntentView(operatorSurface: $operatorSurface)
        }
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
            operatorSurface = nextSurface
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

private struct AppAudioDeviceSelectionSection: View {
    let title: String
    let emptyMessage: String
    let devices: [NativeAppShellAudioDeviceOption]
    let selectedUID: String?
    let supportsInput: Bool
    let supportsOutput: Bool
    let onSelect: (String) -> Void

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        ForEach(devices, id: \.uid) { device in
            AppAudioDeviceCard(
                device: device,
                supportsInput: supportsInput,
                supportsOutput: supportsOutput,
                isSelected: selectedUID == device.uid
            ) {
                onSelect(device.uid)
            }
        }
        if devices.isEmpty {
            Text(emptyMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AppVideoDeviceSelectionSection: View {
    let devices: [NativeAppShellVideoDeviceOption]
    let selectedID: String?
    let onSelect: (String) -> Void

    var body: some View {
        Text("Video")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        ForEach(devices, id: \.uniqueId) { device in
            AppVideoDeviceCard(
                device: device,
                isSelected: selectedID == device.uniqueId
            ) {
                onSelect(device.uniqueId)
            }
        }
        if devices.isEmpty {
            Text("No video devices found.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct AppPeerNetworkFieldsView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let appSettings: AppSettings

    var body: some View {
        GroupBox("Peer Network Fields") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Role", selection: roleBinding) {
                    Text("Initiator").tag(DirectPeerSessionManualRole.initiator)
                    Text("Responder").tag(DirectPeerSessionManualRole.responder)
                }
                .pickerStyle(.segmented)

                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        TextField("Local peer", text: textBinding(\.localPeer, storage: \.localPeer))
                        TextField("Remote peer", text: textBinding(\.remotePeer, storage: \.remotePeer))
                    }
                    GridRow {
                        TextField("Local host", text: textBinding(\.localHost, storage: \.localHost))
                        TextField("Remote host", text: textBinding(\.remoteHost, storage: \.remoteHost))
                    }
                    GridRow {
                        TextField("Output path", text: textBinding(\.outputPath, storage: \.outputPath))
                            .gridCellColumns(2)
                    }
                    GridRow {
                        UInt16Field("Control port", value: uint16Binding(\.controlPort, storage: \.controlPort))
                        UInt16Field(
                            "Remote control port",
                            value: uint16Binding(\.remoteControlPort, storage: \.remoteControlPort)
                        )
                    }
                    GridRow {
                        UInt16Field("Audio port", value: uint16Binding(\.audioPort, storage: \.audioPort))
                        UInt16Field("Video port", value: uint16Binding(\.videoPort, storage: \.videoPort))
                    }
                    GridRow {
                        UInt16Field("Metrics port", value: uint16Binding(\.metricsPort, storage: \.metricsPort))
                        IntField("Duration", value: intBinding(\.durationSeconds, storage: \.duration))
                    }
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
        }
    }

    private var roleBinding: Binding<DirectPeerSessionManualRole> {
        Binding(
            get: { operatorSurface.directPeerCommandFields.role },
            set: {
                operatorSurface.directPeerCommandFields.role = $0
                appSettings.role = $0.rawValue
            }
        )
    }

    private func textBinding(
        _ keyPath: WritableKeyPath<NativeAppShellDirectPeerCommandFields, String>,
        storage: ReferenceWritableKeyPath<AppSettings, String>
    ) -> Binding<String> {
        Binding(
            get: { operatorSurface.directPeerCommandFields[keyPath: keyPath] },
            set: {
                operatorSurface.directPeerCommandFields[keyPath: keyPath] = $0
                appSettings[keyPath: storage] = $0
            }
        )
    }

    private func uint16Binding(
        _ keyPath: WritableKeyPath<NativeAppShellDirectPeerCommandFields, UInt16>,
        storage: ReferenceWritableKeyPath<AppSettings, Int>
    ) -> Binding<UInt16> {
        Binding(
            get: { operatorSurface.directPeerCommandFields[keyPath: keyPath] },
            set: {
                operatorSurface.directPeerCommandFields[keyPath: keyPath] = $0
                appSettings[keyPath: storage] = Int($0)
            }
        )
    }

    private func intBinding(
        _ keyPath: WritableKeyPath<NativeAppShellDirectPeerCommandFields, Int>,
        storage: ReferenceWritableKeyPath<AppSettings, Int>
    ) -> Binding<Int> {
        Binding(
            get: { operatorSurface.directPeerCommandFields[keyPath: keyPath] },
            set: {
                let value = max(1, $0)
                operatorSurface.directPeerCommandFields[keyPath: keyPath] = value
                appSettings[keyPath: storage] = value
            }
        )
    }
}

private struct AppCommandIntentView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState

    private var planIsConfigured: Bool {
        AppOperatorPrototypePlan.make(operatorSurface: operatorSurface).isConfigured
    }

    var body: some View {
        GroupBox("Command Intent") {
            VStack(alignment: .leading, spacing: 12) {
                MetricsGrid {
                    LabeledContent("Intent", value: operatorSurface.commandIntent.rawValue)
                    LabeledContent("Remote orchestration", value: yesNo(operatorSurface.remoteOrchestrationEnabled))
                    LabeledContent("Long-running process", value: yesNo(operatorSurface.startsLongRunningProcess))
                }
                HStack {
                    Button("Intent: Handoff") { operatorSurface.commandIntent = .handoffRequested }
                        .disabled(!planIsConfigured)
                    Button("Intent: Start") { operatorSurface.commandIntent = .startRequested }
                        .disabled(!planIsConfigured)
                    Button("Intent: Run") { operatorSurface.commandIntent = .runRequested }
                        .disabled(!planIsConfigured)
                    Button("Intent: Stop") { operatorSurface.commandIntent = .stopRequested }
                    Button("Clear Intent") { operatorSurface.commandIntent = .idle }
                }
            }
        }
    }
}
