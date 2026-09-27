// Renders AppExecutionLogViews in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import OpenLolaCore
import SwiftUI

struct AppReportsView: View {
    let plan: AppOperatorPrototypePlan
    let executionController: AppExecutionController

    var body: some View {
        GroupBox("Report paths") {
            MetricsGrid {
                if plan.sessionMode == .windowsLoLa {
                    AppReadableMetric(
                        label: "External connector",
                        value: plan.windowsLoLaFields.outputPath,
                        monospaced: true
                    )
                } else if plan.sessionMode == .directMacPeer {
                    AppReadableMetric(label: "Plan", value: executionController.settings.planPath, monospaced: true)
                    AppReadableMetric(
                        label: "Supervisor",
                        value: executionController.settings.supervisorReportPath,
                        monospaced: true
                    )
                } else if plan.sessionMode.externalConnectorKind != nil {
                    AppReadableMetric(
                        label: plan.sessionMode.displayName,
                        value: plan.externalConnectorFields.outputPath,
                        monospaced: true
                    )
                } else {
                    AppReadableMetric(label: plan.sessionMode.displayName, value: "not available")
                }
                AppReadableMetric(label: "Stdout", value: executionController.stdoutPath, monospaced: true)
                AppReadableMetric(label: "Stderr", value: executionController.stderrPath, monospaced: true)
            }
        }

        GroupBox(plan.sessionMode.externalConnectorKind != nil ? "Connector report" : "Plan reports") {
            MetricsGrid {
                if plan.sessionMode.externalConnectorKind != nil {
                    let reportPath = plan.sessionMode == .windowsLoLa
                        ? plan.windowsLoLaFields.outputPath
                        : plan.externalConnectorFields.outputPath
                    AppReadableMetric(label: "Path", value: reportPath, monospaced: true)
                    if let report = executionController.lastExternalConnectorReport {
                        LabeledContent("Verdict", value: report.verdict.rawValue)
                        LabeledContent("Dry run", value: yesNo(report.dryRun))
                        LabeledContent("Role", value: report.role.rawValue)
                        AppReadableMetric(label: "Runtime error", value: report.runtimeError ?? "none")
                    } else {
                        LabeledContent("Status", value: "No report loaded")
                    }
                } else if plan.sessionMode == .directMacPeer {
                    ForEach(plan.report?.reportReferences ?? [], id: \.peerID) { reference in
                        AppReadableMetric(label: reference.peerID, value: reference.path, monospaced: true)
                    }
                } else {
                    AppReadableMetric(label: "Status", value: plan.sessionMode.unavailableAppReason ?? "Not wired")
                }
            }
        }

        if let report = executionController.lastExternalConnectorReport {
            GroupBox("LoLa evidence") {
                MetricsGrid {
                    LabeledContent("Control", value: report.lolaControl == nil ? "not measured" : "recorded")
                    LabeledContent("Media", value: report.lolaMedia?.verdict.rawValue ?? "not measured")
                    LabeledContent("Control port", value: "\(report.plan.controlPort)")
                    LabeledContent("Audio port", value: "\(report.plan.audioPort)")
                    LabeledContent("Video port", value: "\(report.plan.videoPort)")
                }
            }
        }

        GroupBox("Session Details") {
            if let report = executionController.lastReport {
                MetricsGrid {
                    AppReadableMetric(label: "ID", value: report.id, monospaced: true)
                    LabeledContent("Verdict", value: report.verdict.rawValue)
                    LabeledContent("Exit", value: AppProcessExitDisplay.title(report.exitCode))
                    LabeledContent("Validation", value: report.validationExitCode.map(String.init) ?? "none")
                    LabeledContent("Stopped", value: yesNo(report.stopRequested))
                }
            } else {
                Label(
                    "Session details appear here after a session completes.",
                    systemImage: "doc.text.magnifyingglass"
                )
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct AppExecutionErrorLogView: View {
    let errors: [String]

    var body: some View {
        if !errors.isEmpty {
            GroupBox("Session errors") {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(Array(errors.enumerated()), id: \.offset) { index, error in
                        HStack(alignment: .top, spacing: AppSpacing.xs) {
                            Text("\(index + 1).")
                                .foregroundStyle(.secondary)
                            Text(error)
                                .textSelection(.enabled)
                                .lineLimit(nil)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
}

struct AppLogsView: View {
    let executionController: AppExecutionController

    var body: some View {
        DesignPanel(title: "Log files", systemImage: "doc.text") {
            MetricsGrid {
                AppReadableMetric(label: "Stdout", value: executionController.stdoutPath, monospaced: true)
                AppReadableMetric(label: "Stderr", value: executionController.stderrPath, monospaced: true)
                AppReadableMetric(
                    label: "Previous stdout",
                    value: executionController.previousStdoutPath,
                    monospaced: true
                )
                AppReadableMetric(
                    label: "Previous stderr",
                    value: executionController.previousStderrPath,
                    monospaced: true
                )
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    openLogButton(label: "stdout", path: executionController.stdoutPath)
                    openLogButton(label: "stderr", path: executionController.stderrPath)
                }
                HStack(spacing: AppSpacing.xs) {
                    openLogButton(label: "previous stdout", path: executionController.previousStdoutPath)
                    openLogButton(label: "previous stderr", path: executionController.previousStderrPath)
                }
                ForEach(unavailableLogReasons, id: \.self) { reason in
                    AppDisabledControlReasonText(reason: reason)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(.caption)
        }
        AppPreviousRunEvidenceView(snapshots: executionController.previousRunEvidence)
        AppExecutionErrorLogView(errors: executionController.errorLog)
        GroupBox {
            DisclosureGroup("Show last command") {
                Text(AppCommandPreview.shellLine(executionController.lastCommand))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(nil)
            }
        } label: {
            Text("Last command").font(.caption.weight(.semibold))
        }
    }

    private var unavailableLogReasons: [String] {
        [
            AppLogOpenButtonPolicy.disabledReason(
                label: "stdout",
                path: executionController.stdoutPath,
                canOpen: executionController.canOpenLogFile(executionController.stdoutPath)
            ),
            AppLogOpenButtonPolicy.disabledReason(
                label: "stderr",
                path: executionController.stderrPath,
                canOpen: executionController.canOpenLogFile(executionController.stderrPath)
            ),
            AppLogOpenButtonPolicy.disabledReason(
                label: "previous stdout",
                path: executionController.previousStdoutPath,
                canOpen: executionController.canOpenLogFile(executionController.previousStdoutPath)
            ),
            AppLogOpenButtonPolicy.disabledReason(
                label: "previous stderr",
                path: executionController.previousStderrPath,
                canOpen: executionController.canOpenLogFile(executionController.previousStderrPath)
            )
        ].compactMap(\.self)
    }

    private func openLogButton(label: String, path: String) -> some View {
        let canOpen = executionController.canOpenLogFile(path)
        let disabledReason = AppLogOpenButtonPolicy.disabledReason(
            label: label,
            path: path,
            canOpen: canOpen
        )
        return Button("Open \(label)") { executionController.openLogFile(path) }
            .disabled(disabledReason != nil)
            .help(disabledReason ?? AppLogOpenButtonPolicy.openHelp(label: label))
    }
}

enum AppLogOpenButtonPolicy {
    static func disabledReason(label: String, path: String, canOpen: Bool) -> String? {
        guard !canOpen else {
            return nil
        }
        return "\(label.capitalized) log unavailable. No file exists at \(path)."
    }

    static func openHelp(label: String) -> String {
        "Open \(label) log file"
    }
}

struct AppPreviousRunEvidenceView: View {
    let snapshots: [AppRunEvidenceSnapshot]

    var body: some View {
        if !snapshots.isEmpty {
            GroupBox("Previous Runs") {
                DisclosureGroup("\(snapshots.count) preserved snapshot\(snapshots.count == 1 ? "" : "s")") {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        if snapshots.count > 0 { snapshotRow(snapshots[0]); Divider() }
                        if snapshots.count > 1 { snapshotRow(snapshots[1]); Divider() }
                        if snapshots.count > 2 { snapshotRow(snapshots[2]) }
                    }
                }
            }
        }
    }

    private func snapshotRow(_ snapshot: AppRunEvidenceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(snapshot.capturedAt)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(String(describing: snapshot.phase))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            MetricsGrid {
                AppReadableMetric(label: "Status", value: snapshot.status)
                AppReadableMetric(label: "Exit", value: AppProcessExitDisplay.title(snapshot.exitCode))
                AppReadableMetric(
                    label: "Validation",
                    value: snapshot.validationExitCode.map(String.init) ?? snapshot.validationResult.displayTitle
                )
                AppReadableMetric(label: "Errors", value: String(snapshot.errorCount))
                AppReadableMetric(label: "Latency", value: snapshot.latencySummary)
                AppReadableMetric(label: "Capture", value: snapshot.captureSummary)
                AppReadableMetric(label: "Connector", value: snapshot.externalConnectorSummary)
            }
            if let lastError = snapshot.lastError {
                Label(lastError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(AppDesignSystem.stateError)
                    .textSelection(.enabled)
            }
            Text(snapshot.commandLine)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(nil)
        }
        .padding(.vertical, AppSpacing.xs)
    }
}
