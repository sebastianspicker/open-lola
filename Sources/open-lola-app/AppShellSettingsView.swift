import OpenLolaCore
import SwiftUI

struct AppShellSettingsView: View {
    let configuration: NativeAppConfigurationSnapshot
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let executionController: AppExecutionController
    let previewState: AppPreviewReceiverState
    @Bindable var appSettings: AppSettings
    @State private var settingsDraft = AppSettingsDraft()
    @State private var settingsFeedback: AppSettingsCommitFeedback?
    @AppStorage(AppStorageKeys.selectedSettingsTab) private var selectedSettingsTabRawValue = AppShellSettingsTabID.execution.rawValue

    var executionSettingsLocked: Bool {
        executionController.isRunning
    }

    var executionSettingsHelp: String {
        Self.executionSettingsHelp(phase: executionController.phase, isRunning: executionSettingsLocked)
    }

    static func executionSettingsHelp(isRunning: Bool) -> String {
        executionSettingsHelp(phase: .idle, isRunning: isRunning)
    }

    static func executionSettingsHelp(phase: AppExecutionPhase, isRunning: Bool) -> String {
        isRunning
            ? AppRuntimeInputLock.reason(phase: phase, isRunning: isRunning)
                ?? "Execution-affecting settings are locked while a process is active."
            : "Changes apply to the next generated command or validation."
    }

    var body: some View {
        let visibleTabs = AppShellSettingsTabVisibility.visibleTabs(
            sessionMode: sessionModeBinding.wrappedValue,
            controlMode: controlModeBinding.wrappedValue
        )

        VStack(spacing: 0) {
        TabView(selection: selectedSettingsTabBinding) {
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
                    scpExecutable: executionTextBinding(\.scpExecutable, storage: appSettingsBinding(\.executionSCPExecutable)),
                    lastValidationSummary: executionController.lastValidationSummary
                )
                .disabled(executionSettingsLocked)
                .help(executionSettingsHelp)
                .tag(AppShellSettingsTabID.execution)
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
                .tag(AppShellSettingsTabID.peers)
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
                .tag(AppShellSettingsTabID.audio)
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
                .tag(AppShellSettingsTabID.video)
            }

            if visibleTabs.contains(.preview) {
                AppPreviewSettingsTab(
                    audioPreviewEnabled: appPreviewDraftBinding(
                        \.audioPreviewEnabled,
                        state: previewState,
                        storage: appSettingsBinding(\.audioPreviewEnabled)
                    ),
                    videoPreviewEnabled: appPreviewDraftBinding(
                        \.videoPreviewEnabled,
                        state: previewState,
                        storage: appSettingsBinding(\.videoPreviewEnabled)
                    ),
                    showSafeFrame: appPreviewDraftBinding(
                        \.showSafeFrame,
                        state: previewState,
                        storage: appSettingsBinding(\.showSafeFrame)
                    ),
                    monitorGain: appPreviewDraftBinding(
                        \.monitorGain,
                        state: previewState,
                        storage: appSettingsBinding(\.monitorGain)
                    ),
                    remoteReturnBlend: appPreviewDraftBinding(
                        \.remoteReturnBlend,
                        state: previewState,
                        storage: appSettingsBinding(\.remoteReturnBlend)
                    ),
                    videoScale: appPreviewDraftBinding(
                        \.videoScale,
                        state: previewState,
                        storage: appSettingsBinding(\.videoScale)
                    ),
                    visibleStreams: appPreviewDraftIntBinding(
                        \.visibleStreams,
                        state: previewState,
                        storage: appSettingsBinding(\.visibleStreams)
                    ),
                    selectedVideoStream: appPreviewDraftIntBinding(
                        \.selectedVideoStream,
                        state: previewState,
                        storage: appSettingsBinding(\.selectedVideoStream)
                    )
                )
                .tag(AppShellSettingsTabID.preview)
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
                .tag(AppShellSettingsTabID.windowsLoLa)
            }

            if visibleTabs.contains(.externalConnectorNotice) {
                AppExternalConnectorNoticeTab(sessionMode: sessionModeBinding.wrappedValue)
                    .tag(AppShellSettingsTabID.externalConnectorNotice)
            }

            if visibleTabs.contains(.snapshot) {
                AppSnapshotSettingsTab(configuration: configuration)
                    .tag(AppShellSettingsTabID.snapshot)
            }
        }
        .frame(
            minWidth: AppWindowSize.settingsMinWidth,
            idealWidth: AppWindowSize.settingsWidth,
            maxWidth: AppWindowSize.settingsMaxWidth
        )
        .overlay(alignment: .top) {
            if executionSettingsLocked {
                Label(executionSettingsHelp, systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppDesignSystem.stateWarning)
                    .padding(.horizontal, AppSpacing.s)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppDesignSystem.stateWarningBackground, in: Capsule())
                    .padding(.top, AppSpacing.xs)
                }
        }
            Divider()
            settingsCommitBar(visibleTabs: visibleTabs)
        }
        .scenePadding()
        .onAppear {
            settingsDraft.load(from: appSettings)
            clampSelectedSettingsTab(visibleTabs)
        }
        .onChange(of: visibleTabs) { _, tabs in clampSelectedSettingsTab(tabs) }
    }

    private var selectedSettingsTabBinding: Binding<AppShellSettingsTabID> {
        Binding(
            get: { AppShellSettingsTabID(rawValue: selectedSettingsTabRawValue) ?? .execution },
            set: { selectedSettingsTabRawValue = $0.rawValue }
        )
    }

    @ViewBuilder
    private func settingsCommitBar(visibleTabs: [AppShellSettingsTabID]) -> some View {
        HStack(spacing: AppSpacing.s) {
            if let settingsFeedback {
                Label(settingsFeedback.title, systemImage: settingsFeedback.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(settingsFeedback.color)
                    .transition(.opacity)
            } else {
                Text("Unsaved edits stay local until Save.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("Discard") {
                discardSettingsDraft(visibleTabs: visibleTabs)
            }
            .disabled(executionSettingsLocked)

            Button("Save") {
                saveSettingsDraft(visibleTabs: visibleTabs)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(executionSettingsLocked)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.s)
    }

    private func saveSettingsDraft(visibleTabs: [AppShellSettingsTabID]) {
        settingsDraft.commit(
            to: appSettings,
            operatorSurface: &operatorSurface,
            executionController: executionController,
            previewState: previewState
        )
        showSettingsFeedback(.saved)
        clampSelectedSettingsTab(visibleTabs)
    }

    private func discardSettingsDraft(visibleTabs: [AppShellSettingsTabID]) {
        settingsDraft.load(from: appSettings)
        showSettingsFeedback(.discarded)
        clampSelectedSettingsTab(visibleTabs)
    }

    private func showSettingsFeedback(_ feedback: AppSettingsCommitFeedback) {
        withAnimation(.easeOut(duration: 0.16)) {
            settingsFeedback = feedback
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard settingsFeedback == feedback else {
                return
            }
            withAnimation(.easeOut(duration: 0.2)) {
                settingsFeedback = nil
            }
        }
    }

    private func clampSelectedSettingsTab(_ visibleTabs: [AppShellSettingsTabID]) {
        guard !visibleTabs.contains(selectedSettingsTabBinding.wrappedValue),
              let firstVisible = visibleTabs.first else {
            return
        }
        selectedSettingsTabBinding.wrappedValue = firstVisible
    }

    private var executableBinding: Binding<String> {
        Binding(
            get: { settingsDraft.executablePath },
            set: { settingsDraft.executablePath = $0 }
        )
    }

    private var sessionModeBinding: Binding<NativeAppShellSessionMode> {
        Binding(
            get: { NativeAppShellSessionMode(rawValue: settingsDraft.sessionMode) ?? .directMacPeer },
            set: { settingsDraft.sessionMode = $0.rawValue }
        )
    }

    private var controlModeBinding: Binding<NativeAppShellControlMode> {
        Binding(
            get: { NativeAppShellControlMode(rawValue: settingsDraft.controlMode) ?? .normal },
            set: { settingsDraft.controlMode = $0.rawValue }
        )
    }

    private var executionModeBinding: Binding<DirectPeerTwoPeerRunExecutionMode> {
        Binding(
            get: {
                AppExecutionModeAvailability.normalized(
                    DirectPeerTwoPeerRunExecutionMode(rawValue: settingsDraft.executionMode) ?? .local
                )
            },
            set: { settingsDraft.executionMode = AppExecutionModeAvailability.normalized($0).rawValue }
        )
    }

    private var preflightBinding: Binding<Bool> {
        Binding(
            get: { settingsDraft.requirePreflight },
            set: { settingsDraft.requirePreflight = $0 }
        )
    }

    private var roleBinding: Binding<DirectPeerSessionManualRole> {
        Binding(
            get: { DirectPeerSessionManualRole(rawValue: settingsDraft.role) ?? .initiator },
            set: { settingsDraft.role = $0.rawValue }
        )
    }

    private var avProfileBinding: Binding<DirectPeerSessionAVProfile> {
        Binding(
            get: { DirectPeerSessionAVProfile(rawValue: settingsDraft.avProfile) ?? .fastest },
            set: {
                settingsDraft.avProfile = $0.rawValue
                let defaultRx = $0.defaultRXBufferProfile
                settingsDraft.rxBufferProfile = defaultRx.rawValue
            }
        )
    }

    private var rxBufferProfileBinding: Binding<RxBufferProfile> {
        Binding(
            get: { RxBufferProfile(rawValue: settingsDraft.rxBufferProfile) ?? avProfileBinding.wrappedValue.defaultRXBufferProfile },
            set: { settingsDraft.rxBufferProfile = $0.rawValue }
        )
    }

    private var previewBinding: Binding<DirectPeerSessionPreviewMode> {
        Binding(
            get: { DirectPeerSessionPreviewMode(rawValue: settingsDraft.preview) ?? .on },
            set: { settingsDraft.preview = $0.rawValue }
        )
    }

    private var windowsLoLaRoleBinding: Binding<ExternalConnectorSessionRole> {
        Binding(
            get: { ExternalConnectorSessionRole(rawValue: settingsDraft.windowsLoLaRole) ?? .txRx },
            set: { settingsDraft.windowsLoLaRole = $0.rawValue }
        )
    }

    private var windowsLoLaMediaModeBinding: Binding<ExternalConnectorMediaMode> {
        Binding(
            get: { ExternalConnectorMediaMode(rawValue: settingsDraft.windowsLoLaMediaMode) ?? .audioVideo },
            set: { settingsDraft.windowsLoLaMediaMode = $0.rawValue }
        )
    }

    private var windowsLoLaPayloadModeBinding: Binding<LoLaVideoPayloadKind> {
        Binding(
            get: { LoLaVideoPayloadKind(rawValue: settingsDraft.windowsLoLaPayloadMode) ?? .generated },
            set: { settingsDraft.windowsLoLaPayloadMode = $0.rawValue }
        )
    }

    private var videoCompressionBinding: Binding<DirectPeerSessionVideoCompression> {
        Binding(
            get: { DirectPeerSessionVideoCompression(rawValue: settingsDraft.videoCompression) ?? .jpegXS },
            set: { settingsDraft.videoCompression = $0.rawValue }
        )
    }

    private var audioTransportBinding: Binding<DirectPeerSessionAudioTransport> {
        Binding(
            get: { DirectPeerSessionAudioTransport(rawValue: settingsDraft.audioTransport) ?? .openLolaRaw },
            set: { settingsDraft.audioTransport = $0.rawValue }
        )
    }

    private func appSettingsBinding<Value>(
        _ keyPath: ReferenceWritableKeyPath<AppSettingsDraft, Value>
    ) -> Binding<Value> {
        Binding(
            get: { settingsDraft[keyPath: keyPath] },
            set: { settingsDraft[keyPath: keyPath] = $0 }
        )
    }

    private func executionTextBinding(
        _ keyPath: WritableKeyPath<NativeAppShellExecutionSettings, String>,
        storage: Binding<String>
    ) -> Binding<String> {
        Binding(
            get: { storage.wrappedValue },
            set: { storage.wrappedValue = $0 }
        )
    }

    private func textBinding<Surface>(
        _ keyPath: WritableKeyPath<Surface, String>,
        surface: WritableKeyPath<NativeAppShellOperatorPrototypeState, Surface>,
        storage: Binding<String>
    ) -> Binding<String> {
        Binding(
            get: { storage.wrappedValue },
            set: { storage.wrappedValue = $0 }
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
            set: { storage.wrappedValue = Int($0) }
        )
    }

    private func appPreviewDraftBinding<Value>(
        _ keyPath: ReferenceWritableKeyPath<AppPreviewReceiverState, Value>,
        state: AppPreviewReceiverState,
        storage: Binding<Value>
    ) -> Binding<Value> {
        Binding(
            get: { storage.wrappedValue },
            set: { storage.wrappedValue = $0 }
        )
    }

    private func appPreviewDraftIntBinding(
        _ keyPath: ReferenceWritableKeyPath<AppPreviewReceiverState, Int>,
        state: AppPreviewReceiverState,
        storage: Binding<Int>
    ) -> Binding<Int> {
        Binding(
            get: { AppShellStoredDefaults.positivePreviewStreamValue(storage.wrappedValue) },
            set: { storage.wrappedValue = AppShellStoredDefaults.positivePreviewStreamValue($0) }
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

enum AppSettingsCommitFeedback: Equatable {
    case saved
    case discarded

    var title: String {
        switch self {
        case .saved:
            return "Saved"
        case .discarded:
            return "Discarded"
        }
    }

    var systemImage: String {
        switch self {
        case .saved:
            return "checkmark.circle.fill"
        case .discarded:
            return "arrow.uturn.backward.circle"
        }
    }

    var color: Color {
        switch self {
        case .saved:
            return AppDesignSystem.stateLive
        case .discarded:
            return AppDesignSystem.stateReady
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
