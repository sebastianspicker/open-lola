// Captures route identity as a report-model value without runtime ownership.
public struct RouteIdentity: Codable, Equatable, Sendable {
    public let label: String
    public let topology: String

    public init(label: String, topology: String) {
        self.label = label
        self.topology = topology
    }
}
