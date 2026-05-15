import Foundation

public enum ProductionVideoHardwareKind: String, Codable, Equatable, Sendable {
    case atem
    case deckLink
    case ultraStudio
    case blackmagicCapture
    case genericCamera

    var isBlackmagicProductionTarget: Bool {
        switch self {
        case .atem, .deckLink, .ultraStudio, .blackmagicCapture:
            true
        case .genericCamera:
            false
        }
    }
}

public enum ProductionVideoConnectionMethod: String, Codable, Equatable, Sendable {
    case usbUvc
    case thunderbolt
    case pcie
    case unknown
}

public enum BlackmagicDesktopVideoSdkStatus: String, Codable, Equatable, Sendable {
    case notLinkedOptionalBoundary
    case linked
    case unavailable
    case requiredAfterMeasurement
}

public struct ProductionVideoCaptureEvidence: Codable, Equatable, Sendable {
    public var hardwareKind: ProductionVideoHardwareKind
    public var modelName: String
    public var manufacturer: String
    public var connectionMethod: ProductionVideoConnectionMethod
    public var avFoundationVisible: Bool
    public var avFoundationDeviceUniqueId: String?
    public var desktopVideoSdkStatus: BlackmagicDesktopVideoSdkStatus
    public var desktopVideoSdkDecisionNotes: String
    public var atemReadOnlyControlReport: AtemReadOnlyControlReport?

    public init(
        hardwareKind: ProductionVideoHardwareKind,
        modelName: String,
        manufacturer: String,
        connectionMethod: ProductionVideoConnectionMethod,
        avFoundationVisible: Bool,
        avFoundationDeviceUniqueId: String?,
        desktopVideoSdkStatus: BlackmagicDesktopVideoSdkStatus,
        desktopVideoSdkDecisionNotes: String,
        atemReadOnlyControlReport: AtemReadOnlyControlReport?
    ) {
        self.hardwareKind = hardwareKind
        self.modelName = modelName
        self.manufacturer = manufacturer
        self.connectionMethod = connectionMethod
        self.avFoundationVisible = avFoundationVisible
        self.avFoundationDeviceUniqueId = avFoundationDeviceUniqueId
        self.desktopVideoSdkStatus = desktopVideoSdkStatus
        self.desktopVideoSdkDecisionNotes = desktopVideoSdkDecisionNotes
        self.atemReadOnlyControlReport = atemReadOnlyControlReport
    }
}

public enum VideoCaptureValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case unorderedPacketAge
    case invalidFrameAccounting
    case passWithoutAVFoundationCapture
    case passWithoutDeviceUniqueId
    case passWithoutProductionCaptureEvidence
    case passWithoutBlackmagicProductionTarget(ProductionVideoHardwareKind)
    case passWithProductionDeviceMismatch(expected: String, actual: String)
    case passWithRequiredDesktopVideoSdk
    case passWithoutFrameIntervalMetrics
    case passWithoutProcessCpuMetrics
    case passWithoutProcessMemoryMetrics
    case passIncreasesAudioP99(baseline: Double, video: Double)
    case passIncreasesAudioMax(baseline: Double, video: Double)
    case passChangesAudioPlayoutTarget(baseline: Int, video: Int)
    case passWithUnderruns(Int)
    case passWithHiddenAudioImpact
}

public struct VideoCaptureReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var stream: VideoCaptureStreamMetadata
    public var source: VideoSourceDescription
    public var format: VideoCaptureFormat
    public var durationSeconds: Double
    public var queue: VideoQueueMetrics
    public var framesCaptured: Int
    public var framesRetained: Int
    public var frameAge: UdpPcmPacketAgeMetrics
    public var frameInterval: UdpPcmPacketAgeMetrics?
    public var audioImpact: VideoAudioImpactMetrics
    public var processCpu: VideoProcessCpuMetrics?
    public var processMemory: VideoProcessMemoryMetrics?
    public var productionCaptureEvidence: ProductionVideoCaptureEvidence?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        stream: VideoCaptureStreamMetadata = .syntheticTestPattern,
        source: VideoSourceDescription,
        format: VideoCaptureFormat,
        durationSeconds: Double,
        queue: VideoQueueMetrics,
        framesCaptured: Int,
        framesRetained: Int,
        frameAge: UdpPcmPacketAgeMetrics,
        frameInterval: UdpPcmPacketAgeMetrics? = nil,
        audioImpact: VideoAudioImpactMetrics,
        processCpu: VideoProcessCpuMetrics? = nil,
        processMemory: VideoProcessMemoryMetrics? = nil,
        productionCaptureEvidence: ProductionVideoCaptureEvidence? = nil,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.stream = stream
        self.source = source
        self.format = format
        self.durationSeconds = durationSeconds
        self.queue = queue
        self.framesCaptured = framesCaptured
        self.framesRetained = framesRetained
        self.frameAge = frameAge
        self.frameInterval = frameInterval
        self.audioImpact = audioImpact
        self.processCpu = processCpu
        self.processMemory = processMemory
        self.productionCaptureEvidence = productionCaptureEvidence
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try validateShape()
        try validatePassVerdict()
    }

    private func validateShape() throws {
        try requireVideoCaptureNonEmpty(id, "id")
        try requireVideoCaptureNonEmpty(title, "title")
        try requireVideoCaptureNonEmpty(capturedAt, "capturedAt")
        try requireVideoCapturePositive(stream.streamID, "stream.streamID")
        guard stream.sourceRole != .disabled else {
            throw VideoCaptureValidationError.emptyField("stream.sourceRole")
        }
        try requireVideoCaptureNonEmpty(source.label, "source.label")
        try requireVideoCaptureNonEmpty(source.permissionStatus, "source.permissionStatus")
        try requireVideoCaptureOptionalNonEmpty(source.deviceUniqueId, "source.deviceUniqueId")
        try requireVideoCaptureNonEmpty(format.pixelFormat, "format.pixelFormat")
        try requireVideoCapturePositive(format.width, "format.width")
        try requireVideoCapturePositive(format.height, "format.height")
        try requireVideoCapturePositive(format.nominalFrameRate, "format.nominalFrameRate")
        try requireVideoCapturePositive(durationSeconds, "durationSeconds")
        try requireVideoCapturePositive(queue.maxDepth, "queue.maxDepth")
        try requireVideoCaptureNonNegative(queue.observedMaxDepth, "queue.observedMaxDepth")
        try requireVideoCaptureNonNegative(queue.droppedFrames, "queue.droppedFrames")
        try requireVideoCaptureNonNegative(framesCaptured, "framesCaptured")
        try requireVideoCaptureNonNegative(framesRetained, "framesRetained")
        try requireVideoCapturePacketAge(frameAge, fieldPrefix: "frameAge")
        if let frameInterval {
            try requireVideoCapturePacketAge(frameInterval, fieldPrefix: "frameInterval")
        }
        try validateAudioImpact()
        try validateProcessCpu()
        try validateProcessMemory()
        try validateProductionEvidence()

        guard framesRetained <= framesCaptured else {
            throw VideoCaptureValidationError.invalidFrameAccounting
        }
        try requireVideoCaptureNonEmpty(notes, "notes")
    }

    private func validateAudioImpact() throws {
        try requireVideoCaptureNonNegative(
            audioImpact.baselineCallbackP99Microseconds,
            "audioImpact.baselineCallbackP99Microseconds"
        )
        try requireVideoCaptureNonNegative(
            audioImpact.videoCallbackP99Microseconds,
            "audioImpact.videoCallbackP99Microseconds"
        )
        try requireVideoCaptureNonNegative(
            audioImpact.baselineCallbackMaxMicroseconds,
            "audioImpact.baselineCallbackMaxMicroseconds"
        )
        try requireVideoCaptureNonNegative(
            audioImpact.videoCallbackMaxMicroseconds,
            "audioImpact.videoCallbackMaxMicroseconds"
        )
        try requireVideoCapturePositive(
            audioImpact.baselinePlayoutTargetFrames,
            "audioImpact.baselinePlayoutTargetFrames"
        )
        try requireVideoCapturePositive(
            audioImpact.videoPlayoutTargetFrames,
            "audioImpact.videoPlayoutTargetFrames"
        )
        try requireVideoCaptureNonNegative(audioImpact.underruns, "audioImpact.underruns")
    }

    private func validateProcessCpu() throws {
        guard let processCpu else {
            return
        }
        try requireVideoCaptureNonNegative(processCpu.userSeconds, "processCpu.userSeconds")
        try requireVideoCaptureNonNegative(processCpu.systemSeconds, "processCpu.systemSeconds")
    }

    private func validateProcessMemory() throws {
        guard let processMemory else {
            return
        }
        try requireVideoCapturePositive(
            processMemory.residentPeakBytes,
            "processMemory.residentPeakBytes"
        )
    }

    private func validateProductionEvidence() throws {
        guard let evidence = productionCaptureEvidence else {
            return
        }
        try requireVideoCaptureNonEmpty(evidence.modelName, "productionCaptureEvidence.modelName")
        try requireVideoCaptureNonEmpty(evidence.manufacturer, "productionCaptureEvidence.manufacturer")
        try requireVideoCaptureOptionalNonEmpty(
            evidence.avFoundationDeviceUniqueId,
            "productionCaptureEvidence.avFoundationDeviceUniqueId"
        )
        try requireVideoCaptureNonEmpty(
            evidence.desktopVideoSdkDecisionNotes,
            "productionCaptureEvidence.desktopVideoSdkDecisionNotes"
        )
        try evidence.atemReadOnlyControlReport?.validate()
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        guard source.kind == .avFoundation, source.permissionStatus == "authorized" else {
            throw VideoCaptureValidationError.passWithoutAVFoundationCapture
        }
        guard let deviceUniqueId = source.deviceUniqueId, !deviceUniqueId.isEmpty else {
            throw VideoCaptureValidationError.passWithoutDeviceUniqueId
        }
        guard let evidence = productionCaptureEvidence else {
            throw VideoCaptureValidationError.passWithoutProductionCaptureEvidence
        }
        guard evidence.hardwareKind.isBlackmagicProductionTarget else {
            throw VideoCaptureValidationError.passWithoutBlackmagicProductionTarget(
                evidence.hardwareKind
            )
        }
        if let evidenceDeviceId = evidence.avFoundationDeviceUniqueId,
           evidenceDeviceId != deviceUniqueId {
            throw VideoCaptureValidationError.passWithProductionDeviceMismatch(
                expected: deviceUniqueId,
                actual: evidenceDeviceId
            )
        }
        guard evidence.desktopVideoSdkStatus != .requiredAfterMeasurement else {
            throw VideoCaptureValidationError.passWithRequiredDesktopVideoSdk
        }
        guard frameInterval != nil else {
            throw VideoCaptureValidationError.passWithoutFrameIntervalMetrics
        }
        guard processCpu != nil else {
            throw VideoCaptureValidationError.passWithoutProcessCpuMetrics
        }
        guard processMemory != nil else {
            throw VideoCaptureValidationError.passWithoutProcessMemoryMetrics
        }
        if audioImpact.videoCallbackP99Microseconds > audioImpact.baselineCallbackP99Microseconds {
            throw VideoCaptureValidationError.passIncreasesAudioP99(
                baseline: audioImpact.baselineCallbackP99Microseconds,
                video: audioImpact.videoCallbackP99Microseconds
            )
        }
        if audioImpact.videoCallbackMaxMicroseconds > audioImpact.baselineCallbackMaxMicroseconds {
            throw VideoCaptureValidationError.passIncreasesAudioMax(
                baseline: audioImpact.baselineCallbackMaxMicroseconds,
                video: audioImpact.videoCallbackMaxMicroseconds
            )
        }
        if audioImpact.videoPlayoutTargetFrames != audioImpact.baselinePlayoutTargetFrames {
            throw VideoCaptureValidationError.passChangesAudioPlayoutTarget(
                baseline: audioImpact.baselinePlayoutTargetFrames,
                video: audioImpact.videoPlayoutTargetFrames
            )
        }
        if audioImpact.underruns > 0 {
            throw VideoCaptureValidationError.passWithUnderruns(audioImpact.underruns)
        }
        if audioImpact.hiddenAudioImpactDetected {
            throw VideoCaptureValidationError.passWithHiddenAudioImpact
        }
    }
}
