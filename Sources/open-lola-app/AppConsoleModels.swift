import OpenLolaCore
import SwiftUI

struct AppConsoleStatusSnapshot {
    let verdictTitle: String
    let verdictTone: Color
    let executionTitle: String
    let executionTone: Color
    let validationTitle: String
    let validationTone: Color
    let packetTitle: String
    let packetTone: Color
    let remoteStreamTitle: String
    let remoteStreamTone: Color
    let searchPlaceholder: String

    @MainActor
    static func make(
        report: NativeAppShellReport,
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController,
        captureReport: LoLaCompatibilityCaptureReport?
    ) -> AppConsoleStatusSnapshot {
        AppConsoleStatusSnapshot(
            verdictTitle: report.verdict.rawValue.uppercased(),
            verdictTone: tone(for: report.verdict),
            executionTitle: executionController.status,
            executionTone: executionController.isRunning ? .green : .secondary,
            validationTitle: validationTitle(plan: plan, executionController: executionController),
            validationTone: validationTone(plan: plan, executionController: executionController),
            packetTitle: packetTitle(captureReport),
            packetTone: captureReport == nil ? .secondary : tone(for: captureReport?.verdict ?? .partial),
            remoteStreamTitle: remoteStreamTitle(plan: plan, executionController: executionController),
            remoteStreamTone: remoteStreamTone(plan: plan, executionController: executionController),
            searchPlaceholder: "Filter current operator surface"
        )
    }

    @MainActor
    private static func remoteStreamTitle(
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController
    ) -> String {
        if plan.sessionMode == .windowsLoLa {
            return executionController.lastExternalConnectorReport == nil
                ? "LoLa not measured"
                : "LoLa report loaded"
        }
        if plan.sessionMode.unavailableAppReason != nil {
            return "\(plan.sessionMode.displayName) unavailable"
        }
        return plan.macB == nil ? "Remote unavailable" : "Remote plan only"
    }

    @MainActor
    private static func remoteStreamTone(
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController
    ) -> Color {
        if plan.sessionMode == .windowsLoLa {
            return executionController.lastExternalConnectorReport == nil ? .secondary : .blue
        }
        if plan.sessionMode.unavailableAppReason != nil {
            return .orange
        }
        return plan.macB == nil ? .secondary : .blue
    }

    @MainActor
    private static func validationTitle(
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController
    ) -> String {
        if let validationExitCode = executionController.lastValidationExitCode {
            return validationExitCode == 0 && executionController.hasValidatedRuntimeEvidence
                ? "Report validated"
                : "Validation failed"
        }
        if plan.sessionMode.unavailableAppReason != nil {
            return "Runtime unavailable"
        }
        return plan.report == nil ? "Setup required" : "Source-level PARTIAL"
    }

    @MainActor
    private static func validationTone(
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController
    ) -> Color {
        if let validationExitCode = executionController.lastValidationExitCode {
            return validationExitCode == 0 && executionController.hasValidatedRuntimeEvidence ? .green : .red
        }
        if plan.sessionMode.unavailableAppReason != nil {
            return .orange
        }
        return plan.report == nil ? .orange : .blue
    }

    private static func packetTitle(_ report: LoLaCompatibilityCaptureReport?) -> String {
        guard let report else {
            return "Packet monitor unavailable"
        }
        return "\(sanitizedPacketCount(report.summary.packetCount)) packets decoded"
    }

    private static func sanitizedPacketCount(_ packetCount: Int) -> Int {
        max(0, packetCount)
    }

    static func tone(for verdict: MeasurementVerdict) -> Color {
        switch verdict {
        case .pass:
            return .green
        case .partial:
            return .orange
        case .fail:
            return .red
        @unknown default:
            return .secondary
        }
    }
}

struct AppOverviewStatusItem: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
}

struct AppOverviewNextAction: Equatable {
    let title: String
    let detail: String
    let targetSection: NativeAppShellSurfaceSectionID
    let systemImage: String
}

struct AppOverviewEvidenceSummary: Equatable {
    let sourceVerdict: String
    let runtimeEvidence: String
    let latestReportPath: String
    let freshness: String
}

struct AppOverviewOperatorSummary: Equatable {
    let statusItems: [AppOverviewStatusItem]
    let nextAction: AppOverviewNextAction
    let evidence: AppOverviewEvidenceSummary

    @MainActor
    static func make(
        report: NativeAppShellReport,
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController,
        sessionState: AppSessionState,
        captureReport: LoLaCompatibilityCaptureReport?
    ) -> AppOverviewOperatorSummary {
        AppOverviewOperatorSummary(
            statusItems: [
                AppOverviewStatusItem(
                    id: "readiness",
                    title: "Readiness",
                    value: plan.isConfigured ? "Configured" : "Setup required",
                    systemImage: "flag"
                ),
                AppOverviewStatusItem(
                    id: "session",
                    title: "Session",
                    value: sessionState.rawValue,
                    systemImage: sessionState.systemImage
                ),
                AppOverviewStatusItem(
                    id: "execution",
                    title: "Execution",
                    value: executionController.status,
                    systemImage: "terminal"
                ),
                AppOverviewStatusItem(
                    id: "validation",
                    title: "Validation",
                    value: validationStatus(executionController),
                    systemImage: "checklist.checked"
                ),
                AppOverviewStatusItem(
                    id: "packets",
                    title: "Packet Evidence",
                    value: packetEvidenceStatus(captureReport),
                    systemImage: "tablecells"
                ),
            ],
            nextAction: nextAction(
                plan: plan,
                executionController: executionController,
                sessionState: sessionState,
                captureReport: captureReport
            ),
            evidence: AppOverviewEvidenceSummary(
                sourceVerdict: report.verdict.rawValue.uppercased(),
                runtimeEvidence: runtimeEvidenceStatus(executionController),
                latestReportPath: latestReportPath(plan: plan, executionController: executionController),
                freshness: freshness(executionController: executionController, captureReport: captureReport)
            )
        )
    }

    @MainActor
    private static func nextAction(
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController,
        sessionState: AppSessionState,
        captureReport: LoLaCompatibilityCaptureReport?
    ) -> AppOverviewNextAction {
        if !plan.isConfigured {
            return AppOverviewNextAction(
                title: "Configure devices",
                detail: "Import or select local and remote media inventory before arming a run.",
                targetSection: .devices,
                systemImage: "slider.horizontal.below.rectangle"
            )
        }
        if executionController.isRunning || sessionState == .supervisorRunning || sessionState == .dryRunRunning {
            return AppOverviewNextAction(
                title: "Monitor the run",
                detail: "Execution is active. Watch session state and logs before validating evidence.",
                targetSection: .session,
                systemImage: "dot.radiowaves.left.and.right"
            )
        }
        if sessionState == .error || executionController.phase == .failedToStart || executionController.phase == .runFailed {
            return AppOverviewNextAction(
                title: "Inspect the failure",
                detail: executionController.lastError ?? "The last execution did not complete successfully.",
                targetSection: .diagnostics,
                systemImage: "exclamationmark.triangle"
            )
        }
        if executionController.lastValidationExitCode == 0, !executionController.hasValidatedRuntimeEvidence {
            return AppOverviewNextAction(
                title: "Resolve evidence gap",
                detail: "The validator exited cleanly, but current runtime evidence is incomplete.",
                targetSection: .validation,
                systemImage: "clock.badge.exclamationmark"
            )
        }
        if executionController.armedForExecution {
            return AppOverviewNextAction(
                title: "Start armed supervisor",
                detail: "Configuration is locked for an explicit run request.",
                targetSection: .session,
                systemImage: "play.fill"
            )
        }
        if executionController.hasValidatedRuntimeEvidence {
            return AppOverviewNextAction(
                title: captureReport == nil ? "Inspect validation evidence" : "Inspect packet evidence",
                detail: captureReport == nil
                    ? "Runtime evidence validated; decoded packet evidence has not been loaded."
                    : "Decoded packet evidence is available for stream inspection.",
                targetSection: captureReport == nil ? .validation : .packetMonitor,
                systemImage: captureReport == nil ? "checkmark.seal" : "tablecells"
            )
        }
        return AppOverviewNextAction(
            title: "Arm or dry-run",
            detail: "Configuration is ready. Use Session to arm execution or run a dry-run supervisor.",
            targetSection: .session,
            systemImage: "checkmark.shield"
        )
    }

    @MainActor
    private static func validationStatus(_ executionController: AppExecutionController) -> String {
        guard let exitCode = executionController.lastValidationExitCode else {
            return "Not run"
        }
        if exitCode == 0, executionController.hasValidatedRuntimeEvidence {
            return "Validated"
        }
        return "Evidence incomplete"
    }

    private static func packetEvidenceStatus(_ captureReport: LoLaCompatibilityCaptureReport?) -> String {
        guard let captureReport else {
            return "Missing"
        }
        return "\(max(0, captureReport.summary.packetCount)) decoded"
    }

    @MainActor
    private static func runtimeEvidenceStatus(_ executionController: AppExecutionController) -> String {
        if executionController.hasValidatedRuntimeEvidence {
            return "Measured and validated"
        }
        if executionController.lastLatencyMetrics != nil || executionController.lastExternalConnectorReport != nil {
            return "Loaded but incomplete"
        }
        return "Missing current measurement"
    }

    @MainActor
    private static func latestReportPath(
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController
    ) -> String {
        if plan.sessionMode == .windowsLoLa {
            return plan.windowsLoLaFields.outputPath
        }
        return executionController.settings.supervisorReportPath
    }

    @MainActor
    private static func freshness(
        executionController: AppExecutionController,
        captureReport: LoLaCompatibilityCaptureReport?
    ) -> String {
        if executionController.isRunning {
            return "Run in progress"
        }
        if executionController.lastValidationExitCode != nil {
            return "Last validator result"
        }
        if captureReport != nil {
            return "Loaded capture report"
        }
        return "Source-level baseline"
    }
}

enum AppConsoleSectionSelection {
    static func activeSection(
        current: NativeAppShellSurfaceSectionID,
        visibleSections: [NativeAppShellSurfaceSection],
        sessionState: AppSessionState,
        captureReportAvailable: Bool
    ) -> NativeAppShellSurfaceSectionID? {
        let visibleIDs = Set(visibleSections.map(\.id))
        guard visibleIDs.contains(current),
              isAvailable(current, sessionState: sessionState, captureReportAvailable: captureReportAvailable) else {
            return nil
        }
        return current
    }

    static func resolvedSection(
        current: NativeAppShellSurfaceSectionID,
        visibleSections: [NativeAppShellSurfaceSection],
        sessionState: AppSessionState,
        captureReportAvailable: Bool
    ) -> NativeAppShellSurfaceSectionID? {
        activeSection(
            current: current,
            visibleSections: visibleSections,
            sessionState: sessionState,
            captureReportAvailable: captureReportAvailable
        )
            ?? replacementSection(
                visibleSections: visibleSections,
                sessionState: sessionState,
                captureReportAvailable: captureReportAvailable
            )
    }

    private static func replacementSection(
        visibleSections: [NativeAppShellSurfaceSection],
        sessionState: AppSessionState,
        captureReportAvailable: Bool
    ) -> NativeAppShellSurfaceSectionID? {
        visibleSections.first {
            isAvailable($0.id, sessionState: sessionState, captureReportAvailable: captureReportAvailable)
        }?.id
    }

    private static func isAvailable(
        _ section: NativeAppShellSurfaceSectionID,
        sessionState: AppSessionState,
        captureReportAvailable: Bool
    ) -> Bool {
        section != .packetMonitor || sessionState != .unconfigured
    }
}

struct AppValidationRow: Identifiable {
    let id: String
    let title: String
    let detail: String
    let tone: Color

    @MainActor
    static func rows(
        report: NativeAppShellReport,
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController,
        surfaceProbe: NativeAppShellSurfaceProbeReport
    ) -> [AppValidationRow] {
        [
            AppValidationRow(
                id: "source-report",
                title: "Native app shell report",
                detail: report.verdict.rawValue.uppercased(),
                tone: AppConsoleStatusSnapshot.tone(for: report.verdict)
            ),
            AppValidationRow(
                id: "two-peer-plan",
                title: planValidationTitle(plan),
                detail: planValidationDetail(plan),
                tone: plan.isConfigured ? .blue : .orange
            ),
            AppValidationRow(
                id: "surface-probe",
                title: "Surface probe",
                detail: surfaceProbe.verdict.rawValue.uppercased(),
                tone: AppConsoleStatusSnapshot.tone(for: surfaceProbe.verdict)
            ),
            AppValidationRow(
                id: "supervisor-report",
                title: "Supervisor report",
                detail: executionController.lastValidationExitCode.map {
                    $0 == 0 && executionController.hasValidatedRuntimeEvidence ? "validated" : "failed"
                }
                    ?? "not measured",
                tone: executionController.lastValidationExitCode.map {
                    $0 == 0 && executionController.hasValidatedRuntimeEvidence ? .green : .red
                } ?? .secondary
            ),
        ]
    }

    private static func planValidationTitle(_ plan: AppOperatorPrototypePlan) -> String {
        switch plan.sessionMode {
        case .directMacPeer:
            return "Two-peer plan"
        case .windowsLoLa:
            return "LoLa command"
        case .jackTrip, .ultraGrid:
            return "\(plan.sessionMode.displayName) runtime"
        }
    }

    private static func planValidationDetail(_ plan: AppOperatorPrototypePlan) -> String {
        switch plan.sessionMode {
        case .directMacPeer:
            return plan.report?.verdict.rawValue.uppercased() ?? "PARTIAL: remote selection incomplete"
        case .windowsLoLa:
            return plan.windowsLoLaCommand == nil ? "PARTIAL: fields incomplete" : "PARTIAL: external endpoint required"
        case .jackTrip, .ultraGrid:
            return plan.sessionMode.unavailableAppReason ?? "PARTIAL: app runtime unavailable"
        }
    }
}

enum AppValidationPreflightVerdict: String, Equatable {
    case ready = "Ready"
    case blocked = "Blocked"
    case running = "Running"
    case evidenceIncomplete = "Evidence incomplete"
}

struct AppValidationBlocker: Equatable, Identifiable {
    let id: String
    let title: String
    let remediation: String
    let targetSection: NativeAppShellSurfaceSectionID
}

struct AppValidationPreflightModel: Equatable {
    let verdict: AppValidationPreflightVerdict
    let detail: String
    let blockers: [AppValidationBlocker]

    @MainActor
    static func make(
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController,
        surfaceProbe: NativeAppShellSurfaceProbeReport
    ) -> AppValidationPreflightModel {
        if executionController.isRunning || executionController.phase == .supervisorRunning || executionController.phase == .dryRunRunning {
            return AppValidationPreflightModel(
                verdict: .running,
                detail: "A run is active; validation waits for the report artifact.",
                blockers: [
                    AppValidationBlocker(
                        id: "running",
                        title: "Execution is still running",
                        remediation: "Stop or let the Session run complete before validating its report.",
                        targetSection: .session
                    ),
                ]
            )
        }

        var blockers: [AppValidationBlocker] = []
        if !plan.isConfigured {
            blockers.append(AppValidationBlocker(
                id: "plan",
                title: "\(plan.sessionMode.displayName) setup is incomplete",
                remediation: plan.validationError ?? "Complete device inventory and routing fields.",
                targetSection: plan.sessionMode == .directMacPeer ? .devices : .routing
            ))
        }
        if surfaceProbe.verdict == .fail {
            blockers.append(AppValidationBlocker(
                id: "surface",
                title: "Surface probe failed",
                remediation: "Re-run the app launch verifier and inspect launch logs.",
                targetSection: .diagnostics
            ))
        }
        if let error = executionController.lastError, executionController.phase == .validationFailed {
            blockers.append(AppValidationBlocker(
                id: "last-error",
                title: "Last validation failed",
                remediation: error,
                targetSection: .diagnostics
            ))
        }

        if !blockers.isEmpty {
            return AppValidationPreflightModel(
                verdict: .blocked,
                detail: "Resolve blockers before treating any validation result as current runtime evidence.",
                blockers: blockers
            )
        }
        if executionController.lastValidationExitCode == 0, !executionController.hasValidatedRuntimeEvidence {
            return AppValidationPreflightModel(
                verdict: .evidenceIncomplete,
                detail: "The validator exited with 0, but measured evidence is missing, stale, or only PARTIAL.",
                blockers: [
                    AppValidationBlocker(
                        id: "evidence",
                        title: "Runtime evidence is incomplete",
                        remediation: "Run or load a current PASS supervisor or external connector report.",
                        targetSection: .session
                    ),
                ]
            )
        }
        return AppValidationPreflightModel(
            verdict: .ready,
            detail: "Configuration is complete enough to run or validate the current report path.",
            blockers: []
        )
    }
}

struct AppPacketMonitorEmptyState: Equatable {
    let title: String
    let reason: String
    let expectedReportPath: String
    let actionTitle: String
    let targetSection: NativeAppShellSurfaceSectionID

    static func make(plan: AppOperatorPrototypePlan, executionSettings: NativeAppShellExecutionSettings) -> AppPacketMonitorEmptyState {
        let path = plan.sessionMode == .windowsLoLa
            ? plan.windowsLoLaFields.outputPath
            : executionSettings.supervisorReportPath
        return AppPacketMonitorEmptyState(
            title: "Packet evidence unavailable",
            reason: "No decoded LoLa compatibility capture report is loaded for this operator session.",
            expectedReportPath: path,
            actionTitle: "Run and validate evidence",
            targetSection: .session
        )
    }
}

struct AppDiagnosticsStatusModel: Equatable {
    let permissionsTitle: String
    let realtimeSafetyTitle: String
    let processTitle: String
    let evidenceTitle: String
    let evidenceDetail: String

    @MainActor
    static func make(
        report: NativeAppShellReport,
        executionController: AppExecutionController
    ) -> AppDiagnosticsStatusModel {
        AppDiagnosticsStatusModel(
            permissionsTitle: permissionsReady(report.permissions) ? "Ready" : "Incomplete",
            realtimeSafetyTitle: realtimeSafe(report.realtimeBoundary) ? "Callback-safe" : "Review required",
            processTitle: executionController.isRunning
                ? "Running"
                : executionController.lastExitCode.map { "Exit \($0)" } ?? "Idle",
            evidenceTitle: evidenceTitle(report: report, executionController: executionController),
            evidenceDetail: evidenceDetail(report: report, executionController: executionController)
        )
    }

    private static func permissionsReady(_ permissions: NativePermissionReadiness) -> Bool {
        permissions.microphoneUsageDescriptionPlanned
            && permissions.cameraUsageDescriptionPlanned
            && permissions.localNetworkUsageDescriptionPlanned
            && permissions.networkClientEntitlementPlanned
    }

    private static func realtimeSafe(_ boundary: NativeRealtimeBoundaryReport) -> Bool {
        !boundary.uiOwnsAudioLane
            && !boundary.uiOwnsVideoLane
            && !boundary.uiOwnsControlLane
            && !boundary.realtimeDependsOnSwiftUILifecycle
            && boundary.usesImmutableConfigSnapshots
            && boundary.latencyChangeRequiresExplicitUserAction
            && boundary.settingsPersistedOutsideCallback
    }

    @MainActor
    private static func evidenceTitle(
        report: NativeAppShellReport,
        executionController: AppExecutionController
    ) -> String {
        if executionController.hasValidatedRuntimeEvidence {
            return "Live measured"
        }
        if executionController.lastLatencyMetrics != nil || executionController.lastExternalConnectorReport != nil {
            return "Loaded partial"
        }
        if report.runMode == .synthetic {
            return "Synthetic source"
        }
        return "Missing"
    }

    @MainActor
    private static func evidenceDetail(
        report: NativeAppShellReport,
        executionController: AppExecutionController
    ) -> String {
        if let error = executionController.lastError {
            return error
        }
        if executionController.hasValidatedRuntimeEvidence {
            return "Validation loaded current runtime report evidence."
        }
        if report.runMode == .synthetic {
            return "Current source report is synthetic and cannot prove field readiness."
        }
        return "No current measured report is loaded."
    }
}
