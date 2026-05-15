import Foundation
import Dispatch

#if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreImage) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo

protocol LoLaAVFoundationPayloadCollector: AVCaptureVideoDataOutputSampleBufferDelegate {
    var payloadCount: Int { get }
    func waitForPayloads(until deadline: Date)
    func result() throws -> [Data]
}

final class LoLaAVFoundationMjpegCollector: NSObject, LoLaAVFoundationPayloadCollector, @unchecked Sendable {
    private let stateCondition = NSCondition()
    private let expectedWidth: Int
    private let expectedHeight: Int
    private let targetFrameCount: Int
    private let ciContext = CIContext()
    private var payloads: [Data] = []
    private var mismatch: LoLaVideoPayloadError?

    init(expectedWidth: Int, expectedHeight: Int, targetFrameCount: Int) {
        self.expectedWidth = expectedWidth
        self.expectedHeight = expectedHeight
        self.targetFrameCount = targetFrameCount
    }

    var payloadCount: Int {
        stateCondition.lock()
        defer { stateCondition.unlock() }
        return payloads.count
    }

    func waitForPayloads(until deadline: Date) {
        stateCondition.lock()
        defer { stateCondition.unlock() }
        while payloads.count < targetFrameCount, mismatch == nil, Date() < deadline {
            stateCondition.wait(until: deadline)
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        _ = output
        _ = connection
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        guard width == expectedWidth, height == expectedHeight else {
            recordMismatch(width: width, height: height)
            return
        }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            recordMismatch(error: .jpegEncodingFailed)
            return
        }
        let jpeg: Data
        do {
            jpeg = try LoLaMjpegJPEGEncoder.jpegData(from: cgImage)
        } catch {
            recordMismatch(error: .jpegEncodingFailed)
            return
        }
        stateCondition.lock()
        defer { stateCondition.unlock() }
        if payloads.count < targetFrameCount {
            payloads.append(jpeg)
            stateCondition.signal()
        }
    }

    func result() throws -> [Data] {
        stateCondition.lock()
        defer { stateCondition.unlock() }
        if let mismatch {
            throw mismatch
        }
        guard payloads.count >= targetFrameCount else {
            throw LoLaVideoPayloadError.captureUnavailable
        }
        return Array(payloads.prefix(targetFrameCount))
    }

    private func recordMismatch(width: Int, height: Int) {
        recordMismatch(error: .frameDimensionMismatch(
            expectedWidth: expectedWidth,
            expectedHeight: expectedHeight,
            actualWidth: width,
            actualHeight: height
        ))
    }

    private func recordMismatch(error: LoLaVideoPayloadError) {
        stateCondition.lock()
        defer { stateCondition.unlock() }
        mismatch = error
        stateCondition.signal()
    }
}

final class LoLaAVFoundationJpegXSCollector: NSObject, LoLaAVFoundationPayloadCollector, @unchecked Sendable {
    private let stateCondition = NSCondition()
    private let expectedWidth: Int
    private let expectedHeight: Int
    private let targetFrameCount: Int
    private let ciContext = CIContext()
    private var payloads: [Data] = []
    private var error: LoLaVideoPayloadError?

    init(expectedWidth: Int, expectedHeight: Int, targetFrameCount: Int) {
        self.expectedWidth = expectedWidth
        self.expectedHeight = expectedHeight
        self.targetFrameCount = targetFrameCount
    }

    var payloadCount: Int {
        stateCondition.lock()
        defer { stateCondition.unlock() }
        return payloads.count
    }

    func waitForPayloads(until deadline: Date) {
        stateCondition.lock()
        defer { stateCondition.unlock() }
        while payloads.count < targetFrameCount, error == nil, Date() < deadline {
            stateCondition.wait(until: deadline)
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        _ = output
        _ = connection
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            record(error: .jpegXSEncodingFailed)
            return
        }
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        guard width == expectedWidth, height == expectedHeight else {
            record(error: .frameDimensionMismatch(
                expectedWidth: expectedWidth,
                expectedHeight: expectedHeight,
                actualWidth: width,
                actualHeight: height
            ))
            return
        }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            record(error: .jpegXSEncodingFailed)
            return
        }
        do {
            let bgra = try bgraPayload(from: cgImage, width: width, height: height)
            let metadata = CapturedVideoFrame(
                streamID: 100,
                sequenceNumber: UInt64(payloads.count + 1),
                timestampNanoseconds: DispatchTime.now().uptimeNanoseconds,
                timestampBasis: .hostUptimeNanoseconds,
                sourceRole: .avFoundationDevice,
                width: width,
                height: height,
                pixelFormat: "bgra8",
                frameRate: VideoFrameRate(numerator: 30, denominator: 1),
                fingerprint: "lola-avfoundation-jpeg-xs-\(payloads.count + 1)"
            )
            let encoded = try JPEGXSReferenceCodec.encode(frame: RawCapturedVideoFrame(metadata: metadata, payload: bgra))
            stateCondition.lock()
            defer { stateCondition.unlock() }
            if payloads.count < targetFrameCount {
                payloads.append(encoded)
                stateCondition.signal()
            }
        } catch {
            record(error: .jpegXSEncodingFailed)
        }
    }

    func result() throws -> [Data] {
        stateCondition.lock()
        defer { stateCondition.unlock() }
        if let error {
            throw error
        }
        guard payloads.count >= targetFrameCount else {
            throw LoLaVideoPayloadError.captureUnavailable
        }
        return Array(payloads.prefix(targetFrameCount))
    }

    private func record(error: LoLaVideoPayloadError) {
        stateCondition.lock()
        defer { stateCondition.unlock() }
        self.error = error
        stateCondition.signal()
    }
}

final class LoLaAVFoundationRaw8Collector: NSObject, LoLaAVFoundationPayloadCollector, @unchecked Sendable {
    private let stateCondition = NSCondition()
    private let expectedWidth: Int
    private let expectedHeight: Int
    private let targetFrameCount: Int
    private var payloads: [Data] = []
    private var error: LoLaVideoPayloadError?

    init(expectedWidth: Int, expectedHeight: Int, targetFrameCount: Int) {
        self.expectedWidth = expectedWidth
        self.expectedHeight = expectedHeight
        self.targetFrameCount = targetFrameCount
    }

    var payloadCount: Int {
        stateCondition.lock()
        defer { stateCondition.unlock() }
        return payloads.count
    }

    func waitForPayloads(until deadline: Date) {
        stateCondition.lock()
        defer { stateCondition.unlock() }
        while payloads.count < targetFrameCount, error == nil, Date() < deadline {
            stateCondition.wait(until: deadline)
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        _ = output
        _ = connection
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            record(error: .raw8ExtractionFailed)
            return
        }
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        guard width == expectedWidth, height == expectedHeight else {
            record(error: .frameDimensionMismatch(
                expectedWidth: expectedWidth,
                expectedHeight: expectedHeight,
                actualWidth: width,
                actualHeight: height
            ))
            return
        }
        guard let payload = raw8LumaPayload(from: imageBuffer, width: width, height: height) else {
            record(error: .raw8ExtractionFailed)
            return
        }
        stateCondition.lock()
        defer { stateCondition.unlock() }
        if payloads.count < targetFrameCount {
            payloads.append(payload)
            stateCondition.signal()
        }
    }

    func result() throws -> [Data] {
        stateCondition.lock()
        defer { stateCondition.unlock() }
        if let error {
            throw error
        }
        guard payloads.count >= targetFrameCount else {
            throw LoLaVideoPayloadError.captureUnavailable
        }
        return Array(payloads.prefix(targetFrameCount))
    }

    private func record(error: LoLaVideoPayloadError) {
        stateCondition.lock()
        defer { stateCondition.unlock() }
        self.error = error
        stateCondition.signal()
    }
}

func captureTimeoutSeconds(frameCount: Int, fps: Int) -> TimeInterval {
    max(2, Double(frameCount) / Double(max(1, fps)) + 1)
}

func captureLoLaAVFoundationPayloads(
    configuration: ExternalConnectorSessionConfiguration,
    frameCount: Int,
    collector: LoLaAVFoundationPayloadCollector
) throws -> [Data] {
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
    output.setSampleBufferDelegate(
        collector,
        queue: DispatchQueue(label: "open-lola.lola-video.avfoundation", qos: .userInitiated)
    )
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

private func bgraPayload(from image: CGImage, width: Int, height: Int) throws -> Data {
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
