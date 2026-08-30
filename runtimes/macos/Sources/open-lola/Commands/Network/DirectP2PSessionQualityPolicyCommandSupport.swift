// Validates DirectP2PSessionQualityPolicyCommandSupport acceptance rules, keeping failure policy close to its contract rather than the runtime path.
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
