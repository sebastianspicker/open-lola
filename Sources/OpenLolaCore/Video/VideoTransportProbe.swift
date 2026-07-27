// Implements VideoTransportProbe media transport boundary, separating packet I/O from session policy.
import Foundation
/// Defines `raw`, `intraFrame`, `videoToolboxH264`, and `videoToolboxHevc` states used to make video transport mode decisions in video capture and frame transport.
public enum VideoTransportMode: String, Codable, Equatable, Sendable {
    case raw
    case intraFrame
    case videoToolboxH264
    case videoToolboxHevc
}
/// Defines `dropFrame`, `reduceFrameRate`, `reduceQuality`, and `reduceResolution` states used to make video degradation action decisions in video capture and frame transport.
public enum VideoDegradationAction: String, Codable, Equatable, Sendable {
    case dropFrame
    case reduceFrameRate
    case reduceQuality
    case reduceResolution
    case disableVideo
}
/// Defines `mode`, `networkProtocol`, `payloadFormat`, and `reliableRetransmission` used to model impairment during video transport tests.
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
}
/// Defines `syntheticLocal`, `localhost`, `directWired`, and `switched` states used to make video transport route kind decisions in video capture and frame transport.
public enum VideoTransportRouteKind: String, Codable, Equatable, Sendable {
    case syntheticLocal
    case localhost
    case directWired
    case switched
    case campus
}
/// Preserves `routeKind`, `routeLabel`, `packetCapturePoint`, and `rawOrIntraFrameBaselineReportId` needed to distinguish measured video capture and frame transport behavior from configuration claims.
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
/// Binds `mode`, `streamID`, `streamCount`, and `visibleStreamCount` before video capture and frame transport starts, preventing implicit runtime defaults.
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
    public struct Input: Equatable, Sendable {
        public var mode: VideoTransportMode
        public var streamID: UInt32 = 100
        public var streamCount: Int = 1
        public var visibleStreamCount: Int = 1
        public var sourceRole: VideoStreamRole = .testPattern
        public var peer: String
        public var port: UInt16
        public var durationSeconds: Int
        public var outputPath: String
        public var width: Int = 1_280
        public var height: Int = 720
        public var pixelFormat: String = "synthetic-rgb"
        public var frameRate: Double = 30
        public var queueDepth: Int = 1
        public var maxPacketBytes: Int = RawVideoFrameTransport.defaultMaxPacketBytes
        public var routeKind: VideoTransportRouteKind = .localhost
        public var packetCapturePoint: String = "not-captured"

        public struct Connection: Equatable, Sendable {
            public var peer: String
            public var port: UInt16
            public var durationSeconds: Int
            public var outputPath: String

            public init(peer: String, port: UInt16, durationSeconds: Int, outputPath: String) {
                self.peer = peer
                self.port = port
                self.durationSeconds = durationSeconds
                self.outputPath = outputPath
            }
        }

        public struct Stream: Equatable, Sendable {
            public var id: UInt32
            public var count: Int
            public var visibleCount: Int
            public var sourceRole: VideoStreamRole

            public init(
                id: UInt32 = 100,
                count: Int = 1,
                visibleCount: Int = 1,
                sourceRole: VideoStreamRole = .testPattern
            ) {
                self.id = id
                self.count = count
                self.visibleCount = visibleCount
                self.sourceRole = sourceRole
            }
        }

        public struct Frame: Equatable, Sendable {
            public var width: Int
            public var height: Int
            public var pixelFormat: String
            public var frameRate: Double
            public var queueDepth: Int
            public var maxPacketBytes: Int

            public init(
                width: Int = 1_280,
                height: Int = 720,
                pixelFormat: String = "synthetic-rgb",
                frameRate: Double = 30,
                queueDepth: Int = 1,
                maxPacketBytes: Int = RawVideoFrameTransport.defaultMaxPacketBytes
            ) {
                self.width = width
                self.height = height
                self.pixelFormat = pixelFormat
                self.frameRate = frameRate
                self.queueDepth = queueDepth
                self.maxPacketBytes = maxPacketBytes
            }
        }

        public struct Route: Equatable, Sendable {
            public var kind: VideoTransportRouteKind
            public var packetCapturePoint: String

            public init(
                kind: VideoTransportRouteKind = .localhost,
                packetCapturePoint: String = "not-captured"
            ) {
                self.kind = kind
                self.packetCapturePoint = packetCapturePoint
            }
        }

        public init(
            mode: VideoTransportMode,
            connection: Connection,
            stream: Stream = Stream(),
            frame: Frame = Frame(),
            route: Route = Route()
        ) {
            self.mode = mode
            streamID = stream.id
            streamCount = stream.count
            visibleStreamCount = stream.visibleCount
            sourceRole = stream.sourceRole
            peer = connection.peer
            port = connection.port
            durationSeconds = connection.durationSeconds
            outputPath = connection.outputPath
            width = frame.width
            height = frame.height
            pixelFormat = frame.pixelFormat
            frameRate = frame.frameRate
            queueDepth = frame.queueDepth
            maxPacketBytes = frame.maxPacketBytes
            routeKind = route.kind
            packetCapturePoint = route.packetCapturePoint
        }
    }

    public init(_ input: Input) {
        self.mode = input.mode
        self.streamID = input.streamID
        self.streamCount = input.streamCount
        self.visibleStreamCount = input.visibleStreamCount
        self.sourceRole = input.sourceRole
        self.peer = input.peer
        self.port = input.port
        self.durationSeconds = input.durationSeconds
        self.outputPath = input.outputPath
        self.width = input.width
        self.height = input.height
        self.pixelFormat = input.pixelFormat
        self.frameRate = input.frameRate
        self.queueDepth = input.queueDepth
        self.maxPacketBytes = input.maxPacketBytes
        self.routeKind = input.routeKind
        self.packetCapturePoint = input.packetCapturePoint
    }
    public static func parse(_ arguments: [String]) throws -> VideoTransportRunConfiguration {
        let values = try videoTransportRunArgumentValues(arguments)
        return try videoTransportRunConfiguration(
            values: values,
            mode: videoTransportRunMode(values),
            routeKind: videoTransportRunRouteKind(values),
            streams: videoTransportRunStreamCounts(values)
        )
    }
}
private struct VideoTransportRunStreamCounts {
    var streamCount: Int
    var visibleStreamCount: Int
}
private let videoTransportRunAllowedArguments: Set<String> = [
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
    "--packet-capture-point"
]
private func videoTransportRunArgumentValues(_ arguments: [String]) throws -> [String: String] {
    try KeyValueArgumentParser.parseValues(
        arguments,
        allowed: videoTransportRunAllowedArguments,
        allowsDashPrefixedValues: false,
        unknown: VideoTransportRunConfigurationError.unknownArgument,
        duplicate: VideoTransportRunConfigurationError.duplicateArgument,
        missingValue: VideoTransportRunConfigurationError.missingValue
    )
}
private func videoTransportRunMode(_ values: [String: String]) throws -> VideoTransportMode {
    let modeText = try requiredVideoTransportRunString("--mode", values)
    guard let mode = VideoTransportMode(rawValue: modeText) else {
        throw VideoTransportRunConfigurationError.invalidMode(modeText)
    }
    guard mode == .raw else {
        throw VideoTransportRunConfigurationError.unsupportedMode(modeText)
    }
    return mode
}
private func videoTransportRunRouteKind(
    _ values: [String: String]
) throws -> VideoTransportRouteKind {
    let text = values["--route-kind"] ?? VideoTransportRouteKind.localhost.rawValue
    guard let routeKind = VideoTransportRouteKind(rawValue: text) else {
        throw VideoTransportRunConfigurationError.invalidRouteKind(text)
    }
    return routeKind
}
private func videoTransportRunStreamCounts(
    _ values: [String: String]
) throws -> VideoTransportRunStreamCounts {
    let streamCount = try optionalVideoTransportRunPositiveInteger(
        "--stream-count",
        values,
        defaultValue: 1
    )
    guard streamCount <= VideoTransportRunConfiguration.maximumStreamCount else {
        throw VideoTransportRunConfigurationError.tooManyStreams(
            requested: streamCount,
            maximum: VideoTransportRunConfiguration.maximumStreamCount
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
    return VideoTransportRunStreamCounts(
        streamCount: streamCount,
        visibleStreamCount: visibleStreamCount
    )
}
private func videoTransportRunConfiguration(
    values: [String: String],
    mode: VideoTransportMode,
    routeKind: VideoTransportRouteKind,
    streams: VideoTransportRunStreamCounts
) throws -> VideoTransportRunConfiguration {
    VideoTransportRunConfiguration(
        VideoTransportRunConfiguration.Input(
            mode: mode,
            connection: try videoTransportRunConnection(values),
            stream: try videoTransportRunStream(values, streams: streams),
            frame: try videoTransportRunFrame(values),
            route: videoTransportRunRoute(values, kind: routeKind)
        )
    )
}

private func videoTransportRunConnection(
    _ values: [String: String]
) throws -> VideoTransportRunConfiguration.Input.Connection {
    VideoTransportRunConfiguration.Input.Connection(
        peer: try requiredVideoTransportRunString("--peer", values),
        port: try requiredVideoTransportRunPort(values),
        durationSeconds: try requiredVideoTransportRunPositiveInteger("--duration-seconds", values),
        outputPath: try requiredVideoTransportRunString("--output", values)
    )
}

private func videoTransportRunStream(
    _ values: [String: String],
    streams: VideoTransportRunStreamCounts
) throws -> VideoTransportRunConfiguration.Input.Stream {
    VideoTransportRunConfiguration.Input.Stream(
        id: try optionalVideoTransportRunPositiveUInt32("--stream-id", values, defaultValue: 100),
        count: streams.streamCount,
        visibleCount: streams.visibleStreamCount,
        sourceRole: try optionalVideoTransportRunSourceRole(
            "--source-role",
            values,
            defaultValue: .testPattern
        )
    )
}

private func videoTransportRunFrame(
    _ values: [String: String]
) throws -> VideoTransportRunConfiguration.Input.Frame {
    VideoTransportRunConfiguration.Input.Frame(
        width: try optionalVideoTransportRunPositiveInteger("--width", values, defaultValue: 1_280),
        height: try optionalVideoTransportRunPositiveInteger("--height", values, defaultValue: 720),
        pixelFormat: values["--pixel-format"] ?? "synthetic-rgb",
        frameRate: try optionalVideoTransportRunPositiveDouble("--frame-rate", values, defaultValue: 30),
        queueDepth: try optionalVideoTransportRunPositiveInteger("--queue-depth", values, defaultValue: 1),
        maxPacketBytes: try optionalVideoTransportRunPositiveInteger(
            "--max-packet-bytes",
            values,
            defaultValue: RawVideoFrameTransport.defaultMaxPacketBytes
        )
    )
}

private func videoTransportRunRoute(
    _ values: [String: String],
    kind: VideoTransportRouteKind
) -> VideoTransportRunConfiguration.Input.Route {
    VideoTransportRunConfiguration.Input.Route(
        kind: kind,
        packetCapturePoint: values["--packet-capture-point"] ?? "not-captured"
    )
}
/// Reports `missingRequiredArgument`, `missingValue`, `unknownArgument`, and `duplicateArgument` failures that stop invalid video capture and frame transport work before it reaches a live path.
public enum VideoTransportRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidMode(String)
    case invalidInteger(argument: String, value: String)
    case invalidDouble(argument: String, value: String)
    case nonPositiveArgument(String)
    case invalidPort(Int)
    case invalidSourceRole(String)
    case unsupportedMode(String)
    case invalidRouteKind(String)
    case tooManyStreams(requested: Int, maximum: Int)
    case visibleStreamsExceedStreamCount(visible: Int, streamCount: Int)
}
/// Tracks `framesSent`, `framesDroppedBeforeSend`, `packetsSent`, and `packetsDropped` to expose latency, pressure, and delivery outcomes in video capture and frame transport.
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
/// Tracks `queuePolicy`, `receivedFrames`, `displayedFrames`, and `droppedFrames` to expose latency, pressure, and delivery outcomes in video capture and frame transport.
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
/// Constrains `actions`, `triggeredBeforeAudioTargetChange`, and `triggeredBeforeAudioOrRouteImpact` so video capture and frame transport tradeoffs remain explicit and testable.
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

/// Reports `emptyField`, `emptyList`, `nonPositiveField`, and `negativeField` failures that stop invalid video capture and frame transport work before it reaches a live path.
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
    case passWithoutTransmittedFrames
    case passWithTransportDrops(frames: Int, packets: Int)
    case passWithOversizedFragmentPayload(payloadBytes: Int, maxPacketBytes: Int)
    case passWithFragmentedFrameMismatch(expected: Int, actual: Int)
    case passWithReassembledFrameMismatch(expected: Int, actual: Int)
    case passWithIncompleteReassembly
    case renderOutputAccountingMismatch(expectedMaximumOutput: Int, actualOutput: Int)
    case renderOutputDropAccountingMismatch(expectedMaximumSubmitted: Int, actualAccounted: Int)
    case duplicateMultiVideoStreamID(Int)
    case unknownMultiVideoSelectedStreamID(Int)
    case invalidMultiVideoLayout(String)
    case invalidMultiVideoAudioPriorityEvidence
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
    case passWithoutMeasuredAudioPriorityProtection
    case passWithUnprotectedAudioPriority
    case passWithoutAVSyncTimingMetrics
}

extension VideoTransportValidationError: ValidationEmptyFieldError {}
extension VideoTransportValidationError: ValidationNonPositiveFieldError {}
extension VideoTransportValidationError: ValidationNegativeFieldError {}
extension VideoTransportValidationError: ValidationNonFiniteFieldError {}
