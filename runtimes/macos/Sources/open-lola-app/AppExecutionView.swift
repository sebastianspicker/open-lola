// Renders AppExecutionView in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
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

            DisclosureGroup("Run details") {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
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
                            AppReadableMetric(
                                label: "Plan",
                                value: executionController.settings.planPath,
                                monospaced: true
                            )
                            AppReadableMetric(
                                label: "Supervisor",
                                value: executionController.settings.supervisorReportPath,
                                monospaced: true
                            )
                        } else {
                            AppReadableMetric(
                                label: "Report",
                                value: plan.externalConnectorFields.outputPath,
                                monospaced: true
                            )
                            AppReadableMetric(label: "Peer", value: plan.externalConnectorFields.peerHost)
                        }
                        LabeledContent("Require preflight", value: yesNo(executionController.settings.requirePreflight))
                        LabeledContent("Running", value: yesNo(executionController.isRunning))
                        LabeledContent(
                            "Last exit",
                            value: AppProcessExitDisplay.title(executionController.lastExitCode)
                        )
                    }
                    if showsDryRunBadge {
                        AppStatusBadge(
                            title: "DRY RUN",
                            systemImage: "play.slash.fill",
                            tone: AppDesignSystem.stateWarning
                        )
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
                .padding(.top, AppSpacing.s)
            }
            .appExecutionDisclosureRow()

            DisclosureGroup(
                plan.sessionMode == .directMacPeer ? "Supervisor command" : "Connector command"
            ) {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Text("Preview command generated with dry-run semantics.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    commandBlock(result: executionController.executionCommand(
                        executablePath: currentExecutablePath,
                        operatorSurface: operatorSurface,
                        dryRun: true
                    ))
                }
                .padding(.top, AppSpacing.s)
            }
            .appExecutionDisclosureRow()
        }
    }

    private var resolvedExecutablePath: String {
        AppExecutablePathResolver.resolve(currentExecutablePath).displayPath
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

private extension View {
    func appExecutionDisclosureRow() -> some View {
        padding(.horizontal, AppSpacing.xxs)
            .padding(.vertical, AppSpacing.s)
            .overlay {
                VStack {
                    Spacer()
                    Divider()
                }
            }
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
        let safeScalars = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_@%+=:,./-"
        )
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
