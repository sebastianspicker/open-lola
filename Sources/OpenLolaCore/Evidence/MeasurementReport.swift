// Collects measurement evidence evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Defines the finite report contents values recorded by measurement artifacts for deterministic validation and report interpretation.
public enum MeasurementReportKind: String, CaseIterable, Codable, Hashable, Sendable {
    case endpoint
    case network
    case video
    case lighting
    case fieldTest
}

/// Captures hardware and endpoint identity required to validate, interpret, and reproduce a measurement result.
public struct HardwareIdentity: Codable, Equatable, Sendable {
    public let referenceMac: String
    public let audioInterface: String
    public let osVersion: String
    public let driverVersion: String

    public init(
        referenceMac: String,
        audioInterface: String,
        osVersion: String,
        driverVersion: String
    ) {
        self.referenceMac = referenceMac
        self.audioInterface = audioInterface
        self.osVersion = osVersion
        self.driverVersion = driverVersion
    }
}

/// Captures hardware and endpoint identity required to validate, interpret, and reproduce a measurement result.
public struct RouteIdentity: Codable, Equatable, Sendable {
    public let label: String
    public let topology: String

    public init(label: String, topology: String) {
        self.label = label
        self.topology = topology
    }
}

/// Captures operating mode required to validate, interpret, and reproduce a measurement result.
public struct AudioMode: Codable, Equatable, Sendable {
    public let sampleRateHertz: Int
    public let framesPerBuffer: Int
    public let channelCount: Int
    public let sampleFormat: String

    public init(
        sampleRateHertz: Int,
        framesPerBuffer: Int,
        channelCount: Int,
        sampleFormat: String
    ) {
        self.sampleRateHertz = sampleRateHertz
        self.framesPerBuffer = framesPerBuffer
        self.channelCount = channelCount
        self.sampleFormat = sampleFormat
    }
}

/// Captures measured metrics required to validate, interpret, and reproduce a measurement result.
public struct TimingMetrics: Codable, Equatable, Sendable {
    public let p50Milliseconds: Double
    public let p95Milliseconds: Double
    public let p99Milliseconds: Double
    public let maxMilliseconds: Double

    public init(
        p50Milliseconds: Double,
        p95Milliseconds: Double,
        p99Milliseconds: Double,
        maxMilliseconds: Double
    ) {
        self.p50Milliseconds = p50Milliseconds
        self.p95Milliseconds = p95Milliseconds
        self.p99Milliseconds = p99Milliseconds
        self.maxMilliseconds = maxMilliseconds
    }
}

/// Captures measured metrics required to validate, interpret, and reproduce a measurement result.
public struct LossMetrics: Codable, Equatable, Sendable {
    public let lostPackets: Int
    public let droppedFrames: Int
    public let underruns: Int
    public let overruns: Int

    public init(
        lostPackets: Int,
        droppedFrames: Int,
        underruns: Int,
        overruns: Int
    ) {
        self.lostPackets = lostPackets
        self.droppedFrames = droppedFrames
        self.underruns = underruns
        self.overruns = overruns
    }
}

/// Describes failures that prevent measurement inputs or evidence from satisfying the required validation invariants.
public enum MeasurementReportValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case unorderedTiming
}

enum MeasurementReportValidator: ReportPrimitiveValidating {
    typealias ValidationError = MeasurementReportValidationError

    static func requireNonNegative(_ value: Double, _ field: String) throws {
        try ValidationPrimitives.requireNonNegative(
            value,
            field: field,
            negative: MeasurementReportValidationError.negativeField
        )
    }
}

/// Captures report contents required to validate, interpret, and reproduce a measurement result.
public struct MeasurementReport: Codable, Equatable, Sendable {
    public struct Identity: Sendable {
        public let id: String
        public let kind: MeasurementReportKind
        public let title: String
        public let capturedAt: String

        public init(id: String, kind: MeasurementReportKind, title: String, capturedAt: String) {
            self.id = id
            self.kind = kind
            self.title = title
            self.capturedAt = capturedAt
        }
    }

    public struct Context: Sendable {
        public let hardware: HardwareIdentity
        public let route: RouteIdentity
        public let audioMode: AudioMode

        public init(hardware: HardwareIdentity, route: RouteIdentity, audioMode: AudioMode) {
            self.hardware = hardware
            self.route = route
            self.audioMode = audioMode
        }
    }

    public struct Results: Sendable {
        public let timing: TimingMetrics
        public let loss: LossMetrics

        public init(timing: TimingMetrics, loss: LossMetrics) {
            self.timing = timing
            self.loss = loss
        }
    }

    public struct Outcome: Sendable {
        public let verdict: MeasurementVerdict
        public let notes: String

        public init(verdict: MeasurementVerdict, notes: String) {
            self.verdict = verdict
            self.notes = notes
        }
    }

    public let id: String
    public let kind: MeasurementReportKind
    public let title: String
    public let capturedAt: String
    public let hardware: HardwareIdentity
    public let route: RouteIdentity
    public let audioMode: AudioMode
    public let timing: TimingMetrics
    public let loss: LossMetrics
    public let verdict: MeasurementVerdict
    public let notes: String

    public init(
        identity: Identity,
        context: Context,
        results: Results,
        outcome: Outcome
    ) {
        self.id = identity.id
        self.kind = identity.kind
        self.title = identity.title
        self.capturedAt = identity.capturedAt
        self.hardware = context.hardware
        self.route = context.route
        self.audioMode = context.audioMode
        self.timing = results.timing
        self.loss = results.loss
        self.verdict = outcome.verdict
        self.notes = outcome.notes
    }

    public static func decode(from data: Data) throws -> MeasurementReport {
        try JSONDecoder().decode(MeasurementReport.self, from: data)
    }

    public func validate() throws {
        try MeasurementReportValidator.requireNonEmpty(id, "id")
        try MeasurementReportValidator.requireNonEmpty(title, "title")
        try MeasurementReportValidator.requireNonEmpty(capturedAt, "capturedAt")
        try MeasurementReportValidator.requireNonEmpty(hardware.referenceMac, "hardware.referenceMac")
        try MeasurementReportValidator.requireNonEmpty(hardware.audioInterface, "hardware.audioInterface")
        try MeasurementReportValidator.requireNonEmpty(hardware.osVersion, "hardware.osVersion")
        try MeasurementReportValidator.requireNonEmpty(hardware.driverVersion, "hardware.driverVersion")
        try MeasurementReportValidator.requireNonEmpty(route.label, "route.label")
        try MeasurementReportValidator.requireNonEmpty(route.topology, "route.topology")
        try MeasurementReportValidator.requireNonEmpty(audioMode.sampleFormat, "audioMode.sampleFormat")
        try MeasurementReportValidator.requirePositive(audioMode.sampleRateHertz, "audioMode.sampleRateHertz")
        try MeasurementReportValidator.requirePositive(audioMode.framesPerBuffer, "audioMode.framesPerBuffer")
        try MeasurementReportValidator.requirePositive(audioMode.channelCount, "audioMode.channelCount")
        try MeasurementReportValidator.requireNonNegative(timing.p50Milliseconds, "timing.p50Milliseconds")
        try MeasurementReportValidator.requireNonNegative(timing.p95Milliseconds, "timing.p95Milliseconds")
        try MeasurementReportValidator.requireNonNegative(timing.p99Milliseconds, "timing.p99Milliseconds")
        try MeasurementReportValidator.requireNonNegative(timing.maxMilliseconds, "timing.maxMilliseconds")
        try MeasurementReportValidator.requireNonNegative(loss.lostPackets, "loss.lostPackets")
        try MeasurementReportValidator.requireNonNegative(loss.droppedFrames, "loss.droppedFrames")
        try MeasurementReportValidator.requireNonNegative(loss.underruns, "loss.underruns")
        try MeasurementReportValidator.requireNonNegative(loss.overruns, "loss.overruns")

        guard timing.p50Milliseconds <= timing.p95Milliseconds,
              timing.p95Milliseconds <= timing.p99Milliseconds,
              timing.p99Milliseconds <= timing.maxMilliseconds else {
            throw MeasurementReportValidationError.unorderedTiming
        }
    }
}
