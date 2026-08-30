// Validates SessionLatencyProfilePolicy acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

/// Defines the validated fields for session latency profile policy.
public struct SessionLatencyProfilePolicy: Codable, Equatable, Sendable {
    public var profile: SessionLatencyProfile
    public var defaultRxBufferProfile: RxBufferProfile
    public var allowedRxBufferProfiles: [RxBufferProfile]
    public var maximumEnabledVideoStreams: Int
    public var requiresEnabledVideo: Bool
    public var fastestAudioPassEligible: Bool
    public var benchmarkEvidenceRequired: Bool
    public var videoPressurePolicy: SessionVideoPressurePolicy
    public var continuityPriority: SessionContinuityPriority

    public static func policy(for profile: SessionLatencyProfile) -> SessionLatencyProfilePolicy {
        let policy = switch profile {
        case .directAudioFirst:
            directAudioFirstPolicy()
        case .balancedAV:
            balancedAVPolicy()
        case .multiVideoPerformance:
            multiVideoPerformancePolicy()
        case .wanStable:
            wanStablePolicy()
        }
        precondition(
            policy.allowedRxBufferProfiles.contains(policy.defaultRxBufferProfile),
            "SessionLatencyProfilePolicy default RX buffer must be allowed"
        )
        return policy
    }

    private static func directAudioFirstPolicy() -> SessionLatencyProfilePolicy {
        SessionLatencyProfilePolicy(
            profile: .directAudioFirst,
            defaultRxBufferProfile: .direct,
            allowedRxBufferProfiles: [.direct],
            maximumEnabledVideoStreams: 1,
            requiresEnabledVideo: false,
            fastestAudioPassEligible: true,
            benchmarkEvidenceRequired: false,
            videoPressurePolicy: .dropVideoBeforeAudioLatency,
            continuityPriority: .latencyFirst
        )
    }

    private static func balancedAVPolicy() -> SessionLatencyProfilePolicy {
        SessionLatencyProfilePolicy(
            profile: .balancedAV,
            defaultRxBufferProfile: .small,
            allowedRxBufferProfiles: [.small],
            maximumEnabledVideoStreams: 1,
            requiresEnabledVideo: false,
            fastestAudioPassEligible: false,
            benchmarkEvidenceRequired: true,
            videoPressurePolicy: .singleStreamPaced,
            continuityPriority: .balanced
        )
    }

    private static func multiVideoPerformancePolicy() -> SessionLatencyProfilePolicy {
        SessionLatencyProfilePolicy(
            profile: .multiVideoPerformance,
            defaultRxBufferProfile: .adaptive,
            allowedRxBufferProfiles: [.small, .adaptive],
            maximumEnabledVideoStreams: 4,
            requiresEnabledVideo: true,
            fastestAudioPassEligible: false,
            benchmarkEvidenceRequired: true,
            videoPressurePolicy: .dropVideoBeforeAudioLatency,
            continuityPriority: .balanced
        )
    }

    private static func wanStablePolicy() -> SessionLatencyProfilePolicy {
        SessionLatencyProfilePolicy(
            profile: .wanStable,
            defaultRxBufferProfile: .stableWan,
            allowedRxBufferProfiles: [.stableWan],
            maximumEnabledVideoStreams: 1,
            requiresEnabledVideo: false,
            fastestAudioPassEligible: false,
            benchmarkEvidenceRequired: true,
            videoPressurePolicy: .continuityFirstVideo,
            continuityPriority: .continuityFirst
        )
    }
}
