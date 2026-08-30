// Calculates safe frame dimensions and payload sizes for video packetization and rendering.
import Foundation

/// Reports `invalidPositiveField`, `byteCountOverflow`, and `byteCountTooLarge` failures that stop invalid video capture and frame transport work before it reaches a live path.
public enum MediaGeometrySizingError: Error, Equatable, Sendable {
    case invalidPositiveField(String, Int)
    case byteCountOverflow(String)
    case byteCountTooLarge(field: String, actual: Int, max: Int)
}

/// Calculates frame byte counts and geometry while rejecting invalid or overflowing dimensions.
public enum MediaGeometrySizing {
    public static func rawFrameByteCount(
        width: Int,
        height: Int,
        bytesPerPixel: Int,
        maxByteCount: Int? = nil,
        field: String = "rawVideoFrameBytes"
    ) throws -> Int {
        try requirePositive(width, "width")
        try requirePositive(height, "height")
        try requirePositive(bytesPerPixel, "bytesPerPixel")
        let pixels = try checkedProduct(width, height, field: field)
        let byteCount = try checkedProduct(pixels, bytesPerPixel, field: field)
        if let maxByteCount, byteCount > maxByteCount {
            throw MediaGeometrySizingError.byteCountTooLarge(
                field: field,
                actual: byteCount,
                max: maxByteCount
            )
        }
        return byteCount
    }

    public static func rawFrameByteCountForBitsPerPixel(
        width: Int,
        height: Int,
        bitsPerPixel: Int,
        maxByteCount: Int? = nil,
        field: String = "rawVideoFrameBytes"
    ) throws -> Int {
        try requirePositive(bitsPerPixel, "bitsPerPixel")
        let pixelCount = try checkedProduct(width, height, field: field)
        let totalBits = try checkedProduct(pixelCount, bitsPerPixel, field: field)
        let biasedBits = totalBits.addingReportingOverflow(7)
        guard !biasedBits.overflow else {
            throw MediaGeometrySizingError.byteCountOverflow(field)
        }
        let byteCount = max(1, biasedBits.partialValue / 8)
        if let maxByteCount, byteCount > maxByteCount {
            throw MediaGeometrySizingError.byteCountTooLarge(
                field: field,
                actual: byteCount,
                max: maxByteCount
            )
        }
        return byteCount
    }

    public static func clampedRawFrameByteCount(
        width: Int,
        height: Int,
        bytesPerPixel: Int
    ) -> Int {
        (try? rawFrameByteCount(width: width, height: height, bytesPerPixel: bytesPerPixel)) ?? Int.max
    }

    public static func clampedRawFrameByteCountForBitsPerPixel(
        width: Int,
        height: Int,
        bitsPerPixel: Int
    ) -> Int {
        (try? rawFrameByteCountForBitsPerPixel(
            width: width,
            height: height,
            bitsPerPixel: bitsPerPixel
        )) ?? Int.max
    }

    private static func requirePositive(_ value: Int, _ field: String) throws {
        guard value > 0 else {
            throw MediaGeometrySizingError.invalidPositiveField(field, value)
        }
    }

    private static func checkedProduct(_ lhs: Int, _ rhs: Int, field: String) throws -> Int {
        let product = lhs.multipliedReportingOverflow(by: rhs)
        guard !product.overflow else {
            throw MediaGeometrySizingError.byteCountOverflow(field)
        }
        return product.partialValue
    }
}
