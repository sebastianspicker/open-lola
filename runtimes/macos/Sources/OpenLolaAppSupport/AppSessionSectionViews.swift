// Composes the Quiet signal check, run and review stages over the existing runtime controller.
import OpenLolaCore
import SwiftUI

struct AppSessionSectionView: View {
    let report: NativeAppShellReport
    var phase: AppSessionPhase? = nil
    let previewState: AppPreviewReceiverState
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let executionController: AppExecutionController
    let operatorPlan: AppOperatorPrototypePlan
    let captureReport: LoLaCompatibilityCaptureReport?
    let sessionState: AppSessionState
    let inputsLocked: Bool
    let navigateToSection: (NativeAppShellSurfaceSectionID) -> Void

    private var selectedPhase: AppSessionPhase {
        phase ?? AppSessionPhaseRailPolicy.currentPhase(
            sessionState: sessionState,
            hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence,
            lastExitCode: executionController.lastExitCode
        )
    }

    private var summary: AppQuietSessionSummary {
        AppQuietSessionSummary(surface: operatorSurface, plan: operatorPlan)
    }

    private var packetEvidenceAvailable: Bool {
        AppConnectionTopologyAnimationPolicy.hasPacketEvidence(captureReport)
    }

    private var evidenceSourceState: String { report.verdict.rawValue.capitalized }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            heading
            switch selectedPhase {
            case .setup, .ready:
                checkWorkspace
            case .live:
                runWorkspace
            case .review:
                reviewWorkspace
            }
            AppExecutionView(
                operatorSurface: $operatorSurface,
                executionController: executionController,
                plan: operatorPlan,
                inputsLocked: inputsLocked
            )
            DisclosureGroup("Evidence chain and measured latency") {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    topologyDetails
                    evidenceDetails
                    AppLatencyHeroView(
                        audioLatencyMs: executionController.lastLatencyMetrics?.audioLatencyMs,
                        packetLossPercent: executionController.lastLatencyMetrics?.packetLossPercent,
                        jitterMs: executionController.lastLatencyMetrics?.jitterMs,
                        evidenceStatusMessage: executionController.lastLatencyMetrics?.evidenceStatusMessage
                    )
                }.padding(.top, AppSpacing.s)
            }
            DisclosureGroup("Commands and logs") {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    AppOperatorCommandsView(plan: operatorPlan)
                    AppLogsView(executionController: executionController)
                }.padding(.top, AppSpacing.s)
            }
        }
    }

    private var heading: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.l) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text(pageTitle).font(.system(size: 38, weight: .semibold))
                Text("\(summary.localPeer) ↔ \(summary.remotePeer) · \(summary.durationSeconds)-second run")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: AppSpacing.s)
            if selectedPhase == .live {
                VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                    Label(sessionState.rawValue, systemImage: sessionState.systemImage)
                        .font(.callout.weight(.medium))
                    Text(String(format: "%02d:%02d / %02d:%02d",
                                executionController.elapsedSeconds / 60,
                                executionController.elapsedSeconds % 60,
                                summary.durationSeconds / 60,
                                summary.durationSeconds % 60))
                        .font(.system(.title3, design: .monospaced))
                }
            }
        }
        .padding(.bottom, AppSpacing.s)
    }

    private var pageTitle: String {
        switch selectedPhase {
        case .setup, .ready:
            operatorPlan.isConfigured ? "Review before transmitting" : "Complete your configuration"
        case .live:
            executionController.isRunning ? "Session in progress" : "Ready for a run"
        case .review:
            executionController.lastExitCode == 0 ? "Run completed" : "Review the evidence"
        }
    }

    private var checkWorkspace: some View {
        AppQuietColumns {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                AppQuietWorksheet(title: "Configured media", rows: summary.rows)
                Label("Physical latency has not been established by configuration.", systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } aside: {
            AppQuietReadiness(surface: operatorSurface, plan: operatorPlan, summary: summary, navigate: navigateToSection)
        }
    }

    private var runWorkspace: some View {
        AppQuietColumns {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                plannedPath
                observationTable
            }
        } aside: {
            AppQuietPreviewStatus(previewState: previewState, navigate: navigateToSection)
        }
    }

    private var plannedPath: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Configured signal path").font(.title3.weight(.semibold))
            HStack(spacing: AppSpacing.m) {
                Text(summary.localPeer)
                Circle().stroke(AppDesignSystem.interactionAccent, lineWidth: 1).frame(width: 10, height: 10)
                Rectangle().fill(AppDesignSystem.signalAccent).frame(height: 1)
                    .accessibilityHidden(true)
                Circle().stroke(AppDesignSystem.interactionAccent, lineWidth: 1).frame(width: 10, height: 10)
                Text(summary.remotePeer)
            }
            .font(.callout)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Configured route from \(summary.localPeer) to \(summary.remotePeer)")
            Text("\(operatorPlan.sessionMode.displayName) · Configuration, not proof of media flow")
                .font(.caption)
                .foregroundStyle(.secondary)
            DisclosureGroup("Media configuration") {
                AppQuietWorksheet(title: "Selected formats", rows: summary.rows)
                    .padding(.top, AppSpacing.s)
            }
        }
        .padding(AppSpacing.l)
        .background(AppDesignSystem.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(AppDesignSystem.panelBorder, lineWidth: 0.5) }
    }

    private var observationTable: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            AppQuietWorksheet(title: "Recorded observations", rows: [
                .init(label: "Session process", value: executionController.status),
                .init(label: "Process exit", value: AppProcessExitDisplay.title(executionController.lastExitCode)),
                .init(label: "Audio p99", value: metric(executionController.lastLatencyMetrics?.audioLatencyMs, unit: "ms")),
                .init(label: "Packet loss", value: metric(executionController.lastLatencyMetrics?.packetLossPercent, unit: "%")),
                .init(label: "Jitter", value: metric(executionController.lastLatencyMetrics?.jitterMs, unit: "ms"))
            ])
            Text("Worst-peer audio p99 and packet metrics are from loaded reports, not live telemetry.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var reviewWorkspace: some View {
        AppQuietColumns {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                observationTable
                if let message = executionController.lastLatencyMetrics?.evidenceStatusMessage {
                    Text(message).font(.callout).foregroundStyle(AppDesignSystem.stateWarning)
                }
            }
        } aside: {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                Text("Evidence summary").font(.title3.weight(.semibold))
                Label(executionController.hasValidatedRuntimeEvidence ? "Runtime evidence validated" : "Runtime evidence incomplete",
                      systemImage: executionController.hasValidatedRuntimeEvidence ? "checkmark.seal" : "info.circle")
                    .foregroundStyle(executionController.hasValidatedRuntimeEvidence ? AppDesignSystem.stateLive : .secondary)
                Text("A completed process does not establish physical performance. Validate the current report to inspect its evidence scope.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Reports and validation", systemImage: "doc.text.magnifyingglass") {
                    navigateToSection(.validation)
                }.buttonStyle(.bordered)
                Button("Configure another run", systemImage: "arrow.right") {
                    navigateToSection(.devices)
                }.buttonStyle(.borderless)
                Button("Inspect packet evidence", systemImage: "tablecells") {
                    navigateToSection(.packetMonitor)
                }.buttonStyle(.borderless)
            }
        }
    }

    private func metric(_ value: Double?, unit: String) -> String {
        value.map { String(format: "%.2f %@", $0, unit) } ?? "Not measured"
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

    private var profileCaption: String {
        let profile = report.configuration.profileName
        let rx = operatorPlan.rxBufferProfile.rawValue
        return rx.isEmpty ? profile : "\(profile) · RX \(rx)"
    }

    private var localDeviceLabel: String? {
        let selection = report.configuration.audioDeviceSelection.trimmingCharacters(in: .whitespacesAndNewlines)
        return selection.isEmpty ? nil : selection
    }

    private var topologyDetails: some View {
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

    }

    private var evidenceDetails: some View {
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

    }
}
