import Foundation

extension PeerSessionRunner {
    static func requirePeerSessionTransport(
        _ transport: UdpMediaTransport?,
        _ label: String
    ) throws -> UdpMediaTransport {
        guard let transport else {
            switch label {
            case "audio":
                throw PeerSessionRunnerError.missingAudioTransport
            case "video":
                throw PeerSessionRunnerError.missingVideoTransport
            default:
                throw PeerSessionRunnerError.missingMetricsTransport
            }
        }
        return transport
    }

    static func sessionID(kind: String, localPeerID: String, remotePeerID: String) -> String {
        "m06-direct-p2p/\(kind)/local:\(localPeerID.utf8.count):\(localPeerID)/remote:\(remotePeerID.utf8.count):\(remotePeerID)"
    }
}

func allocatedControlEndpoint() throws -> SessionNetworkEndpoint {
    let descriptor = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { closeUdpSocket(descriptor) }
    try OpenLolaCore.bindLoopback(descriptor, port: 0)
    return SessionNetworkEndpoint(
        host: "127.0.0.1",
        port: UInt16(bigEndian: try boundPort(descriptor))
    )
}

func videoPixelFormatDescription(_ value: String) throws -> VideoPixelFormat {
    let normalized = directPeerNormalizedVideoPixelFormat(value)
    guard let pixelFormat = VideoPixelFormat(rawValue: normalized), pixelFormat != .disabled else {
        throw SessionValidationError.unsupportedVideoPixelFormat(.disabled)
    }
    return pixelFormat
}
