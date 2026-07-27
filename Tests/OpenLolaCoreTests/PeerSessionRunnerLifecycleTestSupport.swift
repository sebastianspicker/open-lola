// Shared peer session runner lifecycle helpers keep related tests deterministic and focused on their contract.
import Foundation

@testable import OpenLolaCore

func drainDirectPeerAVControlEventually(
    runner: inout PeerSessionRunner,
    control: DirectPeerSessionControlSocket,
    remoteControl: SessionNetworkEndpoint,
    timeoutNanoseconds: UInt64 = 50_000_000
) throws -> DirectPeerAVControlServiceResult {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    repeat {
        let result = try serviceDirectPeerAVControl(
            runner: &runner,
            control: control,
            remoteControl: remoteControl
        )
        if result.controlMessagesReceived > 0 || result.controlMessagesDropped > 0 || result.shouldStop {
            return result
        }
        Thread.sleep(forTimeInterval: 0.001)
    } while DispatchTime.now().uptimeNanoseconds < deadline
    return DirectPeerAVControlServiceResult()
}

var peerSessionRunnerLifecycleRepositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

func peerSessionRunnerLifecycleSwiftSourceFiles(under root: URL) throws -> [URL] {
    try testSwiftSourceFiles(under: root)
}
