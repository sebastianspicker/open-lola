import Foundation

public struct IntegratedProfileReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: IntegratedProfileRunMode
    public var defaultProfile: IntegratedProfileLabel
    public var profileOptions: [IntegratedProfileOption]
    public var subordinateEvidence: [IntegratedProfileSubordinateEvidence]
    public var degradationOrder: [IntegratedProfileDegradationStep]
    public var benchmarkMatrix: [IntegratedProfileBenchmarkRow]
    public var verdict: MeasurementVerdict
    public var notes: String

    public var aggregateSubordinateVerdict: MeasurementVerdict {
        aggregateIntegratedProfileVerdicts(
            profileOptions.map(\.verdict)
                + subordinateEvidence.map(\.verdict)
                + benchmarkMatrix.map(\.verdict)
        )
    }

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: IntegratedProfileRunMode,
        defaultProfile: IntegratedProfileLabel,
        profileOptions: [IntegratedProfileOption],
        subordinateEvidence: [IntegratedProfileSubordinateEvidence],
        degradationOrder: [IntegratedProfileDegradationStep],
        benchmarkMatrix: [IntegratedProfileBenchmarkRow],
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.defaultProfile = defaultProfile
        self.profileOptions = profileOptions
        self.subordinateEvidence = subordinateEvidence
        self.degradationOrder = degradationOrder
        self.benchmarkMatrix = benchmarkMatrix
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try validateIdentity()
        try validateProfileOptions()
        try validateSubordinateEvidence()
        try validateDegradationOrder()
        try validateBenchmarkMatrix()
        try validatePassVerdict()
        try validateAggregateVerdict()
    }

    private func validateIdentity() throws {
        try requireIntegratedProfileNonEmpty(id, "id")
        try requireIntegratedProfileNonEmpty(title, "title")
        try requireIntegratedProfileNonEmpty(capturedAt, "capturedAt")
        try requireIntegratedProfileNonEmpty(notes, "notes")
    }

    private func validateProfileOptions() throws {
        guard defaultProfile == .fastestAudio else {
            throw IntegratedProfileValidationError.defaultProfileMustBeFastestAudio(defaultProfile)
        }
        try requireIntegratedProfileList(profileOptions, "profileOptions")

        var seen: Set<IntegratedProfileLabel> = []
        for option in profileOptions {
            guard seen.insert(option.label).inserted else {
                throw IntegratedProfileValidationError.duplicateProfileOption(option.label)
            }
            try requireIntegratedProfileNonEmpty(option.sourceReportId, "profileOptions.sourceReportId")
            try requireIntegratedProfileNonEmpty(option.costReportId, "profileOptions.costReportId")
            try requireIntegratedProfileNonEmpty(option.notes, "profileOptions.notes")
            try requireIntegratedProfileNonNegative(
                option.latencyCostMicroseconds,
                "profileOptions.latencyCostMicroseconds"
            )

            if option.label == .fastestAudio {
                if !option.features.isEmpty {
                    throw IntegratedProfileValidationError.defaultProfileHasFeatures
                }
                if option.latencyCostMicroseconds != 0 {
                    throw IntegratedProfileValidationError.defaultProfileHasLatencyCost(
                        option.latencyCostMicroseconds
                    )
                }
            } else if option.features.isEmpty {
                throw IntegratedProfileValidationError.optionalProfileMissingFeatures(option.label)
            }
        }

        if let promoted = profileOptions.first(where: { $0.defaultProfile && $0.label != .fastestAudio }) {
            throw IntegratedProfileValidationError.optionalProfilePromotedToDefault(promoted.label)
        }
        guard profileOptions.first(where: { $0.label == .fastestAudio })?.defaultProfile == true else {
            throw IntegratedProfileValidationError.fastestAudioProfileMustBeDefault
        }

        for label in requiredIntegratedProfileOptions
            where !seen.contains(label) {
            throw IntegratedProfileValidationError.missingProfileOption(label)
        }
        for feature in [IntegratedProfileFeature.video, .lightingControl]
            where !profileOptions.contains(where: { $0.features.contains(feature) }) {
            throw IntegratedProfileValidationError.missingOptionalFeature(feature)
        }
    }

    private func validateSubordinateEvidence() throws {
        try requireIntegratedProfileList(subordinateEvidence, "subordinateEvidence")
        var seen: Set<IntegratedProfileSubordinateLane> = []
        for evidence in subordinateEvidence {
            guard seen.insert(evidence.lane).inserted else {
                throw IntegratedProfileValidationError.duplicateSubordinateLane(evidence.lane)
            }
            try requireIntegratedProfileNonEmpty(evidence.reportId, "subordinateEvidence.reportId")
            try requireIntegratedProfileNonEmpty(evidence.notes, "subordinateEvidence.notes")
        }
    }

    private func validateDegradationOrder() throws {
        try requireIntegratedProfileList(degradationOrder, "degradationOrder")
        var seenSteps = Set<IntegratedProfileDegradationStep>()
        for step in degradationOrder {
            guard seenSteps.insert(step).inserted else {
                throw IntegratedProfileValidationError.duplicateDegradationStep(step)
            }
        }
        guard degradationOrder.last == .increaseAudioLatency else {
            throw IntegratedProfileValidationError.audioLatencyDegradationMustBeLast
        }

        let hasVideoProfile = profileOptions.contains { $0.features.contains(.video) }
        if hasVideoProfile {
            guard degradationOrder.count >= 2,
                  degradationOrder[0] == .reduceVideoQuality,
                  degradationOrder[1] == .reduceVideoFrameRate else {
                throw IntegratedProfileValidationError.videoDegradationMustLead
            }
            guard let disableVideoIndex = degradationOrder.firstIndex(of: .disableVideo),
                  let audioIndex = degradationOrder.firstIndex(of: .increaseAudioLatency),
                  disableVideoIndex < audioIndex else {
                throw IntegratedProfileValidationError.videoDisableMustPrecedeAudioLatency
            }
        }

        let hasLightingProfile = profileOptions.contains { $0.features.contains(.lightingControl) }
        if hasLightingProfile {
            guard let lightingIndex = degradationOrder.firstIndex(of: .disableLighting),
                  let audioIndex = degradationOrder.firstIndex(of: .increaseAudioLatency),
                  lightingIndex < audioIndex else {
                throw IntegratedProfileValidationError.lightingDegradationMustPrecedeAudioLatency
            }
        }
    }

    private func validateBenchmarkMatrix() throws {
        try requireIntegratedProfileList(benchmarkMatrix, "benchmarkMatrix")
        var seen: Set<IntegratedProfileBenchmarkScenario> = []
        for row in benchmarkMatrix {
            guard seen.insert(row.scenario).inserted else {
                throw IntegratedProfileValidationError.duplicateBenchmarkScenario(row.scenario)
            }
            try requireIntegratedProfileNonEmpty(row.reportId, "benchmarkMatrix.reportId")
            try requireIntegratedProfileNonEmpty(row.notes, "benchmarkMatrix.notes")
            try validateMetrics(row.metrics, scenario: row.scenario)
        }
        for scenario in requiredIntegratedProfileBenchmarkScenarios
            where !seen.contains(scenario) {
            if verdict == .pass {
                throw IntegratedProfileValidationError.passWithoutBenchmarkScenario(scenario)
            }
            throw IntegratedProfileValidationError.missingBenchmarkScenario(scenario)
        }
    }

    private func validateMetrics(
        _ metrics: IntegratedProfileBenchmarkMetrics,
        scenario: IntegratedProfileBenchmarkScenario
    ) throws {
        try requireIntegratedProfileNonNegative(
            metrics.audioLatencyP99Microseconds,
            "benchmarkMatrix.metrics.audioLatencyP99Microseconds"
        )
        try requireIntegratedProfileNonNegative(
            metrics.audioJitterP99Microseconds,
            "benchmarkMatrix.metrics.audioJitterP99Microseconds"
        )
        try requireIntegratedProfileNonNegative(metrics.lostPackets, "benchmarkMatrix.metrics.lostPackets")
        try requireIntegratedProfileNonNegative(metrics.latePackets, "benchmarkMatrix.metrics.latePackets")
        try requireIntegratedProfileNonNegative(metrics.underruns, "benchmarkMatrix.metrics.underruns")
        try requireIntegratedProfileNonNegative(
            metrics.droppedVideoFrames,
            "benchmarkMatrix.metrics.droppedVideoFrames"
        )
        try requireIntegratedProfileNonNegative(
            metrics.cueTimingP99Microseconds,
            "benchmarkMatrix.metrics.cueTimingP99Microseconds"
        )
        try requireIntegratedProfilePercent(metrics.cpuP99Percent, "benchmarkMatrix.metrics.cpuP99Percent")
        try requireIntegratedProfileNonNegative(
            metrics.residentMemoryMegabytes,
            "benchmarkMatrix.metrics.residentMemoryMegabytes"
        )
        if let duration = metrics.measurementDurationSeconds {
            try requireIntegratedProfileNonNegative(
                duration,
                "benchmarkMatrix.metrics.measurementDurationSeconds"
            )
        }
        if metrics.durationMismatch {
            throw IntegratedProfileValidationError.benchmarkDurationMismatch(scenario)
        }
        try requireIntegratedProfileNonNegative(
            metrics.callbackDeadlineWarnings,
            "benchmarkMatrix.metrics.callbackDeadlineWarnings"
        )
        try requireIntegratedProfileNonNegative(
            metrics.allocationWarnings,
            "benchmarkMatrix.metrics.allocationWarnings"
        )
        try requireIntegratedProfileNonNegative(
            metrics.threadSchedulingWarnings,
            "benchmarkMatrix.metrics.threadSchedulingWarnings"
        )
    }

    private func validateAggregateVerdict() throws {
        let aggregate = aggregateSubordinateVerdict
        if verdict == .pass && aggregate != .pass {
            throw IntegratedProfileValidationError.aggregateVerdictMismatch(
                report: verdict,
                aggregate: aggregate
            )
        }
        if aggregate == .fail && verdict != .fail {
            throw IntegratedProfileValidationError.aggregateVerdictMismatch(
                report: verdict,
                aggregate: aggregate
            )
        }
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        guard runMode == .measured else {
            throw IntegratedProfileValidationError.passWithoutMeasuredRun
        }

        for option in profileOptions {
            try requireIntegratedProfilePassText(
                option.sourceReportId,
                field: "profileOptions.sourceReportId"
            )
            try requireIntegratedProfilePassText(
                option.costReportId,
                field: "profileOptions.costReportId"
            )
            guard option.verdict == .pass else {
                throw IntegratedProfileValidationError.passWithoutPassProfileOption(
                    option.label,
                    option.verdict
                )
            }
        }

        for lane in requiredIntegratedProfileSubordinateLanes {
            guard let evidence = subordinateEvidence.first(where: { $0.lane == lane }) else {
                throw IntegratedProfileValidationError.passWithoutPassSubordinateEvidence(lane, .partial)
            }
            try requireIntegratedProfilePassText(evidence.reportId, field: "subordinateEvidence.reportId")
            guard evidence.verdict == .pass else {
                throw IntegratedProfileValidationError.passWithoutPassSubordinateEvidence(
                    lane,
                    evidence.verdict
                )
            }
            guard evidence.measured else {
                throw IntegratedProfileValidationError.passWithoutMeasuredSubordinateEvidence(lane)
            }
            guard evidence.physicalPassEvidence else {
                throw IntegratedProfileValidationError.passWithoutPhysicalSubordinateEvidence(lane)
            }
        }

        for scenario in requiredIntegratedProfileBenchmarkScenarios {
            guard let row = benchmarkMatrix.first(where: { $0.scenario == scenario }) else {
                throw IntegratedProfileValidationError.passWithoutBenchmarkScenario(scenario)
            }
            try requireIntegratedProfilePassText(row.reportId, field: "benchmarkMatrix.reportId")
            guard row.verdict == .pass else {
                throw IntegratedProfileValidationError.passWithoutPassBenchmarkScenario(scenario, row.verdict)
            }
            guard row.measured else {
                throw IntegratedProfileValidationError.passWithoutMeasuredBenchmarkScenario(scenario)
            }
            guard row.physicalEvidence else {
                throw IntegratedProfileValidationError.passWithoutPhysicalBenchmarkScenario(scenario)
            }
        }

        try validatePassProfileLatencyCosts()
    }

    private func validatePassProfileLatencyCosts() throws {
        let audioOnly = try benchmarkRow(for: .audioOnly)
        for (profile, scenario) in integratedProfileCostScenarios {
            let option = try profileOption(for: profile)
            let row = try benchmarkRow(for: scenario)
            let observed = row.metrics.audioLatencyP99Microseconds
                - audioOnly.metrics.audioLatencyP99Microseconds
            if observed < 0 {
                throw IntegratedProfileValidationError.passProfileLatencyBelowAudioOnly(
                    profile: profile,
                    observedMicroseconds: observed
                )
            }
            if option.latencyCostMicroseconds < observed {
                throw IntegratedProfileValidationError.passUnderreportsProfileLatencyCost(
                    profile: profile,
                    reportedMicroseconds: option.latencyCostMicroseconds,
                    observedMicroseconds: observed
                )
            }
        }
    }

    private func profileOption(for label: IntegratedProfileLabel) throws -> IntegratedProfileOption {
        guard let option = profileOptions.first(where: { $0.label == label }) else {
            throw IntegratedProfileValidationError.missingProfileOption(label)
        }
        return option
    }

    private func benchmarkRow(
        for scenario: IntegratedProfileBenchmarkScenario
    ) throws -> IntegratedProfileBenchmarkRow {
        guard let row = benchmarkMatrix.first(where: { $0.scenario == scenario }) else {
            throw IntegratedProfileValidationError.missingBenchmarkScenario(scenario)
        }
        return row
    }
}


private let requiredIntegratedProfileOptions: [IntegratedProfileLabel] = [
    .fastestAudio,
    .audioVideo,
    .audioLighting,
    .audioVideoLighting,
]

private let requiredIntegratedProfileSubordinateLanes: [IntegratedProfileSubordinateLane] = [
    .fastestAudio,
    .audioRoute,
    .videoCapture,
    .videoTransport,
    .integratedAv,
    .lightingControl,
]

private let requiredIntegratedProfileBenchmarkScenarios: [IntegratedProfileBenchmarkScenario] = [
    .audioOnly,
    .audioVideo,
    .audioControl,
    .audioVideoControl,
]

private let integratedProfileCostScenarios: [
    (IntegratedProfileLabel, IntegratedProfileBenchmarkScenario)
] = [
    (.audioVideo, .audioVideo),
    (.audioLighting, .audioControl),
    (.audioVideoLighting, .audioVideoControl),
]

private func aggregateIntegratedProfileVerdicts(_ verdicts: [MeasurementVerdict]) -> MeasurementVerdict {
    if verdicts.contains(.fail) {
        return .fail
    }
    if verdicts.allSatisfy({ $0 == .pass }) {
        return .pass
    }
    return .partial
}

private func requireIntegratedProfileNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw IntegratedProfileValidationError.emptyField(field)
    }
}

private func requireIntegratedProfilePassText(_ value: String, field: String) throws {
    try requireIntegratedProfileNonEmpty(value, field)
    if isIntegratedProfilePlaceholder(value) {
        throw IntegratedProfileValidationError.passWithPlaceholderEvidenceField(field)
    }
}

private func requireIntegratedProfileList<T>(_ value: [T], _ field: String) throws {
    if value.isEmpty {
        throw IntegratedProfileValidationError.emptyList(field)
    }
}

private func requireIntegratedProfileNonNegative(_ value: Int, _ field: String) throws {
    if value < 0 {
        throw IntegratedProfileValidationError.negativeField(field)
    }
}

private func requireIntegratedProfileNonNegative(_ value: Double, _ field: String) throws {
    if !value.isFinite {
        throw IntegratedProfileValidationError.nonFiniteField(field)
    }
    if value < 0 {
        throw IntegratedProfileValidationError.negativeField(field)
    }
}

private func requireIntegratedProfilePercent(_ value: Double, _ field: String) throws {
    if !value.isFinite {
        throw IntegratedProfileValidationError.nonFiniteField(field)
    }
    if value < 0 || value > 100 {
        throw IntegratedProfileValidationError.percentOutOfRange(field: field, value: value)
    }
}


private func isIntegratedProfilePlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: ["todo(human)", "placeholder", "fixture", "synthetic", "required", "not-measured"],
        exactly: ["unknown", "tbd"]
    )
}
