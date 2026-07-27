// Moves incoming PCM payloads through bounded realtime storage and returns explicit pressure outcomes so network code never owns callback buffers.
import CoreAudio
import Darwin
import Foundation

/// Classifies whether a received packet was queued or dropped for lateness, capacity, or validity.
public enum RealtimeAudioPacketReceiveResult: Equatable, Sendable {
    case queued
    case droppedLate
    case droppedFull
    case droppedInvalid
}

/// Reports packet-mode, payload, and sequence failures before network input enters the audio callback path.
public enum RealtimeAudioPacketHandoffError: Error, Equatable, Sendable {
    case packetModeMismatch
    case transportModeMismatch
    case emptyPayloadBuffer
    case sequenceNumberExhausted
}

/// Owns the bounded packet queue and deadline accounting between network input and audio playout.
public struct RealtimeAudioPacketHandoff: Sendable {
    private var captureRing: RealtimeAudioPayloadCaptureRing
    private var playout: RealtimeAudioDueBlockPlayout
    private var packetPayloadScratch: Data
    private var nextSequenceNumber: UInt64 = 0
    private var nextReceiveSequenceNumber: UInt64?
    private var lastBackwardReceiveSequenceNumber: UInt64?
    private let packetMode: UdpPcmPacketMode
    private let inputChannelMap: [Int]
    private let playoutTargetFrames: Int
    private let clock: RealtimeAudioPacketHandoffClock

    public private(set) var metrics: RealtimeAudioHandoffMetrics

    public init(configuration: RealtimeAudioEngineConfiguration) throws {
        try configuration.validateRealtimeBufferInputs()
        let initialState = try RealtimeAudioPacketHandoffInitialState(configuration: configuration)
        self.clock = initialState.clock
        self.packetMode = initialState.packetMode
        self.inputChannelMap = initialState.inputChannelMap
        self.playoutTargetFrames = initialState.playoutTargetFrames
        self.captureRing = initialState.captureRing
        self.packetPayloadScratch = initialState.packetPayloadScratch
        self.playout = initialState.playout
        self.metrics = initialState.metrics
    }
}

extension RealtimeAudioPacketHandoff {
    public mutating func captureCallback(
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64
    ) -> RealtimeAudioRingPushResult {
        recordCaptureResult(
            captureRing.pushSilence(
                startFrame: startFrame,
                hostTimeNanoseconds: hostTimeNanoseconds
            )
        )
    }

    public mutating func captureCallback(
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64,
        payload: Data
    ) -> RealtimeAudioRingPushResult {
        payload.withUnsafeBytes { sourceBytes in
            captureInterleavedInputCallback(
                startFrame: startFrame,
                hostTimeNanoseconds: hostTimeNanoseconds,
                sourceChannelCount: packetMode.channelCount,
                sourceBytes: sourceBytes
            )
        }
    }

    public mutating func captureInterleavedInputCallback(
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64,
        sourceChannelCount: Int,
        sourceBytes: UnsafeRawBufferPointer
    ) -> RealtimeAudioRingPushResult {
        recordCaptureResult(
            captureRing.pushInterleaved(
                startFrame: startFrame,
                hostTimeNanoseconds: hostTimeNanoseconds,
                sourceChannelCount: sourceChannelCount,
                sourceBytes: sourceBytes
            )
        )
    }

    public mutating func captureAudioBufferListCallback(
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64,
        input: UnsafePointer<AudioBufferList>
    ) -> RealtimeAudioRingPushResult {
        let inputBuffers = RealtimeAudioBufferListReader(input)
        return recordCaptureResult(
            captureRing.pushAudioBuffers(
                startFrame: startFrame,
                hostTimeNanoseconds: hostTimeNanoseconds,
                inputBuffers: inputBuffers
            )
        )
    }

    public mutating func sendNextPacket() throws -> UdpPcmPacket? {
        let start = clock.nowNanoseconds()
        let sequenceNumber = try reserveSendSequenceNumber()
        guard let block = captureRing.popPayload(into: &packetPayloadScratch) else {
            return nil
        }
        guard packetPayloadScratch.count == packetMode.payloadByteCount else {
            throw RealtimeAudioPacketHandoffError.emptyPayloadBuffer
        }
        let packet = UdpPcmPacket(
            header: UdpPcmPacketHeader(
                transport: .init(
                    sequenceNumber: sequenceNumber,
                    senderFrameIndex: block.startFrame,
                    senderHostTimeNanoseconds: block.hostTimeNanoseconds
                ),
                format: .init(
                    sampleRateHertz: UInt32(packetMode.sampleRateHertz),
                    framesPerPacket: UInt32(packetMode.framesPerPacket),
                    channelCount: UInt16(packetMode.channelCount),
                    sampleFormat: packetMode.sampleFormat
                )
            ),
            payload: packetPayloadScratch
        )
        recordPacketizedSend(start: start, fragmentCount: 1, nextSequenceNumber: sequenceNumber + 1)
        return packet
    }

    public mutating func sendNextV2Packets(mode: AudioTransportMode) throws -> [UdpPcmV2Packet]? {
        guard mode.protocolVersion == .udpPcmV2,
              mode.sampleRateHertz == packetMode.sampleRateHertz,
              mode.framesPerPacket == packetMode.framesPerPacket,
              mode.channelCount == packetMode.channelCount,
              mode.sampleFormat == packetMode.sampleFormat else {
            throw RealtimeAudioPacketHandoffError.transportModeMismatch
        }
        try validateV2FragmentPlan(mode)
        let start = clock.nowNanoseconds()
        let sequenceNumber = try reserveSendSequenceNumber()
        guard let packets = try captureRing.withPoppedPayload({ block, payloadBytes in
            try UdpPcmV2Packetizer.packetize(
                payloadBytes,
                sequenceNumber: sequenceNumber,
                senderFrameIndex: block.startFrame,
                senderHostTimeNanoseconds: block.hostTimeNanoseconds,
                mode: mode
            )
        }) else {
            return nil
        }
        recordPacketizedSend(start: start, fragmentCount: packets.count, nextSequenceNumber: sequenceNumber + 1)
        return packets
    }

    public mutating func receive(_ packet: UdpPcmPacket) throws -> RealtimeAudioPacketReceiveResult {
        guard packet.matches(packetMode) else {
            throw RealtimeAudioPacketHandoffError.packetModeMismatch
        }

        let start = clock.nowNanoseconds()
        metrics.networkReceiveBlocks += 1
        recordReceiveSequence(packet)
        let playoutFrame = packet.header.senderFrameIndex.addingReportingOverflow(UInt64(playoutTargetFrames))
        guard !playoutFrame.overflow else { return recordInvalidReceiveDrop(start: start) }
        guard playoutFrame.partialValue >= playout.nextDueFrame else { return recordLateReceiveDrop(start: start) }

        return recordPlayoutEnqueue(
            playout.enqueue(frameBlock(for: packet, playoutFrame: playoutFrame.partialValue)),
            start: start
        )
    }

}

extension RealtimeAudioPacketHandoff {
    private func frameBlock(for packet: UdpPcmPacket, playoutFrame: UInt64) -> RealtimeAudioFrameBlock {
        RealtimeAudioFrameBlock(
            startFrame: playoutFrame,
            frameCount: Int(packet.header.framesPerPacket),
            payloadByteCount: packet.payload.count,
            hostTimeNanoseconds: packet.header.senderHostTimeNanoseconds
        )
    }

    private mutating func recordInvalidReceiveDrop(start: UInt64) -> RealtimeAudioPacketReceiveResult {
        metrics.droppedNetworkBlocks += 1
        updateRxBuffer { snapshot in
            snapshot.lostPackets += 1
        }
        metrics.depacketizationDuration.record(clock.elapsedMicroseconds(since: start))
        return .droppedInvalid
    }

    private mutating func recordLateReceiveDrop(start: UInt64) -> RealtimeAudioPacketReceiveResult {
        metrics.latePackets += 1
        metrics.droppedNetworkBlocks += 1
        updateRxBuffer { snapshot in
            snapshot.latePackets += 1
            snapshot.lostPackets += 1
        }
        metrics.depacketizationDuration.record(clock.elapsedMicroseconds(since: start))
        return .droppedLate
    }

    private mutating func recordPlayoutEnqueue(
        _ result: RealtimeAudioRingPushResult,
        start: UInt64
    ) -> RealtimeAudioPacketReceiveResult {
        switch result {
        case .stored:
            updateMaximumBufferedBlocks()
            metrics.depacketizationDuration.record(clock.elapsedMicroseconds(since: start))
            return .queued
        case .droppedLate:
            metrics.latePackets += 1
            metrics.droppedNetworkBlocks += 1
            updateRxBuffer { snapshot in
                snapshot.latePackets += 1
                snapshot.lostPackets += 1
            }
            updateMaximumBufferedBlocks()
            metrics.depacketizationDuration.record(clock.elapsedMicroseconds(since: start))
            return .droppedLate
        case .droppedFull, .droppedAhead:
            metrics.droppedNetworkBlocks += 1
            updateRxBuffer { snapshot in
                snapshot.overruns += 1
            }
            updateMaximumBufferedBlocks()
            metrics.depacketizationDuration.record(clock.elapsedMicroseconds(since: start))
            return .droppedFull
        case .droppedInvalid:
            metrics.droppedNetworkBlocks += 1
            updateMaximumBufferedBlocks()
            metrics.depacketizationDuration.record(clock.elapsedMicroseconds(since: start))
            return .droppedInvalid
        }
    }

    public mutating func renderCallback() -> RealtimeAudioPlayoutResult {
        let result = playout.renderNextBlock()
        metrics.outputBlocks += 1
        if case .silence = result {
            metrics.outputUnderrunBlocks += 1
            updateRxBuffer { snapshot in
                snapshot.underruns += 1
            }
        }
        updateMaximumBufferedBlocks()
        return result
    }

    public mutating func markShutdownCompleted() {
        metrics.shutdownCompleted = true
    }

    private mutating func recordCaptureResult(
        _ captureResult: RealtimeAudioCapturePushResult
    ) -> RealtimeAudioRingPushResult {
        metrics.inputBlocks += 1
        switch captureResult.copyKind {
        case .silent:
            break
        case .direct:
            metrics.directInputBlocks += 1
        case .remapped:
            metrics.remappedInputBlocks += 1
        case .invalid:
            metrics.invalidInputBlocks += 1
            metrics.allocationWarnings += 1
        }
        if captureResult.result == .droppedInvalid {
            metrics.droppedInputBlocks += 1
        } else if captureResult.result == .droppedFull {
            metrics.droppedInputBlocks += 1
            metrics.callbackOverrunBlocks += 1
            metrics.fullCaptureRingBlocks += 1
        }
        updateMaximumBufferedBlocks()
        return captureResult.result
    }

    private func reserveSendSequenceNumber() throws -> UInt64 {
        guard nextSequenceNumber < UInt64.max else {
            throw RealtimeAudioPacketHandoffError.sequenceNumberExhausted
        }
        return nextSequenceNumber
    }

    private mutating func recordReceiveSequence(_ packet: UdpPcmPacket) {
        guard let expected = nextReceiveSequenceNumber else {
            nextReceiveSequenceNumber = nextSequence(after: packet.header.sequenceNumber)
            return
        }
        if packet.header.sequenceNumber == expected {
            nextReceiveSequenceNumber = nextSequence(after: packet.header.sequenceNumber)
            return
        }
        if packet.header.sequenceNumber > expected {
            let missing = packet.header.sequenceNumber - expected
            updateRxBuffer { snapshot in
                snapshot.lostPackets += Int(min(missing, UInt64(Int.max)))
            }
            nextReceiveSequenceNumber = nextSequence(after: packet.header.sequenceNumber)
            return
        }
        let isDuplicateBackwardSequence = lastBackwardReceiveSequenceNumber == packet.header.sequenceNumber
        lastBackwardReceiveSequenceNumber = packet.header.sequenceNumber
        updateRxBuffer { snapshot in
            if isDuplicateBackwardSequence {
                snapshot.duplicatePackets += 1
            } else {
                snapshot.reorderedPackets += 1
            }
        }
    }

    private func nextSequence(after sequence: UInt64) -> UInt64 {
        sequence == UInt64.max ? UInt64.max : sequence + 1
    }

    private func validateV2FragmentPlan(_ mode: AudioTransportMode) throws {
        let fragments = mode.fragments.sorted { $0.fragmentIndex < $1.fragmentIndex }
        guard !fragments.isEmpty, fragments.count == fragments[0].fragmentCount else {
            throw RealtimeAudioPacketHandoffError.transportModeMismatch
        }
        var expectedOffset = 0
        for (expectedIndex, fragment) in fragments.enumerated() {
            guard fragment.fragmentIndex == expectedIndex,
                  fragment.fragmentCount == fragments.count,
                  fragment.totalChannelCount == packetMode.channelCount,
                  fragment.channelOffset == expectedOffset,
                  fragment.channelsInFragment > 0 else {
                throw RealtimeAudioPacketHandoffError.transportModeMismatch
            }
            expectedOffset += fragment.channelsInFragment
        }
        guard expectedOffset == packetMode.channelCount else {
            throw RealtimeAudioPacketHandoffError.transportModeMismatch
        }
    }

    private mutating func recordPacketizedSend(
        start: UInt64,
        fragmentCount: Int,
        nextSequenceNumber: UInt64
    ) {
        metrics.packetizationDuration.record(clock.elapsedMicroseconds(since: start))
        self.nextSequenceNumber = nextSequenceNumber
        metrics.networkSendBlocks += 1
        metrics.packetFragmentCount += fragmentCount
        updateMaximumBufferedBlocks()
    }

    private mutating func updateMaximumBufferedBlocks() {
        let playoutBufferedBlockCount = playout.bufferedBlockCount
        metrics.maximumCaptureRingOccupancyBlocks = max(
            metrics.maximumCaptureRingOccupancyBlocks,
            captureRing.count
        )
        metrics.maximumPlayoutQueueDepthBlocks = max(
            metrics.maximumPlayoutQueueDepthBlocks,
            playoutBufferedBlockCount
        )
        metrics.maximumBufferedBlocks = max(
            metrics.maximumBufferedBlocks,
            captureRing.count,
            playoutBufferedBlockCount
        )
        if metrics.maximumBufferedBlocks > metrics.ringCapacityBlocks {
            metrics.hiddenPlayoutGrowthDetected = true
        }
        updateRxBuffer { snapshot in
            snapshot.recordBufferedPacketCount(playoutBufferedBlockCount)
        }
    }

    private mutating func updateRxBuffer(_ update: (inout RxBufferRuntimeSnapshot) -> Void) {
        guard var rxBuffer = metrics.rxBuffer else {
            return
        }
        update(&rxBuffer)
        metrics.rxBuffer = rxBuffer
    }
}
