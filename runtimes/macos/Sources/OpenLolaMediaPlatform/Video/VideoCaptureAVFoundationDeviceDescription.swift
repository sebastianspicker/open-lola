// Describes AVFoundation camera devices, formats, and source-use policy shared by capture and Integrations connectors.
import Foundation

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

public func videoCaptureSourcePolicy(for label: String) -> AVFoundationVideoSourcePolicy {
    let normalized = label.lowercased()
    let externalTokens = ["atem", "uvc", "decklink", "deck link", "ultrastudio", "blackmagic", "capture"]
    if externalTokens.contains(where: { normalized.contains($0) }) {
        return .blackmagicFirstAvFoundationFallback
    }
    return .genericAvFoundation
}

public func videoCaptureManufacturer(label: String, fallback: String) -> String {
    let normalized = label.lowercased()
    if normalized.contains("atem")
        || normalized.contains("decklink")
        || normalized.contains("ultrastudio")
        || normalized.contains("blackmagic") {
        return "Blackmagic Design"
    }
    return fallback
}

public func preferredAVFoundationVideoDevice(
    from devices: [AVFoundationVideoDeviceDescription]
) -> AVFoundationVideoDeviceDescription? {
    devices.first(where: \.isExternalCaptureCandidate) ?? devices.first
}

public func videoCaptureFourCCString(_ code: FourCharCode) -> String {
    let bytes = [
        UInt8((code >> 24) & 0xff),
        UInt8((code >> 16) & 0xff),
        UInt8((code >> 8) & 0xff),
        UInt8(code & 0xff)
    ]
    if bytes.allSatisfy({ $0 >= 32 && $0 <= 126 }) {
        return String(bytes: bytes, encoding: .ascii) ?? "\(code)"
    }
    return "\(code)"
}
