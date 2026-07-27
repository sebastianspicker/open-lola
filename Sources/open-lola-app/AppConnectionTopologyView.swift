// Renders AppConnectionTopologyView in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import OpenLolaCore
import SwiftUI

// MARK: - P2P Connection Topology (Signal Path)

/// Instrument-style signal path: endpoint cards, weighted media tracks, timing gate.
/// Animated data-flow when the topology animation policy allows it.
struct AppConnectionTopologyView: View {
    private enum Layout {
        static let endpointWidth: CGFloat = 148
        static let pathMinHeight: CGFloat = 96
        static let trackGap: CGFloat = 14
        static let audioH: CGFloat = 4
        static let secondaryH: CGFloat = 2
        static let flowDot: CGFloat = 5
        static let labelW: CGFloat = 88
        static let gate: CGFloat = 36
        static let glow = 0.22
        static let videoOp = 0.45
        static let controlOp = 0.28
        static let metricsOp = 0.22
        static let radius: CGFloat = 10
    }

    private enum Animation {
        static let flowSeconds: Double = 1.8
        static let stopSeconds: Double = 0.2
        static let dotCount = 4
    }

    let localPeer: String
    let remotePeer: String
    let localHost: String
    let remoteHost: String
    let channelCount: Int
    let sessionMode: NativeAppShellSessionMode
    let sessionState: AppSessionState
    let executionPhase: AppExecutionPhase
    let packetEvidenceAvailable: Bool
    var localDeviceLabel: String? = nil
    var remoteDeviceLabel: String? = nil
    var profileCaption: String? = nil
    var videoEnabled: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flowOffset: CGFloat = 0
    @State private var flowTrackWidth: CGFloat = 0
    @State private var isAnimating = false

    private var shouldAnimateFlow: Bool {
        AppConnectionTopologyAnimationPolicy.shouldAnimate(
            phase: executionPhase,
            reduceMotion: reduceMotion,
            packetEvidenceAvailable: packetEvidenceAvailable
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            if let profileCaption {
                HStack(alignment: .firstTextBaseline) {
                    Text("Signal path")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: AppSpacing.xs)
                    Text(profileCaption)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            HStack(alignment: .center, spacing: AppSpacing.xs) {
                TopologyEndpointCard(
                    role: "Local",
                    hostName: localPeer,
                    address: localHost,
                    deviceLabel: localDeviceLabel,
                    isLocal: true
                )
                .frame(width: Layout.endpointWidth)

                signalPathStage
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Layout.pathMinHeight)

                TopologyEndpointCard(
                    role: "Remote",
                    hostName: remotePeer,
                    address: remoteHost,
                    deviceLabel: remoteDeviceLabel,
                    isLocal: false
                )
                .frame(width: Layout.endpointWidth)
            }
        }
        .padding(AppSpacing.m)
        .background(AppDesignSystem.panelBackground, in: RoundedRectangle(cornerRadius: Layout.radius))
        .overlay {
            RoundedRectangle(cornerRadius: Layout.radius)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
        .onAppear { updateAnimationState(trackWidth: flowTrackWidth) }
        .onChange(of: executionPhase) { _, _ in updateAnimationState(trackWidth: flowTrackWidth) }
        .onChange(of: packetEvidenceAvailable) { _, _ in updateAnimationState(trackWidth: flowTrackWidth) }
        .onChange(of: reduceMotion) { _, _ in updateAnimationState(trackWidth: flowTrackWidth) }
        .onDisappear { stopAnimation() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(topologyAccessibilityLabel)
    }

    // MARK: - Signal path stage

    private var signalPathStage: some View {
        ZStack {
            VStack(spacing: Layout.trackGap) {
                pathRow(
                    "Audio · \(channelCount) ch",
                    height: Layout.audioH,
                    color: AppDesignSystem.interactionAccent,
                    opacity: 1,
                    glow: true
                )
                pathRow(
                    videoEnabled ? "Video" : "Video · off",
                    height: Layout.secondaryH,
                    color: .secondary,
                    opacity: videoEnabled ? Layout.videoOp : Layout.controlOp,
                    glow: false,
                    animate: videoEnabled
                )
                pathRow(
                    "Control",
                    height: Layout.secondaryH,
                    color: .secondary,
                    opacity: Layout.controlOp,
                    glow: false
                )
                if sessionMode == .directMacPeer {
                    pathRow(
                        "Metrics",
                        height: Layout.secondaryH,
                        color: .secondary,
                        opacity: Layout.metricsOp,
                        glow: false
                    )
                }
            }
            .padding(.horizontal, AppSpacing.xs)

            timingGate
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var timingGate: some View {
        ZStack {
            Circle()
                .fill(AppDesignSystem.appBackground)
                .frame(width: Layout.gate, height: Layout.gate)
                .shadow(color: AppDesignSystem.interactionAccent.opacity(Layout.glow), radius: 10)
            Circle()
                .stroke(AppDesignSystem.interactionAccent.opacity(0.55), lineWidth: 2)
                .frame(width: Layout.gate, height: Layout.gate)
            HStack(spacing: 4) {
                Capsule().fill(Color.primary.opacity(0.9)).frame(width: 2, height: 14)
                Capsule().fill(Color.primary.opacity(0.9)).frame(width: 2, height: 14)
            }
        }
    }

    private var topologyAccessibilityLabel: Text {
        Text(
            "Topology: \(localPeer) on \(localHost) to \(remotePeer) on \(remoteHost), " +
            "\(channelCount) audio channels, state \(sessionState.rawValue)."
        )
    }

    private func pathRow(
        _ label: String,
        height: CGFloat,
        color: Color,
        opacity: Double,
        glow: Bool,
        animate: Bool = true
    ) -> some View {
        HStack(spacing: AppSpacing.s) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppDesignSystem.elevatedBackground)
                        .frame(height: height)
                    Capsule()
                        .fill(color.opacity(opacity))
                        .frame(height: height)
                        .shadow(color: glow ? color.opacity(Layout.glow) : .clear, radius: glow ? 8 : 0)
                    if isAnimating, animate {
                        // swiftlint:disable:next identifier_name
                        ForEach(0..<Animation.dotCount, id: \.self) { i in
                            Circle()
                                .fill(color.opacity(max(opacity, 0.7)))
                                .frame(width: Layout.flowDot, height: Layout.flowDot)
                                .offset(x: dotOffset(index: i, width: geo.size.width))
                                .offset(y: (height - Layout.flowDot) / 2)
                        }
                    }
                }
                .frame(height: max(height, Layout.flowDot))
                .clipped()
                .onAppear { updateFlowTrackWidth(geo.size.width) }
                .onChange(of: geo.size.width) { _, _ in updateFlowTrackWidth(geo.size.width) }
            }
            .frame(height: max(height, Layout.flowDot) + 2)

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color.opacity(opacity < 0.5 ? 0.7 : 1))
                .frame(minWidth: Layout.labelW, alignment: .trailing)
                .lineLimit(1)
        }
    }

    private func dotOffset(index: Int, width: CGFloat) -> CGFloat {
        guard width > Layout.flowDot else { return 0 }
        let spacing = width / CGFloat(Animation.dotCount)
        return (CGFloat(index) * spacing + flowOffset).truncatingRemainder(dividingBy: width)
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
        guard trackWidth > 0, !isAnimating else { return }
        restartAnimation(trackWidth: trackWidth)
    }

    private func restartAnimation(trackWidth: CGFloat) {
        guard shouldAnimateFlow else { return }
        isAnimating = true
        flowOffset = 0
        withAnimation(.linear(duration: Animation.flowSeconds).repeatForever(autoreverses: false)) {
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
        withAnimation(.easeOut(duration: Animation.stopSeconds)) {
            flowOffset = 0
        } completion: {
            isAnimating = false
        }
    }
}

// MARK: - Endpoint card

private struct TopologyEndpointCard: View {
    let role: String
    let hostName: String
    let address: String
    let deviceLabel: String?
    let isLocal: Bool

    var body: some View {
        let peerRole = isLocal ? "Local peer" : "Remote peer"
        let hostRole = isLocal ? "Local host" : "Remote host"

        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(role.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.tertiary)

            Text(hostName)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(AppConnectionTopologyValuePolicy.fullValueHelp(role: peerRole, value: hostName))
                .accessibilityLabel(AppConnectionTopologyValuePolicy.accessibilityLabel(role: peerRole, value: hostName))

            Text(address)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(AppConnectionTopologyValuePolicy.fullValueHelp(role: hostRole, value: address))
                .accessibilityLabel(AppConnectionTopologyValuePolicy.accessibilityLabel(role: hostRole, value: address))

            if let deviceLabel, !deviceLabel.isEmpty {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppDesignSystem.interactionAccent)
                        .frame(width: 6, height: 6)
                    Text(deviceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.top, AppSpacing.xxs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.s)
        .background(AppDesignSystem.elevatedBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
    }
}

// MARK: - Policies

enum AppConnectionTopologyAnimationPolicy {
    static func hasPacketEvidence(_ captureReport: LoLaCompatibilityCaptureReport?) -> Bool {
        (captureReport?.summary.packetCount ?? 0) > 0
    }

    static func shouldAnimate(
        phase: AppExecutionPhase,
        reduceMotion: Bool,
        packetEvidenceAvailable: Bool
    ) -> Bool {
        phase == .supervisorRunning && packetEvidenceAvailable && !reduceMotion
    }
}

enum AppConnectionTopologyValuePolicy {
    static func fullValueHelp(role: String, value: String) -> String {
        "\(role): \(value)"
    }

    static func accessibilityLabel(role: String, value: String) -> String {
        "\(role): \(value)"
    }
}
