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
                            refreshHelp: inputsLocked ? AppRuntimeInputLock.lockedHelp : "Refresh local media inventory",
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

                    Divider().padding(.vertical, AppSpacing.xxs)

                    AppVideoDeviceSelectionSection(
                        devices: operatorSurface.inventory.videoDevices,
                        selectedID: operatorSurface.inventory.selection.videoDeviceID
                    ) { uniqueID in
                        operatorSurface.inventory.selection.videoDeviceID = uniqueID
                    }
                    .disabled(inputsLocked)
                }
                .frame(minWidth: 340, maxWidth: 560, alignment: .leading)
                .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "")
            }

            if operatorSurface.sessionMode == .directMacPeer {
                DesignPanel(title: "Remote media inventory", systemImage: "network") {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        MetricsGrid {
                            TextField("Remote host label", text: $operatorSurface.remoteInventory.hostName)
                                .disabled(AppRemoteInventoryEditPolicy.fieldsDisabled(inputsLocked: inputsLocked))
                                .help(AppRemoteInventoryEditPolicy.help(inputsLocked: inputsLocked))
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

                        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: AppSpacing.s, verticalSpacing: AppSpacing.xs) {
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
            } else {
                AppWorkflowUnavailableView(sessionMode: operatorSurface.sessionMode)
            }
            AppCommandIntentView(operatorSurface: $operatorSurface, inputsLocked: inputsLocked)
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

struct AppDeviceSetupRecoverySummary: Equatable {
    let title: String
    let messages: [String]
}

enum AppDeviceSetupRecoveryPolicy {
    static func summary(for inventory: NativeAppShellLocalMediaInventory) -> AppDeviceSetupRecoverySummary? {
        var messages: [String] = []
        if inventory.audioDevices.filter(\.supportsInput).isEmpty {
            messages.append("No audio input devices found. Connect an input device or check Microphone permission, then refresh inventory.")
        }
        if inventory.audioDevices.filter(\.supportsOutput).isEmpty {
            messages.append("No audio output devices found. Connect an output device, then refresh inventory.")
        }
        if inventory.videoDevices.isEmpty {
            messages.append("No video devices found. Connect a camera or check Camera permission, then refresh inventory.")
        }
        if !inventory.inventoryErrors.isEmpty {
            messages.append("Inventory refresh reported warnings. Open Diagnostics for source readiness context if refresh does not resolve them.")
        }
        guard !messages.isEmpty else {
            return nil
        }
        messages.append("macOS permissions are changed outside the app in System Settings > Privacy & Security.")
        return AppDeviceSetupRecoverySummary(title: "Setup recovery", messages: messages)
    }
}

private struct AppDeviceSetupRecoveryPanel: View {
    let summary: AppDeviceSetupRecoverySummary
    let refreshDisabled: Bool
    let refreshHelp: String
    let onRefreshInventory: () -> Void
    let onOpenDiagnostics: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(summary.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(summary.messages, id: \.self) { message in
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Refresh Inventory", action: onRefreshInventory)
                    .disabled(refreshDisabled)
                    .help(refreshHelp)
                Button("Open Diagnostics", action: onOpenDiagnostics)
            }
        }
        .padding(.top, AppSpacing.xs)
    }
}

enum AppRemoteInventoryEditPolicy {
    static func fieldsDisabled(inputsLocked: Bool) -> Bool {
        inputsLocked
    }

    static func help(inputsLocked: Bool) -> String {
        inputsLocked ? AppRuntimeInputLock.lockedHelp : ""
    }
}

private struct AppWorkflowModeSelectorView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let appSettings: AppSettings
    let inputsLocked: Bool

    var body: some View {
        DesignPanel(title: "Workflow", systemImage: "arrow.triangle.branch") {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Picker("Mode", selection: sessionModeBinding) {
                    ForEach(NativeAppShellSessionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(inputsLocked)

                Picker("Controls", selection: controlModeBinding) {
                    ForEach(NativeAppShellControlMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(inputsLocked)

                Text(operatorSurface.sessionMode.appModeSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "")
    }

    private var sessionModeBinding: Binding<NativeAppShellSessionMode> {
        Binding(
            get: { operatorSurface.sessionMode },
            set: {
                operatorSurface.sessionMode = $0
                appSettings.sessionMode = $0.rawValue
            }
        )
    }

    private var controlModeBinding: Binding<NativeAppShellControlMode> {
        Binding(
            get: { operatorSurface.controlMode },
            set: {
                operatorSurface.controlMode = $0
                appSettings.controlMode = $0.rawValue
            }
        )
    }
}

private struct AppNormalMacToMacConnectionFieldsView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let appSettings: AppSettings

    var body: some View {
        DesignPanel(title: "Mac-to-Mac connection", systemImage: "macpro.gen3.server") {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: AppSpacing.s, verticalSpacing: AppSpacing.xs) {
                GridRow {
                    TextField("Local peer", text: textBinding(\.localPeer, storage: \.localPeer))
                    TextField("Remote peer", text: textBinding(\.remotePeer, storage: \.remotePeer))
                }
                GridRow {
                    TextField("Remote host", text: textBinding(\.remoteHost, storage: \.remoteHost))
                        .gridCellColumns(2)
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
        }
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
}

private struct AppWindowsLoLaConnectionFieldsView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let appSettings: AppSettings

    private var advanced: Bool {
        operatorSurface.controlMode == .advanced
    }

    var body: some View {
        DesignPanel(title: "LoLa connection", systemImage: "antenna.radiowaves.left.and.right") {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: AppSpacing.s, verticalSpacing: AppSpacing.xs) {
                GridRow {
                    TextField("Local host", text: textBinding(\.localHost, storage: \.windowsLoLaLocalHost))
                    TextField("Windows host", text: textBinding(\.windowsHost, storage: \.windowsLoLaWindowsHost))
                }
                if advanced {
                    GridRow {
                        UInt16Field("Control port", value: uint16Binding(\.controlPort, storage: \.windowsLoLaControlPort))
                        UInt16Field("Audio port", value: uint16Binding(\.audioPort, storage: \.windowsLoLaAudioPort))
                    }
                    GridRow {
                        UInt16Field("Video port", value: uint16Binding(\.videoPort, storage: \.windowsLoLaVideoPort))
                        IntField("Duration", value: intBinding(\.durationSeconds, storage: \.windowsLoLaDuration))
                    }
                    GridRow {
                        Picker("Payload", selection: payloadBinding) {
                            Text("Generated").tag(LoLaVideoPayloadKind.generated)
                            Text("AVFoundation MJPEG").tag(LoLaVideoPayloadKind.avFoundationMjpeg)
                            Text("AVFoundation Raw 8").tag(LoLaVideoPayloadKind.avFoundationRaw8)
                            Text("AVFoundation JPEG XS").tag(LoLaVideoPayloadKind.avFoundationJpegXS)
                        }
                        .gridCellColumns(2)
                    }
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
        }
    }

    private func textBinding(
        _ keyPath: WritableKeyPath<NativeAppShellWindowsLoLaPeerFields, String>,
        storage: ReferenceWritableKeyPath<AppSettings, String>
    ) -> Binding<String> {
        Binding(
            get: { operatorSurface.windowsLoLaPeerFields[keyPath: keyPath] },
            set: {
                operatorSurface.windowsLoLaPeerFields[keyPath: keyPath] = $0
                appSettings[keyPath: storage] = $0
            }
        )
    }

    private func uint16Binding(
        _ keyPath: WritableKeyPath<NativeAppShellWindowsLoLaPeerFields, UInt16>,
        storage: ReferenceWritableKeyPath<AppSettings, Int>
    ) -> Binding<UInt16> {
        Binding(
            get: { operatorSurface.windowsLoLaPeerFields[keyPath: keyPath] },
            set: {
                operatorSurface.windowsLoLaPeerFields[keyPath: keyPath] = $0
                appSettings[keyPath: storage] = Int($0)
            }
        )
    }

    private func intBinding(
        _ keyPath: WritableKeyPath<NativeAppShellWindowsLoLaPeerFields, Int>,
        storage: ReferenceWritableKeyPath<AppSettings, Int>
    ) -> Binding<Int> {
        Binding(
            get: { operatorSurface.windowsLoLaPeerFields[keyPath: keyPath] },
            set: {
                let value = max(1, $0)
                operatorSurface.windowsLoLaPeerFields[keyPath: keyPath] = value
                appSettings[keyPath: storage] = value
            }
        )
    }

    private var payloadBinding: Binding<LoLaVideoPayloadKind> {
        Binding(
            get: { operatorSurface.windowsLoLaPeerFields.payloadMode },
            set: {
                operatorSurface.windowsLoLaPeerFields.payloadMode = $0
                appSettings.windowsLoLaPayloadMode = $0.rawValue
            }
        )
    }
}

struct AppWorkflowUnavailableView: View {
    let sessionMode: NativeAppShellSessionMode

    var body: some View {
        AppWarningBanner(
            title: "\(sessionMode.displayName) unavailable",
            message: "This mode is not available yet. Switch to a supported workflow in Settings to continue."
        )
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
        DesignPanel(title: "Peer network fields", systemImage: "network.badge.shield.half.filled") {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Picker("Role", selection: roleBinding) {
                    Text("Initiator").tag(DirectPeerSessionManualRole.initiator)
                    Text("Responder").tag(DirectPeerSessionManualRole.responder)
                }
                .pickerStyle(.segmented)

                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: AppSpacing.s, verticalSpacing: AppSpacing.xs) {
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
    let inputsLocked: Bool

    private var planIsConfigured: Bool {
        AppOperatorPrototypePlan.make(operatorSurface: operatorSurface).isConfigured
    }

    var body: some View {
        GroupBox("Command Intent") {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                MetricsGrid {
                    LabeledContent("Intent", value: operatorSurface.commandIntent.rawValue)
                    LabeledContent("Remote orchestration", value: yesNo(operatorSurface.remoteOrchestrationEnabled))
                    LabeledContent("Long-running process", value: yesNo(operatorSurface.startsLongRunningProcess))
                }
                HStack {
                    Button(AppCommandIntentControlPolicy.title(for: .handoffRequested)) {
                        operatorSurface.commandIntent = .handoffRequested
                    }
                        .disabled(!planIsConfigured || inputsLocked)
                        .help(AppCommandIntentControlPolicy.help(for: .handoffRequested, inputsLocked: inputsLocked))
                    Button(AppCommandIntentControlPolicy.title(for: .startRequested)) {
                        operatorSurface.commandIntent = .startRequested
                    }
                        .disabled(!planIsConfigured || inputsLocked)
                        .help(AppCommandIntentControlPolicy.help(for: .startRequested, inputsLocked: inputsLocked))
                    Button(AppCommandIntentControlPolicy.title(for: .runRequested)) {
                        operatorSurface.commandIntent = .runRequested
                    }
                        .disabled(!planIsConfigured || inputsLocked)
                        .help(AppCommandIntentControlPolicy.help(for: .runRequested, inputsLocked: inputsLocked))
                    Button(AppCommandIntentControlPolicy.title(for: .stopRequested)) {
                        operatorSurface.commandIntent = .stopRequested
                    }
                    .disabled(AppCommandIntentControlPolicy.stopIntentDisabled(inputsLocked: inputsLocked))
                    .help(AppCommandIntentControlPolicy.help(for: .stopRequested, inputsLocked: inputsLocked))
                    Button(AppCommandIntentControlPolicy.title(for: .idle)) { operatorSurface.commandIntent = .idle }
                        .disabled(inputsLocked)
                        .help(AppCommandIntentControlPolicy.help(for: .idle, inputsLocked: inputsLocked))
                }
                .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "")
            }
        }
    }
}

enum AppCommandIntentControlPolicy {
    static let stopIntentTitle = "Mark Stop Intent"

    static func title(for intent: NativeAppShellOperatorCommandIntent) -> String {
        switch intent {
        case .idle:
            return "Clear Command Intent"
        case .handoffRequested:
            return "Mark Handoff Intent"
        case .startRequested:
            return "Mark Start Intent"
        case .runRequested:
            return "Mark Run Intent"
        case .stopRequested:
            return stopIntentTitle
        }
    }

    static func help(
        for intent: NativeAppShellOperatorCommandIntent,
        inputsLocked: Bool
    ) -> String {
        if inputsLocked {
            return intent == .stopRequested
                ? "Use the transport Stop control to stop the active process."
                : AppRuntimeInputLock.lockedHelp
        }
        switch intent {
        case .idle:
            return "Clear command intent metadata."
        case .handoffRequested:
            return "Record handoff intent metadata without launching a process."
        case .startRequested:
            return "Record start-requested intent metadata without starting a process."
        case .runRequested:
            return "Record run-requested intent metadata without starting a process."
        case .stopRequested:
            return "Record stop-requested intent metadata without stopping a process."
        }
    }

    static func stopIntentDisabled(inputsLocked: Bool) -> Bool {
        inputsLocked
    }

    static func stopIntentHelp(inputsLocked: Bool) -> String {
        help(for: .stopRequested, inputsLocked: inputsLocked)
    }
}
