import OpenLolaCore
import SwiftUI

struct AppShellSettingsView: View {
    let configuration: NativeAppConfigurationSnapshot
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let executionController: AppExecutionController
    let previewState: AppPreviewReceiverState
    @Bindable var appSettings: AppSettings

    var executionSettingsLocked: Bool {
        executionController.isRunning
    }

    var executionSettingsHelp: String {
        Self.executionSettingsHelp(isRunning: executionSettingsLocked)
    }

    static func executionSettingsHelp(isRunning: Bool) -> String {
        isRunning
            ? "Execution-affecting settings are locked while a process is active."
            : "Changes apply to the next generated command or validation."
    }

    var body: some View {
        let visibleTabs = AppShellSettingsTabVisibility.visibleTabs(
            sessionMode: sessionModeBinding.wrappedValue,
            controlMode: controlModeBinding.wrappedValue
        )

        TabView {
            if visibleTabs.contains(.execution) {
                AppExecutionSettingsTab(
                    sessionMode: sessionModeBinding,
                    controlMode: controlModeBinding,
                    executablePath: executableBinding,
                    planPath: executionTextBinding(\.planPath, storage: appSettingsBinding(\.planPath)),
                    supervisorReportPath: executionTextBinding(
                        \.supervisorReportPath,
                        storage: appSettingsBinding(\.supervisorReportPath)
                    ),
                    requirePreflight: preflightBinding,
                    executionMode: executionModeBinding,
                    macASSH: executionTextBinding(\.macASSH, storage: appSettingsBinding(\.executionMacASSH)),
                    macBSSH: executionTextBinding(\.macBSSH, storage: appSettingsBinding(\.executionMacBSSH)),
                    macAWorkingDirectory: executionTextBinding(
                        \.macAWorkingDirectory,
                        storage: appSettingsBinding(\.executionMacAWorkingDirectory)
                    ),
                    macBWorkingDirectory: executionTextBinding(
                        \.macBWorkingDirectory,
                        storage: appSettingsBinding(\.executionMacBWorkingDirectory)
                    ),
                    sshExecutable: executionTextBinding(\.sshExecutable, storage: appSettingsBinding(\.executionSSHExecutable)),
                    scpExecutable: executionTextBinding(\.scpExecutable, storage: appSettingsBinding(\.executionSCPExecutable))
                )
                .disabled(executionSettingsLocked)
                .help(executionSettingsHelp)
            }

            if visibleTabs.contains(.peers) {
                AppPeersSettingsTab(
                    role: roleBinding,
                    localPeer: textBinding(\.localPeer, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.localPeer)),
                    remotePeer: textBinding(\.remotePeer, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.remotePeer)),
                    localHost: textBinding(\.localHost, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.localHost)),
                    remoteHost: textBinding(\.remoteHost, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.remoteHost)),
                    controlPort: uint16Binding(\.controlPort, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.controlPort)),
                    remoteControlPort: uint16Binding(\.remoteControlPort, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.remoteControlPort)),
                    audioPort: uint16Binding(\.audioPort, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.audioPort)),
                    videoPort: uint16Binding(\.videoPort, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.videoPort)),
                    metricsPort: uint16Binding(\.metricsPort, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.metricsPort)),
                    outputPath: textBinding(\.outputPath, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.outputPath))
                )
                .disabled(executionSettingsLocked)
                .help(executionSettingsHelp)
            }

            if visibleTabs.contains(.audio) {
                AppAudioSettingsTab(
                    channelCount: positiveIntBinding(\.channelCount, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.channelCount)),
                    sampleRate: positiveIntBinding(\.sampleRateHertz, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.sampleRate)),
                    frames: positiveIntBinding(\.framesPerPacket, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.frames)),
                    duration: positiveIntBinding(\.durationSeconds, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.duration)),
                    sampleFormat: textBinding(\.sampleFormat, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.sampleFormat)),
                    audioTransport: audioTransportBinding,
                    avProfile: avProfileBinding,
                    rxBufferProfile: rxBufferProfileBinding
                )
                .disabled(executionSettingsLocked)
                .help(executionSettingsHelp)
            }

            if visibleTabs.contains(.video) {
                AppVideoSettingsTab(
                    videoWidth: positiveIntBinding(\.videoWidth, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.videoWidth)),
                    videoHeight: positiveIntBinding(\.videoHeight, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.videoHeight)),
                    videoPixelFormat: textBinding(\.videoPixelFormat, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.videoPixelFormat)),
                    videoCompression: videoCompressionBinding,
                    videoFrameRate: positiveIntBinding(\.videoFrameRate, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.videoFrameRate)),
                    videoStreamID: positiveIntBinding(\.videoStreamID, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.videoStreamID)),
                    timeoutSeconds: positiveIntBinding(\.timeoutSeconds, surface: \.directPeerCommandFields, storage: appSettingsBinding(\.timeoutSeconds)),
                    preview: previewBinding
                )
                .disabled(executionSettingsLocked)
                .help(executionSettingsHelp)
            }

            if visibleTabs.contains(.preview) {
                AppPreviewSettingsTab(
                    audioPreviewEnabled: appPreviewBinding(
                        \.audioPreviewEnabled,
                        state: previewState,
                        storage: appSettingsBinding(\.audioPreviewEnabled)
                    ),
                    videoPreviewEnabled: appPreviewBinding(
                        \.videoPreviewEnabled,
                        state: previewState,
                        storage: appSettingsBinding(\.videoPreviewEnabled)
                    ),
                    showSafeFrame: appPreviewBinding(
                        \.showSafeFrame,
                        state: previewState,
                        storage: appSettingsBinding(\.showSafeFrame)
                    ),
                    monitorGain: appPreviewBinding(
                        \.monitorGain,
                        state: previewState,
                        storage: appSettingsBinding(\.monitorGain)
                    ),
                    remoteReturnBlend: appPreviewBinding(
                        \.remoteReturnBlend,
                        state: previewState,
                        storage: appSettingsBinding(\.remoteReturnBlend)
                    ),
                    videoScale: appPreviewBinding(
                        \.videoScale,
                        state: previewState,
                        storage: appSettingsBinding(\.videoScale)
                    ),
                    visibleStreams: appPreviewIntBinding(
                        \.visibleStreams,
                        state: previewState,
                        storage: appSettingsBinding(\.visibleStreams)
                    ),
                    selectedVideoStream: appPreviewIntBinding(
                        \.selectedVideoStream,
                        state: previewState,
                        storage: appSettingsBinding(\.selectedVideoStream)
                    )
                )
            }

            if visibleTabs.contains(.windowsLoLa) {
                AppWindowsLoLaSettingsTab(
                localHost: textBinding(
                    \.localHost,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaLocalHost)
                ),
                windowsHost: textBinding(
                    \.windowsHost,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaWindowsHost)
                ),
                role: windowsLoLaRoleBinding,
                controlPort: uint16Binding(
                    \.controlPort,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaControlPort)
                ),
                audioPort: uint16Binding(
                    \.audioPort,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaAudioPort)
                ),
                videoPort: uint16Binding(
                    \.videoPort,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaVideoPort)
                ),
                mediaMode: windowsLoLaMediaModeBinding,
                payloadMode: windowsLoLaPayloadModeBinding,
                videoWidth: positiveIntBinding(
                    \.videoWidth,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaVideoWidth)
                ),
                videoHeight: positiveIntBinding(
                    \.videoHeight,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaVideoHeight)
                ),
                videoFrameRate: positiveIntBinding(
                    \.videoFrameRate,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaVideoFrameRate)
                ),
                videoBitsPerPixel: positiveIntBinding(
                    \.videoBitsPerPixel,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaVideoBitsPerPixel)
                ),
                duration: positiveIntBinding(
                    \.durationSeconds,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaDuration)
                ),
                outputPath: textBinding(
                    \.outputPath,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaOutputPath)
                ),
                sampleRate: positiveIntBinding(
                    \.sampleRateHertz,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaSampleRate)
                ),
                frames: positiveIntBinding(
                    \.framesPerPacket,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaFrames)
                ),
                channelCount: positiveIntBinding(
                    \.channelCount,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaChannelCount)
                ),
                compression: nonNegativeIntBinding(
                    \.compression,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaCompression)
                ),
                bayer: nonNegativeIntBinding(
                    \.bayer,
                    surface: \.windowsLoLaPeerFields,
                    storage: appSettingsBinding(\.windowsLoLaBayer)
                )
                )
                .disabled(executionSettingsLocked)
                .help(executionSettingsHelp)
            }

            if visibleTabs.contains(.externalConnectorNotice) {
                AppExternalConnectorNoticeTab(sessionMode: sessionModeBinding.wrappedValue)
            }

            if visibleTabs.contains(.snapshot) {
                AppSnapshotSettingsTab(configuration: configuration)
            }
        }
        .frame(
            minWidth: AppWindowSize.settingsMinWidth,
            idealWidth: AppWindowSize.settingsWidth,
            maxWidth: AppWindowSize.settingsMaxWidth
        )
        .scenePadding()
    }

    private var executableBinding: Binding<String> {
        Binding(
            get: { appSettings.executablePath },
            set: {
                appSettings.executablePath = $0
                operatorSurface.directPeerCommandFields.executablePath = $0
                operatorSurface.windowsLoLaPeerFields.executablePath = $0
            }
        )
    }

    private var sessionModeBinding: Binding<NativeAppShellSessionMode> {
        Binding(
            get: { NativeAppShellSessionMode(rawValue: appSettings.sessionMode) ?? .directMacPeer },
            set: {
                appSettings.sessionMode = $0.rawValue
                operatorSurface.sessionMode = $0
            }
        )
    }

    private var controlModeBinding: Binding<NativeAppShellControlMode> {
        Binding(
            get: { NativeAppShellControlMode(rawValue: appSettings.controlMode) ?? .normal },
            set: {
                appSettings.controlMode = $0.rawValue
                operatorSurface.controlMode = $0
            }
        )
    }

    private var executionModeBinding: Binding<DirectPeerTwoPeerRunExecutionMode> {
        Binding(
            get: { DirectPeerTwoPeerRunExecutionMode(rawValue: appSettings.executionMode) ?? .local },
            set: {
                appSettings.executionMode = $0.rawValue
                executionController.settings.executionMode = $0
            }
        )
    }

    private var preflightBinding: Binding<Bool> {
        Binding(
            get: { appSettings.requirePreflight },
            set: {
                appSettings.requirePreflight = $0
                executionController.settings.requirePreflight = $0
            }
        )
    }

    private var roleBinding: Binding<DirectPeerSessionManualRole> {
        Binding(
            get: { DirectPeerSessionManualRole(rawValue: appSettings.role) ?? .initiator },
            set: {
                appSettings.role = $0.rawValue
                operatorSurface.directPeerCommandFields.role = $0
            }
        )
    }

    private var avProfileBinding: Binding<DirectPeerSessionAVProfile> {
        Binding(
            get: { DirectPeerSessionAVProfile(rawValue: appSettings.avProfile) ?? .fastest },
            set: {
                appSettings.avProfile = $0.rawValue
                operatorSurface.directPeerCommandFields.avProfile = $0
                let defaultRx = $0.defaultRXBufferProfile
                appSettings.rxBufferProfile = defaultRx.rawValue
                operatorSurface.directPeerCommandFields.rxBufferProfile = defaultRx
            }
        )
    }

    private var rxBufferProfileBinding: Binding<RxBufferProfile> {
        Binding(
            get: { RxBufferProfile(rawValue: appSettings.rxBufferProfile) ?? avProfileBinding.wrappedValue.defaultRXBufferProfile },
            set: {
                appSettings.rxBufferProfile = $0.rawValue
                operatorSurface.directPeerCommandFields.rxBufferProfile = $0
            }
        )
    }

    private var previewBinding: Binding<DirectPeerSessionPreviewMode> {
        Binding(
            get: { DirectPeerSessionPreviewMode(rawValue: appSettings.preview) ?? .on },
            set: {
                appSettings.preview = $0.rawValue
                operatorSurface.directPeerCommandFields.preview = $0
            }
        )
    }

    private var windowsLoLaRoleBinding: Binding<ExternalConnectorSessionRole> {
        Binding(
            get: { ExternalConnectorSessionRole(rawValue: appSettings.windowsLoLaRole) ?? .txRx },
            set: {
                appSettings.windowsLoLaRole = $0.rawValue
                operatorSurface.windowsLoLaPeerFields.role = $0
            }
        )
    }

    private var windowsLoLaMediaModeBinding: Binding<ExternalConnectorMediaMode> {
        Binding(
            get: { ExternalConnectorMediaMode(rawValue: appSettings.windowsLoLaMediaMode) ?? .audioVideo },
            set: {
                appSettings.windowsLoLaMediaMode = $0.rawValue
                operatorSurface.windowsLoLaPeerFields.mediaMode = $0
            }
        )
    }

    private var windowsLoLaPayloadModeBinding: Binding<LoLaVideoPayloadKind> {
        Binding(
            get: { LoLaVideoPayloadKind(rawValue: appSettings.windowsLoLaPayloadMode) ?? .generated },
            set: {
                appSettings.windowsLoLaPayloadMode = $0.rawValue
                operatorSurface.windowsLoLaPeerFields.payloadMode = $0
            }
        )
    }

    private var videoCompressionBinding: Binding<DirectPeerSessionVideoCompression> {
        Binding(
            get: { operatorSurface.directPeerCommandFields.videoCompression },
            set: { value in
                operatorSurface.directPeerCommandFields.videoCompression = value
                appSettings.videoCompression = value.rawValue
            }
        )
    }

    private var audioTransportBinding: Binding<DirectPeerSessionAudioTransport> {
        Binding(
            get: { operatorSurface.directPeerCommandFields.audioTransport },
            set: { value in
                operatorSurface.directPeerCommandFields.audioTransport = value
                appSettings.audioTransport = value.rawValue
            }
        )
    }

    private func appSettingsBinding<Value>(
        _ keyPath: ReferenceWritableKeyPath<AppSettings, Value>
    ) -> Binding<Value> {
        Binding(
            get: { appSettings[keyPath: keyPath] },
            set: { appSettings[keyPath: keyPath] = $0 }
        )
    }

    private func executionTextBinding(
        _ keyPath: WritableKeyPath<NativeAppShellExecutionSettings, String>,
        storage: Binding<String>
    ) -> Binding<String> {
        Binding(
            get: { storage.wrappedValue },
            set: {
                storage.wrappedValue = $0
                executionController.settings[keyPath: keyPath] = $0
            }
        )
    }

    private func textBinding<Surface>(
        _ keyPath: WritableKeyPath<Surface, String>,
        surface: WritableKeyPath<NativeAppShellOperatorPrototypeState, Surface>,
        storage: Binding<String>
    ) -> Binding<String> {
        Binding(
            get: { storage.wrappedValue },
            set: { value in
                storage.wrappedValue = value
                operatorSurface[keyPath: surface][keyPath: keyPath] = value
            }
        )
    }

    private func positiveIntBinding<Surface>(
        _ keyPath: WritableKeyPath<Surface, Int>,
        surface: WritableKeyPath<NativeAppShellOperatorPrototypeState, Surface>,
        storage: Binding<Int>
    ) -> Binding<Int> {
        intBinding(
            keyPath,
            surface: surface,
            storage: storage,
            lowerBound: 1
        )
    }

    private func nonNegativeIntBinding<Surface>(
        _ keyPath: WritableKeyPath<Surface, Int>,
        surface: WritableKeyPath<NativeAppShellOperatorPrototypeState, Surface>,
        storage: Binding<Int>
    ) -> Binding<Int> {
        intBinding(
            keyPath,
            surface: surface,
            storage: storage,
            lowerBound: 0
        )
    }

    private func intBinding<Surface>(
        _ keyPath: WritableKeyPath<Surface, Int>,
        surface: WritableKeyPath<NativeAppShellOperatorPrototypeState, Surface>,
        storage: Binding<Int>,
        lowerBound: Int
    ) -> Binding<Int> {
        Binding(
            get: { max(lowerBound, storage.wrappedValue) },
            set: {
                let value = max(lowerBound, $0)
                storage.wrappedValue = value
                operatorSurface[keyPath: surface][keyPath: keyPath] = value
            }
        )
    }

    private func uint16Binding<Surface>(
        _ keyPath: WritableKeyPath<Surface, UInt16>,
        surface: WritableKeyPath<NativeAppShellOperatorPrototypeState, Surface>,
        storage: Binding<Int>
    ) -> Binding<UInt16> {
        Binding(
            get: {
                UInt16(exactly: storage.wrappedValue)
                    ?? operatorSurface[keyPath: surface][keyPath: keyPath]
            },
            set: {
                storage.wrappedValue = Int($0)
                operatorSurface[keyPath: surface][keyPath: keyPath] = $0
            }
        )
    }
}

enum AppShellSettingsTabID: String, CaseIterable, Equatable {
    case execution
    case peers
    case audio
    case video
    case preview
    case windowsLoLa
    case externalConnectorNotice
    case snapshot

    var title: String {
        switch self {
        case .execution:
            return "Execution"
        case .peers:
            return "Peers"
        case .audio:
            return "Audio"
        case .video:
            return "Video"
        case .preview:
            return "Preview"
        case .windowsLoLa:
            return "Windows LoLa"
        case .externalConnectorNotice:
            return "External Connector"
        case .snapshot:
            return "Snapshot"
        }
    }
}

enum AppShellSettingsTabVisibility {
    static func visibleTabs(
        sessionMode: NativeAppShellSessionMode,
        controlMode: NativeAppShellControlMode
    ) -> [AppShellSettingsTabID] {
        guard sessionMode.supportsAppExecution else {
            return [.execution, .externalConnectorNotice]
        }
        switch (sessionMode, controlMode) {
        case (.directMacPeer, .normal):
            return [.execution, .preview, .snapshot]
        case (.directMacPeer, .advanced):
            return [.execution, .peers, .audio, .video, .preview, .snapshot]
        case (.windowsLoLa, .normal):
            return [.execution, .preview, .snapshot]
        case (.windowsLoLa, .advanced):
            return [.execution, .windowsLoLa, .preview, .snapshot]
        case (.jackTrip, _), (.ultraGrid, _):
            return [.execution, .externalConnectorNotice]
        }
    }
}
