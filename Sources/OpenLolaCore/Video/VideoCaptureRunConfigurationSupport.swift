// Parses production-hardware and audio-impact fields with explicit maxima so optional capture evidence cannot bypass configuration checks.
import Foundation
import OpenLolaContracts

/// Preserves `hardwareKind`, `modelName`, `manufacturer`, and `connectionMethod` needed to distinguish measured video capture and frame transport behavior from configuration claims.
public struct ProductionVideoCaptureEvidenceInput: Codable, Equatable, Sendable {
    public var hardwareKind: ProductionVideoHardwareKind
    public var modelName: String
    public var manufacturer: String
    public var connectionMethod: ProductionVideoConnectionMethod
    public var desktopVideoSdkStatus: BlackmagicDesktopVideoSdkStatus
    public var desktopVideoSdkDecisionNotes: String

    public init(
        hardwareKind: ProductionVideoHardwareKind,
        modelName: String,
        manufacturer: String,
        connectionMethod: ProductionVideoConnectionMethod,
        desktopVideoSdkStatus: BlackmagicDesktopVideoSdkStatus,
        desktopVideoSdkDecisionNotes: String
    ) {
        self.hardwareKind = hardwareKind
        self.modelName = modelName
        self.manufacturer = manufacturer
        self.connectionMethod = connectionMethod
        self.desktopVideoSdkStatus = desktopVideoSdkStatus
        self.desktopVideoSdkDecisionNotes = desktopVideoSdkDecisionNotes
    }

    public func evidence(for source: VideoSourceDescription) -> ProductionVideoCaptureEvidence {
        ProductionVideoCaptureEvidence(
            hardware: .init(
                kind: hardwareKind,
                modelName: modelName,
                manufacturer: manufacturer,
                connectionMethod: connectionMethod
            ),
            discovery: .init(
                avFoundationVisible: source.kind == .avFoundation,
                deviceUniqueID: source.deviceUniqueId
            ),
            desktopSDK: .init(
                status: desktopVideoSdkStatus,
                decisionNotes: desktopVideoSdkDecisionNotes,
                atemReadOnlyControlReport: nil
            )
        )
    }
}

func optionalVideoCaptureVerdict(
    _ values: [String: String],
    defaultValue: MeasurementVerdict
) throws -> MeasurementVerdict {
    guard let value = values["--verdict"] else {
        return defaultValue
    }
    guard let verdict = MeasurementVerdict(rawValue: value.lowercased()) else {
        throw VideoCaptureRunConfigurationError.invalidVerdict(value)
    }
    return verdict
}

func optionalVideoCaptureAudioImpact(
    _ values: [String: String]
) throws -> VideoAudioImpactMetrics? {
    guard videoCaptureAudioImpactArguments.contains(where: { values[$0] != nil }) else {
        return nil
    }
    return try videoCaptureAudioImpactMetrics(values)
}

let videoCaptureAudioImpactArguments = [
    "--baseline-callback-p99-us",
    "--video-callback-p99-us",
    "--baseline-callback-max-us",
    "--video-callback-max-us",
    "--baseline-playout-target-frames",
    "--video-playout-target-frames",
    "--audio-underruns",
    "--hidden-audio-impact",
    "--audio-baseline-report-id"
]

func videoCaptureAudioImpactMetrics(
    _ values: [String: String]
) throws -> VideoAudioImpactMetrics {
    VideoAudioImpactMetrics(
        baselineCallbackP99Microseconds: try requiredVideoCaptureDouble(
            "--baseline-callback-p99-us",
            values
        ),
        videoCallbackP99Microseconds: try requiredVideoCaptureDouble(
            "--video-callback-p99-us",
            values
        ),
        baselineCallbackMaxMicroseconds: try requiredVideoCaptureDouble(
            "--baseline-callback-max-us",
            values
        ),
        videoCallbackMaxMicroseconds: try requiredVideoCaptureDouble(
            "--video-callback-max-us",
            values
        ),
        baselinePlayoutTargetFrames: try requiredVideoCaptureInteger(
            "--baseline-playout-target-frames",
            values
        ),
        videoPlayoutTargetFrames: try requiredVideoCaptureInteger(
            "--video-playout-target-frames",
            values
        ),
        underruns: try requiredVideoCaptureNonNegativeInteger("--audio-underruns", values),
        hiddenAudioImpactDetected: try requiredVideoCaptureBoolean(
            "--hidden-audio-impact",
            values
        ),
        baselineReportId: values["--audio-baseline-report-id"],
        synthetic: false
    )
}

func requireVideoCaptureMaximum(_ value: Int, _ argument: String, maximum: Int) throws {
    guard value <= maximum else {
        throw VideoCaptureRunConfigurationError.argumentExceedsMaximum(
            argument: argument,
            maximum: String(maximum)
        )
    }
}

func requireVideoCaptureMaximum(_ value: Double, _ argument: String, maximum: Double) throws {
    guard value <= maximum else {
        throw VideoCaptureRunConfigurationError.argumentExceedsMaximum(
            argument: argument,
            maximum: String(maximum)
        )
    }
}

func optionalProductionVideoCaptureEvidenceInput(
    _ values: [String: String]
) throws -> ProductionVideoCaptureEvidenceInput? {
    let arguments = [
        "--production-hardware",
        "--production-model",
        "--production-manufacturer",
        "--production-connection",
        "--desktop-video-sdk-status",
        "--desktop-video-sdk-notes"
    ]
    guard arguments.contains(where: { values[$0] != nil }) else {
        return nil
    }

    return ProductionVideoCaptureEvidenceInput(
        hardwareKind: try requiredProductionVideoHardwareKind("--production-hardware", values),
        modelName: try requiredVideoCaptureString("--production-model", values),
        manufacturer: try requiredVideoCaptureString("--production-manufacturer", values),
        connectionMethod: try requiredProductionVideoConnection(
            "--production-connection",
            values
        ),
        desktopVideoSdkStatus: try requiredDesktopVideoSdkStatus(
            "--desktop-video-sdk-status",
            values
        ),
        desktopVideoSdkDecisionNotes: try requiredVideoCaptureString(
            "--desktop-video-sdk-notes",
            values
        )
    )
}

func requiredVideoCaptureDouble(
    _ argument: String,
    _ values: [String: String]
) throws -> Double {
    let value = try requiredVideoCaptureString(argument, values)
    guard let double = Double(value) else {
        throw VideoCaptureRunConfigurationError.invalidDouble(argument: argument, value: value)
    }
    guard double > 0 else {
        throw VideoCaptureRunConfigurationError.nonPositiveArgument(argument)
    }
    return double
}

func requiredVideoCaptureNonNegativeInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int {
    let value = try requiredVideoCaptureString(argument, values)
    guard let integer = Int(value) else {
        throw VideoCaptureRunConfigurationError.invalidInteger(argument: argument, value: value)
    }
    guard integer >= 0 else {
        throw VideoCaptureRunConfigurationError.nonPositiveArgument(argument)
    }
    return integer
}

func optionalVideoCapturePositiveUInt32(
    _ argument: String,
    _ values: [String: String],
    defaultValue: UInt32
) throws -> UInt32 {
    guard let value = values[argument] else {
        return defaultValue
    }
    guard let integer = UInt32(value) else {
        throw VideoCaptureRunConfigurationError.invalidInteger(argument: argument, value: value)
    }
    guard integer > 0 else {
        throw VideoCaptureRunConfigurationError.nonPositiveArgument(argument)
    }
    return integer
}

func requiredVideoCaptureBoolean(
    _ argument: String,
    _ values: [String: String]
) throws -> Bool {
    guard let value = try optionalVideoCaptureBoolean(argument, values) else {
        throw VideoCaptureRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

func requiredProductionVideoHardwareKind(
    _ argument: String,
    _ values: [String: String]
) throws -> ProductionVideoHardwareKind {
    let value = try requiredVideoCaptureString(argument, values)
    switch value.lowercased() {
    case "atem":
        return .atem
    case "decklink", "deck-link", "deck_link":
        return .deckLink
    case "ultrastudio", "ultra-studio", "ultra_studio":
        return .ultraStudio
    case "blackmagic", "blackmagic-capture", "blackmagic_capture":
        return .blackmagicCapture
    case "generic", "generic-camera", "generic_camera":
        return .genericCamera
    default:
        throw VideoCaptureRunConfigurationError.invalidProductionHardware(value)
    }
}

func requiredProductionVideoConnection(
    _ argument: String,
    _ values: [String: String]
) throws -> ProductionVideoConnectionMethod {
    let value = try requiredVideoCaptureString(argument, values)
    switch value.lowercased() {
    case "usbuvc", "usb-uvc", "usb_uvc", "uvc", "usb":
        return .usbUvc
    case "thunderbolt":
        return .thunderbolt
    case "pcie", "pci-e", "pci":
        return .pcie
    case "unknown":
        return .unknown
    default:
        throw VideoCaptureRunConfigurationError.invalidProductionConnection(value)
    }
}

func requiredDesktopVideoSdkStatus(
    _ argument: String,
    _ values: [String: String]
) throws -> BlackmagicDesktopVideoSdkStatus {
    let value = try requiredVideoCaptureString(argument, values)
    switch value.lowercased() {
    case "notlinkedoptionalboundary", "not-linked", "not-linked-optional-boundary":
        return .notLinkedOptionalBoundary
    case "linked":
        return .linked
    case "unavailable":
        return .unavailable
    case "requiredaftermeasurement", "required-after-measurement":
        return .requiredAfterMeasurement
    default:
        throw VideoCaptureRunConfigurationError.invalidDesktopVideoSdkStatus(value)
    }
}

func videoCaptureRunNotes(configuration: VideoCaptureRunConfiguration) -> String {
    if configuration.requestedVerdict == .pass {
        return "Measured AVFoundation capture report with production hardware and "
            + "audio-impact evidence supplied by the run configuration."
    }
    if configuration.audioImpact != nil {
        return "Measured AVFoundation capture report with supplied audio-impact comparison; "
            + "production PASS remains gated by hardware evidence."
    }
    return "Video-only AVFoundation capture report; PASS requires later production hardware and audio-impact evidence."
}

func videoFrameRate(from nominalFrameRate: Double) -> VideoFrameRate {
    let rounded = Int(nominalFrameRate.rounded(.toNearestOrAwayFromZero))
    return VideoFrameRate(numerator: max(1, rounded), denominator: 1)
}
