// Validates DirectPeerMeshValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
struct DirectPeerMeshDirectedPair: Hashable {
    var sender: String
    var receiver: String
}

func requireDirectPeerMeshNonEmpty(
    _ value: String,
    _ field: String,
    makeError: (String) -> Error
) throws {
    if value.isEmpty {
        throw makeError(field)
    }
}

func requireDirectPeerMeshNonNegative(
    _ value: Int,
    _ field: String,
    makeError: (String) -> Error
) throws {
    if value < 0 {
        throw makeError(field)
    }
}

func requireDirectPeerMeshMetric(
    _ condition: Bool,
    _ field: String,
    makeError: (String) -> Error
) throws {
    if !condition {
        throw makeError(field)
    }
}
