// Validates NativeAppShellSurfaceContractValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension NativeAppShellSurfaceProbeReport {
func validateActions() throws {
        var seen = Set<String>()
        for action in actions {
            try requireNativeAppSurfaceNonEmpty(action.id, "actions.id")
            try requireNativeAppSurfaceNonEmpty(action.title, "actions.title")
            guard seen.insert(action.id).inserted else {
                throw NativeAppShellSurfaceValidationError.duplicateAction(action.id)
            }
            if action.startsRealtimeAudio || action.startsRealtimeVideo || action.armsControlOutput {
                throw NativeAppShellSurfaceValidationError.actionStartsRealtimePath(action.id)
            }
            if action.operatorCommandIntent == .runRequested,
               action.launchesExternalProcess,
               !action.launchesExternalRealtimeProcess {
                throw NativeAppShellSurfaceValidationError.actionRunIntentWithoutExternalRealtimeMarker(action.id)
            }
        }
    }

func validateLaunchProbePlan() throws {
        try requireNativeAppSurfaceNonEmpty(launchProbePlan.appTargetName, "launchProbePlan.appTargetName")
        try requireNativeAppSurfaceNonEmpty(launchProbePlan.buildCommand, "launchProbePlan.buildCommand")
        try requireNativeAppSurfaceNonEmpty(launchProbePlan.launchCommand, "launchProbePlan.launchCommand")
        if verdict == .pass {
            guard launchProbePlan.recordsScreenshotOrLog else {
                throw NativeAppShellSurfaceValidationError.passWithoutLaunchedSurfaceEvidence
            }
            guard !launchProbePlan.blocksFieldReadyPass else {
                throw NativeAppShellSurfaceValidationError.passWhileLaunchProbeBlocksFieldReady
            }
        }
    }
}

/// Records the evidence and outcome for native app shell surface probe report.
public struct NativeAppShellSurfaceProbeReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let capturedAt: String
    public let sourceReportId: String
    public let appTargetName: String
    public let sections: [NativeAppShellSurfaceSection]
    public let actions: [NativeAppShellSurfaceAction]
    public let launchProbePlan: NativeAppShellLaunchProbePlan
    public var verdict: MeasurementVerdict
    public let notes: String

    public static func decode(from data: Data) throws -> NativeAppShellSurfaceProbeReport {
        try JSONDecoder().decode(NativeAppShellSurfaceProbeReport.self, from: data)
    }

    public func validate() throws {
        try requireNativeAppSurfaceNonEmpty(id, "id")
        try requireNativeAppSurfaceNonEmpty(title, "title")
        try requireNativeAppSurfaceNonEmpty(capturedAt, "capturedAt")
        try requireNativeAppSurfaceNonEmpty(sourceReportId, "sourceReportId")
        try requireNativeAppSurfaceNonEmpty(appTargetName, "appTargetName")
        try requireNativeAppSurfaceNonEmpty(notes, "notes")
        try validateSections()
        try validateActions()
        try validateLaunchProbePlan()
    }

    private func validateSections() throws {
        var seen = Set<NativeAppShellSurfaceSectionID>()
        for section in sections {
            try requireNativeAppSurfaceNonEmpty(section.title, "sections.title")
            try requireNativeAppSurfaceNonEmpty(section.systemImage, "sections.systemImage")
            guard seen.insert(section.id).inserted else {
                throw NativeAppShellSurfaceValidationError.duplicateSection(section.id)
            }
            if section.mutatesRealtimeConfiguration {
                throw NativeAppShellSurfaceValidationError.sectionMutatesRealtimeConfiguration(section.id)
            }
        }
        for requiredSection in NativeAppShellSurfaceSectionID.allCases where !seen.contains(requiredSection) {
            throw NativeAppShellSurfaceValidationError.missingRequiredSection(requiredSection)
        }
    }
}

/// Validates the declared shell surface and records whether required sections and actions are present.
public enum NativeAppShellSurfaceProbe {
    public static func run(
        sourceReport: NativeAppShellReport,
        capturedAt: String = ISO8601DateFormatter().string(from: Date()),
        contract: NativeAppShellSurfaceContract = .releaseReadiness
    ) -> NativeAppShellSurfaceProbeReport {
        NativeAppShellSurfaceProbeReport(
            id: "c11-native-app-shell-surface-probe",
            title: "C11 native app shell surface probe",
            capturedAt: capturedAt,
            sourceReportId: sourceReport.id,
            appTargetName: contract.launchProbePlan.appTargetName,
            sections: contract.sections,
            actions: contract.actions,
            launchProbePlan: contract.launchProbePlan,
            verdict: .partial,
            notes: "Source-level SwiftUI surface contract. Field-ready PASS remains blocked until a launched app " +
                "window is observed and recorded."
        )
    }
}

func section(
    _ id: NativeAppShellSurfaceSectionID,
    _ title: String,
    _ systemImage: String,
    readOnly: Bool = true
) -> NativeAppShellSurfaceSection {
    NativeAppShellSurfaceSection(
        id: id,
        title: title,
        systemImage: systemImage,
        readOnly: readOnly,
        mutatesRealtimeConfiguration: false
    )
}

func requireNativeAppSurfaceNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty { throw NativeAppShellSurfaceValidationError.emptyField(field) }
}
