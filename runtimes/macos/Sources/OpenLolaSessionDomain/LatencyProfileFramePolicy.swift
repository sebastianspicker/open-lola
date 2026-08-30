// Maps the wire-level packet cadence to the pure session latency profile.
public extension LatencyProfile {
    static func profile(forFramesPerBuffer framesPerBuffer: Int) -> LatencyProfile? {
        switch framesPerBuffer {
        case 8:
            .extremeLowLatency8
        case 16:
            .ultraLowLatency16
        case 32, 64:
            .safeLowLatency
        default:
            nil
        }
    }
}
