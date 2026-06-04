import OpenLolaCore
import SwiftUI

enum AppExecutionModeAvailability {
    static let supportedSettingsModes: [DirectPeerTwoPeerRunExecutionMode] = [.local]
    static let unsupportedSettingsHelp = "SSH launch is not available in Settings. Use Local execution here, or copy an SSH supervisor command from the operator artifacts."

    static func normalized(_ mode: DirectPeerTwoPeerRunExecutionMode) -> DirectPeerTwoPeerRunExecutionMode {
        supportedSettingsModes.contains(mode) ? mode : .local
    }
}

struct AppExecutionSettingsTab: View {
    @Binding var sessionMode: NativeAppShellSessionMode
    @Binding var controlMode: NativeAppShellControlMode
    @Binding var executablePath: String
    @Binding var planPath: String
    @Binding var supervisorReportPath: String
    @Binding var requirePreflight: Bool
    @Binding var executionMode: DirectPeerTwoPeerRunExecutionMode
    @Binding var macASSH: String
    @Binding var macBSSH: String
    @Binding var macAWorkingDirectory: String
    @Binding var macBWorkingDirectory: String
    @Binding var sshExecutable: String
    @Binding var scpExecutable: String
    let lastValidationSummary: String

    var body: some View {
        Form {
            Picker("Workflow", selection: $sessionMode) {
                ForEach(NativeAppShellSessionMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            Picker("Controls", selection: $controlMode) {
                ForEach(NativeAppShellControlMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            Text(sessionMode.appModeSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            if sessionMode.supportsAppExecution {
                TextField("Executable", text: $executablePath)
            }
            LabeledContent("Last validation", value: lastValidationSummary)
            if let validationShortcutLabel = AppExecutionSettingsShortcutCopy.validationShortcutLabel() {
                Text(validationShortcutLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if controlMode == .advanced, sessionMode == .directMacPeer {
                TextField("Plan path", text: $planPath)
                TextField("Supervisor report", text: $supervisorReportPath)
                Toggle("Require preflight", isOn: $requirePreflight)
                Picker("Execution mode", selection: $executionMode) {
                    ForEach(AppExecutionModeAvailability.supportedSettingsModes, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                Text(AppExecutionModeAvailability.unsupportedSettingsHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if executionMode == .ssh {
                    Section("SSH Fallback") {
                        TextField("Mac A SSH target", text: $macASSH)
                        TextField("Mac B SSH target", text: $macBSSH)
                        TextField("Mac A working directory", text: $macAWorkingDirectory)
                        TextField("Mac B working directory", text: $macBWorkingDirectory)
                        TextField("SSH executable", text: $sshExecutable)
                        TextField("SCP executable", text: $scpExecutable)
                    }
                }
            }
        }
        .tabItem { Label("Execution", systemImage: "playpause.circle") }
    }
}

enum AppExecutionSettingsShortcutCopy {
    static func validationShortcutLabel(
        actions: [NativeAppShellSurfaceAction] = NativeAppShellActionInventory.menuActions
    ) -> String? {
        guard let shortcut = actions.first(where: { $0.id == "validate-supervisor-report" })?.keyboardShortcut,
              let shortcutLabel = shortcutLabel(shortcut) else {
            return nil
        }
        return "Shortcut: \(shortcutLabel)"
    }

    private static func shortcutLabel(_ shortcut: String) -> String? {
        switch shortcut {
        case "command-shift-v":
            return "⌘⇧V"
        default:
            return nil
        }
    }
}

struct AppExternalConnectorNoticeTab: View {
    let sessionMode: NativeAppShellSessionMode

    var body: some View {
        Form {
            LabeledContent("Workflow", value: sessionMode.displayName)
            LabeledContent("Connector", value: sessionMode.externalConnectorKind?.rawValue ?? "none")
            Text(sessionMode.unavailableAppReason ?? sessionMode.appModeSummary)
                .foregroundStyle(.secondary)
        }
        .tabItem { Label(sessionMode.displayName, systemImage: "externaldrive.connected.to.line.below") }
    }
}

struct AppExternalConnectorSettingsTab: View {
    let title: String
    let allowsMediaSelection: Bool
    @Binding var localHost: String
    @Binding var peerHost: String
    @Binding var role: ExternalConnectorSessionRole
    @Binding var audioPort: UInt16
    @Binding var peerAudioPort: UInt16
    @Binding var videoPort: UInt16
    @Binding var mediaMode: ExternalConnectorMediaMode
    @Binding var duration: Int
    @Binding var outputPath: String

    var body: some View {
        Form {
            TextField("Local host", text: $localHost)
            TextField("Peer host", text: $peerHost)
            Picker("Role", selection: $role) {
                Text("TX-RX").tag(ExternalConnectorSessionRole.txRx)
                Text("TX").tag(ExternalConnectorSessionRole.tx)
                Text("RX").tag(ExternalConnectorSessionRole.rx)
            }
            if allowsMediaSelection {
                Picker("Media", selection: $mediaMode) {
                    Text("Audio + Video").tag(ExternalConnectorMediaMode.audioVideo)
                    Text("Audio").tag(ExternalConnectorMediaMode.audio)
                }
            } else {
                LabeledContent("Media", value: ExternalConnectorMediaMode.audio.cliValue)
            }
            UInt16Field("Audio port", value: $audioPort)
            if role.transmits {
                UInt16Field("Peer audio port", value: $peerAudioPort)
            }
            if allowsMediaSelection {
                UInt16Field("Video port", value: $videoPort)
            }
            IntField("Duration", value: $duration)
            TextField("Output report", text: $outputPath)
        }
        .tabItem { Label(title, systemImage: "antenna.radiowaves.left.and.right") }
    }
}

struct AppWindowsLoLaSettingsTab: View {
    @Binding var localHost: String
    @Binding var windowsHost: String
    @Binding var role: ExternalConnectorSessionRole
    @Binding var controlPort: UInt16
    @Binding var audioPort: UInt16
    @Binding var videoPort: UInt16
    @Binding var mediaMode: ExternalConnectorMediaMode
    @Binding var payloadMode: LoLaVideoPayloadKind
    @Binding var videoWidth: Int
    @Binding var videoHeight: Int
    @Binding var videoFrameRate: Int
    @Binding var videoBitsPerPixel: Int
    @Binding var duration: Int
    @Binding var outputPath: String
    @Binding var sampleRate: Int
    @Binding var frames: Int
    @Binding var channelCount: Int
    @Binding var compression: Int
    @Binding var bayer: Int

    var body: some View {
        Form {
            TextField("Local host", text: $localHost)
            TextField("Windows host", text: $windowsHost)
            Picker("Role", selection: $role) {
                Text("TX-RX").tag(ExternalConnectorSessionRole.txRx)
                Text("TX").tag(ExternalConnectorSessionRole.tx)
                Text("RX").tag(ExternalConnectorSessionRole.rx)
            }
            UInt16Field("Control port", value: $controlPort)
            UInt16Field("Audio port", value: $audioPort)
            UInt16Field("Video port", value: $videoPort)
            Picker("Media", selection: $mediaMode) {
                Text("Audio + Video").tag(ExternalConnectorMediaMode.audioVideo)
                Text("Audio").tag(ExternalConnectorMediaMode.audio)
                Text("Video").tag(ExternalConnectorMediaMode.video)
            }
            Picker("Payload", selection: $payloadMode) {
                Text("Generated").tag(LoLaVideoPayloadKind.generated)
                Text("AVFoundation MJPEG").tag(LoLaVideoPayloadKind.avFoundationMjpeg)
                Text("AVFoundation Raw 8").tag(LoLaVideoPayloadKind.avFoundationRaw8)
                Text("AVFoundation JPEG XS").tag(LoLaVideoPayloadKind.avFoundationJpegXS)
            }
            IntField("Video width", value: $videoWidth)
            IntField("Video height", value: $videoHeight)
            IntField("Video FPS", value: $videoFrameRate)
            IntField("Video BPP", value: $videoBitsPerPixel)
            IntField("Duration", value: $duration)
            TextField("Output report", text: $outputPath)
            IntField("Sample rate", value: $sampleRate)
            IntField("Frames", value: $frames)
            IntField("Channels", value: $channelCount)
            IntField("Compression", value: $compression, minimumValue: 0)
            IntField("Bayer", value: $bayer, minimumValue: 0)
        }
        .tabItem { Label("Windows LoLa", systemImage: "display.and.arrow.down") }
    }
}

struct AppPeersSettingsTab: View {
    @Binding var role: DirectPeerSessionManualRole
    @Binding var localPeer: String
    @Binding var remotePeer: String
    @Binding var localHost: String
    @Binding var remoteHost: String
    @Binding var controlPort: UInt16
    @Binding var remoteControlPort: UInt16
    @Binding var audioPort: UInt16
    @Binding var videoPort: UInt16
    @Binding var metricsPort: UInt16
    @Binding var outputPath: String

    var body: some View {
        Form {
            Picker("Role", selection: $role) {
                Text("Initiator").tag(DirectPeerSessionManualRole.initiator)
                Text("Responder").tag(DirectPeerSessionManualRole.responder)
            }
            TextField("Local peer", text: $localPeer)
            TextField("Remote peer", text: $remotePeer)
            TextField("Local host", text: $localHost)
            TextField("Remote host", text: $remoteHost)
            UInt16Field("Control port", value: $controlPort)
            UInt16Field("Remote control port", value: $remoteControlPort)
            UInt16Field("Audio port", value: $audioPort)
            UInt16Field("Video port", value: $videoPort)
            UInt16Field("Metrics port", value: $metricsPort)
            TextField("Output path", text: $outputPath)
        }
        .tabItem { Label("Peers", systemImage: "network") }
    }
}

struct AppAudioSettingsTab: View {
    @Binding var channelCount: Int
    @Binding var sampleRate: Int
    @Binding var frames: Int
    @Binding var duration: Int
    @Binding var sampleFormat: String
    @Binding var audioTransport: DirectPeerSessionAudioTransport
    @Binding var avProfile: DirectPeerSessionAVProfile
    @Binding var rxBufferProfile: RxBufferProfile

    var body: some View {
        Form {
            IntField("Channels", value: $channelCount)
            IntField("Sample rate", value: $sampleRate)
            IntField("Frames", value: $frames)
            IntField("Duration", value: $duration)
            Picker("Sample format", selection: $sampleFormat) {
                Text("Float 32").tag("float32")
                Text("Int 16").tag("int16")
            }
            Picker("Audio transport", selection: $audioTransport) {
                Text("OpenLoLa raw").tag(DirectPeerSessionAudioTransport.openLolaRaw)
                Text("OpenLoLa Opus CELT LD").tag(DirectPeerSessionAudioTransport.openLolaOpusCeltLowDelay)
                Text("AES67 / ST 2110-30 L24").tag(DirectPeerSessionAudioTransport.aes67ST2110L24)
            }
            Picker("AV profile", selection: $avProfile) {
                Text("Fastest").tag(DirectPeerSessionAVProfile.fastest)
                Text("Balanced").tag(DirectPeerSessionAVProfile.balanced)
            }
            Picker("RX buffer", selection: $rxBufferProfile) {
                ForEach(validRXBufferProfiles, id: \.self) { profile in
                    Text(profile.rawValue).tag(profile)
                }
            }
        }
        .tabItem { Label("Audio", systemImage: "waveform") }
    }

    private var validRXBufferProfiles: [RxBufferProfile] {
        switch avProfile {
        case .fastest:
            [.direct]
        case .balanced:
            [.small, .adaptive, .stableWan]
        }
    }
}

struct AppVideoSettingsTab: View {
    @Binding var videoWidth: Int
    @Binding var videoHeight: Int
    @Binding var videoPixelFormat: String
    @Binding var videoCompression: DirectPeerSessionVideoCompression
    @Binding var videoFrameRate: Int
    @Binding var videoStreamID: Int
    @Binding var timeoutSeconds: Int
    @Binding var preview: DirectPeerSessionPreviewMode

    var body: some View {
        Form {
            IntField("Video width", value: $videoWidth)
            IntField("Video height", value: $videoHeight)
            Picker("Video pixel format", selection: $videoPixelFormat) {
                Text("BGRA 8").tag("bgra8")
                Text("RGB 24").tag("rgb24")
                Text("YUV 4:2:2").tag("yuv422")
            }
            Picker("Video compression", selection: $videoCompression) {
                Text("Raw").tag(DirectPeerSessionVideoCompression.raw)
                Text("JPEG XS").tag(DirectPeerSessionVideoCompression.jpegXS)
            }
            IntField("Video frame rate", value: $videoFrameRate)
            IntField("Video stream ID", value: $videoStreamID)
            IntField("Timeout seconds", value: $timeoutSeconds)
            Picker("Preview", selection: $preview) {
                Text("On").tag(DirectPeerSessionPreviewMode.on)
                Text("Off").tag(DirectPeerSessionPreviewMode.off)
            }
        }
        .tabItem { Label("Video", systemImage: "video") }
    }
}

struct AppPreviewSettingsTab: View {
    @Binding var audioPreviewEnabled: Bool
    @Binding var videoPreviewEnabled: Bool
    @Binding var showSafeFrame: Bool
    @Binding var monitorGain: Double
    @Binding var videoScale: Double

    var body: some View {
        Form {
            Toggle("Audio Preview", isOn: $audioPreviewEnabled)
            Toggle("Video Preview", isOn: $videoPreviewEnabled)
            Toggle("Safe frame", isOn: $showSafeFrame)
            Slider(value: $monitorGain, in: 0...1) {
                Text("Monitor gain")
            }
            Slider(value: $videoScale, in: 0.5...2) {
                Text("Video scale")
            }
            AppDisabledControlReasonText(
                reason: AppPreviewDisabledReasonCopy.unsupportedLocalPreviewControls
            )
        }
        .tabItem { Label("Preview", systemImage: "macwindow.on.rectangle") }
    }
}

struct AppSnapshotSettingsTab: View {
    let configuration: NativeAppConfigurationSnapshot

    var body: some View {
        Form {
            LabeledContent("Default profile", value: configuration.profileName)
            LabeledContent("Sample rate", value: "\(configuration.sampleRateHertz) Hz")
            LabeledContent("Frames per buffer", value: "\(configuration.framesPerBuffer)")
        }
        .tabItem { Label("Snapshot", systemImage: "doc.text") }
    }
}
