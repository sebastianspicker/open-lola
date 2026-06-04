import Dispatch
import Foundation

func directPeerAES67SSRC(peerID: String) -> UInt32 {
    let hash = directPeerFNV1A32(peerID)
    return hash == 0 ? 1 : hash
}

struct DirectPeerAudioTXLoopConfiguration {
    var transport: DirectPeerSessionAudioTransport
    var opusEncoder: OpusCELTLowDelayEncoder?
    var rtpSSRC: UInt32
    var maxPackets: Int
}

private struct DirectPeerAudioTXEncodingPlan {
    var encodeOpus: ((UnsafeRawBufferPointer) throws -> Data)?
}

private struct DirectPeerAudioTXPayloadView {
    var block: RealtimeAudioFrameBlock
    var bytes: UnsafeRawBufferPointer
}

func runAudioTXLoop(
    runner: inout PeerSessionRunner,
    audioGraph: DirectPeerRealtimeAudioGraph,
    configuration: DirectPeerAudioTXLoopConfiguration
) throws -> DirectPeerAudioTXDrainResult {
    let encodingPlan = try makeDirectPeerAudioTXEncodingPlan(configuration)
    var result = DirectPeerAudioTXDrainResult()
    while result.payloadsSent < configuration.maxPackets {
        let didSend = try sendNextDirectPeerAudioTXPayload(
            runner: &runner,
            audioGraph: audioGraph,
            configuration: configuration,
            encodingPlan: encodingPlan
        )
        guard didSend else {
            break
        }
        result.payloadsSent += 1
    }
    if configuration.maxPackets > 0, result.payloadsSent == configuration.maxPackets {
        result.budgetExhausted = true
    }
    return result
}

private func makeDirectPeerAudioTXEncodingPlan(
    _ configuration: DirectPeerAudioTXLoopConfiguration
) throws -> DirectPeerAudioTXEncodingPlan {
    switch configuration.transport {
    case .openLolaRaw, .aes67ST2110L24:
        return DirectPeerAudioTXEncodingPlan(encodeOpus: nil)
    case .openLolaOpusCeltLowDelay:
        guard let opusEncoder = configuration.opusEncoder else {
            throw DirectPeerSessionAVRuntimeError.unsupportedAudioCompressionShape("missing Opus encoder")
        }
        var opusEncodeScratch = Data(count: OpusCELTLowDelayConstants.maxEncodedByteCount)
        return DirectPeerAudioTXEncodingPlan { payloadBytes in
            let encodedByteCount = try opusEncodeScratch.withUnsafeMutableBytes { output in
                try opusEncoder.encode(payloadBytes, into: output)
            }
            return Data(opusEncodeScratch.prefix(encodedByteCount))
        }
    }
}

private func sendNextDirectPeerAudioTXPayload(
    runner: inout PeerSessionRunner,
    audioGraph: DirectPeerRealtimeAudioGraph,
    configuration: DirectPeerAudioTXLoopConfiguration,
    encodingPlan: DirectPeerAudioTXEncodingPlan
) throws -> Bool {
    try audioGraph.withCapturedPayload { block, payloadBytes in
        try sendDirectPeerAudioTXPayload(
            runner: &runner,
            audioGraph: audioGraph,
            payload: DirectPeerAudioTXPayloadView(block: block, bytes: payloadBytes),
            configuration: configuration,
            encodingPlan: encodingPlan
        )
        return true
    } ?? false
}

private func sendDirectPeerAudioTXPayload(
    runner: inout PeerSessionRunner,
    audioGraph: DirectPeerRealtimeAudioGraph,
    payload: DirectPeerAudioTXPayloadView,
    configuration: DirectPeerAudioTXLoopConfiguration,
    encodingPlan: DirectPeerAudioTXEncodingPlan
) throws {
    let sequenceNumber = payload.block.startFrame / UInt64(audioGraph.configuration.framesPerBuffer) + 1
    switch configuration.transport {
    case .openLolaRaw:
        try runner.sendAudioPayload(
            payload.bytes,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: payload.block.startFrame,
            hostTimeNanoseconds: payload.block.hostTimeNanoseconds
        )
    case .openLolaOpusCeltLowDelay:
        guard let encodeOpus = encodingPlan.encodeOpus else {
            preconditionFailure("Opus encoder was prevalidated for Opus transport")
        }
        let encoded = try encodeOpus(payload.bytes)
        try runner.sendOpusAudioPayload(
            encoded,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: payload.block.startFrame,
            hostTimeNanoseconds: payload.block.hostTimeNanoseconds,
            channelCount: audioGraph.configuration.channelCount
        )
    case .aes67ST2110L24:
        try runner.sendAES67ST2110L24AudioPayload(
            payload.bytes,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: payload.block.startFrame,
            ssrc: configuration.rtpSSRC
        )
    }
}

struct DirectPeerAudioTXDrainResult {
    var payloadsSent = 0
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
        if pendingDeadlines[deadlineIndex].packets.contains(where: { $0.header.fragmentIndex == packet.header.fragmentIndex })
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

struct DirectPeerAudioRXLoopConfiguration {
    var transport: DirectPeerSessionAudioTransport
    var opusDecoder: OpusCELTLowDelayDecoder?
    var maxPackets: Int
}

struct DirectPeerAudioRXLoopState {
    var rtpValidator: AES67ST2110L24RTPReceiveValidator
    var aes67ClockMapper: DirectPeerAES67RTPHostTimeMapper
    var rawAudioReassembly: DirectPeerOpenLolaRawAudioReassemblyState
}

private struct DirectPeerAudioRXLoopContext {
    var state: DirectPeerAudioRXLoopState
    var result = DirectPeerAudioRXDrainResult()
    var opusDecodeScratch: Data
    var received = 0
}

private struct DirectPeerAudioPlayoutPayload {
    var payload: Data
    var senderFrameIndex: UInt64
    var senderHostTimeNanoseconds: UInt64
}

private enum DirectPeerAudioRXReceiveOutcome {
    case payload(DirectPeerAudioPlayoutPayload)
    case dropped
    case noPacket
}

func runAudioRXLoop(
    runner: inout PeerSessionRunner,
    audioGraph: DirectPeerRealtimeAudioGraph,
    state: inout DirectPeerAudioRXLoopState,
    configuration: DirectPeerAudioRXLoopConfiguration
) throws -> DirectPeerAudioRXDrainResult {
    var context = DirectPeerAudioRXLoopContext(
        state: state,
        opusDecodeScratch: Data(count: configuration.opusDecoder?.outputPCMByteCount ?? 0)
    )
    while context.received < configuration.maxPackets {
        switch try receiveDirectPeerAudioPayload(
            runner: &runner,
            configuration: configuration,
            context: &context
        ) {
        case .payload(let payload):
            queueDirectPeerAudioPayload(payload, audioGraph: audioGraph, result: &context.result)
        case .dropped:
            continue
        case .noPacket:
            state = context.state
            return context.result
        }
    }
    state = context.state
    return context.result
}

private func receiveDirectPeerAudioPayload(
    runner: inout PeerSessionRunner,
    configuration: DirectPeerAudioRXLoopConfiguration,
    context: inout DirectPeerAudioRXLoopContext
) throws -> DirectPeerAudioRXReceiveOutcome {
    switch configuration.transport {
    case .openLolaRaw:
        return try receiveDirectPeerRawAudioPayload(runner: &runner, context: &context)
    case .openLolaOpusCeltLowDelay:
        return try receiveDirectPeerOpusAudioPayload(
            runner: &runner,
            configuration: configuration,
            context: &context
        )
    case .aes67ST2110L24:
        return try receiveDirectPeerAES67AudioPayload(runner: &runner, context: &context)
    }
}

private func receiveDirectPeerRawAudioPayload(
    runner: inout PeerSessionRunner,
    context: inout DirectPeerAudioRXLoopContext
) throws -> DirectPeerAudioRXReceiveOutcome {
    let receivedPacket: PeerSessionReceivedAudioMediaPacket
    do {
        guard let packet = try runner.receiveDecodedAudioMediaPacketIfAvailable() else {
            return .noPacket
        }
        receivedPacket = packet
    } catch {
        guard isRecoverableOpenLolaRawAudioReceiveError(error) else {
            throw error
        }
        context.received += 1
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    context.received += 1
    guard receivedPacket.packet.header.payloadType == DirectPeerSessionAudioTransport.openLolaRaw.payloadType else {
        context.result.unexpectedPayloadTypes += 1
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    guard let decoded = receivedPacket.decodedPcmV2 else {
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    let reassembled: DirectPeerOpenLolaRawAudioBlock?
    do {
        reassembled = try context.state.rawAudioReassembly.receive(decoded)
        context.result.droppedBeforePlayout += context.state.rawAudioReassembly.consumeDroppedIncompleteDeadlines()
        context.result.droppedBeforePlayout += context.state.rawAudioReassembly.consumeDroppedDuplicateFragments()
    } catch {
        context.result.droppedBeforePlayout += context.state.rawAudioReassembly.flushIncomplete()
        context.result.droppedBeforePlayout += context.state.rawAudioReassembly.consumeDroppedDuplicateFragments()
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    guard let reassembled else {
        return .dropped
    }
    return .payload(DirectPeerAudioPlayoutPayload(
        payload: reassembled.payload,
        senderFrameIndex: reassembled.senderFrameIndex,
        senderHostTimeNanoseconds: reassembled.senderHostTimeNanoseconds
    ))
}

private func receiveDirectPeerOpusAudioPayload(
    runner: inout PeerSessionRunner,
    configuration: DirectPeerAudioRXLoopConfiguration,
    context: inout DirectPeerAudioRXLoopContext
) throws -> DirectPeerAudioRXReceiveOutcome {
    let receivedPacket: PeerSessionReceivedAudioMediaPacket
    do {
        guard let packet = try runner.receiveDecodedAudioMediaPacketIfAvailable() else {
            return .noPacket
        }
        receivedPacket = packet
    } catch is UdpMediaMalformedDatagramError {
        context.received += 1
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    context.received += 1
    guard receivedPacket.packet.header.payloadType == configuration.transport.payloadType else {
        context.result.unexpectedPayloadTypes += 1
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    guard let opusDecoder = configuration.opusDecoder else {
        throw DirectPeerSessionAVRuntimeError.unsupportedAudioCompressionShape("missing Opus decoder")
    }
    guard let decoded = receivedPacket.decodedOpusCeltLowDelay else {
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    do {
        let decodedByteCount = try decoded.payload.withUnsafeBytes { input in
            try context.opusDecodeScratch.withUnsafeMutableBytes { output in
                try opusDecoder.decode(input, into: output)
            }
        }
        return .payload(DirectPeerAudioPlayoutPayload(
            payload: Data(context.opusDecodeScratch.prefix(decodedByteCount)),
            senderFrameIndex: decoded.header.senderFrameIndex,
            senderHostTimeNanoseconds: decoded.header.senderHostTimeNanoseconds
        ))
    } catch {
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
}

private func receiveDirectPeerAES67AudioPayload(
    runner: inout PeerSessionRunner,
    context: inout DirectPeerAudioRXLoopContext
) throws -> DirectPeerAudioRXReceiveOutcome {
    let packet: RTPPacket
    do {
        guard let receivedPacket = try runner.receiveAES67ST2110L24RTPPacketIfAvailable() else {
            return .noPacket
        }
        packet = receivedPacket
    } catch {
        context.received += 1
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    context.received += 1
    let decodedPayload: Data
    do {
        let lostBefore = context.state.rtpValidator.lostPackets
        try context.state.rtpValidator.validate(packet)
        let lostDelta = max(0, context.state.rtpValidator.lostPackets - lostBefore)
        context.result.rtpPacketsLost += lostDelta
        context.result.droppedBeforePlayout += lostDelta
        decodedPayload = try L24PCMCodec.decodeFloat32InterleavedStereo(packet.payload)
    } catch {
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    guard let mappedHostTimeNanoseconds = context.state.aes67ClockMapper.hostTimeNanoseconds(
        rtpTimestamp: packet.header.timestamp,
        observedHostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
    ) else {
        context.result.droppedBeforePlayout += 1
        return .dropped
    }
    return .payload(DirectPeerAudioPlayoutPayload(
        payload: decodedPayload,
        senderFrameIndex: UInt64(packet.header.timestamp),
        senderHostTimeNanoseconds: mappedHostTimeNanoseconds
    ))
}

private func queueDirectPeerAudioPayload(
    _ payload: DirectPeerAudioPlayoutPayload,
    audioGraph: DirectPeerRealtimeAudioGraph,
    result: inout DirectPeerAudioRXDrainResult
) {
        let queueResult = audioGraph.queuePlayoutPayload(
            payload.payload,
            startFrame: payload.senderFrameIndex,
            hostTimeNanoseconds: payload.senderHostTimeNanoseconds
        )
        if queueResult == .stored {
            result.queuedForPlayout += 1
            result.latestHostTimeNanoseconds = payload.senderHostTimeNanoseconds
        } else {
            result.droppedByPlayoutQueue += 1
        }
}

private func isRecoverableOpenLolaRawAudioReceiveError(_ error: Error) -> Bool {
    if error is UdpMediaMalformedDatagramError {
        return true
    }
    if error is MadiReceiveError {
        return true
    }
    if let runnerError = error as? PeerSessionRunnerError {
        switch runnerError {
        case .unsupportedControlMessage:
            return true
        default:
            return false
        }
    }
    return false
}
