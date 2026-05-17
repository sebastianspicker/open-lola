import OpenLolaCore
import SwiftUI

struct AppExecutionView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    @Bindable var executionController: AppExecutionController
    let plan: AppOperatorPrototypePlan

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
                    title: "Execution Error",
                    message: cleanError(error),
                    detail: AppExecutionErrorGuidance.detail(for: error),
                    dismissAction: { executionController.lastError = nil }
                )
            }

            GroupBox("Execution Control") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Arm execution", isOn: $executionController.armedForExecution)
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
                            AppReadableMetric(label: "Runtime", value: "not launchable from app")
                        }
                        LabeledContent("Require preflight", value: yesNo(executionController.settings.requirePreflight))
                        LabeledContent("Running", value: yesNo(executionController.isRunning))
                        LabeledContent("Last exit", value: executionController.lastExitCode.map(String.init) ?? "none")
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
                        .disabled(executionController.isRunning || plan.sessionMode != .directMacPeer)
                    }
                }
            }

            GroupBox(plan.sessionMode == .directMacPeer ? "Supervisor Command Example" : "Connector Command Example") {
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

    private var resolvedExecutablePath: String {
        AppExecutablePathResolver.resolve(currentExecutablePath).displayPath
    }

    private var currentExecutablePath: String {
        switch operatorSurface.sessionMode {
        case .directMacPeer:
            return operatorSurface.directPeerCommandFields.executablePath
        case .windowsLoLa:
            return operatorSurface.windowsLoLaPeerFields.executablePath
        case .jackTrip, .ultraGrid:
            return operatorSurface.directPeerCommandFields.executablePath
        }
    }

    private func cleanError(_ error: String) -> String {
        error.replacingOccurrences(of: "Error Domain=NSCocoaErrorDomain Code=4 ", with: "")
    }

    @ViewBuilder
    private func commandBlock(result: Result<[String], Error>) -> some View {
        switch result {
        case .success(let command):
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text("Command")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: AppSpacing.xs)
                    Button {
                        copyToPasteboard(AppCommandPreview.shellLine(command))
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .help("Copy command")
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
            }
        case .failure(let error):
            Label(String(describing: error), systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }

    private func copyToPasteboard(_ command: String) {
        AppPasteboard.copyString(command)
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

enum AppCommandPreview {
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

struct AppReportsView: View {
    let plan: AppOperatorPrototypePlan
    let executionController: AppExecutionController

    var body: some View {
        GroupBox("Report Paths") {
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
                } else {
                    AppReadableMetric(label: plan.sessionMode.displayName, value: "not launchable from app")
                }
                AppReadableMetric(label: "Stdout", value: executionController.stdoutPath, monospaced: true)
                AppReadableMetric(label: "Stderr", value: executionController.stderrPath, monospaced: true)
            }
        }

        GroupBox(plan.sessionMode == .windowsLoLa ? "Connector Report" : "Plan Reports") {
            MetricsGrid {
                if plan.sessionMode == .windowsLoLa {
                    AppReadableMetric(label: "Path", value: plan.windowsLoLaFields.outputPath, monospaced: true)
                    if let report = executionController.lastExternalConnectorReport {
                        LabeledContent("Verdict", value: report.verdict.rawValue.uppercased())
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
            GroupBox("LoLa Evidence") {
                MetricsGrid {
                    LabeledContent("Control", value: report.lolaControl == nil ? "not measured" : "recorded")
                    LabeledContent("Media", value: report.lolaMedia?.verdict.rawValue.uppercased() ?? "not measured")
                    LabeledContent("Control port", value: "\(report.plan.controlPort)")
                    LabeledContent("Audio port", value: "\(report.plan.audioPort)")
                    LabeledContent("Video port", value: "\(report.plan.videoPort)")
                }
            }
        }

        if let report = executionController.lastReport {
            GroupBox("Last App Execution Report") {
                MetricsGrid {
                    AppReadableMetric(label: "ID", value: report.id, monospaced: true)
                    LabeledContent("Verdict", value: report.verdict.rawValue.uppercased())
                    LabeledContent("Exit", value: report.exitCode.map(String.init) ?? "none")
                    LabeledContent("Validation", value: report.validationExitCode.map(String.init) ?? "none")
                    LabeledContent("Stopped", value: yesNo(report.stopRequested))
                }
            }
        }
    }
}

private struct AppExecutionErrorLogView: View {
    let errors: [String]

    var body: some View {
        if !errors.isEmpty {
            GroupBox("Execution Errors") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(errors.enumerated()), id: \.offset) { index, error in
                        HStack(alignment: .top, spacing: 8) {
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
        GroupBox("Log Files") {
            MetricsGrid {
                HStack {
                    AppReadableMetric(label: "Stdout", value: executionController.stdoutPath, monospaced: true)
                    Button("Open") { executionController.openLogFile(executionController.stdoutPath) }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .disabled(!executionController.canOpenLogFile(executionController.stdoutPath))
                }
                HStack {
                    AppReadableMetric(label: "Stderr", value: executionController.stderrPath, monospaced: true)
                    Button("Open") { executionController.openLogFile(executionController.stderrPath) }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .disabled(!executionController.canOpenLogFile(executionController.stderrPath))
                }
            }
        }
        AppExecutionErrorLogView(errors: executionController.errorLog)
        GroupBox("Last Command") {
            Text(AppCommandPreview.shellLine(executionController.lastCommand))
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(nil)
        }
    }
}
