// Opens an AVFoundation device, applies capture format, collects frames for a bounded duration, and restores the device afterward.
import Foundation
import Dispatch
import os
#if canImport(Darwin)
import Darwin
#endif
#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
#endif

/// Reports `cameraNotAuthorized`, `cameraNotFound`, `captureUnavailable`, and `emptyPixelBufferBaseAddress` failures that stop invalid video capture and frame transport work before it reaches a live path.
public enum VideoCaptureProbeError: Error, Equatable, Sendable {
    case cameraNotAuthorized(AVFoundationPermissionStatus)
    case cameraNotFound(String?)
    case captureUnavailable
    case emptyPixelBufferBaseAddress
    case emptyRawFramePayload
    case invalidPixelBufferLayout(widthBytes: Int, bytesPerRow: Int, height: Int)
    case planarPixelBufferUnsupported
    case pixelBufferLockFailed(Int32)
    case unsupportedPixelBufferFormat(String)
    case unsupportedFrameRate(Double)
}

/// Executes a bounded AVFoundation capture run and returns accountable frame and timing evidence.
public enum AVFoundationVideoCaptureRunner {
    static let logger = Logger(subsystem: "de.hfmt.open-lola", category: "AVFoundationVideoCaptureRunner")

    public static func makeReport(
        snapshot: AVFoundationCameraSourceSnapshot,
        configuration: VideoCaptureRunConfiguration,
        capturedAt: String,
        nowNanoseconds: UInt64,
        processCpu: VideoProcessCpuMetrics?,
        processMemory: VideoProcessMemoryMetrics? = nil,
        productionCaptureEvidence: ProductionVideoCaptureEvidence? = nil
    ) throws -> VideoCaptureReport {
        return VideoCaptureReport(
            identity: videoCaptureReportIdentity(snapshot: snapshot, capturedAt: capturedAt),
            capture: videoCaptureReportCapture(snapshot: snapshot, configuration: configuration),
            frameMetrics: videoCaptureReportFrameMetrics(snapshot: snapshot, nowNanoseconds: nowNanoseconds),
            runtimeEvidence: videoCaptureReportRuntimeEvidence(
                snapshot: snapshot,
                configuration: configuration,
                processCpu: processCpu,
                processMemory: processMemory,
                productionCaptureEvidence: productionCaptureEvidence
            ),
            outcome: videoCaptureReportOutcome(configuration: configuration)
        )
    }

    private static func videoCaptureReportIdentity(
        snapshot: AVFoundationCameraSourceSnapshot,
        capturedAt: String
    ) -> VideoCaptureReport.Identity {
        .init(
            id: "m08-avfoundation-capture-run",
            title: "AVFoundation video capture run",
            capturedAt: capturedAt,
            stream: snapshot.stream
        )
    }

    private static func videoCaptureReportCapture(
        snapshot: AVFoundationCameraSourceSnapshot,
        configuration: VideoCaptureRunConfiguration
    ) -> VideoCaptureReport.Capture {
        .init(
            source: snapshot.source,
            format: snapshot.format,
            durationSeconds: Double(configuration.durationSeconds),
            queue: snapshot.queue
        )
    }

    private static func videoCaptureReportFrameMetrics(
        snapshot: AVFoundationCameraSourceSnapshot,
        nowNanoseconds: UInt64
    ) -> VideoCaptureReport.FrameMetrics {
        let ages = snapshot.retainedFrameTimestampsNanoseconds.map { timestamp in
            Double(nowNanoseconds >= timestamp ? nowNanoseconds - timestamp : 0) / 1_000
        }
        let intervals = videoCaptureIntervalsMicroseconds(
            from: snapshot.capturedFrameTimestampsNanoseconds
        )
        return .init(
            framesCaptured: snapshot.framesCaptured,
            framesRetained: snapshot.framesRetained,
            frameAge: videoCapturePacketAge(from: ages),
            frameInterval: videoCapturePacketAge(from: intervals)
        )
    }

    private static func videoCaptureReportRuntimeEvidence(
        snapshot: AVFoundationCameraSourceSnapshot,
        configuration: VideoCaptureRunConfiguration,
        processCpu: VideoProcessCpuMetrics?,
        processMemory: VideoProcessMemoryMetrics?,
        productionCaptureEvidence: ProductionVideoCaptureEvidence?
    ) -> VideoCaptureReport.RuntimeEvidence {
        .init(
            audioImpact: configuration.audioImpact ?? defaultVideoCaptureAudioImpact(),
            processCpu: processCpu,
            processMemory: processMemory,
            productionCaptureEvidence: productionCaptureEvidence,
            rawCapture: snapshot.rawCapture
        )
    }

    private static func videoCaptureReportOutcome(
        configuration: VideoCaptureRunConfiguration
    ) -> VideoCaptureReport.Outcome {
        .init(
            verdict: configuration.requestedVerdict,
            notes: videoCaptureRunNotes(configuration: configuration)
        )
    }

    public static func run(configuration: VideoCaptureRunConfiguration) throws -> VideoCaptureReport {
        #if canImport(AVFoundation)
        let context = try makeRunContext(configuration: configuration)
        let captureSession = context.captureSession
        defer {
            captureSession.restoreDevice(logger: Self.logger)
        }
        let result = try captureSnapshot(context: context, durationSeconds: configuration.durationSeconds)
        return try makeReport(
            snapshot: result.snapshot,
            configuration: configuration,
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            nowNanoseconds: result.nowNanoseconds,
            processCpu: videoCaptureProcessCpuDelta(from: result.startCpu, to: result.endCpu),
            processMemory: currentVideoCaptureProcessMemory(),
            productionCaptureEvidence: productionEvidence(for: context, configuration: configuration)
        )
        #else
        throw VideoCaptureProbeError.captureUnavailable
        #endif
    }

    #if canImport(AVFoundation)
    private static func makeRunContext(
        configuration: VideoCaptureRunConfiguration
    ) throws -> AVFoundationVideoCaptureRunContext {
        let permission = resolveAVFoundationVideoPermission()
        guard permission == .authorized else {
            throw VideoCaptureProbeError.cameraNotAuthorized(permission)
        }
        let selected = try authorizedAVFoundationDevice(configuration: configuration)
        let source = VideoSourceDescription(
            kind: .avFoundation,
            label: selected.localizedName,
            deviceUniqueId: selected.uniqueID,
            permissionStatus: permission.rawValue
        )
        let format = videoCaptureFormat(
            for: selected.activeFormat,
            requestedFrameRate: configuration.requestedFrameRate
        )
        let collector = AVFoundationSampleBufferCollector(
            stream: AVFoundationSampleBufferStreamConfiguration(queueDepth: configuration.queueDepth, streamID: configuration.streamID, frameRate: videoFrameRate(from: configuration.requestedFrameRate))
        )
        let captureSession = try makeAVFoundationCaptureSession(
            device: selected,
            collector: collector,
            requestedFrameRate: configuration.requestedFrameRate
        )
        return AVFoundationVideoCaptureRunContext(
            selectedDescription: avFoundationDeviceDescription(for: selected),
            source: source,
            format: format,
            collector: collector,
            captureSession: captureSession
        )
    }

    private static func authorizedAVFoundationDevice(
        configuration: VideoCaptureRunConfiguration
    ) throws -> AVCaptureDevice {
        let selected = try selectedAVFoundationDevice(
            from: currentAVCaptureVideoDevices(),
            requestedUniqueId: configuration.deviceUniqueId
        )
        guard let selected else {
            throw VideoCaptureProbeError.cameraNotFound(configuration.deviceUniqueId)
        }
        return selected
    }

    private static func captureSnapshot(
        context: AVFoundationVideoCaptureRunContext,
        durationSeconds: Int
    ) throws -> AVFoundationVideoCaptureRunResult {
        let startCpu = currentVideoCaptureProcessCpu()
        context.captureSession.startRunning()
        waitForAVFoundationCaptureDuration(seconds: durationSeconds)
        context.captureSession.stopRunning()
        let now = DispatchTime.now().uptimeNanoseconds
        let snapshot = context.collector.snapshot(source: context.source, format: context.format)
        guard snapshot.framesCaptured > 0 else {
            throw VideoCaptureProbeError.captureUnavailable
        }
        return AVFoundationVideoCaptureRunResult(
            snapshot: snapshot,
            nowNanoseconds: now,
            startCpu: startCpu,
            endCpu: currentVideoCaptureProcessCpu()
        )
    }

    private static func productionEvidence(
        for context: AVFoundationVideoCaptureRunContext,
        configuration: VideoCaptureRunConfiguration
    ) -> ProductionVideoCaptureEvidence? {
        configuration.productionEvidence?.evidence(for: context.source)
            ?? productionVideoCaptureEvidence(for: context.selectedDescription)
    }
    #endif
}

#if canImport(AVFoundation)
private struct AVFoundationVideoCaptureRunContext {
    var selectedDescription: AVFoundationVideoDeviceDescription
    var source: VideoSourceDescription
    var format: VideoCaptureFormat
    var collector: AVFoundationSampleBufferCollector
    var captureSession: AVFoundationCaptureSessionHandle
}

private struct AVFoundationVideoCaptureRunResult {
    var snapshot: AVFoundationCameraSourceSnapshot
    var nowNanoseconds: UInt64
    var startCpu: VideoProcessCpuMetrics?
    var endCpu: VideoProcessCpuMetrics?
}
#endif

final class VideoCaptureSessionWorkQueue: @unchecked Sendable {
    private let queue: DispatchQueue

    init(label: String = "open-lola.video-capture.session", qos: DispatchQoS = .userInitiated) {
        queue = DispatchQueue(label: label, qos: qos)
    }

    func start(_ operation: @escaping @Sendable () -> Void) {
        queue.async(execute: operation)
    }

    func stop(_ operation: () -> Void) {
        queue.sync(execute: operation)
    }
}

private func waitForAVFoundationCaptureDuration(seconds: Int) {
    Thread.sleep(forTimeInterval: Double(seconds))
}

func defaultVideoCaptureAudioImpact() -> VideoAudioImpactMetrics {
    VideoAudioImpactMetrics(
        baselineCallbackP99Microseconds: 80,
        videoCallbackP99Microseconds: 80,
        baselineCallbackMaxMicroseconds: 95,
        videoCallbackMaxMicroseconds: 95,
        baselinePlayoutTargetFrames: 32,
        videoPlayoutTargetFrames: 32,
        underruns: 0,
        hiddenAudioImpactDetected: false,
        synthetic: true
    )
}

#if canImport(AVFoundation)
func selectedAVFoundationDevice(
    from devices: [AVCaptureDevice],
    requestedUniqueId: String?
) throws -> AVCaptureDevice? {
    if let requestedUniqueId {
        return devices.first(where: { $0.uniqueID == requestedUniqueId })
    }
    let descriptions = devices.map(avFoundationDeviceDescription)
    guard let preferred = preferredAVFoundationVideoDevice(from: descriptions) else {
        return nil
    }
    return devices.first(where: { $0.uniqueID == preferred.uniqueId })
}

func avFoundationDeviceDescription(
    for device: AVCaptureDevice
) -> AVFoundationVideoDeviceDescription {
    AVFoundationVideoDeviceDescription.make(
        label: device.localizedName,
        uniqueId: device.uniqueID,
        modelId: device.modelID,
        manufacturer: device.manufacturer,
        transport: "AVFoundation",
        formats: device.formats.map(avFoundationFormatDescription)
    )
}

func videoCaptureFormat(
    for format: AVCaptureDevice.Format,
    requestedFrameRate: Double
) -> VideoCaptureFormat {
    let activeFormat = avFoundationFormatDescription(format)
    let nominalFrameRate = activeFormat.maxFrameRate > 0
        ? min(requestedFrameRate, activeFormat.maxFrameRate)
        : requestedFrameRate
    return VideoCaptureFormat(
        width: activeFormat.width,
        height: activeFormat.height,
        nominalFrameRate: nominalFrameRate,
        pixelFormat: activeFormat.pixelFormat
    )
}

func makeAVFoundationCaptureSession(
    device: AVCaptureDevice,
    collector: AVFoundationSampleBufferCollector,
    requestedFrameRate: Double
) throws -> AVFoundationCaptureSessionHandle {
    let restorePoint = try configureAVFoundationDevice(device, requestedFrameRate: requestedFrameRate)
    var restoreOnFailure: AVFoundationVideoDeviceRestorePoint? = restorePoint
    defer {
        restoreOnFailure?.restore(logger: AVFoundationVideoCaptureRunner.logger)
    }
    let input = try AVCaptureDeviceInput(device: device)
    let session = AVCaptureSession()
    session.beginConfiguration()

    guard session.canAddInput(input) else {
        session.commitConfiguration()
        throw VideoCaptureProbeError.captureUnavailable
    }
    session.addInput(input)

    let output = AVCaptureVideoDataOutput()
    output.alwaysDiscardsLateVideoFrames = true
    output.setSampleBufferDelegate(
        collector,
        queue: collector.captureQueue
    )
    guard session.canAddOutput(output) else {
        session.commitConfiguration()
        throw VideoCaptureProbeError.captureUnavailable
    }
    session.addOutput(output)
    session.commitConfiguration()
    restoreOnFailure = nil
    return AVFoundationCaptureSessionHandle(session: session, restorePoint: restorePoint)
}

func configureAVFoundationDevice(
    _ device: AVCaptureDevice,
    requestedFrameRate: Double
) throws -> AVFoundationVideoDeviceRestorePoint {
    guard requestedFrameRate > 0 else {
        throw VideoCaptureProbeError.unsupportedFrameRate(requestedFrameRate)
    }
    guard device.activeFormat.videoSupportedFrameRateRanges.contains(where: { range in
        range.minFrameRate <= requestedFrameRate && requestedFrameRate <= range.maxFrameRate
    }) else {
        throw VideoCaptureProbeError.unsupportedFrameRate(requestedFrameRate)
    }

    let scaledTimescale = (requestedFrameRate * 1_000_000).rounded()
    guard scaledTimescale > 0, scaledTimescale <= Double(Int32.max) else {
        throw VideoCaptureProbeError.unsupportedFrameRate(requestedFrameRate)
    }
    let timescale = CMTimeScale(scaledTimescale)
    try device.lockForConfiguration()
    defer {
        device.unlockForConfiguration()
    }
    let duration = CMTime(value: 1_000_000, timescale: timescale)
    let restorePoint = AVFoundationVideoDeviceRestorePoint(
        device: device,
        minFrameDuration: device.activeVideoMinFrameDuration,
        maxFrameDuration: device.activeVideoMaxFrameDuration
    )
    device.activeVideoMinFrameDuration = duration
    device.activeVideoMaxFrameDuration = duration
    return restorePoint
}

struct AVFoundationCaptureSessionHandle {
    var session: AVCaptureSession
    var restorePoint: AVFoundationVideoDeviceRestorePoint
    var workQueue = VideoCaptureSessionWorkQueue()

    func startRunning() {
        workQueue.start {
            session.startRunning()
        }
    }

    func stopRunning() {
        workQueue.stop {
            session.stopRunning()
        }
    }

    func restoreDevice(logger: Logger) {
        stopRunning()
        restorePoint.restore(logger: logger)
    }
}

struct AVFoundationVideoDeviceRestorePoint {
    var device: AVCaptureDevice
    var minFrameDuration: CMTime
    var maxFrameDuration: CMTime

    func restore(logger: Logger) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.activeVideoMinFrameDuration = minFrameDuration
            device.activeVideoMaxFrameDuration = maxFrameDuration
        } catch {
            let description = String(describing: error)
            logger.warning("AVFoundation device restore failed: \(description, privacy: .public)")
        }
    }
}
#endif
