import OpenLolaCore
import SwiftUI

struct AppExecutionView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    @Bindable var executionController: AppExecutionController
    let plan: AppOperatorPrototypePlan
    let inputsLocked: Bool

    var body: some View {
        Group {
            if let validationError = plan.validationError {
                AppWarningBanner(
                    title: "\(plan.sessionMode.displayName) Validation",
                    message: validationError
                )
            }

            if let error = executionController.lastError {
                AppWarningBanner(
                    title: "Session Error",
                    message: cleanError(error),
                    detail: AppExecutionErrorGuidance.detail(for: error),
                    dismissAction: { executionController.lastError = nil }
                )
            }

            DesignPanel(title: "Session control", systemImage: "play.circle") {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Toggle("Arm session", isOn: $executionController.armedForExecution)
                        .disabled(armDisabled)
                        .help(armHelp)
                    MetricsGrid {
                        AppReadableMetric(label: "Executable", value: resolvedExecutablePath, monospaced: true)
                        if plan.sessionMode == .windowsLoLa {
                            AppReadableMetric(
                                label: "Report",
                                value: operatorSurface.windowsLoLaPeerFields.outputPath,
                                monospaced: true
                            )
                            AppReadableMetric(label: "Peer", value: operatorSurface.windowsLoLaPeerFields.windowsHost)
                        } else if plan.sessionMode == .directMacPeer {
                            AppReadableMetric(label: "Plan", value: executionController.settings.planPath, monospaced: true)
                            AppReadableMetric(
                                label: "Supervisor",
                                value: executionController.settings.supervisorReportPath,
                                monospaced: true
                            )
                        } else {
                            AppReadableMetric(label: "Report", value: plan.externalConnectorFields.outputPath, monospaced: true)
                            AppReadableMetric(label: "Peer", value: plan.externalConnectorFields.peerHost)
                        }
                        LabeledContent("Require preflight", value: yesNo(executionController.settings.requirePreflight))
                        LabeledContent("Running", value: yesNo(executionController.isRunning))
                        LabeledContent("Last exit", value: AppProcessExitDisplay.title(executionController.lastExitCode))
                    }
                    if showsDryRunBadge {
                        AppStatusBadge(title: "DRY RUN", systemImage: "play.slash.fill", tone: AppDesignSystem.stateWarning)
                    }
                    HStack {
                        if executionController.isRunning {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Button("Write Plan") {
                            guard executionController.writePlanOrLogError(from: operatorSurface) else {
                                return
                            }
                        }
                        .disabled(inputsLocked || plan.sessionMode != .directMacPeer)
                        .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "Write the current two-peer plan")
                    }
                }
            }

            DesignPanel(
                title: plan.sessionMode == .directMacPeer ? "Supervisor command example" : "Connector command example",
                systemImage: "apple.terminal"
            ) {
                DisclosureGroup("Show preview command") {
                    Text("Preview command generated with dry-run semantics.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    commandBlock(result: executionController.executionCommand(
                        executablePath: currentExecutablePath,
                        operatorSurface: operatorSurface,
                        dryRun: true
                    ))
                }
            }
        }
    }

    private var resolvedExecutablePath: String {
        AppExecutablePathResolver.resolve(currentExecutablePath).displayPath
    }

    private var armDisabled: Bool {
        inputsLocked || !plan.sessionMode.supportsAppExecution
    }

    private var armHelp: String {
        if inputsLocked {
            return AppRuntimeInputLock.lockedHelp
        }
        if !plan.sessionMode.supportsAppExecution {
            return "Switch to a supported workflow in Settings to arm session"
        }
        return "Arm session"
    }

    private var showsDryRunBadge: Bool {
        executionController.phase == .dryRunRunning
            || (executionController.phase == .runFinished && executionController.lastRunWasDryRun)
    }

    private var currentExecutablePath: String {
        switch operatorSurface.sessionMode {
        case .directMacPeer:
            return operatorSurface.directPeerCommandFields.executablePath
        case .windowsLoLa:
            return operatorSurface.windowsLoLaPeerFields.executablePath
        case .jackTrip:
            return operatorSurface.jackTripPeerFields.executablePath
        case .ultraGrid:
            return operatorSurface.ultraGridPeerFields.executablePath
        }
    }

    private func cleanError(_ error: String) -> String {
        error.replacingOccurrences(of: "Error Domain=NSCocoaErrorDomain Code=4 ", with: "")
    }

    @ViewBuilder
    private func commandBlock(result: Result<[String], Error>) -> some View {
        switch result {
        case .success(let command):
            AppCommandReviewBlock(title: "Command", command: command)
        case .failure(let error):
            Label(String(describing: error), systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }
}

enum AppExecutionErrorGuidance {
    static func detail(for error: String) -> String {
        let lowercased = error.lowercased()
        if lowercased.contains("missing report")
            || lowercased.contains("supervisor report")
            || lowercased.contains("external connector report") {
            return "Generate or load the report path shown in Report Paths before validating."
        }
        if lowercased.contains("executable")
            || lowercased.contains("no such file")
            || lowercased.contains("posix") {
            return "Check the executable path in Settings > Execution."
        }
        if lowercased.contains("plan") || lowercased.contains("configuration") {
            return "Review the plan fields and generated command before launching again."
        }
        return "Review the log paths and error details shown in this section."
    }
}

enum AppProcessExitDisplay {
    static func title(_ exitCode: Int?) -> String {
        guard let exitCode else {
            return "none"
        }
        switch exitCode {
        case 0:
            return "Exited cleanly"
        case -15, 15, 143:
            return "Stopped by operator"
        default:
            return "Unexpected exit (code \(exitCode))"
        }
    }
}

enum AppCommandPreview {
    static func copyText(_ command: [String]) -> String {
        shellLine(command)
    }

    static func shellLine(_ command: [String]) -> String {
        command.map(shellEscapedArgument).joined(separator: " ")
    }

    static func multilineDisplay(_ command: [String]) -> String {
        guard let first = command.first else {
            return ""
        }
        let arguments = command.dropFirst().map { "  \(shellEscapedArgument($0))" }
        return ([shellEscapedArgument(first)] + arguments).joined(separator: " \\\n")
    }

    static func shellEscapedArgument(_ argument: String) -> String {
        guard !argument.isEmpty else {
            return "''"
        }
        let safeScalars = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_@%+=:,./-")
        if argument.unicodeScalars.allSatisfy({ safeScalars.contains($0) }) {
            return argument
        }
        return "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

struct AppCommandReviewBlock: View {
    let title: String
    var detail: String?
    let command: [String]

    @State private var copyFeedback: AppPasteboardCopyFeedback?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: AppSpacing.xs)
                Button {
                    copyFeedback = AppPasteboard.copyFeedback(
                        AppCommandPreview.copyText(command),
                        target: "exact command"
                    )
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .font(.caption)
                .buttonStyle(.plain)
                .appCompactToolButtonHitTarget()
                .help("Copy exact command")
            }
            if let copyFeedback {
                AppCopyFeedbackText(feedback: copyFeedback)
            }
            ScrollView([.horizontal, .vertical]) {
                Text(AppCommandPreview.multilineDisplay(command))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: true, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 96, maxHeight: 180, alignment: .topLeading)
            .padding(AppSpacing.s)
            .background(AppDesignSystem.elevatedBackground, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
            }
            .help("Displayed one argument per line. Copy preserves the exact shell command.")
            .accessibilityLabel("Generated command: \(title)")
            .accessibilityHint("Displayed one argument per line. Copy preserves the exact shell command.")
        }
    }
}

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

private struct AppExecutionErrorLogView: View {
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
                AppReadableMetric(label: "Previous stdout", value: executionController.previousStdoutPath, monospaced: true)
                AppReadableMetric(label: "Previous stderr", value: executionController.previousStderrPath, monospaced: true)
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
            ),
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

private struct AppPreviousRunEvidenceView: View {
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
