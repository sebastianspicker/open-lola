// Shares report outcome storage while phantom domains preserve semantic type identity.

/// Stores an immutable verdict and reviewer-facing notes for one report domain.
public struct ImmutableReportOutcome<Domain>: Codable, Equatable, Sendable {
    public let verdict: MeasurementVerdict
    public let notes: String

    public init(verdict: MeasurementVerdict, notes: String) {
        self.verdict = verdict
        self.notes = notes
    }
}

/// Stores a mutable verdict and reviewer-facing notes for one report domain.
public struct MutableReportOutcome<Domain>: Codable, Equatable, Sendable {
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(verdict: MeasurementVerdict, notes: String) {
        self.verdict = verdict
        self.notes = notes
    }
}

/// Stores a verdict together with the explicit boundary of captured evidence.
public struct EvidenceBoundaryReportOutcome<Domain>: Codable, Equatable, Sendable {
    public var verdict: MeasurementVerdict
    public var evidenceBoundary: String
    public var notes: String

    public init(verdict: MeasurementVerdict, evidenceBoundary: String, notes: String) {
        self.verdict = verdict
        self.evidenceBoundary = evidenceBoundary
        self.notes = notes
    }
}
