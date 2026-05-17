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
        return plan.report == nil ? "Plan incomplete" : "Source-level PARTIAL"
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
        section != .packetMonitor || (sessionState != .unconfigured && captureReportAvailable)
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
