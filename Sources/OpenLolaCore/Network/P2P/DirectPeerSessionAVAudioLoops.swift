import Dispatch
import Foundation

func directPeerAES67SSRC(peerID: String) -> UInt32 {
    let hash = directPeerFNV1A32(peerID)
    return hash == 0 ? 1 : hash
}

func runAudioTXLoop(
    runner: inout PeerSessionRunner,
    audioGraph: DirectPeerRealtimeAudioGraph,
    transport: DirectPeerSessionAudioTransport,
    opusEncoder: OpusCELTLowDelayEncoder?,
    rtpSSRC: UInt32,
    maxPackets: Int
) throws -> DirectPeerAudioTXDrainResult {
    let encodeOpus: ((UnsafeRawBufferPointer) throws -> Data)?
    var opusEncodeScratch = Data()
    switch transport {
    case .openLolaRaw, .aes67ST2110L24:
        encodeOpus = nil
    case .openLolaOpusCeltLowDelay:
        guard let opusEncoder else {
            throw DirectPeerSessionAVRuntimeError.unsupportedAudioCompressionShape("missing Opus encoder")
        }
        opusEncodeScratch = Data(count: OpusCELTLowDelayConstants.maxEncodedByteCount)
        encodeOpus = { payloadBytes in
            let encodedByteCount = try opusEncodeScratch.withUnsafeMutableBytes { output in
                try opusEncoder.encode(payloadBytes, into: output)
            }
            return Data(opusEncodeScratch.prefix(encodedByteCount))
        }
    }

    var result = DirectPeerAudioTXDrainResult()
    while result.payloadsSent < maxPackets {
        let didSend = try audioGraph.withCapturedPayload { block, payloadBytes in
            switch transport {
            case .openLolaRaw:
                try runner.sendAudioPayload(
                    payloadBytes,
                    sequenceNumber: block.startFrame / UInt64(audioGraph.configuration.framesPerBuffer) + 1,
                    senderFrameIndex: block.startFrame,
                    hostTimeNanoseconds: block.hostTimeNanoseconds
                )
            case .openLolaOpusCeltLowDelay:
                guard let encodeOpus else {
                    preconditionFailure("Opus encoder was prevalidated for Opus transport")
                }
                let encoded = try encodeOpus(payloadBytes)
                try runner.sendOpusAudioPayload(
                    encoded,
                    sequenceNumber: block.startFrame / UInt64(audioGraph.configuration.framesPerBuffer) + 1,
                    senderFrameIndex: block.startFrame,
                    hostTimeNanoseconds: block.hostTimeNanoseconds,
                    channelCount: audioGraph.configuration.channelCount
                )
            case .aes67ST2110L24:
                try runner.sendAES67ST2110L24AudioPayload(
                    payloadBytes,
                    sequenceNumber: block.startFrame / UInt64(audioGraph.configuration.framesPerBuffer) + 1,
                    senderFrameIndex: block.startFrame,
                    ssrc: rtpSSRC
                )
            }
            return true
        } ?? false
        guard didSend else {
            break
        }
        result.payloadsSent += 1
    }
    if maxPackets > 0, result.payloadsSent == maxPackets {
        result.budgetExhausted = true
    }
    return result
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

func runAudioRXLoop(
    runner: inout PeerSessionRunner,
    audioGraph: DirectPeerRealtimeAudioGraph,
    transport: DirectPeerSessionAudioTransport,
    opusDecoder: OpusCELTLowDelayDecoder?,
    rtpValidator: inout AES67ST2110L24RTPReceiveValidator,
    aes67ClockMapper: inout DirectPeerAES67RTPHostTimeMapper,
    rawAudioReassembly: inout DirectPeerOpenLolaRawAudioReassemblyState,
    maxPackets: Int
) throws -> DirectPeerAudioRXDrainResult {
    var result = DirectPeerAudioRXDrainResult()
    var opusDecodeScratch = Data(count: opusDecoder?.outputPCMByteCount ?? 0)
    var received = 0
    while received < maxPackets {
        let decodedPayload: Data
        let senderFrameIndex: UInt64
        let senderHostTimeNanoseconds: UInt64
        switch transport {
        case .openLolaRaw:
            let receivedPacket: PeerSessionReceivedAudioMediaPacket
            do {
                guard let packet = try runner.receiveDecodedAudioMediaPacketIfAvailable() else {
                    return result
                }
                receivedPacket = packet
            } catch {
                guard isRecoverableOpenLolaRawAudioReceiveError(error) else {
                    throw error
                }
                received += 1
                result.droppedBeforePlayout += 1
                continue
            }
            received += 1
            guard receivedPacket.packet.header.payloadType == transport.payloadType else {
                result.unexpectedPayloadTypes += 1
                result.droppedBeforePlayout += 1
                continue
            }
            guard let decoded = receivedPacket.decodedPcmV2 else {
                result.droppedBeforePlayout += 1
                continue
            }
            let reassembled: DirectPeerOpenLolaRawAudioBlock?
            do {
                reassembled = try rawAudioReassembly.receive(decoded)
                result.droppedBeforePlayout += rawAudioReassembly.consumeDroppedIncompleteDeadlines()
                result.droppedBeforePlayout += rawAudioReassembly.consumeDroppedDuplicateFragments()
            } catch {
                result.droppedBeforePlayout += rawAudioReassembly.flushIncomplete()
                result.droppedBeforePlayout += rawAudioReassembly.consumeDroppedDuplicateFragments()
                result.droppedBeforePlayout += 1
                continue
            }
            guard let reassembled else {
                continue
            }
            decodedPayload = reassembled.payload
            senderFrameIndex = reassembled.senderFrameIndex
            senderHostTimeNanoseconds = reassembled.senderHostTimeNanoseconds
        case .openLolaOpusCeltLowDelay:
            let receivedPacket: PeerSessionReceivedAudioMediaPacket
            do {
                guard let packet = try runner.receiveDecodedAudioMediaPacketIfAvailable() else {
                    return result
                }
                receivedPacket = packet
            } catch is UdpMediaMalformedDatagramError {
                received += 1
                result.droppedBeforePlayout += 1
                continue
            }
            received += 1
            guard receivedPacket.packet.header.payloadType == transport.payloadType else {
                result.unexpectedPayloadTypes += 1
                result.droppedBeforePlayout += 1
                continue
            }
            guard let opusDecoder else {
                throw DirectPeerSessionAVRuntimeError.unsupportedAudioCompressionShape("missing Opus decoder")
            }
            guard let decoded = receivedPacket.decodedOpusCeltLowDelay else {
                result.droppedBeforePlayout += 1
                continue
            }
            do {
                let decodedByteCount = try decoded.payload.withUnsafeBytes { input in
                    try opusDecodeScratch.withUnsafeMutableBytes { output in
                        try opusDecoder.decode(input, into: output)
                    }
                }
                decodedPayload = Data(opusDecodeScratch.prefix(decodedByteCount))
            } catch {
                result.droppedBeforePlayout += 1
                continue
            }
            senderFrameIndex = decoded.header.senderFrameIndex
            senderHostTimeNanoseconds = decoded.header.senderHostTimeNanoseconds
        case .aes67ST2110L24:
            let packet: RTPPacket
            do {
                guard let receivedPacket = try runner.receiveAES67ST2110L24RTPPacketIfAvailable() else {
                    return result
                }
                packet = receivedPacket
            } catch {
                received += 1
                result.droppedBeforePlayout += 1
                continue
            }
            received += 1
            do {
                let lostBefore = rtpValidator.lostPackets
                try rtpValidator.validate(packet)
                let lostDelta = max(0, rtpValidator.lostPackets - lostBefore)
                result.rtpPacketsLost += lostDelta
                result.droppedBeforePlayout += lostDelta
                decodedPayload = try L24PCMCodec.decodeFloat32InterleavedStereo(packet.payload)
            } catch {
                result.droppedBeforePlayout += 1
                continue
            }
            senderFrameIndex = UInt64(packet.header.timestamp)
            guard let mappedHostTimeNanoseconds = aes67ClockMapper.hostTimeNanoseconds(
                rtpTimestamp: packet.header.timestamp,
                observedHostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
            ) else {
                result.droppedBeforePlayout += 1
                continue
            }
            senderHostTimeNanoseconds = mappedHostTimeNanoseconds
        }
        let queueResult = audioGraph.queuePlayoutPayload(
            decodedPayload,
            startFrame: senderFrameIndex,
            hostTimeNanoseconds: senderHostTimeNanoseconds
        )
        if queueResult == .stored {
            result.queuedForPlayout += 1
            result.latestHostTimeNanoseconds = senderHostTimeNanoseconds
        } else {
            result.droppedByPlayoutQueue += 1
        }
    }
    return result
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
