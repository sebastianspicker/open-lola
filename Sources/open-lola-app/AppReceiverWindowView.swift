// Renders AppReceiverWindowView in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import OpenLolaCore
import SwiftUI

struct AppReceiverWindowView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    @Bindable var previewState: AppPreviewReceiverState
    let executionPhase: AppExecutionPhase

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AppSpacing.m) {
                    receiverCanvas
                    audioMeters
                }
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    receiverCanvas
                    audioMeters
                }
            }
            receiverStatus
        }
        .padding(AppSpacing.l)
        .background(AppDesignSystem.appBackground)
        .navigationTitle("Local Device Preview")
        .onAppear {
            previewState.markPreviewWindowVisible()
            restartReceiverPreview()
        }
        .onDisappear {
            previewState.markPreviewWindowHidden()
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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
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
                    AppChannelMeterEmptyStateView(content: AppChannelMeterEmptyStatePolicy.content(
                        audioPreviewEnabled: previewState.audioPreviewEnabled,
                        audioPreviewPhase: previewState.audioLevelMeter.phase,
                        status: previewState.audioLevelMeter.status
                    ))
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
        .appConsoleGroupBoxStyle()
    }

    private var receiverStatus: some View {
        DisclosureGroup("Preview details") {
            MetricsGrid {
                AppReadableMetric(label: "Window", value: previewState.previewWindowStatus)
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
            .padding(.top, AppSpacing.s)
        }
    }

    private var videoOutputStatus: String {
        AppPreviewVideoOutputStatusPolicy.status(inventory: operatorSurface.inventory)
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

enum AppPreviewVideoOutputStatusPolicy {
    static func status(inventory: NativeAppShellLocalMediaInventory) -> String {
        let selectedDevice = inventory.videoDevices.first {
            $0.uniqueId == inventory.selection.videoDeviceID
        }
        return status(
            boundary: BlackmagicOutputBoundary.detect(),
            selectedVideoDevice: selectedDevice
        )
    }

    static func status(
        boundary: BlackmagicOutputBoundaryReport,
        selectedVideoDevice: NativeAppShellVideoDeviceOption?
    ) -> String {
        guard !boundary.hasPhysicalOutputEvidence else {
            return boundary.outputLimitationSummary
        }
        guard let selectedVideoDevice, isBlackmagicDevice(selectedVideoDevice) else {
            return boundary.outputLimitationSummary
        }
        return "PARTIAL: Blackmagic video device selected; "
            + "DeckLink output remains unverified and local preview/report metrics only."
    }

    private static func isBlackmagicDevice(_ device: NativeAppShellVideoDeviceOption) -> Bool {
        device.sourcePolicy == .blackmagicFirstAvFoundationFallback
            || device.manufacturer.localizedCaseInsensitiveContains("blackmagic")
            || device.label.localizedCaseInsensitiveContains("blackmagic")
    }
}
