// Owns observable receiver-preview state and its UI, keeping preview lifecycle separate from the main operator surface.
import Observation
import OpenLolaCore
import SwiftUI

@MainActor
@Observable
final class AppPreviewReceiverState {
    enum Phase: String {
        case idle
        case starting
        case active
        case disabled
        case degraded
        case failed
    }

    enum WindowPhase: String {
        case notRequested
        case requested
        case visible
        case hidden
    }

    var audioPreviewEnabled = true
    var videoPreviewEnabled = true
    var showSafeFrame = true
    var monitorGain = 0.65 {
        didSet { audioLevelMeter.setGain(monitorGain) }
    }
    var videoScale = 1.0
    var receiverStatus = "Ready."
    var previewPhase: Phase = .idle
    var previewWindowPhase: WindowPhase = .notRequested

    var previewIsActive: Bool {
        (audioPreviewEnabled || videoPreviewEnabled)
            && verifiedPreviewPhase == .active
    }

    var verifiedReceiverStatus: String {
        switch verifiedPreviewPhase {
        case .active:
            return "Local device preview active."
        case .starting:
            return "Local device preview starting."
        case .disabled:
            return "Local device preview disabled."
        case .degraded:
            return "Local device preview degraded."
        case .failed:
            return failedPreviewStatus
        case .idle:
            return receiverStatus
        }
    }

    var previewWindowStatus: String {
        AppPreviewWindowStatusPolicy.status(phase: previewWindowPhase)
    }

    // Service objects publish through explicit status sampling in this state.
    @ObservationIgnored let videoPreviewController = AppVideoPreviewController()
    @ObservationIgnored let audioLevelMeter = AppAudioLevelMeter()
    @ObservationIgnored private var previewSessionActive = false

    init(
        audioPreviewEnabled: Bool = true,
        videoPreviewEnabled: Bool = true,
        showSafeFrame: Bool = true,
        monitorGain: Double = 0.65,
        videoScale: Double = 1.0
    ) {
        self.audioPreviewEnabled = audioPreviewEnabled
        self.videoPreviewEnabled = videoPreviewEnabled
        self.showSafeFrame = showSafeFrame
        self.monitorGain = monitorGain
        self.videoScale = videoScale
        videoPreviewController.onStatusChange = { [weak self] in
            self?.reconcilePreviewPhase()
        }
        audioLevelMeter.onStatusChange = { [weak self] in
            self?.reconcilePreviewPhase()
        }
    }

    func startReceiverPreview(
        audioInputUID: String?,
        videoDeviceID: String?
    ) {
        guard audioPreviewEnabled || videoPreviewEnabled else {
            previewSessionActive = false
            previewPhase = .disabled
            receiverStatus = verifiedReceiverStatus
            videoPreviewController.stop()
            audioLevelMeter.stop()
            return
        }
        previewSessionActive = true
        previewPhase = .starting
        receiverStatus = "Local device preview starting."
        videoPreviewController.start(deviceID: videoDeviceID, enabled: videoPreviewEnabled)
        audioLevelMeter.start(inputUID: audioInputUID, enabled: audioPreviewEnabled, gain: monitorGain)
        reconcilePreviewPhase()
    }

    func stopReceiverPreview() {
        previewSessionActive = false
        previewPhase = .idle
        videoPreviewController.stop()
        audioLevelMeter.stop()
        receiverStatus = "Local device preview stopped."
    }

    func requestPreviewWindow() {
        previewWindowPhase = .requested
        receiverStatus = AppPreviewWindowRequestFeedback.statusMessage
    }

    func markPreviewWindowVisible() {
        previewWindowPhase = .visible
    }

    func markPreviewWindowHidden() {
        previewWindowPhase = .hidden
    }

    func reconcilePreviewPhase() {
        guard previewSessionActive else {
            if !audioPreviewEnabled, !videoPreviewEnabled {
                previewPhase = .disabled
                receiverStatus = verifiedReceiverStatus
            }
            return
        }
        previewPhase = verifiedPreviewPhase
        receiverStatus = verifiedReceiverStatus
    }

    var verifiedPreviewPhase: Phase {
        let requiredPhases = [
            videoPreviewEnabled ? videoPreviewController.phase : nil,
            audioPreviewEnabled ? audioLevelMeter.phase : nil
        ]
        let enabledPhases = requiredPhases.compactMap { $0 }
        guard !enabledPhases.isEmpty else {
            return .disabled
        }
        if enabledPhases.allSatisfy({ $0 == .active }) {
            return .active
        }
        if enabledPhases.contains(.failed) {
            return enabledPhases.contains(.active) ? .degraded : .failed
        }
        if enabledPhases.contains(.starting) {
            return .starting
        }
        if enabledPhases.allSatisfy({ $0 == .disabled }) {
            return .disabled
        }
        return .idle
    }

    private var failedPreviewStatus: String {
        [
            videoPreviewController.phase == .failed ? videoPreviewController.status : nil,
            audioLevelMeter.phase == .failed ? audioLevelMeter.status : nil
        ]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

enum AppPreviewDisabledReasonCopy {
    static func inactivePreviewControl(_ control: String, help: String) -> String {
        "\(control): \(help)"
    }
}

enum AppPreviewReceiverWarningPolicy {
    static func showsMainBannerWarning(
        phase: AppPreviewReceiverState.Phase,
        audioPreviewEnabled: Bool,
        videoPreviewEnabled: Bool,
        sessionState: AppSessionState
    ) -> Bool {
        guard audioPreviewEnabled || videoPreviewEnabled else {
            return false
        }
        guard [.supervisorRunning, .awaitingEvidence].contains(sessionState) else {
            return false
        }
        return phase == .degraded || phase == .failed
    }
}

enum AppPreviewWindowRequestFeedback {
    static let statusMessage = "Local preview window request sent. Waiting for visible window confirmation."
    static let menuHelp = "Request the Local Preview window. Display success is not confirmed by this action."
}

enum AppPreviewWindowStatusPolicy {
    static func status(phase: AppPreviewReceiverState.WindowPhase) -> String {
        switch phase {
        case .notRequested:
            return "Local preview window not requested."
        case .requested:
            return AppPreviewWindowRequestFeedback.statusMessage
        case .visible:
            return "Local preview window visible."
        case .hidden:
            return "Local preview window not visible."
        }
    }
}

struct AppPreviewReceiverView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    @Bindable var previewState: AppPreviewReceiverState

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            GroupBox("Local Preview Controls") {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                Toggle("Audio Preview", isOn: $previewState.audioPreviewEnabled)
                Toggle("Video Preview", isOn: $previewState.videoPreviewEnabled)
                Toggle("Safe frame", isOn: $previewState.showSafeFrame)

                Slider(value: $previewState.monitorGain, in: 0...1) {
                    Text("Monitor gain")
                }
                .disabled(!previewState.previewIsActive)
                .help(previewControlHelp)
                if !previewState.previewIsActive {
                    AppDisabledControlReasonText(
                        reason: AppPreviewDisabledReasonCopy.inactivePreviewControl(
                            "Monitor gain",
                            help: previewControlHelp
                        )
                    )
                }
                Slider(value: $previewState.videoScale, in: 0.5...2) {
                    Text("Video scale")
                }
                }
                .frame(maxWidth: 560, alignment: .leading)
            }

            GroupBox("Local Preview Routing") {
                MetricsGrid {
                AppReadableMetric(
                    label: "Audio input",
                    value: operatorSurface.inventory.selection.audioInputUID ?? "none",
                    monospaced: true
                )
                AppReadableMetric(
                    label: "Audio output",
                    value: operatorSurface.inventory.selection.audioOutputUID ?? "none",
                    monospaced: true
                )
                AppReadableMetric(
                    label: "Video device",
                    value: operatorSurface.inventory.selection.videoDeviceID ?? "none",
                    monospaced: true
                )
                LabeledContent("Preview mode", value: operatorSurface.directPeerCommandFields.preview.rawValue)
                AppReadableMetric(label: "Video output", value: videoOutputStatus)
                LabeledContent("Video", value: videoFormatSummary)
                AppReadableMetric(label: "Preview window", value: previewState.previewWindowStatus)
                AppReadableMetric(label: "Local preview", value: previewState.verifiedReceiverStatus)
                }
            }
        }
        .appConsoleGroupBoxStyle()
    }

    private var videoFormatSummary: String {
        let fields = operatorSurface.directPeerCommandFields
        return "\(fields.videoWidth)x\(fields.videoHeight) \(fields.videoFrameRate)fps \(fields.videoPixelFormat)"
    }

    private var videoOutputStatus: String {
        AppPreviewVideoOutputStatusPolicy.status(inventory: operatorSurface.inventory)
    }

    private var previewControlHelp: String {
        if previewState.previewIsActive {
            return "Updates the active local preview."
        }
        return "Open Local Preview Window to apply this control."
    }

}
