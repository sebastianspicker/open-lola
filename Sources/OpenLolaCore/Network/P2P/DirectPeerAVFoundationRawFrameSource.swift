import Dispatch
import Foundation
import os
#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
#endif

final class DirectPeerAVFoundationRawFrameSource: @unchecked Sendable {
    private static let logger = Logger(subsystem: "de.hfmt.open-lola", category: "DirectPeerAVFoundationRawFrameSource")

    private let configuration: DirectPeerSessionAVRunConfiguration
    private let stateLock = NSLock()
    private var videoFormatStorage: DirectPeerSessionVideoFormatReport?
    var videoFormat: DirectPeerSessionVideoFormatReport? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return videoFormatStorage
    }
    #if canImport(AVFoundation)
    private var session: AVCaptureSession?
    private var input: AVCaptureDeviceInput?
    private var output: AVCaptureVideoDataOutput?
    private var collector: AVFoundationSampleBufferCollector?
    private var deviceRestorePoint: AVFoundationDeviceRestorePoint?
    private let queue = DispatchQueue(label: "open-lola.direct-p2p.avfoundation.raw")
    #endif
    private var deliveryGate = DirectPeerAVFoundationFrameDeliveryGate()

    init(configuration: DirectPeerSessionAVRunConfiguration) {
        self.configuration = configuration
    }

    func start() throws {
        #if canImport(AVFoundation)
        try requireVideoPermission()
        let device = try selectedRequiredDevice()
        let configuredDevice = try configureVideoDevice(device)
        var restoreOnStartupFailure: AVFoundationDeviceRestorePoint? = configuredDevice.restorePoint
        defer {
            restoreOnStartupFailure?.restore(logger: Self.logger)
        }
        let capture = try makeStartedCapture(device: device)
        storeStartedCapture(capture, device: device, configuredDevice: configuredDevice)
        restoreOnStartupFailure = nil
        #else
        throw DirectPeerSessionAVRuntimeError.avFoundationCaptureStartFailed("AVFoundation unavailable")
        #endif
    }

    func stop() {
        #if canImport(AVFoundation)
        stateLock.lock()
        let activeSession = session
        let restorePoint = deviceRestorePoint
        session = nil
        input = nil
        output = nil
        collector = nil
        deviceRestorePoint = nil
        videoFormatStorage = nil
        deliveryGate.reset()
        stateLock.unlock()
        activeSession?.stopRunning()
        restorePoint?.restore(logger: Self.logger)
        #endif
    }

    func nextFrame() -> RawCapturedVideoFrame? {
        #if canImport(AVFoundation)
        stateLock.lock()
        let activeCollector = collector
        stateLock.unlock()
        guard let frame = activeCollector?.latestRawFrame() else {
            return nil
        }
        stateLock.lock()
        defer { stateLock.unlock() }
        guard deliveryGate.shouldDeliver(frame) else {
            return nil
        }
        return directPeerHostTimedVideoFrame(
            frame,
            hostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
        )
        #else
        nil
        #endif
    }

    #if canImport(AVFoundation)
    private func requireVideoPermission() throws {
        let permission = resolveAVFoundationVideoPermission()
        guard permission == .authorized else {
            throw DirectPeerSessionAVRuntimeError.avFoundationPermission(permission)
        }
    }

    private func selectedRequiredDevice() throws -> AVCaptureDevice {
        guard let device = selectedDevice() else {
            throw DirectPeerSessionAVRuntimeError.avFoundationDeviceUnavailable(configuration.videoDeviceID)
        }
        return device
    }

    private func selectedDevice() -> AVCaptureDevice? {
        let devices = currentAVCaptureVideoDevices()
        if configuration.videoDeviceID == "auto" {
            let descriptions = currentAVFoundationVideoDevices()
            guard let preferred = preferredAVFoundationVideoDevice(from: descriptions) else {
                return devices.first
            }
            return devices.first(where: { $0.uniqueID == preferred.uniqueId }) ?? devices.first
        }
        return devices.first(where: { $0.uniqueID == configuration.videoDeviceID })
    }

    private func makeStartedCapture(device: AVCaptureDevice) throws -> AVFoundationStartedCapture {
        let input = try AVCaptureDeviceInput(device: device)
        let session = AVCaptureSession()
        try configureCaptureSession(session, input: input)
        let output = makeVideoOutput()
        let collector = makeSampleBufferCollector()
        output.setSampleBufferDelegate(collector, queue: queue)
        try addOutput(output, to: session)
        try startSession(session)
        return AVFoundationStartedCapture(
            session: session,
            input: input,
            output: output,
            collector: collector
        )
    }

    private func configureCaptureSession(
        _ session: AVCaptureSession,
        input: AVCaptureDeviceInput
    ) throws {
        var configurationCommitted = false
        session.beginConfiguration()
        defer {
            if !configurationCommitted {
                session.commitConfiguration()
            }
        }
        session.sessionPreset = .high
        guard session.canAddInput(input) else {
            throw DirectPeerSessionAVRuntimeError.avFoundationCaptureStartFailed("input")
        }
        session.addInput(input)
        session.commitConfiguration()
        configurationCommitted = true
    }

    private func makeVideoOutput() -> AVCaptureVideoDataOutput {
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        return output
    }

    private func makeSampleBufferCollector() -> AVFoundationSampleBufferCollector {
        AVFoundationSampleBufferCollector(
            queueDepth: 2,
            streamID: UInt32(configuration.videoStreamID),
            frameRate: VideoFrameRate(numerator: configuration.videoFrameRate, denominator: 1),
            captureRawFrames: true,
            retainRawFrameArtifact: false
        )
    }

    private func addOutput(_ output: AVCaptureVideoDataOutput, to session: AVCaptureSession) throws {
        session.beginConfiguration()
        var configurationCommitted = false
        defer {
            if !configurationCommitted {
                session.commitConfiguration()
            }
        }
        guard session.canAddOutput(output) else {
            throw DirectPeerSessionAVRuntimeError.avFoundationCaptureStartFailed("output")
        }
        session.addOutput(output)
        session.commitConfiguration()
        configurationCommitted = true
    }

    private func startSession(_ session: AVCaptureSession) throws {
        session.startRunning()
        guard session.isRunning else {
            session.stopRunning()
            throw DirectPeerSessionAVRuntimeError.avFoundationCaptureStartFailed("startRunning")
        }
    }

    private func storeStartedCapture(
        _ capture: AVFoundationStartedCapture,
        device: AVCaptureDevice,
        configuredDevice: AVFoundationConfiguredVideoDevice
    ) {
        stateLock.lock()
        self.input = capture.input
        self.output = capture.output
        self.collector = capture.collector
        self.deviceRestorePoint = configuredDevice.restorePoint
        self.videoFormatStorage = videoFormatReport(device: device, format: configuredDevice.selectedFormat)
        self.session = capture.session
        self.deliveryGate.reset()
        stateLock.unlock()
    }

    private func configureVideoDevice(_ device: AVCaptureDevice) throws -> AVFoundationConfiguredVideoDevice {
        let selected = try selectedFormat(for: device)
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        let restorePoint = AVFoundationDeviceRestorePoint(
            device: device,
            activeFormat: device.activeFormat,
            minFrameDuration: device.activeVideoMinFrameDuration,
            maxFrameDuration: device.activeVideoMaxFrameDuration
        )
        device.activeFormat = selected
        let duration = CMTime(value: 1, timescale: CMTimeScale(configuration.videoFrameRate))
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
        return AVFoundationConfiguredVideoDevice(
            selectedFormat: device.activeFormat,
            restorePoint: restorePoint
        )
    }

    private func selectedFormat(for device: AVCaptureDevice) throws -> AVCaptureDevice.Format {
        let requestedRate = Double(configuration.videoFrameRate)
        if formatMatchesRequest(device.activeFormat, requestedRate) {
            return device.activeFormat
        }
        if let selected = device.formats.first(where: { formatMatchesRequest($0, requestedRate) }) {
            return selected
        }
        throw DirectPeerSessionAVRuntimeError.avFoundationCaptureStartFailed("requested video format unavailable")
    }

    private func formatMatchesRequest(_ format: AVCaptureDevice.Format, _ requestedRate: Double) -> Bool {
        let description = avFoundationFormatDescription(format)
        return description.width == configuration.videoWidth
            && description.height == configuration.videoHeight
            && supportsFrameRate(format, requestedRate)
    }

    private func supportsFrameRate(_ format: AVCaptureDevice.Format, _ requestedRate: Double) -> Bool {
        format.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= requestedRate && requestedRate <= $0.maxFrameRate }
    }

    private func videoFormatReport(
        device: AVCaptureDevice,
        format: AVCaptureDevice.Format
    ) -> DirectPeerSessionVideoFormatReport {
        let description = avFoundationFormatDescription(format)
        return DirectPeerSessionVideoFormatReport(
            requestedDeviceID: configuration.videoDeviceID,
            selectedDeviceID: device.uniqueID,
            selectedDeviceLabel: device.localizedName,
            requestedFrameRate: configuration.videoFrameRate,
            selectedWidth: description.width,
            selectedHeight: description.height,
            selectedPixelFormat: description.pixelFormat,
            outputPixelFormat: directPeerNormalizedVideoPixelFormat(configuration.videoPixelFormat),
            selectedFrameRate: Double(configuration.videoFrameRate),
            sourcePolicy: videoCaptureSourcePolicy(for: device.localizedName)
        )
    }
    #endif
}

struct DirectPeerAVFoundationFrameDeliveryGate: Equatable {
    private var lastDeliveredSequenceNumber: UInt64?

    mutating func shouldDeliver(_ frame: RawCapturedVideoFrame) -> Bool {
        let sequenceNumber = frame.metadata.sequenceNumber
        guard lastDeliveredSequenceNumber != sequenceNumber else {
            return false
        }
        lastDeliveredSequenceNumber = sequenceNumber
        return true
    }

    mutating func reset() {
        lastDeliveredSequenceNumber = nil
    }
}

#if canImport(AVFoundation)
private struct AVFoundationStartedCapture {
    var session: AVCaptureSession
    var input: AVCaptureDeviceInput
    var output: AVCaptureVideoDataOutput
    var collector: AVFoundationSampleBufferCollector
}

private struct AVFoundationConfiguredVideoDevice {
    var selectedFormat: AVCaptureDevice.Format
    var restorePoint: AVFoundationDeviceRestorePoint
}

private struct AVFoundationDeviceRestorePoint {
    var device: AVCaptureDevice
    var activeFormat: AVCaptureDevice.Format
    var minFrameDuration: CMTime
    var maxFrameDuration: CMTime

    func restore(logger: Logger) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.activeFormat = activeFormat
            device.activeVideoMinFrameDuration = minFrameDuration
            device.activeVideoMaxFrameDuration = maxFrameDuration
        } catch {
            logger.warning("AVFoundation device restore failed during raw frame source cleanup: \(String(describing: error), privacy: .public)")
        }
    }
}
#endif

func nextAVRawFrame(
    source: DirectPeerAVFoundationRawFrameSource,
    configuration: DirectPeerSessionAVRunConfiguration,
    sequenceNumber: UInt64,
    timestampNanoseconds: UInt64
) throws -> RawCapturedVideoFrame? {
    if configuration.mediaSourceMode == .syntheticFixture {
        return syntheticAVRawFrame(.init(
            sequenceNumber: sequenceNumber,
            streamID: UInt32(configuration.videoStreamID),
            frameRate: configuration.videoFrameRate,
            timestampNanoseconds: timestampNanoseconds,
            width: configuration.videoWidth,
            height: configuration.videoHeight,
            pixelFormat: configuration.videoPixelFormat
        ))
    }
    return source.nextFrame()
}

func directPeerHostTimedVideoFrame(
    _ frame: RawCapturedVideoFrame,
    hostTimeNanoseconds: UInt64
) -> RawCapturedVideoFrame {
    RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: frame.metadata.streamID,
            sequenceNumber: frame.metadata.sequenceNumber,
            timestampNanoseconds: hostTimeNanoseconds,
            timestampBasis: .hostUptimeNanoseconds,
            sourceRole: frame.metadata.sourceRole,
            width: frame.metadata.width,
            height: frame.metadata.height,
            pixelFormat: frame.metadata.pixelFormat,
            frameRate: frame.metadata.frameRate,
            fingerprint: frame.metadata.fingerprint
        ),
        payload: frame.payload
    )
}

private struct DirectPeerSyntheticAVRawFrameRequest {
    let sequenceNumber: UInt64
    let streamID: UInt32
    let frameRate: Int
    let timestampNanoseconds: UInt64
    let width: Int
    let height: Int
    let pixelFormat: String
}

private func syntheticAVRawFrame(_ request: DirectPeerSyntheticAVRawFrameRequest) -> RawCapturedVideoFrame {
    let normalizedFormat = directPeerNormalizedVideoPixelFormat(request.pixelFormat)
    let payload = Data(
        repeating: UInt8(request.sequenceNumber & 0xFF),
        count: request.width * request.height * directPeerVideoBytesPerPixel(normalizedFormat)
    )
    return RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: request.streamID,
            sequenceNumber: request.sequenceNumber,
            timestampNanoseconds: request.timestampNanoseconds,
            timestampBasis: .hostUptimeNanoseconds,
            sourceRole: .avFoundationDevice,
            width: request.width,
            height: request.height,
            pixelFormat: normalizedFormat,
            frameRate: VideoFrameRate(numerator: request.frameRate, denominator: 1),
            fingerprint: "avfoundation-runtime-\(request.sequenceNumber)-\(request.width)x\(request.height)-\(normalizedFormat)"
        ),
        payload: payload
    )
}

func directPeerNormalizedVideoPixelFormat(_ pixelFormat: String) -> String {
    normalizedVideoPixelFormat(pixelFormat)
}

func directPeerVideoBytesPerPixel(_ pixelFormat: String) -> Int {
    videoBytesPerPixel(for: pixelFormat)
}
