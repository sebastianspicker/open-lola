import Foundation
import Testing

@testable import OpenLolaCore

@Test
func videoTransportReportFixtureDecodesAndValidates() throws {
    let report = try loadVideoTransportFixture(named: "video-transport-partial")

    try report.validate()

    #expect(report.transport.mode == .raw)
    #expect(report.verdict == .partial)
    #expect(report.receiver.droppedFrames == 2)
    #expect(report.degradation.actions == [.dropFrame, .disableVideo])
    #expect(report.avSync?.audioTimestampOrigin == .audioPacketSenderHostTimeNanoseconds)
    #expect(report.avSync?.videoTimestampOrigin == .videoPacketTimestampNanoseconds)
}

@Test
func rawVideoTransportEncodesDeterministicPacket() throws {
    let source = TestPatternCameraSource(width: 640, height: 480, frameIntervalNanoseconds: 1)
    let frame = try #require(source.nextFrame())
    let packet = RawVideoFrameTransport.packet(for: frame)

    #expect(packet.sequenceNumber == 0)
    #expect(packet.timestampNanoseconds == 0)
    #expect(packet.payloadByteCount == 921_600)
    #expect(packet.frameFingerprint == "test-pattern-0-640x480")
}

@Test
func rawVideoTransportFragmentsFitMaxPacketBytes() throws {
    let source = TestPatternCameraSource(width: 640, height: 480, frameIntervalNanoseconds: 1)
    let frame = try #require(source.nextFrame())

    let fragments = try RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 1_200)

    #expect(!fragments.isEmpty)
    #expect(fragments.allSatisfy { $0.encodedByteCount <= 1_200 })
    #expect(fragments.first?.fragmentIndex == 0)
    #expect((fragments.last?.payloadOffset ?? 0) + (fragments.last?.payloadByteCount ?? 0) == 921_600)
    #expect(Set(fragments.map(\.fragmentIndex)).count == fragments.count)
}

@Test
func videoTransportFragmentEncodedByteCountMirrorsEncodedAppendSequence() throws {
    let source = TestPatternCameraSource(width: 64, height: 48, frameIntervalNanoseconds: 1)
    let frame = try #require(source.nextFrame())
    let fragment = try #require(RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 512).first)
    let transportSource = try readRepositoryText("Sources/OpenLolaCore/Video/VideoTransportPacket.swift")

    #expect(try fragment.encoded().count == fragment.encodedByteCount)
    #expect(transportSource.contains("assert(data.count == encodedByteCount"))
}

@Test
func videoTransportFormatOwnsFragmentWireConstants() throws {
    let transportSource = try readRepositoryText("Sources/OpenLolaCore/Video/VideoTransportPacket.swift")
    let formatSource = try readRepositoryText("Sources/OpenLolaCore/Video/VideoStreamDescription.swift")

    #expect(formatSource.contains("public enum VideoTransportFormat"))
    #expect(formatSource.contains("public static let magic = [UInt8](\"OLVF\".utf8)"))
    #expect(formatSource.contains("public static let fixedHeaderByteCount = 72"))
    #expect(formatSource.contains("public static let headerGuardOffset = 68"))
    #expect(transportSource.contains("data.append(contentsOf: VideoTransportFormat.magic)"))
    #expect(transportSource.contains("VideoTransportFormat.fixedHeaderByteCount"))
    #expect(transportSource.contains("VideoTransportFormat.headerGuardOffset"))
}

@Test
func videoFrameReassemblerCompletesOutOfOrderFrame() throws {
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
}

@Test
func videoFrameReassemblerHandlesDuplicateFragmentsIdempotently() throws {
    let source = TestPatternCameraSource(width: 64, height: 48, frameIntervalNanoseconds: 1)
    let frame = try #require(source.nextFrame())
    let fragments = try RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 512)
    let reassembler = VideoFrameReassembler()
    var completed: VideoTransportPacket?

    for fragment in fragments {
        completed = try reassembler.receive(fragment) ?? completed
        completed = try reassembler.receive(fragment) ?? completed
    }

    #expect(completed == RawVideoFrameTransport.packet(for: frame))
    #expect(reassembler.metrics.framesReassembled == 1)
    #expect(reassembler.metrics.duplicateFragments == fragments.count - 1)
}

@Test
func videoFrameReassemblerStoresFirstFragmentOnlyOnceOnNewBucket() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Video/VideoTransportReassembly.swift")

    #expect(source.contains("fragmentsByIndex = [firstFragment.fragmentIndex: firstFragment]"))
    #expect(!source.contains("_ = try bucket.insert(fragment)"))
}

@Test
func videoFrameReassemblerEvictsSameSequenceStaleBucketsWhenOpeningNewFrame() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Video/VideoTransportReassembly.swift")

    #expect(source.contains("videoFrameSequenceIsLate(key.frameSequenceNumber, after: frameSequenceNumber)"))
    #expect(!source.contains("key.frameSequenceNumber < frameSequenceNumber"))
    #expect(!source.contains("key.frameSequenceNumber <= frameSequenceNumber"))
}

@Test
func videoFrameReassemblerCompactsActiveFrameOrderBeforeLargeStaleRun() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Video/VideoTransportReassembly.swift")

    #expect(source.contains("activeFrameOrderCursor > 32"))
    #expect(source.contains("activeFrameOrderCursor > activeFrameOrder.count / 2"))
    #expect(!source.contains("activeFrameOrderCursor > 64"))
    #expect(!source.contains("activeFrameOrderCursor * 2 > activeFrameOrder.count"))
}

@Test
func videoFrameReassemblerRemovesCompletedFramesFromActiveOrder() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Video/VideoTransportReassembly.swift")

    #expect(source.contains("removeActiveFrameOrderKey(key)"))
    #expect(source.contains("private func removeActiveFrameOrderKey(_ key: VideoFrameReassemblyKey)"))
    #expect(source.contains("activeFrameOrder.removeAll { $0 == key }"))
}

@Test
func videoFrameReassemblerAliasesShareOneReassemblyState() throws {
    let source = TestPatternCameraSource(width: 64, height: 48, frameIntervalNanoseconds: 1)
    let frame = try #require(source.nextFrame())
    let fragments = try RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 512)
    let reassembler = VideoFrameReassembler()
    let alias = reassembler
    var completed: VideoTransportPacket?

    for fragment in fragments.prefix(fragments.count / 2) {
        completed = try reassembler.receive(fragment) ?? completed
    }
    for fragment in fragments.dropFirst(fragments.count / 2) {
        completed = try alias.receive(fragment) ?? completed
    }

    #expect(completed == RawVideoFrameTransport.packet(for: frame))
    #expect(reassembler == alias)
    #expect(reassembler.metrics.framesReassembled == 1)
    #expect(alias.metrics.framesReassembled == 1)
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
func videoFrameReassemblerDropsExpiredIncompleteFrames() throws {
    let source = TestPatternCameraSource(width: 64, height: 48, frameIntervalNanoseconds: 1)
    let firstFrame = try #require(source.nextFrame())
    let secondFrame = try #require(source.nextFrame())
    let firstFragments = try RawVideoFrameTransport.fragments(for: firstFrame, maxPacketBytes: 512)
    let secondFragments = try RawVideoFrameTransport.fragments(for: secondFrame, maxPacketBytes: 512)
    let firstFragment = try #require(firstFragments.first)
    let secondFragment = try #require(secondFragments.first)
    let reassembler = VideoFrameReassembler(maxActiveFrames: 4, maxFrameAgeNanoseconds: 0)

    #expect(try reassembler.receive(firstFragment) == nil)
    #expect(try reassembler.receive(secondFragment) == nil)

    #expect(reassembler.metrics.framesDroppedIncomplete == 1)
    #expect(reassembler.metrics.missingFragments == firstFragment.fragmentCount - 1)
}

@Test
func videoFrameReassemblerRejectsOversizedFragmentSet() throws {
    let source = TestPatternCameraSource(width: 64, height: 48, frameIntervalNanoseconds: 1)
    let frame = try #require(source.nextFrame())
    let fragments = try RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 512)
    var fragment = try #require(fragments.first)
    fragment.fragmentCount = 9
    let reassembler = VideoFrameReassembler(maxFragmentsPerFrame: 8)

    #expect(throws: VideoTransportFragmentError.invalidFragmentCount(9)) {
        _ = try reassembler.receive(fragment)
    }
}

@Test
func videoFrameReassemblerDropsOldestActiveFrameAtCapacity() throws {
    let firstFrame = CapturedVideoFrame(
        streamID: 1,
        sequenceNumber: 1,
        timestampNanoseconds: 1,
        timestampBasis: .hostUptimeNanoseconds,
        sourceRole: .testPattern,
        width: 64,
        height: 48,
        pixelFormat: "bgra8",
        frameRate: VideoFrameRate(numerator: 30, denominator: 1),
        fingerprint: "capacity-1"
    )
    let secondFrame = CapturedVideoFrame(
        streamID: 2,
        sequenceNumber: 1,
        timestampNanoseconds: 2,
        timestampBasis: .hostUptimeNanoseconds,
        sourceRole: .testPattern,
        width: 64,
        height: 48,
        pixelFormat: "bgra8",
        frameRate: VideoFrameRate(numerator: 30, denominator: 1),
        fingerprint: "capacity-2"
    )
    let firstFragments = try RawVideoFrameTransport.fragments(for: firstFrame, maxPacketBytes: 512)
    let secondFragments = try RawVideoFrameTransport.fragments(for: secondFrame, maxPacketBytes: 512)
    let firstFragment = try #require(firstFragments.first)
    let secondFragment = try #require(secondFragments.first)
    let reassembler = VideoFrameReassembler(maxActiveFrames: 1)

    #expect(try reassembler.receive(firstFragment) == nil)
    #expect(try reassembler.receive(secondFragment) == nil)

    #expect(reassembler.metrics.framesDroppedIncomplete == 1)
    #expect(reassembler.metrics.missingFragments == firstFragment.fragmentCount - 1)
    #expect(reassembler.metrics.activeFramesPeak == 1)
}

@Test
func videoFrameReassemblerDropsIncompleteFrameWhenNewerFrameArrives() throws {
    let source = TestPatternCameraSource(width: 64, height: 48, frameIntervalNanoseconds: 1)
    let firstFrame = try #require(source.nextFrame())
    let secondFrame = try #require(source.nextFrame())
    let firstFragments = try RawVideoFrameTransport.fragments(for: firstFrame, maxPacketBytes: 512)
    let secondFragments = try RawVideoFrameTransport.fragments(for: secondFrame, maxPacketBytes: 512)
    let reassembler = VideoFrameReassembler()

    let firstFragment = try #require(firstFragments.first)
    #expect(try reassembler.receive(firstFragment) == nil)
    for fragment in secondFragments {
        _ = try reassembler.receive(fragment)
    }
    #expect(try reassembler.receive(firstFragments[1]) == nil)

    #expect(reassembler.metrics.framesReassembled == 1)
    #expect(reassembler.metrics.framesDroppedIncomplete == 1)
    #expect(reassembler.metrics.missingFragments == firstFragments.count - 1)
    #expect(reassembler.metrics.lateFragments == 1)
}

@Test
func videoFrameReassemblerAcceptsWrappedSequenceAfterUInt64Max() throws {
    let firstFrame = CapturedVideoFrame(
        streamID: 7,
        sequenceNumber: UInt64.max,
        timestampNanoseconds: 1,
        timestampBasis: .hostUptimeNanoseconds,
        sourceRole: .testPattern,
        width: 32,
        height: 24,
        pixelFormat: "bgra8",
        frameRate: VideoFrameRate(numerator: 30, denominator: 1),
        fingerprint: "wrap-max"
    )
    let wrappedFrame = CapturedVideoFrame(
        streamID: 7,
        sequenceNumber: 0,
        timestampNanoseconds: 2,
        timestampBasis: .hostUptimeNanoseconds,
        sourceRole: .testPattern,
        width: 32,
        height: 24,
        pixelFormat: "bgra8",
        frameRate: VideoFrameRate(numerator: 30, denominator: 1),
        fingerprint: "wrap-zero"
    )
    let firstFragment = try #require(RawVideoFrameTransport.fragments(for: firstFrame, maxPacketBytes: 4_096).first)
    let wrappedFragment = try #require(RawVideoFrameTransport.fragments(for: wrappedFrame, maxPacketBytes: 4_096).first)
    let reassembler = VideoFrameReassembler()

    #expect(try reassembler.receive(firstFragment) == RawVideoFrameTransport.packet(for: firstFrame))
    #expect(try reassembler.receive(wrappedFragment) == RawVideoFrameTransport.packet(for: wrappedFrame))
    #expect(reassembler.metrics.framesReassembled == 2)
    #expect(reassembler.metrics.lateFragments == 0)
}

@Test
func videoFrameReassemblerUsesWrapAwareOrderingForActiveIncompleteFrames() throws {
    let firstFrame = RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: 7,
            sequenceNumber: UInt64.max,
            timestampNanoseconds: 1,
            timestampBasis: .hostUptimeNanoseconds,
            sourceRole: .testPattern,
            width: 32,
            height: 24,
            pixelFormat: "bgra8",
            frameRate: VideoFrameRate(numerator: 30, denominator: 1),
            fingerprint: "wrap-max-incomplete"
        ),
        payload: Data(repeating: 0x11, count: 512)
    )
    let wrappedFrame = RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: 7,
            sequenceNumber: 0,
            timestampNanoseconds: 2,
            timestampBasis: .hostUptimeNanoseconds,
            sourceRole: .testPattern,
            width: 32,
            height: 24,
            pixelFormat: "bgra8",
            frameRate: VideoFrameRate(numerator: 30, denominator: 1),
            fingerprint: "wrap-zero-complete"
        ),
        payload: Data(repeating: 0x22, count: 512)
    )
    let firstFragments = try RawVideoFrameTransport.fragments(for: firstFrame, maxPacketBytes: 160)
    let wrappedFragments = try RawVideoFrameTransport.fragments(for: wrappedFrame, maxPacketBytes: 160)
    let reassembler = VideoFrameReassembler()

    #expect(firstFragments.count > 1)
    #expect(try reassembler.receiveRaw(try #require(firstFragments.first)) == nil)
    var completed: RawCapturedVideoFrame?
    for fragment in wrappedFragments {
        completed = try reassembler.receiveRaw(fragment) ?? completed
    }

    #expect(completed == wrappedFrame)
    #expect(reassembler.metrics.framesDroppedIncomplete == 1)
    #expect(reassembler.metrics.lateFragments == 0)
}

@Test
func videoFrameReassemblerRejectsCorruptFragmentMetadata() throws {
    let source = TestPatternCameraSource(width: 64, height: 48, frameIntervalNanoseconds: 1)
    let frame = try #require(source.nextFrame())
    let fragments = try RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 512)
    let reassembler = VideoFrameReassembler()
    var corruptSecondFragment = fragments[1]
    corruptSecondFragment.width += 1

    #expect(try reassembler.receive(fragments[0]) == nil)
    #expect(throws: VideoTransportFragmentError.inconsistentFrameMetadata) {
        _ = try reassembler.receive(corruptSecondFragment)
    }
    #expect(reassembler.metrics.framesReassembled == 0)
}

@Test
func videoTransportFragmentDecodeRejectsMalformedFragment() throws {
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
}

@Test
func videoTransportFragmentDecodeRejectsEveryTruncatedHeaderBoundary() throws {
    let source = TestPatternCameraSource(width: 32, height: 24, frameIntervalNanoseconds: 1)
    let frame = try #require(source.nextFrame())
    let fragments = try RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 512)
    let fragment = try #require(fragments.first)
    let encoded = try fragment.encoded()

    for byteCount in 0..<VideoTransportFragment.fixedHeaderByteCount {
        #expect(throws: VideoTransportFragmentError.truncatedPacket(byteCount: byteCount)) {
            _ = try VideoTransportFragment.decode(encoded.prefix(byteCount))
        }
    }
}

@Test
func videoTransportFragmentDecodeRejectsEmptyPayloadWithoutCrash() throws {
    let source = TestPatternCameraSource(width: 32, height: 24, frameIntervalNanoseconds: 1)
    let frame = try #require(source.nextFrame())
    let fragments = try RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 512)
    let fragment = try #require(fragments.first)
    var encoded = try fragment.encoded()
    let payloadStart = encoded.count - fragment.payload.count
    encoded[48] = 0
    encoded[49] = 0
    encoded[50] = 0
    encoded[51] = 0
    encoded.removeSubrange(payloadStart..<encoded.count)

    #expect(throws: VideoTransportFragmentError.emptyPayload) {
        _ = try VideoTransportFragment.decode(encoded)
    }
}

@Test
func videoTransportFragmentDecodeRejectsOversizedMetadataBeforeRangeSlicing() throws {
    let source = TestPatternCameraSource(width: 32, height: 24, frameIntervalNanoseconds: 1)
    let frame = try #require(source.nextFrame())
    let fragments = try RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 512)
    let fragment = try #require(fragments.first)
    var encoded = try fragment.encoded()
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
}

@Test
func videoTransportPercentileInterpolatesBetweenSamples() {
    #expect(videoTransportPercentile([0, 100], rank: 0.50) == 50)
    #expect(abs(videoTransportPercentile([0, 10, 20, 30], rank: 0.95) - 28.5) < 0.000_001)
}

@Test
func videoTransportFragmentEncodingFailureCarriesFieldContext() throws {
    let source = TestPatternCameraSource(width: 32, height: 24, frameIntervalNanoseconds: 1)
    let frame = try #require(source.nextFrame())
    var fragment = try #require(RawVideoFrameTransport.fragments(for: frame, maxPacketBytes: 512).first)
    fragment.payload = Data()

    #expect(throws: VideoTransportFragmentError.encodingValidationFailed(
        field: "payload",
        reason: "emptyPayload"
    )) {
        _ = try fragment.encoded()
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
    var report = try loadVideoTransportFixture(named: "video-transport-partial")
    report.verdict = .pass
    report.routeEvidence = VideoTransportRouteEvidence(
        routeKind: .directWired,
        routeLabel: "m09-direct-wired-raw-baseline",
        packetCapturePoint: "receiver-en0",
        rawOrIntraFrameBaselineReportId: "m09-direct-wired-raw-pass",
        rawOrIntraFrameBaselineMode: .raw,
        baselineAudioRouteVerdict: .pass,
        videoActiveAudioRouteVerdict: .pass
    )
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
    report.renderOutput = VideoRenderOutputMetrics(
        backend: .blackmagicDeckLink,
        pacingPolicy: .latestOnly,
        framesSubmitted: 3,
        framesRendered: 3,
        framesOutput: 3,
        framesDroppedLate: 0,
        framesDroppedBackpressure: 0,
        framesDroppedContinuity: 0,
        observedQueueDepth: 1,
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
    report.blackmagicOutput = BlackmagicOutputBoundaryReport(
        backend: .blackmagicDeckLink,
        desktopVideoSDK: .linkedDeviceAvailable,
        compileTimeAvailable: true,
        runtimeAvailable: true,
        hardwareDetected: true,
        notes: "Synthetic pass-candidate Blackmagic output evidence for validation tests."
    )
    report.degradation.triggeredBeforeAudioOrRouteImpact = true
    return report
}

private func loadVideoTransportFixture(named name: String) throws -> VideoTransportReport {
    let url = try videoTransportFixtureURL(named: name)
    return try VideoTransportReport.decode(from: Data(contentsOf: url))
}

private func videoTransportFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "VideoTransportReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "VideoTransportReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}

private func readRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
