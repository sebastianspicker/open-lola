// Centralizes lighting protocols, network restrictions, gate states, and block reasons so output authorization remains fail-closed.
import Foundation

/// Defines the LightingControlProtocol contract used to negotiate behavior across read-only control integration.
public enum LightingControlProtocol: String, Codable, Equatable, Sendable {
    case sacn
    case artNet

    public var defaultPort: Int {
        switch self {
        case .sacn:
            5_568
        case .artNet:
            6_454
        }
    }
}

/// Records the current standards-review status for a lighting interoperability target.
public enum LightingStandardsReviewStatus: String, Codable, Equatable, Sendable {
    case reviewed
    case pending
    case blocked
}

/// Identifies the lighting protocol or fixture family evaluated by the readiness gate.
public enum LightingInteropTarget: String, Codable, Equatable, Sendable {
    case none
    case ola
    case qlcPlus
}

/// Provides the LightingCueTransport boundary that isolates I/O lifetime from read-only control integration policy.
public enum LightingCueTransport: String, Codable, Equatable, Sendable {
    case oscPeerToPeer
}

/// Captures LightingCueWorkflowEvidence evidence in a stable form for validation and serialized reporting.
public struct LightingCueWorkflowEvidence: Codable, Equatable, Sendable {
    public var cueTransport: LightingCueTransport
    public var oscCueReportId: String
    public var firstPeerKind: OscCuePeerKind
    public var localFixtureOwner: LightingInteropTarget
    public var directFixtureStreamingOnPerformanceLink: Bool
    public var notes: String

    public init(
        cueTransport: LightingCueTransport,
        oscCueReportId: String,
        firstPeerKind: OscCuePeerKind,
        localFixtureOwner: LightingInteropTarget,
        directFixtureStreamingOnPerformanceLink: Bool,
        notes: String
    ) {
        self.cueTransport = cueTransport
        self.oscCueReportId = oscCueReportId
        self.firstPeerKind = firstPeerKind
        self.localFixtureOwner = localFixtureOwner
        self.directFixtureStreamingOnPerformanceLink = directFixtureStreamingOnPerformanceLink
        self.notes = notes
    }
}

/// Selects the network transport mode expected by the lighting readiness check.
public enum LightingNetworkMode: String, Codable, Equatable, Sendable {
    case loopbackUnicast
    case isolatedUnicast
    case isolatedMulticast
    case directedBroadcast
    case limitedBroadcast
    case campusNetwork

    public var isBroadcast: Bool {
        self == .directedBroadcast || self == .limitedBroadcast
    }

    public var isMulticast: Bool {
        self == .isolatedMulticast
    }

    public var isSharedOrUnbounded: Bool {
        self == .campusNetwork || self == .limitedBroadcast
    }
}

/// Records whether the lighting gate is ready, blocked, or awaiting evidence.
public enum LightingGateState: String, Codable, Equatable, Sendable {
    case disabled
    case armed
    case output
    case hold
    case blackout
    case drop
}

/// Classifies why lighting readiness cannot yet be promoted.
public enum LightingGateBlockReason: String, Codable, Equatable, Sendable {
    case standardsNotReviewed
    case networkNotIsolated
    case outputNotArmed
    case universeNotAllowed
    case broadcastNotAllowed
    case multicastNotAllowed
    case requestNotAllowed
    case failurePolicyIncomplete
}

/// Captures LightingProtocolStandardEvidence evidence in a stable form for validation and serialized reporting.
public struct LightingProtocolStandardEvidence: Codable, Equatable, Sendable {
    public var protocolName: LightingControlProtocol
    public var document: String
    public var status: LightingStandardsReviewStatus
    public var sourceURL: String
    public var licenseDisposition: String

    public init(
        protocolName: LightingControlProtocol,
        document: String,
        status: LightingStandardsReviewStatus,
        sourceURL: String,
        licenseDisposition: String
    ) {
        self.protocolName = protocolName
        self.document = document
        self.status = status
        self.sourceURL = sourceURL
        self.licenseDisposition = licenseDisposition
    }
}

/// Configures LightingOutputRequest so callers supply explicit inputs before starting read-only control integration.
public struct LightingOutputRequest: Codable, Equatable, Sendable {
    public var protocolName: LightingControlProtocol
    public var universe: Int
    public var networkMode: LightingNetworkMode
    public var destinationAddress: String
    public var port: Int

    public init(
        protocolName: LightingControlProtocol,
        universe: Int,
        networkMode: LightingNetworkMode,
        destinationAddress: String,
        port: Int
    ) {
        self.protocolName = protocolName
        self.universe = universe
        self.networkMode = networkMode
        self.destinationAddress = destinationAddress
        self.port = port
    }
}

/// Defines LightingUniversePolicy acceptance rules so callers receive deterministic pass or failure evidence.
public struct LightingUniversePolicy: Codable, Equatable, Sendable {
    public var protocolName: LightingControlProtocol
    public var universe: Int
    public var networkMode: LightingNetworkMode
    public var destinationAddress: String
    public var port: Int
    public var maxRefreshRateHertz: Double
    public var fullUniverseOutput: Bool

    public init(
        protocolName: LightingControlProtocol,
        universe: Int,
        networkMode: LightingNetworkMode,
        destinationAddress: String,
        port: Int,
        maxRefreshRateHertz: Double,
        fullUniverseOutput: Bool
    ) {
        self.protocolName = protocolName
        self.universe = universe
        self.networkMode = networkMode
        self.destinationAddress = destinationAddress
        self.port = port
        self.maxRefreshRateHertz = maxRefreshRateHertz
        self.fullUniverseOutput = fullUniverseOutput
    }

    public func allows(_ request: LightingOutputRequest) -> Bool {
        protocolName == request.protocolName
            && universe == request.universe
            && networkMode == request.networkMode
            && destinationAddress == request.destinationAddress
            && port == request.port
    }
}

/// Defines LightingFailurePolicy acceptance rules so callers receive deterministic pass or failure evidence.
public struct LightingFailurePolicy: Codable, Equatable, Sendable {
    public var holdOnPeerLoss: Bool
    public var blackoutOnOperatorTrigger: Bool
    public var dropOnAudioImpact: Bool
    public var disableOnPeerLoss: Bool
    public var notes: String

    public init(
        holdOnPeerLoss: Bool,
        blackoutOnOperatorTrigger: Bool,
        dropOnAudioImpact: Bool,
        disableOnPeerLoss: Bool,
        notes: String
    ) {
        self.holdOnPeerLoss = holdOnPeerLoss
        self.blackoutOnOperatorTrigger = blackoutOnOperatorTrigger
        self.dropOnAudioImpact = dropOnAudioImpact
        self.disableOnPeerLoss = disableOnPeerLoss
        self.notes = notes
    }

    public var isComplete: Bool {
        holdOnPeerLoss && blackoutOnOperatorTrigger && dropOnAudioImpact && disableOnPeerLoss
    }
}

/// Represents LightingGateDecision values used by read-only control integration.
public struct LightingGateDecision: Codable, Equatable, Sendable {
    public var state: LightingGateState
    public var canTransmit: Bool
    public var reason: LightingGateBlockReason?
    public var reasons: [LightingGateBlockReason]

    public init(
        state: LightingGateState,
        canTransmit: Bool,
        reason: LightingGateBlockReason?,
        reasons: [LightingGateBlockReason]? = nil
    ) {
        self.state = state
        self.canTransmit = canTransmit
        self.reason = reason
        self.reasons = reasons ?? reason.map { [$0] } ?? []
    }
}

/// Defines LightingSafetyPolicy acceptance rules so callers receive deterministic pass or failure evidence.
public struct LightingSafetyPolicy: Codable, Equatable, Sendable {
    public var standardsReviewed: Bool
    public var isolatedNetworkVerified: Bool
    public var explicitArmRequired: Bool
    public var explicitlyArmed: Bool
    public var broadcastAllowed: Bool
    public var multicastAllowed: Bool
    public var allowedUniverses: [LightingUniversePolicy]
    public var failurePolicy: LightingFailurePolicy

    public init(
        standardsReviewed: Bool,
        isolatedNetworkVerified: Bool,
        explicitArmRequired: Bool,
        explicitlyArmed: Bool,
        broadcastAllowed: Bool,
        multicastAllowed: Bool,
        allowedUniverses: [LightingUniversePolicy],
        failurePolicy: LightingFailurePolicy
    ) {
        self.standardsReviewed = standardsReviewed
        self.isolatedNetworkVerified = isolatedNetworkVerified
        self.explicitArmRequired = explicitArmRequired
        self.explicitlyArmed = explicitlyArmed
        self.broadcastAllowed = broadcastAllowed
        self.multicastAllowed = multicastAllowed
        self.allowedUniverses = allowedUniverses
        self.failurePolicy = failurePolicy
    }

    public func decision(for request: LightingOutputRequest) -> LightingGateDecision {
        let reasons = blockReasons(for: request)
        if !reasons.isEmpty {
            return blocked(reasons)
        }

        return LightingGateDecision(state: .output, canTransmit: true, reason: nil)
    }

    private func blockReasons(for request: LightingOutputRequest) -> [LightingGateBlockReason] {
        let checks: [(blocked: Bool, reason: LightingGateBlockReason)] = [
            (!standardsReviewed, .standardsNotReviewed),
            (!isolatedNetworkVerified, .networkNotIsolated),
            (request.networkMode.isSharedOrUnbounded, .networkNotIsolated),
            (outputNotArmed, .outputNotArmed),
            (!failurePolicy.isComplete, .failurePolicyIncomplete),
            (!hasAllowedUniverse(for: request), .universeNotAllowed),
            (broadcastBlocked(for: request), .broadcastNotAllowed),
            (multicastBlocked(for: request), .multicastNotAllowed),
            (!hasAllowedRequest(request), .requestNotAllowed)
        ]
        return checks.reduce(into: []) { reasons, check in
            guard check.blocked else { return }
            appendLightingGateBlockReason(check.reason, to: &reasons)
        }
    }

    private var outputNotArmed: Bool {
        explicitArmRequired && !explicitlyArmed
    }

    private func hasAllowedUniverse(for request: LightingOutputRequest) -> Bool {
        allowedUniverses.contains {
            $0.protocolName == request.protocolName && $0.universe == request.universe
        }
    }

    private func broadcastBlocked(for request: LightingOutputRequest) -> Bool {
        request.networkMode.isBroadcast && !broadcastAllowed
    }

    private func multicastBlocked(for request: LightingOutputRequest) -> Bool {
        request.networkMode.isMulticast && !multicastAllowed
    }

    private func hasAllowedRequest(_ request: LightingOutputRequest) -> Bool {
        allowedUniverses.contains { $0.allows(request) }
    }

    private func blocked(_ reason: LightingGateBlockReason) -> LightingGateDecision {
        LightingGateDecision(state: lightingGateState(for: reason), canTransmit: false, reason: reason)
    }

    private func blocked(_ reasons: [LightingGateBlockReason]) -> LightingGateDecision {
        let primaryReason = reasons.first
        return LightingGateDecision(
            state: primaryReason.map(lightingGateState(for:)) ?? .disabled,
            canTransmit: false,
            reason: primaryReason,
            reasons: reasons
        )
    }
}

private func appendLightingGateBlockReason(
    _ reason: LightingGateBlockReason,
    to reasons: inout [LightingGateBlockReason]
) {
    if !reasons.contains(reason) {
        reasons.append(reason)
    }
}

private func lightingGateState(for reason: LightingGateBlockReason) -> LightingGateState {
    switch reason {
    case .standardsNotReviewed:
        .disabled
    case .outputNotArmed:
        .hold
    case .failurePolicyIncomplete:
        .blackout
    case .networkNotIsolated,
         .universeNotAllowed,
         .broadcastNotAllowed,
         .multicastNotAllowed,
         .requestNotAllowed:
        .drop
    }
}
