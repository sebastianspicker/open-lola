// Enforces latency profile budgets, selection warnings, and direct-route rules before a session converts policy into transport settings.
import Foundation

/// Defines `ultraLowLatencyRequiresPhysicalRmeDirectRoute`, `extremeLowLatencyDropoutRisk`, `physicalLongRunEvidenceMissing`, and `maxStableChannelCountMissing` states used to make latency profile warning decisions in timing and drift control.
public enum LatencyProfileWarning: String, Codable, Equatable, Sendable {
// swiftlint:disable:next identifier_name
case ultraLowLatencyRequiresPhysicalRmeDirectRoute
    case extremeLowLatencyDropoutRisk
    case physicalLongRunEvidenceMissing
    case maxStableChannelCountMissing
}

/// Reports invalid timing inputs, unsupported profiles, missing opt-in, and unmet physical-evidence gates.
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

/// Constrains `profile`, `primaryFrames`, `fallbackFrames`, and `defaultRxBufferProfile` so timing and drift control tradeoffs remain explicit and testable.
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

/// Sets `profile`, `framesPerBuffer`, `sampleRateHertz`, and `channelCount` as the latency envelope a selected profile must satisfy.
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

/// Carries `profile`, `sampleRateHertz`, `framesPerBuffer`, and `channelCount` selected by the caller for a planned timing and drift control operation.
public struct LatencyProfileSelectionRequest: Codable, Equatable, Sendable {
    public struct OptIns: Equatable, Sendable {
        public var explicitProfile: Bool
        public var experimentalMode: Bool
        public var warningAcknowledged: Bool

        public init(
            explicitProfile: Bool,
            experimentalMode: Bool = false,
            warningAcknowledged: Bool = false
        ) {
            self.explicitProfile = explicitProfile
            self.experimentalMode = experimentalMode
            self.warningAcknowledged = warningAcknowledged
        }
    }

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
        optIns: OptIns
    ) {
        self.profile = profile
        self.sampleRateHertz = sampleRateHertz
        self.framesPerBuffer = framesPerBuffer
        self.channelCount = channelCount
        self.sampleFormat = sampleFormat
        self.rxBufferProfile = rxBufferProfile
        explicitOptIn = optIns.explicitProfile
        experimentalOptIn = optIns.experimentalMode
        warningAcknowledged = optIns.warningAcknowledged
    }
}

/// Commits `profile`, `framesPerBuffer`, `rxBufferProfile`, and `budget` as the selected latency and receive-buffer operating point.
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
        try validateFrameSelection(request: request, policy: policy)
        try validateOptIns(request: request, policy: policy)
        let rxBufferProfile = try validatedRxBufferProfile(request: request, policy: policy)
        try validateDeviceSupport(request: request, device: device)
        try validateRouteSupport(request: request, route: route)

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

    private static func validateFrameSelection(
        request: LatencyProfileSelectionRequest,
        policy: LatencyProfilePolicy
    ) throws {
        guard request.framesPerBuffer == policy.primaryFrames
            || policy.fallbackFrames.contains(request.framesPerBuffer) else {
            throw LatencyProfileValidationError.unsupportedFrameSize(
                profile: request.profile,
                expected: policy.primaryFrames,
                actual: request.framesPerBuffer
            )
        }
    }

    private static func validateOptIns(
        request: LatencyProfileSelectionRequest,
        policy: LatencyProfilePolicy
    ) throws {
        if policy.requiresExplicitOptIn, !request.explicitOptIn {
            throw LatencyProfileValidationError.missingExplicitOptIn(request.profile)
        }
        if policy.requiresExperimentalOptIn, !request.experimentalOptIn {
            throw LatencyProfileValidationError.missingExperimentalOptIn(request.profile)
        }
        if policy.warning != nil, !request.warningAcknowledged {
            throw LatencyProfileValidationError.missingWarningAcknowledgement(request.profile)
        }
    }

    private static func validatedRxBufferProfile(
        request: LatencyProfileSelectionRequest,
        policy: LatencyProfilePolicy
    ) throws -> RxBufferProfile {
        let rxBufferProfile = request.rxBufferProfile ?? policy.defaultRxBufferProfile
        guard policy.allowedRxBufferProfiles.contains(rxBufferProfile) else {
            throw LatencyProfileValidationError.unsupportedRxBufferProfile(
                profile: request.profile,
                rxBufferProfile: rxBufferProfile
            )
        }
        return rxBufferProfile
    }

    private static func validateDeviceSupport(
        request: LatencyProfileSelectionRequest,
        device: CoreAudioDeviceInventory?
    ) throws {
        guard let device else {
            return
        }
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

    private static func validateRouteSupport(
        request: LatencyProfileSelectionRequest,
        route: RouteIdentity?
    ) throws {
        if let route, request.profile != .safeLowLatency, !isDirectRoute(route) {
            throw LatencyProfileValidationError.directRouteRequired(request.profile)
        }
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

func requireLatencyProfilePositive(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw LatencyProfileValidationError.nonPositiveField(field)
    }
}
