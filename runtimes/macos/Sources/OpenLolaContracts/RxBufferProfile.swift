// Declares public contract configuration and value types with input checks so parsers, runners, and tests apply the same invariants.
/// Selects the receive-buffer strategy shared by session configuration, runtime snapshots, and evidence reports.
public enum RxBufferProfile: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case direct
    case small
    case adaptive
    case stableWan
}
