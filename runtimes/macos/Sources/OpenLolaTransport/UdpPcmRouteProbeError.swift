// Defines socket-level UDP failures independently from route workflow configuration.
public enum UdpPcmRouteProbeError: Error, Equatable, Sendable {
    case invalidPacketCount(Int)
    case socketFailed
    case bindFailed(Int32)
    case getsocknameFailed(Int32)
    case invalidHost(String)
    case connectFailed(Int32)
    case fcntlFailed(Int32)
    case setSocketOptionFailed(Int32)
    case socketBufferTooSmall(option: Int32, requested: Int32, actual: Int32)
    case invalidDscp(Int)
    case sendFailed(Int32)
    case receiveFailed(Int32)
    case shortSend(expected: Int, actual: Int)
}
