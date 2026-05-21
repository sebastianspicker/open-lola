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
            executionTone: executionController.isRunning ? AppDesignSystem.stateConnecting : .secondary,
            validationTitle: validationTitle(plan: plan, executionController: executionController),
            validationTone: validationTone(plan: plan, executionController: executionController),
            packetTitle: packetTitle(captureReport),
            packetTone: captureReport == nil ? .secondary : tone(for: captureReport?.verdict ?? .partial),
            remoteStreamTitle: remoteStreamTitle(plan: plan, executionController: executionController),
            remoteStreamTone: remoteStreamTone(plan: plan, executionController: executionController),
            searchPlaceholder: AppConsoleSearchCopy.placeholder
        )
    }

    @MainActor
    private static func remoteStreamTitle(
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController
    ) -> String {
        if plan.sessionMode == .windowsLoLa {
            return executionController.lastExternalConnectorReport == nil
                ? AppCopyVocabulary.windowsLoLaReportNotLoaded
                : AppCopyVocabulary.windowsLoLaReportLoaded
        }
        if plan.sessionMode.unavailableAppReason != nil {
            return "\(plan.sessionMode.displayName) launcher unavailable"
        }
        return plan.macB == nil ? AppCopyVocabulary.remotePlanUnavailable : AppCopyVocabulary.remotePlanOnly
    }

    @MainActor
    private static func remoteStreamTone(
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController
    ) -> Color {
        if plan.sessionMode == .windowsLoLa {
            return executionController.lastExternalConnectorReport == nil ? .secondary : AppDesignSystem.stateConnecting
        }
        if plan.sessionMode.unavailableAppReason != nil {
            return AppDesignSystem.stateWarning
        }
        return plan.macB == nil ? .secondary : AppDesignSystem.stateConnecting
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
        return plan.report == nil ? "Setup required" : AppCopyVocabulary.sourceSyntheticPartial
    }

    @MainActor
    private static func validationTone(
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController
    ) -> Color {
        if let validationExitCode = executionController.lastValidationExitCode {
            return validationExitCode == 0 && executionController.hasValidatedRuntimeEvidence
                ? AppDesignSystem.stateLive
                : AppDesignSystem.stateError
        }
        if plan.sessionMode.unavailableAppReason != nil {
            return AppDesignSystem.stateWarning
        }
        return plan.report == nil ? AppDesignSystem.stateWarning : AppDesignSystem.stateConnecting
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
            return AppDesignSystem.stateLive
        case .partial:
            return AppDesignSystem.stateWarning
        case .fail:
            return AppDesignSystem.stateError
        @unknown default:
            return .secondary
        }
    }
}

enum AppConsoleSearchCopy {
    static let placeholder = "Filter sections"
    static let accessibilityLabel = "Filter sections"
    static let accessibilityHint = "Filters the sidebar section list. It does not search inside the current section."
}

enum AppCopyVocabulary {
    static let windowsLoLaConnector = "Windows LoLa connector"
    static let windowsLoLaReportNotLoaded = "Windows LoLa report not loaded"
    static let windowsLoLaReportLoaded = "Windows LoLa report loaded"
    static let sourceSyntheticReport = "Source/synthetic report"
    static let sourceSyntheticPartial = "Source/synthetic PARTIAL"
    static let sourceSyntheticBaseline = "Source/synthetic baseline"
    static let currentRuntimeEvidence = "Current runtime evidence"
    static let packetEvidence = "Packet evidence"
    static let remotePacketEvidence = "Remote packet evidence"
    static let remotePlanUnavailable = "Remote plan unavailable"
    static let remotePlanOnly = "Remote plan only"
    static let remotePlanOnlyNoReceivedMedia = "Remote plan only; no received-media proof"
    static let packetCaptureReportLoaded = "Packet capture report loaded"
    static let noRemotePacketEvidenceMeasured = "No remote packet or media evidence measured"
}

enum AppSyntheticMetricsRefreshState: Equatable {
    case idle
    case refreshing
    case refreshed

    var isRefreshing: Bool {
        self == .refreshing
    }

    var badgeTitle: String {
        switch self {
        case .idle:
            return "Source/synthetic"
        case .refreshing:
            return "Refreshing source/synthetic"
        case .refreshed:
            return "Source/synthetic refreshed"
        }
    }

    var systemImage: String {
        switch self {
        case .idle:
            return "doc.text.magnifyingglass"
        case .refreshing:
            return "arrow.triangle.2.circlepath"
        case .refreshed:
            return "checkmark.seal"
        }
    }

    var tone: Color {
        switch self {
        case .idle:
            return .secondary
        case .refreshing:
            return AppDesignSystem.stateConnecting
        case .refreshed:
            return AppDesignSystem.stateWarning
        }
    }

    var buttonAccessibilityLabel: String {
        "Refresh Source/Synthetic Report"
    }

    var buttonHelp: String {
        switch self {
        case .idle:
            return "Refresh the source/synthetic report. This does not measure live runtime."
        case .refreshing:
            return "Refreshing the source/synthetic report. This does not measure live runtime."
        case .refreshed:
            return "Source/synthetic report refreshed. This is not live runtime evidence."
        }
    }

    var badgeHelp: String {
        switch self {
        case .idle:
            return "Source/synthetic report status. No live runtime measurement is implied."
        case .refreshing:
            return "Source/synthetic report refresh is running. No live runtime measurement is implied."
        case .refreshed:
            return "Source/synthetic report refresh completed. No live runtime measurement is implied."
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
                    title: "Session process",
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
                    title: AppCopyVocabulary.packetEvidence,
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
        if executionController.hasValidatedRuntimeEvidence {
            if executionController.armedForExecution {
                return AppOverviewNextAction(
                    title: "Start armed supervisor",
                    detail: "Current runtime evidence is validated and execution is armed.",
                    targetSection: .session,
                    systemImage: "play.fill"
                )
            }
            return AppOverviewNextAction(
                title: captureReport == nil ? "Arm for Start" : "Inspect packet evidence",
                detail: captureReport == nil
                    ? "Runtime evidence is validated. Arm in Session before starting."
                    : "Decoded packet evidence is available for stream inspection.",
                targetSection: captureReport == nil ? .session : .packetMonitor,
                systemImage: captureReport == nil ? "checkmark.shield" : "tablecells"
            )
        }
        let readiness = appValidationReadiness(plan: plan, executionController: executionController)
        if !readiness.isReady {
            return AppOverviewNextAction(
                title: "Produce current report",
                detail: readiness.unavailableMessage ?? "Run or load a current report before validating or starting.",
                targetSection: .session,
                systemImage: "doc.badge.clock"
            )
        }
        return AppOverviewNextAction(
            title: "Validate current report",
            detail: "The report artifact is current enough to validate. Run validation before Start can enable.",
            targetSection: .validation,
            systemImage: "checkmark.seal"
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
        return AppCopyVocabulary.sourceSyntheticBaseline
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
            title: "No capture data yet",
            reason: "Packet capture data appears here after a session completes and report evidence is validated.",
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
            permissionsTitle: permissionsReady(report.permissions) ? "Planned ready" : "Planned incomplete",
            realtimeSafetyTitle: realtimeSafe(report.realtimeBoundary) ? "Source boundary safe" : "Source review required",
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
        if report.id.contains("placeholder") {
            return "Placeholder source"
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
