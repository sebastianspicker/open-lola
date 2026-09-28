// Retains the JPEG XS wire vocabulary while the reference codec is unavailable.
import Foundation

public enum JPEGXSReferenceCodecError: Error, Equatable, Sendable {
    case unavailable
    case invalidDimensions(width: Int, height: Int)
    case unsupportedPixelFormat(String)
    case payloadSizeMismatch(expected: Int, actual: Int)
    case encodeFailed
    case decodeFailed
    case decodedDimensionMismatch(expectedWidth: Int, expectedHeight: Int, actualWidth: Int, actualHeight: Int)
}

public enum JPEGXSReferenceCodec {
    public static let bitsPerPixel: Float = 4.0

    public static func encode(frame: RawCapturedVideoFrame) throws -> Data {
        throw JPEGXSReferenceCodecError.unavailable
    }

    public static func decode(codestream: Data, metadata: CapturedVideoFrame) throws -> RawCapturedVideoFrame {
        throw JPEGXSReferenceCodecError.unavailable
    }
}
