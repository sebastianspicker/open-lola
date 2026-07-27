// Validates VideoValidators acceptance rules, keeping failure policy close to its contract rather than the runtime path.
enum VideoCaptureValidator: ReportPrimitiveValidating {
    typealias ValidationError = VideoCaptureValidationError
}

enum VideoTransportValidator: ReportPrimitiveValidating {
    typealias ValidationError = VideoTransportValidationError
}

func validateVideoPacketAge(_ metrics: UdpPcmPacketAgeMetrics, field: String) throws {
    try VideoTransportValidator.requireNonNegative(metrics.p50Microseconds, "\(field).p50Microseconds")
    try VideoTransportValidator.requireNonNegative(metrics.p95Microseconds, "\(field).p95Microseconds")
    try VideoTransportValidator.requireNonNegative(metrics.p99Microseconds, "\(field).p99Microseconds")
    try VideoTransportValidator.requireNonNegative(metrics.maxMicroseconds, "\(field).maxMicroseconds")
    guard timingPercentilesAreOrdered(
        p50: metrics.p50Microseconds,
        p95: metrics.p95Microseconds,
        p99: metrics.p99Microseconds,
        max: metrics.maxMicroseconds
    ) else {
        throw VideoTransportValidationError.unorderedFrameAge
    }
}
