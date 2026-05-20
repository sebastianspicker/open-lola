import OpenLolaCore
import SwiftUI

// MARK: - P2P Connection Topology

/// Visual diagram showing the peer-to-peer connection topology.
/// Animated data-flow arrows when the session is live.
struct AppConnectionTopologyView: View {
    private enum Layout {
        static let peerNodeWidth: CGFloat = 120
        static let iconWidth: CGFloat = 16
        static let trackHeight: CGFloat = 2
        static let flowDotSize: CGFloat = 5
        static let flowDotYOffset: CGFloat = -1.5
        static let arrowRowHeight: CGFloat = 8
        static let labelMinWidth: CGFloat = 60
    }

    private enum Animation {
        static let flowDurationSeconds: Double = 1.8
        static let stopDurationSeconds: Double = 0.2
        static let flowDotCount = 4
    }

    let localPeer: String
    let remotePeer: String
    let localHost: String
    let remoteHost: String
    let channelCount: Int
    let sessionMode: NativeAppShellSessionMode
    let sessionState: AppSessionState
    let executionPhase: AppExecutionPhase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flowOffset: CGFloat = 0
    @State private var flowTrackWidth: CGFloat = 0
    @State private var isAnimating = false

    private var isLive: Bool { sessionState == .live }
    private var shouldAnimateFlow: Bool {
        AppConnectionTopologyAnimationPolicy.shouldAnimate(
            phase: executionPhase,
            reduceMotion: reduceMotion
        )
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            peerNode(label: localPeer, host: localHost, isLocal: true)

            channelArrows
                .frame(maxWidth: .infinity)

            peerNode(label: remotePeer, host: remoteHost, isLocal: false)
        }
        .padding(AppSpacing.m)
        .background(AppDesignSystem.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
        .onAppear { updateAnimationState(trackWidth: flowTrackWidth) }
        .onChange(of: executionPhase) { _, _ in updateAnimationState(trackWidth: flowTrackWidth) }
        .onChange(of: reduceMotion) { _, _ in updateAnimationState(trackWidth: flowTrackWidth) }
        .onDisappear { stopAnimation() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(topologyAccessibilityLabel)
    }

    // MARK: - Peer node

    @ViewBuilder
    private func peerNode(label: String, host: String, isLocal: Bool) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            Image(systemName: "desktopcomputer")
                .font(.title)
                .foregroundStyle(isLive ? AppDesignSystem.stateLive : .secondary)
            Text(label)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.tail)
            Text(host)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(host)
        }
        .frame(width: Layout.peerNodeWidth)
    }

    // MARK: - Channel arrows

    private var channelArrows: some View {
        VStack(spacing: AppSpacing.xxs + 2) {
            arrowRow(label: "audio ×\(channelCount)", icon: "waveform", color: AppDesignSystem.stateLive)
            arrowRow(label: "video", icon: "video.fill", color: .blue)
            arrowRow(label: "control", icon: "slider.horizontal.3", color: AppDesignSystem.stateArmed)
            if sessionMode == .directMacPeer {
                arrowRow(label: "metrics", icon: "chart.line.uptrend.xyaxis", color: .secondary)
            }
        }
    }

    private var topologyAccessibilityLabel: Text {
        Text(
            "Topology: \(localPeer) on \(localHost) to \(remotePeer) on \(remoteHost), " +
            "\(channelCount) audio channels, state \(sessionState.rawValue)."
        )
    }

    @ViewBuilder
    private func arrowRow(label: String, icon: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color.opacity(isLive ? 1.0 : 0.45))
                .frame(width: Layout.iconWidth)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Rectangle()
                        .fill(color.opacity(0.15))
                        .frame(height: Layout.trackHeight)
                    // Animated flow dots
                    if isAnimating {
                        ForEach(0..<Animation.flowDotCount, id: \.self) { i in
                            Circle()
                                .fill(color)
                                .frame(width: Layout.flowDotSize, height: Layout.flowDotSize)
                                .offset(x: dotOffset(index: i, width: geo.size.width))
                                .offset(y: Layout.flowDotYOffset)
                        }
                    }
                }
                .frame(height: Layout.trackHeight)
                .clipped()
                .onAppear { updateFlowTrackWidth(geo.size.width) }
                .onChange(of: geo.size.width) { _, _ in updateFlowTrackWidth(geo.size.width) }
            }
            .frame(height: Layout.arrowRowHeight)

            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(color.opacity(isLive ? 1.0 : 0.45))
                .frame(minWidth: Layout.labelMinWidth, alignment: .trailing)
        }
    }

    private func dotOffset(index: Int, width: CGFloat) -> CGFloat {
        guard width > Layout.flowDotSize else { return 0 }
        let spacing = width / CGFloat(Animation.flowDotCount)
        let base = CGFloat(index) * spacing
        let adjusted = base + flowOffset
        return adjusted.truncatingRemainder(dividingBy: width)
    }

    private func updateFlowTrackWidth(_ width: CGFloat) {
        guard width > 0 else { return }
        guard flowTrackWidth != width else {
            updateAnimationState(trackWidth: width)
            return
        }
        flowTrackWidth = width
        restartAnimation(trackWidth: width)
    }

    private func updateAnimationState(trackWidth: CGFloat) {
        guard shouldAnimateFlow else {
            stopAnimation()
            return
        }
        guard trackWidth > 0 else { return }
        guard !isAnimating else { return }
        restartAnimation(trackWidth: trackWidth)
    }

    private func restartAnimation(trackWidth: CGFloat) {
        guard shouldAnimateFlow else { return }
        isAnimating = true
        flowOffset = 0
        withAnimation(.linear(duration: Animation.flowDurationSeconds).repeatForever(autoreverses: false)) {
            flowOffset = trackWidth
        }
    }

    private func stopAnimation() {
        guard isAnimating || flowOffset != 0 else {
            isAnimating = false
            return
        }
        guard !reduceMotion else {
            flowOffset = 0
            isAnimating = false
            return
        }
        withAnimation(.easeOut(duration: Animation.stopDurationSeconds)) {
            flowOffset = 0
        } completion: {
            isAnimating = false
        }
    }
}

enum AppConnectionTopologyAnimationPolicy {
    static func shouldAnimate(phase: AppExecutionPhase, reduceMotion: Bool) -> Bool {
        phase == .supervisorRunning && !reduceMotion
    }
}
