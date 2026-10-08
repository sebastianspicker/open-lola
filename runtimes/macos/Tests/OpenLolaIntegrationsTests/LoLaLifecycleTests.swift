// Exercises LoLa media cancellation, worker cleanup, and negotiated format validation.
import Darwin
import Dispatch
import Foundation
import XCTest
import OpenLolaSessionDomain
@testable import OpenLolaIntegrations

final class LoLaLifecycleTests: XCTestCase {
    private func configuration(
        role: ExternalConnectorSessionRole = .txRx,
        video: Bool = false,
        localHost: String = "127.0.0.1"
    ) -> ExternalConnectorSessionConfiguration {
        ExternalConnectorSessionConfiguration(.init(
            connector: .lola, role: role, peer: "127.0.0.1", outputPath: "/private/tmp/lola-lifecycle-report.json"
        ) { input in
            input.localHost = localHost
            input.dryRun = false
            input.mediaMode = video ? .audioVideo : .audio
            input.durationSeconds = 5
            input.audioPort = 0
            input.videoPort = 0
            input.videoWidth = 32
            input.videoHeight = 24
            input.videoBitsPerPixel = 8
            input.videoFrameRate = 25
            input.videoCompression = 0
            input.videoBayer = 0
        })
    }

    func testDisconnectInterruptsTransmitBeforeDuration() throws {
        let config = configuration(role: .tx)
        let cancellation = LoLaSessionCancellation()
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(100)) {
            cancellation.cancel(reason: "peer disconnected", peerMessage: "/MESG_DISCONNECT")
        }
        let start = DispatchTime.now().uptimeNanoseconds
        // Inject a real UDP socket, with a valid destination port; capture is synthetic.
        let socket = try makeLoLaUdpMediaSocket(bindHost: "127.0.0.1", port: 0)
        defer { close(socket) }
        var validConfig = config
        validConfig.audioPort = try socketPort(socket)
        let report = try LoLaSocketUdpMediaLiveTransmitter().transmit(
            configuration: validConfig, socketForPort: { _ in socket }, cancellation: cancellation
        )
        XCTAssertLessThan(DispatchTime.now().uptimeNanoseconds - start, 1_000_000_000)
        XCTAssertGreaterThan(report.sentBytesTotal ?? 0, 0)
        XCTAssertTrue(report.notes.contains("peer disconnected"))
    }

    func testCancelBetweenFragmentsStopsVideoBurst() throws {
        let packets = try LoLaCompatibilityMediaCodec.videoPackets(sequenceNumber: 0, payload: Data(repeating: 7, count: 8_000))
        XCTAssertGreaterThan(packets.count, 1)
        let cancellation = LoLaSessionCancellation()
        var sendCount = 0
        let result = try sendLoLaLivePackets(
            packets,
            request: .init(socket: -1, peer: "127.0.0.1", port: 9000, deadline: .now() + .seconds(5), cancellation: cancellation),
            send: { payload, _, _, _ in
                sendCount += 1
                cancellation.cancel(reason: "peer disconnected")
                return .sent(payload.count)
            }
        )
        XCTAssertEqual(sendCount, 1)
        XCTAssertEqual(result.sentDatagrams, 1)
        XCTAssertFalse(result.abandonedAtDeadline)
        XCTAssertFalse(result.droppedForBackpressure)
    }

    func testBidirectionalCancellationJoinsWorkersPromptly() throws {
        let cancellation = LoLaSessionCancellation()
        let start = DispatchTime.now().uptimeNanoseconds
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(100)) {
            cancellation.cancel(reason: "peer disconnected", peerMessage: "/MESG_DISCONNECT")
        }
        // Port zero allocates local receive sockets; TX to port zero fails. Use
        // separately allocated free ports for this end-to-end local exchange.
        var config = configuration()
        let audio = try makeLoLaUdpMediaSocket(bindHost: "127.0.0.1", port: 0)
        let video = try makeLoLaUdpMediaSocket(bindHost: "127.0.0.1", port: 0)
        config.audioPort = try socketPort(audio)
        config.videoPort = try socketPort(video)
        close(audio)
        close(video)
        let report = try LoLaUdpMediaBidirectionalRunner.run(configuration: config, cancellation: cancellation)
        XCTAssertLessThan(DispatchTime.now().uptimeNanoseconds - start, 1_000_000_000)
        XCTAssertGreaterThan(report.sentBytesTotal ?? 0, 0)
        XCTAssertNil(report.runtimeError)
        XCTAssertTrue(report.notes.contains("peer disconnected"))
    }

    func testReceiveBindFailureDoesNotWaitForUnstartedTransmitter() throws {
        let start = DispatchTime.now().uptimeNanoseconds
        XCTAssertThrowsError(try LoLaUdpMediaBidirectionalRunner.run(
            configuration: configuration(localHost: "invalid"), cancellation: nil
        ))
        XCTAssertLessThan(DispatchTime.now().uptimeNanoseconds - start, 1_000_000_000)
    }

    func testDisconnectRequiresNegotiatedPeerPortAndSession() throws {
        let config = configuration()
        let terminal = LoLaControlTerminalSession(sourceIP: "127.0.0.1", destinationIP: "127.0.0.1", sessionID: 42, send: { $0.utf8.count })
        let message = LoLaCompatibilityControlMessage.disconnect(sourceIP: "127.0.0.1", destinationIP: "127.0.0.1", sessionID: 42)
        let parsed = try LoLaCompatibilityControlMessage.parse(message)
        XCTAssertFalse(lolaRetryResponderHandlePeerDisconnect(configuration: config, message: message, parsed: parsed, senderHost: "127.0.0.1", senderPort: config.controlPort + 1, terminalSession: terminal))
        XCTAssertFalse(terminal.cancellation.isCancelled)
        XCTAssertTrue(lolaRetryResponderHandlePeerDisconnect(configuration: config, message: message, parsed: parsed, senderHost: "127.0.0.1", senderPort: config.controlPort, terminalSession: terminal))
        XCTAssertEqual(terminal.cancellation.peerMessage, message)
    }

    func testResponderRejectsVideoTupleItWillNotRun() throws {
        let config = configuration(video: true)
        var fields = try lolaExpectedQuickConnectFields(configuration: config, sourceIP: config.localHost)
        fields["X"] = "1280"
        XCTAssertThrowsError(try lolaQuickConnectAck(configuration: config, receivedFields: fields, senderHost: config.peer)) { error in
            XCTAssertEqual(lolaQuickConnectRejectReason(error), "video settings mismatch")
        }
    }

    func testBidirectionalAckMustPreserveVideoTuple() throws {
        let config = configuration(video: true)
        let fields = try lolaExpectedQuickConnectFields(configuration: config, sourceIP: config.localHost)
        XCTAssertEqual(fields["X"], "32")
        XCTAssertEqual(fields["BPP"], "8")
        var changed = fields
        changed["COMP"] = "1"
        let failure = lolaOutgoingHandshakeFailure(
            context: .init(sentMessages: [], receivedMessages: [], opaqueControlDatagrams: [], bytesTransferred: 0, parsedMessageName: "/MESG_QUICKCONN_ACK", fields: changed, message: "ack", senderHost: config.peer, senderPort: config.controlPort),
            expectedName: "/MESG_QUICKCONN_ACK", expectedFields: fields, expectedSenderHost: config.peer, expectedSenderPort: config.controlPort
        )
        XCTAssertNotNil(failure)
    }

    func testAudioOnlyAckAllowsPeerVideoPlaceholders() throws {
        let config = configuration(role: .tx)
        let expected = try lolaExpectedQuickConnectFields(configuration: config, sourceIP: config.localHost)
        XCTAssertNil(expected["X"])
        XCTAssertNil(expected["FPS"])
        var fields = expected
        for key in ["FPS", "BPP", "X", "Y", "COMP", "BAYER"] { fields[key] = "0" }
        XCTAssertNoThrow(try lolaQuickConnectAck(configuration: config, receivedFields: fields, senderHost: config.peer))
    }

    func testNormalBidirectionalDeadlineJoinsWithoutTimeoutFailure() throws {
        var config = configuration()
        config.durationSeconds = 1
        let audio = try makeLoLaUdpMediaSocket(bindHost: "127.0.0.1", port: 0)
        let video = try makeLoLaUdpMediaSocket(bindHost: "127.0.0.1", port: 0)
        config.audioPort = try socketPort(audio)
        config.videoPort = try socketPort(video)
        close(audio)
        close(video)
        let report = try LoLaUdpMediaBidirectionalRunner.run(configuration: config)
        XCTAssertNil(report.runtimeError)
        XCTAssertGreaterThan(report.sentBytesTotal ?? 0, 0)
    }

    func testSessionEvidenceForwardsDisconnectToEveryRole() throws {
        for role in [ExternalConnectorSessionRole.tx, .rx, .txRx] {
            XCTAssertTrue(shouldStartLoLaControlRetryResponder(configuration: configuration(role: role)))
            let cancellation = LoLaSessionCancellation()
            cancellation.cancel(reason: "peer disconnected", peerMessage: "/MESG_DISCONNECT")
            let start = DispatchTime.now().uptimeNanoseconds
            let report = try makeLoLaMediaSessionEvidence(configuration(role: role), allowRealMedia: true, cancellation: cancellation)
            XCTAssertLessThan(DispatchTime.now().uptimeNanoseconds - start, 1_000_000_000)
            XCTAssertNil(report?.runtimeError)
            XCTAssertTrue(report?.notes.contains("peer disconnected") == true)
        }
    }

    private func socketPort(_ descriptor: Int32) throws -> UInt16 {
        var address = sockaddr_in()
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        let result = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &size) }
        }
        XCTAssertEqual(result, 0)
        return UInt16(bigEndian: address.sin_port)
    }
}
