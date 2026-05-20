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

    var audioPreviewEnabled = true
    var videoPreviewEnabled = true
    var showSafeFrame = true
    var monitorGain = 0.65 {
        didSet { audioLevelMeter.setGain(monitorGain) }
    }
    var remoteReturnBlend = 0.25
    var videoScale = 1.0
    var visibleStreams = 1
    var selectedVideoStream = 101
    var receiverStatus = "Ready."
    var previewPhase: Phase = .idle

    var previewIsActive: Bool {
        (audioPreviewEnabled || videoPreviewEnabled)
            && (previewPhase == .active || verifiedPreviewPhase == .active)
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

    // Service objects publish through explicit status sampling in this state.
    @ObservationIgnored let videoPreviewController = AppVideoPreviewController()
    @ObservationIgnored let audioLevelMeter = AppAudioLevelMeter()
    @ObservationIgnored private var previewSessionActive = false

    init(
        audioPreviewEnabled: Bool = true,
        videoPreviewEnabled: Bool = true,
        showSafeFrame: Bool = true,
        monitorGain: Double = 0.65,
        remoteReturnBlend: Double = 0.25,
        videoScale: Double = 1.0,
        visibleStreams: Int = 1,
        selectedVideoStream: Int = 101
    ) {
        self.audioPreviewEnabled = audioPreviewEnabled
        self.videoPreviewEnabled = videoPreviewEnabled
        self.showSafeFrame = showSafeFrame
        self.monitorGain = monitorGain
        self.remoteReturnBlend = remoteReturnBlend
        self.videoScale = videoScale
        self.visibleStreams = AppShellStoredDefaults.positivePreviewStreamValue(visibleStreams)
        self.selectedVideoStream = AppShellStoredDefaults.positivePreviewStreamValue(selectedVideoStream)
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
            audioPreviewEnabled ? audioLevelMeter.phase : nil,
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
            audioLevelMeter.phase == .failed ? audioLevelMeter.status : nil,
        ]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

enum AppPreviewControlAvailability {
    static let unsupportedLocalPreviewHelp = "This control is unavailable in the single-stream local device preview."

    static var returnBlendEnabledInLocalPreview: Bool { false }
    static var visibleStreamsEnabledInLocalPreview: Bool { false }
    static var selectedStreamEnabledInLocalPreview: Bool { false }
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
        guard [.supervisorRunning, .awaitingEvidence, .live].contains(sessionState) else {
            return false
        }
        return phase == .degraded || phase == .failed
    }
}

struct AppPreviewReceiverView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    @Bindable var previewState: AppPreviewReceiverState

    var body: some View {
        GroupBox("Preview Controls") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Audio Preview", isOn: $previewState.audioPreviewEnabled)
                Toggle("Video Preview", isOn: $previewState.videoPreviewEnabled)
                Toggle("Safe frame", isOn: $previewState.showSafeFrame)

                Slider(value: $previewState.monitorGain, in: 0...1) {
                    Text("Monitor gain")
                }
                .disabled(!previewState.previewIsActive)
                .help(previewControlHelp)
                Slider(value: $previewState.remoteReturnBlend, in: 0...1) {
                    Text("Return blend")
                }
                .disabled(!AppPreviewControlAvailability.returnBlendEnabledInLocalPreview)
                .help(AppPreviewControlAvailability.unsupportedLocalPreviewHelp)
                Slider(value: $previewState.videoScale, in: 0.5...2) {
                    Text("Video scale")
                }

                HStack {
                    IntField("Visible streams", value: appPreviewIntBinding(\.visibleStreams, state: previewState))
                        .disabled(!AppPreviewControlAvailability.visibleStreamsEnabledInLocalPreview)
                        .help(AppPreviewControlAvailability.unsupportedLocalPreviewHelp)
                    IntField("Selected stream", value: appPreviewIntBinding(\.selectedVideoStream, state: previewState))
                        .disabled(!AppPreviewControlAvailability.selectedStreamEnabledInLocalPreview)
                        .help(AppPreviewControlAvailability.unsupportedLocalPreviewHelp)
                }

            }
            .frame(maxWidth: 560, alignment: .leading)
        }

        GroupBox("Preview Routing") {
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
                AppReadableMetric(label: "Local preview", value: previewState.verifiedReceiverStatus)
            }
        }
    }

    private var videoFormatSummary: String {
        let fields = operatorSurface.directPeerCommandFields
        return "\(fields.videoWidth)x\(fields.videoHeight) \(fields.videoFrameRate)fps \(fields.videoPixelFormat)"
    }

    private var videoOutputStatus: String {
        BlackmagicOutputBoundary.localPreviewFallback().outputLimitationSummary
    }

    private var previewControlHelp: String {
        previewState.previewIsActive ? "Updates the active local preview." : "Open Local Preview Window to apply this control."
    }

}

struct AppReceiverWindowView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    @Bindable var previewState: AppPreviewReceiverState
    let executionPhase: AppExecutionPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                receiverCanvas
                audioMeters
            }
            receiverStatus
        }
        .padding()
        .navigationTitle("Local Device Preview")
        .onAppear {
            restartReceiverPreview()
        }
        .onDisappear {
            previewState.stopReceiverPreview()
        }
        .onChange(of: operatorSurface.inventory.selection.audioInputUID) { _, _ in
            restartReceiverPreview()
        }
        .onChange(of: operatorSurface.inventory.selection.videoDeviceID) { _, _ in
            restartReceiverPreview()
        }
        .onChange(of: previewState.audioPreviewEnabled) { _, _ in
            restartReceiverPreview()
        }
        .onChange(of: previewState.videoPreviewEnabled) { _, _ in
            restartReceiverPreview()
        }
    }

    private var receiverCanvas: some View {
        ZStack {
            Rectangle()
                .fill(.black)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
            if previewState.videoPreviewEnabled {
                AppVideoPreviewLayerView(controller: previewState.videoPreviewController)
                    .overlay(alignment: .bottomLeading) {
                        Text(videoSubtitle)
                            .font(.caption)
                            .padding(8)
                            .background(.black.opacity(0.55))
                            .foregroundStyle(.white)
                    }
            } else {
                Label("Video Preview Off", systemImage: "video.slash")
                    .foregroundStyle(.secondary)
            }
            if previewState.showSafeFrame {
                Rectangle()
                    .stroke(.white.opacity(0.65), lineWidth: 1)
                    .padding(28)
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(
            minWidth: 320 * CGFloat(previewState.videoScale),
            idealWidth: 520 * CGFloat(previewState.videoScale),
            maxWidth: .infinity
        )
        .clipped()
    }

    private var audioMeters: some View {
        GroupBox("Audio Preview") {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Toggle("Enabled", isOn: $previewState.audioPreviewEnabled)

                if AppChannelMeterVisibilityPolicy.showsMeters(
                    phase: executionPhase,
                    audioPreviewEnabled: previewState.audioPreviewEnabled,
                    audioPreviewPhase: previewState.audioLevelMeter.phase
                ) {
                    AppChannelMeterView(
                        levels: previewState.audioLevelMeter.levels,
                        visibleChannels: 8
                    )
                    .frame(height: 120)
                } else {
                    AppChannelMeterEmptyStateView()
                }

                HStack {
                    Text("Monitor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $previewState.monitorGain, in: 0...1)
                }

                Text(previewState.audioLevelMeter.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 220)
        }
    }

    private var receiverStatus: some View {
        GroupBox("Local Preview Status") {
            MetricsGrid {
                AppReadableMetric(label: "Status", value: previewState.verifiedReceiverStatus)
                AppReadableMetric(label: "Video preview", value: previewState.videoPreviewController.status)
                AppReadableMetric(
                    label: "Input",
                    value: operatorSurface.inventory.selection.audioInputUID ?? "none",
                    monospaced: true
                )
                AppReadableMetric(
                    label: "Output",
                    value: operatorSurface.inventory.selection.audioOutputUID ?? "none",
                    monospaced: true
                )
                AppReadableMetric(label: "Video output", value: videoOutputStatus)
                AppReadableMetric(label: "Video", value: videoTitle)
            }
        }
    }

    private var videoOutputStatus: String {
        BlackmagicOutputBoundary.localPreviewFallback().outputLimitationSummary
    }

    private var videoTitle: String {
        guard let id = operatorSurface.inventory.selection.videoDeviceID else {
            return "No video device selected"
        }
        return operatorSurface.inventory.videoDevices.first { $0.uniqueId == id }?.label ?? id
    }

    private var videoSubtitle: String {
        let fields = operatorSurface.directPeerCommandFields
        return "Stream \(previewState.selectedVideoStream), \(fields.videoWidth)x\(fields.videoHeight)"
    }

    private func restartReceiverPreview() {
        previewState.startReceiverPreview(
            audioInputUID: operatorSurface.inventory.selection.audioInputUID,
            videoDeviceID: operatorSurface.inventory.selection.videoDeviceID
        )
    }
}

struct AppChannelMeterEmptyStateView: View {
    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "waveform")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("No audio session active")
                .font(.caption.weight(.semibold))
            Text("Meters appear during an active session.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No audio session active. Meters appear during an active session.")
    }
}

enum AppChannelMeterVisibilityPolicy {
    static func showsMeters(
        phase: AppExecutionPhase,
        audioPreviewEnabled: Bool,
        audioPreviewPhase: AppPreviewReceiverState.Phase = .idle
    ) -> Bool {
        audioPreviewEnabled && (phase == .supervisorRunning || audioPreviewPhase == .active)
    }
}
