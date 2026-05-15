import Foundation

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

public enum LightingStandardsReviewStatus: String, Codable, Equatable, Sendable {
    case reviewed
    case pending
    case blocked
}

public enum LightingInteropTarget: String, Codable, Equatable, Sendable {
    case none
    case ola
    case qlcPlus
}

public enum LightingCueTransport: String, Codable, Equatable, Sendable {
    case oscPeerToPeer
}

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

public enum LightingGateState: String, Codable, Equatable, Sendable {
    case disabled
    case armed
    case output
    case hold
    case blackout
    case drop
}

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
        var reasons: [LightingGateBlockReason] = []
        if !standardsReviewed {
            appendLightingGateBlockReason(.standardsNotReviewed, to: &reasons)
        }
        if !isolatedNetworkVerified {
            appendLightingGateBlockReason(.networkNotIsolated, to: &reasons)
        }
        if request.networkMode.isSharedOrUnbounded {
            appendLightingGateBlockReason(.networkNotIsolated, to: &reasons)
        }
        if explicitArmRequired && !explicitlyArmed {
            appendLightingGateBlockReason(.outputNotArmed, to: &reasons)
        }
        if !failurePolicy.isComplete {
            appendLightingGateBlockReason(.failurePolicyIncomplete, to: &reasons)
        }
        if !allowedUniverses.contains(where: { $0.protocolName == request.protocolName && $0.universe == request.universe }) {
            appendLightingGateBlockReason(.universeNotAllowed, to: &reasons)
        }
        if request.networkMode.isBroadcast && !broadcastAllowed {
            appendLightingGateBlockReason(.broadcastNotAllowed, to: &reasons)
        }
        if request.networkMode.isMulticast && !multicastAllowed {
            appendLightingGateBlockReason(.multicastNotAllowed, to: &reasons)
        }
        if !allowedUniverses.contains(where: { $0.allows(request) }) {
            appendLightingGateBlockReason(.requestNotAllowed, to: &reasons)
        }
        if !reasons.isEmpty {
            return blocked(reasons)
        }

        return LightingGateDecision(state: .output, canTransmit: true, reason: nil)
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

public struct LightingDmxPayloadProfile: Codable, Equatable, Sendable {
    public var channelCount: Int
    public var changedChannels: Int
    public var minLevel: Int
    public var maxLevel: Int

    public init(channelCount: Int, changedChannels: Int, minLevel: Int, maxLevel: Int) {
        self.channelCount = channelCount
        self.changedChannels = changedChannels
        self.minLevel = minLevel
        self.maxLevel = maxLevel
    }
}

public struct LightingPacketCaptureReport: Codable, Equatable, Sendable {
    public var captured: Bool
    public var tool: String
    public var capturePoint: String
    public var packetCount: Int
    public var universesObserved: [Int]
    public var broadcastPackets: Int
    public var multicastPackets: Int
    public var captureArtifact: String
    public var notes: String

    public init(
        captured: Bool,
        tool: String,
        capturePoint: String,
        packetCount: Int,
        universesObserved: [Int],
        broadcastPackets: Int,
        multicastPackets: Int,
        captureArtifact: String,
        notes: String
    ) {
        self.captured = captured
        self.tool = tool
        self.capturePoint = capturePoint
        self.packetCount = packetCount
        self.universesObserved = universesObserved
        self.broadcastPackets = broadcastPackets
        self.multicastPackets = multicastPackets
        self.captureArtifact = captureArtifact
        self.notes = notes
    }
}

public struct LightingProbeReport: Codable, Equatable, Sendable {
    public var interopTarget: LightingInteropTarget
    public var request: LightingOutputRequest
    public var dmx: LightingDmxPayloadProfile
    public var packetCapture: LightingPacketCaptureReport
    public var durationSeconds: Double

    public init(
        interopTarget: LightingInteropTarget,
        request: LightingOutputRequest,
        dmx: LightingDmxPayloadProfile,
        packetCapture: LightingPacketCaptureReport,
        durationSeconds: Double
    ) {
        self.interopTarget = interopTarget
        self.request = request
        self.dmx = dmx
        self.packetCapture = packetCapture
        self.durationSeconds = durationSeconds
    }
}

public enum LightingFixtureMetadataValidationMode: String, Codable, Equatable, Sendable {
    case setupOnly
    case notRun
}

public struct LightingFixtureMetadataPolicy: Codable, Equatable, Sendable {
    public var source: String
    public var validationMode: LightingFixtureMetadataValidationMode
    public var realtimeLookupAllowed: Bool

    public init(
        source: String,
        validationMode: LightingFixtureMetadataValidationMode,
        realtimeLookupAllowed: Bool
    ) {
        self.source = source
        self.validationMode = validationMode
        self.realtimeLookupAllowed = realtimeLookupAllowed
    }
}

public struct LightingAudioImpactMetrics: Codable, Equatable, Sendable {
    public var baselineCallbackP99Microseconds: Double
    public var lightingCallbackP99Microseconds: Double
    public var baselineCallbackMaxMicroseconds: Double
    public var lightingCallbackMaxMicroseconds: Double
    public var baselinePlayoutTargetFrames: Int
    public var lightingPlayoutTargetFrames: Int
    public var underruns: Int
    public var hiddenAudioImpactDetected: Bool
    public var baselineReportId: String?

    public init(
        baselineCallbackP99Microseconds: Double,
        lightingCallbackP99Microseconds: Double,
        baselineCallbackMaxMicroseconds: Double,
        lightingCallbackMaxMicroseconds: Double,
        baselinePlayoutTargetFrames: Int,
        lightingPlayoutTargetFrames: Int,
        underruns: Int,
        hiddenAudioImpactDetected: Bool,
        baselineReportId: String? = nil
    ) {
        self.baselineCallbackP99Microseconds = baselineCallbackP99Microseconds
        self.lightingCallbackP99Microseconds = lightingCallbackP99Microseconds
        self.baselineCallbackMaxMicroseconds = baselineCallbackMaxMicroseconds
        self.lightingCallbackMaxMicroseconds = lightingCallbackMaxMicroseconds
        self.baselinePlayoutTargetFrames = baselinePlayoutTargetFrames
        self.lightingPlayoutTargetFrames = lightingPlayoutTargetFrames
        self.underruns = underruns
        self.hiddenAudioImpactDetected = hiddenAudioImpactDetected
        self.baselineReportId = baselineReportId
    }
}

public enum LightingFixtureGateValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case emptyList(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case valueOutOfRange(field: String, value: Int)
    case invalidDmxLevelRange(minLevel: Int, maxLevel: Int)
    case missingStandard(LightingControlProtocol)
    case unorderedAudioCallbackMetrics(String)
    case packetCaptureAccountingMismatch
    case passWithoutReviewedStandards(LightingControlProtocol)
    case passWithBlockedGate(LightingGateBlockReason)
    case passWithoutFailurePolicy
    case passWithoutPacketCapture
    case passWithoutOneUniverseCapture
    case passWithoutDmxOutputActivity
    case passAllowsRealtimeFixtureLookup
    case passIncreasesAudioP99(baseline: Double, lighting: Double)
    case passIncreasesAudioMax(baseline: Double, lighting: Double)
    case passChangesAudioPlayoutTarget(baseline: Int, lighting: Int)
    case passWithUnderruns(Int)
    case passWithHiddenAudioImpact
    case passWithoutCueWorkflow
    case passWithoutOscCueReport
    case passWithoutLocalFixtureOwner
    case passWithFixtureOwnerMismatch(expected: LightingInteropTarget, actual: LightingInteropTarget)
    case passWithDirectFixtureStreamingOnPerformanceLink
    case passWithPlaceholderWorkflowField(String)
}
