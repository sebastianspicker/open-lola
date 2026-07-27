// Renders AppLatencyHeroView in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import OpenLolaCore
import SwiftUI

// MARK: - Latency Instrument

/// Latency instrument: worst-peer audio p99 as the primary mono readout, with
/// packet loss and jitter as supporting metrics. Measured evidence only —
/// never presented as live telemetry.
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

    private enum Layout {
        static let accentBarWidth: CGFloat = 3
        static let secondaryValueSize: CGFloat = 20
        static let instrumentMinHeight: CGFloat = 132
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            instrumentCard
            provenanceBanner
            if let evidenceStatusMessage {
                AppWarningBanner(
                    title: "Partial latency evidence",
                    message: evidenceStatusMessage
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Audio latency instrument")
    }

    // MARK: - Instrument card

    private var instrumentCard: some View {
        ViewThatFits(in: .horizontal) {
            instrumentHorizontal
            instrumentStacked
        }
        .frame(maxWidth: .infinity, minHeight: Layout.instrumentMinHeight, alignment: .leading)
        .padding(.leading, showsTargetMetAccent ? AppSpacing.s : AppSpacing.m)
        .padding(.trailing, AppSpacing.m)
        .padding(.vertical, AppSpacing.m)
        .background(AppDesignSystem.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            if showsTargetMetAccent {
                Capsule()
                    .fill(AppDesignSystem.stateLive)
                    .frame(width: Layout.accentBarWidth)
                    .padding(.vertical, AppSpacing.m)
                    .padding(.leading, 1)
                    .accessibilityHidden(true)
            }
        }
    }

    private var instrumentHorizontal: some View {
        HStack(alignment: .center, spacing: 0) {
            primaryLatency
                .frame(maxWidth: .infinity, alignment: .leading)
            AppVerticalDivider(verticalPadding: AppSpacing.xs)
            secondaryMetrics
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, AppSpacing.m)
        }
    }

    private var instrumentStacked: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            primaryLatency
            secondaryMetrics
        }
    }

    // MARK: - Primary latency

    private var primaryLatency: some View {
        let status = latencyStatusLabel(audioLatencyMs)
        let statusColor = latencyStatus(audioLatencyMs)
        let valueText = formatted(audioLatencyMs) ?? "N/A"
        let unit = audioLatencyMs == nil ? "" : "ms"

        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Text(AppLatencyHeroMetrics.audioLatencyMetricLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                statusChip(label: status, tone: statusColor)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(valueText)
                    .font(.latencyHero)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Text(primaryCaption)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(AppLatencyHeroMetrics.audioLatencyMetricLabel): "
                + (unit.isEmpty ? valueText : "\(valueText) \(unit)")
                + ". Status: \(status)."
        )
    }

    private var primaryCaption: String {
        audioLatencyMs != nil
            ? "Supervisor report maximum · not live meters"
            : "No completed runtime report is loaded"
    }

    // MARK: - Secondary metrics

    private var secondaryMetrics: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            miniMetric(
                label: "Packet loss",
                value: formatted(packetLossPercent) ?? "N/A",
                unit: packetLossPercent == nil ? "" : "%",
                hint: lossHint(packetLossPercent),
                tone: lossStatus(packetLossPercent),
                statusLabel: lossStatusLabel(packetLossPercent)
            )
            miniMetric(
                label: "Jitter p99",
                value: formatted(jitterMs) ?? "N/A",
                unit: jitterMs == nil ? "" : "ms",
                hint: jitterHint(jitterMs),
                tone: jitterStatus(jitterMs),
                statusLabel: jitterStatusLabel(jitterMs)
            )
        }
    }

    private func miniMetric(
        label: String,
        value: String,
        unit: String,
        hint: String,
        tone: Color,
        statusLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer(minLength: AppSpacing.xs)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: Layout.secondaryValueSize, weight: .bold, design: .monospaced))
                        .foregroundStyle(tone)
                        .monospacedDigit()
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text(hint)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(label): "
                + (unit.isEmpty ? value : "\(value) \(unit)")
                + ". \(hint). Status: \(statusLabel)."
        )
    }

    // MARK: - Provenance banner (outside instrument card)

    private var provenanceBanner: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            Text(hasRecordedMetrics ? "Recorded evidence" : "Not measured")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(hasRecordedMetrics ? AppDesignSystem.stateWarning : .secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    hasRecordedMetrics
                        ? AppDesignSystem.stateWarningBackground
                        : Color.secondary.opacity(0.12),
                    in: Capsule()
                )
            Text(provenanceDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Metric provenance: "
                + (hasRecordedMetrics ? "Recorded evidence. " : "Not measured. ")
                + provenanceDetail
        )
    }

    private var hasRecordedMetrics: Bool {
        audioLatencyMs != nil || packetLossPercent != nil || jitterMs != nil
    }

    private var provenanceDetail: String {
        if hasRecordedMetrics {
            return "\(AppLatencyHeroMetrics.audioLatencyMetricProvenance). "
                + "Local meters are preview-only and do not prove remote receive."
        }
        return "No completed runtime report is loaded; source checks are not substituted."
    }

    /// Green leading accent only when latency target is met with a measured value.
    private var showsTargetMetAccent: Bool {
        guard let audioLatencyMs else { return false }
        return isWithin(audioLatencyMs, Thresholds.latencyTargetMs)
    }

    private func statusChip(label: String, tone: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tone)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(tone.opacity(0.14), in: Capsule())
            .overlay { Capsule().stroke(tone.opacity(0.25), lineWidth: 1) }
            .accessibilityHidden(true)
    }

    private func formatted(_ value: Double?) -> String? {
        value.map { String(format: "%.1f", $0) }
    }
}

// MARK: - Threshold helpers

private extension AppLatencyHeroView {
    func latencyStatus(_ milliseconds: Double?) -> Color {
        bandColor(milliseconds, target: Thresholds.latencyTargetMs, acceptable: Thresholds.latencyAcceptableMs)
    }

    func latencyStatusLabel(_ milliseconds: Double?) -> String {
        bandLabel(milliseconds, target: Thresholds.latencyTargetMs, acceptable: Thresholds.latencyAcceptableMs,
                  met: "target met", ok: "acceptable", high: "above target")
    }

    func lossStatus(_ pct: Double?) -> Color {
        bandColor(pct, target: Thresholds.packetLossTargetPercent, acceptable: Thresholds.packetLossAcceptablePercent)
    }

    func lossStatusLabel(_ pct: Double?) -> String {
        bandLabel(pct, target: Thresholds.packetLossTargetPercent, acceptable: Thresholds.packetLossAcceptablePercent,
                  met: "nominal", ok: "minor loss", high: "high loss")
    }

    func lossHint(_ pct: Double?) -> String {
        guard let pct else { return "No measured loss data" }
        if isWithin(pct, Thresholds.packetLossTargetPercent) {
            return "Nominal across loaded peer reports"
        }
        return lossStatusLabel(pct)
    }

    func jitterStatus(_ milliseconds: Double?) -> Color {
        bandColor(milliseconds, target: Thresholds.jitterTargetMs, acceptable: Thresholds.jitterAcceptableMs)
    }

    func jitterStatusLabel(_ milliseconds: Double?) -> String {
        bandLabel(milliseconds, target: Thresholds.jitterTargetMs, acceptable: Thresholds.jitterAcceptableMs,
                  met: "stable", ok: "moderate", high: "unstable")
    }

    func jitterHint(_ milliseconds: Double?) -> String {
        guard milliseconds != nil else { return "No measured jitter data" }
        return jitterStatusLabel(milliseconds)
    }

    func bandColor(_ value: Double?, target: Double, acceptable: Double) -> Color {
        guard let value else { return .secondary }
        if isWithin(value, target) { return AppDesignSystem.stateLive }
        if isWithin(value, acceptable) { return AppDesignSystem.stateWarning }
        return AppDesignSystem.stateError
    }

    func bandLabel(
        _ value: Double?,
        target: Double,
        acceptable: Double,
        met: String,
        ok: String,
        high: String
    ) -> String {
        guard let value else { return "no data" }
        if isWithin(value, target) { return met }
        if isWithin(value, acceptable) { return ok }
        return high
    }

    func isWithin(_ value: Double, _ threshold: Double) -> Bool {
        value <= threshold + Thresholds.comparisonTolerance
    }
}
