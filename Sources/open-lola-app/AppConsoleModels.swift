// Defines console rows and filters, keeping log presentation data separate from process execution.
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

    @MainActor
    static func make(
        report: NativeAppShellReport,
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController,
        captureReport: LoLaCompatibilityCaptureReport?
    ) -> AppConsoleStatusSnapshot {
        AppConsoleStatusSnapshot(
            verdictTitle: sourceChecksTitle(report),
            verdictTone: tone(for: report.verdict),
            executionTitle: executionController.status,
            executionTone: executionController.isRunning ? AppDesignSystem.stateConnecting : .secondary,
            validationTitle: validationTitle(
                report: report,
                plan: plan,
                executionController: executionController
            ),
            validationTone: validationTone(plan: plan, executionController: executionController),
            packetTitle: packetTitle(captureReport),
            packetTone: captureReport == nil ? .secondary : tone(for: captureReport?.verdict ?? .partial),
            remoteStreamTitle: remoteStreamTitle(plan: plan, executionController: executionController),
            remoteStreamTone: remoteStreamTone(plan: plan, executionController: executionController)
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
        if plan.sessionMode.externalConnectorKind != nil {
            return executionController.lastExternalConnectorReport == nil
                ? "\(plan.sessionMode.displayName) report not loaded"
                : "\(plan.sessionMode.displayName) report loaded"
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
        if plan.sessionMode.externalConnectorKind != nil {
            return executionController.lastExternalConnectorReport == nil ? .secondary : AppDesignSystem.stateConnecting
        }
        return plan.macB == nil ? .secondary : AppDesignSystem.stateConnecting
    }

    @MainActor
    private static func validationTitle(
        report: NativeAppShellReport,
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController
    ) -> String {
        if let validationExitCode = executionController.lastValidationExitCode {
            guard validationExitCode == 0 else {
                return "Validation failed"
            }
            return executionController.hasValidatedRuntimeEvidence
                ? AppCopyVocabulary.measuredReportValidated
                : AppCopyVocabulary.measuredReportIncomplete
        }
        if plan.sessionMode.externalConnectorKind != nil {
            return plan.isConfigured ? sourceChecksTitle(report) : "Setup required"
        }
        return plan.report == nil ? "Setup required" : sourceChecksTitle(report)
    }

    @MainActor
    private static func validationTone(
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController
    ) -> Color {
        if let validationExitCode = executionController.lastValidationExitCode {
            guard validationExitCode == 0 else {
                return AppDesignSystem.stateError
            }
            return executionController.hasValidatedRuntimeEvidence
                ? AppDesignSystem.stateLive
                : AppDesignSystem.stateWarning
        }
        if plan.sessionMode.externalConnectorKind != nil {
            return plan.isConfigured ? AppDesignSystem.stateConnecting : AppDesignSystem.stateWarning
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

    private static func sourceChecksTitle(_ report: NativeAppShellReport) -> String {
        "\(AppCopyVocabulary.sourceSyntheticReport) · \(report.verdict.rawValue.capitalized)"
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

enum AppCopyVocabulary {
    static let windowsLoLaConnector = "Windows LoLa connector"
    static let windowsLoLaReportNotLoaded = "Windows LoLa report not loaded"
    static let windowsLoLaReportLoaded = "Windows LoLa report loaded"
    static let sourceSyntheticReport = "Source checks"
    static let sourceSyntheticPartial = "Source checks · Partial"
    static let sourceSyntheticBaseline = "Not measured"
    static let currentRuntimeEvidence = "Measured report"
    static let measuredReportValidated = "Measured report · Validated"
    static let measuredReportIncomplete = "Measured report · Incomplete"
    static let stale = "Stale"
    static let notMeasured = "Not measured"
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
        _: NativeAppShellSurfaceSectionID,
        sessionState _: AppSessionState,
        captureReportAvailable _: Bool
    ) -> Bool {
        true
    }
}

struct AppPacketMonitorEmptyState: Equatable {
    let title: String
    let reason: String
    let expectedReportPath: String
    let actionTitle: String
    let targetSection: NativeAppShellSurfaceSectionID

    static func make(
        plan: AppOperatorPrototypePlan,
        executionSettings: NativeAppShellExecutionSettings
    ) -> AppPacketMonitorEmptyState {
        let path = plan.sessionMode == .windowsLoLa
            ? plan.windowsLoLaFields.outputPath
            : plan.sessionMode.externalConnectorKind != nil
            ? plan.externalConnectorFields.outputPath
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
            realtimeSafetyTitle: realtimeSafe(report.realtimeBoundary)
                ? "Source boundary safe"
                : "Source review required",
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
            return AppCopyVocabulary.measuredReportValidated
        }
        if executionController.lastValidationExitCode == 0 {
            return AppCopyVocabulary.measuredReportIncomplete
        }
        if executionController.lastLatencyMetrics != nil || executionController.lastExternalConnectorReport != nil {
            return AppCopyVocabulary.measuredReportIncomplete
        }
        if report.id.contains("placeholder") {
            return "\(AppCopyVocabulary.sourceSyntheticReport) · \(AppCopyVocabulary.notMeasured)"
        }
        if report.runMode == .synthetic {
            return "\(AppCopyVocabulary.sourceSyntheticReport) · \(report.verdict.rawValue.capitalized)"
        }
        return AppCopyVocabulary.notMeasured
    }

    @MainActor
    private static func evidenceDetail(
        report: NativeAppShellReport,
        executionController: AppExecutionController
    ) -> String {
        if let error = executionController.lastError {
            return error
        }
        if executionController.lastValidationExitCode == 0,
           !executionController.hasValidatedRuntimeEvidence {
            return "Validator exited 0, but current runtime evidence is incomplete."
        }
        if executionController.hasValidatedRuntimeEvidence {
            return "Validated measured report evidence is loaded."
        }
        if report.runMode == .synthetic {
            return "Current source checks are synthetic and cannot prove field readiness."
        }
        return "No measured report is loaded."
    }
}
