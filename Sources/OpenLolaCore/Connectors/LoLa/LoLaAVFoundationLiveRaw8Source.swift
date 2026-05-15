import Dispatch
import Foundation

#if canImport(AVFoundation) && canImport(CoreMedia) && canImport(CoreVideo)
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
#endif

protocol LoLaLiveRaw8VideoSource: AnyObject, Sendable {
    func start() throws
    func stop()
    func nextPayload() throws -> Data?
}

final class LoLaAVFoundationLiveRaw8Source: NSObject, LoLaLiveRaw8VideoSource, @unchecked Sendable {
    private let configuration: ExternalConnectorSessionConfiguration
    private let stateLock = NSLock()
    private var latestPayload: Data?
    private var latestSequence: UInt64 = 0
    private var deliveredSequence: UInt64 = 0

    #if canImport(AVFoundation) && canImport(CoreMedia) && canImport(CoreVideo)
    private let queue = DispatchQueue(label: "open-lola.lola-live-raw8.avfoundation", qos: .userInitiated)
    private var session: AVCaptureSession?
    #endif

    init(configuration: ExternalConnectorSessionConfiguration) {
        self.configuration = configuration
    }

    func start() throws {
        #if canImport(AVFoundation) && canImport(CoreMedia) && canImport(CoreVideo)
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
        try configureLoLaLiveRaw8Device(device)
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
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw LoLaVideoPayloadError.captureUnavailable
        }
        session.addOutput(output)
        session.commitConfiguration()
        session.startRunning()
        guard session.isRunning else {
            session.stopRunning()
            throw LoLaVideoPayloadError.captureUnavailable
        }
        stateLock.lock()
        self.session = session
        latestPayload = nil
        latestSequence = 0
        deliveredSequence = 0
        stateLock.unlock()
        #else
        throw LoLaVideoPayloadError.avFoundationUnavailable
        #endif
    }

    func stop() {
        #if canImport(AVFoundation) && canImport(CoreMedia) && canImport(CoreVideo)
        stateLock.lock()
        let activeSession = session
        session = nil
        latestPayload = nil
        latestSequence = 0
        deliveredSequence = 0
        stateLock.unlock()
        activeSession?.stopRunning()
        #endif
    }

    func nextPayload() throws -> Data? {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard latestSequence != deliveredSequence, let latestPayload else {
            return nil
        }
        deliveredSequence = latestSequence
        return latestPayload
    }

    #if canImport(AVFoundation) && canImport(CoreMedia) && canImport(CoreVideo)
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

#if canImport(AVFoundation) && canImport(CoreMedia) && canImport(CoreVideo)
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
        guard width == configuration.videoWidth, height == configuration.videoHeight,
              let payload = raw8LumaPayload(from: imageBuffer, width: width, height: height) else {
            return
        }
        stateLock.lock()
        latestSequence &+= 1
        latestPayload = payload
        stateLock.unlock()
    }
}
#endif
