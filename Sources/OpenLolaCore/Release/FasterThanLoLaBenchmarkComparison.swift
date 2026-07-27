// Defines the flat benchmark-comparison artifact and grouped construction inputs used by faster-than-LoLa closure evidence.
import Foundation

/// Captures structured result required to validate, interpret, and reproduce a faster-than-LoLa closure result.
public struct FasterThanLoLaBenchmarkComparison: Codable, Equatable, Sendable {
    public struct BaselineIdentity: Codable, Equatable, Sendable {
        public var lolaBaselineReportID: String
        public var openLolaReportID: String
        public var lolaVersion: String
        public var lolaSettings: String
        public var routeLabel: String

        public init(
            lolaBaselineReportID: String,
            openLolaReportID: String,
            lolaVersion: String,
            lolaSettings: String,
            routeLabel: String
        ) {
            self.lolaBaselineReportID = lolaBaselineReportID
            self.openLolaReportID = openLolaReportID
            self.lolaVersion = lolaVersion
            self.lolaSettings = lolaSettings
            self.routeLabel = routeLabel
        }
    }

    public struct PacketRun: Codable, Equatable, Sendable {
        public var packetMode: UdpPcmPacketMode
        public var fixedPlayoutTargetFrames: Int
        public var durationSeconds: Int

        public init(
            packetMode: UdpPcmPacketMode,
            fixedPlayoutTargetFrames: Int,
            durationSeconds: Int
        ) {
            self.packetMode = packetMode
            self.fixedPlayoutTargetFrames = fixedPlayoutTargetFrames
            self.durationSeconds = durationSeconds
        }
    }

    public struct Measurements: Codable, Equatable, Sendable {
        public var lolaBaselineMeasured: Bool
        public var sameHardwareAndRoute: Bool
        public var openLolaLatency: LolaBaselineLatencyMetrics
        public var lolaLatency: LolaBaselineLatencyMetrics

        public init(
            lolaBaselineMeasured: Bool,
            sameHardwareAndRoute: Bool,
            openLolaLatency: LolaBaselineLatencyMetrics,
            lolaLatency: LolaBaselineLatencyMetrics
        ) {
            self.lolaBaselineMeasured = lolaBaselineMeasured
            self.sameHardwareAndRoute = sameHardwareAndRoute
            self.openLolaLatency = openLolaLatency
            self.lolaLatency = lolaLatency
        }
    }

    public struct PacketHealth: Codable, Equatable, Sendable {
        public var lostPackets: Int
        public var latePackets: Int
        public var underruns: Int

        public init(lostPackets: Int, latePackets: Int, underruns: Int) {
            self.lostPackets = lostPackets
            self.latePackets = latePackets
            self.underruns = underruns
        }
    }

    public struct QualityAssessment: Codable, Equatable, Sendable {
        public var maxAbsoluteDriftPpm: Double
        public var artifactsDetected: Bool
        public var result: LolaBaselineComparisonResult

        public init(
            maxAbsoluteDriftPpm: Double,
            artifactsDetected: Bool,
            result: LolaBaselineComparisonResult
        ) {
            self.maxAbsoluteDriftPpm = maxAbsoluteDriftPpm
            self.artifactsDetected = artifactsDetected
            self.result = result
        }
    }

    public struct Quality: Codable, Equatable, Sendable {
        public var packetHealth: PacketHealth
        public var assessment: QualityAssessment

        public init(packetHealth: PacketHealth, assessment: QualityAssessment) {
            self.packetHealth = packetHealth
            self.assessment = assessment
        }
    }

    public struct Input: Codable, Equatable, Sendable {
        public var baselineIdentity: BaselineIdentity
        public var packetRun: PacketRun
        public var measurements: Measurements
        public var quality: Quality

        public init(
            baselineIdentity: BaselineIdentity,
            packetRun: PacketRun,
            measurements: Measurements,
            quality: Quality
        ) {
            self.baselineIdentity = baselineIdentity
            self.packetRun = packetRun
            self.measurements = measurements
            self.quality = quality
        }
    }

    public var lolaBaselineReportId: String
    public var openLolaReportId: String
    public var lolaVersion: String
    public var lolaSettings: String
    public var routeLabel: String
    public var packetMode: UdpPcmPacketMode
    public var fixedPlayoutTargetFrames: Int
    public var durationSeconds: Int
    public var lolaBaselineMeasured: Bool
    public var measuredOnSameHardwareAndRoute: Bool
    public var openLolaLatency: LolaBaselineLatencyMetrics
    public var lolaLatency: LolaBaselineLatencyMetrics
    public var lostPackets: Int
    public var latePackets: Int
    public var underruns: Int
    public var maxAbsoluteDriftPpm: Double
    public var artifactsDetected: Bool
    public var result: LolaBaselineComparisonResult

    public init(_ input: Input) {
        self.lolaBaselineReportId = input.baselineIdentity.lolaBaselineReportID
        self.openLolaReportId = input.baselineIdentity.openLolaReportID
        self.lolaVersion = input.baselineIdentity.lolaVersion
        self.lolaSettings = input.baselineIdentity.lolaSettings
        self.routeLabel = input.baselineIdentity.routeLabel
        self.packetMode = input.packetRun.packetMode
        self.fixedPlayoutTargetFrames = input.packetRun.fixedPlayoutTargetFrames
        self.durationSeconds = input.packetRun.durationSeconds
        self.lolaBaselineMeasured = input.measurements.lolaBaselineMeasured
        self.measuredOnSameHardwareAndRoute = input.measurements.sameHardwareAndRoute
        self.openLolaLatency = input.measurements.openLolaLatency
        self.lolaLatency = input.measurements.lolaLatency
        self.lostPackets = input.quality.packetHealth.lostPackets
        self.latePackets = input.quality.packetHealth.latePackets
        self.underruns = input.quality.packetHealth.underruns
        self.maxAbsoluteDriftPpm = input.quality.assessment.maxAbsoluteDriftPpm
        self.artifactsDetected = input.quality.assessment.artifactsDetected
        self.result = input.quality.assessment.result
    }
}
