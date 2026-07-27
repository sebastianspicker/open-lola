// Verifies that direct peer pending video transmit yields bounded fragment quanta.
import CoreGraphics
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerPendingVideoTransmitYieldsBoundedFragmentQuanta() {
    let packets = (1...40).map { sequence in
        UdpMediaPacket(
            header: UdpMediaPacketHeader(
                payloadType: .videoRawFrameFragment,
                streamID: 100,
                sequenceNumber: UInt64(sequence),
                timestampNanoseconds: 1
            ),
            payload: Data([UInt8(sequence)])
        )
    }
    var pending = DirectPeerPendingVideoTransmit(packets: packets)

    #expect(pending.nextPackets(limit: 16).count == 16)
    pending.nextPacketIndex += 16
    #expect(pending.nextPackets(limit: 16).count == 16)
    pending.nextPacketIndex += 16
    #expect(pending.nextPackets(limit: 16).count == 8)
    pending.nextPacketIndex += 8
    #expect(pending.isComplete)
}

@Test
func directPeerVideoPreparationWorkerKeepsOnlyNewestFrameOffTheMediaLoop() throws {
    let started = DispatchSemaphore(value: 0)
    let releaseFirst = DispatchSemaphore(value: 0)
    let worker = DirectPeerVideoPreparationWorker { request in
        if request.frame.metadata.sequenceNumber == 1 {
            started.signal()
            _ = releaseFirst.wait(timeout: .now() + 1)
        }
        return [UdpMediaPacket(
            header: UdpMediaPacketHeader(
                payloadType: request.payloadType,
                streamID: request.frame.metadata.streamID,
                sequenceNumber: request.frame.metadata.sequenceNumber,
                timestampNanoseconds: request.frame.metadata.timestampNanoseconds
            ),
            payload: request.frame.payload
        )]
    }
    defer { worker.cancel() }

    worker.submitLatest(videoPreparationRequest(sequenceNumber: 1))
    #expect(started.wait(timeout: .now() + 1) == .success)
    worker.submitLatest(videoPreparationRequest(sequenceNumber: 2))
    worker.submitLatest(videoPreparationRequest(sequenceNumber: 3))
    releaseFirst.signal()

    let descriptor = try #require(worker.readinessDescriptor)
    #expect(try waitForReadableSocket(socket: descriptor, timeoutMicroseconds: 500_000))
    let completedPackets = try worker.takeCompletedPackets()
    let packets = try #require(completedPackets)
    #expect(packets.map(\.header.sequenceNumber) == [3])
    #expect(worker.takeDroppedFrameCount() == 2)
}

@Test
func directPeerVideoDecodeWorkerKeepsOnlyNewestFrameOffTheMediaLoop() throws {
    let started = DispatchSemaphore(value: 0)
    let releaseFirst = DispatchSemaphore(value: 0)
    let worker = DirectPeerVideoDecodeWorker { request in
        if request.frame.metadata.sequenceNumber == 1 {
            started.signal()
            _ = releaseFirst.wait(timeout: .now() + 1)
        }
        return DirectPeerPreparedVideoFrame(
            frame: request.frame,
            proof: directPeerSessionVideoFrameProof(for: request.frame)
        )
    }
    defer { worker.cancel() }

    worker.submitLatest(videoDecodeRequest(sequenceNumber: 1))
    #expect(started.wait(timeout: .now() + 1) == .success)
    worker.submitLatest(videoDecodeRequest(sequenceNumber: 2))
    worker.submitLatest(videoDecodeRequest(sequenceNumber: 3))
    releaseFirst.signal()

    let descriptor = try #require(worker.readinessDescriptor)
    #expect(try waitForReadableSocket(socket: descriptor, timeoutMicroseconds: 500_000))
    let completion = try #require(worker.takeCompletion())
    let prepared = try completion.get()
    #expect(prepared.frame.metadata.sequenceNumber == 3)
    #expect(worker.takeDroppedFrameCount() == 2)
}

@Test
func directPeerAES67VideoHostTimesMapIntoTheReceiverAudioClockEpoch() {
    let mapper = DirectPeerRemoteVideoHostTimeMapper()
    var first = rawCapturedVideoFrame(sequenceNumber: 1)
    first.metadata.timestampNanoseconds = 9_000_000_000_000
    var second = rawCapturedVideoFrame(sequenceNumber: 2)
    second.metadata.timestampNanoseconds = 9_000_033_333_333

    let mappedFirst = mapper.map(first, observedLocalHostTimeNanoseconds: 1_000_000)
    let mappedSecond = mapper.map(second, observedLocalHostTimeNanoseconds: 34_500_000)

    #expect(mappedFirst.metadata.timestampNanoseconds == 1_000_000)
    #expect(mappedSecond.metadata.timestampNanoseconds == 34_333_333)
    #expect(mappedSecond.payload == second.payload)
}

@Test
func directPeerPreparedVideoSupersedesAnIncompleteOlderFrameImmediately() {
    var pending: DirectPeerPendingVideoTransmit? = DirectPeerPendingVideoTransmit(
        packets: videoPackets(sequenceNumbers: [1, 2, 3]),
        frameSequenceNumber: 10,
        timestampNanoseconds: 1_000
    )
    pending?.nextPacketIndex = 1
    let prepared = DirectPeerPreparedVideoTransmit(
        packets: videoPackets(sequenceNumbers: [20, 21]),
        frameSequenceNumber: 11,
        timestampNanoseconds: 2_000
    )

    let dropped = supersedePendingVideoTransmit(with: prepared, pending: &pending)

    #expect(dropped == 1)
    #expect(pending?.frameSequenceNumber == 11)
    #expect(pending?.timestampNanoseconds == 2_000)
    #expect(pending?.nextPacketIndex == 0)
    #expect(pending?.packets.map(\.header.sequenceNumber) == [20, 21])
}

@Test
func directPeerVideoFragmentQuantumYieldsAfterEveryFragmentForAudioService() {
    #expect(directPeerVideoTransmitPacketLimit(
        remainingPacketCount: 384,
        nowNanoseconds: 0,
        nextFrameNanoseconds: 33_333_333,
        audioPacketIntervalNanoseconds: 2_500_000,
        minimumQuantum: 16
    ) == 1)
    #expect(directPeerVideoTransmitPacketLimit(
        remainingPacketCount: 12,
        nowNanoseconds: 34_000_000,
        nextFrameNanoseconds: 33_333_333,
        audioPacketIntervalNanoseconds: 2_500_000,
        minimumQuantum: 16
    ) == 1)
}

private func videoPackets(sequenceNumbers: [UInt64]) -> [UdpMediaPacket] {
    sequenceNumbers.map { sequenceNumber in
        UdpMediaPacket(
            header: UdpMediaPacketHeader(
                payloadType: .videoRawFrameFragment,
                streamID: 1,
                sequenceNumber: sequenceNumber,
                timestampNanoseconds: sequenceNumber
            ),
            payload: Data([UInt8(truncatingIfNeeded: sequenceNumber)])
        )
    }
}

private func videoPreparationRequest(sequenceNumber: UInt64) -> DirectPeerVideoPreparationRequest {
    DirectPeerVideoPreparationRequest(
        frame: rawCapturedVideoFrame(sequenceNumber: sequenceNumber),
        compression: .raw,
        maxPacketBytes: 1_200,
        payloadType: .videoRawFrameFragment
    )
}

private func videoDecodeRequest(sequenceNumber: UInt64) -> DirectPeerVideoDecodeRequest {
    DirectPeerVideoDecodeRequest(
        frame: rawCapturedVideoFrame(sequenceNumber: sequenceNumber),
        compression: .raw
    )
}

@Test
func directPeerRealtimeAudioPreflightBlocksMissingAndSeparateDeviceShapes() throws {
    let inventory = splitDeviceCoreAudioInventory()
    let missing = directPeerRealtimeAudioGraphConfiguration(audioDeviceUID: "missing")
    let outputOnly = directPeerRealtimeAudioGraphConfiguration(audioDeviceUID: "output-only")
    let splitDevices = directPeerSplitRealtimeAudioGraphConfiguration()

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

private func splitDeviceCoreAudioInventory() -> CoreAudioInventoryReport {
    CoreAudioInventoryReport(
        capturedAt: "2026-05-08T00:00:00Z",
        hostName: "test-host",
        devices: [
            coreAudioDeviceInventory(
                id: 2,
                name: "Input Only",
                uid: "input-only",
                inputChannelCount: 2,
                outputChannelCount: 0,
                inputStreamCount: 1,
                outputStreamCount: 0
            ),
            coreAudioDeviceInventory(
                id: 1,
                name: "Output Only",
                uid: "output-only",
                inputChannelCount: 0,
                outputChannelCount: 2,
                inputStreamCount: 0,
                outputStreamCount: 1
            )
        ]
    )
}

// swiftlint:disable:next function_parameter_count
private func coreAudioDeviceInventory(
    id: UInt32,
    name: String,
    uid: String,
    inputChannelCount: Int,
    outputChannelCount: Int,
    inputStreamCount: Int,
    outputStreamCount: Int
) -> CoreAudioDeviceInventory {
    var fixture = SyntheticFullDuplexDeviceFixture(id: id, name: name, uid: uid)
    fixture.inputChannelCount = inputChannelCount
    fixture.outputChannelCount = outputChannelCount
    fixture.inputStreamCount = inputStreamCount
    fixture.outputStreamCount = outputStreamCount
    fixture.bufferFrameSizeRange = .init(minimum: 16, maximum: 128)
    fixture.candidateBufferFrames = .init(
        candidates: [16, 32],
        reportedRange: .init(minimum: 16, maximum: 128)
    )
    return syntheticFullDuplexDevice(fixture)
}

private func directPeerRealtimeAudioGraphConfiguration(
    audioDeviceUID: String
) -> DirectPeerRealtimeAudioGraphConfiguration {
    standardDirectPeerAudioGraphConfiguration(
        inputDeviceUID: audioDeviceUID,
        outputDeviceUID: audioDeviceUID
    )
}

private func directPeerSplitRealtimeAudioGraphConfiguration() -> DirectPeerRealtimeAudioGraphConfiguration {
    standardDirectPeerAudioGraphConfiguration(
        inputDeviceUID: "input-only",
        outputDeviceUID: "output-only"
    )
}

@Test
func directPeerAVFastestSyncPolicyUsesMediaSourceToleranceWithoutAudioDelay() throws {
    try expectFastestProductionAVSyncPolicyUsesOneFrameTolerance()
    try expectFastestSyntheticAVSyncPolicyUsesTwoFrameTolerance()
}

private func expectFastestProductionAVSyncPolicyUsesOneFrameTolerance() throws {
    let bufferPolicy = try DirectPeerSessionAVBufferPolicy.resolve(
        avProfile: .fastest,
        rxBufferProfile: .direct
    )
    let frameIntervalNanoseconds: UInt64 = 33_333_333
    let policy = directPeerAVSyncPolicy(
        configuration: directPeerAVSupportConfiguration(mediaSourceMode: .production),
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

private func expectFastestSyntheticAVSyncPolicyUsesTwoFrameTolerance() throws {
    let syntheticBufferPolicy = try DirectPeerSessionAVBufferPolicy.resolve(
        avProfile: .fastest,
        rxBufferProfile: .direct
    )
    let frameIntervalNanoseconds: UInt64 = 33_333_333
    let syntheticPolicy = directPeerAVSyncPolicy(
        configuration: directPeerAVSupportConfiguration(mediaSourceMode: .syntheticFixture),
        bufferPolicy: syntheticBufferPolicy,
        videoFrameIntervalNanoseconds: frameIntervalNanoseconds
    )

    #expect(syntheticPolicy.profile == .directAudioFirst)
    #expect(syntheticPolicy.audioMayDelayForVideo == false)
    #expect(syntheticPolicy.videoAlignmentToleranceMicroseconds == Double(frameIntervalNanoseconds * 2) / 1_000)
    #expect(AVTimestampAligner.decision(
        videoTimestampNanoseconds: 166_666_666,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: syntheticPolicy
    ).action == .renderNow)
    #expect(AVTimestampAligner.decision(
        videoTimestampNanoseconds: 166_666_668,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: syntheticPolicy
    ).action == .deferVideo)
}

@Test
func directPeerAVFoundationFrameHelpersRetimestampDeferAndGateDelivery() {
    let presentationFrame = rawCapturedVideoFrame(sequenceNumber: 10)
    let hostTimed = directPeerHostTimedVideoFrame(
        presentationFrame,
        hostTimeNanoseconds: 123_456_789
    )

    #expect(hostTimed.metadata.sequenceNumber == presentationFrame.metadata.sequenceNumber)
    #expect(hostTimed.metadata.timestampNanoseconds == 123_456_789)
    #expect(hostTimed.metadata.timestampBasis == .hostUptimeNanoseconds)
    #expect(hostTimed.payload == presentationFrame.payload)

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

    var metrics = DirectPeerSessionAVRuntimeMetrics()
    dropDeferredVideoFrameAtShutdown(&deferredFrame, metrics: &metrics)
    #expect(deferredFrame == nil)
    #expect(metrics.videoFramesDroppedForSync == 1)

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

@Test
func directPeerVideoReassemblerUsesNegotiatedFragmentBudgetAndTracksOversizeDrops() throws {
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
