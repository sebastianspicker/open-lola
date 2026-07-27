// Validates DriftPlcFixedTargetCertificationSupport acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension DriftPlcFixedTargetCertificationReport {
func placeholderHeaderFields() -> [(name: String, value: String)] {
    [
        ("id", id),
        ("title", title),
        ("capturedAt", capturedAt),
        ("runArtifactPath", runArtifactPath ?? ""),
        ("notes", notes)
    ]
}

func routeCertificationPlaceholderFields(
    _ report: MacToMacRouteCertificationReport
) -> [(name: String, value: String)] {
    [
        ("routeCertificationReport.id", report.id),
        ("routeCertificationReport.title", report.title),
        (
            "routeCertificationReport.sourceRealtimeEngineReportId",
            report.sourceRealtimeEngineReportId
        ),
        ("routeCertificationReport.notes", report.notes)
    ]
}

func directLinkPlaceholderFields(
    _ routeCertificationReport: MacToMacRouteCertificationReport,
    _ directLinkReport: UdpPcmRouteReport
) -> [(name: String, value: String)] {
    directLinkRoutePlaceholderFields(
        packetCaptureArtifact: routeCertificationReport.routes.first(where: { $0.routeKind == .directLink })?
            .packetCaptureArtifact ?? "",
        routeReport: directLinkReport
    ) + [
        ("directLink.routeReport.notes", directLinkReport.notes)
    ]
}

func driftPlcPlaceholderFields(
    _ report: DriftPlcReport
) -> [(name: String, value: String)] {
    [
        ("driftPlcReport.id", report.id),
        ("driftPlcReport.title", report.title),
        ("driftPlcReport.route.label", report.route.label),
        ("driftPlcReport.route.topology", report.route.topology),
        ("driftPlcReport.artifactNotes", report.artifactNotes),
        ("driftPlcReport.notes", report.notes)
    ]
}

func realtimePlaceholderFields(
    _ report: RealtimeAudioEngineReport
) -> [(name: String, value: String)] {
    [
        ("sourceRealtimeEngineReport.id", report.id),
        ("sourceRealtimeEngineReport.title", report.title),
        ("sourceRealtimeEngineReport.runArtifactPath", report.runArtifactPath ?? ""),
        ("sourceRealtimeEngineReport.notes", report.notes)
    ]
}

func lolaBaselinePlaceholderFields(
    _ report: LolaBaselineComparison
) -> [(name: String, value: String)] {
    [
        ("lolaBaselineComparison.lolaVersion", report.lolaVersion),
        ("lolaBaselineComparison.lolaSettings", report.lolaSettings),
        ("lolaBaselineComparison.audioInterface", report.audioInterface),
        ("lolaBaselineComparison.route.label", report.route.label),
        ("lolaBaselineComparison.route.topology", report.route.topology),
        ("lolaBaselineComparison.artifactNotes", report.artifactNotes)
    ]
}
}

struct DriftPlcFixedTargetRequiredPassReports {
    let routeCertificationReport: MacToMacRouteCertificationReport
    let driftPlcReport: DriftPlcReport
    let sourceRealtimeEngineReport: RealtimeAudioEngineReport
    let lolaBaselineComparison: LolaBaselineComparison
}

// swiftlint:disable:next type_name
/// Exercises a deterministic timing and drift control path so regressions remain reproducible without hardware.
public enum DriftPlcFixedTargetCertificationSyntheticSmoke {
    public static func run() -> DriftPlcFixedTargetCertificationReport {
        DriftPlcFixedTargetCertificationReport(
            identity: .init(
                id: "g05-drift-plc-certification-synthetic-smoke",
                title: "Synthetic G05 fixed-target drift PLC certification",
                capturedAt: "2026-05-02T00:00:00Z"
            ),
            supportingReports: .init(routeCertificationReport: nil, driftPlcReport: nil),
            outcome: .init(
                runMode: .synthetic,
                runArtifactPath: nil,
                notTestedReason: "Synthetic smoke only; G05 PASS requires accepted G04 route certification " +
                    "and a measured 60-minute fixed-target run.",
                verdict: .partial,
                notes: "Synthetic source validation only; no physical route or artifact assessment is certified."
            )
        )
    }
}

func isDriftCertificationPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: [PlaceholderDetection.manualEvidenceToken, "placeholder", "fixture", "synthetic"],
        exactly: ["unknown", "tbd"]
    )
}
