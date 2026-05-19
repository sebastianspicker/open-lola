import Foundation

public struct UltraGridFourCC: Codable, Equatable, Sendable {
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public init(_ text: String) throws {
        let bytes = Array(text.utf8)
        guard bytes.count == 4 else {
            throw UltraGridCompatibilityError.unsupportedMode("fourcc-\(text)")
        }
        rawValue = UInt32(bytes[0]) << 24
            | UInt32(bytes[1]) << 16
            | UInt32(bytes[2]) << 8
            | UInt32(bytes[3])
    }
}

public enum UltraGridMediaFormatRegistry {
    public static let rgb24 = try! UltraGridFourCC("RGB3")
    public static let rgba = try! UltraGridFourCC("RGBA")
    public static let uyvy = try! UltraGridFourCC("UYVY")
    public static let v210 = try! UltraGridFourCC("v210")

    public static func rawVideoFourCC(bitsPerPixel: Int) throws -> UltraGridFourCC {
        switch bitsPerPixel {
        case 8, 24:
            return rgb24
        case 32:
            return rgba
        default:
            throw UltraGridCompatibilityError.unsupportedMode("raw-video-\(bitsPerPixel)bpp")
        }
    }
}
