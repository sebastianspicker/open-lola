// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation

enum DirectPeerAVControlStopReason: Equatable, Sendable {
    case peerMediaPause
    case terminal
}

struct DirectPeerAVControlServiceResult: Equatable, Sendable {
    var controlMessagesReceived = 0
    var controlMessagesDropped = 0
    var stopReason: DirectPeerAVControlStopReason?

    var shouldStop: Bool { stopReason != nil }
}

func serviceDirectPeerAVControl(
    runner: inout PeerSessionRunner,
    control: DirectPeerSessionControlSocket,
    remoteControl: SessionNetworkEndpoint,
    maxControlDatagrams: Int = 8
) throws -> DirectPeerAVControlServiceResult {
    var result = DirectPeerAVControlServiceResult()
    var drained = 0
    while drained < maxControlDatagrams {
        guard let message = try control.receiveMessageIfAvailable(expectedSource: remoteControl) else {
            break
        }
        drained += 1
        switch message.type {
        case .audioMetadata, .mediaStart, .mediaPause, .metrics, .error, .shutdown:
            do {
                try runner.receiveControlMessages([message])
                result.controlMessagesReceived += 1
            } catch PeerSessionRunnerError.unsupportedControlMessage {
                result.controlMessagesDropped += 1
                continue
            }
            if message.type == .mediaPause {
                result.stopReason = .peerMediaPause
                break
            }
            if message.type == .shutdown || (message.error?.fatal ?? false) {
                result.stopReason = .terminal
                break
            }
        default:
            result.controlMessagesDropped += 1
        }
    }
    return result
}
