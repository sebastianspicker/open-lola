// Moves incoming PCM payloads through bounded realtime storage and returns explicit pressure outcomes so network code never owns callback buffers.
import CoreAudio
import OpenLolaEvidenceModels
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

    private var metricsState: RealtimeAudioHandoffMetrics
    private var packetizationWindow = PerformanceCounterWindow()
    private var depacketizationWindow = PerformanceCounterWindow()

    /// Counters only; cheap enough for per-block callers. Use `metrics` for final reports.
    public var counters: RealtimeAudioHandoffMetrics { metricsState }

    /// Counters plus duration summaries (sorts both windows), for final reports.
    public var metrics: RealtimeAudioHandoffMetrics {
        var snapshot = metricsState
        snapshot.packetizationDuration = packetizationWindow.summary
        snapshot.depacketizationDuration = depacketizationWindow.summary
        return snapshot
    }

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
        self.metricsState = initialState.metrics
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
        let inputBuffers = ReadOnlyAudioBufferListPointer(input)
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
        metricsState.networkReceiveBlocks += 1
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
        metricsState.droppedNetworkBlocks += 1
        updateRxBuffer { snapshot in
            snapshot.lostPackets += 1
        }
        depacketizationWindow.record(clock.elapsedMicroseconds(since: start))
        return .droppedInvalid
    }

    private mutating func recordLateReceiveDrop(start: UInt64) -> RealtimeAudioPacketReceiveResult {
        metricsState.latePackets += 1
        metricsState.droppedNetworkBlocks += 1
        updateRxBuffer { snapshot in
            snapshot.latePackets += 1
            snapshot.lostPackets += 1
        }
        depacketizationWindow.record(clock.elapsedMicroseconds(since: start))
        return .droppedLate
    }

    private mutating func recordPlayoutEnqueue(
        _ result: RealtimeAudioRingPushResult,
        start: UInt64
    ) -> RealtimeAudioPacketReceiveResult {
        switch result {
        case .stored:
            updateMaximumBufferedBlocks()
            depacketizationWindow.record(clock.elapsedMicroseconds(since: start))
            return .queued
        case .droppedLate:
            metricsState.latePackets += 1
            metricsState.droppedNetworkBlocks += 1
            updateRxBuffer { snapshot in
                snapshot.latePackets += 1
                snapshot.lostPackets += 1
            }
            updateMaximumBufferedBlocks()
            depacketizationWindow.record(clock.elapsedMicroseconds(since: start))
            return .droppedLate
        case .droppedFull, .droppedAhead:
            metricsState.droppedNetworkBlocks += 1
            updateRxBuffer { snapshot in
                snapshot.overruns += 1
            }
            updateMaximumBufferedBlocks()
            depacketizationWindow.record(clock.elapsedMicroseconds(since: start))
            return .droppedFull
        case .droppedInvalid:
            metricsState.droppedNetworkBlocks += 1
            updateMaximumBufferedBlocks()
            depacketizationWindow.record(clock.elapsedMicroseconds(since: start))
            return .droppedInvalid
        }
    }

    public mutating func renderCallback() -> RealtimeAudioPlayoutResult {
        let result = playout.renderNextBlock()
        metricsState.outputBlocks += 1
        if case .silence = result {
            metricsState.outputUnderrunBlocks += 1
            updateRxBuffer { snapshot in
                snapshot.underruns += 1
            }
        }
        updateMaximumBufferedBlocks()
        return result
    }

    public mutating func markShutdownCompleted() {
        metricsState.shutdownCompleted = true
    }

    private mutating func recordCaptureResult(
        _ captureResult: RealtimeAudioCapturePushResult
    ) -> RealtimeAudioRingPushResult {
        metricsState.inputBlocks += 1
        switch captureResult.copyKind {
        case .silent:
            break
        case .direct:
            metricsState.directInputBlocks += 1
        case .remapped:
            metricsState.remappedInputBlocks += 1
        case .invalid:
            metricsState.invalidInputBlocks += 1
            metricsState.allocationWarnings += 1
        }
        if captureResult.result == .droppedInvalid {
            metricsState.droppedInputBlocks += 1
        } else if captureResult.result == .droppedFull {
            metricsState.droppedInputBlocks += 1
            metricsState.callbackOverrunBlocks += 1
            metricsState.fullCaptureRingBlocks += 1
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
        packetizationWindow.record(clock.elapsedMicroseconds(since: start))
        self.nextSequenceNumber = nextSequenceNumber
        metricsState.networkSendBlocks += 1
        metricsState.packetFragmentCount += fragmentCount
        updateMaximumBufferedBlocks()
    }

    private mutating func updateMaximumBufferedBlocks() {
        let playoutBufferedBlockCount = playout.bufferedBlockCount
        metricsState.maximumCaptureRingOccupancyBlocks = max(
            metricsState.maximumCaptureRingOccupancyBlocks,
            captureRing.count
        )
        metricsState.maximumPlayoutQueueDepthBlocks = max(
            metricsState.maximumPlayoutQueueDepthBlocks,
            playoutBufferedBlockCount
        )
        metricsState.maximumBufferedBlocks = max(
            metricsState.maximumBufferedBlocks,
            captureRing.count,
            playoutBufferedBlockCount
        )
        if metricsState.maximumBufferedBlocks > metricsState.ringCapacityBlocks {
            metricsState.hiddenPlayoutGrowthDetected = true
        }
        updateRxBuffer { snapshot in
            snapshot.recordBufferedPacketCount(playoutBufferedBlockCount)
        }
    }

    private mutating func updateRxBuffer(_ update: (inout RxBufferRuntimeSnapshot) -> Void) {
        guard var rxBuffer = metricsState.rxBuffer else {
            return
        }
        update(&rxBuffer)
        metricsState.rxBuffer = rxBuffer
    }
}
