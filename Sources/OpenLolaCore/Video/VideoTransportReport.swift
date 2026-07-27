// Validates the complete video transport result so route, frame, packet, timing, degradation, and provenance claims remain mutually consistent.
import Foundation

/// Records `id`, `title`, `capturedAt`, and `durationSeconds` so video capture and frame transport measurements and verdicts can be checked after a run.
public struct VideoTransportReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var durationSeconds: Double
    public var source: VideoSourceDescription
    public var format: VideoCaptureFormat
    public var transport: VideoTransportProfile
    public var routeEvidence: VideoTransportRouteEvidence?
    public var fragmentation: VideoFragmentationMetrics?
    public var reassembly: VideoReassemblyMetrics?
    public var renderOutput: VideoRenderOutputMetrics?
    public var blackmagicOutput: BlackmagicOutputBoundaryReport?
    public var multiVideo: MultiVideoTransportMetrics?
    public var avSync: AVSyncTimingMetrics?
    public var transmitted: VideoTransmittedMetrics
    public var receiver: VideoReceiverMetrics
    public var frameAge: UdpPcmPacketAgeMetrics
    public var performanceCounters: VideoTransportPerformanceCounters?
    public var degradation: VideoDegradationPolicy
    public var audioImpact: VideoAudioImpactMetrics
    public var verdict: MeasurementVerdict
    public var notes: String

    public static func decode(from data: Data) throws -> VideoTransportReport {
        try JSONDecoder().decode(VideoTransportReport.self, from: data)
    }

    public func validate() throws {
        try validateIdentity()
        try validateSourceAndFormat()
        try validateTransport()
        try validateRouteEvidence()
        try validateFragmentation()
        try validateReassembly()
        try validateRenderOutput()
        try validateBlackmagicOutput()
        try multiVideo?.validate()
        try avSync?.validate()
        try validateMetrics()
        try validatePerformanceCounters()
        try validateAudioImpact()
    try validatePassVerdict()
    }

}
