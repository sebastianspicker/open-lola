// Declares how a measurement was obtained, keeping synthetic and measured evidence explicit in reports.
/// Records how evidence was obtained so consumers can distinguish measured from non-measured results.
public enum MeasurementMethodology: String, Codable, Equatable, Sendable {
    case synthetic
    case measured
}
