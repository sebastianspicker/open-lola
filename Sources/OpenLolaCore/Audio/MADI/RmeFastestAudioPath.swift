// Implements RmeFastestAudioPath audio-path behavior, isolating device and sample handling from higher-level routing.
import Foundation

/// Defines `driverKit`, `kernelExtension`, `classCompliant`, and `unknown` states used to make rme madi driver mode decisions in MADI full-duplex transport.
public enum RmeMadiDriverMode: String, Codable, Equatable, Sendable {
    case driverKit
    case kernelExtension
    case classCompliant
    case unknown
}

/// Preserves `driverPackage`, `driverVersion`, `firmwareVersion`, and `driverMode` needed to distinguish measured MADI full-duplex transport behavior from configuration claims.
public struct RmeMadiDriverEvidence: Codable, Equatable, Sendable {
    public struct Driver: Codable, Equatable, Sendable {
        public var package: String
        public var version: String
        public var firmwareVersion: String
        public var mode: RmeMadiDriverMode

        public init(package: String, version: String, firmwareVersion: String, mode: RmeMadiDriverMode) {
            self.package = package
            self.version = version
            self.firmwareVersion = firmwareVersion
            self.mode = mode
        }
    }

    public struct TotalMix: Codable, Equatable, Sendable {
        public var version: String
        public var snapshot: String
        public var routingNotes: String

        public init(version: String, snapshot: String, routingNotes: String) {
            self.version = version
            self.snapshot = snapshot
            self.routingNotes = routingNotes
        }
    }

    public struct Clocking: Codable, Equatable, Sendable {
        public var clockSource: String
        public var sampleRateSource: String
        public var sampleRateConversion: SampleRateConversionState

        public init(
            clockSource: String,
            sampleRateSource: String,
            sampleRateConversion: SampleRateConversionState
        ) {
            self.clockSource = clockSource
            self.sampleRateSource = sampleRateSource
            self.sampleRateConversion = sampleRateConversion
        }
    }
    public var driverPackage: String
    public var driverVersion: String
    public var firmwareVersion: String
    public var driverMode: RmeMadiDriverMode
    public var totalMixVersion: String
    public var totalMixSnapshot: String
    public var clockSource: String
    public var sampleRateSource: String
    public var sampleRateConversion: SampleRateConversionState
    public var routingNotes: String

    public init(driver: Driver, totalMix: TotalMix, clocking: Clocking) {
        self.driverPackage = driver.package
        self.driverVersion = driver.version
        self.firmwareVersion = driver.firmwareVersion
        self.driverMode = driver.mode
        self.totalMixVersion = totalMix.version
        self.totalMixSnapshot = totalMix.snapshot
        self.clockSource = clocking.clockSource
        self.sampleRateSource = clocking.sampleRateSource
        self.sampleRateConversion = clocking.sampleRateConversion
        self.routingNotes = totalMix.routingNotes
    }
}

/// Reports `emptyField`, `nonPositiveField`, `missingRequiredSampleRate`, and `missingRequiredFrameSize` failures that stop invalid MADI full-duplex transport work before it reaches a live path.
public enum RmeFastestAudioPathValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationNonPositiveFieldError {
    case emptyField(String)
    case nonPositiveField(String)
    case missingRequiredSampleRate(Int)
    case missingRequiredFrameSize(sampleRateHertz: Int, framesPerBuffer: Int)
    case passWithPlaceholderField(String)
    case passWithoutRmeMadiDevice
    case passWithoutFullDuplexRmeDevice
    case passWithoutConcreteDriverMode
    case passWithoutDedicatedRmeDriver
    case passWithAggregateDevice
    case passWithAggregateRouting(String)
    case passWithSampleRateConversion(SampleRateConversionState)
    case passWithoutClockDomain
    case passSampleRateOutsideRanges(Int)
    case passBufferFramesOutsideCandidates(Int)
    case passChannelCountExceedsDeviceChannels(
        channelCount: Int,
        inputChannels: Int,
        outputChannels: Int
    )
    case passWithoutThunderboltRmePath
    case passWithoutLoopbackPass
    case passWithoutMatchingLoopbackDeviceUID
    case passWithoutSupportedSampleRate(Int)
    case passWithoutAcceptedStableMode(sampleRateHertz: Int)
    case passSelectedModeIsNotFastestStable(selected: AudioMode, fastest: AudioMode)
}

/// Records `id`, `title`, `capturedAt`, and `inventoryCapturedAt` so MADI full-duplex transport measurements and verdicts can be checked after a run.
public struct RmeFastestAudioPathReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public typealias Identity = ReportCaptureIdentity<RmeFastestAudioPathReport>

    public struct Inventory: Codable, Equatable, Sendable {
        public var capturedAt: String
        public var hostName: String
        public var device: CoreAudioDeviceInventory

        public init(capturedAt: String, hostName: String, device: CoreAudioDeviceInventory) {
            self.capturedAt = capturedAt
            self.hostName = hostName
            self.device = device
        }
    }

    public struct Evidence: Codable, Equatable, Sendable {
        public var driver: RmeMadiDriverEvidence
        public var loopback: EndpointLoopbackReport

        public init(driver: RmeMadiDriverEvidence, loopback: EndpointLoopbackReport) {
            self.driver = driver
            self.loopback = loopback
        }
    }
    public var id: String
    public var title: String
    public var capturedAt: String
    public var inventoryCapturedAt: String
    public var inventoryHostName: String
    public var rmeDevice: CoreAudioDeviceInventory
    public var driverEvidence: RmeMadiDriverEvidence
    public var loopbackReport: EndpointLoopbackReport
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        identity: Identity,
        inventory: Inventory,
        evidence: Evidence,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = identity.id
        self.title = identity.title
        self.capturedAt = identity.capturedAt
        self.inventoryCapturedAt = inventory.capturedAt
        self.inventoryHostName = inventory.hostName
        self.rmeDevice = inventory.device
        self.driverEvidence = evidence.driver
        self.loopbackReport = evidence.loopback
        self.verdict = verdict
        self.notes = notes
    }
}
