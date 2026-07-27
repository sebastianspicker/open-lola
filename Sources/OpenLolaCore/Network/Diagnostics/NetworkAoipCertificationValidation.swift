// Validates NetworkAoipCertificationValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation
import OpenLolaContracts

private struct NetworkAoipPassContext {
    var routeCertificationReport: MacToMacRouteCertificationReport
    var driftPlcCertificationReport: DriftPlcFixedTargetCertificationReport
    var aoipEvaluationReport: AoipEvaluationReport
}

private struct NetworkAoipPassDirectLink {
    var report: UdpPcmRouteReport
    var packetCaptureArtifact: String
}

extension NetworkAoipCertificationReport {
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
        try requireMeasuredRunForPass()
        let context = try requireAcceptedReportsForPass()
        try requireProfessionalAoipModeForPass(context.aoipEvaluationReport)
        let directLink = try requireDirectLinkRouteForPass(context.routeCertificationReport)
        try requirePassEvidenceConsistency(
            context: context,
            directLinkReport: directLink.report
        )
        try requirePassArtifactPaths()
        try requireNoPlaceholderPassFields(
            context: context,
            directLinkReport: directLink.report,
            directLinkArtifactPath: directLink.packetCaptureArtifact
        )
    }

    private func requireMeasuredRunForPass() throws {
        guard runMode == .measured else {
            throw NetworkAoipCertificationValidationError.passWithoutMeasuredRun
        }
    }

    private func requireAcceptedReportsForPass() throws -> NetworkAoipPassContext {
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
        return NetworkAoipPassContext(
            routeCertificationReport: routeCertificationReport,
            driftPlcCertificationReport: driftPlcCertificationReport,
            aoipEvaluationReport: aoipEvaluationReport
        )
    }

    private func requireProfessionalAoipModeForPass(
        _ aoipEvaluationReport: AoipEvaluationReport
    ) throws {
        guard aoipEvaluationReport.mode != .directUdpPcm else {
            throw NetworkAoipCertificationValidationError.passWithoutProfessionalMode
        }
    }

    private func requireDirectLinkRouteForPass(
        _ routeCertificationReport: MacToMacRouteCertificationReport
    ) throws -> NetworkAoipPassDirectLink {
        guard let directLink = routeCertificationReport.routes.first(where: { $0.routeKind == .directLink }),
              let report = directLink.routeReport,
              report.verdict == .pass else {
            throw NetworkAoipCertificationValidationError.passWithoutDirectLinkRoute
        }
        return NetworkAoipPassDirectLink(
            report: report,
            packetCaptureArtifact: directLink.packetCaptureArtifact ?? ""
        )
    }

    private func requirePassEvidenceConsistency(
        context: NetworkAoipPassContext,
        directLinkReport: UdpPcmRouteReport
    ) throws {
        guard context.aoipEvaluationReport.baselineComparison.directUdpPcmRouteReportId == directLinkReport.id else {
            throw NetworkAoipCertificationValidationError.passWithBaselineMismatch
        }
        guard context.aoipEvaluationReport.route == directLinkReport.route,
              context.driftPlcCertificationReport.driftPlcReport?.route == directLinkReport.route else {
            throw NetworkAoipCertificationValidationError.passWithRouteMismatch
        }
    }

    private func requirePassArtifactPaths() throws {
        guard ptpArtifactPath?.isEmpty == false else {
            throw NetworkAoipCertificationValidationError.passWithoutPtpArtifact
        }
        guard stressArtifactPath?.isEmpty == false else {
            throw NetworkAoipCertificationValidationError.passWithoutStressArtifact
        }
        guard profileArtifactPath?.isEmpty == false else {
            throw NetworkAoipCertificationValidationError.passWithoutProfileArtifact
        }
    }

    private func requireNoPlaceholderPassFields(
        context: NetworkAoipPassContext,
        directLinkReport: UdpPcmRouteReport,
        directLinkArtifactPath: String
    ) throws {
        for field in placeholderSensitiveFields(
            routeCertificationReport: context.routeCertificationReport,
            driftPlcCertificationReport: context.driftPlcCertificationReport,
            aoipEvaluationReport: context.aoipEvaluationReport,
            directLinkReport: directLinkReport,
            directLinkArtifactPath: directLinkArtifactPath
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
        var fields = ownPlaceholderFields()
        fields += routeCertificationPlaceholderFields(
            routeCertificationReport,
            directLinkArtifactPath: directLinkArtifactPath,
            directLinkReport: directLinkReport
        )
        fields += driftPlcPlaceholderFields(driftPlcCertificationReport)
        fields += aoipEvaluationPlaceholderFields(aoipEvaluationReport)
        fields += profileEvidencePlaceholderFields(aoipEvaluationReport.profileEvidence)
        return fields
    }

    private func ownPlaceholderFields() -> [(name: String, value: String)] {
        [
            ("id", id),
            ("title", title),
            ("capturedAt", capturedAt),
            ("ptpArtifactPath", ptpArtifactPath ?? ""),
            ("stressArtifactPath", stressArtifactPath ?? ""),
            ("profileArtifactPath", profileArtifactPath ?? ""),
            ("notes", notes)
        ]
    }

    private func routeCertificationPlaceholderFields(
        _ routeCertificationReport: MacToMacRouteCertificationReport,
        directLinkArtifactPath: String,
        directLinkReport: UdpPcmRouteReport
    ) -> [(name: String, value: String)] {
        [
            ("routeCertificationReport.id", routeCertificationReport.id),
            ("routeCertificationReport.title", routeCertificationReport.title),
            (
                "routeCertificationReport.sourceRealtimeEngineReportId",
                routeCertificationReport.sourceRealtimeEngineReportId
            )
        ] + directLinkRoutePlaceholderFields(
            packetCaptureArtifact: directLinkArtifactPath,
            routeReport: directLinkReport
        )
    }

    private func driftPlcPlaceholderFields(
        _ driftPlcCertificationReport: DriftPlcFixedTargetCertificationReport
    ) -> [(name: String, value: String)] {
        [
            ("driftPlcCertificationReport.id", driftPlcCertificationReport.id),
            ("driftPlcCertificationReport.title", driftPlcCertificationReport.title),
            (
                "driftPlcCertificationReport.runArtifactPath",
                driftPlcCertificationReport.runArtifactPath ?? ""
            ),
            ("driftPlcCertificationReport.notes", driftPlcCertificationReport.notes)
        ]
    }

    private func aoipEvaluationPlaceholderFields(
        _ aoipEvaluationReport: AoipEvaluationReport
    ) -> [(name: String, value: String)] {
        aoipEvaluationRouteAndPtpFields(aoipEvaluationReport)
            + aoipEvaluationSwitchFields(aoipEvaluationReport)
            + aoipEvaluationEndpointFields(aoipEvaluationReport)
            + aoipEvaluationStressFields(aoipEvaluationReport)
    }

    private func aoipEvaluationRouteAndPtpFields(
        _ aoipEvaluationReport: AoipEvaluationReport
    ) -> [(name: String, value: String)] {
        [
            ("aoipEvaluationReport.id", aoipEvaluationReport.id),
            ("aoipEvaluationReport.title", aoipEvaluationReport.title),
            ("aoipEvaluationReport.route.label", aoipEvaluationReport.route.label),
            ("aoipEvaluationReport.route.topology", aoipEvaluationReport.route.topology),
            ("aoipEvaluationReport.ptp.version", aoipEvaluationReport.ptp.version),
            ("aoipEvaluationReport.ptp.profile", aoipEvaluationReport.ptp.profile),
            ("aoipEvaluationReport.ptp.domain", aoipEvaluationReport.ptp.domain),
            ("aoipEvaluationReport.ptp.masterClockId", aoipEvaluationReport.ptp.masterClockId),
            ("aoipEvaluationReport.ptp.lockState", aoipEvaluationReport.ptp.lockState)
        ]
    }

    private func aoipEvaluationSwitchFields(
        _ aoipEvaluationReport: AoipEvaluationReport
    ) -> [(name: String, value: String)] {
        [
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
            ("aoipEvaluationReport.switchProfile.schedule", aoipEvaluationReport.switchProfile.schedule)
        ]
    }

    private func aoipEvaluationEndpointFields(
        _ aoipEvaluationReport: AoipEvaluationReport
    ) -> [(name: String, value: String)] {
        [
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
            )
        ]
    }

    private func aoipEvaluationStressFields(
        _ aoipEvaluationReport: AoipEvaluationReport
    ) -> [(name: String, value: String)] {
        [
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
            ("aoipEvaluationReport.notes", aoipEvaluationReport.notes)
        ]
    }

    private func profileEvidencePlaceholderFields(
        _ profileEvidence: AoipProfileEvidence
    ) -> [(name: String, value: String)] {
        var fields: [(name: String, value: String)] = []
        for (index, value) in profileEvidence.standardsRead.enumerated() {
            fields.append((
                "aoipEvaluationReport.profileEvidence.standardsRead[\(index)]",
                value
            ))
        }
        for (index, value) in profileEvidence.vendorProfilesRead.enumerated() {
            fields.append((
                "aoipEvaluationReport.profileEvidence.vendorProfilesRead[\(index)]",
                value
            ))
        }
        return fields
    }
}
