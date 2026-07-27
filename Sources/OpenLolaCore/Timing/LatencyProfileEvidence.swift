// Packages a selected latency profile with route, benchmark, and warning evidence so configuration choices remain reviewable after the run.
import Foundation

/// Preserves `profile`, `explicitOptIn`, `experimentalOptIn`, and `warningAcknowledged` needed to distinguish measured timing and drift control behavior from configuration claims.
public struct LatencyProfileEvidence: PrettyJSONCodable, Equatable, Sendable {
    public struct Selection: Sendable {
        public let profile: LatencyProfile
        public let explicitOptIn: Bool
        public let experimentalOptIn: Bool
        public let warningAcknowledged: Bool

        public init(
            profile: LatencyProfile,
            explicitOptIn: Bool,
            experimentalOptIn: Bool,
            warningAcknowledged: Bool
        ) {
            self.profile = profile
            self.explicitOptIn = explicitOptIn
            self.experimentalOptIn = experimentalOptIn
            self.warningAcknowledged = warningAcknowledged
        }
    }

    public struct PhysicalEvidence: Sendable {
        public let rmeDirect: Bool
        public let routeBenchmarkPassed: Bool
        public let maxStableChannelCount: Int?
        public let longRunDurationSeconds: Int?

        public init(
            rmeDirect: Bool,
            routeBenchmarkPassed: Bool,
            maxStableChannelCount: Int?,
            longRunDurationSeconds: Int?
        ) {
            self.rmeDirect = rmeDirect
            self.routeBenchmarkPassed = routeBenchmarkPassed
            self.maxStableChannelCount = maxStableChannelCount
            self.longRunDurationSeconds = longRunDurationSeconds
        }
    }

    public struct Recovery: Sendable {
        public let rollbackProfile: LatencyProfile
        public let budget: LatencyProfileBudget

        public init(rollbackProfile: LatencyProfile, budget: LatencyProfileBudget) {
            self.rollbackProfile = rollbackProfile
            self.budget = budget
        }
    }

    public var profile: LatencyProfile
    public var explicitOptIn: Bool
    public var experimentalOptIn: Bool
    public var warningAcknowledged: Bool
    public var rmeDirectPhysicalEvidence: Bool
    public var routeBenchmarkPassed: Bool
    public var maxStableChannelCount: Int?
    public var longRunDurationSeconds: Int?
    public var rollbackProfile: LatencyProfile
    public var budget: LatencyProfileBudget

    public var warnings: [LatencyProfileWarning] {
        var result: [LatencyProfileWarning] = []
        if let warning = LatencyProfilePolicy.policy(for: profile).warning {
            result.append(warning)
        }
        if profile == .extremeLowLatency8,
           (longRunDurationSeconds ?? 0) < EndpointLoopbackReport.minimumExtremeLowLatencyDurationSeconds {
            result.append(.physicalLongRunEvidenceMissing)
        }
        if maxStableChannelCount == nil {
            result.append(.maxStableChannelCountMissing)
        }
        return result
    }

    public var recommendedVerdict: MeasurementVerdict {
        !rmeDirectPhysicalEvidence
            || !routeBenchmarkPassed
            || warnings.contains(.physicalLongRunEvidenceMissing)
            || warnings.contains(.maxStableChannelCountMissing) ? .partial : .pass
    }

    public init(
        selection: Selection,
        physicalEvidence: PhysicalEvidence,
        recovery: Recovery
    ) throws {
        self.profile = selection.profile
        self.explicitOptIn = selection.explicitOptIn
        self.experimentalOptIn = selection.experimentalOptIn
        self.warningAcknowledged = selection.warningAcknowledged
        self.rmeDirectPhysicalEvidence = physicalEvidence.rmeDirect
        self.routeBenchmarkPassed = physicalEvidence.routeBenchmarkPassed
        self.maxStableChannelCount = physicalEvidence.maxStableChannelCount
        self.longRunDurationSeconds = physicalEvidence.longRunDurationSeconds
        self.rollbackProfile = recovery.rollbackProfile
        self.budget = recovery.budget
        try validateShape()
    }

    public func validate(for audioMode: AudioMode, verdict: MeasurementVerdict) throws {
        guard let expectedProfile = LatencyProfilePolicy.profile(
            forFramesPerBuffer: audioMode.framesPerBuffer
        ), expectedProfile == profile else {
            throw LatencyProfileValidationError.evidenceProfileMismatch(
                expected: LatencyProfilePolicy.profile(
                    forFramesPerBuffer: audioMode.framesPerBuffer
                ) ?? .safeLowLatency,
                actual: profile
            )
        }
        guard budget.framesPerBuffer == audioMode.framesPerBuffer else {
            throw LatencyProfileValidationError.evidenceBudgetMismatch(
                expectedFrames: audioMode.framesPerBuffer,
                actualFrames: budget.framesPerBuffer
            )
        }
        try validateShape()
        if verdict == .pass {
            try validatePassEvidence(channelCount: audioMode.channelCount)
        }
    }

    private func validateShape() throws {
        let policy = LatencyProfilePolicy.policy(for: profile)
        if policy.requiresExplicitOptIn, !explicitOptIn {
            throw LatencyProfileValidationError.missingExplicitOptIn(profile)
        }
        if policy.requiresExperimentalOptIn, !experimentalOptIn {
            throw LatencyProfileValidationError.missingExperimentalOptIn(profile)
        }
        if policy.warning != nil, !warningAcknowledged {
            throw LatencyProfileValidationError.missingWarningAcknowledgement(profile)
        }
        guard policy.rollbackProfiles.contains(rollbackProfile) || policy.rollbackProfiles.isEmpty else {
            throw LatencyProfileValidationError.invalidRollbackProfile(
                profile: profile,
                rollback: rollbackProfile
            )
        }
        if let maxStableChannelCount {
            try requireLatencyProfilePositive(maxStableChannelCount, "maxStableChannelCount")
        }
        if let longRunDurationSeconds {
            try requireLatencyProfilePositive(longRunDurationSeconds, "longRunDurationSeconds")
        }
    }

    private func validatePassEvidence(channelCount: Int) throws {
        guard rmeDirectPhysicalEvidence else {
            throw LatencyProfileValidationError.physicalRmeDirectEvidenceRequired(profile)
        }
        guard routeBenchmarkPassed else {
            throw LatencyProfileValidationError.routeBenchmarkRequired(profile)
        }
        guard let maxStableChannelCount else {
            throw LatencyProfileValidationError.maxStableChannelCountRequired(profile)
        }
        guard maxStableChannelCount >= channelCount else {
            throw LatencyProfileValidationError.maxStableChannelCountTooSmall(
                profile: profile,
                stable: maxStableChannelCount,
                requested: channelCount
            )
        }
        if profile == .extremeLowLatency8 {
            let minimum = EndpointLoopbackReport.minimumExtremeLowLatencyDurationSeconds
            guard (longRunDurationSeconds ?? 0) >= minimum else {
                throw LatencyProfileValidationError.longRunEvidenceRequired(
                    profile: profile,
                    seconds: longRunDurationSeconds,
                    minimumSeconds: minimum
                )
            }
        }
    }
}
/// Exercises a deterministic timing and drift control path so regressions remain reproducible without hardware.
public enum LatencyProfileSyntheticSmoke {
    public static func run() throws -> LatencyProfileEvidence {
        try LatencyProfileEvidence(
            selection: LatencyProfileEvidence.Selection(
                profile: .extremeLowLatency8,
                explicitOptIn: true,
                experimentalOptIn: true,
                warningAcknowledged: true
            ),
            physicalEvidence: LatencyProfileEvidence.PhysicalEvidence(
                rmeDirect: false,
                routeBenchmarkPassed: false,
                maxStableChannelCount: nil,
                longRunDurationSeconds: nil
            ),
            recovery: LatencyProfileEvidence.Recovery(
                rollbackProfile: .ultraLowLatency16,
                budget: .calculate(
                    profile: .extremeLowLatency8,
                    sampleRateHertz: 48_000,
                    channelCount: 2,
                    sampleFormat: .int16LittleEndian
                )
            )
        )
    }
}
