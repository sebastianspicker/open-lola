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
    case invalidRawCaptureAccounting
    case passWithoutRawCaptureEvidence
    case passWithoutRawPayloadEvidence
    case passWithRawCaptureFailures(Int)
    case passIncreasesAudioP99(baseline: Double, video: Double)
    case passIncreasesAudioMax(baseline: Double, video: Double)
    case passChangesAudioPlayoutTarget(baseline: Int, video: Int)
    case passWithUnderruns(Int)
    case passWithHiddenAudioImpact
    case passWithoutAudioImpactProvenance
    case passWithSyntheticAudioImpact
}

extension VideoCaptureValidationError: ValidationEmptyFieldError {}
extension VideoCaptureValidationError: ValidationNonPositiveFieldError {}
extension VideoCaptureValidationError: ValidationNegativeFieldError {}
extension VideoCaptureValidationError: ValidationNonFiniteFieldError {}

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
    public var rawCapture: RawVideoCaptureMetrics?
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
        rawCapture: RawVideoCaptureMetrics? = nil,
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
        self.rawCapture = rawCapture
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try validateShape()
        try validatePassVerdict()
    }

    private func validateShape() throws {
        try VideoCaptureValidator.requireNonEmpty(id, "id")
        try VideoCaptureValidator.requireNonEmpty(title, "title")
        try VideoCaptureValidator.requireNonEmpty(capturedAt, "capturedAt")
        try VideoCaptureValidator.requirePositive(stream.streamID, "stream.streamID")
        guard stream.sourceRole != .disabled else {
            throw VideoCaptureValidationError.emptyField("stream.sourceRole")
        }
        try VideoCaptureValidator.requireNonEmpty(source.label, "source.label")
        try VideoCaptureValidator.requireNonEmpty(source.permissionStatus, "source.permissionStatus")
        try VideoCaptureValidator.requireOptionalNonEmpty(source.deviceUniqueId, "source.deviceUniqueId")
        try VideoCaptureValidator.requireNonEmpty(format.pixelFormat, "format.pixelFormat")
        try VideoCaptureValidator.requirePositive(format.width, "format.width")
        try VideoCaptureValidator.requirePositive(format.height, "format.height")
        try VideoCaptureValidator.requirePositive(format.nominalFrameRate, "format.nominalFrameRate")
        try VideoCaptureValidator.requirePositive(durationSeconds, "durationSeconds")
        try VideoCaptureValidator.requirePositive(queue.maxDepth, "queue.maxDepth")
        try VideoCaptureValidator.requireNonNegative(queue.observedMaxDepth, "queue.observedMaxDepth")
        try VideoCaptureValidator.requireNonNegative(queue.droppedFrames, "queue.droppedFrames")
        try VideoCaptureValidator.requireNonNegative(framesCaptured, "framesCaptured")
        try VideoCaptureValidator.requireNonNegative(framesRetained, "framesRetained")
        try requireVideoCapturePacketAge(frameAge, fieldPrefix: "frameAge")
        if let frameInterval {
            try requireVideoCapturePacketAge(frameInterval, fieldPrefix: "frameInterval")
        }
        try validateAudioImpact()
        try validateProcessCpu()
        try validateProcessMemory()
        try validateProductionEvidence()
        try validateRawCapture()

        guard framesRetained <= framesCaptured else {
            throw VideoCaptureValidationError.invalidFrameAccounting
        }
        try VideoCaptureValidator.requireNonEmpty(notes, "notes")
    }

    private func validateAudioImpact() throws {
        try VideoCaptureValidator.requireNonNegative(
            audioImpact.baselineCallbackP99Microseconds,
            "audioImpact.baselineCallbackP99Microseconds"
        )
        try VideoCaptureValidator.requireNonNegative(
            audioImpact.videoCallbackP99Microseconds,
            "audioImpact.videoCallbackP99Microseconds"
        )
        try VideoCaptureValidator.requireNonNegative(
            audioImpact.baselineCallbackMaxMicroseconds,
            "audioImpact.baselineCallbackMaxMicroseconds"
        )
        try VideoCaptureValidator.requireNonNegative(
            audioImpact.videoCallbackMaxMicroseconds,
            "audioImpact.videoCallbackMaxMicroseconds"
        )
        try VideoCaptureValidator.requirePositive(
            audioImpact.baselinePlayoutTargetFrames,
            "audioImpact.baselinePlayoutTargetFrames"
        )
        try VideoCaptureValidator.requirePositive(
            audioImpact.videoPlayoutTargetFrames,
            "audioImpact.videoPlayoutTargetFrames"
        )
        try VideoCaptureValidator.requireNonNegative(audioImpact.underruns, "audioImpact.underruns")
        try VideoCaptureValidator.requireOptionalNonEmpty(
            audioImpact.baselineReportId,
            "audioImpact.baselineReportId"
        )
    }

    private func validateProcessCpu() throws {
        guard let processCpu else {
            return
        }
        try VideoCaptureValidator.requireNonNegative(processCpu.userSeconds, "processCpu.userSeconds")
        try VideoCaptureValidator.requireNonNegative(processCpu.systemSeconds, "processCpu.systemSeconds")
    }

    private func validateProcessMemory() throws {
        guard let processMemory else {
            return
        }
        try VideoCaptureValidator.requirePositive(
            processMemory.residentPeakBytes,
            "processMemory.residentPeakBytes"
        )
    }

    private func validateProductionEvidence() throws {
        guard let evidence = productionCaptureEvidence else {
            return
        }
        try VideoCaptureValidator.requireNonEmpty(evidence.modelName, "productionCaptureEvidence.modelName")
        try VideoCaptureValidator.requireNonEmpty(evidence.manufacturer, "productionCaptureEvidence.manufacturer")
        try VideoCaptureValidator.requireOptionalNonEmpty(
            evidence.avFoundationDeviceUniqueId,
            "productionCaptureEvidence.avFoundationDeviceUniqueId"
        )
        try VideoCaptureValidator.requireNonEmpty(
            evidence.desktopVideoSdkDecisionNotes,
            "productionCaptureEvidence.desktopVideoSdkDecisionNotes"
        )
        try evidence.atemReadOnlyControlReport?.validate()
    }

    private func validateRawCapture() throws {
        guard let rawCapture else {
            return
        }
        try VideoCaptureValidator.requireNonNegative(
            rawCapture.extractionAttempts,
            "rawCapture.extractionAttempts"
        )
        try VideoCaptureValidator.requireNonNegative(
            rawCapture.extractionFailures,
            "rawCapture.extractionFailures"
        )
        try VideoCaptureValidator.requireNonNegative(
            rawCapture.payloadsCaptured,
            "rawCapture.payloadsCaptured"
        )
        try VideoCaptureValidator.requireNonNegative(
            rawCapture.artifactFramesRetained,
            "rawCapture.artifactFramesRetained"
        )
        try VideoCaptureValidator.requireOptionalNonEmpty(
            rawCapture.lastExtractionError,
            "rawCapture.lastExtractionError"
        )
        switch rawCapture.mode {
        case .disabled:
            guard rawCapture.extractionAttempts == 0,
                  rawCapture.extractionFailures == 0,
                  rawCapture.payloadsCaptured == 0,
                  rawCapture.artifactFramesRetained == 0,
                  rawCapture.lastExtractionError == nil else {
                throw VideoCaptureValidationError.invalidRawCaptureAccounting
            }
        case .requested:
            let accountedExtractions = rawCapture.payloadsCaptured.addingReportingOverflow(
                rawCapture.extractionFailures
            )
            guard rawCapture.extractionFailures <= rawCapture.extractionAttempts,
                  rawCapture.payloadsCaptured <= rawCapture.extractionAttempts,
                  rawCapture.artifactFramesRetained <= rawCapture.payloadsCaptured,
                  !accountedExtractions.overflow,
                  accountedExtractions.partialValue <= rawCapture.extractionAttempts else {
                throw VideoCaptureValidationError.invalidRawCaptureAccounting
            }
            if rawCapture.extractionFailures > 0,
               rawCapture.lastExtractionError == nil {
                throw VideoCaptureValidationError.invalidRawCaptureAccounting
            }
        }
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
        let deviceUniqueId = try requirePassCaptureSource()
        try requirePassProductionEvidence(matches: deviceUniqueId)
        try requirePassRuntimeMetrics()
        try requirePassRawCapture()
        try requirePassAudioImpact()
    }

    private func requirePassCaptureSource() throws -> String {
        guard source.kind == .avFoundation, source.permissionStatus == "authorized" else {
            throw VideoCaptureValidationError.passWithoutAVFoundationCapture
        }
        guard let deviceUniqueId = source.deviceUniqueId, !deviceUniqueId.isEmpty else {
            throw VideoCaptureValidationError.passWithoutDeviceUniqueId
        }
        return deviceUniqueId
    }

    private func requirePassProductionEvidence(matches deviceUniqueId: String) throws {
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
    }

    private func requirePassRuntimeMetrics() throws {
        guard frameInterval != nil else {
            throw VideoCaptureValidationError.passWithoutFrameIntervalMetrics
        }
        guard processCpu != nil else {
            throw VideoCaptureValidationError.passWithoutProcessCpuMetrics
        }
        guard processMemory != nil else {
            throw VideoCaptureValidationError.passWithoutProcessMemoryMetrics
        }
    }

    private func requirePassRawCapture() throws {
        guard let rawCapture, rawCapture.mode == .requested else {
            throw VideoCaptureValidationError.passWithoutRawCaptureEvidence
        }
        guard rawCapture.extractionFailures == 0 else {
            throw VideoCaptureValidationError.passWithRawCaptureFailures(
                rawCapture.extractionFailures
            )
        }
        guard rawCapture.payloadsCaptured > 0 else {
            throw VideoCaptureValidationError.passWithoutRawPayloadEvidence
        }
    }

    private func requirePassAudioImpact() throws {
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
        guard audioImpact.baselineReportId?.isEmpty == false else {
            throw VideoCaptureValidationError.passWithoutAudioImpactProvenance
        }
        guard audioImpact.synthetic != true else {
            throw VideoCaptureValidationError.passWithSyntheticAudioImpact
        }
    }
}
