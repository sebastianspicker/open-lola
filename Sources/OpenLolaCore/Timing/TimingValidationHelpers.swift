func timingPercentilesAreOrdered(p50: Double, p95: Double, p99: Double, max: Double) -> Bool {
    p50 <= p95 && p95 <= p99 && p99 <= max
}
