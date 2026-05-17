import Foundation
import OpenLolaCore
import SwiftUI

// MARK: - Packet Monitor

struct AppPacketMonitorView: View {
    private enum Layout {
        static let streamPickerMaxWidth: CGFloat = 240
        static let packetTableMaxHeight: CGFloat = 480
    }

    let captureReport: LoLaCompatibilityCaptureReport?

    @State private var searchText = ""
    @State private var streamFilter: NativeAppPacketStreamFilter = .all

    var body: some View {
        if let report = captureReport {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                summaryCards(report)
                filterToolbar
                packetTable(report)
            }
        } else {
            AppConsolePanel(title: "Packet Monitor", systemImage: "tablecells") {
                Label("No decoded capture report loaded.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(
                    "Live packet capture is unavailable in the operator console until " +
                    "a LoLaCompatibilityCaptureDecoder report exists."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Summary cards

    private func summaryCards(_ report: LoLaCompatibilityCaptureReport) -> some View {
        HStack(spacing: AppSpacing.s) {
            summaryCard(
                value: "\(report.summary.packetCount)",
                label: "Total",
                icon: "tablecells",
                color: .secondary
            )
            summaryCard(
                value: "\(report.summary.audioPacketCount)",
                label: "Audio",
                icon: "waveform",
                color: AppDesignSystem.stateLive,
                pct: pct(report.summary.audioPacketCount, of: report.summary.packetCount)
            )
            summaryCard(
                value: "\(report.summary.videoPacketCount)",
                label: "Video",
                icon: "video.fill",
                color: .blue,
                pct: pct(report.summary.videoPacketCount, of: report.summary.packetCount)
            )
            summaryCard(
                value: report.verdict.rawValue.uppercased(),
                label: "Verdict",
                icon: "checkmark.seal",
                color: verdictColor(report.verdict)
            )
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func summaryCard(
        value: String,
        label: String,
        icon: String,
        color: Color,
        pct: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.metricsValue)
                .monospacedDigit()
            if let pct {
                Text(pct)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppSpacing.s)
        .background(AppDesignSystem.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
    }

    // MARK: - Filter toolbar

    private var filterToolbar: some View {
        HStack(spacing: AppSpacing.s) {
            Picker("Stream", selection: $streamFilter) {
                ForEach(NativeAppPacketStreamFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: Layout.streamPickerMaxWidth)

            TextField("Filter packets…", text: $searchText)
                .textFieldStyle(.plain)
                .padding(.horizontal, AppSpacing.s)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Packet table

    private func packetTable(_ report: LoLaCompatibilityCaptureReport) -> some View {
        let rowsState = AppPacketMonitorRowsState.make(report: report, streamFilter: streamFilter, searchText: searchText)
        return VStack(alignment: .leading, spacing: 0) {
            switch rowsState {
            case .rows(let rows):
                if rows.isEmpty {
                    packetTableEmptyState
                } else {
                    Table(rows) {
                        TableColumn("#") { row in
                            packetTableCell("\(row.id)", help: row.accessibilityLabel)
                                .monospacedDigit()
                        }
                        TableColumn("Stream") { row in
                            packetTableCell(row.stream, color: streamColor(row.streamType), help: row.accessibilityLabel)
                        }
                        TableColumn("Source") { row in
                            packetTableCell(row.source, help: row.source)
                        }
                        TableColumn("Destination") { row in
                            packetTableCell(row.destination, help: row.destination)
                        }
                        TableColumn("Payload") { row in
                            packetTableCell(row.payload, help: row.payload)
                        }
                        TableColumn("Candidate") { row in
                            packetTableCell(row.candidate, help: row.candidate)
                        }
                        TableColumn("Copy") { row in
                            Button {
                                copyToPasteboard(row.accessibilityLabel)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Copy packet row \(row.id)")
                            .help("Copy full packet row")
                        }
                    }
                    .frame(minHeight: 160, maxHeight: Layout.packetTableMaxHeight)
                    .accessibilityLabel("Decoded packet table")
                }
            case .failure(let message):
                AppWarningBanner(
                    title: "Packet Row Error",
                    message: message,
                    detail: "This is different from an empty packet filter result."
                )
                .padding(AppSpacing.s)
            }
        }
        .background(AppDesignSystem.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func packetTableCell(_ value: String, color: Color = .primary, help: String) -> some View {
        Text(value)
            .font(.caption.monospaced())
            .foregroundStyle(color)
            .lineLimit(2)
            .truncationMode(.middle)
            .textSelection(.enabled)
            .help(help)
    }

    private var packetTableEmptyState: some View {
        Label("No packets match the current filter.", systemImage: "line.3.horizontal.decrease.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(AppSpacing.m)
    }

    // MARK: - Helpers

    private func copyToPasteboard(_ value: String) {
        AppPasteboard.copyString(value)
    }

    private func pct(_ part: Int, of total: Int) -> String {
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

    private func verdictColor(_ verdict: MeasurementVerdict) -> Color {
        switch verdict {
        case .pass: AppDesignSystem.stateLive
        case .partial: AppDesignSystem.meterCaution
        case .fail: AppDesignSystem.stateError
        }
    }

    private func streamColor(_ streamType: LoLaCompatibilityCaptureStream) -> Color {
        switch streamType {
        case .audio:
            return AppDesignSystem.stateLive
        case .video:
            return .blue
        case .control:
            return AppDesignSystem.stateArmed
        case .otherUDP, .nonUDP, .malformed:
            return .secondary
        }
    }
}

enum AppPacketMonitorRowsState: Equatable {
    case rows([NativeAppPacketMonitorRow])
    case failure(String)

    static func make(
        report: LoLaCompatibilityCaptureReport,
        streamFilter: NativeAppPacketStreamFilter,
        searchText: String,
        limit: Int = AppConstants.packetMonitorCapacity
    ) -> AppPacketMonitorRowsState {
        do {
            return .rows(try NativeAppPacketMonitorRows.rows(
                report: report,
                streamFilter: streamFilter,
                searchText: searchText,
                limit: limit
            ))
        } catch {
            return .failure("Packet monitor failed to build rows: \(error)")
        }
    }
}
