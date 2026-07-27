// Verifies that real-time audio packet handoff rejects invalid configuration without trap.
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func realtimeAudioPacketHandoffRejectsInvalidConfigurationWithoutTrap() throws {
    var invalid = packetHandoffConfiguration(preallocatedBlockCount: 0)
    #expect(throws: RealtimeAudioBufferConfigurationError.nonPositiveField("preallocatedBlockCount")) {
        _ = try RealtimeAudioPacketHandoff(configuration: invalid)
    }

    invalid.preallocatedBlockCount = 4
    invalid.playoutTargetFrames = -1
    #expect(throws: RealtimeAudioBufferConfigurationError.negativeField("playoutTargetFrames")) {
        _ = try RealtimeAudioPacketHandoff(configuration: invalid)
    }

    invalid.playoutTargetFrames = 32
    invalid.inputChannelMap = [0]
    #expect(throws: RealtimeAudioBufferConfigurationError.invalidChannelMap(
        field: "inputChannelMap",
        expected: 2,
        actual: 1
    )) {
        _ = try RealtimeAudioPacketHandoff(configuration: invalid)
    }
}

@Test
func realtimeAudioPacketHandoffCapturesSendsAndReportsInputDrops() throws {
    try assertPacketHandoffCapturesExpectedPacket()
    try assertPacketHandoffReportsFullInputRing()
    try assertPacketHandoffRejectsInvalidInputPayloads()
    try assertPacketHandoffPreservesBurstSendOrder()
}

private func assertPacketHandoffCapturesExpectedPacket() throws {
    var handoff = try RealtimeAudioPacketHandoff(configuration: packetHandoffConfiguration())
    let payload = Data((0..<128).map(UInt8.init))

    #expect(handoff.captureCallback(
        startFrame: 0,
        hostTimeNanoseconds: 1,
        payload: payload
    ) == .stored)
    let capturedPacket = try handoff.sendNextPacket()
    let packet = try #require(capturedPacket)

    #expect(packet.payload == payload)
    #expect(packet.header.sequenceNumber == 0)
    #expect(packet.header.senderFrameIndex == 0)
    #expect(packet.header.senderHostTimeNanoseconds == 1)
    #expect(handoff.metrics.directInputBlocks == 1)
    #expect(handoff.metrics.packetFragmentCount == 1)
    #expect(handoff.metrics.allocationWarnings == 0)
}

private func assertPacketHandoffReportsFullInputRing() throws {
    var fullRingHandoff = try RealtimeAudioPacketHandoff(
        configuration: packetHandoffConfiguration(preallocatedBlockCount: 1)
    )

    #expect(fullRingHandoff.captureCallback(startFrame: 0, hostTimeNanoseconds: 1) == .stored)
    #expect(fullRingHandoff.captureCallback(startFrame: 32, hostTimeNanoseconds: 2) == .droppedFull)

    #expect(fullRingHandoff.metrics.droppedInputBlocks == 1)
    #expect(fullRingHandoff.metrics.fullCaptureRingBlocks == 1)
    #expect(fullRingHandoff.metrics.callbackOverrunBlocks == 1)
    #expect(fullRingHandoff.metrics.maximumBufferedBlocks == 1)
}

private func assertPacketHandoffRejectsInvalidInputPayloads() throws {
    var invalidShapeHandoff = try RealtimeAudioPacketHandoff(configuration: packetHandoffConfiguration())
    let invalidShapePayload = Data(repeating: 0, count: 64)

    let result = invalidShapePayload.withUnsafeBytes { bytes in
        invalidShapeHandoff.captureInterleavedInputCallback(
            startFrame: 0,
            hostTimeNanoseconds: 1,
            sourceChannelCount: 1,
            sourceBytes: bytes
        )
    }

    #expect(result == .droppedInvalid)
    #expect(invalidShapeHandoff.metrics.invalidInputBlocks == 1)
    #expect(invalidShapeHandoff.metrics.droppedInputBlocks == 1)
    #expect(invalidShapeHandoff.metrics.callbackOverrunBlocks == 0)
    #expect(invalidShapeHandoff.metrics.fullCaptureRingBlocks == 0)

    var oversizedHandoff = try RealtimeAudioPacketHandoff(configuration: packetHandoffConfiguration())
    let oversizedPayload = Data(repeating: 0, count: 129)

    #expect(oversizedHandoff.captureCallback(
        startFrame: 0,
        hostTimeNanoseconds: 1,
        payload: oversizedPayload
    ) == .droppedInvalid)
    #expect(oversizedHandoff.metrics.invalidInputBlocks == 1)
    #expect(oversizedHandoff.metrics.directInputBlocks == 0)
}

private func assertPacketHandoffPreservesBurstSendOrder() throws {
    var burstHandoff = try RealtimeAudioPacketHandoff(
        configuration: packetHandoffConfiguration(preallocatedBlockCount: 2)
    )

    #expect(burstHandoff.captureCallback(startFrame: 0, hostTimeNanoseconds: 1) == .stored)
    #expect(burstHandoff.captureCallback(startFrame: 32, hostTimeNanoseconds: 2) == .stored)
    #expect(burstHandoff.captureCallback(startFrame: 64, hostTimeNanoseconds: 3) == .droppedFull)

    let capturedFirst = try burstHandoff.sendNextPacket()
    let capturedSecond = try burstHandoff.sendNextPacket()
    let first = try #require(capturedFirst)
    let second = try #require(capturedSecond)

    #expect(first.header.senderFrameIndex == 0)
    #expect(second.header.senderFrameIndex == 32)
    #expect(try burstHandoff.sendNextPacket() == nil)
    #expect(burstHandoff.metrics.droppedInputBlocks == 1)
    #expect(burstHandoff.metrics.networkSendBlocks == 2)
    #expect(burstHandoff.metrics.maximumCaptureRingOccupancyBlocks == 2)
}

@Test
func realtimeAudioPacketHandoffReceivePathReportsBufferFallbackAndInvalidPlayout() throws {
    var handoff = try RealtimeAudioPacketHandoff(
        configuration: packetHandoffConfiguration(preallocatedBlockCount: 2, playoutTargetFrames: 32)
    )

    #expect(try handoff.receive(packet(sequence: 1, senderFrameIndex: 0)) == .queued)
    #expect(try handoff.receive(packet(sequence: 2, senderFrameIndex: 0)) == .droppedFull)

    #expect(handoff.metrics.networkReceiveBlocks == 2)
    #expect(handoff.metrics.droppedNetworkBlocks == 1)
    #expect(handoff.metrics.maximumPlayoutQueueDepthBlocks == 1)

    var fallbackHandoff = try RealtimeAudioPacketHandoff(
        configuration: packetHandoffConfiguration(playoutTargetFrames: 0)
    )

    #expect(try fallbackHandoff.receive(packet(sequence: 1, senderFrameIndex: 0)) == .queued)
    #expect(fallbackHandoff.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    #expect(fallbackHandoff.renderCallback() == .played(
        RealtimeAudioFrameBlock(
            startFrame: 32,
            frameCount: 32,
            payloadByteCount: 128,
            hostTimeNanoseconds: 1
        )
    ))

    var overflowHandoff = try RealtimeAudioPacketHandoff(
        configuration: packetHandoffConfiguration()
    )

    #expect(try overflowHandoff.receive(packet(
        sequence: 1,
        senderFrameIndex: UInt64.max - 10
    )) == .droppedInvalid)
    #expect(overflowHandoff.metrics.networkReceiveBlocks == 1)
    #expect(overflowHandoff.metrics.droppedNetworkBlocks == 1)
    #expect(overflowHandoff.metrics.maximumPlayoutQueueDepthBlocks == 0)
}

@Test
func realtimeAudioPacketHandoffAdverseReceiveScheduleKeepsTruthfulRuntimeMetrics() throws {
    let policy = try RxBufferPolicy.direct(framesPerPacket: 32, sampleRateHertz: 48_000)
    var handoff = try RealtimeAudioPacketHandoff(
        configuration: packetHandoffConfiguration(preallocatedBlockCount: 4, rxBufferPolicy: policy)
    )

    #expect(try handoff.receive(packet(sequence: 0, senderFrameIndex: 0)) == .queued)
    #expect(try handoff.receive(packet(sequence: 2, senderFrameIndex: 64)) == .queued)
    #expect(handoff.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    #expect(try handoff.receive(packet(sequence: 1, senderFrameIndex: 32)) == .queued)
    #expect(try handoff.receive(packet(sequence: 1, senderFrameIndex: 32)) == .droppedFull)

    #expect(handoff.renderCallback() == .played(RealtimeAudioFrameBlock(
        startFrame: 32,
        frameCount: 32,
        payloadByteCount: 128,
        hostTimeNanoseconds: 0
    )))
    #expect(handoff.renderCallback() == .played(RealtimeAudioFrameBlock(
        startFrame: 64,
        frameCount: 32,
        payloadByteCount: 128,
        hostTimeNanoseconds: 1
    )))
    #expect(handoff.renderCallback() == .played(RealtimeAudioFrameBlock(
        startFrame: 96,
        frameCount: 32,
        payloadByteCount: 128,
        hostTimeNanoseconds: 2
    )))

    #expect(handoff.metrics.networkReceiveBlocks == 4)
    #expect(handoff.metrics.droppedNetworkBlocks == 1)
    #expect(handoff.metrics.outputUnderrunBlocks == 1)
    #expect(handoff.metrics.maximumBufferedBlocks <= handoff.metrics.ringCapacityBlocks)
    #expect(handoff.metrics.maximumPlayoutQueueDepthBlocks == 3)
    #expect(handoff.metrics.rxBuffer?.lostPackets == 1)
    #expect(handoff.metrics.rxBuffer?.reorderedPackets == 1)
    #expect(handoff.metrics.rxBuffer?.duplicatePackets == 1)
    #expect(handoff.metrics.rxBuffer?.underruns == 1)
    #expect(handoff.metrics.rxBuffer?.overruns == 1)
}

@Test
func realtimeAudioPacketHandoffRuntimeSupportsConcurrentReceiveAndRenderCallbacks() throws {
    let handoff = try RealtimeAudioPacketHandoffRuntime(
        configuration: packetHandoffConfiguration(preallocatedBlockCount: 64)
    )
    let totalPackets = 256
    let producerDone = DispatchSemaphore(value: 0)
    let consumerDone = DispatchSemaphore(value: 0)
    let received = PacketHandoffIntCounter()
    let played = PacketHandoffUInt64PayloadRecorder(capacity: totalPackets)

    startConcurrentReceiveStressProducer(
        handoff: handoff,
        totalPackets: totalPackets,
        received: received,
        played: played,
        producerDone: producerDone
    )
    startConcurrentRenderStressConsumer(
        handoff: handoff,
        totalPackets: totalPackets,
        received: received,
        played: played,
        consumerDone: consumerDone
    )

    #expect(producerDone.wait(timeout: .now() + 5) == .success)
    #expect(consumerDone.wait(timeout: .now() + 5) == .success)
    #expect(played.snapshot() == (0..<totalPackets).map(UInt64.init))
    let metrics = handoff.metricsSnapshot()
    #expect(metrics.networkReceiveBlocks == totalPackets)
    #expect(metrics.outputBlocks >= totalPackets)
    #expect(metrics.droppedNetworkBlocks == 0)
    #expect(metrics.hiddenPlayoutGrowthDetected == false)
}

private func startConcurrentReceiveStressProducer(
    handoff: RealtimeAudioPacketHandoffRuntime,
    totalPackets: Int,
    received: PacketHandoffIntCounter,
    played: PacketHandoffUInt64PayloadRecorder,
    producerDone: DispatchSemaphore
) {
    DispatchQueue.global(qos: .userInitiated).async {
        do {
            for index in 0..<totalPackets {
                let result = try handoff.receive(packet(
                    sequence: UInt64(index),
                    senderFrameIndex: UInt64(index * 32)
                ))
                if result == .queued {
                    received.increment()
                }
                while received.value - played.count > 32 {
                    sched_yield()
                }
            }
        } catch {
            Issue.record("receive failed: \(error)")
        }
        producerDone.signal()
    }
}

private func startConcurrentRenderStressConsumer(
    handoff: RealtimeAudioPacketHandoffRuntime,
    totalPackets: Int,
    received: PacketHandoffIntCounter,
    played: PacketHandoffUInt64PayloadRecorder,
    consumerDone: DispatchSemaphore
) {
    DispatchQueue.global(qos: .userInitiated).async {
        while played.count < totalPackets {
            if received.value > played.count {
                switch handoff.renderCallback() {
                case .played(let block):
                    played.append(block.hostTimeNanoseconds)
                case .silence:
                    break
                }
            } else {
                sched_yield()
            }
        }
        consumerDone.signal()
    }
}

@Test
func realtimeAudioPacketHandoffRuntimeLockIsNotUsedByProductionRealtimeSources() throws {
    let sourcesRoot = realtimeAudioPacketHandoffRepositoryRoot.appendingPathComponent("Sources")
    let sourceFiles = try realtimeAudioPacketHandoffSwiftSourceFiles(under: sourcesRoot)
    let runtimeDeclarationPath =
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoffSupport.swift"
    var productionReferences: [String] = []

    for sourceFile in sourceFiles {
        let relativePath = sourceFile.path.replacingOccurrences(
            of: realtimeAudioPacketHandoffRepositoryRoot.path + "/",
            with: ""
        )
        guard relativePath != runtimeDeclarationPath else {
            continue
        }
        let source = try String(contentsOf: sourceFile, encoding: .utf8)
        if source.contains("RealtimeAudioPacketHandoffRuntime") {
            productionReferences.append(relativePath)
        }
    }

    #expect(productionReferences.isEmpty)

    let runtimeDeclarationSource = try String(
        contentsOf: sourcesRoot.appendingPathComponent(
            "OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoffSupport.swift"
        ),
        encoding: .utf8
    )
    #expect(runtimeDeclarationSource.contains("Host-thread convenience wrapper"))
    #expect(runtimeDeclarationSource.contains("Do not call this wrapper from real-time audio callbacks"))
}

@Test
func realtimeAudioPacketHandoffRejectsInvalidV2TransportModesBeforeSend() throws {
    var handoff = try RealtimeAudioPacketHandoff(configuration: packetHandoffConfiguration())
    let mode = try mismatchedV2Mode()

    #expect(handoff.captureCallback(startFrame: 0, hostTimeNanoseconds: 1) == .stored)
    #expect(throws: RealtimeAudioPacketHandoffError.transportModeMismatch) {
        _ = try handoff.sendNextV2Packets(mode: mode)
    }

    var incompletePlanHandoff = try RealtimeAudioPacketHandoff(configuration: packetHandoffConfiguration())
    let incompletePlanMode = incompleteV2Mode()

    #expect(incompletePlanHandoff.captureCallback(startFrame: 0, hostTimeNanoseconds: 1) == .stored)
    #expect(throws: RealtimeAudioPacketHandoffError.transportModeMismatch) {
        _ = try incompletePlanHandoff.sendNextV2Packets(mode: incompletePlanMode)
    }
}
