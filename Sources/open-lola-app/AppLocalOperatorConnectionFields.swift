import OpenLolaCore
import SwiftUI

struct AppWorkflowModeSelectorView: View {
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

struct AppNormalMacToMacConnectionFieldsView: View {
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

struct AppWindowsLoLaConnectionFieldsView: View {
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

struct AppExternalConnectorConnectionFieldsView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let appSettings: AppSettings

    private var advanced: Bool {
        operatorSurface.controlMode == .advanced
    }

    private var isUltraGrid: Bool {
        operatorSurface.sessionMode == .ultraGrid
    }

    var body: some View {
        DesignPanel(title: "\(operatorSurface.sessionMode.displayName) connection", systemImage: "antenna.radiowaves.left.and.right") {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: AppSpacing.s, verticalSpacing: AppSpacing.xs) {
                GridRow {
                    TextField("Local host", text: textBinding(\.localHost))
                    TextField("Peer host", text: textBinding(\.peerHost))
                }
                if advanced {
                    GridRow {
                        UInt16Field("Audio port", value: uint16Binding(\.audioPort))
                        UInt16Field("Video port", value: uint16Binding(\.videoPort))
                    }
                    GridRow {
                        UInt16Field("Peer audio port", value: uint16Binding(\.peerAudioPort))
                        IntField("Duration", value: intBinding(\.durationSeconds))
                    }
                    if isUltraGrid {
                        GridRow {
                            Picker("Media", selection: mediaBinding) {
                                Text("Audio + Video").tag(ExternalConnectorMediaMode.audioVideo)
                                Text("Audio").tag(ExternalConnectorMediaMode.audio)
                            }
                            .gridCellColumns(2)
                        }
                    }
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
        }
    }

    private func textBinding(
        _ keyPath: WritableKeyPath<NativeAppShellExternalConnectorPeerFields, String>
    ) -> Binding<String> {
        Binding(
            get: { currentFields[keyPath: keyPath] },
            set: { value in
                if operatorSurface.sessionMode == .jackTrip {
                    operatorSurface.jackTripPeerFields[keyPath: keyPath] = value
                } else {
                    operatorSurface.ultraGridPeerFields[keyPath: keyPath] = value
                }
                updateStringSetting(keyPath, value: value)
            }
        )
    }

    private func uint16Binding(
        _ keyPath: WritableKeyPath<NativeAppShellExternalConnectorPeerFields, UInt16>
    ) -> Binding<UInt16> {
        Binding(
            get: { currentFields[keyPath: keyPath] },
            set: { value in
                if operatorSurface.sessionMode == .jackTrip {
                    operatorSurface.jackTripPeerFields[keyPath: keyPath] = value
                } else {
                    operatorSurface.ultraGridPeerFields[keyPath: keyPath] = value
                }
                updateIntSetting(keyPath, value: Int(value))
            }
        )
    }

    private func intBinding(
        _ keyPath: WritableKeyPath<NativeAppShellExternalConnectorPeerFields, Int>
    ) -> Binding<Int> {
        Binding(
            get: { currentFields[keyPath: keyPath] },
            set: { newValue in
                let value = max(1, newValue)
                if operatorSurface.sessionMode == .jackTrip {
                    operatorSurface.jackTripPeerFields[keyPath: keyPath] = value
                } else {
                    operatorSurface.ultraGridPeerFields[keyPath: keyPath] = value
                }
                updateIntSetting(keyPath, value: value)
            }
        )
    }

    private var mediaBinding: Binding<ExternalConnectorMediaMode> {
        Binding(
            get: { currentFields.mediaMode },
            set: { value in
                if operatorSurface.sessionMode == .jackTrip {
                    operatorSurface.jackTripPeerFields.mediaMode = .audio
                } else {
                    operatorSurface.ultraGridPeerFields.mediaMode = value
                }
                if operatorSurface.sessionMode == .ultraGrid {
                    appSettings.ultraGridMediaMode = value.rawValue
                } else {
                    appSettings.jackTripMediaMode = ExternalConnectorMediaMode.audio.rawValue
                }
            }
        )
    }

    private var currentFields: NativeAppShellExternalConnectorPeerFields {
        operatorSurface.sessionMode == .jackTrip
            ? operatorSurface.jackTripPeerFields
            : operatorSurface.ultraGridPeerFields
    }

    private func updateStringSetting(
        _ keyPath: WritableKeyPath<NativeAppShellExternalConnectorPeerFields, String>,
        value: String
    ) {
        if operatorSurface.sessionMode == .jackTrip {
            if keyPath == \NativeAppShellExternalConnectorPeerFields.localHost {
                appSettings.jackTripLocalHost = value
            } else if keyPath == \NativeAppShellExternalConnectorPeerFields.peerHost {
                appSettings.jackTripPeerHost = value
            } else if keyPath == \NativeAppShellExternalConnectorPeerFields.outputPath {
                appSettings.jackTripOutputPath = value
            }
        } else {
            if keyPath == \NativeAppShellExternalConnectorPeerFields.localHost {
                appSettings.ultraGridLocalHost = value
            } else if keyPath == \NativeAppShellExternalConnectorPeerFields.peerHost {
                appSettings.ultraGridPeerHost = value
            } else if keyPath == \NativeAppShellExternalConnectorPeerFields.outputPath {
                appSettings.ultraGridOutputPath = value
            }
        }
    }

    private func updateIntSetting(
        _ keyPath: WritableKeyPath<NativeAppShellExternalConnectorPeerFields, UInt16>,
        value: Int
    ) {
        if operatorSurface.sessionMode == .jackTrip {
            if keyPath == \NativeAppShellExternalConnectorPeerFields.audioPort {
                appSettings.jackTripAudioPort = value
            } else if keyPath == \NativeAppShellExternalConnectorPeerFields.peerAudioPort {
                appSettings.jackTripPeerAudioPort = value
            } else if keyPath == \NativeAppShellExternalConnectorPeerFields.videoPort {
                appSettings.jackTripVideoPort = value
            }
        } else {
            if keyPath == \NativeAppShellExternalConnectorPeerFields.audioPort {
                appSettings.ultraGridAudioPort = value
            } else if keyPath == \NativeAppShellExternalConnectorPeerFields.peerAudioPort {
                appSettings.ultraGridPeerAudioPort = value
            } else if keyPath == \NativeAppShellExternalConnectorPeerFields.videoPort {
                appSettings.ultraGridVideoPort = value
            }
        }
    }

    private func updateIntSetting(
        _ keyPath: WritableKeyPath<NativeAppShellExternalConnectorPeerFields, Int>,
        value: Int
    ) {
        if operatorSurface.sessionMode == .jackTrip,
           keyPath == \NativeAppShellExternalConnectorPeerFields.durationSeconds {
            appSettings.jackTripDuration = value
        } else if operatorSurface.sessionMode == .ultraGrid,
                  keyPath == \NativeAppShellExternalConnectorPeerFields.durationSeconds {
            appSettings.ultraGridDuration = value
        }
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
