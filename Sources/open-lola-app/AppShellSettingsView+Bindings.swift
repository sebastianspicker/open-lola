// Builds settings bindings, keeping draft and persisted-value synchronization out of settings layout code.
import OpenLolaCore
import SwiftUI

extension AppShellSettingsView {
    var selectedSettingsTabBinding: Binding<AppShellSettingsTabID> {
        Binding(
            get: { AppShellSettingsTabID(rawValue: selectedSettingsTabRawValue) ?? .execution },
            set: { selectedSettingsTabRawValue = $0.rawValue }
        )
    }

    @ViewBuilder
    func settingsCommitBar(visibleTabs: [AppShellSettingsTabID]) -> some View {
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
        .background(AppDesignSystem.footerBackground)
    }

    func saveSettingsDraft(visibleTabs: [AppShellSettingsTabID]) {
        let result = settingsDraft.commit(
            to: appSettings,
            operatorSurface: &operatorSurface,
            executionController: executionController,
            previewState: previewState
        )
        showSettingsFeedback(AppSettingsCommitFeedback(result))
        clampSelectedSettingsTab(visibleTabs)
    }

    func discardSettingsDraft(visibleTabs: [AppShellSettingsTabID]) {
        settingsDraft.load(from: appSettings)
        showSettingsFeedback(.discarded)
        clampSelectedSettingsTab(visibleTabs)
    }

    func showSettingsFeedback(_ feedback: AppSettingsCommitFeedback) {
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

    func clampSelectedSettingsTab(_ visibleTabs: [AppShellSettingsTabID]) {
        guard !visibleTabs.contains(selectedSettingsTabBinding.wrappedValue),
              let firstVisible = visibleTabs.first else {
            return
        }
        selectedSettingsTabBinding.wrappedValue = firstVisible
    }

    var executableBinding: Binding<String> {
        Binding(
            get: { settingsDraft.executablePath },
            set: { settingsDraft.executablePath = $0 }
        )
    }

    var sessionModeBinding: Binding<NativeAppShellSessionMode> {
        Binding(
            get: { NativeAppShellSessionMode(rawValue: settingsDraft.sessionMode) ?? .directMacPeer },
            set: { settingsDraft.sessionMode = $0.rawValue }
        )
    }

    var controlModeBinding: Binding<NativeAppShellControlMode> {
        Binding(
            get: { NativeAppShellControlMode(rawValue: settingsDraft.controlMode) ?? .normal },
            set: { settingsDraft.controlMode = $0.rawValue }
        )
    }

    var executionModeBinding: Binding<DirectPeerTwoPeerRunExecutionMode> {
        Binding(
            get: {
                AppExecutionModeAvailability.normalized(
                    DirectPeerTwoPeerRunExecutionMode(rawValue: settingsDraft.executionMode) ?? .local
                )
            },
            set: { settingsDraft.executionMode = AppExecutionModeAvailability.normalized($0).rawValue }
        )
    }

    var preflightBinding: Binding<Bool> {
        Binding(
            get: { settingsDraft.requirePreflight },
            set: { settingsDraft.requirePreflight = $0 }
        )
    }

    var roleBinding: Binding<DirectPeerSessionManualRole> {
        Binding(
            get: { DirectPeerSessionManualRole(rawValue: settingsDraft.role) ?? .initiator },
            set: { settingsDraft.role = $0.rawValue }
        )
    }

    var avProfileBinding: Binding<DirectPeerSessionAVProfile> {
        Binding(
            get: { DirectPeerSessionAVProfile(rawValue: settingsDraft.avProfile) ?? .fastest },
            set: {
                settingsDraft.avProfile = $0.rawValue
                let defaultRx = $0.defaultRXBufferProfile
                settingsDraft.rxBufferProfile = defaultRx.rawValue
            }
        )
    }

    var rxBufferProfileBinding: Binding<RxBufferProfile> {
        Binding(
            get: {
                RxBufferProfile(rawValue: settingsDraft.rxBufferProfile)
                ?? avProfileBinding.wrappedValue.defaultRXBufferProfile
            },
            set: { settingsDraft.rxBufferProfile = $0.rawValue }
        )
    }

    var previewBinding: Binding<DirectPeerSessionPreviewMode> {
        Binding(
            get: { DirectPeerSessionPreviewMode(rawValue: settingsDraft.preview) ?? .on },
            set: { settingsDraft.preview = $0.rawValue }
        )
    }

    var windowsLoLaRoleBinding: Binding<ExternalConnectorSessionRole> {
        Binding(
            get: { ExternalConnectorSessionRole(rawValue: settingsDraft.windowsLoLaRole) ?? .txRx },
            set: { settingsDraft.windowsLoLaRole = $0.rawValue }
        )
    }

    var windowsLoLaMediaModeBinding: Binding<ExternalConnectorMediaMode> {
        Binding(
            get: { ExternalConnectorMediaMode(rawValue: settingsDraft.windowsLoLaMediaMode) ?? .audioVideo },
            set: { settingsDraft.windowsLoLaMediaMode = $0.rawValue }
        )
    }

    var windowsLoLaPayloadModeBinding: Binding<LoLaVideoPayloadKind> {
        Binding(
            get: { LoLaVideoPayloadKind(rawValue: settingsDraft.windowsLoLaPayloadMode) ?? .generated },
            set: { settingsDraft.windowsLoLaPayloadMode = $0.rawValue }
        )
    }

    func externalConnectorRoleBinding(
        _ keyPath: ReferenceWritableKeyPath<AppSettingsDraft, String>
    ) -> Binding<ExternalConnectorSessionRole> {
        Binding(
            get: { ExternalConnectorSessionRole(rawValue: settingsDraft[keyPath: keyPath]) ?? .txRx },
            set: { settingsDraft[keyPath: keyPath] = $0.rawValue }
        )
    }

    func externalConnectorMediaBinding(
        _ keyPath: ReferenceWritableKeyPath<AppSettingsDraft, String>,
        fallback: ExternalConnectorMediaMode
    ) -> Binding<ExternalConnectorMediaMode> {
        Binding(
            get: { ExternalConnectorMediaMode(rawValue: settingsDraft[keyPath: keyPath]) ?? fallback },
            set: { settingsDraft[keyPath: keyPath] = $0.rawValue }
        )
    }

    var videoCompressionBinding: Binding<DirectPeerSessionVideoCompression> {
        Binding(
            get: { DirectPeerSessionVideoCompression(rawValue: settingsDraft.videoCompression) ?? .jpegXS },
            set: { settingsDraft.videoCompression = $0.rawValue }
        )
    }

    var audioTransportBinding: Binding<DirectPeerSessionAudioTransport> {
        Binding(
            get: { DirectPeerSessionAudioTransport(rawValue: settingsDraft.audioTransport) ?? .openLolaRaw },
            set: { settingsDraft.audioTransport = $0.rawValue }
        )
    }

    func appSettingsBinding<Value>(
        _ keyPath: ReferenceWritableKeyPath<AppSettingsDraft, Value>
    ) -> Binding<Value> {
        Binding(
            get: { settingsDraft[keyPath: keyPath] },
            set: { settingsDraft[keyPath: keyPath] = $0 }
        )
    }

    func executionTextBinding(
        _ keyPath: WritableKeyPath<NativeAppShellExecutionSettings, String>,
        storage: Binding<String>
    ) -> Binding<String> {
        Binding(
            get: { storage.wrappedValue },
            set: { storage.wrappedValue = $0 }
        )
    }

    func textBinding<Surface>(
        _ keyPath: WritableKeyPath<Surface, String>,
        surface: WritableKeyPath<NativeAppShellOperatorPrototypeState, Surface>,
        storage: Binding<String>
    ) -> Binding<String> {
        Binding(
            get: { storage.wrappedValue },
            set: { storage.wrappedValue = $0 }
        )
    }

    func positiveIntBinding<Surface>(
        _ keyPath: WritableKeyPath<Surface, Int>,
        surface: WritableKeyPath<NativeAppShellOperatorPrototypeState, Surface>,
        storage: Binding<Int>
    ) -> Binding<Int> {
        boundedIntBinding(storage, lowerBound: 1)
    }

    func nonNegativeIntBinding<Surface>(
        _ keyPath: WritableKeyPath<Surface, Int>,
        surface: WritableKeyPath<NativeAppShellOperatorPrototypeState, Surface>,
        storage: Binding<Int>
    ) -> Binding<Int> {
        boundedIntBinding(storage, lowerBound: 0)
    }

    func intBinding<Surface>(
        _ keyPath: WritableKeyPath<Surface, Int>,
        surface: WritableKeyPath<NativeAppShellOperatorPrototypeState, Surface>,
        storage: Binding<Int>,
        lowerBound: Int
    ) -> Binding<Int> {
        boundedIntBinding(storage, lowerBound: lowerBound)
    }

    private func boundedIntBinding(_ storage: Binding<Int>, lowerBound: Int) -> Binding<Int> {
        Binding(
            get: { max(lowerBound, storage.wrappedValue) },
            set: {
                let value = max(lowerBound, $0)
                storage.wrappedValue = value
            }
        )
    }

    func uint16Binding<Surface>(
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

    func uint16DraftBinding(
        _ keyPath: ReferenceWritableKeyPath<AppSettingsDraft, Int>,
        fallback: UInt16
    ) -> Binding<UInt16> {
        Binding(
            get: { UInt16(exactly: settingsDraft[keyPath: keyPath]) ?? fallback },
            set: { settingsDraft[keyPath: keyPath] = Int($0) }
        )
    }

    func positiveDraftIntBinding(
        _ keyPath: ReferenceWritableKeyPath<AppSettingsDraft, Int>
    ) -> Binding<Int> {
        Binding(
            get: { max(1, settingsDraft[keyPath: keyPath]) },
            set: { settingsDraft[keyPath: keyPath] = max(1, $0) }
        )
    }

    func appPreviewDraftBinding<Value>(
        _ keyPath: ReferenceWritableKeyPath<AppPreviewReceiverState, Value>,
        state: AppPreviewReceiverState,
        storage: Binding<Value>
    ) -> Binding<Value> {
        Binding(
            get: { storage.wrappedValue },
            set: { storage.wrappedValue = $0 }
        )
    }

    func appPreviewDraftIntBinding(
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
