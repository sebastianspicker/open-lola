// Collects public contract evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
/// Records the execution context behind a report so validators can distinguish proof from planning artifacts.
public enum ReportRunMode: String, Codable, Equatable, Sendable {
    case synthetic
    case measured
}
