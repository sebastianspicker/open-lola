// Settings-tab rendering coverage kept separate from the broader app hotspot rendering suite.
import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

private let appHotspotTabsRenderSize = CGSize(width: 1_000, height: 760)

@MainActor
extension AppHotspotRenderingCoverageTests {
    @Test
    func appSettingsTabsRenderEveryConcreteFormWithSyntheticBindings() throws {
        let state = AppSettingsTabRenderState()
        let snapshot = NativeAppConfigurationSnapshot(
            profile: .init(name: "rendering", audioDeviceSelection: "synthetic-input", outputDeviceUID: nil),
            audio: .init(sampleRateHertz: 48_000, framesPerBuffer: 128, requestedPlayoutTargetFrames: 128),
            features: .init(
                videoEnabled: true,
                showControlEnabled: false,
                lightingEnabled: false,
                createdByUI: true,
                immutableHandoff: true
            )
        )
        let tabs: [(String, AnyView)] = [
            ("execution", AnyView(AppExecutionSettingsTab(
                sessionMode: state.binding(\.sessionMode),
                controlMode: state.binding(\.controlMode),
                executablePath: state.binding(\.executablePath),
                planPath: state.binding(\.planPath),
                supervisorReportPath: state.binding(\.supervisorReportPath),
                executionMode: state.binding(\.executionMode),
                macASSH: state.binding(\.macASSH),
                macBSSH: state.binding(\.macBSSH),
                macAWorkingDirectory: state.binding(\.macAWorkingDirectory),
                macBWorkingDirectory: state.binding(\.macBWorkingDirectory),
                sshExecutable: state.binding(\.sshExecutable),
                scpExecutable: state.binding(\.scpExecutable),
                lastValidationSummary: "Synthetic validation not run."
            ))),
            ("connector-notice", AnyView(AppExternalConnectorNoticeTab(sessionMode: .jackTrip))),
            ("connector-settings", AnyView(AppExternalConnectorSettingsTab(
                title: "Synthetic connector",
                allowsMediaSelection: true,
                localHost: state.binding(\.localHost),
                peerHost: state.binding(\.peerHost),
                role: state.binding(\.connectorRole),
                audioPort: state.binding(\.audioPort),
                peerAudioPort: state.binding(\.peerAudioPort),
                videoPort: state.binding(\.videoPort),
                mediaMode: state.binding(\.connectorMediaMode),
                duration: state.binding(\.duration),
                outputPath: state.binding(\.outputPath)
            ))),
            ("windows-lola", AnyView(AppWindowsLoLaSettingsTab(
                localHost: state.binding(\.localHost),
                windowsHost: state.binding(\.windowsHost),
                role: state.binding(\.connectorRole),
                controlPort: state.binding(\.controlPort),
                audioPort: state.binding(\.audioPort),
                videoPort: state.binding(\.videoPort),
                mediaMode: state.binding(\.connectorMediaMode),
                payloadMode: state.binding(\.payloadMode),
                videoWidth: state.binding(\.videoWidth),
                videoHeight: state.binding(\.videoHeight),
                videoFrameRate: state.binding(\.videoFrameRate),
                videoBitsPerPixel: state.binding(\.videoBitsPerPixel),
                duration: state.binding(\.duration),
                outputPath: state.binding(\.outputPath),
                sampleRate: state.binding(\.sampleRate),
                frames: state.binding(\.frames),
                channelCount: state.binding(\.channelCount),
                compression: state.binding(\.compression),
                bayer: state.binding(\.bayer)
            ))),
            ("peers", AnyView(AppPeersSettingsTab(
                role: state.binding(\.peerRole),
                localPeer: state.binding(\.localPeer),
                remotePeer: state.binding(\.remotePeer),
                localHost: state.binding(\.localHost),
                remoteHost: state.binding(\.remoteHost),
                controlPort: state.binding(\.controlPort),
                remoteControlPort: state.binding(\.remoteControlPort),
                audioPort: state.binding(\.audioPort),
                videoPort: state.binding(\.videoPort),
                metricsPort: state.binding(\.metricsPort),
                outputPath: state.binding(\.outputPath)
            ))),
            ("audio", AnyView(AppAudioSettingsTab(
                channelCount: state.binding(\.channelCount),
                sampleRate: state.binding(\.sampleRate),
                frames: state.binding(\.frames),
                duration: state.binding(\.duration),
                sampleFormat: state.binding(\.sampleFormat),
                audioTransport: state.binding(\.audioTransport),
                avProfile: state.binding(\.avProfile),
                rxBufferProfile: state.binding(\.rxBufferProfile)
            ))),
            ("video", AnyView(AppVideoSettingsTab(
                videoWidth: state.binding(\.videoWidth),
                videoHeight: state.binding(\.videoHeight),
                videoPixelFormat: state.binding(\.videoPixelFormat),
                videoCompression: state.binding(\.videoCompression),
                videoFrameRate: state.binding(\.videoFrameRate),
                videoStreamID: state.binding(\.videoStreamID),
                timeoutSeconds: state.binding(\.timeoutSeconds),
                preview: state.binding(\.previewMode)
            ))),
            ("preview", AnyView(AppPreviewSettingsTab(
                audioPreviewEnabled: state.binding(\.audioPreviewEnabled),
                videoPreviewEnabled: state.binding(\.videoPreviewEnabled),
                showSafeFrame: state.binding(\.showSafeFrame),
                monitorGain: state.binding(\.monitorGain),
                videoScale: state.binding(\.videoScale)
            ))),
            ("snapshot", AnyView(AppSnapshotSettingsTab(configuration: snapshot)))
        ]

        for (name, tab) in tabs {
            assertHostedStructure(
                try render(TabView { tab }.padding(), size: appHotspotTabsRenderSize),
                named: "settings-tab-\(name)"
            )
        }
        #expect(AppExecutionSettingsShortcutCopy.validationShortcutLabel() == "Shortcut: ⌘⇧V")
        #expect(NativeAppShellSessionMode.jackTrip.externalConnectorKind?.rawValue == "jackTrip")
        #expect(snapshot.profileName == "rendering")
        #expect(state.avProfile == .balanced)
        #expect(state.rxBufferProfile == .adaptive)
    }

}
