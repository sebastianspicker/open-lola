// Supplies session capability defaults by dependency injection so direct-peer execution does not depend on application CLI policy.
import Foundation

/// Supplies the local capability advertisement and version identity used to start a peer session.
public struct PeerSessionCapabilityProvider: Sendable {
    public let implementationVersion: String
    private let makeCapabilities: @Sendable () -> CapabilitySet

    public init(
        implementationVersion: String,
        makeCapabilities: @escaping @Sendable () -> CapabilitySet
    ) {
        self.implementationVersion = implementationVersion
        self.makeCapabilities = makeCapabilities
    }

    public func localCapabilitySet() -> CapabilitySet {
        makeCapabilities()
    }
}
