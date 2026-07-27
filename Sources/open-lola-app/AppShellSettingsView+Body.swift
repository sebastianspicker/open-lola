// Composes the settings tab body, keeping its SwiftUI layout separate from binding and draft-persistence helpers.
import OpenLolaCore
import SwiftUI

extension AppShellSettingsView {
    var body: some View {
        let visibleTabs = AppShellSettingsTabVisibility.visibleTabs(
            sessionMode: sessionModeBinding.wrappedValue,
            controlMode: controlModeBinding.wrappedValue
        )

        return VStack(spacing: 0) {
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
                    sshExecutable: executionTextBinding(
                        \.sshExecutable,
                        storage: appSettingsBinding(\.executionSSHExecutable)
                    ),
                    scpExecutable: executionTextBinding(
                        \.scpExecutable,
                        storage: appSettingsBinding(\.executionSCPExecutable)
                    ),
                    lastValidationSummary: executionController.lastValidationSummary
                )
                .disabled(executionSettingsLocked)
                .help(executionSettingsHelp)
                .tag(AppShellSettingsTabID.execution)
            }

            if visibleTabs.contains(.peers) {
                AppPeersSettingsTab(
                    role: roleBinding,
                    localPeer: textBinding(
                        \.localPeer,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.localPeer)
                    ),
                    remotePeer: textBinding(
                        \.remotePeer,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.remotePeer)
                    ),
                    localHost: textBinding(
                        \.localHost,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.localHost)
                    ),
                    remoteHost: textBinding(
                        \.remoteHost,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.remoteHost)
                    ),
                    controlPort: uint16Binding(
                        \.controlPort,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.controlPort)
                    ),
                    remoteControlPort: uint16Binding(
                        \.remoteControlPort,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.remoteControlPort)
                    ),
                    audioPort: uint16Binding(
                        \.audioPort,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.audioPort)
                    ),
                    videoPort: uint16Binding(
                        \.videoPort,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.videoPort)
                    ),
                    metricsPort: uint16Binding(
                        \.metricsPort,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.metricsPort)
                    ),
                    outputPath: textBinding(
                        \.outputPath,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.outputPath)
                    )
                )
                .disabled(executionSettingsLocked)
                .help(executionSettingsHelp)
                .tag(AppShellSettingsTabID.peers)
            }

            if visibleTabs.contains(.audio) {
                AppAudioSettingsTab(
                    channelCount: positiveIntBinding(
                        \.channelCount,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.channelCount)
                    ),
                    sampleRate: positiveIntBinding(
                        \.sampleRateHertz,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.sampleRate)
                    ),
                    frames: positiveIntBinding(
                        \.framesPerPacket,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.frames)
                    ),
                    duration: positiveIntBinding(
                        \.durationSeconds,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.duration)
                    ),
                    sampleFormat: textBinding(
                        \.sampleFormat,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.sampleFormat)
                    ),
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
                    videoWidth: positiveIntBinding(
                        \.videoWidth,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.videoWidth)
                    ),
                    videoHeight: positiveIntBinding(
                        \.videoHeight,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.videoHeight)
                    ),
                    videoPixelFormat: textBinding(
                        \.videoPixelFormat,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.videoPixelFormat)
                    ),
                    videoCompression: videoCompressionBinding,
                    videoFrameRate: positiveIntBinding(
                        \.videoFrameRate,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.videoFrameRate)
                    ),
                    videoStreamID: positiveIntBinding(
                        \.videoStreamID,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.videoStreamID)
                    ),
                    timeoutSeconds: positiveIntBinding(
                        \.timeoutSeconds,
                        surface: \.directPeerCommandFields,
                        storage: appSettingsBinding(\.timeoutSeconds)
                    ),
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
                    videoScale: appPreviewDraftBinding(
                        \.videoScale,
                        state: previewState,
                        storage: appSettingsBinding(\.videoScale)
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

            if visibleTabs.contains(.externalConnector), sessionModeBinding.wrappedValue == .jackTrip {
                AppExternalConnectorSettingsTab(
                    title: "JackTrip",
                    allowsMediaSelection: false,
                    localHost: appSettingsBinding(\.jackTripLocalHost),
                    peerHost: appSettingsBinding(\.jackTripPeerHost),
                    role: externalConnectorRoleBinding(\.jackTripRole),
                    audioPort: uint16DraftBinding(
                        \.jackTripAudioPort,
                        fallback: NativeAppShellExternalConnectorPeerFields.jackTripAppDefault.audioPort
                    ),
                    peerAudioPort: uint16DraftBinding(
                        \.jackTripPeerAudioPort,
                        fallback: NativeAppShellExternalConnectorPeerFields.jackTripAppDefault.peerAudioPort
                    ),
                    videoPort: uint16DraftBinding(
                        \.jackTripVideoPort,
                        fallback: NativeAppShellExternalConnectorPeerFields.jackTripAppDefault.videoPort
                    ),
                    mediaMode: externalConnectorMediaBinding(\.jackTripMediaMode, fallback: .audio),
                    duration: positiveDraftIntBinding(\.jackTripDuration),
                    outputPath: appSettingsBinding(\.jackTripOutputPath)
                )
                .disabled(executionSettingsLocked)
                .help(executionSettingsHelp)
                .tag(AppShellSettingsTabID.externalConnector)
            }

            if visibleTabs.contains(.externalConnector), sessionModeBinding.wrappedValue == .ultraGrid {
                AppExternalConnectorSettingsTab(
                    title: "UltraGrid",
                    allowsMediaSelection: true,
                    localHost: appSettingsBinding(\.ultraGridLocalHost),
                    peerHost: appSettingsBinding(\.ultraGridPeerHost),
                    role: externalConnectorRoleBinding(\.ultraGridRole),
                    audioPort: uint16DraftBinding(
                        \.ultraGridAudioPort,
                        fallback: NativeAppShellExternalConnectorPeerFields.ultraGridAppDefault.audioPort
                    ),
                    peerAudioPort: uint16DraftBinding(
                        \.ultraGridPeerAudioPort,
                        fallback: NativeAppShellExternalConnectorPeerFields.ultraGridAppDefault.peerAudioPort
                    ),
                    videoPort: uint16DraftBinding(
                        \.ultraGridVideoPort,
                        fallback: NativeAppShellExternalConnectorPeerFields.ultraGridAppDefault.videoPort
                    ),
                    mediaMode: externalConnectorMediaBinding(\.ultraGridMediaMode, fallback: .audioVideo),
                    duration: positiveDraftIntBinding(\.ultraGridDuration),
                    outputPath: appSettingsBinding(\.ultraGridOutputPath)
                )
                .disabled(executionSettingsLocked)
                .help(executionSettingsHelp)
                .tag(AppShellSettingsTabID.externalConnector)
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
        .formStyle(.grouped)
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
        .background(AppDesignSystem.appBackground)
        .onAppear {
            settingsDraft.load(from: appSettings)
            clampSelectedSettingsTab(visibleTabs)
        }
        .onChange(of: visibleTabs) { _, tabs in clampSelectedSettingsTab(tabs) }
    }
}
