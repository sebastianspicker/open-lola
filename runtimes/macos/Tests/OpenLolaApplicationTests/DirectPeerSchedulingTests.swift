// Verifies negotiated diagnostic audio cadence and bounded video work in the direct-peer runtime.
import XCTest
@testable import OpenLolaApplication

// Verifies scheduler limits at the shortest AES67 cadence and diagnostic capture pacing.
final class DirectPeerSchedulingTests: XCTestCase {
    func testVideoBurstUsesQuarterOfShortestAudioPeriod() {
        XCTAssertEqual(directPeerVideoWorkBudgetNanoseconds(audioPacketIntervalNanoseconds: 125_000), 31_250)
        XCTAssertEqual(directPeerVideoWorkBudgetNanoseconds(audioPacketIntervalNanoseconds: 1_000_000), 250_000)
        XCTAssertEqual(directPeerVideoWorkBudgetNanoseconds(audioPacketIntervalNanoseconds: 10_000_000), 250_000)
        XCTAssertEqual(directPeerVideoWorkBudgetNanoseconds(audioPacketIntervalNanoseconds: 0), 1)
    }

    func testSyntheticCaptureDoesNotFollowFrequentVideoWakeups() throws {
        var configuration = syntheticSessionConfiguration()
        let timing = try DirectPeerAVMediaLoopTiming(configuration: configuration)
        let resources = try makeDirectPeerAVMediaLoopResources(configuration)
        var state = try DirectPeerAVMediaLoopState(configuration: configuration, timing: timing)
        var capturedFrames: [UInt64] = []
        for now: UInt64 in stride(from: 1_000_000, through: 11_000_000, by: 50_000) {
            try captureSyntheticAVAudioIfNeeded(
                resources: resources, state: &state, configuration: configuration, timing: timing, now: now
            )
            if let startFrame = resources.audioGraph.withCapturedPayload({ block, bytes in
                XCTAssertEqual(bytes.count, configuration.framesPerPacket * 2 * MemoryLayout<Float>.size)
                return block.startFrame
            }) {
                capturedFrames.append(startFrame)
            }
        }
        XCTAssertEqual(capturedFrames, (0...10).map { UInt64($0 * configuration.framesPerPacket) })
        XCTAssertEqual(state.audioSequence, 12)
        XCTAssertEqual(resources.audioGraph.runtimeCounters().capturedInputBlocks, 11)
        XCTAssertNil(state.playoutAnchor.latestAudioHostTimeNanoseconds)
        configuration.mediaSourceMode = .production
        try captureSyntheticAVAudioIfNeeded(
            resources: resources, state: &state, configuration: configuration, timing: timing, now: 12_000_000
        )
        XCTAssertEqual(resources.audioGraph.runtimeCounters().capturedInputBlocks, 11)
    }

    private func syntheticSessionConfiguration() -> DirectPeerSessionAVRunConfiguration {
        DirectPeerSessionAVRunConfiguration(
            manual: .init(
                identity: .init(role: .initiator, localPeerID: "capture-a", remotePeerID: "capture-b"),
                network: .init(localHost: "127.0.0.1", remoteHost: "127.0.0.1", ports: .init(
                    controlPort: 40_000, remoteControlPort: 40_004,
                    audioPort: 40_001, videoPort: 40_002, metricsPort: 40_003
                ))
            ),
            durationSeconds: 1,
            devices: .init(inputDeviceUID: "synthetic-input", outputDeviceUID: "synthetic-output"),
            audio: .init(framesPerPacket: 48),
            video: .init(deviceID: "synthetic-camera", width: 16, height: 16),
            quality: .init(profile: .fastest, preview: .off, mediaSourceMode: .syntheticFixture)
        )
    }

    func testSyntheticAudioDeadlineSaturates() {
        XCTAssertEqual(directPeerNextSyntheticAudioTime(nowNanoseconds: UInt64.max - 2, intervalNanoseconds: 10), UInt64.max)
    }
}
