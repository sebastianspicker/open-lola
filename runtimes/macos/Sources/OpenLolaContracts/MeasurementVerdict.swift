// Declares measurement verdict values, giving reports and validators a shared pass/fail vocabulary.
/// Records the evidence-backed disposition of a measurement or validation run.
public enum MeasurementVerdict: String, Codable, Hashable, Sendable {
    case pass
    case fail
    case partial
}
