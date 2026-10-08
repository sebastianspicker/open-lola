// Exercises outgoing LoLa control negotiation and peer disconnect across all transmitting roles.
import Darwin
import Dispatch
import Foundation
import OpenLolaTransport
import XCTest
@testable import OpenLolaIntegrations

final class LoLaSessionControlTests: XCTestCase {
    func testOutgoingRolesReceivePeerDisconnectThroughNegotiatedControlSocket() throws {
        for role in [ExternalConnectorSessionRole.tx, .txRx] {
            let peerSocket = try makeLoLaUdpMediaSocket(bindHost: "127.0.0.1", port: 0)
            let audioSocket = try makeLoLaUdpMediaSocket(bindHost: "127.0.0.1", port: 0)
            let videoSocket = try makeLoLaUdpMediaSocket(bindHost: "127.0.0.1", port: 0)
            defer { close(peerSocket) }
            let controlPort = try port(of: peerSocket)
            let audioPort = try port(of: audioSocket)
            let videoPort = try port(of: videoSocket)
            close(audioSocket)
            close(videoSocket)
            let config = ExternalConnectorSessionConfiguration(.init(
                connector: .lola, role: role, peer: "127.0.0.1", outputPath: "/private/tmp/lola-session-control-test.json"
            ) { input in
                input.localHost = "127.0.0.1"
                input.controlTransport = .udp
                input.controlPort = controlPort
                input.audioPort = audioPort
                input.videoPort = videoPort
                input.mediaMode = .audio
                input.sessionID = "42"
                input.durationSeconds = 5
                input.dryRun = false
            })
            let peerFinished = expectation(description: "peer completed \(role)")
            DispatchQueue.global().async {
                defer { peerFinished.fulfill() }
                do {
                    guard try waitForReadableSocket(socket: peerSocket, timeoutMicroseconds: 1_000_000) else {
                        XCTFail("missing status check")
                        return
                    }
                    let status = try receiveExternalConnectorUdp(socket: peerSocket, bufferSize: 4096)
                    let statusAck = LoLaCompatibilityControlMessage.checkStatusAck(sourceIP: config.peer, destinationIP: config.localHost, sessionID: 42)
                    _ = try sendExternalConnectorUdp(statusAck, socket: peerSocket, host: config.localHost, port: status.senderPort)
                    guard try waitForReadableSocket(socket: peerSocket, timeoutMicroseconds: 1_000_000) else {
                        XCTFail("missing QUICKCONN")
                        return
                    }
                    let quick = try receiveExternalConnectorUdp(socket: peerSocket, bufferSize: 4096)
                    let parsed = try LoLaCompatibilityControlMessage.parse(quick.message)
                    let ack = try lolaQuickConnectAck(configuration: config, receivedFields: parsed.fields, senderHost: config.localHost)
                    _ = try sendExternalConnectorUdp(ack, socket: peerSocket, host: config.localHost, port: quick.senderPort)
                    usleep(100_000)
                    let disconnect = LoLaCompatibilityControlMessage.disconnect(sourceIP: config.peer, destinationIP: config.localHost, sessionID: 42)
                    _ = try sendExternalConnectorUdp(disconnect, socket: peerSocket, host: config.localHost, port: quick.senderPort)
                } catch {
                    XCTFail("peer control exchange failed: \(error)")
                }
            }
            let start = DispatchTime.now().uptimeNanoseconds
            let report = try ExternalConnectorSessionRunner.run(configuration: config)
            wait(for: [peerFinished], timeout: 2)
            XCTAssertLessThan(DispatchTime.now().uptimeNanoseconds - start, 2_000_000_000)
            XCTAssertNil(report.runtimeError)
            XCTAssertTrue(report.lolaControlRetryResponder?.started == true)
            XCTAssertTrue(report.lolaMedia?.notes.contains("peer disconnected") == true)
            XCTAssertTrue(report.lolaControl?.receivedMessages.contains(where: { $0.hasPrefix("/MESG_DISCONNECT;") }) == true)
        }
    }

    private func port(of descriptor: Int32) throws -> UInt16 {
        var address = sockaddr_in()
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        let result = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &size) }
        }
        XCTAssertEqual(result, 0)
        return UInt16(bigEndian: address.sin_port)
    }
}
