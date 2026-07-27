// Converts AVFoundation sample buffers into bounded raw, MJPEG, or JPEG XS payload collections.
import Foundation
import Dispatch

#if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreImage)
import AVFoundation
import CoreGraphics
import CoreImage

class LoLaAVFoundationPayloadCollectorBase: NSObject, @unchecked Sendable {
    let state: LoLaAVFoundationPayloadCollectionState
    private let ciContext = CIContext()

    init(expectedWidth: Int, expectedHeight: Int, targetFrameCount: Int) {
        state = LoLaAVFoundationPayloadCollectionState(
            expectedWidth: expectedWidth,
            expectedHeight: expectedHeight,
            targetFrameCount: targetFrameCount
        )
    }

    var payloadCount: Int { state.payloadCount }

    func waitForPayloads(until deadline: Date) { state.waitForPayloads(until: deadline) }

    func result() throws -> [Data] { try state.result() }

    func captureImagePayload(
        from sampleBuffer: CMSampleBuffer,
        missingImageError: LoLaVideoPayloadError?,
        encodingError: LoLaVideoPayloadError,
        encode: (CGImage, Int, Int, UInt64) throws -> Data
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            if let missingImageError {
                state.record(missingImageError)
            }
            return
        }
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        if let error = state.dimensionMismatchError(actualWidth: width, actualHeight: height) {
            state.record(error)
            return
        }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(
            ciImage,
            from: CGRect(x: 0, y: 0, width: width, height: height)
        ) else {
            state.record(encodingError)
            return
        }
        do {
            state.append(try encode(cgImage, width, height, UInt64(state.payloadCount + 1)))
        } catch {
            state.record(encodingError)
        }
    }

    func captureRaw8Payload(from sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            state.record(.raw8ExtractionFailed)
            return
        }
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        if let error = state.dimensionMismatchError(actualWidth: width, actualHeight: height) {
            state.record(error)
            return
        }
        guard let payload = raw8LumaPayload(from: imageBuffer, width: width, height: height) else {
            state.record(.raw8ExtractionFailed)
            return
        }
        state.append(payload)
    }
}

final class LoLaAVFoundationJpegXSCollector: LoLaAVFoundationPayloadCollectorBase, LoLaAVFoundationPayloadCollector, @unchecked Sendable {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        _ = output
        _ = connection
        captureImagePayload(
            from: sampleBuffer,
            missingImageError: .jpegXSEncodingFailed,
            encodingError: .jpegXSEncodingFailed
        ) { image, width, height, sequenceNumber in
            try encodeLoLaJpegXSPayload(
                from: image,
                width: width,
                height: height,
                sequenceNumber: sequenceNumber,
                frameRate: 30
            )
        }
    }
}

final class LoLaAVFoundationRaw8Collector: LoLaAVFoundationPayloadCollectorBase, LoLaAVFoundationPayloadCollector, @unchecked Sendable {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        _ = output
        _ = connection
        captureRaw8Payload(from: sampleBuffer)
    }
}

func captureTimeoutSeconds(frameCount: Int, fps: Int) -> TimeInterval {
    max(2, Double(frameCount) / Double(max(1, fps)) + 1)
}

func loLaAVFoundationCaptureDevice(
    configuration: ExternalConnectorSessionConfiguration
) throws -> AVCaptureDevice {
    let permission = resolveAVFoundationVideoPermission()
    guard permission == .authorized else {
        throw LoLaVideoPayloadError.cameraNotAuthorized(permission)
    }
    let requestedDevice = configuration.videoCapture.flatMap { $0 == "auto" ? nil : $0 }
    guard let device = try selectedAVFoundationDevice(
        from: currentAVCaptureVideoDevices(),
        requestedUniqueId: requestedDevice
    ) else {
        throw LoLaVideoPayloadError.cameraNotFound(configuration.videoCapture)
    }
    return device
}

func captureLoLaAVFoundationPayloads(
    configuration: ExternalConnectorSessionConfiguration,
    frameCount: Int,
    collector: LoLaAVFoundationPayloadCollector
) throws -> [Data] {
    let device = try loLaAVFoundationCaptureDevice(configuration: configuration)
    let session = try makeLoLaAVFoundationCaptureSession(
        device: device,
        collector: collector,
        width: configuration.videoWidth,
        height: configuration.videoHeight,
        requestedFrameRate: Double(configuration.videoFrameRate)
    )
    session.startRunning()
    defer { session.stopRunning() }
    let deadline = Date().addingTimeInterval(
        captureTimeoutSeconds(frameCount: frameCount, fps: configuration.videoFrameRate)
    )
    collector.waitForPayloads(until: deadline)
    return try collector.result()
}

func makeLoLaAVFoundationCaptureSession(
    device: AVCaptureDevice,
    collector: LoLaAVFoundationPayloadCollector,
    width: Int,
    height: Int,
    requestedFrameRate: Double
) throws -> AVCaptureSession {
    try configureLoLaAVFoundationDevice(
        device,
        width: width,
        height: height,
        requestedFrameRate: requestedFrameRate
    )
    let input = try AVCaptureDeviceInput(device: device)
    return try makeLoLaAVFoundationCaptureSession(
        input: input,
        collector: collector,
        queue: DispatchQueue(label: "open-lola.lola-video.avfoundation", qos: .userInitiated)
    )
}

func makeLoLaAVFoundationCaptureSession(
    input: AVCaptureDeviceInput,
    collector: AVCaptureVideoDataOutputSampleBufferDelegate,
    queue: DispatchQueue
) throws -> AVCaptureSession {
    let session = AVCaptureSession()
    session.beginConfiguration()
    guard session.canAddInput(input) else {
        session.commitConfiguration()
        throw LoLaVideoPayloadError.captureUnavailable
    }
    session.addInput(input)
    let output = AVCaptureVideoDataOutput()
    output.alwaysDiscardsLateVideoFrames = true
    output.videoSettings = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    ]
    output.setSampleBufferDelegate(collector, queue: queue)
    guard session.canAddOutput(output) else {
        session.commitConfiguration()
        throw LoLaVideoPayloadError.captureUnavailable
    }
    session.addOutput(output)
    session.commitConfiguration()
    return session
}

func configureLoLaAVFoundationDevice(
    _ device: AVCaptureDevice,
    width: Int,
    height: Int,
    requestedFrameRate: Double
) throws {
    let matchingFormat = device.formats.first { format in
        let description = avFoundationFormatDescription(format)
        return description.width == width
            && description.height == height
            && format.videoSupportedFrameRateRanges.contains { range in
                range.minFrameRate <= requestedFrameRate && requestedFrameRate <= range.maxFrameRate
            }
    }
    guard let matchingFormat else {
        let activeDescription = avFoundationFormatDescription(device.activeFormat)
        throw LoLaVideoPayloadError.frameDimensionMismatch(
            expectedWidth: width,
            expectedHeight: height,
            actualWidth: activeDescription.width,
            actualHeight: activeDescription.height
        )
    }
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }
    device.activeFormat = matchingFormat
    guard requestedFrameRate > 0 else {
        return
    }
    let scaledTimescale = (requestedFrameRate * 1_000_000).rounded()
    guard scaledTimescale > 0, scaledTimescale <= Double(Int32.max) else {
        return
    }
    let timescale = CMTimeScale(scaledTimescale)
    let duration = CMTime(value: 1_000_000, timescale: timescale)
    device.activeVideoMinFrameDuration = duration
    device.activeVideoMaxFrameDuration = duration
}

func raw8LumaPayload(from imageBuffer: CVPixelBuffer, width: Int, height: Int) -> Data? {
    guard CVPixelBufferIsPlanar(imageBuffer),
          CVPixelBufferGetPlaneCount(imageBuffer) > 0 else {
        return nil
    }
    CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0) else {
        return nil
    }
    let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0)
    guard bytesPerRow >= width else {
        return nil
    }
    var payload = Data()
    payload.reserveCapacity(width * height)
    for row in 0..<height {
        let rowStart = base.advanced(by: row * bytesPerRow).assumingMemoryBound(to: UInt8.self)
        payload.append(rowStart, count: width)
    }
    return payload
}

func encodeLoLaJpegXSPayload(
    from image: CGImage,
    width: Int,
    height: Int,
    sequenceNumber: UInt64,
    frameRate: Int
) throws -> Data {
    let bgra = try bgraPayload(from: image, width: width, height: height)
    let metadata = CapturedVideoFrame(
        streamID: 100,
        sequenceNumber: sequenceNumber,
        timestampNanoseconds: DispatchTime.now().uptimeNanoseconds,
        timestampBasis: .hostUptimeNanoseconds,
        sourceRole: .avFoundationDevice,
        width: width,
        height: height,
        pixelFormat: "bgra8",
        frameRate: VideoFrameRate(numerator: max(1, frameRate), denominator: 1),
        fingerprint: "lola-avfoundation-jpeg-xs-\(sequenceNumber)"
    )
    return try JPEGXSReferenceCodec.encode(
        frame: RawCapturedVideoFrame(metadata: metadata, payload: bgra)
    )
}

func bgraPayload(from image: CGImage, width: Int, height: Int) throws -> Data {
    var payload = Data(count: width * height * 4)
    let created = payload.withUnsafeMutableBytes { rawBuffer -> Bool in
        guard let baseAddress = rawBuffer.baseAddress else {
            return false
        }
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
                .union(.byteOrder32Little)
                .rawValue
        ) else {
            return false
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard created else {
        throw LoLaVideoPayloadError.jpegXSEncodingFailed
    }
    return payload
}
#endif
