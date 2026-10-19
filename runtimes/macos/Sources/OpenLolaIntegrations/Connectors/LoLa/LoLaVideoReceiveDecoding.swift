// Reassembles received LoLa video fragments into frame payloads and converts the negotiated payload to BGRA.
import CoreGraphics
import Foundation
import ImageIO
import OpenLolaMediaPlatform

/// How the RX side interprets a reassembled LoLa video payload. The format
/// follows the QUICKCONN tuple both peers agreed on (COMP, BPP, BAYER).
public enum LoLaReceivedVideoFormat: String, Codable, Equatable, Sendable {
    /// COMP 0, BPP 8, BAYER 0: one grey byte per pixel (GREY/Mono8).
    case mono8
    /// COMP 0, BPP 8, BAYER != 0: a Bayer mosaic. The pattern is not part of
    /// QUICKCONN, so the preview shows the undemosaiced mosaic as grey.
    case bayer8
    /// COMP 0, BPP 24: packed R, G, B bytes.
    case rgb24
    /// COMP 1: one complete JPEG image per frame.
    case jpeg

    /// The format for the negotiated tuple, or nil when the RX side cannot display it.
    public static func negotiated(
        compression: Int,
        bitsPerPixel: Int,
        bayer: Int
    ) -> LoLaReceivedVideoFormat? {
        switch (compression, bitsPerPixel) {
        case (1, _): return .jpeg
        case (0, 8): return bayer == 0 ? .mono8 : .bayer8
        case (0, 24): return .rgb24
        default: return nil
        }
    }
}

/// Errors that keep one received frame off the preview; the session continues.
enum LoLaReceivedVideoDecodeError: Error, Equatable, CustomStringConvertible {
    case payloadSizeMismatch(expected: Int, actual: Int)
    case jpegDecodeFailed
    /// The payload is an image of another type (named by its uniform type identifier), not a JPEG.
    case notJPEG(String)
    case jpegDimensionMismatch(expectedWidth: Int, expectedHeight: Int, actualWidth: Int, actualHeight: Int)

    var description: String {
        switch self {
        case let .payloadSizeMismatch(expected, actual):
            return "video payload has \(actual) bytes, expected \(expected)"
        case .jpegDecodeFailed:
            return "JPEG video payload could not be decoded"
        case let .notJPEG(type):
            return "video payload is \(type), not a JPEG"
        case let .jpegDimensionMismatch(expectedWidth, expectedHeight, actualWidth, actualHeight):
            return "JPEG frame is \(actualWidth)x\(actualHeight), negotiated \(expectedWidth)x\(expectedHeight)"
        }
    }
}

/// Collects one LoLa video frame at a time from its prelude and fragments.
/// Used from the single media receive thread, so it holds no lock.
///
/// Memory per frame is bounded by the prelude's `serializedSize`, which itself must not exceed
/// `maximumSerializedSize`: fragments with a different `fragmentCount`, out-of-range or duplicate indexes are
/// dropped, and a frame whose running byte total passes `serializedSize` is abandoned.
struct LoLaVideoFrameAssembler {
    /// Largest serialized frame a prelude may announce; nil keeps only the codec's global limits.
    let maximumSerializedSize: Int?
    private var prelude: LoLaCompatibilityVideoPrelude?
    private var fragments: [LoLaCompatibilityNormalFragment] = []
    /// One bit per fragment index of the current frame, so a duplicate never counts toward completion.
    private var receivedIndexes: [UInt64] = []
    private var receivedByteCount = 0
    /// Frames whose prelude arrived but which never reassembled cleanly.
    private(set) var incompleteFrameCount = 0
    /// Packets that were malformed, duplicated, oversized or belonged to no announced frame.
    private(set) var discardedPacketCount = 0

    init(maximumSerializedSize: Int? = nil) {
        self.maximumSerializedSize = maximumSerializedSize
    }

    /// The prelude size limit for a negotiated stream: the raw frame plus the 8-byte body header, or twice the raw
    /// frame for JPEG (COMP 1). Nil when the negotiated geometry does not give a representable size.
    static func maximumSerializedSize(compression: Int, width: Int, height: Int, bitsPerPixel: Int) -> Int? {
        guard let raw = try? MediaGeometrySizing.rawFrameByteCountForBitsPerPixel(
            width: width, height: height, bitsPerPixel: bitsPerPixel
        ) else {
            return nil
        }
        let payload = compression == 1 ? raw.multipliedReportingOverflow(by: 2) : (raw, false)
        let total = payload.0.addingReportingOverflow(8)
        return payload.1 || total.overflow ? nil : total.partialValue
    }

    /// Feeds one received video datagram and returns the frame payload when it completes a frame.
    mutating func accept(_ datagram: Data) -> (sequence: UInt32, payload: Data)? {
        guard let decoded = try? LoLaCompatibilityMediaCodec.decode(datagram) else {
            discardedPacketCount += 1
            return nil
        }
        if let next = decoded.videoPrelude {
            begin(next)
            return nil
        }
        guard let fragment = decoded.normalFragment, let current = prelude, admits(fragment, into: current) else {
            discardedPacketCount += 1
            return nil
        }
        receivedByteCount += fragment.fragmentBytes.count
        guard receivedByteCount <= current.serializedSize else {
            incompleteFrameCount += 1
            reset()
            return nil
        }
        markReceived(fragment.header.fragmentIndex)
        fragments.append(fragment)
        guard fragments.count == current.fragmentCount else { return nil }
        defer { reset() }
        guard let body = try? LoLaCompatibilityMediaCodec.reassemble(prelude: current, fragments: fragments) else {
            incompleteFrameCount += 1
            return nil
        }
        return (body.sequence, body.payload)
    }

    /// Starts a new frame; an oversized prelude or a fragment count above its byte size is discarded.
    private mutating func begin(_ next: LoLaCompatibilityVideoPrelude) {
        if prelude != nil { incompleteFrameCount += 1 }
        reset()
        let withinLimit = maximumSerializedSize.map { next.serializedSize <= $0 } ?? true
        guard withinLimit, next.fragmentCount > 0, next.fragmentCount <= max(1, next.serializedSize),
              next.fragmentCount <= LoLaCompatibilityMediaCodec.maxVideoFragmentCount else {
            discardedPacketCount += 1
            return
        }
        prelude = next
        receivedIndexes = Array(repeating: 0, count: (next.fragmentCount + 63) / 64)
    }

    /// True for a not-yet-seen fragment of `current` whose header agrees with the prelude.
    private func admits(
        _ fragment: LoLaCompatibilityNormalFragment,
        into current: LoLaCompatibilityVideoPrelude
    ) -> Bool {
        let header = fragment.header
        guard header.frameID == current.frameID, header.fragmentCount == current.fragmentCount,
              (0..<current.fragmentCount).contains(header.fragmentIndex) else {
            return false
        }
        return receivedIndexes[header.fragmentIndex / 64] & (1 << UInt64(header.fragmentIndex % 64)) == 0
    }

    private mutating func markReceived(_ index: Int) {
        receivedIndexes[index / 64] |= 1 << UInt64(index % 64)
    }

    private mutating func reset() {
        prelude = nil
        fragments.removeAll(keepingCapacity: true)
        receivedIndexes.removeAll(keepingCapacity: true)
        receivedByteCount = 0
    }
}

/// Converts reassembled LoLa video payloads to the BGRA layout the preview sinks accept.
enum LoLaReceivedVideoConverter {
    static func bgra(
        _ payload: Data,
        format: LoLaReceivedVideoFormat,
        width: Int,
        height: Int
    ) throws -> Data {
        let pixelCount = width * height
        switch format {
        case .mono8, .bayer8:
            try requireByteCount(payload, pixelCount)
            return expand(payload, pixelCount: pixelCount, bytesPerPixel: 1) { source, offset in
                (source[offset], source[offset], source[offset])
            }
        case .rgb24:
            try requireByteCount(payload, pixelCount * 3)
            return expand(payload, pixelCount: pixelCount, bytesPerPixel: 3) { source, offset in
                (source[offset + 2], source[offset + 1], source[offset])
            }
        case .jpeg:
            return try decodeJPEG(payload, width: width, height: height)
        }
    }

    private static func requireByteCount(_ payload: Data, _ expected: Int) throws {
        guard payload.count == expected else {
            throw LoLaReceivedVideoDecodeError.payloadSizeMismatch(expected: expected, actual: payload.count)
        }
    }

    /// Writes B, G, R and an opaque alpha byte for each source pixel.
    private static func expand(
        _ payload: Data,
        pixelCount: Int,
        bytesPerPixel: Int,
        pixel: (UnsafeBufferPointer<UInt8>, Int) -> (UInt8, UInt8, UInt8)
    ) -> Data {
        var output = Data(count: pixelCount * 4)
        payload.withUnsafeBytes { (sourceRaw: UnsafeRawBufferPointer) in
            output.withUnsafeMutableBytes { (destinationRaw: UnsafeMutableRawBufferPointer) in
                let source = sourceRaw.bindMemory(to: UInt8.self)
                let destination = destinationRaw.bindMemory(to: UInt8.self)
                for index in 0..<pixelCount {
                    let (blue, green, red) = pixel(source, index * bytesPerPixel)
                    destination[index * 4] = blue
                    destination[index * 4 + 1] = green
                    destination[index * 4 + 2] = red
                    destination[index * 4 + 3] = 0xff
                }
            }
        }
        return output
    }

    /// Decodes only a JPEG whose header size matches the negotiated size; the type and size are checked from the
    /// image header before ImageIO decodes any pixels, so other formats and oversized images never reach a decoder.
    private static func decodeJPEG(_ payload: Data, width: Int, height: Int) throws -> Data {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(payload as CFData, options) else {
            throw LoLaReceivedVideoDecodeError.jpegDecodeFailed
        }
        let type = CGImageSourceGetType(source).map { $0 as String }
        guard type == "public.jpeg" else {
            throw LoLaReceivedVideoDecodeError.notJPEG(type ?? "unknown")
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
              let headerWidth = properties[kCGImagePropertyPixelWidth] as? Int,
              let headerHeight = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw LoLaReceivedVideoDecodeError.jpegDecodeFailed
        }
        guard headerWidth == width, headerHeight == height else {
            throw LoLaReceivedVideoDecodeError.jpegDimensionMismatch(
                expectedWidth: width, expectedHeight: height, actualWidth: headerWidth, actualHeight: headerHeight
            )
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, options),
              image.width == width, image.height == height else {
            throw LoLaReceivedVideoDecodeError.jpegDecodeFailed
        }
        var output = Data(count: width * height * 4)
        let drawn = output.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw LoLaReceivedVideoDecodeError.jpegDecodeFailed }
        return output
    }
}
