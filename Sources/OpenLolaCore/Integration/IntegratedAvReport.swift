import Foundation

public enum IntegratedAvRunMode: String, Codable, Equatable, Sendable {
    case synthetic
    case measured
}

public enum IntegratedAvMasterClock: String, Codable, Equatable, Sendable {
    case audio
    case video
    case external
}

public struct IntegratedAvSyncPolicy: Codable, Equatable, Sendable {
    public var masterClock: IntegratedAvMasterClock
    public var audioMayBlockForVideo: Bool
    public var videoMayChangeAudioPlayoutTarget: Bool
    public var videoDegradesBeforeAudioImpact: Bool

    public init(
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

    public static let audioMaster = IntegratedAvSyncPolicy(
        masterClock: .audio,
        audioMayBlockForVideo: false,
        videoMayChangeAudioPlayoutTarget: false,
        videoDegradesBeforeAudioImpact: true
    )
}

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

    public init(
        baselineRouteReportId: String,
        baselineVerdict: MeasurementVerdict,
        integratedVerdict: MeasurementVerdict,
        baselineCallbackP99Microseconds: Double,
        integratedCallbackP99Microseconds: Double,
        baselineCallbackMaxMicroseconds: Double,
        integratedCallbackMaxMicroseconds: Double,
        baselinePlayoutTargetFrames: Int,
        integratedPlayoutTargetFrames: Int,
        packetAge: UdpPcmPacketAgeMetrics,
        lostPackets: Int,
        latePackets: Int,
        underruns: Int,
        hiddenPlayoutGrowthDetected: Bool
    ) {
        self.baselineRouteReportId = baselineRouteReportId
        self.baselineVerdict = baselineVerdict
        self.integratedVerdict = integratedVerdict
        self.baselineCallbackP99Microseconds = baselineCallbackP99Microseconds
        self.integratedCallbackP99Microseconds = integratedCallbackP99Microseconds
        self.baselineCallbackMaxMicroseconds = baselineCallbackMaxMicroseconds
        self.integratedCallbackMaxMicroseconds = integratedCallbackMaxMicroseconds
        self.baselinePlayoutTargetFrames = baselinePlayoutTargetFrames
        self.integratedPlayoutTargetFrames = integratedPlayoutTargetFrames
        self.packetAge = packetAge
        self.lostPackets = lostPackets
        self.latePackets = latePackets
        self.underruns = underruns
        self.hiddenPlayoutGrowthDetected = hiddenPlayoutGrowthDetected
    }
}

public enum IntegratedVideoTimestampClock: String, Codable, Equatable, Sendable {
    case continuousMonotonic
}

public enum IntegratedVideoFrameIdentity: String, Codable, Equatable, Sendable {
    case monotonicFrameCounter
}

public enum IntegratedVideoRenderSelectionPolicy: String, Codable, Equatable, Sendable {
    case nearestUseful
    case latestUseful
}

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

    public init(
        source: VideoSourceDescription,
        format: VideoCaptureFormat,
        captureFrameAge: UdpPcmPacketAgeMetrics,
        captureDroppedFrames: Int,
        transportMode: VideoTransportMode,
        transportFrameAge: UdpPcmPacketAgeMetrics,
        receiverDroppedFrames: Int,
        receiverLateFrames: Int,
        frameTiming: IntegratedVideoFrameTiming,
        renderSync: IntegratedVideoRenderSync,
        degradation: VideoDegradationPolicy
    ) {
        self.source = source
        self.format = format
        self.captureFrameAge = captureFrameAge
        self.captureDroppedFrames = captureDroppedFrames
        self.transportMode = transportMode
        self.transportFrameAge = transportFrameAge
        self.receiverDroppedFrames = receiverDroppedFrames
        self.receiverLateFrames = receiverLateFrames
        self.frameTiming = frameTiming
        self.renderSync = renderSync
        self.degradation = degradation
    }
}

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

public enum IntegratedClosureGate: String, Codable, Equatable, Sendable {
    case p04IntegratedAvProof
}

public struct IntegratedProofEvidence: Codable, Equatable, Sendable {
    public var closureGate: IntegratedClosureGate
    public var audioOnlyBaselineFirst: Bool
    public var audioOnlyBaselineReportId: String
    public var integratedRunReportId: String
    public var audioRoutePacketCapturePoint: String?
    public var rmeAudioDeviceVisible: Bool
    public var rmeAudioDeviceUid: String
    public var videoCaptureEnabled: Bool
    public var videoCaptureReportId: String?
    public var videoTransportEnabled: Bool
    public var videoTransportReportId: String?
    public var videoTransportPacketCapturePoint: String?
    public var videoPreviewEnabled: Bool
    public var videoPreviewReportId: String?
    public var oscPollingEnabled: Bool
    public var oscControlReportId: String
    public var atemReadOnlyPollingEnabled: Bool
    public var atemControlReportId: String
    public var atemArmedCommandsAllowed: Bool
    public var baselineRouteVerdict: MeasurementVerdict
    public var integratedRouteVerdict: MeasurementVerdict

    public init(
        closureGate: IntegratedClosureGate,
        audioOnlyBaselineFirst: Bool,
        audioOnlyBaselineReportId: String,
        integratedRunReportId: String,
        audioRoutePacketCapturePoint: String? = nil,
        rmeAudioDeviceVisible: Bool,
        rmeAudioDeviceUid: String,
        videoCaptureEnabled: Bool,
        videoCaptureReportId: String? = nil,
        videoTransportEnabled: Bool,
        videoTransportReportId: String? = nil,
        videoTransportPacketCapturePoint: String? = nil,
        videoPreviewEnabled: Bool,
        videoPreviewReportId: String? = nil,
        oscPollingEnabled: Bool,
        oscControlReportId: String,
        atemReadOnlyPollingEnabled: Bool,
        atemControlReportId: String,
        atemArmedCommandsAllowed: Bool,
        baselineRouteVerdict: MeasurementVerdict,
        integratedRouteVerdict: MeasurementVerdict
    ) {
        self.closureGate = closureGate
        self.audioOnlyBaselineFirst = audioOnlyBaselineFirst
        self.audioOnlyBaselineReportId = audioOnlyBaselineReportId
        self.integratedRunReportId = integratedRunReportId
        self.audioRoutePacketCapturePoint = audioRoutePacketCapturePoint
        self.rmeAudioDeviceVisible = rmeAudioDeviceVisible
        self.rmeAudioDeviceUid = rmeAudioDeviceUid
        self.videoCaptureEnabled = videoCaptureEnabled
        self.videoCaptureReportId = videoCaptureReportId
        self.videoTransportEnabled = videoTransportEnabled
        self.videoTransportReportId = videoTransportReportId
        self.videoTransportPacketCapturePoint = videoTransportPacketCapturePoint
        self.videoPreviewEnabled = videoPreviewEnabled
        self.videoPreviewReportId = videoPreviewReportId
        self.oscPollingEnabled = oscPollingEnabled
        self.oscControlReportId = oscControlReportId
        self.atemReadOnlyPollingEnabled = atemReadOnlyPollingEnabled
        self.atemControlReportId = atemControlReportId
        self.atemArmedCommandsAllowed = atemArmedCommandsAllowed
        self.baselineRouteVerdict = baselineRouteVerdict
        self.integratedRouteVerdict = integratedRouteVerdict
    }
}

public enum IntegratedAvValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case emptyList(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case unorderedPacketAge(String)
    case unorderedAudioCallbackMetrics(String)
    case percentOutOfRange(field: String, value: Double)
    case passRunTooShort(seconds: Double, minimumSeconds: Double)
    case passWithoutMeasuredRun
    case passWithoutP04Proof
    case passWithoutAudioOnlyBaselineFirst
    case passWithoutRmeAudioDevice
    case passWithoutVideoCapture
    case passWithoutVideoTransportOrPreview
    case passWithoutOscPolling
    case passWithoutAtemReadOnlyPolling
    case passWithAtemCommandsArmed
    case passWithNonPassAudioBaseline(MeasurementVerdict)
    case passWithNonPassIntegratedAudio(MeasurementVerdict)
    case passChangesAudioRouteVerdict(baseline: MeasurementVerdict, integrated: MeasurementVerdict)
    case passWithNonPassAudioRouteVerdict(baseline: MeasurementVerdict, integrated: MeasurementVerdict)
    case passWithUiRealtimeOwnership
    case passWithoutPreAudioDegradation
    case passIncreasesAudioP99(baseline: Double, integrated: Double)
    case passIncreasesAudioMax(baseline: Double, integrated: Double)
    case passChangesAudioPlayoutTarget(baseline: Int, integrated: Int)
    case passWithAudioLossOrLatePackets
    case passWithUnderruns(Int)
    case passWithHiddenPlayoutGrowth
    case passWithoutRunWindow
    case passWithInsufficientAudioVideoOverlap(seconds: Double, minimumSeconds: Double)
    case passWithAudioBaselineReportMismatch(expected: String, actual: String)
    case passWithIntegratedRunReportMismatch(expected: String, actual: String)
    case passWithoutAudioRoutePacketCapturePoint
    case passWithoutVideoCaptureReportId
    case passWithoutVideoTransportReportId
    case passWithoutVideoTransportPacketCapturePoint
    case passWithoutVideoPreviewReportId
    case passWithPlaceholderProofField(String)
    case audioMasterClockViolation(IntegratedAvMasterClock)
    case audioMayBlockForVideo
    case videoMayChangeAudioPlayoutTarget
    case videoWithoutPreAudioImpactDegradation
    case invalidVideoFrameIdentityRange(firstFrameId: Int, lastFrameId: Int)
    case invalidVideoFrameTimestampRange(firstFrameMonotonicNanoseconds: Int, lastFrameMonotonicNanoseconds: Int)
    case passWithNonMonotonicVideoFrameTiming(Int)
    case passWithDuplicateVideoFrameIdentities(Int)
    case passWithStaleVideoRendered(maxAgeMicroseconds: Double, limitMicroseconds: Double)
    case passWithRenderedStaleVideoFrames(Int)
    case passWithAudioHoldForVideoEvents(Int)
}

public struct IntegratedAvReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public static let minimumPassDurationSeconds: Double = 1_800

    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: IntegratedAvRunMode
    public var durationSeconds: Double
    public var runWindow: IntegratedAvRunWindowEvidence?
    public var sync: IntegratedAvSyncPolicy
    public var headless: HeadlessOwnershipReport
    public var audio: IntegratedAudioMetrics
    public var video: IntegratedVideoMetrics
    public var systemLoad: IntegratedSystemLoadMetrics
    public var proof: IntegratedProofEvidence?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: IntegratedAvRunMode,
        durationSeconds: Double,
        runWindow: IntegratedAvRunWindowEvidence? = nil,
        sync: IntegratedAvSyncPolicy = .audioMaster,
        headless: HeadlessOwnershipReport,
        audio: IntegratedAudioMetrics,
        video: IntegratedVideoMetrics,
        systemLoad: IntegratedSystemLoadMetrics,
        proof: IntegratedProofEvidence? = nil,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.durationSeconds = durationSeconds
        self.runWindow = runWindow
        self.sync = sync
        self.headless = headless
        self.audio = audio
        self.video = video
        self.systemLoad = systemLoad
        self.proof = proof
        self.verdict = verdict
        self.notes = notes
    }
}
