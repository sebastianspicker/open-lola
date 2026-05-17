import Foundation
import Dispatch
#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
#endif

public enum AVFoundationPermissionStatus: String, Codable, Equatable, Sendable {
    case authorized
    case denied
    case restricted
    case notDetermined
    case requestTimedOut
    case unknown
}

public enum AVFoundationVideoSourcePolicy: String, Codable, Equatable, Sendable {
    case genericAvFoundation
    case blackmagicFirstAvFoundationFallback
}

public struct AVFoundationVideoFormatDescription: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var maxFrameRate: Double
    public var pixelFormat: String

    public init(width: Int, height: Int, maxFrameRate: Double, pixelFormat: String) {
        self.width = width
        self.height = height
        self.maxFrameRate = maxFrameRate
        self.pixelFormat = pixelFormat
    }
}

public struct AVFoundationVideoDeviceDescription: Codable, Equatable, Sendable {
    public var label: String
    public var uniqueId: String
    public var modelId: String
    public var manufacturer: String
    public var transport: String
    public var sourcePolicy: AVFoundationVideoSourcePolicy
    public var formats: [AVFoundationVideoFormatDescription]

    public init(
        label: String,
        uniqueId: String,
        modelId: String,
        manufacturer: String,
        transport: String,
        sourcePolicy: AVFoundationVideoSourcePolicy,
        formats: [AVFoundationVideoFormatDescription]
    ) {
        self.label = label
        self.uniqueId = uniqueId
        self.modelId = modelId
        self.manufacturer = manufacturer
        self.transport = transport
        self.sourcePolicy = sourcePolicy
        self.formats = formats
    }

    public var sourceKind: VideoSourceKind {
        .avFoundation
    }

    public var isExternalCaptureCandidate: Bool {
        sourcePolicy == .blackmagicFirstAvFoundationFallback
    }

    public static func make(
        label: String,
        uniqueId: String,
        modelId: String = "unknown",
        manufacturer: String = "unknown",
        transport: String = "unknown",
        formats: [AVFoundationVideoFormatDescription]
    ) -> AVFoundationVideoDeviceDescription {
        let policy = videoCaptureSourcePolicy(for: label)
        return AVFoundationVideoDeviceDescription(
            label: label,
            uniqueId: uniqueId,
            modelId: modelId,
            manufacturer: videoCaptureManufacturer(label: label, fallback: manufacturer),
            transport: transport,
            sourcePolicy: policy,
            formats: formats
        )
    }
}

public struct AVFoundationVideoDeviceInventoryReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var permissionStatus: AVFoundationPermissionStatus
    public var devices: [AVFoundationVideoDeviceDescription]
    public var blackmagicSdkStatus: BlackmagicDesktopVideoSdkStatus
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        permissionStatus: AVFoundationPermissionStatus,
        devices: [AVFoundationVideoDeviceDescription],
        blackmagicSdkStatus: BlackmagicDesktopVideoSdkStatus,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.permissionStatus = permissionStatus
        self.devices = devices
        self.blackmagicSdkStatus = blackmagicSdkStatus
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try requireVideoCaptureNonEmpty(id, "id")
        try requireVideoCaptureNonEmpty(title, "title")
        try requireVideoCaptureNonEmpty(capturedAt, "capturedAt")
        try requireVideoCaptureNonEmpty(notes, "notes")
        for (index, device) in devices.enumerated() {
            try requireVideoCaptureNonEmpty(device.label, "devices[\(index)].label")
            try requireVideoCaptureNonEmpty(device.uniqueId, "devices[\(index)].uniqueId")
            try requireVideoCaptureNonEmpty(device.modelId, "devices[\(index)].modelId")
            try requireVideoCaptureNonEmpty(device.manufacturer, "devices[\(index)].manufacturer")
            try requireVideoCaptureNonEmpty(device.transport, "devices[\(index)].transport")
            for (formatIndex, format) in device.formats.enumerated() {
                try requireVideoCapturePositive(
                    format.width,
                    "devices[\(index)].formats[\(formatIndex)].width"
                )
                try requireVideoCapturePositive(
                    format.height,
                    "devices[\(index)].formats[\(formatIndex)].height"
                )
                try requireVideoCapturePositive(
                    format.maxFrameRate,
                    "devices[\(index)].formats[\(formatIndex)].maxFrameRate"
                )
                try requireVideoCaptureNonEmpty(
                    format.pixelFormat,
                    "devices[\(index)].formats[\(formatIndex)].pixelFormat"
                )
            }
        }
    }
}

public struct AVFoundationVideoDeviceInventoryReader: Sendable {
    public init() {}

    public func capture() -> AVFoundationVideoDeviceInventoryReport {
        AVFoundationVideoDeviceInventoryReport(
            id: "m08-avfoundation-video-device-inventory",
            title: "AVFoundation video device inventory",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            permissionStatus: currentAVFoundationPermissionStatus(),
            devices: currentAVFoundationVideoDevices(),
            blackmagicSdkStatus: .notLinkedOptionalBoundary,
            verdict: .partial,
            notes: "Read-only AVFoundation inventory; Blackmagic Desktop Video SDK is optional and not linked."
        )
    }
}

func videoCaptureSourcePolicy(for label: String) -> AVFoundationVideoSourcePolicy {
    let normalized = label.lowercased()
    let externalTokens = ["atem", "uvc", "decklink", "deck link", "ultrastudio", "blackmagic", "capture"]
    if externalTokens.contains(where: { normalized.contains($0) }) {
        return .blackmagicFirstAvFoundationFallback
    }
    return .genericAvFoundation
}

func videoCaptureManufacturer(label: String, fallback: String) -> String {
    let normalized = label.lowercased()
    if normalized.contains("atem")
        || normalized.contains("decklink")
        || normalized.contains("ultrastudio")
        || normalized.contains("blackmagic") {
        return "Blackmagic Design"
    }
    return fallback
}

func preferredAVFoundationVideoDevice(
    from devices: [AVFoundationVideoDeviceDescription]
) -> AVFoundationVideoDeviceDescription? {
    devices.first(where: \.isExternalCaptureCandidate) ?? devices.first
}

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
        hardwareKind: hardwareKind,
        modelName: device.label,
        manufacturer: videoCaptureManufacturer(
            label: device.label,
            fallback: device.manufacturer
        ),
        connectionMethod: productionVideoConnectionMethod(
            label: device.label,
            transport: device.transport
        ),
        avFoundationVisible: true,
        avFoundationDeviceUniqueId: device.uniqueId,
        desktopVideoSdkStatus: .notLinkedOptionalBoundary,
        desktopVideoSdkDecisionNotes: "AVFoundation exposes this Blackmagic/ATEM capture path; Desktop Video SDK remains optional until measured need.",
        atemReadOnlyControlReport: nil
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
    if normalized.contains("uvc") || normalized.contains("usb") || normalized.contains("atem") {
        return .usbUvc
    }
    if normalized.contains("thunderbolt") || normalized.contains("ultrastudio") {
        return .thunderbolt
    }
    if normalized.contains("pcie") || normalized.contains("pci") || normalized.contains("decklink") {
        return .pcie
    }
    return .unknown
}

func currentAVFoundationPermissionStatus() -> AVFoundationPermissionStatus {
    #if canImport(AVFoundation)
    AVFoundationPermissionStatus(authorizationStatus: AVCaptureDevice.authorizationStatus(for: .video))
    #else
    .unknown
    #endif
}

func currentAVFoundationVideoDevices() -> [AVFoundationVideoDeviceDescription] {
    #if canImport(AVFoundation)
    return currentAVCaptureVideoDevices().map { device in
        AVFoundationVideoDeviceDescription.make(
            label: device.localizedName,
            uniqueId: device.uniqueID,
            modelId: device.modelID,
            manufacturer: device.manufacturer,
            transport: "AVFoundation",
            formats: device.formats.map(avFoundationFormatDescription)
        )
    }
    #else
    return []
    #endif
}

#if canImport(AVFoundation)
func currentAVCaptureVideoDevices() -> [AVCaptureDevice] {
    AVCaptureDevice.DiscoverySession(
        deviceTypes: [
            .external,
            .builtInWideAngleCamera,
            .continuityCamera,
            .deskViewCamera,
        ],
        mediaType: .video,
        position: .unspecified
    ).devices
}
#endif

func resolveAVFoundationVideoPermission() -> AVFoundationPermissionStatus {
    #if canImport(AVFoundation)
    let current = AVCaptureDevice.authorizationStatus(for: .video)
    guard current == .notDetermined else {
        return AVFoundationPermissionStatus(authorizationStatus: current)
    }

    let semaphore = DispatchSemaphore(value: 0)
    AVCaptureDevice.requestAccess(for: .video) { _ in
        semaphore.signal()
    }
    guard semaphore.wait(timeout: .now() + 5.0) == .success else {
        return .requestTimedOut
    }
    return AVFoundationPermissionStatus(
        authorizationStatus: AVCaptureDevice.authorizationStatus(for: .video)
    )
    #else
    return .unknown
    #endif
}

#if canImport(AVFoundation)
extension AVFoundationPermissionStatus {
    init(authorizationStatus: AVAuthorizationStatus) {
        switch authorizationStatus {
        case .authorized:
            self = .authorized
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .notDetermined:
            self = .notDetermined
        @unknown default:
            self = .unknown
        }
    }
}

private let rawFrameDataCompactionThresholdBytes = 8 * 1024 * 1024
typealias AVFoundationRawFrameExtractor = (CVPixelBuffer) throws -> Data

func avFoundationFormatDescription(
    _ format: AVCaptureDevice.Format
) -> AVFoundationVideoFormatDescription {
    let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
    let frameRate = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
    return AVFoundationVideoFormatDescription(
        width: Int(dimensions.width),
        height: Int(dimensions.height),
        maxFrameRate: frameRate,
        pixelFormat: videoCaptureFourCCString(
            CMFormatDescriptionGetMediaSubType(format.formatDescription)
        )
    )
}

final class AVFoundationSampleBufferCollector: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let captureQueue = DispatchQueue(label: "open-lola.video-capture.avfoundation", qos: .userInitiated)
    private let stateLock = NSLock()
    // Lock coverage for @unchecked Sendable: latestFrameQueue,
    // capturedTimestampsNanoseconds, callbackArrivalTimestampsNanoseconds,
    // rawFrameData, rawFrameDataBaseOffset, rawFrameIndex,
    // latestRawCapturedFrame, raw extraction counters/errors, and
    // nextSequenceNumber are
    // read or written only while stateLock is held. The remaining stored
    // properties are immutable after init.
    private var latestFrameQueue: LatestFrameQueue
    private var capturedTimestampsNanoseconds: [UInt64] = []
    private var callbackArrivalTimestampsNanoseconds: [UInt64] = []
    private var rawFrameData = Data()
    private var rawFrameDataBaseOffset = 0
    private var rawFrameIndex: [RecordingVideoFrameIndexEntry] = []
    private var latestRawCapturedFrame: RawCapturedVideoFrame?
    private var rawExtractionAttempts = 0
    private var rawExtractionFailures = 0
    private var rawPayloadsCaptured = 0
    private var lastRawExtractionError: String?
    private var nextSequenceNumber: UInt64 = 0
    private let streamID: UInt32
    private let frameRate: VideoFrameRate
    private let captureRawFrames: Bool
    private let retainRawFrameArtifact: Bool
    private let maxRetainedRawFrameCount: Int
    private let rawFrameExtractor: AVFoundationRawFrameExtractor

    init(
        queueDepth: Int,
        streamID: UInt32,
        frameRate: VideoFrameRate,
        captureRawFrames: Bool = false,
        retainRawFrameArtifact: Bool = true,
        maxRetainedRawFrameCount: Int = 120,
        rawFrameExtractor: @escaping AVFoundationRawFrameExtractor = { try rawFrameBytes(from: $0) }
    ) {
        self.latestFrameQueue = LatestFrameQueue(maxDepth: queueDepth)
        self.streamID = streamID
        self.frameRate = frameRate
        self.captureRawFrames = captureRawFrames
        self.retainRawFrameArtifact = retainRawFrameArtifact
        self.maxRetainedRawFrameCount = max(1, maxRetainedRawFrameCount)
        self.rawFrameExtractor = rawFrameExtractor
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        _ = output
        _ = connection
        record(sampleBuffer: sampleBuffer)
    }

    func record(sampleBuffer: CMSampleBuffer) {
        autoreleasepool {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }

            let callbackArrivalNanoseconds = DispatchTime.now().uptimeNanoseconds
            let timestampNanoseconds = avFoundationPresentationTimestampNanoseconds(
                sampleBuffer: sampleBuffer,
                fallbackNanoseconds: callbackArrivalNanoseconds
            )
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            let pixelFormat = videoCaptureFourCCString(CVPixelBufferGetPixelFormatType(imageBuffer))
            let rawExtractionResult: Result<Data, Error>? = captureRawFrames
                ? Result { try rawFrameExtractor(imageBuffer) }
                : nil

            stateLock.lock()
            defer {
                stateLock.unlock()
            }
            let sequenceNumber = nextSequenceNumber
            nextSequenceNumber += 1
            let frame = CapturedVideoFrame(
                streamID: streamID,
                sequenceNumber: sequenceNumber,
                timestampNanoseconds: timestampNanoseconds,
                timestampBasis: .avFoundationPresentationTimeNanoseconds,
                sourceRole: .avFoundationDevice,
                width: width,
                height: height,
                pixelFormat: pixelFormat,
                frameRate: frameRate,
                fingerprint: "avfoundation-\(sequenceNumber)-\(width)x\(height)-\(pixelFormat)"
            )
            capturedTimestampsNanoseconds.append(timestampNanoseconds)
            callbackArrivalTimestampsNanoseconds.append(callbackArrivalNanoseconds)
            latestFrameQueue.enqueue(frame)
            if let rawExtractionResult {
                rawExtractionAttempts += 1
                switch rawExtractionResult {
                case .success(let rawBytes) where !rawBytes.isEmpty:
                    rawPayloadsCaptured += 1
                    saveRawFrame(rawBytes, metadata: frame)
                case .success:
                    recordRawFrameExtractionFailure(VideoCaptureProbeError.emptyRawFramePayload)
                case .failure(let error):
                    recordRawFrameExtractionFailure(error)
                }
            }
        }
    }

    func snapshot(
        source: VideoSourceDescription,
        format: VideoCaptureFormat
    ) -> AVFoundationCameraSourceSnapshot {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        let queue = latestFrameQueue
        let captured = capturedTimestampsNanoseconds
        let callbackArrivals = callbackArrivalTimestampsNanoseconds
        let rawCapture = rawCaptureMetricsLocked()

        return AVFoundationCameraSourceSnapshot(
            source: source,
            stream: VideoCaptureStreamMetadata(
                streamID: streamID,
                sourceRole: .avFoundationDevice,
                timestampBasis: .avFoundationPresentationTimeNanoseconds
            ),
            format: format,
            queue: VideoQueueMetrics(
                policy: .latestFrame,
                maxDepth: queue.maxDepth,
                observedMaxDepth: queue.observedMaxDepth,
                droppedFrames: queue.droppedFrames
            ),
            framesCaptured: captured.count,
            framesRetained: queue.frames.count,
            capturedFrameTimestampsNanoseconds: captured,
            callbackArrivalTimestampsNanoseconds: callbackArrivals,
            retainedFrameTimestampsNanoseconds: queue.frames.map(\.timestampNanoseconds),
            rawCapture: rawCapture
        )
    }

    func rawCaptureMetrics() -> RawVideoCaptureMetrics {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        return rawCaptureMetricsLocked()
    }

    func rawVideoArtifact() -> RecordingCapturedVideo? {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        guard !rawFrameData.isEmpty, !rawFrameIndex.isEmpty else {
            return nil
        }
        let retainedDataStart = min(rawFrameDataBaseOffset, rawFrameData.count)
        return RecordingCapturedVideo(
            rawFrameData: rawFrameData.subdata(in: retainedDataStart..<rawFrameData.count),
            frameIndex: rawFrameIndex.map(normalizedRawFrameIndexEntry)
        )
    }

    func latestRawFrame() -> RawCapturedVideoFrame? {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        if let latestRawCapturedFrame {
            return latestRawCapturedFrame
        }
        guard let entry = rawFrameIndex.last else {
            return nil
        }
        let byteOffset = entry.byteOffset
        guard byteOffset >= 0 else {
            return nil
        }
        let endOffset = byteOffset + entry.byteCount
        guard endOffset <= rawFrameData.count else {
            return nil
        }
        return RawCapturedVideoFrame(
            metadata: CapturedVideoFrame(
                streamID: streamID,
                sequenceNumber: entry.sequenceNumber,
                timestampNanoseconds: entry.timestampNanoseconds,
                timestampBasis: .avFoundationPresentationTimeNanoseconds,
                sourceRole: .avFoundationDevice,
                width: entry.width,
                height: entry.height,
                pixelFormat: entry.pixelFormat,
                frameRate: frameRate,
                fingerprint: "avfoundation-\(entry.sequenceNumber)-\(entry.width)x\(entry.height)-\(entry.pixelFormat)"
            ),
            payload: rawFrameData.subdata(in: byteOffset..<endOffset)
        )
    }

    private func saveRawFrame(_ rawBytes: Data, metadata frame: CapturedVideoFrame) {
        latestRawCapturedFrame = RawCapturedVideoFrame(metadata: frame, payload: rawBytes)
        guard retainRawFrameArtifact else {
            return
        }
        let rawIndexEntry = RecordingVideoFrameIndexEntry(
            sequenceNumber: frame.sequenceNumber,
            timestampNanoseconds: frame.timestampNanoseconds,
            byteOffset: rawFrameData.count,
            byteCount: rawBytes.count,
            width: frame.width,
            height: frame.height,
            pixelFormat: frame.pixelFormat
        )
        rawFrameData.append(rawBytes)
        rawFrameIndex.append(rawIndexEntry)
        trimRawFrameArtifactIfNeeded()
    }

    private func recordRawFrameExtractionFailure(_ error: Error) {
        rawExtractionFailures += 1
        lastRawExtractionError = String(describing: error)
    }

    private func rawCaptureMetricsLocked() -> RawVideoCaptureMetrics {
        guard captureRawFrames else {
            return .disabled
        }
        return RawVideoCaptureMetrics(
            mode: .requested,
            extractionAttempts: rawExtractionAttempts,
            extractionFailures: rawExtractionFailures,
            payloadsCaptured: rawPayloadsCaptured,
            artifactFramesRetained: rawFrameIndex.count,
            lastExtractionError: lastRawExtractionError
        )
    }

    private func trimRawFrameArtifactIfNeeded() {
        var trimmed = false
        while rawFrameIndex.count > maxRetainedRawFrameCount,
              let removed = rawFrameIndex.first {
            rawFrameIndex.removeFirst()
            rawFrameDataBaseOffset = removed.byteOffset + removed.byteCount
            trimmed = true
        }
        if trimmed {
            compactRawFrameDataIfNeeded()
        }
    }

    private func compactRawFrameDataIfNeeded() {
        guard rawFrameDataBaseOffset > 0 else {
            return
        }
        let retainedDataStart = min(rawFrameDataBaseOffset, rawFrameData.count)
        let retainedByteCount = rawFrameData.count - retainedDataStart
        guard rawFrameDataBaseOffset >= rawFrameDataCompactionThresholdBytes
            || rawFrameDataBaseOffset > retainedByteCount else {
            return
        }
        rawFrameData = rawFrameData.subdata(in: retainedDataStart..<rawFrameData.count)
        rawFrameIndex = rawFrameIndex.map { entry in
            RecordingVideoFrameIndexEntry(
                sequenceNumber: entry.sequenceNumber,
                timestampNanoseconds: entry.timestampNanoseconds,
                byteOffset: entry.byteOffset - retainedDataStart,
                byteCount: entry.byteCount,
                width: entry.width,
                height: entry.height,
                pixelFormat: entry.pixelFormat
            )
        }
        rawFrameDataBaseOffset = 0
    }

    private func normalizedRawFrameIndexEntry(
        _ entry: RecordingVideoFrameIndexEntry
    ) -> RecordingVideoFrameIndexEntry {
        RecordingVideoFrameIndexEntry(
            sequenceNumber: entry.sequenceNumber,
            timestampNanoseconds: entry.timestampNanoseconds,
            byteOffset: entry.byteOffset - rawFrameDataBaseOffset,
            byteCount: entry.byteCount,
            width: entry.width,
            height: entry.height,
            pixelFormat: entry.pixelFormat
        )
    }
}

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
    var data = Data()
    if CVPixelBufferIsPlanar(imageBuffer) {
        throw VideoCaptureProbeError.planarPixelBufferUnsupported
    } else if let base = CVPixelBufferGetBaseAddress(imageBuffer) {
        let pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer)
        guard pixelFormat == kCVPixelFormatType_32BGRA else {
            throw VideoCaptureProbeError.unsupportedPixelBufferFormat(videoCaptureFourCCString(pixelFormat))
        }
        let bytesPerPixel = 4
        let widthBytes = CVPixelBufferGetWidth(imageBuffer) * bytesPerPixel
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
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
        let source = base.assumingMemoryBound(to: UInt8.self)
        if bytesPerRow == widthBytes {
            data.append(source, count: contiguousProduct.partialValue)
        } else {
            for row in 0..<height {
                data.append(source.advanced(by: row * bytesPerRow), count: widthBytes)
            }
        }
    } else {
        throw VideoCaptureProbeError.emptyPixelBufferBaseAddress
    }
    return data
}
#endif
