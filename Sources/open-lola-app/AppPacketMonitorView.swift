// Renders AppPacketMonitorView in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
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
    let emptyState: AppPacketMonitorEmptyState
    let navigateToSection: (NativeAppShellSurfaceSectionID) -> Void

    @State private var searchText = ""
    @State private var streamFilter: NativeAppPacketStreamFilter = .all
    @State var selectedPacketRowID: NativeAppPacketMonitorRow.ID?
    @State var copyFeedback: AppPasteboardCopyFeedback?

    var body: some View {
        if let report = captureReport {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                summaryCards(report)
                filterToolbar
                packetTable(report)
                if let copyFeedback {
                    AppCopyFeedbackText(feedback: copyFeedback)
                }
            }
        } else {
            DesignPanel(title: "Packet Monitor", systemImage: "tablecells") {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Label(emptyState.title, systemImage: "exclamationmark.triangle")
                        .font(.headline)
                        .foregroundStyle(AppDesignSystem.stateWarning)
                    Text(emptyState.reason)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    MetricsGrid {
                    AppReadableMetric(
                        label: "Expected source",
                        value: emptyState.expectedReportPath,
                        monospaced: true
                    )
                        LabeledContent("Recovery", value: emptyState.actionTitle)
                    }
                    Button {
                        navigateToSection(emptyState.targetSection)
                    } label: {
                        Label(emptyState.actionTitle, systemImage: "arrow.right.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: - Summary cards

    private func summaryCards(_ report: LoLaCompatibilityCaptureReport) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.s) {
                summaryCardsContent(report)
                Spacer(minLength: 0)
            }
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140), spacing: AppSpacing.s)],
                alignment: .leading,
                spacing: AppSpacing.s
            ) {
                summaryCardsContent(report)
            }
        }
    }

    @ViewBuilder
    private func summaryCardsContent(_ report: LoLaCompatibilityCaptureReport) -> some View {
        summaryCard(value: "\(report.summary.packetCount)", label: "Total", icon: "tablecells", color: .secondary)
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
            color: AppDesignSystem.stateConnecting,
            pct: pct(report.summary.videoPacketCount, of: report.summary.packetCount)
        )
        summaryCard(
            value: report.verdict.rawValue.uppercased(),
            label: "Verdict",
            icon: "checkmark.seal",
            color: verdictColor(report.verdict)
        )
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
        .padding(AppSpacing.m)
        .frame(minWidth: 132, alignment: .leading)
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
                ForEach(NativeAppPacketStreamFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
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
        let rowsState = AppPacketMonitorRowsState.make(
            report: report,
            streamFilter: streamFilter,
            searchText: searchText
        )
        return VStack(alignment: .leading, spacing: 0) {
            packetTableContent(rowsState)
        }
        .background(AppDesignSystem.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func packetTableContent(_ rowsState: AppPacketMonitorRowsState) -> some View {
        switch rowsState {
        case .rows(let rows):
            packetRowsContent(rows)
        case .failure(let message):
            packetRowsFailure(message)
        }
    }

    @ViewBuilder
    private func packetRowsContent(_ rows: [NativeAppPacketMonitorRow]) -> some View {
        if rows.isEmpty {
            packetTableEmptyState
        } else {
            packetRowsTable(rows)
            packetRowDetail(AppPacketMonitorRowDetailState.selectedRow(
                rows: rows,
                selectedID: selectedPacketRowID
            ))
        }
    }

    private func packetRowsTable(_ rows: [NativeAppPacketMonitorRow]) -> some View {
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
            TableColumn("Actions") { row in
                packetRowActionButtons(row)
            }
        }
        .frame(minHeight: 160, maxHeight: Layout.packetTableMaxHeight)
        .accessibilityLabel("Decoded packet table")
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

enum AppPacketMonitorRowDetailState {
    static func selectedRow(
        rows: [NativeAppPacketMonitorRow],
        selectedID: NativeAppPacketMonitorRow.ID?
    ) -> NativeAppPacketMonitorRow? {
        guard let selectedID else { return nil }
        return rows.first { $0.id == selectedID }
    }

    static func copyText(_ row: NativeAppPacketMonitorRow) -> String {
        row.accessibilityLabel
    }
}
