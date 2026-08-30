// Defines direct-peer control socket bounds and failures below the application runner layer.
import OpenLolaSessionDomain

package let directPeerMaximumTimeoutSeconds = 86_400

public enum DirectPeerSessionSocketRunnerError: Error, Equatable, Sendable {
    case timedOutWaitingForControlMessage(String)
    case unexpectedControlSource(expected: SessionNetworkEndpoint, actualHost: String, actualPort: UInt16)
    case invalidPacketCount(Int)
    case invalidTimeoutSeconds(Int)
    case invalidAudioChannelCount(Int)
    case invalidManualHost(String, String)
    case invalidManualHostParse(String, String, Int32)
    case invalidManualPort(String, UInt16)
    case duplicateManualPort(String, UInt16)
    case missingExpectedControlMessage(String)
    case missingRemoteCapabilities
}
