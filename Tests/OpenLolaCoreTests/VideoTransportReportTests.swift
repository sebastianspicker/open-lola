// Verifies that raw video transport encodes fragments and wire format deterministically.
import Foundation
import Testing
@testable import OpenLolaCore
@Test
func rawVideoTransportEncodesFragmentsAndWireFormatDeterministically() throws {
    let source = TestPatternCameraSource(width: 640, height: 480, frameIntervalNanoseconds: 1)
    let frame = try #require(source.nextFrame())
    let packet = RawVideoFrameTransport.packet(for: frame)
    let fragments = try RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 1_200)
    #expect(packet.sequenceNumber == 0)
    #expect(packet.timestampNanoseconds == 0)
    #expect(packet.payloadByteCount == 921_600)
    #expect(packet.frameFingerprint == "test-pattern-0-640x480")
    #expect(!fragments.isEmpty)
    #expect(fragments.allSatisfy { $0.encodedByteCount <= 1_200 })
    #expect(fragments.first?.fragmentIndex == 0)
    #expect((fragments.last?.payloadOffset ?? 0) + (fragments.last?.payloadByteCount ?? 0) == 921_600)
    #expect(Set(fragments.map(\.fragmentIndex)).count == fragments.count)
    let encodedSource = TestPatternCameraSource(width: 64, height: 48, frameIntervalNanoseconds: 1)
    let encodedFrame = try #require(encodedSource.nextFrame())
    let fragment = try #require(RawVideoFrameTransport.fragments(for: encodedFrame, maxPacketBytes: 512).first)
    let encoded = try fragment.encoded()
    #expect(encoded.count == fragment.encodedByteCount)
    #expect(VideoTransportFormat.magic == [UInt8]("OLVF".utf8))
    #expect(VideoTransportFormat.fixedHeaderByteCount == 72)
    #expect(VideoTransportFormat.headerGuardOffset == 68)
    #expect(Array(encoded.prefix(VideoTransportFormat.magic.count)) == VideoTransportFormat.magic)
    #expect(encoded[VideoTransportFormat.versionOffset] == VideoTransportFormat.currentVersion)
    #expect(try VideoTransportFragment.decode(encoded) == fragment)
}
@Test
func videoFrameReassemblerCompletesOutOfOrderAndDuplicateFragments() throws {
    let source = TestPatternCameraSource(width: 64, height: 48, frameIntervalNanoseconds: 1)
    let frame = try #require(source.nextFrame())
    let fragments = try RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 512)
    let reassembler = VideoFrameReassembler()
    var completed: VideoTransportPacket?
    for fragment in fragments.reversed() {
        completed = try reassembler.receive(fragment) ?? completed
    }
    #expect(completed == RawVideoFrameTransport.packet(for: frame))
    #expect(reassembler.metrics.framesReassembled == 1)
    #expect(reassembler.metrics.framesDroppedIncomplete == 0)
    #expect(reassembler.metrics.missingFragments == 0)
    let duplicateFrame = try #require(source.nextFrame())
    let duplicateFragments = try RawVideoFrameTransport.fragments(for: duplicateFrame, maxPacketBytes: 512)
    let duplicateReassembler = VideoFrameReassembler()
    var duplicateCompleted: VideoTransportPacket?
    for fragment in duplicateFragments {
        duplicateCompleted = try duplicateReassembler.receive(fragment) ?? duplicateCompleted
        duplicateCompleted = try duplicateReassembler.receive(fragment) ?? duplicateCompleted
    }
    #expect(duplicateCompleted == RawVideoFrameTransport.packet(for: duplicateFrame))
    #expect(duplicateReassembler.metrics.framesReassembled == 1)
    #expect(duplicateReassembler.metrics.duplicateFragments == duplicateFragments.count - 1)
    let aliasFrame = try #require(source.nextFrame())
    let aliasFragments = try RawVideoFrameTransport.fragments(for: aliasFrame, maxPacketBytes: 512)
    let aliasReassembler = VideoFrameReassembler()
    let alias = aliasReassembler
    var aliasCompleted: VideoTransportPacket?
    for fragment in aliasFragments.prefix(aliasFragments.count / 2) {
        aliasCompleted = try aliasReassembler.receive(fragment) ?? aliasCompleted
    }
    for fragment in aliasFragments.dropFirst(aliasFragments.count / 2) {
        aliasCompleted = try alias.receive(fragment) ?? aliasCompleted
    }
    #expect(aliasCompleted == RawVideoFrameTransport.packet(for: aliasFrame))
    #expect(aliasReassembler == alias)
    #expect(aliasReassembler.metrics.framesReassembled == 1)
    #expect(alias.metrics.framesReassembled == 1)
}
@Test
func videoFrameReassemblerDropsIncompleteFramesForNewerExpiredAndCapacityCases() throws {
 try expectReassemblerDropsIncompleteForNewerFrame()
 try expectReassemblerDropsExpiredIncompleteFrame()
 try expectReassemblerDropsOldestIncompleteFrameAtCapacity()
}
private func expectReassemblerDropsIncompleteForNewerFrame() throws {
 let source = TestPatternCameraSource(width: 64, height: 48, frameIntervalNanoseconds: 1)
 let firstFrame = try #require(source.nextFrame())
 let secondFrame = try #require(source.nextFrame())
 let firstFragments = try RawVideoFrameTransport.fragments(for: firstFrame, maxPacketBytes: 512)
 let secondFragments = try RawVideoFrameTransport.fragments(for: secondFrame, maxPacketBytes: 512)
    let reassembler = VideoFrameReassembler()
    #expect(try reassembler.receive(try #require(firstFragments.first)) == nil)
    for fragment in secondFragments {
        _ = try reassembler.receive(fragment)
    }
    #expect(reassembler.metrics.framesDroppedIncomplete == 1)
    #expect(reassembler.metrics.missingFragments == firstFragments.count - 1)
 #expect(reassembler.metrics.framesReassembled == 1)
 #expect(try reassembler.receive(firstFragments[1]) == nil)
 #expect(reassembler.metrics.lateFragments == 1)
}
private func expectReassemblerDropsExpiredIncompleteFrame() throws {
 let source = TestPatternCameraSource(width: 64, height: 48, frameIntervalNanoseconds: 1)
 let expiredFirstFrame = try #require(source.nextFrame())
 let expiredSecondFrame = try #require(source.nextFrame())
 let expiredFirstFragments = try RawVideoFrameTransport.fragments(for: expiredFirstFrame, maxPacketBytes: 512)
 let expiredSecondFragments = try RawVideoFrameTransport.fragments(for: expiredSecondFrame, maxPacketBytes: 512)
    let expiredFirstFragment = try #require(expiredFirstFragments.first)
    let expiredSecondFragment = try #require(expiredSecondFragments.first)
    let expiringReassembler = VideoFrameReassembler(maxActiveFrames: 4, maxFrameAgeNanoseconds: 0)
    #expect(try expiringReassembler.receive(expiredFirstFragment) == nil)
    #expect(try expiringReassembler.receive(expiredSecondFragment) == nil)
 #expect(expiringReassembler.metrics.framesDroppedIncomplete == 1)
 #expect(expiringReassembler.metrics.missingFragments == expiredFirstFragment.fragmentCount - 1)
}
private func expectReassemblerDropsOldestIncompleteFrameAtCapacity() throws {
 let capacityFirstFrame = syntheticVideoFrame(
  streamID: 1,
  timestampNanoseconds: 1,
  fingerprint: "capacity-1"
 )
 let capacitySecondFrame = syntheticVideoFrame(
  streamID: 2,
  timestampNanoseconds: 2,
  fingerprint: "capacity-2"
 )
 let capacityFirstFragments = try RawVideoFrameTransport.fragments(for: capacityFirstFrame, maxPacketBytes: 512)
 let capacitySecondFragments = try RawVideoFrameTransport.fragments(for: capacitySecondFrame, maxPacketBytes: 512)
 let capacityFirstFragment = try #require(capacityFirstFragments.first)
    let capacitySecondFragment = try #require(capacitySecondFragments.first)
    let capacityReassembler = VideoFrameReassembler(maxActiveFrames: 1)
    #expect(try capacityReassembler.receive(capacityFirstFragment) == nil)
    #expect(try capacityReassembler.receive(capacitySecondFragment) == nil)
    #expect(capacityReassembler.metrics.framesDroppedIncomplete == 1)
    #expect(capacityReassembler.metrics.missingFragments == capacityFirstFragment.fragmentCount - 1)
    #expect(capacityReassembler.metrics.activeFramesPeak == 1)
}
@Test
func videoFrameReassemblerExpiresIncompleteFramesAtProductionDefaultAge() throws {
 let firstFrame = syntheticVideoFrame(
  streamID: 1,
  timestampNanoseconds: 1,
  fingerprint: "default-age-1"
 )
 let secondFrame = syntheticVideoFrame(
  streamID: 2,
  timestampNanoseconds: 2,
  fingerprint: "default-age-2"
 )
 let firstFragment = try #require(RawVideoFrameTransport.fragments(
        for: firstFrame,
        maxPacketBytes: 512
    ).first)
    let secondFragment = try #require(RawVideoFrameTransport.fragments(
        for: secondFrame,
        maxPacketBytes: 512
    ).first)
    let boundaryReassembler = VideoFrameReassembler(maxActiveFrames: 4)
    let expiringReassembler = VideoFrameReassembler(maxActiveFrames: 4)
    let startTime = UInt64(10_000)
    let productionDefaultAge = UInt64(250_000_000)
    #expect(try boundaryReassembler.receive(
        firstFragment,
        receivedAtNanosecondsForTesting: startTime
    ) == nil)
    #expect(try boundaryReassembler.receive(
        secondFragment,
        receivedAtNanosecondsForTesting: startTime + productionDefaultAge
    ) == nil)
    #expect(boundaryReassembler.metrics.framesDroppedIncomplete == 0)
    #expect(try expiringReassembler.receive(
        firstFragment,
        receivedAtNanosecondsForTesting: startTime
    ) == nil)
    #expect(try expiringReassembler.receive(
        secondFragment,
        receivedAtNanosecondsForTesting: startTime + productionDefaultAge + 1
    ) == nil)
 #expect(expiringReassembler.metrics.framesDroppedIncomplete == 1)
 #expect(expiringReassembler.metrics.missingFragments == firstFragment.fragmentCount - 1)
}
private func syntheticVideoFrame(
 streamID: UInt32,
 timestampNanoseconds: UInt64,
 fingerprint: String
) -> CapturedVideoFrame {
 CapturedVideoFrame(
  streamID: streamID,
  sequenceNumber: 1,
  timestampNanoseconds: timestampNanoseconds,
  timestampBasis: .hostUptimeNanoseconds,
  sourceRole: .testPattern,
  width: 64,
  height: 48,
  pixelFormat: "bgra8",
  frameRate: VideoFrameRate(numerator: 30, denominator: 1),
  fingerprint: fingerprint
 )
}
@Test
func videoFrameReassemblerSerializesConcurrentFragmentReceive() async throws {
    let source = TestPatternCameraSource(width: 96, height: 72, frameIntervalNanoseconds: 1)
    let frame = try #require(source.nextFrame())
    let fragments = try RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 384)
    let reassembler = VideoFrameReassembler()
    var completedPackets: [VideoTransportPacket] = []
    try await withThrowingTaskGroup(of: VideoTransportPacket?.self) { group in
        for fragment in fragments {
            group.addTask {
                try reassembler.receive(fragment)
            }
        }
        for try await packet in group {
            if let packet {
                completedPackets.append(packet)
            }
        }
    }
    #expect(completedPackets == [RawVideoFrameTransport.packet(for: frame)])
    #expect(reassembler.metrics.framesReassembled == 1)
    #expect(reassembler.metrics.framesDroppedIncomplete == 0)
    #expect(reassembler.metrics.missingFragments == 0)
}

@Test
// swiftlint:disable:next function_body_length
func videoTransportFragmentDecodeAndEncodeRejectMalformedShapes() throws {
    let source = TestPatternCameraSource(width: 32, height: 24, frameIntervalNanoseconds: 1)
    let frame = try #require(source.nextFrame())
    let fragments = try RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 512)
    let fragment = try #require(fragments.first)
    var encoded = try fragment.encoded()
    encoded[0] = 0

    #expect(throws: VideoTransportFragmentError.invalidMagic) {
        _ = try VideoTransportFragment.decode(encoded)
    }

    var invalidIndex = fragment
    invalidIndex.fragmentIndex = invalidIndex.fragmentCount
    #expect(throws: VideoTransportFragmentError.invalidFragmentIndex(
        index: invalidIndex.fragmentCount,
        count: invalidIndex.fragmentCount
    )) {
        try invalidIndex.validate()
    }

    encoded = try fragment.encoded()
    let payloadStart = encoded.count - fragment.payload.count
    encoded[48] = 0
    encoded[49] = 0
    encoded[50] = 0
    encoded[51] = 0
    encoded.removeSubrange(payloadStart..<encoded.count)

    #expect(throws: VideoTransportFragmentError.emptyPayload) {
        _ = try VideoTransportFragment.decode(encoded)
    }

    encoded = try fragment.encoded()
    encoded[6] = 0xff
    encoded[7] = 0xff

    #expect(throws: VideoTransportFragmentError.payloadLengthMismatch(
        expected: VideoTransportFragment.fixedHeaderByteCount + 65_535
            + Int(encoded[12]) + (Int(encoded[13]) << 8)
            + Int(encoded[14]) + (Int(encoded[15]) << 8)
            + fragment.payload.count,
        actual: encoded.count
    )) {
        _ = try VideoTransportFragment.decode(encoded)
    }

    encoded = try fragment.encoded()

    for byteCount in 0..<VideoTransportFragment.fixedHeaderByteCount {
        #expect(throws: VideoTransportFragmentError.truncatedPacket(byteCount: byteCount)) {
            _ = try VideoTransportFragment.decode(encoded.prefix(byteCount))
        }
    }

    var emptyPayloadFragment = fragment
    emptyPayloadFragment.payload = Data()

    #expect(throws: VideoTransportFragmentError.encodingValidationFailed(
        field: "payload",
        reason: "emptyPayload"
    )) {
        _ = try emptyPayloadFragment.encoded()
    }
}

@Test
func latestVideoFrameReceiverDropsStalePackets() throws {
    let source = TestPatternCameraSource(width: 320, height: 240, frameIntervalNanoseconds: 1)
    var receiver = LatestVideoFrameReceiver(maxDepth: 1)

    receiver.receive(RawVideoFrameTransport.packet(for: try #require(source.nextFrame())))
    receiver.receive(RawVideoFrameTransport.packet(for: try #require(source.nextFrame())))
    receiver.receive(RawVideoFrameTransport.packet(for: try #require(source.nextFrame())))

    #expect(receiver.droppedFrames == 2)
    #expect(receiver.observedQueueDepth == 1)
    #expect(receiver.packets.map(\.sequenceNumber) == [2])
}

private func passCandidateReport() throws -> VideoTransportReport {
 var report = try loadJSONFixture(
  named: "video-transport-partial",
  fixtureDirectory: "VideoTransportReports",
  decode: VideoTransportReport.decode(from:)
 )
 report.verdict = .pass
 report.routeEvidence = passCandidateRouteEvidence()
 report.fragmentation = VideoFragmentationMetrics(
  framesFragmented: 3,
  fragmentsSent: 3,
  maxFragmentsPerFrame: 1,
  maxPayloadBytesPerFragment: 9_000
 )
 report.reassembly = VideoReassemblyMetrics(
  framesReassembled: 3,
  framesDroppedIncomplete: 0,
  missingFragments: 0,
  lateFragments: 0
 )
 report.renderOutput = passCandidateRenderOutput()
 report.blackmagicOutput = passCandidateBlackmagicOutput()
 report.degradation.triggeredBeforeAudioOrRouteImpact = true
 return report
}

private func passCandidateRouteEvidence() -> VideoTransportRouteEvidence {
 VideoTransportRouteEvidence(
  routeKind: .directWired,
  routeLabel: "m09-direct-wired-raw-baseline",
  packetCapturePoint: "receiver-en0",
  rawOrIntraFrameBaselineReportId: "m09-direct-wired-raw-pass",
  rawOrIntraFrameBaselineMode: .raw,
  baselineAudioRouteVerdict: .pass,
  videoActiveAudioRouteVerdict: .pass
 )
}

func passCandidateRenderOutput() -> VideoRenderOutputMetrics {
 VideoRenderOutputMetrics(
  configuration: .init(
   backend: .blackmagicDeckLink,
   pacingPolicy: .latestOnly
  ),
  frameDelivery: .init(
   framesSubmitted: 3,
   framesRendered: 3,
   framesOutput: 3,
   framesDroppedLate: 0,
   framesDroppedBackpressure: 0,
   framesDroppedContinuity: 0,
   observedQueueDepth: 1
  ),
  latency: .init(
   receiveToReassembly: UdpPcmPacketAgeMetrics(
    p50Microseconds: 100,
    p95Microseconds: 100,
    p99Microseconds: 100,
    maxMicroseconds: 100
   ),
   reassemblyToRender: UdpPcmPacketAgeMetrics(
    p50Microseconds: 100,
    p95Microseconds: 100,
    p99Microseconds: 100,
    maxMicroseconds: 100
   ),
   renderToOutput: UdpPcmPacketAgeMetrics(
    p50Microseconds: 100,
    p95Microseconds: 100,
    p99Microseconds: 100,
    maxMicroseconds: 100
   )
  )
 )
}

private func passCandidateBlackmagicOutput() -> BlackmagicOutputBoundaryReport {
 BlackmagicOutputBoundaryReport(
  backend: .blackmagicDeckLink,
  desktopVideoSDK: .linkedDeviceAvailable,
  compileTimeAvailable: true,
  runtimeAvailable: true,
  hardwareDetected: true,
  notes: "Synthetic pass-candidate Blackmagic output evidence for validation tests."
 )
}
