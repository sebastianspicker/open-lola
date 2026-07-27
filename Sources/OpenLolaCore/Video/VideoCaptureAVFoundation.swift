// Inventories AVFoundation cameras, permissions, formats, and source-use policy for capture runs.
import Foundation
import Dispatch
#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
#endif

/// Reports the AVFoundation authorization state that permits or blocks camera capture.
public enum AVFoundationPermissionStatus: String, Codable, Equatable, Sendable {
    case authorized
    case denied
    case restricted
    case notDetermined
    case requestTimedOut
    case unknown
}

/// States whether an AVFoundation source may be used for synthetic, requested, or measured capture.
public enum AVFoundationVideoSourcePolicy: String, Codable, Equatable, Sendable {
    case genericAvFoundation
    case blackmagicFirstAvFoundationFallback
}

/// Describes `width`, `height`, `maxFrameRate`, and `pixelFormat` so video transport can select and identify a compatible source or format.
public struct AVFoundationVideoFormatDescription: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var maxFrameRate: Double
    public var pixelFormat: String

    public init(width: Int, height: Int, maxFrameRate: Double, pixelFormat: String) {
        self.width = width
        self.height = height
        self.maxFrameRate = maxFrameRate
        self.pixelFormat = pixelFormat
    }
}

/// Describes `label`, `uniqueId`, `modelId`, and `manufacturer` so video transport can select and identify a compatible source or format.
public struct AVFoundationVideoDeviceDescription: Codable, Equatable, Sendable {
    public var label: String
    public var uniqueId: String
    public var modelId: String
    public var manufacturer: String
    public var transport: String
    public var sourcePolicy: AVFoundationVideoSourcePolicy
    public var formats: [AVFoundationVideoFormatDescription]

    public init(
        label: String,
        uniqueId: String,
        modelId: String,
        manufacturer: String,
        transport: String,
        sourcePolicy: AVFoundationVideoSourcePolicy,
        formats: [AVFoundationVideoFormatDescription]
    ) {
        self.label = label
        self.uniqueId = uniqueId
        self.modelId = modelId
        self.manufacturer = manufacturer
        self.transport = transport
        self.sourcePolicy = sourcePolicy
        self.formats = formats
    }

    public var sourceKind: VideoSourceKind {
        .avFoundation
    }

    public var isExternalCaptureCandidate: Bool {
        sourcePolicy == .blackmagicFirstAvFoundationFallback
    }

    public static func make(
        label: String,
        uniqueId: String,
        modelId: String = "unknown",
        manufacturer: String = "unknown",
        transport: String = "unknown",
        formats: [AVFoundationVideoFormatDescription]
    ) -> AVFoundationVideoDeviceDescription {
        let policy = videoCaptureSourcePolicy(for: label)
        return AVFoundationVideoDeviceDescription(
            label: label,
            uniqueId: uniqueId,
            modelId: modelId,
            manufacturer: videoCaptureManufacturer(label: label, fallback: manufacturer),
            transport: transport,
            sourcePolicy: policy,
            formats: formats
        )
    }
}

/// Records `id`, `title`, `capturedAt`, and `permissionStatus` so video capture and frame transport measurements and verdicts can be checked after a run.
public struct AVFoundationVideoDeviceInventoryReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var permissionStatus: AVFoundationPermissionStatus
    public var devices: [AVFoundationVideoDeviceDescription]
    public var blackmagicSdkStatus: BlackmagicDesktopVideoSdkStatus
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        permissionStatus: AVFoundationPermissionStatus,
        devices: [AVFoundationVideoDeviceDescription],
        blackmagicSdkStatus: BlackmagicDesktopVideoSdkStatus,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.permissionStatus = permissionStatus
        self.devices = devices
        self.blackmagicSdkStatus = blackmagicSdkStatus
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try VideoCaptureValidator.requireNonEmpty(id, "id")
        try VideoCaptureValidator.requireNonEmpty(title, "title")
        try VideoCaptureValidator.requireNonEmpty(capturedAt, "capturedAt")
        try VideoCaptureValidator.requireNonEmpty(notes, "notes")
        for (index, device) in devices.enumerated() {
            try VideoCaptureValidator.requireNonEmpty(device.label, "devices[\(index)].label")
            try VideoCaptureValidator.requireNonEmpty(device.uniqueId, "devices[\(index)].uniqueId")
            try VideoCaptureValidator.requireNonEmpty(device.modelId, "devices[\(index)].modelId")
            try VideoCaptureValidator.requireNonEmpty(device.manufacturer, "devices[\(index)].manufacturer")
            try VideoCaptureValidator.requireNonEmpty(device.transport, "devices[\(index)].transport")
            for (formatIndex, format) in device.formats.enumerated() {
                try VideoCaptureValidator.requirePositive(
                    format.width,
                    "devices[\(index)].formats[\(formatIndex)].width"
                )
                try VideoCaptureValidator.requirePositive(
                    format.height,
                    "devices[\(index)].formats[\(formatIndex)].height"
                )
                try VideoCaptureValidator.requirePositive(
                    format.maxFrameRate,
                    "devices[\(index)].formats[\(formatIndex)].maxFrameRate"
                )
                try VideoCaptureValidator.requireNonEmpty(
                    format.pixelFormat,
                    "devices[\(index)].formats[\(formatIndex)].pixelFormat"
                )
            }
        }
    }
}

/// Reads AVFoundation camera devices and converts their permissions and formats into stable inventory data.
public struct AVFoundationVideoDeviceInventoryReader: Sendable {
    public init() {}

    public func capture() -> AVFoundationVideoDeviceInventoryReport {
        AVFoundationVideoDeviceInventoryReport(
            id: "m08-avfoundation-video-device-inventory",
            title: "AVFoundation video device inventory",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            permissionStatus: currentAVFoundationPermissionStatus(),
            devices: currentAVFoundationVideoDevices(),
            blackmagicSdkStatus: .notLinkedOptionalBoundary,
            verdict: .partial,
            notes: "Read-only AVFoundation inventory; Blackmagic Desktop Video SDK is optional and not linked."
        )
    }
}
