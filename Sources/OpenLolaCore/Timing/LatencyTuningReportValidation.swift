// Validates LatencyTuningReportValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension LatencyTuningReport {
    public func validate() throws {
        try validateIdentity()
        try validateThresholds()
        try validateCandidates()
        try validateTuningChanges()
        try validatePassVerdict()
    }

    private func validateIdentity() throws {
        try LatencyTuningValidator.requireNonEmpty(id, "id")
        try LatencyTuningValidator.requireNonEmpty(title, "title")
        try LatencyTuningValidator.requireNonEmpty(capturedAt, "capturedAt")
        try validateLatencyTuningHardware(comparisonHardware, prefix: "comparisonHardware")
        try validateLatencyTuningRoute(comparisonRoute, prefix: "comparisonRoute")
        try LatencyTuningValidator.requireNonEmpty(notes, "notes")
        guard !sourceReportIds.isEmpty else {
            throw LatencyTuningValidationError.emptyList("sourceReportIds")
        }
        for (index, reportId) in sourceReportIds.enumerated() {
            try LatencyTuningValidator.requireNonEmpty(reportId, "sourceReportIds[\(index)]")
        }
        if let selectedCandidateReportId {
            try LatencyTuningValidator.requireNonEmpty(selectedCandidateReportId, "selectedCandidateReportId")
        }
        if let rollbackCandidateReportId {
            try LatencyTuningValidator.requireNonEmpty(rollbackCandidateReportId, "rollbackCandidateReportId")
        }
        if let sameHardwareLolaBaselineReportId {
            try LatencyTuningValidator.requireNonEmpty(
                sameHardwareLolaBaselineReportId,
                "sameHardwareLolaBaselineReportId"
            )
        }
    }

    private func validateThresholds() throws {
        try LatencyTuningValidator.requireNonEmpty(thresholds.budgetDocument, "thresholds.budgetDocument")
        try LatencyTuningValidator.requirePositive(
            thresholds.minimumDurationSeconds,
            "thresholds.minimumDurationSeconds"
        )
        try LatencyTuningValidator.requirePositive(
            thresholds.oneWayTargetMicroseconds,
            "thresholds.oneWayTargetMicroseconds"
        )
        try LatencyTuningValidator.requireNonNegative(
            thresholds.jitterP99MaxMicroseconds,
            "thresholds.jitterP99MaxMicroseconds"
        )
        try requireLatencyTuningPercent(thresholds.packetLossMaxPercent, "thresholds.packetLossMaxPercent")
        try requireLatencyTuningPercent(thresholds.cpuP99MaxPercent, "thresholds.cpuP99MaxPercent")
        try LatencyTuningValidator.requireNonNegative(thresholds.underrunMaxCount, "thresholds.underrunMaxCount")
        try LatencyTuningValidator.requireNonNegative(
            thresholds.callbackDeadlineWarningMaxCount,
            "thresholds.callbackDeadlineWarningMaxCount"
        )
        try LatencyTuningValidator.requireNonNegative(
            thresholds.allocationWarningMaxCount,
            "thresholds.allocationWarningMaxCount"
        )
        try LatencyTuningValidator.requireNonNegative(
            thresholds.artifactWarningMaxCount,
            "thresholds.artifactWarningMaxCount"
        )
    }

    private func validateCandidates() throws {
        guard !candidates.isEmpty else {
            throw LatencyTuningValidationError.emptyList("candidates")
        }
        var seen: Set<String> = []
        for candidate in candidates {
            guard seen.insert(candidate.reportId).inserted else {
                throw LatencyTuningValidationError.duplicateCandidate(candidate.reportId)
            }
            try validate(candidate)
        }
    }

    private func validate(_ candidate: LatencyTuningCandidate) throws {
        try LatencyTuningValidator.requireNonEmpty(candidate.reportId, "candidates.reportId")
        try validateLatencyTuningHardware(candidate.hardware, prefix: "candidates.hardware")
        try validateLatencyTuningRoute(candidate.route, prefix: "candidates.route")
        try LatencyTuningValidator.requirePositive(
            candidate.audioMode.sampleRateHertz,
            "candidates.audioMode.sampleRateHertz"
        )
        try LatencyTuningValidator.requirePositive(
            candidate.audioMode.framesPerBuffer,
            "candidates.audioMode.framesPerBuffer"
        )
        try LatencyTuningValidator.requirePositive(
candidate.audioMode.channelCount,
"candidates.audioMode.channelCount"
)
        try LatencyTuningValidator.requireNonEmpty(
candidate.audioMode.sampleFormat,
"candidates.audioMode.sampleFormat"
)
        try LatencyTuningValidator.requirePositive(candidate.durationSeconds, "candidates.durationSeconds")
        try validateLatencyTuningTiming(candidate.timing, candidateId: candidate.reportId)
        try validateLatencyTuningLoss(candidate.loss)
        try validateLatencyTuningFaults(candidate.faults)
        try validateLatencyTuningResources(candidate.resources, candidateId: candidate.reportId)
        try LatencyTuningValidator.requireNonNegative(
            candidate.callbackDeadlineWarnings,
            "candidates.callbackDeadlineWarnings"
        )
        for (index, artifactWarning) in candidate.artifactWarnings.enumerated() {
            try LatencyTuningValidator.requireNonEmpty(artifactWarning, "candidates.artifactWarnings[\(index)]")
        }
        try candidate.latencyProfileEvidence?.validate(
            for: candidate.audioMode,
            verdict: verdict
        )
        try LatencyTuningValidator.requireNonEmpty(candidate.notes, "candidates.notes")

        if candidate.includedInSelection {
            guard candidate.hardware == comparisonHardware else {
                throw LatencyTuningValidationError.includedCandidateHardwareMismatch(candidate.reportId)
            }
            guard candidate.route == comparisonRoute else {
                throw LatencyTuningValidationError.includedCandidateRouteMismatch(candidate.reportId)
            }
        } else if candidate.exclusionReason?.isEmpty != false {
            throw LatencyTuningValidationError.excludedCandidateMissingReason(candidate.reportId)
        }
    }

    private func validateTuningChanges() throws {
        for change in tuningChanges {
            try LatencyTuningValidator.requireNonEmpty(change.id, "tuningChanges.id")
            try LatencyTuningValidator.requireNonEmpty(change.summary, "tuningChanges.summary")
            try LatencyTuningValidator.requireNonEmpty(
                change.beforeCandidateReportId,
                "tuningChanges.beforeCandidateReportId"
            )
            try LatencyTuningValidator.requireNonEmpty(
                change.afterCandidateReportId,
                "tuningChanges.afterCandidateReportId"
            )
            try LatencyTuningValidator.requireNonNegative(
                change.beforeOneWayMicroseconds,
                "tuningChanges.beforeOneWayMicroseconds"
            )
            try LatencyTuningValidator.requireNonNegative(
                change.afterOneWayMicroseconds,
                "tuningChanges.afterOneWayMicroseconds"
            )
            try LatencyTuningValidator.requireNonEmpty(change.notes, "tuningChanges.notes")
            if change.promoted && change.afterOneWayMicroseconds > change.beforeOneWayMicroseconds {
                throw LatencyTuningValidationError.promotedChangeIncreasesOneWay(
                    changeId: change.id,
                    before: change.beforeOneWayMicroseconds,
                    after: change.afterOneWayMicroseconds
                )
            }
        }
    }

    private func validatePassVerdict() throws {
        try LatencyTuningValidator.validateVerdictPass(verdict) {
            try validatePassEvidence()
            let comparableCandidates = try passComparableCandidates()
            let selected = try passSelectedCandidate()
            try validateSelectedProfileEvidence(selected)
            try validateSelectedIsFastest(selected, comparableCandidates: comparableCandidates)
            try validateSelectedThresholds(selected)
            try validateRollbackCandidate()
            try validatePromotedChangeEvidence(selectedId: selected.reportId)
            try validateSameHardwareBaselineComparison()
        }
    }

    private func validatePassEvidence() throws {
        guard runMode == .measured else {
            throw LatencyTuningValidationError.passWithoutMeasuredRun
        }
        guard evidenceKind == .physicalReferenceRig else {
            throw LatencyTuningValidationError.passWithoutPhysicalReferenceRig
        }
        guard thresholds.budgetDocument.contains("latency-budget.md") else {
            throw LatencyTuningValidationError.passWithoutLatencyBudgetReference(thresholds.budgetDocument)
        }
    }

    private func passComparableCandidates() throws -> [LatencyTuningCandidate] {
        let comparableCandidates = candidates.filter(\.includedInSelection)
        guard comparableCandidates.count >= 2 else {
            throw LatencyTuningValidationError.passWithoutComparableMatrix
        }
        return comparableCandidates
    }

    private func passSelectedCandidate() throws -> LatencyTuningCandidate {
        guard let selectedId = selectedCandidateReportId else {
            throw LatencyTuningValidationError.passWithoutSelectedCandidate
        }
        guard let selected = candidates.first(where: { $0.reportId == selectedId }) else {
            throw LatencyTuningValidationError.selectedCandidateMissing(selectedId)
        }
        guard selected.includedInSelection else {
            throw LatencyTuningValidationError.passSelectedCandidateNotComparable(selectedId)
        }
        guard selected.accepted && selected.stable else {
            throw LatencyTuningValidationError.passSelectedCandidateIsNotStable(selectedId)
        }
        return selected
    }

    private func validateSelectedProfileEvidence(_ selected: LatencyTuningCandidate) throws {
        if let profile = latencyProfile(for: selected.audioMode),
           profile != .safeLowLatency,
           selected.latencyProfileEvidence == nil {
            throw LatencyTuningValidationError.passSelectedCandidateMissingProfileEvidence(
                selected.reportId,
                profile
            )
        }
    }

    private func validateSelectedIsFastest(
        _ selected: LatencyTuningCandidate,
        comparableCandidates: [LatencyTuningCandidate]
    ) throws {
        let stableCandidates = comparableCandidates.filter { $0.accepted && $0.stable }
        guard let fastest = stableCandidates.min(by: latencyTuningCandidateIsFaster) else {
            throw LatencyTuningValidationError.passWithoutStableCandidate
        }
        guard fastest.reportId == selected.reportId else {
            throw LatencyTuningValidationError.passSelectedCandidateIsNotFastest(
                selected: selected.reportId,
                fastest: fastest.reportId
            )
        }
    }

    private func validateSelectedThresholds(_ selected: LatencyTuningCandidate) throws {
        if selected.durationSeconds < thresholds.minimumDurationSeconds {
            throw LatencyTuningValidationError.passSelectedDurationTooShort(
                value: selected.durationSeconds,
                threshold: thresholds.minimumDurationSeconds
            )
        }
        try validateSelectedDoubleThreshold(
            field: "timing.oneWayEstimateMicroseconds",
            value: selected.timing.oneWayEstimateMicroseconds,
            threshold: thresholds.oneWayTargetMicroseconds
        )
        try validateSelectedDoubleThreshold(
            field: "timing.jitter.p99Microseconds",
            value: selected.timing.jitter.p99Microseconds,
            threshold: thresholds.jitterP99MaxMicroseconds
        )
        try validateSelectedDoubleThreshold(
            field: "loss.lossPercent",
            value: selected.loss.lossPercent,
            threshold: thresholds.packetLossMaxPercent
        )
        try validateSelectedDoubleThreshold(
            field: "resources.cpuP99Percent",
            value: selected.resources.cpuP99Percent,
            threshold: thresholds.cpuP99MaxPercent
        )
        try validateSelectedCountThreshold(
            field: "faults.underruns",
            value: selected.faults.underruns,
            threshold: thresholds.underrunMaxCount
        )
        try validateSelectedCountThreshold(
            field: "callbackDeadlineWarnings",
            value: selected.callbackDeadlineWarnings,
            threshold: thresholds.callbackDeadlineWarningMaxCount
        )
        try validateSelectedCountThreshold(
            field: "resources.allocationWarnings",
            value: selected.resources.allocationWarnings.count,
            threshold: thresholds.allocationWarningMaxCount
        )
        try validateSelectedCountThreshold(
            field: "artifactWarnings",
            value: selected.artifactWarnings.count,
            threshold: thresholds.artifactWarningMaxCount
        )
    }

    private func validateSelectedDoubleThreshold(
        field: String,
        value: Double,
        threshold: Double
    ) throws {
        try LatencyTuningValidator.validateThreshold(
            value: value,
            max: threshold,
            error: LatencyTuningValidationError.passSelectedExceedsThreshold(
                field: field,
                value: value,
                threshold: threshold
            )
        )
    }

    private func validateSelectedCountThreshold(
        field: String,
        value: Int,
        threshold: Int
    ) throws {
        try LatencyTuningValidator.validateThreshold(
            value: value,
            max: threshold,
            error: LatencyTuningValidationError.passSelectedCountExceedsThreshold(
                field: field,
                value: value,
                threshold: threshold
            )
        )
    }

    private func validateRollbackCandidate() throws {
        guard let rollbackId = rollbackCandidateReportId else {
            throw LatencyTuningValidationError.passWithoutRollbackCandidate
        }
        guard let rollback = candidates.first(where: { $0.reportId == rollbackId }) else {
            throw LatencyTuningValidationError.rollbackCandidateMissing(rollbackId)
        }
        guard rollback.includedInSelection, rollback.accepted, rollback.stable else {
            throw LatencyTuningValidationError.rollbackCandidateIneligible(rollbackId)
        }
    }

    private func validatePromotedChangeEvidence(selectedId: String) throws {
        let promotedChanges = tuningChanges.filter(\.promoted)
        guard !promotedChanges.isEmpty else {
            throw LatencyTuningValidationError.passWithoutPromotedChangeEvidence
        }
        let candidateIds = Set(candidates.map(\.reportId))
        for change in promotedChanges
            where !candidateIds.contains(change.beforeCandidateReportId)
                || !candidateIds.contains(change.afterCandidateReportId) {
            throw LatencyTuningValidationError.passPromotedChangeReferencesUnknownCandidate(change.id)
        }
        guard promotedChanges.contains(where: { $0.afterCandidateReportId == selectedId }) else {
            throw LatencyTuningValidationError.passWithoutPromotedSelectedCandidateEvidence
        }
    }

    private func validateSameHardwareBaselineComparison() throws {
        guard comparedWithSameHardwareLolaBaseline,
              sameHardwareLolaBaselineReportId?.isEmpty == false else {
            throw LatencyTuningValidationError.passWithoutSameHardwareBaselineComparison
        }
    }
}
