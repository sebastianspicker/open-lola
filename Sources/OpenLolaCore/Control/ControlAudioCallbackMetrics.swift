// Shares callback timing evidence while control domains remain distinct types.

/// Captures callback timing and playout state for one control-integration domain.
public struct ControlAudioCallbackMetrics<Domain>: Codable, Equatable, Sendable {
    public var p99Microseconds: Double
    public var maxMicroseconds: Double
    public var playoutTargetFrames: Int

    public init(p99Microseconds: Double, maxMicroseconds: Double, playoutTargetFrames: Int) {
        self.p99Microseconds = p99Microseconds
        self.maxMicroseconds = maxMicroseconds
        self.playoutTargetFrames = playoutTargetFrames
    }
}

/// Marks callback metrics gathered during lighting control integration.
public enum LightingAudioCallbackMetricsDomain {}
/// Marks callback metrics gathered during OSC cue control integration.
public enum OscCueAudioCallbackMetricsDomain {}

/// Names lighting-specific callback metrics without changing the shared metric shape.
public typealias LightingAudioCallbackMetrics = ControlAudioCallbackMetrics<LightingAudioCallbackMetricsDomain>
/// Names OSC cue-specific callback metrics without changing the shared metric shape.
public typealias OscCueAudioCallbackMetrics = ControlAudioCallbackMetrics<OscCueAudioCallbackMetricsDomain>
