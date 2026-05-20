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
        let requiredReports = try validateRequiredPassReports()
        let routeCertificationReport = requiredReports.routeCertificationReport
        let driftPlcReport = requiredReports.driftPlcReport
        let sourceRealtimeEngineReport = requiredReports.sourceRealtimeEngineReport
        let lolaBaselineComparison = requiredReports.lolaBaselineComparison
        guard routeCertificationReport.verdict == .pass else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutAcceptedRouteCertification
        }
        guard driftPlcReport.verdict == .pass else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutAcceptedDriftPlcReport
        }
        guard sourceRealtimeEngineReport.verdict == .pass else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutAcceptedRealtimeEngineReport
        }
        guard sourceRealtimeEngineReport.sourceRouteCertificationReport?.id == routeCertificationReport.id else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithRealtimeRouteMismatch(
                expected: routeCertificationReport.id,
                actual: sourceRealtimeEngineReport.sourceRouteCertificationReport?.id ?? ""
            )
        }
        guard routeCertificationReport.sourceRealtimeEngineReportId == sourceRealtimeEngineReport.id else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithRealtimeRouteMismatch(
                expected: sourceRealtimeEngineReport.id,
                actual: routeCertificationReport.sourceRealtimeEngineReportId
            )
        }
        guard let directLink = routeCertificationReport.routes.first(where: { $0.routeKind == .directLink }),
              let directLinkReport = directLink.routeReport,
              directLinkReport.verdict == .pass else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutDirectLinkRoute
        }
        guard routeCertificationReport.packetMode == driftPlcReport.packetMode,
              directLinkReport.packetMode == driftPlcReport.packetMode else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithPacketModeMismatch
        }
        guard directLinkReport.route == driftPlcReport.route else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithRouteMismatch
        }
        if let rxBuffer = driftPlcReport.metrics.rxBuffer,
           !rxBuffer.policy.fastestAudioPassEligible {
            throw DriftPlcFixedTargetCertificationValidationError.passWithFastestIneligibleRxBuffer(
                rxBuffer.policy.profile
            )
        }
        guard lolaBaselineComparison.availability == .measured else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutMeasuredLolaBaseline
        }
        guard lolaBaselineComparison.packetMode == driftPlcReport.packetMode else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithLolaPacketModeMismatch
        }
        guard lolaBaselineComparison.route == driftPlcReport.route else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithLolaRouteMismatch
        }
        guard lolaBaselineComparison.measuredOnSameHardwareAndRoute else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithLolaHardwareMismatch
        }
        guard lolaBaselineComparison.result == .openLolaFaster
            || lolaBaselineComparison.result == .openLolaEquivalent else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithLolaTrailingBaseline(
                lolaBaselineComparison.result
            )
        }
        guard runArtifactPath?.isEmpty == false else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutRunArtifactPath
        }

        for field in placeholderSensitiveFields(
            routeCertificationReport: routeCertificationReport,
            driftPlcReport: driftPlcReport,
            directLinkReport: directLinkReport,
            sourceRealtimeEngineReport: sourceRealtimeEngineReport,
            lolaBaselineComparison: lolaBaselineComparison
        ) where isDriftCertificationPlaceholder(field.value) {
            throw DriftPlcFixedTargetCertificationValidationError.passWithPlaceholderField(
                field.name
            )
        }
    }

    private func validateRequiredPassReports() throws -> (
        routeCertificationReport: MacToMacRouteCertificationReport,
        driftPlcReport: DriftPlcReport,
        sourceRealtimeEngineReport: RealtimeAudioEngineReport,
        lolaBaselineComparison: LolaBaselineComparison
    ) {
        var missingReports: [String] = []
        if routeCertificationReport == nil {
            missingReports.append("routeCertificationReport")
        }
        if driftPlcReport == nil {
            missingReports.append("driftPlcReport")
        }
        if sourceRealtimeEngineReport == nil {
            missingReports.append("sourceRealtimeEngineReport")
        }
        if lolaBaselineComparison == nil {
            missingReports.append("lolaBaselineComparison")
        }

        if missingReports.count > 1 {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutRequiredReports(missingReports)
        }
        if missingReports == ["routeCertificationReport"] {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutRouteCertification
        }
        if missingReports == ["driftPlcReport"] {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutDriftPlcReport
        }
        if missingReports == ["sourceRealtimeEngineReport"] {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutRealtimeEngineReport
        }
        if missingReports == ["lolaBaselineComparison"] {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutLolaBaselineComparison
        }

        guard let routeCertificationReport,
              let driftPlcReport,
              let sourceRealtimeEngineReport,
              let lolaBaselineComparison else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithoutRequiredReports(missingReports)
        }

        return (
            routeCertificationReport: routeCertificationReport,
            driftPlcReport: driftPlcReport,
            sourceRealtimeEngineReport: sourceRealtimeEngineReport,
            lolaBaselineComparison: lolaBaselineComparison
        )
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
        containing: ["todo(human)", "placeholder", "fixture", "synthetic"],
        exactly: ["unknown", "tbd"]
    )
}

private enum DriftPlcFixedTargetCertificationValidator: ReportPrimitiveValidating {
    typealias ValidationError = DriftPlcFixedTargetCertificationValidationError
}
