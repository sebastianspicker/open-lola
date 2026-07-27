// Validates production capture hardware, connection, SDK, format, and audio-impact evidence before a video probe can pass.
import Foundation

/// Defines `atem`, `deckLink`, `ultraStudio`, and `blackmagicCapture` states used to make production video hardware kind decisions in video capture and frame transport.
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

/// Defines `usbUvc`, `thunderbolt`, `pcie`, and `unknown` states used to make production video connection method decisions in video capture and frame transport.
public enum ProductionVideoConnectionMethod: String, Codable, Equatable, Sendable {
    case usbUvc
    case thunderbolt
    case pcie
    case unknown
}

/// Defines `notLinkedOptionalBoundary`, `linked`, `unavailable`, and `requiredAfterMeasurement` states used to make blackmagic desktop video sdk status decisions in video capture and frame transport.
public enum BlackmagicDesktopVideoSdkStatus: String, Codable, Equatable, Sendable {
    case notLinkedOptionalBoundary
    case linked
    case unavailable
    case requiredAfterMeasurement
}

/// Preserves `hardwareKind`, `modelName`, `manufacturer`, and `connectionMethod` needed to distinguish measured video capture and frame transport behavior from configuration claims.
public struct ProductionVideoCaptureEvidence: Codable, Equatable, Sendable {
    public struct Hardware: Equatable, Sendable {
        public var kind: ProductionVideoHardwareKind
        public var modelName: String
        public var manufacturer: String
        public var connectionMethod: ProductionVideoConnectionMethod

        public init(
            kind: ProductionVideoHardwareKind,
            modelName: String,
            manufacturer: String,
            connectionMethod: ProductionVideoConnectionMethod
        ) {
            self.kind = kind
            self.modelName = modelName
            self.manufacturer = manufacturer
            self.connectionMethod = connectionMethod
        }
    }

    public struct Discovery: Equatable, Sendable {
        public var avFoundationVisible: Bool
        public var deviceUniqueID: String?

        public init(avFoundationVisible: Bool, deviceUniqueID: String?) {
            self.avFoundationVisible = avFoundationVisible
            self.deviceUniqueID = deviceUniqueID
        }
    }

    public struct DesktopSDK: Equatable, Sendable {
        public var status: BlackmagicDesktopVideoSdkStatus
        public var decisionNotes: String
        public var atemReadOnlyControlReport: AtemReadOnlyControlReport?

        public init(
            status: BlackmagicDesktopVideoSdkStatus,
            decisionNotes: String,
            atemReadOnlyControlReport: AtemReadOnlyControlReport?
        ) {
            self.status = status
            self.decisionNotes = decisionNotes
            self.atemReadOnlyControlReport = atemReadOnlyControlReport
        }
    }

    public var hardwareKind: ProductionVideoHardwareKind
    public var modelName: String
    public var manufacturer: String
    public var connectionMethod: ProductionVideoConnectionMethod
    public var avFoundationVisible: Bool
    public var avFoundationDeviceUniqueId: String?
    public var desktopVideoSdkStatus: BlackmagicDesktopVideoSdkStatus
    public var desktopVideoSdkDecisionNotes: String
    public var atemReadOnlyControlReport: AtemReadOnlyControlReport?

    public init(hardware: Hardware, discovery: Discovery, desktopSDK: DesktopSDK) {
        self.hardwareKind = hardware.kind
        self.modelName = hardware.modelName
        self.manufacturer = hardware.manufacturer
        self.connectionMethod = hardware.connectionMethod
        self.avFoundationVisible = discovery.avFoundationVisible
        self.avFoundationDeviceUniqueId = discovery.deviceUniqueID
        self.desktopVideoSdkStatus = desktopSDK.status
        self.desktopVideoSdkDecisionNotes = desktopSDK.decisionNotes
        self.atemReadOnlyControlReport = desktopSDK.atemReadOnlyControlReport
    }
}

/// Reports `emptyField`, `nonPositiveField`, `negativeField`, and `nonFiniteField` failures that stop invalid video capture and frame transport work before it reaches a live path.
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

/// Records `id`, `title`, `capturedAt`, and `stream` so video capture and frame transport measurements and verdicts can be checked after a run.
public struct VideoCaptureReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Identity: Equatable, Sendable {
        public var id: String
        public var title: String
        public var capturedAt: String
        public var stream: VideoCaptureStreamMetadata

        public init(
            id: String,
            title: String,
            capturedAt: String,
            stream: VideoCaptureStreamMetadata = .syntheticTestPattern
        ) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.stream = stream
        }
    }

    public struct Capture: Equatable, Sendable {
        public var source: VideoSourceDescription
        public var format: VideoCaptureFormat
        public var durationSeconds: Double
        public var queue: VideoQueueMetrics

        public init(
            source: VideoSourceDescription,
            format: VideoCaptureFormat,
            durationSeconds: Double,
            queue: VideoQueueMetrics
        ) {
            self.source = source
            self.format = format
            self.durationSeconds = durationSeconds
            self.queue = queue
        }
    }

    public struct FrameMetrics: Equatable, Sendable {
        public var framesCaptured: Int
        public var framesRetained: Int
        public var frameAge: UdpPcmPacketAgeMetrics
        public var frameInterval: UdpPcmPacketAgeMetrics?

        public init(
            framesCaptured: Int,
            framesRetained: Int,
            frameAge: UdpPcmPacketAgeMetrics,
            frameInterval: UdpPcmPacketAgeMetrics? = nil
        ) {
            self.framesCaptured = framesCaptured
            self.framesRetained = framesRetained
            self.frameAge = frameAge
            self.frameInterval = frameInterval
        }
    }

    public struct RuntimeEvidence: Equatable, Sendable {
        public var audioImpact: VideoAudioImpactMetrics
        public var processCpu: VideoProcessCpuMetrics?
        public var processMemory: VideoProcessMemoryMetrics?
        public var productionCaptureEvidence: ProductionVideoCaptureEvidence?
        public var rawCapture: RawVideoCaptureMetrics?

        public init(
            audioImpact: VideoAudioImpactMetrics,
            processCpu: VideoProcessCpuMetrics? = nil,
            processMemory: VideoProcessMemoryMetrics? = nil,
            productionCaptureEvidence: ProductionVideoCaptureEvidence? = nil,
            rawCapture: RawVideoCaptureMetrics? = nil
        ) {
            self.audioImpact = audioImpact
            self.processCpu = processCpu
            self.processMemory = processMemory
            self.productionCaptureEvidence = productionCaptureEvidence
            self.rawCapture = rawCapture
        }
    }

    public enum OutcomeDomain {}
    public typealias Outcome = MutableReportOutcome<OutcomeDomain>

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
        identity: Identity,
        capture: Capture,
        frameMetrics: FrameMetrics,
        runtimeEvidence: RuntimeEvidence,
        outcome: Outcome
    ) {
        self.id = identity.id
        self.title = identity.title
        self.capturedAt = identity.capturedAt
        self.stream = identity.stream
        self.source = capture.source
        self.format = capture.format
        self.durationSeconds = capture.durationSeconds
        self.queue = capture.queue
        self.framesCaptured = frameMetrics.framesCaptured
        self.framesRetained = frameMetrics.framesRetained
        self.frameAge = frameMetrics.frameAge
        self.frameInterval = frameMetrics.frameInterval
        self.audioImpact = runtimeEvidence.audioImpact
        self.processCpu = runtimeEvidence.processCpu
        self.processMemory = runtimeEvidence.processMemory
        self.productionCaptureEvidence = runtimeEvidence.productionCaptureEvidence
        self.rawCapture = runtimeEvidence.rawCapture
        self.verdict = outcome.verdict
        self.notes = outcome.notes
    }
}
