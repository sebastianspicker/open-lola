// Shares stable report identity fields while phantom domains preserve semantic type identity.

/// Identifies one report capture and the run mode under which it was produced.
public struct ImmutableReportIdentity<Domain>: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let capturedAt: String
    public let runMode: ReportRunMode

    public init(id: String, title: String, capturedAt: String, runMode: ReportRunMode) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
    }
}

/// Identifies a captured report that does not carry a run-mode dimension.
public struct ReportCaptureIdentity<Domain>: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String

    public init(id: String, title: String, capturedAt: String) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
    }
}

/// Exposes the shared identity portion of report-specific metadata values.
protocol ReportMetadataFields {
    associatedtype RunMode

    var id: String { get }
    var title: String { get }
    var capturedAt: String { get }
    var runMode: RunMode { get }
}

func reportMetadataValues<Metadata: ReportMetadataFields>(
    _ metadata: Metadata
) -> (
    identity: (id: String, title: String),
    capture: (capturedAt: String, runMode: Metadata.RunMode)
) {
    ((metadata.id, metadata.title), (metadata.capturedAt, metadata.runMode))
}
