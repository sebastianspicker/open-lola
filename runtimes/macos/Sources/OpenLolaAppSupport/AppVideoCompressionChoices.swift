// Decides which video-compression choices the app offers, so a build without JPEG XS never shows or falls back to it.
import Foundation
import OpenLolaCore

/// Pure rules for the direct-peer video-compression choice, parameterised on whether JPEG XS is built in.
enum AppVideoCompressionChoices {
    /// The compressions a picker may offer; JPEG XS is listed only when the build contains it.
    static func selectable(
        jpegXSAvailable: Bool = JPEGXSReferenceCodec.isAvailable
    ) -> [DirectPeerSessionVideoCompression] {
        jpegXSAvailable ? [.raw, .jpegXS] : [.raw]
    }

    /// The compression used when a stored or drafted value is missing, unknown or not offered by this build.
    static func fallback(
        jpegXSAvailable: Bool = JPEGXSReferenceCodec.isAvailable
    ) -> DirectPeerSessionVideoCompression {
        jpegXSAvailable ? .jpegXS : .raw
    }

    /// Maps a stored raw value to an offered compression, falling back when it is unknown or unavailable.
    static func resolved(
        rawValue: String,
        jpegXSAvailable: Bool = JPEGXSReferenceCodec.isAvailable
    ) -> DirectPeerSessionVideoCompression {
        guard let parsed = DirectPeerSessionVideoCompression(rawValue: rawValue),
              selectable(jpegXSAvailable: jpegXSAvailable).contains(parsed) else {
            return fallback(jpegXSAvailable: jpegXSAvailable)
        }
        return parsed
    }

    /// Operator-facing picker label.
    static func label(_ compression: DirectPeerSessionVideoCompression) -> String {
        switch compression {
        case .raw: "Raw"
        case .jpegXS: "JPEG XS"
        }
    }
}
