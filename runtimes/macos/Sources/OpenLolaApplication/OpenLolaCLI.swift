import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Defines CLI capability and version defaults, centralizing values consumed by the executable and tests.
import OpenLolaSessionDomain
/// Provides the implementation version and local capability advertisement shared by the CLI and tests.
public enum OpenLolaCLI {
    public static let implementationVersion = PeerSessionCapabilityProvider.openLolaDefault.implementationVersion

    public static func localCapabilitySet() -> CapabilitySet {
        PeerSessionCapabilityProvider.openLolaDefault.localCapabilitySet()
    }
}
