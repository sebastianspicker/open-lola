import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Converts AVFoundation device and format properties into capture-safe OpenLola values.
import Foundation

#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
#endif

func productionVideoCaptureEvidence(
    for device: AVFoundationVideoDeviceDescription
) -> ProductionVideoCaptureEvidence? {
    let hardwareKind = productionVideoHardwareKind(
        label: device.label,
        manufacturer: device.manufacturer
    )
    guard hardwareKind.isBlackmagicProductionTarget else {
        return nil
    }

    return ProductionVideoCaptureEvidence(
        hardware: .init(
            kind: hardwareKind,
            modelName: device.label,
            manufacturer: videoCaptureManufacturer(
                label: device.label,
                fallback: device.manufacturer
            ),
            connectionMethod: productionVideoConnectionMethod(
                label: device.label,
                transport: device.transport
            )
        ),
        discovery: .init(avFoundationVisible: true, deviceUniqueID: device.uniqueId),
        desktopSDK: .init(
            status: .notLinkedOptionalBoundary,
            decisionNotes: "AVFoundation exposes this Blackmagic/ATEM capture path; "
                + "Desktop Video SDK remains optional until measured need.",
            atemReadOnlyControlReport: nil
        )
    )
}

func productionVideoHardwareKind(label: String, manufacturer: String) -> ProductionVideoHardwareKind {
    let normalized = "\(label) \(manufacturer)".lowercased()
    if normalized.contains("atem") {
        return .atem
    }
    if normalized.contains("decklink") || normalized.contains("deck link") {
        return .deckLink
    }
    if normalized.contains("ultrastudio") || normalized.contains("ultra studio") {
        return .ultraStudio
    }
    if normalized.contains("blackmagic") || normalized.contains("capture") {
        return .blackmagicCapture
    }
    return .genericCamera
}

func productionVideoConnectionMethod(
    label: String,
    transport: String
) -> ProductionVideoConnectionMethod {
    let normalized = "\(label) \(transport)".lowercased()
    if usbUvcConnectionTokens.contains(where: normalized.contains) {
        return .usbUvc
    }
    if thunderboltConnectionTokens.contains(where: normalized.contains) {
        return .thunderbolt
    }
    if pcieConnectionTokens.contains(where: normalized.contains) {
        return .pcie
    }
    return .unknown
}

private let usbUvcConnectionTokens = ["uvc", "usb", "atem"]
private let thunderboltConnectionTokens = ["thunderbolt", "ultrastudio"]
private let pcieConnectionTokens = ["pcie", "pci", "decklink"]

func currentAVFoundationPermissionStatus() -> AVFoundationPermissionStatus {
    #if canImport(AVFoundation)
    AVFoundationPermissionStatus(authorizationStatus: AVCaptureDevice.authorizationStatus(for: .video))
    #else
    .unknown
    #endif
}

func currentAVFoundationVideoDevices() -> [AVFoundationVideoDeviceDescription] {
    #if canImport(AVFoundation)
    return currentAVCaptureVideoDevices().map { avFoundationDeviceDescription(for: $0) }
    #else
    return []
    #endif
}

#if canImport(AVFoundation)
func avFoundationPresentationTimestampNanoseconds(
    sampleBuffer: CMSampleBuffer,
    fallbackNanoseconds: UInt64
) -> UInt64 {
    avFoundationPresentationTimestampNanoseconds(
        presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
        fallbackNanoseconds: fallbackNanoseconds
    )
}

func avFoundationPresentationTimestampNanoseconds(
    presentationTime: CMTime,
    fallbackNanoseconds: UInt64
) -> UInt64 {
    guard presentationTime.isValid,
          presentationTime.isNumeric,
          !presentationTime.isIndefinite,
          presentationTime.seconds.isFinite,
          presentationTime.seconds >= 0 else {
        return fallbackNanoseconds
    }
    let nanoseconds = presentationTime.seconds * 1_000_000_000
    guard nanoseconds <= Double(UInt64.max) else {
        return UInt64.max
    }
    return UInt64(nanoseconds.rounded())
}

typealias CVPixelBufferLockOperation = (CVPixelBuffer, CVPixelBufferLockFlags) -> CVReturn

private struct RawFrameBufferLayout {
    var source: UnsafePointer<UInt8>
    var widthBytes: Int
    var bytesPerRow: Int
    var height: Int
    var contiguousByteCount: Int
}

func rawFrameBytes(
    from imageBuffer: CVPixelBuffer,
    lockBaseAddress: CVPixelBufferLockOperation = CVPixelBufferLockBaseAddress,
    unlockBaseAddress: CVPixelBufferLockOperation = CVPixelBufferUnlockBaseAddress
) throws -> Data {
    let lockStatus = lockBaseAddress(imageBuffer, .readOnly)
    guard lockStatus == kCVReturnSuccess else {
        throw VideoCaptureProbeError.pixelBufferLockFailed(lockStatus)
    }
    defer {
        _ = unlockBaseAddress(imageBuffer, .readOnly)
    }
    return try rawFrameBytesFromLockedBuffer(imageBuffer)
}

private func rawFrameBytesFromLockedBuffer(_ imageBuffer: CVPixelBuffer) throws -> Data {
    let layout = try rawFrameBufferLayout(from: imageBuffer)
    return copyRawFrameBytes(layout)
}

private func rawFrameBufferLayout(from imageBuffer: CVPixelBuffer) throws -> RawFrameBufferLayout {
    guard !CVPixelBufferIsPlanar(imageBuffer) else {
        throw VideoCaptureProbeError.planarPixelBufferUnsupported
    }
    guard let base = CVPixelBufferGetBaseAddress(imageBuffer) else {
        throw VideoCaptureProbeError.emptyPixelBufferBaseAddress
    }
    try requireRawFramePixelFormat(imageBuffer)
    let widthBytes = CVPixelBufferGetWidth(imageBuffer) * 4
    let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
    let height = CVPixelBufferGetHeight(imageBuffer)
    let contiguousByteCount = try validatedRawFrameByteCount(
        widthBytes: widthBytes,
        bytesPerRow: bytesPerRow,
        height: height
    )
    return RawFrameBufferLayout(
        source: base.assumingMemoryBound(to: UInt8.self),
        widthBytes: widthBytes,
        bytesPerRow: bytesPerRow,
        height: height,
        contiguousByteCount: contiguousByteCount
    )
}

private func requireRawFramePixelFormat(_ imageBuffer: CVPixelBuffer) throws {
    let pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer)
    guard pixelFormat == kCVPixelFormatType_32BGRA else {
        throw VideoCaptureProbeError.unsupportedPixelBufferFormat(videoCaptureFourCCString(pixelFormat))
    }
}

private func validatedRawFrameByteCount(widthBytes: Int, bytesPerRow: Int, height: Int) throws -> Int {
    guard widthBytes > 0,
          bytesPerRow >= widthBytes,
          height > 0 else {
        throw VideoCaptureProbeError.invalidPixelBufferLayout(
            widthBytes: widthBytes,
            bytesPerRow: bytesPerRow,
            height: height
        )
    }
    let contiguousProduct = widthBytes.multipliedReportingOverflow(by: height)
    let rowStrideProduct = bytesPerRow.multipliedReportingOverflow(by: height)
    guard !contiguousProduct.overflow,
          !rowStrideProduct.overflow,
          rowStrideProduct.partialValue >= contiguousProduct.partialValue else {
        throw VideoCaptureProbeError.invalidPixelBufferLayout(
            widthBytes: widthBytes,
            bytesPerRow: bytesPerRow,
            height: height
        )
    }
    return contiguousProduct.partialValue
}

private func copyRawFrameBytes(_ layout: RawFrameBufferLayout) -> Data {
    var data = Data()
    if layout.bytesPerRow == layout.widthBytes {
        data.append(layout.source, count: layout.contiguousByteCount)
    } else {
        for row in 0..<layout.height {
            let rowStart = layout.source.advanced(by: row * layout.bytesPerRow)
            data.append(rowStart, count: layout.widthBytes)
        }
    }
    return data
}

#endif
