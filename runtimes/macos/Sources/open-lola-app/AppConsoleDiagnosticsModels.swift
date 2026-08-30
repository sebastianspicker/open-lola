// Defines console diagnostics and packet-monitor presentation, keeping evidence state separate from navigation.
import OpenLolaCore

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
