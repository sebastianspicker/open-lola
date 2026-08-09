// Settings-tab rendering coverage kept separate from the broader app hotspot rendering suite.
import AppKit
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
                requirePreflight: state.binding(\.requirePreflight),
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
        #expect(AppPreviewDisabledReasonCopy.unsupportedLocalPreviewControls.contains("unavailable"))
        #expect(snapshot.profileName == "rendering")
        #expect(state.avProfile == .balanced)
        #expect(state.rxBufferProfile == .adaptive)
    }

}

@MainActor
private func render<Content: View>(_ rootView: Content, size: CGSize) throws -> AppHotspotTabsRender {
    let hostingView = NSHostingView(rootView: rootView)
    hostingView.frame = CGRect(origin: .zero, size: size)
    hostingView.appearance = NSAppearance(named: .aqua)
    let window = NSWindow(
        contentRect: hostingView.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.appearance = hostingView.appearance
    window.contentView = hostingView
    hostingView.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    hostingView.layoutSubtreeIfNeeded()
    hostingView.displayIfNeeded()

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw AppHotspotTabsRenderError.bitmapUnavailable
    }
    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
    guard let pixels = bitmap.bitmapData else {
        throw AppHotspotTabsRenderError.bitmapUnavailable
    }

    var sampledColors = Set<UInt32>()
    var visibleSamples = 0
    for offset in stride(from: 0, to: bitmap.bytesPerRow * bitmap.pixelsHigh, by: 64) {
        let red = pixels[offset]
        let green = pixels[offset + 1]
        let blue = pixels[offset + 2]
        let alpha = pixels[offset + 3]
        if alpha > 0, Int(red) + Int(green) + Int(blue) > 24 {
            visibleSamples += 1
        }
        sampledColors.insert(UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue))
    }
    return AppHotspotTabsRender(
        frame: hostingView.bounds,
        hostedSubviewCount: hostingView.subviews.count,
        sampledColorCount: sampledColors.count,
        visibleSampleCount: visibleSamples
    )
}

private func assertHostedStructure(_ render: AppHotspotTabsRender, named name: String) {
    #expect(render.frame.width > 0, "\(name) must have a nonzero rendered width.")
    #expect(render.frame.height > 0, "\(name) must have a nonzero rendered height.")
    #expect(render.hostedSubviewCount > 0, "\(name) must build an AppKit hosting hierarchy.")
    #expect(render.sampledColorCount > 0, "\(name) must produce a render cache.")
}

private struct AppHotspotTabsRender {
    let frame: CGRect
    let hostedSubviewCount: Int
    let sampledColorCount: Int
    let visibleSampleCount: Int
}

private enum AppHotspotTabsRenderError: Error {
    case bitmapUnavailable
}

@MainActor
private final class AppSettingsTabRenderState {
    var sessionMode: NativeAppShellSessionMode = .directMacPeer
    var controlMode: NativeAppShellControlMode = .advanced
    var executablePath = "/Applications/Open LoLa/bin/open-lola"
    var planPath = "/tmp/open-lola/synthetic-plan.json"
    var supervisorReportPath = "/tmp/open-lola/synthetic-report.json"
    var requirePreflight = true
    var executionMode: DirectPeerTwoPeerRunExecutionMode = .ssh
    var macASSH = "operator@mac-a.example.test"
    var macBSSH = "operator@mac-b.example.test"
    var macAWorkingDirectory = "/tmp/open-lola/mac-a"
    var macBWorkingDirectory = "/tmp/open-lola/mac-b"
    var sshExecutable = "/usr/bin/ssh"
    var scpExecutable = "/usr/bin/scp"
    var localHost = "192.0.2.10"
    var peerHost = "198.51.100.10"
    var windowsHost = "192.0.2.20"
    var remoteHost = "198.51.100.20"
    var connectorRole: ExternalConnectorSessionRole = .txRx
    var peerRole: DirectPeerSessionManualRole = .initiator
    var controlPort: UInt16 = 7_000
    var remoteControlPort: UInt16 = 7_001
    var audioPort: UInt16 = 7_002
    var peerAudioPort: UInt16 = 7_003
    var videoPort: UInt16 = 7_004
    var metricsPort: UInt16 = 7_005
    var connectorMediaMode: ExternalConnectorMediaMode = .audioVideo
    var payloadMode: LoLaVideoPayloadKind = .generated
    var duration = 30
    var outputPath = "/tmp/open-lola/synthetic-output.json"
    var videoWidth = 1_920
    var videoHeight = 1_080
    var videoFrameRate = 60
    var videoBitsPerPixel = 8
    var sampleRate = 48_000
    var frames = 128
    var channelCount = 2
    var compression = 0
    var bayer = 0
    var localPeer = "mac-a"
    var remotePeer = "mac-b"
    var sampleFormat = "float32"
    var audioTransport: DirectPeerSessionAudioTransport = .openLolaRaw
    var avProfile: DirectPeerSessionAVProfile = .balanced
    var rxBufferProfile: RxBufferProfile = .adaptive
    var videoPixelFormat = "bgra8"
    var videoCompression: DirectPeerSessionVideoCompression = .jpegXS
    var videoStreamID = 101
    var timeoutSeconds = 2
    var previewMode: DirectPeerSessionPreviewMode = .on
    var audioPreviewEnabled = true
    var videoPreviewEnabled = true
    var showSafeFrame = true
    var monitorGain = 0.65
    var videoScale = 1.0

    func binding<Value>(_ keyPath: ReferenceWritableKeyPath<AppSettingsTabRenderState, Value>) -> Binding<Value> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )
    }
}
