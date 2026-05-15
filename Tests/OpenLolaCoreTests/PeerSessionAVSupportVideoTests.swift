import CoreGraphics
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerRealtimeAudioPreflightBlocksMissingAndSeparateDeviceShapes() throws {
    let inventory = CoreAudioInventoryReport(
        capturedAt: "2026-05-08T00:00:00Z",
        hostName: "test-host",
        devices: [
            CoreAudioDeviceInventory(
                id: 2,
                name: "Input Only",
                uid: "input-only",
                manufacturer: nil,
                transportType: nil,
                isAggregate: false,
                inputChannelCount: 2,
                outputChannelCount: 0,
                inputStreamCount: 1,
                outputStreamCount: 0,
                nominalSampleRateHertz: 48_000,
                availableSampleRateRanges: [AudioValueRangeSnapshot(minimum: 48_000, maximum: 48_000)],
                currentBufferFrameSize: 32,
                bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128),
                candidateBufferFrames: BufferFrameCandidates(
                    candidates: [16, 32],
                    reportedRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128)
                ),
                inputLatencyFrames: nil,
                outputLatencyFrames: nil,
                inputSafetyOffsetFrames: nil,
                outputSafetyOffsetFrames: nil,
                clockDomain: nil,
                diagnosticNotes: []
            ),
            CoreAudioDeviceInventory(
                id: 1,
                name: "Output Only",
                uid: "output-only",
                manufacturer: nil,
                transportType: nil,
                isAggregate: false,
                inputChannelCount: 0,
                outputChannelCount: 2,
                inputStreamCount: 0,
                outputStreamCount: 1,
                nominalSampleRateHertz: 48_000,
                availableSampleRateRanges: [AudioValueRangeSnapshot(minimum: 48_000, maximum: 48_000)],
                currentBufferFrameSize: 32,
                bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128),
                candidateBufferFrames: BufferFrameCandidates(
                    candidates: [16, 32],
                    reportedRange: AudioValueRangeSnapshot(minimum: 16, maximum: 128)
                ),
                inputLatencyFrames: nil,
                outputLatencyFrames: nil,
                inputSafetyOffsetFrames: nil,
                outputSafetyOffsetFrames: nil,
                clockDomain: nil,
                diagnosticNotes: []
            )
        ]
    )
    let missing = DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "missing",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0, 1],
        outputChannelMap: [0, 1]
    )
    let outputOnly = DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "output-only",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0, 1],
        outputChannelMap: [0, 1]
    )
    let splitDevices = DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "input-only",
        inputDeviceUID: "input-only",
        outputDeviceUID: "output-only",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0, 1],
        outputChannelMap: [0, 1]
    )

    #expect(throws: DirectPeerAudioGraphError.missingDeviceUID("missing")) {
        _ = try DirectPeerRealtimeAudioGraph.preflight(configuration: missing, inventory: inventory)
    }
    #expect(throws: DirectPeerAudioGraphError.deviceNotFullDuplex("output-only")) {
        _ = try DirectPeerRealtimeAudioGraph.preflight(configuration: outputOnly, inventory: inventory)
    }
    let splitPreflight = try DirectPeerRealtimeAudioGraph.preflight(configuration: splitDevices, inventory: inventory)
    #expect(splitPreflight.device?.uid == "input-only")
    #expect(splitPreflight.outputDevice?.uid == "output-only")
    #expect(splitPreflight.canStart)
}

@Test
func rawBGRAPreviewFactoryConvertsFrameDimensions() throws {
    let frame = RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: 1,
            sequenceNumber: 1,
            timestampNanoseconds: 1,
            timestampBasis: .hostUptimeNanoseconds,
            sourceRole: .avFoundationDevice,
            width: 2,
            height: 2,
            pixelFormat: "bgra8",
            frameRate: VideoFrameRate(numerator: 30, denominator: 1),
            fingerprint: "test-frame"
        ),
        payload: Data(repeating: 255, count: 16)
    )

    let image = try RawBGRAImageFactory.makeCGImage(frame: frame)

    #expect(image.width == 2)
    #expect(image.height == 2)
}

@Test
func rawBGRAPreviewFactoryUsesOpaqueBGRABitmapInfo() throws {
    let frame = RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: 1,
            sequenceNumber: 1,
            timestampNanoseconds: 1,
            timestampBasis: .hostUptimeNanoseconds,
            sourceRole: .avFoundationDevice,
            width: 1,
            height: 1,
            pixelFormat: "bgra8",
            frameRate: VideoFrameRate(numerator: 30, denominator: 1),
            fingerprint: "opaque-bgra"
        ),
        payload: Data([255, 255, 255, 255])
    )

    let image = try RawBGRAImageFactory.makeCGImage(frame: frame)

    #expect(image.alphaInfo == .noneSkipFirst)
    #expect(image.bitmapInfo.contains(.byteOrder32Little))
}

@Test
func rawBGRAAppKitPreviewWindowCountsPendingSubmissionDrops() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Video/RawBGRAAppKitPreviewWindow.swift")

    #expect(source.contains("var droppedFrameCount: Int { get }"))
    #expect(source.contains("public var droppedFrameCount: Int"))
    #expect(source.contains("private var droppedFrameCountStorage = 0"))
    #expect(source.contains("droppedFrameCountStorage += 1"))
    #expect(source.range(of: "guard !submitPending else")?.lowerBound ?? source.endIndex
        < source.range(of: "droppedFrameCountStorage += 1")?.lowerBound ?? source.startIndex)
}

@Test
func directPeerAVVideoRXConvertsCorruptFragmentsAndPreviewFailuresToCounters() throws {
    let loopSource = try readRepositoryText("Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVVideoLoops.swift")
    let socketSource = try readRepositoryText("Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift")

    #expect(loopSource.contains("result.fragmentsDroppedCorrupt += 1"))
    #expect(loopSource.contains("result.framesDroppedDuringReassembly += 1"))
    #expect(loopSource.contains("result.previewFramesDropped += droppedAfterSubmit - droppedBeforeSubmit"))
    #expect(loopSource.contains("result.previewFramesFailed += 1"))
    #expect(socketSource.contains("metrics.videoFragmentsDroppedCorrupt += videoRX.fragmentsDroppedCorrupt"))
    #expect(socketSource.contains("metrics.videoFramesDroppedDuringReassembly += videoRX.framesDroppedDuringReassembly"))
    #expect(socketSource.contains("metrics.videoReassemblyMissingFragments += videoRX.reassemblyMissingFragments"))
    #expect(socketSource.contains("metrics.previewFramesDropped += videoRX.previewFramesDropped"))
    #expect(socketSource.contains("metrics.previewFramesFailed += videoRX.previewFramesFailed"))
    #expect(loopSource.range(of: "VideoTransportFragment.decode(packet.payload)")?.lowerBound ?? loopSource.startIndex
        < loopSource.range(of: "result.fragmentsDroppedCorrupt += 1")?.lowerBound ?? loopSource.endIndex)
    #expect(loopSource.range(of: "try previewSink.submit(frame: frame)")?.lowerBound ?? loopSource.startIndex
        < loopSource.range(of: "result.previewFramesFailed += 1")?.lowerBound ?? loopSource.endIndex)
}

@Test
func directPeerAVVideoReassemblyMetricsMergeShutdownFlushDelta() {
    let before = VideoReassemblyMetrics(
        framesReassembled: 2,
        framesDroppedIncomplete: 1,
        missingFragments: 3,
        lateFragments: 4,
        duplicateFragments: 5,
        activeFramesPeak: 2
    )
    let after = VideoReassemblyMetrics(
        framesReassembled: 2,
        framesDroppedIncomplete: 2,
        missingFragments: 7,
        lateFragments: 6,
        duplicateFragments: 8,
        activeFramesPeak: 2
    )
    var metrics = DirectPeerSessionAVRuntimeMetrics()

    mergeDirectPeerVideoReassemblyMetricDelta(
        directPeerVideoReassemblyMetricDelta(before: before, after: after),
        into: &metrics
    )

    #expect(metrics.videoFramesDroppedDuringReassembly == 1)
    #expect(metrics.videoReassemblyMissingFragments == 4)
    #expect(metrics.videoReassemblyLateFragments == 2)
    #expect(metrics.videoReassemblyDuplicateFragments == 3)
}

@Test
func directPeerAVRuntimeFlushesVideoReassemblerOnShutdown() throws {
    let socketSource = try readRepositoryText("Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift")

    #expect(socketSource.contains("let videoReassemblyBeforeFlush = videoReassembler.metrics"))
    #expect(socketSource.contains("videoReassembler.flushIncomplete()"))
    #expect(socketSource.contains("mergeDirectPeerVideoReassemblyMetricDelta("))
}

@Test
func directPeerAVVideoRXContinuesAfterDeferredFrameDefersAgain() throws {
    let loopSource = try readRepositoryText("Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVVideoLoops.swift")

    #expect(loopSource.contains("case .deferred:\n            break"))
    #expect(!loopSource.contains("case .deferred:\n            return result"))
}

@Test
func directPeerAVProductionFastestSyncAllowsOneFrameWithoutAudioDelay() throws {
    let configuration = directPeerAVSupportConfiguration(mediaSourceMode: .production)
    let bufferPolicy = try DirectPeerSessionAVBufferPolicy.resolve(
        avProfile: .fastest,
        rxBufferProfile: .direct
    )
    let frameIntervalNanoseconds: UInt64 = 33_333_333
    let policy = directPeerAVSyncPolicy(
        configuration: configuration,
        bufferPolicy: bufferPolicy,
        videoFrameIntervalNanoseconds: frameIntervalNanoseconds
    )

    #expect(policy.profile == .directAudioFirst)
    #expect(policy.audioMayDelayForVideo == false)
    #expect(policy.videoAlignmentToleranceMicroseconds == Double(frameIntervalNanoseconds) / 1_000)
    #expect(AVTimestampAligner.decision(
        videoTimestampNanoseconds: 133_333_333,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: policy
    ).action == .renderNow)
    #expect(AVTimestampAligner.decision(
        videoTimestampNanoseconds: 66_666_667,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: policy
    ).action == .renderNow)
}

@Test
func directPeerAVSyntheticFastestSyncAllowsTwoFramesWithoutAudioDelay() throws {
    let configuration = directPeerAVSupportConfiguration(mediaSourceMode: .syntheticFixture)
    let bufferPolicy = try DirectPeerSessionAVBufferPolicy.resolve(
        avProfile: .fastest,
        rxBufferProfile: .direct
    )
    let frameIntervalNanoseconds: UInt64 = 33_333_333
    let policy = directPeerAVSyncPolicy(
        configuration: configuration,
        bufferPolicy: bufferPolicy,
        videoFrameIntervalNanoseconds: frameIntervalNanoseconds
    )

    #expect(policy.profile == .directAudioFirst)
    #expect(policy.audioMayDelayForVideo == false)
    #expect(policy.videoAlignmentToleranceMicroseconds == Double(frameIntervalNanoseconds * 2) / 1_000)
    #expect(AVTimestampAligner.decision(
        videoTimestampNanoseconds: 166_666_666,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: policy
    ).action == .renderNow)
    #expect(AVTimestampAligner.decision(
        videoTimestampNanoseconds: 166_666_668,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: policy
    ).action == .deferVideo)
}

@Test
func directPeerAVFoundationRawFramesAreRetimestampedToHostTimeForTransport() {
    let presentationFrame = rawCapturedVideoFrame(sequenceNumber: 10)
    let hostTimed = directPeerHostTimedVideoFrame(
        presentationFrame,
        hostTimeNanoseconds: 123_456_789
    )

    #expect(hostTimed.metadata.sequenceNumber == presentationFrame.metadata.sequenceNumber)
    #expect(hostTimed.metadata.timestampNanoseconds == 123_456_789)
    #expect(hostTimed.metadata.timestampBasis == .hostUptimeNanoseconds)
    #expect(hostTimed.payload == presentationFrame.payload)
}

@Test
func directPeerDeferredVideoFrameReplacementIsCounted() {
    var result = DirectPeerVideoRXDrainResult()
    var deferredFrame: RawCapturedVideoFrame?

    deferVideoFrameForSync(
        rawCapturedVideoFrame(sequenceNumber: 1),
        deferredFrame: &deferredFrame,
        result: &result
    )
    deferVideoFrameForSync(
        rawCapturedVideoFrame(sequenceNumber: 2),
        deferredFrame: &deferredFrame,
        result: &result
    )

    #expect(deferredFrame?.metadata.sequenceNumber == 2)
    #expect(result.framesReplacedDuringSyncDefer == 1)
    #expect(result.framesDroppedForSync == 1)
}

@Test
func rawVideoPacketBudgetFailsOnUnsupportedProfileCombinations() throws {
    let runTypesSource = try readRepositoryText("Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRunTypes.swift")

    #expect(runTypesSource.contains("preconditionFailure(\"unsupported raw video packet budget profile combination\")"))
    #expect(!runTypesSource.contains("default:\n            128"))
}

@Test
func directPeerVideoReassemblerUsesNegotiatedProfileFragmentBudget() throws {
    var configuration = directPeerAVSupportConfiguration(mediaSourceMode: .syntheticFixture)
    configuration.avProfile = .fastest
    configuration.rxBufferProfile = .direct
    configuration.videoWidth = 2
    configuration.videoHeight = 2
    let reassembler = try directPeerVideoReassembler(for: configuration)
    var fragment = try #require(RawVideoFrameTransport.fragments(
        for: rawCapturedVideoFrame(sequenceNumber: 1),
        maxPacketBytes: 512
    ).first)
    fragment.fragmentCount = 129

    #expect(throws: VideoTransportFragmentError.invalidFragmentCount(129)) {
        _ = try reassembler.receiveRaw(fragment)
    }
}

@Test
func directPeerAVVideoRXTracksOversizeRemoteFramePlansSeparately() throws {
    let loopSource = try readRepositoryText("Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVVideoLoops.swift")
    let socketSource = try readRepositoryText("Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift")

    #expect(loopSource.contains("result.fragmentsDroppedOversize += 1"))
    #expect(socketSource.contains("metrics.videoFragmentsDroppedOversize += videoRX.fragmentsDroppedOversize"))
}

@Test
func directPeerAVFoundationFrameDeliveryGateDoesNotResendCachedFrame() {
    var gate = DirectPeerAVFoundationFrameDeliveryGate()
    let first = rawCapturedVideoFrame(sequenceNumber: 7)
    let second = rawCapturedVideoFrame(sequenceNumber: 8)
    let firstDelivery = gate.shouldDeliver(first)
    let duplicateFirstDelivery = gate.shouldDeliver(first)
    let secondDelivery = gate.shouldDeliver(second)

    #expect(firstDelivery)
    #expect(!duplicateFirstDelivery)
    #expect(secondDelivery)

    gate.reset()
    let firstDeliveryAfterReset = gate.shouldDeliver(first)
    #expect(firstDeliveryAfterReset)
}

private func readRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

private func rawCapturedVideoFrame(sequenceNumber: UInt64) -> RawCapturedVideoFrame {
    RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: 1,
            sequenceNumber: sequenceNumber,
            timestampNanoseconds: sequenceNumber,
            timestampBasis: .hostUptimeNanoseconds,
            sourceRole: .avFoundationDevice,
            width: 2,
            height: 2,
            pixelFormat: "bgra8",
            frameRate: VideoFrameRate(numerator: 30, denominator: 1),
            fingerprint: "test-frame-\(sequenceNumber)"
        ),
        payload: Data(repeating: UInt8(sequenceNumber & 0xff), count: 16)
    )
}
