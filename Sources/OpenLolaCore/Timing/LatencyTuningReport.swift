import Foundation
import OpenLolaContracts

public enum LatencyTuningEvidenceKind: String, Codable, Equatable, Sendable {
    case synthetic
    case physicalReferenceRig
}

public enum LatencyTuningValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError,
    ValidationNonFiniteFieldError {
    case emptyField(String)
    case emptyList(String)
    case duplicateCandidate(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case percentOutOfRange(field: String, value: Double)
    case unorderedJitter(String)
    case unorderedCpu(String)
    case oneWayExceedsRoundTrip(candidate: String, oneWay: Double, roundTrip: Double)
    case includedCandidateHardwareMismatch(String)
    case includedCandidateRouteMismatch(String)
    case excludedCandidateMissingReason(String)
    case promotedChangeIncreasesOneWay(changeId: String, before: Double, after: Double)
    case passWithoutMeasuredRun
    case passWithoutPhysicalReferenceRig
    case passWithoutLatencyBudgetReference(String)
    case passWithoutComparableMatrix
    case passWithoutSelectedCandidate
    case selectedCandidateMissing(String)
    case passSelectedCandidateNotComparable(String)
    case passSelectedCandidateIsNotStable(String)
    case passWithoutStableCandidate
    case passSelectedCandidateIsNotFastest(selected: String, fastest: String)
    case passSelectedDurationTooShort(value: Int, threshold: Int)
    case passSelectedExceedsThreshold(field: String, value: Double, threshold: Double)
    case passSelectedCountExceedsThreshold(field: String, value: Int, threshold: Int)
    case passWithoutRollbackCandidate
    case rollbackCandidateMissing(String)
    case rollbackCandidateIneligible(String)
    case passWithoutPromotedChangeEvidence
    case passPromotedChangeReferencesUnknownCandidate(String)
    case passWithoutPromotedSelectedCandidateEvidence
    case passWithoutSameHardwareBaselineComparison
    case passSelectedCandidateMissingProfileEvidence(String, LatencyProfile)
}

public struct LatencyTuningThresholds: Codable, Equatable, Sendable {
    public var budgetDocument: String
    public var minimumDurationSeconds: Int
    public var oneWayTargetMicroseconds: Double
    public var jitterP99MaxMicroseconds: Double
    public var packetLossMaxPercent: Double
    public var cpuP99MaxPercent: Double
    public var underrunMaxCount: Int
    public var callbackDeadlineWarningMaxCount: Int
    public var allocationWarningMaxCount: Int
    public var artifactWarningMaxCount: Int

    public init(
        budgetDocument: String,
        minimumDurationSeconds: Int,
        oneWayTargetMicroseconds: Double,
        jitterP99MaxMicroseconds: Double,
        packetLossMaxPercent: Double,
        cpuP99MaxPercent: Double,
        underrunMaxCount: Int,
        callbackDeadlineWarningMaxCount: Int,
        allocationWarningMaxCount: Int,
        artifactWarningMaxCount: Int
    ) {
        self.budgetDocument = budgetDocument
        self.minimumDurationSeconds = minimumDurationSeconds
        self.oneWayTargetMicroseconds = oneWayTargetMicroseconds
        self.jitterP99MaxMicroseconds = jitterP99MaxMicroseconds
        self.packetLossMaxPercent = packetLossMaxPercent
        self.cpuP99MaxPercent = cpuP99MaxPercent
        self.underrunMaxCount = underrunMaxCount
        self.callbackDeadlineWarningMaxCount = callbackDeadlineWarningMaxCount
        self.allocationWarningMaxCount = allocationWarningMaxCount
        self.artifactWarningMaxCount = artifactWarningMaxCount
    }
}

public struct LatencyTuningCandidate: Codable, Equatable, Sendable {
    public var reportId: String
    public var hardware: HardwareIdentity
    public var route: RouteIdentity
    public var audioMode: AudioMode
    public var durationSeconds: Int
    public var timing: LatencyBenchmarkTimingMetrics
    public var loss: LatencyBenchmarkLossMetrics
    public var faults: LatencyBenchmarkFaultMetrics
    public var resources: LatencyBenchmarkResourceMetrics
    public var callbackDeadlineWarnings: Int
    public var artifactWarnings: [String]
    public var latencyProfileEvidence: LatencyProfileEvidence?
    public var stable: Bool
    public var accepted: Bool
    public var includedInSelection: Bool
    public var exclusionReason: String?
    public var notes: String

    public init(
        reportId: String,
        hardware: HardwareIdentity,
        route: RouteIdentity,
        audioMode: AudioMode,
        durationSeconds: Int,
        timing: LatencyBenchmarkTimingMetrics,
        loss: LatencyBenchmarkLossMetrics,
        faults: LatencyBenchmarkFaultMetrics,
        resources: LatencyBenchmarkResourceMetrics,
        callbackDeadlineWarnings: Int,
        artifactWarnings: [String],
        latencyProfileEvidence: LatencyProfileEvidence? = nil,
        stable: Bool,
        accepted: Bool,
        includedInSelection: Bool,
        exclusionReason: String?,
        notes: String
    ) {
        self.reportId = reportId
        self.hardware = hardware
        self.route = route
        self.audioMode = audioMode
        self.durationSeconds = durationSeconds
        self.timing = timing
        self.loss = loss
        self.faults = faults
        self.resources = resources
        self.callbackDeadlineWarnings = callbackDeadlineWarnings
        self.artifactWarnings = artifactWarnings
        self.latencyProfileEvidence = latencyProfileEvidence
        self.stable = stable
        self.accepted = accepted
        self.includedInSelection = includedInSelection
        self.exclusionReason = exclusionReason
        self.notes = notes
    }
}

public struct LatencyTuningChangeRecord: Codable, Equatable, Sendable {
    public var id: String
    public var summary: String
    public var beforeCandidateReportId: String
    public var afterCandidateReportId: String
    public var beforeOneWayMicroseconds: Double
    public var afterOneWayMicroseconds: Double
    public var promoted: Bool
    public var notes: String

    public init(
        id: String,
        summary: String,
        beforeCandidateReportId: String,
        afterCandidateReportId: String,
        beforeOneWayMicroseconds: Double,
        afterOneWayMicroseconds: Double,
        promoted: Bool,
        notes: String
    ) {
        self.id = id
        self.summary = summary
        self.beforeCandidateReportId = beforeCandidateReportId
        self.afterCandidateReportId = afterCandidateReportId
        self.beforeOneWayMicroseconds = beforeOneWayMicroseconds
        self.afterOneWayMicroseconds = afterOneWayMicroseconds
        self.promoted = promoted
        self.notes = notes
    }
}

public struct LatencyTuningReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: ReportRunMode
    public var evidenceKind: LatencyTuningEvidenceKind
    public var comparisonHardware: HardwareIdentity
    public var comparisonRoute: RouteIdentity
    public var sourceReportIds: [String]
    public var candidates: [LatencyTuningCandidate]
    public var selectedCandidateReportId: String?
    public var rollbackCandidateReportId: String?
    public var sameHardwareLolaBaselineReportId: String?
    public var comparedWithSameHardwareLolaBaseline: Bool
    public var thresholds: LatencyTuningThresholds
    public var tuningChanges: [LatencyTuningChangeRecord]
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: ReportRunMode,
        evidenceKind: LatencyTuningEvidenceKind,
        comparisonHardware: HardwareIdentity,
        comparisonRoute: RouteIdentity,
        sourceReportIds: [String],
        candidates: [LatencyTuningCandidate],
        selectedCandidateReportId: String?,
        rollbackCandidateReportId: String?,
        sameHardwareLolaBaselineReportId: String?,
        comparedWithSameHardwareLolaBaseline: Bool,
        thresholds: LatencyTuningThresholds,
        tuningChanges: [LatencyTuningChangeRecord],
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.evidenceKind = evidenceKind
        self.comparisonHardware = comparisonHardware
        self.comparisonRoute = comparisonRoute
        self.sourceReportIds = sourceReportIds
        self.candidates = candidates
        self.selectedCandidateReportId = selectedCandidateReportId
        self.rollbackCandidateReportId = rollbackCandidateReportId
        self.sameHardwareLolaBaselineReportId = sameHardwareLolaBaselineReportId
        self.comparedWithSameHardwareLolaBaseline = comparedWithSameHardwareLolaBaseline
        self.thresholds = thresholds
        self.tuningChanges = tuningChanges
        self.verdict = verdict
        self.notes = notes
    }
}

public enum LatencyTuningSyntheticSmoke {
    public static func run() -> LatencyTuningReport {
        let hardware = HardwareIdentity(
            referenceMac: "synthetic-mac",
            audioInterface: "synthetic-built-in-audio",
            osVersion: "not-measured",
            driverVersion: "not-measured"
        )
        let directRoute = RouteIdentity(label: "direct-link", topology: "source-validation-only")
        return LatencyTuningReport(
            id: "m07-latency-tuning-synthetic-smoke",
            title: "M07 latency tuning source-validation smoke",
            capturedAt: "2026-05-03T00:00:00Z",
            runMode: .synthetic,
            evidenceKind: .synthetic,
            comparisonHardware: hardware,
            comparisonRoute: directRoute,
            sourceReportIds: ["synthetic-direct-48k-32f", "synthetic-direct-48k-64f", "synthetic-campus-48k-32f"],
            candidates: [
                latencyTuningSyntheticCandidate(.init(
                    reportId: "synthetic-direct-48k-32f",
                    hardware: hardware,
                    route: directRoute,
                    framesPerBuffer: 32,
                    oneWayMicroseconds: 2_400,
                    includedInSelection: true,
                    exclusionReason: nil
                )),
                latencyTuningSyntheticCandidate(.init(
                    reportId: "synthetic-direct-48k-64f",
                    hardware: hardware,
                    route: directRoute,
                    framesPerBuffer: 64,
                    oneWayMicroseconds: 3_200,
                    includedInSelection: true,
                    exclusionReason: nil
                )),
                latencyTuningSyntheticCandidate(.init(
                    reportId: "synthetic-campus-48k-32f",
                    hardware: hardware,
                    route: RouteIdentity(label: "campus-path", topology: "source-validation-only"),
                    framesPerBuffer: 32,
                    oneWayMicroseconds: 3_900,
                    includedInSelection: false,
                    exclusionReason: "Different route label; retained outside the direct-link comparison."
                )),
            ],
            selectedCandidateReportId: nil,
            rollbackCandidateReportId: nil,
            sameHardwareLolaBaselineReportId: nil,
            comparedWithSameHardwareLolaBaseline: false,
            thresholds: LatencyTuningThresholds(
                budgetDocument: "docs/latency-budget.md#audio-budget",
                minimumDurationSeconds: 3_600,
                oneWayTargetMicroseconds: 5_000,
                jitterP99MaxMicroseconds: 1_000,
                packetLossMaxPercent: 0.1,
                cpuP99MaxPercent: 75,
                underrunMaxCount: 0,
                callbackDeadlineWarningMaxCount: 0,
                allocationWarningMaxCount: 0,
                artifactWarningMaxCount: 0
            ),
            tuningChanges: [
                LatencyTuningChangeRecord(
                    id: "synthetic-buffer-change",
                    summary: "Synthetic 64-frame to 32-frame tuning comparison.",
                    beforeCandidateReportId: "synthetic-direct-48k-64f",
                    afterCandidateReportId: "synthetic-direct-48k-32f",
                    beforeOneWayMicroseconds: 3_200,
                    afterOneWayMicroseconds: 2_400,
                    promoted: false,
                    notes: "Source-validation only; physical promotion evidence is not present."
                ),
            ],
            verdict: .partial,
            notes: "Source-validation smoke only; cannot select the physical fastest stable profile."
        )
    }
}

private struct LatencyTuningSyntheticCandidateRequest {
    var reportId: String
    var hardware: HardwareIdentity
    var route: RouteIdentity
    var framesPerBuffer: Int
    var oneWayMicroseconds: Double
    var includedInSelection: Bool
    var exclusionReason: String?
}

private func latencyTuningSyntheticCandidate(
    _ request: LatencyTuningSyntheticCandidateRequest
) -> LatencyTuningCandidate {
    LatencyTuningCandidate(
        reportId: request.reportId,
        hardware: request.hardware,
        route: request.route,
        audioMode: AudioMode(
            sampleRateHertz: 48_000,
            framesPerBuffer: request.framesPerBuffer,
            channelCount: 2,
            sampleFormat: "float32LittleEndian"
        ),
        durationSeconds: 60,
        timing: SourceValidationMetrics.timing(
            oneWayMicroseconds: request.oneWayMicroseconds,
            jitter: SourceValidationMetrics.jitter
        ),
        loss: LatencyBenchmarkLossMetrics(lostPackets: 0, latePackets: 1, lossPercent: 0),
        faults: LatencyBenchmarkFaultMetrics(underruns: 1, overruns: 0, missedDeadlines: 1, droppedFrames: 0),
        resources: LatencyBenchmarkResourceMetrics(
            cpuP50Percent: SourceValidationMetrics.cpuP50Percent,
            cpuP95Percent: SourceValidationMetrics.cpuP95Percent,
            cpuP99Percent: SourceValidationMetrics.cpuP99Percent,
            cpuMaxPercent: SourceValidationMetrics.cpuMaxPercent,
            residentMemoryMegabytes: 96,
            allocationWarnings: [
                LatencyBenchmarkWarning(field: "audio.callback", message: "synthetic warning placeholder"),
            ],
            threadWarnings: [
                LatencyBenchmarkWarning(field: "audio.callback", message: "synthetic warning placeholder"),
            ]
        ),
        callbackDeadlineWarnings: 1,
        artifactWarnings: ["synthetic source validation only"],
        stable: false,
        accepted: false,
        includedInSelection: request.includedInSelection,
        exclusionReason: request.exclusionReason,
        notes: "Synthetic source-validation candidate row."
    )
}
