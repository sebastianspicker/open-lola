import Foundation

public enum NetworkAoipCertificationRunMode: String, Codable, Equatable, Sendable {
    case synthetic
    case measured
}

public enum NetworkAoipCertificationValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case partialWithoutReason
    case passWithoutMeasuredRun
    case passWithoutRouteCertification
    case passWithoutDriftPlcCertification
    case passWithoutAoipEvaluation
    case passWithoutAcceptedRouteCertification
    case passWithoutAcceptedDriftPlcCertification
    case passWithoutAcceptedAoipEvaluation
    case passWithoutDirectLinkRoute
    case passWithoutProfessionalMode
    case passWithBaselineMismatch
    case passWithRouteMismatch
    case passWithoutPtpArtifact
    case passWithoutStressArtifact
    case passWithoutProfileArtifact
    case passWithPlaceholderField(String)
}

public struct NetworkAoipCertificationReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: NetworkAoipCertificationRunMode
    public var routeCertificationReport: MacToMacRouteCertificationReport?
    public var driftPlcCertificationReport: DriftPlcFixedTargetCertificationReport?
    public var aoipEvaluationReport: AoipEvaluationReport?
    public var ptpArtifactPath: String?
    public var stressArtifactPath: String?
    public var profileArtifactPath: String?
    public var notTestedReason: String?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: NetworkAoipCertificationRunMode,
        routeCertificationReport: MacToMacRouteCertificationReport?,
        driftPlcCertificationReport: DriftPlcFixedTargetCertificationReport?,
        aoipEvaluationReport: AoipEvaluationReport?,
        ptpArtifactPath: String?,
        stressArtifactPath: String?,
        profileArtifactPath: String?,
        notTestedReason: String?,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.routeCertificationReport = routeCertificationReport
        self.driftPlcCertificationReport = driftPlcCertificationReport
        self.aoipEvaluationReport = aoipEvaluationReport
        self.ptpArtifactPath = ptpArtifactPath
        self.stressArtifactPath = stressArtifactPath
        self.profileArtifactPath = profileArtifactPath
        self.notTestedReason = notTestedReason
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> NetworkAoipCertificationReport {
        try JSONDecoder().decode(NetworkAoipCertificationReport.self, from: data)
    }

    public func validate() throws {
        try validateIdentity()
        try validateNestedReports()
        try validatePassVerdict()
    }

    private func validateIdentity() throws {
        try requireNetworkAoipNonEmpty(id, "id")
        try requireNetworkAoipNonEmpty(title, "title")
        try requireNetworkAoipNonEmpty(capturedAt, "capturedAt")
        try requireNetworkAoipNonEmpty(notes, "notes")
        if let ptpArtifactPath {
            try requireNetworkAoipNonEmpty(ptpArtifactPath, "ptpArtifactPath")
        }
        if let stressArtifactPath {
            try requireNetworkAoipNonEmpty(stressArtifactPath, "stressArtifactPath")
        }
        if let profileArtifactPath {
            try requireNetworkAoipNonEmpty(profileArtifactPath, "profileArtifactPath")
        }
        if verdict != .pass,
           routeCertificationReport == nil
            || driftPlcCertificationReport == nil
            || aoipEvaluationReport == nil {
            guard notTestedReason?.isEmpty == false else {
                throw NetworkAoipCertificationValidationError.partialWithoutReason
            }
        }
    }

    private func validateNestedReports() throws {
        try routeCertificationReport?.validate()
        try driftPlcCertificationReport?.validate()
        try aoipEvaluationReport?.validate()
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        guard runMode == .measured else {
            throw NetworkAoipCertificationValidationError.passWithoutMeasuredRun
        }
        guard let routeCertificationReport else {
            throw NetworkAoipCertificationValidationError.passWithoutRouteCertification
        }
        guard let driftPlcCertificationReport else {
            throw NetworkAoipCertificationValidationError.passWithoutDriftPlcCertification
        }
        guard let aoipEvaluationReport else {
            throw NetworkAoipCertificationValidationError.passWithoutAoipEvaluation
        }
        guard routeCertificationReport.verdict == .pass else {
            throw NetworkAoipCertificationValidationError.passWithoutAcceptedRouteCertification
        }
        guard driftPlcCertificationReport.verdict == .pass else {
            throw NetworkAoipCertificationValidationError.passWithoutAcceptedDriftPlcCertification
        }
        guard aoipEvaluationReport.verdict == .pass else {
            throw NetworkAoipCertificationValidationError.passWithoutAcceptedAoipEvaluation
        }
        guard aoipEvaluationReport.mode != .directUdpPcm else {
            throw NetworkAoipCertificationValidationError.passWithoutProfessionalMode
        }
        guard let directLink = routeCertificationReport.routes.first(where: { $0.routeKind == .directLink }),
              let directLinkReport = directLink.routeReport,
              directLinkReport.verdict == .pass else {
            throw NetworkAoipCertificationValidationError.passWithoutDirectLinkRoute
        }

        guard aoipEvaluationReport.baselineComparison.directUdpPcmRouteReportId == directLinkReport.id else {
            throw NetworkAoipCertificationValidationError.passWithBaselineMismatch
        }
        guard aoipEvaluationReport.route == directLinkReport.route,
              driftPlcCertificationReport.driftPlcReport?.route == directLinkReport.route else {
            throw NetworkAoipCertificationValidationError.passWithRouteMismatch
        }
        guard ptpArtifactPath?.isEmpty == false else {
            throw NetworkAoipCertificationValidationError.passWithoutPtpArtifact
        }
        guard stressArtifactPath?.isEmpty == false else {
            throw NetworkAoipCertificationValidationError.passWithoutStressArtifact
        }
        guard profileArtifactPath?.isEmpty == false else {
            throw NetworkAoipCertificationValidationError.passWithoutProfileArtifact
        }

        for field in placeholderSensitiveFields(
            routeCertificationReport: routeCertificationReport,
            driftPlcCertificationReport: driftPlcCertificationReport,
            aoipEvaluationReport: aoipEvaluationReport,
            directLinkReport: directLinkReport,
            directLinkArtifactPath: directLink.packetCaptureArtifact ?? ""
        ) where isNetworkAoipPlaceholder(field.value) {
            throw NetworkAoipCertificationValidationError.passWithPlaceholderField(
                field.name
            )
        }
    }

    private func placeholderSensitiveFields(
        routeCertificationReport: MacToMacRouteCertificationReport,
        driftPlcCertificationReport: DriftPlcFixedTargetCertificationReport,
        aoipEvaluationReport: AoipEvaluationReport,
        directLinkReport: UdpPcmRouteReport,
        directLinkArtifactPath: String
    ) -> [(name: String, value: String)] {
        var fields: [(name: String, value: String)] = [
            ("id", id),
            ("title", title),
            ("capturedAt", capturedAt),
            ("ptpArtifactPath", ptpArtifactPath ?? ""),
            ("stressArtifactPath", stressArtifactPath ?? ""),
            ("profileArtifactPath", profileArtifactPath ?? ""),
            ("notes", notes),
            ("routeCertificationReport.id", routeCertificationReport.id),
            ("routeCertificationReport.title", routeCertificationReport.title),
            (
                "routeCertificationReport.sourceRealtimeEngineReportId",
                routeCertificationReport.sourceRealtimeEngineReportId
            ),
            ("directLink.packetCaptureArtifact", directLinkArtifactPath),
            ("directLink.routeReport.id", directLinkReport.id),
            ("directLink.routeReport.title", directLinkReport.title),
            ("directLink.routeReport.route.label", directLinkReport.route.label),
            ("directLink.routeReport.route.topology", directLinkReport.route.topology),
            ("directLink.routeReport.sender.hostName", directLinkReport.sender.hostName),
            ("directLink.routeReport.receiver.hostName", directLinkReport.receiver.hostName),
            (
                "directLink.routeReport.network.packetCapture.point",
                directLinkReport.network.packetCapture.point ?? ""
            ),
            (
                "directLink.routeReport.network.packetCapture.notes",
                directLinkReport.network.packetCapture.notes
            ),
            ("driftPlcCertificationReport.id", driftPlcCertificationReport.id),
            ("driftPlcCertificationReport.title", driftPlcCertificationReport.title),
            (
                "driftPlcCertificationReport.runArtifactPath",
                driftPlcCertificationReport.runArtifactPath ?? ""
            ),
            ("driftPlcCertificationReport.notes", driftPlcCertificationReport.notes),
            ("aoipEvaluationReport.id", aoipEvaluationReport.id),
            ("aoipEvaluationReport.title", aoipEvaluationReport.title),
            ("aoipEvaluationReport.route.label", aoipEvaluationReport.route.label),
            ("aoipEvaluationReport.route.topology", aoipEvaluationReport.route.topology),
            ("aoipEvaluationReport.ptp.version", aoipEvaluationReport.ptp.version),
            ("aoipEvaluationReport.ptp.profile", aoipEvaluationReport.ptp.profile),
            ("aoipEvaluationReport.ptp.domain", aoipEvaluationReport.ptp.domain),
            ("aoipEvaluationReport.ptp.masterClockId", aoipEvaluationReport.ptp.masterClockId),
            ("aoipEvaluationReport.ptp.lockState", aoipEvaluationReport.ptp.lockState),
            ("aoipEvaluationReport.switchProfile.model", aoipEvaluationReport.switchProfile.model),
            (
                "aoipEvaluationReport.switchProfile.firmwareVersion",
                aoipEvaluationReport.switchProfile.firmwareVersion
            ),
            (
                "aoipEvaluationReport.switchProfile.trafficClass",
                aoipEvaluationReport.switchProfile.trafficClass
            ),
            (
                "aoipEvaluationReport.switchProfile.streamReservation",
                aoipEvaluationReport.switchProfile.streamReservation
            ),
            ("aoipEvaluationReport.switchProfile.schedule", aoipEvaluationReport.switchProfile.schedule),
            ("aoipEvaluationReport.endpoint.sender.vendor", aoipEvaluationReport.endpoint.sender.vendor),
            ("aoipEvaluationReport.endpoint.sender.model", aoipEvaluationReport.endpoint.sender.model),
            (
                "aoipEvaluationReport.endpoint.sender.firmwareVersion",
                aoipEvaluationReport.endpoint.sender.firmwareVersion
            ),
            (
                "aoipEvaluationReport.endpoint.sender.profileName",
                aoipEvaluationReport.endpoint.sender.profileName
            ),
            ("aoipEvaluationReport.endpoint.receiver.vendor", aoipEvaluationReport.endpoint.receiver.vendor),
            ("aoipEvaluationReport.endpoint.receiver.model", aoipEvaluationReport.endpoint.receiver.model),
            (
                "aoipEvaluationReport.endpoint.receiver.firmwareVersion",
                aoipEvaluationReport.endpoint.receiver.firmwareVersion
            ),
            (
                "aoipEvaluationReport.endpoint.receiver.profileName",
                aoipEvaluationReport.endpoint.receiver.profileName
            ),
            (
                "aoipEvaluationReport.baselineComparison.directUdpPcmRouteReportId",
                aoipEvaluationReport.baselineComparison.directUdpPcmRouteReportId
            ),
            ("aoipEvaluationReport.baselineComparison.notes", aoipEvaluationReport.baselineComparison.notes),
            (
                "aoipEvaluationReport.stress.competingTrafficProfile",
                aoipEvaluationReport.stress.competingTrafficProfile
            ),
            ("aoipEvaluationReport.stress.recoveryBehavior", aoipEvaluationReport.stress.recoveryBehavior),
            ("aoipEvaluationReport.stress.notes", aoipEvaluationReport.stress.notes),
            ("aoipEvaluationReport.notes", aoipEvaluationReport.notes),
        ]
        for (index, value) in aoipEvaluationReport.profileEvidence.standardsRead.enumerated() {
            fields.append((
                "aoipEvaluationReport.profileEvidence.standardsRead[\(index)]",
                value
            ))
        }
        for (index, value) in aoipEvaluationReport.profileEvidence.vendorProfilesRead.enumerated() {
            fields.append((
                "aoipEvaluationReport.profileEvidence.vendorProfilesRead[\(index)]",
                value
            ))
        }
        return fields
    }
}

public enum NetworkAoipCertificationSyntheticSmoke {
    public static func run() -> NetworkAoipCertificationReport {
        NetworkAoipCertificationReport(
            id: "g06-network-aoip-certification-synthetic-smoke",
            title: "Synthetic G06 network timing AoIP certification",
            capturedAt: "2026-05-02T00:00:00Z",
            runMode: .synthetic,
            routeCertificationReport: nil,
            driftPlcCertificationReport: nil,
            aoipEvaluationReport: nil,
            ptpArtifactPath: nil,
            stressArtifactPath: nil,
            profileArtifactPath: nil,
            notTestedReason: "Synthetic smoke only; G06 PASS requires accepted G04/G05 direct baselines plus measured AoIP, PTP, profile, and WCRT evidence.",
            verdict: .partial,
            notes: "Synthetic source validation only; no professional AoIP route is certified."
        )
    }
}

private func requireNetworkAoipNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw NetworkAoipCertificationValidationError.emptyField(field)
    }
}

private func isNetworkAoipPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: ["todo(human)", "placeholder", "fixture", "synthetic"],
        exactly: ["unknown", "none", "tbd", "not-tested", "notrun", "not-run"]
    )
}
