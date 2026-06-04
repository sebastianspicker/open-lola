import Foundation

extension FasterThanLoLaClosureReport {
    public func validate() throws {
        try validateIdentity()
        try validateEvidence()
        try validateComparison()
        try VerdictValidationPolicy.validatePass(verdict) {
            try validatePassVerdict()
        }
    }


    private func validateIdentity() throws {
        try FasterThanLoLaClosureValidator.requireNonEmpty(id, "id")
        try FasterThanLoLaClosureValidator.requireNonEmpty(title, "title")
        try FasterThanLoLaClosureValidator.requireNonEmpty(capturedAt, "capturedAt")
        try FasterThanLoLaClosureValidator.requireNonEmpty(parityLedgerId, "parityLedgerId")
        try FasterThanLoLaClosureValidator.requireNonEmpty(notes, "notes")
    }

    private func validateEvidence() throws {
        guard !evidence.isEmpty else {
            throw FasterThanLoLaClosureValidationError.emptyList("evidence")
        }

        var seenLanes: Set<FasterThanLoLaEvidenceLane> = []
        for item in evidence {
            guard seenLanes.insert(item.lane).inserted else {
                throw FasterThanLoLaClosureValidationError.duplicateEvidenceLane(item.lane)
            }
            try FasterThanLoLaClosureValidator.requireNonEmpty(item.reportId, "evidence.reportId")
            try FasterThanLoLaClosureValidator.requireNonEmpty(item.notes, "evidence.notes")
        }
    }

    private func validateComparison() throws {
        try FasterThanLoLaClosureValidator.requireNonEmpty(comparison.lolaBaselineReportId, "comparison.lolaBaselineReportId")
        try FasterThanLoLaClosureValidator.requireNonEmpty(comparison.openLolaReportId, "comparison.openLolaReportId")
        try FasterThanLoLaClosureValidator.requireNonEmpty(comparison.lolaVersion, "comparison.lolaVersion")
        try FasterThanLoLaClosureValidator.requireNonEmpty(comparison.lolaSettings, "comparison.lolaSettings")
        try FasterThanLoLaClosureValidator.requireNonEmpty(comparison.routeLabel, "comparison.routeLabel")
        try FasterThanLoLaClosureValidator.requirePositive(comparison.packetMode.sampleRateHertz, "comparison.packetMode.sampleRateHertz")
        try FasterThanLoLaClosureValidator.requirePositive(comparison.packetMode.framesPerPacket, "comparison.packetMode.framesPerPacket")
        try FasterThanLoLaClosureValidator.requirePositive(comparison.packetMode.channelCount, "comparison.packetMode.channelCount")
        try FasterThanLoLaClosureValidator.requireNonNegative(comparison.fixedPlayoutTargetFrames, "comparison.fixedPlayoutTargetFrames")
        try FasterThanLoLaClosureValidator.requireNonNegative(comparison.durationSeconds, "comparison.durationSeconds")
        try validateLatency(comparison.openLolaLatency, label: "comparison.openLolaLatency")
        try validateLatency(comparison.lolaLatency, label: "comparison.lolaLatency")
        try FasterThanLoLaClosureValidator.requireNonNegative(comparison.lostPackets, "comparison.lostPackets")
        try FasterThanLoLaClosureValidator.requireNonNegative(comparison.latePackets, "comparison.latePackets")
        try FasterThanLoLaClosureValidator.requireNonNegative(comparison.underruns, "comparison.underruns")
        try FasterThanLoLaClosureValidator.requireNonNegative(comparison.maxAbsoluteDriftPpm, "comparison.maxAbsoluteDriftPpm")
    }

    private func validateLatency(_ latency: LolaBaselineLatencyMetrics, label: String) throws {
        try FasterThanLoLaClosureValidator.requirePositive(latency.p50Milliseconds, "\(label).p50Milliseconds")
        try FasterThanLoLaClosureValidator.requirePositive(latency.p95Milliseconds, "\(label).p95Milliseconds")
        try FasterThanLoLaClosureValidator.requirePositive(latency.p99Milliseconds, "\(label).p99Milliseconds")
        try FasterThanLoLaClosureValidator.requirePositive(latency.maxMilliseconds, "\(label).maxMilliseconds")
        guard latency.p50Milliseconds <= latency.p95Milliseconds,
              latency.p95Milliseconds <= latency.p99Milliseconds,
              latency.p99Milliseconds <= latency.maxMilliseconds else {
            throw FasterThanLoLaClosureValidationError.unorderedLatencyMetrics(label)
        }
    }

    private func validatePassVerdict() throws {
        guard runMode == .measured else {
            throw FasterThanLoLaClosureValidationError.passWithoutMeasuredRun
        }
        try validatePassEvidence()
        try validatePassComparison()
        try validatePassDurationAndTransportHealth()
        try validatePassParityDeferral()
    }

    private func validatePassEvidence() throws {
        for lane in claimScope.requiredEvidenceLanes {
            guard let item = evidence.first(where: { $0.lane == lane }) else {
                throw FasterThanLoLaClosureValidationError.passWithoutRequiredEvidence(lane)
            }
            try validatePassEvidenceItem(item)
        }
    }

    private func validatePassEvidenceItem(_ item: FasterThanLoLaEvidenceReference) throws {
        guard item.measured else {
            throw FasterThanLoLaClosureValidationError.passWithoutMeasuredEvidence(item.lane)
        }
        guard item.verdict == .pass else {
            throw FasterThanLoLaClosureValidationError.passWithoutPassEvidence(item.lane, item.verdict)
        }
        guard item.physicalOrCleanMacEvidence else {
            throw FasterThanLoLaClosureValidationError.passWithoutPhysicalOrCleanMacEvidence(item.lane)
        }
        guard item.packetCaptureOrArtifactEvidence else {
            throw FasterThanLoLaClosureValidationError.passWithoutPacketCaptureOrArtifactEvidence(item.lane)
        }
    }

    private func validatePassComparison() throws {
        guard comparison.lolaBaselineMeasured else {
            throw FasterThanLoLaClosureValidationError.passWithoutMeasuredLolaBaseline
        }
        guard comparison.measuredOnSameHardwareAndRoute else {
            throw FasterThanLoLaClosureValidationError.passWithoutSameHardwareAndRoute
        }
        guard comparison.result == .openLolaFaster else {
            throw FasterThanLoLaClosureValidationError.passWithoutOpenLolaFaster(comparison.result)
        }
        try validateLatencyWin()
    }

    private func validatePassDurationAndTransportHealth() throws {
        try VerdictValidationPolicy.passRequires(
            comparison.durationSeconds >= VerdictValidationPolicy.fasterThanLoLaMinimumPassDurationSeconds,
            FasterThanLoLaClosureValidationError.passWithRunShorterThanSixtyMinutes
        )
        guard comparison.fixedPlayoutTargetFrames > 0 else {
            throw FasterThanLoLaClosureValidationError.passWithoutFixedPlayoutTarget
        }
        guard comparison.lostPackets == 0,
              comparison.latePackets == 0,
              comparison.underruns == 0,
              !comparison.artifactsDetected else {
            throw FasterThanLoLaClosureValidationError.passWithLossLateUnderrunOrArtifacts
        }
    }

    private func validatePassParityDeferral() throws {
        guard !parityLedgerId.isEmpty else {
            throw FasterThanLoLaClosureValidationError.passWithoutParityLedger
        }
        guard parityFeaturesDeferred, windowsWireCompatibilityDeferred else {
            throw FasterThanLoLaClosureValidationError.passWithoutParityDeferral
        }
        guard !fastestPathBlockedByParity else {
            throw FasterThanLoLaClosureValidationError.passBlocksFastestPathByParity
        }
    }

    private func validateLatencyWin() throws {
        let pairs: [LatencyComparisonPair] = [
            LatencyComparisonPair(
                field: "p50Milliseconds",
                openLolaValue: comparison.openLolaLatency.p50Milliseconds,
                lolaValue: comparison.lolaLatency.p50Milliseconds
            ),
            LatencyComparisonPair(
                field: "p95Milliseconds",
                openLolaValue: comparison.openLolaLatency.p95Milliseconds,
                lolaValue: comparison.lolaLatency.p95Milliseconds
            ),
            LatencyComparisonPair(
                field: "p99Milliseconds",
                openLolaValue: comparison.openLolaLatency.p99Milliseconds,
                lolaValue: comparison.lolaLatency.p99Milliseconds
            ),
            LatencyComparisonPair(
                field: "maxMilliseconds",
                openLolaValue: comparison.openLolaLatency.maxMilliseconds,
                lolaValue: comparison.lolaLatency.maxMilliseconds
            ),
        ]

        for pair in pairs where pair.openLolaValue >= pair.lolaValue {
            throw FasterThanLoLaClosureValidationError.passWithoutLatencyWin(pair.field)
        }
    }
}

private struct LatencyComparisonPair {
    var field: String
    var openLolaValue: Double
    var lolaValue: Double
}
