// Covers peer-session AV support contracts required for interoperable media setup.
import CoreGraphics
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerRemoteAudioFramesAnchorToTheCurrentLocalOutputTimeline() {
    var anchor = DirectPeerRemotePlayoutFrameAnchor()

    #expect(anchor.localFrame(remoteFrame: 48_000, nextLocalOutputFrame: 9_600) == 9_600)
    #expect(anchor.localFrame(remoteFrame: 48_032, nextLocalOutputFrame: 9_600) == 9_632)
    #expect(anchor.localFrame(remoteFrame: 48_016, nextLocalOutputFrame: 9_600) == 9_616)

    // A packet whose mapped deadline has already rendered starts a fresh local epoch.
    #expect(anchor.localFrame(remoteFrame: 48_064, nextLocalOutputFrame: 10_000) == 10_000)
    #expect(anchor.remoteBaseFrame == 48_064)
    #expect(anchor.localBaseFrame == 10_000)
}

@Test
func directPeerAudioRXFreshnessKeepsNewestUnitAcrossABurstLargerThanLegacyDrainLimit() {
    var freshness = DirectPeerAudioRXFreshnessAccumulator()
    for frame in 0..<64 {
        freshness.record(DirectPeerAudioPlayoutPayload(
            payload: Data([UInt8(frame)]),
            senderFrameIndex: UInt64(frame * 32),
            senderHostTimeNanoseconds: UInt64(frame)
        ))
    }

    #expect(freshness.droppedStalePayloadCount == 63)
    let newest = freshness.newestPayload
    #expect(newest?.payload == Data([63]))
    #expect(newest?.senderFrameIndex == 63 * 32)
}

@Test
func directPeerAudioRXFreshnessRejectsDescendingDuplicatesAndKeepsWrapForwardProgress() {
    var freshness = DirectPeerAudioRXFreshnessAccumulator()
    for frame in [UInt64.max - 31, UInt64.max - 63, UInt64.max - 31, 0] {
        freshness.record(DirectPeerAudioPlayoutPayload(
            payload: Data([UInt8(truncatingIfNeeded: frame)]),
            senderFrameIndex: frame,
            senderHostTimeNanoseconds: frame
        ))
    }

    #expect(freshness.newestPayload?.senderFrameIndex == 0)
    #expect(freshness.droppedStalePayloadCount == 3)
}

@Test
func directPeerOpenLolaRawAudioReassemblyHandlesFragmentsLimitsAndIncompleteDeadlines() throws {
 let mode = try directPeerFragmentedRawAudioMode()
 let payload = Data(repeating: 0x7d,
 count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample)

 try assertRawAudioReassemblyCompletes(payload: payload, mode: mode)
 try assertRawAudioReassemblyCountsDuplicateFlood(payload: payload, mode: mode)
 try assertRawAudioReassemblyRejectsOversizedFragmentCount(payload: payload, mode: mode)
 try assertRawAudioReassemblyDropsOldIncompleteDeadline(payload: payload, mode: mode)
 try assertRawAudioReassemblyKeepsReorderedPendingDeadlines(mode: mode)
 try assertRawAudioReassemblyFlushesIncomplete(payload: payload, mode: mode)
}

@Test
func directPeerAVAudioTXDrainsWithPacketBudgetAndLeavesBacklogForNextIteration() throws {
    var pair = try startedAVLoopbackPair(
        audioTransport: .openLolaRaw,
        framesPerPacket: 32
    )
    defer {
        pair.first.shutdown(reason: "bounded audio tx test complete")
        pair.second.shutdown(reason: "bounded audio tx test complete")
    }
    let graph = try DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: 32)
    )
    let payload = Data(repeating: 0x25, count: 32 * 2 * UdpPcmSampleFormat.float32LittleEndian.bytesPerSample)
    #expect(graph.captureInjectedPayload(payload, hostTimeNanoseconds: 1_000) == .stored)
    #expect(graph.captureInjectedPayload(payload, hostTimeNanoseconds: 2_000) == .stored)
    #expect(graph.captureInjectedPayload(payload, hostTimeNanoseconds: 3_000) == .stored)

    let firstDrain = try runAudioTXLoop(
        runner: &pair.first,
        audioGraph: graph,
        configuration: DirectPeerAudioTXLoopConfiguration(
            transport: .openLolaRaw,
            opusEncoder: nil,
            rtpSSRC: 1,
            maxPackets: 2
        )
    )
    let secondDrain = try runAudioTXLoop(
        runner: &pair.first,
        audioGraph: graph,
        configuration: DirectPeerAudioTXLoopConfiguration(
            transport: .openLolaRaw,
            opusEncoder: nil,
            rtpSSRC: 1,
            maxPackets: 2
        )
    )

    #expect(firstDrain.payloadsSent == 2)
    #expect(firstDrain.budgetExhausted)
    #expect(secondDrain.payloadsSent == 1)
    #expect(!secondDrain.budgetExhausted)
}

@Test
func directPeerAVAudioRXCountsMalformedTransportPayloadsAsDrops() throws {
 try assertMalformedRawAudioPayloadDrops()
 try assertMalformedOpusAudioPayloadDrops()
 try assertMalformedAES67PayloadDrops()
}

@Test
func directPeerAVAudioRXCountsUnexpectedPayloadTypesAsDrops() throws {
    var pair = try startedAVLoopbackPair(
        audioTransport: .openLolaRaw,
        framesPerPacket: 32
    )
    defer {
        pair.first.shutdown(reason: "unexpected audio payload test complete")
        pair.second.shutdown(reason: "unexpected audio payload test complete")
    }
    let videoPacket = try directPeerUnexpectedVideoMediaPacket(sequenceNumber: 1)
    try #require(pair.first.audioTransport).send(videoPacket)
    _ = try pair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000)
    let graph = try DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: 32)
    )
    var audioRXState = directPeerAudioRXLoopState()

    let result = try runAudioRXLoop(
        runner: &pair.second,
        audioGraph: graph,
        state: &audioRXState,
        configuration: DirectPeerAudioRXLoopConfiguration(
            transport: .openLolaRaw,
            opusDecoder: nil,
            maxPackets: 4
        )
    )

    #expect(result.queuedForPlayout == 0)
    #expect(result.unexpectedPayloadTypes == 1)
    #expect(result.droppedBeforePlayout == 1)
}

@Test
func directPeerAVVideoRXCountsUnexpectedPayloadTypesAsDrops() throws {
    var pair = try startedAVLoopbackPair(
        audioTransport: .openLolaRaw,
        framesPerPacket: 32
    )
    defer {
        pair.first.shutdown(reason: "unexpected video payload test complete")
        pair.second.shutdown(reason: "unexpected video payload test complete")
    }
    let audioPacket = try directPeerUnexpectedAudioMediaPacket(
        runner: pair.first,
        sequenceNumber: 1
    )
    try #require(pair.first.videoTransport).send(audioPacket)
    _ = try pair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000)
    var reassembler = VideoFrameReassembler(maxFragmentsPerFrame: 4)
    var deferredFrame: DirectPeerPreparedVideoFrame?

    let result = try runVideoRXLoop(
        runner: &pair.second,
        reassembler: &reassembler,
        deferredFrame: &deferredFrame,
        configuration: DirectPeerVideoRXLoopConfiguration(
            previewSink: nil,
            playoutAnchor: DirectPeerAVPlayoutAnchor(policy: .policy(for: .balancedAV)),
            compression: .raw,
            maxPackets: 4
        )
    )

    #expect(result.fragmentsReceived == 0)
    #expect(result.unexpectedPayloadTypes == 1)
    #expect(result.framesReassembled == 0)
}

@Test
func directPeerAVAudioRXFailsMissingInternalRawAudioRouter() throws {
    var pair = try startedAVLoopbackPair(
        audioTransport: .openLolaRaw,
        framesPerPacket: 32
    )
    defer {
        pair.first.shutdown(reason: "missing audio router test complete")
        pair.second.shutdown(reason: "missing audio router test complete")
    }
    let payload = Data(repeating: 0x44, count: 32 * 2 * UdpPcmSampleFormat.float32LittleEndian.bytesPerSample)
    try pair.first.sendAudioPayload(
        payload,
        sequenceNumber: 1,
        senderFrameIndex: 0,
        hostTimeNanoseconds: 1
    )
    _ = try pair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000)
    pair.second.audioRouter = nil
    let graph = try DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: 32)
    )
    var audioRXState = directPeerAudioRXLoopState()

    #expect(throws: PeerSessionRunnerError.missingAudioRouter) {
        _ = try runAudioRXLoop(
            runner: &pair.second,
            audioGraph: graph,
            state: &audioRXState,
            configuration: DirectPeerAudioRXLoopConfiguration(
                transport: .openLolaRaw,
                opusDecoder: nil,
                maxPackets: 4
            )
        )
    }
}

@Test
func directPeerAVAudioRXRecoversAfterAES67ForwardGap() throws {
    var pair = try startedAVLoopbackPair(
        audioTransport: .aes67ST2110L24,
        framesPerPacket: 48
    )
    defer {
        pair.first.shutdown(reason: "aes67 gap recovery test complete")
        pair.second.shutdown(reason: "aes67 gap recovery test complete")
    }
    let payload = Data(repeating: 0, count: AES67ST2110L24Profile.payloadByteCount)
    try #require(pair.first.audioTransport).sendRawDatagram(try RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 1, timestamp: 48, ssrc: 42),
        payload: payload
    ).encoded())
    try #require(pair.first.audioTransport).sendRawDatagram(try RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 3, timestamp: 144, ssrc: 42),
        payload: payload
    ).encoded())
    #expect(try pair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000))
    let graph = try DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: AES67ST2110L24Profile.framesPerPacket)
    )
    var audioRXState = directPeerAudioRXLoopState()

    let result = try runAudioRXLoop(
        runner: &pair.second,
        audioGraph: graph,
        state: &audioRXState,
        configuration: DirectPeerAudioRXLoopConfiguration(
            transport: .aes67ST2110L24,
            opusDecoder: nil,
            maxPackets: 4
        )
    )

    #expect(result.queuedForPlayout == 2)
    #expect(result.rtpPacketsLost == 1)
    #expect(result.droppedBeforePlayout == 1)
}

@Test
func directPeerAVAES67LevelBCDecodeUsesNegotiatedSixFramePacketTime() throws {
    var pair = try startedAVLoopbackPair(
        audioTransport: .aes67ST2110L24,
        framesPerPacket: 6
    )
    defer {
        pair.first.shutdown(reason: "aes67 level bc decode test complete")
        pair.second.shutdown(reason: "aes67 level bc decode test complete")
    }
    let packetTime = AES67ST2110L24PacketTime.levelBC125Microseconds
    let payload = Data(repeating: 0, count: AES67ST2110L24Profile.payloadByteCount(for: packetTime))
    try #require(pair.first.audioTransport).sendRawDatagram(try RTPPacket(
        header: RTPPacketHeader(sequenceNumber: 1, timestamp: 6, ssrc: 42),
        payload: payload
    ).encoded())
    #expect(try pair.second.waitForIncomingMedia(timeoutMicroseconds: 50_000))
    let graph = try DirectPeerRealtimeAudioGraph(
        configuration: testAudioGraphConfiguration(framesPerBuffer: packetTime.framesPerPacket)
    )
    var audioRXState = DirectPeerAudioRXLoopState(
        rtpValidator: AES67ST2110L24RTPReceiveValidator(packetTime: packetTime),
        aes67ClockMapper: DirectPeerAES67RTPHostTimeMapper(sampleRateHertz: 48_000),
        rawAudioReassembly: DirectPeerOpenLolaRawAudioReassemblyState()
    )

    let result = try runAudioRXLoop(
        runner: &pair.second,
        audioGraph: graph,
        state: &audioRXState,
        configuration: DirectPeerAudioRXLoopConfiguration(
            transport: .aes67ST2110L24,
            opusDecoder: nil,
            maxPackets: 1
        )
    )

    #expect(result.queuedForPlayout == 1)
    #expect(result.droppedBeforePlayout == 0)
}

@Test
func directPeerAVConfigurationValidationRequiresSplitAudioDeviceUIDs() throws {
    var valid = directPeerAVSupportConfiguration(mediaSourceMode: .syntheticFixture)
    valid.videoWidth = 16
    valid.videoHeight = 16
    try validateAVConfiguration(valid)

    var missingOutput = valid
    missingOutput.outputDeviceUID = ""

    #expect(throws: DirectPeerSessionAVRuntimeError.missingOutputDeviceUID) {
        try validateAVConfiguration(missingOutput)
    }
}

@Test
func directPeerAVAudioRXDrainMetricsDoNotDoubleCountPlayoutQueueDrops() {
    var metrics = DirectPeerSessionAVRuntimeMetrics()
    metrics.audioPayloadsDroppedBeforePlayout = 2
    let drain = DirectPeerAudioRXDrainResult(
        queuedForPlayout: 7,
        droppedBeforePlayout: 3,
        droppedByPlayoutQueue: 2
    )

    accumulateAudioRXDrainMetrics(drain, into: &metrics)

    #expect(metrics.audioPayloadsQueuedForPlayout == 7)
    #expect(metrics.audioPayloadsDroppedBeforePlayout == 5)
    #expect(metrics.audioPayloadsDroppedByPlayoutQueue == 2)
}

@Test
func directPeerAVMetricsServicePublishesDrainsAndPersistsTransportFields() throws {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    defer {
        pair.first.shutdown(reason: "metrics test complete")
        pair.second.shutdown(reason: "metrics test complete")
    }
 try pair.negotiate()
 try pair.startMedia()

 var firstNextMetricsPublish: UInt64 = 1
 let publish = serviceDirectPeerAVMetrics(
 runner: &pair.first,
 nextMetricsPublishTimeNanoseconds: &firstNextMetricsPublish,
 nowNanoseconds: 1
 )
 let receive = serviceDirectPeerAVMetricsUntilReceived(runner: &pair.second)

 #expect(publish.metricsMessagesPublished == 1)
 #expect(pair.first.metrics.metricsMessagesSent == 1)
 #expect(receive.peerMetricsMessagesReceived == 1)
 #expect(pair.second.metrics.remoteMetricsMessagesReceived == 1)

 try assertMetricsReportPersistsTransportFields(pair: &pair)
}
