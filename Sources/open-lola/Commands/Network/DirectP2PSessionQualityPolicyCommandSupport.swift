import OpenLolaCore

func directP2PQualityPolicy(
    _ value: String?
) throws -> DirectPeerSessionAVRunQualityPolicy {
    guard let value else {
        return .requireUsefulMedia
    }
    guard let policy = DirectPeerSessionAVRunQualityPolicy(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --quality-policy")
    }
    return policy
}
