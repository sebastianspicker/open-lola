import Foundation

public enum LatencyProfileWarning: String, Codable, Equatable, Sendable {
    case ultraLowLatencyRequiresPhysicalRmeDirectRoute
    case extremeLowLatencyDropoutRisk
    case physicalLongRunEvidenceMissing
    case maxStableChannelCountMissing
}

public enum LatencyProfileValidationError: Error, Equatable, Sendable {
    case nonPositiveField(String)
    case unsupportedFrameSize(profile: LatencyProfile, expected: Int, actual: Int)
    case unsupportedSampleFormat(String)
    case unsupportedHardwareFrameSize(profile: LatencyProfile, framesPerBuffer: Int)
    case unsupportedSampleRate(profile: LatencyProfile, sampleRateHertz: Int)
    case unsupportedRxBufferProfile(profile: LatencyProfile, rxBufferProfile: RxBufferProfile)
    case missingExplicitOptIn(LatencyProfile)
    case missingExperimentalOptIn(LatencyProfile)
    case missingWarningAcknowledgement(LatencyProfile)
    case rmeDirectHardwareRequired(LatencyProfile)
    case directRouteRequired(LatencyProfile)
    case evidenceProfileMismatch(expected: LatencyProfile, actual: LatencyProfile)
    case evidenceBudgetMismatch(expectedFrames: Int, actualFrames: Int)
    case invalidRollbackProfile(profile: LatencyProfile, rollback: LatencyProfile)
    case physicalRmeDirectEvidenceRequired(LatencyProfile)
    case routeBenchmarkRequired(LatencyProfile)
    case maxStableChannelCountRequired(LatencyProfile)
    case maxStableChannelCountTooSmall(profile: LatencyProfile, stable: Int, requested: Int)
    case longRunEvidenceRequired(profile: LatencyProfile, seconds: Int?, minimumSeconds: Int)
}

public struct LatencyProfilePolicy: Codable, Equatable, Sendable {
    public var profile: LatencyProfile
    public var primaryFrames: Int
    public var fallbackFrames: [Int]
    public var defaultRxBufferProfile: RxBufferProfile
    public var allowedRxBufferProfiles: [RxBufferProfile]
    public var requiresExplicitOptIn: Bool
    public var requiresExperimentalOptIn: Bool
    public var hiddenByDefault: Bool
    public var warning: LatencyProfileWarning?
    public var rollbackProfiles: [LatencyProfile]

    public static func policy(for profile: LatencyProfile) -> LatencyProfilePolicy {
        switch profile {
        case .safeLowLatency:
            LatencyProfilePolicy(
                profile: profile,
                primaryFrames: 32,
                fallbackFrames: [64],
                defaultRxBufferProfile: .direct,
                allowedRxBufferProfiles: [.direct, .small],
                requiresExplicitOptIn: false,
                requiresExperimentalOptIn: false,
                hiddenByDefault: false,
                warning: nil,
                rollbackProfiles: []
            )
        case .ultraLowLatency16:
            LatencyProfilePolicy(
                profile: profile,
                primaryFrames: 16,
                fallbackFrames: [],
                defaultRxBufferProfile: .direct,
                allowedRxBufferProfiles: [.direct, .small],
                requiresExplicitOptIn: true,
                requiresExperimentalOptIn: false,
                hiddenByDefault: false,
                warning: .ultraLowLatencyRequiresPhysicalRmeDirectRoute,
                rollbackProfiles: [.safeLowLatency]
            )
        case .extremeLowLatency8:
            LatencyProfilePolicy(
                profile: profile,
                primaryFrames: 8,
                fallbackFrames: [],
                defaultRxBufferProfile: .direct,
                allowedRxBufferProfiles: [.direct],
                requiresExplicitOptIn: true,
                requiresExperimentalOptIn: true,
                hiddenByDefault: true,
                warning: .extremeLowLatencyDropoutRisk,
                rollbackProfiles: [.ultraLowLatency16, .safeLowLatency]
            )
        }
    }

    public static func profile(forFramesPerBuffer framesPerBuffer: Int) -> LatencyProfile? {
        switch framesPerBuffer {
        case 8:
            .extremeLowLatency8
        case 16:
            .ultraLowLatency16
        case 32, 64:
            .safeLowLatency
        default:
            nil
        }
    }
}

public struct LatencyProfileBudget: Codable, Equatable, Sendable {
    public var profile: LatencyProfile
    public var framesPerBuffer: Int
    public var sampleRateHertz: Int
    public var channelCount: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var blockDurationMicroseconds: Double
    public var packetsPerSecond: Double
    public var audioPayloadBytesPerPacket: Int
    public var audioPayloadBytesPerSecond: Double
    public var defaultRxBufferProfile: RxBufferProfile
    public var defaultRxLatencyMicroseconds: Double

    public static func calculate(
        profile: LatencyProfile,
        sampleRateHertz: Int,
        channelCount: Int,
        sampleFormat: UdpPcmSampleFormat,
        framesPerBuffer: Int? = nil
    ) throws -> LatencyProfileBudget {
        try requireLatencyProfilePositive(sampleRateHertz, "sampleRateHertz")
        try requireLatencyProfilePositive(channelCount, "channelCount")
        let policy = LatencyProfilePolicy.policy(for: profile)
        let frames = framesPerBuffer ?? policy.primaryFrames
        try requireLatencyProfilePositive(frames, "framesPerBuffer")
        guard frames == policy.primaryFrames || policy.fallbackFrames.contains(frames) else {
            throw LatencyProfileValidationError.unsupportedFrameSize(
                profile: profile,
                expected: policy.primaryFrames,
                actual: frames
            )
        }
        let blockDuration = RxBufferPolicy.microseconds(
            frames: frames,
            sampleRateHertz: sampleRateHertz
        )
        let payloadBytes = frames * channelCount * sampleFormat.bytesPerSample
        return LatencyProfileBudget(
            profile: profile,
            framesPerBuffer: frames,
            sampleRateHertz: sampleRateHertz,
            channelCount: channelCount,
            sampleFormat: sampleFormat,
            blockDurationMicroseconds: blockDuration,
            packetsPerSecond: Double(sampleRateHertz) / Double(frames),
            audioPayloadBytesPerPacket: payloadBytes,
            audioPayloadBytesPerSecond: Double(payloadBytes)
                * (Double(sampleRateHertz) / Double(frames)),
            defaultRxBufferProfile: policy.defaultRxBufferProfile,
            defaultRxLatencyMicroseconds: blockDuration
        )
    }
}

public struct LatencyProfileSelectionRequest: Codable, Equatable, Sendable {
    public var profile: LatencyProfile
    public var sampleRateHertz: Int
    public var framesPerBuffer: Int
    public var channelCount: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var rxBufferProfile: RxBufferProfile?
    public var explicitOptIn: Bool
    public var experimentalOptIn: Bool
    public var warningAcknowledged: Bool

    public init(
        profile: LatencyProfile,
        sampleRateHertz: Int,
        framesPerBuffer: Int,
        channelCount: Int,
        sampleFormat: UdpPcmSampleFormat,
        rxBufferProfile: RxBufferProfile?,
        explicitOptIn: Bool,
        experimentalOptIn: Bool,
        warningAcknowledged: Bool
    ) {
        self.profile = profile
        self.sampleRateHertz = sampleRateHertz
        self.framesPerBuffer = framesPerBuffer
        self.channelCount = channelCount
        self.sampleFormat = sampleFormat
        self.rxBufferProfile = rxBufferProfile
        self.explicitOptIn = explicitOptIn
        self.experimentalOptIn = experimentalOptIn
        self.warningAcknowledged = warningAcknowledged
    }
}

public struct LatencyProfileSelection: Codable, Equatable, Sendable {
    public var profile: LatencyProfile
    public var framesPerBuffer: Int
    public var rxBufferProfile: RxBufferProfile
    public var budget: LatencyProfileBudget
    public var warnings: [LatencyProfileWarning]
    public var verdict: MeasurementVerdict

    public static func validate(
        request: LatencyProfileSelectionRequest,
        device: CoreAudioDeviceInventory?,
        route: RouteIdentity?
    ) throws -> LatencyProfileSelection {
        try validateRequestShape(request)
        let policy = LatencyProfilePolicy.policy(for: request.profile)
        guard request.framesPerBuffer == policy.primaryFrames
            || policy.fallbackFrames.contains(request.framesPerBuffer) else {
            throw LatencyProfileValidationError.unsupportedFrameSize(
                profile: request.profile,
                expected: policy.primaryFrames,
                actual: request.framesPerBuffer
            )
        }
        if policy.requiresExplicitOptIn, !request.explicitOptIn {
            throw LatencyProfileValidationError.missingExplicitOptIn(request.profile)
        }
        if policy.requiresExperimentalOptIn, !request.experimentalOptIn {
            throw LatencyProfileValidationError.missingExperimentalOptIn(request.profile)
        }
        if policy.warning != nil, !request.warningAcknowledged {
            throw LatencyProfileValidationError.missingWarningAcknowledgement(request.profile)
        }
        let rxBufferProfile = request.rxBufferProfile ?? policy.defaultRxBufferProfile
        guard policy.allowedRxBufferProfiles.contains(rxBufferProfile) else {
            throw LatencyProfileValidationError.unsupportedRxBufferProfile(
                profile: request.profile,
                rxBufferProfile: rxBufferProfile
            )
        }
        if let device {
            guard supportsSampleRate(device, request.sampleRateHertz) else {
                throw LatencyProfileValidationError.unsupportedSampleRate(
                    profile: request.profile,
                    sampleRateHertz: request.sampleRateHertz
                )
            }
            guard device.candidateBufferFrames.inReportedRange.contains(request.framesPerBuffer) else {
                throw LatencyProfileValidationError.unsupportedHardwareFrameSize(
                    profile: request.profile,
                    framesPerBuffer: request.framesPerBuffer
                )
            }
            if request.profile != .safeLowLatency, !isAudioLoopbackRmeMadiDevice(device) {
                throw LatencyProfileValidationError.rmeDirectHardwareRequired(request.profile)
            }
        }
        if let route, request.profile != .safeLowLatency, !isDirectRoute(route) {
            throw LatencyProfileValidationError.directRouteRequired(request.profile)
        }

        var warnings = [LatencyProfileWarning]()
        if let warning = policy.warning {
            warnings.append(warning)
        }
        return LatencyProfileSelection(
            profile: request.profile,
            framesPerBuffer: request.framesPerBuffer,
            rxBufferProfile: rxBufferProfile,
            budget: try .calculate(
                profile: request.profile,
                sampleRateHertz: request.sampleRateHertz,
                channelCount: request.channelCount,
                sampleFormat: request.sampleFormat,
                framesPerBuffer: request.framesPerBuffer
            ),
            warnings: warnings,
            verdict: .partial
        )
    }

    private static func validateRequestShape(_ request: LatencyProfileSelectionRequest) throws {
        try requireLatencyProfilePositive(request.sampleRateHertz, "sampleRateHertz")
        try requireLatencyProfilePositive(request.framesPerBuffer, "framesPerBuffer")
        try requireLatencyProfilePositive(request.channelCount, "channelCount")
    }
}

public struct LatencyProfileEvidence: PrettyJSONCodable, Equatable, Sendable {
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
        profile: LatencyProfile,
        explicitOptIn: Bool,
        experimentalOptIn: Bool,
        warningAcknowledged: Bool,
        rmeDirectPhysicalEvidence: Bool,
        routeBenchmarkPassed: Bool,
        maxStableChannelCount: Int?,
        longRunDurationSeconds: Int?,
        rollbackProfile: LatencyProfile,
        budget: LatencyProfileBudget
    ) throws {
        self.profile = profile
        self.explicitOptIn = explicitOptIn
        self.experimentalOptIn = experimentalOptIn
        self.warningAcknowledged = warningAcknowledged
        self.rmeDirectPhysicalEvidence = rmeDirectPhysicalEvidence
        self.routeBenchmarkPassed = routeBenchmarkPassed
        self.maxStableChannelCount = maxStableChannelCount
        self.longRunDurationSeconds = longRunDurationSeconds
        self.rollbackProfile = rollbackProfile
        self.budget = budget
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

public enum LatencyProfileSyntheticSmoke {
    public static func run() throws -> LatencyProfileEvidence {
        try LatencyProfileEvidence(
            profile: .extremeLowLatency8,
            explicitOptIn: true,
            experimentalOptIn: true,
            warningAcknowledged: true,
            rmeDirectPhysicalEvidence: false,
            routeBenchmarkPassed: false,
            maxStableChannelCount: nil,
            longRunDurationSeconds: nil,
            rollbackProfile: .ultraLowLatency16,
            budget: .calculate(
                profile: .extremeLowLatency8,
                sampleRateHertz: 48_000,
                channelCount: 2,
                sampleFormat: .int16LittleEndian
            )
        )
    }
}

func latencyProfile(for audioMode: AudioMode) -> LatencyProfile? {
    LatencyProfilePolicy.profile(forFramesPerBuffer: audioMode.framesPerBuffer)
}

func udpSampleFormat(for audioMode: AudioMode) -> UdpPcmSampleFormat? {
    switch audioMode.sampleFormat.lowercased() {
    case "int16", "int16littleendian":
        .int16LittleEndian
    case "float32", "float32littleendian":
        .float32LittleEndian
    default:
        nil
    }
}

func isDirectRoute(_ route: RouteIdentity) -> Bool {
    let searchable = [route.label, route.topology].joined(separator: " ").lowercased()
    return searchable.contains("direct") || searchable.contains("loopback")
}

private func requireLatencyProfilePositive(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw LatencyProfileValidationError.nonPositiveField(field)
    }
}
