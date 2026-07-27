// Compares latency candidates against thresholds and records each tuning change so selected settings remain traceable to measured inputs.
import Foundation
import OpenLolaContracts

/// Labels the provenance of latency-tuning evidence so recommendations do not overstate measurements.
public enum LatencyTuningEvidenceKind: String, Codable, Equatable, Sendable {
    case synthetic
    case physicalReferenceRig
}

/// Reports `emptyField`, `emptyList`, `duplicateCandidate`, and `nonPositiveField` failures that stop invalid timing and drift control work before it reaches a live path.
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
// swiftlint:disable:next identifier_name
    case passPromotedChangeReferencesUnknownCandidate(String)
// swiftlint:disable:next identifier_name
    case passWithoutPromotedSelectedCandidateEvidence
// swiftlint:disable:next identifier_name
    case passWithoutSameHardwareBaselineComparison
// swiftlint:disable:next identifier_name
    case passSelectedCandidateMissingProfileEvidence(String, LatencyProfile)
}

/// Sets `budgetDocument`, `minimumDurationSeconds`, `oneWayTargetMicroseconds`, and `jitterP99MaxMicroseconds` used to accept or reject a latency-tuning candidate.
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

}

/// Identifies `reportId`, `hardware`, `route`, and `audioMode` for one proposed latency-tuning configuration.
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

}

/// Links `id`, `summary`, `beforeCandidateReportId`, and `afterCandidateReportId` to one documented latency-tuning change.
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

/// Records `id`, `title`, `capturedAt`, and `runMode` so timing and drift control measurements and verdicts can be checked after a run.
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

}

/// Exercises a deterministic timing and drift control path so regressions remain reproducible without hardware.
public enum LatencyTuningSyntheticSmoke {
    public static func run() -> LatencyTuningReport {
        let hardware = syntheticHardware
        let directRoute = syntheticDirectRoute
        return LatencyTuningReport(
            id: "m07-latency-tuning-synthetic-smoke",
            title: "M07 latency tuning source-validation smoke",
            capturedAt: "2026-05-03T00:00:00Z",
            runMode: .synthetic,
            evidenceKind: .synthetic,
            comparisonHardware: hardware,
            comparisonRoute: directRoute,
            sourceReportIds: syntheticSourceReportIds,
            candidates: syntheticCandidates(hardware: hardware, directRoute: directRoute),
            selectedCandidateReportId: nil,
            rollbackCandidateReportId: nil,
            sameHardwareLolaBaselineReportId: nil,
            comparedWithSameHardwareLolaBaseline: false,
            thresholds: syntheticThresholds,
            tuningChanges: syntheticTuningChanges,
            verdict: .partial,
            notes: "Source-validation smoke only; cannot select physical fastest stable profile."
        )
    }

    private static var syntheticHardware: HardwareIdentity {
        HardwareIdentity(
            referenceMac: "synthetic-mac",
            audioInterface: "synthetic-built-in-audio",
            osVersion: "not-measured",
            driverVersion: "not-measured"
        )
    }

    private static var syntheticDirectRoute: RouteIdentity {
        RouteIdentity(label: "direct-link", topology: "source-validation-only")
    }

    private static var syntheticSourceReportIds: [String] {
        ["synthetic-direct-48k-32f", "synthetic-direct-48k-64f", "synthetic-campus-48k-32f"]
    }

    private static func syntheticCandidates(
        hardware: HardwareIdentity,
        directRoute: RouteIdentity
    ) -> [LatencyTuningCandidate] {
        [
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
                exclusionReason: "Different route label; retained outside direct-link comparison."
            ))
        ]
    }

    private static var syntheticThresholds: LatencyTuningThresholds {
        LatencyTuningThresholds(
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
        )
    }

    private static var syntheticTuningChanges: [LatencyTuningChangeRecord] {
        [
            LatencyTuningChangeRecord(
                id: "synthetic-buffer-change",
                summary: "Synthetic 64-frame to 32-frame tuning comparison.",
                beforeCandidateReportId: "synthetic-direct-48k-64f",
                afterCandidateReportId: "synthetic-direct-48k-32f",
                beforeOneWayMicroseconds: 3_200,
                afterOneWayMicroseconds: 2_400,
                promoted: false,
                notes: "Source-validation only; physical promotion evidence is not present."
            )
        ]
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
                LatencyBenchmarkWarning(field: "audio.callback", message: "synthetic warning placeholder")
            ],
            threadWarnings: [
                LatencyBenchmarkWarning(field: "audio.callback", message: "synthetic warning placeholder")
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
