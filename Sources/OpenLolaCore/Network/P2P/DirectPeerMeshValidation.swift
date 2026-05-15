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
