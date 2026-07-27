// Supplies local-operator surface helpers, keeping view-specific formatting out of its primary layout.
import OpenLolaCore
import SwiftUI

struct AppSetupReadinessView: View {
    let operatorSurface: NativeAppShellOperatorPrototypeState

    var body: some View {
        let items = readinessItems
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Connection path")
                    .font(.headline)
                Spacer(minLength: AppSpacing.s)
                Text(items.allSatisfy(\.isComplete) ? "Ready to arm" : "Setup in progress")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(items.allSatisfy(\.isComplete) ? AppDesignSystem.interactionAccent : .secondary)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: AppSpacing.s)],
                alignment: .leading,
                spacing: AppSpacing.s
            ) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: AppSpacing.xs) {
                        Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isComplete ? AppDesignSystem.interactionAccent : .secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(item.title)
                                .font(.callout.weight(.semibold))
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(item.title): \(item.isComplete ? "Complete" : "Needed"). \(item.detail)"
                    )
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private var readinessItems: [AppSetupReadinessItem] {
        let selection = operatorSurface.inventory.selection
        let plan = AppOperatorPrototypePlan.make(operatorSurface: operatorSurface)
        return [
            AppSetupReadinessItem(
                id: "workflow",
                title: "1 · Workflow",
                detail: operatorSurface.sessionMode.displayName,
                isComplete: true
            ),
            AppSetupReadinessItem(
                id: "audio",
                title: "2 · Audio I/O",
                detail: hasText(selection.audioInputUID) && hasText(selection.audioOutputUID)
                    ? "Input and output selected"
                    : "Choose input and output",
                isComplete: hasText(selection.audioInputUID) && hasText(selection.audioOutputUID)
            ),
            AppSetupReadinessItem(
                id: "peer",
                title: "3 · Remote peer",
                detail: peerIsConfigured ? "Peer address configured" : "Enter the remote address",
                isComplete: peerIsConfigured
            ),
            AppSetupReadinessItem(
                id: "ready",
                title: "4 · Readiness",
                detail: plan.isConfigured ? "Route can be armed" : "Resolve remaining fields",
                isComplete: plan.isConfigured
            )
        ]
    }

    private var peerIsConfigured: Bool {
        switch operatorSurface.sessionMode {
        case .directMacPeer:
            hasText(operatorSurface.directPeerCommandFields.remoteHost)
        case .windowsLoLa:
            hasText(operatorSurface.windowsLoLaPeerFields.windowsHost)
        case .jackTrip:
            hasText(operatorSurface.jackTripPeerFields.peerHost)
        case .ultraGrid:
            hasText(operatorSurface.ultraGridPeerFields.peerHost)
        }
    }

    private func hasText(_ value: String?) -> Bool {
        !(value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}

private struct AppSetupReadinessItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let isComplete: Bool
}

struct AppDeviceSetupRecoverySummary: Equatable {
    let title: String
    let messages: [String]
}

enum AppDeviceSetupRecoveryPolicy {
    static func summary(for inventory: NativeAppShellLocalMediaInventory) -> AppDeviceSetupRecoverySummary? {
        var messages: [String] = []
        if inventory.audioDevices.filter(\.supportsInput).isEmpty {
            messages.append(
                "No audio input devices found. Connect an input device or check Microphone permission, "
                    + "then refresh inventory."
            )
        }
        if inventory.audioDevices.filter(\.supportsOutput).isEmpty {
            messages.append("No audio output devices found. Connect an output device, then refresh inventory.")
        }
        if inventory.videoDevices.isEmpty {
            messages.append(
                "No video devices found. Connect a camera or check Camera permission, then refresh inventory."
            )
        }
        if !inventory.inventoryErrors.isEmpty {
            messages.append(
                "Inventory refresh reported warnings. Open Diagnostics for source readiness context "
                    + "if refresh does not resolve them."
            )
        }
        guard !messages.isEmpty else {
            return nil
        }
        messages.append("macOS permissions are changed outside the app in System Settings > Privacy & Security.")
        return AppDeviceSetupRecoverySummary(title: "Setup recovery", messages: messages)
    }
}

struct AppDeviceSetupRecoveryPanel: View {
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

struct AppAudioDeviceSelectionSection: View {
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

struct AppVideoDeviceSelectionSection: View {
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

                AppDirectPeerConnectionGrid(
                    fields: $operatorSurface.directPeerCommandFields,
                    appSettings: appSettings
                ) {
                    GridRow {
                        TextField(
                            "Local host",
                            text: AppDirectPeerIdentityRow.textBinding(
                                fields: $operatorSurface.directPeerCommandFields,
                                appSettings: appSettings,
                                \.localHost,
                                storage: \.localHost
                            )
                        )
                        TextField(
                            "Remote host",
                            text: AppDirectPeerIdentityRow.textBinding(
                                fields: $operatorSurface.directPeerCommandFields,
                                appSettings: appSettings,
                                \.remoteHost,
                                storage: \.remoteHost
                            )
                        )
                    }
                    GridRow {
                        TextField(
                            "Output path",
                            text: AppDirectPeerIdentityRow.textBinding(
                                fields: $operatorSurface.directPeerCommandFields,
                                appSettings: appSettings,
                                \.outputPath,
                                storage: \.outputPath
                            )
                        )
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

struct AppCommandIntentView: View {
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
        .appConsoleGroupBoxStyle()
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
            return lockedHelp(for: intent)
        }
        return unlockedHelp(for: intent)
    }

    private static func lockedHelp(for intent: NativeAppShellOperatorCommandIntent) -> String {
        intent == .stopRequested
            ? "Use the transport Stop control to stop the active process."
            : AppRuntimeInputLock.lockedHelp
    }

    private static func unlockedHelp(for intent: NativeAppShellOperatorCommandIntent) -> String {
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
