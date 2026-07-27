// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation

func directPeerAES67SSRC(peerID: String) -> UInt32 {
    let hash = directPeerFNV1A32(peerID)
    return hash == 0 ? 1 : hash
}

struct DirectPeerAudioTXLoopConfiguration {
    var transport: DirectPeerSessionAudioTransport
    var opusEncoder: OpusCELTLowDelayEncoder?
    var opusScratch: DirectPeerOpusSessionScratch? = nil
    var rtpSSRC: UInt32
    var maxPackets: Int
    var preferLatestPayload = false
}

/// Owned by one Direct P2P media session. The media loop is its sole user, so
/// the fixed buffers can be reused without cross-thread synchronization.
final class DirectPeerOpusSessionScratch: @unchecked Sendable {
    var encoded = Data(count: OpusCELTLowDelayConstants.maxEncodedByteCount)
    var decoded: Data

    init(decodedByteCount: Int) {
        decoded = Data(count: decodedByteCount)
    }
}

private struct DirectPeerAudioTXPayloadView {
    var block: RealtimeAudioFrameBlock
    var bytes: UnsafeRawBufferPointer
}

private enum DirectPeerAudioTXPayloadOutcome {
    case noPayload
    case sent
    case droppedForBackpressure
}

func runAudioTXLoop(
    runner: inout PeerSessionRunner,
    audioGraph: DirectPeerRealtimeAudioGraph,
    configuration: DirectPeerAudioTXLoopConfiguration
) throws -> DirectPeerAudioTXDrainResult {
    var result = DirectPeerAudioTXDrainResult()
    if configuration.preferLatestPayload {
        result.payloadsDroppedBeforeSend = audioGraph.dropCapturedPayloadsKeepingNewest()
    }
    while result.payloadsSent < configuration.maxPackets {
        let outcome = try sendNextDirectPeerAudioTXPayload(
            runner: &runner,
            audioGraph: audioGraph,
            configuration: configuration,
        )
        switch outcome {
        case .noPayload:
            break
        case .sent:
            result.payloadsSent += 1
            continue
        case .droppedForBackpressure:
            result.payloadsDroppedBeforeSend += 1
            break
        }
        break
    }
    if configuration.maxPackets > 0, result.payloadsSent == configuration.maxPackets {
        result.budgetExhausted = true
    }
    return result
}

private func sendNextDirectPeerAudioTXPayload(
    runner: inout PeerSessionRunner,
    audioGraph: DirectPeerRealtimeAudioGraph,
    configuration: DirectPeerAudioTXLoopConfiguration,
) throws -> DirectPeerAudioTXPayloadOutcome {
    let sent = try audioGraph.withCapturedPayload { block, payloadBytes in
        try trySendDirectPeerAudioTXPayload(
            runner: &runner,
            audioGraph: audioGraph,
            payload: DirectPeerAudioTXPayloadView(block: block, bytes: payloadBytes),
            configuration: configuration,
        )
    }
    guard let sent else {
        return .noPayload
    }
    return sent ? .sent : .droppedForBackpressure
}

private func trySendDirectPeerAudioTXPayload(
    runner: inout PeerSessionRunner,
    audioGraph: DirectPeerRealtimeAudioGraph,
    payload: DirectPeerAudioTXPayloadView,
    configuration: DirectPeerAudioTXLoopConfiguration,
) throws -> Bool {
    let sequenceNumber = payload.block.startFrame / UInt64(audioGraph.configuration.framesPerBuffer) + 1
    switch configuration.transport {
    case .openLolaRaw:
        return try runner.trySendAudioPayload(
            payload.bytes,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: payload.block.startFrame,
            hostTimeNanoseconds: payload.block.hostTimeNanoseconds
        )
    case .openLolaOpusCeltLowDelay:
        guard let opusEncoder = configuration.opusEncoder,
              let opusScratch = configuration.opusScratch else {
            throw DirectPeerSessionAVRuntimeError.unsupportedAudioCompressionShape("missing Opus encoder scratch")
        }
        let encodedByteCount = try opusScratch.encoded.withUnsafeMutableBytes { output in
            try opusEncoder.encode(payload.bytes, into: output)
        }
        let encoded = Data(opusScratch.encoded.prefix(encodedByteCount))
        return try runner.trySendOpusAudioPayload(
            encoded,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: payload.block.startFrame,
            hostTimeNanoseconds: payload.block.hostTimeNanoseconds,
            channelCount: audioGraph.configuration.channelCount
        )
    case .aes67ST2110L24:
        return try runner.trySendAES67ST2110L24AudioPayload(
            payload.bytes,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: payload.block.startFrame,
            ssrc: configuration.rtpSSRC
        )
    }
}

struct DirectPeerAudioTXDrainResult {
    var payloadsSent = 0
    var payloadsDroppedBeforeSend = 0
    var budgetExhausted = false
}

struct DirectPeerAudioRXDrainResult {
    var queuedForPlayout = 0
    var droppedBeforePlayout = 0
    var droppedByPlayoutQueue = 0
    var unexpectedPayloadTypes = 0
    var rtpPacketsLost = 0
    var latestHostTimeNanoseconds: UInt64?
}

struct DirectPeerAES67RTPHostTimeMapper {
    var sampleRateHertz: Int
    private var anchorRTPTimestamp: UInt32?
    private var anchorHostTimeNanoseconds: UInt64?

    init(sampleRateHertz: Int) {
        self.sampleRateHertz = sampleRateHertz
    }

    mutating func hostTimeNanoseconds(
        rtpTimestamp: UInt32,
        observedHostTimeNanoseconds: UInt64
    ) -> UInt64? {
        guard let anchorRTPTimestamp, let anchorHostTimeNanoseconds else {
            self.anchorRTPTimestamp = rtpTimestamp
            self.anchorHostTimeNanoseconds = observedHostTimeNanoseconds
            return observedHostTimeNanoseconds
        }
        let tickDelta = UInt32(rtpTimestamp &- anchorRTPTimestamp)
        let deltaNanoseconds = MediaClock.nanoseconds(
            forFrameCount: UInt64(tickDelta),
            sampleRateHertz: sampleRateHertz
        )
        let mapped = anchorHostTimeNanoseconds.addingReportingOverflow(deltaNanoseconds)
        return mapped.overflow ? nil : mapped.partialValue
    }
}

// swiftlint:disable:next type_name
struct DirectPeerOpenLolaRawAudioReassemblyState {
    private var pendingDeadlines: [DirectPeerOpenLolaRawAudioPendingDeadline] = []
    private var droppedIncompleteDeadlines = 0
    private var droppedDuplicateFragments = 0
    private let maxFragmentCount: UInt16
    private let maxPendingDeadlines: Int

    init(
        maxFragmentCount: UInt16 = directPeerOpenLolaRawAudioMaxFragmentsPerDeadline,
        maxPendingDeadlines: Int = 8
    ) {
        self.maxFragmentCount = maxFragmentCount
        self.maxPendingDeadlines = max(1, maxPendingDeadlines)
    }

    mutating func receive(_ packet: UdpPcmV2Packet) throws -> DirectPeerOpenLolaRawAudioBlock? {
        try validateFragmentCount(packet.header.fragmentCount)
        // Same-deadline raw-audio fragments must describe one playout block:
        // identity, timing, sample shape, fragment plan, metadata revision, and
        // packing mode all have to match before reassembly can share a buffer.
        let key = DirectPeerOpenLolaRawAudioDeadlineKey(packet.header)
        let deadlineIndex: Int
        if let existingIndex = pendingDeadlines.firstIndex(where: { $0.key == key }) {
            deadlineIndex = existingIndex
        } else {
            if pendingDeadlines.count >= maxPendingDeadlines {
                pendingDeadlines.removeFirst()
                droppedIncompleteDeadlines += 1
            }
            pendingDeadlines.append(DirectPeerOpenLolaRawAudioPendingDeadline(key: key))
            deadlineIndex = pendingDeadlines.count - 1
        }
        let fragmentIndex = packet.header.fragmentIndex
        if pendingDeadlines[deadlineIndex].packets.contains(where: { $0.header.fragmentIndex == fragmentIndex })
            || pendingDeadlines[deadlineIndex].packets.count >= Int(packet.header.fragmentCount) {
            droppedDuplicateFragments += 1
            return nil
        }
        pendingDeadlines[deadlineIndex].packets.append(packet)
        let reassembled = try UdpPcmV2FragmentReassembler.reassemble(
            pendingDeadlines[deadlineIndex].packets,
            maxFragmentCount: maxFragmentCount
        )
        guard let payload = reassembled.payload else {
            return nil
        }
        let header = pendingDeadlines[deadlineIndex].packets[0].header
        pendingDeadlines.remove(at: deadlineIndex)
        return DirectPeerOpenLolaRawAudioBlock(
            payload: payload,
            senderFrameIndex: header.senderFrameIndex,
            senderHostTimeNanoseconds: header.senderHostTimeNanoseconds
        )
    }

    mutating func flushIncomplete() -> Int {
        let dropped = pendingDeadlines.count
        pendingDeadlines.removeAll(keepingCapacity: true)
        return dropped
    }

    mutating func consumeDroppedIncompleteDeadlines() -> Int {
        let dropped = droppedIncompleteDeadlines
        droppedIncompleteDeadlines = 0
        return dropped
    }

    mutating func consumeDroppedDuplicateFragments() -> Int {
        let dropped = droppedDuplicateFragments
        droppedDuplicateFragments = 0
        return dropped
    }

    private func validateFragmentCount(_ fragmentCount: UInt16) throws {
        guard fragmentCount <= maxFragmentCount else {
            throw UdpPcmV2FragmentReassemblyError.fragmentCountExceedsLimit(
                actual: fragmentCount,
                max: maxFragmentCount
            )
        }
    }

}

// swiftlint:disable:next type_name
private struct DirectPeerOpenLolaRawAudioPendingDeadline {
    var key: DirectPeerOpenLolaRawAudioDeadlineKey
    var packets: [UdpPcmV2Packet] = []
}

private struct DirectPeerOpenLolaRawAudioDeadlineKey: Equatable {
    var streamID: UInt32
    var sequenceNumber: UInt64
    var senderFrameIndex: UInt64
    var senderHostTimeNanoseconds: UInt64
    var sampleRateHertz: UInt32
    var framesPerPacket: UInt32
    var totalChannelCount: UInt16
    var fragmentCount: UInt16
    var sampleFormat: UdpPcmSampleFormat
    var metadataRevision: UInt32
    var packingMode: AudioWirePackingMode

    init(_ header: UdpPcmV2PacketHeader) {
        streamID = header.streamID
        sequenceNumber = header.sequenceNumber
        senderFrameIndex = header.senderFrameIndex
        senderHostTimeNanoseconds = header.senderHostTimeNanoseconds
        sampleRateHertz = header.sampleRateHertz
        framesPerPacket = header.framesPerPacket
        totalChannelCount = header.totalChannelCount
        fragmentCount = header.fragmentCount
        sampleFormat = header.sampleFormat
        metadataRevision = header.metadataRevision
        packingMode = header.packingMode
    }
}

struct DirectPeerOpenLolaRawAudioBlock {
    var payload: Data
    var senderFrameIndex: UInt64
    var senderHostTimeNanoseconds: UInt64
}
