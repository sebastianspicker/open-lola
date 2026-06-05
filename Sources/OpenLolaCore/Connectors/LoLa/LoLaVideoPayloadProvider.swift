import Foundation
import Dispatch

#if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreImage) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo
import ImageIO
import UniformTypeIdentifiers
#endif

public enum LoLaVideoPayloadError: Error, Equatable, Sendable {
    case avFoundationUnavailable
    case cameraNotAuthorized(AVFoundationPermissionStatus)
    case cameraNotFound(String?)
    case captureUnavailable
    case frameDimensionMismatch(expectedWidth: Int, expectedHeight: Int, actualWidth: Int, actualHeight: Int)
    case jpegEncodingFailed
    case jpegXSEncodingFailed
    case raw8ExtractionFailed
}

public enum LoLaVideoPayloadProvider {
    public static func payloads(
        configuration: ExternalConnectorSessionConfiguration,
        frameCount: Int
    ) throws -> [Data] {
        guard frameCount > 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("frameCount", String(frameCount))
        }
        switch configuration.lolaVideoPayload {
        case .generated:
            return try (0..<frameCount).map {
                try generatedRawVideoPayload(configuration: configuration, sequenceNumber: $0)
            }
        case .avFoundationMjpeg:
            return try LoLaAVFoundationMjpegPayloadProvider.capturePayloads(
                configuration: configuration,
                frameCount: frameCount
            )
        case .avFoundationRaw8:
            return try LoLaAVFoundationRaw8PayloadProvider.capturePayloads(
                configuration: configuration,
                frameCount: frameCount
            )
        case .avFoundationJpegXS:
            return try LoLaAVFoundationJpegXSPayloadProvider.capturePayloads(
                configuration: configuration,
                frameCount: frameCount
            )
        }
    }

    public static func generatedRawVideoPayload(
        configuration: ExternalConnectorSessionConfiguration,
        sequenceNumber: Int
    ) throws -> Data {
        if configuration.videoBitsPerPixel == 8 {
            return try generatedDiagnosticMono8Payload(
                configuration: configuration,
                sequenceNumber: sequenceNumber
            )
        }
        let fullFrameBytes = try MediaGeometrySizing.rawFrameByteCountForBitsPerPixel(
            width: configuration.videoWidth,
            height: configuration.videoHeight,
            bitsPerPixel: configuration.videoBitsPerPixel,
            maxByteCount: LoLaCompatibilityMediaCodec.maxSerializedMediaByteCount
        )
        var payload = Data(count: fullFrameBytes)
        payload.withUnsafeMutableBytes { rawBuffer in
            guard let bytes = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }
            for offset in 0..<fullFrameBytes {
                bytes[offset] = UInt8((offset + sequenceNumber) & 0xff)
            }
        }
        return payload
    }

    private static func generatedDiagnosticMono8Payload(
        configuration: ExternalConnectorSessionConfiguration,
        sequenceNumber: Int
    ) throws -> Data {
        let fullFrameBytes = try MediaGeometrySizing.rawFrameByteCountForBitsPerPixel(
            width: configuration.videoWidth,
            height: configuration.videoHeight,
            bitsPerPixel: configuration.videoBitsPerPixel,
            maxByteCount: LoLaCompatibilityMediaCodec.maxSerializedMediaByteCount
        )
        let width = configuration.videoWidth
        let height = configuration.videoHeight
        var payload = Data(count: fullFrameBytes)
        payload.withUnsafeMutableBytes { rawBuffer in
            guard let bytes = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }
            let barWidth = max(1, width / 8)
            let movingSize = max(8, min(width, height) / 8)
            let movingX = (sequenceNumber * 7) % max(1, width - movingSize)
            let movingY = (sequenceNumber * 5) % max(1, height - movingSize)
            let centerX = width / 2
            let centerY = height / 2
            let pixelContext = DiagnosticMono8PixelContext(
                barWidth: barWidth,
                height: height,
                centerX: centerX,
                centerY: centerY,
                movingX: movingX,
                movingY: movingY,
                movingSize: movingSize,
                sequenceNumber: sequenceNumber
            )

            for y in 0..<height {
                let row = y * width
                for x in 0..<width {
                    bytes[row + x] = pixelContext.value(x: x, y: y)
                }
            }
            drawDiagnosticFrameTicksMono8(bytes: bytes, width: width, height: height, tick: sequenceNumber)
        }
        return payload
    }
}

private struct DiagnosticMono8PixelContext {
    var barWidth: Int
    var height: Int
    var centerX: Int
    var centerY: Int
    var movingX: Int
    var movingY: Int
    var movingSize: Int
    var sequenceNumber: Int

    func value(x: Int, y: Int) -> UInt8 {
        let bar = min(7, x / barWidth)
        var value = UInt8((bar * 32 + (y * 64 / max(1, height))) & 0xff)
        if x == centerX || y == centerY {
            value = 255
        }
        if movingX <= x, x < movingX + movingSize, movingY <= y, y < movingY + movingSize {
            value = ((x + y + sequenceNumber) & 4) != 0 ? 255 : 32
        }
        if y < 16, ((x / 8) & 1) == ((sequenceNumber / 5) & 1) {
            value = 220
        }
        return value
    }
}

private func drawDiagnosticFrameTicksMono8(
    bytes: UnsafeMutablePointer<UInt8>,
    width: Int,
    height: Int,
    tick: Int
) {
    let tickCount = min(16, width / 10)
    let y0 = max(0, height - 18)
    for bit in 0..<tickCount {
        let value: UInt8 = ((tick >> bit) & 1) != 0 ? 255 : 40
        let x0 = 2 + bit * 10
        for y in y0..<min(height, y0 + 12) {
            let row = y * width
            for x in x0..<min(width, x0 + 8) {
                bytes[row + x] = value
            }
        }
    }
}

public enum LoLaAVFoundationRaw8PayloadProvider {
    public static func capturePayloads(
        configuration: ExternalConnectorSessionConfiguration,
        frameCount: Int
    ) throws -> [Data] {
        #if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreImage) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
        return try captureLoLaAVFoundationPayloads(
            configuration: configuration,
            frameCount: frameCount,
            collector: LoLaAVFoundationRaw8Collector(
                expectedWidth: configuration.videoWidth,
                expectedHeight: configuration.videoHeight,
                targetFrameCount: frameCount
            )
        )
        #else
        throw LoLaVideoPayloadError.avFoundationUnavailable
        #endif
    }
}

public enum LoLaAVFoundationMjpegPayloadProvider {
    public static func capturePayloads(
        configuration: ExternalConnectorSessionConfiguration,
        frameCount: Int
    ) throws -> [Data] {
        #if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreImage) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
        return try captureLoLaAVFoundationPayloads(
            configuration: configuration,
            frameCount: frameCount,
            collector: LoLaAVFoundationMjpegCollector(
                expectedWidth: configuration.videoWidth,
                expectedHeight: configuration.videoHeight,
                targetFrameCount: frameCount
            )
        )
        #else
        throw LoLaVideoPayloadError.avFoundationUnavailable
        #endif
    }
}

public enum LoLaAVFoundationJpegXSPayloadProvider {
    public static func capturePayloads(
        configuration: ExternalConnectorSessionConfiguration,
        frameCount: Int
    ) throws -> [Data] {
        #if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreImage) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
        return try captureLoLaAVFoundationPayloads(
            configuration: configuration,
            frameCount: frameCount,
            collector: LoLaAVFoundationJpegXSCollector(
                expectedWidth: configuration.videoWidth,
                expectedHeight: configuration.videoHeight,
                targetFrameCount: frameCount
            )
        )
        #else
        throw LoLaVideoPayloadError.avFoundationUnavailable
        #endif
    }
}

public enum LoLaMjpegJPEGEncoder {
    #if canImport(CoreGraphics) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
    public static func jpegData(from image: CGImage, quality: Double = 0.60) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw LoLaVideoPayloadError.jpegEncodingFailed
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw LoLaVideoPayloadError.jpegEncodingFailed
        }
        return stripNonJfifMetadata(from: data as Data)
    }

    public static func stripNonJfifMetadata(from jpeg: Data) -> Data {
        let bytes = [UInt8](jpeg)
        guard bytes.count >= 4, bytes[0] == 0xff, bytes[1] == 0xd8 else {
            return jpeg
        }
        var output = Data([0xff, 0xd8])
        var index = 2
        while index + 4 <= bytes.count {
            guard bytes[index] == 0xff else {
                output.append(contentsOf: bytes[index...])
                return output
            }
            index = skipJpegMarkerPrefixBytes(bytes, from: index)
            guard index < bytes.count else {
                return output
            }
            let marker = bytes[index]
            index += 1
            switch appendJpegMarkerSegment(
                marker,
                bytes: bytes,
                original: jpeg,
                index: &index,
                output: &output
            ) {
            case .continueScanning:
                continue
            case .finished(let data):
                return data
            case .malformed:
                return output
            }
        }
        return jpeg
    }
    #endif
}

private enum JpegMetadataStripResult {
    case continueScanning
    case finished(Data)
    case malformed
}

private func skipJpegMarkerPrefixBytes(_ bytes: [UInt8], from index: Int) -> Int {
    var currentIndex = index
    while currentIndex < bytes.count, bytes[currentIndex] == 0xff {
        currentIndex += 1
    }
    return currentIndex
}

private func appendJpegMarkerSegment(
    _ marker: UInt8,
    bytes: [UInt8],
    original: Data,
    index: inout Int,
    output: inout Data
) -> JpegMetadataStripResult {
    guard let segment = jpegMarkerSegment(bytes, index: index) else {
        return .finished(original)
    }
    if marker == 0xda {
        output.append(contentsOf: [0xff, marker])
        output.append(contentsOf: segment)
        output.append(contentsOf: bytes[(index + segment.count)...])
        return .finished(output)
    }
    if shouldKeepJpegMarker(marker, segment: segment) {
        output.append(contentsOf: [0xff, marker])
        output.append(contentsOf: segment)
    }
    index += segment.count
    return .continueScanning
}

private func jpegMarkerSegment(_ bytes: [UInt8], index: Int) -> ArraySlice<UInt8>? {
    guard index + 2 <= bytes.count else {
        return nil
    }
    let length = jpegMarkerSegmentLength(bytes, offset: index)
    guard length >= 2, index + length <= bytes.count else {
        return nil
    }
    return bytes[index..<(index + length)]
}

private func jpegMarkerSegmentLength(_ bytes: [UInt8], offset: Int) -> Int {
    Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
}

private func shouldKeepJpegMarker(_ marker: UInt8, segment: ArraySlice<UInt8>) -> Bool {
    if marker == 0xfe {
        return false
    }
    if (0xe1...0xef).contains(marker) {
        return false
    }
    if marker == 0xe0 {
        let payloadStart = segment.startIndex + 2
        guard segment.count >= 7 else {
            return false
        }
        return Array(segment[payloadStart..<(payloadStart + 5)]) == [0x4a, 0x46, 0x49, 0x46, 0x00]
    }
    return true
}
