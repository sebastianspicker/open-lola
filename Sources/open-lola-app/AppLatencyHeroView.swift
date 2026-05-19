import OpenLolaCore
import SwiftUI

// MARK: - Latency Hero Display

/// Three-metric hero display: audio latency, packet loss, jitter.
/// Uses large monospaced numbers with threshold status indicators.
struct AppLatencyHeroView: View {
    let audioLatencyMs: Double?
    let packetLossPercent: Double?
    let jitterMs: Double?
    let evidenceStatusMessage: String?

    private enum Thresholds {
        static let comparisonTolerance: Double = 0.01
        static let latencyTargetMs: Double = 5
        static let latencyAcceptableMs: Double = 15
        static let packetLossTargetPercent: Double = 0.01
        static let packetLossAcceptablePercent: Double = 1.0
        static let jitterTargetMs: Double = 1
        static let jitterAcceptableMs: Double = 5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                heroCell(
                    value: audioLatencyMs.map { String(format: "%.1f", $0) } ?? "—",
                    unit: "ms",
                    label: "Audio Latency",
                    status: latencyStatus(audioLatencyMs),
                    statusLabel: latencyStatusLabel(audioLatencyMs)
                )
                AppVerticalDivider(verticalPadding: AppSpacing.m)
                heroCell(
                    value: packetLossPercent.map { String(format: "%.1f", $0) } ?? "—",
                    unit: "%",
                    label: "Packet Loss",
                    status: lossStatus(packetLossPercent),
                    statusLabel: lossStatusLabel(packetLossPercent)
                )
                AppVerticalDivider(verticalPadding: AppSpacing.m)
                heroCell(
                    value: jitterMs.map { String(format: "%.1f", $0) } ?? "—",
                    unit: "ms",
                    label: "Jitter",
                    status: jitterStatus(jitterMs),
                    statusLabel: jitterStatusLabel(jitterMs)
                )
            }
            if let evidenceStatusMessage {
                AppWarningBanner(
                    title: "Partial latency evidence",
                    message: evidenceStatusMessage
                )
                .padding(.horizontal, AppSpacing.m)
                .padding(.bottom, AppSpacing.m)
            }
        }
        .background(AppDesignSystem.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func heroCell(
        value: String,
        unit: String,
        label: String,
        status: Color,
        statusLabel: String
    ) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.latencyHero)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.25), value: value)
                Text(unit)
                    .font(.title3.weight(.light))
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Circle()
                    .fill(status)
                    .frame(width: 10, height: 10)
                    .accessibilityLabel("Status: \(statusLabel)")
                Text(statusLabel)
                    .font(.caption2)
                    .foregroundStyle(status)
            }
        }
        .frame(minWidth: 200, maxWidth: .infinity)
        .padding(.vertical, AppSpacing.l)
        .padding(.horizontal, AppSpacing.m)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value) \(unit). Status: \(statusLabel).")
    }

    // MARK: - Threshold helpers

    private func latencyStatus(_ ms: Double?) -> Color {
        guard let ms else { return .secondary }
        if isWithin(ms, Thresholds.latencyTargetMs) { return AppDesignSystem.stateLive }
        if isWithin(ms, Thresholds.latencyAcceptableMs) { return AppDesignSystem.meterCaution }
        return AppDesignSystem.stateError
    }

    private func latencyStatusLabel(_ ms: Double?) -> String {
        guard let ms else { return "no data" }
        if isWithin(ms, Thresholds.latencyTargetMs) { return "target met" }
        if isWithin(ms, Thresholds.latencyAcceptableMs) { return "acceptable" }
        return "above target"
    }

    private func lossStatus(_ pct: Double?) -> Color {
        guard let pct else { return .secondary }
        if isWithin(pct, Thresholds.packetLossTargetPercent) { return AppDesignSystem.stateLive }
        if isWithin(pct, Thresholds.packetLossAcceptablePercent) { return AppDesignSystem.meterCaution }
        return AppDesignSystem.stateError
    }

    private func lossStatusLabel(_ pct: Double?) -> String {
        guard let pct else { return "no data" }
        if isWithin(pct, Thresholds.packetLossTargetPercent) { return "nominal" }
        if isWithin(pct, Thresholds.packetLossAcceptablePercent) { return "minor loss" }
        return "high loss"
    }

    private func jitterStatus(_ ms: Double?) -> Color {
        guard let ms else { return .secondary }
        if isWithin(ms, Thresholds.jitterTargetMs) { return AppDesignSystem.stateLive }
        if isWithin(ms, Thresholds.jitterAcceptableMs) { return AppDesignSystem.meterCaution }
        return AppDesignSystem.stateError
    }

    private func jitterStatusLabel(_ ms: Double?) -> String {
        guard let ms else { return "no data" }
        if isWithin(ms, Thresholds.jitterTargetMs) { return "stable" }
        if isWithin(ms, Thresholds.jitterAcceptableMs) { return "moderate" }
        return "unstable"
    }

    private func isWithin(_ value: Double, _ threshold: Double) -> Bool {
        value <= threshold + Thresholds.comparisonTolerance
    }
}
