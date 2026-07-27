// Implements JPEGXSReferenceCodec encoding and decoding, keeping wire representation apart from transport lifetime.
import Foundation
import CJpegXSReference

/// Reports `invalidDimensions`, `unsupportedPixelFormat`, `payloadSizeMismatch`, and `encodeFailed` failures that stop invalid video capture and frame transport work before it reaches a live path.
public enum JPEGXSReferenceCodecError: Error, Equatable, Sendable {
    case invalidDimensions(width: Int, height: Int)
    case unsupportedPixelFormat(String)
    case payloadSizeMismatch(expected: Int, actual: Int)
    case encodeFailed
    case decodeFailed
    case decodedDimensionMismatch(expectedWidth: Int, expectedHeight: Int, actualWidth: Int, actualHeight: Int)
}

/// Adapts raw frame payloads to the JPEG XS reference-codec boundary used for validation.
public enum JPEGXSReferenceCodec {
    public static let bitsPerPixel: Float = 4.0

    public static func encode(frame: RawCapturedVideoFrame) throws -> Data {
        let metadata = frame.metadata
        guard directPeerNormalizedVideoPixelFormat(metadata.pixelFormat) == "bgra8" else {
            throw JPEGXSReferenceCodecError.unsupportedPixelFormat(metadata.pixelFormat)
        }
        guard let width = CInt(exactly: metadata.width),
              let height = CInt(exactly: metadata.height),
              width > 0,
              height > 0 else {
            throw JPEGXSReferenceCodecError.invalidDimensions(width: metadata.width, height: metadata.height)
        }
        let expected = metadata.width * metadata.height * 4
        guard frame.payload.count == expected else {
            throw JPEGXSReferenceCodecError.payloadSizeMismatch(expected: expected, actual: frame.payload.count)
        }

        var output: UnsafeMutablePointer<UInt8>?
        var outputSize = 0
        let encoded = frame.payload.withUnsafeBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return false
            }
            return open_lola_jxs_encode_bgra8(
                baseAddress,
                width,
                height,
                bitsPerPixel,
                &output,
                &outputSize
            )
        }
        guard encoded, let output, outputSize > 0 else {
            throw JPEGXSReferenceCodecError.encodeFailed
        }
        defer { open_lola_jxs_free(output) }
        return Data(bytes: output, count: outputSize)
    }

    public static func decode(codestream: Data, metadata: CapturedVideoFrame) throws -> RawCapturedVideoFrame {
        guard !codestream.isEmpty else {
            throw JPEGXSReferenceCodecError.decodeFailed
        }
        var output: UnsafeMutablePointer<UInt8>?
        var width: CInt = 0
        var height: CInt = 0
        let decoded = codestream.withUnsafeBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return false
            }
            return open_lola_jxs_decode_bgra8(
                baseAddress,
                codestream.count,
                &output,
                &width,
                &height
            )
        }
        guard decoded, let output, width > 0, height > 0 else {
            throw JPEGXSReferenceCodecError.decodeFailed
        }
        defer { open_lola_jxs_free(output) }
        let decodedWidth = Int(width)
        let decodedHeight = Int(height)
        guard decodedWidth == metadata.width, decodedHeight == metadata.height else {
            throw JPEGXSReferenceCodecError.decodedDimensionMismatch(
                expectedWidth: metadata.width,
                expectedHeight: metadata.height,
                actualWidth: decodedWidth,
                actualHeight: decodedHeight
            )
        }
        var decodedMetadata = metadata
        decodedMetadata.pixelFormat = "bgra8"
        return RawCapturedVideoFrame(
            metadata: decodedMetadata,
            payload: Data(bytes: output, count: decodedWidth * decodedHeight * 4)
        )
    }
}
