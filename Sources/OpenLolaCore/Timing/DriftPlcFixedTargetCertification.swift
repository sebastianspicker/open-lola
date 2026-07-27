// Validates DriftPlcFixedTargetCertification acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation
import OpenLolaContracts

// swiftlint:disable:next type_name
/// Reports `emptyField`, `passWithoutMeasuredRun`, `partialWithoutReason`, and `passWithoutRequiredReports` failures that stop invalid timing and drift control work before it reaches a live path.
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
/// Records `id`, `title`, `capturedAt`, and `runMode` so timing and drift control measurements and verdicts can be checked after a run.
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

    public enum IdentityDomain {}
    public typealias Identity = ReportCaptureIdentity<IdentityDomain>

    public struct SupportingReports: Equatable, Sendable {
        public var routeCertificationReport: MacToMacRouteCertificationReport?
        public var driftPlcReport: DriftPlcReport?
        public var sourceRealtimeEngineReport: RealtimeAudioEngineReport?
        public var lolaBaselineComparison: LolaBaselineComparison?

        public init(
            routeCertificationReport: MacToMacRouteCertificationReport?,
            driftPlcReport: DriftPlcReport?,
            sourceRealtimeEngineReport: RealtimeAudioEngineReport? = nil,
            lolaBaselineComparison: LolaBaselineComparison? = nil
        ) {
            self.routeCertificationReport = routeCertificationReport
            self.driftPlcReport = driftPlcReport
            self.sourceRealtimeEngineReport = sourceRealtimeEngineReport
            self.lolaBaselineComparison = lolaBaselineComparison
        }
    }

    public struct Outcome: Equatable, Sendable {
        public var runMode: ReportRunMode
        public var runArtifactPath: String?
        public var notTestedReason: String?
        public var verdict: MeasurementVerdict
        public var notes: String

        public init(
            runMode: ReportRunMode,
            runArtifactPath: String?,
            notTestedReason: String?,
            verdict: MeasurementVerdict,
            notes: String
        ) {
            self.runMode = runMode
            self.runArtifactPath = runArtifactPath
            self.notTestedReason = notTestedReason
            self.verdict = verdict
            self.notes = notes
        }
    }

    public init(
        identity: Identity,
        supportingReports: SupportingReports,
        outcome: Outcome
    ) {
        self.id = identity.id
        self.title = identity.title
        self.capturedAt = identity.capturedAt
        self.runMode = outcome.runMode
        self.routeCertificationReport = supportingReports.routeCertificationReport
        self.driftPlcReport = supportingReports.driftPlcReport
        self.sourceRealtimeEngineReport = supportingReports.sourceRealtimeEngineReport
        self.lolaBaselineComparison = supportingReports.lolaBaselineComparison
        self.runArtifactPath = outcome.runArtifactPath
        self.notTestedReason = outcome.notTestedReason
        self.verdict = outcome.verdict
        self.notes = outcome.notes
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
            guard reports.sourceRealtimeEngineReport.sourceRouteCertificationReport?.id
                == reports.routeCertificationReport.id else {
            throw DriftPlcFixedTargetCertificationValidationError.passWithRealtimeRouteMismatch(
                expected: reports.routeCertificationReport.id,
                actual: reports.sourceRealtimeEngineReport.sourceRouteCertificationReport?.id ?? ""
            )
        }
        guard reports.routeCertificationReport.sourceRealtimeEngineReportId
            == reports.sourceRealtimeEngineReport.id else {
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
            missingReportName(lolaBaselineComparison, "lolaBaselineComparison")
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
    placeholderHeaderFields()
    + routeCertificationPlaceholderFields(routeCertificationReport)
    + directLinkPlaceholderFields(routeCertificationReport, directLinkReport)
    + driftPlcPlaceholderFields(driftPlcReport)
    + realtimePlaceholderFields(sourceRealtimeEngineReport)
    + lolaBaselinePlaceholderFields(lolaBaselineComparison)
}
}
