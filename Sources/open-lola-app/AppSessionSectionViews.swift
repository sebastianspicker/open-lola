// Renders the Session workspace: latency instrument, signal path, evidence chain, and run controls.
import OpenLolaCore
import SwiftUI

struct AppSessionSectionView: View {
    let report: NativeAppShellReport
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let executionController: AppExecutionController
    let operatorPlan: AppOperatorPrototypePlan
    let captureReport: LoLaCompatibilityCaptureReport?
    let sessionState: AppSessionState
    let inputsLocked: Bool
    let navigateToSection: (NativeAppShellSurfaceSectionID) -> Void

    private var sessionSummary: AppOverviewOperatorSummary {
        appOverviewOperatorSummary(
            report: report,
            operatorPlan: operatorPlan,
            executionController: executionController,
            sessionState: sessionState,
            captureReport: captureReport
        )
    }

    private var channelCount: Int {
        if operatorPlan.sessionMode == .windowsLoLa {
            return operatorPlan.windowsLoLaFields.channelCount
        }
        if operatorPlan.sessionMode.externalConnectorKind != nil {
            return 2
        }
        return operatorSurface.directPeerCommandFields.channelCount
    }

    private var packetEvidenceAvailable: Bool {
        AppConnectionTopologyAnimationPolicy.hasPacketEvidence(captureReport)
    }

    private var profileCaption: String {
        let profile = report.configuration.profileName
        let rx = operatorPlan.rxBufferProfile.rawValue
        return rx.isEmpty ? profile : "\(profile) · RX \(rx)"
    }

    private var localDeviceLabel: String? {
        let selection = report.configuration.audioDeviceSelection.trimmingCharacters(in: .whitespacesAndNewlines)
        return selection.isEmpty ? nil : selection
    }

    private var evidenceSourceState: String {
        let verdict = report.verdict.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return verdict.isEmpty ? "Capability" : verdict.capitalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppLatencyHeroView(
                audioLatencyMs: executionController.lastLatencyMetrics?.audioLatencyMs,
                packetLossPercent: executionController.lastLatencyMetrics?.packetLossPercent,
                jitterMs: executionController.lastLatencyMetrics?.jitterMs,
                evidenceStatusMessage: executionController.lastLatencyMetrics?.evidenceStatusMessage
            )

            AppConnectionTopologyView(
                localPeer: operatorPlan.topologyLocalPeer,
                remotePeer: operatorPlan.topologyRemotePeer,
                localHost: operatorPlan.topologyLocalHost,
                remoteHost: operatorPlan.topologyRemoteHost,
                channelCount: channelCount,
                sessionMode: operatorPlan.sessionMode,
                sessionState: sessionState,
                executionPhase: executionController.phase,
                packetEvidenceAvailable: packetEvidenceAvailable,
                localDeviceLabel: localDeviceLabel,
                remoteDeviceLabel: nil,
                profileCaption: profileCaption,
                videoEnabled: report.configuration.videoEnabled
            )

            AppSessionEvidenceChain(
                stages: AppSessionEvidenceChainPolicy.stages(
                    readinessConfigured: operatorPlan.isConfigured,
                    sessionState: sessionState,
                    hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence,
                    lastExitCode: executionController.lastExitCode,
                    lastValidationExitCode: executionController.lastValidationExitCode,
                    isRunning: executionController.isRunning,
                    packetEvidenceAvailable: packetEvidenceAvailable,
                    sourceState: evidenceSourceState,
                    plannedRouteNote: "\(operatorPlan.sessionMode.displayName) · \(report.configuration.profileName)"
                )
            )

            AppSessionActionSummaryLayout(
                action: sessionSummary.nextAction,
                report: report,
                operatorPlan: operatorPlan,
                executionController: executionController,
                channelCount: channelCount,
                navigateToSection: navigateToSection
            )

            AppExecutionView(
                operatorSurface: $operatorSurface,
                executionController: executionController,
                plan: operatorPlan,
                inputsLocked: inputsLocked
            )

            DisclosureGroup("Commands and logs") {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    AppOperatorCommandsView(plan: operatorPlan)
                    AppLogsView(executionController: executionController)
                }
                .padding(.top, AppSpacing.s)
            }
            .operatorDisclosureRow()
        }
    }
}

struct AppSessionActionSummaryLayout: View {
    let action: AppOverviewNextAction
    let report: NativeAppShellReport
    let operatorPlan: AppOperatorPrototypePlan
    let executionController: AppExecutionController
    let channelCount: Int
    let navigateToSection: (NativeAppShellSurfaceSectionID) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AppSpacing.m) {
                nextAction
                Divider()
                    .frame(height: 126)
                runSummary
            }
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                nextAction
                Divider()
                runSummary
            }
        }
        .padding(AppSpacing.m)
        .background(AppDesignSystem.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
    }

    private var nextAction: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Label("Next action", systemImage: action.systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(action.title)
                .font(.title3.weight(.semibold))
            Text(action.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Button {
                navigateToSection(action.targetSection)
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Text(action.targetSectionLabel)
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
    }

    private var runSummary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Label("Run summary", systemImage: "list.bullet.rectangle")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: AppSpacing.l, verticalSpacing: AppSpacing.xs) {
                summaryRow("Workflow", operatorPlan.sessionMode.displayName)
                summaryRow("Profile", report.configuration.profileName)
                summaryRow("Audio channels", "\(channelCount)", monospaced: true)
                summaryRow("Elapsed", elapsedDuration, monospaced: true)
                summaryRow("Evidence", evidenceTitle)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
    }

    private var elapsedDuration: String {
        let seconds = executionController.elapsedSeconds
        return seconds == 0
            ? "Not started"
            : String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var evidenceTitle: String {
        if executionController.hasValidatedRuntimeEvidence { return "Validated" }
        if executionController.lastValidationExitCode != nil { return "Incomplete" }
        return "Not measured"
    }

    private func summaryRow(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        GridRow {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(monospaced ? .caption.monospacedDigit() : .caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}

private extension View {
    func operatorDisclosureRow() -> some View {
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
