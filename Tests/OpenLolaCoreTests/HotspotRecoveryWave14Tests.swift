// Covers Wave 14's deterministic media helpers without touching HAL, sockets, or processes.
import CoreAudio
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func wave14GeneratedRawVideoUsesByteRampForNonMonoFormats() throws {
    let payload = try LoLaVideoPayloadProvider.generatedRawVideoPayload(
        configuration: wave14VideoConfiguration(bitsPerPixel: 24), sequenceNumber: 254
    )

    #expect(payload.count == 192)
    #expect(Array(payload.prefix(5)) == [254, 255, 0, 1, 2])
    #expect(payload.last == 189)
}

@Test
func wave14GeneratedMonoVideoDrawsBarsCenterAndTickBits() throws {
    let payload = try LoLaVideoPayloadProvider.generatedRawVideoPayload(
        configuration: wave14VideoConfiguration(bitsPerPixel: 8, width: 80, height: 32), sequenceNumber: 1
    )
    let width = 80

    #expect(payload.count == 2_560)
    #expect(payload[16 * width + 40] == 255)
    #expect(payload[0 * width + 0] == 220)
    #expect(payload[14 * width + 2] == 255)
}

@Test
func wave14GeneratedMonoVideoMovesDiagnosticRegionAndTickPattern() throws {
    let configuration = wave14VideoConfiguration(bitsPerPixel: 8, width: 80, height: 32)
    let first = try LoLaVideoPayloadProvider.generatedRawVideoPayload(configuration: configuration, sequenceNumber: 0)
    let later = try LoLaVideoPayloadProvider.generatedRawVideoPayload(configuration: configuration, sequenceNumber: 5)

    #expect(first != later)
    #expect(first[14 * 80 + 2] == 40)
    #expect(later[14 * 80 + 2] == 255)
    #expect(first[2] == 220)
    #expect(later[2] != 220)
}

@Test
func wave14GeneratedPayloadsRejectNonPositiveFrameCount() {
    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger("frameCount", "0")) {
        _ = try LoLaVideoPayloadProvider.payloads(
            configuration: wave14VideoConfiguration(bitsPerPixel: 8), frameCount: 0
        )
    }
}

#if canImport(CoreGraphics) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
@Test
func wave14JpegStripperPreservesStandaloneMarkersAndJfif() {
    let jpeg = Data([
        0xff, 0xd8, 0xff, 0xff, 0xe0, 0x00, 0x07, 0x4a, 0x46, 0x49, 0x46, 0x00,
        0xff, 0xdb, 0x00, 0x04, 0x00, 0x11, 0xff, 0xda, 0x00, 0x04, 0x03, 0x00, 0x44, 0xff, 0xd9,
    ])
    let stripped = LoLaMjpegJPEGEncoder.stripNonJfifMetadata(from: jpeg)

    #expect(stripped == Data([
        0xff, 0xd8, 0xff, 0xe0, 0x00, 0x07, 0x4a, 0x46, 0x49, 0x46, 0x00,
        0xff, 0xdb, 0x00, 0x04, 0x00, 0x11, 0xff, 0xda, 0x00, 0x04, 0x03, 0x00, 0x44, 0xff, 0xd9,
    ]))
}

@Test
func wave14JpegStripperDropsEveryAppAndCommentMarker() {
    let jpeg = Data([
        0xff, 0xd8,
        0xff, 0xe1, 0x00, 0x04, 0x41, 0x42,
        0xff, 0xe2, 0x00, 0x04, 0x43, 0x44,
        0xff, 0xed, 0x00, 0x04, 0x45, 0x46,
        0xff, 0xfe, 0x00, 0x04, 0x47, 0x48,
        0xff, 0xc4, 0x00, 0x04, 0x01, 0x02,
        0xff, 0xda, 0x00, 0x04, 0x03, 0x00, 0x7a, 0xff, 0xd9,
    ])
    let stripped = LoLaMjpegJPEGEncoder.stripNonJfifMetadata(from: jpeg)

    #expect(!stripped.contains(Data([0xff, 0xe1])))
    #expect(!stripped.contains(Data([0xff, 0xe2])))
    #expect(!stripped.contains(Data([0xff, 0xed])))
    #expect(!stripped.contains(Data([0xff, 0xfe])))
    #expect(stripped.contains(Data([0xff, 0xc4, 0x00, 0x04, 0x01, 0x02])))
    #expect(stripped.suffix(3) == Data([0x7a, 0xff, 0xd9]))
}

@Test
func wave14JpegStripperReturnsOriginalWhenScannerEndsBeforeSegment() {
    let jpeg = Data([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x20, 0x4a])

    #expect(LoLaMjpegJPEGEncoder.stripNonJfifMetadata(from: jpeg) == jpeg)
}
#endif

@Test
func wave14AudioBufferReaderExposesOwnedBuffersAndRejectsBounds() {
    let fixture = Wave14AudioBufferFixture(buffers: [(.init([1, 2, 3, 4]), 2, nil)])
    let reader = fixture.reader

    #expect(reader.count == 1)
    #expect(reader[0]?.mNumberChannels == 2)
    #expect(reader[0]?.mDataByteSize == 4)
    #expect(reader[-1] == nil)
    #expect(reader[1] == nil)
}

@Test
func wave14CaptureRingPushesSingleInterleavedOwnedBufferDirectly() throws {
    var ring = wave14Ring(capacity: 2, map: [0, 1])
    let fixture = Wave14AudioBufferFixture(buffers: [(.init([1, 0, 2, 0, 3, 0, 4, 0]), 2, nil)])

    let result = ring.pushAudioBuffers(startFrame: 11, hostTimeNanoseconds: 12, inputBuffers: fixture.reader)
    guard let payload = ring.pop() else {
        Issue.record("expected captured payload")
        return
    }

    #expect(result.result == .stored)
    #expect(result.copyKind == .direct)
    #expect(payload.block.startFrame == 11)
    #expect(payload.payload == Data([1, 0, 2, 0, 3, 0, 4, 0]))
}

@Test
func wave14CaptureRingRemapsOwnedPlanarBuffers() throws {
    var ring = wave14Ring(capacity: 2, map: [1, 0])
    let fixture = Wave14AudioBufferFixture(buffers: [
        (.init([1, 0, 2, 0]), 1, nil),
        (.init([3, 0, 4, 0]), 1, nil),
    ])

    let result = ring.pushAudioBuffers(startFrame: 21, hostTimeNanoseconds: 22, inputBuffers: fixture.reader)
    guard let payload = ring.pop() else {
        Issue.record("expected captured payload")
        return
    }

    #expect(result.result == .stored)
    #expect(result.copyKind == .remapped)
    #expect(payload.payload == Data([3, 0, 1, 0, 4, 0, 2, 0]))
}

@Test
func wave14CaptureRingRejectsEmptyAndNilOwnedAudioLists() {
    var ring = wave14Ring(capacity: 2, map: [0, 1])
    let empty = Wave14AudioBufferFixture(buffers: [])
    let nilData = Wave14AudioBufferFixture(buffers: [(.init([]), 2, 8)])

    #expect(ring.pushAudioBuffers(startFrame: 1, hostTimeNanoseconds: 1, inputBuffers: empty.reader).result == .droppedInvalid)
    #expect(ring.pushAudioBuffers(startFrame: 2, hostTimeNanoseconds: 2, inputBuffers: nilData.reader).result == .droppedInvalid)
    #expect(ring.count == 0)
}

@Test
func wave14CaptureRingRejectsUndersizedPlanarOwnedBuffer() {
    var ring = wave14Ring(capacity: 2, map: [0, 1])
    let fixture = Wave14AudioBufferFixture(buffers: [
        (.init([1, 0, 2, 0]), 1, nil),
        (.init([3, 0]), 1, nil),
    ])

    let result = ring.pushAudioBuffers(startFrame: 1, hostTimeNanoseconds: 2, inputBuffers: fixture.reader)

    #expect(result.result == .droppedInvalid)
    #expect(result.copyKind == .invalid)
    #expect(ring.count == 0)
}

@Test
func wave14CaptureRingPopPayloadAndClosureDrainReusableSlots() throws {
    var ring = wave14Ring(capacity: 1, map: [0, 1])
    #expect(ring.pushSilence(startFrame: 7, hostTimeNanoseconds: 8).copyKind == .silent)
    var destination = Data([9])
    guard let block = ring.popPayload(into: &destination) else {
        Issue.record("expected captured block")
        return
    }

    #expect(block.startFrame == 7)
    #expect(destination == Data(repeating: 0, count: 8))
    #expect(ring.withPoppedPayload { _, bytes in bytes.count } == nil)
    #expect(ring.pushSilence(startFrame: 9, hostTimeNanoseconds: 10).result == .stored)
    let byteCount = try #require(ring.withPoppedPayload { block, bytes in
        #expect(block.startFrame == 9)
        return bytes.count
    })
    #expect(byteCount == 8)
}

@Test
func wave14CaptureRingReportsFullAfterOwnedInput() {
    var ring = wave14Ring(capacity: 1, map: [0, 1])
    let fixture = Wave14AudioBufferFixture(buffers: [(.init([1, 0, 2, 0, 3, 0, 4, 0]), 2, nil)])

    #expect(ring.pushAudioBuffers(startFrame: 1, hostTimeNanoseconds: 1, inputBuffers: fixture.reader).result == .stored)
    #expect(ring.pushAudioBuffers(startFrame: 2, hostTimeNanoseconds: 2, inputBuffers: fixture.reader).result == .droppedFull)
    #expect(ring.droppedBlocks == 1)
}

@Test
func wave14LoopbackParsersAcceptAliasesAndFallbackPolicies() throws {
    #expect(try parseAudioLoopbackSampleFormat(nil) == .int16LittleEndian)
    #expect(try parseAudioLoopbackSampleFormat("FLOAT32-LE") == .float32LittleEndian)
    #expect(try parseBool("on", argument: "--dry-run"))
    #expect(!(try parseBool("0", argument: "--dry-run")))
    #expect(try parseLatencyProfile(nil, framesPerBuffer: 64) == .safeLowLatency)
    #expect(try parseRxBufferProfile(nil) == nil)
}

@Test
func wave14LoopbackParsersRejectInvalidPolicyInputs() {
    #expect(throws: AudioLoopbackRunConfigurationError.invalidSampleFormat("pcm24")) {
        _ = try parseAudioLoopbackSampleFormat("pcm24")
    }
    #expect(throws: AudioLoopbackRunConfigurationError.invalidBool(argument: "--dry-run", value: "maybe")) {
        _ = try parseBool("maybe", argument: "--dry-run")
    }
    #expect(throws: AudioLoopbackRunConfigurationError.invalidRxBufferProfile("wide")) {
        _ = try parseRxBufferProfile("wide")
    }
}

@Test
func wave14LoopbackPoliciesCoverSyntheticRangeAndPercentileEdges() {
    let device = wave14AudioDevice()

    #expect(supportsSampleRate(device, 44_100))
    #expect(!supportsSampleRate(device, 96_000))
    #expect(supportsFrameSize(device, 64))
    #expect(!supportsFrameSize(device, 513))
    #expect(channelMapFits([0, 1], available: 2))
    #expect(!channelMapFits([], available: 2))
    #expect(percentile([1, 3, 9], 0.5) == 3)
}

@Test
func wave14VideoMetricDeltaClampsAndMergesIntoBothTargets() {
    let delta = directPeerVideoReassemblyMetricDelta(
        before: .init(framesReassembled: 0, framesDroppedIncomplete: 4, missingFragments: 4, lateFragments: 4, duplicateFragments: 4, activeFramesPeak: 0),
        after: .init(framesReassembled: 0, framesDroppedIncomplete: 2, missingFragments: 6, lateFragments: 3, duplicateFragments: 8, activeFramesPeak: 0)
    )
    var drain = DirectPeerVideoRXDrainResult()
    var runtime = DirectPeerSessionAVRuntimeMetrics()

    mergeDirectPeerVideoReassemblyMetricDelta(delta, into: &drain)
    mergeDirectPeerVideoReassemblyMetricDelta(delta, into: &runtime)

    #expect(delta == .init(framesDroppedIncomplete: 0, missingFragments: 2, lateFragments: 0, duplicateFragments: 4))
    #expect(drain.reassemblyMissingFragments == 2)
    #expect(drain.reassemblyDuplicateFragments == 4)
    #expect(runtime.videoReassemblyMissingFragments == 2)
    #expect(runtime.videoReassemblyDuplicateFragments == 4)
}

@Test
func wave14DeferredRawVideoReplacementAndShutdownAreCounted() {
    var deferred: RawCapturedVideoFrame?
    var drain = DirectPeerVideoRXDrainResult()
    let first = wave14RawFrame(sequence: 1, timestamp: 1)
    let second = wave14RawFrame(sequence: 2, timestamp: 2)

    deferVideoFrameForSync(first, deferredFrame: &deferred, result: &drain)
    deferVideoFrameForSync(second, deferredFrame: &deferred, result: &drain)
    var runtime = DirectPeerSessionAVRuntimeMetrics()
    dropDeferredVideoFrameAtShutdown(&deferred, metrics: &runtime)

    #expect(drain.framesReplacedDuringSyncDefer == 1)
    #expect(drain.framesDroppedForSync == 1)
    #expect(runtime.videoFramesDroppedForSync == 1)
    #expect(deferred == nil)
}

@Test
func wave14VideoSyncWaitsForAudioThenClassifiesEarlyAndStaleFrames() {
    var anchor = DirectPeerAVPlayoutAnchor(policy: .policy(for: .balancedAV))
    #expect(anchor.decision(forVideoTimestampNanoseconds: 1) == nil)
    anchor.observeAudio(hostTimeNanoseconds: 100_000_000)

    #expect(anchor.decision(forVideoTimestampNanoseconds: 130_000_000)?.action == .deferVideo)
    #expect(anchor.decision(forVideoTimestampNanoseconds: 50_000_000)?.action == .dropVideo)
    #expect(anchor.decision(forVideoTimestampNanoseconds: 100_000_000)?.action == .renderNow)
}

@Test
func wave14PeerMediaBudgetUsesSafeNoTransportDefault() {
    #expect(peerSessionMediaReceiveByteBudget(acceptedConfiguration: nil) == peerSessionDefaultMediaReceiveByteBudget)
}

@Test
func wave14ResamplerMaintainsInMemoryInterpolationAndReset() {
    let resampler = LoLaLinearPCMResampler(inputRate: 4, outputRate: 8, channels: 1)

    #expect(resampler.appendAndProduce([0]).isEmpty)
    let output = resampler.appendAndProduce([1, 0])
    #expect(output.prefix(3) == [0, 0.5, 1])
    resampler.reset()
    #expect(resampler.appendAndProduce([0, 1]).prefix(2) == [0, 0.5])
}

@Test
func wave14PcmConversionsClampAndIgnoreOddTrailingByte() {
    let encoded = int16LittleEndianData(fromInterleavedFloat: [-2, -1, 0, 1, 2])
    let decoded = interleavedFloatData(fromInt16LittleEndian: encoded + Data([0xff]))

    #expect(decoded.count == 5)
    #expect(decoded[0] < -0.99)
    #expect(abs(decoded[2]) < 0.001)
    #expect(decoded[3] > 0.99)
}

private func wave14VideoConfiguration(
    bitsPerPixel: Int,
    width: Int = 8,
    height: Int = 8
) -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
        connector: .lola, role: .tx, peer: "192.0.2.14", outputPath: "/tmp/wave14-video.json"
    ) { input in
        input.mediaMode = .video
        input.videoWidth = width
        input.videoHeight = height
        input.videoBitsPerPixel = bitsPerPixel
    })
}

private func wave14Ring(capacity: Int, map: [Int]) -> RealtimeAudioPayloadCaptureRing {
    RealtimeAudioPayloadCaptureRing(
        capacity: capacity,
        shape: try! RealtimeAudioPayloadShape(frameCount: 2, channelCount: 2, sampleFormat: .int16LittleEndian),
        inputChannelMap: map
    )
}

private func wave14AudioDevice() -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
        identity: .init(id: 14, name: "wave14", uid: "wave14", isAggregate: false),
        streams: .init(inputChannelCount: 2, outputChannelCount: 2, inputStreamCount: 1, outputStreamCount: 1),
        sampleRates: .init(availableSampleRateRanges: [.init(minimum: 44_100, maximum: 48_000)]),
        buffering: .init(bufferFrameSizeRange: .init(minimum: 32, maximum: 512), candidateBufferFrames: .init(inReportedRange: [64], outsideReportedRange: [], note: "wave14")),
        timing: .init(), diagnosticNotes: []
    )
}

private func wave14RawFrame(sequence: UInt64, timestamp: UInt64) -> RawCapturedVideoFrame {
    RawCapturedVideoFrame(
        metadata: .init(streamID: 1, sequenceNumber: sequence, timestampNanoseconds: timestamp,
                        timestampBasis: .hostUptimeNanoseconds, sourceRole: .avFoundationDevice,
                        width: 1, height: 1, pixelFormat: "bgra8",
                        frameRate: .init(numerator: 30, denominator: 1), fingerprint: "wave14-\(sequence)"),
        payload: Data([0, 0, 0, 0])
    )
}

private final class Wave14AudioBufferFixture {
    typealias Buffer = (bytes: [UInt8], channels: UInt32, declaredSize: UInt32?)

    let list: UnsafeMutableAudioBufferListPointer
    private let storage: [UnsafeMutableRawPointer]

    init(buffers: [Buffer]) {
        list = AudioBufferList.allocate(maximumBuffers: max(1, buffers.count))
        list.unsafeMutablePointer.pointee.mNumberBuffers = UInt32(buffers.count)
        storage = buffers.map { buffer in
            let pointer = UnsafeMutableRawPointer.allocate(byteCount: max(1, buffer.bytes.count), alignment: 1)
            if !buffer.bytes.isEmpty {
                buffer.bytes.withUnsafeBytes { pointer.copyMemory(from: $0.baseAddress!, byteCount: buffer.bytes.count) }
            }
            return pointer
        }
        for (index, buffer) in buffers.enumerated() {
            list[index] = AudioBuffer(
                mNumberChannels: buffer.channels,
                mDataByteSize: buffer.declaredSize ?? UInt32(buffer.bytes.count),
                mData: buffer.declaredSize == nil ? storage[index] : nil
            )
        }
    }

    deinit {
        storage.forEach { $0.deallocate() }
        list.unsafeMutablePointer.deallocate()
    }

    var reader: RealtimeAudioBufferListReader {
        RealtimeAudioBufferListReader(UnsafePointer(list.unsafeMutablePointer))
    }
}
