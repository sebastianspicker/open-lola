// Collects direct-peer session evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Represents the DirectPeerSessionReportMetrics produced by direct peer sessions without exposing its execution state.
public struct DirectPeerSessionReportMetrics: Codable, Equatable, Sendable {
    public struct Traffic: Equatable, Sendable {
        public var controlMessagesSent: Int
        public var packetsSent: Int
        public var packetsReceived: Int
        public var packetsLost: Int
        public var jitterMicroseconds: Double
        public var audioPacketsRouted: Int
        public var videoPacketsRouted: Int
        public var recoveryEvents: Int

        public init(
            controlMessagesSent: Int,
            packetsSent: Int,
            packetsReceived: Int,
            packetsLost: Int,
            jitterMicroseconds: Double,
            audioPacketsRouted: Int,
            videoPacketsRouted: Int,
            recoveryEvents: Int
        ) {
            self.controlMessagesSent = controlMessagesSent
            self.packetsSent = packetsSent
            self.packetsReceived = packetsReceived
            self.packetsLost = packetsLost
            self.jitterMicroseconds = jitterMicroseconds
            self.audioPacketsRouted = audioPacketsRouted
            self.videoPacketsRouted = videoPacketsRouted
            self.recoveryEvents = recoveryEvents
        }
    }

    public struct Control: Equatable, Sendable {
        public var audioPayloadsSentOnControlChannel: Int
        public var controlDatagramsSent: Int?
        public var controlDatagramsReceived: Int?
        public var audioMetadataMessagesSent: Int
        public var audioMetadataMessagesReceived: Int
        public var timingProbePacketsSent: Int
        public var timingProbePacketsReceived: Int
        public var timingProbeMaxAgeMicroseconds: Double

        public init(
            audioPayloadsSentOnControlChannel: Int,
            controlDatagramsSent: Int? = nil,
            controlDatagramsReceived: Int? = nil,
            audioMetadataMessagesSent: Int = 0,
            audioMetadataMessagesReceived: Int = 0,
            timingProbePacketsSent: Int = 0,
            timingProbePacketsReceived: Int = 0,
            timingProbeMaxAgeMicroseconds: Double = 0
        ) {
            self.audioPayloadsSentOnControlChannel = audioPayloadsSentOnControlChannel
            self.controlDatagramsSent = controlDatagramsSent
            self.controlDatagramsReceived = controlDatagramsReceived
            self.audioMetadataMessagesSent = audioMetadataMessagesSent
            self.audioMetadataMessagesReceived = audioMetadataMessagesReceived
            self.timingProbePacketsSent = timingProbePacketsSent
            self.timingProbePacketsReceived = timingProbePacketsReceived
            self.timingProbeMaxAgeMicroseconds = timingProbeMaxAgeMicroseconds
        }
    }

    public struct Remote: Equatable, Sendable {
        public var metricsMessagesSent: Int?
        public var remoteMetricsMessagesReceived: Int?
        public var remotePacketsLost: Int?
        public var remoteJitterMicroseconds: Double?
        public var remoteLatePackets: Int?
        public var remoteCallbackDurationP99Microseconds: Double?
        public var remoteQueueDepthPackets: Int?
        public var remoteCPUPercent: Double?

        public init(
            metricsMessagesSent: Int? = nil,
            remoteMetricsMessagesReceived: Int? = nil,
            remotePacketsLost: Int? = nil,
            remoteJitterMicroseconds: Double? = nil,
            remoteLatePackets: Int? = nil,
            remoteCallbackDurationP99Microseconds: Double? = nil,
            remoteQueueDepthPackets: Int? = nil,
            remoteCPUPercent: Double? = nil
        ) {
            self.metricsMessagesSent = metricsMessagesSent
            self.remoteMetricsMessagesReceived = remoteMetricsMessagesReceived
            self.remotePacketsLost = remotePacketsLost
            self.remoteJitterMicroseconds = remoteJitterMicroseconds
            self.remoteLatePackets = remoteLatePackets
            self.remoteCallbackDurationP99Microseconds = remoteCallbackDurationP99Microseconds
            self.remoteQueueDepthPackets = remoteQueueDepthPackets
            self.remoteCPUPercent = remoteCPUPercent
        }
    }

    public struct RemoteResources: Equatable, Sendable {
        public var remoteMemoryResidentBytes: UInt64?
        public var remoteUnderruns: Int?
        public var remoteOverruns: Int?
        public var remoteVideoFramesDropped: Int?

        public init(
            remoteMemoryResidentBytes: UInt64? = nil,
            remoteUnderruns: Int? = nil,
            remoteOverruns: Int? = nil,
            remoteVideoFramesDropped: Int? = nil
        ) {
            self.remoteMemoryResidentBytes = remoteMemoryResidentBytes
            self.remoteUnderruns = remoteUnderruns
            self.remoteOverruns = remoteOverruns
            self.remoteVideoFramesDropped = remoteVideoFramesDropped
        }
    }
    public var controlMessagesSent: Int
    public var packetsSent: Int
    public var packetsReceived: Int
    public var packetsLost: Int
    public var jitterMicroseconds: Double
    public var audioPacketsRouted: Int
    public var videoPacketsRouted: Int
    public var recoveryEvents: Int
    public var audioPayloadsSentOnControlChannel: Int
    public var controlDatagramsSent: Int?
    public var controlDatagramsReceived: Int?
    public var audioMetadataMessagesSent: Int
    public var audioMetadataMessagesReceived: Int
    public var timingProbePacketsSent: Int
    public var timingProbePacketsReceived: Int
    public var timingProbeMaxAgeMicroseconds: Double
    public var metricsMessagesSent: Int?
    public var remoteMetricsMessagesReceived: Int?
    public var remotePacketsLost: Int?
    public var remoteJitterMicroseconds: Double?
    public var remoteLatePackets: Int?
    public var remoteCallbackDurationP99Microseconds: Double?
    public var remoteQueueDepthPackets: Int?
    public var remoteCPUPercent: Double?
    public var remoteMemoryResidentBytes: UInt64?
    public var remoteUnderruns: Int?
    public var remoteOverruns: Int?
    public var remoteVideoFramesDropped: Int?

    public init(traffic: Traffic, control: Control, remote: Remote, remoteResources: RemoteResources) {
        self.controlMessagesSent = traffic.controlMessagesSent
        self.packetsSent = traffic.packetsSent
        self.packetsReceived = traffic.packetsReceived
        self.packetsLost = traffic.packetsLost
        self.jitterMicroseconds = traffic.jitterMicroseconds
        self.audioPacketsRouted = traffic.audioPacketsRouted
        self.videoPacketsRouted = traffic.videoPacketsRouted
        self.recoveryEvents = traffic.recoveryEvents
        self.audioPayloadsSentOnControlChannel = control.audioPayloadsSentOnControlChannel
        self.controlDatagramsSent = control.controlDatagramsSent
        self.controlDatagramsReceived = control.controlDatagramsReceived
        self.audioMetadataMessagesSent = control.audioMetadataMessagesSent
        self.audioMetadataMessagesReceived = control.audioMetadataMessagesReceived
        self.timingProbePacketsSent = control.timingProbePacketsSent
        self.timingProbePacketsReceived = control.timingProbePacketsReceived
        self.timingProbeMaxAgeMicroseconds = control.timingProbeMaxAgeMicroseconds
        self.metricsMessagesSent = remote.metricsMessagesSent
        self.remoteMetricsMessagesReceived = remote.remoteMetricsMessagesReceived
        self.remotePacketsLost = remote.remotePacketsLost
        self.remoteJitterMicroseconds = remote.remoteJitterMicroseconds
        self.remoteLatePackets = remote.remoteLatePackets
        self.remoteCallbackDurationP99Microseconds = remote.remoteCallbackDurationP99Microseconds
        self.remoteQueueDepthPackets = remote.remoteQueueDepthPackets
        self.remoteCPUPercent = remote.remoteCPUPercent
        self.remoteMemoryResidentBytes = remoteResources.remoteMemoryResidentBytes
        self.remoteUnderruns = remoteResources.remoteUnderruns
        self.remoteOverruns = remoteResources.remoteOverruns
        self.remoteVideoFramesDropped = remoteResources.remoteVideoFramesDropped
    }

}

/// Represents the DirectPeerSessionAVRuntimeMetrics produced by direct peer sessions without exposing its execution state.
public struct DirectPeerSessionAVRuntimeMetrics: Codable, Equatable, Sendable {
    public static let empty = DirectPeerSessionAVRuntimeMetrics()

    public var audioPayloadsCaptured = 0
    public var audioPayloadsSent = 0
    public var audioTXBudgetExhaustions = 0
    public var audioPayloadsQueuedForPlayout = 0
    public var audioPayloadsDroppedBeforeSend = 0
    public var audioPayloadsDroppedBeforePlayout = 0
    public var audioPayloadsDroppedByPlayoutQueue = 0
    public var audioUnexpectedPayloadTypes = 0
    public var audioRXBuffer: RxBufferRuntimeSnapshot?
    public var audioPlayoutUnderruns = 0
    public var audioCallbackMaxMicroseconds = 0
    public var audioCallbackDeadlineMisses = 0
    public var audioCallbackOverruns = 0
    public var audioHostTimeConversionFailures = 0
    public var videoFramesCaptured = 0
    public var videoFramesSent = 0
    public var videoFramesDroppedBeforeSend = 0
    public var videoFragmentsSent = 0
    public var videoFragmentsReceived = 0
    public var videoFragmentsDroppedCorrupt = 0
    public var videoFragmentsDroppedOversize = 0
    public var videoUnexpectedPayloadTypes = 0
    public var videoFramesReassembled = 0
    public var videoFramesDroppedDuringReassembly = 0
    public var videoReassemblyMissingFragments = 0
    public var videoReassemblyLateFragments = 0
    public var videoReassemblyDuplicateFragments = 0
    public var previewFramesSubmitted = 0
    public var previewFramesDropped = 0
    public var previewFramesFailed = 0
    public var videoFramesDroppedOutsideAudioWindow = 0
    public var videoFramesAlignedForSync = 0
    public var videoFramesDeferredForSync = 0
    public var videoFramesDroppedForSync = 0
    public var videoFramesReplacedDuringSyncDefer = 0
    public var cameraWarmupWaits = 0
    public var audioReceiveDrainIterations = 0
    public var videoReceiveDrainIterations = 0
    public var metricsMessagesPublished = 0
    public var metricsMessagesPublishFailures = 0
    public var peerMetricsMessagesReceived = 0
    public var peerMetricsMessagesDropped = 0

    public init() {}

    enum CodingKeys: String, CodingKey {
        case audioPayloadsCaptured
        case audioPayloadsSent
        case audioTXBudgetExhaustions
        case audioPayloadsQueuedForPlayout
        case audioPayloadsDroppedBeforeSend
        case audioPayloadsDroppedBeforePlayout
        case audioPayloadsDroppedByPlayoutQueue
        case audioUnexpectedPayloadTypes
        case audioRXBuffer
        case audioPlayoutUnderruns
        case audioCallbackMaxMicroseconds
        case audioCallbackDeadlineMisses
        case audioCallbackOverruns
        case audioHostTimeConversionFailures
        case videoFramesCaptured
        case videoFramesSent
        case videoFramesDroppedBeforeSend
        case videoFragmentsSent
        case videoFragmentsReceived
        case videoFragmentsDroppedCorrupt
        case videoFragmentsDroppedOversize
        case videoUnexpectedPayloadTypes
        case videoFramesReassembled
        case videoFramesDroppedDuringReassembly
        case videoReassemblyMissingFragments
        case videoReassemblyLateFragments
        case videoReassemblyDuplicateFragments
        case previewFramesSubmitted
        case previewFramesDropped
        case previewFramesFailed
        case videoFramesDroppedOutsideAudioWindow
        case videoFramesAlignedForSync
        case videoFramesDeferredForSync
        case videoFramesDroppedForSync
        case videoFramesReplacedDuringSyncDefer
        case cameraWarmupWaits
        case audioReceiveDrainIterations
        case videoReceiveDrainIterations
        case metricsMessagesPublished
        case metricsMessagesPublishFailures
        case peerMetricsMessagesReceived
        case peerMetricsMessagesDropped
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        try decodeAudioRuntimeMetrics(from: container)
        try decodeVideoRuntimeMetrics(from: container)
        try decodePreviewAndSyncMetrics(from: container)
        try decodeRuntimeTelemetryMetrics(from: container)
    }

    private mutating func decodeAudioRuntimeMetrics(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws {
        audioPayloadsCaptured = try container.decodeIfPresent(Int.self, forKey: .audioPayloadsCaptured) ?? 0
        audioPayloadsSent = try container.decodeIfPresent(Int.self, forKey: .audioPayloadsSent) ?? 0
        audioTXBudgetExhaustions = try container.decodeIfPresent(Int.self, forKey: .audioTXBudgetExhaustions) ?? 0
        audioPayloadsQueuedForPlayout = try container.decodeIfPresent(
Int.self,
forKey: .audioPayloadsQueuedForPlayout
) ?? 0
        audioPayloadsDroppedBeforeSend = try container.decodeIfPresent(
Int.self,
forKey: .audioPayloadsDroppedBeforeSend
) ?? 0
        audioPayloadsDroppedBeforePlayout = try container.decodeIfPresent(
Int.self,
forKey: .audioPayloadsDroppedBeforePlayout
) ?? 0
        audioPayloadsDroppedByPlayoutQueue = try container.decodeIfPresent(
            Int.self,
            forKey: .audioPayloadsDroppedByPlayoutQueue
        ) ?? 0
        audioUnexpectedPayloadTypes = try container.decodeIfPresent(Int.self, forKey: .audioUnexpectedPayloadTypes) ?? 0
        audioRXBuffer = try container.decodeIfPresent(RxBufferRuntimeSnapshot.self, forKey: .audioRXBuffer)
        audioPlayoutUnderruns = try container.decodeIfPresent(Int.self, forKey: .audioPlayoutUnderruns) ?? 0
        audioCallbackMaxMicroseconds = try container.decodeIfPresent(
Int.self,
forKey: .audioCallbackMaxMicroseconds
) ?? 0
        audioCallbackDeadlineMisses = try container.decodeIfPresent(Int.self, forKey: .audioCallbackDeadlineMisses) ?? 0
        audioCallbackOverruns = try container.decodeIfPresent(Int.self, forKey: .audioCallbackOverruns) ?? 0
        audioHostTimeConversionFailures = try container.decodeIfPresent(
            Int.self,
            forKey: .audioHostTimeConversionFailures
        ) ?? 0
    }

    private mutating func decodeVideoRuntimeMetrics(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws {
        videoFramesCaptured = try container.decodeIfPresent(Int.self, forKey: .videoFramesCaptured) ?? 0
        videoFramesSent = try container.decodeIfPresent(Int.self, forKey: .videoFramesSent) ?? 0
        videoFramesDroppedBeforeSend = try container.decodeIfPresent(
            Int.self,
            forKey: .videoFramesDroppedBeforeSend
        ) ?? 0
        videoFragmentsSent = try container.decodeIfPresent(Int.self, forKey: .videoFragmentsSent) ?? 0
        videoFragmentsReceived = try container.decodeIfPresent(Int.self, forKey: .videoFragmentsReceived) ?? 0
        videoFragmentsDroppedCorrupt = try container.decodeIfPresent(
            Int.self,
            forKey: .videoFragmentsDroppedCorrupt
        ) ?? 0
        videoFragmentsDroppedOversize = try container.decodeIfPresent(
            Int.self,
            forKey: .videoFragmentsDroppedOversize
        ) ?? 0
        videoUnexpectedPayloadTypes = try container.decodeIfPresent(Int.self, forKey: .videoUnexpectedPayloadTypes) ?? 0
        videoFramesReassembled = try container.decodeIfPresent(Int.self, forKey: .videoFramesReassembled) ?? 0
        videoFramesDroppedDuringReassembly = try container.decodeIfPresent(
            Int.self,
            forKey: .videoFramesDroppedDuringReassembly
        ) ?? 0
        videoReassemblyMissingFragments = try container.decodeIfPresent(
            Int.self,
            forKey: .videoReassemblyMissingFragments
        ) ?? 0
        videoReassemblyLateFragments = try container.decodeIfPresent(
            Int.self,
            forKey: .videoReassemblyLateFragments
        ) ?? 0
        videoReassemblyDuplicateFragments = try container.decodeIfPresent(
            Int.self,
            forKey: .videoReassemblyDuplicateFragments
        ) ?? 0
    }

    private mutating func decodePreviewAndSyncMetrics(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws {
        previewFramesSubmitted = try container.decodeIfPresent(Int.self, forKey: .previewFramesSubmitted) ?? 0
        previewFramesDropped = try container.decodeIfPresent(Int.self, forKey: .previewFramesDropped) ?? 0
        previewFramesFailed = try container.decodeIfPresent(Int.self, forKey: .previewFramesFailed) ?? 0
        videoFramesDroppedOutsideAudioWindow = try container.decodeIfPresent(
            Int.self,
            forKey: .videoFramesDroppedOutsideAudioWindow
        ) ?? 0
        videoFramesAlignedForSync = try container.decodeIfPresent(Int.self, forKey: .videoFramesAlignedForSync) ?? 0
        videoFramesDeferredForSync = try container.decodeIfPresent(Int.self, forKey: .videoFramesDeferredForSync) ?? 0
        videoFramesDroppedForSync = try container.decodeIfPresent(Int.self, forKey: .videoFramesDroppedForSync) ?? 0
        videoFramesReplacedDuringSyncDefer = try container.decodeIfPresent(
            Int.self,
            forKey: .videoFramesReplacedDuringSyncDefer
        ) ?? 0
        cameraWarmupWaits = try container.decodeIfPresent(Int.self, forKey: .cameraWarmupWaits) ?? 0
    }

    private mutating func decodeRuntimeTelemetryMetrics(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws {
        audioReceiveDrainIterations = try container.decodeIfPresent(Int.self, forKey: .audioReceiveDrainIterations) ?? 0
        videoReceiveDrainIterations = try container.decodeIfPresent(Int.self, forKey: .videoReceiveDrainIterations) ?? 0
        metricsMessagesPublished = try container.decodeIfPresent(Int.self, forKey: .metricsMessagesPublished) ?? 0
        metricsMessagesPublishFailures = try container.decodeIfPresent(
            Int.self,
            forKey: .metricsMessagesPublishFailures
        ) ?? 0
        peerMetricsMessagesReceived = try container.decodeIfPresent(Int.self, forKey: .peerMetricsMessagesReceived) ?? 0
        peerMetricsMessagesDropped = try container.decodeIfPresent(Int.self, forKey: .peerMetricsMessagesDropped) ?? 0
    }
}

/// Enumerates failures that callers must handle when working with direct peer sessions.
public enum DirectPeerSessionReportError: Error, Equatable, Sendable {
    case emptyField(String)
    case missingAcceptedConfiguration
    case missingPeerMediaEndpoints
    case negativeMetric(String)
    // swiftlint:disable:next identifier_name
    case passRequiresDirectLanManualAddressEvidence
    case passRequiresPhysicalTwoPeerEvidence(DirectPeerSessionMeasuredEvidenceKind)
    case passRequiresProductionMediaSourceMode(DirectPeerSessionAVMediaSourceMode)
    case passRequiresVideoFormat
    case passRequiresVideoReceiveProof
    case passWithPlaceholderMeasuredEvidence(String)
    case passWithInvalidEvidenceArtifact(String)
    case passWithInvalidDSCPEvidence(String)
    case passRequiresStructuredEvidence(String)
    case invalidUsefulMediaProof(String)
    case passRequiresUsefulMediaProof(DirectPeerSessionUsefulMediaProof)
    case passRequiresFastestAVBaselineComparison
    // swiftlint:disable:next identifier_name
    case passWithFailedFastestAVBaselineComparison(String)
    case passWithInconsistentVideoProof(String)
    case passWithoutRoutedMedia(String)
    case passRequiresNonLoopbackPeerEndpoint(String)
    case passWithRuntimeDegradation(String)
}
