// Exercises LoLa retry acknowledgments and accepted-session control ownership.
import Darwin
import Foundation
import OpenLolaTransport

import XCTest
@testable import OpenLolaIntegrations

final class LoLaRetryTests: XCTestCase {
    func testRetryResponderPinsSessionAndSurvivesUnrelatedMessage() throws {
        let responder = try makeLoLaUdpMediaSocket(bindHost: "127.0.0.1", port: 0)
        defer { close(responder) }
        var address = sockaddr_in()
        var addressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let result = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(responder, $0, &addressLength) }
        }
        XCTAssertEqual(result, 0)
        let responderPort = UInt16(bigEndian: address.sin_port)
        // Independent ephemeral sockets model both endpoints on Darwin's
        // single loopback address; cancellation still pins the peer's port.
        let peer = try makeLoLaUdpMediaSocket(bindHost: "127.0.0.1", port: 0)
        defer { close(peer) }
        let peerResult = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(peer, $0, &addressLength) }
        }
        XCTAssertEqual(peerResult, 0)
        let port = UInt16(bigEndian: address.sin_port)
        let config = ExternalConnectorSessionConfiguration(.init(
            connector: .lola, role: .rx, peer: "127.0.0.1", outputPath: "/private/tmp/lola-retry-test.json"
        ) { input in
            input.localHost = "127.0.0.1"
            input.controlPort = port
            input.durationSeconds = 5
            input.dryRun = false
            input.mediaMode = .audio
        })
        let terminal = LoLaControlTerminalSession(
            sourceIP: config.localHost, destinationIP: config.peer, sessionID: 42,
            send: { $0.utf8.count }, duplicateSocketForRetryResponder: { dup(responder) }
        )
        defer { terminal.cancellation.cancel(reason: "test finished") }
        XCTAssertTrue(startLoLaControlRetryResponder(configuration: config, terminalSession: terminal).started)
        let unrelated = LoLaCompatibilityControlMessage.checkStatus(sourceIP: config.peer, destinationIP: config.localHost, sessionID: 43)
        _ = try sendExternalConnectorUdp(unrelated, socket: peer, host: config.localHost, port: responderPort)
        XCTAssertFalse(try waitForReadableSocket(socket: peer, timeoutMicroseconds: 100_000))
        let retry = LoLaCompatibilityControlMessage.checkStatus(sourceIP: config.peer, destinationIP: config.localHost, sessionID: 42)
        for _ in 0..<2 {
            _ = try sendExternalConnectorUdp(retry, socket: peer, host: config.localHost, port: responderPort)
            XCTAssertTrue(try waitForReadableSocket(socket: peer, timeoutMicroseconds: 1_000_000))
            let received = try receiveExternalConnectorUdp(socket: peer, bufferSize: 4096)
            let parsed = try LoLaCompatibilityControlMessage.parse(received.message)
            XCTAssertEqual(parsed.name, "/MESG_CHECKLOLASTATUS_ACK")
            XCTAssertEqual(parsed.fields["SID"], "42")
        }
        terminal.cancellation.cancel(reason: "test finished")
        _ = try sendExternalConnectorUdp(retry, socket: peer, host: config.localHost, port: responderPort)
        XCTAssertFalse(try waitForReadableSocket(socket: peer, timeoutMicroseconds: 100_000))
    }
}
