import Foundation
import OpenLolaContracts

public enum DriftPlcFixedTargetCertificationValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError {
    case emptyField(String)
    case passWithoutMeasuredRun
    case partialWithoutReason
    case passWithoutRequiredReports([String])
    case passWithoutRouteCertification
    case passWithoutDriftPlcReport
    case passWithoutRealtimeEngineReport
    case passWithoutAcceptedRouteCertification
    case passWithoutAcceptedDriftPlcReport
    case passWithoutAcceptedRealtimeEngineReport
    case passWithRealtimeRouteMismatch(expected: String, actual: String)
    case passWithoutDirectLinkRoute
    case passWithPacketModeMismatch
    case passWithRouteMismatch
    case passWithoutLolaBaselineComparison
    case passWithoutMeasuredLolaBaseline
    case passWithLolaPacketModeMismatch
    case passWithLolaRouteMismatch
    case passWithLolaHardwareMismatch
    case passWithLolaTrailingBaseline(LolaBaselineComparisonResult)
    case passWithoutRunArtifactPath
    case passWithPlaceholderField(String)
    case passWithFastestIneligibleRxBuffer(RxBufferProfile)
}

public struct DriftPlcFixedTargetCertificationReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: ReportRunMode
    public var routeCertificationReport: MacToMacRouteCertificationReport?
    public var driftPlcReport: DriftPlcReport?
    public var sourceRealtimeEngineReport: RealtimeAudioEngineReport?
    public var lolaBaselineComparison: LolaBaselineComparison?
    public var runArtifactPath: String?
    public var notTestedReason: String?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: ReportRunMode,
        routeCertificationReport: MacToMacRouteCertificationReport?,
        driftPlcReport: DriftPlcReport?,
        sourceRealtimeEngineReport: RealtimeAudioEngineReport? = nil,
        lolaBaselineComparison: LolaBaselineComparison? = nil,
        runArtifactPath: String?,
        notTestedReason: String?,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.routeCertificationReport = routeCertificationReport
        self.driftPlcReport = driftPlcReport
        self.sourceRealtimeEngineReport = sourceRealtimeEngineReport
        self.lolaBaselineComparison = lolaBaselineComparison
        self.runArtifactPath = runArtifactPath
        self.notTestedReason = notTestedReason
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> DriftPlcFixedTargetCertificationReport {
        try JSONDecoder().decode(DriftPlcFixedTargetCertificationReport.self, from: data)
    }

    public func validate() throws {
        try validateIdentity()
        try validatePassVerdict()
        try validateNestedReports()
    }

    private func validateIdentity() throws {
        try DriftPlcFixedTargetCertificationValidator.requireNonEmpty(id, "id")
        try DriftPlcFixedTargetCertificationValidator.requireNonEmpty(title, "title")
        try DriftPlcFixedTargetCertificationValidator.requireNonEmpty(capturedAt, "capturedAt")
        try DriftPlcFixedTargetCertificationValidator.requireNonEmpty(notes, "notes")
        if let artifactPath = runArtifactPath {
            try DriftPlcFixedTargetCertificationValidator.requireNonEmpty(artifactPath, "runArtifactPath")
        }
        if verdict != .pass, routeCertificationReport == nil || driftPlcReport == nil {
            guard notTestedReason?.isEmpty == false else {
                throw DriftPlcFixedTargetCertificationValidationError.partialWithoutReason
            }
        }
    }

    private func validateNestedReports() throws {
        try routeCertificationReport?.validate()
        try driftPlcReport?.validate()
        try sourceRealtimeEngineReport?.validate()
        try lolaBaselineComparison?.validate()
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        guard runMode == .measured else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutMeasuredRun
        }
        let reports = try validateRequiredPassReports()
        let directLinkReport = try validateAcceptedPassReports(reports)
        try validateRealtimeRouteLinkage(reports)
        try validateDriftRouteCompatibility(reports, directLinkReport: directLinkReport)
        try validateFastestAudioEligibility(reports.driftPlcReport)
        try validateLolaBaseline(reports)
        try validateRunArtifactPath()
        try validatePlaceholderSensitivePassFields(reports, directLinkReport: directLinkReport)
    }

    private func validateAcceptedPassReports(
        _ reports: DriftPlcFixedTargetRequiredPassReports
    ) throws -> UdpPcmRouteReport {
        guard reports.routeCertificationReport.verdict == .pass else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutAcceptedRouteCertification
        }
        guard reports.driftPlcReport.verdict == .pass else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutAcceptedDriftPlcReport
        }
        guard reports.sourceRealtimeEngineReport.verdict == .pass else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutAcceptedRealtimeEngineReport
        }
        guard let directLink = reports.routeCertificationReport.routes.first(where: { $0.routeKind == .directLink }),
              let directLinkReport = directLink.routeReport,
              directLinkReport.verdict == .pass else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutDirectLinkRoute
        }
        return directLinkReport
    }

    private func validateRealtimeRouteLinkage(
        _ reports: DriftPlcFixedTargetRequiredPassReports
    ) throws {
        guard reports.sourceRealtimeEngineReport.sourceRouteCertificationReport?.id == reports.routeCertificationReport.id else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithRealtimeRouteMismatch(
                expected: reports.routeCertificationReport.id,
                actual: reports.sourceRealtimeEngineReport.sourceRouteCertificationReport?.id ?? ""
            )
        }
        guard reports.routeCertificationReport.sourceRealtimeEngineReportId == reports.sourceRealtimeEngineReport.id else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithRealtimeRouteMismatch(
                expected: reports.sourceRealtimeEngineReport.id,
                actual: reports.routeCertificationReport.sourceRealtimeEngineReportId
            )
        }
    }

    private func validateDriftRouteCompatibility(
        _ reports: DriftPlcFixedTargetRequiredPassReports,
        directLinkReport: UdpPcmRouteReport
    ) throws {
        guard reports.routeCertificationReport.packetMode == reports.driftPlcReport.packetMode,
              directLinkReport.packetMode == reports.driftPlcReport.packetMode else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithPacketModeMismatch
        }
        guard directLinkReport.route == reports.driftPlcReport.route else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithRouteMismatch
        }
    }

    private func validateFastestAudioEligibility(_ driftPlcReport: DriftPlcReport) throws {
        if let rxBuffer = driftPlcReport.metrics.rxBuffer,
           !rxBuffer.policy.fastestAudioPassEligible {
            throw DriftPlcFixedTargetCertificationValidationError.passWithFastestIneligibleRxBuffer(
                rxBuffer.policy.profile
            )
        }
    }

    private func validateLolaBaseline(_ reports: DriftPlcFixedTargetRequiredPassReports) throws {
        let baseline = reports.lolaBaselineComparison
        guard baseline.availability == .measured else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutMeasuredLolaBaseline
        }
        guard baseline.packetMode == reports.driftPlcReport.packetMode else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithLolaPacketModeMismatch
        }
        guard baseline.route == reports.driftPlcReport.route else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithLolaRouteMismatch
        }
        guard baseline.measuredOnSameHardwareAndRoute else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithLolaHardwareMismatch
        }
        guard baseline.result == .openLolaFaster || baseline.result == .openLolaEquivalent else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithLolaTrailingBaseline(
                baseline.result
            )
        }
    }

    private func validateRunArtifactPath() throws {
        guard runArtifactPath?.isEmpty == false else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutRunArtifactPath
        }
    }

    private func validatePlaceholderSensitivePassFields(
        _ reports: DriftPlcFixedTargetRequiredPassReports,
        directLinkReport: UdpPcmRouteReport
    ) throws {
        for field in placeholderSensitiveFields(
            routeCertificationReport: reports.routeCertificationReport,
            driftPlcReport: reports.driftPlcReport,
            directLinkReport: directLinkReport,
            sourceRealtimeEngineReport: reports.sourceRealtimeEngineReport,
            lolaBaselineComparison: reports.lolaBaselineComparison
        ) where isDriftCertificationPlaceholder(field.value) {
            throw DriftPlcFixedTargetCertificationValidationError.passWithPlaceholderField(
                field.name
            )
        }
    }

    private func validateRequiredPassReports() throws -> DriftPlcFixedTargetRequiredPassReports {
        let missingReports = missingRequiredPassReportNames()
        if !missingReports.isEmpty {
            throw missingRequiredPassReportError(missingReports)
        }

        guard let routeCertificationReport,
              let driftPlcReport,
              let sourceRealtimeEngineReport,
              let lolaBaselineComparison else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutRequiredReports(missingReports)
        }

        return DriftPlcFixedTargetRequiredPassReports(
            routeCertificationReport: routeCertificationReport,
            driftPlcReport: driftPlcReport,
            sourceRealtimeEngineReport: sourceRealtimeEngineReport,
            lolaBaselineComparison: lolaBaselineComparison
        )
    }

    private func missingRequiredPassReportNames() -> [String] {
        [
            missingReportName(routeCertificationReport, "routeCertificationReport"),
            missingReportName(driftPlcReport, "driftPlcReport"),
            missingReportName(sourceRealtimeEngineReport, "sourceRealtimeEngineReport"),
            missingReportName(lolaBaselineComparison, "lolaBaselineComparison"),
        ].compactMap { $0 }
    }

    private func missingReportName<T>(_ report: T?, _ name: String) -> String? {
        report == nil ? name : nil
    }

    private func missingRequiredPassReportError(
        _ missingReports: [String]
    ) -> DriftPlcFixedTargetCertificationValidationError {
        guard missingReports.count == 1 else {
            return .passWithoutRequiredReports(missingReports)
        }
        switch missingReports[0] {
        case "routeCertificationReport":
            return .passWithoutRouteCertification
        case "driftPlcReport":
            return .passWithoutDriftPlcReport
        case "sourceRealtimeEngineReport":
            return .passWithoutRealtimeEngineReport
        case "lolaBaselineComparison":
            return .passWithoutLolaBaselineComparison
        default:
            return .passWithoutRequiredReports(missingReports)
        }
    }

    private func placeholderSensitiveFields(
        routeCertificationReport: MacToMacRouteCertificationReport,
        driftPlcReport: DriftPlcReport,
        directLinkReport: UdpPcmRouteReport,
        sourceRealtimeEngineReport: RealtimeAudioEngineReport,
        lolaBaselineComparison: LolaBaselineComparison
    ) -> [(name: String, value: String)] {
        [
            ("id", id),
            ("title", title),
            ("capturedAt", capturedAt),
            ("runArtifactPath", runArtifactPath ?? ""),
            ("notes", notes),
            ("routeCertificationReport.id", routeCertificationReport.id),
            ("routeCertificationReport.title", routeCertificationReport.title),
            ("routeCertificationReport.sourceRealtimeEngineReportId", routeCertificationReport.sourceRealtimeEngineReportId),
            ("routeCertificationReport.notes", routeCertificationReport.notes),
            ("directLink.packetCaptureArtifact", routeCertificationReport.routes.first(where: { $0.routeKind == .directLink })?.packetCaptureArtifact ?? ""),
            ("directLink.routeReport.id", directLinkReport.id),
            ("directLink.routeReport.title", directLinkReport.title),
            ("directLink.routeReport.route.label", directLinkReport.route.label),
            ("directLink.routeReport.route.topology", directLinkReport.route.topology),
            ("directLink.routeReport.sender.hostName", directLinkReport.sender.hostName),
            ("directLink.routeReport.receiver.hostName", directLinkReport.receiver.hostName),
            ("directLink.routeReport.network.packetCapture.point", directLinkReport.network.packetCapture.point ?? ""),
            ("directLink.routeReport.network.packetCapture.notes", directLinkReport.network.packetCapture.notes),
            ("directLink.routeReport.notes", directLinkReport.notes),
            ("driftPlcReport.id", driftPlcReport.id),
            ("driftPlcReport.title", driftPlcReport.title),
            ("driftPlcReport.route.label", driftPlcReport.route.label),
            ("driftPlcReport.route.topology", driftPlcReport.route.topology),
            ("driftPlcReport.artifactNotes", driftPlcReport.artifactNotes),
            ("driftPlcReport.notes", driftPlcReport.notes),
            ("sourceRealtimeEngineReport.id", sourceRealtimeEngineReport.id),
            ("sourceRealtimeEngineReport.title", sourceRealtimeEngineReport.title),
            ("sourceRealtimeEngineReport.runArtifactPath", sourceRealtimeEngineReport.runArtifactPath ?? ""),
            ("sourceRealtimeEngineReport.notes", sourceRealtimeEngineReport.notes),
            ("lolaBaselineComparison.lolaVersion", lolaBaselineComparison.lolaVersion),
            ("lolaBaselineComparison.lolaSettings", lolaBaselineComparison.lolaSettings),
            ("lolaBaselineComparison.audioInterface", lolaBaselineComparison.audioInterface),
            ("lolaBaselineComparison.route.label", lolaBaselineComparison.route.label),
            ("lolaBaselineComparison.route.topology", lolaBaselineComparison.route.topology),
            ("lolaBaselineComparison.artifactNotes", lolaBaselineComparison.artifactNotes),
        ]
    }
}

private struct DriftPlcFixedTargetRequiredPassReports {
    let routeCertificationReport: MacToMacRouteCertificationReport
    let driftPlcReport: DriftPlcReport
    let sourceRealtimeEngineReport: RealtimeAudioEngineReport
    let lolaBaselineComparison: LolaBaselineComparison
}

public enum DriftPlcFixedTargetCertificationSyntheticSmoke {
    public static func run() -> DriftPlcFixedTargetCertificationReport {
        DriftPlcFixedTargetCertificationReport(
            id: "g05-drift-plc-certification-synthetic-smoke",
            title: "Synthetic G05 fixed-target drift PLC certification",
            capturedAt: "2026-05-02T00:00:00Z",
            runMode: .synthetic,
            routeCertificationReport: nil,
            driftPlcReport: nil,
            runArtifactPath: nil,
            notTestedReason: "Synthetic smoke only; G05 PASS requires accepted G04 route certification and a measured 60-minute fixed-target run.",
            verdict: .partial,
            notes: "Synthetic source validation only; no physical route or artifact assessment is certified."
        )
    }
}

private func isDriftCertificationPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: [PlaceholderDetection.manualEvidenceToken, "placeholder", "fixture", "synthetic"],
        exactly: ["unknown", "tbd"]
    )
}
