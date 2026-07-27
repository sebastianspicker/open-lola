// Captures AVFoundation video frames and converts them into LoLa raw 8-bit payloads.
import Dispatch
import Foundation

#if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreImage) && canImport(CoreMedia) && canImport(CoreVideo) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import ImageIO
import UniformTypeIdentifiers
#endif

protocol LoLaLiveRaw8VideoSource: AnyObject, Sendable {
    func start() throws
    func stop()
    func nextPayload() throws -> Data?
    func nextPayload(until deadline: Date) throws -> Data?
}

extension LoLaLiveRaw8VideoSource {
    func nextPayload(until _: Date) throws -> Data? {
        try nextPayload()
    }
}

final class LoLaAVFoundationLiveRaw8Source: NSObject, LoLaLiveRaw8VideoSource, @unchecked Sendable {
    private let configuration: ExternalConnectorSessionConfiguration
    private let stateCondition = NSCondition()
    private var latestPayload: Data?
    private var latestSequence: UInt64 = 0
    private var deliveredSequence: UInt64 = 0
    private var latestError: LoLaVideoPayloadError?
    private var running = false

    #if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreImage) && canImport(CoreMedia) && canImport(CoreVideo) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
    private let queue = DispatchQueue(label: "open-lola.lola-live-raw8.avfoundation", qos: .userInitiated)
    private let ciContext = CIContext()
    private var session: AVCaptureSession?
    #endif

    init(configuration: ExternalConnectorSessionConfiguration) {
        self.configuration = configuration
    }

    func start() throws {
        #if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreImage) && canImport(CoreMedia) && canImport(CoreVideo) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
        let input = try makeCaptureInput()
        let session = try makeCaptureSession(input: input)
        session.startRunning()
        guard session.isRunning else {
            session.stopRunning()
            throw LoLaVideoPayloadError.captureUnavailable
        }
        installRunningSession(session)
        #else
        throw LoLaVideoPayloadError.avFoundationUnavailable
        #endif
    }

    #if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreImage) && canImport(CoreMedia) && canImport(CoreVideo) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
    private func makeCaptureInput() throws -> AVCaptureDeviceInput {
        let device = try loLaAVFoundationCaptureDevice(configuration: configuration)
        try configureLoLaLiveRaw8Device(device)
        return try AVCaptureDeviceInput(device: device)
    }

    private func makeCaptureSession(input: AVCaptureDeviceInput) throws -> AVCaptureSession {
        try makeLoLaAVFoundationCaptureSession(
            input: input,
            collector: self,
            queue: queue
        )
    }

    private func installRunningSession(_ session: AVCaptureSession) {
        stateCondition.lock()
        self.session = session
        latestPayload = nil
        latestSequence = 0
        deliveredSequence = 0
        latestError = nil
        running = true
        stateCondition.unlock()
    }
    #endif

    func stop() {
        #if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreImage) && canImport(CoreMedia) && canImport(CoreVideo) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
        stateCondition.lock()
        let activeSession = session
        session = nil
        latestPayload = nil
        latestSequence = 0
        deliveredSequence = 0
        latestError = nil
        running = false
        stateCondition.broadcast()
        stateCondition.unlock()
        activeSession?.stopRunning()
        #endif
    }

    func nextPayload() throws -> Data? {
        stateCondition.lock()
        defer { stateCondition.unlock() }
        if let latestError {
            throw latestError
        }
        return takeLatestPayload()
    }

    func nextPayload(until deadline: Date) throws -> Data? {
        stateCondition.lock()
        defer { stateCondition.unlock() }
        while latestSequence == deliveredSequence, running, Date() < deadline {
            stateCondition.wait(until: deadline)
        }
        if let latestError {
            throw latestError
        }
        return takeLatestPayload()
    }

    private func takeLatestPayload() -> Data? {
        guard latestSequence != deliveredSequence, let latestPayload else {
            return nil
        }
        deliveredSequence = latestSequence
        return latestPayload
    }

    #if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreImage) && canImport(CoreMedia) && canImport(CoreVideo) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
    private func configureLoLaLiveRaw8Device(_ device: AVCaptureDevice) throws {
        let matchingFormat = device.formats.first { format in
            let description = avFoundationFormatDescription(format)
            return description.width == configuration.videoWidth
                && description.height == configuration.videoHeight
                && format.videoSupportedFrameRateRanges.contains { range in
                    range.minFrameRate <= Double(configuration.videoFrameRate)
                        && Double(configuration.videoFrameRate) <= range.maxFrameRate
                }
        }
        guard let matchingFormat else {
            let activeDescription = avFoundationFormatDescription(device.activeFormat)
            throw LoLaVideoPayloadError.frameDimensionMismatch(
                expectedWidth: configuration.videoWidth,
                expectedHeight: configuration.videoHeight,
                actualWidth: activeDescription.width,
                actualHeight: activeDescription.height
            )
        }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        device.activeFormat = matchingFormat
        let duration = CMTime(value: 1, timescale: CMTimeScale(max(1, configuration.videoFrameRate)))
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
    }
    #endif
}

#if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreImage) && canImport(CoreMedia) && canImport(CoreVideo) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
extension LoLaAVFoundationLiveRaw8Source: AVCaptureVideoDataOutputSampleBufferDelegate {
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
        guard width == configuration.videoWidth, height == configuration.videoHeight else {
            recordLiveError(.frameDimensionMismatch(
                expectedWidth: configuration.videoWidth,
                expectedHeight: configuration.videoHeight,
                actualWidth: width,
                actualHeight: height
            ))
            return
        }
        let payload: Data
        do {
            payload = try livePayload(from: imageBuffer, width: width, height: height)
        } catch let error as LoLaVideoPayloadError {
            recordLiveError(error)
            return
        } catch {
            recordLiveError(.captureUnavailable)
            return
        }
        stateCondition.lock()
        latestSequence &+= 1
        latestPayload = payload
        stateCondition.signal()
        stateCondition.unlock()
    }

    private func livePayload(from imageBuffer: CVPixelBuffer, width: Int, height: Int) throws -> Data {
        switch configuration.lolaVideoPayload {
        case .avFoundationRaw8:
            guard let payload = raw8LumaPayload(from: imageBuffer, width: width, height: height) else {
                throw LoLaVideoPayloadError.raw8ExtractionFailed
            }
            return payload
        case .avFoundationMjpeg, .avFoundationJpegXS:
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            guard let image = ciContext.createCGImage(
                ciImage,
                from: CGRect(x: 0, y: 0, width: width, height: height)
            ) else {
                throw configuration.lolaVideoPayload == .avFoundationMjpeg
                    ? LoLaVideoPayloadError.jpegEncodingFailed
                    : LoLaVideoPayloadError.jpegXSEncodingFailed
            }
            if configuration.lolaVideoPayload == .avFoundationMjpeg {
                return try LoLaMjpegJPEGEncoder.jpegData(from: image)
            }
            return try encodeLoLaJpegXSPayload(
                from: image,
                width: width,
                height: height,
                sequenceNumber: DispatchTime.now().uptimeNanoseconds,
                frameRate: configuration.videoFrameRate
            )
        case .generated:
            throw LoLaVideoPayloadError.captureUnavailable
        }
    }

    private func recordLiveError(_ error: LoLaVideoPayloadError) {
        stateCondition.lock()
        latestError = error
        stateCondition.signal()
        stateCondition.unlock()
    }
}
#endif
