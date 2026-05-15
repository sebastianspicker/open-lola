import Foundation

public enum MeasurementReportKind: String, CaseIterable, Codable, Hashable, Sendable {
    case endpoint
    case network
    case video
    case lighting
    case fieldTest
}

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

public struct RouteIdentity: Codable, Equatable, Sendable {
    public let label: String
    public let topology: String

    public init(label: String, topology: String) {
        self.label = label
        self.topology = topology
    }
}

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

public struct MeasurementReport: Codable, Equatable, Sendable {
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
        id: String,
        kind: MeasurementReportKind,
        title: String,
        capturedAt: String,
        hardware: HardwareIdentity,
        route: RouteIdentity,
        audioMode: AudioMode,
        timing: TimingMetrics,
        loss: LossMetrics,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.capturedAt = capturedAt
        self.hardware = hardware
        self.route = route
        self.audioMode = audioMode
        self.timing = timing
        self.loss = loss
        self.verdict = verdict
        self.notes = notes
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
