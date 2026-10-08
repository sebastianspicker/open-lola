// Runs the actual two-peer A/V socket loop with synthetic capture and the headless preview sink.
import Dispatch
import Foundation
import XCTest
import OpenLolaApplication
import OpenLolaTransport

final class DirectPeerAVLoopIntegrationTests: XCTestCase {
    func testTwoSyntheticPeersMoveAudioAndRenderVideoThenStop() throws {
        let reservations = try (0..<8).map { _ in try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 0) }
        defer { reservations.forEach { $0.close() } }
        let ports = reservations.map { $0.localEndpoint.port }
        let responder = configuration(role: .responder, localPorts: Array(ports[0..<4]), remoteControlPort: ports[4])
        let initiator = configuration(role: .initiator, localPorts: Array(ports[4..<8]), remoteControlPort: ports[0])
        let ready = DispatchSemaphore(value: 0)
        let finished = DispatchGroup()
        let results = SyntheticPeerResults()
        reservations[0..<4].forEach { $0.close() }
        finished.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            results.record(role: .responder, result: Result(catching: {
                try DirectPeerSessionSocketRunner.runManualAddressAudioVideo(
                    configuration: responder, onReady: { ready.signal() }
                )
            }))
            ready.signal()
            finished.leave()
        }
        guard ready.wait(timeout: .now() + 5) == .success else {
            XCTFail("Responder did not bind its sockets")
            return
        }
        if let completed = results.snapshot()[.responder] {
            _ = try completed.get()
            XCTFail("Responder ended before initiator started")
            return
        }
        reservations[4..<8].forEach { $0.close() }
        finished.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            results.record(role: .initiator, result: Result(catching: {
                try DirectPeerSessionSocketRunner.runManualAddressAudioVideo(configuration: initiator)
            }))
            finished.leave()
        }
        guard finished.wait(timeout: .now() + 10) == .success else {
            XCTFail("Bounded A/V sessions did not finish")
            return
        }
        let reports = results.snapshot()
        XCTAssertEqual(reports.count, 2)
        for role in [DirectPeerSessionManualRole.initiator, .responder] {
            let result = try XCTUnwrap(reports[role])
            let report = try result.get()
            let runtime = try XCTUnwrap(report.avRuntime)
            XCTAssertEqual(runtime.mediaSourceMode, .syntheticFixture)
            XCTAssertEqual(runtime.usefulMediaProof, .requiredAndProven)
            XCTAssertNotNil(runtime.receiveProof)
            XCTAssertGreaterThan(runtime.runtimeMetrics.audioPayloadsSent, 0)
            XCTAssertGreaterThan(runtime.runtimeMetrics.audioPayloadsQueuedForPlayout, 0)
            XCTAssertGreaterThan(runtime.runtimeMetrics.videoFramesSent, 0)
            XCTAssertGreaterThan(runtime.runtimeMetrics.videoFramesReassembled, 0)
            XCTAssertGreaterThan(runtime.runtimeMetrics.previewFramesSubmitted, 0)
            XCTAssertEqual(runtime.runtimeMetrics.previewFramesFailed, 0)
        }
    }

    private func configuration(
        role: DirectPeerSessionManualRole, localPorts: [UInt16], remoteControlPort: UInt16
    ) -> DirectPeerSessionAVRunConfiguration {
        let localID = role.rawValue
        let remoteID = role == .initiator ? "responder" : "initiator"
        let network = DirectPeerManualNetworkShape(
            localHost: "127.0.0.1", remoteHost: "127.0.0.1",
            ports: .init(controlPort: localPorts[0], remoteControlPort: remoteControlPort,
                         audioPort: localPorts[1], videoPort: localPorts[2], metricsPort: localPorts[3])
        )
        let manual = DirectPeerSessionManualRunConfiguration(
            identity: .init(role: role, localPeerID: localID, remotePeerID: remoteID),
            network: network, tuning: .init(timeoutSeconds: 2)
        )
        let devices = DirectPeerSessionAVRunConfiguration.DeviceRouting(
            inputDeviceUID: "synthetic-input", outputDeviceUID: "synthetic-output"
        )
        let video = DirectPeerSessionAVRunConfiguration.Video(deviceID: "synthetic-camera", width: 64, height: 36)
        return DirectPeerSessionAVRunConfiguration(
            manual: manual, durationSeconds: 1, devices: devices,
            audio: .init(framesPerPacket: 32), video: video,
            quality: .init(profile: .fastest, preview: .on, mediaSourceMode: .syntheticFixture)
        )
    }
}

private final class SyntheticPeerResults: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [DirectPeerSessionManualRole: Result<DirectPeerSessionReport, any Error>] = [:]

    func record(role: DirectPeerSessionManualRole, result: Result<DirectPeerSessionReport, any Error>) {
        lock.withLock { results[role] = result }
    }

    func snapshot() -> [DirectPeerSessionManualRole: Result<DirectPeerSessionReport, any Error>] {
        lock.withLock { results }
    }
}
