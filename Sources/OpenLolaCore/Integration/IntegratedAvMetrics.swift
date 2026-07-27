// Collects IntegratedAvMetrics measurements, keeping metric aggregation separate from report validation.
import Foundation
import OpenLolaContracts

// swiftlint:disable:next inclusive_language
/// Defines the supported choices for integrated AV master clock.
public enum IntegratedAvMasterClock: String, Codable, Equatable, Sendable {
    case audio
    case video
    case external
}

/// Defines the validated fields for integrated AV sync policy.
public struct IntegratedAvSyncPolicy: Codable, Equatable, Sendable {
    // swiftlint:disable:next inclusive_language
    public var masterClock: IntegratedAvMasterClock
    public var audioMayBlockForVideo: Bool
    public var videoMayChangeAudioPlayoutTarget: Bool
    public var videoDegradesBeforeAudioImpact: Bool

    public init(
        // swiftlint:disable:next inclusive_language
        masterClock: IntegratedAvMasterClock,
        audioMayBlockForVideo: Bool,
        videoMayChangeAudioPlayoutTarget: Bool,
        videoDegradesBeforeAudioImpact: Bool
    ) {
        self.masterClock = masterClock
        self.audioMayBlockForVideo = audioMayBlockForVideo
        self.videoMayChangeAudioPlayoutTarget = videoMayChangeAudioPlayoutTarget
        self.videoDegradesBeforeAudioImpact = videoDegradesBeforeAudioImpact
    }

    // swiftlint:disable:next inclusive_language
    public static let audioMaster = IntegratedAvSyncPolicy(
        masterClock: .audio,
        audioMayBlockForVideo: false,
        videoMayChangeAudioPlayoutTarget: false,
        videoDegradesBeforeAudioImpact: true
    )
}

/// Records the evidence and outcome for headless ownership report.
public struct HeadlessOwnershipReport: Codable, Equatable, Sendable {
    public var audioLaneOwner: String
    public var videoLaneOwner: String
    public var uiOwnsRealtimePaths: Bool
    public var recordingEnabled: Bool

    public init(
        audioLaneOwner: String,
        videoLaneOwner: String,
        uiOwnsRealtimePaths: Bool,
        recordingEnabled: Bool
    ) {
        self.audioLaneOwner = audioLaneOwner
        self.videoLaneOwner = videoLaneOwner
        self.uiOwnsRealtimePaths = uiOwnsRealtimePaths
        self.recordingEnabled = recordingEnabled
    }
}

/// Records the evidence and outcome for integrated audio metrics.
public struct IntegratedAudioMetrics: Codable, Equatable, Sendable {
    public var baselineRouteReportId: String
    public var baselineVerdict: MeasurementVerdict
    public var integratedVerdict: MeasurementVerdict
    public var baselineCallbackP99Microseconds: Double
    public var integratedCallbackP99Microseconds: Double
    public var baselineCallbackMaxMicroseconds: Double
    public var integratedCallbackMaxMicroseconds: Double
    public var baselinePlayoutTargetFrames: Int
    public var integratedPlayoutTargetFrames: Int
    public var packetAge: UdpPcmPacketAgeMetrics
    public var lostPackets: Int
    public var latePackets: Int
    public var underruns: Int
    public var hiddenPlayoutGrowthDetected: Bool

    public struct Verdicts: Equatable, Sendable {
        public var baselineRouteReportId: String
        public var baselineVerdict: MeasurementVerdict
        public var integratedVerdict: MeasurementVerdict

        public init(
            baselineRouteReportId: String,
            baselineVerdict: MeasurementVerdict,
            integratedVerdict: MeasurementVerdict
        ) {
            self.baselineRouteReportId = baselineRouteReportId
            self.baselineVerdict = baselineVerdict
            self.integratedVerdict = integratedVerdict
        }
    }

    public struct CallbackTiming: Equatable, Sendable {
        public var baselineP99Microseconds: Double
        public var integratedP99Microseconds: Double
        public var baselineMaxMicroseconds: Double
        public var integratedMaxMicroseconds: Double

        public init(
            baselineP99Microseconds: Double,
            integratedP99Microseconds: Double,
            baselineMaxMicroseconds: Double,
            integratedMaxMicroseconds: Double
        ) {
            self.baselineP99Microseconds = baselineP99Microseconds
            self.integratedP99Microseconds = integratedP99Microseconds
            self.baselineMaxMicroseconds = baselineMaxMicroseconds
            self.integratedMaxMicroseconds = integratedMaxMicroseconds
        }
    }

    public struct PlayoutTargets: Equatable, Sendable {
        public var baselineFrames: Int
        public var integratedFrames: Int

        public init(baselineFrames: Int, integratedFrames: Int) {
            self.baselineFrames = baselineFrames
            self.integratedFrames = integratedFrames
        }
    }

    public struct PacketHealth: Equatable, Sendable {
        public var packetAge: UdpPcmPacketAgeMetrics
        public var lostPackets: Int
        public var latePackets: Int
        public var underruns: Int
        public var hiddenPlayoutGrowthDetected: Bool

        public init(
            packetAge: UdpPcmPacketAgeMetrics,
            lostPackets: Int,
            latePackets: Int,
            underruns: Int,
            hiddenPlayoutGrowthDetected: Bool
        ) {
            self.packetAge = packetAge
            self.lostPackets = lostPackets
            self.latePackets = latePackets
            self.underruns = underruns
            self.hiddenPlayoutGrowthDetected = hiddenPlayoutGrowthDetected
        }
    }

    public init(
        verdicts: Verdicts,
        callbackTiming: CallbackTiming,
        playoutTargets: PlayoutTargets,
        packetHealth: PacketHealth
    ) {
        self.baselineRouteReportId = verdicts.baselineRouteReportId
        self.baselineVerdict = verdicts.baselineVerdict
        self.integratedVerdict = verdicts.integratedVerdict
        self.baselineCallbackP99Microseconds = callbackTiming.baselineP99Microseconds
        self.integratedCallbackP99Microseconds = callbackTiming.integratedP99Microseconds
        self.baselineCallbackMaxMicroseconds = callbackTiming.baselineMaxMicroseconds
        self.integratedCallbackMaxMicroseconds = callbackTiming.integratedMaxMicroseconds
        self.baselinePlayoutTargetFrames = playoutTargets.baselineFrames
        self.integratedPlayoutTargetFrames = playoutTargets.integratedFrames
        self.packetAge = packetHealth.packetAge
        self.lostPackets = packetHealth.lostPackets
        self.latePackets = packetHealth.latePackets
        self.underruns = packetHealth.underruns
        self.hiddenPlayoutGrowthDetected = packetHealth.hiddenPlayoutGrowthDetected
    }
}

/// Defines the supported choices for integrated video timestamp clock.
public enum IntegratedVideoTimestampClock: String, Codable, Equatable, Sendable {
    case continuousMonotonic
}

/// Defines the supported choices for integrated video frame identity.
public enum IntegratedVideoFrameIdentity: String, Codable, Equatable, Sendable {
    case monotonicFrameCounter
}

/// Defines the supported choices for integrated video render selection policy.
public enum IntegratedVideoRenderSelectionPolicy: String, Codable, Equatable, Sendable {
    case nearestUseful
    case latestUseful
}

/// Defines the validated fields for integrated video frame timing.
public struct IntegratedVideoFrameTiming: Codable, Equatable, Sendable {
    public var timestampClock: IntegratedVideoTimestampClock
    public var frameIdentity: IntegratedVideoFrameIdentity
    public var firstFrameId: Int
    public var lastFrameId: Int
    public var firstFrameMonotonicNanoseconds: Int
    public var lastFrameMonotonicNanoseconds: Int
    public var nonMonotonicTimestampCount: Int
    public var duplicateFrameIdentityCount: Int

    public init(
        timestampClock: IntegratedVideoTimestampClock,
        frameIdentity: IntegratedVideoFrameIdentity,
        firstFrameId: Int,
        lastFrameId: Int,
        firstFrameMonotonicNanoseconds: Int,
        lastFrameMonotonicNanoseconds: Int,
        nonMonotonicTimestampCount: Int,
        duplicateFrameIdentityCount: Int
    ) {
        self.timestampClock = timestampClock
        self.frameIdentity = frameIdentity
        self.firstFrameId = firstFrameId
        self.lastFrameId = lastFrameId
        self.firstFrameMonotonicNanoseconds = firstFrameMonotonicNanoseconds
        self.lastFrameMonotonicNanoseconds = lastFrameMonotonicNanoseconds
        self.nonMonotonicTimestampCount = nonMonotonicTimestampCount
        self.duplicateFrameIdentityCount = duplicateFrameIdentityCount
    }
}

/// Defines the validated fields for integrated video render sync.
public struct IntegratedVideoRenderSync: Codable, Equatable, Sendable {
    public var selectionPolicy: IntegratedVideoRenderSelectionPolicy
    public var staleFrameLimitMicroseconds: Double
    public var renderedFrameAge: UdpPcmPacketAgeMetrics
    public var staleFramesDropped: Int
    public var staleFramesRendered: Int
    public var audioHoldEvents: Int

    public init(
        selectionPolicy: IntegratedVideoRenderSelectionPolicy,
        staleFrameLimitMicroseconds: Double,
        renderedFrameAge: UdpPcmPacketAgeMetrics,
        staleFramesDropped: Int,
        staleFramesRendered: Int,
        audioHoldEvents: Int
    ) {
        self.selectionPolicy = selectionPolicy
        self.staleFrameLimitMicroseconds = staleFrameLimitMicroseconds
        self.renderedFrameAge = renderedFrameAge
        self.staleFramesDropped = staleFramesDropped
        self.staleFramesRendered = staleFramesRendered
        self.audioHoldEvents = audioHoldEvents
    }
}

/// Records the evidence and outcome for integrated video metrics.
public struct IntegratedVideoMetrics: Codable, Equatable, Sendable {
    public var source: VideoSourceDescription
    public var format: VideoCaptureFormat
    public var captureFrameAge: UdpPcmPacketAgeMetrics
    public var captureDroppedFrames: Int
    public var transportMode: VideoTransportMode
    public var transportFrameAge: UdpPcmPacketAgeMetrics
    public var receiverDroppedFrames: Int
    public var receiverLateFrames: Int
    public var frameTiming: IntegratedVideoFrameTiming
    public var renderSync: IntegratedVideoRenderSync
    public var degradation: VideoDegradationPolicy

    public struct Capture: Equatable, Sendable {
        public var source: VideoSourceDescription
        public var format: VideoCaptureFormat
        public var frameAge: UdpPcmPacketAgeMetrics
        public var droppedFrames: Int

        public init(
            source: VideoSourceDescription,
            format: VideoCaptureFormat,
            frameAge: UdpPcmPacketAgeMetrics,
            droppedFrames: Int
        ) {
            self.source = source
            self.format = format
            self.frameAge = frameAge
            self.droppedFrames = droppedFrames
        }
    }

    public struct Transport: Equatable, Sendable {
        public var mode: VideoTransportMode
        public var frameAge: UdpPcmPacketAgeMetrics
        public var receiverDroppedFrames: Int
        public var receiverLateFrames: Int

        public init(
            mode: VideoTransportMode,
            frameAge: UdpPcmPacketAgeMetrics,
            receiverDroppedFrames: Int,
            receiverLateFrames: Int
        ) {
            self.mode = mode
            self.frameAge = frameAge
            self.receiverDroppedFrames = receiverDroppedFrames
            self.receiverLateFrames = receiverLateFrames
        }
    }

    public init(
        capture: Capture,
        transport: Transport,
        frameTiming: IntegratedVideoFrameTiming,
        renderSync: IntegratedVideoRenderSync,
        degradation: VideoDegradationPolicy
    ) {
        self.source = capture.source
        self.format = capture.format
        self.captureFrameAge = capture.frameAge
        self.captureDroppedFrames = capture.droppedFrames
        self.transportMode = transport.mode
        self.transportFrameAge = transport.frameAge
        self.receiverDroppedFrames = transport.receiverDroppedFrames
        self.receiverLateFrames = transport.receiverLateFrames
        self.frameTiming = frameTiming
        self.renderSync = renderSync
        self.degradation = degradation
    }
}

/// Records the evidence and outcome for integrated system load metrics.
public struct IntegratedSystemLoadMetrics: Codable, Equatable, Sendable {
    public var cpuStressEnabled: Bool
    public var gpuStressEnabled: Bool
    public var networkStressEnabled: Bool
    public var cpuP99Percent: Double
    public var gpuP99Percent: Double
    public var networkMegabitsPerSecond: Double

    public init(
        cpuStressEnabled: Bool,
        gpuStressEnabled: Bool,
        networkStressEnabled: Bool,
        cpuP99Percent: Double,
        gpuP99Percent: Double,
        networkMegabitsPerSecond: Double
    ) {
        self.cpuStressEnabled = cpuStressEnabled
        self.gpuStressEnabled = gpuStressEnabled
        self.networkStressEnabled = networkStressEnabled
        self.cpuP99Percent = cpuP99Percent
        self.gpuP99Percent = gpuP99Percent
        self.networkMegabitsPerSecond = networkMegabitsPerSecond
    }
}

/// Records the evidence and outcome for integrated AV run window evidence.
public struct IntegratedAvRunWindowEvidence: Codable, Equatable, Sendable {
    public var startedAt: String
    public var endedAt: String
    public var audioVideoOverlapSeconds: Double

    public init(startedAt: String, endedAt: String, audioVideoOverlapSeconds: Double) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.audioVideoOverlapSeconds = audioVideoOverlapSeconds
    }
}

/// Defines the supported choices for integrated closure gate.
public enum IntegratedClosureGate: String, Codable, Equatable, Sendable {
    case p04IntegratedAvProof
}
