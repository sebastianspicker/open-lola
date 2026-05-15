import Foundation

public struct DirectPeerSessionReportMetrics: Codable, Equatable, Sendable {
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

    public init(
        controlMessagesSent: Int,
        packetsSent: Int,
        packetsReceived: Int,
        packetsLost: Int,
        jitterMicroseconds: Double,
        audioPacketsRouted: Int,
        videoPacketsRouted: Int,
        recoveryEvents: Int,
        audioPayloadsSentOnControlChannel: Int,
        controlDatagramsSent: Int? = nil,
        controlDatagramsReceived: Int? = nil,
        audioMetadataMessagesSent: Int = 0,
        audioMetadataMessagesReceived: Int = 0,
        timingProbePacketsSent: Int = 0,
        timingProbePacketsReceived: Int = 0,
        timingProbeMaxAgeMicroseconds: Double = 0,
        metricsMessagesSent: Int? = nil,
        remoteMetricsMessagesReceived: Int? = nil,
        remotePacketsLost: Int? = nil,
        remoteJitterMicroseconds: Double? = nil,
        remoteLatePackets: Int? = nil,
        remoteCallbackDurationP99Microseconds: Double? = nil,
        remoteQueueDepthPackets: Int? = nil,
        remoteCPUPercent: Double? = nil,
        remoteMemoryResidentBytes: UInt64? = nil,
        remoteUnderruns: Int? = nil,
        remoteOverruns: Int? = nil,
        remoteVideoFramesDropped: Int? = nil
    ) {
        self.controlMessagesSent = controlMessagesSent
        self.packetsSent = packetsSent
        self.packetsReceived = packetsReceived
        self.packetsLost = packetsLost
        self.jitterMicroseconds = jitterMicroseconds
        self.audioPacketsRouted = audioPacketsRouted
        self.videoPacketsRouted = videoPacketsRouted
        self.recoveryEvents = recoveryEvents
        self.audioPayloadsSentOnControlChannel = audioPayloadsSentOnControlChannel
        self.controlDatagramsSent = controlDatagramsSent
        self.controlDatagramsReceived = controlDatagramsReceived
        self.audioMetadataMessagesSent = audioMetadataMessagesSent
        self.audioMetadataMessagesReceived = audioMetadataMessagesReceived
        self.timingProbePacketsSent = timingProbePacketsSent
        self.timingProbePacketsReceived = timingProbePacketsReceived
        self.timingProbeMaxAgeMicroseconds = timingProbeMaxAgeMicroseconds
        self.metricsMessagesSent = metricsMessagesSent
        self.remoteMetricsMessagesReceived = remoteMetricsMessagesReceived
        self.remotePacketsLost = remotePacketsLost
        self.remoteJitterMicroseconds = remoteJitterMicroseconds
        self.remoteLatePackets = remoteLatePackets
        self.remoteCallbackDurationP99Microseconds = remoteCallbackDurationP99Microseconds
        self.remoteQueueDepthPackets = remoteQueueDepthPackets
        self.remoteCPUPercent = remoteCPUPercent
        self.remoteMemoryResidentBytes = remoteMemoryResidentBytes
        self.remoteUnderruns = remoteUnderruns
        self.remoteOverruns = remoteOverruns
        self.remoteVideoFramesDropped = remoteVideoFramesDropped
    }
}

public struct DirectPeerSessionAVRuntimeMetrics: Codable, Equatable, Sendable {
    public static let empty = DirectPeerSessionAVRuntimeMetrics()

    public var audioPayloadsCaptured: Int
    public var audioPayloadsSent: Int
    public var audioPayloadsQueuedForPlayout: Int
    public var audioPayloadsDroppedBeforeSend: Int
    public var audioPayloadsDroppedBeforePlayout: Int
    public var audioPayloadsDroppedByPlayoutQueue: Int
    public var audioRXBuffer: RxBufferRuntimeSnapshot?
    public var audioPlayoutUnderruns: Int
    public var audioCallbackOverruns: Int
    public var videoFramesCaptured: Int
    public var videoFramesSent: Int
    public var videoFragmentsSent: Int
    public var videoFragmentsReceived: Int
    public var videoFragmentsDroppedCorrupt: Int
    public var videoFragmentsDroppedOversize: Int
    public var videoFramesReassembled: Int
    public var videoFramesDroppedDuringReassembly: Int
    public var videoReassemblyMissingFragments: Int
    public var videoReassemblyLateFragments: Int
    public var videoReassemblyDuplicateFragments: Int
    public var previewFramesSubmitted: Int
    public var previewFramesDropped: Int
    public var previewFramesFailed: Int
    public var videoFramesDroppedOutsideAudioWindow: Int
    public var videoFramesAlignedForSync: Int
    public var videoFramesDeferredForSync: Int
    public var videoFramesDroppedForSync: Int
    public var videoFramesReplacedDuringSyncDefer: Int
    public var cameraWarmupWaits: Int
    public var audioReceiveDrainIterations: Int
    public var videoReceiveDrainIterations: Int
    public var metricsMessagesPublished: Int
    public var metricsMessagesPublishFailures: Int
    public var peerMetricsMessagesReceived: Int
    public var peerMetricsMessagesDropped: Int

    public init(
        audioPayloadsCaptured: Int = 0,
        audioPayloadsSent: Int = 0,
        audioPayloadsQueuedForPlayout: Int = 0,
        audioPayloadsDroppedBeforeSend: Int = 0,
        audioPayloadsDroppedBeforePlayout: Int = 0,
        audioPayloadsDroppedByPlayoutQueue: Int = 0,
        audioRXBuffer: RxBufferRuntimeSnapshot? = nil,
        audioPlayoutUnderruns: Int = 0,
        audioCallbackOverruns: Int = 0,
        videoFramesCaptured: Int = 0,
        videoFramesSent: Int = 0,
        videoFragmentsSent: Int = 0,
        videoFragmentsReceived: Int = 0,
        videoFragmentsDroppedCorrupt: Int = 0,
        videoFragmentsDroppedOversize: Int = 0,
        videoFramesReassembled: Int = 0,
        videoFramesDroppedDuringReassembly: Int = 0,
        videoReassemblyMissingFragments: Int = 0,
        videoReassemblyLateFragments: Int = 0,
        videoReassemblyDuplicateFragments: Int = 0,
        previewFramesSubmitted: Int = 0,
        previewFramesDropped: Int = 0,
        previewFramesFailed: Int = 0,
        videoFramesDroppedOutsideAudioWindow: Int = 0,
        videoFramesAlignedForSync: Int = 0,
        videoFramesDeferredForSync: Int = 0,
        videoFramesDroppedForSync: Int = 0,
        videoFramesReplacedDuringSyncDefer: Int = 0,
        cameraWarmupWaits: Int = 0,
        audioReceiveDrainIterations: Int = 0,
        videoReceiveDrainIterations: Int = 0,
        metricsMessagesPublished: Int = 0,
        metricsMessagesPublishFailures: Int = 0,
        peerMetricsMessagesReceived: Int = 0,
        peerMetricsMessagesDropped: Int = 0
    ) {
        self.audioPayloadsCaptured = audioPayloadsCaptured
        self.audioPayloadsSent = audioPayloadsSent
        self.audioPayloadsQueuedForPlayout = audioPayloadsQueuedForPlayout
        self.audioPayloadsDroppedBeforeSend = audioPayloadsDroppedBeforeSend
        self.audioPayloadsDroppedBeforePlayout = audioPayloadsDroppedBeforePlayout
        self.audioPayloadsDroppedByPlayoutQueue = audioPayloadsDroppedByPlayoutQueue
        self.audioRXBuffer = audioRXBuffer
        self.audioPlayoutUnderruns = audioPlayoutUnderruns
        self.audioCallbackOverruns = audioCallbackOverruns
        self.videoFramesCaptured = videoFramesCaptured
        self.videoFramesSent = videoFramesSent
        self.videoFragmentsSent = videoFragmentsSent
        self.videoFragmentsReceived = videoFragmentsReceived
        self.videoFragmentsDroppedCorrupt = videoFragmentsDroppedCorrupt
        self.videoFragmentsDroppedOversize = videoFragmentsDroppedOversize
        self.videoFramesReassembled = videoFramesReassembled
        self.videoFramesDroppedDuringReassembly = videoFramesDroppedDuringReassembly
        self.videoReassemblyMissingFragments = videoReassemblyMissingFragments
        self.videoReassemblyLateFragments = videoReassemblyLateFragments
        self.videoReassemblyDuplicateFragments = videoReassemblyDuplicateFragments
        self.previewFramesSubmitted = previewFramesSubmitted
        self.previewFramesDropped = previewFramesDropped
        self.previewFramesFailed = previewFramesFailed
        self.videoFramesDroppedOutsideAudioWindow = videoFramesDroppedOutsideAudioWindow
        self.videoFramesAlignedForSync = videoFramesAlignedForSync
        self.videoFramesDeferredForSync = videoFramesDeferredForSync
        self.videoFramesDroppedForSync = videoFramesDroppedForSync
        self.videoFramesReplacedDuringSyncDefer = videoFramesReplacedDuringSyncDefer
        self.cameraWarmupWaits = cameraWarmupWaits
        self.audioReceiveDrainIterations = audioReceiveDrainIterations
        self.videoReceiveDrainIterations = videoReceiveDrainIterations
        self.metricsMessagesPublished = metricsMessagesPublished
        self.metricsMessagesPublishFailures = metricsMessagesPublishFailures
        self.peerMetricsMessagesReceived = peerMetricsMessagesReceived
        self.peerMetricsMessagesDropped = peerMetricsMessagesDropped
    }

    enum CodingKeys: String, CodingKey {
        case audioPayloadsCaptured
        case audioPayloadsSent
        case audioPayloadsQueuedForPlayout
        case audioPayloadsDroppedBeforeSend
        case audioPayloadsDroppedBeforePlayout
        case audioPayloadsDroppedByPlayoutQueue
        case audioRXBuffer
        case audioPlayoutUnderruns
        case audioCallbackOverruns
        case videoFramesCaptured
        case videoFramesSent
        case videoFragmentsSent
        case videoFragmentsReceived
        case videoFragmentsDroppedCorrupt
        case videoFragmentsDroppedOversize
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
        audioPayloadsCaptured = try container.decodeIfPresent(Int.self, forKey: .audioPayloadsCaptured) ?? 0
        audioPayloadsSent = try container.decodeIfPresent(Int.self, forKey: .audioPayloadsSent) ?? 0
        audioPayloadsQueuedForPlayout = try container.decodeIfPresent(Int.self, forKey: .audioPayloadsQueuedForPlayout) ?? 0
        audioPayloadsDroppedBeforeSend = try container.decodeIfPresent(Int.self, forKey: .audioPayloadsDroppedBeforeSend) ?? 0
        audioPayloadsDroppedBeforePlayout = try container.decodeIfPresent(Int.self, forKey: .audioPayloadsDroppedBeforePlayout) ?? 0
        audioPayloadsDroppedByPlayoutQueue = try container.decodeIfPresent(
            Int.self,
            forKey: .audioPayloadsDroppedByPlayoutQueue
        ) ?? 0
        audioRXBuffer = try container.decodeIfPresent(RxBufferRuntimeSnapshot.self, forKey: .audioRXBuffer)
        audioPlayoutUnderruns = try container.decodeIfPresent(Int.self, forKey: .audioPlayoutUnderruns) ?? 0
        audioCallbackOverruns = try container.decodeIfPresent(Int.self, forKey: .audioCallbackOverruns) ?? 0
        videoFramesCaptured = try container.decodeIfPresent(Int.self, forKey: .videoFramesCaptured) ?? 0
        videoFramesSent = try container.decodeIfPresent(Int.self, forKey: .videoFramesSent) ?? 0
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

public enum DirectPeerSessionReportError: Error, Equatable, Sendable {
    case emptyField(String)
    case missingAcceptedConfiguration
    case missingPeerMediaEndpoints
    case negativeMetric(String)
    case passRequiresDirectLanManualAddressEvidence
    case passRequiresPhysicalTwoPeerEvidence(DirectPeerSessionMeasuredEvidenceKind)
    case passRequiresProductionMediaSourceMode(DirectPeerSessionAVMediaSourceMode)
    case passRequiresVideoFormat
    case passRequiresVideoReceiveProof
    case passWithPlaceholderMeasuredEvidence(String)
    case passWithInvalidEvidenceArtifact(String)
    case passRequiresStructuredEvidence(String)
    case passRequiresFastestAVBaselineComparison
    case passWithFailedFastestAVBaselineComparison(String)
    case passWithInconsistentVideoProof(String)
    case passWithoutRoutedMedia(String)
}
