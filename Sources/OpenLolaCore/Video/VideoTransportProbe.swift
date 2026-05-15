import Foundation

public enum VideoTransportMode: String, Codable, Equatable, Sendable {
    case raw
    case intraFrame
    case videoToolboxH264
    case videoToolboxHevc
}

public enum VideoDegradationAction: String, Codable, Equatable, Sendable {
    case dropFrame
    case reduceFrameRate
    case reduceQuality
    case reduceResolution
    case disableVideo
}

public struct VideoTransportProfile: Codable, Equatable, Sendable {
    public var mode: VideoTransportMode
    public var networkProtocol: String
    public var payloadFormat: String
    public var reliableRetransmission: Bool
    public var maxPacketBytes: Int
    public var encoderQueueDepth: Int
    public var frameReorderingAllowed: Bool
    public var videoToolboxAvailable: Bool
    public var videoToolboxRealtimeMode: Bool

    public init(
        mode: VideoTransportMode,
        networkProtocol: String,
        payloadFormat: String,
        reliableRetransmission: Bool,
        maxPacketBytes: Int,
        encoderQueueDepth: Int,
        frameReorderingAllowed: Bool,
        videoToolboxAvailable: Bool,
        videoToolboxRealtimeMode: Bool
    ) {
        self.mode = mode
        self.networkProtocol = networkProtocol
        self.payloadFormat = payloadFormat
        self.reliableRetransmission = reliableRetransmission
        self.maxPacketBytes = maxPacketBytes
        self.encoderQueueDepth = encoderQueueDepth
        self.frameReorderingAllowed = frameReorderingAllowed
        self.videoToolboxAvailable = videoToolboxAvailable
        self.videoToolboxRealtimeMode = videoToolboxRealtimeMode
    }
}

public enum VideoTransportRouteKind: String, Codable, Equatable, Sendable {
    case syntheticLocal
    case localhost
    case directWired
    case switched
    case campus
}

public struct VideoTransportRouteEvidence: Codable, Equatable, Sendable {
    public var routeKind: VideoTransportRouteKind
    public var routeLabel: String
    public var packetCapturePoint: String
    public var rawOrIntraFrameBaselineReportId: String?
    public var rawOrIntraFrameBaselineMode: VideoTransportMode?
    public var baselineAudioRouteVerdict: MeasurementVerdict
    public var videoActiveAudioRouteVerdict: MeasurementVerdict

    public init(
        routeKind: VideoTransportRouteKind,
        routeLabel: String,
        packetCapturePoint: String,
        rawOrIntraFrameBaselineReportId: String?,
        rawOrIntraFrameBaselineMode: VideoTransportMode?,
        baselineAudioRouteVerdict: MeasurementVerdict,
        videoActiveAudioRouteVerdict: MeasurementVerdict
    ) {
        self.routeKind = routeKind
        self.routeLabel = routeLabel
        self.packetCapturePoint = packetCapturePoint
        self.rawOrIntraFrameBaselineReportId = rawOrIntraFrameBaselineReportId
        self.rawOrIntraFrameBaselineMode = rawOrIntraFrameBaselineMode
        self.baselineAudioRouteVerdict = baselineAudioRouteVerdict
        self.videoActiveAudioRouteVerdict = videoActiveAudioRouteVerdict
    }

    public var isPhysicalRoute: Bool {
        switch routeKind {
        case .directWired, .switched, .campus:
            return true
        case .syntheticLocal, .localhost:
            return false
        }
    }
}

public struct VideoTransportRunConfiguration: Codable, Equatable, Sendable {
    public static let maximumFrameCount = 3_600
    public static let maximumStreamCount = 4

    public var mode: VideoTransportMode
    public var streamID: UInt32
    public var streamCount: Int
    public var visibleStreamCount: Int
    public var sourceRole: VideoStreamRole
    public var peer: String
    public var port: UInt16
    public var durationSeconds: Int
    public var outputPath: String
    public var width: Int
    public var height: Int
    public var pixelFormat: String
    public var frameRate: Double
    public var queueDepth: Int
    public var maxPacketBytes: Int
    public var routeKind: VideoTransportRouteKind
    public var packetCapturePoint: String

    public var frameCount: Int {
        let requestedFrames = min(Double(Self.maximumFrameCount), Double(durationSeconds) * frameRate)
        return max(1, Int(requestedFrames.rounded(.toNearestOrAwayFromZero)))
    }

    public var frameIntervalNanoseconds: UInt64 {
        max(1, UInt64((1_000_000_000 / frameRate).rounded(.toNearestOrAwayFromZero)))
    }

    public init(
        mode: VideoTransportMode,
        streamID: UInt32 = 100,
        streamCount: Int = 1,
        visibleStreamCount: Int = 1,
        sourceRole: VideoStreamRole = .testPattern,
        peer: String,
        port: UInt16,
        durationSeconds: Int,
        outputPath: String,
        width: Int = 1_280,
        height: Int = 720,
        pixelFormat: String = "synthetic-rgb",
        frameRate: Double = 30,
        queueDepth: Int = 1,
        maxPacketBytes: Int = RawVideoFrameTransport.defaultMaxPacketBytes,
        routeKind: VideoTransportRouteKind = .localhost,
        packetCapturePoint: String = "not-captured"
    ) {
        self.mode = mode
        self.streamID = streamID
        self.streamCount = streamCount
        self.visibleStreamCount = visibleStreamCount
        self.sourceRole = sourceRole
        self.peer = peer
        self.port = port
        self.durationSeconds = durationSeconds
        self.outputPath = outputPath
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.frameRate = frameRate
        self.queueDepth = queueDepth
        self.maxPacketBytes = maxPacketBytes
        self.routeKind = routeKind
        self.packetCapturePoint = packetCapturePoint
    }

    public static func parse(_ arguments: [String]) throws -> VideoTransportRunConfiguration {
        let allowed = [
            "--mode",
            "--stream-id",
            "--stream-count",
            "--visible-streams",
            "--source-role",
            "--peer",
            "--port",
            "--duration-seconds",
            "--output",
            "--width",
            "--height",
            "--pixel-format",
            "--frame-rate",
            "--queue-depth",
            "--max-packet-bytes",
            "--route-kind",
            "--packet-capture-point",
        ]
        var values: [String: String] = [:]
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            guard allowed.contains(argument) else {
                throw VideoTransportRunConfigurationError.unknownArgument(argument)
            }
            guard values[argument] == nil else {
                throw VideoTransportRunConfigurationError.duplicateArgument(argument)
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
                throw VideoTransportRunConfigurationError.missingValue(argument)
            }
            values[argument] = arguments[valueIndex]
            index += 2
        }

        let modeText = try requiredVideoTransportRunString("--mode", values)
        guard let mode = VideoTransportMode(rawValue: modeText) else {
            throw VideoTransportRunConfigurationError.invalidMode(modeText)
        }
        guard mode == .raw else {
            throw VideoTransportRunConfigurationError.unsupportedMode(modeText)
        }

        let routeKindText = values["--route-kind"] ?? VideoTransportRouteKind.localhost.rawValue
        guard let routeKind = VideoTransportRouteKind(rawValue: routeKindText) else {
            throw VideoTransportRunConfigurationError.invalidRouteKind(routeKindText)
        }
        let streamCount = try optionalVideoTransportRunPositiveInteger(
            "--stream-count",
            values,
            defaultValue: 1
        )
        guard streamCount <= Self.maximumStreamCount else {
            throw VideoTransportRunConfigurationError.tooManyStreams(
                requested: streamCount,
                maximum: Self.maximumStreamCount
            )
        }
        let visibleStreamCount = try optionalVideoTransportRunPositiveInteger(
            "--visible-streams",
            values,
            defaultValue: 1
        )
        guard visibleStreamCount <= streamCount else {
            throw VideoTransportRunConfigurationError.visibleStreamsExceedStreamCount(
                visible: visibleStreamCount,
                streamCount: streamCount
            )
        }

        return VideoTransportRunConfiguration(
            mode: mode,
            streamID: try optionalVideoTransportRunPositiveUInt32(
                "--stream-id",
                values,
                defaultValue: 100
            ),
            streamCount: streamCount,
            visibleStreamCount: visibleStreamCount,
            sourceRole: try optionalVideoTransportRunSourceRole(
                "--source-role",
                values,
                defaultValue: .testPattern
            ),
            peer: try requiredVideoTransportRunString("--peer", values),
            port: try requiredVideoTransportRunPort(values),
            durationSeconds: try requiredVideoTransportRunPositiveInteger("--duration-seconds", values),
            outputPath: try requiredVideoTransportRunString("--output", values),
            width: try optionalVideoTransportRunPositiveInteger("--width", values, defaultValue: 1_280),
            height: try optionalVideoTransportRunPositiveInteger("--height", values, defaultValue: 720),
            pixelFormat: values["--pixel-format"] ?? "synthetic-rgb",
            frameRate: try optionalVideoTransportRunPositiveDouble("--frame-rate", values, defaultValue: 30),
            queueDepth: try optionalVideoTransportRunPositiveInteger("--queue-depth", values, defaultValue: 1),
            maxPacketBytes: try optionalVideoTransportRunPositiveInteger(
                "--max-packet-bytes",
                values,
                defaultValue: RawVideoFrameTransport.defaultMaxPacketBytes
            ),
            routeKind: routeKind,
            packetCapturePoint: values["--packet-capture-point"] ?? "not-captured"
        )
    }
}

public enum VideoTransportRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case invalidDouble(argument: String, value: String)
    case nonPositiveArgument(String)
    case invalidPort(Int)
    case invalidMode(String)
    case invalidSourceRole(String)
    case unsupportedMode(String)
    case invalidRouteKind(String)
    case tooManyStreams(requested: Int, maximum: Int)
    case visibleStreamsExceedStreamCount(visible: Int, streamCount: Int)
}

public struct VideoTransmittedMetrics: Codable, Equatable, Sendable {
    public var framesSent: Int
    public var framesDroppedBeforeSend: Int
    public var packetsSent: Int
    public var packetsDropped: Int

    public init(
        framesSent: Int,
        framesDroppedBeforeSend: Int,
        packetsSent: Int,
        packetsDropped: Int
    ) {
        self.framesSent = framesSent
        self.framesDroppedBeforeSend = framesDroppedBeforeSend
        self.packetsSent = packetsSent
        self.packetsDropped = packetsDropped
    }
}

public struct VideoReceiverMetrics: Codable, Equatable, Sendable {
    public var queuePolicy: VideoQueuePolicy
    public var receivedFrames: Int
    public var displayedFrames: Int
    public var droppedFrames: Int
    public var lateFrames: Int
    public var observedQueueDepth: Int

    public init(
        queuePolicy: VideoQueuePolicy,
        receivedFrames: Int,
        displayedFrames: Int,
        droppedFrames: Int,
        lateFrames: Int,
        observedQueueDepth: Int
    ) {
        self.queuePolicy = queuePolicy
        self.receivedFrames = receivedFrames
        self.displayedFrames = displayedFrames
        self.droppedFrames = droppedFrames
        self.lateFrames = lateFrames
        self.observedQueueDepth = observedQueueDepth
    }
}

public struct VideoDegradationPolicy: Codable, Equatable, Sendable {
    public var actions: [VideoDegradationAction]
    public var triggeredBeforeAudioTargetChange: Bool
    public var triggeredBeforeAudioOrRouteImpact: Bool?

    public init(
        actions: [VideoDegradationAction],
        triggeredBeforeAudioTargetChange: Bool,
        triggeredBeforeAudioOrRouteImpact: Bool? = nil
    ) {
        self.actions = actions
        self.triggeredBeforeAudioTargetChange = triggeredBeforeAudioTargetChange
        self.triggeredBeforeAudioOrRouteImpact = triggeredBeforeAudioOrRouteImpact
    }
}

public enum VideoTransportValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case emptyList(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case unorderedFrameAge
    case unorderedAudioCallbackMetrics(String)
    case packetAccountingMismatch(expectedReceived: Int, actualReceived: Int)
    case receiverAccountingMismatch(expectedDisplayed: Int, actualDisplayed: Int)
    case passUsesReliableRetransmission
    case passWithoutPreAudioDegradation
    case passWithoutPreAudioOrRouteDegradation
    case passWithoutPhysicalRouteEvidence
    case passWithoutRawOrIntraFrameRouteBaseline
    case passWithoutFragmentationMetrics
    case passWithoutReassemblyMetrics
    case passWithOversizedFragmentPayload(payloadBytes: Int, maxPacketBytes: Int)
    case passWithFragmentedFrameMismatch(expected: Int, actual: Int)
    case passWithReassembledFrameMismatch(expected: Int, actual: Int)
    case passWithIncompleteReassembly
    case renderOutputAccountingMismatch(expectedMaximumOutput: Int, actualOutput: Int)
    case renderOutputDropAccountingMismatch(expectedMaximumSubmitted: Int, actualAccounted: Int)
    case duplicateMultiVideoStreamID(Int)
    case unknownMultiVideoSelectedStreamID(Int)
    case invalidMultiVideoLayout(String)
    case passWithoutRenderOutputMetrics
    case passWithoutRenderedOutputFrames
    case passWithRenderOutputDrops
    case passWithoutBlackmagicOutputEvidence
    case passWithNonPassBaselineRouteVerdict(MeasurementVerdict)
    case passChangesAudioRouteVerdict(baseline: MeasurementVerdict, videoActive: MeasurementVerdict)
    case passAllowsVideoToolboxFrameReordering
    case passWithoutVideoToolboxAvailability
    case passWithoutVideoToolboxRealtimeMode
    case passWithEncoderQueueDepth(Int)
    case passIncreasesAudioP99(baseline: Double, video: Double)
    case passIncreasesAudioMax(baseline: Double, video: Double)
    case passChangesAudioPlayoutTarget(baseline: Int, video: Int)
    case passWithUnderruns(Int)
    case passWithHiddenAudioImpact
    case passWithoutAVSyncTimingMetrics
}
