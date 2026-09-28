import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Inventories AVFoundation cameras, permissions, formats, and source-use policy for capture runs.
import Foundation

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
