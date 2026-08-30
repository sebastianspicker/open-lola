import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Requires negotiated transports, creates collision-resistant session IDs, allocates loopback control ports, and normalizes video formats.
import Foundation
import Security

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

    static func sessionID(
        kind: String,
        localPeerID: String,
        remotePeerID: String,
        nonce: [UInt8]
    ) throws -> String {
        _ = localPeerID
        _ = remotePeerID
        guard nonce.count == 16 else {
            throw PeerSessionRunnerError.secureSessionIDGenerationFailed(-1)
        }
        return "m06-direct-p2p/\(kind)/nonce:" + nonce.map { String(format: "%02x", $0) }.joined()
    }
}

/// Produces opaque nonces that separate direct-peer sessions and stale control traffic.
/// It does not authenticate peers or control messages.
func secureSessionIDNonce() throws -> [UInt8] {
    var nonce = [UInt8](repeating: 0, count: 16)
    let status = SecRandomCopyBytes(kSecRandomDefault, nonce.count, &nonce)
    guard status == errSecSuccess else {
        throw PeerSessionRunnerError.secureSessionIDGenerationFailed(Int32(status))
    }
    return nonce
}

func allocatedControlEndpoint() throws -> SessionNetworkEndpoint {
    let descriptor = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { closeUdpSocket(descriptor) }
    try OpenLolaTransport.bindLoopback(descriptor, port: 0)
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
