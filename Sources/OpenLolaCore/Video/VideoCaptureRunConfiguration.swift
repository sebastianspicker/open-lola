// Parses and bounds capture device, duration, frame-rate, format, and output options before AVFoundation resources are opened.
import Foundation
import OpenLolaContracts

/// Reports `missingRequiredArgument`, `missingValue`, `unknownArgument`, and `duplicateArgument` failures that stop invalid video capture and frame transport work before it reaches a live path.
public enum VideoCaptureRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidVerdict(String)
    case invalidInteger(argument: String, value: String)
    case invalidDouble(argument: String, value: String)
    case invalidBoolean(argument: String, value: String)
    case invalidProductionHardware(String)
    case invalidProductionConnection(String)
    case invalidDesktopVideoSdkStatus(String)
    case nonPositiveArgument(String)
    case argumentExceedsMaximum(argument: String, maximum: String)
}

/// Binds `deviceUniqueId`, `streamID`, `durationSeconds`, and `queueDepth` before video capture and frame transport starts, preventing implicit runtime defaults.
public struct VideoCaptureRunConfiguration: Codable, Equatable, Sendable {
    public static let maximumDurationSeconds = 3_600
    public static let maximumRequestedFrameRate = 240.0

    public var deviceUniqueId: String?
    public var streamID: UInt32
    public var durationSeconds: Int
    public var queueDepth: Int
    public var requestedFrameRate: Double
    public var requestedVerdict: MeasurementVerdict
    public var audioImpact: VideoAudioImpactMetrics?
    public var productionEvidence: ProductionVideoCaptureEvidenceInput?
    public var outputPath: String

    public struct CaptureInput: Equatable, Sendable {
        public var deviceUniqueId: String?
        public var streamID: UInt32
        public var durationSeconds: Int
        public var queueDepth: Int
        public var requestedFrameRate: Double

        public init(
            deviceUniqueId: String?,
            streamID: UInt32 = 100,
            durationSeconds: Int,
            queueDepth: Int = 1,
            requestedFrameRate: Double = 30
        ) {
            self.deviceUniqueId = deviceUniqueId
            self.streamID = streamID
            self.durationSeconds = durationSeconds
            self.queueDepth = queueDepth
            self.requestedFrameRate = requestedFrameRate
        }
    }

    public struct EvidenceInput: Equatable, Sendable {
        public var requestedVerdict: MeasurementVerdict
        public var audioImpact: VideoAudioImpactMetrics?
        public var productionEvidence: ProductionVideoCaptureEvidenceInput?

        public init(
            requestedVerdict: MeasurementVerdict = .partial,
            audioImpact: VideoAudioImpactMetrics? = nil,
            productionEvidence: ProductionVideoCaptureEvidenceInput? = nil
        ) {
            self.requestedVerdict = requestedVerdict
            self.audioImpact = audioImpact
            self.productionEvidence = productionEvidence
        }
    }

    public init(
        capture: CaptureInput,
        evidence: EvidenceInput = EvidenceInput(),
        outputPath: String
    ) {
        deviceUniqueId = capture.deviceUniqueId
        streamID = capture.streamID
        durationSeconds = capture.durationSeconds
        queueDepth = capture.queueDepth
        requestedFrameRate = capture.requestedFrameRate
        requestedVerdict = evidence.requestedVerdict
        audioImpact = evidence.audioImpact
        productionEvidence = evidence.productionEvidence
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> VideoCaptureRunConfiguration {
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: videoCaptureRunAllowedArguments,
            allowsDashPrefixedValues: false,
            unknown: VideoCaptureRunConfigurationError.unknownArgument,
            duplicate: VideoCaptureRunConfigurationError.duplicateArgument,
            missingValue: VideoCaptureRunConfigurationError.missingValue
        )
        return try configuration(from: values)
    }

    private static func configuration(
        from values: [String: String]
    ) throws -> VideoCaptureRunConfiguration {
        let device = try requiredVideoCaptureString("--device-id", values)
        let durationSeconds = try boundedVideoCaptureDuration(values)
        let requestedFrameRate = try boundedVideoCaptureFrameRate(values)
        return VideoCaptureRunConfiguration(
            capture: CaptureInput(
                deviceUniqueId: device == "auto" ? nil : device,
                streamID: try optionalVideoCapturePositiveUInt32(
                    "--stream-id",
                    values,
                    defaultValue: 100
                ),
                durationSeconds: durationSeconds,
                queueDepth: try optionalVideoCaptureInteger("--queue-depth", values, defaultValue: 1),
                requestedFrameRate: requestedFrameRate
            ),
            evidence: EvidenceInput(
                requestedVerdict: try optionalVideoCaptureVerdict(values, defaultValue: .partial),
                audioImpact: try optionalVideoCaptureAudioImpact(values),
                productionEvidence: try optionalProductionVideoCaptureEvidenceInput(values)
            ),
            outputPath: try requiredVideoCaptureString("--output", values)
        )
    }
}

private let videoCaptureRunAllowedArguments: Set<String> = [
    "--device-id",
    "--stream-id",
    "--duration-seconds",
    "--queue-depth",
    "--frame-rate",
    "--baseline-callback-p99-us",
    "--video-callback-p99-us",
    "--baseline-callback-max-us",
    "--video-callback-max-us",
    "--baseline-playout-target-frames",
    "--video-playout-target-frames",
    "--audio-underruns",
    "--hidden-audio-impact",
    "--audio-baseline-report-id",
    "--production-hardware",
    "--production-model",
    "--production-manufacturer",
    "--production-connection",
    "--desktop-video-sdk-status",
    "--desktop-video-sdk-notes",
    "--verdict",
    "--output"
]

private func boundedVideoCaptureDuration(_ values: [String: String]) throws -> Int {
    let durationSeconds = try requiredVideoCaptureInteger("--duration-seconds", values)
    try requireVideoCaptureMaximum(
        durationSeconds,
        "--duration-seconds",
        maximum: VideoCaptureRunConfiguration.maximumDurationSeconds
    )
    return durationSeconds
}

private func boundedVideoCaptureFrameRate(_ values: [String: String]) throws -> Double {
    let requestedFrameRate = try optionalVideoCaptureDouble(
        "--frame-rate",
        values,
        defaultValue: 30
    )
    try requireVideoCaptureMaximum(
        requestedFrameRate,
        "--frame-rate",
        maximum: VideoCaptureRunConfiguration.maximumRequestedFrameRate
    )
    return requestedFrameRate
}
