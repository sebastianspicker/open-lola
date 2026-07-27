// Supplies packet-monitor presentation helpers, keeping display calculations out of the monitor view body.
import Foundation
import OpenLolaCore
import SwiftUI

extension AppPacketMonitorView {
    func packetRowActionButtons(_ row: NativeAppPacketMonitorRow) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Button {
                copyToPasteboard(AppPacketMonitorRowDetailState.copyText(row), target: "packet row \(row.id)")
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .appCompactToolButtonHitTarget()
            .accessibilityLabel("Copy packet row \(row.id)")
            .help("Copy full packet row")

            Button {
                selectedPacketRowID = row.id
            } label: {
                Image(systemName: "sidebar.right")
            }
            .buttonStyle(.plain)
            .appCompactToolButtonHitTarget()
            .accessibilityLabel("Show details for packet row \(row.id)")
            .help("Show full packet row details")
        }
    }

    func packetRowsFailure(_ message: String) -> some View {
        AppWarningBanner(
            title: "Packet Row Error",
            message: message,
            detail: "This is different from an empty packet filter result."
        )
        .padding(AppSpacing.s)
    }

    @ViewBuilder
    func packetTableCell(_ value: String, color: Color = .primary, help: String) -> some View {
        Text(value)
            .font(.caption.monospaced())
            .foregroundStyle(color)
            .lineLimit(2)
            .truncationMode(.middle)
            .textSelection(.enabled)
            .help(help)
    }

    @ViewBuilder
    func packetRowDetail(_ row: NativeAppPacketMonitorRow?) -> some View {
        GroupBox("Packet row details") {
            if let row {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    MetricsGrid {
                        AppReadableMetric(label: "Packet", value: "\(row.id)", monospaced: true)
                        AppReadableMetric(label: "Stream", value: row.stream)
                        AppReadableMetric(label: "Source", value: row.source, monospaced: true)
                        AppReadableMetric(label: "Destination", value: row.destination, monospaced: true)
                        AppReadableMetric(label: "Payload", value: row.payload, monospaced: true)
                        AppReadableMetric(label: "Candidate", value: row.candidate, monospaced: true)
                    }
                    Text(AppPacketMonitorRowDetailState.copyText(row))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(nil)
                    Button {
                        copyToPasteboard(
                            AppPacketMonitorRowDetailState.copyText(row),
                            target: "full packet row \(row.id)"
                        )
                    } label: {
                        Label("Copy Full Row", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Copy full packet row \(row.id)")
                    .help("Copy full packet row")
                }
            } else {
                Label("Select Details on a packet row to review full values.", systemImage: "sidebar.right")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .appConsoleGroupBoxStyle()
        .padding(.top, AppSpacing.s)
    }

    var packetTableEmptyState: some View {
        Label("No packets match the current filter.", systemImage: "line.3.horizontal.decrease.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(AppSpacing.m)
    }

    // MARK: - Helpers

    private func copyToPasteboard(_ value: String, target: String) {
        copyFeedback = AppPasteboard.copyFeedback(value, target: target)
    }

    func pct(_ part: Int, of total: Int) -> String {
        guard total > 0 else { return "0.0%" }
        let percent = Decimal(part) / Decimal(total) * 100
        let roundedPercent = NSDecimalNumber(decimal: percent).rounding(
            accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .plain,
                scale: 1,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )
        )
        return "\(roundedPercent.stringValue)%"
    }

    func verdictColor(_ verdict: MeasurementVerdict) -> Color {
        switch verdict {
        case .pass: AppDesignSystem.stateLive
        case .partial: AppDesignSystem.stateWarning
        case .fail: AppDesignSystem.stateError
        }
    }

    func streamColor(_ streamType: LoLaCompatibilityCaptureStream) -> Color {
        switch streamType {
        case .audio:
            return AppDesignSystem.stateLive
        case .video:
            return AppDesignSystem.stateConnecting
        case .control:
            return AppDesignSystem.stateArmed
        case .otherUDP, .nonUDP, .malformed:
            return .secondary
        }
    }
}
